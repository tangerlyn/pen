# 마이페이지 (Mypage)

## 개요

내 프로필·활동 내역 조회, 잉크 차트 관리, 다른 유저 프로필 탐색, 앱 설정.

---

## 화면 목록

### `mypage_screen.dart`
- 경로: `/mypage` (하단 탭 5번째)
- 프로필 사진, 닉네임, 소개, 레벨 뱃지
- 팔로워 / 팔로잉 수 → 탭 시 `/profile/:uid/followers`
- **내 잉크 차트 버튼** — `OutlinedButton` 스타일 (아이콘 + "내 잉크 차트" 텍스트 + 보유 차트 권수 + chevron_right), 탭 시 `/ink-chart`로 이동
- "프로필 편집" 버튼은 이 화면에서 제거됨 → 설정 화면 계정 섹션으로 이동
- **탭 3개**
  - 내 리뷰 — 작성한 리뷰 그리드
  - 스크랩 — 북마크한 리뷰 + 커뮤니티 게시글 혼합, 최신순 정렬
  - 게시글 — 작성한 커뮤니티 글

#### 스크랩 탭 (`_ScrapbookGrid`)
- `scrappedReviewsProvider(uid)` + `scrappedPostsProvider(uid)` 동시 구독 (실시간 Stream)
- 둘을 합쳐 `createdAt` 내림차순으로 정렬
- 타입 판별: Dart 3 sealed class (`_ScrapItem`, `_ReviewScrap`, `_PostScrap`)로 type-safe 분기
- 리뷰 → `ReviewListCard`, 게시글 → `PostCard` 위젯으로 렌더링
- 당겨서 새로고침: `ref.invalidate()` 사용 (StreamProvider 호환)

### `user_profile_screen.dart`
- 경로: `/profile/:uid`
- 다른 유저의 프로필 페이지 (본인 mypage와 동일 레이아웃)
- 팔로우 / 언팔로우 버튼
- 차단 메뉴 (신고 포함)
- **색상 테마** — 베이지 계열에서 네이비 계열로 전환
  - `_kNavyTint (0xFFEEF2F8)`: 소개 박스 배경
  - `_kNavyLight (0xFFE2EAF4)`: 프로필 아바타 테두리·배경, 팔로잉 버튼 배경, 탭 배경
  - `_kNavyMid (0xFF8BA5C8)`: 아바타 기본 아이콘 색
  - 레벨 칭호: `AppColors.primary`, 팔로워 구분선: `AppColors.divider`

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
- **배경색** — 흰색 (`Colors.white`)

### `ink_book_detail_screen.dart`
- 경로: `/ink-chart/:bookId`
- **스와치 페이지** — 3×3 격자로 잉크 스와치 나열
- **뷰 모드** — 좌우 스와이프 / 위아래 스와이프 전환
- **페이지 스타일** — 실선 / 격자 / 민무늬 배경
- **정렬** — 기본순 / 브랜드순 / 색상순 (palette_generator 기반 주요 색상 추출)
- **드래그 정렬** — 길게 누른 후 순서 변경
- **내보내기** — 화면 캡처 후 갤러리 저장 (gal 패키지)
- 잉크 추가 FAB → `/ink-chart/:bookId/add`
- **배경색** — 흰색 (`Colors.white`)
- **잉크 추가 후 자동 이동** — `ref.listen`으로 잉크 목록 개수 증가를 감지해 추가된 잉크가 속한 페이지로 `PageController.animateToPage` (450ms, easeOutCubic)

### `ink_chart_add_screen.dart`
- 경로: `/ink-chart/:bookId/add`
- 잉크 검색 → 선택 → 스와치 사진 촬영/선택 → 차트에 추가
- **사진 필수** — 사진 없이 저장 시 SnackBar 안내 표시
- **사진 피커** — `TapScale(scale: 0.97)` 탭 피드백 적용
- **추가 완료 오버레이** — 저장 성공 시 `showInkAddSuccess` 호출
  - 흰 배경 위에 잉크 스와치 사진이 elastic 바운스 + 살짝 기울어지며 등장
  - 브랜드명 / 잉크명 텍스트 및 3개의 ripple 파동 애니메이션
  - 약 2.2초 후 자동 닫힘

### `ink_crop_screen.dart`
- 스와치 이미지 크롭 화면 (원형·사각형 등 모양 선택)

---

## 설정

### `settings_screen.dart`
- 경로: `/mypage/settings`
- 알림 설정 — 좋아요·댓글·팔로우 토글 (Firestore에 저장)
- **계정 섹션** — 프로필 편집 / 차단 목록 / 문의하기 / 이용약관 / 개인정보처리방침
  - "프로필 편집"이 계정 섹션 첫 항목으로 추가됨 → `/mypage/edit`
- 로그아웃 / 회원탈퇴 (확인 다이얼로그)
- 디버그 모드: 아카이브 DB 초기화 버튼, 검색 인덱스 생성 버튼

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

## 상태 관리

- `scrappedReviewsProvider` — StreamProvider.family, 실시간 스크랩 리뷰 목록
- `scrappedPostsProvider` — StreamProvider.family, 실시간 스크랩 게시글 목록

---

## 공유 위젯

- `lib/shared/widgets/tap_scale.dart` — `TapScale`: GestureDetector 기반 탭 시 0.95 축소 피드백 위젯 (80ms easeIn down, 220ms elasticOut up)
- `lib/features/mypage/widgets/ink_add_success_overlay.dart` — `showInkAddSuccess(context, photo, shape, brand, inkName)`: 잉크 추가 성공 시 전체 화면 오버레이

---

## 관련 파일

- `lib/features/mypage/providers/` — 알림 설정, 유저 활동 providers
- `lib/data/repositories/user_repository.dart`
- `lib/shared/providers/ink_book_providers.dart`
- `lib/data/repositories/ink_book_repository.dart`
- `lib/shared/providers/user_providers.dart`
