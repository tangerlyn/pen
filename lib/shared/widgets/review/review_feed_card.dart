import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../features/archive/providers/archive_detail_provider.dart';
import '../../../data/models/review_model.dart';
import '../../../core/theme/app_theme.dart';

class ReviewFeedCard extends ConsumerWidget {
  const ReviewFeedCard({super.key, required this.review, required this.onTap});

  final ReviewModel review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
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
                    placeholder: (_, _) => Container(color: AppColors.chipBackground),
                    errorWidget: (_, _, _) => Container(
                      color: AppColors.chipBackground,
                      child: const Icon(Icons.image_not_supported, color: AppColors.textTertiary, size: 32),
                    ),
                  ),
                  if (review.imageUrls.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.collections, color: Colors.white, size: 11),
                            const SizedBox(width: 2),
                            Text('${review.imageUrls.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 하단 정보
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GearTags(review: review),
                  if (review.title.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      review.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        review.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Icon(Icons.favorite_border, size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text('${review.likeCount}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text('${review.commentCount}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GearTags extends ConsumerWidget {
  const _GearTags({required this.review});
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
        Flexible(child: _TagChip(type: first.type, id: first.id)),
        if (remaining > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
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

class _TagChip extends ConsumerWidget {
  const _TagChip({required this.type, required this.id});
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
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.chipBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
