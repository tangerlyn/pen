import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/ink_model.dart';
import '../../../data/models/pen_model.dart';
import '../../../shared/providers/providers.dart';

const _kColorFamilyOrder = [
  '레드', '오렌지', '옐로우', '그린', '시안', '블루', '퍼플', '핑크', '무채색',
];

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

// 색상 계열별 인기 잉크 (색상 있고 리뷰 있는 잉크를 계열별로 묶어 Top1 선정)
final homeColorFamilyRankingProvider = FutureProvider<List<(String, InkModel)>>((ref) async {
  final inks = await ref.read(archiveRepoProvider).getInks();
  final withColor = inks.where((ink) => ink.hexColor.isNotEmpty).toList();
  final byFamily = <String, List<InkModel>>{};
  for (final ink in withColor) {
    (byFamily[ink.autoColorFamily] ??= []).add(ink);
  }
  final result = <(String, InkModel)>[];
  for (final family in _kColorFamilyOrder) {
    final list = byFamily[family];
    if (list == null || list.isEmpty) continue;
    list.sort((a, b) {
      final cmp = b.reviewCount.compareTo(a.reviewCount);
      return cmp != 0 ? cmp : b.avgRating.compareTo(a.avgRating);
    });
    result.add((family, list.first));
  }
  return result;
});
