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

**The race runs in BOTH directions — and the reverse one is not fixable by
`-o`.** On issue #145 (parallel with #141/#144) I staged my two files, and a
parallel agent's `git add -A`-style commit landed in that window and swallowed
them into ITS commit; my own `git commit` then reported "no changes added to
commit". `-o`/`--only` protects other units from YOU, but nothing protects
your staged content from another agent's broad `git add`. So: stage and commit
in a single command, or use `git commit -o <paths>` with no prior `git add` at
all, keeping the window at zero.

**If your work does land inside another unit's commit, do NOT rewrite it.**
The tempting fix (`reset --soft` + re-split) invalidates the SHA the other
in-flight agent is very likely citing in its own review packet, converting
their PASS into an unverifiable range through no fault of theirs. The content
is already correct in the tree; report your unit with a path-scoped range
instead (`git show <sha> -- <your paths>`) and flag the contaminated commit
boundary explicitly so both reviewers know to scope their diffs.

**NEW FILES need `git add -N` first.** `git commit -- <paths>` (and `-o`)
errors with `pathspec '<f>' did not match any file(s) known to git` when a
path is untracked — git resolves the pathspec against the index. Fix without
reopening the race: `git add -N <exact paths>` (intent-to-add only, stages no
content) and then the usual `git commit -- <paths>`, which still takes
working-tree content for exactly those paths and leaves a sibling's staged
work untouched. Hit on #132 (2026-08-10).

**RECURRED on #141** (2026-07-29, Step 2 of the namespace-gate plan) — the
same mistake, with this note already written: I ran the verify-then-`git add`
sequence anyway, and two `adapters/codex/**` files a parallel unit staged in
the gap landed in my commit. So the pathspec form is not the "careful" option
to reach for when things feel risky, it is the ONLY commit form to use in
this repo: `git commit -F - -- <paths>` works identically to `-o <paths>`
(both commit the named paths' working-tree content and leave the rest of the
shared index untouched, so a sibling's staged work survives intact). Recovery
was `git reset --soft HEAD~1` (reflog-checked: my commit was still the tip)
then re-commit with `--`, which preserved the sibling's staged files exactly
as they were.
