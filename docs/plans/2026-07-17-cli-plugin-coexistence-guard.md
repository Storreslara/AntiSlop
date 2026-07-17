# Standalone CLI installer: detect an already-enabled marketplace plugin before writing duplicate hook registrations

Status: FINALIZED (2026-07-17). Both open questions resolved by the user;
published to the issue tracker via `to-spec` with the `ready-for-agent` label.
This is the canonical artifact; the tracker issue is the additive publish.

## Goal
Make `bin/cli.js`'s standalone installer detect that the antislop plugin is
already enabled via the Claude Code marketplace
(`enabledPlugins["antislop@antislop-marketplace"] === true`, across the three
settings files where that key can live) BEFORE it writes hook registrations,
and — on detection — skip only the hook-registration merge while completing
the rest of the scaffold (Option C), with a `--force-hooks` opt-out. The guard
is added to all three scaffold targets (`claude`, `cursor`, `codex`) for
uniformity; for cursor/codex it is a structurally always-false, documented
no-op because no marketplace/plugin-enable distribution of antislop exists for
those ecosystems.

## Context
Two mutually-exclusive install paths register the same hooks for the Claude
target:
- Marketplace `/plugin` flow: when
  `enabledPlugins["antislop@antislop-marketplace"]: true` is set, Claude Code
  auto-loads `hooks/hooks.json`, registering hooks at
  `${CLAUDE_PLUGIN_ROOT}/hooks/scripts/*.sh`.
- Standalone CLI (`node bin/cli.js`, default `--target=claude`): copies
  `hooks/scripts/*.sh` into `.claude/hooks/scripts/`, rewrites
  `${CLAUDE_PLUGIN_ROOT}/hooks/scripts` → `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts`
  (`bin/cli.js:1330-1332`), and merges that into `.claude/settings.json`
  (`bin/cli.js:1346`, `deepMerge(settings, hooksConfig)`).

