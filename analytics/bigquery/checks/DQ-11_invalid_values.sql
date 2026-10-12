-- rule: DQ-11
-- dimension: 유효성
-- severity: error
-- description: 필수 파라미터 누락 또는 명세에 없는 값 (entry_point=unknown이면 명세에 없는 진입점이 생긴 것)
-- allowed가 빈 배열이면 "값이 있기만 하면 됨"
SELECT DISTINCT
  'DQ-11' AS rule_id,
  e.event_date_kst AS check_date,
  e.build_env,
  IFNULL(e.write_session_id, CONCAT('no_session:', e.user_pseudo_id)) AS entity_id,
  FORMAT('%s.%s=%s', e.event_name, c.field, IFNULL(c.value, 'NULL')) AS detail
FROM `{{dataset}}.stg_review_events` AS e,
UNNEST([
  STRUCT('write_session_id' AS field, e.write_session_id AS value, CAST([] AS ARRAY<STRING>) AS allowed, TRUE AS applies),
  ('mode', e.mode, ['new', 'edit'], TRUE),
  ('entry_point', e.entry_point, ['home', 'review_feed', 'product_detail', 'review_detail'], TRUE),
  ('prefilled_product_type', e.prefilled_product_type, ['ink', 'pen', 'none'], e.event_name = 'review_write_view'),
  ('first_input', e.first_input, ['title', 'body', 'tag', 'photo'], e.event_name = 'review_write_start'),
  ('source', e.photo_source, ['camera', 'gallery'], e.event_name = 'review_photo_add'),
  ('reason', e.blocked_reason, ['no_photo'], e.event_name = 'review_submit_blocked'),
  ('error_stage', e.error_stage, ['image_upload', 'auth', 'firestore_write'], e.event_name = 'review_submit_fail'),
  ('review_id', e.review_id, CAST([] AS ARRAY<STRING>), e.event_name = 'review_submit_success'),
  ('last_stage', e.last_stage, ['view', 'started', 'photo_added', 'attempted'], e.event_name = 'review_write_exit')
]) AS c
WHERE c.applies
  AND (c.value IS NULL OR (ARRAY_LENGTH(c.allowed) > 0 AND c.value NOT IN UNNEST(c.allowed)))
