# 대시보드 — 리뷰 작성 로그 품질 (Looker Studio)

## 개요

보고서: [https://datastudio.google.com/s/jM2rDh6cP7o](https://datastudio.google.com/s/jM2rDh6cP7o) (현재 `review_dq_test` 연결 — 실데이터 배포 후 `review_dq`로 교체)

`analytics/bigquery`가 만든 결과를 보는 Looker Studio 대시보드 구성안. **누가 무엇을 결정할 때 보는지**를 기준으로 페이지를 나눈다.

| 페이지 | 보는 사람 | 답하는 질문 | 데이터 소스 |
|---|---|---|---|
| 1. 로그 품질 모니터링 (메인) | 로그 담당자 | 어제 로그를 믿어도 되나? 어떤 규칙이 깨졌고 어떤 세션인가? | `rpt_dq_daily`, `dq_violations` |
| 2. 작성 퍼널 | PO | 어느 단계에서 이탈하나? 진입 경로별로 다른가? | `mart_review_funnel_steps`, `mart_review_funnel_daily` |
| 3. 수집 지연 | 로그 담당자 | 어제 숫자가 확정된 숫자인가, 아직 더 들어올 데이터가 있나? | `mart_ingest_latency_daily` |

> 퍼널 페이지 상단에 **"출시 전 QA·테스터 데이터, 표본 소수"** 텍스트를 반드시 둔다. 수치 해석이 아니라 퍼널 구조 확인용이다.

---

## 만드는 법

1. 데이터 소스 4개를 연결한다. (Looker Studio Linking API는 템플릿 보고서 없이 데이터 소스를 여러 개 붙이면 `ds0은(는) 유효한 데이터 소스 별칭이 아닙니다` 오류가 나서 직접 추가한다)
   - **새 보고서 작성 → BigQuery → 내 프로젝트 → nibpen → `review_dq`(실데이터) 또는 `review_dq_test`(레이아웃 연습용) → `rpt_dq_daily` → 추가**
   - 상단 **데이터 추가**로 같은 경로에서 `dq_violations`, `mart_review_funnel_daily`, `mart_ingest_latency_daily` 추가
   - 테스트로 먼저 만들었다면 나중에 **리소스 → 데이터 소스 관리 → 데이터 소스 수정 → 테이블 다시 선택**으로 `review_dq`로 교체한다.
2. 아래 페이지별 구성대로 차트를 배치한다.
3. 공유 → **링크가 있는 모든 사용자 보기 권한**으로 열어 이력서에 링크를 건다. (BigQuery 데이터 소스의 사용자 인증 정보는 "소유자"로 둬야 보는 사람이 BigQuery 권한 없이 볼 수 있다)

---

## 페이지 1. 로그 품질 모니터링

**상단 필터**: 기간(기본 최근 14일), `build_env`(기본 `prod`, 지금은 `testflight`)

| 위치 | 차트 | 설정 |
|---|---|---|
| 1행 | 스코어카드 3개 | ① `severity = error` 위반 합계 (어제) — 0이 아니면 빨간색 ② `severity = monitor` 위반 합계 ③ 점검된 규칙 수 (`COUNT_DISTINCT(rule_id)`) |
| 2행 | 표 (규칙 × 날짜 피벗) | 행 `rule_id`·`dimension`·`description`, 열 `check_date`, 값 `SUM(violation_count)`, 조건부 서식 >0 빨강 / 0 초록. 한눈에 "어느 날 어느 규칙이 깨졌나" |
| 3행 왼쪽 | 시계열 | `check_date` × `SUM(violation_count)`, 분류 `dimension`. 품질 차원별 추이 |
| 3행 오른쪽 | 표 | `dq_violations`: `check_date`, `rule_id`, `entity_id`, `detail`. 2행 표와 **상호작용 필터**로 연결해, 규칙을 누르면 해당 세션·리뷰 목록이 나오게 |

## 페이지 2. 작성 퍼널

**상단 텍스트**: "출시 전 QA·테스터 데이터 (표본 소수). 퍼널 구조 검증용이며 전환율 해석용이 아님"
**상단 필터**: 기간, `build_env`, `platform`, `entry_point`

| 위치 | 차트 | 설정 |
|---|---|---|
| 1행 | 막대 (가로) | `mart_review_funnel_steps`: 측정기준 `step_name`, 측정항목 `SUM(sessions)`, `step_name` 오름차순 정렬. 퍼널 모양 |
| 2행 | 표 | 차원 `entry_point`, 측정항목 세션·성공 + 계산 필드 `등록률 = SUM(succeeded)/SUM(sessions)`, `사진 필수에 막힌 비율 = SUM(blocked_sessions)/SUM(attempted)` |
| 3행 | 시계열 | `session_date_kst` × 등록률 |

## 페이지 3. 수집 지연

| 위치 | 차트 | 설정 |
|---|---|---|
| 1행 | 시계열 | `event_date_kst` × `p50_delay_sec`, `p95_delay_sec`, 분류 `platform` |
| 2행 | 표 | 날짜·플랫폼별 `events`, `max_delay_sec` |

**읽는 법**: p95가 몇 시간 단위로 커지면 어제 퍼널 숫자는 아직 확정이 아니다. 일일 점검이 최근 7일을 다시 계산하는 이유.
