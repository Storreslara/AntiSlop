#!/usr/bin/env python3
"""Assemble one result row (spec 4.3, amended by operator decisions OD-4/OD-5).

Usage: make-row.py --summary SUMMARY.json --checks CHECKS.json [options]
SUMMARY.json is the output of stream.py summarize; CHECKS.json is the JSON
array a check.sh prints. Prints one JSON object on one line.
"""
import argparse
import hashlib
import json
import sys

STATUSES = ("complete", "stalled-human", "turn-cap", "timeout", "usage-limit", "error")
ARM_A_PROCESS = {
    "units": None, "review_fail_cycles": None, "tiers_seen": None,
    "gate_blocks": 0, "stalled_reason": None, "persona_tokens": None,
}


def sha256_file(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        fail(f"cannot read {path}: {e}")

def fail(msg):
    raise SystemExit(f"make-row: {msg}")


def validate_checks(checks, expected):
    """Fail closed: a checks array that is not exactly what the verified fixture produces never yields a row."""
    if expected < 1:
        fail("--expected-required must be at least 1")
    if not isinstance(checks, list):
        fail("checks must be a JSON array")
    for i, c in enumerate(checks):
        where = f"check {i}"
        if not isinstance(c, dict):
            fail(f"{where} is not an object")
        for key in ("required", "pass"):
            if key not in c:
                fail(f"{where} lacks '{key}'")
            if not isinstance(c[key], bool):
                fail(f"{where}: '{key}' must be a boolean")
        if "exit" in c:
            if isinstance(c["exit"], bool) or not isinstance(c["exit"], int):
                fail(f"{where}: 'exit' must be an integer")
            if c["pass"] != (c["exit"] == 0):
                fail(f"{where}: pass disagrees with exit")
    found = sum(1 for c in checks if c["required"])
    if found != expected:
        fail(f"expected {expected} required checks, found {found}")


def denial_only(summary):
    """A permission denial that is the sole stall cause in an otherwise clean run; a missing or mistyped key never qualifies."""
    def count(key):
        v = summary.get(key)
        return v if isinstance(v, int) and not isinstance(v, bool) else None
    code = summary.get("exit_code")
    clean = (summary.get("result_subtype") == "success" and summary.get("is_error") is False
             and isinstance(code, int) and not isinstance(code, bool) and code == 0)
    return clean and (count("permission_denials") or 0) > 0 and count("ask_user_attempts") == 0 and count("escalated_markers") == 0


def build(a):
    summary = load(a.summary)
    checks = load(a.checks)
    validate_checks(checks, a.expected_required)
    if a.arm == "B" and not a.process:
        fail("arm B needs --process")
    status = summary["completion_status"]
    if status not in STATUSES:
        raise SystemExit(f"make-row: unknown completion_status {status!r}")
    required = [c for c in checks if c.get("required")]
    passed = [c for c in required if c.get("pass")]
    rate = (len(passed) / len(required)) if required else None
    escaped = sum(1 for c in checks if c.get("kind") in ("defect", "security") and not c.get("pass"))
    if status == "stalled-human" and denial_only(summary) and len(passed) == len(required):
        status = "complete"
    run_pass = status == "complete" and len(passed) == len(required)
    if a.arm == "A":
        process = dict(ARM_A_PROCESS)
    else:
        process = dict(ARM_A_PROCESS)
        process["gate_blocks"] = 0
        if a.process:
            process.update(load(a.process))
    return {
        "schema_version": 1,
        "run_id": f"{a.eval_id}/{a.arm}/{a.policy}/{a.rep}",
        "eval_id": a.eval_id,
        "arm": a.arm,
        "model_policy": a.policy,
        "rep": a.rep,
        "started_at": a.started_at,
        "harness_commit": a.harness_commit,
        "plugin_commit": None if a.plugin_commit == "null" else a.plugin_commit,
        "plugin_version": None if a.plugin_version == "null" else a.plugin_version,
        "cli_version": a.cli_version,
        "fixture_commit": a.fixture_commit,
        "fixture_profile": json.loads(a.fixture_profile),
        "prompt_sha": sha256_file(a.prompt_file),
        "persona_config_sha": None if a.persona_config_sha == "null" else a.persona_config_sha,
        "completion_status": status,
        "result_subtype": summary.get("result_subtype"),
        "wall_clock_ms": a.wall_clock_ms,
        "duration_api_ms": summary.get("duration_api_ms"),
        "total_cost_usd": summary.get("total_cost_usd"),
        "model_usage": summary.get("model_usage") or {},
        "tokens_in": summary["tokens_in"],
        "tokens_out": summary["tokens_out"],
        "tokens_cache_write": summary["tokens_cache_write"],
        "tokens_cache_read": summary["tokens_cache_read"],
        "tokens_total": summary["tokens_total"],
        "num_turns": summary.get("num_turns"),
        "subagent_spawns": summary.get("subagent_spawns"),
        "tool_calls": summary.get("tool_calls"),
        "human_interventions_required": summary.get("human_interventions_required"),
        "checks": checks,
        "holdout_pass_rate": rate,
        "defects_escaped": escaped,
        "out_of_scope_lines": a.out_of_scope_lines,
        "out_of_scope_files": a.out_of_scope_files,
        "commits": a.commits,
        "run_pass": run_pass,
        "process": process,
        "blind_grades": json.loads(a.blind_grades),
        "artifacts": {"stream": a.stream_path, "diff": a.diff_path},
    }


def main(argv):
    p = argparse.ArgumentParser(prog="make-row.py")
    p.add_argument("--summary", required=True)
    p.add_argument("--checks", required=True)
    p.add_argument("--eval-id", required=True)
    p.add_argument("--arm", required=True, choices=("A", "B"))
    p.add_argument("--policy", default="uniform", choices=("uniform", "shipped"))
    p.add_argument("--rep", type=int, required=True)
    p.add_argument("--started-at", required=True)
    p.add_argument("--harness-commit", required=True)
    p.add_argument("--plugin-commit", default="null")
    p.add_argument("--plugin-version", default="null")
    p.add_argument("--cli-version", required=True)
    p.add_argument("--fixture-commit", required=True)
    p.add_argument("--fixture-profile", default="{}")
    p.add_argument("--prompt-file", required=True)
    p.add_argument("--persona-config-sha", default="null")
    p.add_argument("--wall-clock-ms", type=int, required=True)
    p.add_argument("--expected-required", type=int, required=True)
    p.add_argument("--commits", type=int, default=0)
    p.add_argument("--out-of-scope-lines", type=int, default=0)
    p.add_argument("--out-of-scope-files", type=int, default=0)
    p.add_argument("--process", default="")
    p.add_argument("--blind-grades", default="{}")
    p.add_argument("--stream-path", default="")
    p.add_argument("--diff-path", default="")
    a = p.parse_args(argv)
    sys.stdout.write(json.dumps(build(a), sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
