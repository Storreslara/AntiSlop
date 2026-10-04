# Escalation follow-ups: gate predicate pins, glossary wording, probe hygiene (2026-10-04)

Status: FINAL (spec-master, 2026-10-04). Three units, fast path (five or
fewer units): this document holds the dispatch contracts, and there is no
task-master slicing or tracker issue. Predecessor:
`docs/plans/2026-10-04-escalation-leftovers.md` (esc-left-1..4, all PASS,
HEAD 3baa67e).

## Goal

Close the non-blocking notes that the esc-left-2, esc-left-3 and esc-left-4
reviews left behind. Change no gate behaviour.

- **esc-fu-1** (gate suite and gate header comment):
  - pin the three predicate branches that no row pins yet (extglob groups,
    case-insensitive matching, a comma-free brace group that holds `/`);
  - pin the quoted-payload forms (`bash -c '...D*'` and `sh -c '...D*'`) at
    their measured gate verdicts, with real-shell reachability checks;
  - restore the gate header's non-exhaustive residual wording;
  - fix the N21 section label (R-2 to R-4).
- **esc-fu-2** (glossary only): make four wording fixes, and update the F-1
  residual sentence so it agrees with esc-fu-1's new pins.
- **esc-fu-3** (operator probe script):
  - test that `main()` wires `tmux_retry_summary` after the retry;
  - document what the retry count counts;
  - fence the raw tmux pane safely;
  - keep the summary's temp file under `$SCRATCH`, so an interrupt removes
    it.

## Context

### What the esc-left reviews left (measured from the `.pass` notes, 2026-10-04)

The `.pass` notes left by esc-left-2, esc-left-3 and esc-left-4 are the
inputs. Every note below is in scope unless "Out of scope" says otherwise.

- **esc-left-3 NOTE[code] x3.** These three predicate branches are unpinned:
  - Extglob-group handling in `glob_scan_words`. A mutant that disables it
    leaves the suite at rc 0.
  - nocasematch. Only OB-8 pins it.
  - The comma-free "`/` inside a brace group names both" branch. Only
    OB-1/3/12/13 pin it.
- **esc-left-3 NOTE[spec].** The header above the early exit lists the
  residuals as A3, R-4, R-5 and NL1, and drops the earlier "not the whole
  enumeration" hedge.
- **esc-left-4 NOTE[spec] x4.** Glossary wording:
  - `:2383-2384`: "quoted glob is literal" holds only when the command lexes;
  - `:2382`: "whose tokens" should read "either token";
  - `:2398-2399`: "substring early-exit";
  - the suite's N21 label says R-2.
- **esc-left-4 NOTE[code].** The reviewer could not run the `sh -c` rows,
  because the gate refused its fixture. It reproduced the shell semantics on
  neutral filenames instead.
- **esc-left-2 NOTE[code]/NOTE[spec].** Four notes on the probe script:
  - `main()` wiring is untested;
  - the pane fence can be unbalanced;
  - a bare `mktemp` lands in `$TMPDIR`;
  - the count semantics are not documented.

### Measured at HEAD 3baa67e (this session, scratch scripts, nothing committed)

**Predicate-branch candidate rows vs. three single-branch mutants.** Each
mutant is a scratch copy with `lib/` copied alongside it. Each replacement
was asserted to occur exactly once.

- M-ext: `if [ "$sep" = '(' ] &&` -> `if false && [ "$sep" = '(' ] &&`
- M-nc: `shopt -s extglob nocasematch` -> `shopt -s extglob`
- M-br: `elif [[ $inner == */* && $inner != *..* ]]; then` -> `elif false; then`

Results (gate rc: 2 = denied, 0 = allowed; reach W = real bash in a fixture
overwrote a sentinel DECISION; `$hr` = `.claude/human-review/u1`):

| candidate row | real | M-ext | M-nc | M-br | reach |
|---|---|---|---|---|---|
| `shopt -s extglob` NEWLINE `printf x > $hr/@(X\|D)ECISION` | 2 | **0** | 2 | 2 | W |
| `shopt -s nocaseglob` NEWLINE `printf x > $hr/d*` | 2 | 2 | **0** | 2 | W |
| `tee x{a/b}y < /dev/null` | 2 | 2 | 2 | **0** | none |

Each row is killed by exactly its own mutant. Two facts about these rows:

- Extglob syntax needs the `shopt` on an earlier line. bash parses a whole
  line before it runs any of it: on one line joined by `;`, the
  `@(...)` write is a syntax error and writes nothing.
- A comma-free brace group is literal to bash, so it writes nothing.
  `tee x{a/b}y` writes nothing to DECISION. The branch is fail-closed
  over-approximation, and its row pins a blocked verdict with no
  reachability claim.

