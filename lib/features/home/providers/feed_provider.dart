import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/review_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';

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
    this.filter = const FeedFilter(),
  });

  /// 팔로잉한 유저가 최근 24시간 내에 올린 리뷰 — 피드 상단에 고정 노출, 페이지네이션 없음
  final List<ReviewModel> followingRecent;
  final List<ReviewModel> reviews;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final FeedFilter filter;

  FeedState copyWith({
    List<ReviewModel>? followingRecent,
    List<ReviewModel>? reviews,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    FeedFilter? filter,
  }) {
    return FeedState(
      followingRecent: followingRecent ?? this.followingRecent,
      reviews: reviews ?? this.reviews,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      filter: filter ?? this.filter,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier(this._ref) : super(const FeedState()) {
    // Firebase Auth 세션 복원 전에 쿼리가 나가면 permission-denied가 나므로,
    // 로그인 상태가 확정된 뒤에 최초 로드를 실행한다.
    if (_ref.read(authUserProvider).value != null) {
      loadFeed(refresh: true);
    } else {
      late final ProviderSubscription<AsyncValue<String?>> sub;
      sub = _ref.listen(authUserProvider, (_, next) {
        if (next.isLoading) return;
        sub.close();
        loadFeed(refresh: true);
      });
    }
  }

  final Ref _ref;
  Object? _lastDoc;

  Future<List<ReviewModel>> _loadFollowingRecent(String? uid) async {
    if (uid == null) return [];
    final followingUids = await _ref.read(userRepoProvider).getFollowingUids(uid);
    if (followingUids.isEmpty) return [];

    final (reviews, _) = await _ref
        .read(reviewRepoProvider)
        .getFollowingFeed(followingUids: followingUids, limit: 30);

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return reviews.where((r) => r.createdAt.isAfter(cutoff)).toList();
  }

  Future<void> loadFeed({bool refresh = false}) async {
    if (refresh) {
      _lastDoc = null;
      state = state.copyWith(isLoading: true, reviews: [], hasMore: true);
    }

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
      _lastDoc = lastDoc;

      // 상단 "팔로잉 최근" 섹션에 이미 나온 리뷰는 일반 피드에서 중복 제거
      final recentIds = followingRecent.map((r) => r.id).toSet();
      final deduped = fetched.where((r) => !recentIds.contains(r.id)).toList();

      final filtered = await _ref
          .read(userRepoProvider)
          .filterByBlocked(uid, deduped, (r) => r.authorId);

      state = state.copyWith(
        followingRecent: followingRecent,
        reviews: refresh ? filtered : [...state.reviews, ...filtered],
        isLoading: false,
        isLoadingMore: false,
        hasMore: fetched.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, isLoadingMore: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
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

  Future<void> toggleScrap(String reviewId, bool isScrapped) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(reviewRepoProvider).toggleScrap(reviewId, uid, isScrapped);

    ReviewModel apply(ReviewModel r) {
      if (r.id != reviewId) return r;
      return r.copyWith(
        isScrapped: !isScrapped,
        scrapCount: isScrapped ? r.scrapCount - 1 : r.scrapCount + 1,
      );
    }

    state = state.copyWith(
      followingRecent: state.followingRecent.map(apply).toList(),
      reviews: state.reviews.map(apply).toList(),
    );
    _ref.invalidate(scrappedReviewsProvider(uid));
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref);
});
