/*
  03 데이터 개요. 02의 final_survey_semantic을 그대로 조회한다.
  단일응답은 SQL에서 집계하고, Q6·Q7·Q8 복수응답은
  pandas의 ', ' 분리·explode 방식으로 집계한다.
*/

-- name: population | 정제 흐름과 분석 집단
SELECT a.raw_n AS raw, a.removed_n AS removed,
       (SELECT COUNT(*) FROM final_survey_semantic) AS cleaned,
       (SELECT COUNT(*) FROM final_survey_semantic WHERE is_platform_user = 1) AS platform_users,
       (SELECT COUNT(*) FROM final_survey_semantic WHERE is_buyer = 1) AS buyers,
       (SELECT COUNT(*) FROM final_survey_semantic WHERE is_valid_q18 = 1) AS valid_q18,
       (SELECT COUNT(*) FROM final_survey_semantic
         WHERE is_valid_q18 = 1 AND is_platform_user = 1) AS platform_user_q18
FROM final_etl_audit a;

-- name: gender_distribution | 성별 인원·전체 비율
SELECT gender, COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM final_survey_semantic
GROUP BY gender
ORDER BY n DESC;

-- name: age_distribution | 연령대 인원·전체 비율
SELECT age, COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM final_survey_semantic
GROUP BY age
ORDER BY CASE age
    WHEN '10대' THEN 1 WHEN '20대 초중반' THEN 2 WHEN '20대 후반' THEN 3
    WHEN '30대' THEN 4 WHEN '40대 이상' THEN 5 ELSE 99 END;

-- name: platform_use_distribution | 플랫폼 사용 여부
SELECT uses_platform, COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM final_survey_semantic
GROUP BY uses_platform
ORDER BY n DESC;

-- name: platform_responses | Q6 정규화된 복수응답 원문, Python에서 분리
SELECT user_id, platforms
FROM final_survey_semantic
WHERE is_platform_user = 1;

-- name: multihoming_distribution | platform_count 기준 단일·복수
SELECT CASE WHEN platform_count >= 2 THEN 2 ELSE 1 END AS platform_group,
       COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM final_survey_semantic
WHERE is_platform_user = 1
GROUP BY platform_group
ORDER BY platform_group;

-- name: selection_factor_responses | Q7 복수응답 원문, Python에서 분리
SELECT user_id, selection_factors
FROM final_survey_semantic
WHERE is_platform_user = 1;

-- name: open_purpose_responses | Q8 복수응답 원문, Python에서 분리
SELECT user_id, open_purpose
FROM final_survey_semantic
WHERE is_platform_user = 1;

-- name: buyers_count | Q9 최근 6개월 구매자
SELECT COUNT(*) AS n
FROM final_survey_semantic
WHERE is_buyer = 1;

-- name: variable_validity | 04의 주요 문항별 유효 응답 수
SELECT
    SUM(is_platform_user = 1 AND nps IS NOT NULL) AS q15_n,
    SUM(is_platform_user = 1 AND continue_use IS NOT NULL) AS q14_n,
    SUM(is_buyer = 1 AND frequency_score IS NOT NULL) AS q9_buyer_n,
    SUM(is_buyer = 1 AND recency_score IS NOT NULL) AS q10_buyer_n,
    SUM(is_platform_user = 1 AND dissatisfaction IS NOT NULL) AS q13_n,
    SUM(is_valid_q18 = 1) AS q18_n,
    SUM(is_valid_q18 = 1 AND is_platform_user = 1) AS q18_user_n,
    (SELECT COUNT(*) FROM final_survey_semantic
      WHERE is_platform_user = 1 AND nps IS NOT NULL
        AND discovery_label IN ('SNS', '유튜브', '친구/지인')) AS h3_channel_n
FROM final_survey_semantic;
