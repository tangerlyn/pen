import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/providers/feed_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/review/review_feed_card.dart';
import '../../../shared/widgets/review/review_list_tile.dart';
import '../../home/widgets/feed_filter_bar.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/widgets/tap_scale.dart';

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

  Future<void> _markFollowingAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'following_last_seen', DateTime.now().millisecondsSinceEpoch);
    ref.invalidate(followingHasNewProvider);
  }

  void _scrollToTop() {
    final ns = _scrollKey.currentState;
    if (ns == null) return;
    if (ns.innerController.hasClients) {
      ns.innerController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    if (ns.outerController.hasClients) {
      ns.outerController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedProvider);
    final followingCount = ref.watch(currentUserProvider).valueOrNull?.followingCount ?? 0;
    final hasFollowings = followingCount > 0;
    final hasNewReviews = hasFollowings
        ? (ref.watch(followingHasNewProvider).valueOrNull ?? false)
        : false;

    // 팔로잉 없는데 팔로잉 탭이면 추천으로 리셋
    if (!hasFollowings && state.filter.feedType == '팔로잉') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(feedProvider.notifier).setFilter(
              state.filter.copyWith(feedType: '추천'),
            );
      });
    }

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
                if (show != _showScrollTop) setState(() => _showScrollTop = show);
              }
              return false;
            },
            child: NestedScrollView(
              key: _scrollKey,
              headerSliverBuilder: (context, _) => [
                if (widget.showAppBar)
                  SliverAppBar(
                    pinned: true,
                    title: const Text('리뷰',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    actions: [
                      IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => context.push('/search?type=review')),
                    ],
                  ),
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        if (hasFollowings)
                          Row(
                            children: ['추천', '팔로잉'].map((type) {
                              final isActive = state.filter.feedType == type;
                              final showDot =
                                  type == '팔로잉' && hasNewReviews && !isActive;
                              return Expanded(
                                child: TapScale(
                                  onTap: () {
                                    ref.read(feedProvider.notifier).setFilter(
                                          state.filter.copyWith(feedType: type),
                                        );
                                    if (type == '팔로잉') _markFollowingAsSeen();
                                  },
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Text(
                                              type,
                                              style: TextStyle(
                                                fontWeight: isActive
                                                    ? FontWeight.w700
                                                    : FontWeight.w400,
                                                color: isActive
                                                    ? AppColors.textPrimary
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                            if (showDot)
                                              Positioned(
                                                right: -8,
                                                top: 0,
                                                child: Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isActive)
                                        Container(height: 2, color: AppColors.primary)
                                      else
                                        const SizedBox(height: 2),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: FeedFilterBar(
                                filter: state.filter,
                                onFilterChanged: (f) => ref
                                    .read(feedProvider.notifier)
                                    .setFilter(f),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: IconButton(
                                icon: Icon(
                                  _isGridView
                                      ? Icons.view_list
                                      : Icons.grid_view,
                                  size: 22,
                                ),
                                onPressed: _toggleViewMode,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              body: state.isLoading
                  ? _isGridView
                      ? GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(10),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
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
                        child: _isGridView
                            ? GridView.builder(
                                padding: const EdgeInsets.all(10),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: state.reviews.length +
                                    (state.isLoadingMore ? 2 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= state.reviews.length) {
                                    return const ReviewGridSkeleton();
                                  }
                                  final review = state.reviews[index];
                                  return ReviewFeedCard(
                                    review: review,
                                    onTap: () =>
                                        context.push('/review/${review.id}'),
                                  );
                                },
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: state.reviews.length +
                                    (state.isLoadingMore ? 1 : 0),
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  if (index >= state.reviews.length) {
                                    return const SizedBox(
                                      height: 60,
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  }
                                  final review = state.reviews[index];
                                  return ReviewListTile(
                                    review: review,
                                    onTap: () =>
                                        context.push('/review/${review.id}'),
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
                  child: const Icon(Icons.keyboard_arrow_up, size: 22),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'review_write',
              onPressed: () => context.push('/write/review'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.camera_alt_outlined),
            ),
          ),
        ],
      ),
    );
  }
}
