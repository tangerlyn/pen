import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/providers.dart';
import '../providers/notification_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifSettings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const _SectionHeader('알림 설정'),
          _SwitchTile(
            title: '좋아요',
            value: notifSettings.likes,
            onChanged: (v) => ref.read(notificationSettingsProvider.notifier).setLikes(v),
          ),
          _SwitchTile(
            title: '댓글',
            value: notifSettings.comments,
            onChanged: (v) => ref.read(notificationSettingsProvider.notifier).setComments(v),
          ),
          _SwitchTile(
            title: '팔로우',
            value: notifSettings.follows,
            onChanged: (v) => ref.read(notificationSettingsProvider.notifier).setFollows(v),
          ),
          const Divider(),
          const _SectionHeader('계정'),
          ListTile(
            title: const Text('차단 목록'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/mypage/settings/blocked'),
          ),
          ListTile(
            title: const Text('문의하기'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/mypage/settings/inquiries'),
          ),
          ListTile(
            title: const Text('이용약관'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/mypage/settings/terms'),
          ),
          ListTile(
            title: const Text('개인정보처리방침'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/mypage/settings/privacy'),
          ),
          const Divider(),
          ListTile(
            title: const Text('로그아웃'),
            onTap: () => _showLogoutDialog(context, ref),
          ),
          ListTile(
            title: const Text('회원탈퇴', style: TextStyle(color: AppColors.error)),
            onTap: () => _showDeleteAccountDialog(context, ref),
          ),
          if (kDebugMode) ...[
            const Divider(),
            const _SectionHeader('개발자 설정'),
            ListTile(
              title: const Text('아카이브 DB 초기화 (CSV)'),
              subtitle: const Text('assets/info_csv 내 CSV 파일을 Firestore에 업로드'),
              trailing: const Icon(Icons.cloud_upload),
              onTap: () async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('DB 초기화 시작...')),
                  );
                  await ref.read(archiveRepoProvider).initializeDatabase();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('DB 초기화 완료!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('초기화 실패: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).signOut();
            },
            child: const Text('로그아웃', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('탈퇴하면 모든 데이터가 삭제됩니다.\n정말 탈퇴하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).deleteAccount();
            },
            child: const Text('탈퇴', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.title, required this.value, required this.onChanged});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}
