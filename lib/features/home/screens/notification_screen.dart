import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_navigation.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../providers/notification_provider.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  Future<void> _markAllRead(String uid) async {
    final col = FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items');
    final snap = await col.where('isRead', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _markRead(String uid, String itemId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .doc(itemId)
        .update({'isRead': true});
  }

  void _navigate(BuildContext context, WidgetRef ref, NotificationItem item) {
    if (item.type == 'follow') {
      navigateToProfile(context, ref, item.fromUid);
    } else if (item.type == 'inquiry_answered') {
      context.push('/mypage/settings/inquiries/${item.targetId}');
    } else if (item.targetType == 'review') {
      context.push('/review/${item.targetId}');
    } else if (item.targetType == 'post') {
      context.push('/community/${item.targetId}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () => _markAllRead(uid),
              child: Text(
                '모두 읽음',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '알림이 없습니다',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = items[i];
              return _NotificationTile(
                item: item,
                onTap: () async {
                  if (!item.isRead && uid != null) {
                    await _markRead(uid, item.id);
                  }
                  if (context.mounted) _navigate(context, ref, item);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});
  final NotificationItem item;
  final VoidCallback onTap;

  IconData get _typeIcon {
    return switch (item.type) {
      'like' => Icons.favorite,
      'comment' => Icons.chat_bubble,
      'follow' => Icons.person_add,
      'inquiry_answered' => Icons.mail,
      _ => Icons.notifications,
    };
  }

  Color get _typeColor {
    return switch (item.type) {
      'like' => AppColors.error,
      'comment' => AppColors.primary,
      'follow' => const Color(0xFF43A047),
      'inquiry_answered' => const Color(0xFFFB8C00),
      _ => AppColors.textTertiary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        color: item.isRead ? AppColors.surface : const Color(0xFFFFF8F0),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 + 타입 아이콘 오버레이
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(imageUrl: item.fromProfileImageUrl, radius: 22),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _typeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                    child: Icon(_typeIcon, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            // 메시지 + 시간
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
                      children: [
                        TextSpan(
                          text: item.fromNickname,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' ${item.message}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(item.createdAt, locale: 'ko'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm, top: 6),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: AppColors.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
