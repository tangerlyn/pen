import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/ink_book_model.dart';
import '../../../data/models/ink_chart_model.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/providers/providers.dart';

/// 기록 홈의 한 칸 — 스와치와 그 스와치가 들어 있는 공책
class InkRecord {
  const InkRecord({required this.book, required this.entry});
  final InkBookModel book;
  final InkChartModel entry;
}

/// 공책별 스와치를 하나로 합쳐 기록 날짜 최신순으로. 날짜가 같으면 늦게 만든 것이 먼저.
List<InkRecord> mergeRecords(
  List<InkBookModel> books,
  Map<String, List<InkChartModel>> entriesByBook,
) {
  final records = [
    for (final b in books)
      for (final e in entriesByBook[b.id] ?? const <InkChartModel>[])
        InkRecord(book: b, entry: e),
  ];
  records.sort((a, b) {
    final d = b.entry.recordDate.compareTo(a.entry.recordDate);
    return d != 0 ? d : b.entry.createdAt.compareTo(a.entry.createdAt);
  });
  return records;
}

/// 내 모든 공책의 스와치. 마이페이지 잉크 차트와 같은 Provider(inkBookListProvider,
/// inkChartInBookProvider)를 구독하므로 데이터·캐시를 그대로 공유한다.
/// (스와치 문서에 소유자 필드가 없어 collectionGroup 대신 공책별로 모은다)
final myInkRecordsProvider = Provider.autoDispose<AsyncValue<List<InkRecord>>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const AsyncData([]);

  final booksAsync = ref.watch(inkBookListProvider(uid));
  final books = booksAsync.valueOrNull;
  if (books == null) {
    return booksAsync.hasError
        ? AsyncError(booksAsync.error!, booksAsync.stackTrace ?? StackTrace.current)
        : const AsyncLoading();
  }

  final entriesByBook = <String, List<InkChartModel>>{};
  for (final b in books) {
    final chartAsync = ref.watch(inkChartInBookProvider((uid, b.id)));
    final entries = chartAsync.valueOrNull;
    if (entries == null) {
      if (chartAsync.hasError) {
        return AsyncError(chartAsync.error!, chartAsync.stackTrace ?? StackTrace.current);
      }
      return const AsyncLoading();
    }
    entriesByBook[b.id] = entries;
  }
  return AsyncData(mergeRecords(books, entriesByBook));
});

enum RecordViewMode { grid, timeline }

const _kViewModeKey = 'record_home_view_mode';

class RecordViewModeNotifier extends StateNotifier<RecordViewMode> {
  RecordViewModeNotifier() : super(RecordViewMode.grid) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kViewModeKey);
    if (name != null && mounted) {
      state = RecordViewMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => RecordViewMode.grid,
      );
    }
  }

  Future<void> set(RecordViewMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kViewModeKey, mode.name);
  }
}

final recordViewModeProvider =
    StateNotifierProvider<RecordViewModeNotifier, RecordViewMode>(
  (ref) => RecordViewModeNotifier(),
);
