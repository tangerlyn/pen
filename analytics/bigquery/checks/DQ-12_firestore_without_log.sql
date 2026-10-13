-- rule: DQ-12
-- dimension: 정합성
-- severity: error
-- description: Firestore에 생성된 리뷰인데 등록 성공 로그가 없음 (로그 유실)
-- env_scope: none
-- 로깅 배포 이전 문서와, 아직 GA4 일별 테이블이 도착하지 않은 날짜는 제외한다
-- 확장 설치 전에 만들어져 백필(IMPORT)된 문서도 로깅 배포 이후 생성분이면 검사한다.
-- 설치 시점은 로그 수집과 무관하므로, 기준은 문서의 createdAt 하나로 둔다.
WITH loaded AS (
  SELECT MAX(event_date_kst) AS last_loaded_date
  FROM `{{dataset}}.stg_review_events`
)
SELECT
  'DQ-12' AS rule_id,
  DATE(r.created_at, 'Asia/Seoul') AS check_date,
  'n/a' AS build_env,
  r.review_id AS entity_id,
  FORMAT('created_at=%t', r.created_at) AS detail
FROM `{{dataset}}.stg_reviews` AS r, loaded
WHERE r.created_at >= TIMESTAMP('{{logging_start}}')
  AND DATE(r.created_at, 'Asia/Seoul') <= loaded.last_loaded_date
  AND NOT EXISTS (
    SELECT 1
    FROM `{{dataset}}.stg_review_events` AS e
    WHERE e.event_name = 'review_submit_success'
      AND e.review_id = r.review_id
  )
