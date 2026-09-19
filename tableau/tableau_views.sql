/* =====================================================================
   Tableau 단일 요약 대시보드용 데이터 VIEW (tableau_views.sql)

   목적: 01_semantic_view.sql의 canonical 분류를 사용자 1행 평면 뷰로
         통합한다. Tableau Public은 MySQL 라이브 연결이 안 되므로,
         export_csv.py가 이 뷰를 읽어 CSV로 떨군 뒤 Tableau에 연결한다.

   재사용 출처:
     R·F·M 점수·rf_quadrant → sql/04_retention_and_behavior.sql
     rfm_segment            → sql/05_segmentation.sql
     채널 라벨·channel_type·멀티호밍 → sql/06_channel.sql
     nps_segment            → 03~06 공통

   대상: 플랫폼 사용자 200명 (uses_platform='예' AND nps IS NOT NULL)
         비구매자는 R·F·M·rf_quadrant·rfm_segment가 NULL.
   ===================================================================== */


-- name: create_main_view | 사용자 200명 평면 뷰 (인구통계·NPS·RFM·채널·KPI 헬퍼)
CREATE OR REPLACE VIEW v_tableau_main AS
SELECT
    user_id,
    -- 인구통계 ----------------------------------------------------------
    gender,
    age,
    age_group_3 AS age_group,
    content_freq,
    monthly_spend,
    -- NPS ---------------------------------------------------------------
    nps,
    nps_segment,
    -- 구매 행동 ---------------------------------------------------------
    purchase_count,
    last_purchase,
    avg_spend,
    -- 계속 사용 의향 (Q14) ----------------------------------------------
    continue_use,
    continue_score,
    -- R·F·M 점수 (비구매자 NULL) ---------------------------------------
    recency_score AS R,
    frequency_score AS F,
    monetary_score AS M,
    -- R×F 4분면 (sql/04) ------------------------------------------------
    rf_quadrant,
    -- RFM 5세그먼트 (sql/05, 위에서 아래 순서대로 평가) ----------------
    rfm_segment,
    -- 채널 라벨 (sql/06) ------------------------------------------------
    discovery_label AS discovery,
    influence_label AS influence,
    influence_channel_type AS channel_type,
    -- 멀티호밍 (플랫폼 2개 이상이면 멀티) -------------------------------
    platform_group_label AS platform_group,
    -- KPI 헬퍼 플래그 ---------------------------------------------------
    CASE WHEN nps_segment = 'Promoter' THEN 1 ELSE 0 END AS is_promoter,
    CASE WHEN nps_segment = 'Detractor' THEN 1 ELSE 0 END AS is_detractor,
    is_buyer,
    -- 구매 공백: 구매자 중 최근 구매 3개월 초과 (= 재활성화 후보 + 휴면)
    CASE WHEN is_buyer = 1 AND recency_bin = '3개월 초과' THEN 1 ELSE 0 END AS recency_gap_flag,
    -- 계속 사용 의향 긍정(아마/계속) 플래그
    CASE WHEN continue_score >= 4 THEN 1 ELSE 0 END AS is_retain_positive
FROM survey_semantic
WHERE is_platform_user = 1
  AND nps IS NOT NULL;


-- name: create_channel_view | 인지(Q16)·구매영향(Q17) 롱 결합 (그룹 막대용)
CREATE OR REPLACE VIEW v_tableau_channel AS
SELECT user_id, gender, age_group, '인지경로(Q16)' AS channel_role, discovery AS channel
FROM v_tableau_main
UNION ALL
SELECT user_id, gender, age_group, '구매영향(Q17)' AS channel_role, influence AS channel
FROM v_tableau_main;


-- name: export_main | CSV 추출용 (v_tableau_main 전체)
SELECT * FROM v_tableau_main;


-- name: export_channel | CSV 추출용 (v_tableau_channel 전체)
SELECT * FROM v_tableau_channel;
