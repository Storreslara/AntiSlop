# Final cleanup stage after the rubric-gated haiku programme and its hardening (2026-10-07)

Status: FINAL (standard path, 5 units, so task-master slices them). This is the
**last** cleanup stage. Findings after it go to the backlog table at the end of
this plan, not to another stage, unless the user asks for one.

Parents (cited, not restated):
- `docs/plans/2026-10-06-rubric-gated-haiku-programme.md` (Stages 0-3 done;
  Stages 4-5 gated: live `G3 closed: rubric_era=13 scored7=10`);
- `docs/plans/2026-10-06-contract-hardening.md` (14 units, all PASSed; gate HG
  passed at bceefd5, version 0.31.138).

This plan touches no Stage 4/5 text or gate.

## Goal

task-master does all the thinking; lead-programmer and scribe (target tier:
haiku) only follow orders. Close the leftovers that still leave a decision to an
implementer, or that let a check pass vacuously. Park the rest with a reason.

| Goal clause | Unit | Criteria |
|---|---|---|
| Scorer and exporter checks can no longer pass vacuously (A, B) | fc-1 | AC-fc1.* |
| task-master's contracts and the orchestrator's routing leave nothing to infer (D, E, P1-P5) | fc-2 | AC-fc2.* |
| lead-programmer, its ports, scribe and spec-master have no remaining judgment gaps (C, F) | fc-3 | AC-fc3.* |
| The invariants that matter are pinned by tests (G, plus D/E presence) | fc-4 | AC-fc4.* |
| The glossary matches the shipped text, edited once, last (H, P3) | fc-5 | AC-fc5.* |

## Context: evidence at bceefd5 (each claim re-verified)

- **A.**
  - tests/contract-score.test.js:191-196 asserts only `v1 < 7` for the
    generated CRLF input (v1 measures 4).
  - bin/contract-score.js:315-316 (`r6v2`) accepts `[-*+]` bullets, and no
    fixture uses `+`.
- **B.** scripts/unit-outcomes.js:
  - :260-264 `rubricVersion`: an unparseable `contract_ts` gives
    `Date.parse` = NaN, so `NaN <= x` is false and it returns `'v2'`;
  - :269-270 `h2Pass` comes from `terminalOf(…, opt.cutoff)`, but no test pins
    the cutoff filter;
  - :290 counts per `rubric_version`.

  tests/unit-outcomes.test.js:318-339 `stubDir`/`rvSet` call `rmSync` only on
  the success path.
- **C.** agents/spec-master.md:
  - :159 `git show --name-only <final_commit>` also prints the commit header and
    only the PASS commit's files. Unit `262` (fail classes scope, host;
    `baseline: null`) lists only `.claude/agent-memory/task-master/feedback_reviewed_path_bash_blocked.md`.
  - Unit `item19-2-measure-skip-rate` (class vacuous) has `final_commit: null`
    in the committed snapshot.
  - :160-161 "citing every matching criterion" sits beside a single-`<ACn>`
    template, and "the mutation recorded for <unit-id>" names a field the export
    lacks.
  - :277-278 "finding id" has no source.
- **D.** agents/task-master.md:
  - :100-101 gives only the `SPEC-GAP:` prefix; :377 gives the full shape
    `SPEC-GAP: <unit-id> <what is missing>` (count 1 now).
  - :65-66 `git status --porcelain -- .claude` also lists untracked
    non-ignored files.
  - :92-93 "a line naming that gap's ruling" is not a literal.
  - :177 "The template's only blanks are `<FILL: ...>`" does not require one
    blank per criterion.
  - The scribe contract has no fixed heading. orchestrator.md:52-53 selects
    "the `## Dispatch contract` heading that names scribe".
  - tests/contract-examples.test.js does not detect reverting H12's E3 (anchor
    form) or E6 (separate `proof:` line): both examples still score 7.
- **E.** agents/orchestrator.md:
  - :205-212 says nothing about a report that starts with neither `Unit:` nor
    `SPEC-GAP:`;
  - :116 ends "No hook enforces this." directly above :118 "Gate:
    `dispatch-hygiene.sh`. Escape hatch:", which now reads as covering all four
    items.
