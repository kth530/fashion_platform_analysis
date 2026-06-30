/* =====================================================================
   패션 플랫폼 RFM 세그먼트 분석 (05_segmentation)

   Skills used:
     CASE WHEN 다단 분류 · JOIN · CTE(WITH) · 윈도우 함수(PARTITION BY / OVER() / RANK)
     · 조건부 집계(SUM) · VIEW / CREATE TABLE AS · PK + FK 제약

   대상: 플랫폼 사용자 200명 / 구매자 191명 (fashion_platform.survey)
   사용법: 위→아래 순서로 실행. rfm_scored_view·rfm_seg_table가
           rfm_scored 뷰·rfm_seg 테이블을 만든 뒤 나머지 집계 쿼리가 이를 참조한다.
           (Python 노트북은 `-- name:` 마커로 각 쿼리를 이름 호출한다.)
   ===================================================================== */


-- name: rfm_scored_view | 설문 → R·F·M 점수 + 5세그먼트 분류 (VIEW, CASE WHEN)
-- 값↑ = 최근성·빈도·객단가 신호↑. 사용자 200명을 담되 비구매자는 점수·세그먼트 NULL.
CREATE OR REPLACE VIEW rfm_scored AS
SELECT
    *,
    CASE WHEN nps >= 9 THEN 'Promoter'
         WHEN nps >= 7 THEN 'Passive'
         ELSE 'Detractor' END AS nps_segment,
    -- R (Recency): 1=6개월 이상 → 4=1개월 이내
    CASE WHEN last_purchase = '6개월 이상' THEN 1
         WHEN last_purchase = '3~6개월'   THEN 2
         WHEN last_purchase = '1~3개월'   THEN 3
         WHEN last_purchase = '1개월 이내' THEN 4
         ELSE NULL END AS R,
    -- F (Frequency): 1=1-2번 → 3=6번 이상
    CASE WHEN purchase_count = '1~2번'   THEN 1
         WHEN purchase_count = '3~5번'   THEN 2
         WHEN purchase_count = '6번 이상' THEN 3
         ELSE NULL END AS F,
    -- M (Monetary, 객단가): 1=3만 미만 → 5=30만 이상
    CASE WHEN avg_spend = '3만원 미만'  THEN 1
         WHEN avg_spend = '3~7만원'    THEN 2
         WHEN avg_spend = '7~15만원'   THEN 3
         WHEN avg_spend = '15~30만원'  THEN 4
         WHEN avg_spend = '30만원 이상' THEN 5
         ELSE NULL END AS M,
    -- 5세그먼트 룰 기반 분류 (위에서 아래 순서대로 평가)
    CASE
        WHEN purchase_count IS NULL OR purchase_count = '구매하지 않음' THEN NULL
        WHEN last_purchase IN ('1~3개월', '1개월 이내')
             AND purchase_count = '6번 이상'
             AND avg_spend IN ('7~15만원', '15~30만원', '30만원 이상')
             THEN 'Champions'
        WHEN purchase_count = '6번 이상'
             AND last_purchase IN ('1~3개월', '1개월 이내')
             THEN 'Loyal'
        WHEN last_purchase IN ('1~3개월', '1개월 이내')
             AND purchase_count IN ('1~2번', '3~5번')
             THEN 'Potential'
        WHEN last_purchase IN ('6개월 이상', '3~6개월')
             AND (purchase_count IN ('3~5번', '6번 이상')
                  OR avg_spend IN ('7~15만원', '15~30만원', '30만원 이상'))
             THEN 'At Risk'
        ELSE 'Hibernating'
    END AS rfm_segment
FROM survey
WHERE uses_platform = '예'
  AND nps IS NOT NULL;


-- name: rfm_seg_table | 구매자 191명 매핑 테이블 (CREATE TABLE AS + PK + FK)
-- user_id를 PK(자체 식별)이자 survey 참조 FK(무결성)로 사용한다.
DROP TABLE IF EXISTS rfm_seg;

CREATE TABLE rfm_seg AS
SELECT user_id, R, F, M, rfm_segment
FROM rfm_scored
WHERE rfm_segment IS NOT NULL;

ALTER TABLE rfm_seg
    MODIFY user_id INT NOT NULL PRIMARY KEY,
    ADD CONSTRAINT fk_rfm_seg_user
        FOREIGN KEY (user_id) REFERENCES survey(user_id);


-- name: rfm_distribution | R·F·M 점수 분포 (UNION ALL + GROUP BY + 윈도우 비율)
-- 비율(pct)은 각 축(dim) 내 비율. SUM(COUNT(*)) OVER () = 해당 축 총합.
SELECT 'R (Recency)' AS dim, R AS score, COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM rfm_scored WHERE R IS NOT NULL GROUP BY R
UNION ALL
SELECT 'F (Frequency)', F, COUNT(*),
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)
FROM rfm_scored WHERE F IS NOT NULL GROUP BY F
UNION ALL
SELECT 'M (Monetary)', M, COUNT(*),
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)
FROM rfm_scored WHERE M IS NOT NULL GROUP BY M
ORDER BY dim, score;


