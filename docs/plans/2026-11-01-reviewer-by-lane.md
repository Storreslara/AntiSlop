# Reviewer by lane: skip the reviewer on small units (2026-11-01)

Slug `2026-11-01-reviewer-by-lane`, unit prefix `rv-`. Appendix (scorecard, clarifications, constitution
check, self-check, PRD mapping, marker sweep): `docs/plans/2026-11-01-reviewer-by-lane/appendix.md`.

## Goal

User decision (2026-11-01, authoritative): "the reviewer is called too often; it should only be used for
medium-high big units". In the 2026-10-31 A/B, Arm B's reviewer ran 43 times, returned PASS 43 of 43, cost
$46.6 (37% of Arm B spend, about $1.08 and 88 s per dispatch) and changed no outcome. Elsewhere its findings
were real (41 of 41 sampled defects), so the reviewer stays where the risk is.

After this plan:
- G1. A unit in the `small` lane gets no reviewer. The orchestrator runs a mechanical check with no LLM
  (`unit-bookkeeping.sh check`, built on `review-precheck.sh`) and reports
  `unchecked-by-reviewer (small lane): precheck PASS`. No marker is written.
- G2. A small-lane writer's stop leaves no pending-review flag, so nothing waits for a reviewer. Medium and
  full units keep the flag, the reviewer and every gate, with no change.
- G3. The main Stop no longer blocks while the flag's reviewer has been dispatched (A/B recommendation 3),
  and `defer:`/`skip:` are no longer prescribed as a Bash redirect into `.claude/`.
- G4. The policy, the evidence and the trade-off are recorded in ADR-0045 and the glossaries. The work
  ships as 0.33.0.

## Decisions

- **D1 Which lanes get the reviewer.** `small` skips it; `medium` and `full` keep it. The lane is the one
  `bin/unit-size.sh` already prints and records in `.claude/bookkeeping/<unit>.lane`. Its definition does
  not change: 4 files or fewer, all measurable, none on a sensitive path, and no `.fail` record. Anything
  else is medium or full. The orchestrator may move a unit to a heavier lane, never a lighter one. Because
  the gates now read the lane, a heavier move must be recorded: `unit-size.sh <unit> --at-least
  <medium|full> (--contract <path> | -- <path>...)` prints and records the heavier of the two lanes, with
  `reason=at-least` when it lifted the lane. The exemption applies in subagent-orchestrator mode only (D7).
- **D2 What replaces the reviewer on a small unit.** `bash .claude/bin/unit-bookkeeping.sh check <unit>
  <baseline> [--contract <path>]` runs the rules in unit 1c's table and prints
  `check: <pass|fail|escalate> unit=<u> reason=<word>`. `pass` means done. `fail` sends the printed
  failure lines to the writer as defects. `escalate` means a check that cannot be decided mechanically.
  After a `fail` or an `escalate`, the unit leaves the small lane: the orchestrator runs `unit-size.sh
  <unit> --at-least medium --contract <path>` (or `-- <path>...` with no contract) before the next dispatch, so the fix gets the pending-review flag, the reviewer and the
  normal FAIL ladder. An `escalate` with no further writer work goes straight to the reviewer. The check
  writes no marker (only the reviewer writes markers); it appends one RULING line to the ledger. Resolved:
  Open Question 1. Prior FAIL: `qw-u1.fail` (haiku) was a fail-open on an unchecked helper exit in this
  file, so units that edit `check` get sonnet or above.