**Quoted payload re-parsed by a second shell.** `/bin/sh` here is dash.

| form | gate rc | real-shell effect on DECISION |
|---|---|---|
| `bash -c 'printf x > .claude/human-review/u1/D*'` | 0 (allowed) | overwritten (`x`) |
| `sh -c 'tee .claude/human-review/u1/D* < /dev/null'` | 0 (allowed) | overwritten (emptied) |
| `sh -c 'printf x > .claude/human-review/u1/D*'` | 0 (allowed) | untouched; dash creates a literal file `D*` |

The same verdicts hold with `.claude/h*/u1/D*`.

- `bash --posix -c 'printf x > A*'` also creates a literal `A*`. POSIX `sh`
  does not pathname-expand a redirect word non-interactively, so the
  third row writes nothing on any POSIX `/bin/sh`, not only on dash.
- Rows one and two are **genuine allowed overwrites**. This is the class the
  removed hedge covered. The glossary's F-1 entry (`:2333-2339`) already
  states all three as "allowed ... with no pin".

**Probe script signals.**

- A background child of a non-interactive bash script ignores SIGINT:
  rc 0, and its EXIT trap runs only at normal exit. With `set -m` around the
  spawn, SIGINT lands: rc 130, and the EXIT trap runs.
- bash runs an `EXIT` trap on INT, TERM and HUP (rc 130/143/129).
- `main()` already sets `trap cleanup EXIT`, and `cleanup` removes
  `$SCRATCH`. A temp file under `$SCRATCH` is therefore removed on interrupt
  with no trap change.

**Other facts.**

- `bash tests/human-decision-gate.test.sh` takes about 90 s standalone.
- The gate has exactly one mirror, `.claude/hooks/scripts/human-decision-gate.sh`.
  `docs/harness-glossary.md` and the two `scripts/`/`tests/` probe files
  have no mirror (`git ls-files`).
- `jq -r .version .claude-plugin/plugin.json` prints `0.31.118`.

### Prior defect history (`.fail` screen)

The whole `.claude/reviewed/` directory was listed and all `esc-*` records
were read.

- `esc-left-4.fail`: the prose claimed more than the code (an arming rule
  disproved by FG-c-1, and an "extglob" table row that does not exist).
- Earlier `esc-chat-1/6/7` `.fail` records are the same class.

This is durable evidence: **docs units in this area fail on prose
accuracy**. esc-fu-2 therefore uses entry-scoped, whitespace-normalised
claim greps, plus pin-existence greps for every row id the prose cites, not
file-wide existence greps. No unit re-scoped here has a prior FAIL of its
own, so the Implementer-tier ratchet does not apply.

### Marker-audit `--notes` sweep

The sweep ran `bash bin/marker-audit.sh . --notes --surface=<path>` per
touched path.

- `hooks/scripts/human-decision-gate.sh`: 4 `NOTE[spec]` and 12 `untagged`
  lines. The esc-left-3 header note is consumed here by esc-fu-1 edit 1. The
  rest are older units, all PASSed and dispatched (gh345-1, gh360, gh417,
  hdg-*, item02/19, esf-*), and none is a step not yet dispatched.
  Disposition: out of scope; no new work.
- The other four surfaces: see "Sweep disposition" under Risks.

The sweep is best-effort. `.claude/reviewed/` is untracked per-clone state.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-04 Functional scope & success criteria: Q The `bash -c` and
  `sh -c tee` pins prove a genuine allowed overwrite, and the brief allows a
  gate change "unless a test proves a genuine overwrite is allowed". Does
  esc-fu-1 close that bypass? → A (self-resolved, narrowest): no. esc-fu-1
  pins both forms `allowed` under a `TRACKED-OPEN (not accepted)` section,
  with reachability checks, and changes no gate logic. Closing them needs a
  differential sweep and a quoted-payload model. That is a separate spec, see
  Open Question 1.
- 2026-10-04 Functional scope & success criteria: Q Is "document event-count
  semantics" a change to the summary text or documentation only? → A
  (self-resolved, narrowest): documentation only. Add a function comment and
  one sentence in `method_text`. The `ran: N run2-tmux capture lines` text
  stays byte-identical, so I32-I35 stay valid.
- 2026-10-04 Non-functional attributes: Q Does an interrupt need a new
  trap? → A (self-resolved): no, if the temp file lives under `$SCRATCH`. The
  existing `trap cleanup EXIT` fires on INT, TERM and HUP (measured). A test
  proves it. An explicit trap is added only if that test fails without one,
  and such a trap must `exit`, never return.
- 2026-10-04 Edge cases / failure handling: Q Is the `sh -c 'printf x > ...D*'`
  no-write premise platform-dependent? → A (self-resolved): it is not, for
  POSIX shells. dash and `bash --posix` both decline to glob a
  non-interactive redirect word (measured). The row asserts "no overwrite"
  unconditionally, with that comment.
