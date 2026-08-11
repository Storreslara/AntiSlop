# Microworld silo — namespaced code/test directories plus a canonical index

**Status:** finalized, ready for `task-master` slicing
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

Measured against the tree at 2026-08-11 (all counts re-run at authoring time,
see the Constitution check for the P1 evidence):

**Code to move — `bin/dashboard/` (7 files):**
`audit-log.js`, `discover.js`, `feedback-block.js`, `index.html`,
`invoke.js`, `server.js`, `source.js`.

**Tests to move — 8 files, two naming families:**
`tests/dashboard-client.test.js`, `tests/dashboard-feedback.test.js`,
`tests/dashboard-invoke.test.js`, `tests/dashboard-notebook.test.js`,
`tests/dashboard-packets.test.js`, `tests/dashboard-server.test.js`,
`tests/microworld-audit-contract.test.js`, `tests/microworld-rerun.test.sh`.

**Referrers to `bin/dashboard/` in live code (14 grep hits across `bin/`,
`tests/`, `hooks/`):**

| Referrer | Nature |
|---|---|
| `bin/cli.js:2161` | `require('./dashboard/server')` — the only production require |
| `bin/dashboard/feedback-block.js:9` | self-referential header comment naming `bin/dashboard/server.js` |
| `hooks/scripts/microworld-rerun.sh:10-11` | **consumed-interface** header naming `bin/dashboard/audit-log.js` and `tests/microworld-audit-contract.test.js` |
| 7 test files | `require('../bin/dashboard/…')` |
| `tests/dashboard-client.test.js:40`, `tests/dashboard-notebook.test.js:73` | `fs.readFileSync(path.join(REPO_ROOT, 'bin/dashboard/index.html'))` |

**Relative-path assumptions that break when tests move down one level:**
7 Node tests compute `const REPO_ROOT = path.resolve(__dirname, '..')`;
`tests/microworld-rerun.test.sh:8` does `cd "$(dirname "$0")/.."`. All eight
need one more `..`.

**`tests/validate.sh`:** 8 registration blocks name these paths
(lines ~259, ~268, ~423, ~432, ~441, ~450, ~459, ~468).

**Living docs referencing the old paths (5 lines):** `CONTEXT.md:102`
(**Consumed interface** entry), `:601` (**Relocatable run.sh** entry, names
`tests/microworld-rerun.test.sh`), `:791` and `:798` (**Bundle source**
entry), `:850` (**D5 browser client** entry); `.claude/wiki/architecture.md:105`
(the audit-log contract paragraph, which names four old paths in one line).

**Deliberately NOT touched (historical record — OQ3):** `CHANGELOG.md`'s
existing entries, `.claude/wiki/changelog.md`'s existing entries,
everything under `docs/plans/`, everything under `docs/adr/`. Those cite
paths as they were at the time and are evidence, not documentation.

**Facts that make this cheaper than it looks:**
- `package.json`'s `files` array lists `bin` (the directory), not
  `bin/dashboard`, so packaging needs no change. Verified: `npm pack
  --dry-run --json` currently lists 7 `bin/dashboard/` paths.
- `tests/validate.sh`'s npm-pack composition check asserts
  `included = ['agents/','hooks/','templates/','skills/']` — it does not name
  `bin/`, so it is indifferent to this rename.
- The two adapter mirrors (`adapters/codex/hooks/scripts/microworld-rerun.sh`,
  `adapters/cursor/hooks/scripts/microworld-rerun.sh`) have **their own**
  header prose and do **not** contain the `bin/dashboard/audit-log.js` line.
  Verified by grep: zero hits for `bin/dashboard|tests/dashboard|tests/microworld`
  anywhere under `adapters/`. This plan therefore does **not** trip the
  "never gate a source edit apart from its shipped copy" trap — but see R5.
- No file this plan edits is version-stamped (`grep -rln "antislop v"
  hooks/scripts/` returns nothing; no `agents/*.md` or template is touched).

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
- **R5 — adapter-mirror parity is NOT at risk here, but only because the
  mirrors happen not to carry the affected lines.** This was verified, not
  assumed (`grep -rn "bin/dashboard|tests/dashboard|tests/microworld"
  adapters/` → zero hits). If a future unit adds the consumed-interface
  header to the mirrors, Step 3 becomes a three-file unit. Any executing
  persona should re-run that grep rather than trusting this line.
- **R6 — scope creep into the dashboard's behaviour.** This plan renames and
  documents; it changes no logic. Any diff hunk inside a moved file that is
  not a path string, a `require`, a `__dirname` walk, or a comment naming a
  moved path is out of scope.
- **Pre-existing drift observed, deliberately out of scope:** `CONTEXT.md`'s
  **Microworld dashboard** entry cites `README.md:177` for the dashboard
  section, which actually begins at `README.md:204`. Not caused by this plan
  and not fixed by it (fixing unrelated drift inside a rename unit is how
  rename units grow teeth). Flagged here so `scribe` can file it separately.
