import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/home_discovery_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/home_banner_carousel.dart';
import '../../community/providers/community_provider.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/community/post_card.dart';
import '../../../shared/widgets/review/review_grid_card.dart';
import '../../../data/models/ink_model.dart';
import '../../../data/models/review_model.dart';
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
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
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
                  context.push('/write/review?entry=home');
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
                  '내가 사용한 잉크·펜을 기록해요',
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
    // 새로 불러오기가 끝날 때까지 당김 인디케이터를 유지한다. 실패는 각 섹션이 따로 처리한다.
    await Future.wait<Object?>([
      ref.refresh(homeBannersProvider.future),
      ref.refresh(homeLatestReviewsProvider.future),
      ref.refresh(homeWeeklyPopularReviewsProvider.future),
      ref.refresh(homeRecentProductsProvider.future),
      ref.refresh(homePopularInksProvider.future),
      ref.refresh(homePopularPensProvider.future),
      ref.refresh(filteredPostsProvider.future),
    ].map((f) => f.then<Object?>((v) => v, onError: (_) => null)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(scrollToTopTabProvider, (_, next) {
      if (next == 0) {
        if (_scrollController.hasClients) _scrollToTop();
        ref.read(scrollToTopTabProvider.notifier).state = null;
      }
    });
    // 떠 있는 하단 바 높이 — 목록 끝과 플로팅 버튼을 그만큼 띄운다.
    final navInset = MediaQuery.paddingOf(context).bottom;
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
                    AppConstants.appNameKorean,
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
                      const HomeBannerCarousel(),
                      _ReviewRowSection(
                        title: '최신 리뷰',
                        provider: homeLatestReviewsProvider,
                        topPadding: AppSpacing.sm,
                        showSkeleton: true,
                      ),
                      _RecentProductsSection(),
                      _ReviewRowSection(
                        title: '이번 주 인기 리뷰',
                        provider: homeWeeklyPopularReviewsProvider,
                      ),
                      _PopularInksSection(),
                      _PopularPensSection(),
                      _CommunitySection(),
                      SizedBox(height: 80 + navInset),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 스크롤 탑 버튼
          Positioned(
            right: AppSpacing.lg,
            bottom: 80 + navInset,
            child: PopReveal(
              visible: _showScrollTop,
              child: IgnorePointer(
                ignoring: !_showScrollTop,
                child: FloatingActionButton.small(
                  heroTag: 'home_scroll_top',
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
          // 글쓰기 FAB
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg + navInset,
            child: FloatingActionButton(
              heroTag: 'home_write',
              onPressed: () => _showWriteModal(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const StadiumBorder(),
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

// ── 리뷰 가로 목록 섹션 (최신 리뷰 · 이번 주 인기 리뷰) ─────────────────────

class _ReviewRowSection extends ConsumerWidget {
  const _ReviewRowSection({
    required this.title,
    required this.provider,
    this.topPadding = AppSpacing.section,
    this.showSkeleton = false,
  });

  final String title;
  final FutureProvider<List<ReviewModel>> provider;
  final double topPadding;

  /// 첫 섹션만 로딩 중 뼈대를 보여주고, 아래 섹션은 준비되면 나타난다.
  final bool showSkeleton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(provider);
    // 화면 폭에 비례한 카드 너비 — 좁은 폰에서도 다음 카드가 살짝 보이고,
    // 넓은 폰/기기에서 카드가 지나치게 작아 보이지 않도록 상하한을 둔다.
    // 리뷰 탭과 같은 카드(사진 4:5 + 작성자·제목·본문·시간). 한 화면에 2장 반쯤 보이게.
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.36).clamp(
      124.0,
      170.0,
    );
    // 사진 높이 + 글 영역(실제 글꼴·글자 크기로 계산)
    final listHeight = ReviewGridCard.extent(context, cardWidth);
    final header = _SectionHeader(
      title: title,
      topPadding: topPadding,
      onMore: () => context.go('/review'),
    );

    return reviewsAsync.when(
      loading: () => !showSkeleton
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: AppSpacing.pagePadding,
                    itemCount: 4,
                    itemBuilder: (_, _) =>
                        HomeReviewCardSkeleton(width: cardWidth),
                  ),
                ),
              ],
            ),
      error: (_, _) => const SizedBox.shrink(),
      data: (reviews) {
        if (reviews.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            SizedBox(
              height: listHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.pagePadding,
                itemCount: reviews.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: SizedBox(
                    width: cardWidth,
                    child: ReviewGridCard(
                      review: reviews[i],
                      onTap: () => context.push('/review/${reviews[i].id}'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 최근 본 잉크·만년필 섹션 ────────────────────────────────────────────────

class _RecentProductsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeRecentProductsProvider).valueOrNull ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: '최근 본 잉크·만년필',
          onMore: () => context.go('/archive'),
        ),
        SizedBox(
          height: _ProductCircleItem.heightOf(context),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.pagePadding,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              if (item is InkModel) {
                return _ProductCircleItem(
                  brand: item.brand,
                  label: item.name,
                  circle: InkDropCircle(color: item.inkColor, size: 56),
                  onTap: () => context.push('/archive/ink/${item.id}'),
                );
              }
              final pen = item as PenModel;
              return _ProductCircleItem(
                brand: pen.brand,
                label: pen.modelName,
                circle: _PenCircle(photoUrl: pen.photoUrl),
                onTap: () => context.push('/archive/pen/${pen.id}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 동그라미 + 브랜드 + 이름 두 줄 — 아카이브 탭 잉크 목록과 같은 모양.
/// 인기 잉크 · 인기 만년필 · 최근 본 목록에서 함께 쓴다.
class _ProductCircleItem extends StatelessWidget {
  const _ProductCircleItem({
    required this.brand,
    required this.label,
    required this.circle,
    required this.onTap,
  });

  final String brand;
  final String label;
  final Widget circle;
  final VoidCallback onTap;

  static const _brandStyle = TextStyle(
    fontSize: 9,
    height: 1.3,
    color: AppColors.textSecondary,
  );
  static final _nameStyle = AppTextStyles.caption.copyWith(
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.35,
  );

  /// 동그라미(56) + 간격(6) + 브랜드 한 줄 + 이름 두 줄(글자 크기에 비례) + 여유.
  static double heightOf(BuildContext context) =>
      56 + 6 + MediaQuery.textScalerOf(context).scale(9 * 1.3 + 10 * 1.35 * 2) + 4;

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
            circle,
            const SizedBox(height: 6),
            Text(
              brand,
              style: _brandStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: _nameStyle,
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

class _PenCircle extends StatelessWidget {
  const _PenCircle({this.photoUrl});
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.chipBackground,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  const Icon(Icons.edit, size: 22, color: AppColors.textSecondary),
            )
          : const Icon(Icons.edit, size: 22, color: AppColors.textSecondary),
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
              height: _ProductCircleItem.heightOf(context),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.pagePadding,
                itemCount: inks.length,
                itemBuilder: (_, i) => _ProductCircleItem(
                  brand: inks[i].brand,
                  label: inks[i].name,
                  circle: InkDropCircle(color: inks[i].inkColor, size: 56),
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
        final preview = posts.take(5).toList();
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
      error: (_, _) => const SizedBox.shrink(),
      data: (pens) {
        if (pens.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: '인기 만년필',
              onMore: () => context.go('/archive'),
            ),
            SizedBox(
              height: _ProductCircleItem.heightOf(context),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.pagePadding,
                itemCount: pens.length,
                itemBuilder: (_, i) => _ProductCircleItem(
                  brand: pens[i].brand,
                  label: pens[i].modelName,
                  circle: _PenCircle(photoUrl: pens[i].photoUrl),
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