- 2026-10-04 Edge cases / failure handling: Q Should the capture.jsonl
  appendix fence also be widened? → A (self-resolved, narrowest): no. The
  brief names the pane only. The capture appendix is listed as a non-goal.
- 2026-10-04 Technical constraints & tradeoffs: Q Does the N21 label fix go
  in esc-fu-1 or esc-fu-2? → A (self-resolved): esc-fu-1. That unit already
  edits `tests/human-decision-gate.test.sh`, so esc-fu-2 stays docs-only and
  the two units share no file.
- 2026-10-04 Technical constraints & tradeoffs: Q Does a comment-only gate
  edit need a version bump? → A: yes, per the brief. P3's mechanical check
  covers only `agents/` and `templates/`, but the gate is mirrored, so bump
  0.31.118 to 0.31.119 and run CHANGELOG and `--update` in the same commit,
  as esc-left-3 did.
- 2026-10-04 Terminology consistency: Q The brief's "trigger token entry's
  'literal substrings' opening tweak" and "drop 'substring'": how far do they
  go? → A (self-resolved): only the `**trigger token**` entry. The opening
  becomes "one of two strings", "substring early-exit" becomes "early exit",
  and the entry's source line gains `esc-left-3, 2026-10-04` (the same
  esc-left-4 note). The second occurrence, in another entry (glossary
  `:1944-1945`), still describes a true behaviour and is out of scope.
- 2026-10-04 Terminology consistency: Q The brief says to add "when the
  command lexes" to "quoted glob is literal". Should the raw-scan else-case
  be stated too? → A (self-resolved, narrowest): add only the qualifier.
  No new else-clause.

## Assumptions
- AS1: `/bin/sh` is a POSIX shell that does not pathname-expand a
  non-interactive redirect word. Measured on this host: dash, and
  `bash --posix`.
- AS2: esc-fu-1's reachability checks reuse the suite's existing
  `fg_overwrites` helper, which runs `bash -c "$cmd"` in a fixture. QP rows
  start with `bash -c` or `sh -c`, so the second shell is the real one.
- AS3: The repo filesystem is case-sensitive (ext4 under WSL `/home`). The
  nocase row overwrites only because `shopt -s nocaseglob` is set in the
  row's command.

## Risks / dependencies
- R1: The suite runs from `validate.sh`. New rows must not write outside
  `$tmproot`. `fg_overwrites` already confines execution to a `mktemp -d`
  fixture, and gate-only rows (FP-br-1) never execute the command.
- R2: Mutation proofs under the microworld queue report false FAILs
  (memoization). Run them standalone with `GATE_UNDER_TEST=<absolute path>`,
  and copy `hooks/scripts/lib` beside the mutant. Otherwise every case dies
  at rc 1, which only looks like a kill (suite comment `:696-705`).
- R3: The human-decision gate blocks the implementer's own Bash text when it
  names both tokens. Use Edit/Write for the suite and scratch scripts, run
  them as `bash <path>`, and commit with `git commit -F <file>`. The
  reviewed-path gate also refuses a Bash command whose text spells the
  marker directory, so read markers with the Read tool.
- R4: `tests/validate.sh` takes more than 10 minutes. Run it in a clean
  worktree (`git worktree add /tmp/<unit>-v HEAD`, then
  `bash tests/validate.sh` there). If it cannot finish inside the
  600000 ms foreground cap, end with the WIP sentinel and the reason "no
  autonomous wake-up available — requires the dispatcher to resume me
  later". The reviewer re-runs it.
- R5: esc-fu-1's QP-1/QP-2 rows **document an open bypass**: an agent
  reading the suite learns a working spelling. That spelling is already in
  the committed glossary (`:2333-2339`), so this adds no new disclosure.
  Open Question 1 tracks closing it.
- R6: The probe's interrupt test spawns a child that blocks. Its blocking
  stub must be bounded (5 s or less), and the child's output must go to a
  file, so an orphaned sleep cannot hold a pipe that `validate.sh` captures.
- Sweep disposition (other surfaces):
  - `tests/human-decision-gate.test.sh` swept: 3 `NOTE[spec]`.
    - esc-left-4's N21 note is consumed by esc-fu-1 edit 2.
    - esc-chat-6's note was already handled by esc-left-4.
    - item19-1's note is unrelated.
  - The sweeps for `docs/harness-glossary.md` and the two probe files had
    not finished when this plan was committed. That is incomplete, not
    empty. Those surfaces rely on the esc-left `.pass` notes read
    directly, which are listed in Context. The reviewer of esc-fu-2/esc-fu-3
    should re-run
    `bash bin/marker-audit.sh . --notes --surface=<path>` for its surface.
