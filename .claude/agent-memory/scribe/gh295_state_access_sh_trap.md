---
name: gh295_state_access_sh_trap
description: state-access.sh sourcing override trap — functions must use `|| true` or fail silently
metadata:
  type: feedback
---

**Rule:** Any hook function that sources `hooks/scripts/lib/state-access.sh` must explicitly handle non-zero exit codes in its return path.

**Why:** `state-access.sh` sources with `set -euo pipefail`, which overrides the sourcing script's own looser `set` options for the remainder of execution. This means any function whose normal/expected return path is non-zero (e.g., a check that returns 1 on success) will cause the entire script to exit silently with no error text if not guarded by `|| true` or an explicit `return 0` before the script reaches its end.

**How to apply:** When writing hook scripts that source state-access.sh (or any other lib files that source with strict pipefail), always:
- Use `|| true` after any call that may intentionally return non-zero
- Explicitly return 0 at the end of functions that might exit with non-zero
- Document this in any hook-authoring guide or README for future developers

**Where this matters:** All hook files under `hooks/scripts/` that source `lib/state-access.sh`. This includes any scripts that call the `state_*` family of functions.

**Source:** Flagged during unit gh295-1 review (lead-programmer note on the implementation) and documented in `.claude/wiki/conventions.md`.
