part of '../screens/review_detail_screen.dart';

class _PhotoSlider extends StatefulWidget {
  const _PhotoSlider({required this.review, required this.controller});
  final ReviewModel review;
  final PageController controller;

  @override
  State<_PhotoSlider> createState() => _PhotoSliderState();
}

class _PhotoSliderState extends State<_PhotoSlider> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        SizedBox(
          height: size.width,
          child: PageView.builder(
            controller: widget.controller,
            itemCount: widget.review.imageUrls.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(
                    imageUrls: widget.review.imageUrls,
                    initialIndex: i,
                  ),
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: widget.review.imageUrls[i],
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // 페이지 인디케이터
        if (widget.review.imageUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: widget.controller,
                count: widget.review.imageUrls.length,
                effect: const WormEffect(
                  dotHeight: 6,
                  dotWidth: 6,
                  activeDotColor: Colors.white,
                  dotColor: Colors.white54,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 프로필 ────────────────────────────────────────────────────
class _ProfileRow extends ConsumerWidget {
  const _ProfileRow({required this.review, required this.currentUid});
  final ReviewModel review;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(_reviewAuthorProvider(review.authorId));
    final isOwnPost = review.authorId == currentUid;
    final isDeletedUser = authorAsync.valueOrNull == null;
    final isFollowing = (!isOwnPost && currentUid != null && !isDeletedUser)
        ? ref
                  .watch(followStatusProvider((currentUid!, review.authorId)))
                  .valueOrNull ??
              false
        : false;
    final timeStr = formatPostDate(review.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => navigateToProfile(context, ref, review.authorId),
            child: authorAsync.when(
              data: (user) =>
                  UserAvatar(imageUrl: user?.profileImageUrl, radius: 16),
              loading: () => const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.chipBackground,
              ),
              error: (_, __) => const UserAvatar(radius: 16),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => navigateToProfile(context, ref, review.authorId),
              child: authorAsync.when(
                data: (user) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user == null ? '알수없음(탈퇴)' : user.nickname,
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (user != null) ...[
                          const SizedBox(width: 6),
                          LevelBadge(user.level),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(timeStr, style: AppTextStyles.labelSmall),
                        if (review.updatedAt != null) ...[
                          const SizedBox(width: 4),
                          const Text('· 수정됨', style: AppTextStyles.labelSmall),
                        ],
                      ],
                    ),
                  ],
                ),
                loading: () => Container(
                  height: 14,
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                error: (_, __) => Text(
                  review.authorId,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          if (!isOwnPost && currentUid != null && !isDeletedUser)
            isFollowing
                ? ElevatedButton(
                    onPressed: () => ref
                        .read(userRepoProvider)
                        .unfollow(currentUid!, review.authorId),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(72, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontSize: 13),
                      backgroundColor: AppColors.chipBackground,
                      foregroundColor: AppColors.textSecondary,
                      elevation: 0,
                    ),
                    child: const Text('팔로잉'),
                  )
                : OutlinedButton(
                    onPressed: () => ref
                        .read(userRepoProvider)
                        .follow(currentUid!, review.authorId),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(72, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontSize: 13),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: const Text('팔로우'),
                  ),
        ],
      ),
    );
  }
}

// ── 장비 카드 ────────────────────────────────────────────────
class _GearCard extends StatelessWidget {
  const _GearCard({required this.review});
  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    if (review.inkIds.isEmpty && review.penIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...review.inkIds.map(
              (id) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _GearChip(
                  type: 'ink',
                  id: id,
                  onTap: () => context.push('/archive/ink/$id'),
                ),
              ),
            ),
            ...review.penIds.map(
              (id) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _GearChip(
                  type: 'pen',
                  id: id,
                  onTap: () => context.push('/archive/pen/$id'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GearChip extends ConsumerWidget {
  const _GearChip({required this.type, required this.id, required this.onTap});
  final String type;
  final String id;
  final VoidCallback onTap;

  static const _inkBg = AppColors.infoBg;
  static const _inkBorder = Color(0xFF90CAF9);
  static const _inkFg = AppColors.info;
  static const _penBg = AppColors.purpleBg;
  static const _penBorder = Color(0xFFCE93D8);
  static const _penFg = AppColors.purple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInk = type == 'ink';
    final dataState = ref.watch(
      archiveDetailProvider((type: type, productId: id)),
    );

    final label = dataState.when(
      data: (data) {
        if (data == null) return isInk ? '잉크' : '만년필';
        return isInk
            ? '${data.brand} ${data.name}'
            : '${data.brand} ${data.modelName}';
      },
      loading: () => '로딩중...',
      error: (_, __) => isInk ? '잉크' : '만년필',
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isInk ? _inkBg : _penBg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: isInk ? _inkBorder : _penBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInk ? Icons.water_drop_outlined : Icons.edit_outlined,
              size: 12,
              color: isInk ? _inkFg : _penFg,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isInk ? _inkFg : _penFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 액션 바 ──────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.review,
    required this.currentUid,
    required this.onLike,
  });
  final ReviewModel review;
  final String? currentUid;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _ActionButton(
            icon: review.isLiked ? Icons.favorite : Icons.favorite_border,
            label: '${review.likeCount}',
            color: review.isLiked ? AppColors.error : null,
            onTap: onLike,
          ),
          const SizedBox(width: 16),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: '${review.commentCount}',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 댓글 목록 ────────────────────────────────────────────────
