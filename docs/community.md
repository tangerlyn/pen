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
- **전체 게시글 리스트 (`PostCard`, `showDate: false`)**
  - 카테고리 뱃지(질문=파랑, 정보공유=초록, 필사=보라, 그림=주황) + 제목 + 본문 미리보기 + 썸네일
  - 하단: 프사(CircleAvatar radius 11) + 닉네임(네이비, w600) + 레벨 뱃지 + 좋아요 수 + 댓글 수 (작성 시간은 목록에서 생략 — 닉네임+레벨+좋아요+댓글까지 이미 빡빡해서 날짜까지 넣으면 너무 조밀해짐)
  - 닉네임이 길어도 오버플로우 없이 말줄임 처리 (좋아요/댓글 수 침범 시에만 잘림)
  - 좋아요 아이콘 탭 → 좋아요 즉시 토글 (카드 내에서 처리)
  - 카드 탭 → `/community/:postId` (`TapScale`이 `HitTestBehavior.opaque`라 카드 안 빈 여백을 눌러도 동일하게 동작 — 프사/닉네임에 별도 프로필 이동 탭은 없음)
  - `PostCard`는 `showDate`(기본 true) 파라미터로 날짜 표시 여부를 제어. 커뮤니티 탭·홈 "커뮤니티 최신글"·마이페이지/유저프로필의 커뮤니티 탭·스크랩북에서는 `false`로 꺼서 날짜 없이 표시, 검색 결과 등 다른 곳은 기본값(표시)을 씀
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
  - 작성자: CircleAvatar(radius 16) + 닉네임(네이비) + 레벨 뱃지(현재 레벨) + 작성 시간
  - 탭 → `/profile/:uid`
  - 작성 시간 표기(`formatPostDate`, `core/utils/post_date_format.dart`): 3일 이내는 상대 시간("방금"/"N분 전"/"N시간 전"/"1~3일 전"), 4일 이상은 "YYYY.MM.DD". 상세 화면·댓글·답글에 공통 적용, 목록(`PostCard`/`ReviewListTile`)에서는 `showDate: false`로 아예 생략
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
- 본문 입력
- 사진 첨부 (최대 5장, 갤러리 선택)
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
