import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/archive/providers/archive_detail_provider.dart';
import '../../providers/providers.dart';
import '../tap_scale.dart';

final _reviewCardAuthorProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
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
                  // 별점 뱃지 (좌측 상단)
                  Positioned(
                    top: 8,
                    left: 8,
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
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            review.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (review.inkIds.isNotEmpty || review.penIds.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _GearTagOverlay(review: review),
                      ),
                    ),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
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
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.chipBackground,
                        backgroundImage: user?.profileImageUrl != null
                            ? CachedNetworkImageProvider(user!.profileImageUrl!)
                            : null,
                        child: user?.profileImageUrl == null
                            ? const Icon(Icons.person,
                                size: 12, color: AppColors.textTertiary)
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user?.nickname ?? review.authorNickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (review.title.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      review.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
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

// 사진 위 태그된 잉크/만년필 이름 오버레이 (흰 글씨, ex. "블랙 45 +4")
class _GearTagOverlay extends ConsumerWidget {
  const _GearTagOverlay({required this.review});
  final ReviewModel review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allGear = [
      ...review.inkIds.map((id) => (type: 'ink', id: id)),
      ...review.penIds.map((id) => (type: 'pen', id: id)),
    ];
    final first = allGear.first;
    final remaining = allGear.length - 1;

    final state =
        ref.watch(archiveDetailProvider((type: first.type, productId: first.id)));
    final name = state.when(
      data: (data) {
        if (data == null) return '';
        return first.type == 'ink' ? data.name : data.modelName;
      },
      loading: () => '',
      error: (_, _) => '',
    );

    if (name.isEmpty) return const SizedBox.shrink();

    return Text(
      remaining > 0 ? '$name +$remaining' : name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
      ),
    );
  }
}
