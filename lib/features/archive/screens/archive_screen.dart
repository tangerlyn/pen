import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/archive/add_product_bottom_sheet.dart';
import '../providers/archive_provider.dart';
import '../controllers/archive_filter_draft_controller.dart';
import '../widgets/pen_list_tile.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../../shared/providers/providers.dart';
part '../widgets/archive_filter_widgets.dart';
part '../widgets/archive_product_lists.dart';

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
              floatHeaderSlivers: true,
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
                          ColoredBox(
                            color: AppColors.surface,
                            child: _FilterRow(tabIndex: state.tabIndex),
                          ),
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
                  shape: const StadiumBorder(),
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
