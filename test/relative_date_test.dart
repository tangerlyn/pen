import 'package:flutter_test/flutter_test.dart';
import 'package:mannti/core/utils/post_date_format.dart';

void main() {
  final now = DateTime(2026, 11, 12, 12);
  String ago(Duration d) => formatRelativeDate(now.subtract(d), now: now);

  test('목록 카드 상대 시간 구간', () {
    expect(ago(const Duration(seconds: 30)), '방금 전');
    expect(
      formatRelativeDate(now.add(const Duration(minutes: 5)), now: now),
      '방금 전',
    );
    expect(ago(const Duration(minutes: 1)), '1분 전');
    expect(ago(const Duration(minutes: 59)), '59분 전');
    expect(ago(const Duration(hours: 1)), '1시간 전');
    expect(ago(const Duration(hours: 23, minutes: 59)), '23시간 전');
    expect(ago(const Duration(days: 1)), '1일 전');
    expect(ago(const Duration(days: 6)), '6일 전');
    expect(ago(const Duration(days: 7)), '1주 전');
    expect(ago(const Duration(days: 29)), '4주 전');
    expect(ago(const Duration(days: 30)), '1개월 전');
    expect(ago(const Duration(days: 364)), '12개월 전');
    expect(ago(const Duration(days: 365)), '1년 전');
    expect(ago(const Duration(days: 800)), '2년 전');
  });
}
