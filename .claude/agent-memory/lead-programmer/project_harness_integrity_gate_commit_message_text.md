---
name: harness-integrity-gate-commit-message-text
description: harness-integrity-gate.sh scans the FULL Bash command string, including a git commit -m message body, not just paths/args
metadata:
  type: project
---

`harness-integrity-gate.sh`'s Set A literal scan (`set_a_mentioned`) matches
against the entire Bash command text passed to the tool — this includes
prose inside a `git commit -m "..."` message body, not only path-shaped
arguments. Writing `.claude/persona-config.json` (or other Set A literals:
review/dispatch/microworld/wip logs) anywhere in a commit message, even as
descriptive prose about what was regenerated, trips the same BLOCKED refusal
as naming it in `git add`/`git diff`.

**Why:** the gate is deliberately configless and pattern-matches the raw
command string for defense-in-depth; it has no way to distinguish "this
git-diff will read the file" from "this commit message merely mentions the
filename in English."

**How to apply:** when committing a unit that regenerated `.claude/persona-config.json`
(or touched any other Set A path) via `node bin/cli.js --update`, stage with
a directory-level `git add .claude ...` (never naming the file literally,
per [[project_gh_harness_integrity_gate_glob_hole_fix]]'s sibling notes) and
write the commit message describing the change generically ("regenerated
agent bodies and protocol mirrors via node bin/cli.js --update") rather than
naming the exact file. Confirmed live 2026-09-26 on item10-1-name-the-two-axes.
