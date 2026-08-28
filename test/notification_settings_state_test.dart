import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/features/mypage/providers/notification_settings_provider.dart';

void main() {
  test('notification defaults and copyWith preserve active channels', () {
    const defaults = NotificationSettings();
    final changed = defaults.copyWith(comments: false);

    expect(defaults.likes, isTrue);
    expect(defaults.comments, isTrue);
    expect(defaults.follows, isTrue);
    expect(changed.likes, isTrue);
    expect(changed.comments, isFalse);
    expect(changed.follows, isTrue);
  });
}
