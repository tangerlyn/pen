import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nibpen/data/models/ink_model.dart';
import 'package:nibpen/features/archive/widgets/ink_record_actions.dart';
import 'package:nibpen/shared/providers/owned_ink_providers.dart';
import 'package:nibpen/shared/providers/providers.dart';
import 'helpers/record_fakes.dart';

void main() {
  const ink = InkModel(id: 'ink1', brand: 'Pilot', name: 'Kon-peki', hexColor: '#1E88E5');
  late FakeOwnedInkRepository owned;
  late Uri? recordUri;

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: InkRecordActions(ink: ink)),
        ),
      ),
      GoRoute(
        path: '/record/new',
        builder: (_, state) {
          recordUri = state.uri;
          return const Scaffold(body: Text('record screen'));
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        ownedInkRepoProvider.overrideWithValue(owned),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    owned = FakeOwnedInkRepository();
    recordUri = null;
  });

  testWidgets('내 컬렉션 추가 → 상태가 바뀌고 다시 누르면 뺀다', (tester) async {
    await pump(tester);
    expect(find.text('내 컬렉션에 추가'), findsOneWidget);

    await tester.tap(find.text('내 컬렉션에 추가'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(owned.owned['ink1']?.name, 'Kon-peki');
    expect(find.text('내 컬렉션에 있음'), findsOneWidget);

    await tester.tap(find.text('내 컬렉션에 있음'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(owned.owned, isEmpty);
    expect(find.text('내 컬렉션에 추가'), findsOneWidget);
  });

  testWidgets('스와치 기록하기 → 잉크 ID와 진입 경로를 넘겨 기록 화면으로', (tester) async {
    await pump(tester);
    await tester.tap(find.text('스와치 기록하기'));
    await tester.pumpAndSettle();

    expect(find.text('record screen'), findsOneWidget);
    expect(recordUri!.queryParameters, {'inkId': 'ink1', 'entry': 'ink_detail'});
  });
}
