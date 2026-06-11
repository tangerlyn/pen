import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../features/archive/providers/archive_detail_provider.dart';
import '../../../data/models/review_model.dart';
import '../../../core/theme/app_theme.dart';

class ReviewGridItem extends ConsumerWidget {
  const ReviewGridItem({super.key, required this.review, required this.onTap});

  final ReviewModel review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? firstType;
    String? firstId;
    if (review.inkIds.isNotEmpty) {
      firstType = 'ink';
      firstId = review.inkIds.first;
    } else if (review.penIds.isNotEmpty) {
      firstType = 'pen';
      firstId = review.penIds.first;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: review.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.chipBackground),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.chipBackground,
                      child: const Icon(Icons.image_not_supported, color: AppColors.textTertiary),
                    ),
                  ),
                  if (review.imageUrls.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.collections, color: Colors.white, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '${review.imageUrls.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm, AppSpacing.xxl, AppSpacing.sm, AppSpacing.sm),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            review.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.favorite, color: Colors.white, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '${review.likeCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (firstType != null && firstId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
                child: _GearLabel(type: firstType, id: firstId),
              ),
          ],
        ),
      ),
    );
  }
}

class _GearLabel extends ConsumerWidget {
  const _GearLabel({required this.type, required this.id});
  final String type;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(archiveDetailProvider((type: type, productId: id)));

    return state.when(
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final text = switch (type) {
          'ink' => '잉크 > ${data.brand} > ${data.name}',
          'pen' => '펜 > ${data.brand} > ${data.modelName}',
          _ => '펜 > ${data.brand} > ${data.modelName}',
        };
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        );
      },
      loading: () =>
          const Text('로딩중...', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
