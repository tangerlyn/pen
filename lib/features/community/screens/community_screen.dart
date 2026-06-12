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

final _popularCardAuthorProvider =
    FutureProvider.family<UserModel?, String>((ref, uid) {
  return ref.read(userRepoProvider).getUser(uid);
});

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, this.showAppBar = true});
  final bool showAppBar;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _scrollController = ScrollController();
  bool _showScrollTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final show = pos.pixels > 100;
    if (show != _showScrollTop) setState(() => _showScrollTop = show);
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(communityFeedProvider.notifier).loadMore();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('커뮤니티',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.push('/search?type=community'),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          Column(
            children: [
              _CategoryFilterBar(
                selected: feedState.selectedCategory,
                onSelected: (cat) =>
                    ref.read(communityFeedProvider.notifier).setCategory(cat),
              ),
              const Divider(height: 1),
              Expanded(
                child: feedState.isLoading
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
                                const Icon(Icons.article_outlined,
                                    size: 64, color: AppColors.textTertiary),
                                const SizedBox(height: 12),
                                Text(
                                  feedState.selectedCategory != null
                                      ? '${feedState.selectedCategory} 게시글이 없어요.'
                                      : '첫 글을 작성해보세요!',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary),
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
                            child: ListView.separated(
                              controller: _scrollController,
                              itemCount: posts.length +
                                  (hasPopular ? 1 : 0) +
                                  (feedState.isLoadingMore ? 1 : 0),
                              separatorBuilder: (_, i) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final normalStart = hasPopular ? 1 : 0;
                                final normalEnd = posts.length + normalStart;

                                if (hasPopular && i == 0) {
                                  return _PopularSection(
                                    posts: popular,
                                    onTap: (id) =>
                                        context.push('/community/$id'),
                                  );
                                }
                                if (feedState.isLoadingMore && i == normalEnd) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                        child: CircularProgressIndicator()),
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
            ],
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
            child: FloatingActionButton(
              heroTag: 'community_write',
              onPressed: () => context.push('/community/write'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.edit_outlined),
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

  static const _categories = ['질문', '정보공유'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _chip(null, '전체'),
          ..._categories.map((c) => _chip(c, c)),
        ],
      ),
    );
  }

  Widget _chip(String? value, String label) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelected(isSelected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.chipBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
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
                Icon(Icons.local_fire_department,
                    size: 18, color: Color(0xFFFF5722)),
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
                    color: active
                        ? AppColors.primary
                        : AppColors.divider,
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
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
    final authorAsync = ref.watch(_popularCardAuthorProvider(post.authorId as String));
    final user = authorAsync.valueOrNull;
    final hasThumbnail = (post.imageUrls as List).isNotEmpty == true;

    return GestureDetector(
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.body as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.chipBackground,
                        backgroundImage: user?.profileImageUrl != null
                            ? CachedNetworkImageProvider(user!.profileImageUrl!)
                            : null,
                        child: user?.profileImageUrl == null
                            ? const Icon(Icons.person,
                                size: 11, color: AppColors.textTertiary)
                            : null,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        user?.nickname ?? post.authorNickname as String,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                      const Spacer(),
                      const Icon(Icons.favorite_border,
                          size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text('${post.likeCount}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.chat_bubble_outline,
                          size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text('${post.commentCount}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
            if (hasThumbnail) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
