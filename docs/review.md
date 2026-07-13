# 리뷰 (Review)

## 개요

잉크·만년필에 대한 사진·별점·텍스트 리뷰를 작성하고 탐색하는 피드. 그리드/리스트 전환, 팔로잉 최근 게시글 우선 노출, 무한 스크롤 지원.

---

## 화면 목록

### `review_feed_screen.dart`
**경로:** `/review` (하단 탭 2번째 — 리뷰)

**화면 구성**
- **AppBar** (showAppBar: true일 때)
  - 제목 "리뷰"
  - 우측 검색 아이콘 → `/search?type=review`
- **단일 피드** (탭·섹션 구분 없이 인스타그램처럼 하나로 이어짐) — 팔로잉한 유저가 최근 24시간 내 작성한 리뷰가 맨 앞에 자연스럽게 붙고, 바로 이어서 Firestore 최신순 전체 피드가 무한 스크롤로 이어짐
  - 팔로잉 최근 리뷰는 한 번만 조회(페이지네이션 없음), 전체 피드에 이미 포함된 리뷰는 중복 제거
  - 팔로잉한 유저가 없거나 24시간 내 새 글이 없으면 그냥 전체 피드부터 시작
- **카테고리 칩 필터 바 (`FeedFilterBar`)**
  - 전체 / 잉크 / 만년필
  - 선택 시 해당 카테고리 리뷰만 표시
- **뷰 전환 버튼** — 그리드(2열) ↔ 리스트 토글 (설정 SharedPreferences에 저장)
- **그리드 뷰 (`ReviewFeedCard`)** — 2열, 별점 + 좋아요/댓글 수 + 작성 시간 표시, 카드 탭 → `/review/:reviewId`
- **리스트 뷰 (`ReviewListTile`, `lib/shared/widgets/review/review_list_tile.dart`)** — 한 줄씩 표시
  - 별점 뱃지(노란 별 + 점수) + 제목
  - 잉크/만년필 태그 칩 + 본문 미리보기
  - 하단: 프사(CircleAvatar radius 11) + 닉네임(네이비, w600) + 레벨 뱃지 + 작성 시간 + 좋아요/댓글 수
  - 닉네임이 길어도 오버플로우 없이 말줄임 처리 (좋아요/댓글 수 침범 시에만 잘림)
  - 탭 → `/review/:reviewId`
  - 리뷰 탭 리스트 뷰뿐 아니라 **리뷰 검색 결과**(`type=review`)와 **마이페이지/유저 프로필의 리뷰 탭·스크랩북**에서도 동일하게 재사용됨 (예전에 별도로 있던 `ReviewListCard`는 이 위젯에 통합되어 삭제됨)
- 무한 스크롤: 스크롤 하단 200px 이내 진입 시 다음 페이지 자동 로드
- 스켈레톤 로딩 UI (`ReviewGridSkeleton` / `ReviewListTileSkeleton`)
- 스크롤 맨 위로 버튼 (우측 하단, 100px 이상 스크롤 시 표시)
- **하단 우측 FAB** (카메라 아이콘) → `/write/review`

---

### `review_write_screen.dart`
**경로:** `/write/review`
**쿼리 파라미터:** `?type=ink|pen&productId=xxx` (제품 상세에서 진입 시 자동 태깅)

**화면 구성**
- **AppBar**: "리뷰 작성" 또는 "리뷰 수정" (수정 모드)
- **제품 태그 추가**
  - 잉크/만년필 각각 검색 후 선택 (최대 각 3개, 합계 5개)
  - 선택된 태그 칩 표시, X 버튼으로 제거
- **사진 첨부**
  - 최대 5장, 갤러리 선택 / 카메라 촬영
  - 사진 없으면 저장 버튼 비활성화 + 하단에 "사진을 1장 이상 추가해주세요" 안내 문구
  - 드래그로 순서 변경 가능
- **별점** — 0.5 단위 탭 입력 (1~5점)
- **제목** — 텍스트 입력
- **본문** — 블로그 에디터 (텍스트 블록 + 이미지 블록 혼합 입력)
- **저장 버튼** — 탭 시 업로드 + 피드 무효화 → `/review/:reviewId`로 이동
  - 업로드 중 로딩 상태로 버튼 비활성화
  - EXP +10 획득 (레벨업 시 다이얼로그 표시)
- 수정 모드: `reviewToEdit` 파라미터로 기존 데이터 초기화

---

## 데이터 구조 (ReviewModel)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | 리뷰 ID |
| authorId | String | 작성자 UID |
| authorNickname | String | 작성 시점 닉네임 스냅샷 |
| authorLevel | int | 작성 시점 레벨 스냅샷 (표시는 현재 레벨 우선) |
| inkIds | List\<String\> | 태그된 잉크 ID 목록 |
| penIds | List\<String\> | 태그된 만년필 ID 목록 |
| rating | double | 별점 (0.5 단위) |
| title | String | 제목 |
| body | String | 본문 텍스트 (검색/미리보기용) |
| contentBlocks | List\<Map\> | 블로그 형식 본문 블록 |
| imageUrls | List\<String\> | 이미지 URL 목록 |
| likeCount | int | 좋아요 수 |
| commentCount | int | 댓글+답글 수 |
| scrapCount | int | 스크랩 수 |
| createdAt | DateTime | 작성 시각 |
| updatedAt | DateTime? | 수정 시각 |

스크랩 서브컬렉션: `reviews/{reviewId}/scraps/{uid}`

---

## 상태 관리

| Provider | 종류 | 역할 |
|---|---|---|
| `feedProvider` | StateNotifierProvider | 필터·커서·팔로잉 최근/전체 리뷰 목록 상태 |
| `reviewDetailProvider` | StateNotifierProvider.family | 리뷰 상세 + 좋아요/스크랩 토글 |
| `reviewWriteProvider` | StateNotifierProvider | 작성 폼 상태 |
| `commentsProvider` | StreamProvider.family | 댓글 목록 실시간 |
| `reviewRepliesProvider` | StreamProvider.family | 답글 목록 실시간 |
| `scrappedReviewsProvider` | StreamProvider.family | 내 스크랩 리뷰 목록 |

---

## 관련 파일

- `lib/features/review/screens/review_feed_screen.dart`
- `lib/features/review/screens/review_write_screen.dart`
- `lib/features/review/providers/review_write_provider.dart`
- `lib/features/home/screens/review_detail_screen.dart`
- `lib/features/home/providers/feed_provider.dart`
- `lib/features/home/providers/review_detail_provider.dart`
- `lib/data/repositories/review_repository.dart`
- `lib/data/models/review_model.dart`
- `lib/shared/widgets/review/review_feed_card.dart`
- `lib/shared/widgets/review/review_list_tile.dart`
- `lib/shared/widgets/review/comment_tile.dart`
- `lib/shared/widgets/level_badge.dart`
- `lib/core/utils/toast_utils.dart`
