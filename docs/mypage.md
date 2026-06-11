# 마이페이지 (Mypage)

## 개요

내 프로필·활동 내역 조회, 잉크 차트 관리, 다른 유저 프로필 탐색, 앱 설정.

---

## 화면 목록

### `mypage_screen.dart`
- 경로: `/mypage` (하단 탭 5번째)
- 프로필 사진, 닉네임, 소개, 레벨 뱃지
- 팔로워 / 팔로잉 수 → 탭 시 `/profile/:uid/followers`
- 잉크 차트 바로가기 버튼 → `/ink-chart`
- **탭 3개**
  - 내 리뷰 — 작성한 리뷰 그리드
  - 스크랩 — 북마크한 리뷰
  - 게시글 — 작성한 커뮤니티 글

### `user_profile_screen.dart`
- 경로: `/profile/:uid`
- 다른 유저의 프로필 페이지 (본인 mypage와 동일 레이아웃)
- 팔로우 / 언팔로우 버튼
- 차단 메뉴 (신고 포함)

### `profile_edit_screen.dart`
- 경로: `/mypage/edit`
- 프로필 사진 변경 (갤러리), 닉네임, 한 줄 소개 수정

### `follow_list_screen.dart`
- 경로: `/profile/:uid/followers?tab=0|1`
- 팔로워 / 팔로잉 탭 전환
- 각 항목에서 팔로우/언팔로우 즉시 반영

---

## 잉크 차트

### `ink_book_list_screen.dart`
- 경로: `/ink-chart`
- 잉크 차트 목록 그리드
- 새 차트 만들기 셀 (이름 입력 다이얼로그)

### `ink_book_detail_screen.dart`
- 경로: `/ink-chart/:bookId`
- **스와치 페이지** — 3×3 격자로 잉크 스와치 나열
- **뷰 모드** — 좌우 스와이프 / 위아래 스와이프 전환
- **페이지 스타일** — 실선 / 격자 / 민무늬 배경
- **정렬** — 기본순 / 브랜드순 / 색상순 (palette_generator 기반 주요 색상 추출)
- **드래그 정렬** — 길게 누른 후 순서 변경
- **내보내기** — 화면 캡처 후 갤러리 저장 (gal 패키지)
- 잉크 추가 FAB → `/ink-chart/:bookId/add`

### `ink_chart_add_screen.dart`
- 경로: `/ink-chart/:bookId/add`
- 잉크 검색 → 선택 → 스와치 사진 촬영/선택 → 차트에 추가

### `ink_crop_screen.dart`
- 스와치 이미지 크롭 화면 (원형·사각형 등 모양 선택)

---

## 설정

### `settings_screen.dart`
- 경로: `/mypage/settings`
- 알림 설정 — 좋아요·댓글·팔로우 토글 (Firestore에 저장)
- 차단 목록 → `/mypage/settings/blocked`
- 문의하기 → `/mypage/settings/inquiries`
- 이용약관 / 개인정보처리방침
- 로그아웃 / 회원탈퇴 (확인 다이얼로그)
- 디버그 모드: 아카이브 DB 초기화 버튼

### `blocked_users_screen.dart`
- 경로: `/mypage/settings/blocked`
- 차단한 유저 목록, 차단 해제 가능

### `inquiry_screen.dart`
- 경로: `/mypage/settings/inquiries`
- 문의 목록 조회, 새 문의 작성, 문의 상세 (답변 포함)

---

## 레벨 시스템

`lib/core/utils/level_system.dart`에서 리뷰 수·좋아요 수 기반으로 레벨 뱃지 계산.

---

## 관련 파일

- `lib/features/mypage/providers/` — 알림 설정, 유저 활동 providers
- `lib/data/repositories/user_repository.dart`
- `lib/shared/providers/ink_book_providers.dart`
- `lib/data/repositories/ink_book_repository.dart`
