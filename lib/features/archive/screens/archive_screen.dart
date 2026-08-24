import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/archive/add_product_bottom_sheet.dart';
import '../providers/archive_provider.dart';
import '../widgets/pen_list_tile.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../../shared/providers/providers.dart';

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

// 만년필 충전 방식 목록 — add_product_bottom_sheet.dart의 _kFillTypes와 동일
const _fillTypeLabels = ['카트리지·컨버터', '피스톤필러', '아이드로퍼', '진공'];

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
    super.dispose();
  }

  void _scrollToTop() {
    final ns = _scrollKey.currentState;
    if (ns == null) return;
    if (ns.innerController.hasClients) {
      ns.innerController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (ns.outerController.hasClients) {
      ns.outerController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(archiveProvider);

    ref.listen<int?>(scrollToTopTabProvider, (_, next) {
      if (next == 3) {
        _scrollToTop();
        ref.read(scrollToTopTabProvider.notifier).state = null;
      }
    });

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
              headerSliverBuilder: (context, _) {
                final tabBar = TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '잉크'),
                    Tab(text: '만년필'),
                  ],
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                );
                return [
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    pinned: false,
                    title: const Text('아카이브'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => context.push('/archive/search'),
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: Size.fromHeight(
                        tabBar.preferredSize.height + 44,
                      ),
                      child: Column(
                        children: [
                          // 잉크/만년필 탭 — 앱바와 함께 스크롤 시 접힘
                          ColoredBox(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: tabBar,
                          ),
                          // 필터 버튼 — 앱바와 함께 스크롤 시 접힘
                          _FilterRow(tabIndex: state.tabIndex),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _InkList(state: state),
                  _PenList(state: state),
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

enum _ExpandedFilter { color, type, brand, sort, fillType }

class _FilterRow extends ConsumerStatefulWidget {
  const _FilterRow({required this.tabIndex});
  final int tabIndex;

  @override
  ConsumerState<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends ConsumerState<_FilterRow>
    with SingleTickerProviderStateMixin {
  // 드롭다운이 열려있을 때만 칩 목록 맨 끝에 붙이는 보이지 않는 여유 스크롤 폭.
  // 항상 붙어있으면 사용자가 손으로 스와이프해서 그 빈 공간까지 무한정
  // 밀 수 있게 돼버리므로(칩이 하나도 안 보이는 상태까지), 드롭다운이
  // 닫혀있을 땐 0으로 둬서 평소엔 칩 목록 실제 길이만큼만 스크롤되게 함.
  double get _scrollReserveWidth => _expanded != null ? 400.0 : 0.0;

  _ExpandedFilter? _expanded;
  OverlayEntry? _overlayEntry;
  late final AnimationController _animController;
  final _colorLink = LayerLink();
  final _typeLink = LayerLink();
  final _brandLink = LayerLink();
  final _sortLink = LayerLink();
  final _fillTypeLink = LayerLink();
  final _colorChipKey = GlobalKey();
  final _typeChipKey = GlobalKey();
  final _brandChipKey = GlobalKey();
  final _sortChipKey = GlobalKey();
  final _fillTypeChipKey = GlobalKey();
  final _chipScrollController = ScrollController();
  // 열려있는 드롭다운(헤더+패널) 박스의 실제 렌더 크기를 재기 위한 키
  final _dropdownBoxKey = GlobalKey();

  // 드롭다운이 열려있는 동안 임시로 들고 있는 선택값 — 완료/바깥 탭으로
  // 닫힐 때만 실제 필터(archiveProvider)에 반영해서, 고를 때마다 뒤의
  // 목록이 바로바로 바뀌지 않도록 함.
  List<String> _pendingColorFamilies = [];
  List<String> _pendingInkTypes = [];
  List<String> _pendingBrands = [];
  List<String> _pendingFillTypes = [];

  @override
  void initState() {
    super.initState();
    // late final을 dispose()에서 처음 접근하면(드롭다운을 한 번도 안 열었을 때)
    // 이미 deactivate된 element로 vsync를 만들려다 크래시 나므로, 여기서 즉시 생성해둔다.
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _animController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _commit(_ExpandedFilter filter) {
    if (filter == _ExpandedFilter.sort) return; // 정렬은 탭 즉시 적용되므로 커밋할 게 없음
    if (filter == _ExpandedFilter.brand) {
      if (widget.tabIndex == 0) {
        final current = ref.read(archiveProvider).inkFilter;
        ref
            .read(archiveProvider.notifier)
            .setInkFilter(current.copyWith(brands: _pendingBrands));
      } else {
        final current = ref.read(archiveProvider).penFilter;
        ref
            .read(archiveProvider.notifier)
            .setPenFilter(current.copyWith(brands: _pendingBrands));
      }
      return;
    }
    if (filter == _ExpandedFilter.fillType) {
      final current = ref.read(archiveProvider).penFilter;
      ref
          .read(archiveProvider.notifier)
          .setPenFilter(current.copyWith(fillTypes: _pendingFillTypes));
      return;
    }
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
    final list = switch (filter) {
      _ExpandedFilter.color => _pendingColorFamilies,
      _ExpandedFilter.type => _pendingInkTypes,
      _ExpandedFilter.brand => _pendingBrands,
      _ExpandedFilter.fillType => _pendingFillTypes,
      _ExpandedFilter.sort => <String>[], // 정렬은 즉시 적용이라 호출되지 않음
    };
    if (list.contains(value)) {
      list.remove(value);
    } else {
      list.add(value);
    }
    _overlayEntry?.markNeedsBuild();
    // 선택이 늘어나 헤더 텍스트가 길어지면서 드롭다운이 화면 오른쪽 밖으로
    // 넘칠 수 있으므로, 다시 그려진 뒤 실제 크기를 재서 필요하면 보정한다.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _adjustScrollForOverflow(),
    );
  }

  void _clearPending(_ExpandedFilter filter) {
    switch (filter) {
      case _ExpandedFilter.color:
        _pendingColorFamilies = [];
      case _ExpandedFilter.type:
        _pendingInkTypes = [];
      case _ExpandedFilter.brand:
        _pendingBrands = [];
      case _ExpandedFilter.fillType:
        _pendingFillTypes = [];
      case _ExpandedFilter.sort:
        break; // 정렬은 즉시 적용이라 호출되지 않음
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

  void _toggleDropdown(
    _ExpandedFilter filter, {
    List<String> brandOptions = const [],
  }) {
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

    final inkCurrent = ref.read(archiveProvider).inkFilter;
    final penCurrent = ref.read(archiveProvider).penFilter;
    _pendingColorFamilies = List.from(inkCurrent.colorFamilies);
    _pendingInkTypes = List.from(inkCurrent.inkTypes);
    _pendingBrands = List.from(
      widget.tabIndex == 0 ? inkCurrent.brands : penCurrent.brands,
    );
    _pendingFillTypes = List.from(penCurrent.fillTypes);
    final currentSort = widget.tabIndex == 0
        ? ref.read(archiveProvider).inkSort
        : ref.read(archiveProvider).penSort;

    final key = switch (filter) {
      _ExpandedFilter.color => _colorChipKey,
      _ExpandedFilter.type => _typeChipKey,
      _ExpandedFilter.brand => _brandChipKey,
      _ExpandedFilter.sort => _sortChipKey,
      _ExpandedFilter.fillType => _fillTypeChipKey,
    };
    final link = switch (filter) {
      _ExpandedFilter.color => _colorLink,
      _ExpandedFilter.type => _typeLink,
      _ExpandedFilter.brand => _brandLink,
      _ExpandedFilter.sort => _sortLink,
      _ExpandedFilter.fillType => _fillTypeLink,
    };
    final box = key.currentContext!.findRenderObject() as RenderBox;
    final chipSize = box.size;
    // 최대 폭은 화면 좌우 여백만 뺀 넉넉한 값으로 고정 — 칩 위치에 따라
    // 폭을 줄이는 대신, 내용이 길어져서 화면 밖으로 넘치려 하면
    // _adjustScrollForOverflow()가 칩 목록 전체를 왼쪽으로 밀어서 맞춘다.
    final screenWidth = MediaQuery.of(context).size.width;
    final maxDropdownWidth = screenWidth - 24;

    _overlayEntry = OverlayEntry(
      builder: (_) => _FilterDropdownOverlay(
        boxKey: _dropdownBoxKey,
        link: link,
        chipSize: chipSize,
        maxWidth: maxDropdownWidth,
        filter: filter,
        animation: _animController,
        pendingColorFamilies: _pendingColorFamilies,
        pendingInkTypes: _pendingInkTypes,
        pendingBrands: _pendingBrands,
        pendingFillTypes: _pendingFillTypes,
        brandOptions: brandOptions,
        currentSort: currentSort,
        onToggle: (value) => _togglePending(filter, value),
        onClear: () => _clearPending(filter),
        onSelectSort: (opt) {
          switch (widget.tabIndex) {
            case 0:
              ref.read(archiveProvider.notifier).setInkSort(opt);
            case 1:
              ref.read(archiveProvider.notifier).setPenSort(opt);
          }
          _closeDropdown();
        },
        onClose: _closeDropdown,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _expanded = filter);
    _animController.forward(from: 0);
    // 다시 열었을 때 이미 선택된 값들 때문에 헤더가 처음부터 넓게
    // 시작하는 경우도 있으므로, 연 직후에도 한 번 확인한다.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _adjustScrollForOverflow(),
    );
  }

  /// 드롭다운(헤더+패널)이 실제로 그려진 뒤, 화면 오른쪽 경계를 넘지 않는
  /// 선에서 필요한 스크롤 위치를 매번 절대값으로 다시 계산해서 맞춘다.
  /// (예전엔 "현재 스크롤 + 넘친 만큼"으로 매번 더하기만 해서, 서로 다른
  /// 칩을 열고 닫을 때마다 스크롤이 누적되어 계속 오른쪽으로 밀려버렸음 —
  /// 항상 절대 위치로 계산하면 필요 없을 땐 자연스럽게 원래 자리로도 돌아옴)
  /// CompositedTransformFollower가 칩 위치를 실시간으로 따라가므로,
  /// 칩 목록이 스크롤되면 드롭다운도 같이 따라 움직인다.
  void _adjustScrollForOverflow() {
    if (!mounted || _overlayEntry == null) return;
    if (!_chipScrollController.hasClients) return;
    final box =
        _dropdownBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    const rightBoundaryMargin = 12.0; // 화면 오른쪽 끝에 둘 여유 경계
    final screenWidth = MediaQuery.of(context).size.width;
    final currentOffset = _chipScrollController.offset;
    final visibleLeft = box.localToGlobal(Offset.zero).dx;
    // 스크롤이 0이었다면 이 칩(드롭다운)이 원래 있었을 위치
    final naturalLeft = visibleLeft + currentOffset;
    final dropdownWidth = box.size.width;

    final idealOffset =
        (naturalLeft + dropdownWidth - (screenWidth - rightBoundaryMargin))
            .clamp(0.0, _chipScrollController.position.maxScrollExtent);
    if ((idealOffset - currentOffset).abs() < 1) return; // 이미 적절한 위치

    _chipScrollController.animateTo(
      idealOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(archiveProvider);
    final currentSort = widget.tabIndex == 0 ? state.inkSort : state.penSort;
    final brandOptions =
        ref
            .watch(widget.tabIndex == 0 ? inkBrandsProvider : penBrandsProvider)
            .valueOrNull ??
        [];

    final sortChip = CompositedTransformTarget(
      link: _sortLink,
      child: _FilterChipItem(
        key: _sortChipKey,
        label: currentSort.label,
        isActive: currentSort != ArchiveSortOption.defaultOrder,
        icon: _expanded == _ExpandedFilter.sort
            ? Icons.keyboard_arrow_up
            : Icons.keyboard_arrow_down,
        onTap: () => _toggleDropdown(_ExpandedFilter.sort),
      ),
    );

    if (widget.tabIndex != 0) {
      // 만년필: 브랜드 필터 칩 + 충전방식 필터 칩 + 정렬 칩, 함께 좌우 스크롤
      final penBrandSelected = state.penFilter.brands;
      final penBrandLabel = penBrandSelected.isEmpty
          ? '브랜드'
          : '브랜드 : ${penBrandSelected.join(', ')}';
      final penFillTypeSelected = state.penFilter.fillTypes;
      final penFillTypeLabel = penFillTypeSelected.isEmpty
          ? '충전방식'
          : '충전방식 : ${penFillTypeSelected.join(', ')}';
      return SizedBox(
        height: 44,
        child: ListView(
          controller: _chipScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          children: [
            CompositedTransformTarget(
              link: _brandLink,
              child: _FilterChipItem(
                key: _brandChipKey,
                label: penBrandLabel,
                isActive: penBrandSelected.isNotEmpty,
                icon: _expanded == _ExpandedFilter.brand
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                onTap: () => _toggleDropdown(
                  _ExpandedFilter.brand,
                  brandOptions: brandOptions,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CompositedTransformTarget(
              link: _fillTypeLink,
              child: _FilterChipItem(
                key: _fillTypeChipKey,
                label: penFillTypeLabel,
                isActive: penFillTypeSelected.isNotEmpty,
                icon: _expanded == _ExpandedFilter.fillType
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                onTap: () => _toggleDropdown(_ExpandedFilter.fillType),
              ),
            ),
            const SizedBox(width: 8),
            sortChip,
            // 스크롤 여유 공간 — 칩이 몇 개 없어서 목록 자체가 스크롤할 폭이
            // 부족하면(maxScrollExtent가 작으면), 드롭다운이 화면 밖으로
            // 넘칠 때 _adjustScrollForOverflow가 왼쪽으로 밀 공간이 없어서
            // 보정이 부족한 채로 끝나버림 — 항상 충분히 밀 수 있도록 확보
            SizedBox(width: _scrollReserveWidth),
          ],
        ),
      );
    }

    // 잉크: 색상 계열/특수 속성/브랜드/정렬 칩, 함께 좌우 스크롤
    final colorSelected = state.inkFilter.colorFamilies;
    final typeSelected = state.inkFilter.inkTypes
        .map(_inkTypeValueToLabel)
        .toList();
    final brandSelected = state.inkFilter.brands;
    final colorLabel = colorSelected.isEmpty
        ? '색상 계열'
        : '색상 계열 : ${colorSelected.join(', ')}';
    final typeLabel = typeSelected.isEmpty
        ? '특수 속성'
        : '특수 속성 : ${typeSelected.join(', ')}';
    final brandLabel = brandSelected.isEmpty
        ? '브랜드'
        : '브랜드 : ${brandSelected.join(', ')}';

    return SizedBox(
      height: 44,
      child: ListView(
        controller: _chipScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          const SizedBox(width: 8),
          CompositedTransformTarget(
            link: _brandLink,
            child: _FilterChipItem(
              key: _brandChipKey,
              label: brandLabel,
              isActive: brandSelected.isNotEmpty,
              icon: _expanded == _ExpandedFilter.brand
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              onTap: () => _toggleDropdown(
                _ExpandedFilter.brand,
                brandOptions: brandOptions,
              ),
            ),
          ),
          const SizedBox(width: 8),
          sortChip,
          // 스크롤 여유 공간 — 칩이 몇 개 없어서 목록 자체가 스크롤할 폭이
          // 부족하면(maxScrollExtent가 작으면), 드롭다운이 화면 밖으로
          // 넘칠 때 _adjustScrollForOverflow가 왼쪽으로 밀 공간이 없어서
          // 보정이 부족한 채로 끝나버림 — 항상 충분히 밀 수 있도록 확보
          SizedBox(width: _scrollReserveWidth),
        ],
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
    required this.boxKey,
    required this.link,
    required this.chipSize,
    required this.maxWidth,
    required this.filter,
    required this.animation,
    required this.pendingColorFamilies,
    required this.pendingInkTypes,
    required this.pendingBrands,
    required this.pendingFillTypes,
    required this.brandOptions,
    required this.currentSort,
    required this.onToggle,
    required this.onClear,
    required this.onSelectSort,
    required this.onClose,
  });
  final GlobalKey boxKey;
  final LayerLink link;
  final Size chipSize;
  final double maxWidth;
  final _ExpandedFilter filter;
  final Animation<double> animation;
  final List<String> pendingColorFamilies;
  final List<String> pendingInkTypes;
  final List<String> pendingBrands;
  final List<String> pendingFillTypes;
  final List<String> brandOptions;
  final ArchiveSortOption currentSort;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;
  final ValueChanged<ArchiveSortOption> onSelectSort;
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
    final isType = filter == _ExpandedFilter.type;
    final isBrand = filter == _ExpandedFilter.brand;
    final isSort = filter == _ExpandedFilter.sort;
    final isFillType = filter == _ExpandedFilter.fillType;
    // 완료/바깥 탭 전까지는 여기 담긴 값만 바뀌고, 실제 필터(뒤쪽 목록)에는
    // 반영되지 않음 — 고를 때마다 배경이 바뀌어 정신없던 문제 방지.
    // (정렬은 다중 선택이 아니라 탭하면 바로 적용되므로 pending 자체가 없음)
    final pending = isColor
        ? pendingColorFamilies
        : isType
        ? pendingInkTypes
        : isBrand
        ? pendingBrands
        : isFillType
        ? pendingFillTypes
        : const <String>[];
    final selectedLabels = isType
        ? pending.map(_inkTypeValueToLabel).toList()
        : pending;
    final filterLabel = isColor
        ? '색상 계열'
        : (isType ? '특수 속성' : (isFillType ? '충전방식' : '브랜드'));
    final headerText = isSort
        ? currentSort.label
        : (selectedLabels.isEmpty
              ? filterLabel
              : '$filterLabel : ${selectedLabels.join(', ')}');

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
              // 최대폭은 화면 좌우 여백만 뺀 값 — 실제로 화면 밖으로 넘치는지는
              // 렌더링된 뒤 boxKey로 재서 판단하고, 넘치면 폭을 줄이는 대신
              // _FilterRowState._adjustScrollForOverflow()가 칩 목록 전체를
              // 왼쪽으로 스크롤해서 화면 안으로 당겨온다.
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: IntrinsicWidth(
                child: Container(
                  key: boxKey,
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
                    // 기본값(center)이면 헤더가 패널보다 좁을 때(예: "브랜드"처럼
                    // 짧은 라벨) Column이 헤더를 가운데로 밀어서 글씨가 왼쪽이
                    // 아니라 중앙에 떠 보이는 문제가 있었음 — stretch로 헤더도
                    // 패널과 같은 폭을 꽉 채우게 해서 텍스트가 항상 왼쪽에 붙게 함
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                style: AppTextStyles.labelMedium.copyWith(
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
                              if (isSort)
                                // 정렬은 단일 선택 — 탭하면 바로 적용되고 닫힘.
                                // "전체"/"완료" 없이 옵션 목록만 보여줌.
                                ...ArchiveSortOption.values
                                    .where(
                                      (opt) => opt != ArchiveSortOption.rating,
                                    )
                                    .map(
                                      (opt) => _dropdownRow(
                                        label: opt.label,
                                        isSelected: currentSort == opt,
                                        onTap: () => onSelectSort(opt),
                                      ),
                                    )
                              else ...[
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
                                    : isType
                                    ? _inkTypeLabels.map(
                                        (label) => _dropdownRow(
                                          label: label,
                                          isSelected: pending.contains(
                                            _inkTypeLabelToValue(label),
                                          ),
                                          onTap: () => onToggle(
                                            _inkTypeLabelToValue(label),
                                          ),
                                        ),
                                      )
                                    : isFillType
                                    ? _fillTypeLabels.map(
                                        (label) => _dropdownRow(
                                          label: label,
                                          isSelected: pending.contains(label),
                                          onTap: () => onToggle(label),
                                        ),
                                      )
                                    : brandOptions.map(
                                        (brand) => _dropdownRow(
                                          label: brand,
                                          isSelected: pending.contains(brand),
                                          onTap: () => onToggle(brand),
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                style: AppTextStyles.titleSmall.copyWith(
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          // 조건을 선택했을 때만 배경을 채워 강조 — 선택 없으면 글씨만 보임
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isActive ? Colors.white : AppColors.textPrimary,
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