- **F.**
  - agents/lead-programmer.md:78-79, and both ports: "Spawn `researcher` …
    otherwise use WebSearch yourself" has no contract carve-out.
  - agents/lead-programmer.md:98: "add that entry yourself if you haven't" has
    no carve-out (the ports lack that text).
  - agents/scribe.md: "a close condition that does not hold" is a STOP, but
    :118 makes an already-closed issue a silent no-op.
  - agents/scribe.md:48 "must be fixed before you finish" has no carve-out.
- **G.** tests/writer-tier-consistency.test.js:
  - :137 `/^maxTurns: 120$/m` matches anywhere in the file;
  - :141-145 `contractPrecedence` uses `findIndex` with no uniqueness assert;
  - :64-67 AC-D6 scans only the three `agents/` files.
- **H.** docs/harness-glossary.md:
  - :707-713 **shared file** cites only **Shared file, defined**;
  - :665-667 **contract score** opens "R1-R7 lead / S1-S5 scribe" (v1 only);
  - :715-718 **umbrella issue** says sliced units "name as their parent", which
    the cited bullet does not say;
  - :1804 cites `agents/orchestrator.md:137`.
- **P4.** hooks/scripts/version-stamp-check.sh:7 "exit 0 always": stdout alone
  decides.
- **P5.** Scribe commit trailers drift: bf19ad7 and c7aa4bc carry "Claude
  Haiku 4.5", while a4934c2 and 783d9fb carry none (measured with
  `git log --format='%(trailers:key=Co-Authored-By)'`).

## Process rules for every fc contract (lessons P1-P5)

- **P1.** A range criterion (scope, subjects, version-stamp-check, trailers)
  ends at the unit's own last commit,
  `U=$(git log --format=%H -F --grep='(<unit-id>)' | head -1)`, and runs over
  `<B>..$U`, never `<B>..HEAD`.
- **P2.** A red-set criterion over a test file that runs git
  (`tests/unit-outcomes.test.js`) runs in `git worktree add --detach`, never a
  `git archive` extract (ruling H-M).
- **P3.** fc-5 is the only unit that edits `docs/harness-glossary.md`.
  - Scribe close-outs for fc-1..fc-4 make no glossary edits. Their glossary
    findings are batched into fc-5.
  - fc-5's before-texts are re-measured at the HEAD where fc-5 is filed.
- **P4.** `version-stamp-check.sh` exits 0 even on `violation` and reads only
  plugin.json.
  - Criteria check its stdout `version-stamp-check: ok`, never its exit code.
  - package.json is checked by the version-sync check (hardening plan rule B2).
- **P5.**
  - Every contract carries the exact `Co-Authored-By:` trailer line given by the
    orchestrator's dispatch attribution rule.
  - A criterion checks it: `git log --format=%B <B>..$U | /usr/bin/grep -cxF '<trailer line>'`
    equals the unit's commit count.
- **validate.sh:** units run the targeted checks below. One full
  `bash tests/validate.sh` runs at gate **FG** (stage end, main session,
  output to a file, real exit code read from it), as in the hardening plan's
  rule B6.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-10-07 Edge cases / failure handling: Q what should the orchestrator do with a task-master report that starts with neither `Unit:` nor `SPEC-GAP:`? → A (self-resolved): treat it as a spec gap, the fail-closed direction
- 2026-10-07 Technical constraints & tradeoffs: Q should the v1 scribe shape gain the missing rows? → A (self-resolved): no. v1 is frozen, because G3 scores v1-era contracts with it, so a change would rewrite G3 history; parked
- 2026-10-07 Technical constraints & tradeoffs: Q how many units, given each persona unit's cost? → A (self-resolved): 5. Two persona units (fc-2 bundles task-master and orchestrator; fc-3 bundles lead-programmer with its ports, scribe and spec-master), plus three non-persona units

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every before-text and count was measured at bceefd5.
- P2 "Prefer deterministic scripts": satisfied. Mirrors change only via `node bin/cli.js --update`.
- P3 "Version-stamp discipline": satisfied. fc-2 (0.31.139) and fc-3 (0.31.140) bump plugin.json and package.json and add a CHANGELOG entry in the same commit.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. The new orchestrator and scribe text keeps the "if … present" phrasing.
- P5 "tests/validate.sh is the merge gate": satisfied via gate FG.

