-- rule: DQ-05
-- dimension: 일관성
-- severity: error
-- description: 한 세션에 등록 성공(success)과 이탈(exit)이 함께 기록됨
SELECT
  'DQ-05' AS rule_id,
  session_date_kst AS check_date,
  build_env,
  write_session_id AS entity_id,
  CONCAT('exit_stage=', IFNULL(exit_stage, 'NULL')) AS detail
FROM `{{dataset}}.mart_review_write_sessions`
WHERE success_count > 0
  AND exit_count > 0
