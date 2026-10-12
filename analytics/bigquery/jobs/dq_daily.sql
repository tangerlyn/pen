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
  -- 위반이 0건인 규칙도 "0"으로 남겨야 대시보드에서 "점검했고 문제없음"과 "점검 안 됨"이 구분된다
  SELECT DISTINCT session_date_kst AS check_date, build_env
  FROM `{{dataset}}.mart_review_write_sessions`
  WHERE session_date_kst BETWEEN start_date AND @run_date
  UNION DISTINCT
  SELECT DISTINCT check_date, build_env
  FROM `{{dataset}}.dq_violations`
  WHERE check_date BETWEEN start_date AND @run_date
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
CROSS JOIN `{{dataset}}.dq_rules` AS r
LEFT JOIN `{{dataset}}.dq_violations` AS v
  ON v.check_date = s.check_date
 AND v.build_env = s.build_env
 AND v.rule_id = r.rule_id
GROUP BY s.check_date, s.build_env, r.rule_id, r.dimension, r.severity;

COMMIT TRANSACTION;