## Units (dispatch order)

| Order | Unit | Scope | Version |
|---|---|---|---|
| 1 | fc-1 | scorer and exporter tests and the NaN fix (A, B) | none |
| 2 | fc-2 | `agents/task-master.md` and `agents/orchestrator.md` (D, E, P1-P5 rules) | 0.31.139 |
| 3 | fc-3 | `agents/lead-programmer.md` with both ports, `agents/scribe.md`, `agents/spec-master.md` (C, F) | 0.31.140 |
| 4 | fc-4 | invariant tests (G; presence pins for fc-2/fc-3 text) | none |
| 5 | fc-5 | glossary, last (H, plus batched glossary findings) | none |

- fc-1 may interleave anywhere.
- fc-4 depends on fc-2 and fc-3, because it pins their text.
- fc-5 depends on fc-1 through fc-4 (P3).

Persona units follow the hardening plan's **Persona-unit scope rule**
(AC-SCOPE-1/2/3) with the end commit bound per P1. "Flattened grep" means
`tr '\n' ' ' < F | tr -s ' ' | /usr/bin/grep -oF '<p>' | wc -l`. Every "now"
count below was measured at bceefd5.

### fc-1: tool tests and the NaN fix (non-persona)
- **Files:** `tests/contract-score.test.js`, `scripts/unit-outcomes.js`,
  `tests/unit-outcomes.test.js`, and fixtures.
- **Commits:** red `test(fc-1): … (#<issue>)`, then green `fix(fc-1): … (#<issue>)`.
- **A1:** the `v2-crlf` check asserts `v1 === 4` (the measured value) instead
  of `v1 < 7`.
- **A2:** a new fixture `v2-r6-plus.md` is `v2-all-pass.md` with its two Do NOT
  touch bullets marked `+`. Check `v2-r6-plus` asserts R6 true.
- **B1 (code):** `rubricVersion` returns `null` when `Date.parse(contractTs)` is
  NaN. With that, `gateG3`'s `inEra` (NaN > x is false) excludes such a row, so
  the :290 fallback for a null `rubric_version` in the era is unreachable; a test
  pins it.
- **B2 (tests):** new `rvSet` cases:
  - `rv-h2-after-cutoff`: `rgh-h2`'s PASS is after `--until`, so a post-PASS
    contract is `v1`;
  - `rv-equal-boundary`: `contract_ts` equal to `rgh-h2`'s `pass_ts` is `v1`;
  - `rv-nan`: an unparseable `contract_ts` gives `rubric_version` null, and the
    row is not counted in `rubric_era`.
- **B3 (tests):** `stubDir`/`rvSet` wrap the run in `try { … } finally { fs.rmSync(dir, { recursive: true, force: true }); }`.
- **Acceptance criteria:**
  - AC-fc1.1 `node tests/contract-score.test.js` exits 0, and `node tests/unit-outcomes.test.js` exits 0.
  - AC-fc1.2 Mutations, run by the implementer in a scratch copy, each naming the failing check:
    - normalise CRLF also under v1 → `v2-crlf` fails;
    - `[-*+]` becomes `[-*]` in `r6v2` → `v2-r6-plus` fails;
    - drop the cutoff argument from `h2Pass`'s `terminalOf` → `rv-h2-after-cutoff` fails;
    - `<=` becomes `<` in `rubricVersion` → `rv-equal-boundary` fails;
    - remove the NaN guard → `rv-nan` fails.
  - AC-fc1.3 Red set (P2, worktree form): at the red commit exactly the new checks whose behaviour does not exist yet fail. The contract lists them by name, measured by task-master at filing.
  - AC-fc1.4 `git diff --name-only <B>..$U` lists only the files above.
  - AC-fc1.5 P1 subjects and P5 trailer checks.
- **Parked:** the double scorer spawn in `scoreOf` (cost only).

### fc-2: task-master and orchestrator (`agents/task-master.md`, `agents/orchestrator.md`, 0.31.139)
- **OWN:** both files.
- **Commit subject:** `feat(fc-2): … (0.31.139) (#<issue>)`.
- **Edits.** Each before-text was measured once (flattened) at bceefd5, and
  every added phrase is 0 there unless stated.

