# 아카이브 (Archive)

## 개요

잉크·만년필 제품 DB 탐색 화면. CSV로 초기 데이터를 Firestore에 적재하며, 유저가 직접 새 제품을 등록할 수도 있음. 각 제품 페이지에서 해당 제품 리뷰 통계와 목록 확인 가능.

---

## 화면 목록

### `archive_screen.dart`
- 경로: `/archive` (하단 탭 4번째)
- 잉크 / 만년필 탭 (TabController)
- **잉크 탭 필터**
  - 브랜드 드롭다운
  - 색상 계열 멀티 선택 칩 (레드·오렌지·옐로우·그린·시안·블루·퍼플·핑크·무채색·기타)
  - 종류 멀티 선택 칩 (일반·펄·쉰)
- **만년필 탭 필터**
  - 브랜드·펜촉 소재·잉크 주입 방식·펜촉 굵기 드롭다운
- 필터 상태 칩 표시, 초기화 버튼
- 우측 상단: 검색 아이콘 → `/archive/search`, 제품 직접 등록 (+) 버튼
- 스크롤 맨 위로 버튼

### `archive_detail_screen.dart`
- 경로: `/archive/:type/:productId` (`type`: ink / pen)
- **잉크 상세**
  - 색상 헥스 기반 그라데이션 헤더
  - 브랜드·이름·종류·용량
  - 리뷰 통계 (평균 별점, 총 리뷰 수)
  - 해당 잉크 리뷰 목록 (최신순)
  - 이 잉크로 리뷰 작성 버튼
- **만년필 상세**
  - 브랜드·모델·펜촉 소재·굵기·주입 방식
  - 리뷰 통계
  - 이 만년필과 자주 쓰인 잉크 추천 (궁합 추천, 상위 3개)
  - 해당 만년필 리뷰 목록
- 우측 상단 신고 버튼

### `archive_search_screen.dart`
- 경로: `/archive/search`
- 잉크·만년필 브랜드명·제품명 클라이언트사이드 검색
- 검색 결과 탭 구분 (잉크 / 만년필)

---

## 제품 직접 등록

- 바텀 시트(`add_product_bottom_sheet.dart`)에서 잉크·만년필 선택
- 잉크 등록 폼: 브랜드 자동완성, 이름 자동완성, 색상 계열, 종류, 헥스 컬러 (컬러 피커), 용량
- 중복 등록 방지: 동일 브랜드+이름 조합 Firestore 사전 확인
- `isUserAdded: true` 필드로 관리자 등록 데이터와 구분

---

## 데이터 구조

**InkModel**
```
id, brand, name, inkType, hexColor, capacityMl
reviewCount, avgRating  (집계값, 조회 시 주입)
isUserAdded, addedBy, createdAt
```

**PenModel**
```
id, brand, modelName, nibMaterial, nibSizes[], fillType, lineup, priceRange
reviewCount, avgRating
isUserAdded, addedBy, createdAt
```

---

## 상태 관리

- `archiveProvider` — StateNotifier. 탭·필터·목록 상태
- `archiveDetailProvider` — FutureProvider.family (type, productId)

---

## 데이터 초기화 (CSV)

`assets/info_csv/inks.csv`, `pens.csv`를 읽어 Firestore에 batch write.  
개발자 설정 메뉴(설정 화면 → 디버그 모드)에서 수동 실행.

---

## 관련 파일

- `lib/features/archive/providers/archive_provider.dart`
- `lib/features/archive/providers/archive_detail_provider.dart`
- `lib/data/repositories/archive_repository.dart`
- `lib/shared/widgets/archive/add_product_bottom_sheet.dart`
