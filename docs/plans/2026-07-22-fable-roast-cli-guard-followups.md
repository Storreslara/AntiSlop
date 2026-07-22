# Fable roast-work follow-ups: harden downgrade/stamp guards + advisory-check noise

Second, smaller batch of follow-ups surfaced by adversarial fable "roast-work"
advisory passes over the already-PASSed/closed units #102 (downgrade guard) and
#106 (`claude plugin tag` advisory) from the
`docs/plans/2026-07-22-publish-readiness-audit-remediation.md` / GitHub #101
batch. None of these reopen #102 or #106 — both authoritative reviewers
confirmed those PASS verdicts stand and recommended these as separate
follow-ups.

## Goal
Close four independent roast findings, sliced for maximum parallelism:
1. Harden `compareSemver`'s dotted pre-release parsing (+1b conditional
   recovery message, +1c filesystem-state assertion).
2. Extend the same downgrade-stamping guard to the three sibling
   `--overwrite` scaffold paths that #102 never touched.
3. Suppress the permanently-noisy `claude plugin tag` advisory in this repo
   without hiding a real future regression.
4. Refresh a stale `CONTRIBUTING.md` bullet.

## Context
- `bin/cli.js`'s `compareSemver` (~lines 60-72, added `532e24e`) strips only
  single-segment pre-release suffixes; dotted suffixes leak into the numeric
  split. It is exported (`module.exports`, ~line 1689) and imported by
  `tests/cli-backfill.test.js` as `cli.compareSemver`, so it is directly
  unit-testable without spawning a process.
- The downgrade guard in `runUpdate()` (~lines 470-491) is the sole consumer;
  `pluginState = detectMarketplacePlugin(...)` is currently computed later
  (~line 540), AFTER the refusal message — 1b requires computing it before the
  refusal.
- The hooks-collision message (~lines 553-560) is the existing precedent for
  conditioning wording on `pluginState.source`/`.enabled`.
- Three `--overwrite` branches do `existingConfig.pluginVersion = version` with
  no ordering check: `scaffoldCursor` (~928-934), `scaffoldCodex`
  (~1299-1304), claude-target (~1616-1619).
- The `claude plugin tag --dry-run` advisory lives in `tests/validate.sh`
  (~lines 81-93), gated on `command -v claude`; it SKIPs when the CLI is
  absent and WARNs (never fails) otherwise.
- Tests run via `node tests/cli-backfill.test.js`; `bash tests/validate.sh` is
  the umbrella merge gate and itself runs that test file (~line 255).
- No `.claude/reviewed/*.fail` record applies — these are fresh units on
  previously-PASSed work. (Bash cannot enumerate `.claude/reviewed/` under the
  reviewed-path-gate for spec-master; per the task both #102 and #106 PASSed
  and closed, so no prior FAIL history colors this batch.)

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-22 External dependencies & integrations: Q How can Finding 3's fix
  be machine-checked when the `claude` CLI may be absent on CI (the SKIP
  branch)? → A (self-resolved): factor the allowlist filter into a unit
  testable against canned/fixture `claude plugin tag` output, so the test
  never needs the real binary; the live check stays SKIP-safe.
- 2026-07-22 Edge cases / failure handling: Q For the three `--overwrite`
  scaffold paths, should a detected downgrade refuse (mirror `runUpdate`) or
  warn-and-proceed? → A (self-resolved): warn-and-proceed. `--overwrite` is
  already an explicit destructive opt-in, so a hard refusal there would be
  surprising/regressive; the finding's actual defect is that the stamping is
  *silent*, which a warning naming both versions closes. Reuse `compareSemver`
  as the single comparison source, lighter reaction than `runUpdate`.
- 2026-07-22 Edge cases / failure handling: Q Which direction should the
  dotted-suffix regression assert? → A (self-resolved): equal (=== 0) in both
  directions — the parser deliberately ignores pre-release ranking, so
  stripping `-beta.3`/`-rc.1` yields identical numeric tuples; the only
  requirement is it must NOT report the pre-release as newer/older.
