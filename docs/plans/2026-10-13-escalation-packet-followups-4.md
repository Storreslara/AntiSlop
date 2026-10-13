# Escalation packet follow-ups, round 4 (epfd-1..epfd-3): the epfc carry-forward items

Status: FINAL (spec-master, 2026-10-13). **Three dispatchable units**, so this
is the **fast path**: the nine-element dispatch contracts are in the last
section of this file, and `task-master` is not needed. The units are
**file-disjoint and meant to run in parallel**.
Baseline: HEAD ba198a5, version 0.31.162. **No unit is stamped:** none touches
`agents/*.md` or `templates/*`, so no unit bumps the version, adds a CHANGELOG
entry or regenerates `.claude/` mirrors.

## Goal

Close the epfc "Live carry-forward" items in
`.claude/agent-memory/scribe/project_epa2_completion.md` (epfc closure
section), plus the untested `splitFences` helper. Goal clauses map to criteria:
item 1 (mutant (d) in `epfb4-ac3.sh` finds its line with `text.indexOf(line)`)
→ epfd-1 criteria 1-3;
item 2 (F5 pins one input only and overlaps F2) → epfd-2 criteria 1-4
(decided: add the bare `## ` input; add no trailing-newline input, and keep
the F2 overlap, for the measured reasons in Clarifications);
item 3 (`splitFences` in `tests/adapter-protocol-parity.test.js` has no direct
test) → epfd-3 criteria 1-4;
item 4 (watch item j, `validate.sh` once exiting 1 under concurrency) → **no
unit**. It is unreproduced and a documented non-goal; it stays out of scope.

## Context

### Item inventory

| # | Item | Unit | Disposition |
|---|---|---|---|
| 1 | Mutant (d) in `docs/plans/epfb-criteria/epfb4-ac3.sh` locates its line with `text.indexOf(line)` | epfd-1 | The mutant's loop takes the line index (`for (const [li, line] of text.split('\n').entries())`) and looks ahead from `li + 1`. Measured on a scratch copy: with an opener line that repeats an **earlier** line, the indexOf mutant gives `["H1","H2"]` and the index mutant gives `["H1","H2","H3"]`. A second fixture whose opener repeats a **later** line rules out a `lastIndexOf` "fix" (`["H1","H3"]` expected). |
| 2 | F5 in `tests/protocol-cross-references.test.js` pins only `'## A\nx\n## B'` and overlaps F2 | epfd-2 | **Add the bare `## ` input** (text `'## '`: one section, empty title, empty preamble, join `'\n## '`). Measured: a parser that needs a non-space after `## ` passes the **whole** suite at HEAD ("All protocol-cross-references checks passed."); the new input kills it. **No trailing-newline input**: a parser that drops a trailing newline already fails F2 and F4 (measured), so that input would add no kill. **The F2 overlap stays**: F5's first-line loop gives the cause by name, and `epfc3-ac2.sh` (b) greps that message. |
| 3 | `splitFences` (local to the parity test since epfc-4) has no direct test | epfd-3 | New check **SF1** in the same file, six cases: backtick fence, tilde fence, info string, unclosed fence, other-character closer, shorter closer. Nothing is exported from `bin/`. Six mutants of `splitFences`, one per case, each fail SF1 on their own case. |
| 4 | Watch item j (`validate.sh` exit 1 under concurrency) | none | Out of scope (user instruction). R4 below keeps the existing re-run-alone rule. |

### Contract hygiene (reused from rounds 2 and 3, binding on every contract here)

1. Each criterion's `stdout:` line is the script's literal output on success,
   byte for byte. `range.sh <unit> trailer` prints `1 ` (a 1 then one space).
2. The commit trailer names the model the implementer **actually ran on**.
   Each contract writes its suggested tier and says to substitute the real one.
3. Every `run:` was executed: red at HEAD (except criteria marked `check:`),
   and green in a prototype worktree with this plan's criteria committed and
   all three units' edits applied **from this file's before/after blocks** by
   script and committed. It was also green in three **isolated** worktrees,
   each holding only one unit on top of the criteria commit.

### Parallel execution rules (reused from round 3)

- File sets are disjoint (intersection table in the dispatch preamble).
  epfd-1's criteria run `tests/protocol-cross-references.test.js` (epfd-2's
  file) in scratch worktrees of HEAD; the new F5 input contains no fence, so
  mutants (a), (b), (d), (e) fail F4 exactly as before (verified in the
  combined run).
