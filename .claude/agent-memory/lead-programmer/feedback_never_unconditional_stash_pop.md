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

**Recurrence (spec2-unitE, 2026-08-25):** even a "correct" stash/pop (real
"Saved working directory", stack depth verified before/after, my own stash
popped cleanly) still isn't safe here, because the danger isn't only about
popping the wrong stash — it's the WINDOW where the tree sits reverted to
HEAD. A concurrent agent's own broad `git commit -a`/`add -A` landing during
that window scoops up nothing extra (tree was clean then), but once my `pop`
restores my edits to disk, if THEIR commit lands microseconds later than my
pop, their broad add sweeps up MY uncommitted files under THEIR commit
message. This is what happened: a "spec2-unitD" commit ended up containing my
entire Unit E `protectedPaths` restructuring, correctly content-wise but
mislabeled and un-reviewable as Unit E's own diff. Detected it by noticing
`git diff` on files I'd just edited showed no changes (already matched HEAD)
and cross-checking `git show --stat <their-commit>`. Recovery: don't rewrite
their history — just commit only the genuinely-still-uncommitted remainder
(`git add <exact files>; git commit -m ... -- <exact files>`) and note the
mislabeled prior commit in the ready-for-review report so the reviewer can
verify the right diff. Root cause is shared-tree concurrency, not the stash
mechanics — the fix is the same as always: prefer a worktree, and if a plain
`git stash` was already run, treat the immediate post-pop window as
contended and commit your own files IMMEDIATELY, narrowly, before doing
anything else that takes time (like running a 100s+ test suite).
