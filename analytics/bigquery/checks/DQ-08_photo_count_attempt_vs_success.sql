-- rule: DQ-08
-- dimension: 정확성
-- severity: error
-- description: 등록 성공의 사진 수가 같은 시도(attempt_no)의 사진 수와 다름
SELECT
  'DQ-08' AS rule_id,
  s.event_date_kst AS check_date,
  s.build_env,
  s.write_session_id AS entity_id,
  FORMAT('attempt_no=%d: attempt=%d, success=%d', s.attempt_no, a.photo_count, s.photo_count) AS detail
FROM `{{dataset}}.stg_review_events` AS s
JOIN `{{dataset}}.stg_review_events` AS a
  ON a.write_session_id = s.write_session_id
 AND a.attempt_no = s.attempt_no
 AND a.event_name = 'review_submit_attempt'
WHERE s.event_name = 'review_submit_success'
  AND s.photo_count != a.photo_count
