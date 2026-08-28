part of '../screens/archive_detail_screen.dart';

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.type,
    required this.data,
    required this.productId,
  });
  final String type;
  final dynamic data;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(
      productReviewsProvider((type: type, productId: productId)),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            // 색상 비교 버튼 — 구현 완료, 적용 보류 (ink_compare_screen.dart)
            child: type == 'ink'
                ? _InkProfileHeader(data: data as InkModel)
                : _PenProfileHeader(data: data as PenModel),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '사용자 리뷰',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                OutlinedButton(
                  onPressed: () => context.push(
                    '/write/review?type=$type&productId=$productId',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('새 리뷰 작성'),
                ),
              ],
            ),
          ),
          reviewsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('오류: $e')),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      '아직 리뷰가 없습니다.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = (constraints.maxWidth - 1) / 2;
                  return Wrap(
                    spacing: 1,
                    runSpacing: 1,
                    children: list
                        .map(
                          (review) => SizedBox(
                            width: w,
                            height: w / 0.85,
                            child: ReviewFeedCard(
                              review: review,
                              onTap: () => context.push('/review/${review.id}'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── 잉크 프로필 헤더 (인스타 프로필 스타일: 좌측 원 + 우측 정보) ──────────────
class _InkProfileHeader extends StatelessWidget {
  const _InkProfileHeader({required this.data});
  final InkModel data;

  @override
  Widget build(BuildContext context) {
    Color color;
    try {
      color = Color(
        int.parse('FF${data.hexColor.replaceAll('#', '')}', radix: 16),
      );
    } catch (e) {
      color = Colors.grey.shade300;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkDropCircle(color: color, size: 72),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.brand, style: AppTextStyles.labelMedium),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      data.name,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      data.inkTypeLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 별점 시스템 비활성화 — 평균 별점 표시 제거, 리뷰 개수만 표시
              // Row(
              //   mainAxisSize: MainAxisSize.min,
              //   children: [
              //     const Icon(Icons.star, color: Colors.amber, size: 14),
              //     const SizedBox(width: 2),
              //     Text(
              //       data.avgRating.toStringAsFixed(1),
              //       style: const TextStyle(
              //         fontSize: 13,
              //         fontWeight: FontWeight.w600,
              //         color: AppColors.textPrimary,
              //       ),
              //     ),
              //     const SizedBox(width: 6),
              //     Text(
              //       '· 리뷰 ${data.reviewCount}개',
              //       style: const TextStyle(
              //         fontSize: 13,
              //         color: AppColors.textSecondary,
              //       ),
              //     ),
              //   ],
              // ),
              if (data.reviewCount > 0)
                Text(
                  '리뷰 ${data.reviewCount}개',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                )
              else
                Text(
                  '아직 리뷰가 없어요',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 만년필 프로필 헤더 (인스타 프로필 스타일: 좌측 원형 사진 + 우측 정보) ──────
class _PenProfileHeader extends StatelessWidget {
  const _PenProfileHeader({required this.data});
  final PenModel data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _PenPhotoCircle(photoUrl: data.photoUrl, size: 72),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.brand, style: AppTextStyles.labelMedium),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      data.modelName,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      data.fillType,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (data.reviewCount > 0)
                Text(
                  '리뷰 ${data.reviewCount}개',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                )
              else
                Text(
                  '아직 리뷰가 없어요',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// 만년필 사진 원형 — 등록된 사진이 있으면 그대로, 없으면 아이콘 기본 이미지
class _PenPhotoCircle extends StatelessWidget {
  const _PenPhotoCircle({required this.photoUrl, this.size = 56});
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.chipBackground,
        alignment: Alignment.center,
        child: (photoUrl == null || photoUrl!.isEmpty)
            ? Icon(
                Icons.edit,
                color: AppColors.textSecondary,
                size: size * 0.4,
              )
            : CachedNetworkImage(
                imageUrl: photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.edit,
                  color: AppColors.textSecondary,
                  size: size * 0.4,
                ),
              ),
      ),
    );
  }
}

// ── 위시리스트 버튼 ────────────────────────────────────────────────────────
class _WishlistButton extends ConsumerWidget {
  const _WishlistButton({
    required this.type,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.hexColor,
  });
  final String type;
  final String productId;
  final String productName;
  final String brand;
  final String hexColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWishlisted =
        ref.watch(wishlistStatusProvider(productId)).valueOrNull ?? false;
    return IconButton(
      icon: Icon(
        isWishlisted ? Icons.favorite : Icons.favorite_border,
        color: isWishlisted ? Colors.redAccent : null,
      ),
      onPressed: () async {
        final added = await ref
            .read(wishlistActionsProvider)
            .toggle(
              type: type,
              productId: productId,
              productName: productName,
              brand: brand,
              hexColor: hexColor,
            );
        if (added != null && context.mounted) {
          showWishlistToast(context, added: added);
        }
      },
    );
  }
}

// ── 신고 버튼 ──────────────────────────────────────────────────────────────
class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.type,
    required this.productId,
    required this.targetName,
  });
  final String type;
  final String productId;
  final String targetName;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () => _showMenu(context),
    );
  }

  void _showMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text(
                '신고하기',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!ctx.mounted) return;
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl),
                      ),
                    ),
                    builder: (innerCtx) => _ReportSheet(
                      type: type,
                      productId: productId,
                      targetName: targetName,
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── 잉크 정보 수정 시트 ────────────────────────────────────────────────────
