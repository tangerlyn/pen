-- 검증 규칙 실행 결과 누적 테이블 (대시보드의 품질 모니터링 페이지가 읽음)
-- 이미 있으면 그대로 둔다: 결과 이력은 재배포해도 지워지면 안 된다
CREATE TABLE IF NOT EXISTS `{{dataset}}.dq_check_results` (
  check_date DATE NOT NULL,
  build_env STRING NOT NULL,
  rule_id STRING NOT NULL,
  dimension STRING,
  severity STRING,
  violation_count INT64 NOT NULL,
  sample_entity_ids ARRAY<STRING>,
  checked_at TIMESTAMP NOT NULL
)
PARTITION BY check_date
OPTIONS (description = '리뷰 작성 로그 데이터 품질 규칙(DQ-01~14) 일별 실행 결과. jobs/dq_daily.sql이 적재');
