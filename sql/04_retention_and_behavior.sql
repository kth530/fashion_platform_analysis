/* =====================================================================
   태도-구매 행동 정합성 분석 (04_retention_and_behavior)

   Skills used:
     CASE WHEN 다단 분류 · VIEW · GROUP BY · 조건부 집계(SUM) · 윈도우 함수(OVER())

   대상: 플랫폼 사용자 200명 / 구매자 191명 (fashion_platform.survey)
   사용법: rf_scored_view로 점수·분류 뷰를 만든 뒤 나머지 집계 쿼리가 참조한다.
           (스피어만·카이제곱·다중응답(Q7)은 SQL이 아니라 노트북 pandas/scipy에서
            처리한다 — 검정·explode는 SQL 부적합. base_scored를 행 단위로 가져가 사용.)
   ===================================================================== */


-- name: rf_scored_view | 설문 → 구매행동 점수·R×F 4분면·태도 점수 (VIEW, CASE WHEN)
CREATE OR REPLACE VIEW rf_scored AS
SELECT
    *,
    CASE WHEN nps >= 9 THEN 'Promoter'
         WHEN nps >= 7 THEN 'Passive'
         ELSE 'Detractor' END AS nps_segment,
    -- 구매 빈도 점수 (F)
    CASE WHEN purchase_count = '1~2번'   THEN 1
         WHEN purchase_count = '3~5번'   THEN 2
         WHEN purchase_count = '6번 이상' THEN 3
         ELSE NULL END AS freq_score,
    -- 최근성 점수 (R)
    CASE WHEN last_purchase = '6개월 이상' THEN 1
         WHEN last_purchase = '3~6개월'   THEN 2
         WHEN last_purchase = '1~3개월'   THEN 3
         WHEN last_purchase = '1개월 이내' THEN 4
         ELSE NULL END AS recency_score,
    -- 빈도 2분 / 최근성 2분
    CASE WHEN purchase_count IN ('3~5번', '6번 이상') THEN '자주(≥3)'
         WHEN purchase_count = '1~2번'               THEN '가끔(1-2)'
         ELSE NULL END AS freq_bin,
    CASE WHEN last_purchase IN ('1~3개월', '1개월 이내') THEN '3개월 이내'
         WHEN last_purchase IN ('3~6개월', '6개월 이상') THEN '3개월 초과'
         ELSE NULL END AS recency_bin,
    -- R×F 4분면
    CASE
        WHEN purchase_count IN ('3~5번', '6번 이상') AND last_purchase IN ('1~3개월', '1개월 이내') THEN '충성'
        WHEN purchase_count = '1~2번'               AND last_purchase IN ('1~3개월', '1개월 이내') THEN '활성'
        WHEN purchase_count IN ('3~5번', '6번 이상') AND last_purchase IN ('3~6개월', '6개월 이상') THEN '재활성화 후보'
        WHEN purchase_count = '1~2번'               AND last_purchase IN ('3~6개월', '6개월 이상') THEN '휴면'
        ELSE NULL
    END AS rf_quadrant,
    -- Q14 계속 사용 의향 점수
    CASE continue_use
        WHEN '다른 앱으로 바꿀 것 같다'   THEN 1
        WHEN '아마 사용하지 않을 것 같다' THEN 2
        WHEN '잘 모르겠다'               THEN 3
        WHEN '아마 사용할 것 같다'       THEN 4
        WHEN '계속 사용할 것 같다'       THEN 5
        ELSE NULL END AS continue_score
FROM survey
WHERE uses_platform = '예'
  AND nps IS NOT NULL;


-- name: base_scored | 점수·분류가 붙은 사용자 200명 전체 (pandas 검정·다중응답용)
SELECT * FROM rf_scored;


-- name: rf_full_3x4 | 구매 빈도 × 최근성 3×4 분포 (GROUP BY)
SELECT purchase_count AS frequency,
       last_purchase  AS recency,
       COUNT(*) AS n,
       ROUND(AVG(nps), 2) AS avg_nps
FROM rf_scored
WHERE purchase_count <> '구매하지 않음'
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
    CASE WHEN age IN ('10대', '20대 초중반') THEN '10-20대 초중반'
         WHEN age = '20대 후반'             THEN '20대 후반'
         ELSE '30대 이상' END AS age_3g,
    recency_bin,
    COUNT(*) AS n
FROM rf_scored
WHERE recency_bin IS NOT NULL
GROUP BY age_3g, recency_bin;


-- name: gap_by_demo | 성별 × 연령 3구간 구매 공백률 (조건부 집계)
SELECT
    gender,
    CASE WHEN age IN ('10대', '20대 초중반') THEN '10-20대 초중반'
         WHEN age = '20대 후반'             THEN '20대 후반'
         ELSE '30대 이상' END AS age_3g,
    SUM(recency_bin = '3개월 이내') AS within_3m,
    SUM(recency_bin = '3개월 초과') AS over_3m,
    COUNT(*) AS n,
    ROUND(SUM(recency_bin = '3개월 초과') * 100.0 / COUNT(*), 1) AS gap_pct
FROM rf_scored
WHERE recency_bin IS NOT NULL
GROUP BY gender, age_3g;
