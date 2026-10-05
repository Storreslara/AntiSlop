# Probe Outcome C false positive: judge the teammate marker by its own transcript (2026-10-04)

Status: FINAL (fast path, 1 unit: `poc-1`). Author: spec-master.

## Goal

`scripts/probe-hook-identity.sh` must not write a teammate Identity row, and
so must not report `Outcome: C`, when the session that received the run-2
operator prompt (the lead) ran `echo probe-teammate` itself. That must hold
even when the lead never ran `echo probe-main` and another session in the
same run did. Every existing test row keeps its current result.

Severity is low. This is experiment tooling only: the probe writes a
diagnostic record, and a human reads it. But Outcome C is the outcome that
would dispatch esf-eid-gate (a gate change), so a false C is the one
misclassification that can start real work.

## Context

### The defect (reproduced 2026-10-04 against HEAD `fcfcc47`)

The `esf-eid-probe-fix` PASS marker (`.claude/reviewed/esf-eid-probe-fix.pass`,
first NOTE[spec]) recorded the residual, and the
`docs/plans/2026-10-04-review-note-cleanup.md` item 13 / Open Question 1
deferred it to its own spec. The mechanism:

1. `teammate_choose` (`scripts/probe-hook-identity.sh:107-116`) takes the
   first `echo probe-main` PreToolUse line of the candidate's `run` as "the
   lead" (`m`). It never checks that `m` is the lead.
2. `teammate_check` (`:100-105`) returns `no-lead` only when `m` is missing
   or has no `session_id`. A candidate with a null `agent_id` is never
   `subagent-shaped` (`looks_like_subagent` needs an `agent_id`), so it reads
   `genuine`.
3. `attributable` (`:67-75`) withholds the row only if a **reference**
   transcript holds a Bash `tool_use` of the marker. The reference set is
   every `run2*` `echo probe-main` line's `transcript_path`. The lead's own
   transcript joins that set only if the lead ran `echo probe-main`.
4. So, in `run2-tmux`: session s8 runs `echo probe-main` (null `agent_id`,
   or `agent_id` `tc`), and lead s9 never runs it but runs
   `echo probe-teammate` itself (null `agent_id`, transcript t9 shows it).
   The result is `Teammate check: genuine`, a teammate row with
   `agent_id=absent`, keys equal to main's, and `Outcome: C`. That is false:
   it is the lead's own call.

Measured with the new rows I44/I44b (below) against the unfixed script:
`FAIL (I44) -> D: got [C] want [D]` and `FAIL (I44b) -> D: got [C] want [D]`.

### Root cause: both prior attempts used the same lead proxy

- `.claude/reviewed/esf-eid-probe-fix.fail` (FAIL #1, 2026-10-03,
  attempt `71fec81`). The teammate's run had no `echo probe-main` line, so
  `m=""` and the check fell through to `genuine`. `attributable` pooled
  every `run2*` main transcript, so the tmux lead's own transcript was never
  consulted. That gave a false C (case i) and a false A (case ii).
- Attempt 2 (`1305ed6`, PASS 2026-10-03) fixed exactly the shown repro.
  It judged each candidate against its **own run's** first main line and
  added `no-lead` when the run has none. It kept the proxy unchanged:
  **"the lead is whoever ran `echo probe-main`"**. The lead is only *asked*
  to run that marker. If the lead skips it and any other session in the run
  runs it, the proxy names the wrong session, and the false C comes back.
  The tests could not see this: every tmux fixture (I26, I26c, I27-I30)
  has either no `run2-tmux` main line or one from the lead s9 itself. No
  fixture has a third session's main line.

This spec stops using the proxy for the one decision that can yield C: *did
the lead run the teammate marker?* The evidence it uses instead is the
candidate's own `transcript_path`. A transcript that holds the run-2 operator
prompt text belongs to a session that received the operator prompt, which
means a lead. Such a transcript joins the reference set, so a lead that ran
the marker is withheld whether or not it ran `echo probe-main`. This is
positive evidence only. A missing, unreadable or prompt-free candidate
transcript adds nothing, and behaviour stays exactly as today.

