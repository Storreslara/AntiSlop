---
name: technique-contract-guard-r6-bullet-shape
description: contract-score v2 R6 fails a lead contract unless EVERY "Do NOT touch" bullet opens with a backticked path; prose-first bullets silently drop the unit to sonnet.
metadata:
  type: feedback
---

`bin/contract-score.js` r6v2 requires >= 2 bullets in `## Do NOT touch`, and every one must match
`^- \`[^\`]*[/.][^\`]*\`` — the FIRST token is a backticked path containing `/` or `.`.
A bullet like "- the rest of `agents/orchestrator.md` ..." or "- the adapter ports under `adapters/`"
scores R6 false, and the guard prints `contract-guard: sonnet ... failed=R6`.

**Why:** 2026-10-10 rnf-4/rnf-5 drafts scored 6/7 for exactly this; rewording to
"- `agents/orchestrator.md` outside edit 1, ..." restored 7/7.

**How to apply:** after drafting fast-path contracts, always run
`node bin/contract-guard.js <plan> --unit=<id> [--shape=scribe]` for every unit before handoff;
lead every Do NOT touch bullet with the backticked path. Related: [[verify-own-criteria-nonvacuous]].
