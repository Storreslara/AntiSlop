# Quoted-payload closure for the human-decision gate (2026-10-04)

Status: FINAL (spec-master, 2026-10-04). Two units, fast path (five or fewer
units): this document holds the dispatch contracts. There is no task-master
slicing and no tracker issue. Predecessor:
`docs/plans/2026-10-04-escalation-followups.md`, Open Question 1 (esc-fu-1..3
all PASS, HEAD dfce91f).

Scope rule from the user (2026-10-04): this spec is written **in general
terms only**. It names no concrete bypass spelling beyond the three already
committed as QP-1..QP-3. The frozen family table of blocked forms and the
over-block measurement are **implementer/operator steps**, with runnable
acceptance criteria below. Neither was prototyped at spec time.

## Goal

Close the quoted-payload bypass of `hooks/scripts/human-decision-gate.sh`.
A glob inside a quoted string that the command hands to a second shell for
re-parsing must count as a pattern for the gate's early exit, the same way
an unquoted glob already does.

- **qp-1** (gate, suite, version; opus):
  - add a quoted-payload predicate to the gate;
  - flip QP-1 and QP-2 from `allowed` to `blocked`;
  - pin QP-3 `blocked` as an accepted fail-closed over-block, and add a
    literal-`D*` fixture check to it;
  - freeze a family table with one row per new predicate branch, each killed
    by its own mutant;
  - run the differential sweep and pin every new over-block class as OB-14
    onward;
  - fix the esc-fu-1 reviewer notes: (a) the suite comment's mechanism,
    (b) the gate header's lead-in wording, (c) the QP-3 literal file check;
  - bump to 0.31.120, add a CHANGELOG entry and run `node bin/cli.js --update`,
    all in one commit.
- **qp-2** (glossary only; sonnet): make the `docs/harness-glossary.md`
  entries that qp-1 falsifies agree with the new pins.

## Context

### Measured mechanism (read from the code at dfce91f)

- The early exit is at gate `:702-712`. `joined` deletes only the quote
  characters. QP-1, QP-2 and QP-3 therefore **do** spell `human-review` in
  `joined`.
- They pass the early exit because `DECISION` is never spelled, and because
  `glob_names_tokens()` (`:430-448`) reads the **skeleton**. The skeleton
  masks the quoted span, so the quoted `D*` never reaches `glob_scan_words()`
  and `glob_d` stays 0.
- Once the early exit is passed, a command that names a token only through a
  glob reaches the fail-closed branch (`:717-720`). Only
  `command_is_provably_benign()` and `is_sanctioned_marker_write()` can allow
  it there. A second-shell program is not in `program_allowed()`
  (`hooks/scripts/lib/benign-command.sh:36-52`), so the branch denies it.
- **Consequence for the design.** A predicate whose only effect is to set
  `glob_h`/`glob_d` more often can only turn an allow into a deny, never the
  reverse. That is the monotonicity property the sweep's
  `new_allowances=0` criterion checks.
- QP-3 writes nothing under POSIX `sh` (dash, `bash --posix`), because POSIX
  sh does not pathname-expand a non-interactive redirect word. It creates a
  literal file `D*` instead (measured in esc-fu-1, reviewer note (c)).

### esc-fu-1 reviewer notes folded in (`esc-fu-1.pass`, read 2026-10-04)

- (a) The suite comment at `tests/human-decision-gate.test.sh:1001-1003`
  says "neither token is spelled in the joined text". That is false.
  `joined` spells `human-review`. The early exit fires because DECISION is
  never spelled and `glob_names_tokens` skips the quoted `D*`.
- (b) The gate header lead-in at `:696` reads "because the text names
  neither token even as a pattern". It is loose. Before this fix the precise
  form was "does not name both tokens, counting only unquoted globs as
  patterns". After this fix the pattern set also includes the quoted
  payload, so the wording is updated to the post-fix form (Clarifications,
  terminology line).
- (c) QP-3's `overwrite=no` check cannot tell "POSIX sh did not glob" apart
  from "the payload never ran". The row must also assert that a literal file
  `D*` exists in the fixture.

### Prior defect history (`.fail` screen)

The whole `.claude/reviewed/` directory was listed. The records for this
gate and its units were read: `hdg-prose-2.fail` and the esc-* records.

