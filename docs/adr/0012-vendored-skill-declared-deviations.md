# ADR 0012: Vendored-skill declared deviations (`fm-noflag`)

Date: 2026-08-07
Status: Accepted

## Context
ADR-0005 vendors the mattpocock/skills closure byte-verbatim by default
(provenance header and pinned upstream SHA aside). A **declared deviation** is
a documented, machine-reconstructed departure from that default — a change
the drift script is taught to expect and reconstruct, rather than an
undeclared edit that would silently drift.

Unit **#248** (Step 5 of spec **#245**) needed exactly one such deviation:
stripping upstream's `disable-model-invocation: true` line from `handoff` and
`improve-codebase-architecture` so those two skills are reachable by any
antislop persona in any mode (the flag removes a skill from a persona's
context everywhere it is set). Leaving the flag in place kept both skills
unreachable; stripping it without declaring the change would have turned
`scripts/resync-vendored-skills.sh --check` red on the very drift check that
protects vendored content. Declaring the deviation — teaching the script a
new reconstruction type, `fm-noflag`, in its `FILES` table — keeps both:
the skills are reachable, and drift coverage on them is retained.

## Decision
`fm-noflag` is the reconstruction type in `scripts/resync-vendored-skills.sh`'s
`FILES` table that implements the declared-deviation class for this one
existing deviation (upstream model-invocation-block removal). It performs the
same `fm`-type header insertion as byte-verbatim rows, then removes the
`disable-model-invocation: true` line from the *expected* content before
diffing, so `--check` compares the vendored file against the deviation it was
declared to have, not against the untouched upstream byte stream.

The deviation does not apply uniformly across the five skills descended from
this decision. The asymmetry is deliberate, not an oversight:

| skill | upstream flag stripped? | drift-tracked as | in the script's `FILES` (byte-diffed)? |
|---|---|---|---|
| `handoff` | yes | `fm-noflag` | yes |
| `improve-codebase-architecture` | yes | `fm-noflag` | yes |
| `to-spec` | yes | untracked | no — `REPOINT_SKILLS`, reported only |
| `to-tickets` | yes | untracked | no — `REPOINT_SKILLS`, reported only |
| `grill-me` | no — still flagged | `fm` (byte-verbatim) | yes |

Only `handoff` and `improve-codebase-architecture` are drift-tracked as
`fm-noflag`: they are the two skills that needed the un-flag to become
reachable, and they sit in the script's byte-diffed `FILES` set. `to-spec` and
`to-tickets` were also un-flagged (by Step 4 of the same plan) but sit in
`REPOINT_SKILLS`, the never-diffed repoint set — the script reports their
presence but never byte-diffs their content, so they carry the same
deviation without being tracked as `fm-noflag` or any other reconstruction
type. `grill-me` is the control: still flagged by upstream, still vendored
byte-verbatim, deliberately left alone.

**Consequence of the asymmetry.** Because `to-spec` and `to-tickets` are
never diffed, `disable-model-invocation: true` silently returning to either
of them on a future re-pin would not be caught by `--check`. This gap is
recorded here, not fixed — closing it would mean moving those two skills into
the diffed `FILES` set, which is outside this ADR's and unit `245-CF1`'s
scope.

## Consequences
- Declaring a deviation via `fm-noflag` keeps drift coverage on the two
  skills that need it, instead of the alternative (moving them to the
  never-diffed set) which would have lost coverage entirely.
- The declared-deviation class is now the *architectural* record; the
  *mechanical* reconstruction type (`fm-noflag` in `FILES`) and the
  *operational* record (the runbook, NOTICES, README) both already existed
  from Step 5 — this ADR is what ties the three together and names the
  concept.
- The `to-spec`/`to-tickets` blind spot (above) persists until those two
  skills are moved into the diffed set, which this ADR does not propose.

## Related
- **ADR-0005** (vendor the mattpocock/skills closure): this ADR qualifies,
  does not withdraw, ADR-0005's Decision 1 "verbatim" statement. See
  ADR-0005's `Status:` line and `## Related` bullet for the reciprocal note.
- `docs/maintenance/resync-vendored-skills.md`: the re-sync runbook,
  including the `fm-noflag` reconstruction type and the deviation callout.
- `skills/THIRD-PARTY-NOTICES.md`: per-skill upstream provenance table.
- Plan: `docs/plans/2026-08-04-skills-library-remediation.md`, Step 5 (spec
  #245, unit #248) and Convergence follow-ups → Step 11 (unit `245-CF1`,
  this ADR).
