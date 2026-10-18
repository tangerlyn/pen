import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/core/analytics/analytics_logger.dart';
import 'package:nibpen/data/models/ink_model.dart';
import 'package:nibpen/features/record/analytics/swatch_record_tracker.dart';
import 'package:nibpen/features/record/controllers/swatch_record_controller.dart';
import 'package:nibpen/shared/providers/ink_book_providers.dart';
import 'package:nibpen/shared/providers/owned_ink_providers.dart';
import 'package:nibpen/shared/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/record_fakes.dart';

void main() {
  late FakeInkBookRepository repo;
  late FakeStorageService storage;
  late FakeInkRequestRepository requests;
  late FakeLogger logger;
  late ProviderContainer container;

  final photo = File('swatch.png'); // 업로드는 가짜라 실제 파일이 없어도 됨
  Future<List<Map<String, dynamic>>> noMemo(String uid) async => [];

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      currentUidProvider.overrideWithValue('alice'),
      inkBookRepoProvider.overrideWithValue(repo),
      storageServiceProvider.overrideWithValue(storage),
      inkRequestRepoProvider.overrideWithValue(requests),
      analyticsLoggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  (SwatchRecordController, SwatchRecordArgs) controllerFor(SwatchRecordArgs args) {
    final provider = swatchRecordControllerProvider(args);
    container.listen(provider, (_, _) {}); // autoDispose 유지
    return (container.read(provider.notifier), args);
  }

  SwatchRecordController newController({String? presetInkId}) => controllerFor(
        SwatchRecordArgs(entryPoint: SwatchEntryPoint.home, presetInkId: presetInkId),
      ).$1;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeInkBookRepository();
    storage = FakeStorageService();
    requests = FakeInkRequestRepository();
    logger = FakeLogger();
    container = makeContainer();
  });

  test('필수 입력은 사진과 잉크 이름뿐 — 둘 중 하나라도 없으면 저장 불가', () {
    final c = newController();
    expect(c.state.canSave, isFalse);
    c.selectInk(const SwatchInk(name: '  '), matchType: SwatchMatchType.freeText);
    expect(c.state.canSave, isFalse, reason: '공백 이름은 이름이 아님');
    c.selectInk(const SwatchInk(name: '이름만'), matchType: SwatchMatchType.freeText);
    expect(c.state.canSave, isFalse, reason: '사진 없음');
    c.setPhoto(photo, source: SwatchPhotoSource.camera, cropShape: 'circle');
    expect(c.state.canSave, isTrue);
  });

  test('공책이 없는 사용자: 사진+이름만으로 저장하면 비공개 기본 공책을 만들고 거기에 기록한다', () async {
    final c = newController()
      ..setPhoto(photo, source: SwatchPhotoSource.gallery, cropShape: 'circle')
      ..selectInk(const SwatchInk(name: '이름만 아는 잉크'), matchType: SwatchMatchType.freeText);

    final result = await c.save(buildMemoBlocks: noMemo);

    expect(repo.created, [(name: kDefaultRecordBookName, visibility: 'private')]);
    expect(result!.createdBook, isTrue);
    expect(repo.added.single.bookId, result.bookId);
    final entry = repo.added.single.entry;
    expect(entry.inkName, '이름만 아는 잉크');
    expect(entry.brand, '');
    expect(entry.inkId, isNull);
    expect(entry.photoUrl, storage.uploaded.single);
    expect(entry.penName, isNull, reason: '빈 선택 항목은 문서에 쓰지 않음');
    expect(entry.toMap().containsKey('penName'), isFalse);

    final success = logger.last('swatch_save_success');
    expect(success['created_book'], 1);
    expect(success['has_ink_id'], 0);
    expect(success['optional_field_count'], 0);
    expect(success['record_id'], entry.id);

    // 다음 기록은 방금 쓴 공책이 기본값
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_record_book_id'), result.bookId);
  });

  test('공책이 있으면 마지막으로 쓴 공책에 저장하고 새로 만들지 않는다', () async {
    repo.books.addAll([book('b1'), book('b2')]);
    SharedPreferences.setMockInitialValues({'last_record_book_id': 'b2'});

    final c = newController()
      ..setPhoto(photo, source: SwatchPhotoSource.camera, cropShape: 'circle')
      ..selectInk(
        SwatchInk.fromArchive(const InkModel(id: 'ink1', brand: 'Pilot', name: 'Kon-peki')),
        matchType: SwatchMatchType.archive,
      )
      ..setPenName(' Custom 74 ')
      ..setRecordedAt(DateTime(2026, 2, 14));

    final result = await c.save(buildMemoBlocks: noMemo);

    expect(repo.created, isEmpty);
    expect(result!.bookId, 'b2');
    final entry = repo.added.single.entry;
    expect(entry.inkId, 'ink1');
    expect(entry.penName, 'Custom 74');
    expect(entry.recordedAt, DateTime(2026, 2, 14));
    // 브랜드·펜·날짜 = 3
    expect(logger.last('swatch_save_success')['optional_field_count'], 3);
  });

  test('기본 공책: 마지막 공책 → 그 공책이 지워졌으면 첫 공책 → 공책이 없으면 null', () {
    expect(resolveDefaultBookId([book('b1'), book('b2')], 'b2'), 'b2');
    expect(resolveDefaultBookId([book('b1'), book('b2')], 'gone'), 'b1');
    expect(resolveDefaultBookId([], 'b2'), isNull);
  });

  test('직접 고른 공책이 기본값보다 우선한다', () async {
    repo.books.addAll([book('b1'), book('b2')]);
    SharedPreferences.setMockInitialValues({'last_record_book_id': 'b2'});
    final c = newController()
      ..setPhoto(photo, source: SwatchPhotoSource.camera, cropShape: 'circle')
      ..selectInk(const SwatchInk(name: 'Ink'), matchType: SwatchMatchType.freeText)
      ..setBook('b1');
    final result = await c.save(buildMemoBlocks: noMemo);
    expect(result!.bookId, 'b1');
  });

  test('Firestore 쓰기 실패: fail 이벤트, 올린 사진 정리, 다시 저장해도 같은 문서 ID', () async {
    repo.books.add(book('b1'));
    repo.addError = Exception('unavailable');
    final c = newController()
      ..setPhoto(photo, source: SwatchPhotoSource.camera, cropShape: 'circle')
      ..selectInk(const SwatchInk(name: 'Ink'), matchType: SwatchMatchType.freeText);

    await expectLater(c.save(buildMemoBlocks: noMemo), throwsException);
    expect(logger.last('swatch_save_fail')['error_stage'], 'firestore_write');
    expect(storage.deleted, [storage.uploaded.first]);
    expect(c.state.isSaving, isFalse);
    expect(c.state.canSave, isTrue, reason: '다시 저장할 수 있어야 함');

    repo.addError = null;
    final retry = await c.save(buildMemoBlocks: noMemo);
    expect(retry, isNotNull);
    expect(logger.names.where((n) => n == 'swatch_save_success'), hasLength(1));
    expect(repo.added.single.entry.id, logger.last('swatch_save_success')['record_id']);
  });

  test('새 잉크 요청: inkRequests에 남기고 그 이름으로 기록에 연결', () async {
    final c = newController();
    await c.requestNewInk(brand: ' ', name: ' 없는 잉크 ', queryLength: 5);
    expect(requests.requests.single, (brand: '', name: '없는 잉크'));
    expect(c.state.ink!.name, '없는 잉크');
    expect(c.state.ink!.inkId, isNull);
    expect(logger.last('swatch_ink_match')['match_type'], 'request');
  });

  test('잉크 상세에서 들어오면 preset 매칭, 이미 고른 잉크는 덮어쓰지 않음', () {
    const ink = InkModel(id: 'ink9', brand: 'Sailor', name: 'Yama-dori');
    final c = newController(presetInkId: 'ink9')..applyPresetInk(ink);
    expect(logger.last('swatch_record_start')['has_preset_ink'], 1);
    expect(c.state.ink!.inkId, 'ink9');
    expect(logger.last('swatch_ink_match')['match_type'], 'preset');

    final other = newController(presetInkId: 'ink9')
      ..selectInk(const SwatchInk(name: '먼저 고름'), matchType: SwatchMatchType.freeText)
      ..applyPresetInk(ink);
    expect(other.state.ink!.name, '먼저 고름');
  });

  test('수정 모드: 같은 공책·문서를 updateRecord로 덮어쓰고 사진을 안 바꾸면 업로드하지 않음', () async {
    final edited = chartEntry('c1', penName: 'Old pen', photoUrl: 'https://old.png');
    final (c, _) = controllerFor(SwatchRecordArgs(
      entryPoint: SwatchEntryPoint.recordDetail,
      editBookId: 'b1',
      editEntry: edited,
    ));
    expect(c.state.canSave, isTrue, reason: '기존 사진·이름이 있으니 바로 저장 가능');
    c.setPenName('');

    await c.save(buildMemoBlocks: noMemo);

    expect(storage.uploaded, isEmpty);
    expect(repo.added, isEmpty);
    final u = repo.updated.single;
    expect(u.bookId, 'b1');
    expect(u.entry.id, 'c1');
    expect(u.entry.photoUrl, 'https://old.png');
    expect(u.entry.penName, isNull, reason: '비운 펜은 삭제 대상');
    expect(logger.last('swatch_save_success')['mode'], 'edit');
  });
}
