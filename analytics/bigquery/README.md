# 리뷰 작성 로그 — BigQuery 정제·마트·데이터 품질 레이어

리뷰 작성 퍼널 로그(`docs/analytics_spec.md`)가 **실제 사용자 행동과 서버 결과를 정확히 기록하는지** 매일 검증하는 SQL 모음.

## 구조

```
원천                         정제                      마트                              검증
GA4 events_* ──────────► stg_review_events ──► mart_review_write_sessions ──► checks/DQ-01~14
(앱 이벤트 로그)               │                   mart_review_funnel_daily            │
                               │                   mart_ingest_latency_daily           ▼
Firestore 확장 ─────────► stg_reviews ─────────────────────────────────────► dq_violations (위반 상세)
reviews_raw_changelog                                                                   │ jobs/dq_daily.sql (매일)
(서버의 정답)                                                                           ▼
                                                                                dq_check_results ─► rpt_dq_daily ─► Looker Studio
```

| 계층 | 객체 | 역할 |
|---|---|---|
| 정제 | `stg_review_events` | GA4의 중첩 구조(`event_params` 배열)를 컬럼으로 펼침. KST 날짜, `build_env` 부여. 이후 모든 쿼리는 원천 대신 이 뷰만 읽는다 |
| 정제 | `stg_reviews` | Firestore 변경 이력 → 리뷰 1개당 1행. 생성 시점 사진 수, 삭제 여부 |
| 마트 | `mart_review_write_sessions` | 작성 세션 1개당 1행. 단계별 최초 도달 시각, 이벤트 수 |
| 마트 | `mart_review_funnel_daily` | 일·환경·플랫폼·진입 경로별 퍼널 (새 리뷰만) |
| 마트 | `mart_ingest_latency_daily` | 수집 지연 p50·p95 |
| 검증 | `checks/DQ-*.sql` → `dq_violations` | 규칙 14개의 위반 상세 (규칙·날짜·환경·대상 ID·설명) |
| 검증 | `dq_rules` | 규칙 카탈로그. 각 check 파일의 머리 주석에서 자동 생성 |
| 검증 | `dq_check_results` | 일별·환경별·규칙별 위반 건수 누적 (위반 0건도 기록) |
| 리포트 | `rpt_dq_daily` | 결과 + 규칙 설명. 대시보드가 읽음 |

## 설계에서 신경 쓴 점

- **원천 의존을 한 곳에 모음**: GA4 스키마를 아는 건 `stg_review_events` 하나뿐. 파라미터가 바뀌어도 이 뷰만 고치면 된다.
- **삭제된 리뷰 오탐 방지**: Firestore 확장의 `raw_latest` 뷰는 삭제된 문서를 뺀다. 그대로 쓰면 "작성 후 삭제한 리뷰"의 성공 로그가 유령 성공(DQ-13)으로 잡히므로 `raw_changelog`에서 "존재한 적이 있는지"로 판단한다.
- **수정 이력 오탐 방지**: 사진 수 비교(DQ-07)는 최신 문서가 아니라 **생성 시점** 스냅샷과 비교한다. 등록 후 수정으로 사진 수가 바뀌어도 오탐이 나지 않는다.
- **늦게 도착하는 데이터**: GA4는 늦게 올라온 이벤트를 원래 날짜 테이블에 나중에 반영한다. 일일 점검은 최근 7일을 지우고 다시 계산하므로(delete → insert), 몇 번을 다시 돌려도 결과가 같다(멱등).
- **아직 도착 안 한 날짜 제외**: Firestore는 실시간, GA4는 다음 날 도착한다. 로그 유실 검사(DQ-12)는 GA4 테이블이 도착한 날짜까지만 본다. 안 그러면 매일 오늘 작성분이 전부 "유실"로 잡힌다.
- **0건도 기록**: 위반이 없는 규칙도 `violation_count = 0`으로 남겨, 대시보드에서 "점검했고 문제없음"과 "점검이 안 돌았음"을 구분한다.

## 검증 쿼리의 테스트

```bash
python3 analytics/bigquery/test/run_tests.py
```

GA4 export·Firestore changelog와 같은 스키마의 가짜 데이터를 `review_dq_test` 데이터 세트에 올린다.
- **정상 시나리오**: 명세의 S1·S2·S3·S4·S9, 업로드 실패 후 이탈, 작성 후 삭제, 디버그 빌드, 로깅 이전 문서, 백필 문서 → 어떤 규칙에도 걸리면 안 됨
- **심은 위반**: 규칙마다 1건씩 → 해당 규칙에만 정확히 1건 걸려야 함

확인하는 것: 규칙별 오탐·미탐 0, 일일 점검 잡을 두 번 돌려도 결과 동일.

테스트로 실제로 잡은 문제: DQ-11이 한 세션의 여러 이벤트를 각각 세서 위반 1건이 2건으로 집계됨 → 위반 건수를 "대상 수"(`COUNT(DISTINCT entity_id)`)로 정의.

## 배포·운영

```bash
# 사전 조건: bq CLI 로그인, GA4 export 데이터 세트(analytics_*)와 Firestore 확장 테이블 존재
python3 analytics/bigquery/deploy.py --env prod                    # 뷰·규칙·결과 테이블 배포 (재실행 안전)
python3 analytics/bigquery/deploy.py --env prod --run 2026-10-13   # 일일 점검 1회 수동 실행
python3 analytics/bigquery/deploy.py --env prod --schedule         # 매일 KST 12:00 예약 쿼리 등록
```

- 설정: `config.json` (`events_table: auto`면 `analytics_<속성ID>` 데이터 세트를 자동으로 찾음)
- 규칙 추가: `checks/DQ-15_xxx.sql` 파일을 머리 주석(`rule`/`dimension`/`severity`/`description`)과 함께 추가하고 테스트에 심은 위반 1건을 추가하면 끝. `dq_rules`·`dq_violations`는 배포 시 자동 갱신
- 출력 컬럼 규약: 모든 check는 `rule_id, check_date, build_env, entity_id, detail`을 반환
