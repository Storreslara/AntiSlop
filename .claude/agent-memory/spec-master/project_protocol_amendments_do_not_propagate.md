---
name: protocol-amendments-do-not-propagate
description: Amending templates/persona-protocol.md does NOT reach a persona's own body or the Codex port; scope all six approve-attestation surfaces explicitly, never count .claude/protocol-digest.md as a protocol mirror (a UNIVERSAL_PROTOCOL_CORE section lands in 16 files, not 17), and bump the version BEFORE running --update or mirrors silently stay stale.
metadata:
  type: project
---

Three traps that fire on any spec that amends `templates/persona-protocol.md`.
Traps 1 and 2 were measured at `2b5b853` while writing Addendum A of
`docs/plans/2026-08-15-dashboard-decision-run-and-pill-controls.md`; trap 3 was
measured 2026-09-24 (see below).

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

## 3. `.claude/protocol-digest.md` is NOT a protocol mirror — never count it

Measured 2026-09-24 correcting a shipped defective criterion (gh479 / Step 3 of
`docs/plans/2026-09-23-cost-governance-output-cap-and-effort-tiers.md`, which
said "17 files: 4 sources + 13 mirrors including the digest"). The real count
for a `UNIVERSAL_PROTOCOL_CORE` section is **16**:

- 4 hand-maintained sources — `templates/persona-protocol{,-slim}.md`,
  `adapters/cursor/rules/persona-protocol.mdc`,
  `adapters/codex/agents-md-fragment.md`
- 12 generated mirrors — `.claude/persona-protocol{,-slim}.md` + all 10
  `.claude/agents/*.md`

**Why:** `.claude/protocol-digest.md` is a **verbatim copy** of the separate
hand-written `templates/protocol-digest.md` (`bin/cli.js:564-566`). Only
`templates/persona-protocol.md` feeds `UNIVERSAL_PROTOCOL_CORE`, via
`parseProtocolSections` (`bin/cli.js:676-683`). The digest carries one `#`
heading and **zero `## ` sections**, so it structurally cannot hold protocol
prose, and its own header caps it at ~15 lines. Adding the paragraph to its
template to "make the count work" yields 18, not 17, and breaches that cap.

**How to apply:** never write a file-count criterion from an assumed mirror
list — run `git grep -l "<exact sentence>" | wc -l` against the landed text
first, or on a sibling section already in the core. Note the digest DOES get
re-copied by `--update` (byte-identically), so it legitimately appears in a
"files touched by `--update`" list while never appearing in a grep-count
criterion — two different lists, easily conflated. See
[[feedback-verify-own-criteria-nonvacuous]].
