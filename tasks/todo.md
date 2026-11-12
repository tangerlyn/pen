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

---

# 보안 점검 1단계: Firestore·Storage 규칙 강화 (2026-11-11)

원칙: 현재 배포된 앱의 정상 동작은 그대로 통과, 악용 경로만 막는다. 규칙 테스트(에뮬레이터)로 양쪽 다 증명.

- [x] reports: 문서 ID = `targetType_targetId_신고자uid` 강제 (1인 다중 신고로 자동 삭제 악용 차단)
- [x] Storage reviews/posts: 덮어쓰기 금지, 이미지·용량 제한, 삭제는 업로더(customMetadata.uploader)만
- [x] Storage profiles/inkChart/pens: 이미지·용량 제한
- [x] 클라이언트 업로드에 `uploader` 메타데이터 추가 (다음 앱 배포부터 본인 사진 삭제 가능)
- [x] inks/pens: 등록 시 addedBy=본인 강제, 잉크 수정은 등록자만·4개 필드만
- [x] 카운터: likeCount/scrapCount는 좋아요 문서 생성·삭제와 묶어 ±1, commentCount ±1, 생성 시 0
- [x] users: 남은 followerCount(팔로우 문서와 묶어 ±1)·exp(+1)만, 본인은 exp +10 이하·팔로워 수 조작 불가
- [x] authorId 변경 금지 (리뷰·게시글·댓글·답글)
- [x] follows: 문서 ID = `followerId_followeeId` 강제, 자기 팔로우 금지
- [x] 규칙 테스트 작성 (`rules_test/`) — 정상 시나리오 통과 + 공격 시나리오 거부
- [x] 배포 완료 (2026-11-11, `firebase deploy --only firestore:rules,storage`)

## 검토 (2026-11-11)
- 규칙 테스트 26개 전부 통과 (`cd rules_test && npm run emu`)
- 수정 전 규칙(HEAD)으로 같은 테스트를 돌리면 공격 10건이 전부 성공 → 테스트가 실제 구멍을 잡는 것 확인. 정상 동작 11건은 수정 전/후 모두 통과
- 발견: Storage는 기존 파일을 덮어쓰는 업로드도 `create`로 판정 → `resource == null`로 막음
- 남은 한계: 
  - 본인 EXP는 "1회 +10 이하"로만 제한 — 반복 호출 파밍은 서버 지급(Functions)으로 옮겨야 완전히 막힘
  - 남의 EXP +1도 좋아요 문서와 묶이지 않음(어떤 글인지 규칙이 알 수 없음) — 같은 이유로 서버 지급 필요
  - 신고 자동 삭제는 이제 계정 5개가 있어야 가능 — 자동 삭제 대신 숨김 처리 검토
  - uploader 메타데이터가 없는 기존 리뷰·게시글 이미지는 앱에서 삭제 안 됨(고아 파일). 새 앱 배포 후 업로드분부터 정상

---

# 보안 점검 2단계: users 문서의 개인 필드 분리 (2026-11-11)

문제: `users/{uid}`는 로그인한 누구나 읽을 수 있는데 `email`(네이버·애플 실제 이메일, 카카오 ID가 드러나는 가짜 이메일)과 `fcmToken`이 들어있음.
설계: 본인만 읽고 쓰는 `users/{uid}/private/account`로 이동.
호환성: 옛 앱은 계속 공개 문서에 `fcmToken`을 씀 → 새 앱은 private에 쓰고 공개 필드를 지움. 따라서 "공개 필드가 있다 = 옛 앱이 가장 최근에 쓴 값" → 함수는 공개 필드 우선, 없으면 private.

- [x] 규칙: `users/{uid}/private/{docId}` 본인만 읽기/쓰기 + 테스트
- [x] 클라이언트: 토큰 저장·갱신·로그아웃 삭제, 가입 시 email을 private에 (쓰는 곳 4곳을 헬퍼 하나로)
- [x] 함수: `getUserFcmData`가 공개 필드 → private 순으로 토큰 조회
- [x] 마이그레이션 스크립트 `scripts/migrate_private_fields.js` (기본 dry-run, `--apply`로 실행)
- [ ] 배포 순서: 규칙·함수 → 마이그레이션(사용자 확인) → 앱 출시
- [ ] 후속: 강제 업데이트(min_version) 이후 규칙에서 users 문서에 email/fcmToken 쓰기 금지

## 검토 (2026-11-11)
- 규칙 테스트 28개 통과 (private 문서: 본인 읽기·쓰기 OK, 남·비로그인 거부)
- 마이그레이션을 에뮬레이터에서 검증: dry-run은 변경 없음, --apply 후 공개 필드 삭제·private 이동, 공개 토큰이 오래된 private 토큰보다 우선, 재실행 시 대상 0명
- `flutter analyze` 109건으로 변경 전과 동일한 이슈 목록 (중간에 내가 남긴 unused import 2건을 diff로 잡아서 제거), `flutter test` 전체 통과, `node --check functions/index.js` 통과
- 탈퇴 시 private 문서는 onUserDeleted의 users 재귀 삭제에 포함돼 같이 지워짐

---

# 보안 점검 3단계: 카카오·네이버 로그인을 서버 검증(커스텀 토큰)으로 교체 (2026-11-11)

