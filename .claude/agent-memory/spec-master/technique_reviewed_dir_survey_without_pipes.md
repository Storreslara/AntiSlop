---
name: reviewed-dir-survey-without-pipes
description: How to enumerate .claude/reviewed FAIL records from a spec-master Bash call without tripping reviewed-path-gate (plain `grep -rl`, no pipe, no wc, no ls)
metadata:
  type: feedback
---

Enumerate FAIL records with a single plain command — `grep -rl '^FAIL ' .claude/reviewed/` — and nothing else on the line: no `| wc -l`, no `| grep`, no `ls`, no `$(...)`, no `;` chaining with other commands.

**Why:** `reviewed-path-gate.sh` allows a Bash command that names the marker directory only when it is provably read-only AND lexable as one simple read; a pipe, a redirect, a command substitution, or a second command on the same line makes it "cannot be lexed / runs a writer" and the whole call is BLOCKED (hit twice on 2026-10-16 while doing the mandatory all-records FAIL survey). Read individual records with the `Read` tool (ungated).

**How to apply:** run the survey as its own Bash call; count or filter the returned filenames in a *separate* call that does not name the directory (e.g. paste the list into a `grep -c` over a heredoc, or just read it). Keep `bin/marker-audit.sh … --surface=<path>` on its own line too — it never names the directory, so it is safe, but combining it with the survey on one line is not.
