import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 첫 탭에 무엇을 보여줄지 — Remote Config `home_variant`.
/// 기록 홈 전환 후 문제가 생기면 콘솔에서 `discover`로 바꿔 앱 업데이트 없이 되돌린다.
enum HomeVariant {
  record('record'),
  discover('discover');

  const HomeVariant(this.wireName);
  final String wireName;

  static HomeVariant fromWire(String value) => HomeVariant.values
      .firstWhere((v) => v.wireName == value, orElse: () => record);
}

const kHomeVariantKey = 'home_variant';

/// 값을 못 받으면(오프라인·오류) 기본값 record. 앱 실행 중 한 번만 읽는다.
final homeVariantProvider = FutureProvider<HomeVariant>((ref) async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setDefaults({kHomeVariantKey: HomeVariant.record.wireName});
    await remoteConfig.fetchAndActivate();
    return HomeVariant.fromWire(remoteConfig.getString(kHomeVariantKey));
  } catch (_) {
    return HomeVariant.record;
  }
});
