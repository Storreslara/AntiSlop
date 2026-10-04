---
name: validate-exceeds-600s-poll-task-output
description: tests/validate.sh took 672 s at qp-1 (2026-10-04), past the Bash 600 s ceiling; the harness auto-backgrounds it and a foreground poll loop on the task output file recovers the full-run verdict
metadata:
  type: project
---

`bash tests/validate.sh` in a clean `/tmp` worktree took 11m12s at qp-1 (0.31.120), past the
600000 ms foreground ceiling. The harness then moves the command to the background and names
a task output file under `.../tasks/<id>.output`. The run keeps going.

**Why:** the suite keeps growing (esc-fu-3 added probe tests at the end), so it's now regularly over the ceiling.

**How to apply:** wrap the run as `(bash tests/validate.sh > out 2>&1; echo validate-exit=$?)`. If it gets
backgrounded, run a foreground poll in a new call: `for i in $(seq 1 100); do grep -q validate-exit= <task.output> && break; sleep 3; done`
with timeout 400000. That gives the full-run exit code without falling back to "final section
only". Poll the output FILE, never pgrep (see [[pgrep-self-match-polling-trap]]).
