import 'package:cloud_firestore/cloud_firestore.dart';

/// 홈 상단 배너. Firestore `banners` 컬렉션에서 운영자가 콘솔로 관리한다
/// (앱에서는 읽기만 가능). 등록된 배너가 없으면 [BannerModel.welcome]을 보여준다.
///
/// 문서 필드 (콘솔에서 추가할 때)
/// - title (string, 필수): 배너 큰 글씨
/// - subtitle (string): 배너 작은 글씨
/// - body (string): 상세 화면 본문. 줄바꿈으로 문단을 나누고,
///   `# `로 시작하는 줄은 소제목으로 보인다.
/// - imageUrl (string): 배너 이미지(가로형). 없으면 네이비 기본 디자인.
/// - linkUrl / linkLabel (string): 상세 화면 하단 버튼. `/`로 시작하면 앱 안 화면,
///   그 외에는 외부 브라우저로 연다.
/// - order (number): 작을수록 앞. active (bool): false면 숨김.
class BannerModel {
  const BannerModel({
    required this.id,
    required this.title,
    this.subtitle = '',
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
  final String body;
  final String? imageUrl;
  final String? linkUrl;
  final String? linkLabel;
  final int order;
  final bool active;

  static String? _nonEmpty(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  factory BannerModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return BannerModel(
      id: doc.id,
      title: (d['title'] as String?)?.trim() ?? '',
      subtitle: (d['subtitle'] as String?)?.trim() ?? '',
      // 콘솔 입력창에서는 줄바꿈을 넣기 어려워 `\n` 문자열도 줄바꿈으로 취급한다.
      body: ((d['body'] as String?) ?? '').replaceAll(r'\n', '\n'),
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
    title: '만티에 오신 걸 환영해요',
    subtitle: '만년필 · 잉크 · 종이 이야기를 나누는 곳',
    body: '''어떤 잉크가 내 펜에 어울릴지, 이 색은 종이에 쓰면 어떤 느낌일지 궁금했던 적 있으신가요? 만티에서는 직접 써본 사람들의 사진과 후기로 바로 확인할 수 있어요.

# 리뷰
사진 중심으로 잉크와 만년필 리뷰를 둘러보세요. 리뷰에 쓴 잉크와 펜이 태그돼 있어서 어떤 조합인지 한눈에 알 수 있어요.

# 아카이브
잉크와 만년필을 브랜드, 색상 계열, 종류별로 찾아보고 제품마다 모인 리뷰를 확인해 보세요. 찾는 제품이 없으면 직접 등록할 수 있어요.

# 잉크 차트
직접 찍은 스와치 사진으로 나만의 잉크 차트를 만들고, 갖고 있는 잉크를 정리해 보세요.

# 커뮤니티
질문, 정보 공유, 필사, 그림 게시판에서 펜과 잉크 이야기를 자유롭게 나눠 보세요.

첫 리뷰를 남겨 보세요. 만티가 여러분의 잉크 기록을 기다리고 있어요.''',
    linkUrl: '/write/review?entry=home',
    linkLabel: '첫 리뷰 쓰러 가기',
  );
}