| # | File | Before | After |
|---|---|---|---|
| D1 | task-master | ``contract and reports a spec gap; the report's first line starts with `SPEC-GAP:`. A fix`` | ``contract and reports a spec gap; the report's first line starts with `SPEC-GAP: <unit-id> <what is missing>`. A fix`` |
| D2 | task-master | ``listed by `git status --porcelain -- .claude` right after running it.`` | ``listed by `git status --porcelain --untracked-files=no -- .claude` right after running it.`` |
| D3 | task-master | `the umbrella issue's body has a line naming that gap's ruling, which spec-master adds per ruling` | ``the umbrella issue's body has a line starting `- <ruling-id>:` for that gap (for example `- H-K:`), which spec-master adds per ruling`` |
| D4 | task-master | ``The template's only blanks are `<FILL: ...>`, for observed results`` | ``The template has exactly one `criterion N: <FILL: exit and stdout>` line per acceptance criterion, and its only blanks are `<FILL: ...>`, for observed results`` |
| D5 | task-master | `Score it with` (in **Scribe dispatch contract**; count 1) | ``In the issue body it sits under the heading `## Dispatch contract (scribe)`, exactly. Score it with`` |
| D6 | task-master | `**Version derivation.**` (count 1) | ``**Range criteria.** A criterion over a commit range binds its end to the unit's own last commit, `git log --format=%H -F --grep='(<unit-id>)' \| head -1`, never `HEAD`. A red-set criterion over a test file that runs git uses a `git worktree add --detach` checkout, never a `git archive` extract. `version-stamp-check.sh` exits 0 even on `violation`: check its stdout. Each `commit-message:` is followed by the exact trailer line the dispatch gives, and a criterion greps it.`` followed by a blank line and then `**Version derivation.**` |
| E1 | orchestrator | `the cap count is unchanged.` (count 1) | ``the cap count is unchanged. A report that starts with neither `Unit:` nor `SPEC-GAP:` is treated as a spec gap.`` |
| E2 | orchestrator | ``Gate: `dispatch-hygiene.sh`. Escape hatch:`` | ``Gate for item 3: `dispatch-hygiene.sh`. Escape hatch:`` |
| E3 | orchestrator | ``Dispatch contract` heading that names scribe,`` | ``Dispatch contract (scribe)` heading,`` |

- **Acceptance criteria:**
  - AC-fc2.1 Flattened greps in `agents/task-master.md`:
    - `SPEC-GAP: <unit-id> <what is missing>` prints 2 (1 now);
    - each of `--untracked-files=no -- .claude`, ``line starting `- <ruling-id>:` ``, `` exactly one `criterion N: <FILL: ``, `## Dispatch contract (scribe)` and `**Range criteria.**` prints 1 (0 now).
  - AC-fc2.2 Flattened greps in `agents/orchestrator.md`: `starts with neither`, `Gate for item 3` and `## Dispatch contract (scribe)` each print 1 (0 now), and `heading that names scribe` prints 0 (1 now).
  - AC-fc2.3 The mirrors give the same results.
  - AC-fc2.4 Guardrails:
    - `node tests/writer-tier-consistency.test.js` exits 0, and `node tests/contract-examples.test.js` exits 0;
    - the hardening plan's AC-H13.4 diff-grep (2-FAIL cap, Sonnet ladder, `fable` line, milestone audit gate) over `<B>..$U` prints 0.
  - AC-fc2.5 Persona baseline with P1 binding, version-sync, and P4 stdout `version-stamp-check: ok`.

### fc-3: lead-programmer (and its ports), scribe, spec-master (0.31.140)
- **OWN:** `agents/lead-programmer.md`, `agents/scribe.md`, `agents/spec-master.md`.
- **Extra:** `adapters/cursor/agents/lead-programmer.md` and `adapters/codex/agents/lead-programmer.toml` (hand-edited, same commit).

