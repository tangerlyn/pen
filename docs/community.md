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
- **인기글 섹션** — 최근 7일 좋아요 수 상위 게시글 (전체 보기 상태에서만 표시)
- **전체 게시글 리스트** — 최신순, 무한 스크롤 (pageSize 20)
- 우측 상단 검색 아이콘 → `/search?type=community`
- 우측 하단 글쓰기 FAB → `/community/write`

### `post_detail_screen.dart`
- 경로: `/community/:postId`
- 제목, 카테고리 뱃지, 본문, 첨부 이미지 (PageView)
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
postId, uid, nickname, profileImageUrl
category ('질문' | '정보공유')
title, content
imageUrls[]
likeCount, commentCount
createdAt
```

---

## 상태 관리

- `communityFeedProvider` — StateNotifier
  - `selectedCategory` 상태 보유 (null = 전체)
  - `setCategory(String?)` — 카테고리 변경 시 목록 초기화 후 재조회
  - 카테고리 필터 시 `where('category')` + 클라이언트 정렬 (Firestore 복합 인덱스 불필요)
  - 카테고리 없는 경우 cursor-based pagination
- `popularPostsProvider` — 최근 7일 인기글 FutureProvider

---

## 관련 파일

- `lib/features/community/providers/community_provider.dart`
- `lib/data/repositories/post_repository.dart`
- `lib/shared/widgets/community/post_card.dart`
