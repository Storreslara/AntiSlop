---
name: sibling-function-avoids-shared-writer-blast-radius
description: when only one marker type of a shared truncating-writer needs new behavior, add a new sibling function instead of branching the existing one — existing tests of the raw function stay valid for free
metadata:
  type: project
---

On item12-1 (`state_write_unit_marker()`'s truncating `.fail` overwrite,
`hooks/scripts/lib/state-access.sh`), the spec's R3 warned the shared
function is used for **all** marker types (`.pass`, `.fail`, `.blocked`) and
said "scope the change to the FAIL path only." I read this as license to
branch inside the existing function (`if marker_type == fail: append`), but
chose instead to add a brand-new `state_append_unit_marker()` and repoint
only `marker-write.sh`'s FAIL case at it, leaving `state_write_unit_marker()`
100% untouched.

**Why this mattered beyond style:** `tests/state-access-constraints.test.sh`
CONSTRAINT 10 calls `state_write_unit_marker(..., "fail", ...)` **directly**
and asserts the old truncating behavior as a deliberate architectural
property ("2-FAIL-cap count is not filesystem-derivable [from .fail
alone]"). Branching inside the shared function would have made that test
assert something now false, forcing a scope-creep edit to a test file the
dispatch packet never named. Adding a sibling function instead meant that
test kept passing unmodified — the raw writer genuinely didn't change,
only the one call site marker-write.sh uses for FAIL did.

**How to apply:** when a spec says "scope to path X, function Y is shared,"
check whether any EXISTING test calls Y directly (not through the caller
being fixed) and hard-codes the old behavior as correct. If so, prefer a new
sibling function over an in-place branch — it's the same amount of code, but
avoids an out-of-scope test edit and keeps the shared function's contract
provably unchanged for every other caller. Reserve the escalation ("if
scoping requires changing the shared function's signature, report blast
radius") for cases where a sibling genuinely can't work, e.g. every caller
truly needs the same new logic.
