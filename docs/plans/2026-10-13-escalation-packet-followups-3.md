# Escalation packet follow-ups, round 3 (epfc-1..epfc-5): the epfb reviewers' notes 1-5

Status: FINAL (spec-master, 2026-10-13). **Five dispatchable units**, so this is
the **fast path**: the nine-element dispatch contracts are in the last section
of this file, and `task-master` is not needed. The units are **file-disjoint and
meant to run in parallel**.
Baseline: HEAD 948fb02 (the plan-only commit d4a91dd landed while this was
written; it touches only the round-2 plan), version 0.31.162. **No unit is
stamped:** none touches `agents/*.md` or `templates/*`, so no unit bumps the
version, adds a CHANGELOG entry or regenerates `.claude/` mirrors.

## Goal

Close the "Live carry-forward" notes 1-5 in
`.claude/agent-memory/scribe/project_epa2_completion.md` (opened by the epfb
reviewers, 2026-10-13). Goal clauses map to criteria as follows:
note 1 (`* ` branch of `mdStartsBlock` untested) → epfc-1 criteria 1-2;
note 2 (`epfb4-ac3.sh` misses F4 cases 3 and 4) → epfc-2 criteria 1-2;
note 3 (no-preamble round trip) → epfc-3 criteria 1-2 (decided: pin and
document, not fix);
note 4 (EB1 cannot tell prose from a fenced example) → epfc-4 criteria 1-3;
note 5 (alias sentence says "the template") → epfc-5 criteria 1-2.
Item j (concurrent validate.sh exit 1) stays a watch item, not a defect: no unit.

## Context

### Item inventory

