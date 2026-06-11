import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ink_book_model.dart';
import '../../data/models/ink_chart_model.dart';
import '../../data/repositories/ink_book_repository.dart';

final inkBookRepoProvider = Provider<InkBookRepository>((ref) => InkBookRepository());

final inkBookListProvider = StreamProvider.family<List<InkBookModel>, String>((ref, uid) {
  return ref.watch(inkBookRepoProvider).watchBooks(uid);
});

final inkChartInBookProvider =
    StreamProvider.family<List<InkChartModel>, (String, String)>((ref, args) {
  final (uid, bookId) = args;
  return ref.watch(inkBookRepoProvider).watchChart(uid, bookId);
});
