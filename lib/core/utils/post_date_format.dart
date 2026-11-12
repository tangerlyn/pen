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

/// 목록 카드용 상대 시간. 정확한 날짜는 상세 화면에서 보여 준다.
/// 1분 미만 "방금 전" → "N분 전" → "N시간 전" → "N일 전"(7일 미만)
/// → "N주 전"(30일 미만) → "N개월 전"(1년 미만) → "N년 전".
String formatRelativeDate(DateTime date, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inMinutes < 1) return '방금 전'; // 기기 시계가 느려 미래 시각이어도 여기로
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}주 전';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}개월 전';
  return '${diff.inDays ~/ 365}년 전';
}
