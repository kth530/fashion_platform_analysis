/*
  04 가설 검증 · 후속 EDA.
  -- name: 쿼리를 pd.read_sql로 호출한다.
  Spearman·카이제곱·차트와 Q13 복수응답 분리는 Python에서 처리한다.
*/

-- name: population | 02의 ETL 결과와 문항별 분모
SELECT a.raw_n AS raw,
       (SELECT COUNT(*) FROM final_survey_semantic) AS cleaned,
       (SELECT COUNT(*) FROM final_survey_semantic WHERE is_platform_user = 1) AS platform_users,
       (SELECT COUNT(*) FROM final_survey_semantic WHERE is_buyer = 1) AS buyers,
       (SELECT COUNT(*) FROM final_survey_semantic WHERE is_valid_q18 = 1) AS valid_q18,
       (SELECT COUNT(*) FROM final_survey_semantic
         WHERE is_valid_q18 = 1 AND is_platform_user = 1) AS platform_user_q18,
       (SELECT COUNT(*) FROM final_survey_semantic
         WHERE is_platform_user = 1 AND nps IS NOT NULL
           AND discovery_label IN ('SNS', '유튜브', '친구/지인')) AS h3_channel_n
FROM final_etl_audit a;

-- name: users | H1: 사용자 200명의 NPS와 지속 이용 의향
SELECT user_id, nps, nps_segment, continue_score, is_retain_positive
FROM final_survey_semantic
WHERE is_platform_user = 1;

-- name: buyers | H2: 구매자 191명의 자기보고 구매 점수
SELECT user_id, nps, nps_segment, frequency_score, recency_score
FROM final_survey_semantic
WHERE is_buyer = 1;

-- name: channel_match | 공통 3채널 인지자 × 동일 채널 여부
-- Q16·Q17 표준화 라벨은 final_survey_semantic에서 정의한다.
WITH channel_base AS (
    SELECT user_id, discovery_label, influence_label
    FROM final_survey_semantic
    WHERE is_platform_user = 1 AND nps IS NOT NULL
)
SELECT discovery_label AS `인지채널`,
       SUM(discovery_label = influence_label) AS `일치`,
       SUM(discovery_label <> influence_label) AS `불일치`,
       COUNT(*) AS n
FROM channel_base
WHERE discovery_label IN ('SNS', '유튜브', '친구/지인')
GROUP BY discovery_label;

-- name: channel_cross | 같은 155명의 Q16 3채널 × Q17 6채널 히트맵 입력
WITH channel_base AS (
    SELECT user_id, discovery_label, influence_label
    FROM final_survey_semantic
    WHERE is_platform_user = 1 AND nps IS NOT NULL
)
SELECT discovery_label AS discovery, influence_label AS influence, COUNT(*) AS n
FROM channel_base
WHERE discovery_label IN ('SNS', '유튜브', '친구/지인')
GROUP BY discovery_label, influence_label;

-- name: q13_base | 후속 탐색: 사용자별 선택형 불편 원문
SELECT user_id, dissatisfaction
FROM final_survey_semantic
WHERE is_platform_user = 1;

-- name: q18_labeled | 후속 탐색: 유효 자유응답과 전수 감사 다중 라벨
SELECT s.user_id, s.is_platform_user, l.category
FROM final_survey_semantic s
JOIN final_q18_labels l ON l.user_id = s.user_id
WHERE s.is_valid_q18 = 1;