문제: 비밀번호 = sha256(소셜ID + 앱에 박힌 salt). salt는 디컴파일로 추출 가능 → 소셜 ID만 알면 남의 계정으로 로그인.
설계: 앱은 카카오/네이버 액세스 토큰만 서버(callable `socialLogin`)에 보냄 → 서버가 카카오/네이버 API로 토큰을 검증해 ID를 얻고 → Firebase 커스텀 토큰 발급.
- 카카오: `access_token_info`의 `app_id`가 우리 앱 ID와 같은지 확인 (다른 앱에서 받은 토큰 재사용 차단). 문서로 확인함
- 네이버: `nid/me`로 ID 조회. 토큰이 우리 앱에서 발급됐는지 검증하는 방법은 문서 확인 못 함 → 미검증 위험으로 남김
- 기존 계정 유지: 예전 가상 이메일(`kakao_<id>@nibpen.login`, 네이버는 실제 이메일 → `naver_<id>@...`)로 기존 uid를 찾아 그대로 씀. 없으면 새 uid `kakao:<id>`
  - 찾은 계정이 비밀번호 외 제공자(애플 등)를 가지고 있으면 매칭하지 않음 (이메일이 같아도 남의 계정 탈취 방지)

- [x] 함수 `socialLogin` + 단위 테스트(외부 API는 가짜로)
- [x] 앱: 로그인·탈퇴 전 재인증을 커스텀 토큰 방식으로
- [ ] 배포 시 필요: `KAKAO_APP_ID` 값, 함수 서비스 계정에 토큰 서명 권한(Service Account Token Creator)
- [ ] 후속(강제 업데이트 이후): 기존 계정의 비밀번호 제공자 해제 스크립트 실행 + 콘솔에서 이메일/비밀번호 로그인 끄기 → 여기서 구멍이 완전히 닫힘

## 검토 (2026-11-11)
- `socialLogin` 단위 테스트 12개 통과 (`cd functions && npm test`): 기존 uid 유지, 신규 uid, 다른 앱 토큰·위조 토큰 거부, 같은 이메일의 애플 계정 보호
- 에뮬레이터에서 실제 카카오·네이버 API에 무효 토큰을 보내 둘 다 UNAUTHENTICATED로 거부되는 것 확인
- 탈퇴 전 재인증: 다른 소셜 계정으로 재인증하면 삭제하지 않고 로그아웃 (엉뚱한 계정 삭제 방지)
- 앱에서 salt·비밀번호 해시 코드 제거, `app_secrets.dart`의 authSalt 삭제
- 마무리 스크립트 `scripts/rotate_legacy_social_passwords.js`: 에뮬레이터에서 옛 비밀번호 로그인 true → 실행 후 false, 이메일 유지, 애플·신규 계정 제외 확인
- 확인 못 한 것: 네이버 토큰이 우리 앱에서 발급됐는지 검증하는 방법(공식 문서 접근 불가). 실기기 로그인은 시뮬레이터 금지 원칙상 미실행 → TestFlight에서 확인 필요

# 보안 점검 4단계: 소소한 항목 (2026-11-11)
- [x] 카카오 액세스 토큰 로그 출력 제거
- [x] 가입 화면 `[필수] 만 14세 이상입니다` + `ageConfirmedAt` 기록
- [x] 개인정보처리방침: 만 14세 미만 가입 제한, 국외 이전 항목 (앱 화면·docs 둘 다)
- [ ] 개인정보처리방침: 보호책임자 성명·연락처 (사용자 정보 필요)
- [x] 탈퇴 시 리뷰·게시글 이미지, 문의, 제품 등록 요청 삭제 — 에뮬레이터 E2E 11개 항목 확인
- [x] 공개 users 문서에 이메일 쓰기 금지 규칙 (지우기만 허용) — 규칙 테스트 30개 통과
- [ ] Android 릴리스 서명 키 (debug 키 사용 중) — 사용자 확인 필요
- [ ] App Check 도입
- [ ] Functions 런타임: Node 22로 올림(2026-11-11). Node 22 폐기 2027-10-31 → 그 전에 firebase-tools 업데이트 후 Node 24로

## 화면 크기 대응 점검 (2026-11-12)
- [x] 글자 크기 최대 1.3배로 제한 (`lib/app.dart`)
- [x] 상단 바 흰색으로 변경 (`app_theme.dart` AppBarTheme)
- [x] 320~430 폭 · 글자 1.3배 · 키보드 · 긴 닉네임 기준 넘침 수정 (마이페이지 12, 아카이브·검색 9, 홈·리뷰·로그인 14, 커뮤니티·공통·탭바 11곳)
- [ ] 실기기 확인 필요: 잉크북 상세 3×3 노트 그리드 세 번째 줄이 잘리는지 (계산상 393×852에서 약 50px)
- [ ] 실기기 확인 필요: 잉크북 이름 변경 오버레이가 작은 화면에서 키보드에 겹치는지

### 검토
- `flutter analyze` 109건 → 109건 (새 이슈 없음), `flutter test` 전체 통과
- 기본 크기(375폭, 글자 1.0)에서는 모양이 그대로 유지되게 수정 (인기 만년필 목록만 높이 110→112)