- Each contract stages **only its own file by explicit path** and never runs
  `git add -A`, `git add -u` or `git commit -a`. The final self-check is
  `git diff --quiet HEAD -- <own file>`.
- If `git commit` reports an `index.lock`, another unit is committing. Re-run
  the same command after a few seconds. Never delete the lock.

### Prior FAIL history and notes sweep (Implementer-tier ratchet input)

- No `.fail` record exists for any epf-*, epfb-* or epfc-* unit (the epfc
  closure note records five PASSes; no FAIL is mentioned anywhere in it).
- Notes sweep, `bin/marker-audit.sh . --notes --surface=<path>`, 2026-10-13,
  557 markers. `epfb4-ac3.sh`: 0 notes. `protocol-cross-references.test.js`:
  3 notes (0 spec, 2 code, 1 untagged); the relevant one is epfc-3's NOTE[code]
  "F5 duplicates part of F2's guarantee … F5's first-line loop only adds a
  clearer failure message" — **disposition:** kept on purpose (item 2 above).
  The other two (gh348-2 slim-template dangle, rgh-u2-1 Replay sentence) are
  unrelated. `adapter-protocol-parity.test.js`: 2 NOTE[spec] (esf-flag-prose
  timing anchor; reviewer-changes-examples-lean-1 port wording) and 14
  untagged, none naming `splitFences`, EB1 or fences — **disposition:** out of
  scope, untouched. The sweep is best effort (gitignored, per-clone records).

### Measured facts (2026-10-13, HEAD ba198a5)

- `for (const line of text.split('\n')) {` and `if (open) fence =` each occur
  once in `bin/cli.js` (:726 and inside `parseProtocolSections`), so mutant
  (d)'s two substitutions have unique anchors.
