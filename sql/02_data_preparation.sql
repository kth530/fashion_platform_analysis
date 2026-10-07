/*
  02 전처리·ETL 이후의 최종 분석용 뷰.
  02 notebook이 원본 CSV를 정제해 MySQL final_survey에 적재한다.
  데이터 개요와 H1·H2·Q13·Q18에 필요한 모수·점수 정의를 제공한다.
*/

-- name: semantic_view | 최종 분석에 필요한 모수·점수
CREATE OR REPLACE VIEW final_survey_semantic AS
SELECT s.user_id, s.gender, s.age, s.uses_platform, s.platforms,
       s.selection_factors, s.open_purpose, s.purchase_count,
       s.last_purchase, s.dissatisfaction, s.continue_use, s.nps, s.feedback,
       CASE WHEN s.platforms IS NULL THEN 0
            ELSE 1 + LENGTH(s.platforms) - LENGTH(REPLACE(s.platforms, ',', ''))
       END AS platform_count,
       CASE WHEN s.uses_platform = '예' THEN 1 ELSE 0 END AS is_platform_user,
       CASE WHEN s.uses_platform = '예'
                 AND s.purchase_count IN ('1~2번', '3~5번', '6번 이상')
            THEN 1 ELSE 0 END AS is_buyer,
       CASE WHEN s.feedback IS NOT NULL
                 AND TRIM(s.feedback) <> '패션 앱을 자주 사용하지 않음'
            THEN 1 ELSE 0 END AS is_valid_q18,
       CASE WHEN s.nps BETWEEN 0 AND 6 THEN 'Detractor'
            WHEN s.nps BETWEEN 7 AND 8 THEN 'Passive'
            WHEN s.nps BETWEEN 9 AND 10 THEN 'Promoter'
            ELSE NULL END AS nps_segment,
       CASE s.continue_use
            WHEN '다른 앱으로 바꿀 것 같다' THEN 1
            WHEN '아마 사용하지 않을 것 같다' THEN 2
            WHEN '잘 모르겠다' THEN 3
            WHEN '아마 사용할 것 같다' THEN 4
            WHEN '계속 사용할 것 같다' THEN 5
            ELSE NULL END AS continue_score,
       CASE WHEN s.continue_use IN ('아마 사용할 것 같다', '계속 사용할 것 같다')
            THEN 1 ELSE 0 END AS is_retain_positive,
       CASE s.purchase_count
            WHEN '1~2번' THEN 1 WHEN '3~5번' THEN 2
            WHEN '6번 이상' THEN 3 ELSE NULL END AS frequency_score,
       CASE s.last_purchase
            WHEN '6개월 이상' THEN 1 WHEN '3~6개월' THEN 2
            WHEN '1~3개월' THEN 3 WHEN '1개월 이내' THEN 4
            ELSE NULL END AS recency_score,
       CASE WHEN s.discovery LIKE '인스타그램%' THEN 'SNS'
            WHEN s.discovery = '친구 / 지인 추천' THEN '친구/지인'
            ELSE s.discovery END AS discovery_label,
       CASE WHEN s.influence LIKE '인스타그램%' THEN 'SNS'
            WHEN s.influence = '친구 / 지인 추천' THEN '친구/지인'
            WHEN s.influence = '앱 내 추천 상품' THEN '앱 내 추천'
            WHEN s.influence = '앱 푸시 알림 / 쿠폰' THEN '앱 푸시/쿠폰'
            ELSE s.influence END AS influence_label
FROM final_survey s;

-- name: population | 전처리 실행 기록과 SQL 분석 집단
SELECT a.raw_n AS raw,
       (SELECT COUNT(*) FROM final_survey_semantic) AS cleaned,
       (SELECT COUNT(*) FROM final_survey_semantic WHERE is_platform_user = 1) AS platform_users,
       (SELECT COUNT(*) FROM final_survey_semantic WHERE is_buyer = 1) AS buyers,
       (SELECT COUNT(*) FROM final_survey_semantic WHERE is_valid_q18 = 1) AS valid_q18,
       (SELECT COUNT(*) FROM final_survey_semantic
         WHERE is_valid_q18 = 1 AND is_platform_user = 1) AS platform_user_q18,
       (SELECT COUNT(DISTINCT user_id) FROM final_q18_labels) AS labeled_q18
FROM final_etl_audit a;
