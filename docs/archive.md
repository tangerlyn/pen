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
  - 색상 계열 / 특수 속성 / 브랜드 / 정렬 칩 — 전부 바텀시트가 아니라, 칩을 누르면 그 칩이 그대로 헤더가 되어 바로 아래로 옵션 목록이 펼쳐지는 드롭다운(토스 스타일)으로 통일되어 있음(예전엔 정렬만 바텀시트였음). 칩 위치/크기에 `CompositedTransformTarget`·`Follower`로 앵커링되고, 선택 개수에 맞춰 헤더 폭이 실시간으로 늘어남(`IntrinsicWidth`). 선택이 늘어나 헤더가 넓어지면서 드롭다운이 화면 오른쪽 경계(여백 12px)를 넘으려 하면, 폭을 줄이는 대신 칩 목록 전체를 왼쪽으로 부드럽게 스크롤해서 경계 안으로 당겨옴(`CompositedTransformFollower`가 칩을 실시간으로 따라가므로 드롭다운도 같이 이동)(`_FilterRowState._adjustScrollForOverflow`). 이 보정은 매번 "현재 스크롤 위치 + 넘친 만큼"을 더하는 게 아니라, 스크롤이 0이었다면 이 칩이 있었을 자리를 기준으로 필요한 스크롤 위치를 절대값으로 다시 계산함 — 그래야 서로 다른 칩을 여러 번 열고 닫아도 한쪽으로 계속 밀리지 않고, 필요 없을 땐 자연스럽게 원래 자리로 돌아옴. 칩이 몇 개 없어서(예: 만년필 탭은 브랜드+정렬 칩 2개뿐) 목록 자체가 스크롤할 여지가 부족하면 보정이 부족한 채 끝날 수 있어서, 칩 목록 맨 끝에 보이지 않는 여유 폭(400px)을 붙여둠(`_scrollReserveWidth`) — 단, 드롭다운이 열려있을 때만 존재하고 닫히면 0으로 돌아가서, 평소 사용자가 직접 손가락으로 목록을 미는 경우엔 실제 칩 길이만큼만 스크롤되고(양끝 다 정상적으로 고무줄처럼 튕겨 돌아옴) 그 빈 공간까지 밀려서 칩이 하나도 안 보이게 되는 일은 없음. 바깥 영역은 어둡게 딤 처리, 바깥 탭으로 닫힘
    - 칩은 조건이 선택된 상태(active)일 때만 네이비 배경이 채워지고, 선택 없으면 배경 없이 글씨만 보임
    - 색상 계열: 빨강·주황·노랑·초록·파랑·보라·검정 7개 (`InkModel.autoColorFamily`가 hexColor의 HSV로 자동 분류)
    - 특수 속성: 일반·펄·테
    - 브랜드: 현재 등록된 잉크들의 브랜드 목록을 중복 제거 후 이름순으로 보여줌 (`inkBrandsProvider`, `ArchiveRepository.getInkFieldSuggestions()` 재사용)
    - 색상 계열/특수 속성/브랜드는 다중 선택 가능, 목록 맨 위 "전체" 항목으로 선택 해제, 하단 "완료" 버튼으로 확정. 고르는 동안은 로컬에만 임시로 담아두고, 닫힐 때만 실제 필터에 반영(고를 때마다 목록이 바로 바뀌지 않도록)
    - 정렬(기본순·인기순)은 단일 선택이라 "전체"/"완료" 없이 옵션을 탭하면 바로 적용되고 닫힘 — "기본순"은 이름 가나다순(한글 우선) + 영어/숫자로 시작하는 이름은 뒤로 밀려 알파벳/숫자 순 (별점순은 별점 시스템 비활성화로 목록에서 숨김 — `ArchiveSortOption.rating`은 enum에 남아있으나 UI에서 필터링됨)
    - 필터 칩과 정렬 칩 모두 같은 가로 스크롤 영역에 있어서 함께 좌우로 스와이프됨(예전엔 정렬 칩만 오른쪽에 고정이었음)
  - 리스트 하단 "새 잉크 직접 등록하기" 버튼 → 제품 등록 바텀 시트