- **D3 How the stop gate recognises a small-lane writer.** At the gated writer's dispatch,
  `dispatch-hygiene.sh` (the orchestrator's PreToolUse, which runs before the writer exists) appends to
  `.claude/reviewed/dispatch-lane.log` the line `<ts> tool_use_id=<tu> prompt=<sha256> unit=<id|none>
  lane=<small|medium|full|none>`. The lane is `full` when `.claude/reviewed/<unit>.fail` exists; otherwise
  it is the word on the unit's `.lane` file when that word is valid, else `none`. On a SubagentStop,
  `stop-gate.sh` (the Claude entry script) joins the writer back to that record the way
  `writer-scope-gate.sh` joins it to its dispatch baseline: the transcript's `.meta.json` `toolUseId`, the
  first record with that id, and the prompt hash of the transcript's first message. It sets `writer_lane`
  only on an exact match. In the core, rule 6 writes no flag when `writer_lane` is `small` and logs
  `<ts> small-lane agent=<id> no-flag` to `review-audit.log`. Every miss (no transcript, no record, a hash
  mismatch, any other lane) writes the flag, so the gate fails toward review. The codex and cursor entry
  scripts never set `writer_lane`, so behaviour on those ports is unchanged.
- **D4 Consistency.** Under `reviewGating.mode: off`, rule 1 still exits before anything else. The D6
  forged-marker check still runs on every gated writer's stop, small included. `dispatch-hygiene.sh` still
  touches the writer-dispatch stamp at every gated dispatch. The format of `dispatch-baseline.log` does not
  change (`tests/writer-scope-gate.test.sh` matches its lines exactly), which is why the lane goes in a
  separate log.
- **D5 Main Stop while a reviewer runs (recommendation 3a).** When it allows a reviewer dispatch,
  `reviewer-route-gate-core.sh` rewrites every flag whose first line starts with none of `defer: `,
  `skip: ` or `review-dispatched: ` so that its first line is `review-dispatched: <UTC ts>`, keeps the old
  content below it, and logs `<ts> review-dispatched flags=<n>`. Rule 3 of the stop gate allows a
  `review-dispatched:` flag, keeps it and logs nothing. The line contains no ` defer: `, so the self-report
  tally does not count it. The route gate still blocks the next gated dispatch while any flag exists, and
  the reviewer's stop still clears all flags.
- **D6 The `defer:`/`skip:` channel (recommendation 3b).** `unit-bookkeeping.sh flag <defer|skip>
  <reason>` writes `<kind>: <reason>` as the first line of every flag that already exists. Claude Code
  allows a script to write into `.claude/` in headless mode but denies a Bash redirect there. When
  `<dot>/bin/unit-bookkeeping.sh` exists, the stop gate's block message names this command; on ports
  without the script the old text stays. The Claude prose stops prescribing the redirect. The adapter
  protocol fragments (codex, cursor) are left as they are: the denial is specific to Claude Code.
- **D7 Agent-teams mode is out of scope for the exemption.** `task-gate.sh` refuses to complete an `impl:`
  task without a valid `.pass`, so in agent-teams mode every unit keeps its reviewer. Resolved: Open Question 2.
- **D8 Tracker issues of small units.** The scribe closes an issue only on a quoted reviewer PASS line. A
  small-lane unit's issue therefore stays open; the orchestrator puts it on its `open:` line together with
  the check line. Resolved: Open Question 3.
- **D9 Order and release.** The tooling comes first, then its hardening (rv-harden; the user chose
  "Harden first" on 2026-11-01, after the rv-tools PASS notes), then rv-harden2 (the user chose "Fix these,
  then add a safety net" on 2026-11-01, after the rv-harden PASS notes; one FAIL, fixed in-unit), then the lane record, then the gate, then the prose
  (lane). The recommendation 3 work follows: gate, then route gate, then prose. The scribe unit comes next
  and the 0.33.0 release is last. Content units add an `[Unreleased]` CHANGELOG bullet and bump no version
  (constitution P3). The system works after every unit: until rv-prose lands, the orchestrator still sends
  every unit to the reviewer, and a reviewer dispatch with no flag is allowed.
- **D10 What is not touched.** `agents/reviewer.md` does not change: the reviewer's routine on medium and
  full units is the same. `writer-scope-gate.sh`, `task-gate.sh`, `protected-paths.sh`,
  `reviewed-path-gate.sh`, `harness-integrity-gate.sh`, `eval/` and `tests/abtest-arms.test.sh` are not
  touched. Adapter files change only as copies regenerated by `node bin/cli.js --update --force-render`.

## Units

The tier is a hint; the orchestrator decides with `ladder-tier.sh`. The lane is what `unit-size.sh` prints for the files listed, checked when this plan was written. File counts are hand-edited files,
including the CHANGELOG. Every unit also refreshes its mirrors with `node bin/cli.js --update
--force-render` (the generated `.claude/` copies, adapter cores and fileHashes), and its last criterion
is `bash tests/validate.sh`, run once after the final commit. It gates the whole suite, has no
`mutation:` line, and is never the only criterion that detects a behaviour.

| # | id | files | lane | tier hint | contract |
|---|---|---|---|---|---|
| 1 | rv-tools | 5 | medium | sonnet | [rv-tools](2026-11-01-reviewer-by-lane/contracts/rv-tools.md) |
| 1b | rv-harden | 5 | medium | sonnet | [rv-harden](2026-11-01-reviewer-by-lane/contracts/rv-harden.md) |
| 1c | rv-harden2 | 3 | small (reviewed, D9) | sonnet | [rv-harden2](2026-11-01-reviewer-by-lane/contracts/rv-harden2.md) |
| 2 | rv-lanerec | 3 | full (hooks/) | sonnet | [rv-lanerec](2026-11-01-reviewer-by-lane/contracts/rv-lanerec.md) |
| 3 | rv-stopgate | 4 + 2 regenerated | full | opus | [rv-stopgate](2026-11-01-reviewer-by-lane/contracts/rv-stopgate.md) |
| 4 | rv-prose | 5 | full (agents/) | opus | [rv-prose](2026-11-01-reviewer-by-lane/contracts/rv-prose.md) |
| 5 | rv-mainstop | 3 + 2 regenerated | full | sonnet | [rv-mainstop](2026-11-01-reviewer-by-lane/contracts/rv-mainstop.md) |
| 6 | rv-routemark | 3 + 2 regenerated | full | opus | [rv-routemark](2026-11-01-reviewer-by-lane/contracts/rv-routemark.md) |
| 7 | rv-flagprose | 5 (+1 if text moves) | full (agents/) | sonnet | [rv-flagprose](2026-11-01-reviewer-by-lane/contracts/rv-flagprose.md) |
| 8 | rv-scribe | 3 | small | sonnet | [rv-scribe](2026-11-01-reviewer-by-lane/contracts/rv-scribe.md) |
| 9 | rv-release | 3 | full (.claude-plugin/) | haiku | [rv-release](2026-11-01-reviewer-by-lane/contracts/rv-release.md) |

### 1. rv-tools: lane floor, small-lane check, flag channel (PASS)

Files: `bin/unit-size.sh`, `bin/unit-bookkeeping.sh`, `tests/unit-size.test.sh`,
`tests/unit-bookkeeping.test.sh`, `CHANGELOG.md`. It added `unit-size.sh --at-least` (D1), `check` (D2;
rules C1-C8, now in unit 1c's table) and `flag` (D6: rewrites the first line of every existing flag,
never creates one, exits 1 when none). `check` exits 0 on every outcome (on `fail` the packet follows its
line) and 2 on bad usage, unit id or baseline. Tests `(rv-a1)`-`(rv-a3)`,
`(rv-c1)`-`(rv-c8)`, `(rv-f1)`, `(rv-f2)`.

### 1b. rv-harden: close the rv-tools PASS notes (PASS)

Files: as rv-tools. It added C2a, C2b, C4a, C5's non-numeric case, C6's `</dev/null`, C7's contract and
cwd cases, the `flag` symlink skip and `dd conv=notrunc,nocreat` write, and `unit-size.sh`'s exit 2 on an
argument after `--contract <path>`. Tests `(rv-a4)`, `(rv-h1)`-`(rv-h9)`, `(rv-e1)`-`(rv-e3)`. Its PASS
notes (`.claude/reviewed/rv-harden.pass`) are the source of unit 1c.

### 1c. rv-harden2: `check` is fail-closed

Files: `bin/unit-bookkeeping.sh`, `tests/unit-bookkeeping.test.sh`, `CHANGELOG.md`. Principle: `check` prints
`pass` only on positive evidence. Every guard has the form `<evidence test> || finish <fail|escalate>
<reason>`, so a test that errors never lets a unit through: no `<bad test> && finish`, no `finish` inside
a pipe or subshell, and exactly one `finish pass`. Rules in order; the first unmet one decides; an
outcome not marked `fail` escalates:

| rule | evidence needed to go on | otherwise |
|---|---|---|
| C1 | the `.lane` first-line word is literally `small` | escalate `not-small` |
| C2 | no `.claude/reviewed/<unit>.fail` | escalate `fail-record` |
| C2a | `git status --porcelain --untracked-files=all -- . ':(exclude).claude/agent-memory'` exits 0, prints nothing | fail `uncommitted` |
| C2b | `git merge-base --is-ancestor <base> HEAD` exits 0 | escalate `bad-baseline` |
| C2c | `git diff --quiet <base> HEAD` exits exactly 1 | escalate `empty-range` |
| C3 | precheck exits 0; line 1 matches `^precheck: result=(pass\|fail) unit=<unit> range=[^ ]+ fails=[0-9]+ deferred=[0-9]+ judge=[0-9]+$` | escalate `precheck-error` |
| C4 | `result=pass` | fail `precheck` |
| C4a | `fails=0`, and `grep -c '^sensitive: '` prints `0` | else `precheck-error`; a line: `sensitive` |
| C4b | exactly one `^size: files=<N> ` line, N not 0 | no line: `precheck-error`; N 0: `empty-range` |
| C5 | `judge=0` literally (a 20-digit value is not 0) | escalate `judge` |
| C6 | `deferred long` lines = `deferred=`; each re-run prints `^criterion <n>: pass exit=[0-9]+$` | count: `precheck-error`; exit 124: `timeout`; else fail `criterion-<n>` |
| C7, contract | each `criterion` line is `pass exit=<n>` or `deferred long`; declared numbers non-empty, unique, and equal to the packet's (sorted) | other line: `precheck-error`; none: `no-criteria`; differ or duplicate: `criteria-mismatch` |
| C7, none | `.testAndLintCommand` non-empty, exits 0 under `timeout 590` from the repo top | empty: `no-criteria`; 124: `timeout`; else fail `test-command` |
| C8 | all of the above | pass `precheck` |

- Declared numbers: lines matching `^[0-9]+\. ` between `## Acceptance criteria` and the next `## `
  line, read by `check`'s own `sed`/`awk` from the working-tree contract, never through `us_section` or
  the precheck. That copy is the baseline copy here: C2a proved the tree clean, and the real precheck
  fails a contract that is not at the baseline or changed since. An unreadable contract escalates
  `criteria-mismatch`. Duplicates (`sort -n` differs from `sort -nu`) escalate too: C6 re-runs only the
  first item numbered n, so a later long item n never ran (rv-harden2 FAIL).
- Exclusions in C2a: only `.claude/agent-memory` (tracked notes other personas write concurrently; rv-harden
  note 10; no criterion reads them). Harness state needs none: what the harness writes untracked
  (`.claude/bookkeeping/`, `.claude/reviewed/`, flags, logs) is in `bin/cli.js`'s managed `.gitignore` list.
- Fixtures: the stub and end-to-end repos commit a `.gitignore` that keeps `.claude/` (and the stub
  `c.md`) out of `git status`; stub packets gain a `size: files=1 lines=1 binary=0` line and `c.md`
  items matching each packet. Old labels keep their outcomes.
- Tests, stubbed: `(rv-k1)` an untracked file: `uncommitted`; `(rv-k2)` an ignored file plus an untracked
  `.claude/agent-memory/n.md`: pass; `(rv-k3)` a baseline descending from HEAD: `bad-baseline`; `(rv-k4)` a
  commit and its revert, and a `size: files=0` packet: `empty-range`; `(rv-k5)` `judge=0 judge=5`,
  `result=pass` with `fails=3`, `unit=other`, no `size:` line: each `precheck-error`; `(rv-k6)`
  `judge=99999999999999999999`: `judge`; `(rv-k7)` declared 1,2 against packet 1, and against 1,3, and
  `(rv-k10)` declared 1,1 against packet 1,1: `criteria-mismatch`; `(rv-k8)` a `criterion 1: fail` line
  under `fails=0`, and `deferred=2` with one deferred line: `precheck-error`; `(rv-k9)` a re-run line
  `criterion 3: pass` with no `exit=`: `fail criterion-3`. Real precheck: `(rv-e4)` an untracked file a
  criterion reads: `uncommitted`; `(rv-e5)` criterion 1 plus `2. run: false`, and `(rv-e9)` a short and a
  long item both numbered 1: `criteria-mismatch`; `(rv-e6)` an `--allow-empty` range and `(rv-e8)` one
  changing only `docs/plans/`: `empty-range`; `(rv-e7)` a descendant baseline: `bad-baseline`.

### 2. rv-lanerec: dispatch-time lane snapshot

Files: `hooks/scripts/dispatch-hygiene.sh`, `tests/dispatch-hygiene.test.sh`, `CHANGELOG.md`.
This unit implements D3's record. It goes in the existing dispatch-baseline block (same target, caller,
tool_use_id and hash conditions; guarded the same way, so it never blocks and never changes a verdict),
after the baseline append. The unit id comes from the same first-non-blank-line `Unit:` regex as H3. Tests
`(rv-l1)`-`(rv-l5)`: small recorded; `.fail` forces full; no lane file gives `none`; no `Unit:` line gives
`unit=none lane=none`; a non-orchestrator caller writes no record.

### 3. rv-stopgate: small-lane writer stop writes no flag

Files: `hooks/scripts/stop-gate.sh`, `hooks/scripts/lib/stop-gate-core.sh`, `tests/stop-gate.test.sh`,
`CHANGELOG.md`. The adapter cores are regenerated. This unit implements D3's lookup and rule-6 branch.
The core's header comment gains `writer_lane` (optional) in its caller contract and in rule 6, and the
core reads it as `${writer_lane:-}`. The strings that `tests/state-distinctions-manifest.test.sh` pins
stay. Tests `(rv-s1)`-`(rv-s6)`: a small record writes no flag (rc 0); a small record with a marker newer
than the stamp still blocks (D6); a medium record writes the flag; a hash mismatch writes the flag; no
transcript writes the flag; under mode off the result is rc 0 and no flag.

### 4. rv-prose: orchestrator and protocol route by lane

Files: `agents/orchestrator.md`, `templates/persona-protocol.md`, `docs/orchestrator-rationale.md`,
`tests/unit-size.test.sh`, `CHANGELOG.md`.
- In the orchestrator, the small bullet gains the check: on ready-for-review, run
  `bash .claude/bin/unit-bookkeeping.sh check <task-id> <baseline>` (adding `--contract` when one exists)
  instead of the reviewer, with the outcomes from D2, and report
  `unchecked-by-reviewer (small lane): precheck PASS`. Heavier moves use
  `unit-size.sh <task-id> --at-least medium --contract <file>` (a bare `--at-least medium` with no
  `--contract` or `--` prints `full ... reason=no-input` and empties `<unit>.scope`). The line "Every unit in every lane gets its reviewer." becomes
  "Medium and full units always get their reviewer (if present); in agent-teams mode every unit does." The
  scribe convention counts `check: pass` as done for a small unit and keeps its issue open (D8).
- The protocol's "Review ownership" section states the small-lane unit exception. Its "Pending-review flag"
  section states that the gate writes no flag for a writer whose `dispatch-lane.log` record is small.
- The rationale gains an entry that cites the A/B figures.
- Byte caps: source 16,384 or less, deployed 40,960 or less. Text may move to the rationale to fit.

### 5. rv-mainstop: rule 3 allows `review-dispatched:`, block text names the script

Files: `hooks/scripts/lib/stop-gate-core.sh`, `tests/stop-gate.test.sh`, `CHANGELOG.md`; the adapter
cores are regenerated. This unit implements D5's rule-3 case and D6's block message. Tests
`(rv-m1)`-`(rv-m4)`: a review-dispatched flag lets the main Stop through (rc 0) and is kept; with a plain
flag present as well, the Stop still blocks; when `.claude/bin/unit-bookkeeping.sh` is present, the
block text names `unit-bookkeeping.sh flag` and has no `printf`; when it is absent, the old text stays.

### 6. rv-routemark: reviewer dispatch marks open flags

Files: `hooks/scripts/lib/reviewer-route-gate-core.sh`, `tests/reviewer-route-gate-caller.test.sh`,
`CHANGELOG.md`; the adapter cores are regenerated. This unit implements D5's rewrite, placed at the end
of the reviewer-target block, after the name check passes, and skipped under mode off. Tests
`(rv-r1)`-`(rv-r5)`: a plain flag is marked; a `defer:` flag is left alone; under mode off nothing is
touched; a reviewer dispatch refused by the name check touches nothing; after marking, a gated
lead-programmer dispatch is still blocked and `hooks/scripts/stop-gate.sh` lets a main Stop through.

### 7. rv-flagprose: prose for the new channel

Files: `agents/orchestrator.md`, `templates/persona-protocol.md`, `templates/protocol-digest.md`,
`tests/stop-gate.test.sh`, `CHANGELOG.md`, and `docs/orchestrator-rationale.md` only if text must move to fit the
byte caps (Risks, "Byte budget"). In the orchestrator, the sentence "To end your turn during a
background review, write `defer: <reason>` into the flag." is replaced: a reviewer dispatch marks the
flags `review-dispatched:`, so the turn may end, and any other defer or skip goes through
`bash .claude/bin/unit-bookkeeping.sh flag defer|skip <reason>`. The protocol's escape-hatch paragraph and
the digest line say the same. Sticky and abandon semantics do not change. Prose pins `(rv-p1)`-`(rv-p3)`
go in `tests/stop-gate.test.sh`. The byte caps are those of unit 4.

### 8. rv-scribe: ADR-0045 and glossary

Files: `docs/adr/0045-reviewer-by-lane.md`, `CONTEXT.md`, `docs/harness-glossary.md`. The ADR records
the policy (D1, D2, D7), the evidence (43 dispatches, 43 of 43 PASS, $46.6, 37%, 41 of 41 sampled defects
real elsewhere) and the trade-off (Risks below). In `CONTEXT.md`, the entry "The Writer/Reviewer split"
names the small-lane exception, and new entries define **unit lane** and **small-lane check**. In
`docs/harness-glossary.md`, new entries define **dispatch-lane record** and **review-dispatched flag**.

### 9. rv-release: 0.33.0

Files: `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`, plus the `.claude/` files that
`node bin/cli.js --update` re-stamps. One commit bumps 0.32.0 to 0.33.0 and adds `## [0.33.0] - <date>`
below `## [Unreleased]`. Dispatch it after rv-scribe has passed.

## Risks

- **What is lost.** A small unit gets no independent review. A defect that passes its own criteria and
  stays inside its listed scope ships without a second reader. In the A/B no reviewer verdict changed an
  outcome, but the evals were five toy repos. Here, sensitive paths (hooks, agents, `bin/cli.js`, the
  protocol, settings, adapter hooks) are never small, so the exemption mostly reaches docs, tests and
  non-sensitive `bin/` scripts.
- **What stays.** Every medium and full unit keeps its reviewer, its flag and the route gate, with no
  change. On small units, `writer-scope-gate.sh` still blocks out-of-scope changes; the D6 forged-marker
  check, `protected-paths.sh`, `reviewed-path-gate.sh` and `harness-integrity-gate.sh` stay armed; and the
  precheck (scope, version stamp, criteria) plus the test command run on every small unit.
- **Gates that behave differently for a small unit.** (1) In agent-teams mode, `task-gate.sh` would block
  completion with no `.pass`, which is why D7 keeps the reviewer there. (2) H3 in `dispatch-hygiene.sh`
  cannot detect a re-dispatch of a finished small unit, because it keys on `.pass`; the RULING line is the
  only record. (3) Marker audits (`bin/marker-audit.sh`, agent-auditor) may list small units as having no
  marker. (4) A reviewer dispatch that another PreToolUse hook refuses after the route gate has run leaves
  the flag marked `review-dispatched:`. The main Stop is then allowed although no reviewer runs, but the
  flag still blocks the next gated dispatch, as a sticky `defer:` does today.
- **Trust.** Before a dispatch, the lane file can be changed by the orchestrator's Bash. After the dispatch,
  the writer cannot move its own lane, because the snapshot was taken before the writer existed and the
  first record wins. Since ADR-0044 a Bash write into `.claude/reviewed/` is not blocked, so a writer could
  append a forged record, but only after its genuine one. The join takes the first record.
- **The 600000 ms Bash ceiling.** The precheck runs each criterion with `timeout 590`, C6 re-runs each
  deferred one, and C7 adds up to 590 s, so one `check` call on a unit with long criteria can outlast a
  single Bash call. A call cut off there prints no `check:` line. That is not `pass`, so the unit is not
  done (D2: only `pass` is done); it fails toward the reviewer, never toward a skipped review.
- **Further gaps (found writing rv-harden2).** (1) Untracked `eval/reports/` in this clone makes every
  `check` fail `uncommitted` until it is committed, removed or ignored (fails closed; the user decides).
  (2) A `version-stamp:` line reading `unknown`, or none, still passes; requiring `ok` would escalate every
  unit in a repo with no stamp file. (3) `check` with no `--contract` when one exists runs only the test
  command; rv-prose must pass it. (4) A baseline later than the writer's first commit is still an
  ancestor; `check` sees only the range it is given. (5) Not fixed: `flag` writes through a hard link
  (rv-harden note 9, no capability gain) and `bin/unit-size.sh:6`'s stale header (note 11). (6) The mirror
  criteria's `git diff --quiet` misses an untracked generated file. (7) `UB_PRECHECK` replaces the
  precheck; it is a test seam set from the caller's environment. (8) Accepted, not fixed: C2a misses a
  tracked file flagged `--skip-worktree` and edited after its commit (rv-harden2 roast note); like the
  reviewer's `git diff --quiet HEAD`, it needs a deliberate writer action.
- **Byte budget.** The orchestrator source has 646 bytes of headroom. rv-prose and rv-flagprose may
  have to move text into `docs/orchestrator-rationale.md`.

## Open Questions

None open. The user answered all three on 2026-11-01 with the recommended defaults: a failed or escalated
check moves the unit to medium (D2); agent-teams mode keeps the reviewer (D7); a small unit's issue stays
open (D8). Needs the user, not blocking: Risks "Further gaps" (1).

## Dispatch

All eleven contracts are written and committed; each Units-table link goes to its contract file. Dispatch
in table order, one unit at a time, from the contract file only: rv-tools (PASS), rv-harden (PASS),
rv-harden2, rv-lanerec, rv-stopgate, rv-prose, rv-mainstop, rv-routemark, rv-flagprose, rv-scribe,
rv-release. rv-stopgate needs rv-harden2's PASS.

## Scribe update hint

Knowledge proposals for rv-scribe: amend CONTEXT.md "The Writer/Reviewer split" (small-lane exception);
add **unit lane** and **small-lane check** (CONTEXT.md); add **dispatch-lane record** and
**review-dispatched flag** (docs/harness-glossary.md); write ADR-0045 (meets all three ADR tests: hard to
reverse once consumers rely on it, surprising without the A/B evidence, a real trade-off of safety for cost).
