# SQL 중심 워크플로

03~07 분석은 추출·점수화·분류·집계 같은 로직을 **노트북당 SQL 파일 1개**(`sql/NN_*.sql`)에 모으고, 노트북은 그 결과를 받아 **시각화·통계 검정·해석**을 담당한다. 한 `.sql` 파일 안에서 각 쿼리를 `-- name:` 마커로 구분하고(상단에 "Skills used" 헤더), 노트북은 쿼리를 이름으로 호출한다.

---

## 왜 이렇게 했나

현업 데이터 분석은 보통 다음 순서로 흐른다.

```
문제 정의 → 지표 합의 → SQL로 추출·집계 → (SQL로 안 되는 것만) Python → 시각화 → 의사결정
```

데이터가 웨어하우스에 있고 규모가 커서 **집계·조인·분류를 SQL에서 끝내고 줄어든 결과만 Python으로** 가져온다. 즉 SQL이 "데이터 로딩 단계"가 아니라 **분석의 본체**다.

**원칙: SQL이 할 일만 SQL로.** 집계·분류·조인·윈도우는 SQL로, 통계 검정(카이제곱·스피어만·만-휘트니)·다중응답 explode·한국어 텍스트(NLP)는 pandas/scipy로 둔다. 각 노트북의 `### 결과` 아래 `_사용 SQL: ..._` 태그가 어떤 쿼리·기법으로 산출했는지 보여준다.

---

## 노트북이 쿼리를 부르는 방식

```python
import re
def load_queries(path):
    body = Path(path).read_text(encoding='utf-8')
    parts = re.split(r'(?m)^--\s*name:\s*(\w+).*$', body)   # `-- name: 이름 | 설명`
    return {parts[i]: parts[i + 1].strip() for i in range(1, len(parts), 2)}

Q = load_queries('../sql/05_segmentation.sql')
seg = pd.read_sql(Q['segment_counts'], engine)   # 이름으로 호출
```

DDL(뷰·테이블 생성)은 세미콜론 단위로 분리해 `execute()`로 실행한다.

---

## 노트북별 SQL / pandas 분담

| 노트북 | SQL 쿼리 | pandas로 남긴 것 |
|--------|---------|----------------|
| `03_nps` | 7 | 카이제곱+조정잔차, 다중응답 3종, 스피어만 |
| `04_retention_and_behavior` | 7 | 스피어만, 다중응답(Q7), 카이제곱 |
| `05_segmentation` | 10 | — |
| `06_channel` | 11 | 카이제곱, 만-휘트니 U |
| `07_text_analysis` | 3 | 형태소(Okt)·키워드·카테고리·워드클라우드 전부 |

> `02_eda`는 분포·다중응답 위주라 Python(원본)을 유지하고, `00`(요약)·`01`(ETL 적재)은 이 패턴 대상이 아니다.

### 사용한 SQL 기법 (누적)

CASE WHEN 다단 분류 · VIEW / CREATE TABLE AS · PK + FK 제약 · GROUP BY 집계 · 조건부 집계(SUM) · 윈도우 함수(`OVER`, `PARTITION BY`) · JOIN · CTE(`WITH`) · `RANK() OVER` · UNION ALL

---

## 실행

각 노트북을 `Restart & Run All` 하면 `load_queries`로 `sql/NN_*.sql`을 읽어, 뷰·테이블을 만든 뒤 집계 쿼리를 이름으로 호출한다. DB 연결은 프로젝트 루트 `.env`. 통계 검정 방법론은 [METHODS.md](METHODS.md) 참조.

> `07_text_analysis`만 KoNLPy(Okt) 형태소 분석을 쓰므로 `.env`의 `JAVA_HOME` + `konlpy`·`wordcloud` 설치가 필요하다.