- **만년필 탭**
  - `PenListTile` 목록 (탭 → `/archive/pen/:productId`)
  - 브랜드 필터 칩 — 잉크 탭과 동일한 드롭다운 방식, 다중 선택 가능 (`penBrandsProvider`, `ArchiveRepository.getPenBrands()`)
  - 정렬 칩 — 잉크 탭과 동일하게 같은 가로 스크롤 영역에서 드롭다운으로 선택. "기본순"은 잉크와 동일하게 이름 가나다순/알파벳순
  - 리스트 하단 "새 만년필 직접 등록하기" 버튼 → 제품 등록 바텀 시트
- 스크롤 맨 위로 버튼

---

### `archive_detail_screen.dart`
**경로:** `/archive/:type/:productId` (type: `ink` 또는 `pen`)

**잉크 상세 화면**
- **인스타 프로필 스타일 헤더** (`_InkProfileHeader`) — 배경색 없음, 좌측에 잉크 원(`InkDropCircle`), 우측에 브랜드 + (이름·타입 뱃지를 한 줄로) + 리뷰 수(리뷰 없으면 "아직 리뷰가 없어요") 표시 (평균 별점 표시는 비활성화됨)
- **위시리스트 하트 버튼** — 탭 시 위시리스트 추가/제거 (로그인 필요), 결과에 따라 화면 중앙에 "위시리스트에 추가/제거되었습니다" 팝업 표시 (`showWishlistToast`)
- **해당 잉크 리뷰 목록** — "사용자 리뷰" 섹션, 탭 → `/review/:reviewId`

**만년필 상세 화면**
- **정보 카드** (`_InfoCard`) — 브랜드, 라인업, 닙 소재, 충전 방식, 닙 사이즈
- **위시리스트 하트 버튼** — 잉크 상세와 동일하게 결과 팝업 표시
- **해당 만년필 리뷰 목록** — "사용자 리뷰" 섹션, 탭 → `/review/:reviewId`

**공통**
- **리뷰 작성 버튼** — "사용자 리뷰" 섹션 제목 오른쪽에 네이비 테두리 아웃라인 버튼 "새 리뷰 작성" (아이콘 없음, 작고 눈에 덜 띄는 스타일) → `/write/review?type=ink|pen&productId=xxx`
- 우측 상단 ⋮(더보기) 메뉴 (`_ReportButton`) — 현재는 "신고하기"만 노출됨. 잉크 정보 수정 폼(`_EditInkSheet`, 브랜드/이름/타입/색상 수정 + `ArchiveRepository.updateInk` 연동)은 구현은 돼 있지만 메뉴 항목이 없어 진입 불가 — 코드는 남겨두고 진입점만 뺀 상태, 필요 시 메뉴에 ListTile 복원하면 됨
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
| avgRating | double | 평균 별점 (집계) — 별점 시스템 비활성화로 UI에는 표시 안 됨, 필드/집계 로직은 유지 |
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
| avgRating | double | 평균 별점 — 별점 시스템 비활성화로 UI에는 표시 안 됨, 필드/집계 로직은 유지 |
| isUserAdded | bool | 유저가 직접 등록했는지 여부 |

---

## 상태 관리

| Provider | 종류 | 역할 |
|---|---|---|
| `archiveProvider` | StateNotifierProvider | 탭·필터·목록·페이지네이션 상태 (`loadMore()`로 다음 페이지 이어붙임, 검색/필터가 걸려있을 땐 이미 전체를 가져온 상태라 무동작) |
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
- 사용 예시는 파일 상단 주석 참고. 이 방식(웹사이트 스크래핑)으로 글입다 159종의 hexColor를 채웠음.

**참고 — 이미지 스크린샷에서 색을 뽑은 경우 (디아민 109종, 파이롯트 이로시주쿠 24종)**: 브랜드 웹사이트가 아니라 사용자가 올린 컬러차트 스크린샷(이미지 파일)에서 뽑은 경우엔 `extract_ink_colors.js`를 그대로 쓰지 않고, 그때그때 좌표를 계산해 각 잉크 스와치 영역을 자르는 별도의 1회성 Python 스크립트를 작성해서 처리함(레포에 커밋되지 않은 세션별 스크래치 스크립트). 색상 추출 알고리즘 자체(흰 배경 제외 + 채도 높은 픽셀 중앙값)는 동일하게 재사용했지만, "이미지 목록을 어떻게 얻는지"(웹 스크래핑 vs. 정적 이미지 좌표 크롭)는 소스마다 달라서 매번 새로 짜야 함.

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
