import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/post_date_format.dart';
import '../../providers/providers.dart';
import '../../../features/community/providers/community_provider.dart';
import '../icon_count.dart';
import '../level_badge.dart';
import '../tap_scale.dart';
import '../user_avatar.dart';

final _postCardAuthorProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  return ref.watch(userRepoProvider).watchUser(uid);
});

class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.topPadding = 8.0,
    this.showDate = true,
  });

  final PostModel post;
  final VoidCallback onTap;
  final double topPadding;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final isLiked = uid != null
        ? ref.watch(postLikeStatusProvider((post.id, uid))).valueOrNull ?? false
        : false;
    // 목록은 한 번 불러온 뒤 실시간으로 안 갱신되는 스냅샷이라, 상세 화면에서
    // 좋아요/댓글을 누르고 돌아와도 숫자가 그대로였다. 좋아요 여부(isLiked)처럼
    // 문서를 실시간으로 watch해서 좋아요/댓글 수만 최신값으로 덮어씌운다.
    final live = ref.watch(postDetailProvider(post.id)).valueOrNull;
    final likeCount = live?.likeCount ?? post.likeCount;
    final commentCount = live?.commentCount ?? post.commentCount;

    final hasImage = post.imageUrls.isNotEmpty;
    final showBadge = post.category != null;

    return TapScale(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          topPadding,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (showBadge) ...[
                        _CategoryBadge(category: post.category!),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          post.title,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showDate) ...[
                        const SizedBox(width: 6),
                        Text(
                          formatPostDate(post.createdAt),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.body,
                    style: AppTextStyles.labelMedium,
                    maxLines: hasImage ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: _AuthorRow(
                                authorId: post.authorId,
                                fallbackNickname: post.authorNickname,
                                authorLevel: post.authorLevel,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconCount(
                            icon: isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            count: likeCount,
                            iconColor: isLiked
                                ? AppColors.error
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 10),
                          IconCount(
                            icon: Icons.chat_bubble_outline,
                            count: commentCount,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: AppSpacing.md),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrls.first,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (category) {
      '질문' => (const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
      '정보공유' => (const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      '필사' => (const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
      '그림' => (const Color(0xFFEF6C00), const Color(0xFFFFF3E0)),
      _ => (AppColors.textSecondary, AppColors.chipBackground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        category,
        style: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── 작성자 프사 + 닉네임 ───────────────────────────────────────────────────
class _AuthorRow extends ConsumerWidget {
  const _AuthorRow({
    required this.authorId,
    required this.fallbackNickname,
    required this.authorLevel,
  });
  final String authorId;
  final String fallbackNickname;
  final int authorLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(_postCardAuthorProvider(authorId));
    final user = authorAsync.valueOrNull;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(imageUrl: user?.profileImageUrl, radius: 11, iconSize: 13),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            user?.nickname ?? fallbackNickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 5),
        LevelBadge(user?.level ?? authorLevel),
      ],
    );
  }
}
