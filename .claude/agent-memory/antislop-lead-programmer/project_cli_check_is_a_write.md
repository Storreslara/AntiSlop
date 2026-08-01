---
name: cli-check-is-a-write
description: bin/cli.js --update --check is a forced WRITE, not a dry run - measure no-op properties differentially between two throwaway git worktrees
metadata:
  type: project
---

`node bin/cli.js --update --check` is a **forced render**, not a report.
`checkFlag` gates only the "already current" fast-path (`bin/cli.js:711`); every
`copyStampedBody` write and both `persona-config.json` writes run unguarded. Run
it against the working tree and you dirty six mirrors plus
`.claude/persona-config.json`. Conversely a *plain* `--update` on a clean tree
usually takes that fast-path and writes nothing — so
`git diff --numstat -- .claude/agents/` after it proves only that the fast-path
fired. The two obvious "did my change alter the mirrors?" checks are therefore
one destructive and one vacuous.

**Why:** during Pass-1 of the efficiency-audit plan the mirrors are deliberately
stale against the templates until the final regeneration step, so *any* render
during the middle steps legitimately differs from what is on disk.

**How to apply:** measure a no-op differentially — `git worktree add` BASE and
BASE+your-commit, render in both, `diff -r` the two `.claude/agents` trees. The
pending template prose cancels because both sides carry it. Always pair it with
a mutation control (append a throwaway line to `templates/persona-protocol.md`
in one worktree only; `diff -rq` must then flag all six full-tier mirrors and
*not* the slim ones) — a mis-pathed `diff -r` is green forever otherwise. Same
`git rev-parse HEAD` caution as
[[bash-lexer-gate-traps]] item 4 when picking BASE.

Related: [[marker-gate-blocks-own-commits]].