- Dependencies: esc-fu-2 depends on esc-fu-1 (PASS), because it cites the
  QP pin ids. esc-fu-3 is independent.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied.
  - Every behavioural claim in Context was measured this session at
    3baa67e.
  - Each new suite row is credited only by its reachability check or its
    mutant.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The
  mirror and fileHashes come from `node bin/cli.js --update`, never from a
  hand edit.
- P3 "Version-stamp discipline": satisfied.
  - esc-fu-1 bumps to 0.31.119, adds the CHANGELOG entry and runs
    `--update`, all in its one commit.
  - esc-fu-2 and esc-fu-3 touch no `agents/*.md` or `templates/*`. Their
    criteria assert that.
- P4 "Optional personas degrade gracefully": satisfied. No shared persona
  prose is touched.
- P5 "`tests/validate.sh` is the merge gate": satisfied. Every unit has a
  clean-worktree `validate.sh` criterion (R4).

## Dispatch order

Units are **serial**: esc-fu-1, then esc-fu-2, then esc-fu-3. Only one unit
is mid-review at a time (the one-unit-at-a-time invariant). Each unit is
dispatched only after the previous one has a reviewer PASS. esc-fu-3 has no
data dependency, so it could run earlier, but it is kept last so the serial
invariant has one obvious order.

Retrieval contract, for every unit: read
`docs/plans/2026-10-04-escalation-followups.md`, this file, at the unit's
section, plus Context and Risks. There is no tracker issue on the fast path.

## Steps (dispatch contracts)

### Unit: esc-fu-1
Suggested model: opus. Depends on: none.

## Objective
Pin three unpinned predicate branches, and pin three quoted-payload forms at
their measured verdicts. Restore the gate header's non-exhaustive residual
wording, and fix the N21 label. Change no gate logic.

## Retrieval
This plan: Context "Measured at HEAD 3baa67e" (both tables), Clarifications,
R1-R5. Suite helpers: `bash_case`, `fg_overwrites`, `$hr`, all in
`tests/human-decision-gate.test.sh` (`:57`, `:886-924`).

## Affected files
- `hooks/scripts/human-decision-gate.sh`: comment lines `:686-699` only.
- `tests/human-decision-gate.test.sh`
- `.claude-plugin/plugin.json` and `package.json` (0.31.118 -> 0.31.119)
- `CHANGELOG.md`
- Regenerated by `node bin/cli.js --update`, committed in the same commit,
  never hand-edited: the `.claude/hooks/scripts/human-decision-gate.sh`
  mirror, the fileHashes in `.claude/persona-config.json`, and version
  stamps.

## Ordered edits
1. Gate header (`:696-699`). Reword the residual sentence so it is plainly
   non-exhaustive.
   - It must contain the literal phrase `not the whole enumeration`.
   - It must name the quoted-payload class: a glob inside a quoted payload
     that a second shell re-parses (`bash -c '...'`). Pin it as QP-1/QP-2,
     and point to this plan.
   - Keep A3, R-4, R-5 and NL1 named. Comment lines only.
2. Suite `:207`: change `pinned residual R-2:` to `pinned residual R-4:`.
   Change nothing else on that line.
3. New suite section, after the FC rows:
   `echo "-- F-1 predicate-branch pins (FP-*) --"`.
   - **FP-ext-1**: `$'shopt -s extglob\nprintf x > '"$hr"'/@(X|D)ECISION'`.
     A `blocked` row, plus a reachability line via `fg_overwrites` that must
     report an overwrite.
   - **FP-nc-1**: `$'shopt -s nocaseglob\nprintf x > '"$hr"'/d*'`.
     A `blocked` row, plus a reachability line that must report an
     overwrite.
   - **FP-br-1**: `tee x{a/b}y < /dev/null`. A `blocked` row only. Its
     comment states that the command writes nothing, and that the row pins
     the fail-closed comma-free-`/` branch.
   - Each line the section prints begins with its row id, so the FP/QP
     criterion below can count it. Example: `FP-ext-1 reachability: ...`.
4. New suite section:
   `echo "-- quoted payload re-parsed by a second shell: ALLOWED, TRACKED-OPEN (not accepted) --"`.
   - **QP-1**: `bash -c 'printf x > .claude/human-review/u1/D*'`. An
     `allowed` row, plus a reachability line asserting that `fg_overwrites`
     **succeeds**: a genuine overwrite.
   - **QP-2**: `sh -c 'tee .claude/human-review/u1/D* < /dev/null'`. An
     `allowed` row, plus a reachability line asserting an overwrite.
   - **QP-3**: `sh -c 'printf x > .claude/human-review/u1/D*'`. An
     `allowed` row, plus a reachability line asserting that `fg_overwrites`
     **fails**: no overwrite.
     - Its comment says that POSIX `sh` (dash, and `bash --posix`) does not
       pathname-expand a non-interactive redirect word. It writes a literal
       file `D*` instead, so this is not a bypass.
     - QP-1 is the same text under `bash`. QP-1 is the control proving that
       the reachability check discriminates.
   - The section comment says the gate masks the quoted payload, so the
     early exit at `:703-710` fires. It also says that QP-1/QP-2 flip to
     `blocked` if the gate ever closes them, and points to Open Question 1.
