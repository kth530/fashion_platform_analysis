/* =====================================================================
   Canonical semantic layer (01_semantic_view)

   목적:
     - 정제 survey 266행을 그대로 유지한다.
     - 분석 모수는 is_* 플래그로 선택한다.
     - 02~06 분석 SQL과 Tableau가 공유하는 점수·세그먼트 정의를 한 곳에 둔다.
     - 원본 값이 정의역을 벗어나도 조용히 다른 범주로 흡수하지 않고 validation
       flag로 드러낸다.

   실행 순서: 01_cleaning 적재 완료 후 이 파일을 실행하고 02~06/Tableau를 실행한다.
   ===================================================================== */


-- name: semantic_view | 정제 응답 266행 canonical semantic view
CREATE OR REPLACE VIEW survey_semantic AS
WITH semantic_base AS (
    SELECT
        s.*,

        -- 분석 모수 -------------------------------------------------------
        CASE WHEN uses_platform = '예' THEN 1 ELSE 0 END AS is_platform_user,
        CASE WHEN uses_platform = '예'
                  AND purchase_count IN ('1~2번', '3~5번', '6번 이상')
             THEN 1 ELSE 0 END AS is_buyer,
        CASE WHEN uses_platform = '예'
                  AND nps IS NOT NULL
                  AND purchase_count IN ('1~2번', '3~5번', '6번 이상')
                  AND last_purchase IN ('6개월 이상', '3~6개월', '1~3개월', '1개월 이내')
                  AND avg_spend IN ('3만원 미만', '3~7만원', '7~15만원', '15~30만원', '30만원 이상')
             THEN 1 ELSE 0 END AS is_rfm_eligible,

        -- validation flag: 분류 결과를 바꾸는 필터가 아니라 이상값을 노출한다.
        CASE WHEN nps BETWEEN 0 AND 10 THEN 1 ELSE 0 END AS nps_valid_flag,
        CASE WHEN age IN ('10대', '20대 초중반', '20대 후반', '30대', '40대 이상')
             THEN 1 ELSE 0 END AS age_valid_flag,
        CASE
            WHEN uses_platform <> '예' THEN NULL
            WHEN purchase_count = '구매하지 않음' THEN 1
            WHEN purchase_count IN ('1~2번', '3~5번', '6번 이상')
                 AND last_purchase IN ('6개월 이상', '3~6개월', '1~3개월', '1개월 이내')
                 AND avg_spend IN ('3만원 미만', '3~7만원', '7~15만원', '15~30만원', '30만원 이상')
                THEN 1
            ELSE 0
        END AS rfm_input_valid_flag,

        -- 태도 ------------------------------------------------------------
        CASE WHEN nps BETWEEN 9 AND 10 THEN 'Promoter'
             WHEN nps BETWEEN 7 AND 8  THEN 'Passive'
             WHEN nps BETWEEN 0 AND 6  THEN 'Detractor'
             ELSE NULL END AS nps_segment,
        CASE continue_use
            WHEN '다른 앱으로 바꿀 것 같다'   THEN 1
            WHEN '아마 사용하지 않을 것 같다' THEN 2
            WHEN '잘 모르겠다'               THEN 3
            WHEN '아마 사용할 것 같다'       THEN 4
            WHEN '계속 사용할 것 같다'       THEN 5
            ELSE NULL END AS continue_score,

        -- 구매 점수: 비구매자=0인 EDA 점수와 구매자 전용 F를 분리한다. ------
        CASE purchase_count
            WHEN '구매하지 않음' THEN 0
            WHEN '1~2번'        THEN 1
            WHEN '3~5번'        THEN 2
            WHEN '6번 이상'     THEN 3
            ELSE NULL END AS purchase_activity_score,
        CASE purchase_count
            WHEN '1~2번'    THEN 1
            WHEN '3~5번'    THEN 2
            WHEN '6번 이상' THEN 3
            ELSE NULL END AS frequency_score,
        CASE last_purchase
            WHEN '6개월 이상' THEN 1
            WHEN '3~6개월'   THEN 2
            WHEN '1~3개월'   THEN 3
            WHEN '1개월 이내' THEN 4
            ELSE NULL END AS recency_score,
        CASE avg_spend
            WHEN '3만원 미만'   THEN 1
            WHEN '3~7만원'     THEN 2
            WHEN '7~15만원'    THEN 3
            WHEN '15~30만원'   THEN 4
            WHEN '30만원 이상' THEN 5
            ELSE NULL END AS monetary_score,

        -- 원본 age는 s.*에 유지하고 분석용 3구간만 별도 제공한다. ----------
        CASE WHEN age IN ('10대', '20대 초중반') THEN '10-20대 초중반'
             WHEN age = '20대 후반'             THEN '20대 후반'
             WHEN age IN ('30대', '40대 이상')  THEN '30대 이상'
             ELSE NULL END AS age_group_3,

        -- 채널 상세 라벨: 정제된 선택지를 보존하면서 표기만 통일한다. ------
        CASE WHEN discovery LIKE '인스타그램%'   THEN 'SNS'
             WHEN discovery = '친구 / 지인 추천' THEN '친구/지인'
             ELSE discovery END AS discovery_label,
        CASE WHEN influence LIKE '인스타그램%'     THEN 'SNS'
             WHEN influence = '친구 / 지인 추천'   THEN '친구/지인'
             WHEN influence = '앱 내 추천 상품'    THEN '앱 내 추천'
             WHEN influence = '앱 푸시 알림 / 쿠폰' THEN '앱 푸시/쿠폰'
             ELSE influence END AS influence_label,
        CASE
            WHEN uses_platform <> '예' THEN NULL
            WHEN discovery LIKE '인스타그램%'
              OR discovery IN ('친구 / 지인 추천', '포털 검색', '유튜브',
                               '오프라인/미디어 광고', '앱스토어/플레이스토어', '기타/기억 안남')
                THEN 1
            ELSE 0
        END AS discovery_valid_flag,
        CASE
            WHEN uses_platform <> '예' THEN NULL
            WHEN influence LIKE '인스타그램%'
              OR influence IN ('유튜브', '친구 / 지인 추천', '앱 내 추천 상품',
                               '앱 푸시 알림 / 쿠폰', '특별히 없음')
                THEN 1
            ELSE 0
        END AS influence_valid_flag,
        CASE WHEN platforms IS NULL THEN 0
             ELSE 1 + LENGTH(platforms) - LENGTH(REPLACE(platforms, ',', ''))
        END AS platform_count
    FROM survey s
),
semantic_segmented AS (
    SELECT
        b.*,
        CASE WHEN purchase_count IN ('3~5번', '6번 이상') THEN '자주(≥3)'
             WHEN purchase_count = '1~2번'               THEN '가끔(1-2)'
             ELSE NULL END AS frequency_bin,
        CASE WHEN last_purchase IN ('1~3개월', '1개월 이내') THEN '3개월 이내'
             WHEN last_purchase IN ('3~6개월', '6개월 이상') THEN '3개월 초과'
             ELSE NULL END AS recency_bin,
        CASE
            WHEN purchase_count IN ('3~5번', '6번 이상')
                 AND last_purchase IN ('1~3개월', '1개월 이내') THEN '충성'
            WHEN purchase_count = '1~2번'
                 AND last_purchase IN ('1~3개월', '1개월 이내') THEN '활성'
            WHEN purchase_count IN ('3~5번', '6번 이상')
                 AND last_purchase IN ('3~6개월', '6개월 이상') THEN '재활성화 후보'
            WHEN purchase_count = '1~2번'
                 AND last_purchase IN ('3~6개월', '6개월 이상') THEN '휴면'
            ELSE NULL
        END AS rf_quadrant,
        CASE
            WHEN purchase_count IS NULL OR purchase_count = '구매하지 않음' THEN NULL
            WHEN purchase_count NOT IN ('1~2번', '3~5번', '6번 이상')
                 OR last_purchase IS NULL
                 OR last_purchase NOT IN ('6개월 이상', '3~6개월', '1~3개월', '1개월 이내')
                 OR avg_spend IS NULL
                 OR avg_spend NOT IN ('3만원 미만', '3~7만원', '7~15만원', '15~30만원', '30만원 이상')
                THEN NULL
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

        -- 두 문항을 같은 축에서 비교하기 위한 대분류. 상세 라벨과 분리한다.
        CASE
            WHEN discovery_label = 'SNS' THEN 'SNS'
            WHEN discovery_label = '유튜브' THEN '유튜브'
            WHEN discovery_label = '친구/지인' THEN '친구/지인'
            WHEN discovery_label = '포털 검색' THEN '검색'
            WHEN discovery_label = '앱스토어/플레이스토어' THEN '앱스토어/플레이스토어'
            WHEN discovery_label = '기타/기억 안남' THEN '특별히 없음/기억 안남'
            WHEN discovery_label = '오프라인/미디어 광고' THEN '광고/미디어'
            WHEN discovery_label IS NOT NULL THEN '기타'
            ELSE NULL
        END AS discovery_compare_group,
        CASE
            WHEN influence_label = 'SNS' THEN 'SNS'
            WHEN influence_label = '유튜브' THEN '유튜브'
            WHEN influence_label = '친구/지인' THEN '친구/지인'
            WHEN influence_label IN ('앱 내 추천', '앱 푸시/쿠폰') THEN '앱 내부 추천/알림'
            WHEN influence_label = '특별히 없음' THEN '특별히 없음/기억 안남'
            WHEN influence_label = '포털 검색' THEN '검색'
            WHEN influence_label = '앱스토어/플레이스토어' THEN '앱스토어/플레이스토어'
            WHEN influence_label = '오프라인/미디어 광고' THEN '광고/미디어'
            WHEN influence_label IS NOT NULL THEN '기타'
            ELSE NULL
        END AS influence_compare_group,
        CASE WHEN discovery_label IN ('SNS', '유튜브', '친구/지인', '포털 검색')
             THEN discovery_label
             WHEN discovery_label IS NOT NULL THEN '기타'
             ELSE NULL END AS discovery_group_5,
        CASE WHEN influence_label IN ('SNS', '유튜브', '친구/지인') THEN '외부'
             WHEN influence_label IN ('앱 내 추천', '앱 푸시/쿠폰') THEN '앱 내'
             WHEN influence_label = '특별히 없음' THEN '특별히 없음'
             ELSE NULL END AS influence_channel_type,
        CASE WHEN platform_count >= 2 THEN 2 ELSE 1 END AS platform_group_code,
        CASE WHEN platform_count >= 2 THEN '멀티' ELSE '단일' END AS platform_group_label
    FROM semantic_base b
)
SELECT *
FROM semantic_segmented;


