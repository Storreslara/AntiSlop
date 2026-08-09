---
description: Audit which agents were deployed, what tools each invoked, and flag anomalies — read-only observability over agent activity.
---

Dispatch the `agent-auditor` persona if present in this project to analyze agent activity in the transcript store. It enumerates every agent dispatch in a chosen time window, inventories tools and skills each used, and flags a fixed set of anomalies (undeclared tool use, unregistered agent types, nested spawning, gated dispatch without review follow-up, missing terminal status lines, orphan PASS markers).

The persona reads only — it never writes code, gates anything, or fixes findings. Its output is an observation report for a human decision.

Options:
- `--sessions=N` — analyze the last N sessions (default: 1, current session only)
- `--all` — analyze all available sessions
- `--json` — emit machine-readable JSON instead of plain text

Internally the persona runs `bash scripts/agent-audit.sh`. Read the script's own usage for lower-level control.