5. In one commit, version first: bump the version, add the CHANGELOG entry,
   run `node bin/cli.js --update`.

## Do NOT touch
- Any non-comment line of `hooks/scripts/human-decision-gate.sh`.
- `hooks/scripts/lib/`, `hooks/scripts/reviewed-path-gate.sh`,
  `tests/hdg-differential-sweep.sh`.
- `docs/` (esc-fu-2 owns the glossary), `agents/`, `templates/`.
- Existing rows, other than the one label in edit 2.

## Acceptance criteria
- `bash tests/human-decision-gate.test.sh` exits 0. Run it standalone, not
  under the microworld queue.
- `bash tests/human-decision-gate.test.sh | grep -E '^(OK|FAIL) +(FP|QP)-'`
  prints exactly 11 lines, all starting `OK`. That is 6 verdict lines, plus
  2 FP reachability lines, plus 3 QP reachability lines.
- Mutation, three mutants (M-ext, M-nc, M-br), with exact replacement texts
  from Context.
  - Each mutant is a scratch copy with `hooks/scripts/lib` copied beside
    it, run with `GATE_UNDER_TEST=<absolute path>`.
  - Each run of `bash tests/human-decision-gate.test.sh` exits non-zero.
  - Its output contains the `FAIL` line for FP-ext-1, FP-nc-1 and FP-br-1
    respectively.
  - No case line reads rc=1: rc 1 would mean the mutant did not start.
  - Paste the three FAIL lines into the commit message.
- `grep -c 'not the whole enumeration' hooks/scripts/human-decision-gate.sh`
  prints 1, and the same grep on
  `.claude/hooks/scripts/human-decision-gate.sh` prints 1.
- The following prints nothing (the gate diff is comment-only):
  `git diff -U0 HEAD~1 -- hooks/scripts/human-decision-gate.sh | grep -E '^[+-]' | grep -vE '^(\+\+\+|---) ' | grep -vE '^[+-][[:space:]]*#'`
- `grep -c 'TRACKED-OPEN (not accepted)' tests/human-decision-gate.test.sh`
  prints 2 (NL1 and the new QP section).
- `grep -c 'pinned residual R-4: split-variable' tests/human-decision-gate.test.sh`
  prints 1, and `grep -c 'residual R-2' tests/human-decision-gate.test.sh`
  prints 0.
- `jq -r .version .claude-plugin/plugin.json package.json` prints
  `0.31.119` twice. `grep -c '0.31.119' CHANGELOG.md` is at least 1.
- `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD` reports ok.
- `git diff --quiet HEAD~1 -- hooks/scripts/lib hooks/scripts/reviewed-path-gate.sh agents templates docs`
  exits 0.
- `bash tests/validate.sh` exits 0 in a clean worktree under `/tmp` (R4).

## Pre-resolved context
- All six commands and their verdicts, mutant kills and reachability results
  were measured at 3baa67e (Context tables). If a measurement disagrees at
  dispatch time, that is an escalation, not a redesign.
- The `shopt` must sit on its own line. On one line joined by `;`, the
  extglob write is a parse error and FP-ext-1's reachability check fails.

## Escalation
- If QP-1 or QP-2 is denied by the gate, or does not overwrite, stop and
  report. The same applies if QP-3 overwrites.
- If any mutant fails to kill its row, stop and report with the output.
- Do not change gate logic to "fix" QP-1/QP-2. That is Open Question 1.

### Unit: esc-fu-2
Suggested model: sonnet. Depends on: esc-fu-1 (PASS).

## Objective
Make four glossary wording fixes from the esc-left-4 notes. Make the F-1
entry's residual sentence agree with esc-fu-1's pins. Docs only.

## Retrieval
This plan: Context "What the esc-left reviews left", Clarifications
(terminology lines), the "Prior defect history" docs-accuracy warning.
esc-fu-1's commit (QP/FP ids). `esc-left-4.pass` NOTE lines 4-6.

## Affected files
- `docs/harness-glossary.md` only. The glossary has no mirror.

## Ordered edits
1. `**expansion-named token**` entry, `~:2382`: change "A command whose
   tokens are expansion-named fails closed" to "A command with either token
   expansion-named fails closed".
