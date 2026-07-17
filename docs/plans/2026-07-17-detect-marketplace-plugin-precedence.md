# Make `detectMarketplacePlugin` settings-precedence-aware (fix silent zero-hooks on a project-level opt-out)

Status: FINALIZED (2026-07-17). Self-check passes; published to the issue
tracker via the `to-spec` process as GitHub issue #71 with the
`ready-for-agent` label. This is the canonical artifact; the tracker issue is
the additive publish. Follow-up to the now-shipped #66–70 coexistence guard
(`docs/plans/2026-07-17-cli-plugin-coexistence-guard.md`, released in CHANGELOG
0.13.2). Narrow fix to one function; not a replan. One Open Question (settings
data-format) is recorded for user verification but is non-blocking — the fix
degrades safely under either answer (see OQ1). Next: `task-master` slices this
into dispatch-ready units.

## Goal
Change `detectMarketplacePlugin(target, cwd, homeDir)` in `bin/cli.js` so its
`claude`-branch scan resolves `enabledPlugins["antislop@antislop-marketplace"]`
the way Claude Code itself resolves settings — by **precedence**, not by a
"any file says `true` wins" OR. Concretely: an explicit `false` at a
higher-precedence scope must override a `true` at a lower one. This fixes the
reported gap where a user who has the plugin enabled globally
(`~/.claude/settings.json`: `true`) but explicitly opts out for one project
(`<project>/.claude/settings.json`: `false`) currently gets
`enabled: true` → the installer skips hook registration → that project ends up
with **zero** hook registrations (a silent failure, strictly worse than the
duplicate-hooks bug the whole #66–70 plan fixed).

The function signature, return shape (`{enabled, source, reason}`), export, and
all three call sites are unchanged. Only the internal scan logic changes. The
`cursor`/`codex` branch (documented always-false no-op) is untouched.

## Context
`detectMarketplacePlugin` (bin/cli.js:945–979) currently scans three files and
returns `enabled:true` on the FIRST file where the key is strictly `=== true`:

```
candidates = [ <cwd>/.claude/settings.json,
               <cwd>/.claude/settings.local.json,
               <homeDir>/.claude/settings.json ]   // scan order today
for file of candidates: if key === true -> return enabled:true
return enabled:false
```

Two defects for the "home=true, project=false" scenario:
1. **No precedence.** It never inspects an explicit `false`; a `false` reads
   the same as an absent key ("not true → keep scanning"). So a lower-scope
   `true` is found and wins even though a higher-scope `false` should override.
2. **Scan order is not precedence order.** The array lists project
   `settings.json` before `settings.local.json`, but Claude Code ranks
   `settings.local.json` (Local) *above* `settings.json` (Project). Under an
   OR this was harmless; under a first-explicit-value-wins walk it is not.

### What Claude Code actually does (researched, not assumed)
Source: official docs, https://code.claude.com/docs/en/settings.md ("How
Scopes Interact"). Documented and certain:
- **Precedence order, highest→lowest:** Managed → Command-line → **Local
  (`.claude/settings.local.json`) → Project (`.claude/settings.json`) → User
  (`~/.claude/settings.json`)**. Higher-priority scopes override lower.
- **Object-valued settings deep-merge across scopes**, with higher precedence
  winning on a conflicting leaf. `enabledPlugins` is NOT listed as a special
  case (only permission rules are special — they union instead of override).
- Therefore, treating `enabledPlugins` as the object-of-booleans the shipped
  code assumes: a project-scope `false` leaf deep-merges over a user-scope
  `true` leaf → the effective value is **`false` → plugin disabled for that
  project**. This is a direct consequence of two documented rules, so the fix
  is grounded, not an invented precedence model.

A precedence WALK over the three files (highest scope first; the first file
that sets the key to an explicit `true` **or** `false` wins; absent falls
through) computes exactly the documented single-key deep-merge result.

### The format caveat (→ OQ1)
The same docs show `enabledPlugins` as an **array** of `{marketplace, plugin}`
entries / plugin-id strings, e.g.
`"enabledPlugins": [{"marketplace":"...","plugin":"github"}]` — NOT the
object-of-booleans (`{"antislop@antislop-marketplace": true}`) shape the
shipped `detectMarketplacePlugin`, its tests, and the user's real-world "Ran 2
stop hooks" observation all use. The docs do not show the boolean-object form
at all. This is unresolved from documentation alone and is recorded as OQ1. It
does not block this fix: if the real format is the array form, the
object-shaped key lookup simply never matches at any scope → `enabled:false` →
the installer registers standalone hooks. That is the *safe* failure direction
(a visible duplicate-hooks warning if the plugin is truly active, never the
silent zero-hooks failure this plan closes).

### Blast radius
- One function body changes (`bin/cli.js:953–979`, the `claude` branch scan).
- Signature `detectMarketplacePlugin(target, cwd, homeDir)`, return shape,
  `module.exports` entry (bin/cli.js:1546), and all three call sites
  (bin/cli.js:1412 claude, :811 cursor, :1131 codex) are unchanged — the
  call sites consume `{enabled, source}` exactly as before.
- Tests live in `tests/cli-backfill.test.js` (run by `bash tests/validate.sh`,
  the merge gate). All existing `detectMarketplacePlugin` unit tests remain
  green under the new logic (verified below).

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-17 Functional scope & success criteria: Q What is the exact defect
  and the success signal? → A (self-resolved): "home=true, project=false"
  currently returns enabled:true (skip hooks → zero hooks); success = a new
  unit test asserting enabled:false for that case passes, existing tests stay
  green.
- 2026-07-17 Domain entities / data model: Q Should the detector model a
  three-way per-file state (true / false / absent) instead of a two-way
  (true / not-true)? → A (self-resolved): yes — an explicit `false` must be
  distinguished from an absent key so it can act as a higher-scope override;
  absent falls through, explicit true/false stops the walk.
- 2026-07-17 External dependencies & integrations: Q What is Claude Code's
  real precedence for `enabledPlugins` across the three files? → A: documented
  at code.claude.com/docs/en/settings.md — Local > Project > User, objects
  deep-merge with higher scope winning per-key, `enabledPlugins` not special;
  so project `false` overrides user `true`. (The object-vs-array data-format
  ambiguity in the same docs is unresolved → OQ1.)
- 2026-07-17 Edge cases / failure handling: Q How do absent/malformed files and
  the Managed/CLI scopes behave? → A (self-resolved): absent/unreadable/
  malformed = "key not set here" → fall through (unchanged best-effort
  behavior); Managed/CLI scopes are not file-scannable and are out of scope,
  noted as a bounded limitation in Risks (safe direction: under-detection →
  register hooks).
- 2026-07-17 User interaction flow: Q Does this change any CLI surface or
  console output? → A (self-resolved): no new flag or surface; the guard
  simply fires correctly. An optional, non-required note when an explicit
  higher-scope `false` is seen is left to implementer discretion.
- 2026-07-17 Technical constraints & tradeoffs: Q May the signature/return
  shape/call sites change? → A (self-resolved): no — internal scan logic only,
  to keep blast radius to one function and preserve the three call sites.

## Risks / dependencies
- **Behavioral change to the installer's detection helper.** The new logic can
  flip a previously-`true` result to `false` (exactly the intended fix). The
  only direction that flips is "a higher-scope explicit `false` was being
  ignored" — which is the bug. No scenario that should stay `true` flips
  (proved by keeping all existing unit tests green).
- **OQ1 (data format).** If real Claude Code uses the array form, this fix is a
  harmless no-op and the reported scenario is not expressible — but that would
  also mean the entire #66–70 guard does not match real settings, a larger
  pre-existing concern this narrow follow-up does not fix. Flagged for user
  verification; not resolved here.
- **Managed / command-line scopes are not scanned.** A plugin
  enabled/disabled via a managed policy file or a `--setting` CLI arg is
  invisible to this file-only detector, same as the shipped code. Erring here
  means under-detection → the installer registers standalone hooks → a visible
  duplicate-hooks warning at worst, never the silent zero-hooks failure. Out
  of scope; documented, not fixed.
- **Prior `.fail` history on `bin/cli.js`.** `.claude/reviewed/` shows this
  file's logic has failed-then-passed repeatedly (`1.4`, `1.10`, `3.1b`,
  `3.3`, `reviewer-gate-model-step-1`). This change is small and regex-free
  (JSON reads + a boolean walk), but the history means task-master must NOT
  tag these units `haiku` and the precedence walk warrants direct unit tests.
