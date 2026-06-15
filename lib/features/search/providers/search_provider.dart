import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/search_utils.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/post_model.dart';

// ── 정렬 옵션 ─────────────────────────────────────────────────────────
enum ReviewSortOption {
  newest('최신순'),
  popular('인기순'),
  rating('평점순');

  const ReviewSortOption(this.label);
  final String label;
}

enum PostSortOption {
  newest('최신순'),
  popular('인기순');

  const PostSortOption(this.label);
  final String label;
}

// ── 최근 검색어 ──────────────────────────────────────────────────────
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  static const _prefKey = 'search_history';
  static const _maxHistory = 20;

  SearchHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefKey) ?? [];
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final list = [trimmed, ...state.where((s) => s != trimmed)]
        .take(_maxHistory)
        .toList();
    state = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, list);
  }

  Future<void> remove(String query) async {
    final list = state.where((s) => s != query).toList();
    state = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, list);
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>(
        (_) => SearchHistoryNotifier());

// ── 검색 상태 ─────────────────────────────────────────────────────────
class SearchState {
  const SearchState({
    this.isLoading = false,
    this.reviews = const [],
    this.posts = const [],
    this.rawReviews = const [],
    this.rawPosts = const [],
    this.hasSearched = false,
    this.error,
    this.reviewSort = ReviewSortOption.newest,
    this.postSort = PostSortOption.newest,
  });

  final bool isLoading;
  final List<ReviewModel> reviews;
  final List<PostModel> posts;
  final List<ReviewModel> rawReviews;
  final List<PostModel> rawPosts;
  final bool hasSearched;
  final String? error;
  final ReviewSortOption reviewSort;
  final PostSortOption postSort;

  // UI compat shims — always false (pagination not needed with indexed search)
  bool get hasMoreReviews => false;
  bool get hasMorePosts => false;
  bool get isLoadingMore => false;

  static const _sentinel = Object();

  SearchState copyWith({
    bool? isLoading,
    List<ReviewModel>? reviews,
    List<PostModel>? posts,
    List<ReviewModel>? rawReviews,
    List<PostModel>? rawPosts,
    bool? hasSearched,
    Object? error = _sentinel,
    ReviewSortOption? reviewSort,
    PostSortOption? postSort,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      reviews: reviews ?? this.reviews,
      posts: posts ?? this.posts,
      rawReviews: rawReviews ?? this.rawReviews,
      rawPosts: rawPosts ?? this.rawPosts,
      hasSearched: hasSearched ?? this.hasSearched,
      error: identical(error, _sentinel) ? this.error : error as String?,
      reviewSort: reviewSort ?? this.reviewSort,
      postSort: postSort ?? this.postSort,
    );
  }
}

// ── 검색 Notifier ─────────────────────────────────────────────────────
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._type) : super(const SearchState());

  final String _type;
  final _db = FirebaseFirestore.instance;

  static const _limit = 50;

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    state = state.copyWith(
      isLoading: true,
      hasSearched: true,
      error: null,
      reviews: [],
      rawReviews: [],
      posts: [],
      rawPosts: [],
      reviewSort: ReviewSortOption.newest,
      postSort: PostSortOption.newest,
    );

    try {
      final tokens = SearchUtils.queryTokens(q);
      if (tokens.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final reviews = <ReviewModel>[];
      final posts = <PostModel>[];

      if (_type == 'review' || _type == 'all') {
        final snap = await _db
            .collection('reviews')
            .where('searchIndex', arrayContainsAny: tokens)
            .limit(_limit)
            .get();
        final candidates = snap.docs
            .map((d) => ReviewModel.fromMap(d.data(), d.id))
            .where((r) => SearchUtils.matchesQuery('${r.title} ${r.body}', q))
            .toList();
        reviews.addAll(candidates);
      }

      if (_type == 'community' || _type == 'all') {
        final snap = await _db
            .collection('posts')
            .where('searchIndex', arrayContainsAny: tokens)
            .limit(_limit)
            .get();
        final candidates = snap.docs
            .map((d) => PostModel.fromMap(d.data(), d.id))
            .where((p) => SearchUtils.matchesQuery('${p.title} ${p.body}', q))
            .toList();
        posts.addAll(candidates);
      }

      final sortedReviews = _sortReviews(reviews, ReviewSortOption.newest);
      final sortedPosts = _sortPosts(posts, PostSortOption.newest);

      state = state.copyWith(
        isLoading: false,
        reviews: sortedReviews,
        rawReviews: sortedReviews,
        posts: sortedPosts,
        rawPosts: sortedPosts,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // No-op: pagination not needed with indexed full-text search
  void loadMore() {}

  void setReviewSort(ReviewSortOption sort) {
    state = state.copyWith(
      reviews: _sortReviews(state.rawReviews, sort),
      reviewSort: sort,
    );
  }

  void setPostSort(PostSortOption sort) {
    state = state.copyWith(
      posts: _sortPosts(state.rawPosts, sort),
      postSort: sort,
    );
  }

  void reset() {
    state = const SearchState();
  }

  // ── 정렬 ──────────────────────────────────────────────────────────

  List<ReviewModel> _sortReviews(List<ReviewModel> list, ReviewSortOption sort) {
    final sorted = [...list];
    switch (sort) {
      case ReviewSortOption.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case ReviewSortOption.popular:
        sorted.sort((a, b) => b.likeCount.compareTo(a.likeCount));
      case ReviewSortOption.rating:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return sorted;
  }

  List<PostModel> _sortPosts(List<PostModel> list, PostSortOption sort) {
    final sorted = [...list];
    switch (sort) {
      case PostSortOption.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case PostSortOption.popular:
        sorted.sort((a, b) {
          final likeCmp = b.likeCount.compareTo(a.likeCount);
          if (likeCmp != 0) return likeCmp;
          final commentCmp = b.commentCount.compareTo(a.commentCount);
          if (commentCmp != 0) return commentCmp;
          return b.createdAt.compareTo(a.createdAt);
        });
    }
    return sorted;
  }
}

final searchProvider =
    StateNotifierProvider.family<SearchNotifier, SearchState, String>(
        (_, type) => SearchNotifier(type));
