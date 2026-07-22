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
