---
name: shared-worktree-stash-race
description: In this repo's shared main worktree, concurrent agents' git stash/reset can wipe your uncommitted Edit-tool changes or inject conflict markers mid-task
metadata:
  type: feedback
---

Distinct from [[feedback_check_index_before_commit]] (which covers the shared
*index*/staging race) — this is the shared *working tree* itself getting
mutated by another concurrent agent's `git stash` / `git reset` / `git stash
pop` while your Edit-tool changes sit uncommitted in it.

**Why:** on gh275-276 (2026-08-11), two `Edit` calls landed fine on disk, but
by the time I re-read the file minutes later (after doing unrelated
verification work), both were gone — `git reflog` showed a `reset: moving to
HEAD` entry from another concurrent agent operating in the exact same
`/home/sebas/AntiSlop` directory (not an isolated worktree). I redid the
edits and committed immediately; a `git commit -F <file> -- <paths>`
succeeded and stuck. Later, a re-check of the same file showed literal
`<<<<<<< Updated upstream` / `=======` / `>>>>>>> Stashed changes` conflict
markers injected into it mid-flight by another agent's `git stash pop`
colliding with my already-committed change — this self-resolved (in my
favor) a few Bash calls later without my intervention, but could just as
easily not have.

**How to apply:**
- Treat any uncommitted `Edit` in this repo's main directory as fragile the
  moment you stop actively working on it. Minimize the gap between "content is
  correct" and `git commit -F <msg-file> -- <exact paths>` (the pathspec form
  from [[feedback_check_index_before_commit]] still applies — no separate
  `git add` step).
- After committing, don't fully trust a single `git status`/`grep` snapshot if
  several Bash calls have passed since — re-read the file fresh before
  reporting success, especially if you're about to hand off a ready-for-review
  packet.
- If you see literal `<<<<<<<`/`=======`/`>>>>>>>` markers appear in a file
  you didn't put them in, don't panic-resolve someone else's stash conflict
  blind — re-check moments later first (it may resolve itself if another
  agent is mid-operation), and if it doesn't, surface it rather than guessing
  at ownership of the conflicting side.
- To tell "did MY change break this test" from "did a concurrent commit from
  another agent break it": check out your own commit SHA in a throwaway `git
  worktree add --detach <tmp-dir> <your-sha>`, run the suite there, then
  `git worktree remove <tmp-dir> --force`. This cleanly isolates your diff's
  correctness from unrelated churn landing on `master` while you work.
