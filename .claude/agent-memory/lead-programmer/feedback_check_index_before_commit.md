---
name: check-index-before-commit
description: Always inspect git diff --cached --stat before committing in this repo — the working tree often carries pre-existing staged changes from other in-flight plan units
metadata:
  type: feedback
---

Before running `git commit`, always run `git diff --cached --stat` (or
`git status --porcelain`) right before the commit and confirm ONLY the
files your own unit's scope names are staged — never assume `git add
<your files>` starts from a clean index.

**Why:** on issue #94 (Step 5 of the 2026-07-21 no-self-wake plan), the
working tree already had unrelated files staged in the index from a prior
in-flight unit (`agents/orchestrator.md`, `.claude/agents/orchestrator.md`,
and a partial hunk of `.claude/persona-config.json` — Step 2 / issue #91
content). Running `git add <my 3 files>` on top of that pre-staged state
and then `git commit` swept all of it into one commit, silently violating
the unit's `Edit ONLY: ...` scope boundary. Caught only by checking
`git show --stat HEAD` after the fact; fixed via `git reset --soft HEAD~1`
+ `git restore --staged <the files that weren't mine>` + re-commit — safe
only because nothing had been pushed yet.

**How to apply:** in any repo where multiple units/sessions may leave
uncommitted-but-staged work sitting in the same working tree (this repo's
plan-with-many-issues workflow is exactly that shape), treat the index as
untrusted state. `git add` only the exact paths your unit's scope names,
then verify with `git diff --cached --stat` (or `--name-only`) BEFORE
committing, not after. If unrelated files are already staged, unstage them
first (`git restore --staged <path>`) — don't assume a fresh `git add` of
your own files means the commit will only contain your own files.

**When units run truly in PARALLEL (shared index race):** verify-then-commit
is not enough — another agent can `git add` into the shared index in the
window between your `git diff --cached` check and your `git commit`. On issue
#102 (6 parallel units, one working tree) a `git add`-then-commit swept two
files another agent staged concurrently (`.claude/settings.json`, a docs
file) even though my staged diff was clean moments earlier. The robust fix is
a **pathspec-limited commit**: `git commit -o <file1> <file2> -m ...` (the
`-o`/`--only` form commits ONLY the named paths' working-tree content,
ignoring whatever else is in the shared index — no staging step, no race
window). Also note: `git reset --soft HEAD~1` is dangerous under parallel
commits — if another agent's commit became the tip after yours, HEAD~1 is
THEIRS, not yours; check `git reflog` to confirm you rewound your own commit.
