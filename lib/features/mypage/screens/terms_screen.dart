import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이용약관')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: _TermsContent(),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Header('닙펜 서비스 이용약관'),
        _Body('최종 수정일: 2025년 6월 1일\n시행일: 2025년 6월 1일'),
        SizedBox(height: 8),
        _Section('제1조 (목적)',
            '이 약관은 닙펜(이하 "서비스")을 운영하는 운영자(이하 "회사")가 제공하는 만년필·잉크·노트 전문 커뮤니티 및 관련 서비스의 이용과 관련하여 회사와 이용자 간의 권리·의무 및 책임 사항, 기타 필요한 사항을 규정함을 목적으로 합니다.'),
        _Section('제2조 (정의)',
            '① "서비스"란 회사가 제공하는 닙펜 앱 및 이와 관련된 모든 기능을 의미합니다.\n② "이용자"란 이 약관에 동의하고 서비스를 이용하는 회원을 말합니다.\n③ "콘텐츠"란 이용자가 서비스 내에 게시한 리뷰, 게시글, 댓글, 이미지 등 일체의 정보를 말합니다.'),
        _Section('제3조 (약관의 효력 및 변경)',
            '① 이 약관은 서비스 내 공지 또는 앱 화면에 게시함으로써 효력이 발생합니다.\n② 회사는 관련 법령을 위반하지 않는 범위에서 약관을 변경할 수 있으며, 변경 시 시행일 7일 전까지 공지합니다.\n③ 이용자가 변경된 약관에 동의하지 않을 경우 서비스 이용을 중단하고 탈퇴할 수 있습니다.'),
        _Section('제4조 (회원가입)',
            '① 이용자는 회사가 정한 절차에 따라 소셜 로그인(애플, 카카오, 네이버) 방식으로 회원가입을 할 수 있습니다.\n② 만 14세 미만의 아동은 서비스에 가입할 수 없습니다.\n③ 타인의 정보를 도용하거나 허위 정보를 기재하여 가입한 경우 서비스 이용이 제한될 수 있습니다.'),
        _Section('제5조 (이용자의 의무)',
            '이용자는 다음 각 호의 행위를 해서는 안 됩니다.\n\n① 타인의 개인정보 무단 수집·이용·유포\n② 허위 정보 기재 또는 타인 사칭\n③ 서비스 운영을 방해하거나 서버에 과부하를 유발하는 행위\n④ 저작권 등 지식재산권을 침해하는 행위\n⑤ 음란물, 혐오 표현, 불법 콘텐츠 게시\n⑥ 영리를 목적으로 한 무단 광고·홍보 행위\n⑦ 기타 관련 법령 위반 행위'),
        _Section('제6조 (콘텐츠의 권리)',
            '① 이용자가 서비스에 게시한 콘텐츠의 저작권은 해당 이용자에게 귀속됩니다.\n② 이용자는 콘텐츠를 게시함으로써 회사에 서비스 운영, 개선, 홍보 목적에 한하여 해당 콘텐츠를 사용할 수 있는 비독점적 권리를 부여합니다.\n③ 회사는 이용자의 콘텐츠를 무단으로 상업적 목적에 사용하지 않습니다.'),
        _Section('제7조 (서비스 이용 제한)',
            '① 회사는 이용자가 제5조를 위반한 경우 사전 통지 없이 해당 콘텐츠를 삭제하거나 이용을 제한할 수 있습니다.\n② 위반의 정도가 중대한 경우 회원 자격을 영구 박탈할 수 있습니다.\n③ 이에 대해 이의가 있는 이용자는 서비스 내 문의하기를 통해 이의를 제기할 수 있습니다.'),
        _Section('제8조 (서비스 제공 및 중단)',
            '① 서비스는 연중무휴 24시간 제공함을 원칙으로 합니다.\n② 시스템 정기점검, 설비 증설·교체, 천재지변 등 불가피한 사유가 있는 경우 서비스의 전부 또는 일부가 일시 중단될 수 있습니다.\n③ 회사는 서비스를 변경하거나 종료할 경우 사전에 공지합니다.'),
        _Section('제9조 (면책조항)',
            '① 회사는 이용자 간의 분쟁, 거래에 관해 개입하지 않으며 이로 인한 손해에 책임을 지지 않습니다.\n② 이용자가 게시한 콘텐츠의 정확성·신뢰성에 대해 회사는 보증하지 않습니다.\n③ 회사의 귀책 없이 발생한 서비스 장애로 인한 손해에 대해 책임을 지지 않습니다.'),
        _Section('제10조 (준거법 및 관할)',
            '① 이 약관은 대한민국 법률에 따라 해석됩니다.\n② 서비스 이용과 관련된 분쟁이 발생한 경우 민사소송법상 관할 법원을 제1심 관할법원으로 합니다.'),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13, color: AppColors.textSecondary, height: 1.5));
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.65)),
        ],
      ),
    );
  }
}
