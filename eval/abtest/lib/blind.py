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

PERSONAS = r"orchestrator|spec[- ]master|task[- ]master|lead[- ]programmer|reviewer|scribe|explorer|milestone[- ]auditor|researcher|agent[- ]auditor"
# A Unit: line is dropped only when its value looks like a unit id (letters, then a separator or a digit),
# a STATUS: line only when its value is complete or incomplete; "Unit: percent" and "Price per Unit: $5" stay.
UNIT_ID = r"(?:[A-Za-z]+[-._#][A-Za-z0-9._#-]*|[A-Za-z]+[0-9][A-Za-z0-9._#-]*|#[0-9]+)"
STATUS_VALUE = r"(?:complete|incomplete\b.*)"
REDACT = [
    (re.compile(r"\.claude(?:/\S*[\w/~-])?"), "[path]"),
    (re.compile(rf"^.*\b(?:Unit:\**[ \t]*{UNIT_ID}.*|STATUS:\**[ \t]*{STATUS_VALUE}\W*)$", re.MULTILINE | re.IGNORECASE), "[line removed]"),
    (re.compile(rf"\b(?:{PERSONAS})[A-Za-z]*", re.IGNORECASE), "[agent]"),
    (re.compile(r"\b(?:personas?|pending-review|pathfinder|roast-work|domain-modeling)\b|(?<![A-Za-z])\.?pass markers?\b", re.IGNORECASE), "[term]"),
    (re.compile(r"anti-?slop", re.IGNORECASE), "[tool]"),
    (re.compile(r"\b(?:Arm [AB]|arm-[ab])\b"), "[arm]"),
    (re.compile(r"\b(?:PASS|FAIL) (?=\S*[A-Za-z])\S*\d\S*"), "[marker]"),
    (re.compile(r"\((?:#\d+|[A-Za-z]{1,6}\d+)\)"), "(scope)"),
    (re.compile(r"\([A-Za-z0-9]+(?:-[A-Za-z0-9._#]+)+\)"), "(scope)"),
]
DROP = (re.compile(r"\.(pass|fail)$"), re.compile(r"(^|/)\.claude/"), re.compile(r"^docs/plans/"), re.compile(r"(^|/)docs/(wiki|adr)/"))


def redact(text):
    for pattern, repl in REDACT:
        text = pattern.sub(repl, text)
    return text


def filter_diff(diff):
    keep = []
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
    if not rows:
        print(f"blind: no usable runs of {eval_id} in {rows_path}", file=sys.stderr)
        return 1
    blind_dir = os.path.join(out, "blind")
    if os.path.exists(os.path.join(out, "sealed-map.json")) or (os.path.isdir(blind_dir) and os.listdir(blind_dir)):
        print(f"blind: refusing to build into {out}: it already holds a blind set; use a fresh directory", file=sys.stderr)
        return 1
    os.makedirs(blind_dir, exist_ok=True)
    sealed, items = {}, {}
    for r in rows:
        while True:
            item = secrets.token_hex(4)
            if item not in items:
                items[item] = r
                break
    # Item directories are created in id order, so their timestamps never show the run order.
    for item in sorted(items):
        r = items[item]
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
