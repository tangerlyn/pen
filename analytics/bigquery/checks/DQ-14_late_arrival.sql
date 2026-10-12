-- rule: DQ-14
-- dimension: 적시성
-- severity: monitor
-- description: 이벤트 발생 후 24시간 넘게 지나서 수집됨 (일별 집계에 늦게 반영될 수 있음, 분포는 mart_ingest_latency_daily)
SELECT DISTINCT
  'DQ-14' AS rule_id,
  event_date_kst AS check_date,
  build_env,
  write_session_id AS entity_id,
  FORMAT('%s 지연 %.1f시간', event_name, server_offset_us / 3.6e9) AS detail
FROM `{{dataset}}.stg_review_events`
WHERE server_offset_us > 24 * 3600 * 1000000
