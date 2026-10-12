-- rule: DQ-10
-- dimension: 완전성
-- severity: monitor
-- description: 등록 시도(attempt) 뒤에 blocked·fail·success 중 아무 결과도 없음 (강제 종료 등으로 0이 목표는 아님, 비율 추적)
SELECT
  'DQ-10' AS rule_id,
  a.event_date_kst AS check_date,
  a.build_env,
  FORMAT('%s#%d', a.write_session_id, a.attempt_no) AS entity_id,
  FORMAT('platform=%s, app_version=%s', IFNULL(a.platform, 'NULL'), IFNULL(a.app_version, 'NULL')) AS detail
FROM `{{dataset}}.stg_review_events` AS a
WHERE a.event_name = 'review_submit_attempt'
  AND NOT EXISTS (
    SELECT 1
    FROM `{{dataset}}.stg_review_events` AS o
    WHERE o.write_session_id = a.write_session_id
      AND o.attempt_no = a.attempt_no
      AND o.event_name IN ('review_submit_blocked', 'review_submit_fail', 'review_submit_success')
  )
