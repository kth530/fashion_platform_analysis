/* =====================================================================
   태도-구매 행동 정합성 분석 (04_retention_and_behavior)

   Skills used:
     CASE WHEN 다단 분류 · VIEW · GROUP BY · 조건부 집계(SUM) · 윈도우 함수(OVER())

   대상: 플랫폼 사용자 200명 / 구매자 191명 (fashion_platform.survey)
   사용법: 01_semantic_view.sql 실행 후 rf_scored_view로 점수·분류 뷰를 만든 뒤 나머지 집계 쿼리가 참조한다.
           (스피어만·카이제곱·다중응답(Q7)은 SQL이 아니라 노트북 pandas/scipy에서
            처리한다 — 검정·explode는 SQL 부적합. base_scored를 행 단위로 가져가 사용.)
   ===================================================================== */


-- name: rf_scored_view | 설문 → 구매행동 점수·R×F 4분면·태도 점수 (VIEW, CASE WHEN)
CREATE OR REPLACE VIEW rf_scored AS
SELECT
    *,
    frequency_score AS freq_score,
    frequency_bin AS freq_bin
FROM survey_semantic
WHERE is_platform_user = 1
  AND nps IS NOT NULL;


-- name: base_scored | 점수·분류가 붙은 사용자 200명 전체 (pandas 검정·다중응답용)
SELECT * FROM rf_scored;


-- name: rf_full_3x4 | 구매 빈도 × 최근성 3×4 분포 (GROUP BY)
SELECT purchase_count AS frequency,
       last_purchase  AS recency,
       COUNT(*) AS n,
       ROUND(AVG(nps), 2) AS avg_nps
FROM rf_scored
WHERE is_buyer = 1
  AND last_purchase IS NOT NULL
GROUP BY purchase_count, last_purchase;


-- name: rf_quadrant_counts | R×F 4분면 인원·평균추천점수·비율 (GROUP BY + 윈도우)
SELECT rf_quadrant,
       COUNT(*) AS n,
       ROUND(AVG(nps), 2) AS avg_nps,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM rf_scored
WHERE rf_quadrant IS NOT NULL
GROUP BY rf_quadrant;


-- name: recency_by_gender | Recency × 성별 분할표 카운트 (카이제곱 입력)
SELECT gender, recency_bin, COUNT(*) AS n
FROM rf_scored
WHERE recency_bin IS NOT NULL
GROUP BY gender, recency_bin;


-- name: recency_by_age | Recency × 연령 3구간 분할표 카운트 (카이제곱 입력)
SELECT
    age_group_3 AS age_3g,
    recency_bin,
    COUNT(*) AS n
FROM rf_scored
WHERE recency_bin IS NOT NULL
GROUP BY age_3g, recency_bin;


-- name: gap_by_demo | 성별 × 연령 3구간 구매 공백률 (조건부 집계)
SELECT
    gender,
    age_group_3 AS age_3g,
    SUM(recency_bin = '3개월 이내') AS within_3m,
    SUM(recency_bin = '3개월 초과') AS over_3m,
    COUNT(*) AS n,
    ROUND(SUM(recency_bin = '3개월 초과') * 100.0 / COUNT(*), 1) AS gap_pct
FROM rf_scored
WHERE recency_bin IS NOT NULL
GROUP BY gender, age_3g;