| # | Note (scribe, live carry-forward) | Unit | Disposition |
|---|---|---|---|
| 1 | `* ` branch of `mdStartsBlock` untested | epfc-1 | New TABLE_CASES row **TB18** (`* item \| x` ends the table body). Measured: deleting the branch at HEAD leaves the suite green ("All tests passed."), and the mutant renders `<tr><td>* item</td><td>x</td></tr>` instead of the list. |
| 2 | `epfb4-ac3.sh` mutations miss F4 cases 3 and 4 | epfc-2 | Two new mutants in `docs/plans/epfb-criteria/epfb4-ac3.sh`: **(d)** an opener that opens only when a later closer exists (so an unclosed fence opens nothing) fails F4 on case 3 alone; **(e)** a tilde opener that rejects backticks in its info string fails F4 on case 4 alone. Both were measured: each fails only F4, on its own case. |
| 3 | `parseProtocolSections` does not round-trip text that opens with `## ` | epfc-3 | **Pin, do not fix** (see Clarifications for why). The function's comment now states the exception and calls it a non-goal. New check **F5** pins the current output and checks that no live template's first line starts with `## `. |
| 4 | EB1 cannot tell prose from a fenced example | epfc-4 | EB1 splits each file into prose lines and fenced-block lines (a local `splitFences`). It requires the token **in prose** in all 7 files, and **in a fence** (the card) in the 6 files that carry a card. The em-dash ban stays whole-text. |
| 5 | CONTEXT.md alias sentence says "the template" | epfc-5 | The sentence names `templates/persona-protocol.md`. `docs/plans/epfb-criteria/epfb1-ac3.sh` pins the old sentence byte for byte, so the same unit updates that pin (otherwise a closed unit's criterion goes red at HEAD). |

### Contract hygiene (reused from the round-2 plan, binding on every contract here)

1. Each criterion's `stdout:` line is the script's literal output on success,
   byte for byte, including trailing spaces. `range.sh <unit> trailer` prints
   `1 ` (a 1 then one space). No script here prints more than one line on success.
2. The commit trailer names the model the implementer **actually ran on**
   (`Claude Haiku 5.5`, `Claude Sonnet 5.5` or `Claude Opus 5.5`). Each contract
   writes its suggested tier into the commit command and says to substitute the
   real one. `range.sh trailer` checks only the trailer's shape.
3. Every `run:` was executed: red at HEAD (except criteria marked `check:`),
   and green in a prototype worktree with the plan's criteria committed and all
   five units' edits applied by script and committed. It was also green in five
   **isolated** worktrees, each holding only one unit on top of the criteria
   commit (this is the parallel-safety evidence). Every mutation script printed
   its "killed" line in both settings.

### Parallel execution rules (new for this round)

- File sets are disjoint (intersection table in the dispatch preamble). No two
  units read each other's edited lines in a way that changes a verdict. epfc-2's
  script runs `tests/protocol-cross-references.test.js`, which epfc-3 extends
  with F5, and its mutants (d) and (e) leave F5 green. epfc-4's EB1 reads
  CONTEXT.md:1054, and epfc-5 edits a different entry (:832-835). Both were
  verified in the combined and in the isolated runs.
- Each contract stages **only its own files by explicit path** and never runs
  `git add -A`, `git add -u` or `git commit -a`. The final self-check is
  `git diff --quiet HEAD -- <own files>`, not an empty `git status`, because
  the other units' edits may be in flight in the same tree.
- If `git commit` reports an `index.lock`, another unit is committing. Re-run
  the same command after a few seconds. Never delete the lock.

### Prior FAIL history (Implementer-tier ratchet input)

- No `.fail` record exists for any epf-* or epfb-* unit. The reviewed-markers
  directory holds `epf-1..6.pass` and `epfb-1..5.pass` only (listed 2026-10-13).
- Notes sweep, `bin/marker-audit.sh . --notes --surface=<path>` (2026-10-13).
  `NOTE[spec]`/`untagged` counts per surface: markdown-lite test 0/1,
  `epfb4-ac3.sh` 0/1, cross-references test 0/2, parity test 2/14. For
  CONTEXT.md (141/301) and `bin/cli.js` (15/188), the counts are taken from the
  round-2 plan's d4a91dd correction, because the full sweep exceeded the time
  budget here. Filtered for this plan's topics (epfb, epfc, mdStartsBlock,
  preamble, EB1, skip token, fence), the four swept surfaces give no match. The
  one cli.js match recorded in round 2 (epf-5's inline-code opener) was closed
  by epfb-4. **Disposition:** no note changes this plan. The sweep is best
  effort, because the records are gitignored, per-clone state.

### Measured facts (2026-10-13, HEAD 948fb02)

- The skip token `examples: none - <one-line reason>` occurs once in prose and
  once inside the card fence in each of `agents/reviewer.md` (:380 prose, :289
  fence), `templates/persona-protocol.md` (:514, :445), their two mirrors, and
  both ports (codex :270, :209; cursor :276, :219). In `CONTEXT.md` it occurs
  once, in prose (:1054), and there is no card. So the old whole-text EB1 still
  passes after the prose copy in `agents/reviewer.md` is deleted (measured:
  epfc4-ac2 prints `(a) prose-token deletion survived EB1` at HEAD).
- `parseProtocolSections('## A')` and `parseProtocolSections('\n## A')` return
  identical values (preamble `''`, one section). The function is not
  injective, so no change inside it alone can round-trip both.
- `inlineProtocolBlock` (`bin/cli.js`, the only caller that joins) joins
  `[preamble, ...sections]` with `'\n'` and then strips trailing whitespace, but
  not leading whitespace. F2 already fails if a live template ever opens with
  `## `, because the join would then differ from the file.
- `CONTEXT.md:832-835` hold the alias sentence. `epfb1-ac3.sh:8` pins the
  sentence with `grep -qF` over the flattened entry.
- A Bash command whose text names the reviewed-markers directory is refused by
  `reviewed-path-gate.sh`, even for `ls -c`/`grep -c` pipelines. That happened
  while this plan was written. No contract command names it.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-10-13 Edge cases / failure handling: Q Note 3: fix `parseProtocolSections` so no-preamble text round-trips, or pin it with a test and a documented non-goal? → A (self-resolved): **pin.** This is cheaper and just as safe. A fix cannot live inside the function: `'## A'` and `'\n## A'` already map to the same value. It would need a new return shape (for example a `hasPreamble` flag, or `null` for an absent preamble) plus edits to `inlineProtocolBlock` and to the round-trip join in F1, F2 and F4. That is a wider change on the path that renders every persona, and it buys nothing reachable: every live template opens with a header comment, and F2 already fails the day one does not. The pin is one comment correction and one check (F5). The comment's old claim, "reproduces the file byte-for-byte", was false for this input. The pin also makes a future "fix" deliberate, because F5 fails on it (epfc3-ac2 (a)).
- 2026-10-13 Edge cases / failure handling: Q Note 4: what should EB1 require now? → A (self-resolved): the em-dash ban stays whole-text, since an em dash is wrong in an example too. The positive check must hold **in prose** in all 7 files, and **in a fence** in the 6 card-carrying files. `CONTEXT.md` has no card, so only the prose half applies to it. The check keeps its `EB1 ` name prefix, so `epfb2-ac1.sh` and `epfb2-ac2.sh` stay valid, and epfc-4 re-runs `epfb2-ac2.sh` as a criterion.
- 2026-10-13 Technical constraints & tradeoffs: Q Note 5 breaks `epfb1-ac3.sh`, which pins the old sentence. Update it, or leave a closed unit's criterion red? → A (self-resolved): update its pinned string in the same unit (epfc-5). Committed criteria are re-runnable evidence, and a red one at HEAD would mislead the next auditor. The round-2 plan called that directory read-only for the round-2 units only. Note 2 already requires editing `epfb4-ac3.sh` there, so this follows the same precedent.
- 2026-10-13 Technical constraints & tradeoffs: Q Is any unit stamped (P3)? → A (self-resolved): none is. The edited paths are `tests/`, `bin/cli.js` (a comment), `CONTEXT.md` and `docs/plans/`. `version-stamp-check.sh` stamps only `agents/*.md` and `templates/*`. No version bump, no CHANGELOG entry and no mirror refresh.
- 2026-10-13 Technical constraints & tradeoffs: Q Where does `splitFences` live? → A (self-resolved): locally in `tests/adapter-protocol-parity.test.js`, which does not load `bin/cli.js` today. Exporting a fence helper from `bin/cli.js` would add a third file to epfc-4 and overlap epfc-3's file set. The regexes are copied from `parseProtocolSections` on purpose, so both agree on what a fence is.
- 2026-10-13 Completion / acceptance signals: Q What proves note 2 is closed, not just "the script has more lines"? → A (self-resolved): a mutation proof of the mutation script itself. `epfc2-ac2.sh` deletes F4 case 3 (then case 4) from the test in a scratch worktree, commits it there, and runs that worktree's `epfb4-ac3.sh`. That run must fail and name mutant (d) (then (e)). At HEAD, the case-3 deletion goes uncaught (measured).

## Risks / dependencies

- R1: The units are file-disjoint (intersection table) and run in parallel.
  None depends on another. See "Parallel execution rules" above.
- R2: Criteria are scripts in `docs/plans/epfc-criteria/`, committed with this
  plan and read-only for every unit. They source `docs/plans/epf-criteria/lib.sh`
  and reuse its `scope.sh`, `range.sh` and `vtargeted.sh`. A unit's commits are
  found by the subject scope `^[a-z]+\(epfc-N\): `.
- R3: The mutation scripts make scratch worktrees under `mktemp -d` and remove
  them on exit. `epfc2-ac2.sh` also commits inside its scratch worktree (detached
  HEAD, `core.hooksPath=/dev/null`), so the commit touches no branch. If a run is
  killed, `git worktree prune` cleans up.
- R4: Do not paste a criterion as Bash text. Run
  `bash docs/plans/epfc-criteria/<script>`.
- R5: Item j (concurrent validate.sh exit 1) is still a watch item. Five
  parallel units each running `vtargeted.sh` is the same "several concurrent
  validate.sh runs" condition. If a targeted group fails with no matching test
  failure, re-run it alone before reporting a FAIL, and record the case for j.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every criterion was run red at HEAD
  (or marked `check:`) and green in a combined and in per-unit isolated
  prototype worktrees. Each mutation script killed its stated mutants.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The
  criteria are committed scripts, and no mirror is touched.
- P3 "Version-stamp discipline": satisfied, and vacuously so. No unit touches
  `agents/*.md` or `templates/*`, so no unit bumps the version or adds a
  CHANGELOG entry.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. No persona
  wording changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied. No section is added.
  Each unit runs its affected section groups through `vtargeted.sh`. The
  orchestrator runs G (the epf procedure) once, after all five units PASS.

## Steps

### Step 1: epfc-1, test the `* ` branch of mdStartsBlock (note 1)
**Affected files:** `tests/microworld/dashboard-markdown-lite.test.js` only.
**Acceptance:** `epfc1-ac1.sh` (TB18 ok); `epfc1-ac2.sh` (deleting only the
`* ` branch fails TB18); scope; targeted; trailer; tail.

### Step 2: epfc-2, extend epfb4-ac3.sh with case-3 and case-4 mutants (note 2)
**Affected files:** `docs/plans/epfb-criteria/epfb4-ac3.sh` only.
**Acceptance:** `epfb4-ac3.sh` still prints `epfb-4 mutations killed`;
`epfc2-ac2.sh` (dropping case 3 or case 4 from F4 makes `epfb4-ac3.sh` fail on
(d) or (e)); scope; targeted; trailer; tail.

### Step 3: epfc-3, pin the no-preamble non-goal (note 3)
**Affected files:** `bin/cli.js` (the comment above `parseProtocolSections`
only), `tests/protocol-cross-references.test.js` (new F5).
**Acceptance:** `epfc3-ac1.sh` (F5 OK and the comment states the non-goal);
`epfc3-ac2.sh` (a null-preamble parser and a `## `-first template each fail
F5); scope; targeted; trailer; tail.

### Step 4: epfc-4, scope EB1 to prose and the card fence (note 4)
**Affected files:** `tests/adapter-protocol-parity.test.js` only.
**Acceptance:** `epfc4-ac1.sh` (EB1/EB2 OK, EB1 uses `splitFences`);
`epfc4-ac2.sh` (deleting the prose copy, or the card copy, fails EB1);
`epfb2-ac2.sh` still green; scope; targeted; trailer; tail.

### Step 5: epfc-5, name the template file in the glossary alias (note 5)
**Affected files:** `CONTEXT.md` (the **Escalation packet** entry, :832-835),
`docs/plans/epfb-criteria/epfb1-ac3.sh` (:8, the pinned sentence).
**Acceptance:** `epfc5-ac1.sh`; `epfb1-ac3.sh` green; scope; targeted;
trailer; tail.

## Open Questions

None blocking. Every decision was self-resolved and is recorded in
Clarifications, and the user may overrule any of them. The one most worth a
look is note 3's "pin, do not fix". Another is note 5's edit to a closed round's
criterion (`epfb1-ac3.sh`).

## Self-check
- CHK1: Does every note 1-5 map to a unit and to criteria that fail without it? — PASS (Goal mapping; every `epfc*` script was red at HEAD for the stated reason)
- CHK2: Are the five file sets pairwise disjoint, and is each set stated exactly? — PASS (intersection table; each contract's Affected files lists the same set, and `scope.sh` enforces it)
- CHK3: Is there exactly one stamped unit, or none, and is that justified? — PASS (none; Clarifications, Technical constraints; P3 line)
- CHK4: Is note 3's decision stated with its reason? — PASS (Clarifications, Edge cases, first line)
- CHK5: Does epfc-5 leave every committed criterion green at HEAD? — FAIL (missing): the first draft changed CONTEXT.md only and would have turned `epfb1-ac3.sh` red — revised in place (epfc-5 also updates the pin; criterion 2 runs `epfb1-ac3.sh`)
- CHK6: Do the parallel contracts avoid whole-tree staging and an empty-`git status` check? — FAIL (conflicting): the first draft copied round 2's `git status --porcelain | wc -l` = 0 edit, which a parallel sibling's in-flight edit breaks — revised in place (explicit-path staging; `git diff --quiet HEAD -- <own files>`)
- CHK7: Does each mutant in note 2 hit only its own F4 case? — PASS (measured: (d) fails F4 with the case-3 header list, (e) with the case-4 header list; F1-F3 stay OK under both)
- CHK8: Does the new EB1 keep the `EB1 ` name prefix that `epfb2-ac1/ac2` grep for? — PASS (epfc-4 criterion 3 runs `epfb2-ac2.sh`)
- CHK9: Do the contracts' `stdout:` lines match the scripts' literal output? — PASS (observed in the prototype, including `range.sh`'s `1 `)
- CHK10: Does every contract reach 7/7 under `contract-guard`? — PASS (all five `contract-guard: haiku … score=7/7`, run after this file was written)
- CHK11 (replay, gh348-4 / gh360 / gh377-5 / gh409 / gh413 / item04-2-apply-drops / mw-step3 [vacuous, host] on bin/cli.js): Does epfc3-ac1 still fail under its own `mutation:` line? — PASS (skipping edit 1 prints `non-goal sentence missing …`; skipping edit 2 prints `F5 not OK`; both observed)
- CHK12 (replay, gh-303 / gh339 / gh354 / gh409 / gh426 / gh429 / human-review-cleanup-1 / spec2-unitA / spec2-unitB / ci-fetch-depth-cleanup [vacuous, host] on CONTEXT.md): Is epfc5-ac1 entry-scoped and still red when its edit is skipped? — PASS (the awk stops at the next column-0 `**term**`; red at HEAD)
- CHK13 (replay, examples-2 [host] on tests/adapter-protocol-parity.test.js): Does epfc4-ac2 fail when edit 1 is skipped? — PASS (prints `(a) prose-token deletion survived EB1` at HEAD)

Glossary drift (prose mode, advisory). Lens 1: none. Lens 2: none ("card
fence" here means the fenced block that holds the **escalation card**, the
existing term; it is not a new term). Lens 3: "skip token" is still used
without its own entry; this was already suggested to scribe in round 2 and is
not repeated as a unit.

## Scribe update hint
After all five units PASS, mark notes 1-5 closed in the "Live carry-forward"
section of `.claude/agent-memory/scribe/project_epa2_completion.md`, naming
epfc-1..5. Record that note 3 was closed by **pinning** (non-goal, F5), not by a
fix. Item j stays a watch item. If R5 fires during the parallel run, add the
case there.

## Dispatch contracts (spec-master, fast path, 2026-10-13)

Five dispatchable units; none held; **all five may run in parallel**.
**Retrieval contract.** No tracker issue exists for these units (fast path).
Fetch a unit's dispatch prompt by reading
`docs/plans/2026-10-13-escalation-packet-followups-3.md` with the Read tool,
finding the `### Unit: epfc-N` heading, and sending the interior of the
six-backtick fenced block that follows it as the dispatch prompt (nested fences
are payloads). Its first line is the literal `Unit: epfc-N`, and
`node bin/contract-guard.js docs/plans/2026-10-13-escalation-packet-followups-3.md --unit=epfc-N`
finds the block. Commit subjects never carry an issue number.

**Intersection table:**

| unit | files (exact) | shared with | depends on |
|---|---|---|---|
| epfc-1 | `tests/microworld/dashboard-markdown-lite.test.js` | none | none |
| epfc-2 | `docs/plans/epfb-criteria/epfb4-ac3.sh` | none | none |
| epfc-3 | `bin/cli.js`, `tests/protocol-cross-references.test.js` | none | none |
| epfc-4 | `tests/adapter-protocol-parity.test.js` | none | none |
| epfc-5 | `CONTEXT.md`, `docs/plans/epfb-criteria/epfb1-ac3.sh` | none | none |

**Suggested models:** `haiku` for all five, because every edit is written out
literally and there is no FAIL history on these units. The orchestrator
recomputes the Escalation ladder at dispatch, and a tag can raise the tier but
never lower it. The reviewer tier is decided at dispatch by
`hooks/scripts/reviewer-tier.sh` over the actual diff.

**G** (the merge gate, from the epf plan, unchanged): the orchestrator runs it
once, after all five units PASS. Run five separate Bash calls with
`timeout: 600000`. First, the listing-hash command from the round-2 plan's G
paragraph, on its own. Then
`source docs/plans/epf-criteria/lib.sh; export CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel)" REVIEWED_DIR_LEAK_GUARD_NESTED=1`
with `vsec 1 60`, then `vsec 61 108`, then `vsec 109 110` and `vsec 111 999`.
Finally, the listing hash again, which must match the first.

**Verification record:** every `run:` below was executed at 948fb02 (red,
except the `check:` ones). It was also executed in a scratch worktree with the
criteria committed and the five units' edits applied by script and committed as
`test(epfc-1)` … `docs(epfc-5)` (green), and in five isolated worktrees, one
unit each (green). The targeted section groups for all five units ran together
in 23 s, rc 0. `epfb3-ac1/ac3`, `epfb4-ac1/ac2` and `epfb5-ac1` stayed green, and
`node bin/cli.js --update --dry-run` exited 0.

### Unit: epfc-1

- Suggested model: `haiku`
- Depends on / blocked by: none (parallel-safe)
- Spec step: Step 1; closes note 1.

``````
Unit: epfc-1

## Objective
Add table case TB18 to `tests/microworld/dashboard-markdown-lite.test.js`: a `* item | x` line after a table body ends the body and renders as a list item. This is the only test of the `* ` branch of `mdStartsBlock` in `bin/microworld-dashboard/markdown-lite.js`; today deleting that branch leaves the suite green.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-3.md`, section `### Unit: epfc-1`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/microworld/dashboard-markdown-lite.test.js` (anchor: line matching `'<table><thead><tr><th>h</th></tr></thead><tbody><tr><td>x \\| y</td></tr></tbody></table>']`, the last TABLE_CASES row, TB17)

## Ordered edits
1. file: `tests/microworld/dashboard-markdown-lite.test.js` (append TB18 after TB17)
   anchor: line matching `'<table><thead><tr><th>h</th></tr></thead><tbody><tr><td>x \\| y</td></tr></tbody></table>']`
   indent: 0
   before:
~~~~
    '<table><thead><tr><th>h</th></tr></thead><tbody><tr><td>x \\| y</td></tr></tbody></table>']
];
~~~~
   after:
~~~~
    '<table><thead><tr><th>h</th></tr></thead><tbody><tr><td>x \\| y</td></tr></tbody></table>'],
  ['TB18 star list item ends the body', '| a | b |\n|---|---|\n| 1 | 2 |\n* item | x', T_AB + '<ul><li>item | x</li></ul>']
];
~~~~
2. command: `git add tests/microworld/dashboard-markdown-lite.test.js && git commit -m "test(epfc-1): pin the star list-item stop of the markdown-lite table body" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if git reports `index.lock`, a parallel unit is committing: re-run this command after a few seconds)
   expect: 0
3. command: `git diff --quiet HEAD -- tests/microworld/dashboard-markdown-lite.test.js`
   expect: 0

## Do NOT touch
- `bin/microworld-dashboard/markdown-lite.js`: the `* ` branch is correct; this unit only tests it.
- `tests/microworld/dashboard-markdown-lite.test.js` outside the TB17 row's closing bracket and the new TB18 row: `ALLOWED_TAG`, `CONTEXTS`, VM1 and TB1-TB17 stay byte-identical.
- `docs/plans/epfb-criteria/`, `bin/cli.js`, `tests/protocol-cross-references.test.js`, `tests/adapter-protocol-parity.test.js` and `CONTEXT.md`: the other epfc units own them and run in parallel with you.
- `docs/plans/epfc-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfc-criteria/epfc1-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; prints `TB18 not ok`, exit 1.
2. run: `bash docs/plans/epfc-criteria/epfc1-ac2.sh`
   exit: 0
   stdout: `epfc-1 mutation killed`
   mutation: skip edit 1; deleting only the `* ` branch leaves the suite green, so it prints `star branch deletion survived`, exit 1.
