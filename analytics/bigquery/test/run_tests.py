#!/usr/bin/env python3
"""검증 쿼리를 검증한다.

GA4 export·Firestore changelog와 같은 스키마의 가짜 데이터를 test 데이터 세트에 올리고,
명세의 정상 시나리오(위반 0건이어야 함)와 규칙마다 일부러 심은 위반 1건씩을 섞는다.
그 다음 각 규칙이 "심은 위반만 정확히" 잡는지 확인한다. 정상 데이터를 잡으면 오탐, 심은 걸 놓치면 미탐.

    python3 analytics/bigquery/test/run_tests.py
"""
import json
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import deploy  # noqa: E402

HERE = Path(__file__).resolve().parent
KST = timezone(timedelta(hours=9))
BASE = datetime(2026, 10, 12, 14, 0, tzinfo=KST)  # 로깅 배포(13:00) 이후
RUN_DATE = "2026-10-13"

events: list[dict] = []
changelog: list[dict] = []
_clock = {"session": 0}


# ── GA4 이벤트 생성 ────────────────────────────────────────────
class Session:
    """한 작성 세션의 이벤트를 시간 순서대로 쌓는다. 세션마다 시작 시각을 10분씩 띄운다."""

    def __init__(self, sid, mode="new", entry="review_feed", env="testflight", platform="IOS"):
        self.sid, self.mode, self.entry, self.env, self.platform = sid, mode, entry, env, platform
        self.t = BASE + timedelta(minutes=10 * _clock["session"])
        _clock["session"] += 1

    def ev(self, name, at=None, offset_sec=5, **params):
        ts = at or self.t
        self.t = max(self.t, ts) + timedelta(seconds=3)
        common = {"write_session_id": self.sid, "mode": self.mode, "entry_point": self.entry}
        events.append({
            "event_date": ts.strftime("%Y%m%d"),
            "event_timestamp": int(ts.timestamp() * 1_000_000),
            "event_name": name,
            "event_params": [
                {"key": k, "value": {"int_value": v} if isinstance(v, int) else {"string_value": v}}
                for k, v in {**common, **params}.items() if v is not None
            ],
            "user_properties": [{"key": "build_env", "value": {"string_value": self.env}}],
            "user_pseudo_id": f"device-{self.env}",
            "platform": self.platform,
            "app_info": {"id": "com.nibpen.nibpen", "version": "1.0.0"},
            "event_server_timestamp_offset": offset_sec * 1_000_000,
        })
        return self

    # 자주 쓰는 동작
    def view(self, **kw): return self.ev("review_write_view", prefilled_product_type="none", **kw)
    def start(self, first="title", **kw): return self.ev("review_write_start", first_input=first, since_view_ms=1000, **kw)
    def photo(self, n, after, source="gallery"): return self.ev("review_photo_add", source=source, added_count=n, photo_count_after=after)
    def remove(self, after): return self.ev("review_photo_remove", photo_count_after=after)
    def attempt(self, no, photos, **kw):
        return self.ev("review_submit_attempt", attempt_no=no, photo_count=photos, title_len=3,
                       body_len=10, ink_tag_count=1, pen_tag_count=0, **kw)
    def blocked(self, no): return self.ev("review_submit_blocked", attempt_no=no, reason="no_photo")
    def fail(self, no, stage="image_upload"): return self.ev("review_submit_fail", attempt_no=no, error_stage=stage, error_type="unknown", elapsed_ms=900)
    def success(self, no, rid, photos): return self.ev("review_submit_success", attempt_no=no, review_id=rid, photo_count=photos, elapsed_ms=1200)
    def exit(self, stage, had=1, **kw): return self.ev("review_write_exit", last_stage=stage, had_content=had, since_view_ms=5000, **kw)

    def happy(self, rid, photos=1):
        """명세 S1: 진입 → 시작 → 사진 → 시도 → 성공"""
        return self.view().start().photo(photos, photos).attempt(1, photos).success(1, rid, photos)


# ── Firestore changelog 생성 ───────────────────────────────────
def fs(rid, photos, created=None, op="CREATE", changed=None):
    created = created or BASE
    data = {
        "authorId": "user-1",
        "title": "테스트",
        "imageUrls": [f"https://example.com/{rid}/{i}.jpg" for i in range(photos)],
        "createdAt": {"_seconds": int(created.timestamp()), "_nanoseconds": 0},
    }
    changelog.append({
        "timestamp": (changed or created).astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
        "event_id": f"{rid}-{op}-{len(changelog)}",
        "document_name": f"projects/nibpen/databases/(default)/documents/reviews/{rid}",
        "operation": op,
        "data": None if op == "DELETE" else json.dumps(data),
        "old_data": None,
        "document_id": rid,
    })