- **Constitution P5:** tests must live in `tests/cli-backfill.test.js` so
  `tests/validate.sh` actually gates them.

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume": satisfied — the precedence model is taken from
  official docs (cited), not assumed; acceptance is runnable tests that assert
  on the resolved `{enabled, source}`, not inspection. The one unverifiable
  item (data format) is surfaced as OQ1 rather than assumed.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — pure
  installer logic, no LLM path.
- P3 "Version-stamp discipline": deviation — `bin/cli.js` is not a
  version-stamped persona/template file, so no `plugin.json` bump is required
  for the code change itself. A CHANGELOG entry for the corrected user-facing
  behavior IS warranted (flagged for task-master/scribe), not a blocker.
- P4 "Optional personas degrade gracefully": satisfied — no persona prose.
- P5 "tests/validate.sh is the merge gate": satisfied — tests added to
  `tests/cli-backfill.test.js`, already run by `validate.sh`.

## Step 1 — Make the `claude`-branch scan precedence-aware
Affected files: `bin/cli.js` (body of `detectMarketplacePlugin`, lines
953–979 — the `claude` branch only; the `target !== 'claude'` no-op branch,
the signature, the return shape, and `module.exports` are unchanged).

Replace the "first `=== true` wins" scan with a precedence walk over the three
files in **highest-scope-first** order, reading a three-way value per file.
Pseudo-code (intent, not final source):

