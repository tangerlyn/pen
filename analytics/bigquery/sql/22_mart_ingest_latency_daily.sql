-- 적시성: 이벤트 발생부터 서버 수집까지 걸린 시간 분포 (DQ-14와 함께 대시보드에 표시)
CREATE OR REPLACE VIEW `{{dataset}}.mart_ingest_latency_daily` AS
SELECT
  event_date_kst,
  build_env,
  platform,
  COUNT(*) AS events,
  APPROX_QUANTILES(server_offset_us / 1e6, 100)[OFFSET(50)] AS p50_delay_sec,
  APPROX_QUANTILES(server_offset_us / 1e6, 100)[OFFSET(95)] AS p95_delay_sec,
  MAX(server_offset_us) / 1e6 AS max_delay_sec
FROM `{{dataset}}.stg_review_events`
WHERE server_offset_us IS NOT NULL
GROUP BY event_date_kst, build_env, platform
