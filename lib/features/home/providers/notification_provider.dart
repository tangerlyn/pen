import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.targetId,
    required this.targetType,
    required this.fromUid,
    required this.fromNickname,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.fromProfileImageUrl,
  });

  final String id;
  final String type; // 'like' | 'comment' | 'follow'
  final String targetId;
  final String targetType; // 'review' | 'post' | ''
  final String fromUid;
  final String fromNickname;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? fromProfileImageUrl;

  factory NotificationItem.fromMap(Map<String, dynamic> data, String id) {
    return NotificationItem(
      id: id,
      type: data['type'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      targetType: data['targetType'] as String? ?? '',
      fromUid: data['fromUid'] as String? ?? '',
      fromNickname: data['fromNickname'] as String? ?? '누군가',
      message: data['message'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      fromProfileImageUrl: data['fromProfileImageUrl'] as String?,
    );
  }
}

final notificationsProvider = StreamProvider<List<NotificationItem>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('notifications')
      .doc(uid)
      .collection('items')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => NotificationItem.fromMap(d.data(), d.id))
          .toList());
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationsProvider)
      .maybeWhen(data: (list) => list.where((n) => !n.isRead).length, orElse: () => 0);
});
