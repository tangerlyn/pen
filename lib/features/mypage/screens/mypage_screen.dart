import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/community/post_card.dart';
import '../providers/user_activity_provider.dart';

// ── 메인 화면 ─────────────────────────────────────────────────────────
class MypageScreen extends ConsumerStatefulWidget {
  const MypageScreen({super.key});

  @override
  ConsumerState<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends ConsumerState<MypageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/mypage/settings'),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  // 프로필
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.chipBackground,
                        backgroundImage: user?.profileImageUrl != null
                            ? CachedNetworkImageProvider(user!.profileImageUrl!)
                            : null,
                        child: user?.profileImageUrl == null
                            ? const Icon(Icons.person, size: 40, color: AppColors.textTertiary)
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.nickname ?? '',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                            if (user?.bio.isNotEmpty == true) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                user!.bio,
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // 팔로워/팔로잉
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                          child: _StatItem(
                            label: '팔로워',
                            value: '${user?.followerCount ?? 0}',
                            onTap: user != null
                                ? () => context.push('/profile/${user.uid}/followers?tab=0')
                                : null,
                          )),
                      Container(height: 30, width: 1, color: AppColors.divider),
                      Expanded(
                          child: _StatItem(
                            label: '팔로잉',
                            value: '${user?.followingCount ?? 0}',
                            onTap: user != null
                                ? () => context.push('/profile/${user.uid}/followers?tab=1')
                                : null,
                          )),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (user != null) _LevelProgressBar(user: user),
                  const SizedBox(height: AppSpacing.md),
                  // 잉크 컬렉션 미리보기
                  if (user != null) _InkChartCard(uid: user.uid),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => context.push('/mypage/edit'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44)),
                    child: const Text('프로필 편집'),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '리뷰'),
                  Tab(text: '커뮤니티'),
                  Tab(text: '스크랩북'),
                ],
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            _MyReviewGrid(),
            _MyCommunityList(),
            _ScrapbookGrid(),
          ],
        ),
      ),
    );
  }
}

// ── 리뷰 탭 (리스트) ─────────────────────────────────────────────────
class _MyReviewGrid extends ConsumerWidget {
  const _MyReviewGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const SizedBox.shrink();

    final reviewsAsync = ref.watch(userReviewsProvider(uid));

    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.camera_alt_outlined,
            message: '아직 작성한 리뷰가 없습니다',
          );
        }
        return ListView.separated(
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _ReviewListCard(
            review: reviews[i],
            onTap: () => context.push('/review/${reviews[i].id}'),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── 커뮤니티 탭 (게시글 리스트) ─────────────────────────────────────
class _MyCommunityList extends ConsumerWidget {
  const _MyCommunityList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const SizedBox.shrink();

    final postsAsync = ref.watch(userPostsProvider(uid));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.article_outlined,
            message: '아직 작성한 게시글이 없습니다',
          );
        }
        return ListView.separated(
          itemCount: posts.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => PostCard(
            post: posts[i],
            onTap: () => context.push('/community/${posts[i].id}'),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── 스크랩북 탭 (리스트) ─────────────────────────────────────────────
class _ScrapbookGrid extends ConsumerWidget {
  const _ScrapbookGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const SizedBox.shrink();

    final scrapsAsync = ref.watch(scrappedReviewsProvider(uid));

    return scrapsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(scrappedReviewsProvider(uid).future),
            child: ListView(
              children: const [
                SizedBox(height: 120),
                EmptyStateWidget(
                  icon: Icons.bookmark_border,
                  message: '스크랩한 리뷰가 없습니다',
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(scrappedReviewsProvider(uid).future),
          child: ListView.separated(
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _ReviewListCard(
              review: reviews[i],
              onTap: () => context.push('/review/${reviews[i].id}'),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

// ── 리뷰 리스트 카드 (PostCard 레이아웃 동일) ─────────────────────────
class _ReviewListCard extends StatelessWidget {
  const _ReviewListCard({required this.review, required this.onTap});
  final ReviewModel review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = review.imageUrls.isNotEmpty;
    final stars = review.rating.toStringAsFixed(1);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, AppSpacing.lg, AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 11, color: Color(0xFFFFA000)),
                            const SizedBox(width: 2),
                            Text(
                              stars,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFFA000),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          review.body,
                          style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 15, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (review.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      review.body,
                      style: AppTextStyles.labelMedium,
                      maxLines: hasImage ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        timeago.format(review.createdAt, locale: 'ko'),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                      ),
                      const Spacer(),
                      const Icon(Icons.chat_bubble_outline,
                          size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        '${review.commentCount}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.favorite_border,
                          size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        '${review.likeCount}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: AppSpacing.md),
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  child: CachedNetworkImage(
                    imageUrl: review.imageUrls.first,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _LevelProgressBar extends StatelessWidget {
  const _LevelProgressBar({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user.levelTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary),
              ),
              Text(
                'EXP ${user.levelProgressLabel}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: user.levelProgress,
              backgroundColor: AppColors.divider,
              color: AppColors.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 잉크 차트 진입 카드 ────────────────────────────────────────────────
class _InkChartCard extends ConsumerWidget {
  const _InkChartCard({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(inkBookListProvider(uid));
    final count = booksAsync.maybeWhen(data: (l) => l.length, orElse: () => 0);

    return GestureDetector(
      onTap: () => context.push('/ink-chart'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F2E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD4C5A9)),
        ),
        child: Row(
          children: [
            const Icon(Icons.photo_album_outlined,
                size: 18, color: Color(0xFFB8A98A)),
            const SizedBox(width: AppSpacing.sm),
            const Text('내 잉크 차트', style: AppTextStyles.titleSmall),
            const Spacer(),
            Text('$count권', style: AppTextStyles.labelMedium),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) => false;
}
