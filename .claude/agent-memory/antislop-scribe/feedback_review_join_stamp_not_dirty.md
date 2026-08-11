---
name: feedback-review-join-stamp-not-dirty
description: Pre-existing untracked .claude/.review-join.<task-id> stamps don't count as "unexpected dirty state" under a dispatch's escalation clause
metadata:
  type: feedback
---

When a dispatch's escalation clause says "stop and report if git status shows
anything unexpected/dirty from another source," pre-existing untracked
`.claude/.review-join.<task-id>` files do not trigger it, even though they
make `git status --short` non-empty after your own commit.

**Why:** These are the documented review-join stamp mechanism ([[review-join
stamp]] in CONTEXT.md) — written by `reviewer-route-gate.sh` on reviewer
dispatch, consumed by `stop-gate.sh` on verdict. They are never committed in
this repo's history (`git log --all -- '.claude/.review-join.*'` is empty) and
not gitignored either — untracked-but-present is their normal resting state,
including sometimes lingering after a unit's PASS marker lands (observed for
gh326.pass's own stamp at post-PASS documentation time). A file matching a
name/shape documented in CONTEXT.md is *recognized*, not unexpected — the
escalation clause is for genuinely unrecognized content, not for known
workflow byproducts outside your write scope.

**How to apply:** At post-PASS documentation time, if `git status --short`
after your own commit still shows `?? .claude/.review-join.*` entries, do not
delete/touch them (outside scribe's write scope, and one could belong to a
concurrently active reviewer dispatch elsewhere in the session) and do not
treat it as blocking. Read the acceptance criterion "`git status --short`
clean after your commit" as scoped to your own changes (no uncommitted diff
of the files you were supposed to touch), report the stray untracked files by
name in your final response, and proceed to close the issue. Only stop for
real if the untracked/dirty content is something you don't recognize the
shape of at all (e.g. an unfamiliar file path, a modified tracked file you
didn't touch).
