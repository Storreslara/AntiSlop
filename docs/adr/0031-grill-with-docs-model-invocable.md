# ADR 0031: Vendor `grill-with-docs` and make both grill skills model-invocable (amends ADR-0012)

Date: 2026-09-11
Status: Accepted (amends ADR-0012; does not supersede it)

## Context
ADR-0012 placed `grill-me` in the byte-verbatim `fm` class as the deliberate
control — still flagged by upstream, still vendored byte-verbatim,
deliberately left alone — while `handoff` and `improve-codebase-architecture`
were converted to `fm-noflag` so they could be reached in every mode.
`grill-with-docs` was never vendored at all.

`spec-master`'s interrogation step is being pivoted from bare `grilling`
onto `grill-with-docs`, so that grilling also produces `CONTEXT.md`
glossary and ADR side effects rather than Q&A alone. That pivot is
impossible while the skill carries `disable-model-invocation`: that flag
removes a skill from a persona's context in every mode (`CONTEXT.md:1027`,
"entirely unreachable … in all modes"). Separately, the operator asked for
`grill-me` itself to become model-invocable as well, reversing the specific
"control" role ADR-0012 assigned it.

## Decision
`grill-with-docs` is vendored into `skills/grill-with-docs/SKILL.md` as a
new `fm-noflag` declared deviation, and `grill-me` is converted from the
byte-verbatim `fm` class to `fm-noflag`. The `fm-noflag` set is therefore
**four** skills — `handoff`, `improve-codebase-architecture`, `grill-me`,
`grill-with-docs` — all still byte-diffed by `scripts/resync-vendored-skills.sh --check`.

ADR-0012's *mechanism* — the declared-deviation class itself, and the
reconstruction `fm-noflag` performs (strip `disable-model-invocation: true`
from the expected content before diffing) — is unchanged and is being
applied to two more skills, not replaced. Only the per-skill asymmetry
ADR-0012 recorded (`grill-me` as the un-converted control) is amended.

## Consequences
- **Description collision, not locally disambiguable.** Once both are
  model-invocable, `grill-me` ("A relentless interview to sharpen a plan or
  design.") and `grill-with-docs` ("A relentless interview to sharpen a plan
  or design, which also creates docs (ADR's and glossary) as we go.") are
  two model-invocable skills with near-identical descriptions, and nothing
  prevents the harness from selecting `grill-me` when a user says "grill
  me," yielding interrogation with no docs side effect. The descriptions
  cannot be edited to disambiguate: both files are drift-tracked, and
  `fm-noflag` reconstructs the upstream description byte-for-byte, so any
  edit to a description turns `--check` red. The only available mitigation
  is `spec-master`'s own prose naming `grill-with-docs` explicitly, which is
  why the pivot in `agents/spec-master.md` is a prose change and not merely
  a frontmatter change.
- **A stale rationale, not a stale sentence.** `agents/milestone-auditor.md:24`'s
  "(the skill invoked is grilling)" parenthetical was authored
  (`CHANGELOG.md:161`) on the rationale that "`grill-me` is a disabled,
  non-invocable pointer." That rationale no longer holds now that `grill-me`
  is model-invocable, even though the sentence itself remains literally true
  — `milestone-auditor`'s own `skills:` line declares only
  `antislop:grilling`, so `grilling` is still the skill it invokes. This ADR
  records the point so a future reader does not mistake the sentence's
  continued truth for evidence the rationale still applies.
- **ADR-0012's `to-spec`/`to-tickets` never-diffed blind spot is untouched**
  by this ADR — this decision only converts skills already in the byte-diffed
  `FILES` set, and does not move `to-spec`/`to-tickets` into it.
- **`spec-master` / `scribe` boundary.** `grill-with-docs` delegates to
  `domain-modeling`, which both `spec-master` and `scribe` now preload.
  `spec-master` writes `CONTEXT.md` glossary entries directly during
  grilling, but only drafts ADRs into the plan document's Context section,
  leaving numbering and landing to `scribe`, whose custody of `docs/adr/` is
  otherwise unchanged.

## Related
- **ADR-0012** (vendored-skill declared deviations, `fm-noflag`): this ADR
  amends its per-skill asymmetry table row for `grill-me`
  (`| \`grill-me\` | no — still flagged | \`fm\` (byte-verbatim) | yes |` at
  line 42) and its "`grill-me` is the control … deliberately left alone"
  sentence (lines 53-54). That row and sentence were true when written
  (2026-08-07) and have since been reversed by this ADR; ADR-0012's
  declared-deviation mechanism itself stands unamended. See ADR-0012's
  `Status:` line and `## Related` bullet for the reciprocal note.
- **ADR-0005** (vendor the mattpocock/skills closure byte-verbatim): this ADR
  extends the declared-deviation pattern ADR-0005 → ADR-0012 already
  established, without qualifying ADR-0005's Decision 1 further.
- **ADR-0003** (hivemind split: `spec-master` / `task-master`): the
  `spec-master` / `scribe` glossary-and-ADR boundary recorded above
  preserves ADR-0003's persona split where it is load-bearing (ADR custody)
  and relaxes it only where it is not (glossary entries).
- Plan: `docs/plans/2026-09-11-grill-with-docs-vendoring-and-spec-master-pivot.md`,
  Step 2 (unit `gwd-2`, this ADR).
- `docs/maintenance/resync-vendored-skills.md`: the re-sync runbook,
  including the `fm-noflag` reconstruction type and the deviation callout.
