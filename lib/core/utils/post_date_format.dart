import 'package:timeago/timeago.dart' as timeago;

/// 커뮤니티/리뷰 게시물·댓글용 날짜 표기.
/// 3일 이내는 상대 시간("방금", "N분 전", "N시간 전", "1~3일 전")으로,
/// 그 이후는 "YYYY.MM.DD"로 표기한다.
String formatPostDate(DateTime date) {
  final diffDays = DateTime.now().difference(date).inDays;
  if (diffDays >= 4) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
  if (diffDays >= 1) return '$diffDays일 전';
  return timeago.format(date, locale: 'ko');
}
