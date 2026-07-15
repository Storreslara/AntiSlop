# ADR 0005: Vendor the mattpocock/skills dependency closure; delete the `<MATTPOCOCK:slot>` substitution mechanism

Date: 2026-07-15
Status: Accepted (completed plan 2026-07-15-vendor-mattpocock-skills, all tracks)

## Context
Two mechanisms shipped mattpocock-derived skill content to consumers:
- **`<MATTPOCOCK:slot>` substitution** — a placeholder in a persona's
  `skills:` line, resolved at ADAPT/`--update` time via
  `persona-config.json`'s `substitutions.mattpocockSkills` map to an
  EXTERNALLY-installed skill (`npx skills@latest add mattpocock/skills`).
  The skill content itself never lived in this repo.
- **First-party plugin-source skill** — content vendored/authored directly
  into `skills/<name>/`, registered in `.claude-plugin/plugin.json`,
  referenced as a plain `antislop:<name>` string, shipped with the plugin.
  `pathfinder` and `fail-triage` already used this pattern.

Requiring an external `npx skills@latest add mattpocock/skills` install step
before a consumer's persona team was fully functional was friction this
mechanism existed only to work around, not friction the mechanism justified
long-term (ADR-0003's "existing mattpocock skill, wired as
`<MATTPOCOCK:to-spec>` slot" language documents the slot-era wiring this ADR
supersedes).

## Decision
1. **Vendor the full closure, verbatim, with credit.** Traced the 7 wired
   slots (`grill-me`, `to-issues`→`to-tickets`, `improve-codebase-
   architecture`, `tdd`, `diagnose`→`diagnosing-bugs`, `to-spec`, `handoff`)
   against upstream `main` and found 5 further transitive skill
   dependencies, for a closed set of 12: `grill-me`, `grilling`, `handoff`,
   `to-spec`, `to-tickets`, `tdd`, `diagnosing-bugs`,
   `improve-codebase-architecture`, `codebase-design`, `domain-modeling`,
   `implement`, `code-review`. Copied byte-verbatim (provenance header +
   pinned upstream SHA aside) except `to-spec`/`to-tickets`/`code-review`,
   whose sole deviation is repointing their `/setup-matt-pocock-skills`
   reference to antislop's native `install-antislop` setup — MIT license
   (© Matt Pocock) retained in full via `skills/THIRD-PARTY-NOTICES.md`.
   `setup-matt-pocock-skills` itself and the `agents/openai.yaml` adapter
   files are explicitly NOT vendored (antislop's `install-antislop` already
   replaces the former; the latter is a non-Claude adapter format outside
   this plugin's scope).
2. **Delete the substitution machinery entirely**, not deprecate it in
   place: `MATTPOCOCK_RE`, `applyMattpocockSubs`,
   `deriveMattpocockSubsForFile`, `hasMattpocockResidue`, the
   `substitutions.mattpocockSkills` map/backfill, the
   `--with-mattpocock`/`--only-mattpocock` install path, and the
   `install-antislop` mattpocock-selection step — removed TDD-first (tests
   rewritten to drop the mattpocock cases before the `bin/cli.js` code was
   deleted, full suite kept green throughout).
3. **Preserve the issue-tracker capture capability natively.**
   `/setup-matt-pocock-skills` used to seed `persona-config.json`'s
   `issueTracker`; `install-antislop` gained a native capture step so that
   capability survives the wizard's removal.
4. **Document a periodic re-sync process** (`docs/maintenance/resync-
   vendored-skills.md` + `scripts/resync-vendored-skills.sh --check`) since
   vendoring trades "always current with upstream" for "pinned snapshot,"
   and that tradeoff needs an actionable maintenance path, not just a
   one-time fork.

## Consequences
- **No more external install step.** A consumer adopting antislop gets all
  12 skills with the plugin; `npx skills@latest add mattpocock/skills` is no
  longer part of setup.
- **Capability loss, intentional and documented (not silently dropped):**
  the `<MATTPOCOCK:slot>` mechanism was also a generic extension point — a
  consumer could wire an arbitrary *unported* mattpocock skill via a slot +
  map entry without antislop shipping that skill's content at all. That
  indirection is gone. The replacement path is to add any new skill (from
  mattpocock or elsewhere) as a first-party `skills/<name>/` entry, the same
  pattern the 12 vendored skills and `pathfinder`/`fail-triage` already use.
  Recorded in `CHANGELOG.md` [0.12.0] alongside this ADR.
- **Vendored content can drift from upstream.** Mitigated, not eliminated,
  by the pinned-SHA + re-sync runbook; a maintainer must periodically run
  the drift check and decide whether to re-pin, rather than upstream fixes
  arriving automatically.
- **Supersedes ADR-0003's slot-era wiring language.** ADR-0003 (`spec-master`
  publishes "via `to-spec` skill (existing mattpocock skill, wired as
  `<MATTPOCOCK:to-spec>` slot)") described the mechanism this ADR replaces;
  `to-spec` is now the vendored `antislop:to-spec` skill referenced directly,
  no slot involved. ADR-0003's persona-split decision itself is unaffected
  and remains in force — only its slot-wiring description is superseded.
  This repo has no established "Superseded by ADR-000X" marker convention
  in prior ADRs (checked 0001-0004), so the supersession is recorded here
  rather than by editing ADR-0003 in place.

## Related
- Plan: `docs/plans/2026-07-15-vendor-mattpocock-skills.md` (all tracks A-F).
- `skills/THIRD-PARTY-NOTICES.md`: full MIT text + per-skill upstream paths
  + pinned SHA.
- `docs/maintenance/resync-vendored-skills.md`: the re-sync runbook.
