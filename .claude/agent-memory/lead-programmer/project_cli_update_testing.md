---
name: project_cli_update_testing
description: How to test bin/cli.js's runUpdate() (process.exit branches) and the fileHashes/--check machinery added for issue #42
metadata:
  type: project
---

`runUpdate()` in bin/cli.js calls `process.exit()` on several paths (missing
config, unresolved-render, pending). Never call it in-process from
tests/cli-backfill.test.js — it will kill the test runner. Test it via
`spawnSync('node', [cliPath, '--update', ...], { cwd: tmp, encoding: 'utf8' })`
instead and assert on `result.status`/`result.stdout`. This differs from the
existing `backfillSubstitutionsFromDisk`/`backfillFileHashesFromDisk`
integration test in the same file, which chdirs the test process itself and
re-requires cli.js with a cleared require-cache entry (needed only because
those two functions read the module-level `CWD` constant directly, not via a
subprocess) — the two patterns coexist in the file; don't conflate them.

**Why:** `PKG_ROOT` in cli.js is derived from cli.js's own `__dirname`, not
`process.cwd()`, so pure functions like `buildFileSpecs`/`renderCleanBody`/
`sha256Hex` can be called from the top-level (non-chdir'd) `cli` require
directly even when building a fixture project in a different temp `tmp`
directory — no chdir/require-cache dance needed for those.

**How to apply:** When adding more `--update`-flow tests, build a baseline
fixture by writing UNSTAMPED clean-rendered bodies to disk and recording
`fileHashes` against that same unstamped content (`stripStamp` is a no-op
absent a stamp line) — this reproduces "no local edits, already current"
without reimplementing `copyStampedBody`'s stamp-insertion logic.

**Gotcha:** the code-review-graph pre-commit hook flagged `runUpdate` and
`pruneStaleFileHashes` as "untested" after this commit (0a4fe39) even though
both are exercised by two new spawnSync-based integration tests — the
graph's static coverage analysis apparently doesn't attribute coverage
through a spawned child-process test the way it would an in-process call.
Not a blocker (commit succeeded, tests are real and pass), but expect this
false-negative again for any future `--update`-flow test written the same
way; don't take the hook's "untested" note at face value for this function
without checking whether the test spawns a subprocess.

[[project_threefold_update]] — the plan/PASS verdict that flagged this
standalone maintenance issue (#42) as a non-blocking advisory note.

**Gotcha 2 (discovered issue #39, Step A.2):** a plain `node bin/cli.js
--update` prints "already current, nothing to update" and exits 0 WITHOUT
regenerating `.claude/agents/<x>.md` if you only edited the SOURCE
`agents/<x>.md` (e.g. added a new `<MATTPOCOCK:slot>`) while
`pluginVersion` still matches and the adapted copy has no residue/legacy
tokens — the fast-path check in `runUpdate()` never compares source content
to the recorded hash. You must pass `--update --check` to force the
render/diff loop and pick up the drift. Always verify the adapted copy
actually changed (`grep` the resolved value in `.claude/agents/<x>.md`)
rather than trusting a plain `--update`'s exit code/log line alone.

**Gotcha 3:** `tests/cli-backfill.test.js` round-trips `deriveMattpocockSubsForFile`
against the REAL `agents/*.md` source files (not fixtures) using a hardcoded
`KNOWN_MAP` of fake resolved names. Adding a new `<MATTPOCOCK:slot>` to any
of `scribe`/`milestone-auditor`/`lead-programmer`/`spec-master`/`task-master`'s
source file requires adding a matching entry to that `KNOWN_MAP` (any fake
value, e.g. `mattpocock-skills:<slot>` — it doesn't need to match the real
`persona-config.json` registered name) or `tests/validate.sh` fails with
"No recorded substitution for `<MATTPOCOCK:slot>`" in four places at once.

**Gotcha 4 (discovered issue #41, Step C.1):** a version-only bump (no source
content change) does NOT re-stamp an adapted file's `<!-- antislop vX.Y.Z -->`
line. `renderCleanBody`'s hash never includes the stamp, and the "already
current" fast path (`cleanHash === recordedHash`) skips `copyStampedBody`
entirely, so the old stamp is left in place even under `--update --check`.
This is long-standing, accepted behavior, not a bug introduced by this
change — `explorer.md`/`scribe.md` have been pinned at `v0.9.0` since before
this plan. If a plan's acceptance criteria demand every plan-touched file
show the new version stamp, and the file's content didn't change since its
last render, you must hand-edit just the stamp line (safe: `stripStamp`
already excludes it from the hash basis, so this can't desync `fileHashes` —
verify with a follow-up `--update --check` still reporting "already
current"). Also: a plan/issue's acceptance grep may target the plugin
SOURCE path (`agents/<x>.md`) instead of the ADAPTED copy
(`.claude/agents/<x>.md`) — source files never carry a stamp line at all, so
that literal check can never pass; run it as literally written and report
the (expected) failure honestly rather than silently substituting the
correct path.
