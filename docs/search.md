# 검색 (Search)

## 개요

리뷰·커뮤니티 게시글 통합 검색. 검색 기록 저장, 자동완성, 무한 스크롤 지원.

---

## 화면 목록

### `search_screen.dart`
- 경로: `/search?type=all|review|community`
- `type` 파라미터로 탐색 범위 지정 (리뷰·커뮤니티 진입점에서 각각 호출)
- 검색창 진입 시 자동 포커스

**검색 전 상태**
- 검색 기록 목록 (SharedPreferences, 최근 10개)
- 자동완성 드롭다운 (입력 중 Firestore prefix 쿼리)
- 검색 기록 개별 삭제 / 전체 삭제

**검색 결과 상태**
- 결과 없음 안내 메시지
- 리뷰 결과: 2열 그리드 (`ReviewFeedCard`)
- 커뮤니티 결과: 리스트 (`PostCard`)
- 무한 스크롤: `NotificationListener<ScrollNotification>`, `extentAfter < 200`에서 `loadMore()` 호출
- 로딩 더 보기: 그리드 하단에 `ReviewGridSkeleton` 2개 / 리스트 하단에 `CircularProgressIndicator`

---

## 페이지네이션 구조

### 리뷰 검색
- Firestore `content` 필드 prefix 범위 쿼리 (`` 트릭)
- cursor-based: `startAfterDocument`, pageSize 20

### 커뮤니티 게시글 검색
- `title` 쿼리 + `body` 쿼리 두 서브쿼리를 병합 (중복 제거)
- 각 서브쿼리 커서 독립 관리 (`_lastPostTitleDoc`, `_lastPostBodyDoc`)
- `_seenPostIds` Set으로 cross-page 중복 방지
- 어느 서브쿼리든 소진되면 해당 커서 null 처리 → `loadMore` 시 나머지만 실행

---

## 상태 관리

- `searchProvider` — StateNotifier.family(type)
  - `search(query)` — 커서 초기화 후 첫 페이지 조회
  - `loadMore()` — 기존 커서로 다음 페이지 추가
  - `hasMoreReviews`, `hasMorePosts`, `isLoadingMore` 상태
- `searchHistoryProvider` — StateNotifier (SharedPreferences 영속)
- `suggestionProvider` — FutureProvider (입력값 기반 자동완성)

---

## 관련 파일

- `lib/features/search/providers/search_provider.dart`
- `lib/features/search/providers/suggestion_provider.dart`
- `lib/features/search/screens/search_screen.dart`
