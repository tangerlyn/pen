import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/review_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';

class FeedFilter {
  const FeedFilter({
    this.category = '전체',
    this.feedType = '추천',
    this.colorFamily,
    this.inkType,
    this.brand,
    this.nibSize,
  });

  final String category;
  final String feedType; // 추천 / 팔로잉
  final String? colorFamily;
  final String? inkType;
  final String? brand;
  final String? nibSize;

  FeedFilter copyWith({
    String? category,
    String? feedType,
    String? colorFamily,
    String? inkType,
    String? brand,
    String? nibSize,
    bool clearSub = false,
  }) {
    return FeedFilter(
      category: category ?? this.category,
      feedType: feedType ?? this.feedType,
      colorFamily: clearSub ? null : (colorFamily ?? this.colorFamily),
      inkType: clearSub ? null : (inkType ?? this.inkType),
      brand: clearSub ? null : (brand ?? this.brand),
      nibSize: clearSub ? null : (nibSize ?? this.nibSize),
    );
  }
}

class FeedState {
  const FeedState({
    this.reviews = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.filter = const FeedFilter(),
  });

  final List<ReviewModel> reviews;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final FeedFilter filter;

  FeedState copyWith({
    List<ReviewModel>? reviews,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    FeedFilter? filter,
  }) {
    return FeedState(
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
    loadFeed();
  }

  final Ref _ref;
  Object? _lastDoc;

  Future<void> loadFeed({bool refresh = false}) async {
    if (refresh) {
      _lastDoc = null;
      state = state.copyWith(isLoading: true, reviews: [], hasMore: true);
    }

    final repo = _ref.read(reviewRepoProvider);
    final uid = _ref.read(currentUidProvider);

    try {
      List<ReviewModel> reviews;
      Object? lastDoc;

      if (state.filter.feedType == '팔로잉') {
        if (uid == null) {
          state = state.copyWith(reviews: [], isLoading: false, isLoadingMore: false, hasMore: false);
          return;
        }
        final followingUids = await _ref.read(userRepoProvider).getFollowingUids(uid);
        if (followingUids.isEmpty) {
          state = state.copyWith(reviews: [], isLoading: false, isLoadingMore: false, hasMore: false);
          return;
        }
        (reviews, lastDoc) = await repo.getFollowingFeed(
          followingUids: followingUids,
          lastDoc: _lastDoc,
        );

        final category = state.filter.category;
        if (category != '전체') {
          reviews = reviews.where((r) {
            if (category == '잉크') return r.inkIds.isNotEmpty;
            if (category == '만년필') return r.penIds.isNotEmpty;
            return true;
          }).toList();
        }
      } else {
        final category = state.filter.category;
        (reviews, lastDoc) = await repo.getFeed(
          filterCategory: category == '전체' ? null : category,
          lastDoc: _lastDoc,
        );
      }

      _lastDoc = lastDoc;

      final filtered = await _ref
          .read(userRepoProvider)
          .filterByBlocked(uid, reviews, (r) => r.authorId);

      state = state.copyWith(
        reviews: refresh ? filtered : [...state.reviews, ...filtered],
        isLoading: false,
        isLoadingMore: false,
        hasMore: reviews.length >= 20,
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
    state = state.copyWith(
      reviews: state.reviews.map((r) {
        if (r.id == reviewId) {
          return r.copyWith(
            isLiked: !isLiked,
            likeCount: isLiked ? r.likeCount - 1 : r.likeCount + 1,
          );
        }
        return r;
      }).toList(),
    );
  }

  Future<void> toggleScrap(String reviewId, bool isScrapped) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(reviewRepoProvider).toggleScrap(reviewId, uid, isScrapped);
    state = state.copyWith(
      reviews: state.reviews.map((r) {
        if (r.id == reviewId) {
          return r.copyWith(
            isScrapped: !isScrapped,
            scrapCount: isScrapped ? r.scrapCount - 1 : r.scrapCount + 1,
          );
        }
        return r;
      }).toList(),
    );
    _ref.invalidate(scrappedReviewsProvider(uid));
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref);
});

// 팔로잉 탭에 새 리뷰가 있는지 확인
final followingHasNewProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;

  final prefs = await SharedPreferences.getInstance();
  final lastSeenMs = prefs.getInt('following_last_seen') ?? 0;
  if (lastSeenMs == 0) return false;

  final lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenMs);
  final followingUids = await ref.read(userRepoProvider).getFollowingUids(uid);

  return ref.read(reviewRepoProvider).hasNewFollowingReview(
    followingUids: followingUids,
    since: lastSeen,
  );
});
