import 'package:flutter_test/flutter_test.dart';
import 'package:mannti/core/constants/app_constants.dart';

void main() {
  test('the public product name is consistent', () {
    expect(AppConstants.appName, '만티(MANNTI)');
    expect(AppConstants.appNameKorean, '만티');
    expect(AppConstants.appNameEnglish, 'MANNTI');
  });
}