- `hdg-prose-2.fail` hit the **2-FAIL cap on this same gate**, because its
  predicate missed one character dimension, and the first review never
  varied it.
- `esc-left-4.fail`, `esc-chat-6.fail` and `esc-chat-7.fail`: glossary prose
  claimed more than the code does.

What follows from this:
- qp-1 is opus. It carries a frozen family table and per-branch mutants,
  because unbounded "blocks every spelling" criteria are what cause FAIL
  loops on this gate.
- qp-2 uses entry-scoped, claim-anchored greps.
- Neither unit has a `.fail` of its own, so the Implementer-tier ratchet
  does not apply.

### Marker-audit `--notes` sweep

The sweep was not run at spec time. The spec session's Bash is gated by
`reviewed-path-gate.sh`, and the classifier constraints of this session
apply. That is **incomplete, not empty**. The `.pass` notes on the touched
surfaces were read directly instead:
- `esc-fu-1.pass` gives notes a/b/c, which are consumed here.
- `esc-fu-2.pass` NOTE[code] (the frozen family table's closed-vs-pinned
  tension, and long lines) is the deferred "glossary tension" item. It is
  **out of scope** by the user's instruction.
- `esc-left-3.pass` notes are already consumed by esc-fu-1.

The reviewer of each unit re-runs
`bash bin/marker-audit.sh . --notes --surface=<path>` for its surfaces.

### Prior art reused

- `tests/hdg-differential-sweep.sh <old> <new> <corpus.jsonl>` prints
  `total=N new_denials=D new_allowances=A`.
- The corpus recipe is in `docs/plans/2026-10-04-escalation-leftovers.md`
  `:487-493`. esc-left-3 measured `new_allowances=0`, with 14 new denials
  against a cap of 25.
- The OB section is at suite `:1029-1070`, with OB-1..OB-13 and a
  `ob_reasons` array plus a `mapfile` JSON-lines block. New over-blocks
  extend the same arrays.
- `fg_overwrites()` is at suite `:916-924`. Its contract stays unchanged for
  the FG and FP rows.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Missing
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-04 Functional scope & success criteria: Q How wide is the rule:
  only a quoted string handed to a second shell for re-parsing, or every
  quoted pattern given to a non-allowlisted program? → A: only commands that
  hand a quoted string to a second shell for re-parsing. Everything else is
  a declared residual, per user.
- 2026-10-04 Functional scope & success criteria: Q What does QP-3 pin after
  the fix? → A: `blocked`, as an accepted fail-closed over-block. It keeps
  its no-write reachability line, plus a literal-`D*` check through a new
  fixture helper, per user.
- 2026-10-04 Non-functional attributes: Q What over-block cost is
  acceptable? → A: `new_allowances=0`, and every new denial is classified.
  Each distinct class is pinned as an accepted over-block row from OB-14 on.
  If new denials exceed 10, stop and escalate to the user, per user.
- 2026-10-04 Edge cases / failure handling: Q May the spec enumerate concrete
  payload spellings, or prototype the gate? → A: no to both. The spec stays
  in general terms. The frozen table and the sweep are implementer/operator
  steps with runnable criteria. Do not route around the classifier blocks,
  per user.
- 2026-10-04 Edge cases / failure handling: Q Where does the fix live: the
  gate, or the shared `lib/benign-command.sh`? → A (self-resolved): the gate
  only. The lib is shared with `reviewed-path-gate.sh`, whose F-1 variant is
  deferred, so changing it would widen the blast radius past this spec.
- 2026-10-04 Technical constraints & tradeoffs: Q Is hunting for further
  bypasses outside the frozen table a qp-1 criterion? → A (self-resolved):
  no. It is an operator step (Operator steps, O2). A spelling outside the
  table is a declared residual, never a FAIL ground for qp-1. The
  hdg-prose-2 cap shows that an open-ended "blocks everything" criterion
  loops.
- 2026-10-04 Terminology consistency: Q The brief's header wording ("counting
  only unquoted globs as patterns") describes the pre-fix gate. Which
  wording lands? → A (self-resolved): the post-fix form, the literal phrase
  `does not name both tokens, counting as patterns only unquoted globs and
  globs in a quoted string handed to a second shell`. The pre-fix form would
  be false once qp-1 lands.
