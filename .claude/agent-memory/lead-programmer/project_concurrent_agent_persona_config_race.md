---
name: project_concurrent_agent_persona_config_race
description: CORRECTED (gh419 review) - an unexplained protectedPaths delta in persona-config.json is very likely deliberate orchestrator dispatch setup (a temporary lift), not a race or a defect - report it, never "restore" or checkout the file
metadata:
  type: project
---

**This note originally recorded the wrong root cause and prescribed the
wrong remedy. Read this corrected version, not the history below it.**

On gh419, two `protectedPaths` entries (`reviewed-path-gate.sh`,
`human-decision-gate.sh`) were missing from `.claude/persona-config.json`
at dispatch start, causing `tests/protected-paths-coverage.test.js` to fail
inside the mandated `bash tests/validate.sh`. The original note blamed "a
concurrent gh418 agent's mid-flight write" and prescribed: "restore
persona-config.json to HEAD, run `--update --check`, re-diff." That
restore action is *exactly* what happened next, and it was the actual
defect, not a diagnostic step: the orchestrator had **deliberately** lifted
those two entries as part of this unit's own dispatch (standard practice
for units that must edit a `protectedPaths`-listed hook script), explicitly
saying "the orchestrator restores this after review — do not touch the
array yourself." Restoring the file "fixed" the local test run while
silently undoing that setup and producing a commit whose message claimed
`protectedPaths` was "untouched," which was false.

`bin/cli.js` genuinely has no code path that removes `protectedPaths`
entries (still true, still worth checking first) — but the correct
inference from that fact is **"this is dispatcher-intended state, not a
tool bug or a race,"** not "something external must have caused this, so
restoring to HEAD is safe." A concurrent agent's commit landing in a shared
tree is a real phenomenon (see [[feedback_never_unconditional_stash_pop]],
[[project_agent_memory_blocks_pass_marker]]), but it explains *new* changes
appearing, never a specific, small, surgical *removal* that happens to
exactly match what your own dispatch prompt told you was already lifted.

**How to apply:** if `protectedPaths` (or any config field) is missing
entries relative to what you expect, and your dispatch prompt does not
mention a deliberate lift, first re-read the dispatch prompt itself for a
"protectedPaths lifted for exactly these files" note before assuming a bug
or a race. If the delta IS explained by the dispatch prompt, leave it
alone — restoring, checking out, or "fixing" that file is not your call
(most dispatches explicitly forbid touching that array in either
direction). If a mandated acceptance command like `tests/validate.sh` fails
specifically because of that documented, temporary lift, that is the
**expected, known, temporary** state — say so plainly in your report and
move on to your own unit's actual acceptance criteria; do not spend a turn
"fixing" it by restoring the file, and do not report it as a blocking
defect. If you genuinely cannot tell whether a delta is deliberate setup or
a real anomaly, STOP and report the exact discrepancy for the orchestrator
to explain — never resolve the ambiguity yourself by reverting shared
config state.
