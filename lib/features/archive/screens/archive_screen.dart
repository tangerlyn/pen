import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/archive/add_product_bottom_sheet.dart';
import '../../../shared/widgets/center_toast.dart';
import '../providers/archive_provider.dart';
import '../widgets/pen_list_tile.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
import '../../../shared/widgets/tap_scale.dart';

// 색상 계열 목록
const _colorFamilies = [
  '레드', '오렌지', '옐로우', '그린', '시안', '블루', '퍼플', '핑크', '무채색', '기타',
];

// 특수 속성 목록 (레이블 → DB 값 매핑)
const _inkTypeLabels = ['일반', '펄', '테'];
const _inkTypeValues = ['normal', 'shimmer', 'sheen'];

String _inkTypeLabelToValue(String label) {
  final idx = _inkTypeLabels.indexOf(label);
  return idx >= 0 ? _inkTypeValues[idx] : label;
}

String _inkTypeValueToLabel(String value) {
  final idx = _inkTypeValues.indexOf(value);
  return idx >= 0 ? _inkTypeLabels[idx] : value;
}

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollKey = GlobalKey<NestedScrollViewState>();
  bool _showScrollTop = false;

  final _inkScrollCtrl = ScrollController();
  final _penScrollCtrl = ScrollController();

  ScrollController get _activeScrollCtrl {
    switch (_tabController.index) {
      case 1: return _penScrollCtrl;
      default: return _inkScrollCtrl;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(archiveProvider.notifier).setTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inkScrollCtrl.dispose();
    _penScrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    final ns = _scrollKey.currentState;
    if (ns?.outerController.hasClients == true) {
      ns!.outerController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    if (_activeScrollCtrl.hasClients) {
      _activeScrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(archiveProvider);

    return Scaffold(
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) {
                if (_showScrollTop) setState(() => _showScrollTop = false);
              } else if (n is ScrollEndNotification) {
                final show = n.metrics.pixels > 100;
                if (show != _showScrollTop) setState(() => _showScrollTop = show);
              }
              return false;
            },
            child: NestedScrollView(
              key: _scrollKey,
              headerSliverBuilder: (context, _) => [
                SliverAppBar(
                  pinned: true,
                  title: const Text('아카이브'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => context.push('/archive/search'),
                    ),
                  ],
                ),
                // 잉크/만년필 탭 — 스크롤 시 같이 올라감
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: '잉크'),
                        Tab(text: '만년필'),
                      ],
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                    ),
                  ),
                ),
                // 필터 버튼 — 스크롤 시 같이 올라감
                SliverToBoxAdapter(
                  child: _FilterRow(tabIndex: state.tabIndex),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _InkList(state: state, scrollController: _inkScrollCtrl),
                  _PenList(state: state, scrollController: _penScrollCtrl),
                ],
              ),
            ),
          ),
          // 맨 위로 버튼
          Positioned(
            right: 16,
            bottom: 16,
            child: AnimatedOpacity(
              opacity: _showScrollTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showScrollTop,
                child: FloatingActionButton.small(
                  heroTag: 'archive_scroll_top',
                  onPressed: _scrollToTop,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 3,
                  child: const Icon(Icons.keyboard_arrow_up, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.tabIndex});
  final int tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(archiveProvider);
    final currentSort = tabIndex == 0 ? state.inkSort : state.penSort;

    final sortChip = Padding(
      padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
      child: _FilterChipItem(
        label: currentSort.label,
        isActive: currentSort != ArchiveSortOption.defaultOrder,
        icon: Icons.sort,
        onTap: () => _showSortPicker(context, ref, tabIndex, currentSort),
      ),
    );

    if (tabIndex == 0) {
      // 잉크: 왼쪽 필터 칩(스크롤) + 오른쪽 정렬 칩 고정
      final colorLabel = state.inkFilter.colorFamilies.isEmpty
          ? '색상 계열'
          : state.inkFilter.colorFamilies.length == 1
              ? state.inkFilter.colorFamilies.first
              : '${state.inkFilter.colorFamilies.first} 외 ${state.inkFilter.colorFamilies.length - 1}';
      final typeLabel = state.inkFilter.inkTypes.isEmpty
          ? '특수 속성'
          : state.inkFilter.inkTypes.length == 1
              ? _inkTypeValueToLabel(state.inkFilter.inkTypes.first)
              : '${_inkTypeValueToLabel(state.inkFilter.inkTypes.first)} 외 ${state.inkFilter.inkTypes.length - 1}';

      return SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                children: [
                  _FilterChipItem(
                    label: colorLabel,
                    isActive: state.inkFilter.colorFamilies.isNotEmpty,
                    onTap: () => _showColorPicker(context, ref, state.inkFilter),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipItem(
                    label: typeLabel,
                    isActive: state.inkFilter.inkTypes.isNotEmpty,
                    onTap: () => _showInkTypePicker(context, ref, state.inkFilter),
                  ),
                ],
              ),
            ),
            sortChip,
          ],
        ),
      );
    }

    // 만년필/종이: 정렬 칩만 오른쪽 고정
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [sortChip],
      ),
    );
  }

  void _showSortPicker(
    BuildContext context,
    WidgetRef ref,
    int tabIndex,
    ArchiveSortOption current,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('정렬', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
            const Divider(height: 1),
            ...ArchiveSortOption.values.map((opt) => ListTile(
                  title: Text(opt.label),
                  trailing: current == opt
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    switch (tabIndex) {
                      case 0:
                        ref.read(archiveProvider.notifier).setInkSort(opt);
                      case 1:
                        ref.read(archiveProvider.notifier).setPenSort(opt);
                    }
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref, InkFilter current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MultiSelectBottomSheet(
        title: '색상 계열',
        options: _colorFamilies,
        selected: List.from(current.colorFamilies),
        onApply: (selected) {
          ref.read(archiveProvider.notifier).setInkFilter(
                current.copyWith(colorFamilies: selected),
              );
        },
      ),
    );
  }

  void _showInkTypePicker(BuildContext context, WidgetRef ref, InkFilter current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MultiSelectBottomSheet(
        title: '특수 속성',
        options: _inkTypeLabels,
        selected: current.inkTypes.map(_inkTypeValueToLabel).toList(),
        onApply: (selectedLabels) {
          ref.read(archiveProvider.notifier).setInkFilter(
                current.copyWith(
                  inkTypes: selectedLabels.map(_inkTypeLabelToValue).toList(),
                ),
              );
        },
      ),
    );
  }
}

