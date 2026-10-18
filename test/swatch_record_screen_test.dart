import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/core/analytics/analytics_logger.dart';
import 'package:nibpen/data/models/ink_model.dart';
import 'package:nibpen/features/record/analytics/swatch_record_tracker.dart';
import 'package:nibpen/features/record/controllers/swatch_record_controller.dart';
import 'package:nibpen/features/record/providers/ink_catalog_provider.dart';
import 'package:nibpen/features/record/screens/swatch_record_screen.dart';
import 'package:nibpen/shared/providers/ink_book_providers.dart';
import 'package:nibpen/shared/providers/owned_ink_providers.dart';
import 'package:nibpen/shared/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/record_fakes.dart';

void main() {
  late FakeInkBookRepository repo;
  late FakeLogger logger;
  SwatchRecordController? controller;

  const konpeki = InkModel(id: 'ink1', brand: 'Pilot', name: 'Kon-peki', hexColor: '#1E88E5');

  // 휴대폰 크기(360x800) — 기본 800x600이면 잉크 칸이 화면 밖이라 목록에서 안 만들어짐
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        inkBookRepoProvider.overrideWithValue(repo),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
        inkRequestRepoProvider.overrideWithValue(FakeInkRequestRepository()),
        analyticsLoggerProvider.overrideWithValue(logger),
        inkCatalogProvider.overrideWith((ref) async => const [konpeki]),
        // 화면이 만든 컨트롤러를 잡아두고 사진 선택(이미지 피커)을 대신한다
        swatchRecordControllerProvider.overrideWith(
          (ref, args) => controller = SwatchRecordController(ref, args),
        ),
      ],
      child: const MaterialApp(home: SwatchRecordScreen(entryQuery: 'home')),
    ));
    await tester.pump();
  }

  TextButton saveButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.byKey(const Key('swatch_save_button')));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeInkBookRepository();
    logger = FakeLogger();
    controller = null;
  });

  testWidgets('진입하면 start가 남고, 필수 입력 전에는 저장 버튼이 비활성', (tester) async {
    await pumpScreen(tester);

    expect(logger.names, ['swatch_record_start']);
    expect(logger.last('swatch_record_start')['entry_point'], 'home');
    expect(saveButton(tester).onPressed, isNull);
    expect(find.text('사진과 잉크만 있으면 저장할 수 있어요'), findsOneWidget);
    expect(find.text('저장할 공책: $kDefaultRecordBookName'), findsOneWidget,
        reason: '공책이 없으면 기본 공책이 만들어진다고 알려줌');
  });

  testWidgets('매칭 시트에서 아카이브 잉크를 고르면 필드에 표시되고 ink_match가 남는다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('아카이브에서 잉크 찾기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'kon');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kon-peki'));
    await tester.pumpAndSettle();

    expect(find.text('Kon-peki'), findsOneWidget);
    expect(find.text('Pilot'), findsOneWidget);
    expect(logger.last('swatch_ink_match')['match_type'], 'archive');
    expect(logger.last('swatch_ink_match')['query_len'], 3);
    expect(saveButton(tester).onPressed, isNull, reason: '사진이 아직 없음');
  });

  testWidgets('사진과 잉크 이름만으로 저장 버튼이 켜지고, 누르면 기록이 저장된다', (tester) async {
    await pumpScreen(tester);
    controller!
      ..setPhoto(File('swatch.png'), source: SwatchPhotoSource.camera, cropShape: 'circle')
      ..selectInk(const SwatchInk(name: '이름만'), matchType: SwatchMatchType.freeText);
    await tester.pump();

    expect(saveButton(tester).onPressed, isNotNull);
    expect(find.text('사진과 잉크만 있으면 저장할 수 있어요'), findsNothing);

    await tester.tap(find.byKey(const Key('swatch_save_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // 성공 오버레이 애니메이션

    expect(repo.added.single.entry.inkName, '이름만');
    expect(logger.names, contains('swatch_save_success'));
  });

  testWidgets('입력 없이 닫으면 확인 없이 나가고 exit(had_content=0)가 남는다', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        inkBookRepoProvider.overrideWithValue(repo),
        analyticsLoggerProvider.overrideWithValue(logger),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SwatchRecordScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    expect(find.byType(SwatchRecordScreen), findsNothing);
    expect(logger.last('swatch_record_exit')['had_content'], 0);
    expect(logger.last('swatch_record_exit')['entry_point'], 'unknown');
  });
}
