import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../data/models/post_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_navigation.dart';
import '../../providers/providers.dart';
import '../../../features/community/providers/community_provider.dart';

class PostCard extends ConsumerWidget {
  const PostCard(
      {super.key,
      required this.post,
      required this.onTap,
      this.topPadding = 8.0});

  final PostModel post;
  final VoidCallback onTap;
  final double topPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final isLiked = uid != null
        ? ref.watch(postLikeStatusProvider((post.id, uid))).valueOrNull ?? false
        : false;

    final hasImage = post.imageUrls.isNotEmpty;
    final showBadge = post.category == '질문' || post.category == '정보공유';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, topPadding, AppSpacing.lg, AppSpacing.sm),
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
                              fontSize: 15, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                    children: [
                      GestureDetector(
                        onTap: () => navigateToProfile(context, ref, post.authorId),
                        child: Text(
                          post.authorNickname,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        timeago.format(post.createdAt, locale: 'ko'),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                      ),
                      const Spacer(),
                      const Icon(Icons.chat_bubble_outline,
                          size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        '${post.commentCount}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: uid != null
                            ? () => ref
                                .read(postRepositoryProvider)
                                .toggleLike(post.id, uid, post.authorId)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: isLiked
                                  ? AppColors.error
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${post.likeCount}',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
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
      _ => (AppColors.textSecondary, AppColors.chipBackground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
