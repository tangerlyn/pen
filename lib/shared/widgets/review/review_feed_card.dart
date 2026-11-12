import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/post_date_format.dart';
import '../../providers/providers.dart';
import '../level_badge.dart';
import '../tap_scale.dart';
import '../user_avatar.dart';
import 'review_gear_tag_label.dart';

final _reviewCardAuthorProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  return ref.watch(userRepoProvider).watchUser(uid);
});

class ReviewFeedCard extends ConsumerWidget {
  const ReviewFeedCard({super.key, required this.review, required this.onTap});

  final ReviewModel review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(_reviewCardAuthorProvider(review.authorId));
    final user = authorAsync.valueOrNull;

    return TapScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.cardAll,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: AppShadows.cardMd,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 이미지
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: review.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: AppColors.chipBackground),
                    errorWidget: (_, _, _) => Container(
                      color: AppColors.chipBackground,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: AppColors.textTertiary,
                        size: 32,
                      ),
                    ),
                  ),
                  // 별점 뱃지 (좌측 상단) — 별점 시스템 비활성화, 재활성화 시 주석 해제
                  // Positioned(
                  //   top: 8,
                  //   left: 8,
                  //   child: Container(
                  //     padding: const EdgeInsets.symmetric(
                  //       horizontal: 6,
                  //       vertical: 3,
                  //     ),
                  //     decoration: BoxDecoration(
                  //       color: Colors.black.withValues(alpha: 0.55),
                  //       borderRadius: BorderRadius.circular(10),
                  //     ),
                  //     child: Row(
                  //       mainAxisSize: MainAxisSize.min,
                  //       children: [
                  //         const Icon(Icons.star, color: Colors.amber, size: 12),
                  //         const SizedBox(width: 2),
                  //         Text(
                  //           review.rating.toStringAsFixed(1),
                  //           style: const TextStyle(
                  //             color: Colors.white,
                  //             fontSize: 11,
                  //             fontWeight: FontWeight.w600,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  ReviewGearTagOverlay(review: review),
                  if (review.imageUrls.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.collections,
                              color: Colors.white,
                              size: 11,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${review.imageUrls.length}',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 하단 정보 — 작성자 프사·이름 + 제목만
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        imageUrl: user?.profileImageUrl,
                        radius: 10,
                        iconSize: 12,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          user?.nickname ?? review.authorNickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      LevelBadge(user?.level ?? review.authorLevel),
                    ],
                  ),
                  if (review.title.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            review.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatPostDate(review.createdAt),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