- **Dependency order:** Step 1 → Step 2 → {Step 3, Step 5} → Step 4 → Step 6.
  Steps 3 and 5 are independent of each other and may run in either order or
  in parallel, but both name final paths and so must follow Steps 1 and 2.
  Step 4's index names every final path, so it follows Steps 1-3. Step 6 is
  the institutional record and is last.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every acceptance grep authored below
  was executed against the tree at authoring time and returned a non-vacuous
  baseline: `grep -rn "bin/dashboard" bin/ tests/ hooks/` = **14**;
  `ls tests/ | grep -cE "^(dashboard-|microworld-)"` = **8**;
  `grep -rn "bin/dashboard" CONTEXT.md .claude/wiki/architecture.md
  .claude/wiki/conventions.md README.md` = **5**; `docs/microworld/` does not
  exist; `npm pack --dry-run --json` lists **7** `bin/dashboard/` paths and
  **0** `bin/microworld-dashboard/` paths. Each must read **0** (or, for
  npm pack, invert to 0 and 7) after the corresponding step, so no criterion
  in this plan can pass by accident on the pre-change tree.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no
  `--update`, `--wire-*-mcp`, `fileHashes` or backfill path is touched. The
  single edit to `bin/cli.js` is one `require` string at `:2161`, which is not
  a script-driven path.
- P3 "Version-stamp discipline": satisfied — the MUST is not triggered, since
  no `agents/*.md` and no template is edited and no file in scope carries an
  `<!-- antislop vX.Y.Z -->` stamp (verified by grep). Step 6 nevertheless
  bumps `.claude-plugin/plugin.json` and adds a `CHANGELOG.md` entry, per this
  repo's standing release convention.
- P4 "Optional personas degrade gracefully": satisfied — no shared persona
  prose, no `templates/persona-protocol.md`, no `agents/*.md` is edited.
- P5 "`tests/validate.sh` is the merge gate": satisfied — `bash
  tests/validate.sh` exit 0 is an acceptance criterion on all six steps, and
  Step 2 additionally edits the gate itself and must leave all 8 relocated
  registrations executing.

---

## Step 1 — Relocate the dashboard module tree to `bin/microworld-dashboard/`

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

Move all eight test files one level down and fix the two things that always
break on such a move: the tests' own repo-root walks, and the gate's
registrations.

**Affected files**
- `tests/dashboard-{client,feedback,invoke,notebook,packets,server}.test.js`,
  `tests/microworld-audit-contract.test.js`,
  `tests/microworld-rerun.test.sh` → `tests/microworld/` (via `git mv`)
- Inside the 7 Node tests: `path.resolve(__dirname, '..')` →
  `path.resolve(__dirname, '..', '..')`, and `require('../bin/…')` →
  `require('../../bin/…')`
- Inside `tests/microworld/microworld-rerun.test.sh`: `cd "$(dirname "$0")/.."`
  → `cd "$(dirname "$0")/../.."`
- `tests/validate.sh`: the 8 registration blocks' invocation paths

**Naming:** keep each file's basename as-is inside the new directory
(`tests/microworld/dashboard-server.test.js`, not
`tests/microworld/server.test.js`). Stripping the prefix would break every
CHANGELOG and `.claude/wiki/changelog.md` citation's *basename* as well as its
path, and this plan's whole point is to preserve the historical record.

**Do NOT touch:** `bin/`, `hooks/`, `adapters/`, `CONTEXT.md`,
`.claude/wiki/`, `README.md`, `docs/`. No assertion, fixture, or test case may
be added, removed, or reworded — this step moves files and fixes paths only.

**Acceptance criteria**
1. `bash tests/validate.sh` exits 0, and its output contains all 8 `OK`
   lines for the relocated files:
   `bash tests/validate.sh | grep -c "OK   tests/microworld/"` → `8`.
2. `ls tests/ | grep -cE "^(dashboard-|microworld-)"` → `0` (baseline 8);
   `ls tests/microworld/ | wc -l` → `8`.
3. `grep -rn "tests/dashboard-\|tests/microworld-" tests/validate.sh | wc -l`
   → `0`.
4. Repo-root canary: `node tests/microworld/dashboard-client.test.js` and
   `node tests/microworld/dashboard-notebook.test.js` each exit 0 when run
   directly from the repo root. Both read
   `bin/microworld-dashboard/index.html` through `REPO_ROOT` and fail hard on
   a wrong root, so a green run here is the proof that the `..` fix landed.
5. Bash-test root canary: `bash tests/microworld/microworld-rerun.test.sh`
   exits 0 when invoked from the repo root **and** from `tests/microworld/`
   (`cd tests/microworld && bash ./microworld-rerun.test.sh`) — the second
   invocation is what proves the `cd "$(dirname "$0")/../.."` is correct
   rather than accidentally working from one cwd.
6. Rename detection: `git diff --stat -M --summary "$BASE"..HEAD -- tests/ |
   grep -c "^ rename "` → `8`.