2. Same entry, `~:2383-2384`: change "A quoted glob is literal and names
   nothing." to "When the command lexes, a quoted glob is literal and names
   nothing." Add no other clause.
3. `**trigger token**` entry:
   - change the opening "one of two literal substrings whose co-occurrence
     arms" to "one of two strings whose co-occurrence arms";
   - change "the gate's substring early-exit" to "the gate's early exit";
   - extend the source line `(units hdg-lexer-1, hdg-prose-2, 2026-08-24)`
     with `esc-left-3, 2026-10-04`.
   - Leave the "(in asymmetric form) other text-protection gates" clause as
     it is.
4. `**frozen family table**` entry, `~:2326-2339`:
   - Replace "NL1 (newline in the packet id, the one `TRACKED-OPEN` pin)"
     with wording that makes NL1 one of three `TRACKED-OPEN` pins. The other
     two are QP-1 and QP-2.
   - Replace "Also allowed at d331be9 (gate rc 0) with no pin:" with wording
     that says these forms are pinned by esc-fu-1: QP-1 (`bash -c`, writes),
     QP-2 (`sh -c tee`, writes), QP-3 (`sh -c` redirect, writes nothing).
   - Keep the existing example spellings, or switch them to the pinned
     literal-path spellings. Either is accepted, since both verdicts were
     measured identical.

## Do NOT touch
- `hooks/`, `tests/`, `scripts/`, `agents/`, `templates/`, `CONTEXT.md`, ADRs,
  wiki.
- Glossary `:1944-1945` ("substring\n early-exit" in another entry). Its
  claim is still true, so it is out of scope.

## Acceptance criteria
All the greps below use this entry-scoped, whitespace-normalised helper.
It was verified at 3baa67e to return the pre-edit phrases:

```
entry() { awk -v h="**$1**:" 'index($0,h)==1{p=1;print;next} p&&/^\*\*[^*]+\*\*:/{exit} p' docs/harness-glossary.md | tr -s ' \n' ' '; }
```

- `entry 'expansion-named token' | grep -c 'with either token expansion-named fails closed'`
  prints 1.
- `entry 'expansion-named token' | grep -c 'whose tokens are expansion-named'`
  prints 0.
- `entry 'expansion-named token' | grep -c 'When the command lexes, a quoted glob is literal and names nothing'`
  prints 1.
- `entry 'trigger token' | grep -cE 'literal substrings|substring early'`
  prints 0.
- `entry 'trigger token' | grep -c 'one of two strings whose co-occurrence arms'`
  prints 1.
- `entry 'trigger token' | grep -c 'esc-left-3, 2026-10-04'` prints 1.
- `entry 'frozen family table' | grep -cE 'with no pin|the one .TRACKED-OPEN. pin'`
  prints 0.
- Claim anchors: for each of `QP-1`, `QP-2` and `QP-3`:
  - `entry 'frozen family table' | grep -c <id>` is at least 1;
  - `grep -c <id> tests/human-decision-gate.test.sh` is at least 1;
  - List these greps and their outputs in the commit message.
- `grep -c 'TRACKED-OPEN (not accepted)' tests/human-decision-gate.test.sh`
  prints 2. That is two section headers: NL1's, and the one QP section that
  holds QP-1 and QP-2. The glossary's "three `TRACKED-OPEN` pins" counts
  rows (NL1, QP-1, QP-2), not headers.
- Verdict re-measure: each command the edited prose cites has its verdict
  checked against `bash tests/human-decision-gate.test.sh` output lines. The
  commit message lists each cited command and its OK line.
- `node tests/context-glossary-links.test.js` exits 0, and
  `node tests/protocol-doc-drift.test.js` exits 0.
- `git diff --quiet HEAD~1 -- hooks tests scripts agents templates CONTEXT.md`
  exits 0.
- `bash tests/validate.sh` exits 0 in a clean worktree under `/tmp` (R4).

## Pre-resolved context
- esc-left-4 FAILed once on prose claiming more than the suite proves. Every
  sentence you touch must be checkable against a named row.

## Escalation
- If esc-fu-1's QP rows were named differently than this plan says, use the
  landed names and report the discrepancy.

### Unit: esc-fu-3
Suggested model: sonnet. Depends on: none (dispatched after esc-fu-2 for
serial order).

## Objective
In `scripts/probe-hook-identity.sh`, make four changes, and add a test for
each:
- test that `main()` assigns `TMUX_RETRY` from `tmux_retry_summary` after
  `retry_teammate_tmux`;
- document the count semantics;
- fence the raw tmux pane with a fence longer than any backtick run in it;
- create the summary's temp file under `$SCRATCH`, so the existing EXIT trap
  removes it on interrupt.