- 2026-07-22 Technical constraints & tradeoffs: Q Finding 3 — allowlist the
  known-permanent WARNs (option a) or run against a rendered/ADAPTED copy
  (option b)? → A (self-resolved): option (a). Option (b) needs the ADAPT-time
  real launch command that by design does not exist in the plugin's own source
  repo, so it cannot run unattended in CI; (a) is self-contained and directly
  testable.
- 2026-07-22 Functional scope & success criteria: Q Are Finding 1 and Finding
  2 safe to parallelize given both touch `bin/cli.js` and last batch's
  shared-working-tree cross-sweep incident? → A (self-resolved): keep them
  separate units but sequence B after A (B reuses A's hardened `compareSemver`)
  and never run them concurrently in one working tree; see Risks.

## Risks / dependencies
- **Shared-working-tree cross-sweep (the prior-batch incident).** Last batch,
  two of six concurrent units swept each other's staged files mid-commit via
  `git add -A`. That hazard is a function of concurrent `git add -A` in one
  tree, NOT of file overlap — so it applies to ANY concurrent dispatch here,
  even Findings 3/4 on disjoint files. Mitigation (task-master/orchestrator
  dispatch concern): per-unit isolated worktrees/clones, OR scoped
  `git add <explicit paths>` per the lead-programmer's recorded
  index-check-before-commit discipline. With scoped staging, A/C/D parallelize
  safely.
- **B depends on A.** Unit B reuses `compareSemver` as its comparison; it
  should land after Unit A's hardened version (and its exported signature is
  unchanged, so the dependency is semantic, not structural). B also edits
  `bin/cli.js` — do not run B concurrently with A in the same tree.
- **1b breaks an existing test.** `buildBaselineProject` writes no
  marketplace-enabled `settings.json`, so under 1b's conditional message the
  existing refusal test (~362-383) would hit the non-marketplace branch and no
  longer print `claude plugin update antislop@antislop-marketplace`. That test
  MUST be updated/split as part of Unit A (see Step A3).
- **Finding 2 semantics are the one genuinely debatable call.** Warn-vs-refuse
  is self-resolved to warn (above); flagged here so the user can veto at
  review without it being buried.
- **Finding 3 allowlist brittleness.** Matching known-permanent WARN lines by
  substring can silently stop matching if `claude plugin tag`'s wording changes
  across versions — fail-safe (noise returns; nothing real is hidden). The test
  must prove the filter does NOT over-match (a real injected mismatch still
  surfaces).

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume": satisfied — every unit carries a runnable
  acceptance check; Finding 3's implementer must capture real
  `claude plugin tag` output before allowlisting, not assume the WARN strings.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  Findings 1/2 edit `bin/cli.js` itself (the deterministic script), not any of
  its script-driven output files.
- P3 "Version-stamp discipline": satisfied — no `agents/*.md` or template file
  is edited; `bin/cli.js`, `tests/*`, `tests/validate.sh`, and
  `CONTRIBUTING.md` are not version-stamped, so no `plugin.json` bump is
  strictly required. Each unit SHOULD still add a CHANGELOG line per repo
  convention (non-gating).
- P4 "Optional personas degrade gracefully": satisfied — no shared persona
  prose is touched (Finding 4 edits contributor prose, not persona bodies).
- P5 "tests/validate.sh is the merge gate": satisfied — Finding 3 modifies
  `validate.sh` and MUST keep it exit-0 including on a runner without the
  `claude` CLI (SKIP, not fail); all units gate on `bash tests/validate.sh`.

## Unit A — harden `compareSemver` + conditional recovery + fs-state assertion (Findings 1, 1b, 1c)
Affected files: `bin/cli.js` (`compareSemver` ~60-72; `runUpdate` refusal
~470-491), `tests/cli-backfill.test.js` (new case + existing refusal case
~362-383).

- **A1 — fix the parse.** Strip the pre-release/build suffix before splitting:
  `String(v).split(/[-+]/)[0].split('.')`. Correct the overclaiming comment at
  ~60-62 to describe what it now actually does.
