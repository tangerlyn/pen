part of '../screens/review_detail_screen.dart';

class _CommentList extends ConsumerWidget {
  const _CommentList({
    required this.reviewId,
    required this.reviewAuthorId,
    required this.currentUid,
    required this.onReplyTap,
    required this.onCommentDeleted,
    this.onReplyDeleted,
    this.onEditStart,
    this.onEditEnd,
  });
  final String reviewId;
  final String reviewAuthorId;
  final String? currentUid;
  final void Function(String commentId, String nickname) onReplyTap;
  final VoidCallback onCommentDeleted;
  final VoidCallback? onReplyDeleted;
  final VoidCallback? onEditStart;
  final VoidCallback? onEditEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(commentsProvider(reviewId));
    return comments.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (list) => SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => CommentTile(
            comment: list[i],
            reviewId: reviewId,
            reviewAuthorId: reviewAuthorId,
            currentUid: currentUid,
            onReplyTap: onReplyTap,
            onDeleted: onCommentDeleted,
            onReplyDeleted: onReplyDeleted,
            onEditStart: onEditStart,
            onEditEnd: onEditEnd,
          ),
          childCount: list.length,
        ),
      ),
    );
  }
}

// ── 댓글 입력창 ──────────────────────────────────────────────
class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.replyTargetNickname,
    this.onCancelReply,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final String? replyTargetNickname;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyTargetNickname != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.chipBackground,
            child: Row(
              children: [
                Text(
                  '@$replyTargetNickname 에게 답글',
                  style: AppTextStyles.bodySmall,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onCancelReply,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: replyTargetNickname != null
                        ? '답글을 입력하세요...'
                        : '댓글을 입력하세요...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    counterStyle: AppTextStyles.labelSmall,
                  ),
                  maxLines: null,
                  maxLength: replyTargetNickname != null
                      ? AppConstants.maxReply
                      : AppConstants.maxComment,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onSubmit,
                icon: const Icon(Icons.send, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
