---
name: adapter-entrypoint-not-generated
description: adapters/<name>/hooks/scripts/<gate>.sh (the entry point) is hand-edited, unlike its lib/*-core.sh siblings which bin/cli.js --update regenerates
metadata:
  type: project
---

On gh415's second FAIL fix (a raw `>>` append missed in
`adapters/codex/hooks/scripts/stop-gate.sh`'s `block()`), confirmed via
`node bin/cli.js --update --check` that only `adapters/*/hooks/scripts/
lib/*.sh` files (the shared core libraries) are in the generator's mirror
list — the adapter's own entry-point script (`stop-gate.sh`,
`reviewer-route-gate.sh`, etc., the port-specific hand-written file that
*sources* those libs) is not, and `--update --check` reported it
"already current" with zero drift after my hand-edit.

**Why:** the entry point is each adapter's own port of the gate's control
flow (different JSON input shape, different `.codex`/`.cursor` dot-dir),
so it can't be mechanically derived from the canonical `hooks/scripts/`
version the way a shared library can. `bin/cli.js`'s `SHARED_HOOK_LIB_FILES`
constant only lists library filenames, not entry-point scripts.

**How to apply:** when a defect names an adapter's own gate script
(not a `lib/*.sh` file) as needing a hand-edit, don't assume
`--update --force-render` will pick it up or that a hand-edit will be
clobbered — verify with `--update --check` (or `--dry-run`) after editing;
"already current" for that file confirms it's genuinely hand-maintained,
not generated. See also [[project_gh411_core_extraction_concurrent_repo]]
for the related M2 core-extraction split between entry point and
`lib/<name>-core.sh`.
