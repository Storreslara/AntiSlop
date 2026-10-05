---
name: sourcing-state-access-sets-e
description: sourcing hooks/scripts/lib/state-access.sh from a non-hook script silently turns on set -euo pipefail; set dot first, then `set +e` if the caller relies on failing $(...) assignments
metadata:
  type: project
---

`hooks/scripts/lib/state-access.sh` runs `set -euo pipefail` at top level and defaults `dot` from
`CLAUDE_PROJECT_DIR`. A script outside `hooks/` that sources it to reuse `unit_id_marker_path` /
`unit_id_valid` (principle 6: read the marker path via its owner) inherits `-e`.

**Why:** found building ocig-1's `oci-series-gate.sh` (2026-10-05): `x="$(git rev-parse ...)"` that
fails would exit the wrapper silently instead of reaching its refusal line.

**How to apply:** set `dot="$proj/.claude"` before sourcing, then `set +e` right after. For a
mutation proof of a script that resolves helpers via `../../hooks/scripts`, put the temp copy at
the same depth and symlink `hooks` into the temp root, and require an unmutated-copy baseline pass.
