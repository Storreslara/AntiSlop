# Microworld silo — namespaced code/test directories plus a canonical index

**Status:** COMPLETE — all six units (gh327-gh332) reviewer-PASSed as of 2026-09-04. Two follow-up items tracked elsewhere: three pre-existing stale CONTEXT.md path citations (separate from #426/#427) and a spec-level criterion defect in issue #332 (multi-file grep with filename-prefix colon stripping).
**Author:** spec-master, 2026-08-11
**Plan slug (for the tracker label):** `plan/2026-08-11-microworld-silo`

---

## Goal

Give the microworld feature area a single, self-evident home. Today its
implementation is scattered across four unrelated-looking naming families
(`bin/dashboard/`, `tests/dashboard-*.test.js`, `tests/microworld-*.test.*`,
`hooks/scripts/microworld-rerun.sh`) with no artifact that ties them
together, so a reader who greps `microworld` misses `bin/dashboard/` entirely
and a reader who greps `dashboard` misses the reporter hook and its contract
test.

After this plan:

1. All microworld dashboard code lives under `bin/microworld-dashboard/`.
2. All microworld tests live under `tests/microworld/`.
3. The reporter hook stays at `hooks/scripts/microworld-rerun.sh` (siblings
   of every other hook — hooks are located by `hooks.json`, not by feature).
4. Docs and ADRs stay where they are (`docs/adr/`, `docs/plans/`, `CONTEXT.md`,
   `.claude/wiki/`).
5. A new `docs/microworld/README.md` is the canonical index that names every
   one of those locations, so the silo is discoverable from one file.

Nothing about the feature's **behaviour** changes. No route, no flag, no
manifest field, no audit-log line format, no packaging surface.

## Context

> **Baseline refreshed 2026-09-04.** Step 1 shipped (issue #327, closed), and a
> sibling plan (`docs/plans/2026-08-13-dashboard-decision-approval-surface.md`,
> issues #349-354) landed new files into the same two directories. Every count,
> path list and line number below was re-measured against the tree at
> 2026-09-04. The plan's Goal, scope, step ordering and dependency graph are
> unchanged. Three of the refreshed facts are not mere counts but **premise
> reversals** that made Steps 2 and 3 unshippable as previously written — they
> are marked **[REVERSAL]** and are re-stated in Risks as R7, R8 and R9.

**Code — `bin/microworld-dashboard/` (10 files, was 7 under the old name):**
`audit-log.js`, `decision-block.js`, `decisions.js`, `discover.js`,
`feedback-block.js`, `index.html`, `invoke.js`, `markdown-lite.js`,
`server.js`, `source.js`. The three additions (`decision-block.js`,
`decisions.js`, `markdown-lite.js`) came from the sibling decision-surface
plan after this plan was authored. `bin/dashboard/` no longer exists
(`test ! -d bin/dashboard` passes).

**Tests to move — 14 files, two naming families** (`ls tests/ |
grep -cE "^(dashboard-|microworld-)"` = **14**, was 8):
`tests/dashboard-capability-register.test.js`,
`tests/dashboard-client.test.js`, `tests/dashboard-decision-block.test.js`,
`tests/dashboard-decision-run.test.js`,
`tests/dashboard-decisions-client.test.js`,
`tests/dashboard-decisions.test.js`, `tests/dashboard-feedback.test.js`,
`tests/dashboard-invoke.test.js`, `tests/dashboard-markdown-lite.test.js`,
`tests/dashboard-notebook.test.js`, `tests/dashboard-packets.test.js`,
`tests/dashboard-server.test.js`,
`tests/microworld-audit-contract.test.js`, `tests/microworld-rerun.test.sh`.
Thirteen are Node tests; `microworld-rerun.test.sh` is the one bash test.

**Deliberately still out of scope (unchanged from authoring):** three
microworld-adjacent tests do **not** match the `^(dashboard-|microworld-)`
family and therefore do not move — `tests/session-start-microworld-status.test.sh`,
`tests/stop-gate-microworld-skip.test.sh`,
`tests/stop-gate-deferred-microworld.test.sh`. They exercise the
session-start and stop-gate hooks, not the dashboard. See OQ6.

**Referrers to `bin/dashboard/` in live code — now 2 grep hits, not 14.**
Step 1 repointed every other one. Both survivors are the *same two header
lines*, in a source file and its tracked mirror:

| Referrer | Nature |
|---|---|
| `hooks/scripts/microworld-rerun.sh:11-12` | **consumed-interface** header naming `bin/dashboard/audit-log.js` and `tests/microworld-audit-contract.test.js` (was `:10-11`) |
| `.claude/hooks/scripts/microworld-rerun.sh:11-12` | **[REVERSAL]** byte-identical tracked mirror carrying the same two lines — see R7 |

**Referrers to the *test* paths in live, non-historical files (new since
authoring — none of these were in the plan):**

| Referrer | Nature |
|---|---|
| `tests/watch-map.json:17-18` | **[REVERSAL]** the `gh351` entry names `tests/dashboard-decision-block.test.js` in both `watch[]` and `run[]` — live config, gated by `tests/watch-map-registration.test.sh`; see R8 |
| `bin/microworld-dashboard/index.html:117,125,132` | header comments naming `tests/dashboard-feedback.test.js`, `tests/dashboard-decision-block.test.js`, `tests/dashboard-markdown-lite.test.js` — see OQ7 |
| `bin/microworld-dashboard/decision-block.js:92` | comment naming `tests/dashboard-decision-block.test.js` — see OQ7 |
| `tests/dashboard-notebook.test.js:41`, `tests/dashboard-decisions-client.test.js:6` | **[REVERSAL]** comments naming `tests/dashboard-client.test.js` — *inside* moving files, so Step 2 crit 7's allowlist must tolerate the fix; see R9 |

**Relative-path assumptions that break when tests move down one level:**
**9** of the 13 Node tests compute `const REPO_ROOT = path.resolve(__dirname, '..')`
(`dashboard-capability-register`, `dashboard-client`, `dashboard-decisions-client`,
`dashboard-feedback`, `dashboard-invoke`, `dashboard-notebook`,
`dashboard-packets`, `dashboard-server`, `microworld-audit-contract`); the
other 4 (`dashboard-decision-block`, `dashboard-decision-run`,
`dashboard-decisions`, `dashboard-markdown-lite`) contain no `__dirname` at
all and need no walk fix. Additionally
`tests/dashboard-server.test.js:508` has a second, independent
`path.join(__dirname, '..', 'bin', 'microworld-dashboard', 'index.html')`.
`tests/microworld-rerun.test.sh:15` does `cd "$(dirname "$0")/.."` (was `:8`).
There are **13** `require('../bin/microworld-dashboard/…')` lines across 11
files (`dashboard-feedback.test.js` has three);
`dashboard-capability-register.test.js` and `dashboard-decisions-client.test.js`
require nothing from `bin/`.

**`tests/validate.sh`:** **14** registration blocks name these paths (was 8),
invocation lines at ~434, ~470, ~742, ~751, ~760, ~769, ~778, ~787, ~796,
~805, ~814, ~823, ~831, ~840. `grep -c "tests/dashboard-\|tests/microworld-"
tests/validate.sh` = **42** (three lines per block).

**Living docs referencing the old paths — still 5 `bin/dashboard` hits, but
at entirely new locations, and with one entry the plan never knew about:**
`bin/dashboard` appears at `.claude/wiki/architecture.md:105` (the audit-log
contract paragraph, four old paths in one line) and `CONTEXT.md:255`
(**Consumed interface**), `:1685` and `:1692` (**Bundle source**), `:1744`
(**D5 browser client**). Stale *test*-path citations —
`grep -rn "tests/dashboard-\|tests/microworld-rerun.test.sh\|tests/microworld-audit-contract.test.js"
CONTEXT.md .claude/wiki/architecture.md | wc -l` = **5** — sit at
`.claude/wiki/architecture.md:105`, `CONTEXT.md:258` (**Consumed interface**),
`:1233` (**Relocatable run.sh**), `:1692` (**Bundle source**), and
`:1619` (**Markdown-lite renderer** — a glossary entry created by the sibling
plan, naming `tests/dashboard-markdown-lite.test.js`; not in the original
Step 5 list). `grep -c "tests/microworld/"` is **0** in both files today.

**Deliberately NOT touched (historical record — OQ3):** `CHANGELOG.md`'s
existing entries, `.claude/wiki/changelog.md`'s existing entries,
everything under `docs/plans/`, everything under `docs/adr/`. Those cite
paths as they were at the time and are evidence, not documentation.

**Facts that make this cheaper than it looks:**
- `package.json`'s `files` array lists `bin` (the directory), not
  `bin/dashboard`, so packaging needs no change. Confirmed post-Step-1:
  `npm pack --dry-run --json` now lists **10** `bin/microworld-dashboard/`
  paths and **0** `bin/dashboard/` paths.
- `tests/validate.sh`'s npm-pack composition check asserts
  `included = ['agents/','hooks/','templates/','skills/']` — it does not name
  `bin/`, so it is indifferent to this rename.
- The two **adapter** mirrors (`adapters/codex/hooks/scripts/microworld-rerun.sh`,
  `adapters/cursor/hooks/scripts/microworld-rerun.sh`) have **their own**
  header prose and still do **not** contain the `bin/dashboard/audit-log.js`
  line. Re-verified 2026-09-04: zero hits for
  `bin/dashboard|bin/microworld-dashboard|tests/dashboard|tests/microworld`
  anywhere under `adapters/`. **This fact is still true and is no longer
  sufficient** — R5 concluded from it that no mirror is at risk, and a *third*
  mirror outside `adapters/` falsifies that conclusion. See R7.
- **[REVERSAL] There is a third, tracked mirror the plan never considered:**
  `.claude/hooks/scripts/microworld-rerun.sh`, this repo's own adapted install
  of its hooks. It is git-tracked, byte-identical to `hooks/scripts/`, carries
  both stale header lines, and is doubly gated — `tests/validate.sh:302` runs
  `diff -rq hooks/scripts .claude/hooks/scripts`, and
  `.claude/persona-config.json` pins its content hash
  (`fileHashes[".claude/hooks/scripts/microworld-rerun.sh"]`), checked by
  `tests/filehashes-currency.test.js`. Both run inside `bash tests/validate.sh`.
- No file this plan edits is version-stamped (`grep -rln "antislop v"
  hooks/scripts/` returns nothing; no `agents/*.md` or template is touched).
- Nothing in this plan's scope appears in `.claude/persona-config.json`'s
  `protectedPaths` or `fileHashes` **except** the `.claude/hooks/scripts/`
  mirror above: `grep -n '"bin/\|"tests/' .claude/persona-config.json` returns
  nothing. Steps 2, 4, 5 and 6 therefore carry no config-hash entanglement;
  only Step 3 does.

### Verification conventions (applies to every step's criteria)

- `$BASE` = the SHA recorded in the unit's dispatch packet as the commit the
  unit started from. Every `git diff … "$BASE"..HEAD` below is scoped to that
  unit's own commits, never to the whole plan.
- Every step's criteria are run from the repo root.
- `bash tests/validate.sh` must exit 0 at the end of **every** step; a step
  that leaves the suite red is not done, even if its own greps are green.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-11 Functional scope & success criteria: Q Should the microworld
  feature be siloed by moving everything under one directory, or namespaced
  in place with a canonical index tying the locations together? → A
  (OQ1, per user): namespaced silo plus canonical index — code to
  `bin/microworld-dashboard/`, tests to `tests/microworld/`, hook stays in
  `hooks/scripts/`, docs and ADRs stay put, tied together by a new
  `docs/microworld/README.md`.
- 2026-08-11 External dependencies & integrations: Q Do the five open issues
  on the 2026-07-28 plan (#122, #134, #137, #299, #300) need their retrieval
  contract rewritten, and does the plan doc move or get renamed? → A (OQ2,
  per user): no — leave
  `docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md`
  exactly in place, and leave all five issues' retrieval contract unchanged.
- 2026-08-11 Edge cases / failure handling: Q What happens to the eight moved
  tests' `__dirname`-relative repo-root computations and the bash test's
  `cd "$(dirname "$0")/.."`? → A (self-resolved): each gains one `..`, and
  Step 2 carries an explicit criterion that the suite is green after the move
  rather than trusting the edit — this is the single highest-probability way
  this reorg breaks silently.
- 2026-08-11 Technical constraints & tradeoffs: Q Should historical citations
  of the old paths in `CHANGELOG.md`, `.claude/wiki/changelog.md`,
  `docs/plans/` and `docs/adr/` be rewritten to the new paths? → A (OQ3,
  self-resolved, default stands): no. Those documents record what was true at
  the time; rewriting them would destroy the audit trail and make commit SHAs
  disagree with the prose that cites them. Only *living* reference docs
  (`CONTEXT.md`, `.claude/wiki/architecture.md`) are updated.
- 2026-08-11 Terminology consistency: Q Is "microworld silo" an established
  term in `CONTEXT.md`? → A (self-resolved): no — it is a load-bearing new
  domain term with no glossary entry (see the ubiquitous-language findings in
  Self-check CHK7). Step 6 hands it to `scribe` to add, alongside the ADR.
  The already-defined terms this plan reuses — **Microworld dashboard**,
  **Microworld bundle**, **Consumed interface**, **Reporter**, **Microworld
  audit log**, **Bundle source**, **D5 browser client** — are used with their
  canonical meanings and are not redefined.
- 2026-09-04 Functional scope & success criteria: Q After Step 1 shipped and a
  sibling plan landed six new tests and three new modules into the same two
  directories, do Steps 2-6's baselines still describe the tree? → A
  (self-resolved): no. Every count in Steps 2-6 was re-measured; the material
  changes are 7→10 code files, 8→14 test files, 8→14 `tests/validate.sh`
  registrations, and a `bin/dashboard` referrer count that fell 14→2 because
  Step 1 already closed the rest. Scope, ordering and the dependency graph are
  unchanged — this was a baseline refresh, not a re-plan.
- 2026-09-04 Edge cases / failure handling: Q Does any refreshed step now
  contain an edit that makes its own `bash tests/validate.sh` criterion
  unsatisfiable? → A (self-resolved): yes, two — recorded as R7 (Step 3 edits
  a mirrored source without its mirror or `fileHashes` entry) and R8 (Step 2
  rewrites gate registrations without `tests/watch-map.json`'s matching
  token). Both were corrected in place rather than raised as questions,
  because neither is a choice: the steps were unshippable as written.
- 2026-09-04 Technical constraints & tradeoffs: Q Should the four stale
  `bin/` comment lines and the three out-of-family microworld tests be folded
  into this plan? → A (deferred to the user as OQ7 and OQ6): recommended
  default is no for both — widening Step 2 into `bin/` breaks its tightest
  scope guarantee, and moving hook tests into a dashboard-test directory
  trades one miscategorisation for another. Both defaults are applied so the
  plan stays dispatchable, and both name the cheapest route to the
  alternative if the user disagrees.
- 2026-08-11 Completion / acceptance signals: Q What is "done" for a pure
  reorg with no behaviour change? → A (self-resolved): `bash tests/validate.sh`
  exit 0, plus zero residual references to the old paths in live code and
  living docs, plus every path claimed by the new index resolving on disk.
  A green suite alone is insufficient — a stale reference in prose is exactly
  the defect class this plan exists to prevent.

## Risks and dependencies

- **R1 — the moved tests break on relative paths, loudly or quietly.** Seven
  Node tests and one bash test resolve the repo root by walking up from their
  own location. A miss here can *look* green if a test's assertions degrade to
  no-ops on a missing fixture path. Mitigation: Step 2's criteria assert both
  suite-green and that each moved Node test still resolves `REPO_ROOT` to the
  actual repo root, proven by the `index.html` reads in
  `dashboard-client.test.js` and `dashboard-notebook.test.js` — those two fail
  hard on a wrong root, so they are the canary.
- **R2 — `git mv` vs delete+add.** If the move is not recorded as a rename,
  `git log --follow` and `git blame` lose the history of seven code files and
  eight test files at once. Mitigation: explicit rename-detection criterion in
  Steps 1 and 2.
- **R3 — prior FAIL history in this exact area (drives the model tag, see
  "Note for task-master").** Six of the nine microworld/dashboard units carry
  a `.fail` record — `gh315`, `gh317`, `gh318`, `gh319`, `gh320`, `gh323` —
  while `gh316`, `gh321`, `gh322` do not. The area's *documentation* unit
  `gh138` also FAILed (101 lines of defects), and its defect class was
  precisely prose drifting from live state. Steps 4, 5 and 6 are documentation
  units in the same area with the same failure mode.
- **R4 — a docs unit gated only by existence greps gates nothing.** Three
  units in this repo's history have FAILed because "the file exists" was the
  criterion while prose accuracy was the deliverable. Mitigation: Step 4's
  criterion resolves every path the new index claims, and Step 5's criterion
  counts residual stale references rather than asserting an edit happened.
- **R5 — ~~adapter-mirror parity is NOT at risk here~~ — SUPERSEDED BY R7 on
  2026-09-04.** The grep this risk rested on is still zero-hit
  (`grep -rn "bin/dashboard|tests/dashboard|tests/microworld" adapters/` → 0,
  re-verified), but the *conclusion* drawn from it — "no mirror carries the
  affected lines" — was wrong, because it only ever swept `adapters/`. Read R7
  instead. The instruction to re-run the grep rather than trust a recorded
  result stands, and is exactly what surfaced R7.
- **R7 — [REVERSAL] Step 3 is a three-artifact unit, not a one-file unit, and
  as previously written it could not pass its own criterion 5.** Editing
  `hooks/scripts/microworld-rerun.sh` alone makes `bash tests/validate.sh`
  exit 1 twice over: `tests/validate.sh:302`'s
  `diff -rq hooks/scripts .claude/hooks/scripts` reports the divergence, and
  `tests/filehashes-currency.test.js` reports the stale
  `fileHashes[".claude/hooks/scripts/microworld-rerun.sh"]` baseline. The
  source, the mirror, and the config hash must land in **one commit**. This is
  not a novel judgment — `CONTEXT.md:1095` (**Source-artifact + render-step
  gating rule**) states it as a standing rule for all future specs: such a pair
  "can never be gated independently," and the remedy is to "merge them into a
  single unit up-front." It is also the defect that FAILed a sibling unit
  twice: `.claude/reviewed/mw-step3.fail` records `bash tests/validate.sh`
  exiting 1 for precisely this omission, with `node bin/cli.js --update
  --force-render` as the *proven* remedy, and `.claude/reviewed/mw-step2.fail`
  note N7 records the same divergence for `session-start.sh`. Mitigation:
  Step 3's affected-files list, ordered edits and criteria all now name the
  mirror and the hash explicitly. **`.claude/persona-config.json` must never be
  hand-edited** — it is in `harness-integrity-gate.sh`'s Set A, which refuses
  writes from every agent identity with no exemption; regenerating via
  `node bin/cli.js --update --force-render` is the only sanctioned route.
  **Partly superseded, 2026-09-24:**
  `docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md`
  narrows the "refuses writes" predicate above for this config specifically:
  in an allowlisted main-session shape (`agent_id` absent), a `Write`/`Edit`
  there now reaches `permissionDecision: "ask"` — never `allow`, never from a
  subagent — instead of an outright refusal. "With no exemption" stays true
  (no identity gets a unilateral bypass); the `--force-render` sanctioned
  route above is unaffected.
- **R8 — [REVERSAL] Step 2 must update `tests/watch-map.json`, or it cannot
  pass its own criterion 1.** `tests/watch-map.json`'s `gh351` entry names
  `tests/dashboard-decision-block.test.js` in both `watch[]` and `run[]`. This
  is live config (read by `hooks/scripts/session-start.sh`,
  `hooks/scripts/lib/microworld-rerun-core.sh` and
  `hooks/scripts/lib/microworld-queue.sh`), and
  `tests/watch-map-registration.test.sh` — which `tests/validate.sh` runs —
  asserts every `tests/<file>` token in a `run[]` command is grep-able in
  `tests/validate.sh`. Once Step 2 rewrites the registration to
  `tests/microworld/dashboard-decision-block.test.js`, the watch-map's
  unchanged token no longer matches and the merge gate fails. The stale
  `watch[]` entry is the quieter half of the same defect: it would silently
  stop triggering the rerun rather than failing loudly.
- **R9 — [REVERSAL] Step 2's crit 7 would have rejected a correct fix.** Two
  of the moving files carry comments naming a sibling by its old path
  (`tests/dashboard-notebook.test.js:41`,
  `tests/dashboard-decisions-client.test.js:6`, both naming
  `tests/dashboard-client.test.js`). Neither existed in the form the criterion
  was authored against. Repointing them is correct and in scope, but the
  changed lines match none of crit 7's allowed tokens, so the criterion would
  count them as out-of-scope drift and fail. Mitigation: `tests/microworld` is
  added to crit 7's allowlist alternation, preserving the criterion's intent
  (no assertion/fixture/prose drift) while permitting the path fix.
- **R6 — scope creep into the dashboard's behaviour.** This plan renames and
  documents; it changes no logic. Any diff hunk inside a moved file that is
  not a path string, a `require`, a `__dirname` walk, or a comment naming a
  moved path is out of scope.
- **Pre-existing drift observed, deliberately out of scope:** `CONTEXT.md:1638`
  (**Microworld dashboard** entry) cites `README.md:177` for the dashboard
  section, which actually begins at `README.md:263` (it was `:204` when this
  plan was authored — the drift has widened, not closed). Not caused by this
  plan and not fixed by it (fixing unrelated drift inside a rename unit is how
  rename units grow teeth). Flagged here so `scribe` can file it separately.
- **Dependency order:** Step 1 → Step 2 → {Step 3, Step 5} → Step 4 → Step 6.
  Steps 3 and 5 are independent of each other and may run in either order or
  in parallel, but both name final paths and so must follow Steps 1 and 2.
  Step 4's index names every final path, so it follows Steps 1-3. Step 6 is
  the institutional record and is last.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every acceptance grep below was
  re-executed against the tree on **2026-09-04** and returned a non-vacuous
  baseline. Post-Step-1 values, superseding the 2026-08-11 ones:
  `grep -rn "bin/dashboard" bin/ tests/ hooks/` = **2** (was 14 — Step 1
  closed the other 12; both survivors are the Step 3 header lines, and the
  same 2 recur under `.claude/hooks/`);
  `ls tests/ | grep -cE "^(dashboard-|microworld-)"` = **14** (was 8);
  `grep -c "tests/dashboard-\|tests/microworld-" tests/validate.sh` = **42**;
  `grep -rn "bin/dashboard" CONTEXT.md .claude/wiki/architecture.md
  .claude/wiki/conventions.md README.md` = **5** (unchanged in count, moved in
  location); the Step 5 test-path grep = **5**;
  `grep -c "tests/microworld/" CONTEXT.md` = **0** and the same for
  `.claude/wiki/architecture.md` = **0**; `tests/microworld/` does not exist;
  `docs/microworld/` does not exist; `npm pack --dry-run --json` lists **10**
  `bin/microworld-dashboard/` paths and **0** `bin/dashboard/` paths.
  Each must invert after the corresponding step, so no criterion in this plan
  can pass by accident on the pre-change tree. **This re-measurement is what
  surfaced R7, R8 and R9** — the P1 discipline caught three criteria that
  would have failed on a correct implementation, which is the whole reason it
  is a MUST rather than a courtesy.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied, and
  **now load-bearing rather than vacuous**. The 2026-08-11 wording claimed no
  `fileHashes` or backfill path is touched; R7 shows Step 3 does touch one.
  The principle is satisfied precisely *because* the remedy is the
  deterministic script: Step 3 regenerates the mirror and its hash with
  `node bin/cli.js --update --force-render` rather than hand-editing either.
  Hand-editing `.claude/persona-config.json` would violate P2 and would in any
  case be refused by `harness-integrity-gate.sh`. Step 1's `bin/cli.js` edit
  (one `require` string) has already shipped.
- P3 "Version-stamp discipline": satisfied — the MUST is not triggered, since
  no `agents/*.md` and no template is edited and no file in scope carries an
  `<!-- antislop vX.Y.Z -->` stamp (verified by grep). Step 6 nevertheless
  bumps `.claude-plugin/plugin.json` and adds a `CHANGELOG.md` entry, per this
  repo's standing release convention.
- P4 "Optional personas degrade gracefully": satisfied — no shared persona
  prose, no `templates/persona-protocol.md`, no `agents/*.md` is edited.
- P5 "`tests/validate.sh` is the merge gate": satisfied — `bash
  tests/validate.sh` exit 0 is an acceptance criterion on all six steps, and
  Step 2 additionally edits the gate itself and must leave all **14** relocated
  registrations executing. Taking this principle literally (rather than
  treating "validate.sh exits 0" as boilerplate) is what exposed R7 and R8:
  both steps carried that criterion while containing an edit that guarantees
  it fails.

---

## Step 1 — Relocate the dashboard module tree to `bin/microworld-dashboard/`

> **SHIPPED — issue #327, closed.** This step and its criteria are left
> verbatim as the historical record and were deliberately **not** refreshed by
> the 2026-09-04 baseline pass. Its counts describe the tree as it was when
> the step ran (7 files); the directory now holds 10, because a sibling plan
> added three modules afterwards. Do not re-run these criteria against today's
> tree and do not treat the mismatch as drift.

Rename the directory and repoint every referrer, so the tree is green at the
end of this step alone. Test files are edited here (their `require` strings)
but not moved — that is Step 2.

**Affected files**
- `bin/dashboard/` → `bin/microworld-dashboard/` (all 7 files, via `git mv`)
- `bin/cli.js` (line ~2161: `require('./dashboard/server')` →
  `require('./microworld-dashboard/server')`)
- `bin/microworld-dashboard/feedback-block.js` (header comment at ~line 9)
- `tests/dashboard-client.test.js`, `tests/dashboard-feedback.test.js`,
  `tests/dashboard-invoke.test.js`, `tests/dashboard-notebook.test.js`,
  `tests/dashboard-packets.test.js`, `tests/dashboard-server.test.js`,
  `tests/microworld-audit-contract.test.js` (`require` strings and the two
  `'bin/dashboard/index.html'` literals)

**Do NOT touch:** `tests/validate.sh`, `hooks/`, `adapters/`, `CONTEXT.md`,
`.claude/wiki/`, `README.md`, `docs/`, `package.json`, `CHANGELOG.md`.

**Acceptance criteria**
1. `bash tests/validate.sh` exits 0.
2. `grep -rn "bin/dashboard\|'./dashboard/\|\"./dashboard/" bin/ tests/ hooks/ | wc -l` → `0`
   (baseline 14).
3. `ls bin/microworld-dashboard/ | wc -l` → `7`, and `test ! -d bin/dashboard`
   exits 0.
4. Rename detection: `git diff --stat -M --summary "$BASE"..HEAD -- bin/ |
   grep -c "^ rename "` → `7`. Zero `create mode` / `delete mode` lines for
   `bin/dashboard/*` or `bin/microworld-dashboard/*`.
5. Packaging unchanged in substance:
   `npm pack --dry-run --json | python3 -c "import sys,json; f=[x['path'] for
   x in json.load(sys.stdin)[0]['files']]; print(len([p for p in f if
   p.startswith('bin/microworld-dashboard/')]))"` → `7`, and the same
   expression for `bin/dashboard/` → `0`. `package.json` is unmodified:
   `git diff --name-only "$BASE"..HEAD -- package.json | wc -l` → `0`.
6. The dashboard still starts: `node bin/cli.js --dashboard --dashboard-port=0`
   prints a `127.0.0.1` URL and a token, then is terminated. (Run it, do not
   infer it from the suite — the suite starts the server via
   `require`, not via the CLI flag, so criterion 1 alone does not exercise
   `bin/cli.js:2161`.)

---

## Step 2 — Relocate the microworld test suite to `tests/microworld/`

Move all fourteen test files one level down and fix the three things that
break on such a move: the tests' own repo-root walks, the gate's
registrations, and the watch-map's registration tokens.

**Affected files** (counts refreshed 2026-09-04; was 8 files, now 14)
- All 14 files matching `^(dashboard-|microworld-)` in `tests/` →
  `tests/microworld/` (via `git mv`, one rename per file). Enumerated in
  Context; derive the live list with
  `ls tests/ | grep -E "^(dashboard-|microworld-)"` rather than copying it.
- Inside the **9** Node tests that have one: `path.resolve(__dirname, '..')` →
  `path.resolve(__dirname, '..', '..')`. The other 4 Node tests contain no
  `__dirname` and need no walk fix. Note the *second*, independent walk at
  `tests/dashboard-server.test.js:508`
  (`path.join(__dirname, '..', 'bin', 'microworld-dashboard', 'index.html')`),
  which needs the same extra `..` and is easy to miss because it is not the
  `REPO_ROOT` assignment.
- All **13** `require('../bin/microworld-dashboard/…')` lines across 11 files
  → `require('../../bin/microworld-dashboard/…')`.
  `dashboard-feedback.test.js` has three of them;
  `dashboard-capability-register.test.js` and
  `dashboard-decisions-client.test.js` have none.
- Inside `tests/microworld/microworld-rerun.test.sh`: `cd "$(dirname "$0")/.."`
  at **line 15** (was `:8`) → `cd "$(dirname "$0")/../.."`. Change **only**
  that line: lines 451, 529, 539 and 581 contain
  `cd "$(cd "$(dirname "$0")" && pwd)/../.."` inside quoted `RUNEOF` heredocs
  that generate *fixture* `run.sh` files; those are already correct relative to
  the fixture tree and must not be touched.
- `tests/validate.sh`: the **14** registration blocks' invocation paths.
- **`tests/watch-map.json` (new — see R8):** the `gh351` entry's `watch[]` and
  `run[]` both name `tests/dashboard-decision-block.test.js`; both become
  `tests/microworld/dashboard-decision-block.test.js`.
- **Two comments naming a moved sibling (new — see R9):**
  `tests/dashboard-notebook.test.js:41` and
  `tests/dashboard-decisions-client.test.js:6` name
  `tests/dashboard-client.test.js`; both become
  `tests/microworld/dashboard-client.test.js`.

**Naming:** keep each file's basename as-is inside the new directory
(`tests/microworld/dashboard-server.test.js`, not
`tests/microworld/server.test.js`). Stripping the prefix would break every
CHANGELOG and `.claude/wiki/changelog.md` citation's *basename* as well as its
path, and this plan's whole point is to preserve the historical record.

**Do NOT touch:** `bin/`, `hooks/`, `adapters/`, `CONTEXT.md`,
`.claude/wiki/`, `README.md`, `docs/`. No assertion, fixture, or test case may
be added, removed, or reworded — this step moves files and fixes paths only.
(`tests/watch-map.json` **is** in scope, per R8; the `bin/` comment lines that
also name moved test paths are **not**, per OQ7.)

**Acceptance criteria** (expected counts refreshed 2026-09-04)
1. `bash tests/validate.sh` exits 0, and its output contains all 14 `OK`
   lines for the relocated files:
   `bash tests/validate.sh | grep -c "OK   tests/microworld/"` → `14`
   (was `8`).
2. `ls tests/ | grep -cE "^(dashboard-|microworld-)"` → `0` (baseline 14);
   `ls tests/microworld/ | wc -l` → `14`.
3. `grep -rn "tests/dashboard-\|tests/microworld-" tests/validate.sh | wc -l`
   → `0` (baseline 42).
4. Repo-root canary: `node tests/microworld/dashboard-client.test.js`,
   `node tests/microworld/dashboard-notebook.test.js` and
   `node tests/microworld/dashboard-decisions-client.test.js` each exit 0 when
   run directly from the repo root. All three read
   `bin/microworld-dashboard/index.html` through `REPO_ROOT` and fail hard on
   a wrong root, so a green run here is the proof that the `..` fix landed.
   (`dashboard-decisions-client` is new since authoring and is the third
   `index.html` reader — the original criterion named only the first two.)
5. Bash-test root canary: `bash tests/microworld/microworld-rerun.test.sh`
   exits 0 when invoked from the repo root **and** from `tests/microworld/`
   (`cd tests/microworld && bash ./microworld-rerun.test.sh`) — the second
   invocation is what proves the `cd "$(dirname "$0")/../.."` is correct
   rather than accidentally working from one cwd.
6. Rename detection: `git diff --stat -M --summary "$BASE"..HEAD -- tests/ |
   grep -c "^ rename "` → `14`.
7. No test-content drift: for each moved file, the diff touches only
   `require`/`__dirname`/`cd`/path-citation lines. Machine check —
   `git diff -M "$BASE"..HEAD -- tests/microworld/ | grep -E "^[+-]" |
   grep -vE "^(\+\+\+|---)" | grep -vcE "(require\(|__dirname|dirname \"\\$0\"|bin/microworld-dashboard|tests/microworld)"`
   → `0`. **`tests/microworld` was added to the allowlist on 2026-09-04 (R9)**
   so the two sibling-naming comments can be repointed; without it the
   criterion rejects a correct fix. The intent is unchanged: an assertion,
   fixture value or test description that changes still trips this check.
8. **Watch-map registration is coherent (R8):**
   `bash tests/watch-map-registration.test.sh` exits 0, and
   `grep -c "tests/microworld/dashboard-decision-block.test.js"
   tests/watch-map.json` → `2` (one in `watch[]`, one in `run[]`), while
   `grep -c "tests/dashboard-decision-block.test.js" tests/watch-map.json`
   → `0`. Note the registration test's own token extractor
   (`grep -oE 'tests/[A-Za-z0-9._-]+'`, no `/` in the class) truncates a
   nested path to `tests/microworld`, so it would pass *vacuously* after the
   move — the two explicit greps above are what actually gate the `watch[]`
   half, which the registration test never inspects at all.

---

## Step 3 — Repoint the reporter hook's consumed-interface header

`hooks/scripts/microworld-rerun.sh:11-12` (was `:10-11`) documents the
audit-log line format as a **Consumed interface** and names both sides of that
contract by path. Both names are now wrong. This is live protocol prose in a
hook header, not a historical citation, so it is in scope.

> **[REVERSAL, 2026-09-04 — read R7 before starting.] This is a
> three-artifact unit, not a one-file unit.** The 2026-08-11 version of this
> step edited one file and asserted `bash tests/validate.sh` exit 0; those two
> instructions contradict each other, because the tracked mirror
> `.claude/hooks/scripts/microworld-rerun.sh` carries the same two header lines
> and is gated by `tests/validate.sh:302` (`diff -rq`) and by
> `tests/filehashes-currency.test.js` (content hash pinned in
> `.claude/persona-config.json`). Source, mirror and hash land in **one
> commit**, per `CONTEXT.md:1095`'s standing source-artifact + render-step rule.

**Affected files**
- `hooks/scripts/microworld-rerun.sh` (header comment only, lines ~11-12) —
  the source.
- `.claude/hooks/scripts/microworld-rerun.sh` — the tracked mirror.
  **Regenerated, never hand-edited.**
- `.claude/persona-config.json` — the `fileHashes` entry for that mirror.
  **Regenerated, never hand-edited** (Set A; `harness-integrity-gate.sh`
  refuses direct writes from every agent identity, with no exemption).

**Partly superseded, 2026-09-24:**
`docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md` narrows
the "refuses direct writes" predicate above for this config specifically: in
an allowlisted main-session shape (`agent_id` absent), a `Write`/`Edit` there
now reaches `permissionDecision: "ask"` — never `allow`, never from a
subagent — instead of an outright refusal. "With no exemption" stays true.

**Method:** edit the source, then run `node bin/cli.js --update
--force-render`, which rewrites the mirror and re-backfills the hash. This is
the remedy proven in a throwaway worktree and recorded in
`.claude/reviewed/mw-step3.fail`; it is also the P2-compliant route (a
deterministic script rather than LLM re-derivation).

**Do NOT touch:** the hook's logic (below `set -euo pipefail`), the two
**adapter** mirrors under `adapters/` (verified 2026-09-04 to still not carry
these lines — but re-run the grep in criterion 3 before concluding that),
`tests/`, `bin/`, `docs/`. Do not hand-edit the mirror or the config.

**Acceptance criteria** (baselines refreshed 2026-09-04)
1. `grep -c "bin/microworld-dashboard/audit-log.js" hooks/scripts/microworld-rerun.sh`
   → `1`; `grep -c "tests/microworld/microworld-audit-contract.test.js"
   hooks/scripts/microworld-rerun.sh` → `1`.
2. `grep -rn "bin/dashboard\|tests/dashboard-\|tests/microworld-audit" hooks/ | wc -l`
   → `0` (baseline `2`, not 14 — Step 1 closed every other referrer), **and
   the same grep over `.claude/hooks/` → `0`** (baseline `2`). The second half
   is the criterion the 2026-08-11 version was missing; without it the unit
   can report success with the operative mirror still stale.
3. Mirror-parity precondition re-verified, not assumed:
   `grep -rn "bin/dashboard\|bin/microworld-dashboard\|tests/dashboard\|tests/microworld" adapters/ | wc -l`
   → `0`. If this is **not** 0, stop and escalate — the unit's scope must grow
   to include both adapter mirrors in the same commit (never gate a source
   edit apart from its shipped copy). Note this grep was zero-hit at authoring
   *and remains zero-hit*, yet the premise it was taken to establish was still
   false: it sweeps only `adapters/`, and the mirror that mattered lives under
   `.claude/hooks/`. Criterion 6 is the sweep that actually covers it.
4. Logic untouched: `git diff "$BASE"..HEAD --
   hooks/scripts/microworld-rerun.sh .claude/hooks/scripts/microworld-rerun.sh
   | grep -E "^[+-]" | grep -vE "^(\+\+\+|---)" | grep -vc "^[+-]#"` → `0`
   (every changed line in both the source and the mirror is a comment line).
5. `bash tests/validate.sh` exits 0, and
   `node tests/microworld/microworld-audit-contract.test.js`'s registration
   still passes — the contract test executes the real hook, so a header edit
   that accidentally broke the script would surface here.
6. **Mirror and hash are current in the same commit (R7):**
   `diff -rq hooks/scripts .claude/hooks/scripts` exits 0, and
   `node tests/filehashes-currency.test.js` exits 0. Both are already inside
   criterion 5's suite; they are called out separately because they are the
   two checks this unit is uniquely likely to break, and a reviewer should
   confirm them directly rather than infer them from an aggregate exit code.
7. **The unit's diff is confined to the three named artifacts:**
   `git diff --name-only "$BASE"..HEAD | sort` prints exactly
   `.claude/hooks/scripts/microworld-rerun.sh`,
   `.claude/persona-config.json` and `hooks/scripts/microworld-rerun.sh`.
   If `--force-render` rewrites anything beyond these, that is unrelated
   pre-existing mirror drift — stop and report it rather than committing it
   inside this unit.

---

## Step 4 — Author `docs/microworld/README.md`, the canonical index

The artifact that makes the namespaced silo discoverable. It is an **index**,
not a tutorial: it names every location the microworld feature occupies and
says in one line what each holds. It does not re-explain how the dashboard
works (that is `README.md`'s "Microworld dashboard" section) and does not
re-derive rationale (that is `docs/adr/0017` and `docs/adr/0019`).

**Affected files**
- `docs/microworld/README.md` (new)

**Required contents** — at minimum, one entry per location, each naming the
path in backticks:
- `bin/microworld-dashboard/` — the dashboard server, discovery, invoke,
  audit-log parser, feedback-block formatter, source reader, and the D5
  browser client.
- `tests/microworld/` — all **fourteen** tests (was "eight"; refreshed
  2026-09-04), with a one-line note that `microworld-audit-contract.test.js`
  is the cross-language contract test binding the bash hook to the Node
  parser. State the count by counting the directory at authoring time, not by
  copying the number from this plan.
- `hooks/scripts/microworld-rerun.sh` — the **Reporter** hook, with an
  explicit sentence saying it stays under `hooks/scripts/` because hooks are
  located by `hooks.json` registration, not by feature area, and naming its
  two adapter mirrors under `adapters/`.
- `docs/adr/0017-microworld-bundles-gitignored.md` and
  `docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md`.
- `CONTEXT.md` — named as the glossary home for the microworld terms.
- A clearly-headed **"Not on disk"** section for the gitignored runtime
  artifacts (`microworlds/<unit-slug>/`, `.claude/microworld-audit.log`,
  `.claude/human-review/<task-id>/`), which exist at runtime only and are
  therefore excluded from criterion 2's resolution check by construction.

**Do NOT touch:** anything else. This step creates exactly one file.

**Acceptance criteria**
1. `test -f docs/microworld/README.md` exits 0, and
   `git diff --name-only "$BASE"..HEAD | wc -l` → `1`.
2. **Every path the index claims resolves on disk** (this is the criterion
   that makes the unit non-vacuous — an existence check on the file itself
   would gate nothing when prose accuracy is the deliverable):
   ```sh
   grep -o '`[^`]*`' docs/microworld/README.md | tr -d '`' \
     | grep -E '^(bin|tests|hooks|docs|adapters)/[^ ]*$' \
     | grep -vE '[*?{}|<>]' \
     | sed -E 's/:[0-9]+(-[0-9]+)?$//' \
     | sort -u > /tmp/mw_paths.txt
   test -s /tmp/mw_paths.txt || { echo "index claims no checkable paths"; exit 1; }
   missing=0
   while read -r p; do [ -e "$p" ] || { echo "MISSING $p"; missing=1; }; done < /tmp/mw_paths.txt
   exit $missing
   ```
   must exit 0. Two deliberate exclusions, each verified to be needed by
   running this loop against a prose document at authoring time:
   `microworlds/` and `.claude/` prefixes are outside the pattern because
   those are gitignored runtime artifacts and belong in the "Not on disk"
   section; and glob/alternation forms (`*`, `{a,b}`, `|`) are filtered out
   because they are patterns, not paths. **The index must therefore name
   plain, complete paths** — no `tests/microworld/*.test.js` shorthand, no
   `{client,server}` brace lists. A trailing `:<line>` or `:<start>-<end>`
   suffix is tolerated and stripped before the check.
3. The index is complete against the silo — it names every top-level location:
   `for p in bin/microworld-dashboard/ tests/microworld/
   hooks/scripts/microworld-rerun.sh
   docs/adr/0017-microworld-bundles-gitignored.md
   docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md;
   do grep -q "$p" docs/microworld/README.md || echo "UNLISTED $p"; done`
   produces no output.
4. No stale paths: `grep -c "bin/dashboard\|tests/dashboard-\|tests/microworld-audit-contract.test.js"
   docs/microworld/README.md` → `0`, except that
   `tests/microworld/microworld-audit-contract.test.js` (the new path) must
   appear: `grep -c "tests/microworld/microworld-audit-contract.test.js"` → `1`.
5. `bash tests/validate.sh` exits 0.

---

## Step 5 — Update the living reference docs

Repoint the five stale lines in the glossary and the wiki architecture page.
This step's defining constraint is what it must **not** touch.

**Affected files** (line numbers and entry list refreshed 2026-09-04 — every
number below moved, and one entry is new. Match by **entry headword**, never
by line number.)
- `CONTEXT.md` — six citations across five glossary entries:
  `:255` and `:258` (**Consumed interface** — `bin/dashboard/audit-log.js`
  and `tests/microworld-audit-contract.test.js`), `:1233` (**Relocatable
  run.sh** — `tests/microworld-rerun.test.sh`), `:1619` (**Markdown-lite
  renderer** — `tests/dashboard-markdown-lite.test.js`), `:1685` and `:1692`
  (**Bundle source** — `bin/dashboard/index.html` and
  `tests/dashboard-packets.test.js`), `:1744` (**D5 browser client** —
  `bin/dashboard/index.html`).
  **Markdown-lite renderer is new**: the sibling decision-surface plan created
  it after 2026-08-11, so the original Step 5 list (four entries) missed it.
  Criterion 2 already covers it generically, so this is a list refresh, not a
  scope change.
- `.claude/wiki/architecture.md` — line `:105` (unchanged), the audit-log
  contract paragraph, which names `bin/dashboard/audit-log.js`,
  `bin/dashboard/discover.js`, `bin/dashboard/server.js`,
  `bin/dashboard/index.html` and `tests/microworld-audit-contract.test.js` in
  a single line.

**Do NOT touch — the scope boundary (OQ2 and OQ3):**
- Anything under `docs/plans/`. In particular
  `docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md` is
  explicitly out of scope for **any** edit — not a path fix, not a rename, not
  a header note. Its five open issues (#122, #134, #137, #299, #300) keep
  their retrieval contract byte-for-byte.
- Anything under `docs/adr/`.
- `CHANGELOG.md` and `.claude/wiki/changelog.md` — historical entries, and
  this step adds nothing to either (Step 6 does).
- `README.md` — its only dashboard references are `node bin/cli.js
  --dashboard` and conceptual prose, neither of which changes. Verified: zero
  `bin/dashboard` hits in `README.md`.

**Acceptance criteria**
1. `grep -rn "bin/dashboard" CONTEXT.md .claude/wiki/architecture.md
   .claude/wiki/conventions.md README.md | wc -l` → `0` (baseline `5`,
   re-measured 2026-09-04 — count unchanged, locations all moved).
2. `grep -rn "tests/dashboard-\|tests/microworld-rerun.test.sh\|tests/microworld-audit-contract.test.js"
   CONTEXT.md .claude/wiki/architecture.md | wc -l` → `0` (baseline `5`), and
   the new paths are present: `grep -c "tests/microworld/" CONTEXT.md` ≥ `3`
   (raised from `2`: **Consumed interface**, **Relocatable run.sh**,
   **Markdown-lite renderer** and **Bundle source** each gain one, so `3` is
   still a floor rather than an exact count),
   `grep -c "tests/microworld/" .claude/wiki/architecture.md` ≥ `1`.
   Both baselines are `0` today, so neither can pass on the pre-change tree.
3. **Scope boundary, directory-wide:**
   `git diff --name-only "$BASE"..HEAD -- docs/plans/ docs/adr/ | wc -l` → `0`.
4. **Scope boundary, OQ2's specific promise, asserted independently** so it
   survives any future loosening of criterion 3:
   `git diff --name-only "$BASE"..HEAD --
   docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md | wc -l`
   → `0`.
5. **Historical changelogs untouched by this step:**
   `git diff --name-only "$BASE"..HEAD -- CHANGELOG.md .claude/wiki/changelog.md | wc -l`
   → `0`.
6. The unit's whole diff is confined to two files:
   `git diff --name-only "$BASE"..HEAD | sort` prints exactly
   `.claude/wiki/architecture.md` and `CONTEXT.md`.
7. `bash tests/validate.sh` exits 0 (it frontmatter-checks and shape-checks
   these docs).

---

## Step 6 — Institutional record: ADR, glossary term, CHANGELOG, version bump

The `scribe` unit. Records *why* the silo exists and mints the one new term
this plan introduces.

**Affected files**
- `docs/adr/<NNNN>-microworld-silo-namespaced-directories.md` (new).
  **`<NNNN>` must be re-derived at execution time** by listing `docs/adr/` and
  taking the next free number — do not hard-code the number from this plan.
  The `0007` slot is a deliberately preserved hole and must never be
  backfilled (`ls docs/adr/ | grep -c "^0007-"` → `0`, re-verified
  2026-09-04). For orientation only: the highest ADR on 2026-09-04 is `0028`,
  up from `0019` at authoring time — which is exactly why the number is
  re-derived rather than written down here.
- `CONTEXT.md` — one new glossary entry, **Microworld silo**, cross-linked to
  the existing **Microworld dashboard**, **Microworld bundle** and
  **Reporter** entries, plus an `_Avoid_:` line discouraging "the dashboard
  directory" as a synonym.
- `CHANGELOG.md` — one new entry (append; never revise an existing one).
- `.claude/wiki/changelog.md` — one new entry (append).
- `.claude-plugin/plugin.json` — version bump.

**ADR must state:** the decision (namespaced silo plus canonical index), the
alternatives rejected — (b) a full physical silo moving the hook and docs
under one tree, rejected because hooks are located by `hooks.json`
registration and moving them would desynchronise the two adapter mirrors; and
(c) leave everything flat, rejected because a `microworld` grep misses
`bin/dashboard/` entirely — and the explicit consequence that historical
citations in `CHANGELOG.md`, `.claude/wiki/changelog.md`, `docs/plans/` and
`docs/adr/` are **not** rewritten, so any path in those documents must be read
as "the path as of that entry's date."

**Do NOT touch:** `bin/`, `tests/`, `hooks/`, `adapters/`, `README.md`,
`docs/plans/`, `docs/microworld/README.md` (Step 4 owns it).

**Acceptance criteria**
1. The ADR exists and its number is genuinely free at authoring time:
   `ls docs/adr/ | grep -c "^0007-"` → `0` (the hole is still a hole), and the
   new file's number is strictly greater than every pre-existing ADR number.
2. `grep -c "Microworld silo" CONTEXT.md` ≥ `1`, and the entry follows the
   file's existing entry shape (bold headword, colon, indented body) —
   verified by `bash tests/validate.sh` exiting 0.
3. The ADR's rejected alternatives are present, not implied:
   `grep -ci "rejected" docs/adr/<NNNN>-microworld-silo-namespaced-directories.md`
   ≥ `2`.
4. Every path the ADR and the new glossary entry claim resolves — same
   resolution loop as Step 4 criterion 2, run over both
   `docs/adr/<NNNN>-microworld-silo-namespaced-directories.md` and
   `CONTEXT.md`'s new entry.
5. **Changelogs are append-only** (this is where the additive edits land, so
   the invariant shifts from "untouched" to "no deletions"):
   `git diff --numstat "$BASE"..HEAD -- CHANGELOG.md .claude/wiki/changelog.md
   | awk '{s+=$2} END {print s+0}'` → `0`.
6. **`docs/plans/` still untouched:**
   `git diff --name-only "$BASE"..HEAD -- docs/plans/ | wc -l` → `0`.
7. Version bumped: `.claude-plugin/plugin.json`'s `version` differs from its
   value at `$BASE`, and `package.json`'s `version` matches it
   (`node -e "…"` comparing the two, both files' `version` field equal).
8. `bash tests/validate.sh` exits 0.

---

## Open Questions

**Two new questions opened by the 2026-09-04 baseline refresh (OQ6, OQ7).**
Both are genuine scope decisions rather than measurements, so neither was
self-resolved during the refresh; both have a recommended default, and the
plan as amended reflects the default in each case, so Steps 2-6 remain
dispatchable while these are outstanding. Neither blocks dispatch: answering
"take the default" changes nothing.

- **OQ6 — do the three microworld-adjacent tests outside the
  `^(dashboard-|microworld-)` family move too?**
  `tests/session-start-microworld-status.test.sh`,
  `tests/stop-gate-microworld-skip.test.sh` and
  `tests/stop-gate-deferred-microworld.test.sh` all carry `microworld` in the
  name and would be swept up by a reader's `microworld` grep, but they
  exercise the session-start and stop-gate hooks, not the dashboard.
  *Recommended default (applied): leave them in `tests/`.* Moving them would
  put hook tests under a directory whose stated contents are the dashboard
  suite, and the plan's Goal is discoverability, not physical consolidation
  (the same reasoning as OQ5's answer for the hook itself). Cost of the
  default: `docs/microworld/README.md` will describe `tests/microworld/` as
  the microworld test home while three microworld-named tests live elsewhere.
  If that bothers the reader more than the miscategorisation would, the fix is
  one added sentence in Step 4's index, not a change to Step 2.
- **OQ7 — do the four `bin/` comment lines naming moved test paths get fixed,
  and if so by which step?** `bin/microworld-dashboard/index.html:117,125,132`
  and `bin/microworld-dashboard/decision-block.js:92` name
  `tests/dashboard-feedback.test.js`, `tests/dashboard-decision-block.test.js`
  (twice) and `tests/dashboard-markdown-lite.test.js`. Step 2 creates the
  staleness; Step 2's Do-NOT-touch forbids `bin/`; no other step covers `bin/`
  comments. Nothing mechanical breaks either way — these are comments, gated
  by nothing.
  *Recommended default (applied): leave them, and file a follow-up.* Widening
  Step 2 into `bin/` would break its tightest guarantee (its diff is confined
  to `tests/`), and R6 warns specifically against a rename unit growing teeth.
  **This is a real, accepted cost**, not an oversight: it leaves four stale
  path citations in live code comments, which is the same defect class the
  plan's own Completion clarification says a green suite is insufficient to
  catch. If the user prefers to close it now, the cheapest correct route is a
  seventh step after Step 2 (comment-only, one criterion:
  `grep -rc "tests/dashboard-" bin/` → `0`), **not** a widened Step 2.

The five original questions are unchanged. OQ1 and OQ2 were answered by the
user (recorded in Clarifications); OQ3, OQ4 and OQ5 resolved to their
recommended defaults and publishing surfaced no conflict with that resolution:

- **OQ3 (rewrite historical citations?) → no.** Reconfirmed at finalization:
  OQ1's answer makes the canonical index (`docs/microworld/README.md`) the
  place a reader goes for current paths, which is exactly what makes leaving
  historical citations alone safe rather than merely cheap.
- **OQ4 (directory name?) → `bin/microworld-dashboard/`.** Reconfirmed:
  `package.json`'s `files` lists the `bin` directory, not any child, so the
  name is packaging-neutral; and `tests/microworld/` + `bin/microworld-dashboard/`
  read as one family under a `microworld` grep, which is the Goal.
- **OQ5 (move the hook?) → no.** Reconfirmed, and the reason is stronger again
  after the 2026-09-04 refresh: the hook has **three** mirrors, not two — the
  two adapter copies under `adapters/codex/` and `adapters/cursor/`, plus the
  tracked `.claude/hooks/scripts/` copy found in R7 — none of which can move
  with it. Relocating the canonical copy would *increase* the scatter it was
  meant to reduce, and would break a `diff -rq` parity gate besides.

## Self-check

- CHK1: Does Step 5's "do not touch the changelogs" boundary conflict with
  Step 6's requirement to append to both changelogs? — FAIL (conflicting) —
  revised in place: Step 5 asserts `--name-only` empty for both changelogs
  (it adds nothing), Step 6 asserts `--numstat` deletions `== 0` (append-only).
  The two are now complementary, not contradictory, and `docs/plans/` stays
  `--name-only` empty in both.
- CHK2: Is the `$BASE` referent of every `git diff` in this plan defined? —
  FAIL (ambiguous) — revised in place: defined once under "Verification
  conventions" as the SHA in the unit's dispatch packet, scoping each check to
  that unit's own commits.
- CHK3: Does the plan say what happens to the eight moved tests'
  `__dirname`-relative repo-root walks? — PASS (Step 2, affected-files list
  and criteria 4-5, with a stated canary rationale).
- CHK4: Do Steps 1 and 2 agree on who edits the test files' `require`
  strings? — PASS (Step 1 edits them in place to `bin/microworld-dashboard/`;
  Step 2 moves the files and adds the extra `..`; each step's Do-NOT-touch
  list names the other's surface).
- CHK5: Is "the index is accurate" backed by a runnable check, or only by
  "the file exists"? — FAIL (ambiguous) — revised in place: Step 4 criterion 2
  now extracts every backticked path from the index and asserts each resolves,
  with an explicit `test -s` guard so an index claiming zero checkable paths
  fails rather than passing vacuously.
- CHK6: Does the plan state whether the adapter mirrors are in scope for
  Step 3, and is that claim verified rather than assumed? — PASS (Context
  records the zero-hit grep; Step 3 criterion 3 re-runs it as a precondition
  with an explicit stop-and-escalate branch if the premise has changed).
- CHK7: Does the plan introduce terminology that diverges from `CONTEXT.md`?
  — PASS, with advisory findings from the `ubiquitous-language` prose check
  (advisory only, non-blocking): **Lens 1 (redefined term)** — none found;
  every glossary term this plan uses (**Microworld dashboard**, **Microworld
  bundle**, **Consumed interface**, **Reporter**, **Microworld audit log**,
  **Bundle source**, **D5 browser client**) is used with its canonical
  meaning. **Lens 2 (new synonym)** — one risk: "the dashboard directory" and
  "the silo" could each become loose synonyms for `bin/microworld-dashboard/`,
  which the **Microworld dashboard** entry's own `_Avoid_:` line already warns
  against for "the dashboard"; Step 6 carries an `_Avoid_:` line for the new
  entry. **Lens 3 (undefined load-bearing term)** — **microworld silo** is new
  and load-bearing; routed to `scribe` in Step 6 rather than left implicit.
- CHK8: Does the plan give `task-master` what it needs to set the model tag,
  and is the FAIL-history claim stated precisely enough to be checkable? —
  PASS (R3 and "Note for task-master" name the six `.fail` unit ids
  individually and name the three units that have none, rather than asserting
  a blanket "every step FAILed").
- CHK9: Is every step's completion observable without reading prose — i.e.
  does each step carry at least one criterion that is `0`/non-zero today and
  inverts after the step? — PASS (Step 1 crit 2, Step 2 crit 2, Step 3 crit 2,
  Step 4 crit 2, Step 5 crit 1, Step 6 crit 5; all six baselines measured and
  recorded in the Constitution check's P1 line).
- CHK11 (added 2026-09-04): Does every acceptance criterion in Steps 2-6 still
  have a baseline that is measurably non-inverted on today's tree? — FAIL
  (missing) — revised in place. Three criteria had gone stale in a way that
  mattered: Step 2 crit 1/2/6 expected `8` against a tree holding 14 files,
  Step 2 crit 3 cited a baseline of 8 against an actual 42, and Step 3 crit 2
  cited a baseline of 14 against an actual 2. All now re-measured and recorded
  in the Constitution check's P1 line.
- CHK12 (added 2026-09-04): Does any step assert `bash tests/validate.sh`
  exit 0 while also containing an edit that guarantees it exits 1? — FAIL
  (conflicting) — revised in place, twice. Step 3 edited a mirrored source
  without its mirror or hash (R7); Step 2 rewrote `tests/validate.sh`
  registrations without `tests/watch-map.json`'s matching token (R8). Both
  steps' affected-files lists, methods and criteria now cover the missing
  artifact. This is the check that a pure count-refresh would have skipped.
- CHK13 (added 2026-09-04): Would any step's scope-confinement criterion
  reject a *correct* implementation? — FAIL (conflicting) — revised in place:
  Step 2 crit 7's allowlist predated the two sibling-naming comments inside
  the moving files, so repointing them (correct, in scope) counted as
  out-of-scope drift. `tests/microworld` added to the alternation (R9). Step 3
  crit 4 was likewise widened to cover the mirror, and a new crit 7 pins the
  unit's diff to exactly three artifacts so `--force-render` cannot smuggle
  unrelated mirror drift into this commit.
- CHK14 (added 2026-09-04): Where a refreshed fact is a scope decision rather
  than a measurement, is it recorded as a question rather than silently
  applied? — PASS. The two such facts became OQ6 (out-of-family microworld
  tests) and OQ7 (`bin/` comment lines), each with a recommended default, an
  explicit statement of what the default costs, and the cheapest route to the
  alternative. The three mechanical corrections (R7, R8, R9) were applied
  without a question because they are not choices: each step's own
  `bash tests/validate.sh` criterion is unsatisfiable without them.
- CHK15 (added 2026-09-04): Does the refresh preserve the plan's Goal, step
  ordering and dependency graph? — PASS. Goal, the six steps, their order, and
  `1 → 2 → {3, 5} → 4 → 6` are untouched. Step 3 gains two artifacts and
  Step 2 gains one, but no step changed what it is *for*, no step moved, and
  no step gained or lost a dependency. The "Note for task-master" FAIL-history
  section is likewise intact and re-verified (see its 2026-09-04 addendum).
- CHK10: Is Step 4's path-resolution loop itself free of false failures on
  legitimate index prose? — FAIL (ambiguous) — revised in place: the first
  draft's pattern swept up globs (`tests/microworld-*.test.*`), brace lists,
  grep alternations and `path:line` citations and reported them as MISSING
  paths, which would have made the criterion fail on a correct index. The loop
  now filters glob/alternation metacharacters and strips a trailing
  `:<line>[-<line>]`, and Step 4 states the resulting authoring constraint
  (plain complete paths only). Both the false-failure case and the fixed loop
  were executed at authoring time; the fixed loop returns 0 on a simulated
  index of today's paths and non-zero on the post-move paths, so it
  discriminates rather than always passing.

---

## Note for task-master (carry into every unit's dispatch)

**No unit in this plan may be tagged `haiku`.** The microworld/dashboard area
has a dense FAIL history: six of its nine units carry a `.claude/reviewed/*.fail`
record — `gh315`, `gh317`, `gh318`, `gh319`, `gh320`, `gh323` — and its
documentation unit `gh138` FAILed with a 101-line defect list whose defect
class was *prose drifting from live state*, which is precisely the failure
mode Steps 4, 5 and 6 are exposed to. (`gh316`, `gh321` and `gh322` have no
`.fail` record; the claim is six of nine, not all nine.) Steps 1 and 2 look
mechanical but carry the relative-path trap in R1, which is the classic
"looks like a rename, silently disarms a test" defect.

**2026-09-04 addendum — the FAIL-history claim above was re-verified, and it
still holds exactly as written.** `gh315`, `gh317`, `gh318`, `gh319`, `gh320`
and `gh323` each still carry a `.fail` record; `gh316`, `gh321` and `gh322`
still do not; `gh138.fail` still exists. **No unit of this plan has ever been
attempted** — there is no `.pass` and no `.fail` record for any of `gh328`,
`gh329`, `gh330`, `gh331`, `gh332`, so the `sonnet` tag on each (haiku
excluded by this note, opus not independently reachable) is still correct.
Two further pieces of evidence now bear directly on Step 3 and should be
carried into its dispatch: `.claude/reviewed/mw-step3.fail` and
`.claude/reviewed/mw-step2.fail` (note N7) belong to a *different* plan
(`docs/plans/2026-08-25-microworlds-workflow-redesign.md`, whose units are
named `mw-step*`), but both record the same defect R7 now guards against —
a source edited without regenerating its managed mirror, failing the merge
gate. That defect class has already cost this repo two review cycles; Step 3
is the unit most exposed to it.

Additional dispatch notes:
- Slice as six units in the dependency order stated above
  (1 → 2 → {3, 5} → 4 → 6). Steps 3 and 5 may be dispatched in parallel.
- **Step 1 has shipped** (issue #327, closed). Only Steps 2-6 remain, which
  is five units — within the fast path, so no re-slice is required.
- Tracker label: `plan/2026-08-11-microworld-silo`, one issue per step, per
  this repo's established pattern (`[plan] Step N — …`). **No umbrella
  `[spec]` issue** — `spec-master` deliberately did not publish one; this
  document is the canonical artifact.
- Every unit's dispatch packet must record the `$BASE` SHA (see "Verification
  conventions"), since six of the criteria are `git diff` scoped to it.
- Step 6 must re-derive its ADR number at execution time from `ls docs/adr/`;
  do not copy a number out of this plan.

## Scribe update hint

After Step 6 lands: `CONTEXT.md` gains **Microworld silo**; the **Consumed
interface**, **Bundle source**, **Relocatable run.sh** and **D5 browser
client** entries carry new paths; `.claude/wiki/architecture.md`'s audit-log
contract paragraph carries new paths; a new ADR records the layout decision
and the deliberate non-rewriting of historical citations. Separately, file the
pre-existing `README.md:177` → `README.md:263` line-number drift in
`CONTEXT.md:1638`'s **Microworld dashboard** entry, noted in Risks and
deliberately left out of this plan's scope (the drift was `:204` at authoring
and has widened since — file it by *content*, and re-measure the true line
number when you do, since it will move again).

Also file, if OQ7's recommended default stands: the four stale
`tests/dashboard-*` citations in `bin/microworld-dashboard/index.html` and
`bin/microworld-dashboard/decision-block.js` comments, left stale by Step 2 on
purpose.
