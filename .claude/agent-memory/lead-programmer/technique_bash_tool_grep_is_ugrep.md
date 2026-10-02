---
name: bash-tool-grep-is-ugrep
description: In the Bash tool's interactive shell, `grep` is a function wrapping ugrep, which treats a mid-pattern `$` as an anchor; acceptance criteria quoting `"$command"` falsely fail or read VACUOUS unless run from a script file
metadata:
  type: feedback
---

The Bash tool's shell defines `grep` as a function that execs the claude binary as ugrep. ugrep treats `$` in the MIDDLE of a pattern as an anchor (GNU BRE treats it as literal), so `grep -x 'f "$command" && g'` never matches. A plan's mutation control built on `grep -vx` then removes nothing and reports VACUOUS. Non-interactive `bash script.sh` / `bash -c` sees `/usr/bin/grep` (GNU 3.11), as does `tests/validate.sh`.

**Why:** esc-chat-2 (2026-10-02): the plan's AC mutation control printed VACUOUS in the Bash tool and passed when the same text ran from a script file.

**How to apply:** run acceptance-criteria blocks that contain grep from a scratchpad script (`bash $S/ac.sh`), never inline in the Bash tool. When a grep criterion surprises you, check `type grep` first.