## Retrieval
This plan: Context "Probe script signals", Clarifications (count
semantics, trap), R6. `esc-left-2.pass` NOTE lines 4-7. The test file's
stubs and the I37 self-mutation pattern (`tests/probe-hook-identity.test.sh`
`:1-14`, `:253-266`).

## Affected files
- `scripts/probe-hook-identity.sh`
- `tests/probe-hook-identity.test.sh`

## Ordered edits
1. `tmux_retry_summary`:
   - Change `f="$(mktemp)"` to `f="$(mktemp "$SCRATCH/tmux-retry.XXXXXX")"`.
   - Extend its comment: N counts every capture line whose `run` is
     `run2-tmux`, of any event (PreToolUse, Stop, SubagentStop), not only
     teammate candidates.
   - Output text unchanged.
2. `method_text`: add one sentence stating the same count semantics for
   `Tmux retry: ran: N run2-tmux capture lines`. It must contain the literal
   phrase `N counts every run2-tmux capture line, of any event`, and it must
   name Stop and SubagentStop.
3. `write_record`, pane section:
   - The fence is a run of backticks, of length max(3, longest backtick run
     in `$RAW/teammate-tmux.txt` + 1).
   - The opening and closing fence lines are identical.
4. Trap: none, by default. Add explicit traps only if the interrupt test
   (criterion I-int) fails after edit 1. Any trap added must end in `exit`
   (`trap 'exit 130' INT`, `trap 'exit 143' TERM`) so that the EXIT trap
   runs, and must never return into the script.
