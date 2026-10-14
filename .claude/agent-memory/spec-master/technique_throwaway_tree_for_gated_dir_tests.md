---
name: technique-throwaway-tree-for-gated-dir-tests
description: To exercise a test that touches the gated marker dir, copy it into a mktemp tree with a stub tests/validate.sh; the script cds to its own .., so it never sees the checkout.
metadata:
  type: project
---

A repo test that `cd "$(dirname "$0")/.."` can be run against a throwaway tree T: copy it into
`T/tests/`, put a stub `T/tests/validate.sh` beside it, give T its own `.claude/reviewed/`. No
criterion then reads or writes the checkout's marker dir, and a minutes-long nested run becomes
sub-second. Used for lgc-1 (docs/plans/2026-10-14-leak-guard-concurrency.md, `lgc-criteria/lib.sh`).

Two findings from that session:
- The reverted-f3dca44 `tests/marker-write.test.sh` now leaks unitA.pass, unitB.fail, unitC.blocked,
  unitG.fail, NOT gh425 F3's spec2-unitC.pass: `set -e` stops at item12-1 first. Re-measure before
  asserting any historical leak set.
- reviewed-path-gate scans the WHOLE Bash text, including python/heredoc bodies and `"revi""ewed"`
  splits. Put any probe that names the dir in a script written with the Write tool, then `bash` it.

**How to apply:** for any guard/test whose subject is a gated dir, drive it in a throwaway tree;
see [[verify-own-criteria-nonvacuous]].
