-- rule: DQ-07
-- dimension: 정확성
-- severity: error
-- description: 새 리뷰 등록 성공 로그의 사진 수가 Firestore에 저장된 사진 수(등록 당시)와 다름
SELECT
  'DQ-07' AS rule_id,
  e.event_date_kst AS check_date,
  e.build_env,
  e.review_id AS entity_id,
  FORMAT('log=%d, firestore=%d', e.photo_count, r.photo_count_at_create) AS detail
FROM `{{dataset}}.stg_review_events` AS e
JOIN `{{dataset}}.stg_reviews` AS r USING (review_id)
WHERE e.event_name = 'review_submit_success'
  AND e.mode = 'new'
  AND e.photo_count != r.photo_count_at_create
