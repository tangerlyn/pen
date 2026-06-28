# 마이페이지 (Mypage)

## 개요

내 프로필·활동 내역 조회, 잉크 차트 관리, 다른 유저 프로필 탐색, 앱 설정.

---

## 화면 목록

### `mypage_screen.dart`
**경로:** `/mypage` (하단 탭 5번째 — 마이페이지)

**화면 구성 — 상단 프로필 영역**
- 프로필 사진 (CircleAvatar radius 40)
- 닉네임 + 레벨 뱃지 (Lv.N, 네이비)
- 레벨 칭호 (ex. "Lv.3 · 어엿한 필객", 네이비)
- 한 줄 소개
- **팔로워 수** — 탭 → `/profile/:uid/followers?tab=0`
- **팔로잉 수** — 탭 → `/profile/:uid/followers?tab=1`
- **EXP 진행 바 카드**
  - 현재 칭호 + EXP 현황(ex. "140 / 200") 표시
  - 진행률 LinearProgressIndicator (네이비)
- **내 잉크 차트 버튼** — 보유 차트 권수 표시. 탭 → `/ink-chart`
- **위시리스트 버튼** — 위시리스트 개수 표시. 탭 → `/mypage/wishlist`

**화면 구성 — 탭 3개**
- **리뷰 탭** — 내가 작성한 리뷰 목록 (`ReviewListCard`)
  - 탭 → `/review/:reviewId`
- **커뮤니티 탭** — 내가 작성한 게시글 목록 (`PostCard`)
  - 탭 → `/community/:postId`
- **스크랩북 탭** — 스크랩한 리뷰 + 게시글 혼합 (최신순)
  - 리뷰 항목 탭 → `/review/:reviewId`
  - 게시글 항목 탭 → `/community/:postId`
  - 당겨서 새로고침 지원

**AppBar**
- 제목 "마이페이지"
- 우측 설정 아이콘 → `/mypage/settings`

---

### `user_profile_screen.dart`
**경로:** `/profile/:uid`

다른 유저의 프로필 페이지 (본인 마이페이지와 동일 레이아웃).

**화면 구성**
- 프로필 사진 + 닉네임 + 레벨 뱃지 + 레벨 칭호
- 한 줄 소개
- 팔로워/팔로잉 수 — 탭 → `/profile/:uid/followers`
- **팔로우 버튼** / **팔로잉 버튼** (토글)
- **⋮ 메뉴** — 차단 / 신고
- **잉크 차트 공개 설정이 켜진 경우**: 잉크 차트 보기 버튼 → `/public-ink-books?uid=xxx`
- **탭 3개**: 리뷰 / 커뮤니티 / 스크랩북

---

### `profile_edit_screen.dart`
**경로:** `/mypage/edit`

**화면 구성**
- 프로필 사진 변경 (갤러리 선택)
- 닉네임 수정 (중복 검사)
- 한 줄 소개 수정
- 저장 버튼

---

### `follow_list_screen.dart`
**경로:** `/profile/:uid/followers?tab=0|1`

- `tab=0`: 팔로워 목록
- `tab=1`: 팔로잉 목록
- 각 항목: 프사 + 닉네임 + 레벨 뱃지 + 팔로우/팔로잉 버튼
- 항목 탭 → `/profile/:uid`

---

## 잉크 차트

### `ink_book_list_screen.dart`
**경로:** `/ink-chart`

**화면 구성**
- 잉크 차트 목록 그리드 (흰 배경)
- 각 차트 카드: 이름 + 잉크 수 + 썸네일
- 카드 탭 → `/ink-chart/:bookId`
- **새 차트 만들기 셀** — 탭 시 이름 입력 다이얼로그 → 새 차트 생성

---

### `ink_book_detail_screen.dart`
**경로:** `/ink-chart/:bookId`

**화면 구성**
- **스와치 페이지** — 3×3 격자로 잉크 스와치 나열 (흰 배경)
- **페이지 스타일 전환** — 실선 / 격자 / 민무늬 배경
- **정렬 옵션** — 기본순 / 브랜드순 / 색상순 (palette_generator 기반 주요 색상 추출)
- **드래그 정렬** — 스와치를 길게 누른 후 순서 변경
- **뷰 방향** — 좌우 스와이프 / 위아래 스와이프 전환
- **내보내기** — 화면 캡처 후 갤러리 저장 (gal 패키지)
- **잉크 추가 FAB** → `/ink-chart/:bookId/add`
- 잉크 추가 후 자동 이동: 추가된 잉크가 속한 페이지로 `PageController.animateToPage` (450ms, easeOutCubic)

---

### `ink_chart_add_screen.dart`
**경로:** `/ink-chart/:bookId/add`

**화면 구성**
- 잉크 검색 → 목록에서 선택
- 스와치 사진 촬영 또는 갤러리 선택 (`TapScale` 탭 피드백 적용)
- 사진 없으면 저장 불가 (SnackBar 안내)
- **저장 성공 시** — `showInkAddSuccess` 오버레이 표시
  - 흰 배경 위에 스와치 사진이 elastic 바운스 + 기울기로 등장
  - 브랜드명 / 잉크명 텍스트 + ripple 파동 3개 애니메이션
  - 약 2.2초 후 자동 닫힘 → 차트 상세로 돌아감

