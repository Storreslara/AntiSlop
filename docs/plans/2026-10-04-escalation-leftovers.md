# Escalation leftovers: glossary wording, auto double-Interrupted, teammate premise, F-1 (2026-10-04)

Status: FINAL (fast path, 4 dispatchable units; no task-master, no to-spec publish).
Prior specs: `docs/plans/2026-10-01-in-session-escalation-decision.md`,
`docs/plans/2026-10-02-escalation-followups.md`; ADR-0039; F-1 deferral at
`docs/plans/2026-08-24-debug-hdg-prose-2-whitespace-id.md` Part 4.

## Goal

1. Fix the decline-block glossary wording ("per mode" -> "per gated mode").
2. Explain, from evidence already on disk, the second "Interrupted" line in the
   auto-mode post-decline pane of the Bash-ask record, without a live run.
3. Make the hook-identity probe's teammate reporting honest and give the
   operator a runbook. The teammate premise stays unmeasured.
4. Close F-1: a Bash write whose target spells the DECISION path through an
   unquoted glob (`*`, `?`, `[...]`) or brace expansion (`{a,b}`) gets past
   `human-decision-gate.sh` and overwrites an existing DECISION.

## Context

### Item 1 (measured)
`docs/harness-glossary.md:2101` says gate() "requires exactly one decline
block per mode". `gate()` in `scripts/probe-bash-ask.sh:127` loops over
`default acceptEdits auto` only. dontAsk and bypassPermissions blocks are
written but never graded.

### Item 2 (measured 2026-10-03, from on-disk transcripts, no live run)
- The script sends the decline key once per mode (`scripts/probe-bash-ask.sh:71`,
  `tm send-keys -t "$s" 2`). That line is the same in every committed version
  of the script from 8d13b90 to 6d30470.
- The probe sessions' transcripts are still on disk under
  `~/.claude/projects/-tmp-bash-ask-probe/*.jsonl`. Every declined mode in
  every run has exactly one Bash `tool_use` and one rejected `tool_result`
  (`toolUseResult: "User rejected tool use"`). So there was one tool call and
  one decline. There was no second call and no second keystroke.
- The difference is the interrupt marker the session writes after the
  rejection. Auto mode wrote `[Request interrupted by user]` in the 15:53 and
  19:45 runs (2026-10-03, local time). Every other declined session, and the
  13:58 auto run, wrote `[Request interrupted by user for tool use]`.
- This matches the panes 3 of 3 times. Record cbb918e (13:58 run) has one
  Interrupted line in auto. Records 229138e (15:53) and 7e04acd (19:45) have
  two.
- The CLI version does not explain it: the 13:58 and 15:53 auto runs were both
  2.1.288.
- Not determined: why Claude Code chose the generic interrupt in those two auto
  runs, and whether the second rendered line is that marker. Both are inside
  Claude Code and cannot be derived offline. The note says so.
- The double line does not affect any graded result. The Decline row is graded
  from the filesystem decline block, not from the pane (glossary "decline block").

### Item 3 (measured from the 2026-10-03 identity record and transcripts)
- `scripts/probe-hook-identity.sh:245` sets
  `TMUX_RETRY="ran ($TCHECK)"` **before** the tmux retry runs. `$TCHECK` is
  the headless run2 check.
- In the 2026-10-03 record, `Tmux retry: ran (subagent-shaped)` therefore
  describes run2, not the tmux run. The record's appendix holds **zero**
  `run2-tmux` capture lines. `~/.claude/projects/-tmp-hook-identity-probe/`
  has no transcript from the tmux session's time.
- So the tmux retry captured nothing, and the record line reads as though it
  saw a subagent-shaped teammate.
- In run2 the lead used the Agent tool with `name: probe-mate` and got
  "Async agent launched". That is a named background agent, not a team.
- Only an operator can measure a genuine agent-teams teammate.

### Item 4 (measured this session against HEAD e2b2818)
I ran a reachability probe in a scratch fixture: an existing DECISION file
containing `ORIG`, `cwd` = project, and real `bash -c`. Every row below is
**ALLOW at HEAD and really overwrites DECISION** unless marked otherwise:

