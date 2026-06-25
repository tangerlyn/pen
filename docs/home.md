# 홈 (Home)

## 개요

앱 진입 후 가장 먼저 보이는 디스커버리 피드. 인기 리뷰·최근 커뮤니티 글을 한 화면에서 보여주고, 플로팅 버튼으로 리뷰/게시글 작성에 빠르게 접근.

---

## 화면 목록

### `home_screen.dart`
- 경로: `/`
- **구성 섹션**
  - 인기 리뷰 캐러셀 (수평 스크롤)
  - 최근 커뮤니티 게시글 리스트
  - FAB(+) 클릭 시 바텀 시트 — "리뷰 작성" / "게시글 작성" 선택
- 스크롤 300px 이상 내리면 맨 위로 버튼 표시
- 상단 우측: 알림 아이콘 (미읽 배지)
- "최신 리뷰" 더보기 → `context.go('/review')`
- "커뮤니티 최신글" 더보기 → `context.go('/community')`

### `notification_screen.dart`
- 경로: `/notifications`
- 좋아요·댓글·팔로우 알림 목록 (최신순)
- 알림 탭 시 해당 콘텐츠 화면으로 이동
- 읽음 처리 자동 반영

### `review_detail_screen.dart`
- 경로: `/review/:reviewId`
- **커스텀 AppBar** — 뒤로가기, 스크랩 북마크 버튼(로그인 시), more_vert 메뉴
  - 스크랩 버튼: 북마크 아이콘, 스크랩 상태 반영 (파랑 활성화)
  - 스크랩 시 화면 중앙 토스트("스크랩되었습니다") 표시, 취소 시 미표시
  - 토스트 구현: `toast_utils.dart`의 `showScrapToast(context)` (OverlayEntry, fade-in 200ms → 1200ms 유지 → fade-out 200ms)
- **이미지** — PageView (스와이프), smooth_page_indicator 도트
- **중간** — 별점, 제품 태그(잉크/만년필), 작성자 프로필, 본문, 작성 시간
- **액션 바** — 좋아요(하트) + 좋아요 수, 댓글 아이콘 + 댓글 수 (스크랩 버튼은 AppBar로 이동)
- **댓글** — 댓글·대댓글 트리. 좋아요, 신고, 삭제(본인)
- **하단 입력창** — 대댓글 타겟 닉네임 표시, 전송
- 본문 더보기/접기, 긴 텍스트 truncate
- 작성자·댓글 작성자 프로필 탭 → `/profile/:uid`

---

## 상태 관리

- `homeDiscoveryProvider` — 인기 리뷰 + 최근 게시글 FutureProvider
- `notificationProvider` — 알림 목록 StreamProvider
- `reviewDetailProvider` — 리뷰 상세 + 댓글 StreamProvider

---

## UI 애니메이션 (전역)

### 하단 탭바 (`lib/core/shell/main_shell.dart`)
- 탭 아이콘: 활성 시 `AnimatedScale` 1.15배 확대 (260ms, easeOutBack)
- 아이콘 교체: `AnimatedSwitcher` (180ms) + `ValueKey(isActive)` cross-fade
- 텍스트: `AnimatedDefaultTextStyle` (굵기·색상 전환)
- 활성 인디케이터: 하단 4px 점이 `AnimatedContainer` (primary 색)
- 탭 GestureDetector: `HitTestBehavior.opaque`로 빈 영역도 터치 인식

### 화면 전환 (`lib/core/router/app_router.dart`)
- 모든 GoRoute `builder` → `pageBuilder` (CustomTransitionPage)로 교체
- `_slidePage`: 6% 수평 슬라이드 + 페이드 (320/260ms, easeOutCubic) — 일반 화면
- `_slideUpPage`: 7% 수직 슬라이드 + 페이드 (350/280ms) — 작성/추가 화면
- `_fadePage`: 페이드 전용 (280/200ms) — 인증 화면

---

## 관련 파일

- `lib/features/home/providers/home_discovery_provider.dart`
- `lib/features/home/providers/review_detail_provider.dart`
- `lib/features/home/providers/notification_provider.dart`
- `lib/features/home/providers/feed_provider.dart`
- `lib/core/shell/main_shell.dart`
- `lib/core/router/app_router.dart`
- `lib/core/utils/toast_utils.dart`
