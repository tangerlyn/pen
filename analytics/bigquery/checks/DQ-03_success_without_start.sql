-- rule: DQ-03
-- dimension: 완전성
-- severity: error
-- description: 새 리뷰 등록 성공인데 같은 세션에 작성 시작(start)이 없음
SELECT
  'DQ-03' AS rule_id,
  session_date_kst AS check_date,
  build_env,
  write_session_id AS entity_id,
  CONCAT('review_id=', IFNULL(review_id, 'NULL')) AS detail
FROM `{{dataset}}.mart_review_write_sessions`
WHERE mode = 'new'
  AND success_count > 0
  AND start_count = 0
