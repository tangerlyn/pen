import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/community/post_card.dart';
import '../../../shared/widgets/review/review_list_card.dart';
import '../providers/user_activity_provider.dart';

// 네이비 기반 색상
const _kNavyTint  = Color(0xFFEEF2F8);  // 연한 네이비 배경
const _kNavyLight = Color(0xFFE2EAF4);  // 살짝 진한 연네이비
const _kNavyMid   = Color(0xFF8BA5C8);  // 중간 네이비 (아이콘·보조)

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(currentUidProvider);

    if (currentUid == widget.uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/mypage');
      });
    }

    final userAsync = ref.watch(profileUserProvider(widget.uid));

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
          error: (_, __) => const Text('프로필'),
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
              error: (_, __) => const SizedBox.shrink(),
              data: (user) => user == null
                  ? const SizedBox.shrink()
                  : _ProfileHeader(user: user, currentUid: currentUid),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PillTabDelegate(_tabController),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ReviewGrid(uid: widget.uid),
            _PostList(uid: widget.uid),
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
        ? ref
                .watch(followStatusProvider((currentUid!, user.uid)))
                .valueOrNull ??
            false
        : false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
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
                      // 닉네임 + 팔로우 버튼
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
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
                          if (!isOwnProfile && currentUid != null) ...[
                            const SizedBox(width: 8),
                            _FollowButton(
                              isFollowing: isFollowing,
                              onTap: () {
                                if (isFollowing) {
                                  ref
                                      .read(userRepoProvider)
                                      .unfollow(currentUid!, user.uid);
                                } else {
                                  ref
                                      .read(userRepoProvider)
                                      .follow(currentUid!, user.uid);
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      // 레벨 + 칭호 (levelTitle이 이미 'Lv.N · 칭호' 형태)
                      Text(
                        user.levelTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 팔로워 / 팔로잉
                      Row(
                        children: [
                          _StatChip(
                            label: '팔로워',
                            value: _formatCount(user.followerCount),
                            onTap: () => context
                                .push('/profile/${user.uid}/followers?tab=0'),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: Container(
                              width: 1,
                              height: 14,
                              color: AppColors.divider,
                            ),
                          ),
                          _StatChip(
                            label: '팔로잉',
                            value: _formatCount(user.followingCount),
                            onTap: () => context
                                .push('/profile/${user.uid}/followers?tab=1'),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 32,
        backgroundColor: _kNavyLight,
        backgroundImage: imageUrl != null
            ? CachedNetworkImageProvider(imageUrl!)
            : null,
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isFollowing ? _kNavyLight : AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          border: isFollowing
              ? Border.all(color: const Color(0xFFCCD6E8))
              : null,
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
  const _StatChip(
      {required this.label, required this.value, required this.onTap});
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
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pill 탭바 (sticky) ────────────────────────────────────────────────────────

class _PillTabDelegate extends SliverPersistentHeaderDelegate {
  const _PillTabDelegate(this.tabController);
  final TabController tabController;

  static const _height = 58.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
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
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: '리뷰', height: 36),
            Tab(text: '커뮤니티', height: 36),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PillTabDelegate old) =>
      old.tabController != tabController;
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
      error: (_, __) => const SizedBox.shrink(),
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
      error: (_, __) => const SizedBox.shrink(),
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
    );
  }
}
