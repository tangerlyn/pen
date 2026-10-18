# 기록 (Record)

## 개요

첫 탭 "기록". 내가 칠한 잉크 스와치를 모아 보는 개인 아카이브로, 다른 사용자가 없어도 혼자 기록하는 것만으로 쓸모 있게 하는 것이 목적이다 (2026-10-18 디스커버리 홈에서 전환).

데이터는 마이페이지 잉크 차트와 **같은 문서**다 — `users/{uid}/inkBooks/{bookId}/inkChart/{chartId}`. 기록 홈은 모든 공책의 스와치를 합쳐서 보여주고, 새로 기록한 스와치는 마이페이지 공책에도 그대로 보인다.

## 화면

| 경로 | 화면 | 설명 |
|---|---|---|
| `/` (탭 0) | `record_home_screen.dart` | 그리드(3열)·타임라인(월별) 전환, 빈 화면 안내, FAB "스와치 기록". 앱바: 둘러보기(`/discover`)·검색·알림 |
| `/record/new?entry=&inkId=` | `swatch_record_screen.dart` | 사진 → 크롭(`InkCropScreen` 재사용) → 잉크 매칭 → 선택 입력 → 저장 |
| `/record/:bookId/:entryId` | `swatch_record_detail_screen.dart` | 기록 상세, 수정(같은 기록 화면을 수정 모드로)·삭제 |
| `/discover` | `features/home/screens/home_screen.dart` | 기존 디스커버리 피드 (코드 변경 없음, 위치만 이동) |

진입점: 기록 홈 FAB(`entry=home`), 빈 화면 버튼(`entry=empty_state`), 아카이브 잉크 상세 "스와치 기록하기"(`entry=ink_detail`, `inkId` 미리 채움).

## 스와치 기록 규칙

- 필수: 사진, 잉크 이름. 저장 버튼은 둘 다 있을 때만 켜진다
- 선택: 브랜드, 펜, 닙, 종이, 기록 날짜(비우면 저장 시각), 메모(텍스트+사진, 리뷰와 같은 에디터)
- 잉크 매칭 (`ink_match_sheet.dart`): 아카이브 전체 목록을 한 번만 읽어 캐시(`inkCatalogProvider`)하고 검색·색 계열·브랜드 필터는 메모리에서 처리. 없으면 "찾는 잉크가 없어요" → 이름 직접 입력 + `inkRequests`에 추가 요청(기본 체크)
- 저장할 공책: 마지막으로 쓴 공책 → 첫 공책. 공책이 없으면 첫 저장 때 **"내 잉크 기록"(비공개)** 공책을 만든다
- 문서 ID는 화면 진입 시 고정 — 응답만 실패해 다시 저장해도 중복 문서가 생기지 않는다. 쓰기 실패 시 올린 사진은 지운다

## 데이터 (스와치 문서에 추가된 선택 필드)

`inkId`, `penName`, `nibSize`, `paperName`, `recordedAt` — 값이 있을 때만 쓴다. 예전 문서는 그대로 읽히므로 마이그레이션 없음. 마이페이지 공책 화면의 수정(`updateEntry`)은 이 필드를 건드리지 않고, 기록 화면의 수정(`updateRecord`)은 비운 필드를 삭제한다.

새 컬렉션:
- `users/{uid}/ownedInks/{inkId}` — 내 컬렉션(보유 잉크), 본인만 읽기·쓰기. 아카이브 잉크 상세의 "내 컬렉션에 추가"
- `inkRequests/{id}` — 새 잉크 요청. 본인 명의 생성·본인 읽기만, 처리는 관리자 SDK

보안 규칙 테스트: `firebase emulators:exec --only firestore --project demo-nibpen "node scripts/firestore_rules_test.mjs"`

## 롤백

Remote Config `home_variant`를 `discover`로 바꾸면 첫 탭이 기존 디스커버리 홈(라벨 "홈")으로 돌아간다. 기본값 `record`. 앱 시작 시 한 번 읽으므로 앱을 다시 켜야 반영된다.

## 분석

`docs/analytics_spec_swatch.md` — `swatch_record_start` / `swatch_photo_select` / `swatch_ink_match` / `swatch_save_success` / `swatch_save_fail` / `swatch_record_exit`
