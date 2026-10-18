# 메인 경험 전환 — 기록 홈 + 스와치 기록 플로우 (2026-10-18~)

목표: 다른 사용자가 없어도 혼자 기록하는 것만으로 쓸모 있는 앱. 로그인 후 첫 화면 = 내 잉크 기록.
분석 명세: `docs/analytics_spec_swatch.md`

## 확정된 결정 (2026-10-18, 사용자 승인)
- 탭 0 라벨 "기록", 인덱스·순서 유지
- 디스커버리 피드: `HomeScreen` 그대로 `/discover`로 이동, 기록 홈 앱바·빈 화면에서 진입 + Remote Config `home_variant`로 롤백 스위치
- 데이터: 기존 `inkChart`에 선택 필드(`inkId`, `penName`, `nibSize`, `paperName`, `recordedAt`) 추가, 마이그레이션 없음
- 공책이 없으면 첫 저장 때 "내 잉크 기록" 공책(private) 자동 생성
- 내 컬렉션 = `users/{uid}/ownedInks/{inkId}` (본인만 읽기/쓰기, 위시리스트와 별개)
- 새 잉크 요청 = `inkRequests/{id}` (생성만 본인, 읽기 본인, 수정·삭제 클라이언트 불가)
- 펜·닙·종이는 자유 텍스트
- 리뷰 작성 진입값에 `discover` 추가 (`/discover` FAB)
- 분석 이벤트에 `swatch_save_fail`, `swatch_record_exit` 포함
- 마이페이지 기존 스와치 수정 화면의 브랜드 필수 → 선택으로 완화 (최소 수정)

## S0. 계획·명세
- [x] 계획 체크리스트 (이 섹션)
- [x] 분석 명세 초안 `docs/analytics_spec_swatch.md`

## S1. 데이터 계층
- [x] `InkChartModel` 선택 필드 + 하위 호환 `fromMap`/`toMap`
- [x] `OwnedInk` 모델·Repository·Provider, `InkRequest` Repository
- [x] 색 계열 상수 공용화 (`archive_filter_widgets` → 공용)
- [x] `firestore.rules`: `ownedInks`, `inkRequests`, `inkChart` 새 필드 검증
- [x] 테스트: 구 문서 하위 호환, 빈 필드 생략 (`test/ink_chart_model_test.dart`)
- [x] 규칙 에뮬레이터 테스트 24케이스 (`scripts/firestore_rules_test.mjs`)
- 참고: 예전 경로 `users/{uid}/inkChart`(공책 없음)는 현재 앱 어디서도 안 읽음 → 기록 홈 집계 대상 아님. 운영 데이터 존재 여부는 사용자 확인 필요

## S2. 스와치 기록 플로우
- [x] `/record/new` 라우트, `SwatchRecordScreen`, 컨트롤러, 잉크 매칭 시트, 카탈로그 캐시
- [x] `SwatchRecordTracker` + 이벤트 연결
- [x] 테스트: 사진+이름만으로 저장, 기본 공책 생성, `filterInks`, 이벤트 순서, 저장 버튼 위젯

## S3. 아카이브 잉크 상세
- [x] "내 컬렉션에 추가" 토글, "스와치 기록하기" → `/record/new?inkId=..&entry=ink_detail` (`test/ink_record_actions_test.dart`)

## S4. 기록 홈
- [ ] `RecordHomeScreen` (그리드/타임라인, 빈 화면, 앱바 검색·알림·둘러보기, FAB), 상세 화면
- [ ] 탭 0 교체, `/discover` 라우트, 리뷰 `entry=discover`
- [ ] 테스트: 빈 화면 버튼 2개, 기존 차트 기록 표시, 보기 전환

## S5. 마무리
- [ ] Remote Config `home_variant` 스위치
- [ ] 기존 스와치 수정 화면 브랜드 선택 입력
- [ ] QA 체크리스트, `flutter analyze` warning 0 / `flutter test` 전체 통과
- [ ] (사용자) 규칙 배포 `firebase deploy --only firestore:rules`, 실기기 확인