def build_fixtures() -> dict[str, set[str]]:
    """정상 시나리오 + 규칙별 위반 1건. 반환값은 규칙별로 잡혀야 하는 entity_id."""
    # ── 정상: 어떤 규칙에도 걸리면 안 됨 ──
    Session("s_ok1").happy("r_ok1", photos=2); fs("r_ok1", 2)
    # S2: 사진 없이 등록 → 막힘 → 사진 추가 후 재시도
    (Session("s_ok2", entry="home").view().start().attempt(1, 0).blocked(1)
        .photo(1, 1, source="camera").attempt(2, 1).success(2, "r_ok2", 1)); fs("r_ok2", 1)
    # S3: 제품 상세 진입 후 바로 이탈
    Session("s_exit", entry="product_detail").ev("review_write_view", prefilled_product_type="ink").exit("view")
    # S4: 사진부터 추가, 1장 삭제
    (Session("s_ok4").view().start("photo").photo(1, 1, "camera").photo(2, 3).remove(2)
        .attempt(1, 2).success(1, "r_ok4", 2)); fs("r_ok4", 2)
    # S9: 수정 모드 — 같은 review_id로 success가 또 찍히지만 DQ-04 위반이 아님
    (Session("s_edit", mode="edit", entry="review_detail").view().start("photo").photo(1, 3)
        .attempt(1, 3).success(1, "r_ok1", 3)); fs("r_ok1", 3, op="UPDATE", changed=BASE + timedelta(hours=2))
    # 업로드 실패 후 이탈
    Session("s_fail").view().start().photo(1, 1).attempt(1, 1).fail(1).exit("attempted")
    # 작성 후 삭제된 리뷰 — DQ-13(유령 성공)으로 잡히면 안 됨
    Session("s_del").happy("r_del"); fs("r_del", 1); fs("r_del", 0, op="DELETE", changed=BASE + timedelta(hours=1))
    # 디버그 빌드 세션 — 환경별로 따로 집계되는지
    Session("s_debug", env="debug").happy("r_dbg"); fs("r_dbg", 1)
    # 로깅 배포 이전에 만들어진 문서 — DQ-12 대상 아님
    fs("r_old", 1, created=BASE - timedelta(days=1))
    # 확장 설치 전에 만들어져 백필(IMPORT)된 문서 — 로그가 있으면 정상
    Session("s_imported").happy("r_imported"); fs("r_imported", 1, created=BASE + timedelta(minutes=5), op="IMPORT")

    # ── 규칙별로 일부러 심은 위반 ──
    Session("s_dup_view").view().view().exit("view", had=0)                                   # DQ-01
    Session("s_noview").start().photo(1, 1).attempt(1, 1).success(1, "r_noview", 1); fs("r_noview", 1)  # DQ-02
    Session("s_nostart").view().photo(1, 1).attempt(1, 1).success(1, "r_nostart", 1); fs("r_nostart", 1)  # DQ-03
    Session("s_dup_a").happy("r_dup"); Session("s_dup_b").happy("r_dup"); fs("r_dup", 1)      # DQ-04
    Session("s_succ_exit").happy("r_se").exit("attempted"); fs("r_se", 1)                     # DQ-05
    s = Session("s_order")                                                                    # DQ-06
    s.start(at=s.t).view(at=s.t + timedelta(seconds=10)).photo(1, 1).attempt(1, 1).success(1, "r_order", 1); fs("r_order", 1)
    Session("s_pm").happy("r_pm", photos=2); fs("r_pm", 1)                                    # DQ-07
    Session("s_am").view().start().photo(2, 2).attempt(1, 2).success(1, "r_am", 1); fs("r_am", 1)  # DQ-08
    Session("s_ps").view().start().photo(3, 3).attempt(1, 2).success(1, "r_ps", 2); fs("r_ps", 2)  # DQ-09
    Session("s_no_outcome").view().start().photo(1, 1).attempt(1, 1)                          # DQ-10
    Session("s_unknown", entry="unknown").view().exit("view", had=0)                          # DQ-11
    fs("r_orphan", 1, created=BASE + timedelta(hours=3))                                      # DQ-12
    fs("r_orphan_imp", 1, created=BASE + timedelta(hours=3), op="IMPORT")                     # DQ-12 (백필 문서도 검사)
    Session("s_ghost").happy("r_ghost")                                                       # DQ-13
    Session("s_late").view().exit("view", had=0, offset_sec=30 * 3600)                        # DQ-14

    return {
        "DQ-01": {"s_dup_view"},
        "DQ-02": {"s_noview"},
        "DQ-03": {"s_nostart"},
        "DQ-04": {"r_dup"},
        "DQ-05": {"s_succ_exit"},
        "DQ-06": {"s_order"},
        "DQ-07": {"r_pm"},
        "DQ-08": {"s_am"},
        "DQ-09": {"s_ps"},
        "DQ-10": {"s_no_outcome#1"},
        "DQ-11": {"s_unknown"},
        "DQ-12": {"r_orphan", "r_orphan_imp"},
        "DQ-13": {"r_ghost"},
        "DQ-14": {"s_late"},
    }


