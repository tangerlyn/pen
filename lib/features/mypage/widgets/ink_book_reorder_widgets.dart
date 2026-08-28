part of '../screens/ink_book_detail_screen.dart';

Widget _sheetHandle({double topPadding = 6}) {
  return Container(
    margin: EdgeInsets.only(top: topPadding, bottom: 4),
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: const Color(0xFFD4C5A9),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

// ── 공책 노트 페이지 렌더링은 widgets/notebook_page.dart로 이동
// (읽기 전용 화면과 동일한 코드를 공유해 소유자가 설정한 모양 그대로 보이도록 함) ──

// ── 스와치 카드 ──────────────────────────────────────────────────────────

class _SwatchCard extends ConsumerWidget {
  const _SwatchCard({
    required this.entry,
    required this.uid,
    required this.bookId,
    required this.shape,
    required this.allEntries,
    required this.absoluteIndex,
    required this.onLongPress,
  });
  final InkChartModel entry;
  final String uid;
  final String bookId;
  final InkSwatchShape shape;
  final List<InkChartModel> allEntries;
  final int absoluteIndex;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: InkShapeClip(
              shape: shape,
              child: CachedNetworkImage(
                imageUrl: entry.photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFFD4C5A9)),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFD4C5A9),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                Text(
                  entry.brand,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                Text(
                  entry.inkName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: _DetailSheet(
          charts: allEntries,
          initialIndex: absoluteIndex,
          uid: uid,
          bookId: bookId,
          shape: shape,
        ),
      ),
    );
  }
}

// ── 드래그 재정렬 뷰 ───────────────────────────────────────────────────────

class _ReorderView extends ConsumerWidget {
  const _ReorderView({
    required this.entries,
    required this.uid,
    required this.bookId,
    required this.shape,
    required this.onReorder,
  });
  final List<InkChartModel> entries;
  final String uid;
  final String bookId;
  final InkSwatchShape shape;
  final Future<void> Function(List<InkChartModel>) onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutableList = [...entries];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFEDE7D6),
          child: Row(
            children: [
              const Icon(
                Icons.drag_indicator,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '드래그해서 순서를 변경하세요',
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableGridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
            childAspectRatio: 0.65,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 80),
            onReorder: (oldIdx, newIdx) {
              final item = mutableList.removeAt(oldIdx);
              mutableList.insert(newIdx, item);
              onReorder(mutableList);
            },
            children: mutableList
                .asMap()
                .entries
                .map(
                  (me) => _ReorderCard(
                    key: ValueKey(me.value.id),
                    entry: me.value,
                    shape: shape,
                    index: me.key,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ReorderCard extends StatelessWidget {
  const _ReorderCard({
    super.key,
    required this.entry,
    required this.shape,
    required this.index,
  });
  final InkChartModel entry;
  final InkSwatchShape shape;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: Stack(
            children: [
              InkShapeClip(
                shape: shape,
                child: CachedNetworkImage(
                  imageUrl: entry.photoUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFFD4C5A9)),
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFFD4C5A9)),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          entry.inkName,
          style: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── 잉크 상세 바텀시트 ────────────────────────────────────────────────────

