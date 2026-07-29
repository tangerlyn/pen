# 검색 (Search)

## 개요

리뷰·커뮤니티 게시글을 키워드로 검색. 바이그램+유니그램 기반 전문 검색(Firestore `searchIndex` 필드 활용). 최근 검색어 저장(로컬), 연관검색어 자동완성, 정렬 옵션 제공.

---

## 화면 목록

### `search_screen.dart`
**경로:** `/search?type=review|community|all`

진입 시 검색창 자동 포커스.

**`type` 파라미터**
- `review` — 리뷰만 검색 (리뷰 탭 우측 검색 아이콘에서 진입)
- `community` — 게시글만 검색 (커뮤니티 탭 우측 검색 아이콘에서 진입)
- `all` — 리뷰+게시글 통합 검색

---

**[검색어 입력 전] 최근 검색어 화면**

- "최근 검색어" 헤더 + **전체 삭제** 버튼
- 최근 검색어 목록 (최대 20개, SharedPreferences 로컬 저장)
  - 각 항목: 시계 아이콘 + 검색어 + X 버튼(개별 삭제)
  - 항목 탭 → 해당 검색어로 즉시 검색
- 검색어 없으면 "최근 검색어가 없어요" 빈 상태 표시

---

**[검색어 입력 중] 연관검색어 화면**

- 검색창에 텍스트 입력 시 실시간으로 `suggestionProvider` 호출
- 연관검색어 목록: 돋보기 아이콘 + 텍스트
- 항목 탭 → 해당 검색어로 즉시 검색

---

**[검색 완료] 결과 화면**

결과가 없으면 "검색 결과가 없어요 / 다른 검색어로 시도해보세요" 빈 상태 표시.

**`type=review` 결과**
- 상단 우측 정렬 칩 — 탭 시 바텀 시트로 정렬 옵션 선택
  - 최신순 / 인기순(좋아요 수) (평점순은 별점 시스템 비활성화로 목록에서 숨김 — `ReviewSortOption.rating`은 enum에 남아있으나 UI에서 필터링됨)
- 리뷰 리스트 (1열, `ReviewListTile`) — 마이페이지·프로필 리뷰 탭과 동일한 카드
- 각 항목 탭 → `/review/:reviewId`

**`type=community` 결과**
- 상단 우측 정렬 칩 — 최신순 / 인기순(좋아요+댓글 수)
- 게시글 리스트 — `PostCard` + Divider 구분선
- 각 카드 탭 → `/community/:postId`

**`type=all` 결과**
- **리뷰 섹션** 헤더(건수) + 수평 스크롤 카드 (140px 폭, `ReviewFeedCard`)
  - 각 카드 탭 → `/review/:reviewId`
- **커뮤니티 섹션** 헤더(건수) + 세로 리스트 (`PostCard`)
  - 각 항목 탭 → `/community/:postId`

---

## 검색 엔진

**바이그램+유니그램 인덱싱** (`search_utils.dart`)

- 리뷰·게시글 작성/수정 시 `title + body`를 토큰화 → Firestore `searchIndex` 배열 필드에 저장
- 한 글자(유니그램) + 두 글자 연속(바이그램) 토큰 병행 인덱싱 → 단일 글자 검색 지원
- 검색 시 `arrayContainsAny(queryTokens)` 쿼리 → 최대 50건 후보 조회
- 클라이언트 측 `matchesQuery` 함수로 2차 필터링 (오탐 제거)
- 정렬은 모두 클라이언트 측에서 처리 (Firestore 인덱스 불필요)

---

## 상태 관리

| Provider | 종류 | 역할 |
|---|---|---|
| `searchProvider` | StateNotifierProvider.family\<String\> | 검색 상태 (type별 독립 인스턴스) |
| `searchHistoryProvider` | StateNotifierProvider\<List\<String\>\> | 최근 검색어 목록 (SharedPreferences 영속) |
| `suggestionProvider` | FutureProvider.family\<String\> | query 기반 연관검색어 |

---

## 관련 파일

- `lib/features/search/screens/search_screen.dart`
- `lib/features/search/providers/search_provider.dart`
- `lib/features/search/providers/suggestion_provider.dart`
- `lib/core/utils/search_utils.dart`
