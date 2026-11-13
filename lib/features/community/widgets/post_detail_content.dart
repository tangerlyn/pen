part of '../screens/post_detail_screen.dart';

class _EditorialByline extends ConsumerStatefulWidget {
  const _EditorialByline({required this.post, required this.currentUid});
  final PostModel post;
  final String? currentUid;

  @override
  ConsumerState<_EditorialByline> createState() => _EditorialBylineState();
}

class _EditorialBylineState extends ConsumerState<_EditorialByline> {
  bool _followBusy = false;

  PostModel get post => widget.post;
  String? get currentUid => widget.currentUid;

  Future<void> _toggleFollow(bool isFollowing) async {
    final uid = currentUid;
    if (_followBusy || uid == null) return;
    setState(() => _followBusy = true);
    try {
      final repo = ref.read(userRepoProvider);
      if (isFollowing) {
        await repo.unfollow(uid, post.authorId);
      } else {
        await repo.follow(uid, post.authorId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('follow toggle failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('잠시 후 다시 시도해 주세요.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorAsync = ref.watch(_postAuthorProvider(post.authorId));
    final user = authorAsync.valueOrNull;
    final timeStr = formatPostDate(post.createdAt);
    final isOwnPost = post.authorId == currentUid;
    final isDeletedUser = authorAsync.valueOrNull == null;
    final isFollowing = (!isOwnPost && currentUid != null && !isDeletedUser)
        ? ref
                  .watch(followStatusProvider((currentUid!, post.authorId)))
                  .valueOrNull ??
              false
        : false;

    return Row(
      children: [
        Expanded(
          child: TapScale(
            onTap: () => navigateToProfile(context, ref, post.authorId),
            child: Row(
              children: [
                UserAvatar(imageUrl: user?.profileImageUrl, radius: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user?.nickname ?? post.authorNickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          LevelBadge(user?.level ?? post.authorLevel),
                        ],
                      ),
                      Text(timeStr, style: AppTextStyles.labelSmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isOwnPost && currentUid != null && !isDeletedUser)
          isFollowing
              ? ElevatedButton(
                  onPressed: _followBusy ? null : () => _toggleFollow(true),
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
                  onPressed: _followBusy ? null : () => _toggleFollow(false),
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
    );
  }
}
