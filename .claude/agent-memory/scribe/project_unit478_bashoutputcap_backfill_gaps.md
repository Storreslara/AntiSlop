---
name: unit478_bashoutputcap_backfill_gaps
description: Unit #478 (cost-governance-step2-cap-backfill) known gaps and non-blocking items
metadata:
  type: project
---

**Unit:** cost-governance-step2-cap-backfill, issue #478

**Status:** PASS (2026-09-23). Final commit: 3ce5916. Version: 0.31.77

## Non-blocking gap 1: Unguarded settings object type check in backfill

In `bin/cli.js`'s new backfill block (added in this unit), the guard condition is a bare `if (settings)` truthy check. This has two failure modes:

- A project with a malformed or null `settings.json` (e.g., broken JSON parse) will silently skip the backfill with no log line, leaving the project without the `bashOutputMaxChars` cap.
- A non-object-but-truthy value (e.g., a JSON array at the top level of `settings.json`, or a string value) will pass the truthy check and print a false success message ("added bashOutputMaxChars: 12000") while the subsequent `settings[key] = value` assignment silently drops (JSON.stringify on an array cannot carry a named property).

**Effect:** Projects with malformed settings files silently fail to receive the cost-governance cap, and could accumulate Bash output beyond the intended threshold without alerting the user.

**Out of scope:** This gap is a guard-hardening maintenance item; the primary backfill mechanism works correctly when `settings` is a valid object. Documentation of unit #478's known limitations only. No fix required in this dispatch.

**Recording:** This doc serves as a known-gaps reference for future CLI robustness hardening.

## Non-blocking gap 2: Incidental test coverage for `--dedupe-hooks` + backfill interaction

Test coverage for the `--dedupe-hooks` + backfill interaction exists only incidentally, via two pre-existing unrelated test cases in `tests/cli-backfill.test.js` (not by a dedicated named test in the new `tests/cli-settings-backfill.test.js`). The fix in this unit (reassigning the in-memory `settings` variable after `--dedupe-hooks` writes) is guarded only by these two unrelated tests.

**Effect:** A future refactor of those two unrelated test cases could silently remove the only mechanized guard on this interaction, creating a latent bug where `--dedupe-hooks` followed by backfill operations would read stale settings.

**Out of scope:** This gap is a test-consolidation maintenance item for a future refactor of the backfill test suite. Documentation of unit #478's known limitations only. No fix required in this dispatch.

**Recording:** This doc serves as a known-gaps reference for future test-suite refactoring work.
