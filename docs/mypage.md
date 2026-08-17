# 마이페이지 (Mypage)

## 개요

내 프로필·활동 내역 조회, 잉크 차트 관리, 다른 유저 프로필 탐색, 앱 설정.

---

## 화면 목록

### `mypage_screen.dart`
**경로:** `/mypage` (하단 탭 5번째 — 마이페이지)

**화면 구성 — 상단 프로필 영역**
- 프로필 사진 (CircleAvatar radius 40)
- 닉네임 (레벨 뱃지는 바로 아래 레벨 칭호와 중복되어 제거됨)
- 레벨 칭호 (ex. "Lv.3 · 어엿한 필객", 네이비)
- 한 줄 소개
- **팔로워 수** — 탭 → `/profile/:uid/followers?tab=0`
- **팔로잉 수** — 탭 → `/profile/:uid/followers?tab=1`
- **EXP 진행 바 카드**
  - 현재 칭호 + EXP 현황(ex. "140 / 200") 표시
  - 진행률 LinearProgressIndicator (네이비)
- **내 잉크 차트 버튼** — 보유 차트 권수 표시. 탭 → `/ink-chart`
- **위시리스트 버튼** — 위시리스트 개수 표시. 탭 → `/mypage/wishlist`

**화면 구성 — 탭 3개** (리뷰/커뮤니티/스크랩북 모두 `PostCard`/`ReviewListTile`의 제목 줄에 작성 날짜 표시)
- **리뷰 탭** — 내가 작성한 리뷰 목록 (`ReviewListTile`)
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

다른 유저의 프로필 페이지.

**화면 구성**
- AppBar: 뒤로가기만 표시, 별도 타이틀 없음 (닉네임은 아래 카드에 이미 표시되므로 중복 제거)
- 프로필 사진 + 닉네임 + 레벨 칭호 (레벨 뱃지는 칭호와 중복되어 표시하지 않음)
- 한 줄 소개
- 팔로워/팔로잉 수 — 탭 → `/profile/:uid/followers`
- **팔로우 버튼** / **팔로잉 버튼** (토글, 닉네임 옆에 위치)
- **공개 또는 팔로워 공개 잉크북이 있는 경우** (뷰어가 팔로우 중이면 팔로워 공개 잉크북도 포함): "잉크차트" 탭이 추가로 노출됨
  - 탭 안에서 `NotebookCard`(공책 모양 카드) 그리드로 표시 — 내 잉크 차트 목록과 동일한 UI
  - 카드 탭 → `/public-ink-books/:uid/:bookId` (읽기 전용 상세)
- **탭 2~3개**: 리뷰 / 커뮤니티 / (조건부) 잉크차트 — 스크랩북 탭은 본인 마이페이지에만 있음 (리뷰/커뮤니티 탭 모두 본인 마이페이지와 동일하게 날짜 표시)

---

### `profile_edit_screen.dart`
**경로:** `/mypage/edit`

**화면 구성**
- 프로필 사진 변경 — 갤러리에서 선택 후 `InkCropScreen`(원형 오버레이, 핀치줌/드래그)으로 위치·확대 조정해 크롭
- 닉네임 수정 (중복 검사)
- 한 줄 소개 수정
- 저장 버튼
- **뒤로가기 시 저장 확인** — 사진/닉네임/한줄소개 중 하나라도 원래 값과 달라진 상태에서 뒤로가기(제스처·시스템 백)를 누르면 "지금 나가면 변경사항이 저장되지 않습니다" 확인 다이얼로그 표시(`PopScope`, 리뷰/게시글 작성과 동일한 패턴)

---

### `follow_list_screen.dart`
**경로:** `/profile/:uid/followers?tab=0|1`

- `tab=0`: 팔로워 목록
- `tab=1`: 팔로잉 목록
- 각 항목: 프사 + 닉네임 + 팔로우/팔로잉 버튼
- 항목 탭 → `/profile/:uid`

---

## 잉크 차트

### `ink_book_list_screen.dart`
**경로:** `/ink-chart`

