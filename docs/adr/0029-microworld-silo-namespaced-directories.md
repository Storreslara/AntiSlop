# ADR 0029: Microworld silo — namespaced directories plus a canonical index

Date: 2026-09-04
Status: Accepted (plan `docs/plans/2026-08-11-microworld-silo.md`, Step 6)

## Context

The microworld dashboard feature area was scattered across four
unrelated-looking naming families with no artifact tying them together: the
old *bin/dashboard/* (code, since renamed — see Step 1), `tests/dashboard-*.test.js`
and `tests/microworld-*.test.*` (tests, two separate prefixes), and
`hooks/scripts/microworld-rerun.sh` (the reporter hook). A reader who grepped
`microworld` missed *bin/dashboard/* entirely; a reader who grepped
`dashboard` missed the reporter hook and its contract test. Docs and ADRs for
the area were likewise unindexed — nothing said in one place where the
feature actually lived.

## Decision

**Namespaced silo plus canonical index**, not a physical silo and not the
status quo. Concretely:

- Code moved to `bin/microworld-dashboard/` (Step 1).
- Tests moved to `tests/microworld/` (Step 2).
- The reporter hook stays at `hooks/scripts/microworld-rerun.sh`, alongside
  every other hook — hooks are located by `hooks.json` registration, not by
  feature area.
- Docs and ADRs stay where they already live (`docs/adr/`, `docs/plans/`,
  `CONTEXT.md`, `.claude/wiki/`).
- A new `docs/microworld/README.md` (Step 4) is the canonical index that
  names every one of those locations in one file, so the silo is discoverable
  without a lucky grep.

## Alternatives rejected

**(b) A full physical silo — move the hook and the docs under one tree too.**
Rejected because hooks are located by `hooks.json` registration, not by
directory position; relocating `hooks/scripts/microworld-rerun.sh` would
desynchronize its tracked mirror (`.claude/hooks/scripts/microworld-rerun.sh`)
and the two adapter mirrors under `adapters/` without buying any
discoverability the canonical index doesn't already provide. A full silo also
implies moving `CONTEXT.md` entries and ADRs out of the repo's single
glossary/decision-record homes, which would fragment institutional knowledge
that is deliberately kept centralized for every other feature area.

**(c) Leave everything flat, no reorg at all.** Rejected because a
`microworld` grep misses the old *bin/dashboard/* entirely (the original name
carried no `microworld` token), and a `dashboard` grep misses the reporter
hook and its contract test. The naming mismatch was the actual defect this
plan exists to fix — an index alone, with no directory rename, would still
leave a reader who trusts the old *bin/dashboard/* name with an incomplete
picture of what "microworld" means in this codebase.

## Consequences

**Historical citations are not rewritten.** Existing entries in
`CHANGELOG.md`, `.claude/wiki/changelog.md`, `docs/plans/`, and `docs/adr/`
that cite the pre-reorg paths (the old *bin/dashboard/…*, `tests/dashboard-*.test.js`,
etc.) are left exactly as written — rewriting them would make their commit
SHAs disagree with the paths they describe and destroy the audit trail. Any
path cited in one of those four locations must be read as "the path as of
that entry's date," not as a live path. Only *living* reference docs
(`CONTEXT.md`, `.claude/wiki/architecture.md`, `docs/microworld/README.md`)
describe the current tree.

## Related decisions

- `docs/adr/0017-microworld-bundles-gitignored.md` — why microworld bundles
  themselves are gitignored working-tree scratch, not committed.
- `docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md` —
  why the dashboard process superseded the earlier fixture-only design.
- `docs/microworld/README.md` — the canonical index this ADR's decision
  produces (Step 4 of the same plan).
