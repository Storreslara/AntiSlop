---
name: cross-plan-version-coordination
description: This repo can run multiple plans concurrently that each end in their own version-bump/consolidation step touching shared files (plugin.json, package.json, CHANGELOG.md) — slice those steps with an explicit cross-plan dependency, not an assumed sequential order.
metadata:
  type: project
---

This repo (AntiSlop / antislop plugin source, self-hosted) sometimes has two
plans in flight at once, each ending in a "Track C / Step C.1"-style
consolidation step that bumps `.claude-plugin/plugin.json` + `package.json`,
re-stamps `<!-- antislop vX.Y.Z ... -->` lines, and adds a `CHANGELOG.md`
entry. Observed concrete case (2026-07-15): `docs/plans/2026-07-14-threefold-update.md`
(issue #31, its own Step C.1, version target 0.10.0) was still open while
`docs/plans/2026-07-15-handoff-triage-skills.md` was being sliced — that
plan's own Step C.1 (filed as issue #41) targets "next minor above whatever
`plugin.json` reads at execution time," explicitly NOT a hardcoded number,
plus a cross-plan `Depends on` line pointing at #31's *merged* state (not
just its existence).

**Why:** two concurrent version-bump steps racing on the same file would
either silently skip a version or produce a merge conflict; hardcoding a
target version at slicing time (e.g. "0.11.0") bakes in an assumption about
when the other plan's bump lands, which may be stale by execution time.

**How to apply:** when slicing a Track/Step that bumps shared version-stamped
files, (1) check `gh issue list` (or equivalent tracker query) for any other
plan's own version-bump issue and note its current state in the dispatch
prompt; (2) write the acceptance criterion as "strictly greater than the
pre-edit value read at execution time," never a literal version string; (3)
add an explicit cross-plan `Depends on / blocked by` line requiring the other
plan's version-bump issue to be *merged*, not just filed or in progress; (4)
tag the unit `Roast pass: fable` if it also touches many other shared files —
this coordination risk alone makes it a "heavy" unit per the pathfinder
criteria even when the diff itself is small.

**Tracker "open" state can lag actual git state — verify against git, not just
`gh issue state`.** Observed concrete case (2026-07-16): issue #56 (the
vendor-mattpocock-skills plan's own Step F.1 version-bump, target 0.12.0) was
still `OPEN` on GitHub while slicing the reviewer-gate-model-selection plan,
but `git log -- .claude-plugin/plugin.json` showed its work had already
landed (plus a later, separate patch commit bumping further to 0.12.1) — the
issue was simply never closed, not an active race. Before treating an open
version-bump issue as a live blocker, cross-check `git log --oneline -- 
.claude-plugin/plugin.json` (or the project's equivalent version-stamped
file) for whether its work is already merged; if so, note in the dispatch
prompt that the "open" state is a tracker-hygiene gap, not a real dependency,
rather than wiring a `Depends on` line against a phantom blocker. Conversely,
when the finalized spec you're slicing already hardcodes a specific "from X to
Y" bump matching the CURRENT real value of the version file (verified by
reading it, not assumed), it is fine to keep the spec's own literal
acceptance criteria as-is (don't unilaterally rewrite spec substance to a
relative-diff form) — instead add a precondition-check note instructing the
executing persona to re-verify the pre-edit value at execution time and treat
a mismatch as a spec gap to report upward, rather than forcing the literal
target over a changed actual value.
