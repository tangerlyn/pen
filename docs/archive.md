# 아카이브 (Archive)

## 개요

잉크·만년필 제품 DB 탐색 화면. CSV로 초기 데이터를 Firestore에 적재하며, 유저가 직접 새 제품을 등록할 수도 있음. 각 제품 상세 페이지에서 리뷰 통계, 위시리스트 추가, 리뷰 작성이 가능.

> **현재 상태:** 아카이브 화면의 만년필 탭은 주석 처리되어 비활성화됨 (`archive_screen.dart`). 화면에는 잉크만 노출되며, 만년필 관련 코드는 재활성화 가능하도록 남겨둔 상태. 만년필 상세(`/archive/pen/:productId`)·검색·위시리스트 등 나머지 만년필 데이터/라우트 자체는 그대로 존재.

---

## 화면 목록

### `archive_screen.dart`
**경로:** `/archive` (하단 탭 4번째 — 아카이브)

**화면 구성**
- **AppBar**
  - 제목 "아카이브"
  - 우측 검색 아이콘 → `/archive/search`
- **잉크 그리드** (진입 시 바로 표시, 탭 전환 없음)
  - 4열 그리드로 잉크 원형 스와치(`InkDropCircle`) + 이름 표시 — 탭 → `/archive/ink/:productId`
  - 색상 계열 멀티 선택 칩 (레드·오렌지·옐로우·그린·시안·블루·퍼플·핑크·무채색·기타)
  - 특수 속성 멀티 선택 칩 (일반·펄·테)
  - 정렬 칩 (기본순·별점순·인기순)
  - 리스트 하단 "새 잉크 직접 등록하기" 버튼 → 제품 등록 바텀 시트
- ~~만년필 탭~~ — 주석 처리로 비노출 (구현: 브랜드/펜촉 소재/잉크 주입 방식/펜촉 굵기 필터 + `PenListTile` 목록, `_PenList` 위젯에 보존)
- 스크롤 맨 위로 버튼

---

### `archive_detail_screen.dart`
**경로:** `/archive/:type/:productId` (type: `ink` 또는 `pen`)

**잉크 상세 화면**
- **헤더** — 잉크 헥스 색상 기반 그라데이션 배경
- **정보 카드** — 브랜드, 이름, 종류, 용량
- **리뷰 통계** — 평균 별점 + 총 리뷰 수
- **위시리스트 하트 버튼** — 탭 시 위시리스트 추가/제거 (로그인 필요)
- **리뷰 작성 버튼** → `/write/review?type=ink&productId=xxx`
- **해당 잉크 리뷰 목록** — 탭 → `/review/:reviewId`

**만년필 상세 화면**
- **정보 카드** — 브랜드, 모델명, 펜촉 소재, 펜촉 굵기, 잉크 주입 방식
- **리뷰 통계** — 평균 별점 + 총 리뷰 수
- **이 만년필과 자주 쓰인 잉크 추천** (궁합 추천, 상위 3개) — 탭 → `/archive/ink/:id`
- **위시리스트 하트 버튼**
- **리뷰 작성 버튼** → `/write/review?type=pen&productId=xxx`
- **해당 만년필 리뷰 목록** — 탭 → `/review/:reviewId`

**공통**
- 우측 상단 신고 버튼
- 잉크 색상 비교 버튼 — 구현 완료, **적용 보류** (`ink_compare_screen.dart` 존재)

---

### `archive_search_screen.dart`
**경로:** `/archive/search`

**화면 구성**
- 검색창 (자동 포커스)
- 잉크 / 만년필 통합 검색 (브랜드명·제품명)
- 결과: 잉크 탭 + 만년필 탭으로 구분 표시
- 각 결과 탭 → `/archive/:type/:productId`

---

## 제품 직접 등록

**진입:** 아카이브 AppBar 우측 + 버튼 → 바텀 시트에서 잉크/만년필 선택

**잉크 등록 폼**
- 브랜드 자동완성
- 이름 자동완성
- 색상 계열 선택
- 종류 선택 (일반/펄/쉰)
- 헥스 컬러 직접 입력 또는 컬러 피커
- 용량(mL) 입력
- 중복 등록 방지: 동일 브랜드+이름 Firestore 사전 확인
- `isUserAdded: true` 필드로 관리자 등록 데이터와 구분

---

## 위시리스트 (`wishlist_screen.dart`)
**경로:** `/mypage/wishlist`

**화면 구성**
- AppBar: "위시리스트"
- 위시리스트 아이템 목록
  - 각 항목: 제품명 + 브랜드 + 타입(잉크/만년필) + 하트 버튼
  - 항목 탭 → `/archive/:type/:productId`
  - 하트 버튼 탭 → 위시리스트에서 제거
- 빈 경우: "위시리스트가 비어있습니다" 안내

---

## 데이터 구조

### InkModel

| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | 잉크 ID |
| brand | String | 브랜드명 |
| name | String | 잉크명 |
| inkType | String | 일반/펄/쉰 |
| hexColor | String | 색상 헥스값 |
| capacityMl | double | 용량(mL) |
| reviewCount | int | 리뷰 수 (집계) |
| avgRating | double | 평균 별점 (집계) |
| isUserAdded | bool | 유저가 직접 등록했는지 여부 |

### PenModel

| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | 만년필 ID |
| brand | String | 브랜드명 |
| modelName | String | 모델명 |
| nibMaterial | String | 펜촉 소재 |
| nibSizes | List\<String\> | 펜촉 굵기 목록 |
| fillType | String | 잉크 주입 방식 |
| reviewCount | int | 리뷰 수 |
| avgRating | double | 평균 별점 |
| isUserAdded | bool | 유저가 직접 등록했는지 여부 |

---

## 상태 관리

| Provider | 종류 | 역할 |
|---|---|---|
| `archiveProvider` | StateNotifierProvider | 탭·필터·목록 상태 |
| `archiveDetailProvider` | FutureProvider.family | 제품 상세 + 리뷰 통계 |
| `wishlistProvider` | StreamProvider.family | 위시리스트 실시간 목록 |
| `wishlistStatusProvider` | StreamProvider.family | 특정 제품 위시리스트 여부 |

---

## 데이터 초기화 (CSV)

`assets/info_csv/inks.csv`, `pens.csv`를 읽어 Firestore에 batch write.
설정 화면 → 디버그 모드에서 수동 실행 가능.

---

## 관련 파일

- `lib/features/archive/screens/archive_screen.dart`
- `lib/features/archive/screens/archive_detail_screen.dart`
- `lib/features/archive/screens/archive_search_screen.dart`
- `lib/features/archive/screens/ink_compare_screen.dart` (적용 보류)
- `lib/features/archive/providers/archive_provider.dart`
- `lib/features/archive/providers/archive_detail_provider.dart`
- `lib/data/repositories/archive_repository.dart`
- `lib/data/repositories/wishlist_repository.dart`
- `lib/data/models/ink_model.dart`
- `lib/data/models/pen_model.dart`
- `lib/data/models/wishlist_model.dart`
- `lib/features/mypage/screens/wishlist_screen.dart`
- `lib/shared/providers/wishlist_providers.dart`
