import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/data/models/ink_chart_model.dart';
import 'package:nibpen/features/record/screens/swatch_record_detail_screen.dart';
import 'package:nibpen/shared/providers/ink_book_providers.dart';
import 'package:nibpen/shared/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/record_fakes.dart';

void main() {
  Future<void> pumpDetail(WidgetTester tester, String entryId) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = FakeInkBookRepository(
      books: [book('b1', name: '파랑 공책')],
      charts: {
        'b1': [
          chartEntry('legacy', inkName: 'Kon-peki', createdAt: DateTime(2026, 3, 1)),
          InkChartModel(
            id: 'full',
            photoUrl: '',
            brand: 'Sailor',
            inkName: 'Yama-dori',
            memo: '쉰이 강함',
            createdAt: DateTime(2026, 10, 18),
            inkId: 'ink9',
            penName: 'Pro Gear',
            nibSize: 'MF',
            paperName: '토모에리버',
            recordedAt: DateTime(2026, 10, 1),
          ),
        ],
      },
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        inkBookRepoProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(home: SwatchRecordDetailScreen(bookId: 'b1', entryId: entryId)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('선택 항목을 채운 기록은 펜·닙·종이·날짜·공책·메모와 아카이브 링크를 보여준다', (tester) async {
    await pumpDetail(tester, 'full');
    for (final text in ['Yama-dori', 'Sailor', 'Pro Gear', 'MF', '토모에리버', '2026년 10월 1일', '파랑 공책', '쉰이 강함', '아카이브에서 보기']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byTooltip('수정'), findsOneWidget);
    expect(find.byTooltip('삭제'), findsOneWidget);
  });

  testWidgets('기존 잉크 차트 기록은 있는 정보만 보이고 빈 항목 줄은 숨긴다', (tester) async {
    await pumpDetail(tester, 'legacy');
    expect(find.text('Kon-peki'), findsOneWidget);
    expect(find.text('2026년 3월 1일'), findsOneWidget, reason: '기록 날짜가 없으면 생성일');
    expect(find.text('펜'), findsNothing);
    expect(find.text('아카이브에서 보기'), findsNothing);
  });

  testWidgets('없는 기록이면 삭제됐다고 안내', (tester) async {
    await pumpDetail(tester, 'gone');
    expect(find.text('삭제된 기록이에요'), findsOneWidget);
  });
}