5. Tests, new ids continuing from I37:
   - **I38 wiring**: run `main` in a child bash that sources the script.
     - Override `run_headless` to append run1/run2 lines to `$CAP`.
     - Override `retry_teammate_tmux` to append exactly 2 `run2-tmux` lines.
     - Point `REC` at a temp path.
     - Assert the record contains
       `Tmux retry: ran: 2 run2-tmux capture lines`.
     - A self-mutant that moves the `TMUX_RETRY=` assignment above
       `retry_teammate_tmux` (I37's python pattern) must fail I38.
   - **I39 pane fence**:
     - Write a pane holding a line of exactly three backticks and a line of
       exactly four backticks.
     - Assert that the pane section's opening fence has at least 5
       backticks and equals its closing fence line.
     - Assert that no line strictly between them is a backtick-only run as
       long as the fence or longer.
     - A self-mutant with the fixed triple-backtick fence must fail I39.
   - **I40 temp under SCRATCH**:
     - Run the existing I33 scenario with `TMPDIR` set to a fresh empty
       directory.
     - Assert that the directory is still empty afterwards.
   - **I41 interrupt (I-int)**, once with TERM and once with INT:
     - Spawn a child that sources the script and runs `main` with the I38
       overrides.
     - Override `teammate_choose` so that it blocks only when its argument
       matches `"$SCRATCH"/tmux-retry.*`. It touches a ready-file, then
       waits 5 s or less, bounded (R6). For any other argument it sets
       `TCHECK=none`.
     - Wait for the ready-file, then signal the child.
     - Assert the child rc: 143 for TERM, 130 for INT.
     - Assert that `$PROBE_SCRATCH` no longer exists and that the child's
       `TMPDIR` is empty.
     - For INT, spawn the child under `set -m`. Without it, a background
       child ignores SIGINT (measured).
     - Send child output to a file, not a pipe (R6).

## Do NOT touch
- The `ran: N run2-tmux capture lines; ...` output text, `classify_rows`,
  `outcome`, `teammate_check`, the capture hook, and the run prompts.
- The capture.jsonl appendix fence (non-goal, see Out of scope).
- `docs/experiments/2026-10-03-probe-hook-identity.md`. It is a dated
  record: do not regenerate it.
- `agents/`, `templates/`, `hooks/`, `docs/`.

## Acceptance criteria
- `bash tests/probe-hook-identity.test.sh` exits 0, and
  `bash tests/probe-hook-identity.test.sh | grep -cE '^ok +\(I(38|39|40|41)'`
  is at least 5 (I41 has a TERM and an INT line). No `FAIL` lines.
- The I38 and I39 self-mutants are executed by the suite, the I37 way, and
  report `ok` for "mutant fails". Remove that guard by hand in a scratch
  copy: the suite exits non-zero.
- `bash -n scripts/probe-hook-identity.sh` exits 0.
- `grep -c 'mktemp "\$SCRATCH/tmux-retry' scripts/probe-hook-identity.sh`
  prints 1. `grep -nE 'mktemp\)' scripts/probe-hook-identity.sh` prints
  nothing.
- `bash -c 'source scripts/probe-hook-identity.sh /dev/null; method_text' | grep -c 'N counts every run2-tmux capture line, of any event'`
  prints 1. At 3baa67e it prints 0. A bare `run2-tmux` grep is vacuous,
  because it already prints 1 there.
- `git diff --name-only HEAD~1` lists exactly the two affected files.
- `bash tests/validate.sh` exits 0 in a clean worktree under `/tmp` (R4).

## Pre-resolved context
- The test file installs `claude`, `tmux` and `sleep` as PATH stubs. `sleep`
  exits 0 immediately, so blocking stubs must call `/bin/sleep`.
- `finish_record` calls `cleanup`, which removes `$SCRATCH`. I38 must read
  the record at `REC`, never anything under `$SCRATCH`.
- `main` exits 3 when a row is missing. Run it in a child process and
  ignore that rc for I38.

## Escalation
- If I41 cannot be made deterministic within the 5 s bound on this host,
  report with timings. Do not raise the bound past 5 s.

## Out of scope
- Closing the QP-1/QP-2 bypass in the gate (Open Question 1).
- Glossary `:1944-1945` "substring early-exit" in another entry. Its claim
  is still true.
- The capture.jsonl appendix fence in the probe record.
- Every older `.pass` note surfaced by the marker-audit sweep on the gate
  (gh345-1, gh360, gh417, hdg-*, item02/19, esf-*).
- `reviewed-path-gate.sh` F-1 (still deferred).

## Open Questions
1. Should the QP-1/QP-2 bypass get its own spec? These are a glob inside a
   quoted `bash -c` / `sh -c` payload, allowed by the gate (rc 0) and a
   genuine DECISION overwrite (measured). **Recommended default: yes, a
   separate spec.** It needs a quoted-payload model for second-shell
   wrappers (`bash -c`, `sh -c`, `env sh -c`, ...) plus a differential sweep,
   and it carries over-block risk on every agent's Bash. That does not fit
   a follow-ups unit that changes no gate logic. Until then it is pinned
   `TRACKED-OPEN`. Not blocking: every unit here is dispatchable now.

## Self-check
- CHK1: Is it defined whether esc-fu-1 may change gate logic? — PASS (Goal,
  Clarifications line 1, edit list, Do NOT touch, the comment-only diff
  criterion).
- CHK2: Do esc-fu-1 and esc-fu-2 agree on the `TRACKED-OPEN (not accepted)`
  count after esc-fu-1? — FAIL (conflicting): esc-fu-2's draft criterion
  read as "3", while esc-fu-1 asserts 2 lines (NL1 section plus one QP
  section) — revised in place (both assert 2 lines; the glossary wording
  "three pins" counts rows, the grep counts section headers).
- CHK3: Is every FP/QP row's command text given exactly, so the reviewer
  can match it? — PASS (esc-fu-1 edits 3-4, Context tables).
- CHK4: Is each new FP row's mutation non-vacuous? Is a kill by its own
  mutant measured, rather than assumed? — PASS (Context table: each mutant
  flips exactly its row to rc 0).
- CHK5: Is the QP-3 no-write assertion defined for a host whose `/bin/sh`
  is not dash? — PASS (AS1, Clarifications edge-case line: POSIX
  redirect-word rule, measured under `bash --posix`).
- CHK6: Do esc-fu-1 and esc-fu-2 share any file, which would break serial
  review? — PASS (the label fix was folded into esc-fu-1; esc-fu-2 is
  glossary-only, and its criterion asserts `tests` unchanged).
- CHK7: Is every esc-fu-2 glossary claim anchored to a row or an
  entry-scoped grep, not a file-wide existence grep? — PASS (the `entry()`
  helper, verified against the pre-edit text; QP id cross-greps).
- CHK8: Is the SIGINT test defined so that it cannot pass vacuously when
  INT is ignored? — PASS (rc 130 asserted, plus `set -m`, measured).
- CHK9: Does the marker-audit sweep disposition cover every touched
  surface? — FAIL (missing): three sweeps did not finish — revised in place
  (Risks "Sweep disposition" states this, and hands the re-run to each
  unit's reviewer).
- CHK10: Does each Goal clause map to a step criterion? — PASS (header
  hedge → `not the whole enumeration` grep; N21 → R-4 grep; four glossary
  fixes → entry greps; wiring/fence/temp/interrupt → I38-I41).
- CHK11: Does P3 hold per commit for every unit? — PASS (esc-fu-1 bumps in
  its one commit; esc-fu-2/3 criteria assert no `agents`/`templates`
  diff).

## Scribe update hint
- After esc-fu-1: the wiki changelog may get one line, "predicate-branch
  pins FP-*, quoted-payload pins QP-1..3, header hedge restored". Do not
  touch the glossary; esc-fu-2 owns it.
- After esc-fu-2: no CONTEXT.md change. "expansion-named token" and
  "trigger token" are harness-glossary terms, not domain terms.
- Open Question 1, if accepted, becomes a new spec. It does not become an
  amendment here.
