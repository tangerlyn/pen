-- rule: DQ-01
-- dimension: 유일성
-- severity: error
-- description: 한 작성 세션에 화면 진입(view)이 2번 이상 기록됨
SELECT
  'DQ-01' AS rule_id,
  session_date_kst AS check_date,
  build_env,
  write_session_id AS entity_id,
  FORMAT('view %d회', view_count) AS detail
FROM `{{dataset}}.mart_review_write_sessions`
WHERE view_count > 1
