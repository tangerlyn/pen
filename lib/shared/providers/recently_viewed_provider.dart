import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';

/// 최근 본 잉크·만년필 한 건. [type]은 'ink' | 'pen'.
typedef RecentProduct = ({String type, String id});

/// 아카이브 상세를 연 기록 — 기기에만 저장한다(서버 비용 없음).
/// 계정마다 따로 저장해서, 같은 폰에서 다른 계정으로 로그인해도 섞이지 않는다.
class RecentlyViewedNotifier extends StateNotifier<List<RecentProduct>> {
  RecentlyViewedNotifier(this._uid) : super(const []) {
    _load();
  }

  static const maxItems = 12;
  final String? _uid;

  String? get _key => _uid == null ? null : 'recently_viewed_v1_$_uid';

  Future<void> _load() async {
    final key = _key;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(key) ?? const [];
      if (!mounted) return;
      state = raw.map(_decode).whereType<RecentProduct>().toList();
    } catch (_) {
      // 기록을 못 읽어도 홈은 그대로 — 섹션만 안 보인다.
    }
  }

  static RecentProduct? _decode(String s) {
    final i = s.indexOf(':');
    if (i <= 0 || i == s.length - 1) return null;
    final type = s.substring(0, i);
    if (type != 'ink' && type != 'pen') return null;
    return (type: type, id: s.substring(i + 1));
  }

  /// 맨 앞으로 올리고(중복 제거) 최대 [maxItems]개만 남긴다.
  Future<void> record(String type, String id) async {
    final next = [
      (type: type, id: id),
      ...state.where((p) => !(p.type == type && p.id == id)),
    ].take(maxItems).toList();
    state = next;
    final key = _key;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        key,
        next.map((p) => '${p.type}:${p.id}').toList(),
      );
    } catch (_) {}
  }

  /// 삭제된 제품처럼 더 이상 불러올 수 없는 항목을 기록에서 뺀다.
  Future<void> removeMissing(Set<String> missingKeys) async {
    if (missingKeys.isEmpty) return;
    final next =
        state.where((p) => !missingKeys.contains('${p.type}:${p.id}')).toList();
    state = next;
    final key = _key;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        key,
        next.map((p) => '${p.type}:${p.id}').toList(),
      );
    } catch (_) {}
  }
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<RecentProduct>>((ref) {
  return RecentlyViewedNotifier(ref.watch(currentUidProvider));
});
