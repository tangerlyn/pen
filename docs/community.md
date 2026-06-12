# 커뮤니티 (Community)

## 개요

만년필 덕후들의 질문·정보 공유 게시판. 카테고리 필터와 인기글 섹션으로 콘텐츠 탐색 제공.

---

## 화면 목록

### `community_screen.dart`
- 경로: `/community` (하단 탭 3번째)
- **카테고리 필터 바** — 전체 / 질문 / 정보공유 칩 (가로 스크롤)
  - 선택한 카테고리로 Firestore `where` 필터 적용
  - 카테고리 선택 시 인기글 섹션 숨김
- **인기글 섹션** — 좋아요+댓글 수 상위 게시글 PageView 카드
  - 각 카드에 작성자 CircleAvatar(radius 10) + 닉네임 표시
  - 작성자 프로필은 `_popularCardAuthorProvider` (FutureProvider.family)로 lazy 로드
- **전체 게시글 리스트** — 최신순, 무한 스크롤 (pageSize 20)
  - 게시글 사이 Divider 구분선 (카드 테두리 없음)
- `showAppBar` 파라미터 지원 — `false`일 때 AppBar 숨김 (FeedScreen 임베드용)
- 우측 상단 검색 아이콘 → `/search?type=community`
- 우측 하단 글쓰기 FAB → `/community/write`

### `post_detail_screen.dart`
- 경로: `/community/:postId`
- **헤더** — 카테고리 뱃지, 제목, 작성자 프로필 행 (`_EditorialByline`)
  - `_EditorialByline`: CircleAvatar(radius 16) + 닉네임 + 작성 시간 (2줄)
  - 작성자 프로필 탭 → `/profile/:uid`
- 본문, 첨부 이미지
- **AppBar 우측** — 스크랩 북마크 버튼 (로그인 시), more_vert 메뉴
  - 스크랩 시 화면 중앙 토스트("스크랩되었습니다") 표시
  - 스크랩 취소 시 토스트 미표시
- 좋아요 토글, 댓글 수
- 댓글·대댓글 목록 (트리 구조)
- 하단 댓글 입력창
- 작성자 본인이면 수정·삭제 메뉴 표시
- 신고 기능 (다른 유저 게시글)

### `post_write_screen.dart`
- 경로: `/community/write`
- 카테고리 선택 칩 — 질문 / 정보공유
- 제목 + 본문 입력
- 사진 첨부 (최대 5장)
- 이미지 업로드 실패 시 스낵바 에러 메시지 표시

---

## 데이터 구조 (PostModel)

```
postId, authorId, authorNickname
category ('질문' | '정보공유')
title, body
imageUrls[]
contentBlocks[]          // 블로그 형식 본문 (선택)
likeCount, commentCount, scrapCount
createdAt
```

스크랩 서브컬렉션: `posts/{postId}/scraps/{uid}` — `{ uid, createdAt }`

---

## 상태 관리

- `communityFeedProvider` — StateNotifier
  - `selectedCategory` 상태 보유 (null = 전체)
  - `setCategory(String?)` — 카테고리 변경 시 목록 초기화 후 재조회
  - 카테고리 필터 시 `where('category')` + 클라이언트 정렬 (Firestore 복합 인덱스 불필요)
  - 카테고리 없는 경우 cursor-based pagination
- `popularPostsProvider` — 인기글 Provider (filteredPosts 기반 클라이언트 정렬)
- `postLikeStatusProvider` — StreamProvider.family, 좋아요 실시간 상태
- `postScrapStatusProvider` — StreamProvider.family, 스크랩 실시간 상태

---

## 관련 파일

- `lib/features/community/providers/community_provider.dart`
- `lib/data/repositories/post_repository.dart`
- `lib/shared/widgets/community/post_card.dart`
