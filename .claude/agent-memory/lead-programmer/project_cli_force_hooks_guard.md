---
name: project_cli_force_hooks_guard
description: How to integration-test bin/cli.js's fresh-install scaffold end-to-end (issue #68, --force-hooks guard) — spawnSync + tmp HOME pattern
metadata:
  type: project
---

Issue #68 added a `--force-hooks` flag gating the claude-target hooks merge
(`deepMerge(settings, hooksConfig)` in `main()`, ~bin/cli.js:1382 before the
change) on `detectMarketplacePlugin('claude', CWD, os.homedir())` (from
issue #67, [[project_cli_update_testing]]). Skips ONLY that merge; the
`settingsFragment` merge (agent/env/permissions) and rest of the scaffold
(agents/skills/protocol/CLAUDE.md/.gitignore/persona-config.json) still run.

**Why:** double hook registration when both the marketplace plugin AND this
CLI's standalone scaffold are active in the same project — hooks would fire
twice.

**How to apply — testing the fresh-install scaffold end-to-end (new
pattern, first use in this file):** `main()`'s fresh-install path (no
`--update`) only refuses to run if `.claude/persona-config.json` already
exists in CWD — it does NOT check for a pre-existing `.claude/settings.json`
or `.claude/settings.local.json`. That means you CAN pre-seed
`<tmp-cwd>/.claude/settings.json` (or `settings.local.json`) with
`{enabledPlugins: {"antislop@antislop-marketplace": true}}` before running
`spawnSync('node', [cliPath, '--yes'], {cwd: tmpCwd, env: {...process.env,
HOME: tmpHome}})` and the fresh scaffold will still run normally, merging
into that pre-seeded settings.json rather than refusing. For the
home-settings-detection case, override `HOME` in the spawned child's `env`
(not `os.homedir()` directly — that's read inside the child process) to
point `os.homedir()` at a throwaway tmp dir. This is the first
`tests/cli-backfill.test.js` block that spawns the actual scaffold
(not just `--update`) — assert on the merged `.claude/settings.json`
content (e.g. `JSON.stringify(settings.hooks).includes('${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts')`)
rather than stdout text, since the exact wording of the skip/override
console messages isn't part of the acceptance criteria.

Cursor/codex scaffold functions (`scaffoldCursor`, `scaffoldCodex`) are
explicitly out of scope for this guard — `detectMarketplacePlugin` always
returns `enabled: false` for those targets (issue #67 design), so no
equivalent gating was added there. A future unit touching those targets
would need its own decision, not an extension of this one.