- **A2 — regression test (new case, calls `cli.compareSemver` directly).**
  Assert, at minimum: `compareSemver('1.2.0-beta.3','1.2.0') === 0`;
  `compareSemver('1.2.0','1.2.0-beta.3') === 0`;
  `compareSemver('1.0.0-rc.1','1.0.0') === 0`;
  `compareSemver('1.0.0','1.0.0-rc.1') === 0`; single-segment still equal
  (`compareSemver('1.2.0-beta','1.2.0') === 0`); and real ordering intact
  (`compareSemver('1.0.0','2.0.0') < 0`,
  `compareSemver('2.0.0-rc.1','1.0.0') > 0`).
- **A3 — conditional recovery message (1b).** Compute
  `detectMarketplacePlugin('claude', CWD, os.homedir())` before the refusal at
  ~475 and branch the message: `pluginState.enabled` →
  `claude plugin update antislop@antislop-marketplace --scope <local|project|user>`
  (naming `pluginState.source`); else → guidance for non-marketplace installs
  (local `--plugin-dir` clone / standalone `bin/cli.js` scaffold), mirroring the
  ~553-560 pattern. Update the existing refusal test: either add a
  marketplace-enabled `settings.json` to its temp project and keep the
  marketplace-command assertion, OR split into two cases (enabled → marketplace
  command; not-enabled → non-marketplace guidance). Both branches must be
  asserted.
- **A4 — filesystem-state assertion (1c).** Extend the existing refusal test to
  capture, before the refused `--update` run, the byte content (or sha256) of
  `.claude/persona-config.json` (specifically that `fileHashes` and
  `pluginVersion` are unchanged) plus at least one persona `.md` file, and
  assert they are byte-identical after the exit-1 refusal — proving "no file
  writes before this point" per #102's original criterion.

Acceptance criteria (machine-checkable):
- `node tests/cli-backfill.test.js` exits 0 with the new A2 assertions and the
  updated A3/A4 refusal case present and green.
- `bash tests/validate.sh` exits 0.

## Unit B — extend the downgrade guard to the three `--overwrite` scaffold paths (Finding 2)
Affected files: `bin/cli.js` (`scaffoldCursor` ~928-934, `scaffoldCodex`
~1299-1304, claude-target ~1616-1619), `tests/cli-backfill.test.js` (new
test(s)).
Depends on: Unit A (reuses hardened `compareSemver`). Do not run concurrently
with A in the same working tree.

- **B1 — warn-and-proceed guard.** In each of the three `--overwrite` branches,
  before stamping `existingConfig.pluginVersion = version`, when
  `existingConfig.pluginVersion && compareSemver(version, existingConfig.pluginVersion) < 0`,
  emit a downgrade warning naming both versions, then still stamp and proceed
  (honoring the explicit `--overwrite` intent). Reuse `compareSemver` — do not
  introduce a second comparison implementation.

Acceptance criteria (machine-checkable):
- A regression test per path (or one parametrized over the three) asserting:
  (i) with recorded `pluginVersion` strictly higher than the plugin version, the
  scaffold `--overwrite` run prints a downgrade warning naming BOTH versions and
  still completes (exit 0, `pluginVersion` refreshed to the plugin version);
  (ii) with recorded `pluginVersion` equal-or-lower, NO downgrade warning is
  emitted.
- `node tests/cli-backfill.test.js` exits 0; `bash tests/validate.sh` exits 0.

## Unit C — suppress the permanently-noisy `claude plugin tag` advisory (Finding 3)
Affected files: `tests/validate.sh` (~81-93), plus a test asset/case for the
filter (location per implementer; e.g. a new small case in
`tests/cli-backfill.test.js` or a dedicated fixture-driven shell test).
Decision: option (a) — allowlist the two known-permanent WARN findings
(`agents/explorer.md`'s ADAPT-time `<REAL_LAUNCH_COMMAND_...>` placeholder;
the CLAUDE.md-not-loaded notice) and surface a WARN only when non-allowlisted
lines remain.