**화면 구성**
- 공책(잉크북) 목록 그리드 (2열)
- 각 카드: `NotebookCard`(`lib/features/mypage/widgets/notebook_card.dart`) — 스프링 바인딩 척추 + 표지 색상 + 공책 이름 + 잉크 수, 카드 탭 → `/ink-chart/:bookId`
  - 길게 누르면 옵션 시트(이름 변경/삭제)
- **새 공책 만들기 셀** — 탭 시 이름·표지색 입력 바텀 시트 → 새 공책 생성 (기본 공개범위: `public`)

---

### `ink_book_detail_screen.dart`
**경로:** `/ink-chart/:bookId`

**화면 구성**
- **스와치 페이지** — 3×3 격자로 잉크 스와치 나열 (공책 노트 페이지 배경, `NotebookPage` 위젯)
- **페이지 스타일 전환** — 실선 / 격자 / 민무늬 배경
- **스와치 모양 전환** — 원형 / 잉크병 / 붓터치 (`InkSwatchShape`, 계정 전체에 적용되는 설정)
- **정렬 옵션** — 기본순 / 브랜드순 / 색상순 (palette_generator 기반 주요 색상 추출)
- **드래그 정렬** — 스와치를 길게 누른 후 순서 변경
- **뷰 방향** — 좌우 스와이프 / 위아래 스와이프 전환
- **내보내기** — 화면 캡처 후 갤러리 저장 (gal 패키지)
- **잉크 추가 FAB** → `/ink-chart/:bookId/add`
- 잉크 추가 후 자동 이동: 추가된 잉크가 속한 페이지로 `PageController.animateToPage` (450ms, easeOutCubic)
- **잉크 상세 캐러셀** — 스와치 탭 시 좌우로 넘겨볼 수 있는 상세 시트 (`InkDetailCarousel` 공용 위젯, 화면 높이의 75%로 표시, 흰색 배경). 사진·브랜드·이름·날짜·메모
  - 상단 좌측: 페이지 카운터("N / 전체") — 예전엔 우측에 있었음
  - 상단 우측: ⋮ 메뉴(`menuBuilder`, 소유자 화면에서만 전달) — **잉크 수정**(`InkChartAddScreen`을 `entryToEdit`와 함께 다시 열어 브랜드/이름/사진/메모 수정, 저장은 `InkBookRepository.updateEntry`) / **잉크 삭제**(예전엔 하단에 별도 버튼으로 있었음, 메뉴로 통합)
  - 메모는 텍스트만이 아니라 작성 시 추가한 사진도 순서대로 함께 표시됨(`InkMemoContent` 공용 위젯, `lib/features/mypage/widgets/ink_memo_content.dart`) — 사진 탭 시 전체화면으로 확대
- **공개 범위 설정 버튼** (AppBar) — 바텀 시트로 3단계 선택
  - 모든 사람에게 공개 (`public`, 새 차트 생성 시 기본값) — `Icons.public`
  - 팔로워에게만 공개 (`followers`) — `Icons.group_outlined`
  - 비공개 (`private`) — `Icons.lock_outlined`
  - 변경 즉시 Firestore에 `visibility` 필드 저장 (레거시 `isPublic` bool도 함께 하위 호환 저장)
- **페이지 스타일 / 보기 방식 / 스와치 모양 설정은 Firestore에도 저장됨** — 다른 유저가 읽기 전용 화면(`ink_book_readonly_screen.dart`)에서 볼 때도 소유자가 설정한 모양 그대로 보이도록 하기 위함
  - 페이지 스타일·보기 방식: `InkBookModel.pageStyle` / `viewMode` 필드
  - 스와치 모양: `UserModel.inkSwatchShape` 필드 (책 단위가 아니라 계정 전체 설정)
  - 이 동기화 기능이 생기기 전에 로컬(SharedPreferences)로만 저장돼 있던 값은 소급 반영되지 않음 — 설정을 한 번 더 선택해야 서버에 반영됨

---

