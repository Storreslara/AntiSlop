---
name: project_gh385_marker_commit_attribution
description: Plan tracking for gh385 marker-commit-attribution (docs/plans/2026-08-15-marker-commit-attribution.md), parent issue #385
metadata:
  type: project
---

Plan: `docs/plans/2026-08-15-marker-commit-attribution.md`, parent issue #385. Steps
run gh385-1..gh385-8 (approve-route fix, reviewer.md prose, mirror sync already
landed per recent commits; gh385-5 done this session: placeholder replaces
baked `rev-parse HEAD` in stop-gate.sh/task-gate.sh remediation printfs +
adapter ports + `.claude/hooks/scripts/**` resync via `bin/cli.js --update`).

Remaining: gh385-6 (new `hooks/scripts/marker-commit-check.sh`, does not exist
yet), gh385-7 (wire a classifier into stop-gate.sh's review-join loop — do NOT
touch this in gh385-5/6), gh385-8 (version bump, must land last, owns all
version-stamped files: `.claude-plugin/plugin.json`, `package.json`,
`CHANGELOG.md`).

**Why:** the spec deliberately isolates the mirror-regen step (bin/cli.js
--update) into the unit that touches the source files, rather than deferring
it to the version-bump step — R4 bars hand-editing `.claude/hooks/scripts/**`
but not running the sanctioned regen script, and regen alone (no version
stamp touched) is safe to run mid-plan.

**How to apply:** for gh385-6/7/8, re-verify live `grep -c` counts before
editing (they may shift as earlier steps land) — don't trust the counts
quoted in an older dispatch packet.

## Quoting gotcha for remediation-block edits
In these gate scripts, the same-looking `$(cmd)` inside a message string
behaves differently depending on quoting style:
- `echo "... $(git rev-parse HEAD) ..."` — double-quoted, so `$(...)` is a
  LIVE command substitution executed when the block fires (this was the bug:
  it baked in the current HEAD, not the unit's own final commit).
- `echo "... \$(git rev-parse HEAD) ..."` — the `\$` escapes the dollar sign,
  so this prints the LITERAL TEXT `$(git rev-parse HEAD)` for the reader to
  run themselves (task-gate.sh's date arg already worked this way; only its
  git-rev-parse arg needed the placeholder swap since the criterion required
  the substring gone entirely, not just de-live'd).

Don't assume `rev-parse HEAD` occurrences are homogeneous across a file —
check each site's quoting before choosing a replacement strategy.
