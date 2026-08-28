import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/core/constants/app_constants.dart';

void main() {
  test('the public product name is consistent', () {
    expect(AppConstants.appName, '펜귄(PENGWYN)');
    expect(AppConstants.appNameKorean, '펜귄');
    expect(AppConstants.appNameEnglish, 'PENGWYN');
  });
}
