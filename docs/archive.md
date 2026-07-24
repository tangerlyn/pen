# 아카이브 (Archive)

## 개요

잉크·만년필 제품 DB 탐색 화면. CSV로 초기 데이터를 Firestore에 적재하며, 유저가 직접 새 제품을 등록할 수도 있음. 각 제품 상세 페이지에서 위시리스트 추가, 리뷰 작성이 가능.

잉크/만년필 두 탭 모두 활성화되어 있음 (`archive_screen.dart`).

---

## 화면 목록

### `archive_screen.dart`
**경로:** `/archive` (하단 탭 4번째 — 아카이브)

**화면 구성**
- **AppBar**
  - 제목 "아카이브"
  - 우측 검색 아이콘 → `/archive/search`
- **잉크/만년필 탭 바** (스크롤 시 필터 칩과 함께 상단 고정)
- **잉크 탭**
  - 그리드로 잉크 원형 스와치(`InkDropCircle`, 56px) + 브랜드명(연한 색) + 이름(진한 색, 약간 굵게) 2줄 표시 — 탭 → `/archive/ink/:productId`
    - 그리드는 `SliverGridDelegateWithMaxCrossAxisExtent`(셀 최대폭 95) 사용 — 좁은 화면(아이폰 기준)에서는 4열과 동일하게 나오고, 더 넓은 화면에서는 열이 자동으로 늘어나 셀이 커지지 않음
  - 색상 계열 필터 — 텍스트 목록이 아니라 색상칩(원형 스와치 + 라벨) 바텀시트. 빨강·주황·노랑·초록·파랑·보라·검정 7개 (`InkModel.autoColorFamily`가 hexColor의 HSV로 자동 분류)
  - 특수 속성 멀티 선택 칩 (일반·펄·테)
  - 정렬 칩 (기본순·별점순·인기순)
  - 리스트 하단 "새 잉크 직접 등록하기" 버튼 → 제품 등록 바텀 시트
- **만년필 탭**
  - `PenListTile` 목록 (탭 → `/archive/pen/:productId`)
  - 정렬 칩만 제공 (별도 필터 칩 없음)
  - 리스트 하단 "새 만년필 직접 등록하기" 버튼 → 제품 등록 바텀 시트
- 스크롤 맨 위로 버튼

---

### `archive_detail_screen.dart`
**경로:** `/archive/:type/:productId` (type: `ink` 또는 `pen`)

**잉크 상세 화면**
- **인스타 프로필 스타일 헤더** (`_InkProfileHeader`) — 배경색 없음, 좌측에 잉크 원(`InkDropCircle`), 우측에 브랜드 + (이름·타입 뱃지를 한 줄로) + 평균 별점·리뷰 수(리뷰 없으면 "아직 리뷰가 없어요") 표시
- **위시리스트 하트 버튼** — 탭 시 위시리스트 추가/제거 (로그인 필요), 결과에 따라 화면 중앙에 "위시리스트에 추가/제거되었습니다" 팝업 표시 (`showWishlistToast`)
- **해당 잉크 리뷰 목록** — "사용자 리뷰" 섹션, 탭 → `/review/:reviewId`

**만년필 상세 화면**
- **정보 카드** (`_InfoCard`) — 브랜드, 라인업, 닙 소재, 충전 방식, 닙 사이즈
- **위시리스트 하트 버튼** — 잉크 상세와 동일하게 결과 팝업 표시
- **해당 만년필 리뷰 목록** — "사용자 리뷰" 섹션, 탭 → `/review/:reviewId`

**공통**
- **리뷰 작성 버튼** — "사용자 리뷰" 섹션 제목 오른쪽에 네이비 테두리 아웃라인 버튼 "새 리뷰 작성" (아이콘 없음, 작고 눈에 덜 띄는 스타일) → `/write/review?type=ink|pen&productId=xxx`
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
| name | String | 잉크명 (화면엔 이 값만 표시) |
| nameEn | String | 영문 원어명 — 화면엔 안 보이고 검색(`getInks`/`searchInks`)에서 `name`과 함께 매칭됨. 한국어 발음 표기 잉크(예: 디아민)에서 "임페리얼 블루"/"imperial blue" 둘 다 검색되게 하기 위함 |
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

`ArchiveRepository.initializeDatabase()`(앱 내부 메서드)는 UI 트리거가 없는 미사용 코드 — 실제 운영 데이터는 아래 Node 스크립트로 반영한다.

**`scripts/upload_csv.js`** — `assets/info_csv/inks.csv`/`pens.csv`/`papers.csv`를 읽어 Firestore에 upsert(`batch.set`, 기존 컬렉션을 지우지 않고 문서 단위로 덮어씀). `serviceAccountKey.json`(gitignore 대상, 로컬에만 존재) 필요.
```
cd scripts && npm run upload
```

**`scripts/extract_ink_colors.js`** — 브랜드 공식 사이트의 "컬러차트" 페이지(잉크마다 이름 + 워터컬러 스와치 사진이 있는 페이지)에서 대표 색상(hexColor)을 자동으로 뽑아 `inks.csv`에 채워 넣는 도구.
- `scrape` 단계: 사이트별 파서로 `[{title, thumbUrl}, ...]` 목록 JSON을 만듦. 지금은 글입다(wearingeul.kr) 파서만 등록돼 있음 — 새 브랜드는 그 사이트의 HTML 구조에 맞는 파서를 `SCRAPERS`에 추가해야 함. 파싱은 DOM 라이브러리(BeautifulSoup 등) 없이 정규식(regex)으로 직접 처리 — 페이지가 스크롤/무한로드 없이 항목이 한 번의 HTML 응답에 전부 포함된 정적 갤러리 위젯이라 가능했음. 만약 스크롤/AJAX로 항목을 추가 로드하는 사이트라면 이 방식으론 안 되고 브라우저 자동화가 필요함.
- `apply` 단계: 그 목록을 `inks.csv`와 이름으로 매칭해 스와치 이미지를 다운로드하고, 흰 배경/텍스트를 제외한 뒤 채도 높은 픽셀의 중앙값으로 대표색을 계산해 `hexColor`에 반영. 펄/쉰(shimmer/sheen) 타입은 반짝이·테 효과가 베이스 잉크보다 채도가 높아 엉뚱한 색이 뽑힐 수 있어, `overrides.json`으로 실제 색 계열(red/green/blue/purple/gray)을 지정해 보정 가능.
- 사용 예시는 파일 상단 주석 참고. 이 방식으로 글입다 159종 + 디아민(사용자가 올린 컬러차트 이미지에서 동일한 방식으로 추출) 109종의 hexColor를 채웠음.

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
- `scripts/upload_csv.js`
- `scripts/extract_ink_colors.js`
- `lib/shared/providers/wishlist_providers.dart`
