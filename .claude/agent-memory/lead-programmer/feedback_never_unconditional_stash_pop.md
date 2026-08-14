---
name: never_unconditional_stash_pop
description: Never chain `git stash` (as a save-before-risky-op) with an unconditional `git stash pop` in this shared-index repo — "no local changes to save" doesn't mean no stash exists
metadata:
  type: feedback
---

Never write `git stash; <risky command>; git stash pop` as a defensive pattern
in this repo, even when you expect "no local changes to save" from the first
`git stash`. If a stash entry already exists (left by ANOTHER concurrent
agent — this repo runs multiple lead-programmer/reviewer/scribe sessions
against the same working tree, per [[project_threefold_update]] and the
review-join files visible in `git status` at session start), an unconditional
`pop` will apply THAT agent's WIP stash onto your tree, not your own (since
yours was never created). This can produce a merge conflict that stages
unrelated files and corrupts the working tree for whoever owns that stash.

**Why:** hit this live on gh290 — ran `git stash` to snapshot before an
investigative worktree-based test, got "No local changes to save" (my tree
was already clean/committed), then ran `git stash pop` anyway out of habit,
which popped a genuinely unrelated `stash@{0}: WIP on master: fix(gh292)...`
left by a different concurrent unit. Caused a conflict in `tests/validate.sh`
and staged changes to `.gitignore` and `hooks/scripts/dispatch-hygiene.sh`
that weren't mine. Recovered cleanly via
`git restore --source=HEAD --staged --worktree -- <the 3 touched files>`
(pop leaves the stash entry KEPT on conflict, so nothing was lost) — but this
was luck, not design.

**How to apply:** never pair `git stash` with a bare `git stash pop` unless
you captured the stash's own identity first (e.g. compare `git stash list`
before/after, or check the exit code/output of `git stash` for "Saved
working directory" vs "No local changes to save" and only pop if the former).
For "try something risky, then restore" investigations, prefer a detached
`git worktree add` against a specific commit (as I did to isolate the F2
regression test's pre-existing-vs-introduced status) — it never touches the
shared stash namespace at all.
