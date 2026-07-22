# Publish-readiness audit remediation (B1, M1–M5, m1–m3)

Date: 2026-07-22
Author: spec-master
Slug: publish-readiness-audit-remediation
Source: fable-model pre-publish production-readiness audit against HEAD `b1892fd`, antislop v0.13.12, repo Storreslara/AntiSlop.

## Goal

Make the antislop plugin repo publish-ready **in principle** (this is prep, not
an actual marketplace publish) by remediating the 9 non-informational audit
findings. The plan is deliberately sliced so the units are as independent as possible.
Load-bearing dependencies: **M5 → B1** (M5's test asserts B1's guard behavior)
and **M3's content → the convergence plan** (per the user's 2026-07-22 OQ4
decision, M3's install-scope documentation is folded into
`docs/plans/2026-07-17-git-based-install-convergence.md` Step 4 rather than
landing here — so Step 5 below is now only a thin cross-reference, not an
independently-buildable step in this plan). Two file-collision coordination
notes (Steps 7/8 share `tests/validate.sh`) are flagged as dispatch hints, not
logical dependencies.

## Context

The audit surfaced one Blocker (silent-downgrade in `--update`), five Major
findings (npm tarball gap, dev-scratch shipping in the git distribution, two
documentation gaps around install scope, and missing test coverage for the
downgrade case), and three Minor findings (release-CI hygiene). Verified this
session against live code:

- **B1**: `runUpdate()` (`bin/cli.js` L443–654) reads `version` from
  `readPluginVersion()` (L53–57, derived from `PKG_ROOT/.claude-plugin/plugin.json`)
  and the project's recorded `config.pluginVersion` from
  `.claude/persona-config.json` (L453). The only comparison is exact-equality
  same-version fast-path skip (L537). There is **no** `version <
  config.pluginVersion` guard; the per-file loop (L554–608) overwrites on any
  hash mismatch regardless of direction and L639 unconditionally stamps
  `config.pluginVersion = version`, even backward. No `--allow-downgrade` flag
  exists (grep-verified). No existing semver-compare helper in `bin/cli.js`
  (grep-verified) — versions are simple dotted-numeric (`0.13.12`, `0.7.1`).
- **M1**: `package.json` `files` array (L18–28) omits `commands/`. `npm pack
  --dry-run --json` this session: `commands present: False`, 58 files total.
  `commands/update-antislop.md` and `commands/start-feature-team.md` both exist
  on disk.
- **M2**: `.gitattributes` is only `* text=auto eol=lf` / `*.sh text eol=lf` —
  no `export-ignore`. `.claude-plugin/plugin.json` declares no component-path
  allowlist. **Technical caveat verified/reasoned:** `export-ignore` only
  affects `git archive` output, NOT a plain `git clone`. Claude Code's git
  marketplace install clones the repo, so `export-ignore` does not filter what
  a marketplace *clone* receives today — see Step 4 for how the decision
  accounts for this.
- **M3/M4**: repo-wide grep confirms no docs explain install-scope
  (`local`/`project`/`user`) precedence or stale-registration recovery; only a
  code comment (`bin/cli.js` ~L1013) and one test assertion mention scope.
- **M5**: `tests/cli-backfill.test.js` integration harness (L277+) runs the
  real `node bin/cli.js --update` out-of-process via `spawnSync`, with
  `PKG_ROOT` derived from `cli.js`'s own `__dirname` (comment L268). The
  existing `--check`/prune tests already force the render loop by writing a
  **lower** `config.pluginVersion` (`'0.0.1'`, L314). The downgrade case is the
  mirror: write a **higher** recorded version than the real plugin version, so
  no synthetic PKG_ROOT is structurally required.
- **M4**: `skills/install-antislop/SKILL.md` final-report section already has
  precedent for surfacing manual-step caveats — the teammate-model callout
  (~L383). SKILL.md is copied via `copyDirRecursive` at install/overwrite time
  (`bin/cli.js` L1504), NOT part of the stamped `buildFileSpecs`/`--update`
  resync loop and carries no version stamp (head-verified).
- **m1**: `.github/workflows/` contains only `validate.yml`; no `claude plugin
  tag` invocation anywhere (grep-verified across workflows/scripts/tests).
