---
name: item19-microworld-registration-gap
description: watch-map registration is bookkeeping only; the dashboard invoke gate is the executable bit, not registration
metadata:
  type: project
---

Registering a microworld bundle in `tests/watch-map.json` does NOT add test
coverage by itself. `hooks/scripts/lib/microworld-rerun-core.sh` (Tier B)
dynamically discovers every `microworlds/*/manifest.json` and runs its
mutation-proof regardless of `tests/watch-map.json` (Tier A) registration —
Tier A only gates which suites `tests/validate.sh` treats as
skippable-on-clean-bundle. So "unregistered bundle = inert" (item19's
original premise) is false for any bundle with a manifest `watch` glob.

**Why:** item19-1's classification review corrected this; item19-3 (closing
the registration gap) had to state explicitly that registering
`hdg-anchor-1`/`rpg-canon-2` closes a bookkeeping/set-difference gap, not a
coverage gap.

The real security-relevant lever for "retiring" a bundle is
`bin/microworld-dashboard/discover.js`: it marks a bundle `disabled` only if
its entry file is non-executable, with NO check against watch-map
registration at all. A "retired" label in `tests/watch-map.json` alone does
not stop `POST /api/invoke` from running that bundle's `run.sh` via the
dashboard.

**How to apply:** when a plan calls for "retiring" a microworld bundle,
`chmod 644` its `run.sh` (or otherwise strip the executable bit) as the
actual fix — a bookkeeping record without that chmod is cosmetic. When a
plan claims registering a bundle "closes a coverage gap," check whether the
bundle already has manifest-level `watch` globs invoking Tier B before
repeating that claim.

**FAILed first pass (item19-3):** a new check that does `find microworlds
...` unguarded under `set -euo pipefail` aborts the whole test script when
`microworlds/` doesn't exist — which is every fresh clone/CI checkout, since
the directory is gitignored (ADR-0017). My local `bash tests/validate.sh`
exit-0 was worthless as evidence because my machine happens to have bundle
dirs checked out already. Fix pattern already exists at
`hooks/scripts/session-start.sh:66`: `[ -d "${dir}/microworlds" ] && ...`.
**Any new check touching an optional/gitignored directory must be verified
in a fresh `git clone`, not just the local tree** — that's the only way to
reproduce the absence.
