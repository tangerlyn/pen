import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/review_model.dart';
import '../../../shared/providers/providers.dart';
import 'home_discovery_provider.dart';

class FeedFilter {
  const FeedFilter({
    this.category = '전체',
    this.colorFamily,
    this.inkType,
    this.brand,
    this.nibSize,
  });

  final String category;
  final String? colorFamily;
  final String? inkType;
  final String? brand;
  final String? nibSize;

  FeedFilter copyWith({
    String? category,
    String? colorFamily,
    String? inkType,
    String? brand,
    String? nibSize,
    bool clearSub = false,
  }) {
    return FeedFilter(
      category: category ?? this.category,
      colorFamily: clearSub ? null : (colorFamily ?? this.colorFamily),
      inkType: clearSub ? null : (inkType ?? this.inkType),
      brand: clearSub ? null : (brand ?? this.brand),
      nibSize: clearSub ? null : (nibSize ?? this.nibSize),
    );
  }
}

class FeedState {
  const FeedState({
    this.followingRecent = const [],
    this.reviews = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.hasError = false,
    this.filter = const FeedFilter(),
  });

  /// 팔로잉한 유저가 최근 24시간 내에 올린 리뷰 — 피드 상단에 고정 노출, 페이지네이션 없음
  final List<ReviewModel> followingRecent;
  final List<ReviewModel> reviews;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// 마지막 로드가 실패했는지 — 목록이 비어 있을 때 "다시 시도" 화면을 띄우는 데 쓴다.
  final bool hasError;
  final FeedFilter filter;

  FeedState copyWith({
    List<ReviewModel>? followingRecent,
    List<ReviewModel>? reviews,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? hasError,
    FeedFilter? filter,
  }) {
    return FeedState(
      followingRecent: followingRecent ?? this.followingRecent,
      reviews: reviews ?? this.reviews,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      hasError: hasError ?? this.hasError,
      filter: filter ?? this.filter,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier(this._ref) : super(const FeedState()) {
    loadFeed(refresh: true);
  }

  final Ref _ref;
  Object? _lastDoc;

  /// refresh/필터 변경마다 증가 — 이전 세대의 늦게 도착한 응답(loadMore 포함)은 버린다.
  int _generation = 0;

  Future<List<ReviewModel>> _loadFollowingRecent(String? uid) async {
    if (uid == null) return [];
    final followingUids = await _ref.read(userRepoProvider).getFollowingUids(uid);
    if (followingUids.isEmpty) return [];

    final (reviews, _) = await _ref
        .read(reviewRepoProvider)
        .getFollowingFeed(followingUids: followingUids, limit: 30);

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final recent = reviews.where((r) => r.createdAt.isAfter(cutoff)).toList();
    return _ref
        .read(userRepoProvider)
        .filterByBlocked(uid, recent, (r) => r.authorId);
  }

  Future<void> loadFeed({bool refresh = false}) async {
    if (refresh) {
      _generation++;
      _lastDoc = null;
      state = state.copyWith(
        isLoading: true,
        isLoadingMore: false,
        reviews: [],
        hasMore: true,
        hasError: false,
      );
    }
    final generation = _generation;

    final repo = _ref.read(reviewRepoProvider);
    final uid = _ref.read(currentUidProvider);

    try {
      final followingRecent =
          refresh ? await _loadFollowingRecent(uid) : state.followingRecent;

      final category = state.filter.category;
      final (fetched, lastDoc) = await repo.getFeed(
        filterCategory: category == '전체' ? null : category,
        lastDoc: _lastDoc,
      );
      if (!mounted || generation != _generation) return;
      _lastDoc = lastDoc;

      // 상단 "팔로잉 최근" 섹션에 이미 나온 리뷰는 일반 피드에서 중복 제거
      final recentIds = followingRecent.map((r) => r.id).toSet();
      final deduped = fetched.where((r) => !recentIds.contains(r.id)).toList();

      final filtered = await _ref
          .read(userRepoProvider)
          .filterByBlocked(uid, deduped, (r) => r.authorId);

      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        followingRecent: followingRecent,
        reviews: refresh ? filtered : [...state.reviews, ...filtered],
        isLoading: false,
        isLoadingMore: false,
        hasMore: fetched.length >= 20,
        hasError: false,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        hasError: true,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    await loadFeed();
  }

  void setFilter(FeedFilter filter) {
    state = state.copyWith(filter: filter);
    loadFeed(refresh: true);
  }

  Future<void> toggleLike(String reviewId, bool isLiked) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(reviewRepoProvider).toggleLike(reviewId, uid, isLiked);
    if (!mounted) return;

    ReviewModel apply(ReviewModel r) {
      if (r.id != reviewId) return r;
      return r.copyWith(
        isLiked: !isLiked,
        likeCount: isLiked ? r.likeCount - 1 : r.likeCount + 1,
      );
    }

    state = state.copyWith(
      followingRecent: state.followingRecent.map(apply).toList(),
      reviews: state.reviews.map(apply).toList(),
    );
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref);
});

/// 리뷰 작성·수정·삭제·차단 후 피드와 홈 최신 리뷰를 새로 불러오게 한다.
void invalidateReviewLists(WidgetRef ref) {
  ref.invalidate(feedProvider);
  ref.invalidate(homeLatestReviewsProvider);
}