7. No test-content drift: for each moved file, the diff touches only
   `require`/`__dirname`/`cd` lines. Machine check —
   `git diff -M "$BASE"..HEAD -- tests/microworld/ | grep -E "^[+-]" |
   grep -vE "^(\+\+\+|---)" | grep -vcE "(require\(|__dirname|dirname \"\\$0\"|bin/microworld-dashboard)"`
   → `0`.

---

## Step 3 — Repoint the reporter hook's consumed-interface header

`hooks/scripts/microworld-rerun.sh:10-11` documents the audit-log line format
as a **Consumed interface** and names both sides of that contract by path.
Both names are now wrong. This is live protocol prose in a hook header, not a
historical citation, so it is in scope.

**Affected files**
- `hooks/scripts/microworld-rerun.sh` (header comment only, lines ~10-11)

**Do NOT touch:** the hook's logic (below `set -euo pipefail`), the two
adapter mirrors (verified to not carry these lines — but re-run the grep in
criterion 3 before concluding that), `tests/`, `bin/`, `docs/`.

**Acceptance criteria**
1. `grep -c "bin/microworld-dashboard/audit-log.js" hooks/scripts/microworld-rerun.sh`
   → `1`; `grep -c "tests/microworld/microworld-audit-contract.test.js"
   hooks/scripts/microworld-rerun.sh` → `1`.
2. `grep -rn "bin/dashboard\|tests/dashboard-\|tests/microworld-audit" hooks/ | wc -l`
   → `0`.
3. Mirror-parity precondition re-verified, not assumed:
   `grep -rn "bin/dashboard\|bin/microworld-dashboard\|tests/dashboard\|tests/microworld" adapters/ | wc -l`
   → `0`. If this is **not** 0, stop and escalate — the unit's scope was
   computed on a stale premise and must grow to include both mirrors in the
   same commit (never gate a source edit apart from its shipped copy).
4. Logic untouched: `git diff "$BASE"..HEAD --
   hooks/scripts/microworld-rerun.sh | grep -E "^[+-]" |
   grep -vE "^(\+\+\+|---)" | grep -vc "^[+-]#"` → `0` (every changed line is
   a comment line).
5. `bash tests/validate.sh` exits 0, and
   `bash tests/microworld/microworld-audit-contract.test.js`'s registration
   still passes — the contract test executes the real hook, so a header edit
   that accidentally broke the script would surface here.

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
- `tests/microworld/` — all eight tests, with a one-line note that
  `microworld-audit-contract.test.js` is the cross-language contract test
  binding the bash hook to the Node parser.
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

**Affected files**
- `CONTEXT.md` — lines ~102 (**Consumed interface**), ~601 (**Relocatable
  run.sh**, names `tests/microworld-rerun.test.sh`), ~791 and ~798 (**Bundle
  source**), ~850 (**D5 browser client**). Also `:105`'s
  `tests/microworld-audit-contract.test.js` citation.
- `.claude/wiki/architecture.md` — line ~105, the audit-log contract
  paragraph, which names `bin/dashboard/audit-log.js`,
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
   .claude/wiki/conventions.md README.md | wc -l` → `0` (baseline 5).
2. `grep -rn "tests/dashboard-\|tests/microworld-rerun.test.sh\|tests/microworld-audit-contract.test.js"
   CONTEXT.md .claude/wiki/architecture.md | wc -l` → `0`, and the new paths
   are present: `grep -c "tests/microworld/" CONTEXT.md` ≥ `2`,
   `grep -c "tests/microworld/" .claude/wiki/architecture.md` ≥ `1`.
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
  backfilled.
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

None outstanding. OQ1 and OQ2 were answered by the user (recorded in
Clarifications); OQ3, OQ4 and OQ5 resolved to their recommended defaults and
publishing surfaced no conflict with that resolution:

- **OQ3 (rewrite historical citations?) → no.** Reconfirmed at finalization:
  OQ1's answer makes the canonical index (`docs/microworld/README.md`) the
  place a reader goes for current paths, which is exactly what makes leaving
  historical citations alone safe rather than merely cheap.
- **OQ4 (directory name?) → `bin/microworld-dashboard/`.** Reconfirmed:
  `package.json`'s `files` lists the `bin` directory, not any child, so the
  name is packaging-neutral; and `tests/microworld/` + `bin/microworld-dashboard/`
  read as one family under a `microworld` grep, which is the Goal.
- **OQ5 (move the hook?) → no.** Reconfirmed, and now with a stronger reason
  than at drafting: the hook has two adapter mirrors under `adapters/codex/`
  and `adapters/cursor/` that cannot move with it, so relocating the canonical
  copy would *increase* the scatter it was meant to reduce.

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

Additional dispatch notes:
- Slice as six units in the dependency order stated above
  (1 → 2 → {3, 5} → 4 → 6). Steps 3 and 5 may be dispatched in parallel.
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
pre-existing `README.md:177` → `README.md:204` line-number drift in
`CONTEXT.md`'s **Microworld dashboard** entry, noted in Risks and deliberately
left out of this plan's scope.
