# 홈 (Home)

## 개요

앱 진입 후 가장 먼저 보이는 디스커버리 피드. 인기 리뷰 캐러셀과 최근 커뮤니티 글을 한 화면에 보여주고, FAB으로 리뷰/게시글 작성에 빠르게 접근한다.

---

## 화면 목록

### `home_screen.dart`
**경로:** `/` (하단 탭 1번째 — 홈)

**화면 구성**
- 상단 AppBar
  - 앱 로고/타이틀
  - 우측 검색 아이콘 → `/search?type=all`
  - 우측 종 아이콘 → `/notifications` 이동. 미읽 알림이 있으면 빨간 뱃지 표시
- 4개 섹션이 순서대로 표시 (각 섹션은 데이터가 없으면 통째로 숨겨짐)
  1. **최신 리뷰** — 수평 스크롤 카드. 리뷰 탭 2열 그리드와 동일한 `ReviewFeedCard` 재사용(사진장수 뱃지, 잉크·펜 태그 그라데이션 오버레이, 프사·닉네임·레벨 뱃지·제목 — 별점 뱃지는 비활성화됨). 카드 폭은 화면폭 비례(42%, 140~190px 사이로 clamp)라 화면 크기에 따라 자동 조정됨. 더보기 → `/review`, 카드 탭 → `/review/:reviewId`
  2. **인기 잉크** — 수평 스크롤 원형 스와치(`InkDropCircle`) + 이름. 더보기 → `/archive`, 아이템 탭 → `/archive/ink/:id`
  3. **커뮤니티 최신글** — 세로 리스트(`PostCard`, 최대 4개 미리보기). 더보기 → `/community`, 항목 탭 → `/community/:postId`
  4. **인기 만년필** — 수평 스크롤 카드. 카드 폭도 화면폭 비례(38%, 130~175px)로 조정됨. 더보기 → `/archive`, 카드 탭 → `/archive/pen/:id`
- **FAB (+)** — 탭 시 바텀 시트 열림
  - "리뷰 작성" 탭 → `/write/review`
  - "게시글 작성" 탭 → `/community/write`
- 스크롤 300px 이상 내리면 맨 위로 버튼 등장, 탭 시 최상단으로 스크롤

---

### `review_detail_screen.dart`
**경로:** `/review/:reviewId`

**화면 구성**
- **커스텀 AppBar**
  - 좌측: 뒤로가기
  - 우측: ~~공유 아이콘~~(당장 불필요해 주석 처리, 재활성화 가능) / 북마크(스크랩) 아이콘 / ⋮(더보기) 메뉴
    - 북마크: 스크랩 상태 반영(채워진 아이콘 = 스크랩됨). 탭 시 스크랩 토글
    - 스크랩 완료 시 화면 중앙에 "스크랩되었습니다" 토스트 표시
    - ⋮ 본인 글: 수정 / 삭제
    - ⋮ 타인 글: 차단 / 신고
- **리뷰 제목** (굵게) — 커뮤니티 게시글 상세와 동일하게 맨 위에 표시
- **작성자 행 (`_ProfileRow`)** — 제목 바로 아래, 커뮤니티 상세의 `_EditorialByline`과 동일한 배치
  - CircleAvatar(radius 16) + 닉네임 + 레벨 뱃지(작성자 현재 레벨 실시간 반영), 그 아래 줄에 작성 시간(`formatPostDate`, 3일 이내 상대 시간·4일 이상 "YYYY.MM.DD") / "수정됨" 표시
  - 팔로우/팔로잉 버튼 (본인이 아닐 때) — 커뮤니티 게시글 상세에는 없는, 리뷰 상세만의 기능
  - 탭 → `/profile/:uid`
- **본문 영역**
  - 제품 태그 칩 — 잉크: 파랑 계열, 만년필: 보라 계열. 탭 → `/archive/:type/:productId`
  - (별점 시스템 비활성화 — 코드는 주석 처리로 보존)
  - 블로그 형식 본문 (텍스트+이미지 블록 혼합) 또는 기존 body+imageUrls
  - 이미지 탭 → 전체화면 ImageViewer (스와이프 가능)
- **액션 바**
  - 좋아요(하트) + 좋아요 수 — 탭 시 좋아요 토글 (+EXP 1 원작성자 획득)
  - 댓글 아이콘 + 댓글 수
