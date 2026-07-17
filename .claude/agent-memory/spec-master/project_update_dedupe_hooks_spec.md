---
name: update-dedupe-hooks-spec
description: Spec (#74) extending the #66-73 marketplace hook-coexistence guard to bin/cli.js's --update resync path, via a warn-only detect + opt-in --dedupe-hooks removal of stale standalone hook registrations.
metadata:
  type: project
---

Finalized spec (2026-07-17): make `bin/cli.js`'s `--update` (`runUpdate`)
detect the duplicate-hook collision the shipped #66–73 guard fixed only for
fresh install / `--overwrite`. Collision = marketplace plugin enabled (via the
existing `detectMarketplacePlugin`) AND `.claude/settings.json` still carries
standalone antislop hook registrations (commands under the deterministic
`${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/` prefix the installer writes —
already the test harness's `HOOK_MARKER`).

**Design decisions locked in:** warn-only by default (never rewrites
settings.json); new `--dedupe-hooks` flag surgically removes ONLY the
marker-matched standalone entries; removal is a no-op when the plugin is NOT
enabled (never leaves zero hooks — mirrors the #71 silent-zero-hooks guard);
claude-only (`--update` is structurally claude-scoped); NO new install-time
marker (signature detection is retroactive + exact, and settings.json is
strict JSON). Fits as an additive self-contained pass, NOT a hash-diff-model
extension — the only structural constraint is running it before runUpdate's
version-match fast-path early-return.

Canonical artifact:
`docs/plans/2026-07-17-update-dedupe-standalone-hooks.md`. Published as GitHub
issue #74 (`ready-for-agent`).

**Why / how to apply:** the reason default is warn-only (not auto-remove) is
that an intentional `--force-hooks` coexistence is indistinguishable from an
accidental stale state by settings.json alone — auto-removal could undo a
deliberate choice, and silent settings rewrites violate the repo's "never
silently clobber" philosophy. Two non-blocking Open Questions carry recommended
defaults: OQ1 (warn-only vs auto-remove default + flag name), OQ2 (the
enabledPlugins object-vs-array format — see
[[enabledplugins-format-uncertainty]]; if the real format is the array, this
whole pass safely no-ops). If task-master slices this, do NOT tag the bin/cli.js
units `haiku` (prior `.fail` history on that file).