| # | File(s) | Before | After |
|---|---|---|---|
| F1 | lead + both ports (count 1/1/1) | ``- Spawn `researcher` when you need to understand a technique rather than guessing,`` | ``- Spawn `researcher` (not under a dispatch contract) when you need to understand a technique rather than guessing,`` |
| F2 | lead source only (ports lack it) | `add that entry yourself if you haven't` | `add that entry yourself if you haven't (under a dispatch contract the contract's CHANGELOG edit is that entry; if it is missing, STOP and report a spec gap)` |
| F3 | scribe | `a close condition that does not hold.` | `a close condition that does not hold (an issue that is already closed is not a failed condition: closing it is the silent no-op described below).` |
| F4 | scribe | `missing and must be fixed before you finish;` | `missing and must be fixed before you finish (under a scribe dispatch contract, STOP and report a spec gap instead);` |
| C1 | spec-master | ``list its files with `git show --name-only <final_commit>`, and add one CHK item per step whose affected files intersect them, citing every matching criterion: "Does criterion <ACn> still fail under the mutation recorded for <unit-id>?"`` | ``list its files with `git diff --name-only <baseline>..<final_commit>` when the export has `baseline`, else `git show --name-only --format= <final_commit>` (a unit whose `final_commit` is null lists no files and adds no item), and add one CHK item per criterion whose `run:` names an intersecting file: "Does criterion <ACn> still fail under its own `mutation:` line, given <unit-id>'s recorded class <class>?"`` |
| C2 | spec-master | `with the columns finding id, finding,` | `with the columns finding id (the milestone-auditor report's finding number, or F1, F2, … in report order when it has none), finding,` |

- **Acceptance criteria:**
  - AC-fc3.1 Flattened greps:
    - `(not under a dispatch contract) when you need` prints 1 in all three lead-programmer files;
    - `the contract's CHANGELOG edit is that entry` prints 1 in the source;
    - `an issue that is already closed is not a failed condition` and `(under a scribe dispatch contract, STOP and report a spec gap instead)` print 1 in scribe;
    - in spec-master, `git diff --name-only <baseline>..<final_commit>`, `whose \`final_commit\` is null lists no files` and `F1, F2, … in report order` print 1, and `the mutation recorded for <unit-id>` prints 0 (1 now).
  - AC-fc3.2 The mirrors match the sources.
  - AC-fc3.3 Guardrails: `node tests/writer-tier-consistency.test.js` exits 0 (AC-A1 parity holds because F1 is identical in all three), `node tests/adapter-protocol-parity.test.js` exits 0, and `sed -n '1,12p' agents/scribe.md | /usr/bin/grep -c '^model: haiku$'` prints 1.
  - AC-fc3.4 Persona baseline as in fc-2.

### fc-4: invariant tests (non-persona)
- **Files:** `tests/writer-tier-consistency.test.js`, `tests/contract-examples.test.js`.
- **Depends on:** fc-2 and fc-3.
- **Commits:** red `test(fc-4): …`, then green if any check needs a code-free
  fix; otherwise a single `test(fc-4): …` commit with every new check green and
  its mutation proven.
- **Changes to tests/writer-tier-consistency.test.js:**
  - **G1:** AC-T1 matches `maxTurns: 120` only inside the frontmatter, via a
    `frontmatterKey(text, 'maxTurns')` helper shaped like `frontmatterModel`.
  - **G2:** `contractPrecedence` asserts that exactly one line starts with
    `- **Contract precedence.**`.
  - **G3:** AC-D6 also scans both lead-programmer ports and the `.claude/agents/`
    mirrors of the three files; AC-A1 also compares
    `.claude/agents/lead-programmer.md`.
  - **G4:** new presence checks, using whitespace-stripped matching (strip-all,
    per the item06-3 NOTE[spec] convention):
    - **AC-P1:** orchestrator.md contains `At the 2-FAIL cap`, `Sonnet units
      escalate on first FAIL`, ``**`fable` is excluded for `task-master`**``,
      `## Milestone audit gate`, `starts with neither` and `Gate for item 3`.
    - **AC-P2:** task-master.md contains each of the nine contract headings
      (`Unit:` plus the eight `## …` element names) that `dispatch-hygiene.sh`
      H4 checks.
    - **AC-P3:** scribe.md contains `**Contract-only doc edits.**`, and
      lead-programmer.md contains `- **Contract precedence.**`.
- **Change to tests/contract-examples.test.js:**
  - **D7:** assert that the lead example's anchors all use
    `anchor: line matching`, and that the scribe example has a separate
    `   proof:` line.
