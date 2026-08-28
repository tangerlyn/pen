part of '../screens/archive_screen.dart';

class _InkList extends ConsumerWidget {
  const _InkList({required this.state});
  final ArchiveState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 항상 CustomScrollView를 반환 — 타입 변화로 인한 semantics assertion 방지
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 300) {
          ref.read(archiveProvider.notifier).loadMore();
        }
        return false;
      },
      child: CustomScrollView(
      key: const PageStorageKey('archive_ink_list'),
      slivers: [
        if (state.isLoading)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => const InkCircleSkeleton(),
                childCount: 12,
              ),
              // 고정 4열 대신 셀 최대 폭을 지정 — 좁은 폰에선 4열(기존과 동일),
              // 넓은 화면에선 열이 늘어나 셀이 지나치게 커지지 않는다.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 95,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
            ),
          )
        else if (state.inks.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('잉크가 없습니다.'),
                SizedBox(height: 16),
                _ProductRequestFooter(tabLabel: '잉크'),
              ],
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final ink = state.inks[i];
                return RepaintBoundary(
                  child: TapScale(
                    onTap: () => context.push('/archive/ink/${ink.id}'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _InkDropCircleWithReviewBadge(
                          color: ink.inkColor,
                          reviewCount: ink.reviewCount,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ink.brand,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          ink.name,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: state.inks.length),
              // 고정 4열 대신 셀 최대 폭을 지정 — 좁은 폰에선 4열(기존과 동일),
              // 넓은 화면에선 열이 늘어나 셀이 지나치게 커지지 않는다.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 95,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
            ),
          ),
          if (state.isLoadingMoreInks)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: _ProductRequestFooter(tabLabel: '잉크'),
          ),
        ],
        ],
      ),
    );
  }
}

// 잉크 원 우측 하단에 리뷰 개수 뱃지 — 리뷰가 하나도 없으면 숨기고,
// 100개 이상이면 뱃지가 너무 길어지지 않게 "99+"로 잘라서 보여준다.
class _InkDropCircleWithReviewBadge extends StatelessWidget {
  const _InkDropCircleWithReviewBadge({
    required this.color,
    required this.reviewCount,
  });
  final Color color;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkDropCircle(color: color, size: 56),
          if (reviewCount > 0)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  reviewCount > 99 ? '99+' : '$reviewCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PenList extends ConsumerWidget {
  const _PenList({required this.state});
  final ArchiveState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 항상 CustomScrollView를 반환 — 타입 변화로 인한 semantics assertion 방지
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 300) {
          ref.read(archiveProvider.notifier).loadMore();
        }
        return false;
      },
      child: CustomScrollView(
      key: const PageStorageKey('archive_pen_list'),
      slivers: [
        if (state.isLoading)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [PenListTileSkeleton(), Divider(height: 1)],
              ),
              childCount: 6,
            ),
          )
        else if (state.pens.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('만년필이 없습니다.'),
                SizedBox(height: 16),
                _ProductRequestFooter(tabLabel: '만년필'),
              ],
            ),
          )
        else ...[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PenListTile(
                    pen: state.pens[i],
                    onTap: () =>
                        context.push('/archive/pen/${state.pens[i].id}'),
                  ),
                  const Divider(height: 1),
                ],
              ),
              childCount: state.pens.length,
            ),
          ),
          if (state.isLoadingMorePens)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: _ProductRequestFooter(tabLabel: '만년필'),
          ),
        ],
        ],
      ),
    );
  }
}

// ── 직접 등록 버튼 ────────────────────────────────────────────────────
class _ProductRequestFooter extends StatelessWidget {
  const _ProductRequestFooter({required this.tabLabel});
  final String tabLabel;

  String get _type {
    switch (tabLabel) {
      case '만년필':
        return 'pen';
      default:
        return 'ink';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextButton.icon(
        icon: const Icon(Icons.add_circle_outline),
        label: Text('새 $tabLabel 직접 등록하기'),
        onPressed: () => showAddProductSheet(
          context,
          initialType: _type,
          navigateToDetailOnSuccess: true,
        ),
      ),
    );
  }
}
