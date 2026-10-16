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
    with open(path) as f:
        return json.load(f)


def build(a):
    summary = load(a.summary)
    checks = load(a.checks)
    status = summary["completion_status"]
    if status not in STATUSES:
        raise SystemExit(f"make-row: unknown completion_status {status!r}")
    required = [c for c in checks if c.get("required")]
    passed = [c for c in required if c.get("pass")]
    rate = (len(passed) / len(required)) if required else None
    escaped = sum(1 for c in checks if c.get("kind") in ("defect", "security") and not c.get("pass"))
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
