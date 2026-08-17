import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/home_discovery_provider.dart';
import '../providers/notification_provider.dart';
import '../../community/providers/community_provider.dart';
import '../../../shared/widgets/community/post_card.dart';
import '../../../shared/widgets/review/review_feed_card.dart';
import '../../../data/models/ink_model.dart';
import '../../../data/models/pen_model.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../../shared/providers/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  bool _showScrollTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final show = _scrollController.offset > 300;
      if (show != _showScrollTop) setState(() => _showScrollTop = show);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showWriteModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/write/review');
                },
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('리뷰 작성', style: AppTextStyles.titleMedium),
                subtitle: const Text(
                  '내가 사용한 잉크·펜·종이를 기록해요',
                  style: AppTextStyles.labelMedium,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.sm,
                ),
              ),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/community/write');
                },
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.article_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('커뮤니티 글쓰기', style: AppTextStyles.titleMedium),
                subtitle: const Text(
                  '자유게시판에 이야기를 나눠요',
                  style: AppTextStyles.labelMedium,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.sm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(homeLatestReviewsProvider);
    ref.invalidate(homePopularInksProvider);
    ref.invalidate(homePopularPensProvider);
    ref.invalidate(filteredPostsProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(scrollToTopTabProvider, (_, next) {
      if (next == 0) {
        if (_scrollController.hasClients) _scrollToTop();
        ref.read(scrollToTopTabProvider.notifier).state = null;
      }
    });
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  centerTitle: true,
                  title: const Text(
                    '펜귄',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => context.push('/search?type=all'),
                    ),
                    _NotificationBell(),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      _LatestReviewsSection(),
                      _PopularInksSection(),
                      _CommunitySection(),
                      _PopularPensSection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 스크롤 탑 버튼
          Positioned(
            right: AppSpacing.lg,
            bottom: 80,
            child: AnimatedOpacity(
              opacity: _showScrollTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showScrollTop,
                child: FloatingActionButton.small(
                  heroTag: 'home_scroll_top',
                  onPressed: _scrollToTop,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 3,
                  child: const Icon(Icons.keyboard_arrow_up, size: 22),
                ),
              ),
            ),
          ),
          // 글쓰기 FAB
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: FloatingActionButton(
              heroTag: 'home_write',
              onPressed: () => _showWriteModal(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 섹션 공통 헤더 ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onMore,
    this.topPadding = AppSpacing.section,
  });
  final String title;
  final VoidCallback onMore;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        topPadding,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          const Spacer(),
          TextButton(
            onPressed: onMore,
            style: AppButtonStyles.ghost,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('더보기', style: AppTextStyles.labelMedium),
                Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 최신 리뷰 섹션 ──────────────────────────────────────────────────────────

class _LatestReviewsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(homeLatestReviewsProvider);
    // 화면 폭에 비례한 카드 너비 — 좁은 폰에서도 다음 카드가 살짝 보이고,
    // 넓은 폰/기기에서 카드가 지나치게 작아 보이지 않도록 상하한을 둔다.
    final cardWidth = (MediaQuery.of(context).size.width * 0.42).clamp(
      140.0,
      190.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: '최신 리뷰',
          topPadding: AppSpacing.sm,
          onMore: () => context.go('/review'),
        ),
        reviewsAsync.when(
          loading: () => SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.pagePadding,
              itemCount: 4,
              itemBuilder: (_, _) => HomeReviewCardSkeleton(width: cardWidth),
            ),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (reviews) {
            if (reviews.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.pagePadding,
                itemCount: reviews.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: SizedBox(
                    width: cardWidth,
                    child: ReviewFeedCard(
                      review: reviews[i],
                      onTap: () => context.push('/review/${reviews[i].id}'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── 인기 잉크 섹션 ──────────────────────────────────────────────────────────

class _PopularInksSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inksAsync = ref.watch(homePopularInksProvider);

    return inksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (inks) {
        if (inks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: '인기 잉크',
              onMore: () => context.go('/archive'),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.pagePadding,
                itemCount: inks.length,
                itemBuilder: (_, i) => _InkCircleItem(
                  ink: inks[i],
                  onTap: () => context.push('/archive/ink/${inks[i].id}'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InkCircleItem extends StatelessWidget {
  const _InkCircleItem({required this.ink, required this.onTap});
  final InkModel ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkDropCircle(color: ink.inkColor, size: 56),
            const SizedBox(height: AppSpacing.sm - 2),
            Text(
              ink.name,
              style: AppTextStyles.caption.copyWith(
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
  }
}

// ── 커뮤니티 최신글 섹션 ────────────────────────────────────────────────────

class _CommunitySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(filteredPostsProvider);

    return postsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (posts) {
        if (posts.isEmpty) return const SizedBox.shrink();
        final preview = posts.take(4).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: '커뮤니티 최신글',
              topPadding: AppSpacing.lg,
              onMore: () => context.go('/community'),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              itemCount: preview.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => PostCard(
                post: preview[i],
                onTap: () => context.push('/community/${preview[i].id}'),
                topPadding: i == 0 ? AppSpacing.xs : AppSpacing.sm,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 인기 만년필 섹션 ────────────────────────────────────────────────────────

class _PopularPensSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pensAsync = ref.watch(homePopularPensProvider);

    return pensAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (pens) {
        if (pens.isEmpty) return const SizedBox.shrink();
        final cardWidth = (MediaQuery.of(context).size.width * 0.38).clamp(
          130.0,
          175.0,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: '인기 만년필',
              onMore: () => context.go('/archive'),
            ),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.pagePadding,
                itemCount: pens.length,
                itemBuilder: (_, i) => _PenCard(
                  pen: pens[i],
                  width: cardWidth,
                  onTap: () => context.push('/archive/pen/${pens[i].id}'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.push('/notifications'),
        ),
        if (unread > 0)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _PenCard extends StatelessWidget {
  const _PenCard({required this.pen, required this.onTap, this.width = 140});
  final PenModel pen;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        padding: AppSpacing.cardPadding.add(
          const EdgeInsets.all(AppSpacing.xs),
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.70),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadowColor,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit, size: 22, color: AppColors.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(pen.brand, style: AppTextStyles.labelSmall),
            const SizedBox(height: 2),
            Text(
              pen.modelName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
