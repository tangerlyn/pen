import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/level_badge.dart';
import '../../../data/models/ink_book_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/community/post_card.dart';
import '../../../shared/widgets/review/review_list_card.dart';
import '../providers/user_activity_provider.dart';

// 네이비 기반 색상
const _kNavyTint  = Color(0xFFEEF2F8);
const _kNavyLight = Color(0xFFE2EAF4);
const _kNavyMid   = Color(0xFF8BA5C8);

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _hasPublicBooks = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(currentUidProvider) == widget.uid) {
        context.go('/mypage');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setHasPublicBooks(bool hasBooks) {
    if (_hasPublicBooks == hasBooks) return;
    final newLength = hasBooks ? 3 : 2;
    if (_tabController.length == newLength) return;
    final old = _tabController;
    setState(() {
      _hasPublicBooks = hasBooks;
      _tabController = TabController(length: newLength, vsync: this);
    });
    old.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(currentUidProvider);
    final userAsync = ref.watch(profileUserProvider(widget.uid));

    // 공개 잉크북 여부 감지 → 탭 개수 동적 조정
    final publicBooksAsync = ref.watch(userPublicInkBooksProvider(widget.uid));
    final hasPublicBooks = publicBooksAsync.maybeWhen(
      data: (books) => books.isNotEmpty,
      orElse: () => false,
    );
    if (hasPublicBooks != _hasPublicBooks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setHasPublicBooks(hasPublicBooks);
      });
    }

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        title: userAsync.when(
          data: (u) => Text(
            u?.nickname ?? '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const Text('프로필'),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: userAsync.when(
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => const SizedBox.shrink(),
              data: (user) => user == null
                  ? const SizedBox.shrink()
                  : _ProfileHeader(user: user, currentUid: currentUid),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PillTabDelegate(_tabController, _hasPublicBooks),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ReviewGrid(uid: widget.uid),
            _PostList(uid: widget.uid),
            if (_hasPublicBooks) _InkChartTab(uid: widget.uid),
          ],
        ),
      ),
    );
  }
}

// ── 프로필 헤더 ──────────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user, required this.currentUid});
  final UserModel user;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwnProfile = user.uid == currentUid;
    final isFollowing = (!isOwnProfile && currentUid != null)
        ? ref.watch(followStatusProvider((currentUid!, user.uid))).valueOrNull ?? false
        : false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileAvatar(imageUrl: user.profileImageUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    user.nickname,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                LevelBadge(user.level),
                              ],
                            ),
                          ),
                          if (!isOwnProfile && currentUid != null) ...[
                            const SizedBox(width: 8),
                            _FollowButton(
                              isFollowing: isFollowing,
                              onTap: () {
                                if (isFollowing) {
                                  ref.read(userRepoProvider).unfollow(currentUid!, user.uid);
                                } else {
                                  ref.read(userRepoProvider).follow(currentUid!, user.uid);
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.levelTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatChip(
                            label: '팔로워',
                            value: _formatCount(user.followerCount),
                            onTap: () => context.push('/profile/${user.uid}/followers?tab=0'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Container(width: 1, height: 14, color: AppColors.divider),
                          ),
                          _StatChip(
                            label: '팔로잉',
                            value: _formatCount(user.followingCount),
                            onTap: () => context.push('/profile/${user.uid}/followers?tab=1'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (user.bio.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _kNavyTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.bio,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}만';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}

// ── 프로필 사진 ──────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _kNavyLight, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: CircleAvatar(
        radius: 32,
        backgroundColor: _kNavyLight,
        backgroundImage: imageUrl != null ? CachedNetworkImageProvider(imageUrl!) : null,
        child: imageUrl == null
            ? const Icon(Icons.person, size: 32, color: _kNavyMid)
            : null,
      ),
    );
  }
}

// ── 팔로우 버튼 ──────────────────────────────────────────────────────────────

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});
  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isFollowing ? _kNavyLight : AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          border: isFollowing ? Border.all(color: const Color(0xFFCCD6E8)) : null,
        ),
        child: Text(
          isFollowing ? '팔로잉' : '팔로우',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isFollowing ? AppColors.textSecondary : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── 팔로워/팔로잉 수치 ────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            TextSpan(
              text: ' $label',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pill 탭바 (sticky) ────────────────────────────────────────────────────────

class _PillTabDelegate extends SliverPersistentHeaderDelegate {
  const _PillTabDelegate(this.tabController, this.hasPublicBooks);
  final TabController tabController;
  final bool hasPublicBooks;

  static const _height = 58.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: _kNavyLight,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: tabController,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: [
            const Tab(text: '리뷰', height: 36),
            const Tab(text: '커뮤니티', height: 36),
            if (hasPublicBooks) const Tab(text: '잉크차트', height: 36),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PillTabDelegate old) =>
      old.tabController != tabController || old.hasPublicBooks != hasPublicBooks;
}

// ── 리뷰 목록 ────────────────────────────────────────────────────────────────

class _ReviewGrid extends ConsumerWidget {
  const _ReviewGrid({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(userReviewsProvider(uid));
    return reviewsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const EmptyStateWidget(
        icon: Icons.cloud_off_outlined,
        message: '오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.camera_alt_outlined,
            message: '아직 작성한 리뷰가 없습니다',
          );
        }
        return ListView.separated(
          itemCount: reviews.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (_, i) => ReviewListCard(
            review: reviews[i],
            onTap: () => context.push('/review/${reviews[i].id}'),
          ),
        );
      },
    );
  }
}

// ── 게시글 목록 ──────────────────────────────────────────────────────────────

class _PostList extends ConsumerWidget {
  const _PostList({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(uid));
    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const EmptyStateWidget(
        icon: Icons.cloud_off_outlined,
        message: '오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.article_outlined,
            message: '아직 작성한 게시글이 없습니다',
          );
        }
        return ListView.separated(
          itemCount: posts.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (_, i) => PostCard(
            post: posts[i],
            onTap: () => context.push('/community/${posts[i].id}'),
          ),
        );
      },
    );
  }
}

// ── 잉크차트 탭 (공개 잉크북 그리드) ───────────────────────────────────────

class _InkChartTab extends ConsumerWidget {
  const _InkChartTab({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(userPublicInkBooksProvider(uid));
    return booksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const EmptyStateWidget(
        icon: Icons.cloud_off_outlined,
        message: '오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
      ),
      data: (books) {
        if (books.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.photo_album_outlined,
            message: '공개된 잉크 차트가 없습니다',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: books.length,
          itemBuilder: (_, i) => _InkBookCard(book: books[i]),
        );
      },
    );
  }
}

class _InkBookCard extends StatelessWidget {
  const _InkBookCard({required this.book});
  final InkBookModel book;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: book.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: book.color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: book.color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: book.color.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              book.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
