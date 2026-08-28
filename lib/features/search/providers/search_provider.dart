import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/search_utils.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/post_model.dart';
import '../../../data/repositories/search_repository.dart';

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
    final list = [
      trimmed,
      ...state.where((s) => s != trimmed),
    ].take(_maxHistory).toList();
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
      (_) => SearchHistoryNotifier(),
    );

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
    this.hasMoreReviews = false,
    this.hasMorePosts = false,
    this.isLoadingMoreReviews = false,
    this.isLoadingMorePosts = false,
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
  final bool hasMoreReviews;
  final bool hasMorePosts;
  final bool isLoadingMoreReviews;
  final bool isLoadingMorePosts;

  bool get isLoadingMore => isLoadingMoreReviews || isLoadingMorePosts;

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
    bool? hasMoreReviews,
    bool? hasMorePosts,
    bool? isLoadingMoreReviews,
    bool? isLoadingMorePosts,
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
      hasMoreReviews: hasMoreReviews ?? this.hasMoreReviews,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      isLoadingMoreReviews: isLoadingMoreReviews ?? this.isLoadingMoreReviews,
      isLoadingMorePosts: isLoadingMorePosts ?? this.isLoadingMorePosts,
    );
  }
}

// ── 검색 Notifier ─────────────────────────────────────────────────────
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._type, this._repository) : super(const SearchState());

  final String _type;
  final SearchRepository _repository;

  static const _limit = 50;
  String _query = '';
  List<String> _tokens = const [];
  String? _reviewCursor;
  String? _postCursor;
  int _generation = 0;

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    final generation = ++_generation;
    _query = q;
    _tokens = SearchUtils.queryTokens(q);
    _reviewCursor = null;
    _postCursor = null;

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
      hasMoreReviews: _includesReviews,
      hasMorePosts: _includesPosts,
      isLoadingMoreReviews: false,
      isLoadingMorePosts: false,
    );

    try {
      if (_tokens.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      await Future.wait([
        if (_includesReviews) _fetchReviewPage(generation),
        if (_includesPosts) _fetchPostPage(generation),
      ]);
      if (generation == _generation) {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      if (generation == _generation) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> loadMore() {
    return _type == 'community' ? loadMorePosts() : loadMoreReviews();
  }

  Future<void> loadMoreReviews() async {
    if (!_includesReviews ||
        !state.hasMoreReviews ||
        state.isLoadingMoreReviews ||
        state.isLoading) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingMoreReviews: true, error: null);
    try {
      await _fetchReviewPage(generation);
    } catch (e) {
      if (generation == _generation) {
        state = state.copyWith(error: e.toString());
      }
    } finally {
      if (generation == _generation) {
        state = state.copyWith(isLoadingMoreReviews: false);
      }
    }
  }

  Future<void> loadMorePosts() async {
    if (!_includesPosts ||
        !state.hasMorePosts ||
        state.isLoadingMorePosts ||
        state.isLoading) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingMorePosts: true, error: null);
    try {
      await _fetchPostPage(generation);
    } catch (e) {
      if (generation == _generation) {
        state = state.copyWith(error: e.toString());
      }
    } finally {
      if (generation == _generation) {
        state = state.copyWith(isLoadingMorePosts: false);
      }
    }
  }

  Future<void> _fetchReviewPage(int generation) async {
    var hasMore = true;
    final matches = <ReviewModel>[];
    do {
      final page = await _repository.fetchReviews(
        tokens: _tokens,
        cursor: _reviewCursor,
        limit: _limit,
      );
      if (generation != _generation) return;
      _reviewCursor = page.nextCursor;
      hasMore = page.hasMore;
      matches.addAll(
        page.items.where(
          (review) => SearchUtils.matchesQuery(
            '${review.title} ${review.body}',
            _query,
          ),
        ),
      );
    } while (matches.isEmpty && hasMore);

    final rawReviews = _mergeById(
      state.rawReviews,
      matches,
      (review) => review.id,
    );
    state = state.copyWith(
      rawReviews: rawReviews,
      reviews: _sortReviews(rawReviews, state.reviewSort),
      hasMoreReviews: hasMore,
    );
  }

  Future<void> _fetchPostPage(int generation) async {
    var hasMore = true;
    final matches = <PostModel>[];
    do {
      final page = await _repository.fetchPosts(
        tokens: _tokens,
        cursor: _postCursor,
        limit: _limit,
      );
      if (generation != _generation) return;
      _postCursor = page.nextCursor;
      hasMore = page.hasMore;
      matches.addAll(
        page.items.where(
          (post) =>
              SearchUtils.matchesQuery('${post.title} ${post.body}', _query),
        ),
      );
    } while (matches.isEmpty && hasMore);

    final rawPosts = _mergeById(state.rawPosts, matches, (post) => post.id);
    state = state.copyWith(
      rawPosts: rawPosts,
      posts: _sortPosts(rawPosts, state.postSort),
      hasMorePosts: hasMore,
    );
  }

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
    _generation += 1;
    _query = '';
    _tokens = const [];
    _reviewCursor = null;
    _postCursor = null;
    state = const SearchState();
  }

  bool get _includesReviews => _type == 'review' || _type == 'all';
  bool get _includesPosts => _type == 'community' || _type == 'all';

  // ── 정렬 ──────────────────────────────────────────────────────────

  List<ReviewModel> _sortReviews(
    List<ReviewModel> list,
    ReviewSortOption sort,
  ) {
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

List<T> _mergeById<T>(
  List<T> current,
  List<T> additions,
  String Function(T item) idOf,
) {
  final merged = <String, T>{for (final item in current) idOf(item): item};
  for (final item in additions) {
    merged[idOf(item)] = item;
  }
  return merged.values.toList(growable: false);
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (_) => FirestoreSearchRepository(),
);

final searchProvider =
    StateNotifierProvider.family<SearchNotifier, SearchState, String>(
      (ref, type) => SearchNotifier(type, ref.watch(searchRepositoryProvider)),
    );