### `ink_book_readonly_screen.dart`
**경로:** `/public-ink-books/:uid/:bookId`

다른 유저의 공개/팔로워공개 잉크북을 읽기 전용으로 보여주는 화면. 편집·삭제·정렬 등 소유자 전용 기능은 없음.

**화면 구성**
- 소유자가 설정한 `pageStyle`(실선/격자/민무늬) · `viewMode`(좌우/위아래) · `inkSwatchShape`(원형/잉크병/붓터치)를 그대로 읽어와 `NotebookPage`로 렌더링 — 소유자 화면과 동일한 공용 위젯을 사용하므로 모양이 100% 동일
- 스와치 탭 → `InkDetailCarousel` (소유자 화면과 동일한 상세 캐러셀, `menuBuilder`를 안 넘기므로 ⋮ 메뉴 자체가 안 보임 — 수정·삭제 불가)

---

### `ink_chart_add_screen.dart`
**경로:** `/ink-chart/:bookId/add` (추가) — 수정은 이 경로가 아니라 잉크 상세의 ⋮ 메뉴에서 같은 화면을 `entryToEdit`와 함께 직접 push(`Navigator.push`, `reviewToEdit`/`postToEdit`와 동일한 패턴)

**화면 구성**
- 흰색 배경 + 포인트 색상은 네이비(`AppColors.primary`) — 예전엔 베이지 톤이었음
- 브랜드 / 잉크 이름 입력 필드 — 각각 한 글자만 입력해도 기존 아카이브 데이터 기준 자동완성 목록이 바로 아래에 뜸 (브랜드 필드엔 브랜드 이름만, 잉크 이름 필드엔 잉크 이름만 — 서로 안 섞임). 항목 탭 시 해당 값으로 채워짐
- 스와치 사진 촬영 또는 갤러리 선택 (`TapScale` 탭 피드백 적용) — 선택 후 모양(원형/잉크병/붓터치)에 맞는 오버레이로 핀치줌/드래그 크롭. 수정 모드에서는 기존 사진(네트워크 URL)이 미리 채워지고, 새로 고르기 전까지는 그 사진을 그대로 유지
- 사진 없으면 저장 불가 (화면 중앙 팝업 안내)
- **메모 (선택)** — 리뷰/게시글 작성과 동일한 블로그 에디터(`BlogBodyEditor`) 사용. 텍스트 작성 중 키보드 위에 카메라/사진 툴바(`BlogEditorToolbar`)가 나타나 메모 중간에 사진을 추가로 첨부 가능. 저장 시 텍스트는 `memo`, 전체 블록(텍스트+사진)은 `contentBlocks`로 함께 저장됨(`InkChartModel`)
- **뒤로가기 시 저장 확인** — 사진/브랜드/이름/메모 중 하나라도 입력된 상태에서 뒤로가기(제스처·닫기 버튼·시스템 백)를 누르면 "지금 나가면 [작성한/수정한] 내용이 삭제됩니다" 확인 다이얼로그 표시(`PopScope`, 리뷰/게시글 작성과 동일한 패턴)
- **저장 성공 시**
  - 추가: `showInkAddSuccess` 오버레이 표시 — 흰 배경 위에 스와치 사진이 elastic 바운스 + 기울기로 등장, 브랜드명/잉크명 텍스트 + ripple 파동 3개 애니메이션
  - 수정: 오버레이 없이 "수정했어요" 토스트만 표시하고 바로 닫힘
  - 약 2.2초 후 자동 닫힘 → 차트 상세로 돌아감

---

### `public_ink_books_screen.dart`
**경로:** `/public-ink-books`