---

# 리뷰 작성 퍼널 로그 설계·QA 프로젝트

명세: `docs/analytics_spec.md`
목표: 로그 명세 → 구현 → QA 시나리오 검증 → BigQuery 정합성 검증 → 모니터링 대시보드까지 한 사이클 완성
최소 목표 (10/25 이전): 명세 + 구현 + 시나리오 QA + 검증 쿼리 3개

## D1. 준비 (코드 변경 없음)
- [x] 로그 명세서 초안 작성 (`docs/analytics_spec.md`)
- [x] 명세 리뷰 및 확정 (사용자 확인)
- [x] Firebase 콘솔에서 Analytics 활성화 + BigQuery 연결 (2026-10-12, 리전 asia-northeast3, 매일 내보내기만, 광고 ID 제외)
- [x] 요금제(Blaze) 확인

## D2. 구현
- [x] `firebase_analytics` 의존성 추가
- [x] `AnalyticsLogger` 인터페이스 + Firebase 구현 + 테스트용 Fake (`lib/core/analytics/`)
- [x] `ReviewWriteTracker`: 세션 ID 발급, start 1회 플래그, attempt 번호, 경과 시간, 최종 단계 관리
- [x] 라우트에 `entry` 쿼리 파라미터 추가 (홈 / 리뷰 피드 / 제품 상세), 수정 모드는 `review_detail`
- [x] `BlogBodyEditor`에 본문 변경·사진 추가·사진 삭제 콜백 추가
- [x] 화면/프로바이더에 이벤트 연결 (`view`, `start`, `photo_add/remove`, `attempt`, `blocked`, `fail`, `success`, `exit`)
- [x] `success`는 `createReview` 직후, `addExpAndCheck` 이전에 기록
- [x] 사용자 속성 `build_env` 설정
- [x] 단위 테스트: S1·S2·S4·S5 시나리오의 이벤트 순서와 파라미터를 Fake 로거로 검증
- [x] `flutter analyze`, `flutter test` 통과

## D3. 데이터 연결
- [x] Firestore `reviews` → BigQuery (Stream Firestore to BigQuery 확장, 사용자 직접 설치). 기존 문서 9건 백필 → changelog 9행·문서 9개 일치, `createdAt`(`_seconds`)·`imageUrls` 파싱 확인
- [x] 백필 데이터 확인 중 DQ-12 누락 발견: IMPORT 문서를 제외해서 확장 설치 전·로깅 배포 후 리뷰(실기기 2건)가 검사에서 빠짐 → 제외 조건 삭제, 테스트에 백필 유실 위반 추가, 전체 통과
- [x] 개인정보처리방침 업데이트 (`docs/privacy_policy.md` + 앱 내 `privacy_screen.dart`)
- [ ] App Store Connect·Play Console 개인정보 항목 업데이트 (사용자)
- [x] TestFlight 빌드 배포 (`build_env=testflight`)

## D4. QA 시나리오 실행
- [ ] S1~S9를 iOS·Android에서 실행, 실행 시각 기록
- [ ] DebugView로 실시간 1차 확인

### 1차 실기기 확인 (2026-10-12, iOS TestFlight)
- 리뷰 2건 작성 → Analytics 실시간 `review_submit_success` 2건, `review_id` 2개가 Firestore 문서 ID와 1:1 일치 (REST로 조회 확인)
- 두 리뷰 모두 Firestore `imageUrls` 1장 → `photo_count` 대조는 BigQuery 테이블 생성 후 (DQ-07)
- 중복 문서 없음

