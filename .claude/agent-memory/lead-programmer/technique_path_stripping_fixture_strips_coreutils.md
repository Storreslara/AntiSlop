---
name: technique_path_stripping_fixture_strips_coreutils
description: A test fixture that strips PATH entries holding one binary also strips every coreutil in the same dir; swap PATH AFTER sourcing the lib, or the lib fails to load and the assertion becomes vacuous
metadata:
  type: feedback
---

Building a "tool X is unreachable" fixture by dropping every `PATH` entry
that contains X also drops everything else in those directories. On a
standard Linux box `/usr/bin` holds `git` **and** `dirname`, `sed`, `jq`,
`mktemp` — so a git-less `PATH` is also a coreutils-less `PATH`.

**Why:** on gh441 the fixture exported the stripped `PATH` *before*
`source`ing `hooks/scripts/lib/harness-arm.sh`. The lib resolves its own
directory with `dirname`, so the resolution silently produced the wrong dir,
its `. "$dir/audit-log.sh"` failed, and `set -euo pipefail` aborted the
subshell with status 1 — the exact rc the test asserted. The case passed
under *any* implementation and the reviewer FAILed it as vacuous.

**How to apply:**
- Load the code under test under the REAL `PATH`, then swap to the stripped
  one immediately before the call, so only the lookup under test sees it.
- Prefer a shim dir that removes only the one binary (a dir of symlinks to
  everything else) when the code needs tools throughout its run.
- Either way, prove the fixture binds with a mutation control: patch the
  function to always fire, and confirm THAT case flips to FAIL alongside its
  siblings. A sibling-passes/this-one-doesn't split is the tell.

Generalises beyond `PATH`: any "remove a capability" fixture built by
subtracting a container (a directory, an env block, a mount) removes the
container's other contents too. See
[[technique_deterministic_date_stub_for_race_tests]] for the shim-dir shape
that avoids this.
