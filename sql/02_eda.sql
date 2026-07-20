/* =====================================================================
   패션 플랫폼 사용자 행동 탐색 분석 (02_eda)

   Skills used:
     CASE WHEN 순서형 점수화·라벨 통합 · VIEW · GROUP BY
     · 윈도우 함수(PARTITION BY / OVER()) · 조건부 집계

   대상: 정제 설문 266명 / 플랫폼 사용자 200명 / 구매자 191명
   사용법: eda_scored_view로 분석용 점수·라벨 뷰를 만든 뒤 이름이 붙은
           집계 쿼리를 노트북에서 호출한다.

   역할 분담:
     - SQL: 단일응답 점수화, 분포, 교차집계, 채널 라벨 통합
     - scipy/Plotly: 상관 검정과 시각화
     - pandas: 쉼표 구분 다중응답(Q6·Q7·Q8·Q12·Q13) explode
   ===================================================================== */


-- name: eda_scored_view | 설문 → 순서형 점수·구매 상태·채널 통합 라벨 (VIEW, CASE WHEN)
CREATE OR REPLACE VIEW eda_scored AS
SELECT
    *,
    CASE content_freq
        WHEN '전혀 찾아보지 않는다' THEN 1
        WHEN '가끔 본다'           THEN 2
        WHEN '보통이다'            THEN 3
        WHEN '자주 본다'           THEN 4
        WHEN '매우 자주 본다'      THEN 5
        ELSE NULL END AS content_score,
    CASE monthly_spend
        WHEN '5만원 미만'   THEN 1
        WHEN '5~10만원'    THEN 2
        WHEN '10~20만원'   THEN 3
        WHEN '20~30만원'   THEN 4
        WHEN '30만원 이상' THEN 5
        ELSE NULL END AS monthly_score,
    CASE avg_spend
        WHEN '3만원 미만'   THEN 1
        WHEN '3~7만원'     THEN 2
        WHEN '7~15만원'    THEN 3
        WHEN '15~30만원'   THEN 4
        WHEN '30만원 이상' THEN 5
        ELSE NULL END AS avg_score,
    CASE purchase_count
        WHEN '구매하지 않음' THEN 0
        WHEN '1~2번'        THEN 1
        WHEN '3~5번'        THEN 2
        WHEN '6번 이상'     THEN 3
        ELSE NULL END AS purchase_score,
    CASE last_purchase
        WHEN '6개월 이상' THEN 1
        WHEN '3~6개월'   THEN 2
        WHEN '1~3개월'   THEN 3
        WHEN '1개월 이내' THEN 4
        ELSE NULL END AS recency_score,
    CASE continue_use
        WHEN '다른 앱으로 바꿀 것 같다'   THEN 1
        WHEN '아마 사용하지 않을 것 같다' THEN 2
        WHEN '잘 모르겠다'               THEN 3
        WHEN '아마 사용할 것 같다'       THEN 4
        WHEN '계속 사용할 것 같다'       THEN 5
        ELSE NULL END AS continue_score,
    CASE WHEN purchase_count = '구매하지 않음' THEN '비구매자'
         WHEN purchase_count IS NOT NULL       THEN '구매자'
         ELSE NULL END AS purchase_status,
    CASE
        WHEN discovery LIKE '%인스타그램%' OR discovery LIKE '%틱톡%'
             OR discovery LIKE '%스레드%' OR discovery LIKE '%SNS%' THEN 'SNS'
        WHEN discovery LIKE '%유튜브%' THEN '유튜브'
        WHEN discovery LIKE '%친구%' OR discovery LIKE '%지인%' THEN '친구/지인'
        WHEN discovery LIKE '%포털%' OR discovery LIKE '%검색%' THEN '검색'
        WHEN discovery LIKE '%앱스토어%' OR discovery LIKE '%플레이스토어%' THEN '앱스토어/플레이스토어'
        WHEN discovery LIKE '%앱 내%' OR discovery LIKE '%푸시%' OR discovery LIKE '%쿠폰%' THEN '앱 내부 추천/알림'
        WHEN discovery LIKE '%특별히 없음%' OR discovery LIKE '%기억%' THEN '특별히 없음/기억 안남'
        WHEN discovery LIKE '%광고%' THEN '광고/미디어'
        WHEN discovery IS NOT NULL THEN '기타'
        ELSE NULL END AS discovery_group,
    CASE
        WHEN influence LIKE '%인스타그램%' OR influence LIKE '%틱톡%'
             OR influence LIKE '%스레드%' OR influence LIKE '%SNS%' THEN 'SNS'
        WHEN influence LIKE '%유튜브%' THEN '유튜브'
        WHEN influence LIKE '%친구%' OR influence LIKE '%지인%' THEN '친구/지인'
        WHEN influence LIKE '%포털%' OR influence LIKE '%검색%' THEN '검색'
        WHEN influence LIKE '%앱스토어%' OR influence LIKE '%플레이스토어%' THEN '앱스토어/플레이스토어'
        WHEN influence LIKE '%앱 내%' OR influence LIKE '%푸시%' OR influence LIKE '%쿠폰%' THEN '앱 내부 추천/알림'
        WHEN influence LIKE '%특별히 없음%' OR influence LIKE '%기억%' THEN '특별히 없음/기억 안남'
        WHEN influence LIKE '%광고%' THEN '광고/미디어'
        WHEN influence IS NOT NULL THEN '기타'
        ELSE NULL END AS influence_group