- 2026-10-04 Completion / acceptance signals: Q The glossary's frozen family
  table entry states QP-1..3 are allowed. Is updating it bundling a deferred
  item? → A (self-resolved): no. qp-1 makes that sentence false, so qp-2
  corrects only claims qp-1 falsifies. The deferred "glossary tension" note
  (esc-fu-2.pass NOTE[code]) stays out of scope.

## Assumptions
- AS1: `/bin/sh` is a POSIX shell that does not pathname-expand a
  non-interactive redirect word (measured in esc-fu-1: dash and
  `bash --posix`).
- AS2: The transcript corpus under `~/.claude/projects/-home-sebas-AntiSlop`
  exists at execution time. It is machine-local and may be pruned, so the
  commit message quotes the sweep results and does not depend on the corpus
  persisting.
- AS3: Any concrete classification baseline expires. The sweep is run at
  execution time, and no count from this spec is pinned as absolute.

## Risks / dependencies
- R1 **Over-block on every agent's Bash.** The gate runs on all Bash. It is
  bounded three ways:
  - the rule fires only when the command hands a quoted string to a second
    shell;
  - the sweep enforces `new_allowances=0` and at most 10 new denials, each
    classified and pinned;
  - monotonicity: the predicate only sets glob flags.
- R2 **Mutation proofs under the microworld queue report false FAILs**
  (memoization). Run mutants standalone with
  `GATE_UNDER_TEST=<absolute path>`, and copy `hooks/scripts/lib` beside the
  mutant. A case line reading `rc=1` means the mutant did not start.
- R3 **The gate blocks the implementer's own Bash** when the command text
  names both tokens. Write the suite and scratch scripts with Edit/Write, run
  them as `bash <path>`, and commit with `git commit -F <file>`. The
  reviewed-path gate refuses Bash text that spells the marker directory, so
  read markers with Read.
- R4 **`tests/validate.sh` takes about 10 minutes** (575 s at esc-fu-1).
  Run it in a clean worktree: `git worktree add /tmp/<unit>-v HEAD`, then
  `bash tests/validate.sh` there, with the foreground `timeout` at 600000.
  If it cannot finish, end with the WIP sentinel and the reason "no
  autonomous wake-up available — requires the dispatcher to resume me
  later". The reviewer re-runs it.
- R5 **The safety classifier may refuse to author or run new bypass
  fixtures.** If a family-table row or mutant is refused, do not rephrase
  around the refusal. Stop and report the refused row; the user decides.
  This follows the shared protocol's "Blocked by a gate you do not own" rule.
- R6 **Residuals the rule does not close** (declared, never FAIL grounds):
  - (R-QP-a) a pattern expanded by a program that is not a second shell
    re-parsing a string (pattern-matching utilities, language interpreters);
  - (R-QP-b) a second-shell invocation that the predicate cannot recognise
    from the command text;
  - the existing A3, R-4, R-5 and NL1.
- R7 **Dependencies:** qp-2 depends on qp-1 PASS. It cites the landed QP ids,
  the OB count and the family-table ids.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied.
  - Every new row is credited only by a real-shell reachability check in a
    fixture, or by its mutant.
  - The over-block claim is credited only by the execution-time sweep.
  - Nothing in this spec was prototyped, and it says so.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The
  mirror and fileHashes come from `node bin/cli.js --update`.
- P3 "Version-stamp discipline": satisfied.
  - qp-1 bumps 0.31.119 to 0.31.120, adds the CHANGELOG entry and runs
    `--update`, all in its one commit.
  - qp-2 touches no `agents/` or `templates/`, and its criterion asserts it.
- P4 "Optional personas degrade gracefully": satisfied. No shared persona
  prose is touched.
- P5 "`tests/validate.sh` is the merge gate": satisfied. Both units carry a
  clean-worktree `validate.sh` criterion (R4).

## Dispatch order

Units are **serial**: qp-1, then qp-2, each after the previous one has a
reviewer PASS (the one-unit-at-a-time invariant).

Retrieval contract, for every unit: read this file,
`docs/plans/2026-10-04-quoted-payload-closure.md`, at the unit's section,
plus Context, Clarifications and Risks. There is no tracker issue on the
fast path.

## Steps (dispatch contracts)

### Unit: qp-1
Suggested model: opus. Depends on: none.

