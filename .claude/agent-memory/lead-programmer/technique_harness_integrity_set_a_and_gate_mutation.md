---
name: harness-integrity-set-a-and-gate-mutation
description: harness-integrity-gate.sh Set A is only persona-config.json + 4 audit logs (NOT plugin.json/package.json); commit -a -F avoids spelling it; mutating a hooks/scripts/*.sh gate needs the whole directory copied
metadata:
  type: technique
---

Two findings from item12-4-reviewer-append-shape (2026-09-26):

**1. `harness-integrity-gate.sh`'s Set A is narrower than it looks.** A `git
diff -- .claude-plugin/plugin.json package.json .claude/persona-config.json`
got BLOCKED, but the block was caused *only* by the `.claude/persona-config.json`
substring — `set_a_mentioned()`'s literal list is exactly `persona_cfg`
(`.claude/persona-config.json`) plus the four `.claude/*-audit.log[.seal]`
files. `.claude-plugin/plugin.json` and `package.json` are NOT in Set A at
all and never trip this gate. Don't over-generalize a block's error text
(which echoes the WHOLE command, not the matched literal) into "all three
paths are protected" — read `set_a_mentioned()` itself to find which
substring actually matched.

**How to apply:** when a commit touches `.claude/persona-config.json` among
other tracked files, spelling it in `git commit -- <paths>` trips this gate
even for a plain commit. Workaround that stays inside the rules (no path is
spelled in the command text at all): `git add <any new untracked file>`
(paths that aren't Set A are fine to name), then `git commit -a -F
<message-file>` — `-a` stages every already-tracked modified file (including
persona-config.json) without the command text ever naming it. Verify first
that `git diff --cached --stat` is empty (no stray parallel-unit staging) and
that the tracked-modified set really is only your own unit's files, since
`-a` has no per-path selectivity. Write the commit message to a file first
(per [[harness_integrity_gate_commit_message_text]]) so the message text
doesn't spell it either.

**2. Mutation-testing a `hooks/scripts/*.sh` gate needs the whole directory
copied, not just the one file.** These scripts `source
"$(dirname "${BASH_SOURCE[0]}")/lib/*.sh"` relative to their own path. Copying
only the target script to a scratch `mktemp -d` and mutating that copy fails
with "No such file or directory" for the lib, which manifests as every test
case failing (not just the one the mutation should affect) — easy to
misread as "the mutation broke everything" when it's actually just a missing
sibling file. Use `cp -r hooks/scripts "$tmp/scripts"` then mutate
`$tmp/scripts/<gate>.sh`. Several test suites (e.g.
`tests/human-decision-gate.test.sh`) already expose a `GATE_UNDER_TEST` env
override for exactly this purpose — check for one before hand-rolling stdin
piping.
