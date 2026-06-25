# 리뷰 (Review)

## 개요

잉크·만년필에 대한 사진·별점·텍스트 리뷰를 작성하고 탐색하는 피드. 그리드/리스트 전환, 팔로잉/추천 필터 지원.

---

## 화면 목록

### `review_feed_screen.dart`
- 경로: `/review` (하단 탭 2번째)
- **추천/팔로잉 탭 바** — 팔로잉한 유저가 있을 때만 상단에 탭 행 표시
  - 팔로잉 없을 경우 탭 행 숨김, 카테고리 칩만 노출
  - 팔로잉 있을 경우 추천 / 팔로잉 탭 표시
  - **팔로잉 탭 빨간 점**: 마지막 방문 이후 팔로잉한 사람이 새 리뷰를 올린 경우 탭 제목 오른쪽 상단에 6px 빨간 원 표시
  - 팔로잉 탭 클릭 시 `_markFollowingAsSeen()` 호출 → 현재 시각을 SharedPreferences(`following_last_seen`)에 저장, 빨간 점 사라짐
  - 팔로잉이 0명이 되면 feedType이 '팔로잉'인 경우 자동으로 '추천'으로 리셋
- **카테고리 칩 필터 바** (`FeedFilterBar`) — 전체 / 잉크 / 만년필
- **뷰 전환** — 그리드(2열) ↔ 리스트 (SharedPreferences에 설정 저장)
- 무한 스크롤 (cursor-based pagination, pageSize 20)
- 스켈레톤 로딩 UI (ReviewGridSkeleton / ReviewListTileSkeleton)
- 스크롤 맨 위로 버튼
- 상단 검색 아이콘 → `/search?type=review`
- 하단 우측 FAB → `/write/review`
- `showAppBar` 파라미터 지원 — `false`일 때 SliverAppBar 숨김 (FeedScreen 임베드용)

### `review_write_screen.dart`
- 경로: `/write/review`
- **제품 태깅** — 잉크·만년필 검색 후 선택. 각각 최대 3개
- **사진 첨부** — 최대 5장, 갤러리 선택 / 카메라 촬영, 드래그 정렬
- **별점** — 0.5 단위 탭 입력
- **본문** — 텍스트 필드
- 수정 모드: `reviewToEdit` 파라미터로 기존 리뷰 데이터 초기화
- 제품 상세에서 진입 시 해당 제품 자동 태깅 (`initialType`, `initialProductId` 쿼리 파라미터)
- 이미지 업로드 실패 시 스낵바 에러 메시지 표시
- 제출 중 로딩 상태로 버튼 비활성화

---

## 리뷰 상세 (`review_detail_screen.dart`)
- 경로: `/review/:reviewId`
- **상단 커스텀 AppBar** — 뒤로가기, 스크랩 북마크 버튼(로그인 시), more_vert 메뉴
  - 스크랩 버튼: 북마크 아이콘, 스크랩 상태 반영 (파랑 활성화)
  - 스크랩 시 화면 중앙 토스트("스크랩되었습니다") 표시, 취소 시 미표시
- **중간** — 이미지 PageView (스와이프), 별점, 제품 태그(잉크/만년필), 작성자 프로필, 본문, 작성 시간
- **액션 바** — 좋아요(하트) + 좋아요 수, 댓글 아이콘 + 댓글 수
- **댓글** — 댓글·대댓글 트리. 좋아요, 신고, 삭제(본인)
- **하단 입력창** — 대댓글 타겟 닉네임 표시, 전송
- 작성자·댓글 작성자 프로필 탭 → `/profile/:uid`

---

## 데이터 구조 (ReviewModel)

```
reviewId, authorId
inkIds[], penIds[]
rating (0.5 단위)
title, body
contentBlocks[]          // 블로그 형식 본문 (선택)
imageUrls[]
likeCount, commentCount, scrapCount
createdAt, updatedAt
isScrapped, isLiked      // 현재 유저 상태 (클라이언트 조합)
```

스크랩 서브컬렉션: `reviews/{reviewId}/scraps/{uid}` — `{ uid, createdAt }`

---

## 상태 관리

- `feedProvider` — StateNotifier. 필터·커서·정렬 상태 보유. `loadMore()` 메서드로 페이지 추가
  - `FeedFilter.feedType`: 추천 / 팔로잉
  - 팔로잉 탭: 팔로잉 UIDs `whereIn` 쿼리 (Firestore 한도 30)
- `followingHasNewProvider` — `FutureProvider<bool>`. SharedPreferences의 `following_last_seen` 타임스탬프 기준으로 팔로잉 유저의 새 리뷰 유무 확인. 처음 방문(타임스탬프 없음)이면 항상 `false`
- `reviewDetailProvider` — StateNotifierProvider.family. 리뷰 상세 + 좋아요/스크랩 토글
- `reviewWriteProvider` — 작성 폼 상태 (제품 태그, 이미지, 별점, 텍스트)
- `scrappedReviewsProvider` — StreamProvider.family, 실시간 스크랩 목록

---

## 관련 파일

- `lib/features/review/providers/review_write_provider.dart`
- `lib/features/home/providers/feed_provider.dart` (`feedProvider`, `followingHasNewProvider`)
- `lib/features/home/providers/review_detail_provider.dart`
- `lib/data/repositories/review_repository.dart` (`hasNewFollowingReview` 메서드 포함)
- `lib/shared/widgets/review/review_feed_card.dart`
- `lib/core/utils/toast_utils.dart`