```
// Claude Code precedence, HIGHEST scope first (settings.md "How Scopes
// Interact"): Local > Project > User. enabledPlugins deep-merges per-key with
// higher scope winning, so the first file that sets the key to an explicit
// true OR false decides; an absent key falls through to the next-lower scope.
const candidates = [
  path.join(cwd, '.claude', 'settings.local.json'),   // Local  (highest)
  path.join(cwd, '.claude', 'settings.json'),          // Project
  path.join(homeDir, '.claude', 'settings.json'),      // User   (lowest)
];
for (const file of candidates) {
  let val;                                             // true | false | undefined
  try {
    if (!fs.existsSync(file)) continue;
    const json = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (json && json.enabledPlugins &&
        Object.prototype.hasOwnProperty.call(json.enabledPlugins, MARKETPLACE_PLUGIN_KEY)) {
      val = json.enabledPlugins[MARKETPLACE_PLUGIN_KEY];
    }
  } catch (_) { /* malformed/unreadable -> key not set here -> fall through */ continue; }
  if (val === true)  return { enabled: true,  source: file, reason: null };
  if (val === false) return { enabled: false, source: null,
      reason: `explicitly disabled at ${file} (higher-precedence scope)` };
  // any other value (incl. absent/undefined) -> fall through to lower scope
}
return { enabled: false, source: null, reason: null };
```

Notes for the implementer:
- Keep `source` non-null **only** when `enabled:true` (preserves the existing
  contract that the claude console NOTE relies on; the explicit-false file is
  reported via `reason`, not `source`).
- Treat a non-boolean value (e.g. `"true"`, `1`) as "not an explicit
  true/false" → fall through. Only strict `true`/`false` stop the walk. (This
  keeps the strict-`=== true` intent from the original spec and avoids
  coercion surprises.)
- No console/CLI change is required. An optional one-line note when a
  higher-scope explicit `false` overrode a lower `true` is allowed but not
  required and not part of acceptance.

Acceptance criteria (unit tests in `tests/cli-backfill.test.js`; run via
`node tests/cli-backfill.test.js` and `bash tests/validate.sh`, expect exit 0):
- **Reported-bug regression (the defining test):** with
  `<home>/.claude/settings.json` = `{enabledPlugins:{'antislop@antislop-marketplace':true}}`
  AND `<cwd>/.claude/settings.json` =
  `{enabledPlugins:{'antislop@antislop-marketplace':false}}`,
  `detectMarketplacePlugin('claude', cwd, home)` returns `enabled:false`.
- **Local overrides Project:** `settings.local.json` = `false` and
  `settings.json` = `true` (nothing in home) → returns `enabled:false`.
- **Higher explicit `true` still wins over a lower `false`:** `<cwd>` project
  `settings.json` = `true` and `<home>` settings.json = `false` → returns
  `enabled:true` with `source` = the project `settings.json` path.
- **Absent falls through to a lower `true`:** local + project absent, home =
  `true` → returns `enabled:true` (this is the existing home-detection test;
  it must stay green).
- **All existing `detectMarketplacePlugin` unit tests stay green** under the
  new logic: true-in-each-of-the-three-files, `false`-only → false,
  key-absent → false, `enabledPlugins`-absent → false, malformed JSON → false
  without throwing, and `cursor`/`codex` → false even with the key `true`
  everywhere.

