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
- [ ] Firestore `reviews` → BigQuery (Stream Firestore to BigQuery 확장)
- [ ] 개인정보처리방침·스토어 개인정보 항목 업데이트
- [ ] TestFlight / 내부 테스트 빌드 배포 (`build_env=testflight`)

## D4. QA 시나리오 실행
- [ ] S1~S9를 iOS·Android에서 실행, 실행 시각 기록
- [ ] DebugView로 실시간 1차 확인

### 1차 실기기 확인 (2026-10-12, iOS TestFlight)
- 리뷰 2건 작성 → Analytics 실시간 `review_submit_success` 2건, `review_id` 2개가 Firestore 문서 ID와 1:1 일치 (REST로 조회 확인)
- 두 리뷰 모두 Firestore `imageUrls` 1장 → `photo_count` 대조는 BigQuery 테이블 생성 후 (DQ-07)
- 중복 문서 없음

## D5. 검증 SQL
- [ ] DQ-01~DQ-14 쿼리 작성 (`scripts/sql/` 또는 별도 저장소)
- [ ] 시나리오 기대값 vs 실제 로그 비교표 작성
- [ ] 발견한 불일치 원인 분석 → 수정 → 재검증

## D6. 자동화·대시보드
- [ ] BigQuery 예약 쿼리로 검증 규칙 매일 실행 → `dq_check_results` 테이블 적재
- [ ] Looker Studio: ① 로그 품질 모니터링 ② 작성 퍼널 (테스트 데이터임을 명시)

## 후속 과제
- [ ] 화면 조회 로그: 현재 화면 이름이 전부 `FlutterViewController`로만 수집됨 → go_router 화면 이동을 `screen_view`로 남기는 설계 필요

## D7. 회고
- [ ] 발견한 불일치, 원인, 조치, 남은 한계 정리

## 중복 리뷰 수정 (D2에 포함)
- [x] EXP 지급 실패를 non-fatal로 (Crashlytics 기록, 등록은 성공 처리)
- [x] 업로드 중 완료 버튼 연타 방지 (`_isSubmitting` 가드)
- [x] 리뷰 문서 ID를 화면 진입 시 고정 → 재저장 시 같은 문서 덮어쓰기
- [ ] 실기기 확인: 업로드 중 연타 시 리뷰 1개만 생성되는지 (QA S8)

## D3 이전 필수
- [x] `flutterfire configure` 재실행 → 설정 파일 변경 없음 확인 (`IS_ANALYTICS_ENABLED=false`는 그대로, 최신 SDK에서는 쓰지 않는 값). 같이 바뀐 firebase.json·pbxproj는 원복
- [x] `cd ios && pod install` (FirebaseAnalytics 11.15.0 설치)
- [ ] Firestore → BigQuery 확장 설치 시 데이터 세트 리전을 **asia-northeast3**으로 (Analytics와 같아야 조인 가능)

## 검토
### D2 (2026-10-12)
- 새 파일: `lib/core/analytics/analytics_logger.dart`, `lib/features/review/analytics/review_write_tracker.dart`, `test/review_write_tracker_test.dart`
- 수정: 작성 화면·프로바이더·에디터 콜백·진입점 3곳·라우터·`main.dart`(build_env)
- `flutter test` 24개 통과 (신규 11개), `flutter analyze` 에러 없음 (기존 info/warning만 남음)
- 실기기 확인은 아직 하지 않음 → D4 QA 시나리오에서 확인
