import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/features/record/providers/my_records_provider.dart';
import 'package:nibpen/shared/providers/ink_book_providers.dart';
import 'package:nibpen/shared/providers/providers.dart';
import 'helpers/record_fakes.dart';

void main() {
  test('여러 공책의 스와치를 합쳐 기록 날짜 최신순, 같은 날이면 늦게 만든 것이 먼저', () {
    final records = mergeRecords(
      [book('b1'), book('b2')],
      {
        'b1': [
          chartEntry('old', createdAt: DateTime(2025, 12, 1)),
          // 예전에 칠한 스와치를 오늘 기록: 기록 날짜(2월)로 정렬
          chartEntry('backdated', createdAt: DateTime(2026, 10, 1), recordedAt: DateTime(2026, 2, 1)),
        ],
        'b2': [
          chartEntry('new', createdAt: DateTime(2026, 3, 1, 9)),
          chartEntry('newer', createdAt: DateTime(2026, 3, 1, 10)),
        ],
        'missing-book': [chartEntry('orphan')],
      },
    );
    expect(records.map((r) => r.entry.id), ['newer', 'new', 'backdated', 'old']);
    expect(records.first.book.id, 'b2');
  });

  test('기존 잉크 차트 데이터(새 필드 없음)가 기록 홈 목록에 그대로 나온다', () async {
    final repo = FakeInkBookRepository(
      books: [book('b1', name: '파랑 공책'), book('b2', name: '빨강 공책')],
      charts: {
        'b1': [chartEntry('c1', inkName: 'Kon-peki')],
        'b2': [chartEntry('c2', brand: 'Diamine', inkName: 'Oxblood', createdAt: DateTime(2026, 5, 1))],
      },
    );
    final container = ProviderContainer(overrides: [
      currentUidProvider.overrideWithValue('alice'),
      inkBookRepoProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(myInkRecordsProvider, (_, _) {});

    expect(container.read(myInkRecordsProvider), isA<AsyncLoading<List<InkRecord>>>());
    await pumpEventQueue();

    final records = container.read(myInkRecordsProvider).requireValue;
    expect(records.map((r) => (r.book.name, r.entry.inkName)), [
      ('빨강 공책', 'Oxblood'),
      ('파랑 공책', 'Kon-peki'),
    ]);
  });

  test('공책이 없거나 비어 있으면 빈 목록 (빈 화면 안내 조건)', () async {
    final container = ProviderContainer(overrides: [
      currentUidProvider.overrideWithValue('alice'),
      inkBookRepoProvider.overrideWithValue(
        FakeInkBookRepository(books: [book('b1')], charts: {'b1': []}),
      ),
    ]);
    addTearDown(container.dispose);
    container.listen(myInkRecordsProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(myInkRecordsProvider).requireValue, isEmpty);
  });
}