When both are active for one project, each hook (e.g. `stop-gate.sh`) is
registered twice under two different roots. Both fire on every event ("Ran 2
stop hooks") and both enforce the same `.claude/.pending-review.*` gate,
producing duplicate near-identical block messages. Observed by the user in
real sessions. The gate logic (`hooks/scripts/stop-gate.sh`) is NOT buggy —
this is purely a double-registration collision. Nothing currently detects it.

Hook-merge site per target (all verified against `bin/cli.js`, 1463 lines):
- **claude** — `deepMerge(settings, hooksConfig)` at line 1346, into
  `.claude/settings.json`. Separate call from the settingsFragment merge on
  line 1345 (agent/env/permissions), so it can be gated independently.
- **cursor** — the dedupe-aware per-event merge loop at lines 810-823, into
  `.cursor/hooks.json` (`${CURSOR_PLUGIN_ROOT}` → `.cursor/hooks/scripts`).
- **codex** — `mergeNestedHooksJson(hooks, hooksConfig)` at line 1075, into
  `.codex/hooks.json` (`${PLUGIN_ROOT}` → `.codex/hooks/scripts`).

Why the collision is Claude-only in practice (and why the cursor/codex guard
is a documented no-op rather than a live check): `enabledPlugins` is a Claude
Code settings concept, and the marketplace hooks.json resolves
`${CLAUDE_PLUGIN_ROOT}`, which only Claude Code resolves. Cursor and Codex
neither read `enabledPlugins` nor resolve `${CLAUDE_PLUGIN_ROOT}`. Moreover,
antislop reaches cursor/codex ONLY through this standalone CLI scaffold
(`adapters/cursor`, `adapters/codex`) — there is no Cursor or Codex
marketplace/plugin-enable distribution of antislop, so no second registration
path exists to collide with. (Cursor's own merge loop is already dedupe-aware,
so even `--overwrite` re-runs don't double-register there.) The user chose to
apply the guard uniformly to all three targets anyway, for
consistency/future-proofing; the honest implementation is a single
target-aware detector whose cursor/codex branch always returns "not enabled"
with an explanatory reason, so the guard is present and honors `--force-hooks`
but structurally never fires for those targets.

Other structural facts:
- `--update` (`runUpdate`, lines 436-606) resyncs agent files/hashes only; it
  never writes hook registrations, so it cannot cause or re-trigger this
  collision. No change there.
- The claude scaffold runs on both a fresh install and `--overwrite` (both
  reach line 1346), so the guard covers `--overwrite` re-runs automatically.
- `os` is already imported (line 16); `os.homedir()` on Linux respects `$HOME`,
  making `~/.claude/settings.json` controllable in tests via
  `spawnSync(..., { env: { HOME: tmpHome } })`.
- `--yes`/`-y` makes the claude scaffold fully non-interactive
  (`scriptedMode`); the cursor/codex scaffolds are already non-interactive.

The three settings files where
`enabledPlugins["antislop@antislop-marketplace"]` can legitimately be `true`
(claude target only):
1. `<project>/.claude/settings.json`
2. `<project>/.claude/settings.local.json`
3. `<user home>/.claude/settings.json` (`os.homedir()`)

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-17 Functional scope & success criteria: Q What exactly must the
  installer detect and when? → A (self-resolved): detect
  `enabledPlugins["antislop@antislop-marketplace"] === true` in any of the
  three settings files, evaluated BEFORE the hooks merge, for the claude
  target.
- 2026-07-17 Domain entities / data model: Q Which value of the enabledPlugins
  key counts as "enabled"? → A (self-resolved): strictly `=== true`. `false`
  or a missing key does NOT count.
- 2026-07-17 External dependencies & integrations: Q Which files hold the key,
  and does the guard apply to cursor/codex? → A: three files listed in
  Context; per the user, the guard is added to ALL three targets. For
  cursor/codex it is a documented always-false no-op (no antislop
  marketplace/plugin-enable path exists there to collide with) — see OQ2.
- 2026-07-17 Edge cases / failure handling: Q What if a settings file is
  absent or malformed JSON? → A (self-resolved): detection must never crash
  the installer — treat absent/unreadable/malformed as "not enabled".
- 2026-07-17 Technical constraints & tradeoffs: Q Should `--update` also gain
  this check? → A (self-resolved): no — `runUpdate` never writes hook
  registrations.
- 2026-07-17 User interaction flow: Q On detection, abort / warn / skip-hooks
  / prompt? → A (user): Option C — skip ONLY the hook-registration merge,
  finish the rest of the scaffold normally, add a `--force-hooks` opt-out.
- 2026-07-17 Technical constraints & tradeoffs: Q What overrides the guard for
  a deliberate coexistence/transition? → A (user): the `--force-hooks` flag;
  proposed name accepted. `--yes` alone does NOT imply the override.

## Risks / dependencies
- Behavioral change to the installer's most-used path. A false positive would
  suppress the hook registration the user wants; the strict `=== true` rule
  plus best-effort reads bound this. The `--force-hooks` opt-out is the escape
  hatch.
- The three-file scan reads a file outside the project
  (`~/.claude/settings.json`) — read-only, best-effort; must never write to or
  require it.
- Prior `.fail` history: `.claude/reviewed/` shows `bin/cli.js`-adjacent work
  has failed-then-passed before (`reviewer-gate-model-step-1.fail`, several
  `1.x`/`3.x` records) — this file's regex/merge logic is historically
  high-risk. This change adds only JSON reads and gated merge calls (no
  regex), lower-risk, but the detection helper and the target-gating still
  warrant direct tests. Because of this history, task-master should NOT tag
  these units `haiku`.
- Constitution P5: `tests/validate.sh` runs `tests/cli-backfill.test.js` — the
  new tests must live there so they actually gate.
- Codex caveat (pre-existing, not introduced here): `.codex/hooks.json` is
  "scaffolded but not yet trusted" and its registration shape isn't verified
  against a live Codex build (see the codex scaffold's closing notes and
  docs/codex-port-notes.md). The guard does not change that; it only gates the
  same merge that already runs.

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume": satisfied — acceptance is runnable tests in
  `tests/cli-backfill.test.js` that spawn the real CLI and assert on the
  written settings/hooks files, not visual inspection.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  deterministic installer logic, no LLM path, no hand-editing of
  script-driven files.
- P3 "Version-stamp discipline": deviation — `bin/cli.js` is not a
  version-stamped persona/template file, so no `plugin.json` bump is required
  for the code change itself. A CHANGELOG entry for the installer's new
  user-facing behavior IS warranted; flagged for task-master/scribe, not a
  blocker.
- P4 "Optional personas degrade gracefully": satisfied — no persona prose
  changes.
- P5 "tests/validate.sh is the merge gate": satisfied — tests added to
  `tests/cli-backfill.test.js`, already run by `validate.sh`.

## Step 1 — Add a target-aware `detectMarketplacePlugin` helper
Affected files: `bin/cli.js` (new pure function + add to `module.exports`).

Add a side-effect-free, exported helper returning a boolean plus provenance.
Target-aware: real 3-file scan for `claude`; documented always-false for
`cursor`/`codex`. Pseudo-code:

```
const MARKETPLACE_PLUGIN_KEY = 'antislop@antislop-marketplace';

// Returns { enabled: boolean, source: string|null, reason: string|null }.
// Best-effort: any absent/unreadable/malformed file counts as not-enabled.
function detectMarketplacePlugin(target, cwd, homeDir) {
  if (target !== 'claude') {
    // No antislop marketplace/plugin-enable distribution exists for cursor or
    // codex — the standalone CLI scaffold is the ONLY hook-registration path
    // for those targets, so the double-registration collision is structurally
    // impossible. The guard is kept uniform across targets (and honors
    // --force-hooks) but is an intentional always-false no-op here.
    return { enabled: false, source: null,
      reason: `no marketplace plugin-enable mechanism for target '${target}'` };
  }
  const candidates = [
    path.join(cwd, '.claude', 'settings.json'),
    path.join(cwd, '.claude', 'settings.local.json'),
    path.join(homeDir, '.claude', 'settings.json'),
  ];
  for (const file of candidates) {
    try {
      if (!fs.existsSync(file)) continue;
      const json = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (json && json.enabledPlugins &&
          json.enabledPlugins[MARKETPLACE_PLUGIN_KEY] === true) {
        return { enabled: true, source: file, reason: null };
      }
    } catch (_) { /* malformed/unreadable → not-enabled */ }
  }
  return { enabled: false, source: null, reason: null };
}
```

Export `detectMarketplacePlugin` from `module.exports`, matching the existing
exported-helper convention (`deriveMcpLaunchFromDisk`, etc.).

Acceptance criteria (unit tests in `tests/cli-backfill.test.js`, run via
`node tests/cli-backfill.test.js` and `bash tests/validate.sh`):
- `detectMarketplacePlugin('claude', cwd, home)` returns
  `{enabled:true, source:<file>}` when the key is `true` in each of, separately:
  `<cwd>/.claude/settings.json`, `<cwd>/.claude/settings.local.json`,
  `<home>/.claude/settings.json`.
- Returns `enabled:false` when the value is `false`, when the key is absent,
  and when `enabledPlugins` is absent.
- Returns `enabled:false` (does NOT throw) when a candidate file is malformed
  JSON.
- `detectMarketplacePlugin('cursor', ...)` and
  `detectMarketplacePlugin('codex', ...)` return `enabled:false` even when the
  plugin key IS set to `true` in all three settings files (proves the
  cursor/codex branch is an unconditional no-op that never scans).

## Step 2 — `--force-hooks` flag + gate the claude hooks merge (Option C)
Affected files: `bin/cli.js` (default `--target=claude` scaffold path around
lines 1340-1348; flag parsing near line 1174-1176).

Recognize `--force-hooks` (`args.includes('--force-hooks')`). In the claude
scaffold, compute detection once before the hooks merge, using `CWD` and
`os.homedir()`. Keep the settingsFragment merge (line 1345) unchanged; gate
ONLY the hooksConfig merge (line 1346). Option C behavior:

```
const forceHooks = args.includes('--force-hooks');
const pluginState = detectMarketplacePlugin('claude', CWD, os.homedir());
deepMerge(settings, settingsFragment);                 // unchanged (1345)
if (pluginState.enabled && !forceHooks) {
  console.log(`  NOTE: antislop is already enabled via the marketplace plugin `
    + `(${pluginState.source}); its hooks are loaded from `
    + `\${CLAUDE_PLUGIN_ROOT}. Skipping the standalone `
    + `\${CLAUDE_PROJECT_DIR} hook registration to avoid a duplicate `
    + `("Ran 2 stop hooks"). Re-run with --force-hooks if you intend to `
    + `disable the plugin and use the standalone hooks instead.`);
} else {
  if (pluginState.enabled) {
    console.log('  --force-hooks: writing standalone hook registrations even '
      + 'though the marketplace plugin is enabled — expect duplicate hook '
      + 'firing until the plugin is disabled.');
  }
  deepMerge(settings, hooksConfig);                    // gated (1346)
}
fs.writeFileSync(settingsPath, ...);                   // still writes everything else
```

Everything else in the scaffold (agents, skills, protocol, settingsFragment,
CLAUDE.md, persona-config, .gitignore) is unchanged — only the hook
registration is conditionally skipped.

Acceptance criteria (integration, `spawnSync('node', [cliPath, ...])` in a tmp
cwd + tmp HOME):
- **Negative/regression:** with NO plugin key set anywhere,
  `node bin/cli.js --yes` writes a `.claude/settings.json` whose `hooks`
  object contains the `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts`
  registrations exactly as today.
- **Guard fires (Option C):** with the key `true` in
  `<cwd>/.claude/settings.json`, `node bin/cli.js --yes` exits 0 and writes a
  `.claude/settings.json` that (a) does NOT contain any
  `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts` hook registration, and (b)
  still contains the settingsFragment keys (e.g. `agent: "orchestrator"`).
- **Guard fires via home settings:** same as above but the key is set only in
  `<home>/.claude/settings.json` (tmp HOME) — confirms the out-of-project file
  is honored.
- **Opt-out:** with the key `true` AND `--force-hooks`,
  `node bin/cli.js --yes --force-hooks` writes the
  `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts` registrations (restores
  today's behavior on demand).

## Step 3 — Wire the guard into the cursor and codex scaffolds (uniform no-op)
Affected files: `bin/cli.js` (`scaffoldCursor` around lines 796-825;
`scaffoldCodex` around lines 1066-1077).

For uniformity per the user's decision, both scaffolds recognize
`--force-hooks` and gate their hook-merge on
`detectMarketplacePlugin(target, CWD, os.homedir())` exactly as the claude
path does. Because the helper's cursor/codex branch always returns
`enabled:false`, the merge always runs — behavior is byte-for-byte unchanged
from today — but the guard is present, documented, and honors `--force-hooks`,
so the requirement is met explicitly rather than silently dropped. Add an
inline comment at each site pointing to the helper's no-op rationale.

- cursor: gate the per-event dedupe-merge loop (lines 810-823) /
  `fs.writeFileSync(hooksPath, ...)`.
- codex: gate `mergeNestedHooksJson(hooks, hooksConfig)` (line 1075) /
  the subsequent write.

Acceptance criteria:
- **cursor not over-guarded:** with the plugin key `true` in
  `<cwd>/.claude/settings.json` (and/or tmp HOME),
  `node bin/cli.js --target=cursor` exits 0 and writes a `.cursor/hooks.json`
  that DOES contain the `.cursor/hooks/scripts` registrations — proving the
  Claude marketplace key does not suppress cursor hooks.
- **codex not over-guarded:** same, `node bin/cli.js --target=codex` writes a
  `.codex/hooks.json` containing the `.codex/hooks/scripts` registrations even
  with the plugin key set.
- (The unit-level always-false assertions for cursor/codex live in Step 1.)

## Open Questions
Both resolved by the user on 2026-07-17; retained for the audit trail.
1. **RESOLVED (Option C).** On detecting the plugin is enabled, the claude
   installer skips ONLY the hook-registration merge, completes the rest of the
   scaffold, and offers `--force-hooks` to write the hooks anyway. `--yes`
   alone does not override the guard.
2. **RESOLVED (all targets).** The guard is added to claude, cursor, and codex
   uniformly. For cursor/codex it is a documented, structurally always-false
   no-op — no antislop marketplace/plugin-enable distribution exists for those
   ecosystems, so the collision is impossible there; the code path,
   `--force-hooks` handling, and rationale comment are present so the
   requirement is honored explicitly, not silently dropped.

## Self-check
- CHK1: Is "enabled" given a machine-checkable definition? — PASS (strict
  `=== true`, Step 1).
- CHK2: Are all three settings-file locations enumerated and each covered by
  an acceptance criterion? — PASS (Step 1 + Step 2 home-settings criterion).
- CHK3: Is absent/malformed-file behavior defined and tested? — PASS
  (best-effort → not-enabled; Step 1 malformed-JSON criterion).
- CHK4: Do Context/Steps agree on WHERE each target's collision write is and
  that only it is gated? — PASS (claude 1346, cursor 810-823, codex 1075,
  stated consistently).
- CHK5: Is the cursor/codex scope decided with a checkable consequence? — PASS
  (Step 1 always-false unit assertions + Step 3 "not over-guarded" integration
  criteria).
- CHK6: Is the action-on-detection behavior fully specified with a runnable
  acceptance criterion? — PASS (Option C, Step 2; was FAIL/OQ1, now resolved).
- CHK7: Is there a regression guard that the guard does NOT fire when the
  plugin is absent? — PASS (Step 2 negative-path criterion).
- CHK8: Does the plan avoid touching code paths that can't collide
  (`--update`)? — PASS (Clarifications + Context rule it out with a reason).
- CHK9: Is the `--force-hooks` override behavior specified and tested for the
  claude target, and its interaction with `--yes` pinned down? — PASS (Step 2
  opt-out criterion; `--yes` does not override).
- CHK10: For cursor/codex, is the "no-op, not silently dropped" requirement
  discharged with an explicit rationale AND a test? — PASS (Step 1 no-op
  unit + Step 3 not-over-guarded integration + Context/OQ2 rationale).

All items PASS. No FAIL outstanding; safe to publish.

## Scribe update hint
Once implemented: add a CHANGELOG.md entry — the standalone installer now
detects an already-enabled `antislop@antislop-marketplace` plugin (across
project `.claude/settings.json`, project `.claude/settings.local.json`, and
`~/.claude/settings.json`) and skips the duplicate `${CLAUDE_PROJECT_DIR}` hook
registration for the claude target, with `--force-hooks` to override; the same
guard is present on cursor/codex targets as a documented no-op. If a
wiki/CONTEXT entry documents the standalone-vs-marketplace install split, add a
line about the coexistence guard.
