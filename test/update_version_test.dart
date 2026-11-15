import 'package:flutter_test/flutter_test.dart';
import 'package:mannti/data/services/force_update_service.dart';

void main() {
  test('업데이트 버전 비교', () {
    const lower = ForceUpdateService.isVersionLower;
    expect(lower('1.0.0', '1.0.1'), isTrue);
    expect(lower('1.0.0', '1.1'), isTrue); // 자리 수가 달라도
    expect(lower('1.9.9', '2.0.0'), isTrue);
    expect(lower('1.0.0', '1.0.0'), isFalse);
    expect(lower('1.0.0', '1.0'), isFalse);
    expect(lower('1.2.0', '1.1.9'), isFalse);
    expect(lower('1.0.0+5', '1.0.0'), isFalse); // 빌드 번호는 무시
    expect(lower('1.0.0', 'abc'), isFalse); // 잘못된 값은 안내 안 함
  });
}