- **m2**: `tests/validate.sh` version-sync block (L34–42) compares only
  `package.json` vs `plugin.json`. No `npm pack --dry-run`, no marketplace/tag
  cross-check. `.claude-plugin/marketplace.json` has **no** version field (it
  references the plugin by name + `"source": "./"`), so there is no
  marketplace *version* to cross-check — only name/source consistency.
- **m3**: `.claude/settings.json` L23/L35 hardcode `--repo
  "/home/sebas/seb_claude_setup"` in the dogfood code-review-graph hook
  commands. `docs/experiments/2026-07-probe-hook-payloads.md` also references
  `/home/sebas` paths. `bin/cli.js` never copies `.claude/settings.json` into
  targets (only `templates/settings-fragment.json` is merged), so installers
  are unaffected — but a public repo shouldn't ship a personal absolute path.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-22 Functional scope & success criteria: Q Which findings are in
  scope? → A (self-resolved): the 9 non-informational findings (B1, M1–M5,
  m1–m3); informational/already-clean audit items are explicitly excluded per
  the request.
- 2026-07-22 Edge cases / failure handling: Q What exact flag/UX should the
  intentional-rollback escape hatch use for B1? → A (self-resolved):
  `--allow-downgrade` (boolean, no value). On a detected downgrade WITHOUT it:
  hard-refuse (exit 1) with an error naming both versions and pointing at
  `claude plugin update antislop@antislop-marketplace --scope <local|project|user>`.
  WITH it: print a warning and proceed. Reasonable default exists, so not left
  as an Open Question; see Step 1.
- 2026-07-22 Technical constraints & tradeoffs: Q M2 — accept full-tree git
  distribution, or filter dev-scratch? → A (self-resolved, residual
  uncertainty surfaced as Open Question 1): filter via `.gitattributes
  export-ignore` for the dev-only dirs (conventional hygiene, machine-checkable
  via `git archive`, future-proofs any archive-based packaging) AND document
  the clone caveat in-repo (export-ignore does not filter a `git clone`, so
  full-tree still reaches clone-based marketplace installs until Claude Code
  adopts archive or a plugin.json component allowlist). This makes the repo
  publish-ready *in principle* — the user's stated bar.
- 2026-07-22 Technical constraints & tradeoffs: Q Should this batch cut a
  version bump + git tag on merge? → A (self-resolved, confirm via Open
  Question 2): defer the version bump/tag to the real publish moment. None of
  the 9 units edit a constitution-P3 stamped file, so no per-unit bump is
  mandated, and a shared version/CHANGELOG/tag edit would serialize all units
  on `plugin.json`/`package.json`/`CHANGELOG`, defeating the parallelism goal.
- 2026-07-22 External dependencies & integrations: Q What is `claude plugin
  tag`'s exact semantics / is it available in CI? → A (self-resolved, confirm
  via Open Question 3): wire it advisory-only into `tests/validate.sh` with a
  `SKIP` fallback when the `claude` CLI is absent (mirroring the existing
  `tomllib` SKIP at L168–187), plus a release-checklist note — never hard-gate
  CI on a CLI that may not be installed on the runner.
- 2026-07-22 External dependencies & integrations: Q Does the M3 install-scope
  doc collide with the uncommitted `docs/plans/2026-07-17-git-based-install-convergence.md`
  plan? → A: both edit the README Install/First-time-setup region, but that
  plan's scope is "public-vs-private + verbosity," NOT scope-precedence — so
  M3 is a clearly-separated *new* subsection. Sequencing surfaced as Open
  Question 4 (recommended default: land M3 as a standalone new README
  subsection after/merged-with the convergence plan; if that plan is
  abandoned, M3 stands alone).
- 2026-07-22 (OQ answers relayed by coordinator) External dependencies &
  integrations: Q OQ4 — fold M3 in or keep standalone? → A: **fold into the
  convergence plan** (user OVERRODE the recommended standalone default). M3's
  scope-precedence documentation now lives as Step 4 of
  `docs/plans/2026-07-17-git-based-install-convergence.md`; Step 5 here becomes
  a thin cross-reference. This introduces a real cross-plan dependency (see
  Risks).
- 2026-07-22 (OQ answers relayed by coordinator) Technical constraints &
  tradeoffs: Q OQ1 — M2 accept-full-tree vs filter? → A: **filter + document
  clone caveat** (confirmed, matches the recommended default; Step 4 unchanged).
