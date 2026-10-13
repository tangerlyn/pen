#!/usr/bin/env python3
"""리뷰 작성 로그 데이터 품질 레이어를 BigQuery에 배포한다.

    python3 analytics/bigquery/deploy.py --env prod                 # 뷰·규칙·결과 테이블 배포
    python3 analytics/bigquery/deploy.py --env prod --run 2026-10-13  # 일일 점검 1회 실행
    python3 analytics/bigquery/deploy.py --env prod --schedule        # 일일 점검 예약 쿼리 등록

구성 (원천 → 정제 → 마트 → 검증):
    GA4 events_* ─┐
                  ├─ stg_review_events ─ mart_review_write_sessions ─ mart_review_funnel_daily
    Firestore ────┘   stg_reviews                                   └ mart_ingest_latency_daily
    changelog                │
                             └──── checks/DQ-*.sql ─ dq_violations ─ (jobs/dq_daily.sql) ─ dq_check_results ─ rpt_dq_daily

검증 규칙은 checks/ 아래 파일 하나가 규칙 하나다. 파일 머리의 주석(rule/dimension/severity/description)이
dq_rules 테이블의 원본이므로, 규칙을 추가할 때는 파일만 추가하면 된다.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
HEADER = re.compile(r"^--\s*(rule|dimension|severity|description|env_scope):\s*(.+)$", re.M)


def load_config(env: str) -> dict:
    return json.loads((ROOT / "config.json").read_text())[env]


def bq(cfg: dict, args: list[str], stdin: str | None = None) -> str:
    cmd = ["bq", f"--project_id={cfg['project']}", f"--location={cfg['location']}", *args]
    result = subprocess.run(cmd, input=stdin, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"bq {' '.join(args[:2])} 실패:\n{result.stdout}\n{result.stderr}")
    return result.stdout


def query(cfg: dict, sql: str, params: list[str] | None = None) -> list[dict]:
    flags = ["query", "--use_legacy_sql=false", "--format=json", "--max_rows=10000"]
    flags += [f"--parameter={p}" for p in params or []]
    out = bq(cfg, flags, stdin=sql).strip()
    # DDL·스크립트는 결과가 비어 있거나 여러 문장의 결과가 이어 붙어 나올 수 있다
    try:
        return json.loads(out) if out.startswith("[") else []
    except json.JSONDecodeError:
        return []


def render(sql: str, cfg: dict) -> str:
    def sub(m: re.Match) -> str:
        key = m.group(1)
        if key not in cfg:
            raise KeyError(f"템플릿 변수 {{{{{key}}}}}에 해당하는 설정이 없음")
        return cfg[key]
    return re.sub(r"\{\{(\w+)\}\}", sub, sql)


def resolve_events_table(cfg: dict) -> str:
    """GA4 export 데이터 세트 이름(analytics_<속성 ID>)은 첫 내보내기 후에야 생기므로 배포 시점에 찾는다."""
    if cfg["events_table"] != "auto":
        return cfg["events_table"]
    datasets = json.loads(bq(cfg, ["ls", "--format=json"]) or "[]")
    ids = [d["datasetReference"]["datasetId"] for d in datasets]
    ga = [i for i in ids if re.fullmatch(r"analytics_\d+", i)]
    if not ga:
        sys.exit("GA4 export 데이터 세트(analytics_*)가 아직 없음. 첫 일별 내보내기 이후 다시 실행하세요.")
    return f"{cfg['project']}.{ga[0]}.events_*"


def load_checks() -> list[dict]:
    checks = []
    for path in sorted((ROOT / "checks").glob("DQ-*.sql")):
        text = path.read_text()
        meta = {k: v.strip() for k, v in HEADER.findall(text)}
        missing = {"rule", "dimension", "severity", "description"} - meta.keys()
        if missing:
            raise ValueError(f"{path.name}: 머리 주석에 {missing} 없음")
        if not path.name.startswith(meta["rule"]):
            raise ValueError(f"{path.name}: 파일명과 rule({meta['rule']})이 다름")
        # env_scope: by_env(기본) = 앱 빌드 환경별로 집계, none = Firestore만 보는 규칙이라 환경 구분 없이 'n/a'로 집계
        meta.setdefault("env_scope", "by_env")
        if meta["env_scope"] not in ("by_env", "none"):
            raise ValueError(f"{path.name}: env_scope는 by_env 또는 none")
        checks.append({**meta, "sql": text})
    return checks


def rules_table_sql(checks: list[dict]) -> str:
    rows = ",\n  ".join(
        "STRUCT({} AS rule_id, {} AS dimension, {} AS severity, {} AS description, {} AS env_scope)".format(
            *(json.dumps(c[k], ensure_ascii=False) for k in ("rule", "dimension", "severity", "description", "env_scope"))
        )
        for c in checks
    )
    return f"CREATE OR REPLACE TABLE `{{{{dataset}}}}.dq_rules` AS\nSELECT * FROM UNNEST([\n  {rows}\n])"


def violations_view_sql(checks: list[dict]) -> str:
    body = "\nUNION ALL\n".join(f"SELECT * FROM (\n{c['sql'].strip()}\n)" for c in checks)
    return f"CREATE OR REPLACE VIEW `{{{{dataset}}}}.dq_violations` AS\n{body}"


def ensure_dataset(cfg: dict) -> None:
    ref = f"{cfg['project']}:{cfg['dataset']}"
    try:
        bq(cfg, ["show", "--format=none", ref])
    except RuntimeError:
        bq(cfg, ["mk", "--dataset", "--description=리뷰 작성 로그 정제·마트·데이터 품질 검증", ref])
        print(f"데이터 세트 생성: {ref}")


def deploy(cfg: dict) -> None:
    cfg = {**cfg, "events_table": resolve_events_table(cfg)}
    ensure_dataset(cfg)
    checks = load_checks()
    steps = [(p.name, p.read_text()) for p in sorted((ROOT / "sql").glob("[12]*.sql"))]
    steps += [
        ("dq_rules", rules_table_sql(checks)),
        ("dq_violations", violations_view_sql(checks)),
        *[(p.name, p.read_text()) for p in sorted((ROOT / "sql").glob("3*.sql"))],
    ]
    for name, sql in steps:
        query(cfg, render(sql, cfg))
        print(f"  ✓ {name}")
    print(f"배포 완료: {cfg['project']}.{cfg['dataset']} (규칙 {len(checks)}개, 원천 {cfg['events_table']})")


def run_daily(cfg: dict, run_date: str) -> None:
    sql = render((ROOT / "jobs" / "dq_daily.sql").read_text(), cfg)
    query(cfg, sql, params=[f"run_date:DATE:{run_date}"])


def schedule(cfg: dict) -> None:
    """매일 KST 12:00 실행. GA4 일별 테이블은 보통 다음 날 오전 중에 도착하므로 그 이후로 잡는다."""
    sql = render((ROOT / "jobs" / "dq_daily.sql").read_text(), cfg)
    bq(cfg, [
        "mk", "--transfer_config",
        "--data_source=scheduled_query",
        "--display_name=review_dq_daily",
        "--schedule=every day 03:00",  # UTC 03:00 = KST 12:00
        "--params=" + json.dumps({"query": sql}),
    ])
    print("예약 쿼리 등록: review_dq_daily (매일 KST 12:00)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--env", choices=["prod", "test"], required=True)
    parser.add_argument("--run", metavar="YYYY-MM-DD", help="일일 점검을 해당 실행일 기준으로 1회 실행")
    parser.add_argument("--schedule", action="store_true", help="일일 점검 예약 쿼리 등록")
    args = parser.parse_args()

    cfg = load_config(args.env)
    if args.run:
        run_daily(cfg, args.run)
        print(f"일일 점검 실행 완료 (run_date={args.run})")
    elif args.schedule:
        schedule(cfg)
    else:
        deploy(cfg)


if __name__ == "__main__":
    main()
