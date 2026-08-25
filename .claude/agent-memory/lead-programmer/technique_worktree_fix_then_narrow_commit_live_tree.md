---
name: worktree-fix-then-narrow-commit-live-tree
description: Land a debug-spec pristine-worktree fix onto master by narrow `git commit -- <paths>` in the live tree, not by pushing the worktree's own commit — and watch for a sibling unit re-pointing fileHashes while you work
metadata:
  type: project
---

When a debug spec mandates building/verifying a fix in a pristine detached
worktree (to avoid DR2-style contamination from other units' uncommitted
live-tree state), the worktree's own commit does **not** land on `master` —
worktree HEADs are detached, and `git branch -f`/`git fetch . <sha>:master`
both refuse to move a ref checked out in another worktree (the live tree
here). See [[g1-bump-invalidates-mirrors]] for the render mechanics
(`--force-render`, `fileHashes`) this technique wraps.

**How to apply:** after verifying in the worktree, `cp` the exact resulting
files into the live tree and `git commit -- <paths>` there (never `git add
-A`, see [[check-index-before-commit]]) — this is how every other
concurrent unit in this repo actually lands on master, and it naturally
excludes whatever other agents' uncommitted WIP sits in the live tree.

**Race to watch:** re-check `git rev-parse master` immediately before your
final narrow commit. Mid-fix on mw-step3 (2026-08-25) a sibling unit
(gh411, commit `cbd53d5`) landed on master *while I was working in the
worktree* and re-pointed `.claude/persona-config.json`'s `fileHashes` for
the exact 3 mirror files I was regenerating — to the hash of their
pre-existing *stale* content, self-correcting a repeat-`--update`
inconsistency of its own. My first worktree commit (based on the now-stale
parent) became invalid the moment that landed: re-running
`--force-render` against a fresh worktree at the new tip was required, and
it correctly reverted those same 3 hash entries back to match the actual
source content — not scope creep, just my own unit's hashes being
corrected back. Always redo the render against the true current `master`
tip right before the final commit, not the tip you started from.