## Objective
Make a glob inside a quoted string that the command hands to a second shell
for re-parsing count as a pattern in `glob_names_tokens()`. Doing so flips
QP-1 and QP-2 to `blocked`, and QP-3 to `blocked` as an accepted over-block.
Prove the change with a frozen family table, per-branch mutants and a
differential sweep. Fix esc-fu-1 notes a/b/c. Ship as 0.31.120.

## Retrieval
- This plan: Context, Clarifications, R1-R7.
- Gate: `hooks/scripts/human-decision-gate.sh` `:419-561` (glob scan) and
  `:686-724` (header and early exit).
- Suite: `tests/human-decision-gate.test.sh` `:886-924` (`hr`,
  `fg_overwrites`), `:999-1027` (the QP section) and `:1029-1070` (OB).
- Sweep: `tests/hdg-differential-sweep.sh`.
- Corpus recipe: `docs/plans/2026-10-04-escalation-leftovers.md` `:487-493`.

## Affected files
- `hooks/scripts/human-decision-gate.sh`
- `tests/human-decision-gate.test.sh`
- `.claude-plugin/plugin.json` and `package.json` (0.31.119 to 0.31.120)
- `CHANGELOG.md`
- Regenerated by `node bin/cli.js --update` and committed in the same
  commit, never hand-edited: the `.claude/hooks/scripts/human-decision-gate.sh`
  mirror, the fileHashes in `.claude/persona-config.json`, and the version
  stamps.

## Ordered edits
1. **Gate predicate.** In the gate file only:
   - Add a quoted-payload check to `glob_names_tokens()`. When the command
     hands a quoted string to a second shell for re-parsing, scan that
     string's globs as live, the same way the existing lex-failure branch
     scans raw text.
   - The check may only **set** `glob_h`/`glob_d`. It must never clear them,
     and must never add an allow route.
   - Recognising a second-shell invocation is the implementer's design. It
     must be a frozen, documented rule in a comment above the new function,
     **not** an open-ended list that claims completeness. That comment names
     the residuals R-QP-a and R-QP-b.
2. **Gate header** (`:686-701`, comment lines):
   - replace the lead-in "because the text names neither token even as a
     pattern" with the literal phrase
     `does not name both tokens, counting as patterns only unquoted globs and globs in a quoted string handed to a second shell`
     (comment line breaks are allowed; the criterion normalises them);
   - remove the QP-1/QP-2 clause from the residual list, and add the two
     declared residuals R-QP-a and R-QP-b in general terms;
   - keep A3, R-4, R-5, NL1 and the phrase `not the whole enumeration`;
   - cite `docs/plans/2026-10-04-quoted-payload-closure.md`, not
     `escalation-followups.md`.
3. **Suite QP section** (`:999-1027`):
   - change the header to
     `echo "-- quoted payload re-parsed by a second shell: BLOCKED (closed by qp-1) --"`;
   - rewrite the comment so it states the real mechanism (note a): `joined`
     deletes only quote characters, so these commands spell `human-review`;
     the early exit used to fire because DECISION is never spelled and the
     skeleton-based glob scan skipped the quoted `D*`; qp-1 makes that glob
     count. The comment must not contain the phrase
     `neither token is spelled in the joined text`;
   - change all three QP verdicts to `blocked`. QP-3's comment says it
     writes nothing under POSIX sh and is pinned as an accepted fail-closed
     over-block;
   - **note c:** add a new fixture helper. It runs a command once in a fresh
     fixture with a sentinel DECISION, and reports both whether DECISION
     changed and whether a literal file named `D*` exists in the packet
     directory. QP-3 asserts no overwrite **and** that the literal file
     exists, printing a line that begins `QP-3 literal:`. `fg_overwrites()`
     stays byte-unchanged.
4. **Frozen family table (implementer step).** Add a section
   `echo "-- quoted-payload family table (QPF-*): reachable, and BLOCKED --"`.
   - Add one row `QPF-<n>` per predicate branch introduced in edit 1, where
     "branch" means each distinct condition in the new code. Each row has a
     real-shell reachability line (overwrite expected) and a `blocked`
     verdict line, both beginning with the row id. A row that writes nothing
     by design (as FP-br-1 does) carries a comment saying so, and no
     reachability line.
   - The table is frozen in this commit. The commit message holds a table
     mapping each new branch to its row and its mutant (edit 5).
   - Do not add rows probing beyond the branches you introduced. That is
     O2, an operator step.
