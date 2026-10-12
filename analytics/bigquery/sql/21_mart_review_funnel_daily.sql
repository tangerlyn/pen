-- 대시보드용 일별 작성 퍼널. 퍼널은 "순서"가 아니라 "세션 안에서 도달했는지"로 센다 (명세 용어 정의).
-- 수정 모드는 이미 작성한 리뷰를 고치는 흐름이라 퍼널에서 제외한다.
CREATE OR REPLACE VIEW `{{dataset}}.mart_review_funnel_daily` AS
SELECT
  session_date_kst,
  build_env,
  platform,
  entry_point,
  COUNT(*) AS sessions,
  COUNTIF(start_count > 0) AS started,
  COUNTIF(photo_add_count > 0) AS photo_added,
  COUNTIF(attempt_count > 0) AS attempted,
  COUNTIF(success_count > 0) AS succeeded,
  COUNTIF(blocked_count > 0) AS blocked_sessions,
  COUNTIF(fail_count > 0) AS failed_sessions,
  COUNTIF(exit_count > 0) AS exited
FROM `{{dataset}}.mart_review_write_sessions`
WHERE mode = 'new'
GROUP BY session_date_kst, build_env, platform, entry_point
