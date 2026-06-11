import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';
import '../providers/user_activity_provider.dart';

class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({super.key, required this.uid, this.initialTab = 0});
  final String uid;
  final int initialTab;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewerUid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('팔로우'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '팔로워'),
            Tab(text: '팔로잉'),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UserList(
            asyncValue: ref.watch(followersProvider(widget.uid)),
            viewerUid: viewerUid,
            emptyMessage: '팔로워가 없습니다',
          ),
          _UserList(
            asyncValue: ref.watch(followingListProvider(widget.uid)),
            viewerUid: viewerUid,
            emptyMessage: '팔로잉하는 사용자가 없습니다',
          ),
        ],
      ),
    );
  }
}

class _UserList extends ConsumerWidget {
  const _UserList({
    required this.asyncValue,
    required this.viewerUid,
    required this.emptyMessage,
  });
  final AsyncValue<List<UserModel>> asyncValue;
  final String? viewerUid;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('불러오기 실패')),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text(emptyMessage,
                style: const TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) =>
              _UserTile(user: users[i], viewerUid: viewerUid),
        );
      },
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user, required this.viewerUid});
  final UserModel user;
  final String? viewerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwn = user.uid == viewerUid;
    final isFollowing = (viewerUid != null && !isOwn)
        ? ref
                .watch(followStatusProvider((viewerUid!, user.uid)))
                .valueOrNull ??
            false
        : false;

    return ListTile(
      onTap: () => context.push('/profile/${user.uid}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.chipBackground,
        backgroundImage: user.profileImageUrl != null
            ? CachedNetworkImageProvider(user.profileImageUrl!)
            : null,
        child: user.profileImageUrl == null
            ? const Icon(Icons.person, color: AppColors.textTertiary)
            : null,
      ),
      title: Text(user.nickname,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: isOwn
          ? null
          : isFollowing
              ? ElevatedButton(
                  onPressed: () =>
                      ref.read(userRepoProvider).unfollow(viewerUid!, user.uid),
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
                  onPressed: () =>
                      ref.read(userRepoProvider).follow(viewerUid!, user.uid),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(72, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(fontSize: 13),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('팔로우'),
                ),
    );
  }
}
