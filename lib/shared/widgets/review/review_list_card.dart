import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/review_model.dart';

class ReviewListCard extends StatelessWidget {
  const ReviewListCard({super.key, required this.review, required this.onTap});
  final ReviewModel review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = review.imageUrls.isNotEmpty;
    final stars = review.rating.toStringAsFixed(1);

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
                          review.body,
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
                    children: [
                      Text(
                        timeago.format(review.createdAt, locale: 'ko'),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                      ),
                      const Spacer(),
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
