import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/providers/feed_provider.dart';
import '../../../shared/widgets/review/review_feed_card.dart';
import '../../../shared/widgets/review/review_list_tile.dart';
import '../../home/widgets/feed_filter_bar.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/providers/providers.dart';

class ReviewFeedScreen extends ConsumerStatefulWidget {
  const ReviewFeedScreen({super.key, this.showAppBar = true});
  final bool showAppBar;

  @override
  ConsumerState<ReviewFeedScreen> createState() => _ReviewFeedScreenState();
}

class _ReviewFeedScreenState extends ConsumerState<ReviewFeedScreen> {
  final _scrollKey = GlobalKey<NestedScrollViewState>();
  bool _showScrollTop = false;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isGridView = prefs.getBool('review_grid_view') ?? true;
      });
    }
  }

  Future<void> _toggleViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isGridView = !_isGridView);
    await prefs.setBool('review_grid_view', _isGridView);
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
    final state = ref.watch(feedProvider);

    ref.listen<int?>(scrollToTopTabProvider, (_, next) {
      if (next == 1) {
        _scrollToTop();
        ref.read(scrollToTopTabProvider.notifier).state = null;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) {
                if (_showScrollTop) setState(() => _showScrollTop = false);
              } else if (n is ScrollEndNotification) {
                final ns = _scrollKey.currentState;
                final outer = ns?.outerController.hasClients == true
                    ? ns!.outerController.offset
                    : 0.0;
                final inner = ns?.innerController.hasClients == true
                    ? ns!.innerController.offset
                    : 0.0;
                final show = outer + inner > 100;
                if (show != _showScrollTop)
                  setState(() => _showScrollTop = show);
              }
              return false;
            },
            child: NestedScrollView(
              key: _scrollKey,
              floatHeaderSlivers: true,
              headerSliverBuilder: (context, _) => [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  toolbarHeight: widget.showAppBar ? kToolbarHeight : 0,
                  title: widget.showAppBar
                      ? const Text(
                          '리뷰',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        )
                      : null,
                  actions: widget.showAppBar
                      ? [
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () =>
                                context.push('/search?type=review'),
                          ),
                        ]
                      : null,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(44),
                    child: ColoredBox(
                      color: AppColors.surface,
                      child: Row(
                        children: [
                          Expanded(
                            child: FeedFilterBar(
                              filter: state.filter,
                              onFilterChanged: (f) =>
                                  ref.read(feedProvider.notifier).setFilter(f),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              icon: Icon(
                                _isGridView ? Icons.view_list : Icons.grid_view,
                                size: 22,
                              ),
                              onPressed: _toggleViewMode,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              body: state.isLoading
                  ? _isGridView
                        ? GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 1,
                                  mainAxisSpacing: 1,
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: 6,
                            itemBuilder: (_, _) => const ReviewGridSkeleton(),
                          )
                        : ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 5,
                            itemBuilder: (_, _) => const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ReviewListTileSkeleton(),
                                Divider(height: 1),
                              ],
                            ),
                          )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollEndNotification &&
                            notification.metrics.extentAfter < 200) {
                          ref.read(feedProvider.notifier).loadMore();
                        }
                        return false;
                      },
                      child: RefreshIndicator(
                        onRefresh: () => ref
                            .read(feedProvider.notifier)
                            .loadFeed(refresh: true),
                        child: Builder(
                          builder: (context) {
                            // 팔로잉 최근 게시글 + 전체 피드를 하나로 이어붙여
                            // 섹션 구분 없이 자연스럽게 이어지는 하나의 피드로 렌더링
                            final combined = [
                              ...state.followingRecent,
                              ...state.reviews,
                            ];
                            return CustomScrollView(
                              slivers: [
                                _isGridView
                                    ? SliverPadding(
                                        padding: EdgeInsets.zero,
                                        sliver: SliverGrid(
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                crossAxisSpacing: 1,
                                                mainAxisSpacing: 1,
                                                childAspectRatio: 0.85,
                                              ),
                                          delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                              if (index >= combined.length) {
                                                return const ReviewGridSkeleton();
                                              }
                                              final review = combined[index];
                                              return ReviewFeedCard(
                                                review: review,
                                                onTap: () => context.push(
                                                  '/review/${review.id}',
                                                ),
                                              );
                                            },
                                            childCount:
                                                combined.length +
                                                (state.isLoadingMore ? 2 : 0),
                                          ),
                                        ),
                                      )
                                    : SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            if (index >= combined.length) {
                                              return const SizedBox(
                                                height: 60,
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            }
                                            final review = combined[index];
                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ReviewListTile(
                                                  review: review,
                                                  onTap: () => context.push(
                                                    '/review/${review.id}',
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                              ],
                                            );
                                          },
                                          childCount:
                                              combined.length +
                                              (state.isLoadingMore ? 1 : 0),
                                        ),
                                      ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 16),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 80,
            child: AnimatedOpacity(
              opacity: _showScrollTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showScrollTop,
                child: FloatingActionButton.small(
                  heroTag: 'review_scroll_top',
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
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'review_write',
              onPressed: () => context.push('/write/review'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const StadiumBorder(),
              label: const Text(
                '리뷰 쓰기',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
