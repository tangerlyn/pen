-- 대시보드(Looker Studio) 품질 모니터링 페이지용. 결과에 규칙 설명을 붙여 블렌딩 없이 바로 쓰게 한다.
CREATE OR REPLACE VIEW `{{dataset}}.rpt_dq_daily` AS
SELECT
  c.check_date,
  c.build_env,
  c.rule_id,
  c.dimension,
  c.severity,
  r.description,
  c.violation_count,
  c.violation_count > 0 AS has_violation,
  ARRAY_TO_STRING(c.sample_entity_ids, ', ') AS sample_entity_ids,
  c.checked_at
FROM `{{dataset}}.dq_check_results` AS c
LEFT JOIN `{{dataset}}.dq_rules` AS r USING (rule_id)
