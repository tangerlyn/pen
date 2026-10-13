-- 매일 실행되는 데이터 품질 점검 (BigQuery 예약 쿼리). @run_date는 예약 쿼리가 넣어주는 실행일.
--
-- 최근 7일을 매번 다시 계산하는 이유:
--   GA4는 기기에서 늦게 올라온 이벤트(최대 72시간)를 원래 날짜 테이블에 나중에 반영한다.
--   그래서 어제 결과도 오늘 바뀔 수 있다. 해당 기간을 지우고 다시 넣어서(delete → insert)
--   몇 번을 다시 돌려도 결과가 같게(멱등) 만든다.
DECLARE start_date DATE DEFAULT DATE_SUB(@run_date, INTERVAL 7 DAY);

BEGIN TRANSACTION;

DELETE FROM `{{dataset}}.dq_check_results`
WHERE check_date BETWEEN start_date AND @run_date;

INSERT INTO `{{dataset}}.dq_check_results`
  (check_date, build_env, rule_id, dimension, severity, violation_count, sample_entity_ids, checked_at)
WITH scope AS (
  -- 위반이 0건인 규칙도 "0"으로 남겨야 대시보드에서 "점검했고 문제없음"과 "점검 안 됨"이 구분된다.
  -- 그래서 0은 그 규칙이 실제로 검사한 범위에만 채운다.
  --   by_env 규칙: 작성 세션이 있는 날짜 × 빌드 환경
  --   none 규칙(Firestore만 보는 DQ-12): 세션 또는 리뷰 생성이 있는 날짜 × 'n/a'.
  --     단 로깅 배포 이전 문서와 GA4 테이블이 아직 안 온 날짜는 DQ-12가 검사하지 않으므로 제외한다
  SELECT DISTINCT session_date_kst AS check_date, build_env, 'by_env' AS env_scope
  FROM `{{dataset}}.mart_review_write_sessions`
  WHERE session_date_kst BETWEEN start_date AND @run_date
  UNION DISTINCT
  SELECT DISTINCT session_date_kst, 'n/a', 'none'
  FROM `{{dataset}}.mart_review_write_sessions`
  WHERE session_date_kst BETWEEN start_date AND @run_date
  UNION DISTINCT
  SELECT DISTINCT DATE(created_at, 'Asia/Seoul'), 'n/a', 'none'
  FROM `{{dataset}}.stg_reviews`
  WHERE DATE(created_at, 'Asia/Seoul') BETWEEN start_date AND @run_date
    AND created_at >= TIMESTAMP('{{logging_start}}')
    AND DATE(created_at, 'Asia/Seoul') <= (SELECT MAX(event_date_kst) FROM `{{dataset}}.stg_review_events`)
  UNION DISTINCT
  SELECT DISTINCT v.check_date, v.build_env, r.env_scope
  FROM `{{dataset}}.dq_violations` AS v
  JOIN `{{dataset}}.dq_rules` AS r USING (rule_id)
  WHERE v.check_date BETWEEN start_date AND @run_date
)
SELECT
  s.check_date,
  s.build_env,
  r.rule_id,
  r.dimension,
  r.severity,
  -- 위반 건수 = 위반한 대상(세션·리뷰) 수. 한 세션이 여러 이벤트에서 같은 규칙을 어겨도 1건
  COUNT(DISTINCT v.entity_id) AS violation_count,
  ARRAY_AGG(DISTINCT v.entity_id IGNORE NULLS ORDER BY v.entity_id LIMIT 5) AS sample_entity_ids,
  CURRENT_TIMESTAMP() AS checked_at
FROM scope AS s
JOIN `{{dataset}}.dq_rules` AS r
  ON r.env_scope = s.env_scope
LEFT JOIN `{{dataset}}.dq_violations` AS v
  ON v.check_date = s.check_date
 AND v.build_env = s.build_env
 AND v.rule_id = r.rule_id
GROUP BY s.check_date, s.build_env, r.rule_id, r.dimension, r.severity;

COMMIT TRANSACTION;
