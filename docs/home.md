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
  - 우측 종 아이콘 → `/notifications` 이동. 미읽 알림이 있으면 빨간 뱃지 표시
- **인기 리뷰 섹션** — 수평 스크롤 카드 리스트
  - 각 카드: 썸네일 이미지 + 제목 + 별점
  - 카드 탭 → `/review/:reviewId`
- **최근 커뮤니티 게시글 섹션** — 세로 리스트
  - 각 항목: 제목 + 본문 미리보기 + 댓글/좋아요 수 + 작성자 닉네임(네이비) + 레벨 뱃지
  - 항목 탭 → `/community/:postId`
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
  - 우측: 공유 아이콘 / 북마크(스크랩) 아이콘 / ⋮(더보기) 메뉴
    - 북마크: 스크랩 상태 반영(채워진 아이콘 = 스크랩됨). 탭 시 스크랩 토글
    - 스크랩 완료 시 화면 중앙에 "스크랩되었습니다" 토스트 표시
    - 공유: `share_plus`로 제목+본문 외부 공유
    - ⋮ 본인 글: 수정 / 삭제
    - ⋮ 타인 글: 차단 / 신고
- **작성자 행 (`_ProfileRow`)**
  - CircleAvatar(radius 20) + 닉네임 + 레벨 뱃지(작성자 현재 레벨 실시간 반영)
  - 팔로우/팔로잉 버튼 (본인이 아닐 때)
  - 탭 → `/profile/:uid`
- **본문 영역**
  - 리뷰 제목 (굵게)
  - 제품 태그 칩 — 잉크: 파랑 계열, 만년필: 보라 계열. 탭 → `/archive/:type/:productId`
  - 별점
  - 블로그 형식 본문 (텍스트+이미지 블록 혼합) 또는 기존 body+imageUrls
  - 이미지 탭 → 전체화면 ImageViewer (스와이프 가능)
  - 작성 시간 / "수정됨" 표시
- **액션 바**
  - 좋아요(하트) + 좋아요 수 — 탭 시 좋아요 토글 (+EXP 1 원작성자 획득)
  - 댓글 아이콘 + 댓글 수
- **댓글 목록 (`CommentTile`)**
  - 댓글: CircleAvatar + 닉네임 + 레벨 뱃지(현재 레벨) + 작성 시간 + 본문
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

## 피드 화면 (`feed_screen.dart`)
**경로:** 별도 경로 없음, 하단 탭 중 하나에 임베드 가능

**전체·리뷰·커뮤니티 탭 구조**
- 전체 탭: 리뷰 + 커뮤니티 게시글 시간순 혼합
  - 리뷰 항목: [리뷰] 배지 + 제목 + 별점 + 본문 미리보기 + 썸네일. 탭 → `/review/:id`
  - 커뮤니티 항목: [커뮤니티] 배지 + 제목 + 본문 + 작성자 닉네임(네이비). 탭 → `/community/:id`
- 리뷰 탭 → `ReviewFeedScreen(showAppBar: false)` 임베드
- 커뮤니티 탭 → `CommunityScreen(showAppBar: false)` 임베드

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
| `homeDiscoveryProvider` | FutureProvider | 인기 리뷰 + 최근 게시글 |
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
- `lib/features/feed/screens/feed_screen.dart`
- `lib/core/shell/main_shell.dart`
- `lib/core/router/app_router.dart`
- `lib/core/utils/toast_utils.dart`
- `lib/shared/widgets/level_up_dialog.dart`
- `lib/shared/widgets/level_badge.dart`
