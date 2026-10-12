-- 원천: GA4 BigQuery export (events_YYYYMMDD)
-- 리뷰 작성 퍼널 이벤트만 골라 파라미터를 컬럼으로 펼친다. 이후 모든 마트·검증은 이 뷰만 읽는다.
-- 이벤트·파라미터 정의: docs/analytics_spec.md
CREATE OR REPLACE VIEW `{{dataset}}.stg_review_events` AS
SELECT
  TIMESTAMP_MICROS(e.event_timestamp) AS event_ts,
  -- GA4 속성 시간대(대한민국)와 맞춰 KST 날짜로 집계한다
  DATE(TIMESTAMP_MICROS(e.event_timestamp), 'Asia/Seoul') AS event_date_kst,
  e.event_name,
  e.user_pseudo_id,
  e.platform,
  e.app_info.version AS app_version,
  -- 기기에서 이벤트가 발생한 시각과 서버가 수집한 시각의 차이 (적시성 지표)
  e.event_server_timestamp_offset AS server_offset_us,
  COALESCE(
    (SELECT value.string_value FROM UNNEST(e.user_properties) WHERE key = 'build_env'),
    'unset'
  ) AS build_env,

  -- 공통 파라미터
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'write_session_id') AS write_session_id,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'mode') AS mode,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'entry_point') AS entry_point,

  -- 이벤트별 문자열 파라미터
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'prefilled_product_type') AS prefilled_product_type,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'first_input') AS first_input,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'source') AS photo_source,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'reason') AS blocked_reason,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'error_stage') AS error_stage,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'error_type') AS error_type,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'review_id') AS review_id,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'last_stage') AS last_stage,

  -- 이벤트별 정수 파라미터 (SDK가 double로 보내는 경우까지 흡수)
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'attempt_no') AS attempt_no,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'photo_count') AS photo_count,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'added_count') AS added_count,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'photo_count_after') AS photo_count_after,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'title_len') AS title_len,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'body_len') AS body_len,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'ink_tag_count') AS ink_tag_count,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'pen_tag_count') AS pen_tag_count,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'elapsed_ms') AS elapsed_ms,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'since_view_ms') AS since_view_ms,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64)) FROM UNNEST(e.event_params) WHERE key = 'had_content') AS had_content
FROM `{{events_table}}` AS e
WHERE STARTS_WITH(e.event_name, 'review_')
  -- 스트리밍 내보내기를 켜면 생기는 events_intraday_* 테이블이 와일드카드에 섞이지 않게 막는다
  AND NOT STARTS_WITH(_TABLE_SUFFIX, 'intraday')
