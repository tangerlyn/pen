import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_chart_model.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../mypage/widgets/ink_swatch_shape.dart';
import '../providers/my_records_provider.dart';

/// 스와치 사진을 사용자가 고른 모양으로 클리핑. 사진이 없으면 빈 칸.
class SwatchThumbnail extends StatelessWidget {
  const SwatchThumbnail({super.key, required this.entry, required this.shape});
  final InkChartModel entry;
  final InkSwatchShape shape;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '${entry.displayName} 스와치',
      child: AspectRatio(
        aspectRatio: 1,
        child: InkShapeClip(
          shape: shape,
          child: entry.photoUrl.isEmpty
              ? const ColoredBox(color: AppColors.chipBackground)
              : CachedNetworkImage(
                  imageUrl: entry.photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(color: AppColors.chipBackground),
                  errorWidget: (_, _, _) => const ColoredBox(color: AppColors.chipBackground),
                ),
        ),
      ),
    );
  }
}

/// 컬렉션 그리드 — 3열, 스와치 + 잉크 이름
class RecordGrid extends StatelessWidget {
  const RecordGrid({
    super.key,
    required this.records,
    required this.shape,
    required this.onTap,
  });

  final List<InkRecord> records;
  final InkSwatchShape shape;
  final ValueChanged<InkRecord> onTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: AppSpacing.pagePadding,
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.lg,
          childAspectRatio: 0.72,
        ),
        itemCount: records.length,
        itemBuilder: (_, i) {
          final r = records[i];
          return TapScale(
            onTap: () => onTap(r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwatchThumbnail(entry: r.entry, shape: shape),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  r.entry.inkName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge,
                ),
                if (r.entry.brand.isNotEmpty)
                  Text(
                    r.entry.brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 타임라인 — 월별로 묶어 기록 날짜 최신순
class RecordTimeline extends StatelessWidget {
  const RecordTimeline({
    super.key,
    required this.records,
    required this.shape,
    required this.onTap,
  });

  final List<InkRecord> records;
  final InkSwatchShape shape;
  final ValueChanged<InkRecord> onTap;

  @override
  Widget build(BuildContext context) {
    final items = <Object>[]; // String(월 헤더) 또는 InkRecord
    String? lastMonth;
    for (final r in records) {
      final d = r.entry.recordDate;
      final month = '${d.year}년 ${d.month}월';
      if (month != lastMonth) {
        items.add(month);
        lastMonth = month;
      }
      items.add(r);
    }

    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xs,
            ),
            child: Text(item, style: AppTextStyles.sectionTitle),
          );
        }
        final r = item as InkRecord;
        final e = r.entry;
        final d = e.recordDate;
        final details = [e.penName, e.nibSize, e.paperName].whereType<String>().join(' · ');
        return InkWell(
          onTap: () => onTap(r),
          child: Padding(
            padding: AppSpacing.listItemPadding,
            child: Row(
              children: [
                SizedBox(width: 56, child: SwatchThumbnail(entry: e, shape: shape)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.displayName, style: AppTextStyles.titleSmall),
                      if (details.isNotEmpty)
                        Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMedium,
                        ),
                      Text(
                        '${d.month}월 ${d.day}일 · ${r.book.name}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 기록이 하나도 없을 때 — 첫 스와치 기록 안내
class RecordEmptyState extends StatelessWidget {
  const RecordEmptyState({
    super.key,
    required this.onRecord,
    required this.onBrowseArchive,
    required this.onDiscover,
  });

  final VoidCallback onRecord;
  final VoidCallback onBrowseArchive;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.water_drop_outlined, size: 56, color: AppColors.primary),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            '첫 스와치를 기록해보세요',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '종이에 잉크를 칠하고 사진을 찍어두면\n나만의 잉크 아카이브가 쌓여요',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            onPressed: onRecord,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              backgroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('스와치 기록하기'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onBrowseArchive,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            icon: const Icon(Icons.book_outlined),
            label: const Text('아카이브 둘러보기'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onDiscover,
            child: const Text('다른 사람들의 리뷰 구경하기'),
          ),
        ],
      ),
    );
  }
}
