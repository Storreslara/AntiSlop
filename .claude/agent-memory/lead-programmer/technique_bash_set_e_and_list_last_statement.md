---
name: bash-set-e-and-list-last-statement
description: under set -e, an A && B pattern as the LAST statement of a shell function propagates A's failure as the function's own return status and aborts the caller
metadata:
  type: technique
---

`cmd1 && cmd2` as a bare top-level statement under `set -e` is safe even when
cmd1 fails (this repo already relies on it: `command_is_provably_benign
"$command" && exit 0` in hooks/scripts/harness-integrity-gate.sh) — cmd1 is
exempt from errexit because it precedes the list's final `&&`.

**But if that same pattern is the LAST statement executed inside a shell
function**, and cmd1 fails (so cmd2 never runs), the function's own return
status becomes cmd1's nonzero status. Calling that function as a bare
statement (not inside if/while/&&/||) at the call site then DOES trigger
`set -e` and aborts the script right there — silently, with no error message,
which makes it look like a hang or an unrelated later test "never ran".

**Why:** verified empirically (`false && echo x` as a function's last line
vs. with a trailing no-op after it) rather than trusted from the bash manual
prose alone — see [[verify-dont-trust-manual-prose-on-set-e]] (write if this
recurs). Hit this in tests/harness-integrity-gate.test.sh's `count_allowlist()`
helper (gh468/hcb-branch): `run ...; [ "$rc" = 2 ] && count_denies=$((...))`
as the function's final line silently killed the whole suite once `rc` was 0
(mutant made everything ask, so the deny-path check legitimately failed).

**How to apply:** never end a bash test-helper function with a bare `cond &&
action` line. Rewrite as `if cond; then action; fi` (an if-with-no-else
always returns 0 regardless of whether the branch ran), or add a trailing
`return 0` / no-op statement after the `&&` line so it is not the function's
last command. Audit every helper function's LAST line specifically — earlier
lines in the same function with the same `&&` shape are fine.
