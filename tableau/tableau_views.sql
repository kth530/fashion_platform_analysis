/* =====================================================================
   Tableau 단일 요약 대시보드용 데이터 VIEW (tableau_views.sql)

   목적: 03~06 분석 SQL의 검증된 CASE WHEN 분류 로직을 사용자 1행 평면 뷰로
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
    CASE WHEN age IN ('10대', '20대 초중반') THEN '10-20대 초중반'
         WHEN age = '20대 후반'             THEN '20대 후반'
         ELSE '30대 이상' END AS age_group,
    content_freq,
    monthly_spend,
    -- NPS ---------------------------------------------------------------
    nps,
    CASE WHEN nps >= 9 THEN 'Promoter'
         WHEN nps >= 7 THEN 'Passive'
         ELSE 'Detractor' END AS nps_segment,
    -- 구매 행동 ---------------------------------------------------------
    purchase_count,
    last_purchase,
    avg_spend,
    -- 계속 사용 의향 (Q14) ----------------------------------------------
    continue_use,
    CASE continue_use
        WHEN '다른 앱으로 바꿀 것 같다'   THEN 1
        WHEN '아마 사용하지 않을 것 같다' THEN 2
        WHEN '잘 모르겠다'               THEN 3
        WHEN '아마 사용할 것 같다'       THEN 4
        WHEN '계속 사용할 것 같다'       THEN 5
        ELSE NULL END AS continue_score,
    -- R·F·M 점수 (비구매자 NULL) ---------------------------------------
    CASE WHEN last_purchase = '6개월 이상' THEN 1
         WHEN last_purchase = '3~6개월'   THEN 2
         WHEN last_purchase = '1~3개월'   THEN 3
         WHEN last_purchase = '1개월 이내' THEN 4
         ELSE NULL END AS R,
    CASE WHEN purchase_count = '1~2번'   THEN 1
         WHEN purchase_count = '3~5번'   THEN 2
         WHEN purchase_count = '6번 이상' THEN 3
         ELSE NULL END AS F,
    CASE WHEN avg_spend = '3만원 미만'  THEN 1
         WHEN avg_spend = '3~7만원'    THEN 2
         WHEN avg_spend = '7~15만원'   THEN 3
         WHEN avg_spend = '15~30만원'  THEN 4
         WHEN avg_spend = '30만원 이상' THEN 5
         ELSE NULL END AS M,
    -- R×F 4분면 (sql/04) ------------------------------------------------
    CASE
        WHEN purchase_count IN ('3~5번', '6번 이상') AND last_purchase IN ('1~3개월', '1개월 이내') THEN '충성'
        WHEN purchase_count = '1~2번'               AND last_purchase IN ('1~3개월', '1개월 이내') THEN '활성'
        WHEN purchase_count IN ('3~5번', '6번 이상') AND last_purchase IN ('3~6개월', '6개월 이상') THEN '재활성화 후보'
        WHEN purchase_count = '1~2번'               AND last_purchase IN ('3~6개월', '6개월 이상') THEN '휴면'
        ELSE NULL
    END AS rf_quadrant,
    -- RFM 5세그먼트 (sql/05, 위에서 아래 순서대로 평가) ----------------
    CASE
        WHEN purchase_count IS NULL OR purchase_count = '구매하지 않음' THEN NULL
        WHEN last_purchase IN ('1~3개월', '1개월 이내')
             AND purchase_count = '6번 이상'
             AND avg_spend IN ('7~15만원', '15~30만원', '30만원 이상') THEN 'Champions'
        WHEN purchase_count = '6번 이상'
             AND last_purchase IN ('1~3개월', '1개월 이내') THEN 'Loyal'
        WHEN last_purchase IN ('1~3개월', '1개월 이내')
             AND purchase_count IN ('1~2번', '3~5번') THEN 'Potential'
        WHEN last_purchase IN ('6개월 이상', '3~6개월')
             AND (purchase_count IN ('3~5번', '6번 이상')
                  OR avg_spend IN ('7~15만원', '15~30만원', '30만원 이상')) THEN 'At Risk'
        ELSE 'Hibernating'
    END AS rfm_segment,
    -- 채널 라벨 (sql/06) ------------------------------------------------
    CASE WHEN discovery LIKE '인스타그램%'   THEN 'SNS'
         WHEN discovery = '친구 / 지인 추천' THEN '친구/지인'
         ELSE discovery END AS discovery,
    CASE WHEN influence LIKE '인스타그램%'     THEN 'SNS'
         WHEN influence = '친구 / 지인 추천'   THEN '친구/지인'
         WHEN influence = '앱 내 추천 상품'    THEN '앱 내 추천'
         WHEN influence = '앱 푸시 알림 / 쿠폰' THEN '앱 푸시/쿠폰'
         ELSE influence END AS influence,
    CASE WHEN influence LIKE '인스타그램%' OR influence IN ('유튜브', '친구 / 지인 추천') THEN '외부'
         WHEN influence IN ('앱 내 추천 상품', '앱 푸시 알림 / 쿠폰')                    THEN '앱 내'
         ELSE '특별히 없음' END AS channel_type,
    -- 멀티호밍 (플랫폼 2개 이상이면 멀티) -------------------------------
    CASE WHEN platforms LIKE '%,%' THEN '멀티' ELSE '단일' END AS platform_group,
    -- KPI 헬퍼 플래그 ---------------------------------------------------
    CASE WHEN nps >= 9 THEN 1 ELSE 0 END AS is_promoter,
    CASE WHEN nps <= 6 THEN 1 ELSE 0 END AS is_detractor,
    CASE WHEN purchase_count <> '구매하지 않음' THEN 1 ELSE 0 END AS is_buyer,
    -- 구매 공백: 구매자 중 최근 구매 3개월 초과 (= 재활성화 후보 + 휴면)
    CASE WHEN purchase_count <> '구매하지 않음'
              AND last_purchase IN ('3~6개월', '6개월 이상') THEN 1 ELSE 0 END AS recency_gap_flag,
    -- 계속 사용 의향 긍정(아마/계속) 플래그
    CASE WHEN continue_use IN ('아마 사용할 것 같다', '계속 사용할 것 같다') THEN 1 ELSE 0 END AS is_retain_positive
FROM survey
WHERE uses_platform = '예'
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
