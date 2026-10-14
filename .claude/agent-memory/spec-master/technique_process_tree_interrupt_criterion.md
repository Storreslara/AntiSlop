---
name: technique-process-tree-interrupt-criterion
description: How to write a non-flaky "interrupt leaves no survivors" criterion in bash, plus two traps found while speccing vln (2026-10-14).
metadata:
  type: feedback
---

A criterion proving "TERM/INT kills the whole process tree" (vln1-ac1, docs/plans/vln-criteria/):
start the script under `set -m` (a non-job-control `&` child has SIGINT ignored and cannot trap it),
have the stub record `"$$ $!"` into a pids file, poll with a `/proc/uptime` deadline, signal, then
check each pid with `ps -o stat=` (a zombie is dead; `kill -0` says alive). An EXIT trap must KILL
every recorded pid, or a red run leaves `sleep 300`s behind. To reach a tar phase, put a sleeping
`tar` wrapper first on PATH.

Traps:
1. `exit 99` inside a helper called as `t=$(helper ...)` ends only the subshell. A "hard-exit"
   helper needs `|| exit N` at every call site. vlg's `ltree` claimed a hard exit and never had one.
2. Claude Code's built-in rm safety check refuses any Bash command whose TEXT holds
   `rm -rf "$var"`, even inside a python string. Put mutant text in a JSON file and drive it with a script.

**Why:** both cost a round trip in the vln spec. A reviewer note had already called (1) "unlike ltree (exit 99)".

**How to apply:** reuse the vln-criteria `lib.sh` (`reap`/`alive`/`past`) for any signal criterion.
Related: [[verify-own-criteria-nonvacuous]], [[technique-monotonic-timing-and-command-backticks]].
