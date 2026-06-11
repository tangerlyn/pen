import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/ink_model.dart';
import '../../../data/models/pen_model.dart';
import '../../../shared/providers/providers.dart';

final homeLatestReviewsProvider = FutureProvider<List<ReviewModel>>((ref) async {
  final (reviews, _) = await ref.read(reviewRepoProvider).getFeed(limit: 6);
  return reviews;
});

final homePopularInksProvider = FutureProvider<List<InkModel>>((ref) async {
  final (reviews, _) = await ref.read(reviewRepoProvider).getFeed(limit: 60);
  final counts = <String, int>{};
  for (final r in reviews) {
    for (final id in r.inkIds) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return [];
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topIds = sorted.take(6).map((e) => e.key).toList();
  final results = await Future.wait(
    topIds.map((id) => ref.read(archiveRepoProvider).getInk(id)),
  );
  return results.whereType<InkModel>().toList();
});

final homePopularPensProvider = FutureProvider<List<PenModel>>((ref) async {
  final (reviews, _) = await ref.read(reviewRepoProvider).getFeed(limit: 60);
  final counts = <String, int>{};
  for (final r in reviews) {
    for (final id in r.penIds) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return [];
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topIds = sorted.take(6).map((e) => e.key).toList();
  final results = await Future.wait(
    topIds.map((id) => ref.read(archiveRepoProvider).getPen(id)),
  );
  return results.whereType<PenModel>().toList();
});