전체 유저가 공개(`public`) 설정한 잉크북을 모아 탐색하는 화면 (그리드, 소유자 닉네임 표시).
카드 탭 → `/public-ink-books/:uid/:bookId` (`ink_book_readonly_screen.dart`, 읽기 전용 상세)

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
- **회원탈퇴** — 확인 다이얼로그(재인증 진행 중 로딩 표시, 실패 시 다이얼로그 안에 에러 문구) → 소셜 재인증(카카오/네이버/애플 재로그인) → Firebase 계정 삭제 성공 시 `/login`으로 명시적 이동
  - 작성한 리뷰/글/댓글/대댓글은 삭제되지 않고 서버(`onUserDeleted`)가 작성자 닉네임만 "알 수 없음"으로 바꿔 남겨둠 — 자세한 내용은 [auth.md](auth.md#회원탈퇴) 참고

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
- 표시 위치: 리뷰 상세 작성자, 게시글 상세 작성자, 리뷰 리스트 항목(`ReviewListTile`), 게시글 카드, 댓글, 답글
- **마이페이지·유저 프로필 헤더에는 표시하지 않음** — 바로 아래(마이페이지: 레벨 칭호, 유저 프로필: 레벨 칭호)에 레벨 정보가 중복 표시되어 제거됨. 팔로워/팔로잉 목록(`follow_list_screen.dart`)에도 없음

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
| `userVisibleBooksProvider` | FutureProvider.family\<(ownerUid, viewerUid)\> | 뷰어의 팔로우 여부를 반영한 가시적 잉크 차트 목록 (공개 + 팔로우 중이면 팔로워 공개 포함) |
| `singleInkBookProvider` | FutureProvider.family\<(uid, bookId)\> | 단일 잉크북 조회 — 읽기 전용 화면에서 소유자의 pageStyle/viewMode 로드용 |

---

## 공유 위젯

- `lib/shared/widgets/level_badge.dart` — `LevelBadge(level)`: Lv.N 뱃지
- `lib/shared/widgets/level_up_dialog.dart` — 레벨업 시 오버레이 다이얼로그
- `lib/shared/widgets/tap_scale.dart` — 탭 시 0.95 축소 피드백 (80ms in / 220ms elastic out)
- `lib/features/mypage/widgets/notebook_card.dart` — `NotebookCard`: 공책 모양 카드(스프링 바인딩 + 표지), 내 잉크 차트 목록과 다른 유저 잉크 차트 목록에서 공용
- `lib/features/mypage/widgets/notebook_page.dart` — `NotebookPage`: 노트 페이지 배경(실선/격자/민무늬) + 3×3 스와치 그리드, 소유자 화면과 읽기 전용 화면 공용
- `lib/features/mypage/widgets/ink_detail_carousel.dart` — `InkDetailCarousel`: 잉크 상세 좌우 스와이프 캐러셀 셸(카운터 좌측 상단/화살표), 소유자 화면과 읽기 전용 화면 공용. `menuBuilder`(우측 상단 ⋮ 메뉴)를 넘기면 표시, 안 넘기면(읽기 전용) 숨김
- `lib/features/mypage/widgets/ink_memo_content.dart` — `InkMemoContent`: 메모 카드 내용(텍스트+사진) 렌더링, 소유자 화면과 읽기 전용 화면 공용

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
- `lib/features/mypage/screens/ink_book_readonly_screen.dart`
- `lib/features/mypage/screens/ink_chart_add_screen.dart`
- `lib/features/mypage/screens/public_ink_books_screen.dart`
- `lib/features/mypage/screens/blocked_users_screen.dart`
- `lib/features/mypage/screens/inquiry_screen.dart`
- `lib/features/mypage/widgets/notebook_card.dart`
- `lib/features/mypage/widgets/notebook_page.dart`
- `lib/features/mypage/widgets/ink_detail_carousel.dart`
- `lib/features/mypage/widgets/ink_memo_content.dart`
- `lib/features/mypage/widgets/ink_swatch_shape.dart`
- `lib/features/mypage/providers/ink_shape_provider.dart`
- `lib/core/utils/level_system.dart`
- `lib/data/repositories/user_repository.dart`
- `lib/data/repositories/ink_book_repository.dart`
- `lib/data/models/ink_book_model.dart`
- `lib/shared/providers/user_providers.dart`
- `lib/shared/providers/ink_book_providers.dart`
- `lib/shared/providers/wishlist_providers.dart`