def load_table(cfg, table, rows, schema):
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as f:
        f.write("\n".join(json.dumps(r, ensure_ascii=False) for r in rows))
    deploy.bq(cfg, ["load", "--replace", "--source_format=NEWLINE_DELIMITED_JSON",
                    f"{cfg['dataset']}.{table}", f.name, str(HERE / schema)])


def main() -> None:
    cfg = deploy.load_config("test")
    expected = build_fixtures()

    print("1) 테스트 데이터 적재")
    deploy.ensure_dataset(cfg)
    dates = sorted({e["event_date"] for e in events})
    for d in dates:
        load_table(cfg, f"events_{d}", [e for e in events if e["event_date"] == d], "ga4_events_schema.json")
    load_table(cfg, "reviews_raw_changelog", changelog, "firestore_changelog_schema.json")
    print(f"  GA4 이벤트 {len(events)}건, Firestore 변경 {len(changelog)}건")

    print("2) 뷰·규칙 배포")
    deploy.deploy(cfg)

    print("3) 규칙별 검증 (심은 위반만 정확히 잡아야 함)")
    rows = deploy.query(cfg, f"SELECT rule_id, entity_id, detail FROM `{cfg['dataset']}.dq_violations`")
    actual: dict[str, set[str]] = {}
    for r in rows:
        actual.setdefault(r["rule_id"], set()).add(r["entity_id"])
    failures = 0
    for rule, want in expected.items():
        got = actual.get(rule, set())
        ok = got == want
        failures += not ok
        note = "" if ok else f"  ← 오탐 {sorted(got - want)} / 미탐 {sorted(want - got)}"
        print(f"  {'✓' if ok else '✗'} {rule}: {sorted(got)}{note}")
    unknown = set(actual) - set(expected)
    if unknown:
        failures += 1
        print(f"  ✗ 테스트에 없는 규칙이 결과에 있음: {sorted(unknown)}")

    print("4) 일일 점검 잡 (두 번 실행해도 결과가 같아야 함)")
    results = []
    for _ in range(2):
        deploy.run_daily(cfg, RUN_DATE)
        results.append(deploy.query(cfg, f"""
            SELECT rule_id, SUM(violation_count) AS n, COUNT(*) AS row_count
            FROM `{cfg['dataset']}.dq_check_results`
            GROUP BY rule_id ORDER BY rule_id"""))
    if results[0] != results[1]:
        failures += 1
        print("  ✗ 재실행 시 결과가 달라짐 (멱등성 위반)")
    for r in results[1]:
        want = len(expected.get(r["rule_id"], ()))
        ok = int(r["n"]) == want
        failures += not ok
        print(f"  {'✓' if ok else '✗'} {r['rule_id']}: 위반 {r['n']}건 (기대 {want}), 결과 행 {r['row_count']}개")

    print("5) 0건의 의미 (규칙이 실제로 검사하는 환경에만 결과 행이 있어야 함)")
    misplaced = deploy.query(cfg, f"""
        SELECT c.rule_id, c.build_env
        FROM `{cfg['dataset']}.dq_check_results` AS c
        JOIN `{cfg['dataset']}.dq_rules` AS r USING (rule_id)
        WHERE (r.env_scope = 'none') != (c.build_env = 'n/a')""")
    if misplaced:
        failures += 1
        print(f"  ✗ 검사하지 않는 환경에 0건이 채워짐: {misplaced}")
    else:
        print("  ✓ Firestore 규칙(DQ-12)은 n/a에만, 나머지 규칙은 빌드 환경에만 집계됨")

    print("\n" + ("모든 검증 통과" if not failures else f"실패 {failures}건"))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