## Step 2 — End-to-end proof: guard does NOT fire on a project-level opt-out
Affected files: `tests/cli-backfill.test.js` (a new integration case in the
existing `spawnSync` block, mirroring the issue-#68 guard tests).

Prove the fix at the installer level, not just the helper level: pre-seed the
project `.claude/settings.json` with the plugin key `false` while the plugin
is `true` in the tmp HOME, run the real scaffold, and assert the standalone
hook registrations ARE written (the guard correctly did not fire).

Acceptance criteria (integration, `spawnSync('node', [cliPath, '--yes'])` in a
tmp cwd + tmp HOME, per the existing issue-#68 test harness):
- With `<home>/.claude/settings.json` = `{enabledPlugins:{'antislop@antislop-marketplace':true}}`
  AND a pre-seeded `<cwd>/.claude/settings.json` =
  `{enabledPlugins:{'antislop@antislop-marketplace':false}}`,
  `node bin/cli.js --yes` exits 0 and the written `<cwd>/.claude/settings.json`
  `hooks` object CONTAINS the `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts`
  registration (`HOOK_MARKER`). (Under the old logic this scenario suppressed
  the hooks — the silent zero-hooks bug — so this case fails before Step 1 and
  passes after.)
- The pre-seeded `enabledPlugins:{...:false}` key is preserved in the written
  file (the installer merges, does not clobber it).

## Open Questions
1. **Data format of `enabledPlugins` (verification, non-blocking).** Official
   docs (code.claude.com/docs/en/settings.md) show `enabledPlugins` as an
   ARRAY of `{marketplace, plugin}` entries, but the shipped
   `detectMarketplacePlugin`, its tests, and the user's real-world "Ran 2 stop
   hooks" observation all use the object-of-booleans form
   (`{"antislop@antislop-marketplace": true}`). Which form does the user's
   real Claude Code actually write?
   - **Recommended default (proceed):** implement the object-form precedence
     fix above — it matches the shipped code and the user's observations, is
     grounded in the documented precedence + deep-merge rules, and degrades
     safely if the real form is the array (key lookup never matches →
     `enabled:false` → hooks registered → visible-not-silent).
   - **If the user confirms the array form:** this follow-up is a safe no-op
     and a SEPARATE, larger issue should be filed — the entire #66–70 guard
     may not match real settings. That rework is explicitly out of scope here.
   - **How to verify:** inspect a real `~/.claude/settings.json` with the
     plugin enabled, or run `/config`/`/doctor` in a live Claude Code session.

## Self-check
- CHK1: Is "the plugin is enabled for this project" given a machine-checkable,
  precedence-aware definition? — PASS (Step 1 precedence walk; first explicit
  true/false wins, absent falls through).
- CHK2: Does the plan resolve the reported "home=true, project=false" case with
  a runnable acceptance criterion? — PASS (Step 1 defining unit test + Step 2
  integration test).
- CHK3: Do Context and Step 1 agree on the precedence ORDER (Local > Project >
  User) and on scan order? — PASS (both state highest-scope-first: local,
  project, home; the fix explicitly reorders from the shipped code's order).
- CHK4: Is the three-way per-file model (true/false/absent) defined, and is
  explicit-`false`-override distinguished from absent? — PASS (Step 1
  `hasOwnProperty` + strict true/false checks; absent/non-boolean falls
  through).
- CHK5: Are all existing `detectMarketplacePlugin` tests shown to remain green
  under the new logic? — PASS (Step 1 final criterion enumerates them; Context
  walks each case).
- CHK6: Is the signature/return-shape/call-site invariance stated so the change
  stays scoped to one function? — PASS (Goal + Blast radius + Step 1 header).
- CHK7: Is absent/malformed-file and the un-scannable Managed/CLI scope
  behavior defined? — PASS (Clarifications + Risks; fall-through / bounded
  limitation with the safe-direction rationale).
- CHK8: Is the precedence model grounded in a citable source rather than
  assumed? — PASS (Context cites settings.md for order + deep-merge; the one
  unverifiable item, data format, is CHK9).
- CHK9: Is the residual data-format uncertainty represented as an Open
  Question rather than silently assumed? — FAIL (ambiguous, at draft time) —
  converted to Open Question 1.
- CHK10: Is a CHANGELOG follow-up flagged so the corrected behavior is
  documented (per constitution P3's spirit)? — PASS (Constitution check +
  Scribe update hint).

CHK9's residual is discharged into OQ1 with a recommended default; the fix is
safe under either resolution, so OQ1 is a verification item, not a blocker.
No FAIL is left unrepresented. Safe to publish.

## Scribe update hint
Once implemented: add a CHANGELOG "Fixed" entry (next patch version) — the
standalone installer's `detectMarketplacePlugin` now resolves
`enabledPlugins["antislop@antislop-marketplace"]` by Claude Code's documented
settings precedence (Local `.claude/settings.local.json` > Project
`.claude/settings.json` > User `~/.claude/settings.json`) instead of "any
file says true wins", so an explicit project-level opt-out (`false`) correctly
overrides a global (`~/.claude/settings.json`) `true` — fixing a case where a
project could be left with ZERO hook registrations. Reference this follow-up
issue; note it refines the 0.13.2 guard (#66–70).