### Measured premise (headless), 2026-10-04

From the real 2026-10-03 probe transcripts under
`~/.claude/projects/-tmp-hook-identity-probe/`:
- The run-2 lead transcript `315ec329-….jsonl` holds the string
  `Create an agent team with one teammate named probe-mate` (5 matches). Its
  first string user message is the literal prompt. The three run-1 / older
  lead transcripts hold 0.
- The recorded run-2 "teammate" PreToolUse payload (subagent-shaped) carries
  `transcript_path` = that **lead** transcript, not its own sidechain file.
- That lead transcript holds no `"command":"echo probe-teammate"`. The
  subagent's own sidechain (`subagents/agent-a76968a147b7dbc59.jsonl`) holds
  the marker (4) and not the prompt text (0).
- Across all 26 transcripts of this project, no stored user message uses a
  `[Pasted text #N]` placeholder.

So in the measured headless case, adding the candidate's own transcript
changes nothing for a subagent-like candidate: its transcript is the lead's,
and that one is prompt-bearing but marker-free. It withholds exactly the
lead's own call. The tmux (pasted-prompt) case is unmeasured: operator step
O2.

### Prototype evidence (scratch worktree, removed after)

The edits in Step 1 were prototyped on a detached worktree of `fcfcc47`:
- The unfixed script with the new suite gives FAIL I44, I44b (both
  `got [C]`) and I47's literal-equality row. I45, I46 and I47's prompt row
  are ok.
- The fixed script with the new suite gives rc 0, 110 `ok`, 0 `FAIL`, 0
  `SKIP`, in 2m28s foreground.
- Every pre-existing `ok` line is unchanged: the old suite on the old script
  gives 100 `ok` lines, and they are byte-identical to the new run's `ok`
  lines minus I44-I48.
- Over-broad mutant (`transcript_holds_prompt "$5"` → `true`): I46 and I30
  FAIL. Under-reach mutants (→ `false`; candidate transcript not passed):
  I44 FAILs.
- Residual (out of scope): s8 null-agent main line plus a subagent in lead
  s9 gives `TC=genuine OUTC=A` after the fix as well.

### Note-sweep dispositions

`bin/marker-audit.sh . --notes --surface=<path>` was run for both affected
files; dispositions for every returned line are in the "Marker-audit sweep"
subsection below. The sweep is best-effort: `.claude/reviewed/` is
untracked per-clone state, so an empty or partial sweep proves nothing. The
notes harvested by hand from the sibling `.pass` markers:
- esf-eid-probe-fix NOTE[spec] #1 (false C): **this spec**. The suggested
  remedies were "require m to have a null agent_id" and "withhold when the
  run's probe-main lines span more than one session". **Both were rejected
  because neither closes the null-agent single-s8 variant** that the same
  note names. The review-note-cleanup Open Question 1 (d) says so too.
  Method gets the sentence the note asked for.
- NOTE[spec] #2 (`no-lead` undocumented) and #3 (C' dead): already
  satisfied. The current `method_text` names `no-lead` and states C' cannot
  arise. No action.
- NOTE[code] #6 (cross-run subagent-shaped line judged genuine, gives A),
  #7 (headless lead's own call is the first genuine candidate, so the tmux
  retry is skipped and the result is a false D), #8 (`Teammate check:`
  reports the first candidate only): out of scope (see Out of scope). None
  can produce C.
- rnc-2 NOTE[code] #3: `sigint_ignored`/`int41` must stay outside any
  `set -m` region. The new rows go **after** the I42 block and before the
  final `[ "$fails" -eq 0 ]`, with no `set -m`.
- rnc-2 NOTE[code] #2: a vacuous SKIP leaves rc 0. Hence the `SKIP` = 0
  criterion below.

#### Marker-audit sweep