- In the parity test, each splitFences mutant anchor occurs once:
  `(`{3,}(?=[^`]*$)|~{3,})`, `|~{3,})/.exec(line)`,
  `close[1][0] === fence.ch && `, ` && close[1].length >= fence.len`,
  `return { prose, fenced };`. `if (failures) {` occurs once.
- SF1's cases run in order and the first failing case throws, so each mutant
  is reported on its own case name (verified for all six).
- The parity test requires no module from `bin/`; SF1 keeps it that way.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-13 Edge cases / failure handling: Q What does "position-exact" have to rule out for mutant (d)? → A (self-resolved): both wrong-occurrence lookups. `indexOf` fails when the opener repeats an earlier line; `lastIndexOf` fails when it repeats a later one. `epfd1-ac1.sh` runs one fixture for each, so only a line-index lookahead passes.
- 2026-10-13 Technical constraints & tradeoffs: Q Item 2: add the trailing-newline input as well, since it is cheap? → A (self-resolved): no. A parser that drops a trailing newline already fails F2 and F4 (measured, and re-checked by `epfd2-ac2.sh` (b) so the reason stays true). An input that kills nothing new is a forced change. The user may overrule (Open Question 1).
- 2026-10-13 Technical constraints & tradeoffs: Q Item 2: remove F5's overlap with F2? → A (self-resolved): no. F5's first-line loop names the cause ("opens with a ## line"), F2 only says "round-trip differs", and `epfc3-ac2.sh` (b), a committed criterion, greps F5's message.
- 2026-10-13 Technical constraints & tradeoffs: Q Item 3: test `splitFences` where? → A (self-resolved): in the same test file, as check SF1 calling the local function. No export, no new file; `epfd3-ac1.sh` fails if the file starts requiring a `bin/` module.
- 2026-10-13 Terminology consistency: Q "a `## `-only-line text": a text that is just a bare `## ` line, or a text made only of header lines? → A (self-resolved): a bare `## ` line (`'## '`, empty title). It is the only reading with a measured surviving mutant; a header-only text (`'## A\n## B'`) is parsed by the same path as F5's existing input.

## Risks / dependencies

- R1: The units are file-disjoint and run in parallel; none depends on another.
- R2: Criteria are scripts in `docs/plans/epfd-criteria/`, committed with this
  plan and read-only for every unit. They source `docs/plans/epf-criteria/lib.sh`
  and reuse `scope.sh`, `range.sh` and `vtargeted.sh`. A unit's commits are
  found by the subject scope `^[a-z]+\(epfd-N\): `.
- R3: The mutation scripts make scratch worktrees under `mktemp -d` and
  remove them on exit. If a run is killed, `git worktree prune` cleans up.
- R4: Item j stays a watch item. If a `vtargeted.sh` group fails with no
  matching test failure while siblings run, re-run it alone before reporting a
  FAIL, and record the case for j.
- R5: Do not paste a criterion as Bash text. Run `bash <script>`.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every criterion was run red at HEAD
  (or marked `check:`) and green in combined and isolated prototype worktrees.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The
  criteria are committed scripts.
- P3 "Version-stamp discipline": satisfied, vacuously. No unit touches
  `agents/*.md` or `templates/*`.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. No persona
  wording changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied. No section is added;
  epfd-2 and epfd-3 run their section groups through `vtargeted.sh`.

## Steps

### Step 1: epfd-1, make mutant (d) position-exact (item 1)
**Affected files:** `docs/plans/epfb-criteria/epfb4-ac3.sh` only.
**Acceptance:** `epfd1-ac1.sh` (both duplicate-line fixtures parse as a
line-index lookahead would); `epfb4-ac3.sh` still prints
`epfb-4 mutations killed`; `epfc2-ac2.sh` still catches the case-3 and case-4
deletions; scope; trailer; tail.

### Step 2: epfd-2, add the bare `## ` input to F5 (item 2)
**Affected files:** `tests/protocol-cross-references.test.js` only.
**Acceptance:** `epfd2-ac1.sh`; `epfd2-ac2.sh` (bare-header mutant fails F5;
trailing-newline mutant fails F2); `epfc3-ac1.sh` and `epfc3-ac2.sh` still
green; scope; targeted; trailer; tail.

### Step 3: epfd-3, test `splitFences` directly (item 3)
**Affected files:** `tests/adapter-protocol-parity.test.js` only.
**Acceptance:** `epfd3-ac1.sh`; `epfd3-ac2.sh` (six mutants, each fails SF1 on
its own case); `epfc4-ac1.sh` and `epfc4-ac2.sh` still green; scope; targeted;
trailer; tail.

## Open Questions

1. (from CHK4) Item 2 adds no trailing-newline input, because F2 and F4
   already kill the trailing-newline mutant. Recommended default: **keep it
   out**. Overrule if you want the input for documentation value; it would be
   one more assertion block in epfd-2, with no new criterion.

Nothing else is open; every decision is in Clarifications.

## Self-check
- CHK1: Does each of items 1-3 map to a unit and to criteria that fail without it? — PASS (Goal mapping; `epfd1-ac1`, `epfd2-ac1`, `epfd2-ac2`, `epfd3-ac1`, `epfd3-ac2` all red at ba198a5 with the messages in each contract's `mutation:` line)
- CHK2: Is item 4 explicitly excluded, with no unit and no criterion? — PASS (Goal; item inventory row 4; R4)
- CHK3: Are the three file sets pairwise disjoint and stated exactly? — PASS (intersection table; `scope.sh` enforces each)
- CHK4: Is the trailing-newline half of item 2 decided, with a reason the user can check? — FAIL (missing): the first draft dropped it silently — converted to Open Question 1 (and `epfd2-ac2.sh` (b) makes the reason machine-checked)
- CHK5: Does epfd-1's criterion rule out a `lastIndexOf` substitute as well as `indexOf`? — FAIL (missing): the first draft had one fixture only — revised in place (second fixture in `epfd1-ac1.sh`)
- CHK6: Do prior units' committed criteria stay green (epfc2-ac2, epfc3-ac1/ac2, epfc4-ac1/ac2, epfb4-ac3)? — PASS (each is re-run as a `check:` criterion by the unit that touches its file)
- CHK7: Does every SF1 mutant fail on its own case name, not just "some SF1 failure"? — PASS (`mut` in `epfd3-ac2.sh` greps the case name inside the `FAIL SF1` line)
- CHK8: Is any unit stamped? — PASS (none; P3 line)
- CHK9: Do the contracts' `stdout:` lines match the scripts' literal output? — PASS (observed in the prototype)
- CHK10: Does every contract reach 7/7 under `contract-guard`? — PASS (all three `contract-guard: haiku … score=7/7`, run after this file was written)
- CHK11 (replay, examples-2 [host] on tests/adapter-protocol-parity.test.js): Does epfd3-ac1 still fail under its own `mutation:` line? — PASS (skipping edit 1 prints `SF1 not OK`, observed at ba198a5)
- CHK12: Does each `mutation:` line state what its own criterion prints? — FAIL (conflicting): two first-draft lines named the wrong message (epfd-1 criterion 3 used a mutant that criterion 2 catches first; epfd-2 criterion 4 named `(b) header-first template survived`, but F2 still fails, so it prints `(b) no FAIL F5`) — revised in place, both re-observed in the prototype

Glossary drift (prose mode, advisory). Lens 1: none. Lens 2: none ("card
fence", "skip token" as in round 3). Lens 3: none load-bearing; "bare `## `
line" and "mutant" are test vocabulary, not domain terms.

## Scribe update hint
After all three units PASS, mark the epfc carry-forward items closed in
`.claude/agent-memory/scribe/project_epa2_completion.md`: mutant (d) by epfd-1
(line index, two fixtures); F5 by epfd-2 (bare `## ` input; trailing newline
deliberately left to F2/F4; the F2 overlap kept on purpose); and the untested
`splitFences` by epfd-3 (SF1). Item j stays a watch item.

## Dispatch contracts (spec-master, fast path, 2026-10-13)

Three dispatchable units; none held; **all three may run in parallel**.
**Retrieval contract.** No tracker issue exists for these units (fast path).
Fetch a unit's dispatch prompt by reading
`docs/plans/2026-10-13-escalation-packet-followups-4.md` with the Read tool,
finding the `### Unit: epfd-N` heading, and sending the interior of the
six-backtick fenced block that follows it as the dispatch prompt (nested fences
are payloads). Its first line is the literal `Unit: epfd-N`, and
`node bin/contract-guard.js docs/plans/2026-10-13-escalation-packet-followups-4.md --unit=epfd-N`
finds the block. Commit subjects never carry an issue number.

**Intersection table:**

| unit | files (exact) | shared with | depends on |
|---|---|---|---|
| epfd-1 | `docs/plans/epfb-criteria/epfb4-ac3.sh` | none | none |
| epfd-2 | `tests/protocol-cross-references.test.js` | none | none |
| epfd-3 | `tests/adapter-protocol-parity.test.js` | none | none |

**Suggested models:** `haiku` for all three: every edit is written out
literally, and there is no FAIL history on these files' units. The orchestrator
recomputes the Escalation ladder at dispatch; a tag can raise the tier but
never lower it. The reviewer tier is decided at dispatch by
`hooks/scripts/reviewer-tier.sh` over the actual diff.

**Verification record:** the five `epfd*` scripts were run at ba198a5 and
were red with the messages in each contract's `mutation:` line. A scratch
worktree then got this plan's criteria committed, and each unit's before/after
blocks were **extracted from this file and applied by script** (each before
block matched exactly once) and committed as `test(epfd-N)`. All 22 criteria
were green there. Three isolated worktrees, one unit each on the criteria
commit, were green for every non-`range` criterion of their unit. The
non-obvious `mutation:` lines (epfd-1 criteria 2 and 3, epfd-2 criterion 4,
epfd-3 criterion 4) were each observed. All three contracts score
`contract-guard: haiku … score=7/7`.

### Unit: epfd-1

- Suggested model: `haiku`
- Depends on / blocked by: none (parallel-safe)
- Spec step: Step 1; closes item 1.

``````
Unit: epfd-1

## Objective
Make mutant (d) in `docs/plans/epfb-criteria/epfb4-ac3.sh` find the opener line by its position. Today its injected lookahead starts at `text.indexOf(line)`, which is the first line with the same text, not necessarily the current one. The new mutant iterates with a line index and looks ahead from `li + 1`, and a guard line stops the script if the index was not added. The script still prints `epfb-4 mutations killed`.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-4.md`, section `### Unit: epfd-1`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `docs/plans/epfb-criteria/epfb4-ac3.sh` (anchor: line matching `text.slice(text.indexOf(line) + line.length + 1)`, which occurs once, directly before the `(d) changed nothing` line)

## Ordered edits
1. file: `docs/plans/epfb-criteria/epfb4-ac3.sh` (replace mutant (d)'s perl line with a two-substitution perl line plus a guard line)
   anchor: line matching `text.slice(text.indexOf(line) + line.length + 1)`
   indent: 0
   before:
~~~~
perl -0pi -e 's/if \(open\) fence =/if (open && \/^ {0,3}(`{3,}|~{3,})[ \\t\\r]*\$\/m.test(text.slice(text.indexOf(line) + line.length + 1))) fence =/' "$wt/bin/cli.js"
~~~~
   after:
~~~~
perl -0pi -e 's/for \(const line of text\.split\(\x27\\n\x27\)\) \{/for (const [li, line] of text.split(\x27\\n\x27).entries()) {/; s/if \(open\) fence =/if (open && \/^ {0,3}(`{3,}|~{3,})[ \\t\\r]*\$\/m.test(text.split(\x27\\n\x27).slice(li + 1).join(\x27\\n\x27))) fence =/' "$wt/bin/cli.js"
grep -q 'const \[li, line\] of text.split' "$wt/bin/cli.js" || { echo "(d) loop index not added"; exit 1; }
~~~~
2. command: `git add docs/plans/epfb-criteria/epfb4-ac3.sh && git commit -m "test(epfd-1): epfb4-ac3 mutant (d) looks ahead from the line index" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if git reports `index.lock`, a parallel unit is committing: re-run this command after a few seconds)
   expect: 0
3. command: `git diff --quiet HEAD -- docs/plans/epfb-criteria/epfb4-ac3.sh`
   expect: 0

## Do NOT touch
- `docs/plans/epfb-criteria/epfb4-ac3.sh` outside the one replaced line: the header comment, mutants (a), (b), (c), (e), the worktree setup and the trap stay byte-identical.
- `bin/cli.js`: the mutant changes only the scratch worktree's copy.
- `tests/protocol-cross-references.test.js` and `tests/adapter-protocol-parity.test.js`: epfd-2 and epfd-3 own them and run in parallel with you.
- `docs/plans/epfc-criteria/` and `docs/plans/epfd-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfd-criteria/epfd1-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; prints `(d) mislocates an opener that repeats an earlier line: got ["H1","H2"]`, exit 1 (observed at ba198a5).
2. run: `bash docs/plans/epfb-criteria/epfb4-ac3.sh`
   exit: 0
   stdout: `epfb-4 mutations killed`
   check: green at ba198a5 on purpose; the new mutant (d) must still fail F4 on case 3.
   mutation: drop the `.entries()` substitution from edit 1's perl line (keep the second); prints `(d) loop index not added`, exit 1.
3. run: `bash docs/plans/epfc-criteria/epfc2-ac2.sh`
   exit: 0
   stdout: `case 3 and case 4 deletions caught`
   check: green at ba198a5 on purpose; it proves the new (d) still catches a deleted F4 case 3.
   mutation: delete mutant (d)'s five lines (the perl line, the guard line and its three check lines) and commit; criterion 2 stays green, and this prints `(d) case deletion not caught by epfb4-ac3.sh`, exit 1 (observed in the prototype).
4. run: `bash docs/plans/epf-criteria/scope.sh epfd-1 'docs/plans/epfb-criteria/epfb4-ac3\.sh'`
   exit: 0
   stdout: empty
   mutation: also commit `bin/cli.js`; prints `out of scope: bin/cli.js`, exit 1.
5. run: `bash docs/plans/epf-criteria/range.sh epfd-1 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
6. run: `bash docs/plans/epf-criteria/range.sh epfd-1 tail docs/plans/epfb-criteria/epfb4-ac3.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: no docs/plans/epfb-criteria/epfb4-ac3.sh (the file is itself a mutation test; criterion 1 tests its mutant)
blast-radius: docs/plans/epfb-criteria/epfb4-ac3.sh:25 (the only line replaced); read by `docs/plans/epfc-criteria/epfc2-ac2.sh` (criterion 3) and `docs/plans/epfd-criteria/epfd1-ac1.sh` (criterion 1, which runs the lines between the last `git checkout -q -- bin/cli.js` and the `(d) changed nothing` line); no test and no validate.sh section reads it.
commit-message: test(epfd-1): epfb4-ac3 mutant (d) looks ahead from the line index
trailer: the trailer names the model you actually ran on.
parallel: two other units edit other files in the same tree; stage only your file, by path.
quoting: copy edit 1 byte for byte; `\x27` (a single quote inside a single-quoted perl program), `\\n`, `\\t\\r`, `\$` and `\/` are load-bearing.
measured: in `bin/cli.js` both anchors occur once; under the new mutant F4 still fails on case 3 (`also swallowed`).
diagnosis: none
review-packet:
~~~
unit: epfd-1 (plan docs/plans/2026-10-13-escalation-packet-followups-4.md)
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

### Unit: epfd-2

- Suggested model: `haiku`
- Depends on / blocked by: none (parallel-safe)
- Spec step: Step 2; closes item 2.

``````
Unit: epfd-2

## Objective
Extend check F5 in `tests/protocol-cross-references.test.js` with a second no-preamble input, a bare `## ` line (`'## '`): one section with an empty title, an empty-string preamble, and a join of `'\n## '`. Today a parser that needs a non-space after `## ` passes the whole suite. Add a two-line comment saying why there is no trailing-newline input (F2 and F4 already fail a parser that drops one). F5's name and its existing assertions stay unchanged.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-4.md`, section `### Unit: epfd-2`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/protocol-cross-references.test.js` (anchor: line matching `'\n' + t, 'the join adds exactly one leading newline');`, which occurs once, in F5)

## Ordered edits
1. file: `tests/protocol-cross-references.test.js` (F5: comment lines and the bare `## ` input)
   anchor: line matching `'\n' + t, 'the join adds exactly one leading newline');`
   indent: 0
   before:
~~~~
// keeps every live template's first line off `## `.
check('F5 no-preamble text: empty preamble, the join adds a leading newline (non-goal, pinned)', () => {
  const t = '## A\nx\n## B';
  const r = cli.parseProtocolSections(t);
  assert.deepStrictEqual(r.sections.map((s) => s.header), ['A', 'B'], 'headers for a no-preamble text');
  assert.strictEqual(r.preamble, '', 'a no-preamble text has an empty-string preamble');
  assert.strictEqual([r.preamble, ...r.sections.map((s) => s.text)].join('\n'), '\n' + t, 'the join adds exactly one leading newline');
~~~~
   after:
~~~~
// keeps every live template's first line off `## `.
// epfd-2: a bare `## ` line (empty title) is no-preamble text too. No
// trailing-newline input: F2 and F4 already fail a parser that drops one.
check('F5 no-preamble text: empty preamble, the join adds a leading newline (non-goal, pinned)', () => {
  const t = '## A\nx\n## B';
  const r = cli.parseProtocolSections(t);
  assert.deepStrictEqual(r.sections.map((s) => s.header), ['A', 'B'], 'headers for a no-preamble text');
  assert.strictEqual(r.preamble, '', 'a no-preamble text has an empty-string preamble');
  assert.strictEqual([r.preamble, ...r.sections.map((s) => s.text)].join('\n'), '\n' + t, 'the join adds exactly one leading newline');
  const bare = cli.parseProtocolSections('## ');
  assert.deepStrictEqual(bare.sections.map((s) => s.header), [''], 'a bare ## line is a section header with an empty title');
  assert.strictEqual(bare.preamble, '', 'a bare ## line has an empty-string preamble');
  assert.strictEqual([bare.preamble, ...bare.sections.map((s) => s.text)].join('\n'), '\n## ', 'the join adds exactly one leading newline to a bare ## line');
~~~~
2. command: `git add tests/protocol-cross-references.test.js && git commit -m "test(epfd-2): F5 pins a bare ## line as no-preamble text" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if git reports `index.lock`, a parallel unit is committing: re-run this command after a few seconds)
   expect: 0
3. command: `git diff --quiet HEAD -- tests/protocol-cross-references.test.js`
   expect: 0

## Do NOT touch
- `tests/protocol-cross-references.test.js` outside edit 1: F1-F4, F5's name, F5's live-template loop and the summary block stay byte-identical (`epfc3-ac1.sh` greps `^OK   F5 ` and `epfc3-ac2.sh` greps F5's `opens with a ## line` message).
- `bin/cli.js`: the parser is correct for this input; this unit only pins it.
- `docs/plans/epfb-criteria/epfb4-ac3.sh` and `tests/adapter-protocol-parity.test.js`: epfd-1 and epfd-3 own them and run in parallel with you.
- `docs/plans/epfc-criteria/` and `docs/plans/epfd-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfd-criteria/epfd2-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; prints `F5 has no bare ## input`, exit 1 (observed at ba198a5).
2. run: `bash docs/plans/epfd-criteria/epfd2-ac2.sh`
   exit: 0
   stdout: `epfd-2 mutations killed`
   mutation: skip edit 1; the bare-header mutant passes every check, so it prints `(a) bare-header mutant survived`, exit 1 (observed at ba198a5).
3. run: `bash docs/plans/epfc-criteria/epfc3-ac1.sh`
   exit: 0
   stdout: empty
   check: green at ba198a5 on purpose; F5 must still be OK.
   mutation: rename the check so it no longer starts with `F5 `; prints `F5 not OK`, exit 1.
4. run: `bash docs/plans/epfc-criteria/epfc3-ac2.sh`
   exit: 0
   stdout: `epfc-3 mutations killed`
   check: green at ba198a5 on purpose; F5's null-preamble and header-first-template proofs stay valid.
   mutation: delete F5's live-template loop; F2 still fails the header-first template, so this prints `(b) no FAIL F5`, exit 1 (observed in the prototype).
5. run: `bash docs/plans/epf-criteria/scope.sh epfd-2 'tests/protocol-cross-references\.test\.js'`
   exit: 0
   stdout: empty
   mutation: also commit `bin/cli.js`; prints `out of scope: bin/cli.js`, exit 1.
6. run: `bash docs/plans/epf-criteria/vtargeted.sh 'protocol cross-references'`
   exit: 0
   stdout: empty
   check: green at ba198a5 on purpose; it guards the rest of the suite.
   mutation: write the bare input's expected join as `'## '`; prints `section group failed: protocol cross-references`, exit 1.
7. run: `bash docs/plans/epf-criteria/range.sh epfd-2 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
8. run: `bash docs/plans/epf-criteria/range.sh epfd-2 tail tests/protocol-cross-references.test.js`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/protocol-cross-references.test.js (the new assertions pass on arrival because they pin current behaviour; criterion 2 proves they are not vacuous)
blast-radius: tests/protocol-cross-references.test.js:173 (F5; `cli`, `assert` and `check` are defined above it); test-only. `epfb4-ac3.sh` and `epfc2-ac2.sh` run this file in scratch worktrees; the bare `## ` input holds no fence, so their F4 mutants are unaffected.
commit-message: test(epfd-2): F5 pins a bare ## line as no-preamble text
trailer: the trailer names the model you actually ran on.
parallel: two other units edit other files in the same tree; stage only your file, by path.
measured: `parseProtocolSections('## ')` returns preamble `''` and one section `{ header: '', text: '## ' }`; with `line.startsWith('## ')` replaced by `/^## \S/.test(line)` the whole suite passes at ba198a5.
diagnosis: none
review-packet:
~~~
unit: epfd-2 (plan docs/plans/2026-10-13-escalation-packet-followups-4.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epfd-3

- Suggested model: `haiku`
- Depends on / blocked by: none (parallel-safe)
- Spec step: Step 3; closes item 3.

``````
Unit: epfd-3

## Objective
Add check SF1 to `tests/adapter-protocol-parity.test.js`: it calls the file's own `splitFences` (added by epfc-4) on six small texts and checks the prose and fenced lines of each: a backtick fence, a tilde fence, an info string, an unclosed fence, a tilde line inside a backtick fence, and a shorter closer. Nothing is exported from `bin/`, and `splitFences` and EB1 stay unchanged.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-4.md`, section `### Unit: epfd-3`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/adapter-protocol-parity.test.js` (anchor: line matching `if (failures) {`, which occurs once, after EB2)

## Ordered edits
1. file: `tests/adapter-protocol-parity.test.js` (SF1, inserted before the summary block)
   anchor: line matching `if (failures) {`
   indent: 0
   before:
~~~~
if (failures) {
~~~~
   after:
~~~~
// epfd-3: splitFences is a local copy of parseProtocolSections' fence rules, so
// test it directly: backtick and tilde fences, an info string, an unclosed
// fence, and closers that do not match the opener.
check('SF1 splitFences: backtick and tilde fences, info string, unclosed fence, mismatched closers', () => {
  const cases = [
    ['backtick fence', 'a\n```\nb\n```\nc', ['a', 'c'], ['b']],
    ['tilde fence', 'a\n~~~\nb\n~~~\nc', ['a', 'c'], ['b']],
    ['info string', 'a\n```js\nb\n```\nc', ['a', 'c'], ['b']],
    ['unclosed fence runs to the end', 'a\n```\nb\nc', ['a'], ['b', 'c']],
    ['a tilde line does not close a backtick fence', 'a\n```\nb\n~~~\nc\n```\nd', ['a', 'd'], ['b', '~~~', 'c']],
    ['a shorter closer does not close', 'a\n````\nb\n```\nc\n````\nd', ['a', 'd'], ['b', '```', 'c']],
  ];
  for (const [name, t, prose, fenced] of cases) {
    const r = splitFences(t);
    assert.deepStrictEqual(r.prose, prose, `${name}: prose lines`);
    assert.deepStrictEqual(r.fenced, fenced, `${name}: fenced lines`);
  }
});

if (failures) {
~~~~
2. command: `git add tests/adapter-protocol-parity.test.js && git commit -m "test(epfd-3): SF1 tests splitFences directly" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer; if git reports `index.lock`, a parallel unit is committing: re-run this command after a few seconds)
   expect: 0
3. command: `git diff --quiet HEAD -- tests/adapter-protocol-parity.test.js`
   expect: 0

## Do NOT touch
- `tests/adapter-protocol-parity.test.js` outside the inserted block: `splitFences`, EB1, EB2 and every other check stay byte-identical (`epfc4-ac1.sh` reads EB1's body, and `epfd3-ac2.sh` mutates `splitFences` by exact text).
- `bin/cli.js`: do not export a fence helper; SF1 tests the local copy.
- `docs/plans/epfb-criteria/epfb4-ac3.sh` and `tests/protocol-cross-references.test.js`: epfd-1 and epfd-2 own them and run in parallel with you.
- `docs/plans/epfc-criteria/` and `docs/plans/epfd-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfd-criteria/epfd3-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; prints `SF1 not OK`, exit 1 (observed at ba198a5).
2. run: `bash docs/plans/epfd-criteria/epfd3-ac2.sh`
   exit: 0
   stdout: `epfd-3 mutations killed`
   mutation: skip edit 1; prints `(a) mutant not caught by SF1 case: backtick fence`, exit 1 (observed at ba198a5).
3. run: `bash docs/plans/epfc-criteria/epfc4-ac1.sh`
   exit: 0
   stdout: empty
   check: green at ba198a5 on purpose; EB1 must still use `splitFences`.
   mutation: rename the check so it no longer starts with `EB1 `; prints `EB1 not OK`, exit 1.
4. run: `bash docs/plans/epfc-criteria/epfc4-ac2.sh`
   exit: 0
   stdout: `epfc-4 mutations killed`
   check: green at ba198a5 on purpose; EB1's prose and card halves stay proven.
   mutation: change EB1's `prose.some(` to `fenced.concat(prose).some(`; prints `(a) prose-token deletion survived EB1`, exit 1.
5. run: `bash docs/plans/epf-criteria/scope.sh epfd-3 'tests/adapter-protocol-parity\.test\.js'`
   exit: 0
   stdout: empty
   mutation: also commit `bin/cli.js`; prints `out of scope: bin/cli.js`, exit 1.
6. run: `bash docs/plans/epf-criteria/vtargeted.sh 'adapter protocol-port parity'`
   exit: 0
   stdout: empty
   check: green at ba198a5 on purpose; it guards the rest of the parity suite.
   mutation: write the unclosed case's expected fenced lines as `['b']`; prints `section group failed: adapter protocol-port parity`, exit 1.
7. run: `bash docs/plans/epf-criteria/range.sh epfd-3 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
8. run: `bash docs/plans/epf-criteria/range.sh epfd-3 tail tests/adapter-protocol-parity.test.js`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/adapter-protocol-parity.test.js (SF1 passes on arrival because `splitFences` already exists; criterion 2 proves each case is not vacuous)
blast-radius: tests/adapter-protocol-parity.test.js:340 (the insertion point; `splitFences` is defined at :294, and `assert` and `check` at the top of the file); test-only.
commit-message: test(epfd-3): SF1 tests splitFences directly
trailer: the trailer names the model you actually ran on.
parallel: two other units edit other files in the same tree; stage only your file, by path.
measured: the cases run in order and the first failing case throws, so each of the six mutants in criterion 2 is reported on its own case name.
diagnosis: none
review-packet:
~~~
unit: epfd-3 (plan docs/plans/2026-10-13-escalation-packet-followups-4.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````