-- name: semantic_validation | 모수·정의역 검증 (결과를 조용히 필터링하지 않음)
SELECT
    COUNT(*) AS total_n,
    SUM(is_platform_user) AS platform_users,
    SUM(is_buyer) AS buyers,
    SUM(is_rfm_eligible) AS rfm_eligible,
    SUM(nps IS NOT NULL AND nps_valid_flag = 0) AS invalid_nps_n,
    SUM(age_valid_flag = 0) AS invalid_age_n,
    SUM(is_platform_user = 1 AND rfm_input_valid_flag = 0) AS invalid_rfm_input_n,
    SUM(is_platform_user = 1 AND discovery_valid_flag = 0) AS invalid_discovery_n,
    SUM(is_platform_user = 1 AND influence_valid_flag = 0) AS invalid_influence_n,
    CASE
        WHEN COUNT(*) = 266
         AND SUM(is_platform_user) = 200
         AND SUM(is_buyer) = 191
         AND SUM(is_rfm_eligible) = 191
         AND SUM(nps IS NOT NULL AND nps_valid_flag = 0) = 0
         AND SUM(age_valid_flag = 0) = 0
         AND SUM(is_platform_user = 1 AND rfm_input_valid_flag = 0) = 0
         AND SUM(is_platform_user = 1 AND discovery_valid_flag = 0) = 0
         AND SUM(is_platform_user = 1 AND influence_valid_flag = 0) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_status
FROM survey_semantic;