| Family | Example (all measured ALLOW + WRITES at HEAD) |
|---|---|
| F-1a glob in filename | `printf x > .claude/human-review/u1/[D]ECISION`, `?ECISION`, `DEC*`, `*`, `[A-Z]ECISION`, `[!a]ECISION`, `[^a]ECISION`, `[[:upper:]]ECISION` |
| F-1b glob in dir component | `printf x > .claude/human-rev[i]ew/u1/DECISION`, `.claude/*-review/u1/DECISIO?` |
| F-1c neither token spelled | `printf x > .claude/h*/u1/D*`, `.claude/*/*/DECISION`, `.c*/h*/u*/D*`, `.claude/human-rev[i]ew/u1/[D]ECISION`, `.claude/human-review/*/D*` |
| F-1d quotes mixed with glob | `printf x > '.claude/human-review/u1/'[D]'ECISION'`, `".claude/human-rev"[i]"ew/u1/DECISION"`, `.claude/'human-rev'[i]'ew'/u1/D*` |
| F-1e other write programs | `tee .claude/human-review/u1/[D]ECISION < /dev/null`, `cp /dev/null .claude/human-review/u1/D*`, `truncate -s0 .claude/human-review/u1/D*` |
| F-1f brace expansion | `tee .claude/human-review/u1/{D,X}ECISION < /dev/null`, `tee .claude/human-rev{i,}ew/u1/DECISION < /dev/null`, `tee .claude/human-review/u1/D{E,}CISION < /dev/null` |
| F-1g cwd-relative glob | `cd .claude/human-review/u1 && printf x > [D]ECISION`, `cd .claude && printf x > human-review/u1/[D]ECISION` |

Controls measured at HEAD:
- `printf x > '.claude/human-review/u1/[D]ECISION'` (glob quoted, so literal):
  ALLOW and does not write. This must stay ALLOW.
- `printf x > .claude/human-review/*/DECISION`: already DENY, because both
  tokens are spelled.
- `printf x > .claude/human-review/u1/@(DECISION)`: already DENY.

**Mechanism.** The early exit at `hooks/scripts/human-decision-gate.sh:492-501`
looks for literal `human-review` and `DECISION` in the quote-joined text. A
glob or brace word spells neither token, so the gate exits 0 before any
recognizer runs.

A second layer is open too. Even when a literal token appears elsewhere, for
example in a `#` comment, `triggers_are_inert()` reads the skeleton
literally. So `write_with_inert_triggers()` allows the glob write.
Measured shape: `printf x > .claude/h*/u1/[D]ECISION # human-review DECISION`.

**Feasibility prototype (spec-time only, not the implementation).** I patched
a scratch copy of the gate with one predicate, `expansion_names`:
- It walks the command and uses `command_skeleton()` to find quoted
  characters. Quoted characters are literal; a quoted `/` stays a separator.
- It splits on unquoted bash metacharacters.
- For each word with an unquoted `*`, `?`, `[` or `{`, it collapses brace
  groups innermost-first to `*`. A group that contains `/` makes the word
  name both tokens.
- It splits the word on `/` and matches with `nocasematch` and `extglob` on.
  The last component matching `DECISION` sets EXP_D. Any earlier component
  matching `human-review` sets EXP_H.
- When the lexer fails, it scans the raw text with every metacharacter live.

The early exit treated a token as present if it was literal **or** set by
EXP. When EXP fired, only `command_is_provably_benign` and
`is_sanctioned_marker_write` could allow; everything else was denied.

Result: every WRITES row in the table above was DENY, and both quoted-glob
controls stayed ALLOW. That proves the shape is feasible.

I also ran a differential sweep of that **prototype** against HEAD over
9,377 unique real Bash commands taken from this project's transcripts (last
20 days). Result: `total=9377 new_denials=42 new_allowances=0`. I sampled the
42 new denials by eye and did not classify each one:
- Most were heredoc-bearing commands (`cat > f <<'EOF' ...`). The lexer
  fails on these, so the raw-text fail-closed scan treats body text as live
  globs.
- A few were brace words containing `/`, such as
  `sha256sum {.claude,adapters/codex}/hooks/...`, which the prototype treats
  as naming both tokens.

None of the 42 looked like an F-1 write. This is the prototype's
false-positive cost, not the implementation's. esc-left-3 must narrow it
(Open Question 3) and re-measure it.

### Prior defect history (`.fail` screen)
- `.claude/reviewed/esc-chat-6.fail` and `esc-chat-7.fail` both FAILed on
  glossary prose that claimed more than the code does.
- `hdg-prose-2.fail` hit the 2-FAIL cap on this same gate, from a
  predicate that did not model one character dimension.
- Re-scoped consequences:
  - esc-left-3 is opus, carries a frozen family table, and needs a mutation
    proof.
  - esc-left-4, the docs unit for the gate, uses claim-anchored criteria.