- **Acceptance criteria:**
  - AC-fc4.1 Both test files exit 0.
  - AC-fc4.2 Mutations, run by the implementer, each naming the failing check:
    - append a second `- **Contract precedence.**` bullet to a scratch copy of a port → G2 fails;
    - put `maxTurns: 120` in a body line while the frontmatter says 40 → AC-T1 fails;
    - split "looks mechanical" across lines in a scratch copy of a port → AC-D6 fails;
    - delete `## Milestone audit gate` → AC-P1 fails;
    - revert one example anchor to `heading` → D7 fails;
    - merge the scribe example's `proof:` into its `mutation:` line → D7 fails.
  - AC-fc4.3 `git diff --name-only <B>..$U` lists only the two test files; P1 and P5 checks.
- **Parked:** the one-byte spacing at :67 (no behavioural effect).

### fc-5: glossary, last (scribe contract, non-persona)
- **File:** `docs/harness-glossary.md` only (P3).
- **Filing rule:** before-texts are re-measured at the HEAD where fc-5 is filed.
  The texts below were measured at bceefd5, and task-master re-confirms each is
  unique at filing.
- **Edits:**
  - **H1:** in **shared file**, ``Defined in `agents/task-master.md` bullet **Shared file, defined**.`` becomes ``Defined in `agents/task-master.md` bullets **Shared file, defined** and **Shared-file siblings** (the `Depends on` edge).``
  - **H2:** in **contract score**, `— the R1-R7 lead / S1-S5 scribe rubric score` becomes `— the R1-R7 lead / S1-S5 scribe (v1) rubric score`.
  - **H3:** in **umbrella issue**, ``— the spec's `[spec]` PRD issue that the sliced units name as their parent.`` becomes ``— the issue task-master posts the `Slice state:` table to as a comment, and whose body names each gap's ruling (one line starting `- <ruling-id>:` per ruling).``
  - **H4:** `` `agents/orchestrator.md:137` `` (in **gh-304 dual-marker incident**) becomes `` `agents/orchestrator.md` **Reviewer re-tasking discipline** (in **Review routing**) ``. Measured: the cited rule is the bold-label paragraph at orchestrator.md:177, under `## Review routing` at :140; line 137 is now unrelated ledger text.
  - **H5:** a new entry **SPEC-GAP: token**, citing task-master.md **Spec gaps surface upward** and **Fix contract**, and orchestrator.md **Fix-contract re-dispatch** (literal: a report whose first line starts `SPEC-GAP: <unit-id> <what is missing>`).
  - **H6:** batched glossary findings from the fc-1..fc-4 reviews, if any, listed by task-master at filing.
