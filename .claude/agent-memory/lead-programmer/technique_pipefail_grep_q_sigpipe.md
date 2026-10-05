---
name: pipefail-grep-q-sigpipe
description: under set -o pipefail, `producer | grep -q` can report failure on a MATCH when grep exits early and the producer dies of SIGPIPE; capture output into a variable first
metadata:
  type: feedback
---

In a `set -uo pipefail` test suite, `bash "$snap" "$p" | grep -qE '<re>' || fail ...` failed even
though the snapshot's output matched: `grep -q` exits on the first match, the still-writing
producer gets SIGPIPE (141), and pipefail makes the whole pipeline non-zero. The inverse form
`if producer | grep -q "$bad"; then fail; fi` silently MASKS a real failure the same way.

**Why:** ocigf-1 S6d (2026-10-05) went red with correct output; the debug print showed the expected line.

**How to apply:** in pipefail suites, `out="$(producer)"` then `printf '%s\n' "$out" | grep -q`.
A builtin `printf` of a short string is safe in practice; an external producer is not.