- `esc-chat-6.pass` NOTE[spec] asked for "(F-1 aside)" on the glossary
  invariant sentence (`docs/harness-glossary.md` ~2274-2295). Disposition:
  esc-left-4 rewrites that sentence for the post-fix state, naming the
  remaining residuals instead of F-1.
- `esc-chat-6.pass` NOTE[code] said the bare `sh -c 'printf x > DECISION'`
  example is allowed at HEAD. Disposition: esc-left-4 checks the example
  and fixes it if it is still present.
- I did not run `bin/marker-audit.sh --notes` sweeps; the turn limit stopped
  me. Assumption A5 covers this.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-04 Functional scope & success criteria: Q Is brace expansion part
  of F-1, or a separate residual? → A (self-resolved): part of F-1 (family
  F-1f). It is the same early-exit miss, and `tee ...{D,X}ECISION` was
  measured overwriting DECISION. Closing glob without brace is the "partial
  fix is worse than none" trap from the 2026-08-24 Part 4.
- 2026-10-04 Functional scope & success criteria: Q Does F-1 include
  reviewed-path-gate.sh's `.claude/revie[w]ed/...` variant? → A
  (self-resolved): no. The user scoped item 4 to human-decision-gate.sh. It
  is recorded as deferred (Out of scope, Open Question 1).
- 2026-10-04 Non-functional attributes: Q What false-positive cost is
  acceptable? → A (self-resolved): new allowances must be 0. Every new denial
  over the real-command differential sweep must be either in the F-1 family
  table or listed as an accepted over-block in the suite.
- 2026-10-04 External dependencies & integrations: Q Can item 2/3 evidence
  rely on `~/.claude/projects` transcripts? → A (self-resolved): yes as
  measured evidence quoted into the note with the exact command used, but
  the transcripts are machine-local and may be pruned, so the note quotes
  the results and does not depend on them existing later.
- 2026-10-04 Edge cases / failure handling: Q What happens when the shared
  lexer cannot skeletonize (heredoc, backslash, `$'`)? → A (self-resolved):
  fail closed. The raw text is scanned with every metacharacter treated as
  live. Any over-block this causes is pinned as an accepted over-block row,
  not narrowed in this unit.
- 2026-10-04 Technical constraints & tradeoffs: Q Does a hooks/scripts-only
  change trigger P3? → A (self-resolved): not mechanically, because
  `version-stamp-check.sh` matches only `agents/*.md|templates/*`. But the
  gate has a `--update`-managed mirror at
  `.claude/hooks/scripts/human-decision-gate.sh` plus a fileHashes entry, and
  every recent gate commit (ae76a86, 012e7d8, e96db38, 9b98f10) bumped the
  version and the CHANGELOG. So esc-left-3 bumps 0.31.117 -> 0.31.118, adds a
  CHANGELOG entry, and runs `node bin/cli.js --update` in the same commit.
  The version is bumped BEFORE `--update`.
- 2026-10-04 Terminology consistency: Q "teammate" here means a genuine
  agent-teams teammate, not a named background Agent-tool spawn. → A
  (self-resolved): yes. The run2 "probe-mate" was a named async agent, and
  the docs must not call it a teammate measurement.

## Assumptions
- A1: The gate's protected file stays `.claude/human-review/<id>/DECISION`.
  Its two tokens are whole path components, so component-level matching is
  sound for glob words. Literal substring checks are unchanged.
- A2: Bash shell options in the Bash tool are unknown. The predicate assumes
  the worst for the gate: case-insensitive (`nocaseglob`) and `extglob` on.
- A3: The cwd-only family stays a pre-existing residual and is not widened
  here. Its member is a write to a glob such as `D*` from inside a packet dir
  with `human-review` never spelled anywhere, the same as today's literal
  `printf x > DECISION` with no `human-review`.
- A4: R-4 (split variable), R-5 (backslash), and NL1 (newline in id) are
  unchanged.
- A5: The marker-audit `--notes` sweep was not run for this plan. The
  reviewer of each unit treats the `.pass` notes cited in Context as the
  known set, not the complete one.

## Risks / dependencies
- R1: A false-positive regression across every agent's Bash calls. The gate
  runs on all Bash. Mitigation: the differential sweep criterion in
  esc-left-3. The sweep is measured, not assumed.
