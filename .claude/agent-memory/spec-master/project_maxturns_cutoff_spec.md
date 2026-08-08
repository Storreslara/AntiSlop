---
name: project-maxturns-cutoff-spec
description: The 2026-07-28 maxTurns-cutoff spec (issue #123) — settled decisions, the user's second recommendation-override, and the non-obvious two-tier protocol fan-out finding
metadata:
  type: project
---

Spec finalized 2026-07-28 at
`docs/plans/2026-07-28-maxturns-cutoff-handoff.md`, published as GitHub issue
**#123** (labels `ready-for-agent`, `plan/2026-07-28-maxturns-cutoff-handoff`).
Next owner: `task-master` for `to-issues` slicing.

**Why:** a `spec-master` dispatch was force-ended mid-sentence by its
`maxTurns: 30` cap with zero signal to anyone. A prior session verified against
the installed Claude Code binary that the cutoff is undetectable — the persona
is never told, no turn counter is observable from inside a subagent, no hook
fires on that path, and the sidecar metadata records no exit reason. Those
findings (F1-F9 in the plan) are **settled and expensive — never re-derive
them.** The fix inverts the problem: detect the ABSENCE of a completion
signature (`STATUS: complete` / `STATUS: incomplete — <reason>` as the last
line), not the cutoff.

**How to apply — settled by the user, do not re-litigate:** universal persona
scope; status line with distinct values, no new marker file; docs/protocol-only
enforcement (no hooks); the live `SubagentStop`-fires-on-cutoff probe is moot
and must not be run; and `spec-master`/`task-master` `maxTurns` 30→40 bundled
in. Resolved by this plan's own judgment: no other cap is raised — notably
`lead-programmer`'s 30 is the repo's ONLY cap backed by a CONFIRMED measurement
(E1 in `docs/self-improvement-loops.md`), so raising it would undo a shipped
win.

**Second override of a spec-master recommendation, same pattern as #122's
gitignored bundles.** The plan recommended routing the cap raise through the
repo's measurement harness first; the user bundled it anyway, knowingly
shipping it unmeasured. See [[feedback-deliberate-friction]] — expect the
recommended-safer default to be overridden, and state the tradeoff prominently
rather than softening it.

**The non-obvious structural finding worth keeping — do not let anyone
"simplify" it away.** "All personas" does NOT follow from editing
`templates/persona-protocol.md`. `bin/cli.js` INLINES the protocol into each
persona body (no `@import` — proven not to resolve inside a subagent body,
issue #121 Step 2) and there are **two** canonical texts:
`SLIM_TIER_PERSONAS = ['explorer', 'researcher', 'scribe']` get
`templates/persona-protocol-slim.md` instead. `tests/adapter-protocol-parity.test.js`
guards only the Codex/Cursor ports, **not** the slim file — so the slim tier is
an unguarded fan-out path, and `explorer` (tightest cap at 10, highest
frequency) is the likeliest cutoff victim of all. Any future shared-protocol
change must touch both tiers or it silently exempts three personas.

**Recovery note (2026-08-08):** this file and the plan doc it describes were
lost to an uncommitted stash for over a week (stashed 2026-08-06, never
landed on `master`). All 6 child step-issues (#124-128) closed and the code
shipped anyway (commits `b64b811`, `88a2c43`, `1cf3e96`, `b369534`,
`545897b`, `81fa38b`) — the canonical plan doc was simply missing from git
history until recovered from the stash's untracked-files commit
`a0d90e5969982168b323b58d876fdd4c636cd81c` and re-committed. Spot-checked
against shipped reality on recovery: `maxTurns: 40` confirmed in both
`agents/spec-master.md` and `agents/task-master.md`, the `## Terminal status
line` heading confirmed in both protocol tiers, and CHANGELOG 0.14.0 entry
confirmed present. No contradictions found. Also note this memory file's
original stash path was `.claude/agent-memory/antislop-spec-master/` — a
stale persona-directory name; restored here at the current `spec-master/`
path instead, since the old directory no longer exists in this project's
agent-memory tree.
