import 'package:flutter_test/flutter_test.dart';
import 'package:mannti/shared/providers/recently_viewed_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('최근 본 기록: 최신이 앞, 중복 제거, 최대 개수 유지', () async {
    final n = RecentlyViewedNotifier('u1');
    await _settle();
    await n.record('ink', 'a');
    await n.record('pen', 'b');
    await n.record('ink', 'a'); // 다시 보면 맨 앞으로
    expect(n.state, [(type: 'ink', id: 'a'), (type: 'pen', id: 'b')]);

    for (var i = 0; i < 20; i++) {
      await n.record('ink', 'x$i');
    }
    expect(n.state.length, RecentlyViewedNotifier.maxItems);
    expect(n.state.first, (type: 'ink', id: 'x19'));
  });

  test('계정별로 따로 저장되고 다시 열면 복원된다', () async {
    final a = RecentlyViewedNotifier('u1');
    await _settle();
    await a.record('ink', 'a');

    final b = RecentlyViewedNotifier('u2');
    await _settle();
    expect(b.state, isEmpty);

    final again = RecentlyViewedNotifier('u1');
    await _settle();
    expect(again.state, [(type: 'ink', id: 'a')]);
  });

  test('없어진 제품은 기록에서 빠진다', () async {
    final n = RecentlyViewedNotifier('u1');
    await _settle();
    await n.record('ink', 'a');
    await n.record('pen', 'b');
    await n.removeMissing({'ink:a'});
    expect(n.state, [(type: 'pen', id: 'b')]);
  });
}
