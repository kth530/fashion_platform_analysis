"""
Tableau Public용 CSV 추출 스크립트.

tableau/tableau_views.sql의 VIEW(v_tableau_main, v_tableau_channel)를 MySQL에 생성한 뒤
SELECT 결과를 tableau/ 아래 CSV로 저장한다. Tableau Public은 MySQL 라이브 연결이 안 되므로
이 CSV를 데이터 원본으로 연결한다.

실행: python tableau/export_csv.py   (MySQL 실행 + 루트 .env 필요)
"""
import os
import re
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
SQL_FILE = HERE / 'tableau_views.sql'

load_dotenv(ROOT / '.env')

engine = create_engine(
    f"mysql+mysqlconnector://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}"
    f"@{os.getenv('DB_HOST')}/{os.getenv('DB_NAME')}"
)


def load_queries(path):
    body = Path(path).read_text(encoding='utf-8')
    parts = re.split(r'(?m)^--\s*name:\s*(\w+).*$', body)
    return {parts[i]: parts[i + 1].strip() for i in range(1, len(parts), 2)}


Q = load_queries(SQL_FILE)

# 1) VIEW 생성 (DDL)
with engine.begin() as conn:
    for name in ('create_main_view', 'create_channel_view'):
        for stmt in (s for s in Q[name].split(';') if s.strip()):
            conn.execute(text(stmt))

# 2) VIEW → CSV (utf-8-sig: 한글 깨짐 방지)
exports = {
    'v_tableau_main.csv': 'export_main',
    'v_tableau_channel.csv': 'export_channel',
}
for fname, qname in exports.items():
    df = pd.read_sql(Q[qname], engine)
    out = HERE / fname
    df.to_csv(out, index=False, encoding='utf-8-sig')
    print(f"✓ {out.name}: {len(df)}행 × {df.shape[1]}열")

# 3) 다중응답 long (Q6·Q7·Q12·Q13 explode) — Tableau 다중응답 차트용
#    구분자 ', ' split은 02_eda split_multi_response와 동일 (검증 완료).
mr = pd.read_sql(
    "SELECT user_id, gender, age, nps, purchase_count, "
    "platforms, selection_factors, repurchase_reason, dissatisfaction "
    "FROM survey WHERE uses_platform='예' AND nps IS NOT NULL", engine)
mr['age_group'] = mr['age'].map(
    lambda a: '10-20대 초중반' if a in ('10대', '20대 초중반')
    else ('20대 후반' if a == '20대 후반' else '30대 이상'))
mr['nps_segment'] = mr['nps'].map(
    lambda n: 'Promoter' if n >= 9 else ('Passive' if n >= 7 else 'Detractor'))
mr['is_buyer'] = (mr['purchase_count'] != '구매하지 않음').astype(int)

MR_COLS = {
    'platforms': '플랫폼(Q6)',
    'selection_factors': '선택요인(Q7)',
    'repurchase_reason': '재구매이유(Q12)',
    'dissatisfaction': '불만족(Q13)',
}
parts = []
for col, label in MR_COLS.items():
    e = (mr[['user_id', 'gender', 'age_group', 'nps_segment', 'is_buyer', col]]
         .dropna(subset=[col])
         .assign(value=lambda x: x[col].str.split(', '))
         .explode('value'))
    e['value'] = e['value'].str.strip()
    e['question'] = label
    parts.append(e[['user_id', 'gender', 'age_group', 'nps_segment',
                    'is_buyer', 'question', 'value']])
mr_long = pd.concat(parts, ignore_index=True)
mr_long.to_csv(HERE / 'mr_long.csv', index=False, encoding='utf-8-sig')
print(f"✓ mr_long.csv: {len(mr_long)}행 (Q6·Q7·Q12·Q13 explode)")

# 4) 간단 검증 (docs/segments.md 기준값과 대조)
main = pd.read_sql(Q['export_main'], engine)
nps_score = (main['is_promoter'].sum() - main['is_detractor'].sum()) / len(main) * 100
gap_rate = main['recency_gap_flag'].sum() / main['is_buyer'].sum() * 100
print("\n검증 (기대값):")
print(f"  사용자 행 수      : {len(main)}  (200)")
print(f"  구매자(is_buyer)  : {int(main['is_buyer'].sum())}  (191)")
print(f"  R×F 4분면 합      : {int(main['rf_quadrant'].notna().sum())}  (191)")
print(f"  NPS Score         : {nps_score:.1f}  (≈ -32.0)")
print(f"  구매 공백률       : {gap_rate:.1f}%  (≈ 15.7%)")