- 2026-07-22 (OQ answers relayed by coordinator) Technical constraints &
  tradeoffs: Q OQ2 — version bump/tag now vs defer? → A: **defer to real
  publish** (confirmed, matches the recommended default; no per-unit bump).
- 2026-07-22 (OQ answers relayed by coordinator) External dependencies &
  integrations: Q OQ3 — `claude plugin tag` wiring? → A: **advisory, SKIP-safe
  wiring now** (confirmed, matches the recommended default; Step 7 unchanged).

## Risks / dependencies

- **Load-bearing dependency (the only one): M5 → B1.** M5 (Step 2) is a
  regression test that asserts B1's (Step 1) guard: exit code 1, both version
  strings in the message, and the recovery command; plus `--allow-downgrade`
  proceeding. The test cannot pass until B1's guard exists. **Recommendation:**
  dispatch B1+M5 as a single TDD lead-programmer unit (write M5's failing test,
  implement the B1 guard, go green). Presented as two steps so `task-master`
  may keep them separate if it prefers, but if split, M5 must be sequenced
  after B1 merges and its assertions must match B1's fixed contract below.
- **File-collision coordination (NOT a logical dependency): Steps 7 and 8 both
  edit `tests/validate.sh`.** Either can be verified independently, but
  concurrent edits will merge-conflict. **Recommendation:** dispatch m1+m2 as a
  single "harden validate.sh" unit, or sequence them.
- **M3's content is now owned by the convergence plan (cross-plan dependency,
  resolved from OQ4).** Per the user's 2026-07-22 decision, the install-scope
  documentation is folded into
  `docs/plans/2026-07-17-git-based-install-convergence.md` **Step 4**, which in
  turn depends on that plan's Step 1 having created the "## Install" section.
  Consequences: (a) Step 5 in THIS plan is demoted to a thin cross-reference
  with no acceptance criteria of its own (all ACs live in the convergence
  plan's Step 4, to avoid duplicate/conflicting criteria); (b) M3 is **removed
  from this plan's parallel work set** — its content cannot land until the
  convergence plan is implemented (or at least drafted far enough to receive
  Step 4, which it now has); (c) the convergence plan's Step 1 conciseness
  ceiling was raised 70→85 to absorb the subsection. Do not implement M3's
  README content from this plan — it is the convergence plan's Step 4.
- **M2 filter has a known clone-effectiveness gap** (export-ignore ≠ clone
  filtering). The step accepts this consciously and documents it (OQ1 confirmed
  filter + document caveat).
- **Parallel work set is now Steps 3, 4, 6, 9** (was 3, 4, 5, 6, 9). Step 5
  (M3) dropped out because its content relocated to the convergence plan and
  now carries a cross-plan dependency. Steps 3, 4, 6, 9 touch disjoint files
  and remain fully parallel; B1/M5 (Steps 1/2) and the validate.sh pair
  (Steps 7/8) carry their own dependency/collision notes above.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume" (MUST): satisfied — every finding was re-verified
  against live code/`npm pack`/grep this session (see Context); every step's
  acceptance criteria are runnable checks, not prose.
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST): satisfied —
  no script-driven stamped file (`fileHashes`, `substitutions`, `--wire-*`
  targets, `agents/*.md`, templates) is hand-edited. B1 edits `bin/cli.js`'s
  own logic (the script itself, adding a guard), which is the intended locus,
  not a hand-edit of a script-generated artifact.
- P3 "Version-stamp discipline" (MUST): **not triggered** — none of the 9 units
  edits a version-stamped file (`agents/*.md` or templates).
  `skills/install-antislop/SKILL.md` (M4) is copied via `copyDirRecursive`, is
  not stamped, and is not part of the `--update` resync loop, so its edit does
  not require a `plugin.json` bump for `--update` correctness. A publish-time
  version bump + CHANGELOG is recommended as release hygiene but is deferred to
  the real publish (Open Question 2) to preserve unit parallelism.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — no shared
  persona-reference prose is altered; M3/M4 add install-scope docs, not persona
  references.
