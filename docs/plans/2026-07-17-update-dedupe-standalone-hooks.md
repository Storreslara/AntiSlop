# Make `--update` detect (and optionally resolve) stale standalone hook registrations that collide with the marketplace plugin

Status: FINALIZED (2026-07-17). Self-check passes. Published to the issue
tracker via the `to-spec` process as GitHub issue #74 (`ready-for-agent`
label); this `docs/plans/` document is the canonical artifact, the tracker
issue is the additive publish. Follow-up to the shipped #66–73 marketplace hook-coexistence
guard (`docs/plans/2026-07-17-cli-plugin-coexistence-guard.md` and
`docs/plans/2026-07-17-detect-marketplace-plugin-precedence.md`, CHANGELOG
0.13.2). Independent of that shipped work, which stays as-is. Two non-blocking
Open Questions are recorded for user confirmation (both carry a recommended
default and the finalized design is safe under either answer); next:
`task-master` slices this into dispatch-ready units.

## Goal
Give `bin/cli.js`'s `--update` command (`runUpdate`) awareness of the
duplicate-hook collision the #66–73 work fixed for *fresh installs / `--overwrite`*
but never reached for the *resync* path. Concretely: when `--update` runs in a
project that (a) has the antislop marketplace plugin enabled (per the existing
`detectMarketplacePlugin('claude', …)` precedence check) AND (b) still carries
standalone antislop hook registrations in its `.claude/settings.json` (commands
under `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/…`, written by a pre-guard
standalone install), `--update` must **detect and report** that collision, and
— only under an explicit new `--dedupe-hooks` flag — **surgically remove** just
those standalone registrations, leaving the marketplace plugin to provide the
hooks.

Default behavior is **warn-only**: `--update` never rewrites `.claude/settings.json`
without the explicit `--dedupe-hooks` flag. This is deliberate — see Safety
(Step 2) and OQ1.

## Context
### The gap
The shipped guard (#66–73) gates the fresh-scaffold hooks merge
(`deepMerge(settings, hooksConfig)`, bin/cli.js:1441) on
`detectMarketplacePlugin`, with a `--force-hooks` opt-out. That covers a fresh
install and `--overwrite` (both reach line 1441). It does NOT cover `--update`:
`runUpdate` (bin/cli.js:436–605) only resyncs version-stamped `.md` files
(`.claude/agents/*.md`, `.claude/persona-protocol.md`,
`.claude/protocol-digest.md`) via content-hash diffing (`buildFileSpecs` →
`renderCleanBody` → `sha256Hex`, the noLocalEdits/pending/`--accept`/`--keep`
machinery). It never reads or writes `.claude/settings.json`'s `hooks` section,
never touches `.claude/hooks/scripts/`, and never calls
`detectMarketplacePlugin`. Verified by reading both functions.

So a project that ran the standalone `node bin/cli.js` installer BEFORE the
guard existed has duplicate-causing hook entries sitting in its
`.claude/settings.json` (each command rewritten by the installer from
`${CLAUDE_PLUGIN_ROOT}/hooks/scripts/*.sh` to
`${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/*.sh`, bin/cli.js:1407). If that
project then enables the marketplace plugin, both registrations fire every
event ("Ran 2 stop hooks"). Running `node bin/cli.js --update` — even after
upgrading antislop — gives ZERO benefit today. The only current remedies are
`--overwrite` (a heavy full re-copy) or manual settings surgery.

### What the standalone installer deterministically writes (the detection signature)
The installer's hook registrations are not hand-authored guesses — they are the
exact output of parsing `hooks/hooks.json` and rewriting the path prefix
`${CLAUDE_PLUGIN_ROOT}/hooks/scripts` → `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts`
(bin/cli.js:1405–1408). So every standalone-installed antislop hook command has
the literal prefix:

```
${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/
```

followed by one of antislop's own script basenames (the set is enumerable from
`hooks/hooks.json`: `graph-update.sh`, `lint-on-edit.sh`, `protected-paths.sh`,
`reviewer-route-gate.sh`, `reviewed-path-gate.sh`, `stop-gate.sh`,
`session-start.sh`, `task-gate.sh`). This is a precise, deterministic,
retroactive signature — it matches what already sits in legacy projects'
settings, with no marker having been needed at install time. The existing test
harness already treats `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts` as the
canonical `HOOK_MARKER` (tests/cli-backfill.test.js:355), so this signature is
already load-bearing and shared.