FROM survey;


-- name: base_scored | 점수·라벨이 붙은 정제 설문 266명 전체
SELECT *
FROM eda_scored;


-- name: sample_overview | EDA 분석 모수 한 번에 점검 (조건부 집계)
SELECT
    COUNT(*) AS total_n,
    SUM(uses_platform = '예') AS platform_users,
    SUM(uses_platform = '예' AND purchase_status = '구매자') AS buyers,
    SUM(age IN ('10대', '20대 초중반', '20대 후반', '30대')) AS age_10_30_n,
    SUM(age IN ('20대 초중반', '20대 후반')) AS age_20s_n
FROM eda_scored;


-- name: gender_distribution | 성별 인원·전체 비율 (GROUP BY + 윈도우)
SELECT
    gender,
    COUNT(*) AS n,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM eda_scored
GROUP BY gender
ORDER BY n DESC;


-- name: age_distribution | 연령대 인원·전체 비율 (GROUP BY + CASE 정렬)
SELECT
    age,
    COUNT(*) AS n,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM eda_scored
GROUP BY age
ORDER BY CASE age
    WHEN '10대' THEN 1
    WHEN '20대 초중반' THEN 2
    WHEN '20대 후반' THEN 3
    WHEN '30대' THEN 4
    WHEN '40대 이상' THEN 5
    ELSE 99 END;


-- name: gender_age_cross | 연령대 × 성별 카운트 (GROUP BY)
SELECT age, gender, COUNT(*) AS n
FROM eda_scored
GROUP BY age, gender;


-- name: content_by_gender | 성별 × 콘텐츠 탐색 빈도, 성별 내 비율 (PARTITION BY)
SELECT
    gender,
    content_freq,
    COUNT(*) AS n,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY gender), 1) AS pct
FROM eda_scored
WHERE content_freq IS NOT NULL
GROUP BY gender, content_freq;


-- name: spend_by_gender | 성별 × 월 지출, 성별 내 비율 (PARTITION BY)
SELECT
    gender,
    monthly_spend,
    COUNT(*) AS n,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY gender), 1) AS pct
FROM eda_scored
WHERE monthly_spend IS NOT NULL
GROUP BY gender, monthly_spend;


-- name: platform_use_distribution | 플랫폼 사용 여부 분포 (GROUP BY + 윈도우)
SELECT
    uses_platform,
    COUNT(*) AS n,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM eda_scored
GROUP BY uses_platform
ORDER BY n DESC;


-- name: channel_compare | 최초 인지 vs 최근 구매 영향 통합 채널 분포 (CTE + UNION ALL)
WITH channel_counts AS (
    SELECT '최초 인지' AS kind, discovery_group AS channel, COUNT(*) AS n
    FROM eda_scored
    WHERE uses_platform = '예' AND discovery_group IS NOT NULL
    GROUP BY discovery_group
    UNION ALL
    SELECT '최근 구매 영향' AS kind, influence_group AS channel, COUNT(*) AS n
    FROM eda_scored
    WHERE uses_platform = '예' AND influence_group IS NOT NULL
    GROUP BY influence_group
)
SELECT
    kind AS `구분`,
    channel AS `채널`,
    n AS `응답자 수`,
    ROUND(n * 100.0 / SUM(n) OVER (PARTITION BY kind), 1) AS `비율`
FROM channel_counts;


-- name: purchase_status_distribution | 플랫폼 사용자 구매자·비구매자 분포
SELECT
    purchase_status AS `구매 여부`,
    COUNT(*) AS `응답자 수`,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS `비율`
FROM eda_scored
WHERE uses_platform = '예' AND purchase_status IS NOT NULL
GROUP BY purchase_status
ORDER BY `응답자 수` DESC;


-- name: purchase_count_by_gender | 구매자 성별 × 구매 횟수, 성별 내 비율
SELECT
    gender,
    purchase_count,
    COUNT(*) AS n,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY gender), 1) AS pct
FROM eda_scored
WHERE uses_platform = '예' AND purchase_status = '구매자'
GROUP BY gender, purchase_count;


-- name: last_purchase_by_gender | 구매자 성별 × 최근 구매 시점, 성별 내 비율
SELECT
    gender,
    last_purchase,
    COUNT(*) AS n,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY gender), 1) AS pct
FROM eda_scored
WHERE uses_platform = '예' AND purchase_status = '구매자' AND last_purchase IS NOT NULL
GROUP BY gender, last_purchase;


-- name: avg_spend_by_gender | 구매자 성별 × 객단가, 성별 내 비율
SELECT
    gender,
    avg_spend,
    COUNT(*) AS n,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY gender), 1) AS pct
FROM eda_scored
WHERE uses_platform = '예' AND purchase_status = '구매자' AND avg_spend IS NOT NULL
GROUP BY gender, avg_spend;
