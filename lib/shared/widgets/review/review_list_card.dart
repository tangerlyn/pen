import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_navigation.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/providers.dart';
import '../level_badge.dart';

final _reviewCardAuthorProvider =
    StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(userRepoProvider).watchUser(uid);
});

class ReviewListCard extends ConsumerWidget {
  const ReviewListCard({super.key, required this.review, required this.onTap});
  final ReviewModel review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = review.imageUrls.isNotEmpty;
    final stars = review.rating.toStringAsFixed(1);
    final authorAsync = ref.watch(_reviewCardAuthorProvider(review.authorId));
    final user = authorAsync.valueOrNull;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, AppSpacing.lg, AppSpacing.sm),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 11, color: Color(0xFFFFA000)),
                            const SizedBox(width: 2),
                            Text(
                              stars,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFFA000),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          review.title.isNotEmpty ? review.title : review.body,
                          style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 15, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (review.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      review.body,
                      style: AppTextStyles.labelMedium,
                      maxLines: hasImage ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: () => navigateToProfile(context, ref, review.authorId),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 11,
                                      backgroundColor: AppColors.chipBackground,
                                      backgroundImage: user?.profileImageUrl != null
                                          ? CachedNetworkImageProvider(user!.profileImageUrl!)
                                          : null,
                                      child: user?.profileImageUrl == null
                                          ? const Icon(Icons.person, size: 13, color: AppColors.textTertiary)
                                          : null,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        user?.nickname ?? review.authorNickname,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textTertiary,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    LevelBadge(user?.level ?? review.authorLevel),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              timeago.format(review.createdAt, locale: 'ko'),
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textTertiary),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text(
                            '${review.commentCount}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textTertiary),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.favorite_border,
                              size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text(
                            '${review.likeCount}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textTertiary),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  child: CachedNetworkImage(
                    imageUrl: review.imageUrls.first,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorWidget: (context2, url, err) => const SizedBox.shrink(),
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
