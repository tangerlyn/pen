# 리뷰 (Review)

## 개요

잉크·만년필에 대한 사진·텍스트 리뷰를 작성하고 탐색하는 피드. 그리드/리스트 전환, 팔로잉 최근 게시글 우선 노출, 무한 스크롤 지원. (별점 시스템은 비활성화됨 — 아래 "별점" 관련 서술은 코드상 주석 처리로 보존된 상태)

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
- **그리드 뷰 (`ReviewFeedCard`, `lib/shared/widgets/review/review_feed_card.dart`)** — 2열, 카드 간 간격 1px로 빈틈없이 붙어서 표시(아카이브 상세 리뷰 그리드와 동일한 방식). 홈탭 "최신 리뷰" 가로 스크롤 섹션에서도 동일 위젯을 재사용
  - 사진 우측 상단: 사진 여러 장이면 장수 뱃지 (별점 뱃지는 비활성화됨)
  - 사진 하단: 잉크/펜 태그가 있으면 검은색 그라데이션(투명→흑 55%)을 깔고 그 위에 첫 번째 태그 이름(ex. "블랙 45 +4" — 여러 개면 나머지 개수를 "+N"으로 표시)을 흰 글씨(그림자 처리)로 오버레이 표시, 태그 없으면 그라데이션도 표시 안 함
  - 사진 아래 정보 영역: 작성자 프사·닉네임(길면 말줄임) + 레벨 뱃지 + 제목(오른쪽 끝에 작성 시간을 작은 회색 글씨로 함께 표시) — 좋아요·댓글은 그리드에서 생략
  - 카드 탭 → `/review/:reviewId`
- **리스트 뷰 (`ReviewListTile`, `lib/shared/widgets/review/review_list_tile.dart`)** — 한 줄씩 표시
  - 제목 + (제목 줄 오른쪽 끝에 작성 시간) — 별점 뱃지는 비활성화됨
  - 잉크/만년필 태그 칩 + 본문 미리보기
  - 하단: 프사(CircleAvatar radius 11) + 닉네임(네이비, w600) + 레벨 뱃지 + 좋아요/댓글 수 — 여기가 이미 빡빡해서, 날짜는 위쪽 제목 줄 오른쪽 끝에 작게 배치
  - 닉네임이 길어도 오버플로우 없이 말줄임 처리 (좋아요/댓글 수 침범 시에만 잘림)
  - 탭 → `/review/:reviewId`
  - 리뷰 탭 리스트 뷰뿐 아니라 **리뷰 검색 결과**(`type=review`)와 **마이페이지/유저 프로필의 리뷰 탭·스크랩북**에서도 동일하게 재사용됨 (예전에 별도로 있던 `ReviewListCard`는 이 위젯에 통합되어 삭제됨). `showDate`(기본 true) 파라미터로 제목 줄의 날짜 표시 여부를 제어할 수 있음 — 현재는 모든 사용처에서 기본값(표시)을 씀
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
- (별점 시스템 비활성화 — 작성 폼에서 제거됨, `_RatingSection`/`StarRatingInput` 코드는 주석 처리로 보존)
- **제목** — 텍스트 입력
- **본문** — 블로그 에디터 (텍스트 블록 + 이미지 블록 혼합 입력, `BlogBodyEditor`)
  - 텍스트·이미지 블록 전체를 감싸는 테두리 하나로 "하나의 입력 칸"처럼 보이도록 표시 (개별 텍스트 블록 자체에는 테두리 없음)
  - 사진 없으면 저장 시 "사진을 1장 이상 추가해주세요" 안내 다이얼로그
  - 본문 텍스트 블록에 포커스가 있는 동안에만(제목칸 포커스 시엔 안 보임) 키보드 바로 위에 네이버 블로그 스타일 고정 툴바(`BlogEditorToolbar`)가 나타남 — 카메라 / 사진 / 링크 아이콘
    - 카메라 / 사진: 현재 커서 위치에서 텍스트를 자르고 그 사이에 사진을 삽입 (커서가 텍스트 중간이면 뒷부분이 사진 다음 블록으로 이어짐) — 삽입 직후 사진 바로 뒤 블록으로 자동 포커스 이동해 한 칸에서 계속 이어 쓰는 것처럼 동작. 포커스된 블록이 없으면 맨 뒤에 삽입
    - 링크: 버튼만 배치된 상태로, 탭하면 "준비 중" 토스트만 표시 (삽입 기능은 추후 구현 예정)
  - 이미지 블록 우측 상단 ✕ 버튼으로 개별 삭제 가능 — 삭제한 자리의 앞뒤가 둘 다 텍스트 블록이면 자동으로 하나로 합쳐져 사진이 없었던 것처럼 한 단락으로 복원됨
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
| rating | double | 별점 (0.5 단위) — 별점 시스템 비활성화로 항상 0.0, 필드/Firestore 저장은 유지 |
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
- `lib/core/utils/post_date_format.dart`
- `lib/shared/widgets/editor/blog_body_editor.dart`
