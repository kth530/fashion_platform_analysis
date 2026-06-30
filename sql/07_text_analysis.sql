/* =====================================================================
   사용자 자유응답(Q18) 텍스트 분석 (07_text_analysis)

   Skills used:
     CASE WHEN 그룹 라벨링 · 조건부 추출

   대상: Q18 자유응답 응답자 (유효 92건 — Non-User 24·Detractor 31·Passive 30·Promoter 7)
   사용법: 이 노트북의 SQL은 '데이터 추출 + 그룹 라벨링'뿐이다.
           형태소 분석(Okt)·키워드 빈도·카테고리 분류·워드클라우드·NPS×카테고리 교차는
           DB에 없는 파생 결과(nouns/categories)를 만들어 집계하므로 전부 노트북 pandas/NLP다.
           (한국어 텍스트 분석은 SQL 부적합 — 의도된 Python 처리.)
   ===================================================================== */


-- name: feedback_base | Q18 자유응답 + 그룹/NPS 라벨 (CASE WHEN)
-- user_group: Non-User(미사용) / Promoter·Passive·Detractor(사용자 NPS 분류)
SELECT
    user_id, gender, age, uses_platform, platforms, purchase_count, continue_use, nps, feedback,
    CASE WHEN uses_platform = '아니오' THEN 'Non-User'
         WHEN nps >= 9 THEN 'Promoter'
         WHEN nps >= 7 THEN 'Passive'
         WHEN nps IS NOT NULL THEN 'Detractor' END AS user_group,
    CASE WHEN nps >= 9 THEN 'Promoter'
         WHEN nps >= 7 THEN 'Passive'
         WHEN nps IS NOT NULL THEN 'Detractor' END AS nps_segment
FROM survey
WHERE feedback IS NOT NULL
  -- 비해당 응답 1건 제외 → 유효 92건
  AND TRIM(feedback) <> '패션 앱을 자주 사용하지 않음';


-- name: response_base | 그룹별 응답률 base (사용여부 응답자 전체 + feedback)
SELECT
    CASE WHEN uses_platform = '아니오' THEN 'Non-User'
         WHEN nps >= 9 THEN 'Promoter'
         WHEN nps >= 7 THEN 'Passive'
         WHEN nps IS NOT NULL THEN 'Detractor' END AS user_group,
    feedback
FROM survey
WHERE uses_platform IS NOT NULL;


-- name: nonuser_demo | Non-User 인구통계 프로파일 (성별·연령·콘텐츠·지출)
SELECT user_id, gender, age, content_freq, monthly_spend, feedback
FROM survey
WHERE uses_platform = '아니오'
  AND feedback IS NOT NULL
  -- feedback_base와 동일 기준
  AND TRIM(feedback) <> '패션 앱을 자주 사용하지 않음';