### Why NOT add a stamp/marker to the scaffold (design fork #1 resolved)
The task raised whether the scaffold should start stamping a marker (like the
version-stamp comments on `.md` files) so future `--update` runs can identify
its own hook entries. Resolved: **no marker.** Rationale:
- The entire population this spec targets was installed BEFORE any marker could
  exist, so a marker cannot retroactively identify their stale entries —
  defeating the purpose. Content-signature detection is the only approach that
  works for the legacy population, and it is exact.
- `.claude/settings.json` is strict JSON (Claude Code rejects comments), so a
  `.md`-style comment stamp cannot live inside the `hooks` array; a sibling
  metadata key would pollute settings and still not help legacy projects.
- The command-path signature above is already deterministic and unique to
  antislop's own rewrite, so a marker adds nothing this fix needs.

### Why this is claude-only (design fork #3 resolved)
`runUpdate` is structurally a claude-scoped operation: it reads
`.claude/persona-config.json`, and `buildFileSpecs` only ever writes under
`.claude/`. There is no `--update --target=cursor|codex` code path, and no
cursor/codex hook management in `runUpdate` at all. The #69 scaffold decision
applied the guard "uniformly to all three targets," but that was gating an
already-present per-target merge call; here there is no cursor/codex
hooks-merge in `--update` to gate — extending it would mean inventing net-new
machinery for a collision that is structurally impossible for cursor/codex (no
antislop marketplace/plugin-enable distribution exists there;
`detectMarketplacePlugin('cursor'|'codex', …)` is a hard-coded always-false
no-op). So the dedupe pass is claude-only, consistent with `--update`'s
existing scope. (Cursor/codex `.cursor|.codex/hooks.json` are managed only by
their own scaffolds, which are already dedupe-aware.)

### Does this fit `--update`'s hash-diff model? (the task's "bigger structural change" flag)
Partly separate, but it fits cleanly as an **additive, self-contained pass** —
NOT as an extension of the content-hash-diff model. The collision resolution
operates on `.claude/settings.json` (JSON structure), is not a stamped-`.md`
drift/diff operation, and deliberately does NOT plumb through the
`fileHashes`/`noLocalEdits`/`pending`/`--accept`/`--keep` machinery (which
exists for stamped `.md` content, not JSON settings). It is a standalone
detect-and-optionally-remove pass with its own flag. The one structural
interaction: it must run BEFORE `runUpdate`'s version-match fast-path
early-return (bin/cli.js:487–490), because a project can be fully current on
`.md` files yet still carry the stale-hooks collision — see Step 2 ordering.
This is a small placement constraint, not a reshaping of the model. Finding:
this does NOT require a bigger structural change; it fits as an added pass.

### Structural facts (verified against bin/cli.js, 1560 lines)
- `runUpdate` early-return fast-path: lines 487–490.
- Claude scaffold hooks-merge site (the fresh-install guard): lines 1420–1443;
  `HOOK_MARKER`/rewrite at 1405–1408.
- `detectMarketplacePlugin(target, cwd, homeDir)` (precedence-aware, best-effort,
  `{enabled, source, reason}`): lines 953–989; exported at
  `module.exports` (line 1546+, includes `detectMarketplacePlugin`,
  `buildFileSpecs`, `renderCleanBody`, `sha256Hex`).
- `os` (line 16) and `fs`/`path` are imported; `os.homedir()` respects `$HOME`
  on Linux, so tests control `~/.claude/settings.json` via a tmp HOME.
- Test harness: `tests/cli-backfill.test.js` (run by `bash tests/validate.sh`,
  the merge gate). It already exercises `detectMarketplacePlugin` as a pure
  function AND drives `--update` / the scaffold out-of-process via `spawnSync`
  (runUpdate calls `process.exit()`), with `buildBaselineProject(tmp, …)` to
  construct an adapted project fixture. The new tests reuse both patterns.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-17 Functional scope & success criteria: Q What exactly must `--update`
  do, and what is the success signal? → A (self-resolved): detect the
  plugin-enabled + standalone-hooks-present collision and, under `--dedupe-hooks`,
  surgically remove only the standalone antislop hook registrations; success =
  new tests in `tests/cli-backfill.test.js` (Step 1 + Step 2) pass under
  `bash tests/validate.sh`.
