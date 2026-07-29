# 커뮤니티 (Community)

## 개요

만년필 덕후들의 질문·정보공유·필사·그림 게시판. 카테고리 필터, 인기글 섹션, 무한 스크롤 지원.

---

## 화면 목록

### `community_screen.dart`
**경로:** `/community` (하단 탭 3번째 — 커뮤니티)

**화면 구성**
- **AppBar** (showAppBar: true일 때)
  - 제목 "커뮤니티"
  - 우측 검색 아이콘 → `/search?type=community`
- **카테고리 필터 칩 바** (가로 스크롤)
  - 전체 / 질문 / 정보공유 / 필사 / 그림
  - 선택 시 해당 카테고리 게시글만 표시
  - 카테고리 선택 시 인기글 섹션 숨김
- **인기글 섹션** (전체 탭일 때만 표시)
  - **최근 3일 이내** 작성된 게시글 중 좋아요+댓글 수 상위 게시글 PageView 카드 (오래된 인기글이 계속 노출되지 않도록 기간 제한)
  - 각 카드: 제목 + 본문 미리보기 + 작성자 CircleAvatar(radius 10) + 닉네임(네이비) + 좋아요 수 + 댓글 수 (카테고리 뱃지·작성 시간은 없음 — 목록이 빡빡해 보여 날짜 표시 생략)
  - 닉네임이 길면 말줄임(`...`) 처리, 좋아요/댓글 수는 항상 보이도록 고정
  - 탭 → `/community/:postId`
- **전체 게시글 리스트 (`PostCard`)**
  - 카테고리 뱃지(질문=파랑, 정보공유=초록, 필사=보라, 그림=주황) + 제목 + (제목 줄 오른쪽 끝에 작성 시간) + 본문 미리보기 + 썸네일
  - 하단: 프사(CircleAvatar radius 11) + 닉네임(네이비, w600) + 레벨 뱃지 + 좋아요 수 + 댓글 수 — 닉네임+레벨+좋아요+댓글만으로 이미 빡빡해서, 날짜는 하단이 아니라 위쪽 제목 줄 오른쪽 끝(여유 있는 자리)에 작게 배치
  - 닉네임이 길어도 오버플로우 없이 말줄임 처리 (좋아요/댓글 수 침범 시에만 잘림)
  - 좋아요 아이콘 탭 → 좋아요 즉시 토글 (카드 내에서 처리)
  - 카드 탭 → `/community/:postId` (`TapScale`이 `HitTestBehavior.opaque`라 카드 안 빈 여백을 눌러도 동일하게 동작 — 프사/닉네임에 별도 프로필 이동 탭은 없음)
  - `PostCard`는 `showDate`(기본 true) 파라미터로 제목 줄의 날짜 표시 여부를 제어할 수 있음 — 현재는 모든 사용처에서 기본값(표시)을 씀
- 무한 스크롤 (pageSize 20)
- 게시글 사이 Divider 구분선
- **하단 우측 FAB** (연필 아이콘) → `/community/write`

---

### `post_detail_screen.dart`
**경로:** `/community/:postId`

**화면 구성**
- **AppBar**
  - 좌측: 뒤로가기
  - 우측: 북마크(스크랩) 아이콘 / ⋮(더보기) 메뉴
    - 북마크: 스크랩 상태 반영. 탭 시 스크랩 토글
    - 스크랩 완료 시 "스크랩되었습니다" 토스트 표시
    - ⋮ 본인 글: 수정 → `PostWriteScreen(postToEdit:)` / 삭제
    - ⋮ 타인 글: 차단 / 신고
- **헤더 (`_EditorialByline`)**
  - 카테고리 뱃지 (네이비 톤 단색, `PostCard`와 달리 카테고리별 색 구분 없음)
  - 제목
  - 작성자: CircleAvatar(radius 16) + 닉네임(네이비) + 레벨 뱃지(현재 레벨) + 작성 시간 — 리뷰 상세의 `_ProfileRow`와 동일한 배치(닉네임+뱃지 아래 줄에 날짜)
  - 탭 → `/profile/:uid`
  - 팔로우/팔로잉 버튼 (본인 글이 아닐 때) — 리뷰 상세와 동일하게 우측에 표시, 탭 시 팔로우 토글
  - 작성 시간 표기(`formatPostDate`, `core/utils/post_date_format.dart`): 3일 이내는 상대 시간("방금"/"N분 전"/"N시간 전"/"1~3일 전"), 4일 이상은 "YYYY.MM.DD". 상세 화면·댓글·답글에 공통 적용, 목록(`PostCard`/`ReviewListTile`)은 제목 줄 오른쪽 끝에 작게 표시
- **본문** — 텍스트 + 첨부 이미지 (탭 시 전체화면 ImageViewer)
- **액션 바**
  - 좋아요(하트) + 좋아요 수 — 탭 시 토글
  - 댓글 아이콘 + 댓글 수
