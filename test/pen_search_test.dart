import 'package:flutter_test/flutter_test.dart';
import 'package:mannti/data/models/pen_model.dart';

void main() {
  test('만년필은 한국어·영어 표기 모두로 검색된다', () {
    final pen = PenModel.fromMap({
      'brand': '파일럿',
      'modelName': '카쿠노',
      'brandEn': 'Pilot',
      'modelNameEn': 'Kakuno',
    }, 'pen_006');
    expect(pen.displayName, '파일럿 카쿠노');
    for (final q in ['파일럿', '카쿠노', 'pilot', 'KAKUNO', 'pilot kaku', '파일럿 카쿠']) {
      expect(pen.matches(q), isTrue, reason: q);
    }
    expect(pen.matches('라미'), isFalse);
  });

  test('영어 표기가 없는 예전 데이터도 그대로 검색된다', () {
    final pen = PenModel.fromMap({'brand': 'Pilot', 'modelName': 'Kakuno'}, 'x');
    expect(pen.matches('pilot'), isTrue);
    expect(pen.matches('파일럿'), isFalse);
  });
}
