import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/search_utils.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/center_toast.dart';
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
          if (kDebugMode) ...[
            const Divider(),
            const _SectionHeader('개발자 설정'),
            ListTile(
              title: const Text('아카이브 DB 초기화 (CSV)'),
              subtitle: const Text('assets/info_csv 내 CSV 파일을 Firestore에 업로드'),
              trailing: const Icon(Icons.cloud_upload),
              onTap: () async {
                try {
                  showCenterToast(context, message: 'DB 초기화 시작...');
                  await ref.read(archiveRepoProvider).initializeDatabase();
                  if (context.mounted) {
                    showCenterToast(context, message: 'DB 초기화 완료!', icon: Icons.check_circle);
                  }
                } catch (e) {
                  if (context.mounted) {
                    showCenterToast(context,
                        message: '초기화 실패: $e', icon: Icons.error_outline, iconColor: AppColors.error);
                  }
                }
              },
            ),
            ListTile(
              title: const Text('검색 인덱스 생성 (1회용)'),
              subtitle: const Text('기존 리뷰·게시글에 searchIndex 필드 추가'),
              trailing: const Icon(Icons.manage_search),
              onTap: () => _runSearchIndexMigration(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runSearchIndexMigration(BuildContext context) async {
    final db = FirebaseFirestore.instance;
    int updated = 0;
    int failed = 0;

    showCenterToast(context, message: '검색 인덱스 생성 중...');

    try {
      // reviews
      final reviewSnap = await db.collection('reviews').get();
      for (final doc in reviewSnap.docs) {
        try {
          final data = doc.data();
          final title = data['title'] as String? ?? '';
          final body = data['body'] as String? ?? '';
          await doc.reference.update({
            'searchIndex': SearchUtils.buildIndex(title, body),
          });
          updated++;
        } catch (_) {
          failed++;
        }
      }

      // posts
      final postSnap = await db.collection('posts').get();
      for (final doc in postSnap.docs) {
        try {
          final data = doc.data();
          final title = data['title'] as String? ?? '';
          final body = data['body'] as String? ?? '';
          await doc.reference.update({
            'searchIndex': SearchUtils.buildIndex(title, body),
          });
          updated++;
        } catch (_) {
          failed++;
        }
      }

      if (context.mounted) {
        showCenterToast(context,
            message: '완료: $updated건 업데이트, $failed건 실패', icon: Icons.check_circle);
      }
    } catch (e) {
      if (context.mounted) {
        showCenterToast(context,
            message: '오류: $e', icon: Icons.error_outline, iconColor: AppColors.error);
      }
    }
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
