---
name: feedback-acceptance-criterion-assumes-missing-cli-flag
description: When a spec's literal acceptance-criteria command uses a CLI flag combination that doesn't exist yet in the code, fold the minimal, narrowly-scoped addition into Ordered edits (reusing an existing sibling mechanism) instead of treating it as a spec gap — reserve spec-gap escalation for cases where the needed addition isn't narrow or has no existing pattern to reuse.
metadata:
  type: feedback
---

Observed 2026-08-25 (harness-ceremony-consolidation slicing, gh408). The
spec's A4 acceptance criterion was
`node bin/cli.js --target=cursor --dry-run` / `--target=codex --dry-run`
each emitting an ignore list containing a `review-join` entry. Checked live
before dispatch: `scaffoldCursor(args)`/`scaffoldCodex(args)` in
`bin/cli.js` read `--overwrite`/`--force-hooks` but do **not** read
`--dry-run` at all — the flag combination the criterion names doesn't
exist. This is a different class of gap than
[[feedback_recheck_baseline_counts_live]] (a stale *number*) — here the
spec assumes a *capability* that was never built.

**Resolution used:** did not escalate as a spec gap. The unit's own
described work (M1.2: "introduce one canonical array... render it per
target") already implies a render-only code path is being created; the
main claude-install flow (a sibling code path in the same file) already
has the exact mechanism needed — a `dryRun`-aware
`appendUnique(filePath, lines, dryRun)` signature (`bin/cli.js:154`,
used at lines 1088-1101). Folded an explicit Ordered-edit step into the
dispatch: add minimal `--dry-run` support to `scaffoldCursor`/
`scaffoldCodex`, **scoped only to the gitignore-append step**, reusing the
existing dryRun-aware `appendUnique` signature — explicitly told the
executor NOT to extend dry-run to the rest of the scaffold flow (settings,
agents, hooks.json merge), and to STOP and report a spec gap if satisfying
the criterion turns out to need more than that narrow scoping.

**Why this wasn't a spec gap:** the fix is small, has an existing pattern
in the same file to copy (not a novel design decision), and stays within
the unit's own already-described scope (per-target rendering). Compare to
a genuine spec gap: if the criterion had required dry-run support across
the *entire* scaffold flow, or if no analogous mechanism existed anywhere
in the codebase to model the addition on, that would cross into "a step
that can't be sliced into an independently-gradable unit as written" and
should route back to spec-master instead.

**How to apply:** when a literal acceptance-criteria command uses a flag,
endpoint, or code path that doesn't exist yet, first check whether (a) the
missing piece is narrowly scoped to just what the criterion needs, and (b)
an existing sibling mechanism in the same file/module already does the
same thing for a different target. If both hold, fold an explicit Ordered-
edit step instructing the executor to add the minimal capability by
reusing the existing pattern, with an explicit boundary ("scoped only to
X, do not extend to Y") and an explicit escalation instruction if the
scope turns out to be bigger than expected. If either doesn't hold, treat
it as a spec gap per the normal escalation path — do not silently invent a
larger design.