3. run: `bash docs/plans/epf-criteria/scope.sh epfc-1 'tests/microworld/dashboard-markdown-lite\.test\.js'`
   exit: 0
   stdout: empty
   mutation: also commit `bin/microworld-dashboard/markdown-lite.js`; prints `out of scope: bin/microworld-dashboard/markdown-lite.js`, exit 1.
4. run: `bash docs/plans/epf-criteria/vtargeted.sh 'markdown-lite'`
   exit: 0
   stdout: empty
   check: green at 948fb02 on purpose; it guards the rest of the markdown-lite suite.
   mutation: write TB18's expected `<ul><li>` as `<ol><li>`; prints `section group failed: markdown-lite`, exit 1.
5. run: `bash docs/plans/epf-criteria/range.sh epfc-1 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
6. run: `bash docs/plans/epf-criteria/range.sh epfc-1 tail tests/microworld/dashboard-markdown-lite.test.js`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/microworld/dashboard-markdown-lite.test.js (TB18 passes on arrival because the branch already exists; criterion 2 proves it is not vacuous)
blast-radius: tests/microworld/dashboard-markdown-lite.test.js:378 (the `TABLE_CASES.forEach` loop registers TB18 automatically; `T_AB` is defined at :332); test-only.
commit-message: test(epfc-1): pin the star list-item stop of the markdown-lite table body
trailer: the trailer names the model you actually ran on.
parallel: four other units edit other files in the same tree; stage only your file, by path.
measured: with the `* ` branch deleted, the input renders `<tr><td>* item</td><td>x</td></tr>` inside the table instead of `<ul><li>item | x</li></ul>` after it.
diagnosis: none
review-packet:
~~~
unit: epfc-1 (plan docs/plans/2026-10-13-escalation-packet-followups-3.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epfc-2

- Suggested model: `haiku`
- Depends on / blocked by: none (parallel-safe)
- Spec step: Step 2; closes note 2.

``````
Unit: epfc-2

## Objective
Extend the mutation script `docs/plans/epfb-criteria/epfb4-ac3.sh` with mutant (d), an opener that opens only when a later closer exists, so an unclosed fence opens nothing; it must fail F4 on case 3. Add mutant (e), a tilde opener that rejects backticks in its info string; it must fail F4 on case 4. The script still prints `epfb-4 mutations killed` on success.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-3.md`, section `### Unit: epfc-2`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `docs/plans/epfb-criteria/epfb4-ac3.sh` (anchors: line matching `# (c) rendering is unchanged: --update --dry-run exits 0.`; line matching `echo "epfb-4 mutations killed"`)

