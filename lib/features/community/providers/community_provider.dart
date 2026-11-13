import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  final cutoff = DateTime.now().subtract(const Duration(days: 3));
  final recent = posts.where((p) => p.createdAt.isAfter(cutoff)).toList()
    ..sort((a, b) => (b.likeCount + b.commentCount).compareTo(a.likeCount + a.commentCount));
  return recent.take(3).toList();
});

final postLikeStatusProvider =
    StreamProvider.autoDispose.family<bool, (String, String)>((ref, args) {
  final (postId, uid) = args;
  return ref.watch(postRepositoryProvider).watchLikeStatus(postId, uid);
});

final postDetailProvider =
    StreamProvider.autoDispose.family<PostModel?, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchPost(postId);
});

/// 현재 유저가 차단한 uid 집합 — 상세 화면 댓글·답글 필터링용
final _blockedUidsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <String>{});
  return ref
      .watch(userRepoProvider)
      .watchBlockedUids(uid)
      .map((uids) => uids.toSet());
});

/// 원본 목록 스트림에 차단 목록을 합쳐 차단 유저 글을 걸러낸다.
/// 차단 목록이 아직 안 왔을 때는 로딩으로 두어 차단 유저 글이 잠깐이라도
/// 보이지 않게 한다. 스트림을 다시 구독하지 않으려고 동기 Provider로 합친다.
AsyncValue<List<T>> _withoutBlocked<T>(
  Ref ref,
  AsyncValue<List<T>> source,
  String Function(T) authorId,
) {
  final blockedAsync = ref.watch(_blockedUidsProvider);
  if (!blockedAsync.hasValue) {
    return blockedAsync.hasError ? source : const AsyncLoading();
  }
  final blocked = blockedAsync.requireValue;
  if (blocked.isEmpty) return source;
  return source.whenData(
    (items) => items.where((i) => !blocked.contains(authorId(i))).toList(),
  );
}

final _rawPostCommentsProvider =
    StreamProvider.autoDispose.family<List<PostCommentModel>, String>(
        (ref, postId) {
  return ref.watch(postRepositoryProvider).watchComments(postId);
});

final postCommentsProvider = Provider.autoDispose
    .family<AsyncValue<List<PostCommentModel>>, String>((ref, postId) {
  return _withoutBlocked(
    ref,
    ref.watch(_rawPostCommentsProvider(postId)),
    (c) => c.authorId,
  );
});

final _rawPostRepliesProvider = StreamProvider.autoDispose
    .family<List<ReplyModel>, ({String postId, String commentId})>(
        (ref, args) {
  return ref
      .watch(postRepositoryProvider)
      .watchReplies(args.postId, args.commentId);
});

final postRepliesProvider = Provider.autoDispose.family<
    AsyncValue<List<ReplyModel>>,
    ({String postId, String commentId})>((ref, args) {
  return _withoutBlocked(
    ref,
    ref.watch(_rawPostRepliesProvider(args)),
    (r) => r.authorId,
  );
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
      if (!mounted) return;
      _lastDoc = lastDoc;
      final filtered = await _ref
          .read(userRepoProvider)
          .filterByBlocked(uid, posts, (p) => p.authorId);
      if (!mounted) return;
      state = state.copyWith(
        posts: [...state.posts, ...filtered],
        isLoading: false,
        isLoadingMore: false,
        hasMore: state.selectedCategory == null && posts.length >= 20,
      );
    } catch (_) {
      if (!mounted) return;
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

/// 글 작성·수정·삭제, 유저 차단 후에는 ref.invalidate로 새로 불러온다.
/// 계정이 바뀌면 차단 목록이 달라지므로 uid를 watch해서 다시 만든다.
final communityFeedProvider =
    StateNotifierProvider<CommunityFeedNotifier, CommunityFeedState>((ref) {
  ref.watch(currentUidProvider);
  return CommunityFeedNotifier(ref);
});

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

  /// 글 생성에 실패하면 예외를 그대로 던진다(화면에서 안내).
  Future<String> submit({
    required String authorId,
    required String authorNickname,
    required int authorLevel,
    required String title,
    required String body,
    List<String> imageUrls = const [],
    String? category,
    List<Map<String, dynamic>>? contentBlocks,
  }) async {
    state = const PostWriteState(isSubmitting: true);
    final String id;
    try {
      id = await _repo.createPost(
        authorId: authorId,
        authorNickname: authorNickname,
        authorLevel: authorLevel,
        title: title,
        body: body,
        imageUrls: imageUrls,
        category: category,
        contentBlocks: contentBlocks,
      );
    } catch (e) {
      state = PostWriteState(error: e.toString());
      rethrow;
    }
    // 글은 이미 올라갔으니 EXP 지급 실패는 무시한다. 여기서 실패로 처리하면
    // 사용자가 다시 등록을 눌러 같은 글이 두 번 올라갈 수 있다.
    try {
      final levelUp = await _ref
          .read(userRepoProvider)
          .addExpAndCheck(authorId, LevelSystem.expPost);
      if (levelUp != null) {
        _ref.read(levelUpProvider.notifier).state = levelUp;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('addExpAndCheck(post) failed: $e');
    }
    _ref.invalidate(communityFeedProvider);
    state = const PostWriteState();
    return id;
  }
}

final postWriteProvider = StateNotifierProvider<PostWriteNotifier, PostWriteState>((ref) {
  return PostWriteNotifier(ref.watch(postRepositoryProvider), ref);
});
