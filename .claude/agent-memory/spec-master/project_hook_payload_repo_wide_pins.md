---
name: hook-payload-repo-wide-pins
description: a new hooks/scripts/ payload must pass repo-wide pin tests (state-access M5 unit-id spellings) and sourcing state-access.sh re-enables set -e; run them on the clone
metadata:
  type: project
---

st-u3's gate text failed `tests/state-access-constraints.test.sh` M5 (2a/2b): it is a `git grep` over ALL of
`hooks/scripts/` that allows exactly one spelling of the unit-id class (`lib/state-access.sh`) and three
`[^a-zA-Z0-9._-]` sanitiser lines. My clone proof ran the new unit's own test, not that suite, so a contract
"proven on a clone" broke an unrelated pin (2026-10-21, caught by the implementer).

**Why:** pins that scan a whole directory fail on any NEW file there, so they never show up in the unit's
own criteria or blast radius.

**How to apply:** for any contract adding a file under `hooks/scripts/` (or another pinned tree), run every
tests/*.test.sh|js one by one on the chained clone and diff the failure set against a pristine clone (six
abtest/leak-guard/cli-backfill files fail on any clone; same exit codes = environment). Use the owner
helpers (`UNIT_ID_CHARCLASS`, `unit_id_valid`, `unit_id_sanitize`). Sourcing `state-access.sh` runs
`set -euo pipefail`: source libraries in one group with `|| true`, then `set +e` again, or a missing
library exits 1 (= allow for a hook). See [[verify-own-criteria-nonvacuous]].
