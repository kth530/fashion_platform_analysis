# 설문 변수 Reference

> 01_cleaning.ipynb 결과의 단일 진실 소스. 세그먼트 분류는 [segments.md](segments.md).

---

## 모수 정의 (전 노트북 공통)

| 그룹 | n | 조건 |
|------|---|------|
| 전체 응답자 | 266 | cleaning 후 (논리 모순 3건 제외) |
| 플랫폼 사용자 | 200 | `uses_platform = '예'` (= nps IS NOT NULL) |
| 구매자 | 191 | 사용자 중 `purchase_count != '구매하지 않음'` |

---

## 변수 표

| Q | 컬럼 | 타입 | 응답수 | 단일/다중 | 비고 |
|---|------|------|--------|----------|------|
| - | `user_id` | int PK | 266 | - | timestamp 정렬 후 1-266 부여 |
| - | `timestamp` | datetime | 266 | - | 응답 시각 |
| Q1 | `gender` | object | 266 | 단일 | 남성/여성 |
| Q2 | `age` | object | 266 | 단일 | 연령대 |
| Q3 | `content_freq` | category(순서) | 266 | 단일 | 5단계 |
| Q4 | `monthly_spend` | category(순서) | 266 | 단일 | 5단계 (월 지출) |
| Q5 | `uses_platform` | object | 266 | 단일 | 예/아니오 → 모수 분기점 |
| Q6 | `platforms` | object | 200 | **다중(쉼표)** | 1-2개 선택, 정규화 완료 |
| Q7 | `selection_factors` | object | 200 | **다중(쉼표)** | 최대 3개 |
| Q8 | `open_purpose` | object | 200 | **다중(쉼표)** | 최대 2개 |
| Q9 | `purchase_count` | category(순서) | 200 | 단일 | 4단계, '구매하지 않음' 포함 |
| Q10 | `last_purchase` | category(순서) | 191 | 단일 | 4단계 (R) |
| Q11 | `avg_spend` | category(순서) | 191 | 단일 | 5단계 (M) |
| Q12 | `repurchase_reason` | object | 191 | **다중(쉼표)** | 최대 2개 |
| Q13 | `dissatisfaction` | object | 200 | **다중(쉼표)** | 비구매자도 응답 가능 |
| Q14 | `continue_use` | category(순서) | 200 | 단일 | 5단계 |
| Q15 | `nps` | Int64 | 200 | 단일 | 0-10 점수 → 분류는 [segments.md](segments.md) |
| Q16 | `discovery` | object | 200 | 단일 | 인지 경로, 자유입력성 응답 정규화 완료 |
| Q17 | `influence` | object | 200 | 단일 | 구매 영향 채널 |
| Q18 | `feedback` | object | 93 | 텍스트 | DB 비결측 93건. 07 텍스트 분석은 질문 비답변 1건을 제외한 유효 응답 92건 사용 |

---

## 순서형 변수 카테고리 (정렬 순)

> 아래 값은 DB에 저장된 원본 문자열이다. SQL `CASE WHEN`이나 pandas 매핑에서 그대로 사용해야 매칭된다. 설명 텍스트로 언급할 때만 `~` 대신 `-`를 사용한다.

### content_freq (Q3)
전혀 찾아보지 않는다 < 가끔 본다 < 보통이다 < 자주 본다 < 매우 자주 본다

### monthly_spend (Q4)
5만원 미만 < 5~10만원 < 10~20만원 < 20~30만원 < 30만원 이상

### purchase_count (Q9) → F 점수
| 값 | F |
|---|---|
| 구매하지 않음 | - (구매자 모수 제외) |
| 1~2번 | 1 |
| 3~5번 | 2 |
| 6번 이상 | 3 |

### last_purchase (Q10) → R 점수
| 값 | R |
|---|---|
| 6개월 이상 | 1 |
| 3~6개월 | 2 |
| 1~3개월 | 3 |
| 1개월 이내 | 4 |

### avg_spend (Q11) → M 점수
| 값 | M |
|---|---|
| 3만원 미만 | 1 |
| 3~7만원 | 2 |
| 7~15만원 | 3 |
| 15~30만원 | 4 |
| 30만원 이상 | 5 |

### continue_use (Q14)
다른 앱으로 바꿀 것 같다 < 아마 사용하지 않을 것 같다 < 잘 모르겠다 < 아마 사용할 것 같다 < 계속 사용할 것 같다

---

## 다중응답 변수

- **분모**: 응답자 수 (% of respondents). 합이 100%를 넘는 게 정상
- **통계 검정 부적합** — 응답자 단위 독립 가정 위반. 기술통계 비율 비교만
- **분모 명시**: 셀 도입부에 "구매자 191명 중", "Q12 응답자 191명 중" 등 표기

---

## DB 스키마

- `survey` (PK: user_id, 266행, 위 20컬럼) — 01_cleaning에서 적재 완료
- `rfm_seg` (PK + FK→survey, 구매자 191명 대상) — 05에서 생성 완료

---

## 자주 헷갈리는 함정

- `nps IS NOT NULL` = 사용자 200명 (Q5='예'와 동치)
- `purchase_count != '구매하지 않음'` = 구매자 191명 (사용자 모수 한정)
- Q13(dissatisfaction)은 **비구매자도 응답** — '구매 경험 자체가 없음' 선택 가능
- Q11(1회) vs Q4(월 평균) — 단위 혼동 주의
- `platforms` 정규화: 'LOOKPIN'→'룩핀', 'Shein'→'쉬인', '자라 룩핀' → 2개 항목 분리, '종합 쇼핑몰 (쿠팡, 네이버 쇼핑, 테무, 알리익스프레스 등)'은 선택지 내부 쉼표 때문에 split 전 placeholder 치환
- 카테고리 값에 `~` 포함 — SQL/매핑에서 `-`로 쓰면 매칭 안 됨
