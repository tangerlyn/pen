# 리뷰 (Review)

## 개요

잉크·만년필에 대한 사진·별점·텍스트 리뷰를 작성하고 탐색하는 피드. 그리드/리스트 전환, 팔로잉/인기 필터 지원.

---

## 화면 목록

### `review_feed_screen.dart`
- 경로: `/review` (하단 탭 2번째)
- **필터 바** — 전체 / 팔로잉 / 인기 탭
- **뷰 전환** — 그리드(2열) ↔ 리스트 (SharedPreferences에 설정 저장)
- 무한 스크롤 (cursor-based pagination, pageSize 20)
- 스켈레톤 로딩 UI (ReviewGridSkeleton / ReviewListSkeleton)
- 스크롤 맨 위로 버튼
- 상단 검색 아이콘 → `/search?type=review`

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

## 데이터 구조 (ReviewModel)

```
reviewId, uid, nickname, profileImageUrl
inkIds[], penIds[]
rating (0.5 단위)
content
imageUrls[]
likeCount, commentCount
createdAt, updatedAt
```

---

## 상태 관리

- `feedProvider` — StateNotifier. 필터·커서·정렬 상태 보유. `loadMore()` 메서드로 페이지 추가
- `reviewWriteProvider` — 작성 폼 상태 (제품 태그, 이미지, 별점, 텍스트)
- `archiveDetailProvider` — 제품 태깅 시 제품 정보 조회에 재사용

---

## 관련 파일

- `lib/features/review/providers/review_write_provider.dart`
- `lib/features/home/providers/feed_provider.dart`
- `lib/data/repositories/review_repository.dart`
- `lib/shared/widgets/review/review_feed_card.dart`
- `lib/shared/widgets/review/comment_tile.dart`
