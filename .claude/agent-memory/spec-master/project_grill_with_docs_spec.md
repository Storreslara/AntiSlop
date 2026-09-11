---
name: grill-with-docs-spec
description: Settled decisions and measured baselines for the 2026-09-11 grill-with-docs vendoring + spec-master pivot spec (4 fast-path units), incl. the fm-noflag header-swap trap
metadata:
  type: project
---

Spec: `docs/plans/2026-09-11-grill-with-docs-vendoring-and-spec-master-pivot.md`
(4 fast-path units `gwd-1`..`gwd-4`). One open question relayed: who writes
`CONTEXT.md`/ADRs when `spec-master` runs `grill-with-docs` — default (b),
glossary inline, ADRs drafted for `scribe`.

**Why:** the change reverses ADR-0012's "grill-me is the control,
deliberately left alone" decision, so it needed a new ADR (0031) plus the
reciprocal amendment, not a silent edit.

**How to apply — settled decisions, do not re-derive:**
- `skills:` is **supplemented**, not replaced: `grill-with-docs` +
  `grilling` + `domain-modeling` all preload, because grill-with-docs's
  entire body is `Run a /grilling session, using the /domain-modeling skill.`
- ADR bodies are never rewritten here; corrections ride on a `Status:`
  parenthetical + an `Amended by ADR-NNNN` `## Related` bullet. Precedents:
  0004→0006, 0005→0012, 0006→0009, 0010→0026. So ADR-0012's now-false
  asymmetry table row stays, annotated.
- `CONTEXT.md`'s "only 2 of 17 skills" is reworded to drop the count (not
  incremented); `docs/adr/0022`'s identical sentence is left as a dated
  record. Removing the count beats keeping two copies in sync.
- `agents/milestone-auditor.md:24`'s "(the skill invoked is grilling)"
  stays — it remains TRUE after the un-flagging (that persona declares only
  `grilling`); only its ORIGINAL rationale dies.

**The fm-noflag trap that will cause a FAIL if missed:** converting a skill
from `fm` to `fm-noflag` changes **two** things in the file, not one — the
flag line is deleted AND the whole provenance header line is replaced with
the ASCII variant (`MIT (c) 2026 Matt Pocock - see …` vs the `fm` form's
`MIT © 2026 Matt Pocock — see …`). `scripts/resync-vendored-skills.sh:81`
builds a different header string for `fm-noflag`, so a header left alone
turns `--check` red.

**Measured baselines at HEAD `23b0fb4`, 2026-09-11** (reuse instead of
re-measuring): `resync --check` exit 0 with 8 `[OK]`; upstream fetch from
`raw.githubusercontent.com` works (~4 s); upstream `grill-with-docs`
SKILL.md is 245 bytes; runbook table 11 rows; NOTICES table 11 rows;
`grep -c ':fm-noflag:'` 2; `ls -d skills/*/` 17; `grep -c 'grill-me'
agents/spec-master.md` **6** (21, 39, 40, 41, 143, 183 — I first miscounted
this as 5); all 15 `antislop:<x>` tokens across 6 personas resolve to a real
`skills/<x>/SKILL.md`.

**Blast radius, measured — do not re-derive:** `protectedPaths` is `[]`; no
`fileHashes` entry starts with `skills/`; `.claude/skills/` mirrors only
`install-antislop` + `coding-discipline` (`bin/cli.js:2380-2381`), never the
vendored set; no test asserts any persona's `skills:` line or spec-master's
prose; a `grill` sweep over tests/hooks/scripts/bin/adapters/templates/
commands hits only `scripts/resync-vendored-skills.sh`.

**Recorded gap adopted into the spec:** the `unit=gh359` PASS note proposed
a `tests/validate.sh` loop asserting every `antislop:<x>` in an `agents/*.md`
`skills:` line has a `skills/<x>/SKILL.md`. Nothing checked this before;
without it the pivot's central wiring claim ships unguarded. See
[[pass-note-warnings-do-not-propagate]] and
[[validate-sh-is-a-mirror-parity-check]].
