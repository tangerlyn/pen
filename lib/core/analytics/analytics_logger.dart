import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 이벤트 전송 창구. 화면·트래커는 이 인터페이스만 알고,
/// 테스트에서는 기록만 하는 가짜 구현으로 바꿔 끼운다.
/// 이벤트 명세: docs/analytics_spec.md
abstract class AnalyticsLogger {
  Future<void> logEvent(String name, Map<String, Object> params);
  Future<void> setUserProperty(String name, String value);
}

class FirebaseAnalyticsLogger implements AnalyticsLogger {
  FirebaseAnalyticsLogger([FirebaseAnalytics? analytics])
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {
    // 로그 전송 실패가 사용자 흐름을 막으면 안 되므로 예외를 삼킨다.
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('[Analytics] $name 전송 실패: $e');
    }
  }

  @override
  Future<void> setUserProperty(String name, String value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('[Analytics] 사용자 속성 $name 설정 실패: $e');
    }
  }
}

/// 테스트 데이터와 실사용 데이터를 나누는 사용자 속성 값.
/// TestFlight·내부 테스트 빌드는 `--dart-define=BUILD_ENV=testflight`로 빌드한다.
const buildEnv = String.fromEnvironment(
  'BUILD_ENV',
  defaultValue: kDebugMode ? 'debug' : 'prod',
);

final analyticsLoggerProvider = Provider<AnalyticsLogger>(
  (ref) => FirebaseAnalyticsLogger(),
);
