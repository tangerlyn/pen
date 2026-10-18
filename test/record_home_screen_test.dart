import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nibpen/data/models/ink_chart_model.dart';
import 'package:nibpen/features/home/providers/notification_provider.dart';
import 'package:nibpen/features/record/screens/record_home_screen.dart';
import 'package:nibpen/shared/providers/ink_book_providers.dart';
import 'package:nibpen/shared/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/record_fakes.dart';

void main() {
  late String? pushedLocation;

  Future<void> pumpHome(WidgetTester tester, FakeInkBookRepository repo) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Widget stub(GoRouterState state) {
      pushedLocation = state.uri.toString();
      return Scaffold(body: Text('stub ${state.uri}'));
    }

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const RecordHomeScreen()),
      GoRoute(path: '/record/new', builder: (_, s) => stub(s)),
      GoRoute(path: '/record/:bookId/:entryId', builder: (_, s) => stub(s)),
      GoRoute(path: '/archive', builder: (_, s) => stub(s)),
      GoRoute(path: '/discover', builder: (_, s) => stub(s)),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        inkBookRepoProvider.overrideWithValue(repo),
        unreadNotificationCountProvider.overrideWithValue(0),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pushedLocation = null;
  });

  testWidgets('기록이 없으면 첫 기록 안내와 두 버튼이 보이고, 기록 버튼은 empty_state로 진입', (tester) async {
    await pumpHome(tester, FakeInkBookRepository());

    expect(find.text('첫 스와치를 기록해보세요'), findsOneWidget);
    expect(find.text('아카이브 둘러보기'), findsOneWidget);
    expect(find.text('스와치 기록하기'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('스와치 기록하기'));
    await tester.pumpAndSettle();
    expect(pushedLocation, '/record/new?entry=empty_state');
  });

  testWidgets('아카이브 둘러보기는 아카이브 탭으로 이동', (tester) async {
    await pumpHome(tester, FakeInkBookRepository());
    await tester.tap(find.text('아카이브 둘러보기'));
    await tester.pumpAndSettle();
    expect(pushedLocation, '/archive');
  });

  testWidgets('기존 잉크 차트 기록이 그리드로 보이고, 타임라인으로 바꾸면 월별로 묶인다', (tester) async {
    await pumpHome(
      tester,
      FakeInkBookRepository(
        books: [book('b1', name: '파랑 공책')],
        charts: {
          'b1': [
            chartEntry('c1', inkName: 'Kon-peki', createdAt: DateTime(2026, 9, 3)),
            InkChartModel(
              id: 'c2',
              photoUrl: '',
              brand: '',
              inkName: '이름만 기록',
              createdAt: DateTime(2026, 10, 18),
              penName: 'Custom 74',
            ),
          ],
        },
      ),
    );

    expect(find.text('스와치 2개 · 잉크 2종'), findsOneWidget);
    expect(find.text('Kon-peki'), findsOneWidget);
    expect(find.text('이름만 기록'), findsOneWidget);
    expect(find.text('첫 스와치를 기록해보세요'), findsNothing);
    expect(find.text('스와치 기록'), findsOneWidget, reason: 'FAB');

    await tester.tap(find.byTooltip('타임라인으로 보기'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);
    expect(find.text('2026년 9월'), findsOneWidget);
    expect(find.text('Custom 74'), findsOneWidget);
    expect(find.text('Pilot Kon-peki'), findsOneWidget);

    await tester.tap(find.text('Pilot Kon-peki'));
    await tester.pumpAndSettle();
    expect(pushedLocation, '/record/b1/c1');
  });

  testWidgets('FAB는 entry=home으로 기록 화면을 연다', (tester) async {
    await pumpHome(
      tester,
      FakeInkBookRepository(books: [book('b1')], charts: {'b1': [chartEntry('c1')]}),
    );
    await tester.tap(find.text('스와치 기록'));
    await tester.pumpAndSettle();
    expect(pushedLocation, '/record/new?entry=home');
  });
}
