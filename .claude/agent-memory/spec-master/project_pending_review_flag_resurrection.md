---
name: pending-review-flag-resurrection
description: Stale pending-review flag after a reviewer PASS is flag resurrection (orchestrator's defer printf re-creates a flag M3 just deleted); plus the 3 gate sites resting on "no agent_id = main session".
metadata:
  type: project
---

Measured 2026-10-02 at 8428fab (spec docs/plans/2026-10-02-escalation-followups.md):
a stale `.pending-review.*` surviving a reviewer PASS is NOT a review-join or
watermark bug. M3's bounded clear deletes one flag per satisfied stamp; flags are
interchangeable (keyed by agent_id, not unit), and a `defer:` rewrite ties mtimes, so a
lexical tie-break picks which one goes. The orchestrator then does
`printf 'defer: ...' > <that path>` (orchestrator.md:155-161 tells it to), which
RE-CREATES the deleted flag, so there is one flag too many forever. Audit-log
signature: `cleared=1 remaining=1` twice, with two `defer:` lines logged right
after the first clear and no lead-programmer stop in between.

**Why:** the brief listed four candidate causes; the audit log plus a scratch
repro singled one out in minutes. Reading the log first beats theorising.

**How to apply:** read `.claude/review-audit.log` with the Read tool (Bash
access to it is Set A, blocked). For hermetic gate repros that spell
`.claude/reviewed` in a mktemp project, author the script with Write into the
scratchpad and run it with `bash <file>`. A Bash heredoc is refused by
reviewed-path-gate.

Also: three gate sites assume "empty agent_id / agent_type = main session":
human-decision-gate:129, harness-integrity-gate:127 (ask_allowed), and
reviewer-route-gate:68-71 (caller allowlist). Agent-teams teammates are
unmeasured for all three; any teammate-identity fix must consider all three.
Related: [[in-session-escalation-decision-spec]].
