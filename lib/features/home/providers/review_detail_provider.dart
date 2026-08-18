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

    final levelUp = await ref.read(userRepoProvider).addExpAndCheck(uid, LevelSystem.expComment);
    if (levelUp != null) {
      ref.read(levelUpProvider.notifier).state = levelUp;
    }
  }

  void updateCommentCount(int delta) {
    final review = state.value;
    if (review == null) return;
    state = AsyncData(review.copyWith(commentCount: review.commentCount + delta));
  }
}

final commentsProvider = StreamProviderFamily<List<CommentModel>, String>((ref, reviewId) {
  return ref.watch(reviewRepoProvider).watchComments(reviewId);
});

final reviewRepliesProvider = StreamProviderFamily<List<ReplyModel>,
    ({String reviewId, String commentId})>((ref, args) {
  return ref.watch(reviewRepoProvider).watchReplies(args.reviewId, args.commentId);
});

/// 리뷰 목록(1열 리스트)에서 하트 채움 여부를 실시간으로 보여주기 위한
/// 좋아요 상태 스트림 — community_provider.dart의 postLikeStatusProvider와
/// 동일한 역할.
final reviewLikeStatusProvider =
    StreamProvider.family<bool, (String, String)>((ref, args) {
  final (reviewId, uid) = args;
  return ref.watch(reviewRepoProvider).watchLikeStatus(reviewId, uid);
});
