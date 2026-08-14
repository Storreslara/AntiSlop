---
name: git-diff-criterion-untracked-doc
description: A "git diff shows only added lines" acceptance criterion is vacuous when the target doc was never committed at all
metadata:
  type: project
---

On `adhoc-2026-08-14-decision-join-ambiguity-fix`, an acceptance criterion
read `git diff -- docs/plans/2026-08-13-dashboard-decision-approval-surface.md
shows only added lines under R8, no removed or changed lines`. The file
turned out to be entirely **untracked** (`?? ...` in `git status`, never
committed by whichever prior session authored it) — a large batch of prior
sessions' `docs/plans/*.md` and `.claude/agent-memory/*/*.md` output sits
uncommitted in this repo's working tree as ambient state, unrelated to any
one unit.

**Why it matters:** `git diff` on an untracked file shows nothing (no
tracked baseline to diff against), so the literal criterion command produces
empty output — not a real signal that only added lines exist. I verified
add-only-ness by inspection instead (my `Edit` call's `old_string`/`new_string`
only appended a paragraph after the existing bullet; re-grepped the original
bullet text to confirm it survived unchanged) and reported the discrepancy
plainly in the ready-for-review packet rather than silently treating the
empty diff as passing evidence, or trying to "fix" it by committing the
whole pre-existing doc (which isn't mine to author into history).

**How to apply:** before trusting a `git diff -- <path>` acceptance
criterion, check `git status --short -- <path>` first — if it's `??`, the
criterion needs a different verification method (inspect the edit's
old/new strings, or grep for the original text's survival) and the
discrepancy belongs in the report, not silently patched around.