- **댓글 목록 (`CommentTile`)**
  - 댓글: CircleAvatar(실제 프로필 사진, 작성자 정보는 실시간 반영) + 닉네임 + 레벨 뱃지(현재 레벨) + (리뷰 작성자 본인이면 "작성자" 뱃지) + 작성 시간 + 본문
  - 댓글 ⋮ 메뉴: 본인 → 수정/삭제 / 타인 → 차단/신고
  - "답글" 텍스트 탭 → 하단 입력창이 "@닉네임에게 답글" 모드로 전환
  - 답글(들여쓰기): 닉네임 + 레벨 뱃지 + 작성 시간 + 본문 + ⋮ 메뉴
  - 닉네임 탭 → `/profile/:uid`
- **하단 댓글 입력창**
  - 답글 모드: 상단에 "@닉네임 에게 답글" 배너 + X 버튼(취소)
  - 전송 아이콘 탭 → 댓글/답글 등록 (+EXP 2 획득)

---

### `notification_screen.dart`
**경로:** `/notifications`

**화면 구성**
- 좋아요·댓글·팔로우 알림 목록 (최신순)
- 각 알림 탭 → 해당 콘텐츠 화면 이동 (`/review/:id`, `/community/:id`, `/profile/:uid`)
- 진입 시 전체 알림 읽음 처리

---

## 미사용 코드 (`feed_screen.dart`)

`lib/features/feed/screens/feed_screen.dart`에 전체·리뷰·커뮤니티 탭을 합친 `FeedScreen` 위젯이 있지만, `app_router.dart` 어디에도 라우팅되어 있지 않은 **죽은 코드**임 (실제 홈 탭 구성은 위 `home_screen.dart`의 4개 섹션). 이전 설계 단계의 잔재로 보임 — 삭제하거나 실제로 쓸지 결정 필요.

---

## UI 애니메이션

### 하단 탭바 (`main_shell.dart`)
| 요소 | 효과 |
|---|---|
| 탭 아이콘 | 활성 시 `AnimatedScale` 1.15배 (260ms, easeOutBack) |
| 아이콘 교체 | `AnimatedSwitcher` 180ms cross-fade |
| 활성 인디케이터 | 하단 4px 점이 `AnimatedContainer` (primary 네이비) |

### 화면 전환 (`app_router.dart`)
| 전환 타입 | 적용 화면 | 효과 |
|---|---|---|
| `_slidePage` | 일반 화면 | 6% 수평 슬라이드 + 페이드 (320/260ms, easeOutCubic) |
| `_slideUpPage` | 작성·추가 화면 | 7% 수직 슬라이드 + 페이드 (350/280ms) |
| `_fadePage` | 인증 화면 | 페이드 전용 (280/200ms) |

---

## 레벨업 다이얼로그 (`level_up_dialog.dart`)

리뷰·게시글·댓글 작성으로 EXP를 얻어 레벨업 시 전체 화면 위 오버레이 다이얼로그 자동 표시.
- `main_shell.dart`에서 `levelUpProvider` 상태 변화 감지
- 새 레벨 번호와 칭호(ex. "Lv.3 · 어엿한 필객") 표시

---

## 상태 관리

| Provider | 종류 | 역할 |
|---|---|---|
| `homeLatestReviewsProvider` | FutureProvider | 최신 리뷰 목록 |
| `homePopularInksProvider` | FutureProvider | 인기 잉크 목록 |
| `homePopularPensProvider` | FutureProvider | 인기 만년필 목록 |
| `filteredPostsProvider` | StreamProvider | 커뮤니티 최신글 (카테고리 필터 적용) |
| `notificationProvider` | StreamProvider | 알림 목록 |
| `reviewDetailProvider` | StateNotifierProvider.family | 리뷰 상세 + 좋아요/스크랩 |
| `levelUpProvider` | StateProvider\<LevelUpInfo?\> | 레벨업 다이얼로그 트리거 |

---

## 관련 파일

- `lib/features/home/screens/home_screen.dart`
- `lib/features/home/screens/review_detail_screen.dart`
- `lib/features/home/screens/notification_screen.dart`
- `lib/features/home/providers/home_discovery_provider.dart`
- `lib/features/home/providers/review_detail_provider.dart`
- `lib/features/home/providers/notification_provider.dart`
- `lib/features/community/providers/community_provider.dart`
- `lib/features/feed/screens/feed_screen.dart` (미사용, 위 참고)
- `lib/core/shell/main_shell.dart`
- `lib/core/router/app_router.dart`
- `lib/core/utils/toast_utils.dart`
- `lib/core/utils/post_date_format.dart`
- `lib/shared/widgets/level_up_dialog.dart`
- `lib/shared/widgets/level_badge.dart`
- `lib/shared/widgets/author_badge.dart`
- `lib/shared/widgets/tap_scale.dart`
