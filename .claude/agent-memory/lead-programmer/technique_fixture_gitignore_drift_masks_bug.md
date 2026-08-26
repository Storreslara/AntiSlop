---
name: fixture-gitignore-drift-masks-bug
description: a test fixture's hand-copied .gitignore list drifting from the real repo's .gitignore silently masks the exact bug a new regression test targets - verify red for the right reason with bash -x, not just rc
metadata:
  type: project
---

Fixing spec2-unitB's stop-gate-core.sh `_mw_changed_files` bug (swallowed
`git diff --name-only $baseline_sha HEAD` failure on an unreachable session
baseline, returning an empty changed-file list instead of failing closed):
my first attempt at a red TDD test (`tests/stop-gate-microworld-skip.test.sh`
AC-B5d) came back green even against the UNFIXED code - looked like the bug
didn't exist. Root cause: the test harness's `make_project()` builds its own
`.gitignore` by hand-listing paths (`microworlds/`, `.claude/microworld-
audit.log`, etc.) rather than reusing the real repo's `.gitignore`, and it
was missing `.claude/.session-baseline.*` (present in this repo's own
`.gitignore` at line 14). My test wrote a bogus baseline SHA into
`.claude/.session-baseline.s` directly (not via `git add`), so without the
ignore entry it showed up as an untracked/dirty file in `git status
--porcelain` - which made `_mw_changed_files` return a real (non-empty)
changed-file list containing the baseline file itself, unrelated to any
bundle, correctly triggering AC-B5a's "unwatched file forces the check" path
for the WRONG reason. The rc=2 the test asserted was real, just not from the
code path under test.

**How I caught it:** ran the exact fail-record repro by hand with `bash -x`
piped through `grep -n` for the function names, and read the trace around
the `_mw_changed_files`/`git diff` calls line by line instead of trusting
the summary rc. The trace showed `git status --porcelain` returning `??
.claude/.session-baseline.s` - a file I never intended to be "changed" - one
line before the code path I actually meant to exercise.

**Generalizable rule:** when a new regression test's red/green result seems
too easy (passes on the first try, or fails/passes for a plausible-looking
reason), don't stop at the exit code - trace through with `bash -x` (or
equivalent) and confirm the SPECIFIC branch/line the fix touches is the one
that ran. A test fixture's own scaffolding (a hand-built `.gitignore`, a
hand-built config) can silently diverge from the real environment it's
meant to model and produce a same-answer-wrong-reason result that looks like
a passing regression test forever. Cross-check any fixture `.gitignore`/
config against the real repo's own copy when the new test writes a file
under a directory the real `.gitignore` also covers.

See [[project_gh411_core_extraction_concurrent_repo]] for the sibling lesson
about this repo running concurrent agents that can silently touch shared
files (`persona-config.json`, memory files) mid-session - same session also
found a dispatch's "protectedPaths entry already removed by the orchestrator"
claim was stale by the time I checked (HEAD already had the entry restored),
harmless here since my restore-edit was idempotent, but worth re-verifying
a dispatch's "already done" claims against current state rather than
current-state-as-of-dispatch-time.
