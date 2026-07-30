import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/post_date_format.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';
import '../../../features/archive/providers/archive_detail_provider.dart';
import '../../providers/providers.dart';
import '../level_badge.dart';
import '../tap_scale.dart';

final _reviewTileAuthorProvider =
    StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(userRepoProvider).watchUser(uid);
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
                      //     borderRadius: BorderRadius.circular(4),
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
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textTertiary),
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
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
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: AppColors.chipBackground,
                                    backgroundImage: user?.profileImageUrl != null
                                        ? CachedNetworkImageProvider(
                                            user!.profileImageUrl!)
                                        : null,
                                    child: user?.profileImageUrl == null
                                        ? const Icon(Icons.person,
                                            size: 13,
                                            color: AppColors.textTertiary)
                                        : null,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      user?.nickname ?? review.authorNickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
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
                          const Icon(Icons.favorite_border,
                              size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 2),
                          Text('${review.likeCount}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textTertiary)),
                          const SizedBox(width: 8),
                          const Icon(Icons.chat_bubble_outline,
                              size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 2),
                          Text('${review.commentCount}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textTertiary)),
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
                borderRadius: BorderRadius.circular(8),
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
        Flexible(child: _ListTagChip(type: first.type, id: first.id)),
        if (remaining > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+$remaining',
              style: const TextStyle(
                fontSize: 11,
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
