---
name: token-reduction-spec
description: 2026-10-15 persona token-reduction spec (12 Fable items); premise corrections that a future spec must not re-derive or repeat
metadata:
  type: project
---

Plan: docs/plans/2026-10-15-persona-token-reduction.md (draft, OQ1-4 round 1).

Premise corrections measured 2026-10-15:
- A LONE `jq -r ... <persona config>` (no cd/;/pipe) passes harness-integrity-gate (is_benign_jq_read). reviewer.md's "Bash naming it is refused" is false for that form; compound commands naming it ARE blocked.
- ADR-0040 forward rule prints `met` (n=77 f1=6 f2=2 f6=0); the 32.5%/28.6% FAIL figures are August-era.
- reviewer-tier.sh already gives sonnet to non-sensitive diffs <=40 lines/3 files.
- effort is frontmatter-only, and the orchestrator effort policy is raise-never-lower.
- reviewer.md packet prose duplicates the protocol's "Fourth verdict" section, which ships as .claude/persona-protocol.md. Use a pointer there, not a config-conditional render (needsRender ignores config).
- benign-command allowlist already has wc/ls/stat/head/tail/grep. The false positives come from command SHAPE (cd prefix, for, 2>&1, xargs/sort pipes).

**Why:** Fable-style reviews re-propose fixes from stale numbers.
**How to apply:** re-measure before speccing any token or tier lever. See [[feedback_baselines_expire]].
