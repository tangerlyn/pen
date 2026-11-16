import 'package:cloud_firestore/cloud_firestore.dart';

/// 홈 상단 배너. Firestore `banners` 컬렉션에서 운영자가 콘솔로 관리한다
/// (앱에서는 읽기만 가능). 등록된 배너가 없으면 [BannerModel.welcome]을 보여준다.
///
/// 문서 필드 (콘솔에서 추가할 때)
/// - title (string, 필수): 배너 큰 글씨. `\n`으로 두 줄까지.
/// - subtitle (string): 큰 글씨 아래 작은 글씨 한 줄
/// - label (string): 큰 글씨 위 작은 꼬리표 (예: "이벤트", "공지")
/// - backgroundColor (string): 이미지 없을 때 배경색 hex (예: "#EDE7DA")
/// - body (string): 상세 화면 본문. 줄바꿈으로 문단을 나누고,
///   `# `로 시작하는 줄은 소제목으로 보인다.
/// - imageUrl (string): 배너 이미지(가로형). 있으면 이미지 위에 흰 글씨.
/// - linkUrl / linkLabel (string): 상세 화면 하단 버튼. `/`로 시작하면 앱 안 화면,
///   그 외에는 외부 브라우저로 연다.
/// - order (number): 작을수록 앞. active (bool): false면 숨김.
class BannerModel {
  const BannerModel({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.label,
    this.backgroundColor,
    this.body = '',
    this.imageUrl,
    this.linkUrl,
    this.linkLabel,
    this.order = 0,
    this.active = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? label;
  final String? backgroundColor;
  final String body;
  final String? imageUrl;
  final String? linkUrl;
  final String? linkLabel;
  final int order;
  final bool active;

  static String? _nonEmpty(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  // 콘솔 입력창에서는 줄바꿈을 넣기 어려워 `\n` 문자열도 줄바꿈으로 취급한다.
  static String _lines(Object? v) =>
      ((v as String?) ?? '').replaceAll(r'\n', '\n').trim();

  factory BannerModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return BannerModel(
      id: doc.id,
      title: _lines(d['title']),
      subtitle: _lines(d['subtitle']),
      label: _nonEmpty(d['label']),
      backgroundColor: _nonEmpty(d['backgroundColor']),
      body: _lines(d['body']),
      imageUrl: _nonEmpty(d['imageUrl']),
      linkUrl: _nonEmpty(d['linkUrl']),
      linkLabel: _nonEmpty(d['linkLabel']),
      order: (d['order'] as num?)?.toInt() ?? 0,
      active: d['active'] as bool? ?? true,
    );
  }

  /// 첫 출시용 기본 배너 — 콘솔에 배너가 하나도 없을 때 보인다.
  static const welcome = BannerModel(
    id: 'welcome',
    label: '만티 오픈',
    title: '이 잉크, 실제로 쓰면\n어떤 색일까?',
    subtitle: '써본 사람들의 리뷰로 확인해 보세요',
    backgroundColor: '#EDE7DA',
    body: '''만티는 만년필과 잉크를 좋아하는 사람들이 모여 리뷰를 나누는 곳이에요.

화면으로 보던 잉크 색과 실제로 종이에 쓴 색이 달라서 아쉬웠던 적이 있다면, 만티에서 다른 사람들이 직접 찍은 사진을 먼저 확인해 보세요. 리뷰마다 어떤 잉크와 펜을 썼는지 태그가 달려 있어요.

# 이런 걸 할 수 있어요
아카이브에서 잉크와 만년필을 찾아보고, 제품마다 모인 리뷰를 확인할 수 있어요. 갖고 있는 잉크는 스와치 사진으로 잉크 차트에 모아 두면 좋아요. 궁금한 건 커뮤니티에 물어보세요.

# 첫 리뷰를 기다려요
아직 시작하는 단계라 여러분의 리뷰 한 편이 다른 사람에게 큰 도움이 돼요. 요즘 쓰는 잉크가 있다면 사진 한 장으로 남겨 주세요.''',
    linkUrl: '/write/review?entry=home',
    linkLabel: '리뷰 쓰러 가기',
  );
}
