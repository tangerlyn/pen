import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/features/record/analytics/swatch_record_tracker.dart';
import 'helpers/record_fakes.dart';

/// docs/analytics_spec_swatch.md의 QA 시나리오(W1~W4)를 트래커 단위에서 재현한다.

class _Clock {
  var time = DateTime(2026, 10, 18, 12);
  DateTime now() => time;
  void advance(int ms) => time = time.add(Duration(milliseconds: ms));
}

void main() {
  late FakeLogger logger;
  late _Clock clock;

  SwatchRecordTracker tracker({
    SwatchEntryPoint entry = SwatchEntryPoint.home,
    SwatchRecordMode mode = SwatchRecordMode.create,
  }) =>
      SwatchRecordTracker(
        logger: logger,
        mode: mode,
        entryPoint: entry,
        sessionId: 'session-1',
        now: clock.now,
      );

  setUp(() {
    logger = FakeLogger();
    clock = _Clock();
  });

  test('W1 정상 기록: 퍼널 순서대로 남고 공통 파라미터가 모든 이벤트에 붙는다', () {
    final t = tracker()..start(hasPresetInk: false);
    t.photoSelected(source: SwatchPhotoSource.gallery, cropShape: 'circle', isReplace: false);
    t.inkMatched(matchType: SwatchMatchType.archive, queryLength: 4, filterCount: 1);
    clock.advance(4200);
    t.saved(recordId: 'r1', hasInkId: true, optionalFieldCount: 2, createdBook: false);

    expect(logger.names, [
      'swatch_record_start',
      'swatch_photo_select',
      'swatch_ink_match',
      'swatch_save_success',
    ]);
    for (final e in logger.events) {
      expect(e.params['record_session_id'], 'session-1');
      expect(e.params['mode'], 'new');
      expect(e.params['entry_point'], 'home');
    }
    expect(logger.last('swatch_photo_select'), containsPair('source', 'gallery'));
    expect(logger.last('swatch_ink_match')['match_type'], 'archive');
    expect(logger.last('swatch_ink_match')['query_len'], 4);
    final success = logger.last('swatch_save_success');
    expect(success['record_id'], 'r1');
    expect(success['has_ink_id'], 1);
    expect(success['optional_field_count'], 2);
    expect(success['elapsed_ms'], 4200);
  });

  test('W2 첫 기록·직접 입력: free_text, created_book=1', () {
    final t = tracker(entry: SwatchEntryPoint.emptyState)..start(hasPresetInk: false);
    t.photoSelected(source: SwatchPhotoSource.camera, cropShape: 'bottle', isReplace: false);
    t.inkMatched(matchType: SwatchMatchType.freeText);
    t.saved(recordId: 'r2', hasInkId: false, optionalFieldCount: 0, createdBook: true);

    expect(logger.last('swatch_record_start')['entry_point'], 'empty_state');
    expect(logger.last('swatch_ink_match')['match_type'], 'free_text');
    expect(logger.last('swatch_save_success')['created_book'], 1);
    expect(logger.last('swatch_save_success')['has_ink_id'], 0);
  });

  test('W3 잉크 상세 진입: has_preset_ink=1', () {
    tracker(entry: SwatchEntryPoint.inkDetail).start(hasPresetInk: true);
    expect(logger.last('swatch_record_start')['has_preset_ink'], 1);
    expect(logger.last('swatch_record_start')['entry_point'], 'ink_detail');
  });

  test('W4 사진 없이 이탈: last_stage=start, 잉크만 있어도 사진이 없으면 start', () {
    final t = tracker()..start(hasPresetInk: true);
    t.inkMatched(matchType: SwatchMatchType.preset);
    clock.advance(800);
    t.exited(hadContent: false);

    final exit = logger.last('swatch_record_exit');
    expect(exit['last_stage'], 'start');
    expect(exit['had_content'], 0);
    expect(exit['since_start_ms'], 800);
  });

  test('last_stage는 필수 입력 기준으로 진행하고, 저장 실패가 가장 깊다', () {
    final t = tracker()..start(hasPresetInk: false);
    expect(t.lastStage, SwatchRecordStage.start);
    t.photoSelected(source: SwatchPhotoSource.camera, cropShape: 'circle', isReplace: false);
    expect(t.lastStage, SwatchRecordStage.photoSelected);
    t.inkMatched(matchType: SwatchMatchType.archive);
    expect(t.lastStage, SwatchRecordStage.inkMatched);
    t.saveFailed(SwatchErrorStage.photoUpload, Exception('offline'));
    expect(t.lastStage, SwatchRecordStage.saveFailed);
    expect(logger.last('swatch_save_fail')['error_stage'], 'photo_upload');
    expect(logger.last('swatch_save_fail')['error_type'], '_Exception');
  });

  test('불변 조건: start는 1번, 세션이 끝난 뒤에는 어떤 이벤트도 남지 않는다', () {
    final t = tracker()
      ..start(hasPresetInk: false)
      ..start(hasPresetInk: false);
    t.saved(recordId: 'r', hasInkId: false, optionalFieldCount: 0, createdBook: false);
    t.exited(hadContent: true);
    t.photoSelected(source: SwatchPhotoSource.camera, cropShape: 'circle', isReplace: true);
    t.saveFailed(SwatchErrorStage.firestoreWrite, Exception());

    expect(logger.names, ['swatch_record_start', 'swatch_save_success']);
    expect(t.isFinished, isTrue);
  });

  test('수정 모드는 mode=edit, 진입 경로 쿼리는 명세에 없으면 unknown', () {
    tracker(mode: SwatchRecordMode.edit, entry: SwatchEntryPoint.recordDetail)
        .start(hasPresetInk: false);
    expect(logger.last('swatch_record_start')['mode'], 'edit');
    expect(logger.last('swatch_record_start')['entry_point'], 'record_detail');

    expect(SwatchEntryPoint.fromQuery('ink_detail'), SwatchEntryPoint.inkDetail);
    expect(SwatchEntryPoint.fromQuery('somewhere'), SwatchEntryPoint.unknown);
    expect(SwatchEntryPoint.fromQuery(null), SwatchEntryPoint.unknown);
  });
}