- **C1 — capture then allowlist.** The implementer must first run
  `claude plugin tag --dry-run` (or otherwise obtain its real current output) to
  identify the exact known-permanent WARN lines, then filter them by stable
  substrings. Keep the block SKIP-safe when `claude` is absent (P5).
- **C2 — testable filter.** Factor the allowlist filter into a unit testable
  without a real `claude` binary — a shell function/helper fed canned fixture
  output (or a stubbed `claude` on PATH).

Acceptance criteria (machine-checkable):
- A test that feeds the known-permanent output through the filter and asserts it
  reports clean (no residual WARN).
- A test that injects a genuinely NEW marketplace/plugin.json mismatch line into
  the canned output and asserts the filter still surfaces it (not swallowed) —
  same proof style as #106.
- `bash tests/validate.sh` exits 0 both with and without `claude` on PATH (SKIP
  path unaffected).

## Unit D — refresh the stale CONTRIBUTING.md bullet (Finding 4)
Affected files: `CONTRIBUTING.md` (~30-32).

- **D1** — extend the "Making changes" bullet so it also names the
  `npm pack`/tarball-composition check and the marketplace.json/plugin.json
  consistency check added to `tests/validate.sh` in `17cf509`.

Acceptance criteria (machine-checkable):
- `grep -Eiq 'npm pack|tarball' CONTRIBUTING.md` succeeds AND
  `grep -q 'marketplace.json' CONTRIBUTING.md` succeeds AND
  `grep -q 'plugin.json' CONTRIBUTING.md` succeeds.
- `bash tests/validate.sh` exits 0.

## Open Questions
None. All four findings' decision points (Finding 2 warn-vs-refuse, Finding 3
option a-vs-b, and the Finding 1/2 parallelism call) were delegated to
spec-master and resolved above; each is recorded in Clarifications with its
reasoning, and Finding 2's semantics are additionally flagged in Risks so the
user can veto at review without a round-trip.

## Self-check
- CHK1: Is the dotted-suffix fix's expected result defined for both directions?
  — PASS (A2 asserts === 0 both ways; rationale in Clarifications).
- CHK2: Does the plan resolve that 1b's conditional message breaks the existing
  refusal test, and say how? — PASS (Risks + Step A3: update/split the test).
- CHK3: Is Finding 2's refuse-vs-warn behavior unambiguously specified? — PASS
  (warn-and-proceed, self-resolved; acceptance asserts warning + exit 0).
- CHK4: Do Units A and B agree on the single source of the version comparison?
  — PASS (both use `compareSemver`; B declares the dependency on A).
- CHK5: Is Finding 3 machine-checkable despite the `claude`-CLI-absent SKIP
  branch? — PASS (C2 factors a fixture-testable filter; acceptance covers both
  clean-suppression and real-mismatch-surfaced).
- CHK6: Does the plan keep `tests/validate.sh` green without `claude` on PATH
  (P5)? — PASS (Unit C acceptance requires exit 0 on both paths).
- CHK7: Is Finding 4's doc change verifiable by a runnable check? — PASS (three
  grep assertions).
- CHK8: Does the plan state the shared-working-tree collision constraint the
  user explicitly asked about? — PASS (Risks: applies to any concurrent unit;
  scoped-staging/worktree mitigation; B sequenced after A).

## Scribe update hint
No user-facing docs beyond Finding 4's own `CONTRIBUTING.md` edit are in scope.
Each unit SHOULD add a CHANGELOG line (P3 convention, non-gating); a
`plugin.json` version bump is NOT required (no version-stamped file touched) and
is intentionally left out to avoid serializing the parallel units on a shared
version file.

## Slicing recommendation (for task-master)
Four top-level units: A (Finding 1+1b+1c), B (Finding 2), C (Finding 3),
D (Finding 4). A, C, D are logically independent; B depends on A. Parallel set
under scoped-staging discipline: {A, C, D} concurrent, then B after A — OR run
each in an isolated worktree. Do NOT dispatch A and B concurrently in one tree.
