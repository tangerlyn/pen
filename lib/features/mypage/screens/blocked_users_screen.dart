import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/center_toast.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../data/models/user_model.dart';
import '../providers/user_activity_provider.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(currentUidProvider);
    final blockedAsync = ref.watch(blockedUsersDetailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('차단 목록')),
      body: blockedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (users) {
          final valid = users.whereType<UserModel>().toList();
          if (valid.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block, size: 52, color: AppColors.textTertiary),
                  SizedBox(height: 12),
                  Text(
                    '차단한 사용자가 없습니다',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: valid.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _BlockedUserTile(
              user: valid[i],
              onUnblock: currentUid == null
                  ? null
                  : () => _confirmUnblock(context, ref, currentUid, valid[i]),
            ),
          );
        },
      ),
    );
  }

  void _confirmUnblock(
    BuildContext context,
    WidgetRef ref,
    String myUid,
    UserModel target,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('차단 해제'),
        content: Text('${target.nickname} 님의 차단을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(userRepoProvider).unblock(myUid, target.uid);
              if (context.mounted) {
                showCenterToast(
                  context,
                  message: '차단이 해제되었습니다.',
                  icon: Icons.check_circle,
                );
              }
            },
            child: const Text('해제'),
          ),
        ],
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({required this.user, required this.onUnblock});
  final UserModel user;
  final VoidCallback? onUnblock;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: UserAvatar(imageUrl: user.profileImageUrl, radius: 24),
      title: Text(
        user.nickname,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: OutlinedButton(
        onPressed: onUnblock,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(72, 34),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 13),
        ),
        child: const Text('차단 해제'),
      ),
    );
  }
}
