# 설문 변수 Reference

> 최종 분석 02→03→04의 문항·분모 정의.

---

## 모수 정의

`final_survey`와 `final_survey_semantic`은 정제 응답 266행을 유지한다. 분석 모수는 `final_survey_semantic`의 플래그로 선택한다.

| 그룹 | n | 조건 |
|------|---|------|
| 전체 응답자 | 266 | 원본 269건 중 논리 모순 3건 제외 |
| 플랫폼 사용자 | 200 | `is_platform_user = 1` (`uses_platform = '예'`) |
| 구매자 | 191 | `is_buyer = 1` |
| 유효 자유응답 | 92 | `is_valid_q18 = 1` |
| 공통 3채널 인지자 | 155 | 플랫폼 사용자·유효 NPS·`discovery_label`이 SNS·유튜브·친구/지인 |

---

## 변수 표

| Q | 컬럼 | 타입 | 응답수 | 단일/다중 | 비고 |
|---|------|------|--------|----------|------|
| - | `user_id` | int PK | 266 | - | 익명 응답자 ID. timestamp 정렬 후 1-266 부여 |
| - | `timestamp` | datetime | 266 | - | 설문 응답 제출 시각 |
| Q1 | `gender` | object | 266 | 단일 | 응답자 성별 |
| Q2 | `age` | object | 266 | 단일 | 응답자 연령대 |
| Q3 | `content_freq` | category(순서) | 266 | 단일 | 패션 콘텐츠 탐색 빈도 |
| Q4 | `monthly_spend` | category(순서) | 266 | 단일 | 월평균 패션 관련 지출 구간 |
| Q5 | `uses_platform` | object | 266 | 단일 | 온라인 패션 플랫폼 사용 여부. 예/아니오 → 모수 분기점 |
| Q6 | `platforms` | object | 200 | **다중(쉼표)** | 사용 중인 온라인 패션 플랫폼. 1-2개 선택, 정규화 완료 |
| Q7 | `selection_factors` | object | 200 | **다중(쉼표)** | 플랫폼 선택 시 중요하게 보는 요인. 최대 3개 |
| Q8 | `open_purpose` | object | 200 | **다중(쉼표)** | 패션 플랫폼을 여는 주된 목적. 최대 2개 |
| Q9 | `purchase_count` | category(순서) | 200 | 단일 | 최근 6개월 내 플랫폼 구매 횟수. 4단계, '구매하지 않음' 포함 |
| Q10 | `last_purchase` | category(순서) | 191 | 단일 | 최근 구매 시점. `recency_score` 산출에 사용 |
| Q11 | `avg_spend` | category(순서) | 191 | 단일 | 자기보고 1회 평균 구매 금액 |
| Q12 | `repurchase_reason` | object | 191 | **다중(쉼표)** | 재구매 이유. 최대 2개 |
| Q13 | `dissatisfaction` | object | 200 | **다중(쉼표)** | 플랫폼 이용 시 불만족 요인. 비구매자도 응답 가능 |
| Q14 | `continue_use` | category(순서) | 200 | 단일 | 향후 플랫폼 계속 사용 의향 |
| Q15 | `nps` | Int64 | 200 | 단일 | 추천 의향 점수(0-10). 분류는 [02 SQL](../sql/02_data_preparation.sql) |
| Q16 | `discovery` | object | 200 | 단일 | 플랫폼 인지 경로. 원문을 보존하고 SQL에서 `discovery_label` 생성 |
| Q17 | `influence` | object | 200 | 단일 | 최근 구매에 가장 영향을 줬다고 답한 채널 |
| Q18 | `feedback` | object | 93 | 텍스트 | 자유응답 개선 의견. 비결측 93건 중 질문 비답변 1건 제외 후 유효 92건 사용 |

---

## 순서형 변수 카테고리 (정렬 순)

> 아래 값은 DB에 저장된 원본 문자열이다. SQL `CASE WHEN`이나 pandas 매핑에서 그대로 사용해야 매칭된다. 설명 텍스트로 언급할 때만 `~` 대신 `-`를 사용한다.

### content_freq (Q3)
`전혀 찾아보지 않는다` < `가끔 본다` < `보통이다` < `자주 본다` < `매우 자주 본다`

### monthly_spend (Q4)
`5만원 미만` < `5~10만원` < `10~20만원` < `20~30만원` < `30만원 이상`

### purchase_count (Q9) → frequency_score
| 값 | 점수 |
|---|---|
| 구매하지 않음 | - (구매자 모수 제외) |
| 1~2번 | 1 |
| 3~5번 | 2 |
| 6번 이상 | 3 |

### last_purchase (Q10) → recency_score
| 값 | 점수 |
|---|---|
| 6개월 이상 | 1 |
| 3~6개월 | 2 |
| 1~3개월 | 3 |
| 1개월 이내 | 4 |

### continue_use (Q14)
`다른 앱으로 바꿀 것 같다` < `아마 사용하지 않을 것 같다` < `잘 모르겠다` < `아마 사용할 것 같다` < `계속 사용할 것 같다`

---

## 다중응답 변수

- **분모**: 응답자 수 (% of respondents). 합이 100%를 넘는 게 정상
- **현재 분석 범위**: 항목별 응답자 비율의 기술통계만 수행. 복수 선택 항목을 서로 독립인 관측치로 취급하지 않음
- **분모 명시**: 셀 도입부에 "구매자 191명 중", "Q12 응답자 191명 중" 등 표기

---

## DB 스키마

- `final_survey` (PK: user_id, 266행) — 최종 02에서 정제·적재
- `final_survey_semantic` (VIEW, 266행) — 최종 02 SQL의 모수·점수 정의
- `final_q18_labels` — 유효 자유응답 92건의 확정 다중 라벨
- `final_etl_audit` — 원본·제외 응답 수

최종 분석 실행 순서: `notebooks/02_data_preparation.ipynb` → `03_data_overview.ipynb` → `04_eda_validation.ipynb`.

### 최종 분석 뷰의 주요 파생 컬럼

| 역할 | 컬럼 |
|---|---|
| 모수 플래그 | `is_platform_user`, `is_buyer`, `is_valid_q18` |
| 태도 | `nps_segment`, `continue_score`, `is_retain_positive` |
| 자기보고 구매 점수 | `frequency_score`, `recency_score` |
| 채널 | `discovery_label`, `influence_label` |
| 복수 플랫폼 구분 | `platform_count` |

---

## 자주 헷갈리는 함정

- `nps IS NOT NULL` = 사용자 200명 (Q5='예'와 동치)
- `purchase_count != '구매하지 않음'` = 구매자 191명 (사용자 모수 한정)
- Q13(dissatisfaction)은 **비구매자도 응답** — '구매 경험 자체가 없음' 선택 가능
- Q11(1회) vs Q4(월 평균) — 단위 혼동 주의
- `platforms` 정규화: 'LOOKPIN'→'룩핀', 'Shein'→'쉬인', '자라 룩핀' → 2개 항목 분리, '종합 쇼핑몰 (쿠팡, 네이버 쇼핑, 테무, 알리익스프레스 등)'은 선택지 내부 쉼표 때문에 split 전 placeholder 치환
- 카테고리 값에 `~` 포함 — SQL/매핑에서 `-`로 쓰면 매칭 안 됨
