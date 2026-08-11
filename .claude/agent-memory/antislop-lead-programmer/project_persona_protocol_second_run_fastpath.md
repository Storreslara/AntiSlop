---
name: project_persona_protocol_second_run_fastpath
description: RESOLVED (issue #190) — runUpdate's fast path was blind to absent managed files; the recurring trap is that "run --update twice and diff" measures nothing
metadata:
  type: project
---

**Status: fixed** (issue #190, Amendment A2). Kept because the *measurement
trap* it records outlives the bug.

I was asked to verify, not fix, A1's suspicion about
`removeStaleProtocolCopy()`. Confirmed live; spec-master's A2 then found it
strictly larger and ruled the fix shape, which I implemented.
`removeStaleProtocolCopy` no longer exists.

**The trap:** `runUpdate`'s version-match fast path means "run the command
twice and diff the artifact" proves *nothing* — a second `--update` prints
`already current … Nothing to update.` and the entire per-file render loop
never executes, so the diff passes on *never re-rendered*, not on *rendered
and identical*. Same shape as [[project_cli_check_is_a_write]].

**How to apply:** to measure idempotence of anything `runUpdate` generates,
force the render with `--update --check` and assert on the per-file summary
line (`  <path>: already current`, two leading spaces) — emitted only after
`renderCleanBody` ran and its hash was compared. Pair it with a negative
control (the same run *without* `--check` must print `Nothing to update` and
name no file). **Do not use mtime**: the correct "already current" branch
performs no write, so an mtime assertion fails on correct code.

**Workflow consequence (hit again on gh136), not just a measurement issue:**
once the G1 version bump has written the new `pluginVersion` into
`.claude/persona-config.json`, the stamps match, so *any further source edit in
the same session* leaves the `.claude/agents/*.md` mirrors stale while a plain
`node bin/cli.js --update` prints `Nothing to update.` and silently changes
nothing. Order the unit as: edit sources → bump G1 → `--update` → **if you touch
a source again, `--update --check`**. Symptom if you miss it:
`tests/cli-backfill.test.js` F2 fails with `M .claude/agents/<persona>.md` in
the post-run tree — that is a stale mirror, not a cli.js bug.

Root cause, for the record: absence was invisible to the pre-scan (it
`continue`d past any destination that did not exist), and the only defeater
that ever fired on a missing file was hard-coded to one path — so `--update`
could not self-heal *any* deleted managed file, including a deleted
`reviewer.md` mirror. The pre-scan is now absent-or-stale (`needsRender`).

Also reinforces: prefer `cp -r` to a literal path outside the repo over `git
worktree` when mutating a throwaway copy of `bin/cli.js` — a worktree would
not carry uncommitted changes, and cleanup stays a literal `rm -rf` on a path
visible in the transcript.
