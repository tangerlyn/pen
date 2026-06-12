import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/level_system.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/reply_model.dart';
import '../../../data/repositories/post_repository.dart';
import '../../../shared/providers/providers.dart';

final postRepositoryProvider = Provider((ref) => PostRepository());

final postsStreamProvider = StreamProvider<List<PostModel>>((ref) {
  return ref.watch(postRepositoryProvider).watchPosts();
});

final filteredPostsProvider = StreamProvider<List<PostModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(postRepositoryProvider).watchPosts().asyncMap((posts) async {
    return ref
        .read(userRepoProvider)
        .filterByBlocked(uid, posts, (p) => p.authorId);
  });
});

final popularPostsProvider = Provider<List<PostModel>>((ref) {
  final posts = ref.watch(filteredPostsProvider).valueOrNull ?? [];
  final sorted = List<PostModel>.from(posts)
    ..sort((a, b) => (b.likeCount + b.commentCount).compareTo(a.likeCount + a.commentCount));
  return sorted.take(3).toList();
});

final postLikeStatusProvider =
    StreamProvider.family<bool, (String, String)>((ref, args) {
  final (postId, uid) = args;
  return ref.watch(postRepositoryProvider).watchLikeStatus(postId, uid);
});

final postScrapStatusProvider =
    StreamProvider.family<bool, (String, String)>((ref, args) {
  final (postId, uid) = args;
  return ref.watch(postRepositoryProvider).watchScrapStatus(postId, uid);
});

final postDetailProvider = StreamProvider.family<PostModel?, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchPost(postId);
});

final postCommentsProvider = StreamProvider.family<List<PostCommentModel>, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchComments(postId);
});

final postRepliesProvider = StreamProviderFamily<List<ReplyModel>,
    ({String postId, String commentId})>((ref, args) {
  return ref.watch(postRepositoryProvider).watchReplies(args.postId, args.commentId);
});

// ── 커뮤니티 피드 페이지네이션 ─────────────────────────────────────────────
class CommunityFeedState {
  const CommunityFeedState({
    this.posts = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.selectedCategory,
  });
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? selectedCategory;

  CommunityFeedState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? selectedCategory = _sentinel,
  }) =>
      CommunityFeedState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        selectedCategory: selectedCategory == _sentinel
            ? this.selectedCategory
            : selectedCategory as String?,
      );
}

const _sentinel = Object();

class CommunityFeedNotifier extends StateNotifier<CommunityFeedState> {
  CommunityFeedNotifier(this._ref) : super(const CommunityFeedState()) {
    _load();
  }
  final Ref _ref;
  DocumentSnapshot? _lastDoc;

  Future<void> _load() async {
    try {
      final uid = _ref.read(currentUidProvider);
      final (posts, lastDoc) = await _ref.read(postRepositoryProvider).fetchPosts(
            lastDoc: _lastDoc,
            category: state.selectedCategory,
          );
      _lastDoc = lastDoc;
      final filtered = await _ref
          .read(userRepoProvider)
          .filterByBlocked(uid, posts, (p) => p.authorId);
      state = state.copyWith(
        posts: [...state.posts, ...filtered],
        isLoading: false,
        isLoadingMore: false,
        hasMore: state.selectedCategory == null && posts.length >= 20,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, isLoadingMore: false);
    }
  }

  Future<void> loadPosts({bool refresh = false}) async {
    if (refresh) {
      _lastDoc = null;
      state = CommunityFeedState(selectedCategory: state.selectedCategory);
    }
    await _load();
  }

  Future<void> setCategory(String? category) async {
    _lastDoc = null;
    state = CommunityFeedState(selectedCategory: category);
    await _load();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    await _load();
  }
}

final communityFeedProvider =
    StateNotifierProvider<CommunityFeedNotifier, CommunityFeedState>(
        (ref) => CommunityFeedNotifier(ref));

// 글쓰기 상태
class PostWriteState {
  const PostWriteState({
    this.isSubmitting = false,
    this.error,
  });
  final bool isSubmitting;
  final String? error;
}

class PostWriteNotifier extends StateNotifier<PostWriteState> {
  PostWriteNotifier(this._repo, this._ref) : super(const PostWriteState());
  final PostRepository _repo;
  final Ref _ref;

  Future<String?> submit({
    required String authorId,
    required String authorNickname,
    required String title,
    required String body,
    List<String> imageUrls = const [],
    String? category,
    List<Map<String, dynamic>>? contentBlocks,
  }) async {
    state = const PostWriteState(isSubmitting: true);
    try {
      final id = await _repo.createPost(
        authorId: authorId,
        authorNickname: authorNickname,
        title: title,
        body: body,
        imageUrls: imageUrls,
        category: category,
        contentBlocks: contentBlocks,
      );
      // 커뮤니티 글 작성 EXP 지급 + 레벨업 체크
      final levelUp = await _ref.read(userRepoProvider).addExpAndCheck(authorId, LevelSystem.expPost);
      if (levelUp != null) {
        _ref.read(levelUpProvider.notifier).state = levelUp;
      }
      state = const PostWriteState();
      return id;
    } catch (e) {
      state = PostWriteState(error: e.toString());
      return null;
    }
  }
}

final postWriteProvider = StateNotifierProvider<PostWriteNotifier, PostWriteState>((ref) {
  return PostWriteNotifier(ref.watch(postRepositoryProvider), ref);
});
