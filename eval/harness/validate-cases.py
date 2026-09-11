#!/usr/bin/env python3
# Validates eval/cases/reviewer-verdict/{gold,grader}/*/case.yaml against
# the registry's suite list. Prints "file: reason" per failure and exits
# non-zero if any case is invalid.
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

import yaml

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GIT_C = ["-c", "user.email=eval@example.com", "-c", "user.name=eval", "-c", "commit.gpgsign=false"]

GOLD_REQUIRED = ["id", "suite", "fixture", "task", "patch", "packet", "gold", "tags"]
GRADER_REQUIRED = ["id", "suite", "gold", "reviewer_message", "expected"]


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--registry", required=True)
    p.add_argument("--suite")
    p.add_argument("--cases-dir")
    return p.parse_args()


def suite_split(suite_id):
    parts = suite_id.split(".")
    return parts[1] if len(parts) >= 2 else None


def find_case_dirs(cases_dir):
    if not os.path.isdir(cases_dir):
        return []
    dirs = []
    for name in sorted(os.listdir(cases_dir)):
        d = os.path.join(cases_dir, name)
        if os.path.isfile(os.path.join(d, "case.yaml")):
            dirs.append(d)
    return dirs


def parse_patch_touched_files(patch_path):
    files = set()
    with open(patch_path) as f:
        for line in f:
            if line.startswith("+++ b/") or line.startswith("--- a/"):
                files.add(line.split("/", 1)[1].strip())
    return files


def patch_applies_cleanly(patch_path, fixture_name):
    fixture_dir = os.path.join(REPO_ROOT, "eval", "fixtures", fixture_name)
    if not os.path.isdir(fixture_dir):
        return False
    with tempfile.TemporaryDirectory() as t:
        shutil.copytree(fixture_dir, t, dirs_exist_ok=True)
        subprocess.run(["git", *GIT_C, "init", "-q"], cwd=t, check=True)
        subprocess.run(["git", *GIT_C, "add", "-A"], cwd=t, check=True)
        subprocess.run(["git", *GIT_C, "commit", "-qm", "base"], cwd=t, check=True)
        result = subprocess.run(
            ["git", "apply", "--check", os.path.abspath(patch_path)],
            cwd=t, capture_output=True,
        )
        return result.returncode == 0


def check_patch(case_dict, case_dir):
    reasons = []
    patch_rel = case_dict.get("patch")
    touched_files = None
    if patch_rel:
        patch_path = os.path.join(case_dir, patch_rel)
        if os.path.isfile(patch_path):
            touched_files = parse_patch_touched_files(patch_path)
            fixture_name = case_dict.get("fixture")
            if fixture_name and not patch_applies_cleanly(patch_path, fixture_name):
                reasons.append("patch-does-not-apply")
        else:
            reasons.append("patch-does-not-apply")
    return reasons, touched_files


def check_packet(case_dict, case_dir, case_id, dirname, defects):
    reasons = []
    packet_rel = case_dict.get("packet")
    packet_text = None
    if packet_rel:
        packet_path = os.path.join(case_dir, packet_rel)
        if os.path.isfile(packet_path):
            with open(packet_path) as f:
                packet_text = f.read()
        else:
            reasons.append("packet-missing")
    else:
        reasons.append("packet-missing")

    if packet_text is not None:
        unit_prefix = "Unit: eval-{}".format(case_id or dirname)
        if not any(line.startswith(unit_prefix) for line in packet_text.splitlines()):
            reasons.append("packet-lacks-unit-line")
        leak_terms = ["gold:"] + [
            d.get("id") for d in defects if isinstance(d, dict) and d.get("id")
        ]
        if any(term in packet_text for term in leak_terms):
            reasons.append("packet-leaks-gold")
    return reasons