- R2: An unbounded-universal criterion ("no glob bypass exists") would cause
  FAIL loops (memory: harness-integrity-gate debug spec). Mitigation: a
  frozen family table. A spelling outside the table is out of scope, not a
  FAIL ground.
- R3: Mutation proofs under the microworld queue report false FAILs because
  of memoization. Mutation criteria run standalone (`bash
  tests/human-decision-gate.test.sh` with `GATE_UNDER_TEST`), never under the
  queue.
- R4: `tests/validate.sh` takes more than 10 minutes. Run it in a scratch
  git worktree (`git worktree add /tmp/<x> HEAD`). If it cannot finish within
  the 600000 ms foreground cap, end the turn with the WIP sentinel and the
  reason "no autonomous wake-up available — requires the dispatcher to
  resume me later". The reviewer re-runs it.
- R5: The gate blocks your own diagnostic Bash text when it names both
  tokens. Write probe and fixture scripts with the Write tool into scratch
  and run them as `bash <path>`. Use `git commit -F <file>` for messages.
- Dependencies: esc-left-4 depends on esc-left-3. esc-left-1 and esc-left-2
  are independent of everything.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every claim in Context is labelled
  measured or not determined. The unfinished sweep is stated as unfinished,
  and esc-left-3 must measure it.
- P2 "Prefer deterministic scripts": satisfied. The mirror and fileHashes are
  updated by `node bin/cli.js --update`, never by hand.
- P3 "Version-stamp discipline": satisfied.
  - esc-left-3 bumps the version, adds a CHANGELOG entry and runs `--update`
    in the same commit. This is convention for gate changes, not a
    mechanical trigger.
  - esc-left-1, esc-left-2 and esc-left-4 touch no `agents/*.md` or
    `templates/*`, so P3 does not apply. Their criteria assert that.
- P4 "Optional personas degrade gracefully": satisfied. No shared persona
  prose is touched.
- P5 "validate.sh is the merge gate": satisfied. Every unit has a
  `bash tests/validate.sh` criterion, run per R4.

## Steps (dispatch contracts)

### Unit: esc-left-1
Suggested model: sonnet. Depends on: none.

## Objective
Fix the glossary decline-block wording to "per gated mode". Add a post-hoc
analysis note explaining the auto-mode double "Interrupted" line. Point to
the note from the glossary Ship gate entry.

## Retrieval
This plan: `docs/plans/2026-10-04-escalation-leftovers.md`, "Item 1" and
"Item 2" under Context. No tracker issue exists (fast path).

## Affected files
- `docs/harness-glossary.md` (decline block entry ~2093-2104; Ship gate
  entry ~2047-2078)
- `docs/experiments/2026-10-04-auto-double-interrupt.md` (new)

## Ordered edits
1. In the decline block entry, replace "exactly one decline block per mode"
   with "exactly one decline block per gated mode (default, acceptEdits,
   auto)".
2. Create `docs/experiments/2026-10-04-auto-double-interrupt.md`, headed as
   a **post-hoc analysis, not script output**. It must contain:
   - The single-keystroke fact, citing `scripts/probe-bash-ask.sh:71`.
   - The transcript evidence from Context Item 2: one `tool_use` and one
     rejected `tool_result` per declined mode, and auto's
     `[Request interrupted by user]` against
     `[Request interrupted by user for tool use]` everywhere else.
   - The 3-of-3 correlation table: cbb918e=1 line, 229138e=2, 7e04acd=2.
   - Why the version does not explain it.
   - An explicit "Not determined" paragraph: the cause inside Claude Code,
     and whether the second rendered line is that marker.
   - The exact jq command used, with a note that the transcripts are
     machine-local and may be gone.
   - A statement that grading is unaffected.
   - An operator step: a fresh live re-run could confirm whether auto still
     emits the generic marker. That re-run is optional and not part of any
     unit.
3. In the Ship gate entry's "Evidence limits", add one sentence pointing to
   the new note.

## Do NOT touch
- `docs/experiments/2026-10-01-probe-bash-ask.md`. It is a generated
  record, and `gate()` parses it.
- `scripts/`, `hooks/`, `agents/`, `templates/`.

## Acceptance criteria
- `grep -c 'exactly one decline block per gated mode' docs/harness-glossary.md`
  prints 1.
- `grep -c 'decline block per mode' docs/harness-glossary.md` prints 0.
- `grep -cE 'Request interrupted by user for tool use' docs/experiments/2026-10-04-auto-double-interrupt.md`
  is at least 1, and `grep -c 'Not determined' <same>` is at least 1.
