-- 작성 세션(write_session_id) 1개당 1행. 퍼널 분석과 세션 단위 검증 규칙의 기준 테이블.
CREATE OR REPLACE VIEW `{{dataset}}.mart_review_write_sessions` AS
SELECT
  write_session_id,
  DATE(MIN(event_ts), 'Asia/Seoul') AS session_date_kst,
  -- 공통 파라미터는 세션 안에서 같아야 하므로 대표값 하나를 쓴다
  ANY_VALUE(mode) AS mode,
  ANY_VALUE(entry_point) AS entry_point,
  ANY_VALUE(build_env) AS build_env,
  ANY_VALUE(platform) AS platform,
  ANY_VALUE(app_version) AS app_version,
  ANY_VALUE(user_pseudo_id) AS user_pseudo_id,

  -- 단계별 최초 도달 시각
  MIN(IF(event_name = 'review_write_view', event_ts, NULL)) AS viewed_at,
  MIN(IF(event_name = 'review_write_start', event_ts, NULL)) AS started_at,
  MIN(IF(event_name = 'review_photo_add', event_ts, NULL)) AS first_photo_at,
  MIN(IF(event_name = 'review_submit_attempt', event_ts, NULL)) AS first_attempt_at,
  MIN(IF(event_name = 'review_submit_success', event_ts, NULL)) AS succeeded_at,
  MIN(IF(event_name = 'review_write_exit', event_ts, NULL)) AS exited_at,

  -- 이벤트 수 (불변 조건 검증용)
  COUNTIF(event_name = 'review_write_view') AS view_count,
  COUNTIF(event_name = 'review_write_start') AS start_count,
  COUNTIF(event_name = 'review_photo_add') AS photo_add_count,
  COUNTIF(event_name = 'review_photo_remove') AS photo_remove_count,
  COUNTIF(event_name = 'review_submit_attempt') AS attempt_count,
  COUNTIF(event_name = 'review_submit_blocked') AS blocked_count,
  COUNTIF(event_name = 'review_submit_fail') AS fail_count,
  COUNTIF(event_name = 'review_submit_success') AS success_count,
  COUNTIF(event_name = 'review_write_exit') AS exit_count,

  MAX(IF(event_name = 'review_submit_success', review_id, NULL)) AS review_id,
  MAX(IF(event_name = 'review_write_exit', last_stage, NULL)) AS exit_stage,
  MAX(IF(event_name = 'review_write_start', first_input, NULL)) AS first_input
FROM `{{dataset}}.stg_review_events`
WHERE write_session_id IS NOT NULL
GROUP BY write_session_id
