part of '../screens/ink_book_detail_screen.dart';

class _DetailPage extends ConsumerWidget {
  const _DetailPage({
    required this.entry,
    required this.uid,
    required this.bookId,
    required this.shape,
    required this.onDeleted,
  });
  final InkChartModel entry;
  final String uid;
  final String bookId;
  final InkSwatchShape shape;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenW = MediaQuery.of(context).size.width;
    final dateStr = DateFormat('yyyy년 M월 d일').format(entry.createdAt);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: screenW * 0.68,
              child: AspectRatio(
                aspectRatio: 1.0,
                child: InkShapeClip(
                  shape: shape,
                  child: CachedNetworkImage(
                    imageUrl: entry.photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AppColors.chipBackground),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.chipBackground,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(height: 1.5, color: AppColors.divider),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.brand,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.inkName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    dateStr,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              if (entry.memo.isNotEmpty ||
                  (entry.contentBlocks?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '메모',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkMemoContent(entry: entry),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 빈 상태 ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE7D6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.water_drop_outlined,
              size: 44,
              color: Color(0xFFB8A98A),
            ),
          ),
          const SizedBox(height: 20),
          const Text('아직 잉크가 없어요', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            '+ 버튼으로 첫 번째 잉크를 추가해보세요',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => context.push('/ink-chart/$bookId/add'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('잉크 추가'),
          ),
        ],
      ),
    );
  }
}

// ── 공책 이름 변경 바텀시트 ────────────────────────────────────────────────

