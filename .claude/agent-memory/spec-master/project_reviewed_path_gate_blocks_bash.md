---
name: reviewed-path-gate-blocks-bash
description: spec-master CAN inspect .claude/reviewed/ with plain read-only Bash (ls/cat/grep/test); the gate blocks only redirects, substitutions, git and rg. Corrects an earlier over-broad note.
metadata:
  type: project
---

`reviewed-path-gate.sh` (PreToolUse) does **not** block read-only inspection of
`.claude/reviewed/` by spec-master. Verified live 2026-08-07: `ls
.claude/reviewed/`, `ls .claude/reviewed/<id>.pass` and piping `ls` into `grep`
all succeed.

**Corrects a previous version of this memory**, which claimed the gate blocked
all Bash access including `ls`/`cat`. That was wrong — most likely inferred from
a block whose real cause was one of the triggers below, not the path itself.

What actually trips it (per the hook's own refusal text):
- a **redirect** (`2>&1`, `>file`) or a command substitution anywhere in the
  command — even when the redirect belongs to an unrelated part of a compound
  command;
- running a program that *could* write, or a command line it cannot lex
  (unbalanced quote, backslash escape, heredoc are never assumed benign);
- **`git` and `rg` are not allowlisted at all**, whatever the subcommand.

**Why:** the gate enforces review ownership — only the reviewer writes markers
there — so it is conservative about anything it cannot prove is read-only.

**How to apply:** inspect the directory with a *bare* `ls`/`cat`/`grep`/`test`
and no redirects or `$( )`. If a compound command gets blocked, split the
read-only part out rather than concluding the path is unreadable. To search it,
use `grep -r`. To commit a message that merely mentions the path, write the
message to a file and use `git commit -F <file>`. See
[[to-spec-slash-only]] for the other spec-master tooling-access quirk, and
[[adr-numbering-increment-not-backfill]] for a numbering trap this directory's
task-id convention (bare numbers, e.g. `243.pass`) helps cross-check.
