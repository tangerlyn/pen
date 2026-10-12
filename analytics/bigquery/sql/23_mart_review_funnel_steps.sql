-- 퍼널 차트용 세로형. mart_review_funnel_daily의 단계 컬럼을 행으로 세운다.
-- 대시보드 막대 차트는 측정기준 1개(단계) × 측정항목 1개(세션 수)여야 퍼널 모양으로 그릴 수 있다.
-- step_order로 정렬한다. entered_sessions(같은 그룹의 진입 세션 수)로 단계별 도달률을 계산할 수 있다.
CREATE OR REPLACE VIEW `{{dataset}}.mart_review_funnel_steps` AS
SELECT
  f.session_date_kst,
  f.build_env,
  f.platform,
  f.entry_point,
  step.step_order,
  step.step_name,
  step.sessions,
  f.sessions AS entered_sessions
FROM `{{dataset}}.mart_review_funnel_daily` AS f,
UNNEST([
  STRUCT(1 AS step_order, '1. 진입' AS step_name, f.sessions AS sessions),
  STRUCT(2, '2. 작성 시작', f.started),
  STRUCT(3, '3. 사진 첨부', f.photo_added),
  STRUCT(4, '4. 등록 시도', f.attempted),
  STRUCT(5, '5. 등록 성공', f.succeeded)
]) AS step