- **댓글 목록** (트리 구조)
  - 댓글: CircleAvatar(실제 프로필 사진, 작성자 정보는 실시간 반영) + 닉네임 + 레벨 뱃지(현재 레벨) + (게시글 작성자 본인이면 "작성자" 뱃지) + 작성 시간 + 본문
  - 댓글 ⋮ 메뉴: 본인 → 수정/삭제 / 타인 → 차단/신고
  - "답글" 텍스트 탭 → 하단 입력창 답글 모드 전환
  - 답글 (들여쓰기): 닉네임 + 레벨 뱃지 + 작성 시간 + 본문 + ⋮ 메뉴
  - 닉네임 탭 → `/profile/:uid`
- **하단 댓글 입력창**
  - 답글 모드: "@닉네임 에게 답글" 배너 + X(취소)
  - 전송 탭 → 댓글/답글 등록 (+EXP 2 획득)

---

### `post_write_screen.dart`
**경로:** `/community/write`

**화면 구성**
- **AppBar**: "게시글 작성" 또는 "게시글 수정"
- 카테고리 선택 칩 — 질문 / 정보공유 / 필사 / 그림
- 제목 입력
- 본문 — 블로그 에디터 (텍스트 블록 + 이미지 블록 혼합 입력, `BlogBodyEditor`, 리뷰 작성과 동일 컴포넌트)
  - 텍스트·이미지 블록 전체를 감싸는 테두리 하나로 "하나의 입력 칸"처럼 보이도록 표시 (개별 텍스트 블록 자체에는 테두리 없음)
  - 본문 텍스트 블록에 포커스가 있는 동안에만(제목칸 포커스 시엔 안 보임) 키보드 바로 위에 네이버 블로그 스타일 고정 툴바(`BlogEditorToolbar`)가 나타남 — 카메라 / 사진 / 링크 아이콘
    - 카메라 / 사진: 현재 커서 위치에서 텍스트를 자르고 그 사이에 사진을 삽입 (커서가 텍스트 중간이면 뒷부분이 사진 다음 블록으로 이어짐) — 삽입 직후 사진 바로 뒤 블록으로 자동 포커스 이동해 한 칸에서 계속 이어 쓰는 것처럼 동작. 포커스된 블록이 없으면 맨 뒤에 삽입
    - 링크: 버튼만 배치된 상태로, 탭하면 "준비 중" 토스트만 표시 (삽입 기능은 추후 구현 예정)
  - 이미지 블록 우측 상단 ✕ 버튼으로 개별 삭제 가능 — 삭제한 자리의 앞뒤가 둘 다 텍스트 블록이면 자동으로 하나로 합쳐져 사진이 없었던 것처럼 한 단락으로 복원됨
- **등록 버튼** → 저장 후 `/community/:postId`로 이동 (+EXP 5 획득)
  - 이미지 업로드 실패 시 화면 중앙 팝업 에러 표시

---

## 데이터 구조

### PostModel

| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | 게시글 ID |
| authorId | String | 작성자 UID |
| authorNickname | String | 작성 시점 닉네임 스냅샷 |
| authorLevel | int | 작성 시점 레벨 스냅샷 (표시는 현재 레벨 우선) |
| category | String? | 질문 / 정보공유 / 필사 / 그림 |
| title | String | 제목 |
| body | String | 본문 |
| imageUrls | List\<String\> | 첨부 이미지 URL 목록 |
| likeCount | int | 좋아요 수 |
| commentCount | int | 댓글 수 |
| createdAt | DateTime | 작성 시각 |

### PostCommentModel

| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | 댓글 ID |
| authorId | String | 작성자 UID |
| authorNickname | String | 닉네임 스냅샷 |
| authorLevel | int | 레벨 스냅샷 (표시는 현재 레벨 우선) |
| body | String | 댓글 본문 |
| createdAt | DateTime | 작성 시각 |

### ReplyModel (게시글 댓글의 답글)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | 답글 ID |
| authorId | String | 작성자 UID |
| authorNickname | String | 닉네임 스냅샷 |
| authorLevel | int | 레벨 스냅샷 (표시는 현재 레벨 우선) |
| body | String | 답글 본문 |
| createdAt | DateTime | 작성 시각 |

스크랩 서브컬렉션: `posts/{postId}/scraps/{uid}`

---

## 상태 관리

| Provider | 종류 | 역할 |
|---|---|---|
| `communityFeedProvider` | StateNotifierProvider | 카테고리 필터·커서·게시글 목록 |
| `popularPostsProvider` | Provider | 인기글 (최근 3일 이내 게시글만 필터 후 클라이언트 정렬) |
| `postLikeStatusProvider` | StreamProvider.family | 좋아요 실시간 상태 |
| `postScrapStatusProvider` | StreamProvider.family | 스크랩 실시간 상태 |

---

## 관련 파일

- `lib/features/community/screens/community_screen.dart`
- `lib/features/community/screens/post_detail_screen.dart`
- `lib/features/community/screens/post_write_screen.dart`
- `lib/features/community/providers/community_provider.dart`
- `lib/data/repositories/post_repository.dart`
- `lib/data/models/post_model.dart`
- `lib/data/models/reply_model.dart`
- `lib/shared/widgets/community/post_card.dart`
- `lib/shared/widgets/level_badge.dart`
- `lib/shared/widgets/author_badge.dart`
- `lib/core/utils/post_date_format.dart`
- `lib/shared/widgets/tap_scale.dart`
- `lib/shared/widgets/editor/blog_body_editor.dart`
