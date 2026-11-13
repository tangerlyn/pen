import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';
import '../../../shared/providers/ink_book_providers.dart'
    show userVisibleBooksProvider;
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/content_moderation.dart';
import '../../../shared/widgets/community/post_card.dart';
import '../../../shared/widgets/review/review_list_tile.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../providers/user_activity_provider.dart';
import '../widgets/notebook_card.dart';

// 네이비 기반 색상
const _kNavyTint = AppColors.navyTint;
const _kNavyLight = Color(0xFFE2EAF4);
const _kNavyMid = Color(0xFF8BA5C8);

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

    // 알림 딥링크 등으로 navigateToProfile()의 탈퇴 체크를 거치지 않고
    // 곧장 진입한 경우를 대비 — 탈퇴한 사용자면 빈 화면 대신 안내만 표시
    if (userAsync.hasValue && userAsync.value == null) {
      return Scaffold(
        appBar: AppBar(scrolledUnderElevation: 0, elevation: 0),
        body: const Center(child: Text('탈퇴한 사용자입니다.')),
      );
    }

    // 공개 잉크북 여부 감지 → 탭 개수 동적 조정 (팔로우 여부 반영)
    final publicBooksAsync = ref.watch(
      userVisibleBooksProvider((widget.uid, currentUid)),
    );
    final hasPublicBooks = publicBooksAsync.maybeWhen(
      data: (books) => books.isNotEmpty,
      orElse: () => false,
    );
    if (hasPublicBooks != _hasPublicBooks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setHasPublicBooks(hasPublicBooks);
      });
    }

    final profileUser = userAsync.valueOrNull;
    final isBlocked = ref
            .watch(myBlockedUidsProvider)
            .valueOrNull
            ?.contains(widget.uid) ??
        false;
    final appBar = AppBar(
      scrolledUnderElevation: 0,
      elevation: 0,
      actions: [
        if (currentUid != null &&
            currentUid != widget.uid &&
            profileUser != null)
          _ProfileMenu(user: profileUser, isBlocked: isBlocked),
      ],
    );

    // 차단한 사용자는 리뷰·글·잉크북을 보여주지 않는다
    if (isBlocked) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 52, color: AppColors.textTertiary),
                const SizedBox(height: 12),
                const Text(
                  '차단한 사용자예요',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref
                      .read(userRepoProvider)
                      .unblock(currentUid!, widget.uid),
                  child: const Text('차단 해제'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
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
            if (_hasPublicBooks)
              _InkChartTab(uid: widget.uid, viewerUid: currentUid),
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x141B2E4B),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              user.nickname,
                              style: AppTextStyles.headlineSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (!isOwnProfile && currentUid != null) ...[
                            const SizedBox(width: 8),
                            _FollowButton(
                              isFollowing: isFollowing,
                              onTap: () => isFollowing
                                  ? ref
                                        .read(userRepoProvider)
                                        .unfollow(currentUid!, user.uid)
                                  : ref
                                        .read(userRepoProvider)
                                        .follow(currentUid!, user.uid),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.levelTitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 좁은 화면 + 큰 글씨 + 큰 수치에서 한 줄을 넘치면
                      // 다음 줄로 내린다(기본 크기에선 Row와 동일하게 한 줄).
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatChip(
                            label: '팔로워',
                            value: _formatCount(user.followerCount),
                            onTap: () => context.push(
                              '/profile/${user.uid}/followers?tab=0',
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Container(
                              width: 1,
                              height: 14,
                              color: AppColors.divider,
                            ),
                          ),
                          _StatChip(
                            label: '팔로잉',
                            value: _formatCount(user.followingCount),
                            onTap: () => context.push(
                              '/profile/${user.uid}/followers?tab=1',
                            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _kNavyTint,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  user.bio,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
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
            color: Color(0x1A1B2E4B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: UserAvatar(
        imageUrl: imageUrl,
        radius: 32,
        backgroundColor: _kNavyLight,
        iconColor: _kNavyMid,
      ),
    );
  }
}

// ── 팔로우 버튼 ──────────────────────────────────────────────────────────────

// ── 프로필 더보기 메뉴 (신고·차단) ─────────────────────────────────────────

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu({required this.user, required this.isBlocked});
  final UserModel user;
  final bool isBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        final myUid = ref.read(currentUidProvider);
        switch (value) {
          case 'report':
            await showReportSheet(
              context,
              ref,
              targetType: 'user',
              targetId: user.uid,
            );
          case 'block':
            await showBlockDialog(
              context,
              ref,
              targetUid: user.uid,
              targetNickname: user.nickname,
            );
          case 'unblock':
            if (myUid != null) {
              await ref.read(userRepoProvider).unblock(myUid, user.uid);
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'report', child: Text('신고하기')),
        isBlocked
            ? const PopupMenuItem(value: 'unblock', child: Text('차단 해제'))
            : const PopupMenuItem(
                value: 'block',
                child: Text('차단하기', style: TextStyle(color: AppColors.error)),
              ),
      ],
    );
  }
}

class _FollowButton extends StatefulWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});
  final bool isFollowing;
  final Future<void> Function() onTap;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  // 요청이 끝나기 전에 다시 눌러 팔로우/언팔로우가 겹치지 않게 막는다
  bool _busy = false;

  Future<void> _handleTap() async {
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('잠시 후 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFollowing = widget.isFollowing;
    return TapScale(
      onTap: _busy ? null : _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isFollowing ? _kNavyLight : AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isFollowing
              ? Border.all(color: const Color(0xFFCCD6E8))
              : null,
        ),
        child: Text(
          isFollowing ? '팔로잉' : '팔로우',
          style: AppTextStyles.bodySmall.copyWith(
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
  const _StatChip({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
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
            TextSpan(text: ' $label', style: AppTextStyles.bodySmall),
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
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
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
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
      old.tabController != tabController ||
      old.hasPublicBooks != hasPublicBooks;
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
          itemBuilder: (_, i) => ReviewListTile(
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
  const _InkChartTab({required this.uid, this.viewerUid});
  final String uid;
  final String? viewerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(userVisibleBooksProvider((uid, viewerUid)));
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
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemCount: books.length,
          itemBuilder: (_, i) {
            final book = books[i];
            return NotebookCard(
              book: book,
              uid: uid,
              onTap: () => context.push(
                '/public-ink-books/$uid/${book.id}?name=${Uri.encodeComponent(book.name)}',
              ),
            );
          },
        );
      },
    );
  }
}
