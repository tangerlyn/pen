-- rule: DQ-09
-- dimension: 정확성
-- severity: error
-- description: 새 리뷰에서 마지막 시도 전까지의 사진 추가·삭제 합계가 마지막 시도의 사진 수와 다름
-- 마지막 시도 이후의 사진 변경은 비교 대상에서 뺀다 (실패 후 사진을 바꾸고 이탈하는 경우의 오탐 방지)
WITH last_attempt AS (
  SELECT
    write_session_id,
    ARRAY_AGG(STRUCT(photo_count, event_ts, event_date_kst, build_env) ORDER BY attempt_no DESC LIMIT 1)[OFFSET(0)] AS a
  FROM `{{dataset}}.stg_review_events`
  WHERE event_name = 'review_submit_attempt'
    AND mode = 'new'
  GROUP BY write_session_id
),
photo_net AS (
  SELECT
    e.write_session_id,
    SUM(IF(e.event_name = 'review_photo_add', e.added_count, 0))
      - COUNTIF(e.event_name = 'review_photo_remove') AS net
  FROM `{{dataset}}.stg_review_events` AS e
  JOIN last_attempt AS l USING (write_session_id)
  WHERE e.event_ts <= l.a.event_ts
  GROUP BY e.write_session_id
)
SELECT
  'DQ-09' AS rule_id,
  l.a.event_date_kst AS check_date,
  l.a.build_env,
  l.write_session_id AS entity_id,
  FORMAT('추가-삭제=%d, attempt.photo_count=%d', IFNULL(p.net, 0), l.a.photo_count) AS detail
FROM last_attempt AS l
LEFT JOIN photo_net AS p USING (write_session_id)
WHERE IFNULL(p.net, 0) != l.a.photo_count