-- name: segment_counts | 룰 기반 5세그먼트 인원·비율 (GROUP BY + 윈도우 비율)
SELECT rfm_segment,
       COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM rfm_seg
GROUP BY rfm_segment;


-- name: segment_profile | 세그먼트 프로파일링 (JOIN + PARTITION BY / OVER())
-- 세그먼트별 평균과 구매자 전체 가중평균(OVER())을 한 쿼리에서 비교한다.
SELECT DISTINCT
    r.rfm_segment,
    COUNT(*) OVER (PARTITION BY r.rfm_segment) AS n,
    ROUND(COUNT(*) OVER (PARTITION BY r.rfm_segment) * 100.0 /
          COUNT(*) OVER (), 1) AS pct_of_total,
    ROUND(AVG(r.R)   OVER (PARTITION BY r.rfm_segment), 2) AS avg_R,
    ROUND(AVG(r.F)   OVER (PARTITION BY r.rfm_segment), 2) AS avg_F,
    ROUND(AVG(r.M)   OVER (PARTITION BY r.rfm_segment), 2) AS avg_M,
    ROUND(AVG(s.nps) OVER (PARTITION BY r.rfm_segment), 2) AS avg_nps,
    ROUND(AVG(s.nps) OVER (), 2) AS overall_nps,
    ROUND(AVG(s.nps) OVER (PARTITION BY r.rfm_segment)
        - AVG(s.nps) OVER (), 2) AS nps_vs_overall
FROM survey s
JOIN rfm_seg r ON s.user_id = r.user_id
WHERE r.rfm_segment IS NOT NULL;


-- name: segment_gender | 세그먼트별 성별 (조건부 집계 SUM)
SELECT r.rfm_segment,
       SUM(s.gender = '남성') AS male_n,
       SUM(s.gender = '여성') AS female_n,
       ROUND(SUM(s.gender = '남성') * 100.0 / COUNT(*), 1) AS male_pct,
       ROUND(SUM(s.gender = '여성') * 100.0 / COUNT(*), 1) AS female_pct
FROM rfm_seg r
JOIN survey s ON r.user_id = s.user_id
GROUP BY r.rfm_segment;


-- name: segment_age | 세그먼트별 연령 3구간 (CASE 병합 + 조건부 집계)
SELECT r.rfm_segment,
       SUM(s.age IN ('10대', '20대 초중반')) AS age_young,
       SUM(s.age = '20대 후반')             AS age_mid,
       SUM(s.age IN ('30대', '40대 이상'))   AS age_old,
       COUNT(*) AS n
FROM rfm_seg r
JOIN survey s ON r.user_id = s.user_id
GROUP BY r.rfm_segment;


-- name: potential_split | Potential 내부 F × M 2×2 세분화 (CTE)
WITH potential_split AS (
    SELECT
        s.user_id, s.gender, s.age, s.nps,
        r.R, r.F, r.M,
        CASE
            WHEN r.F = 2 AND r.M >= 3 THEN 'Active × High M'
            WHEN r.F = 2 AND r.M <  3 THEN 'Active × Low M'
            WHEN r.F = 1 AND r.M >= 3 THEN 'Light × High M'
            WHEN r.F = 1 AND r.M <  3 THEN 'Light × Low M'
        END AS sub_segment
    FROM survey s
    JOIN rfm_seg r ON s.user_id = r.user_id
    WHERE r.rfm_segment = 'Potential'
)
SELECT * FROM potential_split;


-- name: potential_profile | Potential 4사분면 프로파일 (CTE + GROUP BY)
WITH potential_split AS (
    SELECT
        s.gender, s.nps, r.M,
        CASE
            WHEN r.F = 2 AND r.M >= 3 THEN 'Active × High M'
            WHEN r.F = 2 AND r.M <  3 THEN 'Active × Low M'
            WHEN r.F = 1 AND r.M >= 3 THEN 'Light × High M'
            WHEN r.F = 1 AND r.M <  3 THEN 'Light × Low M'
        END AS sub_segment
    FROM survey s
    JOIN rfm_seg r ON s.user_id = r.user_id
    WHERE r.rfm_segment = 'Potential'
)
SELECT sub_segment,
       COUNT(*) AS n,
       ROUND(AVG(nps), 2) AS avg_nps,
       ROUND(AVG(M), 2)   AS avg_M,
       SUM(gender = '남성') AS male_n,
       SUM(gender = '여성') AS female_n,
       ROUND(SUM(gender = '남성') * 100.0 / COUNT(*), 1) AS male_pct,
       ROUND(SUM(gender = '여성') * 100.0 / COUNT(*), 1) AS female_pct
FROM potential_split
GROUP BY sub_segment;


-- name: cant_lose | At Risk 객단가 신호(M≥3) 후보 (JOIN + RANK() OVER)
SELECT
    RANK() OVER (ORDER BY r.M DESC, s.nps DESC) AS priority_rank,
    s.user_id, s.gender, s.age,
    r.R, r.F, r.M, s.nps
FROM survey s
JOIN rfm_seg r ON s.user_id = r.user_id
WHERE r.rfm_segment = 'At Risk' AND r.M >= 3
ORDER BY priority_rank;
