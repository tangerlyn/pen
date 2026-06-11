import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/post_model.dart';

// Firestore 접두어 검색: q ~ q+ 범위로 시작하는 문서 검색
String _searchEnd(String q) => q + String.fromCharCode(0xF8FF);

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
    this.hasMoreReviews = false,
    this.hasMorePosts = false,
    this.isLoadingMore = false,
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
  final bool isLoadingMore;

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
    bool? isLoadingMore,
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
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

// ── 검색 Notifier ─────────────────────────────────────────────────────
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._type) : super(const SearchState());

  final String _type;
  final _db = FirebaseFirestore.instance;

  static const _pageSize = 20;

  String _currentQuery = '';
  DocumentSnapshot? _lastReviewDoc;
  DocumentSnapshot? _lastPostTitleDoc;
  DocumentSnapshot? _lastPostBodyDoc;
  final _seenPostIds = <String>{};

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    _currentQuery = q;
    _lastReviewDoc = null;
    _lastPostTitleDoc = null;
    _lastPostBodyDoc = null;
    _seenPostIds.clear();

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
      hasMoreReviews: false,
      hasMorePosts: false,
      isLoadingMore: false,
    );

    try {
      final reviews = <ReviewModel>[];
      final posts = <PostModel>[];

      if (_type == 'review' || _type == 'all') {
        final snap = await _reviewQuery(q, null);
        reviews.addAll(snap.docs.map((d) => ReviewModel.fromMap(d.data(), d.id)));
        _lastReviewDoc = snap.docs.length >= _pageSize ? snap.docs.last : null;
      }

      if (_type == 'community' || _type == 'all') {
        await _fetchPosts(q, posts);
      }

      final rawReviews = reviews..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final rawPosts = posts..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        isLoading: false,
        reviews: rawReviews,
        rawReviews: rawReviews,
        posts: rawPosts,
        rawPosts: rawPosts,
        hasMoreReviews: _lastReviewDoc != null,
        hasMorePosts: _lastPostTitleDoc != null || _lastPostBodyDoc != null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading) return;
    final canMoreReviews = (_type == 'review' || _type == 'all') && state.hasMoreReviews;
    final canMorePosts = (_type == 'community' || _type == 'all') && state.hasMorePosts;
    if (!canMoreReviews && !canMorePosts) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final newReviews = <ReviewModel>[];
      final newPosts = <PostModel>[];

      if (canMoreReviews) {
        final snap = await _reviewQuery(_currentQuery, _lastReviewDoc);
        newReviews.addAll(snap.docs.map((d) => ReviewModel.fromMap(d.data(), d.id)));
        _lastReviewDoc = snap.docs.length >= _pageSize ? snap.docs.last : null;
      }

      if (canMorePosts) {
        await _fetchPostsMore(_currentQuery, newPosts);
      }

      final allRawReviews = [...state.rawReviews, ...newReviews];
      final allRawPosts = [...state.rawPosts, ...newPosts];

      state = state.copyWith(
        isLoadingMore: false,
        rawReviews: allRawReviews,
        reviews: _sortReviews(allRawReviews, state.reviewSort),
        rawPosts: allRawPosts,
        posts: _sortPosts(allRawPosts, state.postSort),
        hasMoreReviews: _lastReviewDoc != null,
        hasMorePosts: _lastPostTitleDoc != null || _lastPostBodyDoc != null,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
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
    _currentQuery = '';
    _lastReviewDoc = null;
    _lastPostTitleDoc = null;
    _lastPostBodyDoc = null;
    _seenPostIds.clear();
    state = const SearchState();
  }

  // ── 내부 쿼리 헬퍼 ─────────────────────────────────────────────────

  Future<QuerySnapshot<Map<String, dynamic>>> _reviewQuery(
      String q, DocumentSnapshot? lastDoc) {
    var query = _db
        .collection('reviews')
        .where('body', isGreaterThanOrEqualTo: q)
        .where('body', isLessThanOrEqualTo: _searchEnd(q))
        .orderBy('body')
        .limit(_pageSize);
    if (lastDoc != null) query = query.startAfterDocument(lastDoc);
    return query.get();
  }

  // 첫 페이지 — 양쪽 서브쿼리 실행
  Future<void> _fetchPosts(String q, List<PostModel> out) async {
    final end = _searchEnd(q);

    final titleSnap = await _db
        .collection('posts')
        .where('title', isGreaterThanOrEqualTo: q)
        .where('title', isLessThanOrEqualTo: end)
        .orderBy('title')
        .limit(_pageSize)
        .get();

    final bodySnap = await _db
        .collection('posts')
        .where('body', isGreaterThanOrEqualTo: q)
        .where('body', isLessThanOrEqualTo: end)
        .orderBy('body')
        .limit(_pageSize)
        .get();

    _lastPostTitleDoc = titleSnap.docs.length >= _pageSize ? titleSnap.docs.last : null;
    _lastPostBodyDoc = bodySnap.docs.length >= _pageSize ? bodySnap.docs.last : null;

    for (final doc in [...titleSnap.docs, ...bodySnap.docs]) {
      if (_seenPostIds.add(doc.id)) {
        out.add(PostModel.fromMap(doc.data(), doc.id));
      }
    }
  }

  // 추가 페이지 — 소진되지 않은 서브쿼리만 실행
  Future<void> _fetchPostsMore(String q, List<PostModel> out) async {
    final end = _searchEnd(q);

    if (_lastPostTitleDoc != null) {
      final snap = await _db
          .collection('posts')
          .where('title', isGreaterThanOrEqualTo: q)
          .where('title', isLessThanOrEqualTo: end)
          .orderBy('title')
          .limit(_pageSize)
          .startAfterDocument(_lastPostTitleDoc!)
          .get();
      _lastPostTitleDoc = snap.docs.length >= _pageSize ? snap.docs.last : null;
      for (final doc in snap.docs) {
        if (_seenPostIds.add(doc.id)) {
          out.add(PostModel.fromMap(doc.data(), doc.id));
        }
      }
    }

    if (_lastPostBodyDoc != null) {
      final snap = await _db
          .collection('posts')
          .where('body', isGreaterThanOrEqualTo: q)
          .where('body', isLessThanOrEqualTo: end)
          .orderBy('body')
          .limit(_pageSize)
          .startAfterDocument(_lastPostBodyDoc!)
          .get();
      _lastPostBodyDoc = snap.docs.length >= _pageSize ? snap.docs.last : null;
      for (final doc in snap.docs) {
        if (_seenPostIds.add(doc.id)) {
          out.add(PostModel.fromMap(doc.data(), doc.id));
        }
      }
    }
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
