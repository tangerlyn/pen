import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/banner_model.dart';
import '../../../data/models/review_model.dart';
import '../../../data/repositories/banner_repository.dart';
import '../../../data/models/ink_model.dart';
import '../../../data/models/pen_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/recently_viewed_provider.dart';

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

// ── 이번 주 인기 리뷰 ─────────────────────────────────────────
/// 최근 7일 리뷰 중 좋아요 많은 순 6개. 좋아요가 하나도 없으면 섹션을 숨긴다
/// (최신 리뷰와 똑같은 목록이 되므로).
final homeWeeklyPopularReviewsProvider =
    FutureProvider<List<ReviewModel>>((ref) async {
  final since = DateTime.now().subtract(const Duration(days: 7));
  final reviews = await ref.read(reviewRepoProvider).getPopularSince(since);
  final visible = await ref
      .read(userRepoProvider)
      .filterByBlocked(ref.read(currentUidProvider), reviews, (r) => r.authorId);
  final liked = visible.where((r) => r.likeCount > 0).take(6).toList();
  return liked;
});

// ── 최근 본 잉크·만년필 ──────────────────────────────────────
/// 기기에 저장된 "최근 본" 기록을 실제 제품 정보로 바꾼다.
/// 결과는 [InkModel] 또는 [PenModel]. 삭제된 제품은 기록에서도 지운다.
final homeRecentProductsProvider = FutureProvider<List<Object>>((ref) async {
  final recent = ref.watch(recentlyViewedProvider);
  if (recent.isEmpty) return const [];
  final repo = ref.read(archiveRepoProvider);
  final missing = <String>{};
  final results = await Future.wait(recent.map((p) async {
    try {
      final Object? item = p.type == 'ink'
          ? await repo.getInkBasic(p.id)
          : await repo.getPenBasic(p.id);
      if (item == null) missing.add('${p.type}:${p.id}');
      return item;
    } catch (_) {
      return null; // 일시적 오류는 기록을 지우지 않고 이번만 건너뛴다.
    }
  }));
  if (missing.isNotEmpty) {
    Future.microtask(
      () => ref.read(recentlyViewedProvider.notifier).removeMissing(missing),
    );
  }
  return results.whereType<Object>().toList();
});