- **Acceptance criteria:**
  - AC-fc5.1 `node tests/context-glossary-links.test.js` exits 0, and `node tests/ubiquitous-language.test.js` exits 0.
  - AC-fc5.2 Flattened greps:
    - `**Shared-file siblings** (the \`Depends on\` edge)` prints 1 (0 now);
    - `S1-S5 scribe (v1) rubric score` prints 1 (0 now);
    - `that the sliced units name as their parent` prints 0 (1 now);
    - `` `agents/orchestrator.md:137` `` prints 0 (1 now);
    - the anchored entry grep `^\*\*SPEC-GAP: token\*\*:` prints 1 (0 now).
  - AC-fc5.3 `git diff --name-only <B>..$U` prints only `docs/harness-glossary.md`; P1 subjects and the P5 trailer check (scribe's trailer line is given verbatim in the contract).

### Gate FG (stage end; main session)
Run `bash tests/validate.sh > $F 2>&1; echo "exit=$?" >> $F`; the last line must
be `exit=0`. The stage is then closed. Stage 4/5 gates remain as they are.

## Placement table

| Item | Placed |
|---|---|
| A CRLF v1 assertion; `+` bullets | fc-1 (A1, A2) |
| A v1 scribe shape lacks rows | parked: v1 is frozen for G3 history |
| B h2Pass cutoff mutant, `<` vs `<=` mutant, NaN → v2, temp-dir leak, null rubric_version fallback | fc-1 (B1-B3) |
| B scoreOf double spawn | parked: cost only |
| C Replay-source file list (`git show` header, PASS commit only), null final_commit, single `<ACn>`, nonexistent "recorded mutation" field | fc-3 (C1) |
| C "finding id" source | fc-3 (C2) |
| C "latest record" vs "each FAIL block"; awk indent wording | parked: wording read by spec-master (opus), no implementer impact |
| D SPEC-GAP shape, `--untracked-files=no`, ruling-line literal, one blank per criterion, scribe contract heading, P1/P2/P4/P5 rules | fc-2 (D1-D6) |
| D contract-examples misses the E3/E6 regressions | fc-4 (D7) |
| E neither-token rule, Gate-line scope, scribe selector | fc-2 (E1-E3) |
| E no test for the new orchestrator prose | fc-4 (AC-P1) |
| F researcher/WebSearch carve-out, CHANGELOG half under a contract, closed-issue exemption, scribe violation carve-out | fc-3 (F1-F4) |
| F tdd skill under a contract; scratch-worktree handling | parked: the contract's `tdd:` line decides, and the contracts carry the mutation commands (rules B1, B6) |
| G AC-T1 anchoring, contractPrecedence uniqueness, AC-D6/AC-A1 coverage, guardrail and H4-label presence pins | fc-4 (G1-G4) |
| G one-byte spacing at :67 | parked: no behavioural effect |
| G scribe doc-edit parity | parked: scribe has no ports; presence is pinned by AC-P3 |
| H shared file, contract score (v1), umbrella issue, orchestrator.md:137 citation, SPEC-GAP entry | fc-5 (H1-H5) |
| H G3 (**spec gap** citation) has no omission criterion | parked: the G3 edit shipped and is covered by AC-H10.21 |
| H "lock-in fixture", "v2-only row", judgment-duties scoping entries | parked: no shipped persona text defines them literally |
| I (version-stamp-check package.json guard, guarded protocol wording, HELD hook, "ratcheted tier") | parked by earlier rulings; not reopened |
| P5 trailer drift | rule P5 + trailer criterion in every fc contract |
| New, found while verifying: scribe commits a4934c2 and 783d9fb carry no trailer at all | covered by P5's per-commit trailer count |

## Known issues, parked (backlog; no further stage unless the user asks)

| Issue | Reason |
|---|---|
| v1 scribe shape does not score `Unit:`, Objective, Retrieval, Escalation or order | v1 is frozen; changing it rewrites G3 history |
| `scoreOf` spawns the scorer twice per row | cost only |
| spec-master "latest record" vs "each FAIL block"; awk indent wording | read by opus spec-master; cosmetic |
| lead-programmer tdd-skill invocation under a contract; scratch worktrees | the `tdd:` line and contract-carried commands decide |
| writer-tier test :67 one-byte spacing | no behavioural effect |
| scribe doc-edit parity test | no ports exist; presence pinned instead |
| **spec gap** citation (G3) omission criterion | shipped; covered by AC-H10.21 |
| glossary entries for "lock-in fixture", "v2-only row", judgment-duties scoping | no literal shipped definition |
| `version-stamp-check.sh` package.json guard; guarded protocol "verify the specific claim" wording; `HELD:` hook; "ratcheted tier" | parked by earlier rulings and the user |
| `dispatch-hygiene.sh` H2 counts only backtick fences | hook change (guarded); the scorer's `sizeOver` covers contracts |

Further findings go to this table, not to another stage, unless the user asks.

## Open Questions

None. Every item is placed or parked with a reason, and no decision needs
information only the user has.

## Self-check
- CHK1: Is every A-H item placed or parked? — PASS (placement table)
- CHK2: Does every range criterion bind to the unit's own last commit? — PASS (P1, used in each AC)
- CHK3: Does any red-set criterion use `git archive` with a git-running test? — PASS (P2; fc-1 uses the worktree form)
- CHK4: Is fc-5 the only glossary-editing unit, and is it last? — PASS (P3, dispatch order)
- CHK5: Do any criteria rely on `version-stamp-check.sh`'s exit code? — PASS (P4: stdout only)
- CHK6: Are version numbers serial and collision-free? — PASS (0.31.139, 0.31.140)
- CHK7: Is the unit count at most 5? — PASS (5)

## Scribe update hint
All glossary work is in fc-5 (P3). Scribe close-outs for fc-1..fc-4 make no
glossary edits; they record any glossary finding for fc-5 to batch.
