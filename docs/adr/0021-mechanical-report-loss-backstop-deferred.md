# ADR 0021: Mechanical report-loss backstop deferred

Date: 2026-08-13
Status: Deferred

## Context

Relocated from `agents/orchestrator.md`'s "Default dispatch naming: unnamed
vs. named" section (gh348-5, finding 1.5), where it sat as body prose in a
persona file rather than a design record. No prose content changed in the
move.

Investigated: whether a hook could detect a named agent's `SubagentStop` with
no prior `SendMessage` and warn. Findings:

- `hooks/hooks.json` today registers `PreToolUse` matchers for `Write|Edit`,
  `Agent` and `Bash` only. There is no `SendMessage` matcher, and no hook in
  this repo has ever observed that tool.
- The `SubagentStop` payload carries `agent_type` and `agent_id`, so a hook
  *could* distinguish a named dispatch from an unnamed one — found
  empirically, not guaranteed by design: a named dispatch's `agent_type` is
  not a persona name (it is the raw dispatch name given in the dispatch
  prompt), while an unnamed one's is the persona-derived form.
- A backstop would therefore need: a new `PreToolUse` matcher on
  `SendMessage` writing a per-identity "reported" marker, plus a new
  `stop-gate.sh` branch that warns when a non-persona `agent_type` stops
  with no such marker.

## Decision

**Defer, and record the deferral.** Two reasons, both concrete. First, the
premise is unverified — that a `PreToolUse` matcher fires on `SendMessage`
at all is an assumption about the harness, and this project has already
found one place where an assumption about harness identity was wrong.
Second, the failure mode it guards is fully removed at the source by
orchestrator.md's "default unnamed" rule for every dispatch that does not
need a name, and for the few that do, the dispatch prompt now carries the
explicit requirement. Building a new cross-hook state file and a new
matcher to catch a residue of a residue is disproportionate.

## Consequences

If the practice recurs after the "default unnamed" rule lands, the design
above is the starting point for future work — no hook exists today to
detect a report-loss incident of this shape.

## Related

- `agents/orchestrator.md`'s "Default dispatch naming: unnamed vs. named"
  section — the rule this deferral's failure mode is fully mitigated by.
- Plan: `docs/plans/2026-08-13-persona-efficiency-audit-gh348.md` (Step 5,
  finding 1.5).
