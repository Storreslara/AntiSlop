---
name: protocol-amendments-do-not-propagate
description: Amending templates/persona-protocol.md does NOT reach a persona's own body or the Codex port; scope all six approve-attestation surfaces explicitly, and bump the version BEFORE running --update or mirrors silently stay stale.
metadata:
  type: project
---

Two traps that fire together on any spec that amends
`templates/persona-protocol.md`. Both were measured at `2b5b853` while writing
Addendum A of `docs/plans/2026-08-15-dashboard-decision-run-and-pill-controls.md`.

## 1. The protocol block is TRIMMED — a template edit may reach nobody

`bin/cli.js` inlines a **per-persona trimmed subset** of the protocol into
`.claude/agents/*.md`, not the whole file. The "Resolving an escalation:
the DECISION file and the three routes" section is **not** in any persona's
block. Evidence: `agents/reviewer.md` has no `ANTISLOP:BEGIN` markers at all,
and in the generated mirror the block opens at line ~358 while the approve-route
text sits at line ~302 — i.e. *outside* it.

So Step 6 of gh377 amended the template + the Cursor port, passed its parity
criterion, and the reviewer that must actually perform the duty never saw it.
Feature shipped documented-but-unexecuted.

**Why:** `PROTOCOL_SECTIONS_BY_PERSONA` in `bin/cli.js` decides the trim. A
section outside a persona's slice can never reach it by construction.

**How to apply:** before writing "amend the protocol" as a step, run
`git grep -l "<the exact sentence>"` and enumerate EVERY surface. For the
approve attestation line the full set is six:
`templates/persona-protocol.md`, `.claude/persona-protocol.md` (generated),
`adapters/cursor/rules/persona-protocol.mdc`, `agents/reviewer.md`,
`.claude/agents/reviewer.md` (generated), `adapters/codex/agents-md-fragment.md`.
Note `adapters/{cursor/agents/reviewer.md,codex/agents/reviewer.toml}` carry
**no** escalation-resolution text — adapters keep that duty in the protocol
port only, so they are never in scope for this class of edit.

`tests/adapter-protocol-parity.test.js` will NOT catch the gap: it checks
section *presence* via literal probes in `ESCALATION_PROBES`, so a new clause
with no probe drifts freely. Add probes in the same unit — see
[[technique-branch-agreement-criterion]] and
[[feedback-verify-own-criteria-nonvacuous]].

## 2. `--update` short-circuits on an unchanged version

Measured on a clean tree: `node bin/cli.js --update` printed *"antislop
v0.31.66 — already current. Nothing to update."* and regenerated **nothing**.

**Why:** the script compares `.claude-plugin/plugin.json`'s version against the
recorded one and exits early when equal.

**How to apply:** in any spec touching a version-stamped source, order the
edits **bump → CHANGELOG → `--update`**, and say so explicitly. Bump BOTH
`.claude-plugin/plugin.json` and `package.json` (`tests/validate.sh:80`
asserts they are equal). If an implementer reports "already current", the bump
did not land — that is an escalation, never something to work around. Related:
[[project-config-recovery-has-no-automated-route]],
[[project-validate-sh-is-a-mirror-parity-check]].
