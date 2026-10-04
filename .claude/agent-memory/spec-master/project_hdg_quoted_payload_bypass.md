---
name: hdg-quoted-payload-bypass
description: human-decision-gate allows a glob inside a quoted bash -c/sh -c payload that really overwrites DECISION; measured 2026-10-04, pinned TRACKED-OPEN by esc-fu-1, closing it is Open Question 1 of docs/plans/2026-10-04-escalation-followups.md
metadata:
  type: project
---

At 3baa67e, `bash -c 'printf x > .claude/human-review/u1/D*'` and `sh -c 'tee …/D* < /dev/null'` get gate rc 0 and genuinely overwrite DECISION. The skeleton masks the quoted payload, so glob_names_tokens never sees the glob, and the early exit fires. `sh -c 'printf x > …/D*'` writes NOTHING: POSIX sh (dash, and `bash --posix`) does not pathname-expand a non-interactive redirect word, and creates a literal `D*` file instead.

**Why:** esc-left-3 closed F-1 only for UNQUOTED globs. A second shell re-parsing a quoted payload is the class that the removed "not the whole enumeration" header hedge covered.

**How to apply:** never describe F-1 as closed without this caveat. A spec that closes it needs a quoted-payload model for second-shell wrappers plus a differential sweep (see [[gate-early-exit-residuals-spec]]).

Also measured: the comma-free `{a/b}` brace branch is pure fail-closed over-approximation, because bash treats such a group as literal, so no reachability claim is possible for its row. Extglob reachability needs `shopt -s extglob` on an EARLIER LINE, since bash parses the whole line first.

Testing technique: a background child of a NON-interactive script ignores SIGINT (rc 0). Use `set -m` around the spawn, and assert rc 130, or an INT test passes vacuously.
