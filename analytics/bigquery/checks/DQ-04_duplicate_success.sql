-- rule: DQ-04
-- dimension: 유일성
-- severity: error
-- description: 한 리뷰(review_id)에 새 리뷰 등록 성공이 2번 이상 기록됨 (수정 모드 성공은 제외)
SELECT
  'DQ-04' AS rule_id,
  MIN(event_date_kst) AS check_date,
  ANY_VALUE(build_env) AS build_env,
  review_id AS entity_id,
  FORMAT('success %d회, 세션 %d개', COUNT(*), COUNT(DISTINCT write_session_id)) AS detail
FROM `{{dataset}}.stg_review_events`
WHERE event_name = 'review_submit_success'
  AND mode = 'new'
  AND review_id IS NOT NULL
GROUP BY review_id
HAVING COUNT(*) > 1