- `grep -cE 'cbb918e|229138e|7e04acd' <same>` is at least 3.
- `grep -c '2026-10-04-auto-double-interrupt' docs/harness-glossary.md`
  prints 1.
- `git diff --quiet HEAD~1 -- docs/experiments/2026-10-01-probe-bash-ask.md scripts hooks agents templates`
  exits 0.
- `bash tests/probe-bash-ask.test.sh` exits 0.
- `node tests/context-glossary-links.test.js` exits 0.
- `bash tests/validate.sh` exits 0 (per R4).

## Pre-resolved context
- Correlation and transcript facts: see Context Item 2. Re-verify the counts
  yourself with the jq command; do not copy them blind. If the transcripts
  are gone, cite this plan as the measurement source and say so.

## Escalation
If a measured fact in this plan does not reproduce, report it with the
`STATUS: incomplete` line. Do not soften the note to fit.

### Unit: esc-left-2
Suggested model: sonnet. Depends on: none.

## Objective
Make `scripts/probe-hook-identity.sh` report what the tmux retry itself
captured, and add an operator runbook for measuring a genuine agent-teams
teammate. Measure nothing live.

## Retrieval
This plan, Context "Item 3".

## Affected files
- `scripts/probe-hook-identity.sh`
- `tests/probe-hook-identity.test.sh`

## Ordered edits
1. After `retry_teammate_tmux` returns, set `TMUX_RETRY` from the tmux run's
   OWN capture. Use the format
   `ran: <N> run2-tmux capture lines; teammate check: <check over run2-tmux candidates only, or none>`.
   When N is 0, `TMUX_RETRY` must read
   `ran: 0 run2-tmux capture lines; nothing captured`. Put the logic in a
   pure function, `tmux_retry_summary <capture>`.
2. Write the tmux pane (`$RAW/teammate-tmux.txt`) into the record appendix
   under `### tmux retry pane` when it exists.
