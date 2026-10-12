-- 원천: Firestore → BigQuery 확장의 reviews_raw_changelog (문서 변경 이력)
-- 리뷰 문서 1개당 1행. 서버 쪽 정답(ground truth)으로 쓴다.
--
-- raw_latest 뷰 대신 changelog를 직접 읽는 이유:
--   raw_latest는 삭제된 문서를 빼버린다. 그러면 "작성 후 삭제된 리뷰"의 성공 로그가
--   DQ-13(유령 성공)으로 잘못 잡힌다. 그래서 "한 번이라도 존재했는지"를 changelog로 판단한다.
CREATE OR REPLACE VIEW `{{dataset}}.stg_reviews` AS
WITH per_review AS (
  SELECT
    document_id AS review_id,
    MIN(timestamp) AS first_seen_at,
    ARRAY_AGG(operation ORDER BY timestamp DESC LIMIT 1)[OFFSET(0)] AS last_operation,
    -- CREATE가 있어야 확장 설치 이후에 생성된 문서. IMPORT만 있으면 설치 전부터 있던 문서(백필)
    COUNTIF(operation = 'CREATE') > 0 AS created_after_export,
    -- 생성 시점 스냅샷. 이후 수정(UPDATE)으로 사진 수가 바뀌어도 등록 당시 값과 비교하기 위함
    ARRAY_AGG(IF(operation IN ('CREATE', 'IMPORT'), data, NULL) IGNORE NULLS ORDER BY timestamp LIMIT 1)[SAFE_OFFSET(0)] AS created_data,
    ARRAY_AGG(IF(operation != 'DELETE', data, NULL) IGNORE NULLS ORDER BY timestamp DESC LIMIT 1)[SAFE_OFFSET(0)] AS latest_data
  FROM `{{reviews_changelog}}`
  GROUP BY document_id
)
SELECT
  review_id,
  first_seen_at,
  last_operation = 'DELETE' AS is_deleted,
  created_after_export,
  -- 확장은 Firestore Timestamp를 {"_seconds":..,"_nanoseconds":..}로 직렬화한다. 문자열 형태도 함께 흡수
  COALESCE(
    TIMESTAMP_SECONDS(SAFE_CAST(JSON_VALUE(created_data, '$.createdAt._seconds') AS INT64)),
    SAFE_CAST(JSON_VALUE(created_data, '$.createdAt') AS TIMESTAMP)
  ) AS created_at,
  JSON_VALUE(created_data, '$.authorId') AS author_id,
  ARRAY_LENGTH(JSON_QUERY_ARRAY(created_data, '$.imageUrls')) AS photo_count_at_create,
  ARRAY_LENGTH(JSON_QUERY_ARRAY(latest_data, '$.imageUrls')) AS photo_count_latest
FROM per_review
