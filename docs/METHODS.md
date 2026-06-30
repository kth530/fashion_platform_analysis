# 통계·방법론 레퍼런스 (METHODS)

`notebooks/`의 분석에서 반복 사용하는 통계 검정·해석 기준을 모은 문서다. 노트북 본문은 결과·해석에 집중하고, 검정 선택·가정·효과 크기 기준 등 방법론은 이 문서를 참조한다.

> 세그먼트·R×F·RFM 정의는 [docs/segments.md](segments.md), 변수·모수 정의는 [docs/variables.md](variables.md).

---

## 검정 선택 기준

| 검정 | 변수 조합 | 노트북 사용처 |
|------|----------|--------------|
| 카이제곱 + Cramér's V | 범주형 × 범주형 | 03 NPS×의향, 04·06 인구통계/채널 |
| 스피어만 + ρ | 순서형 × 순서형 | 03 NPS×콘텐츠/지출, 04 의향/NPS×행동 |
| 만-휘트니 U + rank-biserial | 순서/연속형 × 2집단 | 06 멀티호밍×NPS/구매빈도 |
| (검정 부적합) | 다중응답 변수 | 03 Q12·Q13, 04 Q7 — 응답자 단위 독립 가정 위반 |

---

## 카이제곱 (Pearson's chi-squared)

- **가정**: 기대빈도 5 미만 셀이 전체의 20%를 넘으면 카이제곱 분포 근사가 불안정해진다 ([Wikipedia: Assumptions](https://en.wikipedia.org/wiki/Pearson%27s_chi-squared_test#Assumptions), 원전 Cochran 1954).
- **위반 시**: 의미상 가까운 인접 범주를 병합해 재검정하고, 원본 검정은 보조 결과로 제시한다. (예: 03 가설 2에서 5개 의향 → `잔류/비잔류` 2범주 병합)
- **자유도 구분**: `df` = 검정 자유도 `(행-1)(열-1)`. `df*` = Cramér's V 효과 크기 해석 기준값 `min(행-1, 열-1)`.
- **효과 크기 (Cramér's V, Cohen 1988, df*별)**:
  - df*=1: 0.10 / 0.30 / 0.50 (small / medium / large)
  - df*=2: 0.07 / 0.21 / 0.35
- 최종 해석은 p-value보다 **실제 응답 비율 + 효과 크기 + 분석 맥락**을 중심으로 한다.

### 조정 표준화잔차 (Haberman 1973)

셀별 기여도를 보는 표준 지표. 공식: `(O − E) / √(E × (1−행비율) × (1−열비율))`.

- `z` 양수 = 기대보다 많은 응답, 음수 = 기대보다 적은 응답.
- `|z| > 1.96` (95%)이면 해당 셀이 전체 카이제곱 결과에 상대적으로 크게 기여한 것으로 본다.
- 기대빈도가 작은 표에서는 확정 판정보다 **방향성 확인용**으로 읽는다.

---

## 스피어만 순위 상관 (Spearman ρ)

- 순서형 × 순서형, 또는 비정규 연속형에 사용. 검정 전 `dropna()` 후 실제 n을 명시한다.
- **강도 구간** ([Schober et al., 2018](https://journals.lww.com/anesthesia-analgesia/Fulltext/2018/05000/Correlation_Coefficients__Appropriate_Use_and.50.aspx)):
  - 0.00–0.10 Negligible / 0.10–0.39 Weak / 0.40–0.69 Moderate / 0.70–0.89 Strong / 0.90–1.00 Very strong
- p-value보다 상관 방향과 효과 크기를 중심으로 해석한다.

---

## 만-휘트니 U (Mann-Whitney U)

- 두 독립 집단의 순서/연속형 분포 비교 (정규성 가정 없는 비모수 검정).
- 효과 크기 rank-biserial r: `1 − 2U/(n1·n2)` ([Wikipedia](https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test#Rank-biserial_correlation)).
- |r| 해석 구간(0.10 / 0.30 / 0.50, small/medium/large)은 Cohen의 r 관례를 차용한 기준이다 (실무 정리 예: [Metricgate](https://metricgate.com/docs/rank-biserial-correlation/)).

---

## NPS 용어 (스케일 혼동 방지)

- **NPS Score** = Promoter% − Detractor% (범위 −100 ~ +100).
- **평균 추천점수(0-10)** / **NPS 원점수 평균** = Q15 원점수 평균 (0-10).
- 🚫 "평균 NPS Score" 같은 혼합 표현 금지.
- 세그먼트: Promoter 9-10 / Passive 7-8 / Detractor 0-6.

---

## 다중응답 문항 원칙

- Q4(플랫폼)·Q7(선택 요인)·Q12(재구매 이유)·Q13(불만족) 등은 한 응답자가 복수 선택 → 항목 간 독립 가정 위반.
- 통계 검정 대신 **응답자 기준 비율 비교(기술통계)** 만 한다. 분모는 응답자 수, 합은 100%를 넘을 수 있다.
