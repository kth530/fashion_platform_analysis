/* =====================================================================
   채널·멀티호밍 분석 (06_channel)

   Skills used:
     CASE WHEN 라벨·버킷팅 · VIEW · GROUP BY · 조건부 집계(SUM)

   대상: 플랫폼 사용자 200명 (uses_platform='예' AND nps IS NOT NULL)
   사용법: channel_view로 채널 라벨·버킷·멀티호밍 뷰를 만든 뒤 집계가 참조한다.
           인지(Q16 discovery)·구매영향(Q17 influence)은 단일응답이라 SQL로 집계 가능.
           카이제곱(인지=영향 일치)·만-휘트니(멀티호밍 NPS/구매빈도)는 노트북 scipy.
   ===================================================================== */


-- name: channel_view | 채널 라벨·버킷·멀티호밍 (VIEW, CASE WHEN)
CREATE OR REPLACE VIEW channel_scored AS
SELECT
    user_id, gender, age, platforms, purchase_count, nps,
    -- 인지 경로(Q16) 라벨 통합
    CASE WHEN discovery LIKE '인스타그램%'     THEN 'SNS'
         WHEN discovery = '친구 / 지인 추천'   THEN '친구/지인'
         WHEN discovery = '포털 검색'          THEN '포털 검색'
         WHEN discovery = '유튜브'             THEN '유튜브'
         WHEN discovery = '오프라인/미디어 광고' THEN '오프라인/미디어 광고'
         WHEN discovery = '앱스토어/플레이스토어' THEN '앱스토어/플레이스토어'
         WHEN discovery = '기타/기억 안남'      THEN '기타/기억 안남'
         ELSE discovery END AS discovery,
    -- 구매 영향 채널(Q17) 라벨 통합
    CASE WHEN influence LIKE '인스타그램%'   THEN 'SNS'
         WHEN influence = '유튜브'           THEN '유튜브'
         WHEN influence = '친구 / 지인 추천' THEN '친구/지인'
         WHEN influence = '앱 내 추천 상품'  THEN '앱 내 추천'
         WHEN influence = '앱 푸시 알림 / 쿠폰' THEN '앱 푸시/쿠폰'
         WHEN influence = '특별히 없음'      THEN '특별히 없음'
         ELSE influence END AS influence,
    -- 인지 5분류 (SNS/유튜브/친구·지인/포털 검색 외 기타)
    CASE WHEN discovery LIKE '인스타그램%' OR discovery IN ('유튜브', '친구 / 지인 추천', '포털 검색')
         THEN CASE WHEN discovery LIKE '인스타그램%' THEN 'SNS'
                   WHEN discovery = '친구 / 지인 추천' THEN '친구/지인'
                   ELSE discovery END
         ELSE '기타' END AS discovery_grp,
    -- 연령 3구간
    CASE WHEN age IN ('10대', '20대 초중반') THEN '10-20대 초중반'
         WHEN age = '20대 후반'             THEN '20대 후반'
         ELSE '30대 이상' END AS age_group,
    -- 구매 영향 채널 유형 (외부/앱 내/특별히 없음)
    CASE WHEN influence LIKE '인스타그램%' OR influence IN ('유튜브', '친구 / 지인 추천') THEN '외부'
         WHEN influence IN ('앱 내 추천 상품', '앱 푸시 알림 / 쿠폰')                    THEN '앱 내'
         ELSE '특별히 없음' END AS channel_type,
    -- NPS 세그먼트
    CASE WHEN nps >= 9 THEN 'Promoter'
         WHEN nps >= 7 THEN 'Passive'
         ELSE 'Detractor' END AS nps_segment,
    -- 멀티호밍: 플랫폼 2개 이상이면 2
    CASE WHEN platforms LIKE '%,%' THEN 2 ELSE 1 END AS platform_group
FROM survey
WHERE uses_platform = '예'
  AND nps IS NOT NULL;


-- name: base_scored | 채널 라벨이 붙은 사용자 200명 전체 (만-휘트니 등 pandas용)
SELECT * FROM channel_scored;


-- name: discovery_dist | 인지 경로(Q16) 분포 (GROUP BY)
SELECT discovery AS 인지경로, COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM channel_scored
GROUP BY discovery;


-- name: influence_dist | 구매 영향 채널(Q17) 분포 (GROUP BY)
SELECT influence AS 구매영향채널, COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM channel_scored
GROUP BY influence;


-- name: discovery_by_gender | 인지 5분류 × 성별 카운트 (GROUP BY)
SELECT discovery_grp, gender, COUNT(*) AS n
FROM channel_scored
GROUP BY discovery_grp, gender;


-- name: gender_by_influence | 성별 × 구매 영향 채널 카운트 (GROUP BY)
SELECT gender, influence, COUNT(*) AS n
FROM channel_scored
GROUP BY gender, influence;


-- name: age_by_channel_type | 연령 3구간 × 채널 유형 카운트 (GROUP BY)
SELECT age_group, channel_type, COUNT(*) AS n
FROM channel_scored
GROUP BY age_group, channel_type;


-- name: discovery_influence_cross | 인지 5분류 × 구매 영향 채널 교차 카운트 (GROUP BY)
SELECT discovery_grp, influence, COUNT(*) AS n
FROM channel_scored
GROUP BY discovery_grp, influence;


-- name: channel_match | 인지(공통 채널) × 동일채널 구매영향 여부 (카이제곱 입력)
SELECT discovery AS 인지채널,
       SUM(discovery = influence)  AS 일치,
       SUM(discovery <> influence) AS 불일치,
       COUNT(*) AS n
FROM channel_scored
WHERE discovery IN ('SNS', '유튜브', '친구/지인')
GROUP BY discovery;


-- name: platform_group_dist | 멀티호밍 분포 (GROUP BY)
SELECT platform_group, COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM channel_scored
GROUP BY platform_group;


-- name: platform_group_by_nps | 멀티호밍 × NPS 세그먼트 카운트 (GROUP BY)
SELECT platform_group, nps_segment, COUNT(*) AS n
FROM channel_scored
GROUP BY platform_group, nps_segment;
