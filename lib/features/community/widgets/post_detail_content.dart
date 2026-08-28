part of '../screens/post_detail_screen.dart';

class _EditorialByline extends ConsumerWidget {
  const _EditorialByline({required this.post, required this.currentUid});
  final PostModel post;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                          Text(
                            user?.nickname ?? post.authorNickname,
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
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
                  onPressed: () => ref
                      .read(userRepoProvider)
                      .unfollow(currentUid!, post.authorId),
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
                      .follow(currentUid!, post.authorId),
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

