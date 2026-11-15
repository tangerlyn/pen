import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/banner_model.dart';
import '../../../data/models/review_model.dart';
import '../../../data/repositories/banner_repository.dart';
import '../../../data/models/ink_model.dart';
import '../../../data/models/pen_model.dart';
import '../../../shared/providers/providers.dart';

final homeLatestReviewsProvider = FutureProvider<List<ReviewModel>>((ref) async {
  final (reviews, _) = await ref.read(reviewRepoProvider).getFeed(limit: 6);
  return ref
      .read(userRepoProvider)
      .filterByBlocked(ref.read(currentUidProvider), reviews, (r) => r.authorId);
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


// ── 홈 상단 배너 ─────────────────────────────────────────────
final bannerRepoProvider = Provider<BannerRepository>((ref) => BannerRepository());

/// 콘솔에 등록된 노출 중 배너. 하나도 없거나 불러오지 못하면 기본 환영 배너.
final homeBannersProvider = FutureProvider<List<BannerModel>>((ref) async {
  try {
    final banners = await ref.read(bannerRepoProvider).getActiveBanners();
    if (banners.isNotEmpty) return banners;
  } catch (_) {
    // 배너는 부가 요소라 실패해도 홈은 그대로 — 기본 배너로 대체한다.
  }
  return const [BannerModel.welcome];
});
