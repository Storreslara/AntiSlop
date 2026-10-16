#!/usr/bin/env python3
"""Blind the judgment-graded item (E1: does ASSUMPTIONS.md cite the glossary?).

  blind.py build RESULTS_JSONL OUT_DIR [--eval e01-ambiguous-tax]
  blind.py unseal OUT_DIR GRADES_CSV

build writes OUT_DIR/blind/<random-id>/{diff.patch,report.md}, a grades template,
and the id-to-arm map in OUT_DIR/sealed-map.json (outside blind/, never opened by
the grader). unseal joins the graded csv to the map and prints one tally per arm.
"""
import argparse
import csv
import json
import os
import re
import secrets
import sys

PERSONAS = r"orchestrator|spec-master|task-master|lead-programmer|reviewer|scribe|explorer|milestone-auditor|researcher|agent-auditor"
REDACT = [
    (re.compile(rf"\b(?:{PERSONAS})\b", re.IGNORECASE), "[agent]"),
    (re.compile(r"^Unit: .*$", re.MULTILINE), "[line removed]"),
    (re.compile(r"^STATUS: .*$", re.MULTILINE), "[line removed]"),
    (re.compile(r"\([A-Za-z0-9]+(?:-[A-Za-z0-9._#]+)+\)"), "(scope)"),
]
DROP = (re.compile(r"\.(pass|fail)$"), re.compile(r"^\.claude/"), re.compile(r"^docs/plans/"))


def redact(text):
    for pattern, repl in REDACT:
        text = pattern.sub(repl, text)
    return text


def filter_diff(diff):
    keep, drop = [], False
    for chunk in re.split(r"(?m)^(?=diff --git )", diff):
        m = re.match(r"diff --git a/(\S+) b/", chunk)
        if m and any(p.search(m.group(1)) for p in DROP):
            continue
        keep.append(chunk)
    return "".join(keep)


def build(rows_path, out, eval_id):
    with open(rows_path) as f:
        rows = [json.loads(l) for l in f if l.strip()]
    rows = [r for r in rows if r["eval_id"] == eval_id and r["completion_status"] != "usage-limit"]
    blind_dir = os.path.join(out, "blind")
    os.makedirs(blind_dir, exist_ok=True)
    sealed, used = {}, set()
    for r in rows:
        while True:
            item = secrets.token_hex(4)
            if item not in used:
                used.add(item)
                break
        run_dir = os.path.dirname(r["artifacts"]["stream"])
        with open(r["artifacts"]["diff"]) as f:
            diff = filter_diff(f.read())
        with open(os.path.join(run_dir, "summary.json")) as f:
            text = json.load(f).get("result_text") or ""
        item_dir = os.path.join(blind_dir, item)
        os.makedirs(item_dir)
        with open(os.path.join(item_dir, "diff.patch"), "w") as f:
            f.write(diff)
        with open(os.path.join(item_dir, "report.md"), "w") as f:
            f.write(redact(text) + "\n")
        sealed[item] = {"run_id": r["run_id"], "arm": r["arm"]}
    with open(os.path.join(out, "sealed-map.json"), "w") as f:
        json.dump(sealed, f, indent=2, sort_keys=True)
        f.write("\n")
    with open(os.path.join(out, "grades-template.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "assumptions_cites_glossary"])
        for item in sorted(sealed):
            w.writerow([item, ""])
    print(f"blind: wrote {len(sealed)} items to {blind_dir}; map sealed at {os.path.join(out, 'sealed-map.json')}")
    return 0


def unseal(out, grades_path):
    with open(os.path.join(out, "sealed-map.json")) as f:
        sealed = json.load(f)
    tally = {"A": [0, 0], "B": [0, 0]}
    ungraded = 0
    with open(grades_path, newline="") as f:
        for row in csv.DictReader(f):
            grade = (row.get("assumptions_cites_glossary") or "").strip()
            if grade not in ("0", "1"):
                ungraded += 1
                continue
            arm = sealed[row["id"]]["arm"]
            tally[arm][1] += 1
            tally[arm][0] += int(grade)
    print(f"unsealed: A assumptions_cites_glossary={tally['A'][0]}/{tally['A'][1]} "
          f"B assumptions_cites_glossary={tally['B'][0]}/{tally['B'][1]} ungraded={ungraded}")
    return 0


def main(argv):
    ap = argparse.ArgumentParser(prog="blind.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("rows")
    b.add_argument("out")
    b.add_argument("--eval", default="e01-ambiguous-tax")
    u = sub.add_parser("unseal")
    u.add_argument("out")
    u.add_argument("grades")
    a = ap.parse_args(argv)
    if a.cmd == "build":
        return build(a.rows, a.out, a.eval)
    return unseal(a.out, a.grades)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