// ── 다중 선택 바텀시트 ────────────────────────────────────────
class _MultiSelectBottomSheet extends StatefulWidget {
  const _MultiSelectBottomSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onApply,
  });
  final String title;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onApply;

  @override
  State<_MultiSelectBottomSheet> createState() => _MultiSelectBottomSheetState();
}

class _MultiSelectBottomSheetState extends State<_MultiSelectBottomSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  void _toggle(String item) {
    setState(() {
      if (_selected.contains(item)) {
        _selected.remove(item);
      } else {
        _selected.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.55,
      maxChildSize: 0.55,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (_selected.isNotEmpty)
                  TapScale(
                    onTap: () => setState(() => _selected.clear()),
                    child: const Text(
                      '초기화',
                      style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 옵션 목록
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: widget.options.length,
              itemBuilder: (_, i) {
                final item = widget.options[i];
                final isSelected = _selected.contains(item);
                return ListTile(
                  title: Text(
                    item,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : const Icon(Icons.radio_button_unchecked, color: AppColors.textTertiary),
                  onTap: () => _toggle(item),
                );
              },
            ),
          ),
          // 적용 버튼
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(_selected);
                  },
                  child: Text(
                    _selected.isEmpty ? '적용' : '${_selected.length}개 선택 · 적용',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final trailingIcon = icon ?? Icons.keyboard_arrow_down;
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.chipBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isActive ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 16, color: isActive ? Colors.white : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _InkList extends ConsumerWidget {
  const _InkList({required this.state, required this.scrollController});
  final ArchiveState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 항상 CustomScrollView를 반환 — 타입 변화로 인한 semantics assertion 방지
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        if (state.isLoading)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => const InkCircleSkeleton(),
                childCount: 12,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 20,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
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
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final ink = state.inks[i];
                  return RepaintBoundary(
                    child: TapScale(
                      onTap: () => context.push('/archive/ink/${ink.id}'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkDropCircle(color: ink.inkColor, size: 56),
                          const SizedBox(height: 6),
                          Text(
                            ink.name,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: state.inks.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 20,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: _ProductRequestFooter(tabLabel: '잉크'),
          ),
        ],
      ],
    );
  }
}

class _PenList extends ConsumerWidget {
  const _PenList({required this.state, required this.scrollController});
  final ArchiveState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 항상 CustomScrollView를 반환 — 타입 변화로 인한 semantics assertion 방지
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        if (state.isLoading)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PenListTileSkeleton(),
                  Divider(height: 1),
                ],
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
                    onTap: () => context.push('/archive/pen/${state.pens[i].id}'),
                  ),
                  const Divider(height: 1),
                ],
              ),
              childCount: state.pens.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: _ProductRequestFooter(tabLabel: '만년필'),
          ),
        ],
      ],
    );
  }
}

// ── 직접 등록 버튼 ────────────────────────────────────────────────────
class _ProductRequestFooter extends StatelessWidget {
  const _ProductRequestFooter({required this.tabLabel});
  final String tabLabel;

  String get _type {
    switch (tabLabel) {
      case '만년필': return 'pen';
      default: return 'ink';
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
          onAdded: (id, name) {
            showCenterToast(
              context,
              message: '$name 이(가) 등록됐어요!',
              icon: Icons.check_circle,
            );
          },
        ),
      ),
    );
  }
}