---

### `public_ink_books_screen.dart`
**경로:** `/public-ink-books`

다른 유저가 공개 설정한 잉크 차트를 탐색하는 화면.

---

## 설정

### `settings_screen.dart`
**경로:** `/mypage/settings`

**화면 구성**
- **알림 설정** — 좋아요 알림 / 댓글 알림 / 팔로우 알림 각각 토글 (Firestore 저장)
- **계정 섹션**
  - 프로필 편집 → `/mypage/edit`
  - 차단 목록 → `/mypage/settings/blocked`
  - 문의하기 → `/mypage/settings/inquiries`
  - 이용약관 → `/mypage/settings/terms`
  - 개인정보처리방침 → `/mypage/settings/privacy`
- **로그아웃** — 확인 다이얼로그 후 `/login`으로 이동
- **회원탈퇴** — 확인 다이얼로그 후 계정 삭제 + `/login`으로 이동
- **디버그 모드** (개발용): 아카이브 DB 초기화, 검색 인덱스 생성 버튼

### `blocked_users_screen.dart`
**경로:** `/mypage/settings/blocked`

- 차단한 유저 목록
- 각 항목 "차단 해제" 버튼

### `inquiry_screen.dart`
**경로:** `/mypage/settings/inquiries`

- 내 문의 목록 (InquiryListScreen)
- 우측 상단 작성 버튼 → `/mypage/settings/inquiries/write`
- 항목 탭 → `/mypage/settings/inquiries/:inquiryId` (답변 포함 상세)

---

## 레벨 시스템 (`level_system.dart`)

EXP 기반 Lv.1~10 시스템.

| 레벨 | 칭호 | 필요 EXP |
|---|---|---|
| Lv.1 | 백지장 | 0 |
| Lv.2 | 풋내기 | 100 |
| Lv.3 | 어엿한 필객 | 300 |
| Lv.4 | 필방 식구 | 700 |
| Lv.5 | 베테랑 | 1,400 |
| Lv.6 | 고수 | 2,300 |
| Lv.7 | 원로 | 3,500 |
| Lv.8 | 대가 | 5,000 |
| Lv.9 | 전설 | 7,000 |
| Lv.10 | 살아있는 신화 | 10,000 |

**EXP 획득 방법**

| 활동 | EXP |
|---|---|
| 리뷰 작성 | +10 |
| 게시글 작성 | +5 |
| 댓글/답글 작성 | +2 |
| 좋아요 받기 | +1 |

**레벨 뱃지 (`LevelBadge` 위젯)**
- "Lv.N" 형태의 네이비 배경 라운드 뱃지
- 닉네임 우측에 표시
- **표시 레벨은 항상 현재 레벨** (작성 시점 스냅샷 아님)
- 표시 위치: 마이페이지, 유저 프로필, 리뷰 상세 작성자, 리뷰 피드 리스트, 게시글 상세 작성자, 게시글 카드, 댓글, 답글

---

## 상태 관리

| Provider | 종류 | 역할 |
|---|---|---|
| `currentUserProvider` | StreamProvider\<UserModel?\> | 현재 로그인 유저 실시간 |
| `inkBookListProvider` | StreamProvider.family | 잉크 차트 목록 |
| `wishlistProvider` | StreamProvider.family | 위시리스트 목록 |
| `scrappedReviewsProvider` | StreamProvider.family | 스크랩 리뷰 목록 |
| `scrappedPostsProvider` | StreamProvider.family | 스크랩 게시글 목록 |
| `levelUpProvider` | StateProvider\<LevelUpInfo?\> | 레벨업 다이얼로그 트리거 |

---

## 공유 위젯

- `lib/shared/widgets/level_badge.dart` — `LevelBadge(level)`: Lv.N 뱃지
- `lib/shared/widgets/level_up_dialog.dart` — 레벨업 시 오버레이 다이얼로그
- `lib/shared/widgets/tap_scale.dart` — 탭 시 0.95 축소 피드백 (80ms in / 220ms elastic out)

---

## 관련 파일

- `lib/features/mypage/screens/mypage_screen.dart`
- `lib/features/mypage/screens/user_profile_screen.dart`
- `lib/features/mypage/screens/profile_edit_screen.dart`
- `lib/features/mypage/screens/settings_screen.dart`
- `lib/features/mypage/screens/follow_list_screen.dart`
- `lib/features/mypage/screens/wishlist_screen.dart`
- `lib/features/mypage/screens/ink_book_list_screen.dart`
- `lib/features/mypage/screens/ink_book_detail_screen.dart`
- `lib/features/mypage/screens/ink_chart_add_screen.dart`
- `lib/features/mypage/screens/public_ink_books_screen.dart`
- `lib/features/mypage/screens/blocked_users_screen.dart`
- `lib/features/mypage/screens/inquiry_screen.dart`
- `lib/core/utils/level_system.dart`
- `lib/data/repositories/user_repository.dart`
- `lib/shared/providers/user_providers.dart`
- `lib/shared/providers/ink_book_providers.dart`
- `lib/shared/providers/wishlist_providers.dart`