- 2026-07-17 Domain entities / data model: Q How is a "standalone antislop hook
  registration" identified vs hand-authored/other-tool entries? → A
  (self-resolved): by the deterministic command-path signature
  `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/` (the installer's exact rewrite
  target), optionally intersected with antislop's known script basenames from
  `hooks/hooks.json`. No new marker is added (see Context: design fork #1).
- 2026-07-17 User interaction flow: Q On detecting the collision, does `--update`
  auto-fix, warn, or require a flag? → A (self-resolved, recommended-default;
  surfaced for confirmation as OQ1): warn-only by default (never rewrites
  settings.json), with an explicit `--dedupe-hooks` flag to perform the removal.
  This is the safety-critical choice — see Step 2.
- 2026-07-17 Edge cases / failure handling: Q What if settings.json is absent /
  malformed, or the plugin is NOT enabled? → A (self-resolved): absent/malformed
  settings.json = best-effort, no crash, treat as "no standalone hooks found";
  plugin NOT enabled = NO collision → `--dedupe-hooks` is a no-op that never
  strips (removing the only hooks would recreate the silent-zero-hooks failure
  the #71 fix guarded against).
- 2026-07-17 External dependencies & integrations: Q Does the detection depend on
  the `enabledPlugins` data format that is still unverified (object-of-booleans
  vs array)? → A: yes — it reuses `detectMarketplacePlugin`, which assumes the
  object-of-booleans form. Inherited from #71 as OQ2; the fix degrades safely
  under either answer (array form → detection never fires → settings left
  untouched → duplicate persists but nothing is wrongly removed).
- 2026-07-17 Technical constraints & tradeoffs: Q Does this need to extend the
  hash-diff model or a bigger structural change? → A (self-resolved): no — it
  fits as a self-contained additive pass, not plumbed through the fileHashes
  machinery; the only constraint is running it before the version-match
  fast-path (Context + Step 2).
- 2026-07-17 Terminology consistency: Q What terms/constants are reused? → A
  (self-resolved): the existing `HOOK_MARKER`
  (`${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts`) signature and
  `detectMarketplacePlugin`; new flag named `--dedupe-hooks` (name confirmable,
  OQ1).
- 2026-07-17 Non-functional attributes: Q Any perf/security/scale concern? → A
  (self-resolved): none material — bounded JSON reads of at most three settings
  files plus one project settings.json, no network, no writes outside the
  project's own `.claude/settings.json`, and that write only under an explicit
  flag.
- 2026-07-17 Completion / acceptance signals: Q What proves done? → A
  (self-resolved): the five machine-checkable tests in Step 1/Step 2, all green
  under `bash tests/validate.sh`.

## Risks / dependencies
- **Behavioral change to `--update`, the most-used resync path.** Mitigated by
  the warn-only default: no settings.json write happens without `--dedupe-hooks`.
  Under `--dedupe-hooks`, removal is surgical (signature-matched entries only)
  and gated on the plugin actually being enabled, so it can never leave a
  project with zero hooks.
- **Cannot distinguish intentional `--force-hooks` coexistence from accidental
  stale leftover by settings.json state alone.** Both produce the exact same
  on-disk state (plugin enabled + standalone hooks present); there is no record
  of whether `--force-hooks` was originally passed. This is precisely why the
  default is warn-only and removal is opt-in: a user who deliberately wants both
  simply never passes `--dedupe-hooks`, and their coexistence is preserved. See
  Step 2 and OQ1.
- **OQ2 (`enabledPlugins` data format, inherited from #71 / spec-master memory
  `enabledplugins-format-uncertainty`).** Detection reuses
  `detectMarketplacePlugin`, which assumes the object-of-booleans form. If real
  Claude Code uses the documented array form, `detectMarketplacePlugin` returns
  `enabled:false` → no collision detected → `--update` leaves settings.json
  untouched (the safe direction: the duplicate persists, but nothing is wrongly
  removed). Non-blocking; flagged for the same verification #71 already owns.
- **Prior `.fail` history on `bin/cli.js`.** `.claude/reviewed/` shows this
  file's logic has failed-then-passed repeatedly (`1.4`, `1.10`, `3.1b`, `3.3`,
  `reviewer-gate-model-step-1`). This change is JSON reads + a structural
  walk/removal (no new regex), lower-risk, but the history means `task-master`
  must NOT tag these units `haiku`, and the detection + surgical-removal helpers
  warrant direct unit tests (Step 1).
- **Constitution P5:** tests must live in `tests/cli-backfill.test.js` so
  `tests/validate.sh` actually gates them.
- **Constitution P3:** a CHANGELOG entry for the new `--dedupe-hooks`
  user-facing behavior is warranted (flagged for task-master/scribe); `bin/cli.js`
  is not a version-stamped persona/template file, so no `plugin.json` bump is
  required for the code change itself.

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume": satisfied — the detection signature is the exact
  string the installer writes (verified at bin/cli.js:1405–1408, and already the
  test harness's `HOOK_MARKER`), not an assumed shape; acceptance is runnable
  tests that assert on the written `.claude/settings.json`, not inspection. The
  one unverifiable dependency (`enabledPlugins` format) is surfaced as OQ2, not
  assumed away.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — pure,
  deterministic installer logic; no LLM path; no hand-editing of script-driven
  files.
- P3 "Version-stamp discipline": deviation — `bin/cli.js` is not a
  version-stamped persona/template file, so no `plugin.json` bump is required for
  the code change. A CHANGELOG entry for the new user-facing `--dedupe-hooks`
  behavior IS warranted; flagged for task-master/scribe, not a blocker.
- P4 "Optional personas degrade gracefully": satisfied — no persona prose
  changes.
- P5 "tests/validate.sh is the merge gate": satisfied — tests added to
  `tests/cli-backfill.test.js`, already run by `validate.sh`.

## Step 1 — Add pure, exported helpers: detect and strip standalone hook registrations
Affected files: `bin/cli.js` (two new side-effect-free functions + add both to
`module.exports`, matching the existing exported-helper convention —
`detectMarketplacePlugin`, `buildFileSpecs`, `renderCleanBody`, `sha256Hex`).

Add a shared constant and two pure functions that operate on an in-memory
settings object (no file I/O — I/O stays in `runUpdate`, Step 2, so these are
unit-testable directly like `detectMarketplacePlugin`). Pseudo-code (intent, not
final source):

```
// The exact prefix the standalone installer rewrites hook commands to
// (bin/cli.js scaffold: ${CLAUDE_PLUGIN_ROOT}/hooks/scripts -> this). Already
// the test harness's HOOK_MARKER.
const STANDALONE_HOOK_PATH_MARKER = '${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/';

// Returns an array describing every standalone antislop hook registration found
// in settings.hooks, e.g. [{ event, matcher, script }]. Pure, best-effort:
// tolerates a missing/oddly-shaped hooks object by returning [].
function findStandaloneHookRegistrations(settings) {
  const found = [];
  const hooks = settings && settings.hooks;
  if (!hooks || typeof hooks !== 'object') return found;
  for (const event of Object.keys(hooks)) {
    const groups = Array.isArray(hooks[event]) ? hooks[event] : [];
    for (const group of groups) {
      const entries = group && Array.isArray(group.hooks) ? group.hooks : [];
      for (const entry of entries) {
        if (entry && typeof entry.command === 'string' &&
            entry.command.includes(STANDALONE_HOOK_PATH_MARKER)) {
          found.push({ event, matcher: group.matcher || null,
                       script: entry.command.split('/').pop() });
        }
      }
    }
  }
  return found;
}

// Returns a NEW settings object (deep clone) with every standalone antislop hook
// entry removed, plus now-empty matcher-groups and now-empty event arrays
// pruned; if hooks becomes empty, remove the hooks key entirely. Every other
// key (including user-authored hooks whose command does NOT match the marker)
// is preserved untouched. Pure — does not mutate its argument, does no I/O.
function stripStandaloneHookRegistrations(settings) {
  const clone = JSON.parse(JSON.stringify(settings));
  const hooks = clone.hooks;
  if (!hooks || typeof hooks !== 'object') return clone;
  for (const event of Object.keys(hooks)) {
    const groups = Array.isArray(hooks[event]) ? hooks[event] : [];
    for (const group of groups) {
      if (group && Array.isArray(group.hooks)) {
        group.hooks = group.hooks.filter((e) =>
          !(e && typeof e.command === 'string' &&
            e.command.includes(STANDALONE_HOOK_PATH_MARKER)));
      }
    }
    hooks[event] = groups.filter((g) => !(g && Array.isArray(g.hooks) && g.hooks.length === 0));
    if (hooks[event].length === 0) delete hooks[event];
  }
  if (Object.keys(hooks).length === 0) delete clone.hooks;
  return clone;
}
```

Notes for the implementer:
- Match by the `STANDALONE_HOOK_PATH_MARKER` prefix. Intersecting with the
  known antislop script basename set (enumerable from `hooks/hooks.json`) is an
  allowed belt-and-suspenders refinement but not required — the marker prefix is
  already unique to antislop's own rewrite.
- `stripStandaloneHookRegistrations` MUST NOT mutate its input (clone first);
  `runUpdate` decides whether to write the result.
- Export both `findStandaloneHookRegistrations` and
  `stripStandaloneHookRegistrations` from `module.exports`.

Acceptance criteria (unit tests in `tests/cli-backfill.test.js`; run via
`node tests/cli-backfill.test.js` and `bash tests/validate.sh`, expect exit 0):
- `findStandaloneHookRegistrations` returns a non-empty list for a settings
  object whose `hooks` contains a command with the
  `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/stop-gate.sh` marker, and returns
  `[]` for a settings object with only `${CLAUDE_PLUGIN_ROOT}`-rooted commands,
  with no `hooks` key, or with a non-object `hooks`.
- `stripStandaloneHookRegistrations` removes exactly the marker-matched entries:
  given a `hooks` object mixing (a) a standalone antislop entry and (b) a
  user-authored entry whose command does NOT contain the marker, the returned
  object drops (a), keeps (b), and prunes any group/event left empty by the
  removal; the input object is unchanged (not mutated).
- `stripStandaloneHookRegistrations` deletes the `hooks` key entirely when every
  entry was a standalone antislop entry (no empty-`hooks` cruft left behind).
- Non-`hooks` settings keys (e.g. `agent: "orchestrator"`, `env`, `permissions`)
  are preserved byte-for-byte in the returned object.

## Step 2 — Wire the detect/warn/dedupe pass into `runUpdate` (warn-only default + `--dedupe-hooks`)
Affected files: `bin/cli.js` (`runUpdate`, near the top after `config` is loaded
— before the version-match fast-path at lines 487–490; new flag parse alongside
the existing `--check`/`--accept=`/`--keep=` parsing).

Add the pass so it runs on every `--update` invocation, BEFORE the fast-path
early-return (a fully-current project must still see the collision). Read
`.claude/settings.json` best-effort. Reuse `detectMarketplacePlugin('claude',
CWD, os.homedir())` for the plugin-enabled side. Pseudo-code:

```
const dedupeHooks = args.includes('--dedupe-hooks');
const settingsPath = path.join(CWD, '.claude', 'settings.json');
let settings = null;
try { if (fs.existsSync(settingsPath)) settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); }
catch (_) { settings = null; /* malformed -> best-effort, treat as no standalone hooks */ }

const pluginState = detectMarketplacePlugin('claude', CWD, os.homedir());
const standalone = settings ? findStandaloneHookRegistrations(settings) : [];
const collision = pluginState.enabled && standalone.length > 0;

if (collision && dedupeHooks) {
  const cleaned = stripStandaloneHookRegistrations(settings);
  fs.writeFileSync(settingsPath, JSON.stringify(cleaned, null, 2) + '\n');
  console.log(`  Removed ${standalone.length} standalone antislop hook registration(s) `
    + `from .claude/settings.json (the marketplace plugin, enabled per `
    + `${pluginState.source}, already provides them via \${CLAUDE_PLUGIN_ROOT}). `
    + `Duplicate hook firing ("Ran 2 stop hooks") resolved.`);
} else if (collision) {
  console.log(`  NOTE: antislop is enabled via the marketplace plugin `
    + `(${pluginState.source}) AND .claude/settings.json still carries `
    + `${standalone.length} standalone antislop hook registration(s) from a `
    + `pre-guard install — every hook fires twice ("Ran 2 stop hooks"). Re-run `
    + `with --dedupe-hooks to remove the standalone registrations (the plugin `
    + `keeps providing them). If you intentionally want BOTH active, do nothing.`);
} else if (dedupeHooks && standalone.length > 0 && !pluginState.enabled) {
  console.log('  --dedupe-hooks: the marketplace plugin is NOT enabled for this '
    + 'project, so the standalone hook registrations are the ONLY ones present — '
    + 'leaving them in place (removing them would disable all hooks). Nothing removed.');
}
// then continue to the existing version-match fast-path and .md diff loop unchanged
```

Behavioral requirements:
- **Warn-only default:** with no `--dedupe-hooks`, `.claude/settings.json` is
  NEVER written by this pass. The `.md`-resync half of `runUpdate` is unchanged.
- **Removal only under `--dedupe-hooks` AND only when the plugin is enabled.**
  `--dedupe-hooks` with the plugin NOT enabled removes nothing (guards against
  the silent-zero-hooks failure).
- **Runs before the fast-path early-return** so an otherwise-current project
  still gets the NOTE (or the removal).
- Do NOT route settings.json through the `fileHashes`/`pending`/`--accept`/
  `--keep` machinery — this pass is independent (see Context).
- Exit code: this pass does not, by itself, force a non-zero exit — a plain
  `--update` that only surfaces the collision NOTE still exits 0 (the collision
  is pre-existing, not caused by this run). The existing `.md`-pending exit-2 /
  unresolved-render exit-1 paths are unchanged.

Acceptance criteria (integration; `spawnSync('node', [cliPath, '--update', …])`
in a `buildBaselineProject` tmp cwd, plugin key seeded in the project's own
`.claude/settings.json` so no HOME override is needed; `HOOK_MARKER` =
`${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts` as in the existing harness):
- **Collision detected, warn-only default (left alone):** baseline project whose
  `.claude/settings.json` contains BOTH
  `enabledPlugins:{'antislop@antislop-marketplace':true}` AND a `hooks` entry
  with a `HOOK_MARKER/stop-gate.sh` command. `node bin/cli.js --update` exits 0,
  stdout contains the collision NOTE naming `--dedupe-hooks`, AND the written
  `.claude/settings.json` STILL contains the `HOOK_MARKER` command (proves
  warn-only does not rewrite).
- **`--dedupe-hooks` resolves it:** same fixture,
  `node bin/cli.js --update --dedupe-hooks` exits 0, the written
  `.claude/settings.json` `hooks` no longer contains `HOOK_MARKER`, and the
  `enabledPlugins` key plus any non-hooks keys are preserved.
- **Safety — no plugin enabled → `--dedupe-hooks` is a no-op:** baseline project
  with the `HOOK_MARKER` hooks present but NO `enabledPlugins` antislop key.
  `node bin/cli.js --update --dedupe-hooks` exits 0 and the written
  `.claude/settings.json` STILL contains `HOOK_MARKER` (proves it will not strip
  the only hooks present).
- **Surgical removal preserves a user's own hook:** fixture with plugin enabled +
  a `HOOK_MARKER` antislop entry + one user hook whose command does NOT contain
  the marker (e.g. a different path). `node bin/cli.js --update --dedupe-hooks`
  removes the antislop entry and preserves the user hook in the written file.
- **Runs past the version-match fast-path:** fixture is fully current
  (`config.pluginVersion` === the plugin's current version) AND has the
  collision. `node bin/cli.js --update` (no `--dedupe-hooks`) still prints the
  collision NOTE (proves the pass runs before the "Nothing to update" early
  return).

## Open Questions
Both are non-blocking confirmations — the finalized design is safe under either
answer, so the spec is publishable now; the orchestrator should relay these for
the user to confirm or override.
1. **Default behavior: warn-only vs auto-remove (safety-critical, recommended
   default given).** When `--update` detects the collision, should it (a)
   warn-only and require an explicit `--dedupe-hooks` to remove [RECOMMENDED,
   what this spec implements], or (b) auto-remove the standalone registrations by
   default whenever the plugin is enabled (since the plugin provably provides
   the hooks)?
   - **Recommended default (a):** warn-only + `--dedupe-hooks`. Rationale:
     silently rewriting a user's `.claude/settings.json` is exactly the surprise
     the project's "never silently clobber local edits" philosophy exists to
     prevent, AND the intentional-`--force-hooks`-coexistence state is
     indistinguishable from accidental-stale by settings state alone — so
     auto-removal could undo a deliberate choice. Warn-only is the safe,
     reversible baseline; opting into auto-remove-by-default later is a trivial
     additive change.
   - Also confirm the flag name `--dedupe-hooks` (proposed; alternatives:
     `--fix-hooks`, `--strip-standalone-hooks`).
2. **`enabledPlugins` data format (verification, inherited from #71 — non-blocking).**
   Detection reuses `detectMarketplacePlugin`, which assumes the
   object-of-booleans form (`{"antislop@antislop-marketplace": true}`). Official
   docs show an ARRAY form. If the real format is the array, this pass never
   fires (safe direction: settings left untouched, duplicate persists, nothing
   wrongly removed). Same verification #71's OQ1 already owns; recorded here so
   this follow-up inherits it explicitly rather than silently depending on it.
   - **Recommended default:** proceed with the object-form detection (matches the
     shipped code and the user's real "Ran 2 stop hooks" observation); verify
     against a real `~/.claude/settings.json` with the plugin enabled.

## Self-check
- CHK1: Is "a standalone antislop hook registration" given a machine-checkable
  definition? — PASS (the `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/` marker,
  Step 1; already the harness `HOOK_MARKER`).
- CHK2: Is the collision condition (plugin enabled AND standalone hooks present)
  defined with both halves and a runnable check? — PASS (Step 2 collision
  variable; detected-warn-only + dedupe integration tests).
- CHK3: Is the warn-only-by-default / removal-only-under-flag safety rule stated
  with a test that settings.json is NOT rewritten without `--dedupe-hooks`? —
  PASS (Step 2 first acceptance criterion asserts `HOOK_MARKER` still present).
- CHK4: Is the "never create zero-hooks" safety (dedupe is a no-op when the
  plugin is not enabled) defined and tested? — PASS (Step 2 third criterion).
- CHK5: Does the plan guarantee the pass runs before the version-match fast-path
  so a current project still sees the collision? — PASS (Context + Step 2
  ordering + fifth criterion).
- CHK6: Is surgical removal (antislop entries only, user hooks + non-hooks keys
  preserved, empty groups pruned) defined and tested? — PASS (Step 1 strip
  helper + its unit tests; Step 2 fourth criterion).
- CHK7: Do Context and Steps agree this is claude-only and why? — PASS (Context
  design-fork #3; `runUpdate` is claude-scoped; no cursor/codex hook path to
  extend).
- CHK8: Is the "no new marker" decision made explicit with a rationale rather
  than silently dropped? — PASS (Context design-fork #1).
- CHK9: Is the `enabledPlugins`-format dependency represented rather than
  silently assumed? — FAIL (ambiguous, at draft time) — converted to Open
  Question 2.
- CHK10: Is the safety-critical default-behavior fork surfaced for the user
  rather than silently chosen? — FAIL (ambiguous ownership of a settings-rewrite
  decision, at draft time) — converted to Open Question 1 (with recommended
  default; the finalized warn-only design is the safe branch, so non-blocking).
- CHK11: Does the plan answer the task's "bigger structural change?" question
  with a definite finding? — PASS (Context: fits as an additive pass, not a
  hash-diff-model extension; finding stated).
- CHK12: Is a CHANGELOG follow-up flagged (constitution P3 spirit)? — PASS
  (Risks + Scribe update hint).

CHK9 and CHK10 are discharged into OQ2 and OQ1, each with a recommended default
under which the finalized design is the safe branch (warn-only never rewrites;
object-form detection no-ops harmlessly if the real format is the array). No
FAIL is left unrepresented in Open Questions. Safe to publish.

## Scribe update hint
Once implemented: add a CHANGELOG entry (next patch version) — `node bin/cli.js
--update` now DETECTS the duplicate-hook collision (marketplace plugin enabled
AND stale standalone `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/*.sh`
registrations in `.claude/settings.json` from a pre-guard install) and, with the
new `--dedupe-hooks` flag, surgically removes just the standalone registrations
(leaving the plugin to provide the hooks); default is warn-only and never
rewrites settings.json, and `--dedupe-hooks` is a no-op when the plugin is not
enabled (never disables all hooks). Reference this follow-up; note it extends the
0.13.2 fresh-install guard (#66–73) to the `--update` resync path. If a
wiki/CONTEXT entry documents the standalone-vs-marketplace install split or the
`--update` machinery, add a line about the `--dedupe-hooks` pass.
