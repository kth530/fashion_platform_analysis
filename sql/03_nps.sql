/* =====================================================================
   NPS 기반 추천 의향 세그먼트 분석 (03_nps)

   Skills used:
     CASE WHEN 세그먼트 분류 · VIEW · GROUP BY · 다축 교차집계

   대상: 플랫폼 사용자 200명 (NPS 분석 base), 구매자 191명 (Q12 등)
   사용법: nps_scored_view로 세그먼트·점수 뷰를 만든 뒤 집계 쿼리가 참조한다.
           다중응답(Q4 platforms · Q12 repurchase_reason · Q13 dissatisfaction)·
           카이제곱·조정 표준화잔차·스피어만은 노트북 pandas/scipy에서 처리한다
           (explode·검정은 SQL 부적합). base_scored를 행 단위로 가져가 사용.
   ===================================================================== */


-- name: nps_scored_view | 설문 → NPS 세그먼트 + 콘텐츠·지출 점수 (VIEW, CASE WHEN)
CREATE OR REPLACE VIEW nps_scored AS
SELECT
    *,
    CASE WHEN nps >= 9 THEN 'Promoter'
         WHEN nps >= 7 THEN 'Passive'
         ELSE 'Detractor' END AS nps_segment,
    -- Q(콘텐츠 탐색 빈도) 점수
    CASE content_freq
        WHEN '전혀 찾아보지 않는다' THEN 1
        WHEN '가끔 본다'           THEN 2
        WHEN '보통이다'            THEN 3
        WHEN '자주 본다'           THEN 4
        WHEN '매우 자주 본다'      THEN 5
        ELSE NULL END AS content_score,
    -- Q(월 지출) 점수
    CASE monthly_spend
        WHEN '5만원 미만'   THEN 1
        WHEN '5~10만원'    THEN 2
        WHEN '10~20만원'   THEN 3
        WHEN '20~30만원'   THEN 4
        WHEN '30만원 이상' THEN 5
        ELSE NULL END AS spend_score
FROM survey
WHERE uses_platform = '예'
  AND nps IS NOT NULL;


-- name: base_scored | 점수·세그먼트가 붙은 사용자 200명 전체 (pandas 다중응답·검정용)
SELECT * FROM nps_scored;


-- name: nps_distribution | NPS 원점수(0-10) 분포 (GROUP BY)
SELECT nps, COUNT(*) AS n
FROM nps_scored
GROUP BY nps
ORDER BY nps;


-- name: continue_counts | 계속 사용 의향(Q14) 분포 (GROUP BY)
SELECT continue_use, COUNT(*) AS n
FROM nps_scored
WHERE continue_use IS NOT NULL
GROUP BY continue_use;


-- name: segment_continue_cross | NPS 세그먼트 × 계속 사용 의향 교차 카운트 (카이제곱·잔차 입력)
SELECT nps_segment, continue_use, COUNT(*) AS n
FROM nps_scored
WHERE continue_use IS NOT NULL
GROUP BY nps_segment, continue_use;


-- name: gender_by_segment | NPS 세그먼트 × 성별 카운트 (GROUP BY)
SELECT nps_segment, gender, COUNT(*) AS n
FROM nps_scored
GROUP BY nps_segment, gender;


-- name: age_by_segment | NPS 세그먼트 × 연령 카운트 (GROUP BY)
SELECT nps_segment, age, COUNT(*) AS n
FROM nps_scored
GROUP BY nps_segment, age;