## Ordered edits
1. file: `docs/plans/epfb-criteria/epfb4-ac3.sh` (header comment names the two new mutants)
   anchor: line matching `# (c) rendering is unchanged: --update --dry-run exits 0.`
   indent: 0
   before:
~~~~
# (a) the old opener regex fails F4; (b) the old closer regex fails F4;
# (c) rendering is unchanged: --update --dry-run exits 0.
~~~~
   after:
~~~~
# (a) the old opener regex fails F4; (b) the old closer regex fails F4;
# (c) rendering is unchanged: --update --dry-run exits 0; (d) an opener that
# needs a later closer (so an unclosed fence opens nothing) fails F4 case 3;
# (e) a tilde opener that rejects backticks in its info string fails F4 case 4.
~~~~
2. file: `docs/plans/epfb-criteria/epfb4-ac3.sh` (mutants (d) and (e), inserted before the success line)
   anchor: line matching `echo "epfb-4 mutations killed"`
   indent: 0
   before:
~~~~
echo "epfb-4 mutations killed"
~~~~
   after:
~~~~
( cd "$wt" && git checkout -q -- bin/cli.js )
perl -0pi -e 's/if \(open\) fence =/if (open && \/^ {0,3}(`{3,}|~{3,})[ \\t\\r]*\$\/m.test(text.slice(text.indexOf(line) + line.length + 1))) fence =/' "$wt/bin/cli.js"
( cd "$wt" && git diff --quiet -- bin/cli.js ) && { echo "(d) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(d) unclosed-fence mutant survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F4 .*also swallowed' || { echo "(d) no FAIL F4 on case 3"; exit 1; }
( cd "$wt" && git checkout -q -- bin/cli.js )
perl -0pi -e 's/\(`\{3,\}\(\?=\[\^`\]\*\$\)\|~\{3,\}\)\/\.exec/((?:`{3,}|~{3,})(?=[^`]*\$))\/.exec/' "$wt/bin/cli.js"
( cd "$wt" && git diff --quiet -- bin/cli.js ) && { echo "(e) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(e) tilde-backtick mutant survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F4 .*tilde info may hold backticks' || { echo "(e) no FAIL F4 on case 4"; exit 1; }
echo "epfb-4 mutations killed"
~~~~
3. command: `git add docs/plans/epfb-criteria/epfb4-ac3.sh && git commit -m "test(epfc-2): epfb4-ac3 mutants for F4 cases 3 and 4" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if git reports `index.lock`, a parallel unit is committing: re-run this command after a few seconds)
   expect: 0
4. command: `git diff --quiet HEAD -- docs/plans/epfb-criteria/epfb4-ac3.sh`
   expect: 0

## Do NOT touch
- `bin/cli.js` and `tests/protocol-cross-references.test.js`: the mutants change only the scratch worktree's copy; epfc-3 owns the real files and runs in parallel.
- `docs/plans/epfb-criteria/epfb4-ac3.sh` lines other than the two edit sites: mutants (a)-(c), the worktree setup and the trap stay byte-identical.
- `docs/plans/epfb-criteria/epfb1-ac3.sh`: epfc-5 edits it in parallel; leave every other file under `docs/plans/epfb-criteria/` alone too.
- `docs/plans/epfc-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfb-criteria/epfb4-ac3.sh`
   exit: 0
   stdout: `epfb-4 mutations killed`
   check: green at 948fb02 on purpose; the new mutants must keep it green.
   mutation: write mutant (d)'s grep pattern as `'^FAIL F4 .*also swallowedX'`; prints `(d) no FAIL F4 on case 3`, exit 1.
2. run: `bash docs/plans/epfc-criteria/epfc2-ac2.sh`
   exit: 0
   stdout: `case 3 and case 4 deletions caught`
   mutation: skip edit 2; prints `(d) case deletion not caught by epfb4-ac3.sh`, exit 1 (observed at 948fb02).
3. run: `bash docs/plans/epf-criteria/scope.sh epfc-2 'docs/plans/epfb-criteria/epfb4-ac3\.sh'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/protocol-cross-references.test.js`; prints `out of scope: tests/protocol-cross-references.test.js`, exit 1.
4. run: `bash docs/plans/epf-criteria/vtargeted.sh 'protocol cross-references'`
   exit: 0
   stdout: empty
   check: green at 948fb02 on purpose; it guards the suite the mutants run against.
   mutation: put a `## ` line inside the card fence of the template; prints `section group failed: protocol cross-references`, exit 1.
5. run: `bash docs/plans/epf-criteria/range.sh epfc-2 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
6. run: `bash docs/plans/epf-criteria/range.sh epfc-2 tail docs/plans/epfb-criteria/epfb4-ac3.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: no docs/plans/epfb-criteria/epfb4-ac3.sh (the file is itself a test; criterion 2 is its mutation proof)
blast-radius: docs/plans/epfb-criteria/epfb4-ac3.sh:22 (the success line before this unit's edit; the file is read by no test and no validate.sh section; mutant (d) leaves F1-F3 and F5 green and (e) leaves F1-F3 and F5 green (measured), so each fails only F4, on its own case)
commit-message: test(epfc-2): epfb4-ac3 mutants for F4 cases 3 and 4
trailer: the trailer names the model you actually ran on.
parallel: four other units edit other files in the same tree; stage only your file, by path.
measured: under (d) F4 reports headers `A`, `swallowed`, `also swallowed` for case 3; under (e) it reports `A`, `not a header` for case 4.
quoting: copy edit 2 byte for byte; the perl replacement's `\\t\\r`, `\$` and `\/` escapes are load-bearing.
diagnosis: none
review-packet:
~~~
unit: epfc-2 (plan docs/plans/2026-10-13-escalation-packet-followups-3.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epfc-3

- Suggested model: `haiku`
- Depends on / blocked by: none (parallel-safe)
- Spec step: Step 3; closes note 3 (pin, not fix).

``````
Unit: epfc-3

## Objective
Record as a documented non-goal that `parseProtocolSections` (`bin/cli.js`) does not round-trip text that opens with a `## ` line: such text has no preamble, so the preamble-plus-sections join gains a leading newline. Correct the function's header comment, which today says the join always reproduces the file byte-for-byte. Add check F5 to `tests/protocol-cross-references.test.js`: it pins that output and checks that no live template's first line starts with `## `. The parser's code does not change.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-3.md`, section `### Unit: epfc-3`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `bin/cli.js` (anchor: line matching `// byte-for-byte.`, directly above `function parseProtocolSections(text) {`)
- `tests/protocol-cross-references.test.js` (anchor: line matching `if (failures) {`, which occurs once)

## Ordered edits
1. file: `bin/cli.js` (comment only)
   anchor: line matching `// byte-for-byte.`
   indent: 0
   before:
~~~~
// Joining the preamble and every section text with '\n' reproduces the file
// byte-for-byte.
~~~~
   after:
~~~~
// Joining the preamble and every section text with '\n' reproduces the file
// byte-for-byte, except a text that opens with a `## ` line: it has no
// preamble, and the join adds a leading '\n'. That case is a non-goal, kept
// unreachable because every live template opens with a header comment (F2 and
// F5 in tests/protocol-cross-references.test.js).
~~~~
2. file: `tests/protocol-cross-references.test.js` (F5, inserted before the summary block)
   anchor: line matching `if (failures) {`
   indent: 0
   before:
~~~~
if (failures) {
~~~~
   after:
~~~~
// epfc-3: text that opens with a `## ` line has no preamble, so the
// preamble-plus-sections join gains a leading '\n'. A documented non-goal
// (see the comment above parseProtocolSections); this pins the behaviour and
// keeps every live template's first line off `## `.
check('F5 no-preamble text: empty preamble, the join adds a leading newline (non-goal, pinned)', () => {
  const t = '## A\nx\n## B';
  const r = cli.parseProtocolSections(t);
  assert.deepStrictEqual(r.sections.map((s) => s.header), ['A', 'B'], 'headers for a no-preamble text');
  assert.strictEqual(r.preamble, '', 'a no-preamble text has an empty-string preamble');
  assert.strictEqual([r.preamble, ...r.sections.map((s) => s.text)].join('\n'), '\n' + t, 'the join adds exactly one leading newline');
  for (const rel of LIVE_TEMPLATES) {
    const first = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').split('\n')[0];
    assert.ok(!first.startsWith('## '), `${rel}: opens with a ## line, so its preamble join would gain a leading newline`);
  }
});

if (failures) {
~~~~
3. command: `git add bin/cli.js tests/protocol-cross-references.test.js && git commit -m "test(epfc-3): pin parseProtocolSections' no-preamble case as a documented non-goal" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if git reports `index.lock`, a parallel unit is committing: re-run this command after a few seconds)
   expect: 0
4. command: `git diff --quiet HEAD -- bin/cli.js tests/protocol-cross-references.test.js`
   expect: 0

## Do NOT touch
- `bin/cli.js` outside the two comment lines of edit 1: the parser's code, `inlineProtocolBlock` and every caller stay byte-identical (the decision is pin, not fix).
- `tests/protocol-cross-references.test.js` checks F1-F4 and their round-trip joins: unchanged.
- `templates/persona-protocol.md` and `templates/persona-protocol-slim.md`: F5 reads them; editing them would make this a stamped unit.
- `docs/plans/epfb-criteria/epfb4-ac3.sh` (it runs this test in a scratch worktree), `tests/adapter-protocol-parity.test.js`, `tests/microworld/` and `CONTEXT.md`: the other epfc units own them and run in parallel with you.
- `docs/plans/epfc-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfc-criteria/epfc3-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 2; prints `F5 not OK`, exit 1 (skipping only edit 1 prints `non-goal sentence missing from the parseProtocolSections comment`).
2. run: `bash docs/plans/epfc-criteria/epfc3-ac2.sh`
   exit: 0
   stdout: `epfc-3 mutations killed`
   mutation: skip edit 2; prints `(a) null preamble survived`, exit 1.
3. run: `bash docs/plans/epf-criteria/scope.sh epfc-3 '(bin/cli\.js|tests/protocol-cross-references\.test\.js)'`
   exit: 0
   stdout: empty
   mutation: also commit `templates/persona-protocol-slim.md`; prints `out of scope: templates/persona-protocol-slim.md`, exit 1.
4. run: `bash docs/plans/epf-criteria/vtargeted.sh 'protocol cross-references' 'bin/cli.js'`
   exit: 0
   stdout: empty
   check: green at 948fb02 on purpose; it guards the parser's other callers.
   mutation: change F5's expected `'\n' + t` to `t`; prints `section group failed: protocol cross-references`, exit 1.
5. run: `bash docs/plans/epf-criteria/range.sh epfc-3 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
6. run: `bash docs/plans/epf-criteria/range.sh epfc-3 tail bin/cli.js tests/protocol-cross-references.test.js`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on `bin/cli.js`; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/protocol-cross-references.test.js (F5 passes on arrival because it pins current behaviour; criterion 2 proves it is not vacuous)
blast-radius: bin/cli.js:718 (comment only; no code path changes) tests/protocol-cross-references.test.js:151 (`LIVE_TEMPLATES`, `fs`, `path`, `REPO_ROOT`, `cli`, `assert` and `check` are already defined above the insertion point)
commit-message: test(epfc-3): pin parseProtocolSections' no-preamble case as a documented non-goal
trailer: the trailer names the model you actually ran on.
parallel: four other units edit other files in the same tree; stage only your two files, by path.
decision: pin, not fix. `'## A'` and `'\n## A'` parse to the same value, so a fix needs a new return shape plus edits to `inlineProtocolBlock` and the F1/F2/F4 joins, with no reachable benefit. Do not "fix" the parser.
diagnosis: none
review-packet:
~~~
unit: epfc-3 (plan docs/plans/2026-10-13-escalation-packet-followups-3.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epfc-4

- Suggested model: `haiku`
- Depends on / blocked by: none (parallel-safe)
- Spec step: Step 4; closes note 4.

``````
Unit: epfc-4

## Objective
In `tests/adapter-protocol-parity.test.js`, check EB1 tells prose from fenced examples. A new local helper `splitFences` splits a file into prose lines and fenced-block interior lines. EB1 then requires the skip token `examples: none - <one-line reason>` in prose in all seven files, and inside a fence (the escalation card) in the six files that carry a card (all but `CONTEXT.md`). The em-dash ban stays whole-text, and the check keeps its `EB1 ` name prefix.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-3.md`, section `### Unit: epfc-4`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/adapter-protocol-parity.test.js` (anchor: line matching `check('EB1 skip token is`, which occurs once)

## Ordered edits
1. file: `tests/adapter-protocol-parity.test.js` (add splitFences; replace the EB1 block)
   anchor: line matching `check('EB1 skip token is`
   indent: 0
   before:
~~~~
check('EB1 skip token is `examples: none - <one-line reason>` with an ASCII hyphen in every prose copy', () => {
  const files = ['agents/reviewer.md', 'templates/persona-protocol.md', '.claude/agents/reviewer.md',
    '.claude/persona-protocol.md', 'CONTEXT.md', 'adapters/codex/agents-md-fragment.md',
    'adapters/cursor/rules/persona-protocol.mdc'];
  for (const rel of files) {
    const t = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
    assert.ok(!t.includes('examples: none \u2014'), `${rel}: em-dash skip token`);
    assert.ok(t.includes('examples: none - <one-line reason>'), `${rel}: no ASCII-hyphen skip token`);
  }
});
~~~~
   after:
~~~~
// epfc-4: split markdown into prose lines and fenced-block interior lines
// (CommonMark backtick or tilde fences; the fence delimiter lines are in neither).
function splitFences(text) {
  const prose = [];
  const fenced = [];
  let fence = null;
  for (const line of text.split('\n')) {
    if (fence) {
      const close = /^ {0,3}(`{3,}|~{3,})[ \t\r]*$/.exec(line);
      if (close && close[1][0] === fence.ch && close[1].length >= fence.len) fence = null;
      else fenced.push(line);
    } else {
      const open = /^ {0,3}(`{3,}(?=[^`]*$)|~{3,})/.exec(line);
      if (open) fence = { ch: open[1][0], len: open[1].length };
      else prose.push(line);
    }
  }
  return { prose, fenced };
}

check('EB1 skip token is `examples: none - <one-line reason>` with an ASCII hyphen in every prose copy, in prose and in the card fence', () => {
  const files = ['agents/reviewer.md', 'templates/persona-protocol.md', '.claude/agents/reviewer.md',
    '.claude/persona-protocol.md', 'CONTEXT.md', 'adapters/codex/agents-md-fragment.md',
    'adapters/cursor/rules/persona-protocol.mdc'];
  const NO_CARD = ['CONTEXT.md'];
  const token = 'examples: none - <one-line reason>';
  for (const rel of files) {
    const t = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
    assert.ok(!t.includes('examples: none \u2014'), `${rel}: em-dash skip token`);
    const { prose, fenced } = splitFences(t);
    assert.ok(prose.some((l) => l.includes(token)), `${rel}: no ASCII-hyphen skip token in prose`);
    if (!NO_CARD.includes(rel)) {
      assert.ok(fenced.some((l) => l.includes(token)), `${rel}: no ASCII-hyphen skip token in the card fence`);
    }
  }
});
~~~~
2. command: `git add tests/adapter-protocol-parity.test.js && git commit -m "test(epfc-4): EB1 requires the skip token in prose and in the card fence" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if git reports `index.lock`, a parallel unit is committing: re-run this command after a few seconds)
   expect: 0
3. command: `git diff --quiet HEAD -- tests/adapter-protocol-parity.test.js`
   expect: 0

## Do NOT touch
- `tests/adapter-protocol-parity.test.js` outside the EB1 block: the epfb-2 comment above it, EB2 and every other check stay byte-identical.
- `agents/reviewer.md`, `templates/persona-protocol.md`, the two `.claude/` mirrors, `CONTEXT.md` and the two ports (the seven files EB1 reads): the test pins their current text. epfc-5 edits a different `CONTEXT.md` entry in parallel.
- `bin/cli.js`: epfc-3 owns it; `splitFences` is a local copy of its fence regexes on purpose.
- `docs/plans/epfb-criteria/` and `docs/plans/epfc-criteria/`: read-only for this unit.

## Acceptance criteria
1. run: `bash docs/plans/epfc-criteria/epfc4-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; prints `EB1 does not call splitFences`, exit 1.
2. run: `bash docs/plans/epfc-criteria/epfc4-ac2.sh`
   exit: 0
   stdout: `epfc-4 mutations killed`
   mutation: skip edit 1; the old EB1 survives the prose-copy deletion, so it prints `(a) prose-token deletion survived EB1`, exit 1 (observed at 948fb02).
3. run: `bash docs/plans/epfb-criteria/epfb2-ac2.sh`
   exit: 0
   stdout: `epfb-2 mutations killed`
   check: green at 948fb02 on purpose; it keeps the epfb-2 em-dash and EB2 proofs valid against the new EB1.
   mutation: rename the check so it no longer starts with `EB1 `; prints `(a) no FAIL EB1`, exit 1.
4. run: `bash docs/plans/epf-criteria/scope.sh epfc-4 'tests/adapter-protocol-parity\.test\.js'`
   exit: 0
   stdout: empty
   mutation: also commit `CONTEXT.md`; prints `out of scope: CONTEXT.md`, exit 1.
5. run: `bash docs/plans/epf-criteria/vtargeted.sh 'adapter protocol-port parity'`
   exit: 0
   stdout: empty
   check: green at 948fb02 on purpose; it guards the rest of the parity suite.
   mutation: delete the card's `examples: <count> | examples: none - <one-line reason>` line from `agents/reviewer.md`; prints `section group failed: adapter protocol-port parity`, exit 1.
6. run: `bash docs/plans/epf-criteria/range.sh epfc-4 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
7. run: `bash docs/plans/epf-criteria/range.sh epfc-4 tail tests/adapter-protocol-parity.test.js`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/adapter-protocol-parity.test.js (the new EB1 passes on arrival because the prose and card copies exist; criterion 2 proves each half is not vacuous)
blast-radius: tests/adapter-protocol-parity.test.js:292 (EB1; `assert`, `fs`, `path`, `REPO_ROOT` and `check` are defined at the top of the file); test-only. `docs/plans/epfb-criteria/epfb2-ac1.sh` and `epfb2-ac2.sh` grep `^OK   EB1 ` / `^FAIL EB1 `, which the kept name prefix satisfies.
commit-message: test(epfc-4): EB1 requires the skip token in prose and in the card fence
trailer: the trailer names the model you actually ran on.
parallel: four other units edit other files in the same tree; stage only your file, by path.
measured: each of the six card files holds the token once in prose and once inside the card fence; CONTEXT.md holds it once, in prose (:1054). The `\u2014` in the test source is the six-character JavaScript escape, not a literal em dash; keep it that way.
diagnosis: none
review-packet:
~~~
unit: epfc-4 (plan docs/plans/2026-10-13-escalation-packet-followups-3.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epfc-5

- Suggested model: `haiku`
- Depends on / blocked by: none (parallel-safe)
- Spec step: Step 5; closes note 5.

``````
Unit: epfc-5

## Objective
In `CONTEXT.md`'s **Escalation packet** entry, the alias sentence names the template file: `(`agents/reviewer.md` and `templates/persona-protocol.md`)` instead of `(`agents/reviewer.md` and the template)`. Update the one criterion that pins the old sentence, `docs/plans/epfb-criteria/epfb1-ac3.sh` line 8, so it pins the new one and stays green.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-3.md`, section `### Unit: epfc-5`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `CONTEXT.md` (anchor: line matching `names this same term, not a second concept.`, in the **Escalation packet** entry)
- `docs/plans/epfb-criteria/epfb1-ac3.sh` (anchor: line matching `and the template), names this same term`)

## Ordered edits
1. file: `CONTEXT.md` (the alias sentence, re-flowed; every line stays within 80 columns)
   anchor: line matching `names this same term, not a second concept.`
   indent: 2
   before:
~~~~
  `view.sh`, the **packet viewer** (epa-3). The protocol's own heading for
  it, **Durable escalation packet** (`agents/reviewer.md` and the template),
  names this same term, not a second concept.
~~~~
   after:
~~~~
  `view.sh`, the **packet viewer** (epa-3). The protocol's own heading for
  it, **Durable escalation packet** (`agents/reviewer.md` and
  `templates/persona-protocol.md`), names this same term, not a second
  concept.
~~~~
2. file: `docs/plans/epfb-criteria/epfb1-ac3.sh` (the pinned sentence follows the glossary)
   anchor: line matching `and the template), names this same term`
   indent: 0
   before:
~~~~
printf '%s' "$entry" | grep -qF "The protocol's own heading for it, **Durable escalation packet** (\`agents/reviewer.md\` and the template), names this same term, not a second concept." \
~~~~
   after:
~~~~
printf '%s' "$entry" | grep -qF "The protocol's own heading for it, **Durable escalation packet** (\`agents/reviewer.md\` and \`templates/persona-protocol.md\`), names this same term, not a second concept." \
~~~~
3. command: `git add CONTEXT.md docs/plans/epfb-criteria/epfb1-ac3.sh && git commit -m "docs(epfc-5): the Escalation packet alias names templates/persona-protocol.md" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if git reports `index.lock`, a parallel unit is committing: re-run this command after a few seconds)
   expect: 0
4. command: `git diff --quiet HEAD -- CONTEXT.md docs/plans/epfb-criteria/epfb1-ac3.sh`
   expect: 0

## Do NOT touch
- `CONTEXT.md` outside the three lines of edit 1 (which become four): in particular the skip-token line (:1054), which epfc-4's EB1 reads in parallel.
- `docs/plans/epfb-criteria/epfb1-ac3.sh` outside line 8: its reviewer and template heading pins stay as they are.
- `agents/reviewer.md` and `templates/persona-protocol.md`: the headings are correct; editing them would make this a stamped unit.
- `docs/plans/epfb-criteria/epfb4-ac3.sh` (epfc-2 edits it in parallel) and `docs/plans/epfc-criteria/` (read-only).

## Acceptance criteria
1. run: `bash docs/plans/epfc-criteria/epfc5-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; prints `alias sentence does not name templates/persona-protocol.md`, exit 1.
2. run: `bash docs/plans/epfb-criteria/epfb1-ac3.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 2 (keep edit 1); prints `alias sentence missing from the entry`, exit 1.
3. run: `bash docs/plans/epf-criteria/scope.sh epfc-5 '(CONTEXT\.md|docs/plans/epfb-criteria/epfb1-ac3\.sh)'`
   exit: 0
   stdout: empty
   mutation: also commit `agents/reviewer.md`; prints `out of scope: agents/reviewer.md`, exit 1.
4. run: `bash docs/plans/epf-criteria/vtargeted.sh 'protocol doc-drift' '[[link]] integrity'`
   exit: 0
   stdout: empty
   check: green at 948fb02 on purpose; it guards the glossary's section counts and links.
   mutation: write `[[no-such-term]]` into the entry; prints `section group failed: [[link]] integrity`, exit 1.
5. run: `bash docs/plans/epf-criteria/range.sh epfc-5 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
6. run: `bash docs/plans/epf-criteria/range.sh epfc-5 tail CONTEXT.md docs/plans/epfb-criteria/epfb1-ac3.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on `CONTEXT.md`; prints `1`, exit 0.

## Pre-resolved context
tdd: no CONTEXT.md (glossary prose; the criteria scripts are the tests)
blast-radius: docs/plans/epfb-criteria/epfb1-ac3.sh:8 (the only reader that pins this sentence, measured by grep); tests/adapter-protocol-parity.test.js reads CONTEXT.md:1054 only, which this unit does not touch.
commit-message: docs(epfc-5): the Escalation packet alias names templates/persona-protocol.md
trailer: the trailer names the model you actually ran on.
parallel: four other units edit other files in the same tree; stage only your two files, by path.
unstamped: CONTEXT.md and docs/plans/ are not version-stamped; no version bump, no CHANGELOG entry.
diagnosis: none
review-packet:
~~~
unit: epfc-5 (plan docs/plans/2026-10-13-escalation-packet-followups-3.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````
