-- rule: DQ-06
-- dimension: 일관성
-- severity: error
-- description: 이벤트 순서가 뒤집힘 (진입보다 이른 시작·시도·이탈, 시도보다 이른 성공)
-- 같은 기기 시계로 찍힌 시각끼리만 비교하므로 기기 시계가 틀려도 순서 비교는 유효하다
SELECT
  'DQ-06' AS rule_id,
  session_date_kst AS check_date,
  build_env,
  write_session_id AS entity_id,
  ARRAY_TO_STRING([
    IF(started_at < viewed_at, 'start<view', NULL),
    IF(first_attempt_at < viewed_at, 'attempt<view', NULL),
    IF(exited_at < viewed_at, 'exit<view', NULL),
    IF(succeeded_at < first_attempt_at, 'success<attempt', NULL)
  ], ', ') AS detail
FROM `{{dataset}}.mart_review_write_sessions`
WHERE started_at < viewed_at
   OR first_attempt_at < viewed_at
   OR exited_at < viewed_at
   OR succeeded_at < first_attempt_at
