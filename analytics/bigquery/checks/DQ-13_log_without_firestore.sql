-- rule: DQ-13
-- dimension: 정합성
-- severity: error
-- description: 등록 성공 로그가 있는데 Firestore에 그 리뷰가 존재한 적이 없음 (유령 성공)
-- 작성 후 삭제된 리뷰는 changelog에 이력이 남아 있으므로 위반이 아니다
SELECT
  'DQ-13' AS rule_id,
  e.event_date_kst AS check_date,
  e.build_env,
  e.review_id AS entity_id,
  CONCAT('session=', e.write_session_id) AS detail
FROM `{{dataset}}.stg_review_events` AS e
LEFT JOIN `{{dataset}}.stg_reviews` AS r USING (review_id)
WHERE e.event_name = 'review_submit_success'
  AND r.review_id IS NULL
