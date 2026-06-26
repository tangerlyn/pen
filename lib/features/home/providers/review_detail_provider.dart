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
    final isScrapped = await ref.read(reviewRepoProvider).isScrapped(arg, uid);
    return review.copyWith(isLiked: isLiked, isScrapped: isScrapped);
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
  }

  Future<void> toggleScrap() async {
    final review = state.value;
    final uid = ref.read(currentUidProvider);
    if (review == null || uid == null) return;

    await withRetry(
      () => ref.read(reviewRepoProvider).toggleScrap(review.id, uid, !review.isScrapped),
    );
    state = AsyncData(review.copyWith(
      isScrapped: !review.isScrapped,
      scrapCount: review.isScrapped ? review.scrapCount - 1 : review.scrapCount + 1,
    ));
    ref.invalidate(scrappedReviewsProvider(uid));
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
