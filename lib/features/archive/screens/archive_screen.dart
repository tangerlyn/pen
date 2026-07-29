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

// 색상 계열 목록 — 이름 → 칩에 보여줄 대표 색상
const _colorFamilySwatches = {
  '빨강': Color(0xFFE53935),
  '주황': Color(0xFFFB8C00),
  '노랑': Color(0xFFFDD835),
  '초록': Color(0xFF43A047),
  '파랑': Color(0xFF1E88E5),
  '보라': Color(0xFF8E24AA),
  '검정': Color(0xFF2B2B2B),
};

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
      case 1:
        return _penScrollCtrl;
      default:
        return _inkScrollCtrl;
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
      ns!.outerController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (_activeScrollCtrl.hasClients) {
      _activeScrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
                if (show != _showScrollTop) {
                  setState(() => _showScrollTop = show);
                }
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
                SliverToBoxAdapter(child: _FilterRow(tabIndex: state.tabIndex)),
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

enum _ExpandedFilter { color, type }

class _FilterRow extends ConsumerStatefulWidget {
  const _FilterRow({required this.tabIndex});
  final int tabIndex;

  @override
  ConsumerState<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends ConsumerState<_FilterRow>
    with SingleTickerProviderStateMixin {
  _ExpandedFilter? _expanded;
  OverlayEntry? _overlayEntry;
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  );
  final _colorLink = LayerLink();
  final _typeLink = LayerLink();
  final _colorChipKey = GlobalKey();
  final _typeChipKey = GlobalKey();

  // 드롭다운이 열려있는 동안 임시로 들고 있는 선택값 — 완료/바깥 탭으로
  // 닫힐 때만 실제 필터(archiveProvider)에 반영해서, 고를 때마다 뒤의
  // 목록이 바로바로 바뀌지 않도록 함.
  List<String> _pendingColorFamilies = [];
  List<String> _pendingInkTypes = [];

  @override
  void dispose() {
    _overlayEntry?.remove();
    _animController.dispose();
    super.dispose();
  }

  void _commit(_ExpandedFilter filter) {
    final current = ref.read(archiveProvider).inkFilter;
    if (filter == _ExpandedFilter.color) {
      ref
          .read(archiveProvider.notifier)
          .setInkFilter(current.copyWith(colorFamilies: _pendingColorFamilies));
    } else {
      ref
          .read(archiveProvider.notifier)
          .setInkFilter(current.copyWith(inkTypes: _pendingInkTypes));
    }
  }

  void _togglePending(_ExpandedFilter filter, String value) {
    final list = filter == _ExpandedFilter.color
        ? _pendingColorFamilies
        : _pendingInkTypes;
    if (list.contains(value)) {
      list.remove(value);
    } else {
      list.add(value);
    }
    _overlayEntry?.markNeedsBuild();
  }

  void _clearPending(_ExpandedFilter filter) {
    if (filter == _ExpandedFilter.color) {
      _pendingColorFamilies = [];
    } else {
      _pendingInkTypes = [];
    }
    _overlayEntry?.markNeedsBuild();
  }

  Future<void> _closeDropdown() async {
    if (_overlayEntry == null) return;
    if (_expanded != null) _commit(_expanded!);
    await _animController.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _expanded = null);
  }

  void _toggleDropdown(_ExpandedFilter filter) {
    if (_expanded == filter) {
      _closeDropdown();
      return;
    }
    // 다른 필터가 열려있던 상태에서 전환하는 경우, 그동안 고른 값을
    // 버리지 않고 확정한 뒤 전환
    if (_expanded != null) _commit(_expanded!);
    _overlayEntry?.remove();
    _overlayEntry = null;
    _animController.value = 0;

    final current = ref.read(archiveProvider).inkFilter;
    _pendingColorFamilies = List.from(current.colorFamilies);
    _pendingInkTypes = List.from(current.inkTypes);

    final key = filter == _ExpandedFilter.color ? _colorChipKey : _typeChipKey;
    final link = filter == _ExpandedFilter.color ? _colorLink : _typeLink;
    final box = key.currentContext!.findRenderObject() as RenderBox;
    final chipSize = box.size;

    _overlayEntry = OverlayEntry(
      builder: (_) => _FilterDropdownOverlay(
        link: link,
        chipSize: chipSize,
        filter: filter,
        animation: _animController,
        pendingColorFamilies: _pendingColorFamilies,
        pendingInkTypes: _pendingInkTypes,
        onToggle: (value) => _togglePending(filter, value),
        onClear: () => _clearPending(filter),
        onClose: _closeDropdown,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _expanded = filter);
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(archiveProvider);
    final currentSort = widget.tabIndex == 0 ? state.inkSort : state.penSort;

    final sortChip = Padding(
      padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
      child: _FilterChipItem(
        label: currentSort.label,
        isActive: currentSort != ArchiveSortOption.defaultOrder,
        icon: Icons.sort,
        onTap: () =>
            _showSortPicker(context, ref, widget.tabIndex, currentSort),
      ),
    );

    if (widget.tabIndex != 0) {
      // 만년필/종이: 정렬 칩만 오른쪽 고정
      return SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [sortChip],
        ),
      );
    }

    // 잉크: 왼쪽 필터 칩(스크롤) + 오른쪽 정렬 칩 고정
    final colorSelected = state.inkFilter.colorFamilies;
    final typeSelected = state.inkFilter.inkTypes
        .map(_inkTypeValueToLabel)
        .toList();
    final colorLabel = colorSelected.isEmpty
        ? '색상 계열'
        : '색상 계열 : ${colorSelected.join(', ')}';
    final typeLabel = typeSelected.isEmpty
        ? '특수 속성'
        : '특수 속성 : ${typeSelected.join(', ')}';

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
              children: [
                CompositedTransformTarget(
                  link: _colorLink,
                  child: _FilterChipItem(
                    key: _colorChipKey,
                    label: colorLabel,
                    isActive: colorSelected.isNotEmpty,
                    icon: _expanded == _ExpandedFilter.color
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    onTap: () => _toggleDropdown(_ExpandedFilter.color),
                  ),
                ),
                const SizedBox(width: 8),
                CompositedTransformTarget(
                  link: _typeLink,
                  child: _FilterChipItem(
                    key: _typeChipKey,
                    label: typeLabel,
                    isActive: typeSelected.isNotEmpty,
                    icon: _expanded == _ExpandedFilter.type
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    onTap: () => _toggleDropdown(_ExpandedFilter.type),
                  ),
                ),
              ],
            ),
          ),
          sortChip,
        ],
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
                child: Text(
                  '정렬',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const Divider(height: 1),
            // 별점 시스템 비활성화 — '별점순' 정렬 옵션 숨김
            ...ArchiveSortOption.values
                .where((opt) => opt != ArchiveSortOption.rating)
                .map(
              (opt) => ListTile(
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
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── 색상 계열/특수 속성 드롭다운 — 칩이 그대로 헤더가 되어 아래로 패널이
// 이어지는 모양으로 펼쳐짐(토스 스타일). 둘 다 다중 선택, 하단 "완료"
// 버튼이나 바깥 탭으로 닫음. 헤더는 원래 칩과 같은 위치/크기로
// CompositedTransformFollower에 그려져서, 화면을 어둡게 하는 스크림 위에
// 떠 있는 것처럼 보이고 원래 칩과 끊김 없이 이어짐.
class _FilterDropdownOverlay extends StatelessWidget {
  const _FilterDropdownOverlay({
    required this.link,
    required this.chipSize,
    required this.filter,
    required this.animation,
    required this.pendingColorFamilies,
    required this.pendingInkTypes,
    required this.onToggle,
    required this.onClear,
    required this.onClose,
  });
  final LayerLink link;
  final Size chipSize;
  final _ExpandedFilter filter;
  final Animation<double> animation;
  final List<String> pendingColorFamilies;
  final List<String> pendingInkTypes;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;
  final VoidCallback onClose;

  static const _headerRadius = 20.0;
  static const _seamRadius = 0.0; // 헤더-패널 이음새는 완전 직각이어야 끊김 없이 이어짐
  static const _panelBottomRadius = 16.0;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final isColor = filter == _ExpandedFilter.color;
    // 완료/바깥 탭 전까지는 여기 담긴 값만 바뀌고, 실제 필터(뒤쪽 목록)에는
    // 반영되지 않음 — 고를 때마다 배경이 바뀌어 정신없던 문제 방지.
    final pending = isColor ? pendingColorFamilies : pendingInkTypes;
    final selectedLabels = isColor
        ? pending
        : pending.map(_inkTypeValueToLabel).toList();
    final headerText = selectedLabels.isEmpty
        ? (isColor ? '색상 계열' : '특수 속성')
        : '${isColor ? '색상 계열' : '특수 속성'} : ${selectedLabels.join(', ')}';

    return Stack(
      children: [
        // 바깥을 살짝 어둡게 — 탭하면 목록 닫힘(선택한 값 확정). 헤더+패널이
        // 그 위에 그려져 어두워지지 않은 채로 화면과 자연스럽게 이어짐.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: curved,
            builder: (_, _) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Container(
                color: Colors.black.withValues(alpha: 0.35 * curved.value),
              ),
            ),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              // 최대폭만 화면을 벗어나지 않도록 제한 — 최소폭을 열었을 때의
              // 칩 크기에 고정해두면, 예전에 선택해서 넓어졌던 칩을 다시 열어
              // "전체"로 줄여도 그 예전 폭 아래로는 안 줄어드는 문제가 있었음
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: IntrinsicWidth(
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(_headerRadius),
                      topRight: Radius.circular(_headerRadius),
                      bottomLeft: Radius.circular(_panelBottomRadius),
                      bottomRight: Radius.circular(_panelBottomRadius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 헤더 — 원래 칩과 같은 자리에서 시작, 선택 내용에 맞춰
                      // 가로로 실시간으로 늘어남. 탭하면 닫힘(선택 확정). 패널과
                      // 같은 색이라 이어붙는 것처럼 보임(그림자는 바깥에서 통일).
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          height: chipSize.height,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(_headerRadius),
                              topRight: Radius.circular(_headerRadius),
                              bottomLeft: Radius.circular(_seamRadius),
                              bottomRight: Radius.circular(_seamRadius),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                headerText,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_up,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 패널 — 헤더에 이어붙어 위에서 아래로 펼쳐짐
                      SizeTransition(
                        sizeFactor: curved,
                        axisAlignment: -1,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(_seamRadius),
                              topRight: Radius.circular(_seamRadius),
                              bottomLeft: Radius.circular(_panelBottomRadius),
                              bottomRight: Radius.circular(_panelBottomRadius),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // "전체" — 선택 해제(초기화) 역할을 겸함, 항상 맨 위
                              _dropdownRow(
                                label: '전체',
                                isSelected: pending.isEmpty,
                                onTap: onClear,
                              ),
                              ...(isColor
                                  ? _colorFamilySwatches.entries.map(
                                      (e) => _dropdownRow(
                                        label: e.key,
                                        swatch: e.value,
                                        isSelected: pending.contains(e.key),
                                        onTap: () => onToggle(e.key),
                                      ),
                                    )
                                  : _inkTypeLabels.map(
                                      (label) => _dropdownRow(
                                        label: label,
                                        isSelected: pending.contains(
                                          _inkTypeLabelToValue(label),
                                        ),
                                        onTap: () =>
                                            onToggle(_inkTypeLabelToValue(label)),
                                      ),
                                    )),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  6,
                                  12,
                                  12,
                                ),
                                child: SizedBox(
                                  // IntrinsicWidth 아래에서는 width: infinity를 넣으면
                                  // 고유 너비 계산이 무한대로 깨져서 드롭다운이 화면
                                  // 가운데로 튀어보이는 버그가 있었음 — height만 지정하고
                                  // 너비는 IntrinsicWidth가 강제하는 값을 그대로 따르게 둠
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed: onClose,
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      '완료',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownRow({
    required String label,
    Color? swatch,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            if (swatch != null) ...[
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    super.key,
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
            Icon(
              trailingIcon,
              size: 16,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
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
                        InkDropCircle(color: ink.inkColor, size: 56),
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
                          style: const TextStyle(
                            fontSize: 10,
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