- P5 "tests/validate.sh is the merge gate" (MUST): satisfied — every step's
  acceptance criteria include `bash tests/validate.sh` exit 0, and Steps 7/8
  extend validate.sh itself while keeping it green.

## Steps

### Step 1 — B1: semver-ordering downgrade guard in `runUpdate()` + `--allow-downgrade`

Affected files: `bin/cli.js` (add a small `compareSemver` helper near
`readPluginVersion` L53–57; insert the guard in `runUpdate` immediately after
`const config = JSON.parse(...)` at L453, BEFORE the legacy-token migration
block at L459 so a detected downgrade refuses with zero mutations).

Behavior contract (M5 asserts this verbatim — fix it here):
- Add `compareSemver(a, b)` returning negative/0/positive by numeric dotted
  components (pad missing components with 0; ignore any non-numeric pre-release
  suffix conservatively).
- In `runUpdate`, after parsing `config`, compute `isDowngrade =
  config.pluginVersion && compareSemver(version, config.pluginVersion) < 0`.
- If `isDowngrade` and `args` does NOT include `--allow-downgrade`: print to
  stderr an error that (a) names BOTH versions (the `PKG_ROOT` `version` and
  the recorded `config.pluginVersion`), (b) states this would downgrade/refuses,
  and (c) points the user at `claude plugin update antislop@antislop-marketplace
  --scope <local|project|user>` to refresh the stale cache; then
  `process.exit(1)`. No file writes before this point.
- If `isDowngrade` and `--allow-downgrade` IS present: print a warning to
  stdout naming both versions and that an intentional downgrade is proceeding,
  then continue normally.
- Same-version and upgrade paths are unchanged.

Acceptance criteria (machine-checkable):
- AC1: `node -e "const c=require('./bin/cli.js'); process.exit(typeof c.compareSemver==='function' && c.compareSemver('0.7.1','0.13.8')<0 && c.compareSemver('0.13.8','0.7.1')>0 && c.compareSemver('0.13.12','0.13.12')===0 ? 0 : 1)"`
  exits 0. (Requires `compareSemver` be added to `module.exports` alongside the
  existing exports at the bottom of `bin/cli.js`.)
- AC2: `bash tests/validate.sh` exits 0 (includes `node tests/cli-backfill.test.js`).
- AC3: the guard string is present —
  `grep -q 'allow-downgrade' bin/cli.js && grep -q 'claude plugin update antislop@antislop-marketplace' bin/cli.js`
  exits 0.