def validate_gold_case(case_dict, case_dir, suite_id):
    reasons = []
    for field in GOLD_REQUIRED:
        if field not in case_dict or case_dict[field] is None:
            reasons.append("missing-field:{}".format(field))

    dirname = os.path.basename(case_dir.rstrip("/"))
    case_id = case_dict.get("id")
    if case_id is not None and case_id != dirname:
        reasons.append("id-mismatch")
    if case_dict.get("suite") is not None and case_dict["suite"] != suite_id:
        reasons.append("bad-suite")

    gold = case_dict.get("gold")
    verdict = None
    defects = []
    if isinstance(gold, dict):
        if "verdict" not in gold:
            reasons.append("missing-field:gold.verdict")
        else:
            verdict = gold.get("verdict")
            if verdict not in ("PASS", "FAIL"):
                reasons.append("bad-verdict")
        raw_defects = gold.get("defects", [])
        if isinstance(raw_defects, list):
            defects = raw_defects
        if verdict == "FAIL" and len(defects) == 0:
            reasons.append("defects-required")
        if verdict == "PASS" and len(defects) > 0:
            reasons.append("defects-forbidden")

    patch_reasons, touched_files = check_patch(case_dict, case_dir)
    reasons.extend(patch_reasons)
    if touched_files is not None and defects:
        for d in defects:
            if isinstance(d, dict) and d.get("file") and d["file"] not in touched_files:
                reasons.append("defect-file-not-in-patch")
                break

    reasons.extend(check_packet(case_dict, case_dir, case_id, dirname, defects))

    tags = case_dict.get("tags")
    if isinstance(tags, list):
        non_size = [t for t in tags if not (isinstance(t, str) and t.startswith("size:"))]
        if not non_size:
            reasons.append("tag-class-missing")

    return reasons


def validate_grader_case(case_dict, case_dir, suite_id, schema):
    reasons = []
    for field in GRADER_REQUIRED:
        if field not in case_dict or case_dict[field] is None:
            reasons.append("missing-field:{}".format(field))

    dirname = os.path.basename(case_dir.rstrip("/"))
    case_id = case_dict.get("id")
    if case_id is not None and case_id != dirname:
        reasons.append("id-mismatch")
    if case_dict.get("suite") is not None and case_dict["suite"] != suite_id:
        reasons.append("bad-suite")

    expected = case_dict.get("expected")
    if isinstance(expected, dict):
        for prop in schema.get("required", schema.get("properties", {})):
            if prop not in expected:
                reasons.append("missing-field:expected.{}".format(prop))

    return reasons


def load_grader_schema(schema_rel_path):
    with open(os.path.join(REPO_ROOT, schema_rel_path)) as f:
        return json.load(f)


def validate_suite(suite, cases_dir_override):
    suite_id = suite["id"]
    split = suite_split(suite_id)
    cases_dir = cases_dir_override or os.path.join(REPO_ROOT, suite["cases_dir"])
    case_dirs = find_case_dirs(cases_dir)

    schema = load_grader_schema(suite["grader"]["schema"]) if split == "grader" else None

    seen_ids = {}
    failures = []
    for case_dir in case_dirs:
        case_yaml_path = os.path.join(case_dir, "case.yaml")
        with open(case_yaml_path) as f:
            case_dict = yaml.safe_load(f) or {}

        if split == "gold":
            reasons = validate_gold_case(case_dict, case_dir, suite_id)
        else:
            reasons = validate_grader_case(case_dict, case_dir, suite_id, schema)

        case_id = case_dict.get("id")
        if case_id is not None:
            if case_id in seen_ids:
                reasons.append("duplicate-id")
            else:
                seen_ids[case_id] = case_dir

        failures.extend("{}: {}".format(case_yaml_path, r) for r in reasons)

    return failures


def main():
    args = parse_args()
    with open(args.registry) as f:
        registry = yaml.safe_load(f)
    suites = registry.get("suites", [])

    if args.suite:
        suites = [s for s in suites if s["id"] == args.suite]
        if not suites:
            print("error: no such suite: {}".format(args.suite), file=sys.stderr)
            return 2
    elif args.cases_dir:
        print("error: --cases-dir requires --suite", file=sys.stderr)
        return 2

    all_failures = []
    for suite in suites:
        all_failures.extend(validate_suite(suite, args.cases_dir))

    for line in all_failures:
        print(line)

    return 1 if all_failures else 0


if __name__ == "__main__":
    sys.exit(main())