## D5. 검증 SQL
- [x] DQ-01~DQ-14 쿼리 작성 (`analytics/bigquery/checks/`), 정제 뷰·마트 (`analytics/bigquery/sql/`)
- [x] 검증 쿼리 테스트: 가짜 데이터 + 규칙별 심은 위반 → 14개 오탐·미탐 0 (`analytics/bigquery/test/run_tests.py`)
- [x] 실데이터 배포: `deploy.py --env prod` (2026-10-13, 원천 analytics_535406606) → 첫 점검 10-12분 14개 규칙 위반 0, 퍼널 2/2/2/2/2, 지연 p95 0.46초
- [x] 첫 점검에서 발견: DQ-12(Firestore 전용) 0건이 testflight에 채워져 의미 없는 0 → 규칙별 `env_scope` 추가, 테스트 5) 추가
- [ ] 일일 점검 예약 쿼리 등록 (bq CLI는 브라우저 동의 필요 → BigQuery 콘솔에서 사용자 등록)
- [ ] 시나리오 기대값 vs 실제 로그 비교표 작성
- [ ] 발견한 불일치 원인 분석 → 수정 → 재검증

## D6. 자동화·대시보드
- [x] 일일 점검 잡 작성 (`jobs/dq_daily.sql`, 최근 7일 재계산·멱등성 테스트 통과)
- [ ] 예약 쿼리 등록: `deploy.py --env prod --schedule`
- [x] 대시보드 구성안 + 보고서 생성 링크 (`docs/analytics_dashboard.md`)
- [ ] Looker Studio 차트 배치·공유 (사용자)

## 후속 과제
- [ ] 화면 조회 로그: 현재 화면 이름이 전부 `FlutterViewController`로만 수집됨 → go_router 화면 이동을 `screen_view`로 남기는 설계 필요

## D7. 회고
- [x] 케이스 스터디 초안 (`docs/analytics_case_study.md`) — QA S1~S9 결과 칸은 실기기 대조 후 채움

## 중복 리뷰 수정 (D2에 포함)
- [x] EXP 지급 실패를 non-fatal로 (Crashlytics 기록, 등록은 성공 처리)
- [x] 업로드 중 완료 버튼 연타 방지 (`_isSubmitting` 가드)
- [x] 리뷰 문서 ID를 화면 진입 시 고정 → 재저장 시 같은 문서 덮어쓰기
- [ ] 실기기 확인: 업로드 중 연타 시 리뷰 1개만 생성되는지 (QA S8)

## D3 이전 필수
- [x] `flutterfire configure` 재실행 → 설정 파일 변경 없음 확인 (`IS_ANALYTICS_ENABLED=false`는 그대로, 최신 SDK에서는 쓰지 않는 값). 같이 바뀐 firebase.json·pbxproj는 원복
- [x] `cd ios && pod install` (FirebaseAnalytics 11.15.0 설치)
- [x] Firestore → BigQuery 확장 설치 시 데이터 세트 리전을 **asia-northeast3**으로 (Analytics와 같아야 조인 가능)

## 검토
### D2 (2026-10-12)
- 새 파일: `lib/core/analytics/analytics_logger.dart`, `lib/features/review/analytics/review_write_tracker.dart`, `test/review_write_tracker_test.dart`
- 수정: 작성 화면·프로바이더·에디터 콜백·진입점 3곳·라우터·`main.dart`(build_env)
- `flutter test` 24개 통과 (신규 11개), `flutter analyze` 에러 없음 (기존 info/warning만 남음)
- 실기기 확인은 아직 하지 않음 → D4 QA 시나리오에서 확인

### D3~D7 (2026-10-12)
- BigQuery 레이어: 정제 뷰 2, 마트 3, 검증 규칙 14, 일일 점검 잡, 리포트 뷰 (`analytics/bigquery/`)
- 검증 쿼리 테스트로 잡은 버그: DQ-11이 세션 1개를 이벤트 수만큼 세던 문제 → 위반 건수 = 대상 수로 정의
- 테스트 데이터 세트 `nibpen.review_dq_test` 생성 (가짜 데이터, 삭제해도 무방)
- 막힌 것: Firestore 확장 설치는 Claude 권한 정책상 실행 불가 → 사용자 직접 설치