- (Full end-to-end refusal/override behavior is asserted by Step 2's test.)

### Step 2 — M5: downgrade regression test (depends on Step 1)

Affected files: `tests/cli-backfill.test.js` (add two `check(...)` cases in the
existing integration block, reusing `buildBaselineProject`).

Test design (no synthetic PKG_ROOT needed): build a baseline project, then set
its `.claude/persona-config.json` `pluginVersion` to a value strictly HIGHER
than the real plugin version (e.g. `'99.0.0'`), and run the real `node
bin/cli.js --update` via `spawnSync` (as the existing tests do).

Acceptance criteria (machine-checkable):
- AC1: refusal case — `--update` against a `99.0.0`-recorded project exits with
  status 1, and combined stdout+stderr contains BOTH the real plugin version
  string AND `99.0.0` AND the substring `claude plugin update
  antislop@antislop-marketplace`. Asserted in-test.
- AC2: override case — `--update --allow-downgrade` against the same project
  does NOT exit 1 on the downgrade guard (it proceeds; assert `status !== 1`
  and that the downgrade-refusal message is absent / a proceed-warning naming
  both versions is present). Asserted in-test.
- AC3: `bash tests/validate.sh` exits 0 (runs the new cases via
  `node tests/cli-backfill.test.js`).

### Step 3 — M1: add `commands/` to `package.json` `files` array

Affected files: `package.json` (`files` array L18–28).

Add `"commands"` to the array so `commands/update-antislop.md` and
`commands/start-feature-team.md` ship in the npm tarball.

Acceptance criteria (machine-checkable):
- AC1: `npm pack --dry-run --json | python3 -c "import json,sys; f=[x['path'] for x in json.load(sys.stdin)[0]['files']]; import sys as s; s.exit(0 if ('commands/update-antislop.md' in f and 'commands/start-feature-team.md' in f) else 1)"`
  exits 0.
- AC2: `python3 -m json.tool package.json >/dev/null` exits 0.
- AC3: `bash tests/validate.sh` exits 0.

### Step 4 — M2: `.gitattributes export-ignore` for dev-scratch + clone caveat

Affected files: `.gitattributes` (append `export-ignore` entries); a short
in-repo note (append to `.gitattributes` as a comment AND/OR a
`CONTRIBUTING.md`/README maintainer line) recording the clone caveat.

Add `export-ignore` for the dev-only paths: `docs/plans/`, `docs/experiments/`,
`eval/`, `prototype/`, `specs/`, `.claude/agent-memory/` (only paths that exist
in the tree — verify with `git ls-files` before adding). Record, as a comment
in `.gitattributes`, that `export-ignore` filters `git archive` output only,
not `git clone`, so the git-marketplace clone still ships the full tree until
Claude Code adopts an archive-based fetch or a `plugin.json` component
allowlist (Open Question 1).

Acceptance criteria (machine-checkable):
- AC1: each dev-only path that exists resolves `export-ignore` as set —
  e.g. `git check-attr export-ignore docs/plans/ | grep -q 'export-ignore: set'`
  (repeat per path; all exit 0).
- AC2: a `git archive` of HEAD excludes the dev-scratch dirs —
  `git archive --format=tar HEAD | tar -t | grep -qE '^(docs/plans|docs/experiments|eval|prototype|specs|\.claude/agent-memory)/' && exit 1 || exit 0`
  (i.e. the grep finds nothing → exit 0).
- AC3: the clone caveat is recorded —
  `grep -qi 'git archive' .gitattributes` exits 0.
- AC4: `bash tests/validate.sh` exits 0.

### Step 5 — M3: README install-scope precedence + stale-registration recovery doc — FOLDED OUT

**Relocated (2026-07-22, OQ4 decision).** M3's install-scope documentation is
NOT implemented from this plan. It is owned by
`docs/plans/2026-07-17-git-based-install-convergence.md` **Step 4 —
"Document install-scope precedence and stale-registration recovery"**, which
carries the machine-checkable acceptance criteria for this requirement. This
step exists only as a tracking cross-reference so the audit's M3 finding maps
to a concrete owner; it has NO acceptance criteria of its own here (to avoid
duplicate/conflicting criteria across the two plans).

Dependency: the convergence plan's Step 4 depends on that plan's Step 1
(README "## Install" restructure). M3 therefore cannot land until the
convergence plan is implemented — it is excluded from this plan's parallel work
set. `task-master` should slice M3 from the convergence plan's Step 4, not from
this step.

Done-signal for tracking purposes only (verifies the OTHER plan's step landed,
no new criteria): `grep -qiE '^### Install scope' README.md && grep -q 'claude plugin update antislop@antislop-marketplace' README.md`
exits 0.

### Step 6 — M4: install-time scope-choice caveat in the install-antislop final report

Affected files: `skills/install-antislop/SKILL.md` (final-report section, near
the teammate-model manual-step callout ~L383).

Add a final-report line that warns the user which install scope they are in and
that a stale scope registration can freeze the project at an old version,
pointing at the README scope doc (Step 5) and the `claude plugin update ...
--scope` recovery command. Phrase it as a surfaced manual-step caveat, matching
the existing teammate-model precedent.

Acceptance criteria (machine-checkable):
- AC1: `grep -qiE 'scope' skills/install-antislop/SKILL.md` exits 0 AND the
  recovery pointer is present —
  `grep -q 'claude plugin update antislop@antislop-marketplace' skills/install-antislop/SKILL.md`
  exits 0.
- AC2: skill frontmatter still valid (validate.sh skill-frontmatter loop) —
  `bash tests/validate.sh` exits 0.

### Step 7 — m1: wire `claude plugin tag` advisory into `tests/validate.sh` + release-checklist note

Affected files: `tests/validate.sh` (new advisory block); a short
release-checklist note (append to `CONTRIBUTING.md` if present, else a
`## Release checklist` block in README or a new `docs/RELEASING.md`).

Add a block that runs `claude plugin tag` (cross-validating `plugin.json`
against its marketplace entry) IF the `claude` CLI is on `PATH`, else prints
`SKIP` — mirroring the existing `tomllib` SKIP pattern (validate.sh L168–187).
The block must never set `fail=1` when `claude` is absent. Document in the
release checklist that `claude plugin tag` should be run manually at release.

Acceptance criteria (machine-checkable):
- AC1: `grep -q 'plugin tag' tests/validate.sh` exits 0.
- AC2: `bash tests/validate.sh` exits 0 on a machine WITHOUT `claude` on PATH
  (the block SKIPs, does not fail).
- AC3: a release checklist references the tag step —
  `grep -rqi 'plugin tag' CONTRIBUTING.md docs/RELEASING.md README.md 2>/dev/null`
  exits 0 (whichever file the note lands in).

### Step 8 — m2: extend `tests/validate.sh` version-sync with npm-pack + marketplace consistency

Affected files: `tests/validate.sh` (extend/adjacent to the version-sync block
L34–42). **Shares this file with Step 7 — dispatch together or sequence.**

Add: (a) an `npm pack --dry-run --json` check asserting the tarball EXCLUDES
dev-scratch dirs (`docs/`, `eval/`, `prototype/`, `specs/`, `.claude/`) and
INCLUDES the stable shipped dirs (`agents/`, `hooks/`, `templates/`,
`skills/`); (b) a `marketplace.json`↔`plugin.json` consistency check (the
marketplace plugin entry's `name` equals `plugin.json`'s `name`, and `source`
is `"./"`). NOTE: deliberately does NOT assert `commands/` inclusion — that is
Step 3 (M1)'s own acceptance criterion, kept there so Step 8 stays verifiable
independently of Step 3. NOTE: no hard git-tag-vs-version gate (tagging is a
release action; per-commit enforcement would break normal dev flow — deferred
to Open Question 2 / the real publish); an optional non-failing advisory echo
is acceptable.

Acceptance criteria (machine-checkable):
- AC1: `grep -q 'npm pack' tests/validate.sh && grep -q 'marketplace.json' tests/validate.sh`
  exits 0.
- AC2: `bash tests/validate.sh` exits 0 (the new checks pass on the current
  tree — dev-scratch already excluded by the `files` array, marketplace name
  already consistent).
- AC3: the new pack-exclusion check actually catches a regression — verified by
  a scratch assertion during development (documented in the commit), not a
  permanent test artifact.

### Step 9 — m3: genericize the hardcoded `/home/sebas` path

Affected files: `.claude/settings.json` (L23, L35 hook commands);
`docs/experiments/2026-07-probe-hook-payloads.md`.

Replace `--repo "/home/sebas/seb_claude_setup"` with a portable form that
preserves the dogfood behavior — `--repo "$(git rev-parse --show-toplevel)"`
(the command already guards on `git rev-parse --git-dir`) or
`${CLAUDE_PROJECT_DIR}`. Genericize the `/home/sebas` references in the
experiments doc (or note it is export-ignored by Step 4 and replace the literal
paths with a placeholder for public-repo hygiene).

Acceptance criteria (machine-checkable):
- AC1: `! grep -rq '/home/sebas' .claude/settings.json docs/experiments/`
  exits 0 (no personal absolute path remains).
- AC2: `python3 -m json.tool .claude/settings.json >/dev/null` exits 0 (still
  valid JSON).
- AC3: the hook command still targets the repo portably —
  `grep -qE 'git rev-parse --show-toplevel|\$\{CLAUDE_PROJECT_DIR\}' .claude/settings.json`
  exits 0.
- AC4: `bash tests/validate.sh` exits 0.

## Open Questions

**All four RESOLVED by the user on 2026-07-22 (relayed by the coordinator).**
OQ1–3 confirmed the recommended defaults; OQ4 overrode its default. Retained
here for provenance.

1. **M2 accept-vs-filter + clone gap.** RESOLVED → **filter + document caveat**
   (recommended default confirmed). Add `export-ignore` hygiene (Step 4) AND
   document the clone caveat, accepting that clone-based marketplace installs
   still receive the full tree for now. Step 4 unchanged.
2. **Version bump + git tag timing.** RESOLVED → **defer to real publish**
   (recommended default confirmed). No `plugin.json`/`package.json` version
   bump, CHANGELOG entry, or git tag in this batch; units stay parallel.
3. **`claude plugin tag` semantics/availability.** RESOLVED → **advisory,
   SKIP-safe wiring now** (recommended default confirmed). Step 7 stands.
   Command name/flags still unverified against an installed `claude` CLI — the
   SKIP-safe wiring is intentionally robust to that.
4. **M3 coordination with the git-based-install-convergence plan.** RESOLVED →
   **fold into the convergence plan** (recommended standalone default
   OVERRIDDEN by the user). M3's scope-precedence documentation is now
   `docs/plans/2026-07-17-git-based-install-convergence.md` **Step 4**; Step 5
   here is a thin cross-reference. See Risks for the resulting cross-plan
   dependency and the revised parallel work set (Steps 3, 4, 6, 9).

## Self-check

- CHK1: Is the `--allow-downgrade` escape-hatch shape (flag name, exit code,
  message contents) fully defined? — PASS (Step 1 behavior contract:
  `--allow-downgrade`, exit 1 on refusal, both versions + recovery command in
  message).
- CHK2: Do Step 1 (B1) and Step 2 (M5) agree on the exact assertion surface
  (exit code, message substrings)? — PASS (Step 1's contract and Step 2's AC1/
  AC2 reference the same exit-1, both-versions, and `claude plugin update
  antislop@antislop-marketplace` substrings).
- CHK3: Is every step's acceptance criterion machine-runnable (no prose-only)?
  — PASS (each AC is a grep/exit-code/`npm pack`/`git`/`node` command).
- CHK4: Does the plan's M2 decision resolve whether the clone-based marketplace
  distribution is acceptable, or does that require a user policy call the plan
  text cannot supply? — FAIL (ambiguous) — a machine-checkable filter default
  is built in Step 4 (revised in place), but the accept-full-tree-vs-filter
  policy and the clone-effectiveness gap need a user call — converted to Open
  Question 1.
- CHK5: Does the plan's text determine whether this batch cuts a version bump/
  tag now vs at publish? — FAIL (missing user intent) — P3 is shown not
  triggered so no bump is *mandated*, but the cut-now-vs-defer choice is a user
  preference not derivable from the plan — converted to Open Question 2.
- CHK6: Is the one load-bearing dependency (M5→B1) stated, and are non-load-
  bearing collisions (Steps 7/8 on validate.sh; Step 5 on the convergence
  plan) distinguished from it? — PASS (Risks/dependencies section).
- CHK7: Does Step 8's scope avoid a hidden dependency on Step 3 (M1)? — PASS
  (Step 8 explicitly excludes the `commands/` assertion, leaving it as Step
  3's AC, so Step 8 verifies independently).
- CHK8: Is `claude plugin tag`'s exact command/flag contract confirmed by the
  plan? — FAIL (missing) — the plan defines an advisory SKIP-safe wiring (Step
  7, revised in place) but the CLI's exact semantics/availability were not
  verifiable this session — converted to Open Question 3.
- CHK9: Is m3's fix verifiable without breaking the dogfood hook or JSON
  validity? — PASS (Step 9 AC1–AC4: no `/home/sebas`, valid JSON, portable
  `--repo`, validate.sh green).
- CHK10: Does the plan's text settle how M3 (Step 5) sequences against the
  convergence plan editing the same README region? — FAIL (ambiguous) at
  drafting — converted to Open Question 4, now RESOLVED (2026-07-22): user
  chose fold-in, so M3's content moved to the convergence plan's Step 4, Step 5
  here is a thin cross-reference, and the cross-plan dependency + revised
  parallel set (Steps 3, 4, 6, 9) are recorded in Risks. No duplicate
  acceptance criteria remain across the two plans (verified: Step 5 carries a
  tracking done-signal only).

## Scribe update hint

No architectural change. This batch is release/publish hygiene: a new
`--update` downgrade guard + flag (`bin/cli.js`), an npm-tarball fix, a
`.gitattributes` export-ignore policy (with a documented `git archive`-vs-clone
caveat), two install-scope documentation additions (README + install-antislop
final report), two `tests/validate.sh` hardening checks, and removal of a
personal absolute path. If a wiki/CONTEXT page enumerates `--update` flags or
the validate.sh gate contents, add `--allow-downgrade` and the new pack/
marketplace/tag checks. If a page describes install scope, cross-link the new
README scope subsection.
