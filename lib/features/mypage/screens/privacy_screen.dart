import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보처리방침')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: _PrivacyContent(),
      ),
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Header('개인정보처리방침'),
        _Body('최종 수정일: 2025년 6월 1일\n시행일: 2025년 6월 1일\n\n문어다방(이하 "회사")은 이용자의 개인정보를 소중히 여기며, 「개인정보 보호법」 등 관련 법령에 따라 개인정보를 처리합니다.'),
        _Section('1. 수집하는 개인정보 항목',
            '[필수 항목]\n• 소셜 로그인 식별값(애플·카카오·네이버 고유 ID)\n• 이메일 주소\n• 닉네임\n\n[선택 항목]\n• 프로필 사진\n• 자기소개(바이오)\n• 관심 카테고리(잉크, 펜, 노트 등)\n\n[서비스 이용 과정에서 자동 수집]\n• 기기 정보(OS 종류, 기기 모델)\n• FCM 푸시 토큰\n• 서비스 이용 기록(게시글, 리뷰, 댓글, 좋아요 등)'),
        _Section('2. 개인정보 수집 및 이용 목적',
            '① 회원 가입 및 본인 확인\n② 서비스 제공 (커뮤니티, 리뷰, 잉크 차트 등)\n③ 푸시 알림 발송 (좋아요, 댓글, 팔로우 알림)\n④ 서비스 개선 및 신규 기능 개발\n⑤ 법령 의무 이행 및 분쟁 처리'),
        _Section('3. 개인정보 보유 및 이용 기간',
            '회원 탈퇴 시 지체 없이 파기합니다. 단, 관련 법령에 따라 아래 정보는 일정 기간 보관됩니다.\n\n• 서비스 이용 관련 분쟁 기록: 3년 (전자상거래 등에서의 소비자보호에 관한 법률)\n• 통신 비밀 관련 기록: 3개월 (통신비밀보호법)'),
        _Section('4. 개인정보의 제3자 제공',
            '회사는 원칙적으로 이용자의 개인정보를 외부에 제공하지 않습니다. 다만, 다음의 경우는 예외입니다.\n\n① 이용자가 사전에 동의한 경우\n② 법령의 규정에 따르거나 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우'),
        _Section('5. 개인정보 처리 위탁',
            '회사는 서비스 제공을 위해 아래와 같이 개인정보 처리를 위탁하고 있습니다.\n\n• 수탁업체: Google Firebase (Google LLC)\n• 위탁 업무: 데이터베이스 저장·관리, 인증, 파일 저장, 푸시 알림\n• 보유 기간: 회원 탈퇴 또는 위탁 계약 종료 시까지'),
        _Section('6. 이용자의 권리',
            '이용자는 언제든지 아래 권리를 행사할 수 있습니다.\n\n① 개인정보 열람 요청\n② 오류 정정 요청\n③ 삭제 요청 (회원 탈퇴)\n④ 처리 정지 요청\n\n위 요청은 앱 내 설정 → 회원탈퇴 또는 문의하기를 통해 가능합니다.'),
        _Section('7. 개인정보의 파기',
            '보유 기간이 경과하거나 처리 목적이 달성된 개인정보는 지체 없이 파기합니다.\n\n• 전자적 파일: 복원이 불가능한 방법으로 영구 삭제\n• 종이 문서: 분쇄 또는 소각'),
        _Section('8. 개인정보 보호를 위한 기술적·관리적 조치',
            '• 개인정보 전송 시 SSL 암호화\n• Firebase Security Rules를 통한 접근 권한 통제\n• 최소한의 인원만 개인정보에 접근\n• 정기적인 보안 점검'),
        _Section('9. 쿠키 및 자동 수집 도구',
            '서비스는 쿠키를 직접 사용하지 않으나, Firebase 등 제3자 서비스에서 서비스 품질 향상을 위한 기술적 정보를 수집할 수 있습니다. 자세한 내용은 Google의 개인정보처리방침을 참고해 주세요.'),
        _Section('10. 개인정보 보호책임자',
            '개인정보 관련 문의는 앱 내 설정 → 문의하기를 통해 접수할 수 있습니다.\n\n회사는 이용자의 개인정보 보호 관련 문의에 신속하게 답변 드리겠습니다.'),
        _Section('11. 개인정보처리방침 변경',
            '이 방침은 법령·정책 변경 시 개정될 수 있습니다. 변경 시 앱 공지 또는 화면 내 안내를 통해 사전 고지합니다.'),
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
