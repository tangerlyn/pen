import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/community_provider.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/community/post_card.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/widgets/icon_count.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../../shared/widgets/user_avatar.dart';

final _popularCardAuthorProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  return ref.watch(userRepoProvider).watchUser(uid);
});

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, this.showAppBar = true});
  final bool showAppBar;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _scrollKey = GlobalKey<NestedScrollViewState>();
  bool _showScrollTop = false;

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
    final feedState = ref.watch(communityFeedProvider);
    final popular = ref.watch(popularPostsProvider);
    final posts = feedState.posts;
    // Popular section is hidden when a category filter is active
    final hasPopular = popular.isNotEmpty && feedState.selectedCategory == null;

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
              headerSliverBuilder: (context, _) => [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  toolbarHeight: widget.showAppBar ? kToolbarHeight : 0,
                  title: widget.showAppBar
                      ? const Text(
                          '커뮤니티',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        )
                      : null,
                  actions: widget.showAppBar
                      ? [
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () =>
                                context.push('/search?type=community'),
                          ),
                        ]
                      : null,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(45),
                    child: Column(
                      children: [
                        _CategoryFilterBar(
                          selected: feedState.selectedCategory,
                          onSelected: (cat) => ref
                              .read(communityFeedProvider.notifier)
                              .setCategory(cat),
                        ),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                ),
              ],
              body: feedState.isLoading
                  ? ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 6,
                      itemBuilder: (_, _) => const PostCardSkeleton(),
                    )
                  : posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.article_outlined,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            feedState.selectedCategory != null
                                ? '${feedState.selectedCategory} 게시글이 없어요.'
                                : '첫 글을 작성해보세요!',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(filteredPostsProvider);
                        await ref
                            .read(communityFeedProvider.notifier)
                            .loadPosts(refresh: true);
                      },
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollEndNotification &&
                              notification.metrics.extentAfter < 200) {
                            ref.read(communityFeedProvider.notifier).loadMore();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          itemCount:
                              posts.length +
                              (hasPopular ? 1 : 0) +
                              (feedState.isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, i) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final normalStart = hasPopular ? 1 : 0;
                            final normalEnd = posts.length + normalStart;

                            if (hasPopular && i == 0) {
                              return _PopularSection(
                                posts: popular,
                                onTap: (id) => context.push('/community/$id'),
                              );
                            }
                            if (feedState.isLoadingMore && i == normalEnd) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final post = posts[i - normalStart];
                            return PostCard(
                              post: post,
                              onTap: () =>
                                  context.push('/community/${post.id}'),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),
          // 스크롤 탑 버튼 (글쓰기 FAB 위)
          Positioned(
            right: 16,
            bottom: 80,
            child: AnimatedOpacity(
              opacity: _showScrollTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showScrollTop,
                child: FloatingActionButton.small(
                  heroTag: 'community_scroll_top',
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
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'community_write',
              onPressed: () => context.push('/community/write'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              label: const Text(
                '글 쓰기',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 카테고리 필터 바 ──────────────────────────────────────────────────────────
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({required this.selected, required this.onSelected});
  final String? selected;
  final ValueChanged<String?> onSelected;

  static const _categories = ['질문', '정보공유', '필사', '그림'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [_chip(null, '전체'), ..._categories.map((c) => _chip(c, c))],
      ),
    );
  }

  Widget _chip(String? value, String label) {
    final isSelected = selected == value;
    return TapScale(
      onTap: () => onSelected(isSelected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.chipBackground,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PopularSection extends StatefulWidget {
  const _PopularSection({required this.posts, required this.onTap});
  final List<dynamic> posts;
  final ValueChanged<String> onTap;

  @override
  State<_PopularSection> createState() => _PopularSectionState();
}

class _PopularSectionState extends State<_PopularSection> {
  final _pageCtrl = PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.posts;
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: const [
                Icon(
                  Icons.local_fire_department,
                  size: 18,
                  color: Color(0xFFFF5722),
                ),
                SizedBox(width: 4),
                Text(
                  '인기글',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 148,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: posts.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final post = posts[i];
                return _PopularCard(
                  post: post,
                  onTap: () => widget.onTap(post.id),
                );
              },
            ),
          ),
          // 페이지 인디케이터
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(posts.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '전체 게시글',
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 인기글 카드 ────────────────────────────────────────────────────────────
class _PopularCard extends ConsumerWidget {
  const _PopularCard({required this.post, required this.onTap});
  final dynamic post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(
      _popularCardAuthorProvider(post.authorId as String),
    );
    final user = authorAsync.valueOrNull;
    final hasThumbnail = (post.imageUrls as List).isNotEmpty == true;

    return TapScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title as String,
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.body as String,
                        style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(
                              imageUrl: user?.profileImageUrl,
                              radius: 10,
                              iconSize: 11,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                user?.nickname ?? post.authorNickname as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelSmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconCount(
                            icon: Icons.favorite_border,
                            count: post.likeCount,
                            iconSize: 11,
                            fontSize: 11,
                            spacing: 2,
                          ),
                          const SizedBox(width: 8),
                          IconCount(
                            icon: Icons.chat_bubble_outline,
                            count: post.commentCount,
                            iconSize: 11,
                            fontSize: 11,
                            spacing: 2,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasThumbnail) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: CachedNetworkImage(
                  imageUrl: (post.imageUrls as List).first as String,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
