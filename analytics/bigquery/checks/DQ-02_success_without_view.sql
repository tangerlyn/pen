-- rule: DQ-02
-- dimension: 완전성
-- severity: error
-- description: 등록 성공(success)이 있는데 같은 세션에 화면 진입(view)이 없음
SELECT
  'DQ-02' AS rule_id,
  session_date_kst AS check_date,
  build_env,
  write_session_id AS entity_id,
  CONCAT('review_id=', IFNULL(review_id, 'NULL')) AS detail
FROM `{{dataset}}.mart_review_write_sessions`
WHERE success_count > 0
  AND view_count = 0