5. **Mutants (implementer step).** For each branch in the edit-4 table, write
   one single-branch mutant: a scratch copy of the gate with `lib/` copied
   beside it, one replacement asserted to occur exactly once. Also write one
   whole-check mutant that disables the new check entirely.
6. **Differential sweep (operator/implementer step):**
   - build the corpus with the esc-left-3 recipe;
   - copy the HEAD gate plus `lib/` to a scratch "old" path;
   - run
     `bash tests/hdg-differential-sweep.sh <old gate> hooks/scripts/human-decision-gate.sh <corpus>`.
   - If `new_denials` exceeds 10, **stop and escalate to the user**. Do not
     narrow the rule on your own authority.
   - Otherwise classify every new denial and pin each distinct class as one
     row, `OB-14` onward. Extend `ob_reasons` and the `OBEOF` block with one
     representative real command per class, and update the OB section
     header's range.
7. In one commit, version first: bump to 0.31.120, add a CHANGELOG entry,
   run `node bin/cli.js --update`.
   - The CHANGELOG entry names the closed class in general terms, and the
     residuals R-QP-a and R-QP-b. It quotes no spelling beyond QP-1..3.

## Do NOT touch
- `hooks/scripts/lib/` (shared with `reviewed-path-gate.sh`),
  `hooks/scripts/reviewed-path-gate.sh`, `tests/hdg-differential-sweep.sh`.
- `docs/` (qp-2 owns the glossary), `agents/`, `templates/`, `CONTEXT.md`.
- Existing suite rows other than QP-1..3, the QP section header and comment,
  and the OB arrays and header. In particular `fg_overwrites()`, and the FG,
  FP, FN and FC rows.

## Acceptance criteria
- `bash tests/human-decision-gate.test.sh` exits 0, run standalone (R2).
- In that output:
  - `grep -cE '^OK +QP-[123] \[.*-> blocked$'` prints 3;
  - `grep -cE '^OK +QP-[123] reachability'` prints 3;
  - `grep -cE '^OK +QP-3 literal:'` prints 1;
  - `grep -cE '^FAIL '` prints 0.
- `grep -c 'TRACKED-OPEN (not accepted)' tests/human-decision-gate.test.sh`
  prints 1 (NL1 only), and
  `grep -c 'BLOCKED (closed by qp-1)' tests/human-decision-gate.test.sh`
  prints 1.
- `grep -c 'neither token is spelled in the joined text' tests/human-decision-gate.test.sh`
  prints 0.
- Family table:
  - `bash tests/human-decision-gate.test.sh | grep -cE '^OK +QPF-[0-9]+ .*-> blocked$'`
    equals the row count N in the commit message's branch table, with
    N ≥ 1;
  - `grep -cE '^FAIL +QPF-'` prints 0.
- Mutants, each run standalone with `GATE_UNDER_TEST=<absolute path>` and
  `lib/` copied beside it:
  - each single-branch mutant makes the suite exit non-zero, and the output
    holds a `FAIL` line for that branch's own `QPF-<n>` row;
  - the whole-check mutant makes the suite exit non-zero, with `FAIL` lines
    for both QP-1 and QP-2 verdicts;
  - no case line in any mutant run reads `rc=1`;
  - the commit message pastes each mutant's replacement text and its FAIL
    lines.
- Sweep:
  - the summary line shows `new_allowances=0` and `new_denials` ≤ 10;
  - the commit message pastes the summary line, the corpus-build command and
    the classified list (one class per new denial);
  - `bash tests/human-decision-gate.test.sh | grep -cE '^OK +OB-[0-9]+ '`
    equals 13 + K, where K is the number of distinct classes stated in the
    commit message (K = 0 allowed).
- Gate header (normalised):
  - `sed 's/^ *# *//' hooks/scripts/human-decision-gate.sh | tr '\n' ' ' | tr -s ' ' | grep -o 'does not name both tokens, counting as patterns only unquoted globs and globs in a quoted string handed to a second shell' | wc -l`
    prints 1;
  - the same pipeline with `grep -o 'not the whole enumeration'` prints 1;
  - the same pipeline with `grep -o 'names neither token even as a pattern'`
    prints 0;
  - `grep -c 'quoted-payload-closure.md' hooks/scripts/human-decision-gate.sh`
    is at least 1, and `grep -c 'escalation-followups.md' hooks/scripts/human-decision-gate.sh`
    prints 0;
  - each pipeline gives the same result on
    `.claude/hooks/scripts/human-decision-gate.sh`.
