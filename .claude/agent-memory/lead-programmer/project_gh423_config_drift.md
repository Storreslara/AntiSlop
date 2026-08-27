---
name: project_gh423_config_drift
description: gh423 (spec 1 Step 4, last unit) - disarm-surface config-drift detection, PASSED
metadata:
  type: project
---

gh423 (spec 1's Step 4, W7/last unit) shipped a config-drift comparison in
`bin/harness-integrity.sh`: normalizes 9 disarm-surface fields (absent key
-> documented default) from `git show <baseline-sha>:.claude/persona-
config.json` vs. the working tree, reports `config=drift fields=<list>` in
its default report line. Wired report-only into `session-start.sh`, and as
a hard block into `stop-gate-core.sh`'s gated-SubagentStop path only (never
main-session Stop, per RD3), with a new `.config-drift-override.<agent-id>`
defer:/skip: escape hatch mirroring the existing pending-review flag shape.

**Why:** this closes spec 1's Goal 1 (silent kill switch) for the specific
case of a config *weakened* rather than deleted, and is the mechanism that
catches spec 6's own `reviewGating.mode: off` flip once that lands.

**How to apply:** if a future unit touches the disarm-surface field list or
`normalize_disarm_surface()`'s per-field defaults, re-verify against each
consuming gate's own fallback (dispatch-hygiene.sh, stop-gate-core.sh,
reviewer.md's humanReviewMode doc) rather than guessing a default.

Two gotchas worth remembering generally (not gh423-specific enough for
their own entries, folded in here):
- jq's `//` treats a literal `false` as absent - never use it for a boolean
  field's default; compare against `== false` explicitly instead
  (dispatch-hygiene.sh:126-130 already documents this footgun).
- a herestring (`<<<`) appends a trailing newline the source string doesn't
  have; if you then flatten newlines with `tr`, you get an extra token.
  Use `< <(printf '%s' "$x")` process substitution instead when byte-exact
  input matters.

See [[feedback_new_hook_script_shifts_out_of_scope_baseline]] for the
sibling gotcha this unit did NOT trigger (no new top-level hook script was
added, only bin/harness-integrity.sh extended + stop-gate-core.sh/
session-start.sh edited - stop-gate-core.sh already existed pre-M2).
