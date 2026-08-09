---
description: Audit which agents were deployed and flag anomalies, with model-distribution and skill-inventory summaries — read-only observability over agent activity.
---

Dispatch the `agent-auditor` persona if present in this project to analyze agent activity in the transcript store. It flags a fixed set of anomalies (undeclared tool use, unregistered agent types, nested spawning, gated dispatch without review follow-up, missing terminal status lines, orphan PASS markers) and emits two informational summaries: a model-distribution table and a skill inventory.

The persona reads only — it never writes code, gates anything, or fixes findings. Its output is an observation report for a human decision.

Options:
- `--sessions=N` — analyze the last N sessions (default: 1, current session only)
- `--all` — analyze all available sessions
- `--json` — emit machine-readable JSON instead of plain text

Internally the persona runs `bash scripts/agent-audit.sh`, whose only other flags are `--format-probe` (debugging) and the `AGENT_AUDIT_ROOT` environment override (fixture-only); an unrecognized argument exits 1 rather than printing usage.
