---
name: project_concurrent_agent_persona_config_race
description: A surprising `--update --check` diff (protectedPaths entries vanishing) can be another concurrent agent's mid-flight write to the shared persona-config.json, not a real code defect - re-run and compare git log before escalating
metadata:
  type: project
---

On gh419, `node bin/cli.js --update --check` appeared to delete two
`protectedPaths` entries (`reviewed-path-gate.sh`, `human-decision-gate.sh`)
from `.claude/persona-config.json`, which then failed
`tests/protected-paths-coverage.test.js` inside `bash tests/validate.sh`.
`bin/cli.js` has no code path that removes `protectedPaths` entries
(grepped for it - the field is documented as "preserved as-is"), so this
looked like a genuine spec conflict between two mandated acceptance
commands.

**Why:** re-running the exact same sequence (restore persona-config.json to
HEAD, run `--update --check` once, then twice) never reproduced the removal
- only the two expected `fileHashes` lines changed. Checking `git log
--oneline -5` mid-investigation showed FOUR new commits from a concurrent
`gh418` unit that had landed since the session started. The most likely
explanation is a lost-update race: another agent's own `--update`/commit
cycle touched the same shared `.claude/persona-config.json` at nearly the
moment I read or wrote it (this repo runs multiple agents against one
working tree - see [[feedback_never_unconditional_stash_pop]] and
[[project_agent_memory_blocks_pass_marker]] for the same shared-tree
hazard). By the time I re-checked, the file was back to the correct state
and `git diff` on it showed only the two hash lines - a normal, expected
side effect of running the mandated `--update --check` after editing the
two gate scripts' content.

**How to apply:** when `--update --check` or any tool produces a change
that doesn't match its documented behavior (verified by grepping the
tool's own source first), don't immediately treat it as a spec gap to
escalate - check `git log --oneline` for new commits since the session's
own baseline, then simply re-run the suspicious command from the current
(possibly now-corrected) state and diff again before reporting a defect or
invoking the escalation clause. A single anomalous read in a shared
working tree is not proof of a design conflict.