- `cmp hooks/scripts/human-decision-gate.sh .claude/hooks/scripts/human-decision-gate.sh`
  exits 0, or differs only by the `--update` stamp; `bash tests/validate.sh`
  checks parity either way.
- `bash tests/reviewed-path-gate.test.sh` exits 0.
- `git diff --quiet HEAD~1 -- hooks/scripts/lib hooks/scripts/reviewed-path-gate.sh tests/hdg-differential-sweep.sh agents templates docs CONTEXT.md`
  exits 0.
- `jq -r .version .claude-plugin/plugin.json package.json` prints `0.31.120`
  twice, and `grep -c '0.31.120' CHANGELOG.md` is at least 1.
- `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD` reports ok.
- `bash tests/validate.sh` exits 0 in a clean worktree under `/tmp` (R4).

## Pre-resolved context
- Mechanism, early-exit lines, the fail-closed branch and monotonicity were
  all read from the code at dfce91f (Context).
- QP-1/QP-2 overwrite and QP-3 does not (measured in esc-fu-1, PASS).
- Nothing in this spec was prototyped. The sweep and mutants are the
  measurement. If a measurement disagrees with this plan, escalate; do not
  redesign.
- The user's answers bind: the rule covers only a second shell re-parsing a
  quoted string; QP-3 is blocked; the budget is ≤ 10 new denials and 0 new
  allowances.

## Escalation
- `new_denials` > 10, or `new_allowances` > 0: stop and report the sweep
  output to the user.
- Any branch whose mutant does not kill its own row: stop and report with
  the output.
- A classifier or gate refusal while authoring a fixture or mutant: stop and
  report (R5). Never rephrase to get past it.
- Closing the rule would need a change to `hooks/scripts/lib/`: stop and
  report.

### Unit: qp-2
Suggested model: sonnet. Depends on: qp-1 (PASS).

## Objective
Make the glossary claims that qp-1 falsifies agree with the landed pins.
Docs only.

## Retrieval
- This plan: Context, Clarifications (last line), R6.
- qp-1's commit message: the QPF row ids, the OB count K and the branch
  table.
- `docs/harness-glossary.md`, the `**frozen family table**` entry
  (`~:2311-2345`) and the `**accepted over-block (OB row)**` entry
  (`~:2347-2360`).

## Affected files
- `docs/harness-glossary.md` only. It has no mirror.

## Ordered edits
1. In the `**frozen family table**` entry:
   - Make NL1 the **only** `TRACKED-OPEN` pin. Remove "one of three
     `TRACKED-OPEN` pins, with QP-1 and QP-2".
   - Replace the "Also allowed (gate rc 0), and pinned by esc-fu-1 as QP-1
     ... QP-3 ..." passage with a statement that a glob inside a quoted
     string handed to a second shell is now counted as a pattern (qp-1).
     QP-1 and QP-2 are `blocked`, and QP-3 is `blocked` as an accepted
     fail-closed over-block that writes nothing.
   - Name the declared residuals R-QP-a and R-QP-b in general terms.
   - Do not add any spelling beyond those QP-1..3 already use.
2. In the `**accepted over-block (OB row)**` entry, change "There are 13
   (OB-1 to OB-13)" to the landed count, 13 + K. If K = 0, leave it
   unchanged.

## Do NOT touch
- `hooks`, `tests`, `scripts`, `agents`, `templates`, `CONTEXT.md`, ADRs.
- The esc-fu-2 "glossary tension" note (closed vs pinned) and the long-line
  note. Both are deferred.

## Acceptance criteria
All greps use the esc-fu-2 entry-scoped, whitespace-normalised helper:

```
entry() { awk -v h="**$1**:" 'index($0,h)==1{p=1;print;next} p&&/^\*\*[^*]+\*\*:/{exit} p' docs/harness-glossary.md | tr -s ' \n' ' '; }
```

- `entry 'frozen family table' | grep -cE 'three .TRACKED-OPEN. pins|Also allowed \(gate rc 0\)'`
  prints 0.
