---
name: technique-gate-safe-criterion-commands
description: Criterion and persona commands that the reviewer or a downstream persona runs in Bash must pass reviewed-path-gate and harness-integrity-gate as written; probe them in the real repo first
metadata:
  type: feedback
---

A criterion or persona-shipped command is run by another identity through the same PreToolUse gates, so a
command the gates refuse is an unrunnable criterion.

- `harness-integrity-gate.sh` refuses ANY Bash text naming the persona config file, even inside a grep
  regex of a scope check. Match `^\.claude/` generically instead (rfp-u4 criterion 4).
- `reviewed-path-gate.sh` passes plain `grep -r … .claude/reviewed | sort` or `| wc -l`, but refuses
  `$(…)` substitution, `awk`, redirects and heredocs whose text names that directory. Ship separate plain
  counts and let the persona add them (rfp-u4 milestone-auditor sample).
- A test FILE may spell the path freely (the gate scans command text, not the script it runs), so put
  fixtures in a test written with the Write tool, and tell the implementer not to fall back to a heredoc.

**Why:** found 2026-10-27 drafting rfp-u4; my own scratch probes were refused three times before I noticed
the same text would be refused for the reviewer.
**How to apply:** before handoff, run each new criterion once in the real repo (it may print `no-commits`)
just to see that no gate refuses it. Related: [[technique-prove-contracts-on-a-clone]].
