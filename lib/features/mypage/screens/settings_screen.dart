import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
            onChanged: (v) =>
                ref.read(notificationSettingsProvider.notifier).setLikes(v),
          ),
          _SwitchTile(
            title: '댓글',
            value: notifSettings.comments,
            onChanged: (v) =>
                ref.read(notificationSettingsProvider.notifier).setComments(v),
          ),
          _SwitchTile(
            title: '팔로우',
            value: notifSettings.follows,
            onChanged: (v) =>
                ref.read(notificationSettingsProvider.notifier).setFollows(v),
          ),
          const Divider(),
          const _SectionHeader('계정'),
          ListTile(
            title: const Text('프로필 편집'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/mypage/edit'),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
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
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(ref: ref),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _isDeleting = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      await widget.ref.read(authServiceProvider).deleteAccount();
      if (!mounted) return;
      // pop 이후엔 이 State의 context가 곧바로 deactivate될 수 있어,
      // 라우터 참조를 미리 잡아둔다.
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      // 라우터의 redirect가 auth 상태 변화에 반응해 자동으로 /login으로
      // 보내주는 걸 기다리지 않고, 삭제 성공이 확정된 시점에 명시적으로
      // 이동시켜 타이밍에 좌우되지 않게 한다.
      router.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = e is FirebaseAuthException && e.code == 'requires-recent-login'
            ? '보안을 위해 재인증이 필요해요. 다시 시도해주세요.'
            : '탈퇴에 실패했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('회원 탈퇴'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('탈퇴하면 모든 데이터가 삭제됩니다.\n정말 탈퇴하시겠습니까?'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _isDeleting ? null : _delete,
          child: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('탈퇴', style: TextStyle(color: AppColors.error)),
        ),
      ],
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
      child: Text(
        title,
        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });
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
