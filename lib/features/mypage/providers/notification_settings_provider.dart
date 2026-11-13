import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';

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

// 알림 발송 여부는 서버(functions)가 users/{uid}.notificationSettings를 보고
// 정하므로, 화면도 기기 저장값이 아니라 계정의 그 값을 기준으로 보여준다.
// 계정이 바뀌거나 로그아웃하면 provider가 새로 만들어져 상태가 초기화된다.
class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier(this._uid) : super(const NotificationSettings()) {
    _load();
  }

  final String? _uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc => _uid == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_uid);

  Future<void> _load() async {
    final doc = _userDoc;
    if (doc == null) return;
    try {
      final snap = await doc.get();
      final map = snap.data()?['notificationSettings'];
      if (!mounted || map is! Map) return;
      state = NotificationSettings(
        likes: map['likes'] as bool? ?? true,
        comments: map['comments'] as bool? ?? true,
        follows: map['follows'] as bool? ?? true,
      );
    } catch (_) {}
  }

  Future<void> _sync(
    String field,
    bool value,
    NotificationSettings previous,
  ) async {
    final doc = _userDoc;
    if (doc == null) return;
    try {
      await doc.update({'notificationSettings.$field': value});
    } catch (_) {
      // 저장에 실패하면 스위치를 원래대로 돌려 실제 서버 값과 어긋나지 않게 한다
      if (mounted) state = previous;
    }
  }

  void setLikes(bool v) {
    final prev = state;
    state = state.copyWith(likes: v);
    _sync('likes', v, prev);
  }

  void setComments(bool v) {
    final prev = state;
    state = state.copyWith(comments: v);
    _sync('comments', v, prev);
  }

  void setFollows(bool v) {
    final prev = state;
    state = state.copyWith(follows: v);
    _sync('follows', v, prev);
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  (ref) => NotificationSettingsNotifier(ref.watch(currentUidProvider)),
);
