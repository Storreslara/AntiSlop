---
name: ptr-u7c-completion
description: ptr-u7c PASS cb62b9c closed #551; two open follow-ups (stale orchestrator.md claim, unpinned default semantics)
metadata:
  type: project
---

ptr-u7c PASS 2026-10-16 (cb62b9c, 0.31.172): reviewer reads both config keys with one lone jq; glossary entry "lone jq read" added to docs/harness-glossary.md.

Open follow-ups (non-blocking):
- agents/orchestrator.md ~401-403 (and .claude mirror) still says a Bash command naming the persona config is refused; false for a lone jq. Fix in a later unit.
- The U7c test pins gate admission only (fixture config `{}`); off/critical default semantics (reviewer.md ~127-137, ~237) are unpinned for absent keys, "off", non-object root.
- `--update` rewrote persona config (pluginVersion + one fileHashes entry) inside the unit commit.

**Why:** carry into the later unit. **How to apply:** check these before declaring the config-read topic closed.
