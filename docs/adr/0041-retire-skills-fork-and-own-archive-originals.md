# ADR 0041: Retire ten skills, fork-and-own the edited vendored skills, archive originals under `docs/archive/skills/`

Date: 2026-10-14
Status: Accepted
Amends: ADR-0005, ADR-0012, ADR-0031
Ratified by: user (repo owner), 2026-10-14 (skills audit, Open Question 2)

## Context

The skills audit (plan `docs/plans/2026-10-14-skills-audit-implementation.md`) found two near-duplicate grill skills (the ADR-0031 description collision), a `code-review` skill that duplicates the reviewer, `to-spec`, `to-tickets` and `fail-triage`, which only restate or conflict with persona prose (task-master's "to-tickets precedence" block existed only to override `to-tickets`), and vendored text written for an interactive human (grilling one question at a time, an HTML report opened with `xdg-open`, "confirm seams with the user") that a one-shot subagent cannot follow.

## Decision

1. Retire the five vendored skills `grill-me`, `grill-with-docs`, `code-review`, `to-spec` and `to-tickets`, the first-party `fail-triage`, and the four graph-generated local skills (`debug-issue`, `explore-codebase`, `refactor-safely`, `review-changes`). `to-spec` and `fail-triage` are merged into `agents/spec-master.md`, `to-tickets` into `skills/pathfinder`.
2. The vendored skills whose text antislop now edits (`grilling`, `tdd`, `diagnosing-bugs`, `improve-codebase-architecture`) are **fork-and-own**: the live file carries a "Derived from" header, and drift tracking moves to the archived byte-verbatim copy, so `scripts/resync-vendored-skills.sh --check` still reports upstream drift. This is not a declared deviation (ADR-0012): a declared deviation keeps the live file drift-tracked against reconstructed upstream text; a forked skill's live file is not drift-tracked, only its archived copy is.
3. Every pre-change original of a skill that was deleted, merged away or rewritten is kept byte-identical under `docs/archive/skills/<name>/`, with an index row in `docs/archive/skills/README.md` naming its origin path and commit. No skill loader discovers that directory and nothing mirrors or hashes it; `scripts/resync-vendored-skills.sh` lists the archived originals of the forked skills as the local side of its upstream drift check. The npm package ships no `docs/` path, while a git clone or plugin install carries it as inert files (ADR-0022).

## Consequences

- Upstream fixes no longer flow into forked skills automatically; `--check` on the archived copy tells a maintainer when to port one by hand. `handoff`, `domain-modeling` and `codebase-design` stay vendored verbatim.
- Consumers lose six skills on their next plugin update, and the drift-tracked set shrinks from 9 to 7.
- Skill menus come from the installed plugin cache, so retirements reach a session only after a plugin update.

## Why the three ADR tests hold

- Hard to reverse: consumer-visible skill removals and a changed drift-tracking target.
- Surprising without context: an in-tree archive when git history already has the files; the operator required originals browsable without git archaeology.
- A real trade-off: fork-and-own versus a per-edit declared-deviation class versus keeping the text verbatim (Open Question 2 of the plan).

## Related

- Plan: `docs/plans/2026-10-14-skills-audit-implementation.md`, Step 11 (unit `skr-11`, this ADR).
- ADR-0005, ADR-0012 and ADR-0031: amended by this ADR (reciprocal `Amended by ADR-0041` bullets).
- ADR-0003 and ADR-0022: this ADR changes their `to-spec` / `to-tickets` wording and skill count in substance; they are historical and are not edited in place.
- `docs/archive/skills/README.md`: the archive index.

## Corrections

- 2026-10-14 (unit sfu-1): the title said five skills while Decision 1 retires ten, and Decision 3 said nothing ships the archive, overstating ADR-0022's npm-only exclusion. Both corrected in place; the decision is unchanged.
- 2026-10-14 (unit lov-1): Decision 3 said nothing lists the archive, but `scripts/resync-vendored-skills.sh` names the archived originals of the four forked skills as the local paths of its drift check. Corrected in place; the decision is unchanged.
