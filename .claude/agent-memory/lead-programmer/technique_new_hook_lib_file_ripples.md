---
name: new-hook-lib-file-ripples
description: Adding a file to hooks/scripts/lib/ ripples into four places beyond the file itself; two of them fail in ways whose cause is not local
metadata:
  type: project
---

A new `hooks/scripts/lib/*.sh` is never just a new file. Four ripples, in the
order they bite (measured gh415 `audit-log.sh`, gh416 `harness-arm.sh`):

1. **`bin/cli.js` becomes unloadable** until the filename is added to
   `SHARED_HOOK_LIB_FILES` (goes to both adapter `lib/` trees, byte-identical)
   or `CLAUDE_ONLY_HOOK_LIB_FILES`. `assertHookLibDeclarationComplete()` runs
   at module load, so *every* `node bin/cli.js` invocation dies, not just
   `--update`. Diagnose this first — it masks everything else.
2. **Shared means byte-identical, not "substituted".** `buildAdapterLibSpecs()`
   copies raw. A spec that says "copy with the dot-dir substituted" cannot be
   satisfied by the generator — make the dot-dir a function parameter the port
   entry points pass (`.codex`/`.cursor`), the way `stop-gate-core.sh` takes
   `$dot_label`.
3. **`tests/stop-gate-{microworld-skip,deferred-microworld}.test.sh` hand-copy
   an explicit subset of `lib/`** into a mutant tree. If a gate they exercise
   gains a new `source`, the copy list needs the new file or the suite fails
   as `mutation control did not discriminate` — a message that points at the
   mutation, not at the missing file. The deferred suite has TWO copy sites.
4. **`tests/protected-paths-coverage.test.js` requires every `*.sh` under
   `hooks/scripts/` to have a `protectedPaths` entry**, so a new lib file turns
   it red until one is added. When a dispatch forbids touching `protectedPaths`,
   that red is expected — report it, do not add the entry.

**Why:** each ripple lives in a different file from the change that triggers it,
so none is visible while writing the library.
**How to apply:** when a unit's Affected files list a new `hooks/scripts/lib/`
file, walk this list before running `tests/validate.sh`, and re-measure the
validate baseline first — see [[project_g1_bump_invalidates_mirrors]] and
[[project_adapter_entrypoint_not_generated]].
