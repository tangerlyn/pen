import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FcmService {
  FcmService({
    required this.onNavigate,
    required this.onTokenRefresh,
  });

  final void Function(String route) onNavigate;
  final void Function(String uid, String token) onTokenRefresh;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  static const _channelId = 'nibpen_notifications';
  static const _channelName = '펜귄 알림';

  Future<void> initialize() async {
    await _requestPermission();
    await _initLocalNotifications();

    // iOS 포그라운드 알림 표시 설정
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 토큰 갱신 리스너
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) onTokenRefresh(uid, token);
    });

    // 포그라운드 메시지 → 로컬 알림
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // 백그라운드에서 알림 탭
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 종료 상태에서 알림 탭
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      await Future.delayed(const Duration(milliseconds: 500));
      _handleTap(initial);
    }
  }

  Future<void> saveToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('[FCM] 토큰 저장 실패: $e');
    }
  }

  Future<void> _requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) onNavigate(details.payload!);
      },
    );

    // Android 알림 채널 생성
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
        ));
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final route = _routeFrom(message.data);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: route,
    );
  }

  void _handleTap(RemoteMessage message) {
    final route = _routeFrom(message.data);
    if (route != null) onNavigate(route);
  }

  String? _routeFrom(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'like_review':
      case 'comment_review':
        final id = data['reviewId'] as String?;
        return id != null ? '/review/$id' : null;
      case 'like_post':
      case 'comment_post':
        final id = data['postId'] as String?;
        return id != null ? '/community/$id' : null;
      case 'follow':
        final id = data['fromUid'] as String?;
        return id != null ? '/profile/$id' : null;
      case 'inquiry_answered':
        final id = data['inquiryId'] as String?;
        return id != null ? '/mypage/settings/inquiries/$id' : null;
      default:
        return null;
    }
  }
}
