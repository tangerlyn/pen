import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/level_system.dart';
import '../../../core/utils/network_utils.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/reply_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';

final reviewDetailProvider =
    AsyncNotifierProviderFamily<ReviewDetailNotifier, ReviewModel?, String>(
  ReviewDetailNotifier.new,
);

class ReviewDetailNotifier extends FamilyAsyncNotifier<ReviewModel?, String> {
  @override
  Future<ReviewModel?> build(String arg) async {
    final uid = ref.watch(currentUidProvider); // uid 변경 시 자동 rebuild
    final review = await ref.read(reviewRepoProvider).getReview(arg);
    if (review == null || uid == null) return review;

    final isLiked = await ref.read(reviewRepoProvider).isLiked(arg, uid);
    return review.copyWith(isLiked: isLiked);
  }

  Future<void> toggleLike() async {
    final review = state.value;
    final uid = ref.read(currentUidProvider);
    if (review == null || uid == null) return;

    await withRetry(
      () => ref.read(reviewRepoProvider).toggleLike(review.id, uid, !review.isLiked),
    );
    state = AsyncData(review.copyWith(
      isLiked: !review.isLiked,
      likeCount: review.isLiked ? review.likeCount - 1 : review.likeCount + 1,
    ));
    // 마이페이지 좋아요 탭이 stream이라 이론상 자동 반영돼야 하지만, 이미
    // 생성돼있던 provider 인스턴스가 즉시 안 갈아끼워지는 경우가 있어
    // 명시적으로 무효화해서 뒤로가기 시 바로 목록에서 빠지도록 보장한다.
    ref.invalidate(likedReviewsProvider(uid));
  }

  Future<void> addComment(String body) async {
    final review = state.value;
    final uid = ref.read(currentUidProvider);
    if (review == null || uid == null) return;

    final currentUser = ref.read(currentUserProvider).value;
    final comment = CommentModel(
      id: '',
      reviewId: review.id,
      authorId: uid,
      authorNickname: currentUser?.nickname ?? '',
      authorLevel: currentUser?.level ?? 1,
      body: body,
      createdAt: DateTime.now(),
    );
    await withRetry(() => ref.read(reviewRepoProvider).addComment(review.id, comment));
    state = AsyncData(review.copyWith(commentCount: review.commentCount + 1));

    // 댓글은 이미 저장됐으므로 경험치 지급 실패는 사용자에게 실패로 보이지 않게 한다.
    try {
      final levelUp = await ref.read(userRepoProvider).addExpAndCheck(uid, LevelSystem.expComment);
      if (levelUp != null) {
        ref.read(levelUpProvider.notifier).state = levelUp;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ReviewDetail] 댓글 경험치 지급 실패: $e');
    }
  }

  void updateCommentCount(int delta) {
    final review = state.value;
    if (review == null) return;
    state = AsyncData(review.copyWith(commentCount: review.commentCount + delta));
  }
}

/// 내가 차단한 유저 uid 목록 — 차단 직후 댓글/답글 목록에서 바로 빠지도록 스트림으로 구독한다.
final _myBlockedUidsProvider = StreamProvider<List<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  // 유저 문서의 다른 필드(경험치 등) 변경으로 댓글 스트림이 재구독되지 않게 목록이 바뀔 때만 흘린다.
  return ref
      .watch(userRepoProvider)
      .watchBlockedUids(uid)
      .distinct((a, b) => listEquals(a, b));
});

/// 차단 목록을 먼저 받은 뒤 차단한 유저의 항목을 빼고 흘려보낸다
/// (차단 목록 로딩 전 잠깐 노출되는 것 방지). 차단 목록이 바뀌면 provider가 다시 빌드된다.
Stream<List<T>> _withoutBlocked<T>(
  Future<List<String>> blockedFuture,
  Stream<List<T>> source,
  String Function(T) authorId,
) async* {
  final blocked = await blockedFuture.catchError((_) => const <String>[]);
  if (blocked.isEmpty) {
    yield* source;
    return;
  }
  yield* source.map(
    (list) => list.where((item) => !blocked.contains(authorId(item))).toList(),
  );
}

final commentsProvider = StreamProviderFamily<List<CommentModel>, String>((ref, reviewId) {
  return _withoutBlocked(
    ref.watch(_myBlockedUidsProvider.future),
    ref.watch(reviewRepoProvider).watchComments(reviewId),
    (c) => c.authorId,
  );
});

final reviewRepliesProvider = StreamProviderFamily<List<ReplyModel>,
    ({String reviewId, String commentId})>((ref, args) {
  return _withoutBlocked(
    ref.watch(_myBlockedUidsProvider.future),
    ref.watch(reviewRepoProvider).watchReplies(args.reviewId, args.commentId),
    (r) => r.authorId,
  );
});

/// 리뷰 목록(1열 리스트)에서 하트 채움 여부를 실시간으로 보여주기 위한
/// 좋아요 상태 스트림 — community_provider.dart의 postLikeStatusProvider와
/// 동일한 역할.
final reviewLikeStatusProvider =
    StreamProvider.family<bool, (String, String)>((ref, args) {
  final (reviewId, uid) = args;
  return ref.watch(reviewRepoProvider).watchLikeStatus(reviewId, uid);
});