3. Add a header comment block, `# Operator runbook (teammate premise)`. It
   says:
   - A genuine teammate needs an interactive agent-teams session started by
     the operator. Reference the `antislop:start-feature-team` skill and
     `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
   - A named Agent-tool spawn ("Async agent launched") is not a teammate.
   - Re-run the script or capture a teammate's PreToolUse payload by hand.
   - Until a `genuine` check is recorded, Outcome D stands and the teammate
     premise is unmeasured.

## Do NOT touch
- `docs/experiments/2026-10-03-probe-hook-identity.md`. It is a historical
  record and is not regenerated here.
- `classify_rows`, `outcome`, `teammate_check` semantics.
- `hooks/`, `agents/`, `templates/`.

## Acceptance criteria
- `bash tests/probe-hook-identity.test.sh` exits 0 with new cases that do
  all of the following:
  - (a) A capture with run2 subagent-shaped lines and zero run2-tmux lines
    gives `tmux_retry_summary` output containing `0 run2-tmux capture lines`
    and NOT `subagent-shaped`.
  - (b) A capture with run2-tmux candidate lines reports their own count and
    check.
  - (c) Mutation: with `tmux_retry_summary` replaced by the old
    `ran ($TCHECK)` text (`PROBE_UNDER_TEST` pointed at a mutated scratch
    copy), case (a) fails. Record the mutant command in the commit message.
- `grep -c 'Operator runbook (teammate premise)' scripts/probe-hook-identity.sh`
  prints 1.
- `bash -n scripts/probe-hook-identity.sh` exits 0.
- `git diff --name-only HEAD~1` lists only the two affected files.
- `bash tests/validate.sh` exits 0 (per R4).

## Pre-resolved context
- The test file already sources the script with PATH stubs for claude, tmux
  and sleep. Extend the `cap()` fixture with run `run2-tmux`.

## Escalation
If `teammate_choose` cannot be scoped to one run without changing its
existing outputs, stop and report. Do not change classification semantics.

### Unit: esc-left-3
Suggested model: opus. Depends on: none.

## Objective
Close F-1 in `hooks/scripts/human-decision-gate.sh`. A Bash command where an
unquoted glob or brace word could name the human-review directory or the
DECISION file must count as naming that token, and the gate then fails
closed: such a command is allowed only by `command_is_provably_benign`,
`is_sanctioned_marker_write`, or the existing prompt route. Prove closure
against the frozen family table, prove it with a mutation, and bound false
positives with a differential sweep.

## Retrieval
This plan, Context "Item 4" (family table, mechanism, prototype). Prior
deferral: `docs/plans/2026-08-24-debug-hdg-prose-2-whitespace-id.md` Part 4.

## Affected files
- `hooks/scripts/human-decision-gate.sh`
- `tests/human-decision-gate.test.sh`
- `tests/hdg-differential-sweep.sh` (new; review tool, not wired into
  validate.sh)
- `.claude-plugin/plugin.json`, `package.json` (0.31.117 -> 0.31.118)
- `CHANGELOG.md`
- Files regenerated by `node bin/cli.js --update`: the
  `.claude/hooks/scripts/human-decision-gate.sh` mirror, the fileHashes in
  `.claude/persona-config.json`, and version stamps. Commit them in the same
  commit and do not hand-edit them.

## Ordered edits
1. Add a predicate local to the gate (recommended shape: the prototype in
   Context). Requirements:
   - (a) Quotedness comes from `command_skeleton()`. Quoted characters are
     literal, a quoted `/` is still a separator, and quote characters join
     fragments.
   - (b) Only words with an unquoted `*`, `?`, `[` or `{` are analysed.
   - (c) Brace groups collapse innermost-first to a fixpoint. A group
     containing `/` names both tokens.
   - (d) Components are matched with case-insensitive matching and extglob
     on (A2). A last component that can match `DECISION` names the file. A
     non-last component that can match `human-review` names the directory.
   - (e) If `command_skeleton()` fails, scan the raw text with every
     metacharacter treated as live (fail closed).
   - (f) Shell options changed for matching are restored, and the locale
     used is stated in a comment.
2. Change the early exit: a token is present if it is literal in the
   quote-joined text OR named by the predicate. After `gating_off`, the
   prompt route and `command_is_provably_benign`: if the predicate named any
   token, allow only via `is_sanctioned_marker_write`; otherwise deny.
3. Update the header comment at :481-491. It must say F-1 is closed for the
   frozen families, name the residuals that remain (A3, A4), and point to
   this plan.
4. In the suite:
   - Flip F1a-F1d to `blocked` and delete their TRACKED-OPEN comment.
   - Add one `blocked` row per example in the Context Item 4 family table
     (F-1a..F-1g), named `FG-<family>-<n>`.
   - Add a reachability check per family: real bash in a fixture with an
     existing DECISION (sentinel content) shows the spelling overwrites it.
     This is the precondition for crediting a blocked row.
   - Add `allowed` controls:
     - the quoted `'.claude/human-review/u1/[D]ECISION'` write
     - `cat .claude/human-review/u1/D*`
     - `ls .claude/human-review/*/`
     - `rm -f build/*.o`
     - `ls *`
     - `git commit -m 'note human-review [D]ECISION'` (quoted, so inert)
   - Add an `OB-` section pinning each accepted over-block the sweep finds,
     each with a one-line reason.
5. Write `tests/hdg-differential-sweep.sh <old-gate> <new-gate> <corpus.jsonl>`.
   For each command it prints old/new verdicts and a summary line
   `total=N new_denials=D new_allowances=A`.
6. Bump the version, add a CHANGELOG entry, and run `node bin/cli.js --update`,
   all in one commit, version first.

## Do NOT touch
- `hooks/scripts/lib/benign-command.sh` (shared with reviewed-path-gate)
- `hooks/scripts/reviewed-path-gate.sh` (F-1-rpg is out of scope)
- The `is_prompt_eligible_decision_write` and `decision_body_ok` grammar
- `agents/`, `templates/`
- Glossary, ADR and wiki (esc-left-4 owns them)

## Acceptance criteria
- `bash tests/human-decision-gate.test.sh` exits 0, run standalone and not
  under the microworld queue. F1a-F1d are `blocked`, every FG row is
  `blocked`, and every reachability check reports an overwrite.
- `grep -c 'TRACKED-OPEN (not accepted)' tests/human-decision-gate.test.sh`
  prints 1. Only the NL1 pin remains.
- Mutation:
  - Make the new predicate a no-op (never names a token), in a scratch copy
    passed via `GATE_UNDER_TEST`. `bash tests/human-decision-gate.test.sh`
    exits non-zero, and every FG and F1 row FAILs.
  - Second mutant: remove only the post-benign deny from edit 2. At least
    the comment-carried row `printf x > .claude/h*/u1/[D]ECISION # human-review DECISION`
    FAILs, so that row must exist in the suite.
  - Paste both mutant commands and their failure counts in the commit
    message.
- Differential sweep:
  - Build the corpus with
    `find ~/.claude/projects/-home-sebas-AntiSlop -name '*.jsonl' -mtime -20 | xargs cat | jq -c 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Bash") | .input.command' | sort -u > /tmp/hdg-corpus.jsonl`.
  - Run `bash tests/hdg-differential-sweep.sh <HEAD~1 gate copy> hooks/scripts/human-decision-gate.sh /tmp/hdg-corpus.jsonl`.
    It prints `new_allowances=0`.
  - Every new denial is either an F-1 family member or matches an OB row.
    Paste the summary line and the classified list in the commit message.
- `git diff --quiet HEAD~1 -- hooks/scripts/lib/benign-command.sh hooks/scripts/reviewed-path-gate.sh`
  exits 0.
- `jq -r .version .claude-plugin/plugin.json` prints `0.31.118`, and
  `grep -c '0.31.118' CHANGELOG.md` is at least 1.
- `hooks/scripts/version-stamp-check.sh HEAD~1..HEAD` prints `ok`.
- `bash tests/reviewed-path-gate.test.sh` exits 0.
- `bash tests/validate.sh` exits 0 (per R4; mirror parity and fileHashes).

## Pre-resolved context
- The prototype at spec time closed every WRITES row in the family table
  and kept both quoted-glob controls ALLOW.
- That prototype had a bug: it escaped quoted `/`. Edit 1(a) prevents it.
- Its false-positive cost is unmeasured. The sweep criterion is the
  measurement.
- Measured over-block of the prototype: 42 of 9,377 real commands, 0 new
  allowances. The causes are mostly heredoc bodies scanned raw under edit
  1(e), plus brace groups containing `/`.
- Default narrowing (Open Question 3): a heredoc whose delimiter is quoted
  (`<<'X'` or `<<"X"`) has a wholly inert body. Exclude the body lines,
  between the operator line and the first line equal to the delimiter, from
  the glob scan. All other text stays scanned. Never apply this to an
  unquoted delimiter.
- For a brace group containing `/`, expand it to its alternatives instead of
  naming both tokens, if that can be done without `eval`. Otherwise keep it
  and pin it as OB.
- Each narrowing needs its own mutation row: a write hidden AFTER the
  heredoc terminator must still be denied.

## Escalation
- If the sweep shows `new_allowances` > 0, or more than 25 new denials
  outside the F-1 families, stop and report with the list. That threshold is
  the point where the over-block policy needs a human decision.
- A spelling outside the family table that still bypasses is a finding to
  report, not a FAIL ground for this unit (R2).

### Unit: esc-left-4
Suggested model: sonnet. Depends on: esc-left-3 (PASS).

## Objective
Bring the F-1 prose in sync with the closed gate: glossary, ADR-0039,
`.claude/wiki/architecture.md` and CONTEXT.md, wherever they describe F-1 as
open. Also handle the two `esc-chat-6.pass` notes.

## Retrieval
This plan, Context "Prior defect history". esc-left-3's commit message
(family table, OB rows, sweep summary).

## Affected files
- `docs/harness-glossary.md` (~2255-2300)
- `docs/adr/0039-prompt-confirmed-decision-write.md`, only if it states F-1
  as open; `git grep -n 'F-1' docs/adr/0039*` decides.
- `.claude/wiki/architecture.md` (~31-32)
- `.claude/wiki/changelog.md`

## Ordered edits
1. Glossary ~2286 and ~2295: replace the "F-1 residual class ... never arms
   the gate" and "F-1 aside" wording with the post-fix state. F-1's glob and
   brace families are closed as of esc-left-3's commit. Name the remaining
   residuals: R-4, R-5, NL1, the cwd-only family (A3), and the OB
   over-blocks. Every name must match a pin that exists in the suite.
2. Fix the invariant sentence ("no agent can complete a DECISION write
   without a human approving its bytes"). Qualify it with the remaining
   residuals instead of F-1.
3. Glossary ~2262 `sh -c 'printf x > DECISION'` example: check its verdict
   with the gate. If the example still claims a denial the gate does not
   give, correct it.
4. Wiki architecture and changelog: one-line updates that match the above.

## Do NOT touch
- Gate code and tests.
- `agents/`, `templates/`.
- Any prose about the reviewed-path-gate F-1 variant except "deferred".

## Acceptance criteria
- `grep -nE 'F-1 aside|F-1 residual class' docs/harness-glossary.md .claude/wiki/architecture.md`
  returns no lines.
- Claim-anchored check: for each residual the edited glossary names, a pin
  with that name exists in `tests/human-decision-gate.test.sh`. For example,
  `grep -c 'NL1' tests/human-decision-gate.test.sh` is at least 1. List the
  greps run in the commit message.
- Each command the edited prose gives as a gate example has its verdict
  re-measured against the gate. The verdicts are listed in the commit message
  and match the prose.
- `node tests/context-glossary-links.test.js` and
  `node tests/protocol-doc-drift.test.js` exit 0.
- `git diff --quiet HEAD~1 -- hooks tests agents templates` exits 0.
- `bash tests/validate.sh` exits 0 (per R4).

## Pre-resolved context
- esc-chat-6 and esc-chat-7 FAILed for prose claiming more than the code.
  Every sentence must be checkable against the gate or the suite.

## Escalation
If esc-left-3 left a family open, the prose says it is open. Never describe
an open residual as closed.

## Operator steps (not dispatchable)
- OP1: An optional live re-run of `scripts/probe-bash-ask.sh` to see whether
  auto still writes the generic interrupt marker. It is not required by any
  unit.
- OP2: Measure the teammate premise in a genuine agent-teams session, using
  esc-left-2's runbook. Until a `genuine` check is recorded, the docs keep
  the teammate premise as **unmeasured** (Outcome D).

## Out of scope
- The F-1 variant in `reviewed-path-gate.sh` (`.claude/revie[w]ed/...`,
  measured ALLOW on 2026-08-24). Deferred; see Open Question 1.
- The cwd-only family, R-4, R-5 and NL1. They are unchanged.
- Multi-call chains (mv out / write / mv back). The gate is a single-command
  guard by construction.

## Open Questions
1. Should the `reviewed-path-gate.sh` F-1 variant get its own follow-up
   unit? Recommended default: yes, as a separate later spec after
   esc-left-3's predicate has passed review. It is not blocking. (From
   CHK6.)
2. Should a hooks-only gate change keep bumping the plugin version? This
   plan follows recent gate commits and bumps it. Recommended default: yes,
   bump (0.31.118). It is not blocking. (From CHK7.)
3. The F-1 prototype over-blocked 42 of 9,377 real commands (0.45%), with 0
   new allowances. How much over-block is acceptable? Recommended default:
   the implementer narrows quoted-delimiter heredoc bodies and slash-bearing
   brace groups (esc-left-3 Pre-resolved context), and escalates if more
   than 25 new denials outside the F-1 families remain. It is not blocking.
   (From CHK10.)

## Self-check
- CHK1: Does each of the four goal items map to a unit or an operator step?
  — PASS. Item 1 → esc-left-1. Item 2 → esc-left-1 plus OP1. Item 3 →
  esc-left-2 plus OP2. Item 4 → esc-left-3 plus esc-left-4.
- CHK2: Does every unit have runnable criteria, with no prose-only
  criterion? — PASS.
- CHK3: Is the F-1 closure criterion bounded rather than universal? — PASS.
  It uses the frozen family table, and R2 states the out-of-table rule.
- CHK4: Is there a mutation proof that can fail? — PASS. esc-left-3 has two
  mutants, one of them aimed at the comment-carried second layer.
- CHK5: Does the plan claim any measurement it did not run? — PASS. The
  sweep is stated as unfinished, and the item 2 cause is "not determined".
- CHK6: Is reviewed-path-gate's F-1 variant handled explicitly? — FAIL
  (missing), converted to Open Question 1.
- CHK7: Is P3 applicability stated for each unit? — FAIL (ambiguous). It is
  convention, not mechanism. Revised in place (Clarifications, Constitution
  check) and converted to Open Question 2 for user confirmation.
- CHK8: Do esc-left-3 and esc-left-4 agree on who edits the glossary? —
  PASS. esc-left-3's "Do NOT touch" excludes it, and esc-left-4 owns it.
- CHK9: Do the generated records stay untouched? — PASS. Both units'
  "Do NOT touch" lists name them.
- CHK10: Is the false-positive budget for esc-left-3 decided by the plan? —
  FAIL (ambiguous). The prototype measured 42 over-blocks against the
  25-denial escalation threshold. Converted to Open Question 3, with a
  default narrowing written into esc-left-3.

## Scribe update hint
- Once esc-left-3 passes, add a glossary entry for the new predicate,
  "expansion-named token" (harness-glossary, not CONTEXT.md).
- Update the F-1 status in the wiki changelog.