- For each of `QP-1`, `QP-2`, `QP-3`: `entry 'frozen family table' | grep -c <id>`
  is at least 1, and the matching suite line
  `bash tests/human-decision-gate.test.sh | grep -cE '^OK +<id> \[.*-> blocked$'`
  prints 1. The commit message lists all six outputs.
- `entry 'frozen family table' | grep -cE 'R-QP-a' ` is at least 1, and the
  same for `R-QP-b`.
- `entry 'accepted over-block (OB row)' | grep -c "OB-1 to OB-$((13+K))"`
  prints 1, with K taken from qp-1's commit message.
- `grep -c 'TRACKED-OPEN (not accepted)' tests/human-decision-gate.test.sh`
  prints 1, which matches "NL1 is the only pin".
- `node tests/context-glossary-links.test.js` exits 0, and
  `node tests/protocol-doc-drift.test.js` exits 0.
- `git diff --quiet HEAD~1 -- hooks tests scripts agents templates CONTEXT.md`
  exits 0.
- `bash tests/validate.sh` exits 0 in a clean worktree under `/tmp` (R4).

## Pre-resolved context
- Docs units in this area FAIL on prose accuracy (esc-left-4,
  esc-chat-6/7). Every sentence you touch must be checkable against a named
  suite row.

## Escalation
- If qp-1 landed different ids or a different OB count, use the landed
  values and report the discrepancy.

## Operator steps (not units)
- O1: Build the sweep corpus at qp-1 execution time (qp-1 edit 6). The
  corpus is machine-local (AS2).
- O2: A hunt for further quoted-payload or re-parse bypasses beyond qp-1's
  frozen table is an **operator step**, run by a human outside agent
  sessions, if wanted. Any finding becomes a new spec, not an amendment
  here.

## Out of scope
- R-QP-a and R-QP-b (declared residuals).
- `reviewed-path-gate.sh` F-1 (still deferred).
- The esc-fu-2 glossary tension and long-line notes.
- The probe-script notes.
- Glossary `:1944-1945`.

## Open Questions
None. All four from the 2026-10-04 round were answered by the user and are
recorded in Clarifications.

## Self-check
- CHK1: Does each Goal clause map to a step criterion? — PASS:
  - QP flip → QP verdict greps;
  - note a → negative-phrase grep;
  - note b → normalised header grep;
  - note c → `QP-3 literal:` grep;
  - family table → QPF greps;
  - sweep → summary and OB count;
  - version → jq, CHANGELOG and version-stamp-check;
  - glossary → qp-2 entry greps.
- CHK2: Do qp-1 and qp-2 agree on the `TRACKED-OPEN (not accepted)` count
  after qp-1? — PASS (both assert 1).
- CHK3: Is the over-block budget defined, including what happens past it? —
  PASS (≤ 10, otherwise escalate; `new_allowances=0`; OB-14 onward).
- CHK4: Is every new predicate branch required to have a mutant that kills
  its own row? — PASS (qp-1 edits 4-5, and the mutant criteria).
- CHK5: Is the family-table criterion bounded? — FAIL (ambiguous) in the
  draft, which read as "blocks every quoted-payload form" — revised in
  place: it is frozen to the branches introduced, with N tied to the
  commit's branch table, and outside spellings are residual (O2).
- CHK6: Does the spec avoid listing concrete bypass spellings beyond
  QP-1..3, per the user? — PASS.
- CHK7: Is the header wording defined for the post-fix state rather than the
  pre-fix state? — PASS (Clarifications, terminology line; exact phrase in
  the criterion).
- CHK8: Is QP-3's literal-file check defined without changing
  `fg_overwrites()`? — PASS (new helper; Do NOT touch).
- CHK9: Does qp-2's OB count criterion have a defined input? — PASS (K from
  qp-1's commit message, K = 0 allowed).
- CHK10: Is the marker-audit sweep disposition stated? — FAIL (missing): it
  was not run — revised in place (Context states it is incomplete, and hands
  the re-run to each reviewer).
- CHK11: Does P3 hold per commit? — PASS (qp-1 bumps in its one commit;
  qp-2 asserts no `agents`/`templates` diff).

## Scribe update hint
- After qp-1: one wiki changelog line, "quoted-payload class closed for
  second-shell re-parse; QP-1..3 blocked; residuals R-QP-a/b".
- After qp-2: no CONTEXT.md change. These are harness-glossary terms, not
  domain terms.