`--surface=scripts/probe-hook-identity.sh` returned
`marker-notes-sweep=9 markers=453 spec=3 code=6 untagged=0 malformed=4`.
The table lists each line with its disposition:

| Unit | Note | Disposition |
|---|---|---|
| esc-fu-3 | NOTE[code] `:126` unchecked `mktemp` | closed by rnc-2 (I43) |
| esc-fu-3 | NOTE[code] `:241` fence glued without a trailing newline | closed by rnc-2 (I39b) |
| esc-fu-3 | NOTE[spec] false C still open, Method silent | **this spec** (edits 3-5, I44/I44b) |
| esc-left-2 | NOTE[code] `main()` retry/summary order untested | closed by esc-fu-3 (I38, I42 mutant) |
| esc-left-2 | NOTE[code] triple-backtick pane fence | closed by esc-fu-3/rnc-2 (`pane_fence`, I39/I39c) |
| esc-left-2 | NOTE[code] `mktemp` in `$TMPDIR` | closed by esc-fu-3 (I40) |
| esf-eid-probe-fix | NOTE[spec] false C (lead never runs probe-main) | **this spec** |
| esf-eid-probe | NOTE[spec] user-settings env overrides teams flag | closed by `setup_run` (project-settings env, I22); the premise part stays out of scope |
| esf-eid-probe | NOTE[code] greedy `rf()` | closed (`rf` reads the first token, I10b) |

