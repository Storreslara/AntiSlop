# Microworld feature index

An index, not a tutorial. This page names every location the microworld
feature occupies so that a `grep microworld` doesn't miss half the feature
area. For how the dashboard works, see `README.md`'s own "Microworld
dashboard" section; for why the feature is shaped this way, see the two ADRs
listed below. This file does not repeat either.

## Locations

- `bin/microworld-dashboard/` — the dashboard implementation. Ten modules
  (verified live) covering the dashboard server, bundle discovery, function
  invocation, the audit-log parser, the feedback-block formatter, the source
  reader, the markdown-lite renderer, the decision surface, and the D5
  browser client.

- `tests/microworld/` — all fourteen tests for the dashboard and its
  supporting modules (verified live). One of them,
  `tests/microworld/microworld-audit-contract.test.js`, is the cross-language
  contract test binding the bash reporter hook to the Node audit-log parser.

- `hooks/scripts/microworld-rerun.sh` — the **Reporter** hook. It stays under
  `hooks/scripts/` rather than moving into this silo because hooks are
  located by their registration in `hooks/hooks.json`, not by feature area.
  Its adapter mirrors live under `adapters/`:
  `adapters/cursor/hooks/scripts/microworld-rerun.sh` and
  `adapters/codex/hooks/scripts/microworld-rerun.sh`.

- `docs/adr/0017-microworld-bundles-gitignored.md` and
  `docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md` —
  the rationale for the bundle format being gitignored working-tree scratch,
  and for the dashboard superseding the earlier fixture-only narrowing
  approach.

- `CONTEXT.md` — the glossary home for microworld terminology (microworld
  bundles, the watch-map, the Microworld audit log, and related terms).

## Also microworld-named, but outside `tests/microworld/`

Three tests exercise the session-start and stop-gate hooks rather than the
dashboard, so they deliberately live outside this silo:
`tests/session-start-microworld-status.test.sh`,
`tests/stop-gate-microworld-skip.test.sh`, and
`tests/stop-gate-deferred-microworld.test.sh`. `tests/microworld/` is not the
whole microworld test surface.

## Not on disk

These are gitignored runtime artifacts that exist only when the feature runs,
never as static paths in the repo:

- `microworlds/<unit-slug>/` — per-unit bundle working directories.
- `.claude/microworld-audit.log` — the audit log the Reporter hook writes to
  (plus its per-adapter equivalents).
- `.claude/human-review/<task-id>/` — escalation packets.
