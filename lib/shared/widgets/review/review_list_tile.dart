import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/post_date_format.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';
import '../../../features/archive/providers/archive_detail_provider.dart';
import '../../../features/home/providers/review_detail_provider.dart';
import '../../providers/providers.dart';
import '../icon_count.dart';
import '../level_badge.dart';
import '../tap_scale.dart';
import '../user_avatar.dart';

final _reviewTileAuthorProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  return ref.watch(userRepoProvider).watchUser(uid);
});

// 목록은 한 번 불러온 뒤 실시간으로 안 갱신되는 스냅샷이라, 상세 화면에서
// 좋아요/댓글을 누르고 돌아와도 숫자가 그대로였다. 문서를 실시간으로 watch해서
// 좋아요/댓글 수만 최신값으로 덮어씌운다 (post_card.dart와 동일한 패턴).
final _reviewTileLiveProvider = StreamProvider.family<ReviewModel?, String>((
  ref,
  reviewId,
) {
  return ref.watch(reviewRepoProvider).watchReview(reviewId);
});

/// 리뷰 탭 · 리뷰 검색 결과 · 마이페이지 리뷰 목록에서 공통으로 쓰는
/// 한 줄(1열) 리뷰 리스트 타일.
class ReviewListTile extends ConsumerWidget {
  const ReviewListTile({
    super.key,
    required this.review,
    required this.onTap,
    this.showDate = true,
  });

  final ReviewModel review;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasThumbnail = review.thumbnailUrl.isNotEmpty;
    final authorAsync = ref.watch(_reviewTileAuthorProvider(review.authorId));
    final user = authorAsync.valueOrNull;
    final live = ref.watch(_reviewTileLiveProvider(review.id)).valueOrNull;
    final likeCount = live?.likeCount ?? review.likeCount;
    final commentCount = live?.commentCount ?? review.commentCount;
    final uid = ref.watch(currentUidProvider);
    final isLiked = uid != null
        ? ref.watch(reviewLikeStatusProvider((review.id, uid))).valueOrNull ??
              false
        : false;
    // 별점 시스템 비활성화
    // final stars = review.rating.toStringAsFixed(1);

    return TapScale(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 별점 시스템 비활성화 — 재활성화 시 주석 해제
                      // Container(
                      //   padding: const EdgeInsets.symmetric(
                      //       horizontal: AppSpacing.sm, vertical: 3),
                      //   decoration: BoxDecoration(
                      //     color: const Color(0xFFFFF3E0),
                      //     borderRadius: BorderRadius.circular(AppRadius.xs),
                      //   ),
                      //   child: Row(
                      //     mainAxisSize: MainAxisSize.min,
                      //     children: [
                      //       const Icon(Icons.star,
                      //           size: 11, color: Color(0xFFFFA000)),
                      //       const SizedBox(width: 2),
                      //       Text(
                      //         stars,
                      //         style: const TextStyle(
                      //           fontSize: 11,
                      //           fontWeight: FontWeight.w600,
                      //           color: Color(0xFFFFA000),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      if (review.title.isNotEmpty) ...[
                        Expanded(
                          child: Text(
                            review.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (showDate) ...[
                        const SizedBox(width: 6),
                        Text(
                          formatPostDate(review.createdAt),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  _ListGearTags(review: review),
                  if (review.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      review.body,
                      maxLines: hasThumbnail ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UserAvatar(
                                    imageUrl: user?.profileImageUrl,
                                    radius: 11,
                                    iconSize: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      user?.nickname ?? review.authorNickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  LevelBadge(user?.level ?? review.authorLevel),
                                ],
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
                            spacing: 2,
                          ),
                          const SizedBox(width: 8),
                          IconCount(
                            icon: Icons.chat_bubble_outline,
                            count: commentCount,
                            spacing: 2,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasThumbnail) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: CachedNetworkImage(
                  imageUrl: review.thumbnailUrl,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListGearTags extends ConsumerWidget {
  const _ListGearTags({required this.review});

  final ReviewModel review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allGear = [
      ...review.inkIds.map((id) => (type: 'ink', id: id)),
      ...review.penIds.map((id) => (type: 'pen', id: id)),
    ];

    if (allGear.isEmpty) return const SizedBox.shrink();

    final first = allGear.first;
    final remaining = allGear.length - 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _ListTagChip(type: first.type, id: first.id),
        ),
        if (remaining > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              '+$remaining',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ListTagChip extends ConsumerWidget {
  const _ListTagChip({required this.type, required this.id});

  final String type;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(archiveDetailProvider((type: type, productId: id)));

    final label = state.when(
      data: (data) {
        if (data == null) return '';
        if (type == 'ink') return '잉크 · ${data.brand} ${data.name}';
        return '펜 · ${data.brand} ${data.modelName}';
      },
      loading: () => '...',
      error: (_, _) => '',
    );

    if (label.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.chipBackground,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