`--surface=tests/probe-hook-identity.test.sh`: see the addendum at the end
of this document.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-10-04 Functional scope & success criteria: Q Does the fix also close
  the false A, where a third session's `echo probe-main` makes a subagent in
  the real lead's session look genuine? → A (self-resolved): no. The
  dispatch names Outcome C only. A dispatches nothing (both gates already
  deny any non-empty `agent_id`, see the PASS NOTE[code] #6). Closing it
  needs a positive lead identity for the subagent-shape test, i.e. requiring
  the lead line's transcript to hold the prompt text. That would turn every
  existing fixture to `no-lead` and make every real run depend on the
  unmeasured tmux paste premise. The residual is stated as an honest limit
  in Method and named in Out of scope.
- 2026-10-04 Non-functional attributes: Q Is the extra suite runtime of
  three in-suite mutant re-runs acceptable when validate.sh is already over
  600 s? → A (self-resolved): yes. The probe suite runs last in
  validate.sh, and the two-part split already handles the ceiling. Each
  `PROBE_MUTANT=1` re-run skips nested mutants.
- 2026-10-04 External dependencies & integrations: Q Does Claude Code store
  the operator prompt literally in the lead's transcript, so a substring
  check can find it? → A (self-resolved): measured yes for headless
  `claude -p` (Context, "Measured premise"). The tmux paste route is
  unmeasured and becomes operator step O2. If it is false, the fix adds
  nothing in tmux and behaviour is today's. It is never worse.
- 2026-10-04 Edge cases / failure handling: Q What if the candidate's own
  transcript is missing, empty or unreadable? → A (self-resolved): it adds
  nothing to the reference set (positive evidence only). The alternative,
  withholding, would flip I30 (its candidate transcript `t8.jsonl` is never
  created) and would turn any transcript hiccup into a D with no
  diagnostic.
- 2026-10-04 Technical constraints & tradeoffs: Q Where does the new
  evidence go: a new `teammate_check` value (e.g. `lead-own`) or
  `attributable`'s reference set? → A (self-resolved): the reference set.
  That matches the existing split, where `teammate_check` judges shape and
  `attributable` judges who ran the marker (I7 and I26c already give
  `genuine` + no row + D for a lead that ran it). It leaves the four check
  values, `tmux_retry_summary` text and the retry trigger unchanged, so no
  existing row moves.

## Risks / dependencies

- R1. Prior FAIL on this function (`esf-eid-probe-fix.fail`, 1 block).
  Implementer-tier ratchet: dispatch `poc-1` at no cheaper tier than
  esf-eid-probe-fix's fix attempts. The orchestrator must not route it to
  a haiku-tier implementer.
- R2. A genuine separate-session teammate whose own transcript also holds
  the prompt text (because the lead relayed the whole prompt) **and** its
  own marker is withheld, giving a false D. That is conservative, and
  Method states it. In the measured headless run the relayed task did not
  carry the text (sidechain: 0).
- R3. Unmeasured tmux paste premise: operator step O2.
- R4. `tests/validate.sh` takes about 10-12 min. It must run **foreground**
  in a **clean worktree under `/tmp`**, in **two parts**. A backgrounded run
  ignores SIGINT and fails I41. The recipe is in AC8.
- R5. Gates the implementer will meet:
  - `reviewed-path-gate.sh` blocks any Bash command whose text spells
    `.claude/reviewed/`. Use the Read tool for markers.
  - `human-decision-gate.sh` blocks Bash text with a `*/*`-shaped glob
    (hit during this spec on a transcript-dir listing). Name transcript
    files explicitly.
  - If either gate blocks, report and wait. Never reword a command to get
    past one.
  - Do not touch `hooks/scripts/human-decision-gate.sh`.
- R6. Mutant literals must stay exact-once. The I42 mutants depend on
  `retry_teammate_tmux` / `TMUX_RETRY` order, `f="$(pane_fence
  "$RAW/teammate-tmux.txt")"` and `mktemp "$SCRATCH/tmux-retry.XXXXXX"`,
  and none of them change. The new I48 mutants depend on
  `transcript_holds_prompt "$5"` and on
  `main-teams "$(jq -r '.transcript_path // empty' <<<"$TLINE")"`, each
  exactly once.
- R7. Other spec-masters commit plan files concurrently. Every commit stages
  by explicit path.
- R8. Not version-stamped: `scripts/` and `tests/` are outside
  `agents/*.md|templates/*`, so constitution P3 does not fire. No plugin
  bump and no CHANGELOG entry are needed.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. The false C was reproduced live,
  the premise was measured on real transcripts, and every criterion was
  prototyped red-before / green-after with mutants.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. No
  script-driven file (`fileHashes`, `--wire-*`) is touched.
- P3 "Version-stamp discipline": satisfied. No version-stamped path is
  touched (R8).
- P5 "`tests/validate.sh` is the merge gate": satisfied. AC8 is a full
  two-part validate.sh run.

## Step 1 (unit `poc-1`): withhold the teammate row when the candidate's own transcript is a lead's

Affected files (exactly these two):
`scripts/probe-hook-identity.sh`, `tests/probe-hook-identity.test.sh`. No
doc file is edited. The Method text lives in `method_text()` and reaches
the next generated record. `docs/experiments/2026-10-03-probe-hook-identity.md`
is a historical record and stays untouched.

Ordered edits, as specified in the dispatch contract below.

Acceptance criteria: AC1-AC9 below.

### Dispatch contract (fast path)

Unit: poc-1

## Objective
Stop `scripts/probe-hook-identity.sh` from reporting a false `Outcome: C`
when the run-2 lead ran `echo probe-teammate` itself while another session
ran `echo probe-main`. Do this by adding the candidate line's own transcript
to `attributable`'s reference set whenever that transcript holds the run-2
prompt text. Add the rows that prove it.

## Retrieval
This plan, `docs/plans/2026-10-04-probe-outcome-c.md`, is the only spec. No
tracker issue exists (fast path). Read the defect history with the Read
tool, never Bash:
- `.claude/reviewed/esf-eid-probe-fix.fail`
- `.claude/reviewed/esf-eid-probe-fix.pass`
- `.claude/reviewed/rnc-2.pass`

## Affected files
- `scripts/probe-hook-identity.sh`
- `tests/probe-hook-identity.test.sh`

## Ordered edits
1. Script, after the `ALLOWED=` line: add
   `LEAD_PROMPT_MARK='Create an agent team with one teammate named probe-mate'`.
   Build `prompt-mate.txt` in `setup()` from that variable (`printf` with
   `%s`). The resulting file must stay byte-identical to today's. This was
   verified in the prototype with a `diff` of the two generated files.
2. Script: add `transcript_holds_prompt <transcript>`, right before
   `attributable`. It returns 0 iff the file is non-empty (`-s`) and `jq -e`
   finds a line where `any(..|strings; contains($LEAD_PROMPT_MARK))`; any
   other result returns non-zero. It has no other effects.
3. Script, `attributable`: take an optional 5th argument, the candidate's
   transcript. The reference list becomes the existing
   `pick … | jq -r '.transcript_path'` output, plus `"$5"` when it is
   non-empty and `transcript_holds_prompt "$5"` succeeds, then `sort -u`.
   The literal `transcript_holds_prompt "$5"` appears exactly once in the
   file. The loop body and the `[ "$n" -gt 0 ]` tail are unchanged.
4. Script, `classify_rows`: the teammate call becomes
   `attributable "$1" teammate 'echo probe-teammate' main-teams "$(jq -r '.transcript_path // empty' <<<"$TLINE")" || return 0`.
   That `main-teams "$(jq -r '.transcript_path // empty' <<<"$TLINE")"`
   substring appears exactly once.
5. Script, `method_text`: delete the false claim ", which always includes
   the lead of the teammate'"'"'s own run because the check below requires
   one". Then add sentences that state:
   - (a) for teammate, the reference set also holds **the teammate line's
     own transcript** when it holds the run-2 prompt text
     `Create an agent team with one teammate named probe-mate`, because the
     session that received the prompt is a lead whether or not it ran
     `echo probe-main`;
   - (b) honest limit: a separate-session teammate whose own transcript
     holds that text and the marker is withheld (D, conservative);
   - (c) honest limit: the first `echo probe-main` line of a run is taken
     as its lead for the subagent-shape test without checking it. A third
     session that ran it can make a subagent in the real lead's session
     read `genuine`, giving **a false A**. A dispatches nothing.
   Keep every word the I21 loop checks.
6. Test, fixtures. Add near `te()`:
   - a suite literal `P2MARK='Create an agent team with one teammate named probe-mate'`;
   - `uline()`, which writes `{type:"user",message:{content:<prompt text containing $P2MARK>}}`;
   - a `LEAD_PROMPT` knob: `scen` appends `uline` to `t2.jsonl`;
     `tmuxscen` appends it to `t2.jsonl` and `t9.jsonl`.
   The knob is additive, and no existing row sets it.
7. Test, new rows after the I42 block, before the final
   `[ "$fails" -eq 0 ]`, with no `set -m`. Labels are verbatim; AC3 greps
   them.
   - `x_c44`: t8 holds a probe-main `tline`; a `run2-tmux` PreToolUse
     `echo probe-main` from s8 with null `agent_id`; then `lead_mate`. Run
     it with `LEAD_PROMPT=1 LEAD_RAN_MATE=1 tmuxscen x_c44`. Rows:
     `noteam "(I44) lead s9 runs the marker, run2-tmux main line from null-agent s8"`
     and `eq "(I44) -> D" "$OUTC" D`.
   - `x_c44b`: the same, but s8 has `agent_id` `"tc"` and keys `$KS`. Rows
     `(I44b) … s8 agent_id tc` and `eq "(I44b) -> D"`.
   - `LEAD_PROMPT=1 scen null null 1 "$KM"`:
     `eq "(I45) control: in-process teammate, lead transcript holds the prompt but not the marker -> C" "$OUTC" C`.
   - `x_real46`: `lead_main`, plus an s8 `"tc"` teammate whose `t8.jsonl`
     holds an `echo probe-teammate` `tline` (no prompt). Run it with
     `LEAD_PROMPT=1 tmuxscen x_real46`:
     `eq "(I46) control: own-session teammate whose transcript holds the marker but not the prompt -> A" "$OUTC" A`.
   - `(setup && setup_run run2 1) >/dev/null 2>&1`, then two I47 rows:
     - `(I47) run-2 prompt holds the lead-prompt mark, run-1 prompt does not`,
       a `grep -qF "$P2MARK"` on `prompt-mate.txt` and its negation on
       `prompt-sub.txt`;
     - `eq "(I47) script mark equals the suite's literal" "${LEAD_PROMPT_MARK-unset}" "$P2MARK"`.
   - `(I49) method_text names …`: one `ok` line per phrase, for
     `the teammate line's own transcript`, `a false A`, and `$P2MARK`.
   - Three in-suite mutants, inside `if [ -z "${PROBE_MUTANT:-}" ]`, using
     the existing `mutrun`. Each yields one `ok`/`bad` row labelled `(I48)`:
     - M1 `transcript_holds_prompt "$5"` → `false` must produce
       `FAIL (I44)`;
     - M2 `main-teams "$(jq -r '.transcript_path // empty' <<<"$TLINE")"`
       → `main-teams` must produce `FAIL (I44)`;
     - M3 `transcript_holds_prompt "$5"` → `true` must produce
       `FAIL (I46)`.
8. Commit once: `git commit -- scripts/probe-hook-identity.sh tests/probe-hook-identity.test.sh`.
   The subject starts `fix(poc-1):`.

## Do NOT touch
- `hooks/` (above all `hooks/scripts/human-decision-gate.sh`), `tests/validate.sh`,
  `docs/` (including `docs/experiments/2026-10-03-probe-hook-identity.md`,
  `docs/harness-glossary.md`), `CONTEXT.md`.
- Any existing test row's fixture call, label or expectation (I1-I43).
- `teammate_check`, `looks_like_subagent`, `teammate_choose`,
  `tmux_retry_summary`, `outcome`, `separable`, `teammate_done`, `main`.
- Other agents' uncommitted files. Stage by explicit path only.

## Acceptance criteria
Run every criterion in a clean worktree under `/tmp` at the unit commit
`<C>`. Create it with `git worktree add /tmp/poc1-rv <C>`, and add the base
worktree with `git worktree add /tmp/poc1-base <C>~1`. Run everything
foreground through the Bash `timeout` parameter. Never use
`run_in_background`.
- AC1: `bash -n scripts/probe-hook-identity.sh && bash -n tests/probe-hook-identity.test.sh`
  gives rc 0.
- AC2 (red before): in `/tmp/poc1-rv`,
  `PROBE_MUTANT=1 PROBE_UNDER_TEST=/tmp/poc1-base/scripts/probe-hook-identity.sh bash tests/probe-hook-identity.test.sh > /tmp/poc1-red.txt 2>&1`.
  Then each of `grep -cF 'FAIL (I44) -> D: got [C] want [D]'` and
  `grep -cF 'FAIL (I44b) -> D: got [C] want [D]'` on that file is `1`, and
  `grep -cE '^FAIL \((I45|I46)\)'` is `0`.
- AC3 (green after): in `/tmp/poc1-rv`,
  `bash tests/probe-hook-identity.test.sh > /tmp/poc1-green.txt 2>&1; echo rc=$?`
  prints `rc=0`. On `/tmp/poc1-green.txt`: `grep -c '^FAIL'` = 0,
  `grep -c '^SKIP'` = 0, and each of these counts is exactly as stated:
  - `grep -cF 'ok   (I44) -> D'` = 1
  - `grep -cF 'ok   (I44b) -> D'` = 1
  - `grep -c '^ok   (I45)'` = 1
  - `grep -c '^ok   (I46)'` = 1
  - `grep -c '^ok   (I47)'` = 2
  - `grep -c '^ok   (I48)'` = 3
  - `grep -c '^ok   (I49)'` = 3
- AC4 (existing rows unchanged): in `/tmp/poc1-base`,
  `bash tests/probe-hook-identity.test.sh > /tmp/poc1-base.txt 2>&1`
  gives rc 0. Then
  `diff <(grep '^ok' /tmp/poc1-base.txt) <(grep '^ok' /tmp/poc1-green.txt | grep -vE '\(I4[4-9]b?\)')`
  is empty. In the prototype the base side was 100 lines.
- AC5 (mutant, independent of the suite's own I48): in `/tmp/poc1-rv`, copy
  the script with `transcript_holds_prompt "$5"` replaced by `false`
  (assert the literal occurs exactly once), then run
  `PROBE_MUTANT=1 PROBE_UNDER_TEST=<copy> bash tests/probe-hook-identity.test.sh`.
  Its output holds `FAIL (I44) -> D: got [C] want [D]`. The same with
  `true` instead holds `FAIL (I46)`.
- AC6 (Method claim removed): `grep -c 'which always includes the lead' scripts/probe-hook-identity.sh`
  = 0.
- AC7 (scope): `git diff --name-only <C>~1 <C>` prints exactly
  `scripts/probe-hook-identity.sh` and `tests/probe-hook-identity.test.sh`.
- AC8 (merge gate, two parts, foreground, `/tmp/poc1-rv`). The two parts
  together cover every validate.sh section:
  - Part 1: `timeout 580 bash tests/validate.sh > /tmp/poc1-v1.txt 2>&1; echo rc=$?`.
    If it prints `rc=0`, the gate is passed and part 2 is skipped. If it
    prints `rc=124`, note `L`, the line number in `tests/validate.sh` of the
    last `echo "== ` header that appears in `/tmp/poc1-v1.txt`;
    `grep -c '^FAIL' /tmp/poc1-v1.txt` must be 0.
  - Part 2: write `tests/zz-tail.sh` **inside the worktree's `tests/`**
    (validate.sh `cd`s to `$(dirname "$0")/..`). Its content is
    `sed -n '1,9p' tests/validate.sh` followed by
    `sed -n "$((L-1)),\$p" tests/validate.sh`. Run
    `timeout 590 bash tests/zz-tail.sh > /tmp/poc1-v2.txt 2>&1; echo rc=$?`.
    It must print `rc=0`, and `grep -c 'OK   tests/probe-hook-identity.test.sh' /tmp/poc1-v2.txt`
    must be 1.
  - Never run validate.sh as a background job: I41's INT case fails or
    SKIPs there.
- AC9 (cleanup): after the runs, remove `/tmp/poc1-rv` and `/tmp/poc1-base`
  with `git worktree remove --force`, then run `git worktree prune`.
  `git worktree list` must name neither path.

## Pre-resolved context
- Root cause and why both prior attempts missed it: Context, "Root cause"
  above. Do not re-derive it.
- All of AC2-AC5 were prototyped on `fcfcc47` and behave as stated. If one
  does not, that is evidence the edit differs from the spec. Never edit
  classification functions outside edits 1-5 to make a criterion pass.
- Subagent hook payloads carry the **lead's** `transcript_path` (measured).
  That is why I45 (in-process, prompt-bearing, marker-free lead transcript)
  must stay C.
- I30's candidate transcript `t8.jsonl` is never created. Positive-evidence
  only keeps I30 at A. M3 (`true`) proves that the over-broad variant
  breaks it.

## Escalation
Stop and report, without improvising, in these cases:
- any exact-once literal in R6 is not found exactly once;
- AC4's diff is non-empty;
- the suite needs a change to an existing row;
- a gate blocks a command (never reword past it);
- validate.sh fails in a section this unit does not touch. Report it as
  pre-existing, with the section header.

## Operator steps (not agent work)
- O1. Teammate-identity premise: still unmeasured. Measuring it needs a
  real interactive agent-teams session started by the operator (runbook at
  the top of the script). This spec does not measure it.
- O2. On the next real probe run that reaches `run2-tmux`, check that the
  tmux lead's transcript (the `transcript_path` of any `run2-tmux` line with
  a null `agent_id` from the lead session) holds
  `Create an agent team with one teammate named probe-mate`, e.g.
  `grep -c 'Create an agent team with one teammate named probe-mate' <that file>`
  ≥ 1. If it is 0, the fix adds nothing in tmux. Note that in the record and
  open a follow-up.

## Out of scope
- The false A (a third session's `echo probe-main` makes a subagent in the
  real lead's session read `genuine`). It is stated in Method as an honest
  limit.
- PASS NOTE[code] #6, #7 and #8: the cross-run subagent line, the skipped
  tmux retry when the headless lead runs the marker, and `Teammate check:`
  naming only the first candidate.
- Measuring the teammate premise (O1). Regenerating or editing the
  2026-10-03 record. Glossary entries (see the scribe hint).
- `hooks/scripts/human-decision-gate.sh` and its glob false positive (R5).

## Open Questions

None blocking. Each Partial category was self-resolved (Clarifications).
The one premise that cannot be settled offline is operator step O2, which
fails safe.

## Self-check
- CHK1: Does the plan state why the prior attempt failed and how this one
  avoids it? — PASS (Context, "Root cause": the shared proxy; fixtures never
  had a third session's main line; I44/I44b add one)
- CHK2: Is there a row that fails before the fix and passes after, with the
  exact expected text? — PASS (AC2 `got [C] want [D]`, AC3 `ok   (I44) -> D`)
- CHK3: Is the mutant check machine-checkable and both-directional
  (under-reach and over-reach)? — PASS (AC5 and the I48 rows M1/M2 kill
  I44, M3 kills I46)
- CHK4: Do edit 5 and AC6 agree on the claim to remove? — PASS (both
  quote `which always includes the lead`)
- CHK5: Is the missing/unreadable candidate transcript case defined? — PASS
  (Clarifications 6; Pre-resolved context on I30)
- CHK6: Do the affected files agree with the user's file limit (script,
  test, docs the probe touches)? — PASS (two files; no doc edit needed, with
  the reason stated in Step 1)
- CHK7: Does the validate.sh criterion say foreground, clean `/tmp`
  worktree, two parts, and why not background? — PASS (AC8, R4)
- CHK8: Is the residual false A named in both Method text and Out of scope,
  so the plan never claims more than the code? — PASS (edit 5(c), Out of
  scope, Clarifications 1)
- CHK9: Do edit 7's labels and AC3's grep counts agree (I47 = 2, I48 = 3,
  I49 = 3)? — PASS
- CHK10: Is every MUST principle listed in the Constitution check? — PASS
  (P1, P2, P3, P5; P4 is SHOULD)

## Addendum: marker-audit sweep, `--surface=tests/probe-hook-identity.test.sh`

Result: `marker-notes-sweep=6 markers=453 spec=1 code=5 untagged=0 malformed=4`.

| Unit | Note | Disposition |
|---|---|---|
| esc-fu-3 | NOTE[code] validate.sh hits 590 s in its final section | handled by R4 / AC8 (two-part foreground split) |
| esc-fu-3 | NOTE[code] `int41` under `set -m` prints a job-control line | closed by rnc-2 (job-control lines 0) |
| esc-fu-3 | NOTE[code] I39 hard-codes `{5,}` | closed by rnc-2 |
| esf-eid-probe | NOTE[code] suite sources the script before the PATH stubs | closed (stubs installed before the first source, suite `:5-14`) |
| rnc-2 | NOTE[spec] `fence_case` check (c) skips lines equal to the fence | out of scope; check (a) still covers it and this unit does not touch `fence_case` |
| rnc-2 | NOTE[code] `sigint_ignored` is safe only with job control off | honoured: edit 7 places the new rows after I42 and forbids `set -m` |

## Scribe update hint
None required. Optional and not part of `poc-1`: a `docs/harness-glossary.md`
entry for the `no-lead` teammate-check value (it has none; `subagent-shaped`
does), and one for "lead-prompt mark". Both are probe-internal; scribe
decides.
