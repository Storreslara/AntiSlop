---
name: gh468-hcb-branch-completion
description: hcb-branch (issue #468) PASS state — the human-confirmation ask branch on harness-integrity-gate.sh's Write/Edit path
metadata:
  type: project
---

Completed 2026-09-24. Commits: 75f2c0e (gate), dc93e8f (tests),
2f5a530 (regenerated mirror + fileHashes). `bash tests/validate.sh` green
(129/129 in the extended suite), `node bin/cli.js --update --check` clean.

**Non-obvious design point not spelled out plainly in the dispatch packet:**
the plan's C1.7 ("the branch is exactly five paths wide") and OQ1
("(a) config only") together mean Set A's case arm had to be SPLIT — only
`$persona_cfg` gets the `ask_allowed`/`ask` treatment; the 4 audit logs and
their `.seal` sidecars, though they share Set A's case pattern and `deny A`
call, must NOT get it and stay an unconditional deny even under an
allowlisted permission_mode. Implemented via an inner
`if [ "$subject" = "$persona_cfg" ]; then ...ask logic...; fi` inside the
existing Set A arm, preserving "two case arms total" while still gating
ask-eligibility to exactly 5 subjects (persona-config + 4 Set B literals,
including the new `.claude/hooks/scripts/harness-integrity-gate.sh` mirror).
If a future unit touches this again: audit logs staying hard-deny is load
bearing, not an oversight to "fix".

Committing the regenerated `.claude/persona-config.json` required the
sanctioned `git add -A` (no pathspec) + plain `git commit -m` (no `-F`/`--`
naming it) technique from
[[project_harness_integrity_gate_persona_config_commit]] — a `git commit -- .claude/persona-config.json`
or even a bare `git status --short && git diff -- <that path>` in the SAME
Bash call gets blocked by the live production gate on this repo's own
session (it scans the literal Bash command text, not just Write/Edit).

See also [[technique_bash_set_e_and_list_last_statement]] for a set -e bug
hit while writing the mutation-proof test helpers.
