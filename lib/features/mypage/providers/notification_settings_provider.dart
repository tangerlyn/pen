import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  const NotificationSettings({
    this.likes = true,
    this.comments = true,
    this.follows = true,
  });

  final bool likes;
  final bool comments;
  final bool follows;

  NotificationSettings copyWith({
    bool? likes,
    bool? comments,
    bool? follows,
  }) {
    return NotificationSettings(
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      follows: follows ?? this.follows,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      likes: prefs.getBool('notif_likes') ?? true,
      comments: prefs.getBool('notif_comments') ?? true,
      follows: prefs.getBool('notif_follows') ?? true,
    );
  }

  // SharedPreferences 저장 + Firestore 동기화
  Future<void> _sync(String prefsKey, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final field = prefsKey.replaceFirst('notif_', '');
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'notificationSettings.$field': value})
          .catchError((_) {});
    }
  }

  void setLikes(bool v) { state = state.copyWith(likes: v); _sync('notif_likes', v); }
  void setComments(bool v) { state = state.copyWith(comments: v); _sync('notif_comments', v); }
  void setFollows(bool v) { state = state.copyWith(follows: v); _sync('notif_follows', v); }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  (ref) => NotificationSettingsNotifier(),
);
