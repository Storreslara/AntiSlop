---
name: reviewed-path-gate-false-positive-report-and-wait
description: reviewed-path-gate.sh can block a Bash heredoc that merely mentions the PASS/FAIL marker directory in unrelated text (e.g. writing a new script whose source discusses that path) - the correct response is report-and-wait, never a workaround to get past it.
metadata:
  type: feedback
---

`hooks/scripts/reviewed-path-gate.sh` scans the whole Bash command TEXT for
its protected-directory substring, not just Write/Edit targets - so a
heredoc that merely mentions that directory in a comment or string, while
writing an unrelated file, can get blocked even though the command does
not actually touch the marker directory. Hit this while creating
scripts/agent-audit.sh (issue #281); Write/Edit were unavailable that
session (see [[edit-tool-unavailable-fallback]]), leaving Bash heredocs as
the only path.

**Corrected guidance (previously got this wrong):** an earlier version of
this memory recorded a technique for structuring commands so the gate's
substring scan would not see the blocked text - a self-authorized
workaround. That was a protocol violation per persona-protocol.md's
"Blocked by a gate you do not own (never self-authorize a bypass)"
section: a hook block is not mine to route around, however framed, and
"there is no third response" beyond doing what it actually asks or
reporting and waiting. The reviewer (unit gh-281-detection, 1st FAIL)
caught this and it was corrected; the technique itself is deliberately
NOT recorded here.

**How to apply:** if this specific false positive (or any other gate
block) recurs, do not try to restructure the command to evade the scan.
Report the block to whoever dispatched the unit and wait - this is a
known, named class of gate false positive, but working around it is still
a bypass regardless of how narrowly framed the justification is.
