<div align="center">

# 문어다방

**만년필 · 잉크 · 종이 덕후를 위한 커뮤니티 앱**

제품 아카이브 탐색, 잉크 리뷰 공유, 커뮤니티 소통, 잉크 차트 관리까지 한 곳에서.

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.x-00BCD4?style=for-the-badge&logo=dart&logoColor=white)](https://riverpod.dev)

</div>

---

## 주요 기능

| 기능 | 설명 |
|---|---|
| **리뷰** | 잉크·만년필에 별점·사진·텍스트 리뷰 작성. 좋아요·댓글·대댓글 지원 |
| **아카이브** | 잉크·만년필 DB 탐색. 색상 계열·브랜드·종류 필터, 제품별 리뷰 통계 |
| **커뮤니티** | 질문·정보공유 게시판. 카테고리 필터, 인기글, 이미지 첨부 |
| **잉크 차트** | 직접 찍은 스와치 사진으로 개인 잉크 차트 제작·공유·저장 |
| **검색** | 리뷰·커뮤니티 통합 검색. 검색 기록·자동완성·무한 스크롤 |
| **채팅** | 1:1 DM |
| **팔로우** | 유저 팔로우, 팔로잉 피드 필터 |

---

## 기술 스택

<table>
  <tr>
    <td><b>Framework</b></td>
    <td>Flutter 3 / Dart 3</td>
  </tr>
  <tr>
    <td><b>상태 관리</b></td>
    <td>Riverpod 2 (StateNotifier, AsyncNotifier, StreamProvider)</td>
  </tr>
  <tr>
    <td><b>라우팅</b></td>
    <td>go_router</td>
  </tr>
  <tr>
    <td><b>백엔드</b></td>
    <td>Firebase Auth · Firestore · Storage · Messaging · Remote Config</td>
  </tr>
  <tr>
    <td><b>소셜 로그인</b></td>
    <td>카카오 · 네이버 · Apple</td>
  </tr>
  <tr>
    <td><b>이미지</b></td>
    <td>image_picker · flutter_image_compress · cached_network_image</td>
  </tr>
  <tr>
    <td><b>기타</b></td>
    <td>shared_preferences · timeago · smooth_page_indicator · palette_generator</td>
  </tr>
</table>

---

## 프로젝트 구조

```
lib/
├── core/
│   ├── constants/      앱 상수, 비밀키 (gitignore)
│   ├── router/         go_router 라우트 정의
│   ├── shell/          하단 탭 NavigationShell
│   ├── theme/          색상·타이포·간격 토큰
│   └── utils/          레벨 시스템, 네트워크 유틸
├── data/
│   ├── models/         Firestore 데이터 모델
│   ├── repositories/   Firestore CRUD 레이어
│   └── services/       Auth, Storage 서비스
├── features/
│   ├── auth/           로그인·회원가입
│   ├── home/           홈 피드 (디스커버리)
│   ├── review/         리뷰 피드·작성
│   ├── community/      커뮤니티 게시판
│   ├── archive/        제품 아카이브
│   ├── mypage/         마이페이지·잉크차트·설정
│   ├── chat/           1:1 채팅
│   └── search/         통합 검색
└── shared/
    ├── providers/      전역 Provider (auth, user, archive repo 등)
    └── widgets/        공통 위젯 (카드, 스켈레톤, 별점 등)
```

---

## 로컬 실행

```bash
# 의존성 설치
flutter pub get

# 실행 (iOS/Android)
flutter run
```

> **Firebase 설정 필요**
> - `google-services.json` → `android/app/`
> - `GoogleService-Info.plist` → `ios/Runner/`
> - `lib/core/constants/app_secrets.dart` (gitignore 처리됨)

---

## 페이지별 상세 문서

| 문서 | 내용 |
|---|---|
| [auth.md](docs/auth.md) | 로그인·회원가입 플로우 |
| [home.md](docs/home.md) | 홈 피드 (디스커버리) |
| [review.md](docs/review.md) | 리뷰 피드·작성·상세 |
| [community.md](docs/community.md) | 커뮤니티 게시판 |
| [archive.md](docs/archive.md) | 제품 아카이브 |
| [mypage.md](docs/mypage.md) | 마이페이지·잉크차트·설정 |
| [search.md](docs/search.md) | 통합 검색 |
| [chat.md](docs/chat.md) | 1:1 채팅 |
