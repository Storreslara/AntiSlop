# Review-note cleanup after esc-fu-1..3 and qp-1/2 (2026-10-04)

Status: FINAL (spec-master, 2026-10-04). Two units, fast path (five or fewer
units): this document holds the dispatch contracts. There is no task-master
slicing and no tracker issue. Base: HEAD `d7c4242`. Spec only; nothing here
is implemented.

Amended 2026-10-04 (spec-master) after reviewer FAIL #1 on rnc-1 (commit
`09eb34d`, record `.claude/reviewed/rnc-1.fail`). Only rnc-1's edits A, B
and D, its check script, its model tag and the bookkeeping that names them
changed. rnc-2 is untouched. See "Fix after FAIL #1" under rnc-1.

## Goal

Close the deferred non-blocking review notes from esc-fu-1, esc-fu-2,
esc-fu-3, qp-1 and qp-2 that are still true at `d7c4242`, in two units that
never touch the same file:

- G1 (unit rnc-1). The `docs/harness-glossary.md` entries for the frozen
  family table, the accepted over-block (OB row), the expansion-named token
  and the trigger token agree with what qp-1 shipped. "Closed" and "pinned"
  no longer contradict each other. The second-shell rule is described as
  the gate implements it. No body line is wider than 78 columns.
- G2 (unit rnc-2). `scripts/probe-hook-identity.sh` reports a failed
  `mktemp` instead of a silent zero. It also closes its pane fence when the
  pane has no trailing newline. `tests/probe-hook-identity.test.sh` stops
  hard-coding the fence length and prints no job-control lines. When it runs
  as a background job, where SIGINT is ignored, it SKIPs the SIGINT case
  with a visible line instead of failing. The foreground SIGINT check is
  unchanged.

## Context

### Item verification at d7c4242 (13 candidates)

| # | Source | Verdict | Evidence |
|---|---|---|---|
| 1 | esc-fu-1 NOTE[code] gate header wording | **drop, done** | `hooks/scripts/human-decision-gate.sh:728-731` now reads "the early exit fires when the text does not name both tokens, counting as patterns only unquoted globs and globs in a quoted string handed to a second shell". That is the wording the note asked for, and it is extended for qp-1. |
| 2 | esc-fu-1 NOTE[spec] suite comment mechanism | **drop, done** | `tests/human-decision-gate.test.sh:1001-1006` now says "`joined` deletes only the quote characters, so these commands DO spell human-review", and it names the skeleton-based glob scan as the cause. |
| 3 | esc-fu-1 NOTE[code] QP-3 literal `D*` | **drop, done** | `tests/human-decision-gate.test.sh:1043-1045` has the `QP-3 literal:` pass/bad pair. |
| 4 | esc-fu-2 NOTE[code] closed vs pinned | **in, rnc-1 edit A/B** | `docs/harness-glossary.md:2325` "A spelling outside the table is not claimed closed" and `:2333` "Closed by qp-1". The QP rows sit outside the table and are claimed closed. |
| 5 | esc-fu-2 / qp-2 long lines | **in, rnc-1** | Measured body lines over 78 columns: `:2362` (106, OB row), `:2393` (98, expansion-named token), `:2400`, `:2401`, `:2409` (79-80, trigger token). The frozen family table entry's own long lines were already rewrapped by qp-2 (0 now). |
| 5b | "one sentence mixes bash and sh forms" | **drop, no source** | None of the `.pass` notes on this surface says this (esc-fu-2, qp-1, qp-2, marker-audit sweep below). The only sentence naming both forms is OB-14's "`sh -c` / `bash -c` payload". It matches the suite's own OB-14 reason text and is accurate. Edit B rewrites the other candidate, "(`sh`, `bash` or `dash` with a `-c` option)", anyway. |
| 6 | qp-2 NOTE[code] "a `-c` option" | **in, rnc-1 edit B** | `glob_scan_shell_payloads()` (`human-decision-gate.sh:451-480`) matches an unquoted shell name at a word start or after `/`, then option words starting with `-` or `+`, the last a short-option cluster holding `c`, under nocasematch. Pins: QPF-1 `/bin/sh`, QPF-2/3 `-e -c` and `-ec`, QPF-6 `--noediting`, QPF-8 `+e`. |
| 6b | (found here) expansion-named token / trigger token omit qp-1 | **in, rnc-1 edits D/E** | `:2393` "When the command lexes, a quoted glob is literal and names nothing." This has been false since qp-1, because QP-1 and QPF-* are quoted globs that arm the gate. The trigger token entry (`:2402-2404`) lists only "an unquoted glob or brace word". Both are false claims in entries that rnc-1 rewraps anyway. qp-2 corrected only the frozen family table. |
| 7 | esc-fu-3 `:126` `mktemp` unchecked | **in, rnc-2** | Still bare at `scripts/probe-hook-identity.sh:126`. |
| 8 | esc-fu-3 `:241` fence glued | **in, rnc-2** | Now `:238`: `cat "$RAW/teammate-tmux.txt"; printf '%s\n' "$f"`, with no newline guard. |
| 9 | esc-fu-3 I39 `{5,}` | **in, rnc-2** | `tests/probe-hook-identity.test.sh:283-286` (`{5,}` and the `'`````'*` prefix). |
| 10 | esc-fu-3 I41 job-control line | **in, rnc-2** | Measured 2026-10-04: a foreground run prints `[1]+  Terminated ...` and `[1]+  Interrupt ...` on stderr (2 lines). |
| 11 | I41 fails as a background job | **in, rnc-2** | Measured: `bash -c 'bash tests/probe-hook-identity.test.sh > out 2>&1 & wait $!'` gives rc 1 with `FAIL (I41) INT exits 130: got [3] want [130]`, and TERM passes. Mechanism: a non-interactive bash starts async children with SIGINT ignored, and a signal ignored on entry cannot be trapped or reset. `bash -c 'kill -INT $$'` exits 130 in the foreground and 0 under `& wait` (both measured). |
| 12 | esc-fu-3 NOTE[spec] I38/I39 vs I42 ids | **drop** | This is a historical plan-text divergence only. The behaviour matches, and changing a FINAL plan's ids buys nothing. |
| 13 | esf-eid-probe-fix NOTE[spec] false C | **out of scope (Open Question 1)** | Still reachable: `teammate_choose` (`:107-116`) takes the run's first `echo probe-main` line as the lead without checking it. Fixing it means choosing between two classifier remedies and rewording the Method text. Prior defect history in this exact function (see below) points to a separately grilled unit. |

### Prior defect history (`.fail` screen)

The whole review-marker directory was listed (451 markers). Records on
these surfaces were read:
- `esf-eid-probe-fix.fail`: a false C/A from the **same teammate-lead
  selection** that item 13 concerns. That is why item 13 stays out of a
  cleanup bundle.
- `qp-1.fail`: a missed character dimension in the second-shell regex.
  Edit B therefore describes the shipped, fixed rule (`[[:blank:]]`, `+`
  option words), not the pre-fix one.
- `esc-left-4.fail`, `esc-chat-6.fail`, `esc-chat-7.fail`: glossary prose
  that claimed more than the code. Hence rnc-1's claim-anchored,
  entry-scoped check script.
- Neither esc-fu-2, esc-fu-3 nor qp-2 has a `.fail`. The Implementer-tier
  ratchet did not apply to either unit at spec time.
- `rnc-1.fail` (added 2026-10-04, FAIL #1 on `09eb34d`): edit A's
  sentence "the only spellings claimed blocked are pinned ones: FP-ext-1
  and the qp-1 rows below" was a closed list, and false. The same entry
  names Q20 as blocked, and FP-nc-1 is pinned blocked with a real-bash
  reachability line. Neither was in the list. The spec's check only
  tested that the phrase was present. This was a spec defect, not an
  implementer one, so the fix needs this amendment. The ratchet now
  applies: the re-dispatch is tagged opus.

### Marker-audit `--notes` sweep (run 2026-10-04 at d7c4242)

`bash bin/marker-audit.sh . --notes --surface=<path>` for each touched file:
- `docs/harness-glossary.md` (57 notes): the esc-fu-2 and qp-2 NOTE[code]
  lines are items 4/5/6, consumed by rnc-1. The esc-fu-2 NOTE[spec] is
  history. The 2 untagged lines (item05-3, "completion record") are older
  PASSed units, not steps awaiting dispatch, and are **out of scope**.
- `scripts/probe-hook-identity.sh` (9): esc-fu-3's `:126` and `:241` notes
  are consumed by rnc-2. The esc-fu-3 and esf-eid-probe-fix false-C notes
  are item 13 (Open Question 1). esc-left-2's three notes were consumed by
  esc-fu-3. esf-eid-probe `rf()` greedy-match: resolved, because `rf()`
  (`:148`) now splits on spaces and takes the first `key=` token.
  esf-eid-probe user-settings env override: an operator concern, **out of
  scope** (teammate-premise measurement).
- `tests/probe-hook-identity.test.sh` (4): esc-fu-3's job-control and
  `{5,}` notes are consumed by rnc-2. The validate.sh 590 s note is a
  runtime fact handled by the split procedure below. esf-eid-probe's `:6`
  stub-order note was resolved per esc-fu-3.pass.

The sweep is best-effort. The marker directory is per-clone state.

### Blast radius (git grep, not graph-derived)

- The four glossary entries are read by no test. `git grep` for "not
  claimed closed", "Closed by qp-1", "names nothing" and "a `-c` option"
  outside `docs/plans` finds only `docs/harness-glossary.md`. Only
  `tests/context-glossary-links.test.js` (link integrity) and
  `tests/protocol-doc-drift.test.js` touch the file.
- `tmux_retry_summary` and `pane_fence` have no callers outside the script
  and its suite. `tests/validate.sh:1152-1153` runs the suite as its final
  section.

### Version stamping (P3)

Not triggered. `hooks/scripts/version-stamp-check.sh:60-61,91-92` gates only
`agents/*.md|templates/*`. `bin/cli.js` does not ship `scripts/` or
`docs/harness-glossary.md` (`git grep` of `bin/` finds neither). Precedent:
esc-fu-3 (dfce91f) changed these same two files with no bump. No version
bump, no CHANGELOG entry, no `--update`.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-04 Functional scope & success criteria: Q Which of the 13
  candidate notes are still true at d7c4242? → A (self-resolved): verified
  item by item (Context table). Items 1, 2, 3, 12 and 5b are dropped. Item
  13 is out of scope (Open Question 1). Item 6b is added because it is the
  same false-claim class as item 6, in an entry rnc-1 rewraps anyway.
- 2026-10-04 Functional scope & success criteria: Q Should item 13's false
  C be fixed in this bundle? → A (self-resolved, user may override via Open
  Question 1): no. It needs a classifier design choice, and this function
  already has a FAIL on record.
- 2026-10-04 Non-functional attributes (perf, security, scale): Q Should
  rnc-2's new mutation proofs live inside the suite, like I37/I42? → A
  (self-resolved): no, they are acceptance-criteria commands only. Every
  in-suite mutant re-runs the whole suite. `tests/validate.sh` already
  exceeds 600 s, and this suite is its final section.
- 2026-10-04 Edge cases / failure handling: Q How does I41 tell "SIGINT
  ignored by the environment" apart from "the script's INT handling is
  broken"? → A (self-resolved): with a direct probe, `bash -c 'kill -INT
  $$'` (rc 0 means ignored, 130 means live), run before the INT case. Only
  an ignored disposition SKIPs. A foreground run must still print `ok
  (I41) INT exits 130` and zero SKIP lines, and the trap-removal mutant
  must still FAIL I41 INT in the foreground.
- 2026-10-04 Edge cases / failure handling: Q What should
  `tmux_retry_summary` print when `mktemp` fails? → A (self-resolved): a
  single stdout line `failed: could not create a temp file under
  <SCRATCH>; nothing summarized`, then return 1. `main` stores the line in
  `TMUX_RETRY`, so the record shows it, and it never prints `ran: 0`.
- 2026-10-04 Terminology consistency: Q How should "closed" and "pinned"
  be reconciled in the frozen family table entry? → A (self-resolved):
  outside the table the entry claims only *pinned* spellings blocked
  (FP-ext-1 and the qp-1 rows). "Closed by qp-1" becomes "Since qp-1",
  and residual R-QP-a/b stay named.
- 2026-10-04 Terminology consistency: Q After FAIL #1, may the entry list
  the pinned spellings outside the table as a closed list? → A
  (self-resolved): no. The suite pins many blocked rows outside `fg_rows`
  (Q17-Q20, FN2-FN5, FP-ext-1, FP-nc-1, FP-br-1, QP, QPF, OB). The entry
  states the rule ("claimed blocked only where a suite row pins it") and
  gives examples after "such as", naming FP-ext-1, FP-nc-1, Q20 and the
  qp-1 rows. The check fails on any "only ...:" list in the four entries.
- 2026-10-04 Terminology consistency: Q Should the second-shell wording
  keep "at a word start or after a `/`" and "a quoted glob names nothing
  unless its quoted string is a second shell's payload"? → A
  (self-resolved): no, both are narrower than the gate. Measured
  2026-10-04 against `hooks/scripts/human-decision-gate.sh` at HEAD,
  commands fed from a scratch file, each but the `=` case with a trailing
  `> /tmp/zz-out` so the benign-command check cannot allow it. A shell name after `=`,
  `$`, `/` or a closing quote is matched (rc 2), and after a letter it is
  not (rc 0). `echo sh -c` before a quoted glob arms the gate (rc 2)
  although no second shell runs, and the same command without `sh -c` is
  allowed (rc 0). The regex boundary is `(^|[^[:alnum:]_.-])`. Both
  widenings can only over-block. The wording now says that.

## Assumptions

- A1. The `antislop:ubiquitous-language` prose check (CONTEXT.md and the
  draft) found no domain-glossary drift. The vocabulary here is harness
  vocabulary, which belongs to `docs/harness-glossary.md`. "second shell"
  is used without an entry of its own, as qp-2 left it. Lens 3 suggests it
  as an optional later entry for `scribe` (if present). It is not needed
  here.
- A2. The Claude Code Bash tool's foreground context does not ignore
  SIGINT. Measured: the I41 INT case passes there.

## Risks / dependencies

- R1. **human-decision-gate.sh false positive on authoring.** rnc-1's new
  text names both trigger tokens (the trigger token entry). The spec
  session's scratch dry run of these edits was a Bash heredoc, and the gate
  **blocked** it (2026-10-04). It was not rephrased. So the edits' exact
  satisfiability against the check script was not dry-run proven. Line
  widths were counted by hand (the longest new body line is 74 columns).
  The implementer uses the **Edit tool** on `docs/harness-glossary.md`, as
  esc-fu-2 and qp-2 did. If any tool call is blocked, stop and report. Do
  not reword to get past the gate.
- R2. `tests/validate.sh` takes over 600 s. Run it foreground in a clean
  `/tmp` worktree as `timeout 580 bash tests/validate.sh`. If it returns
  124, run prologue lines 1-9 plus `sed -n '<last == header line - 1>,$p'`
  as a tail script **inside the worktree's `tests/`** (validate.sh `cd`s to
  `$(dirname "$0")/..`). Coverage = zero `FAIL` lines in part 1 up to that
  header, plus tail rc 0 (qp-1 precedent, lead-programmer memory
  `technique_validate_exceeds_600s_poll_task_output.md`). Never run it as a
  background job.
- R3. Item 11's acceptance criterion runs the suite under `& wait` on
  purpose. That is a synchronous foreground Bash call reproducing the
  background condition. It is not the banned backgrounded validate.sh.
- R4. rnc-2 keeps the literal `mktemp "$SCRATCH/tmux-retry.XXXXXX"` exactly
  once, and `f="$(pane_fence "$RAW/teammate-tmux.txt")"` exactly once. The
  I42 mutrun 40 and 39 depend on them (`assert count==1`).
- R5. The two units are independent. They can run in either order, each in
  its own commit or commits.
- R6. (FAIL #1 on rnc-1.) Glossary prose that enumerates what is blocked
  goes stale as soon as the suite grows a row. The amended edits state a
  rule plus "such as" examples, and the check fails on any "only ...:"
  form in the four entries. It also checks that every Q, FN or FP row id
  the frozen family table and expansion-named token entries name is
  pinned `blocked` in `tests/human-decision-gate.test.sh`. Unlike R1, the
  amended edits were dry-run proven in a scratch copy (criterion 1). The
  replacement texts were applied by a Python file written with the Write
  tool, never by Bash text naming both trigger tokens.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every item was verified at
  d7c4242. Both failure modes of item 10/11 were reproduced. rnc-1's
  amended check script fails 24 checks at the base and 15 at `09eb34d`
  (the FAIL #1 commit), and passes on the amended text (non-vacuous). Each
  rnc-2 behaviour change has a revert or mutant criterion.
- P2 "Prefer deterministic scripts": satisfied. No script-driven file
  (`fileHashes`, `--wire-*`) is touched.
- P3 "Version-stamp discipline": satisfied (not triggered). No
  `agents/*.md` or `templates/*` change, per version-stamp-check.sh's own
  scope (Context).
- P5 "`tests/validate.sh` is the merge gate": satisfied. Each unit's
  criteria include a full validate.sh run, using the R2 split if needed.

## Steps (dispatch contracts)

### Unit: rnc-1
Suggested model: opus (was sonnet). Depends on: none.
The next dispatch is a lead-programmer fix after FAIL #1 on rnc-1 (commit
`09eb34d`, `.claude/reviewed/rnc-1.fail`). Under the Implementer-tier
ratchet a sonnet unit with a FAIL on record escalates to opus, so the fix
is tagged `model: opus`. The fix applies "Fix after FAIL #1" (below) to
HEAD. It does not redo edits A to E from `d7c4242`.

## Objective
Make four `docs/harness-glossary.md` entries accurate to qp-1, and rewrap
them to 78 columns: frozen family table, accepted over-block (OB row),
expansion-named token, trigger token. Docs only.

## Retrieval
This plan (Context rows 4, 5, 6, 6b; R1). File: `docs/harness-glossary.md`
`:2311-2351`, `:2353-2366`, `:2382-2396`, `:2398-2410` at d7c4242. Rule
source: `hooks/scripts/human-decision-gate.sh:451-480`; pins in
`tests/human-decision-gate.test.sh:1051-1077`.

## Affected files
- `docs/harness-glossary.md` (those four entries only)

## Ordered edits
Use the Edit tool. Each `old` occurs exactly once.

A. Frozen family table (item 4). Replace
```
  did). A spelling outside the table is not claimed closed, and the
  reviewer did not independently probe beyond it. **Declared residuals**,
```
with (amended after FAIL #1; the first version was a false closed list)
```
  did). Outside the table, a spelling is claimed blocked only where a
  suite row pins it, such as FP-ext-1, FP-nc-1, Q20 and the qp-1 rows
  below; that list is not exhaustive. No unpinned spelling outside the
  table is claimed closed, and the esc-left-3 reviewer did not probe
  beyond it.
  **Declared residuals**,
```

B. Frozen family table (item 6). Replace
```
  breaks the gate's path recognizers. Closed by qp-1: a glob inside a quoted
  string handed to a second shell (`sh`, `bash` or `dash` with a `-c`
  option) now counts as a pattern, so the gate reads that payload with
  its quotes removed.
```
with (amended after FAIL #1; the first version described the name
boundary as "a word start or after a `/`", narrower than the regex)
```
  breaks the gate's path recognizers. Since qp-1, a glob inside a quoted
  string handed to a second shell counts as a pattern, so the gate reads
  that payload with its quotes removed. The rule reads the command text
  alone. It recognises a second shell as an unquoted `sh`, `bash` or
  `dash` name whose preceding character, if any, is not a letter, digit,
  `_`, `.` or `-` (so a blank, `/`, `=`, `$` or a quote qualifies), then
  any option words that start with `-` or `+`, the last a short-option
  cluster holding `c` (`-c`, `-ec`); the next word is the payload. It
  matches case-insensitively, and it also matches a name that is only an
  argument, as in `echo sh -c` before a quoted glob; both can only
  over-block.
```

C. Accepted over-block (OB row), rewrap only. Replace
```
  payload whose scratch path can name both tokens. The cap was 25 new denials outside the table. It is the
  per-command form of [[accepted over-block]]; narrowing it is a later
  unit's choice, not a defect.
```
with
```
  payload whose scratch path can name both tokens. The cap was 25 new
  denials outside the table. It is the per-command form of
  [[accepted over-block]]; narrowing it is a later unit's choice, not a
  defect.
```

D. Expansion-named token (item 6b). Replace
```
  word that could expand to it, such as
```
with
```
  word that could expand to it, or, since qp-1, a glob in a quoted string
  handed to a second shell (see [[frozen family table]]), such as
```
and replace
```
  marker-write recognizer may allow it. When the command lexes, a quoted glob is literal and names
  nothing. Coverage is claimed only for the [[frozen family table]]; the
  gate also reads extglob words, pinned by FP-ext-1 rather than by a table
  row.
```
with (amended after FAIL #1; the first version kept a table-only coverage
claim and said a quoted glob names tokens only as a second shell's payload)
```
  marker-write recognizer may allow it. When the command lexes, a quoted
  glob names nothing unless it is in the word that follows text the
  second-shell rule recognises (see [[frozen family table]]). That rule
  reads the text alone, so `echo sh -c` before a quoted glob names its
  tokens too, although no second shell runs. Coverage is claimed for the
  [[frozen family table]], the qp-1 rows and other rows pinned outside
  the table, such as FP-ext-1 (extglob words) and FP-nc-1 (a lowercase
  glob under nocaseglob); no unpinned spelling is claimed.
```

E. Trigger token (item 6b plus wrap). Keep the `**trigger token**:` line and
the provenance line `(units hdg-lexer-1, ...) — one of two strings`
unchanged. Replace the body that follows with
```
  whose co-occurrence arms [[The human-decision gate]] and (in asymmetric
  form) other text-protection gates. In `human-decision-gate.sh`, the two
  triggers are `human-review` and `DECISION`. A token counts as present
  when the quote-joined text contains it as a substring, or when it is an
  [[expansion-named token]] (since esc-left-3; since qp-1 that includes a
  glob in a quoted string handed to a second shell). The gate exits early,
  allowing the command, unless both tokens are present in one of those
  forms. This "both tokens must appear" rule is the gate's early exit (a
  fast check before deeper gate logic). See [[narrate-versus-target
  distinction]] for when a command carrying both tokens is allowed anyway
  (when they are inert to execution).
```

Commit: `docs(rnc-1): glossary entries agree with qp-1, closed vs pinned,
78-column wrap`.

### Fix after FAIL #1 (lead-programmer, model: opus)
Edits A to E landed in `09eb34d`. The fix makes three Edit-tool
replacements in `docs/harness-glossary.md` at HEAD. Each `old` is the
`09eb34d` text and occurs exactly once. Each `new` is the amended text
from edit A, B or D above. Use the Edit tool only; do not write the
glossary through Bash (R1).

F1 (frozen family table, edit A). Replace
```
  did). Outside the table, the only spellings claimed blocked are pinned
  ones: FP-ext-1 and the qp-1 rows below. No other spelling outside it is
  claimed closed, and the esc-left-3 reviewer did not probe beyond it.
  **Declared residuals**,
```
with edit A's amended block.

F2 (frozen family table, edit B). Replace
```
  that payload with its quotes removed. The rule recognises a second
  shell as an unquoted `sh`, `bash` or `dash` name at a word start or
  after a `/`, then any option words that start with `-` or `+`, the last
  a short-option cluster holding `c` (`-c`, `-ec`); it matches
  case-insensitively, an over-block only, and the next word is the
  payload. QP-1
```
with edit B's amended block from its third line ("that payload with its
quotes removed. The rule reads the command text") to its end, followed by
` QP-1` on the same last line, so the line reads `  over-block. QP-1`.

F3 (expansion-named token, edit D). Replace
```
  marker-write recognizer may allow it. When the command lexes, a quoted
  glob names nothing unless its quoted string is a second shell's
  payload. Coverage is claimed only for the [[frozen family table]]; the
  gate also reads extglob words, pinned by FP-ext-1 rather than by a table
  row.
```
with edit D's amended second block.

Edits C and E are unchanged and are not redone. Commit:
`docs(rnc-1): fix FAIL #1, pinned list is open-ended, second-shell rule
as the gate reads it`. Then run all four acceptance criteria. The plan
amendment commit sits between `09eb34d` and the fix, so criterion 3 counts
only the unit's own `docs(rnc-1)` commits.

## Do NOT touch
`hooks/`, `.claude/hooks/`, `tests/`, `scripts/`, `agents/`, `templates/`,
`CONTEXT.md`, any other glossary entry, `CHANGELOG.md`, version files.

## Acceptance criteria
Run in a clean worktree at the unit's final commit
(`git worktree add --detach /tmp/rnc-1-ac <sha>`; `cd /tmp/rnc-1-ac`).
`$S` is a scratch dir.

1. Save this script as `$S/rnc1-check.py` (amended after FAIL #1), then
   `python3 $S/rnc1-check.py docs/harness-glossary.md d7c4242; echo rc=$?`
   gives **rc=0** and zero `FAIL` lines. Run it from the worktree root: it
   reads `tests/human-decision-gate.test.sh` to confirm that each Q, FN or
   FP row id the frozen family table and expansion-named token entries
   name is pinned `blocked`. It also fails on any "only ...:" list in the
   four entries, the FAIL #1 shape. **Revert proofs** (measured
   2026-10-04): `git show d7c4242:docs/harness-glossary.md > $S/base.md &&
   python3 $S/rnc1-check.py $S/base.md d7c4242` gives **rc=1** with 24
   `FAIL` lines. `git show 09eb34d:docs/harness-glossary.md > $S/at09.md
   && python3 $S/rnc1-check.py $S/at09.md d7c4242` gives **rc=1** with 15
   `FAIL` lines, the first being `FAIL frozen family table: no closed
   "only ...:" list`. The amended texts F1-F3, applied to `$S/at09.md` in
   a scratch copy, give **rc=0** with 50 `ok` lines and no `FAIL`.
   ```python
   import re, subprocess, sys
   path, base = sys.argv[1], sys.argv[2]
   NAMES = ['frozen family table', 'accepted over-block (OB row)',
            'expansion-named token', 'trigger token']
   def entries(lines):
       out = {}
       for i, l in enumerate(lines):
           for n in NAMES:
               if l.startswith('**' + n + '**:'):
                   j = i
                   while j < len(lines) and lines[j].strip() != '':
                       j += 1
                   out[n] = (i, j)
       return out
   def rest(lines):
       e = entries(lines); skip = set()
       for i, j in e.values():
           skip.update(range(i, j))
       return [l for k, l in enumerate(lines) if k not in skip], e
   new = open(path, encoding='utf-8').read().split('\n')
   old = subprocess.run(['git', 'show', base + ':docs/harness-glossary.md'],
                        capture_output=True, text=True, check=True).stdout.split('\n')
   suite = open('tests/human-decision-gate.test.sh', encoding='utf-8').read()
   fails = []
   def chk(cond, msg):
       print(('ok   ' if cond else 'FAIL ') + msg)
       if not cond: fails.append(msg)
   rn, en = rest(new); ro, _ = rest(old)
   chk(len(en) == 4, 'all four entries found')
   chk(rn == ro, 'nothing outside the four entries changed')
   T = {}
   for n, (i, j) in en.items():
       T[n] = re.sub(r'\s+', ' ', ' '.join(new[i:j]))
       longl = [i + 1 + k for k, x in enumerate(new[i:j]) if k >= 2 and len(x) > 78]
       chk(not longl, f'{n}: no body line over 78 columns {longl}')
   F, O, X, G = (T.get(n, '') for n in NAMES)
   # closed-list form: "only ... :" inside one sentence, in any of the four
   for n, t in T.items():
       hits = re.findall(r'\bonly\b[^.:;]*:', t)
       chk(not hits, f'{n}: no closed "only ...:" list {hits}')
   chk('not claimed closed' not in F, 'F: old "not claimed closed" sentence gone')
   chk('Closed by qp-1' not in F, 'F: "Closed by qp-1" gone')
   m = re.search(r'Outside the table, a spelling is claimed blocked only where a '
                 r'suite row pins it, such as ([^.;]*)', F)
   chk(m is not None, 'F: open-ended pinned-only claim present ("such as")')
   lst = m.group(1) if m else ''
   for s in ['FP-ext-1', 'FP-nc-1', 'Q20', 'qp-1 rows']:
       chk(s in lst, f'F: pinned example list names {s}')
   # every row id the four entries name outside the FG/OB/QP families is pinned blocked
   ids = set(re.findall(r'\b(Q\d+|FP-[a-z]+-\d+|FN\d+)\b', F + ' ' + X))
   for rid in sorted(ids):
       pinned = re.search(r'bash_case "' + re.escape(rid) + r' [^"]*"\s*(\\\s*)?blocked', suite)
       chk(pinned is not None, f'named row {rid} is pinned blocked in the suite')
   chk('with a `-c` option' not in F, 'F: narrow "-c option" wording gone')
   chk('at a word start or after a `/`' not in F, 'F: narrow boundary wording gone')
   for s in ['`-ec`', '`+`', 'case-insensitiv', 'not a letter, digit', '`=`',
             'echo sh -c', 'over-block']:
       chk(s in F, f'F: recognition wording names {s}')
   chk('a quoted glob is literal and names nothing' not in X, 'X: false "names nothing" sentence gone')
   chk("its quoted string is a second shell's payload" not in X, 'X: inexact payload claim gone')
   chk('echo sh -c' in X, 'X: names the argument-position match')
   chk('second shell' in X, 'X: expansion-named token covers the second-shell payload')
   chk('Coverage is claimed only for the [[frozen family table]];' not in X, 'X: coverage no longer table-only')
   for s in ['qp-1 rows', 'FP-ext-1', 'FP-nc-1', 'such as']:
       chk(s in X, f'X: coverage sentence names {s}')
   chk('second shell' in G, 'G: trigger token covers the second-shell payload')
   for s in ['QP-1', 'QP-2', 'QP-3', 'QPF-1 to QPF-8', 'R-QP-a', 'R-QP-b', 'FP-ext-1']:
       chk(s in F, f'F: still names {s}')
   chk(F.count('TRACKED-OPEN') == 1, 'F: TRACKED-OPEN exactly once')
   for s in ['OB-1 to OB-14', 'OB-14', 'The cap was 25']:
       chk(s in O, f'O: still names {s}')
   sys.exit(1 if fails else 0)
   ```
2. `node tests/context-glossary-links.test.js && node
   tests/protocol-doc-drift.test.js; echo rc=$?` gives rc=0.
3. `git log --format= --name-only --grep='^docs(rnc-1)' 218b7d2..HEAD |
   sort -u | grep -v '^$'` prints exactly `docs/harness-glossary.md`
   (`218b7d2` is the parent of the unit's first commit, `09eb34d`). The
   grep keeps the plan amendment commit, a `docs(plans)` commit, out of
   the count.
4. `bash tests/validate.sh` passes in that worktree, foreground, using R2's
   split if `timeout 580` returns 124. Zero `FAIL` lines across all parts,
   and the tail rc is 0.

## Pre-resolved context
- Measured at d7c4242: the four entries start at lines 2311, 2353, 2382 and
  2398. Their long body lines are listed in Context row 5.
- The edit texts are the spec's own. Width was hand-counted at 74 columns
  or less. The script-based dry run was blocked by human-decision-gate (R1).
- FAIL #1 fix: F1-F3, applied to `git show 09eb34d:docs/harness-glossary.md`
  in a scratch copy, make the amended check pass (rc 0, 50 `ok`, widths
  included). That was dry-run proven by Python files written with the
  Write tool (R6). The F1-F3 `old` blocks each occur once at `09eb34d`.
- Gate facts behind F2/F3 (measured 2026-10-04, Clarifications): the
  name boundary is `(^|[^[:alnum:]_.-])`, and `echo sh -c` before a
  quoted glob with an output redirect is denied (rc 2).
- No test greps these sentences (Blast radius).

## Escalation
If an `old` block is not found exactly once, or check 1 still FAILs after
the edits as written, stop and report the failing line. Do not invent new
wording. If any tool call is refused by a hook, stop and report (R1).

### Unit: rnc-2
Suggested model: sonnet. Depends on: none.

## Objective
Fix two latent probe-script defects (items 7, 8) and three suite defects
(items 9, 10, 11) in `scripts/probe-hook-identity.sh` and
`tests/probe-hook-identity.test.sh`, with a revert or mutant proof for each
behaviour change. Do not change classification logic (item 13 is out).

## Retrieval
This plan (Context rows 7-11, Clarifications, R2-R4).
`scripts/probe-hook-identity.sh:118-131,238`;
`tests/probe-hook-identity.test.sh:231-337` (I32-I42, `mutrun`).

## Affected files
- `scripts/probe-hook-identity.sh`
- `tests/probe-hook-identity.test.sh`

## Ordered edits
1. Script, item 7. In `tmux_retry_summary`, make the `mktemp` statement read
   exactly
   `f="$(mktemp "$SCRATCH/tmux-retry.XXXXXX")" || { echo "failed: could not create a temp file under $SCRATCH; nothing summarized"; return 1; }`
   and move the `jq -c 'select(.run=="run2-tmux")' ...; n=...` that followed
   it on the same line to the next line, unchanged.
2. Script, item 8. In `write_record`'s pane branch, between
   `cat "$RAW/teammate-tmux.txt";` and `printf '%s\n' "$f";`, insert
   exactly `[ -z "$(tail -c 1 "$RAW/teammate-tmux.txt")" ] || echo; `.
3. Suite, item 7: add **I43**, placed after I40. Call `tmux_retry_summary`
   on any capture with `SCRATCH` pointing at a non-existent dir, inside a
   command substitution so `SCRATCH` does not leak. Assert rc 1 and that
   the output equals `failed: could not create a temp file under
   <that dir>; nothing summarized`. Every check prints `ok   (I43) ...` or
   `FAIL (I43) ...` through the suite's `ok`/`bad`/`eq`, in the parent
   shell so `fails` counts.
4. Suite, items 8 and 9: replace the I39 block (`:279-288`) with a helper
   `fence_case <id> <expected-fence-length> <pane-printf-format>`. It
   writes the pane, runs `write_record`, and asserts three things: (a) the
   line two after `### tmux retry pane` is exactly N backticks; (b) the
   record's last line equals that fence; (c) no line strictly between the
   two fences consists only of N or more backticks. N comes from the
   argument and is never a hard-coded regex. Cases, each with `ok` or `FAIL`
   lines tagged with its id:
   - `I39`, N=5, pane `a\n```\nb\n````\nc\n` (the current pane);
   - `I39c`, N=8, pane `x\n```````\ny\n` (a 7-backtick run);
   - `I39b`, N=3, pane `a\nlast-no-newline` (no trailing newline). It
     additionally asserts that the line before the record's last line is
     exactly `last-no-newline`.
   Remove `rm -f "$RAW/teammate-tmux.txt"` after the cases, as now. The
   literal `{5,}` must not remain in the file.
5. Suite, item 10: in `int41`, make the wait read `wait "$pid" 2>/dev/null;
   rc=$?`. Measured: this silences bash's `[1]+ Interrupt` and `Terminated`
   lines and keeps rc 130/143.
6. Suite, item 11: add a one-line helper
   `sigint_ignored() { bash -c 'kill -INT $$' 2>/dev/null; [ "$?" -eq 0 ]; }`
   (exactly one line, starting `sigint_ignored() {`). Replace `int41 INT
   130` with: if `sigint_ignored`, print exactly `SKIP (I41) INT: SIGINT
   is ignored in this shell (started as a background job); run the suite
   in the foreground to check it` and do not run the INT case. Otherwise
   run `int41 INT 130` as now. `int41 TERM 143` is unchanged and always
   runs. SKIP does not touch `fails`.

Commit: `fix(rnc-2): probe reports mktemp failure and closes the pane fence;
suite fence length, job-control noise, SIGINT skip under a background job`.
One commit, or one per file. No version bump (P3 not triggered).

## Do NOT touch
Classification functions (`teammate_choose`, `teammate_check`,
`looks_like_subagent`, `attributable`, `outcome`, `separable`, `rf`),
`method_text`, `main`. Also `tests/validate.sh`, `hooks/`, `docs/`,
`agents/`, `templates/`, version files, `CHANGELOG.md`.

## Acceptance criteria
Run in a clean worktree at the unit's final commit (`/tmp/rnc-2-ac`).
`$S` is a scratch dir outside it. Everything runs in the foreground Bash
call. The `& wait` in 3 is deliberate (R3).

1. `bash -n scripts/probe-hook-identity.sh && bash -n
   tests/probe-hook-identity.test.sh; echo rc=$?` gives rc=0.
   `grep -cF '{5,}' tests/probe-hook-identity.test.sh` gives 0. `grep -cF
   'mktemp "$SCRATCH/tmux-retry.XXXXXX"' scripts/probe-hook-identity.sh`
   gives 1.
2. Foreground: `bash tests/probe-hook-identity.test.sh > $S/fg.out 2>
   $S/fg.err; echo rc=$?` gives **rc=0**. Then:
   - `grep -c '^FAIL' $S/fg.out` = 0; `grep -c '^SKIP' $S/fg.out` = 0;
   - `grep -cF 'ok   (I41) INT exits 130' $S/fg.out` = 1 and `grep -cF 'ok
     (I41) TERM exits 143' $S/fg.out` = 1;
   - each of `grep -cE '^ok +\(I39\)'`, `'^ok +\(I39b\)'`,
     `'^ok +\(I39c\)'` and `'^ok +\(I43\)'` on `$S/fg.out` is ≥ 1;
   - `cat $S/fg.out $S/fg.err | grep -cE
     '^\[[0-9]+\][+-]? +(Terminated|Interrupt)'` = 0. **Revert proof:** the
     same at d7c4242 gives 2 (measured).
3. Background condition: `bash -c 'bash tests/probe-hook-identity.test.sh >
   "$1/bg.out" 2>&1 & wait $!; echo rc=$?' _ $S` gives **rc=0** (d7c4242:
   rc=1, measured). Then `grep -c '^SKIP (I41) INT' $S/bg.out` = 1,
   `grep -cF 'ok   (I41) TERM exits 143' $S/bg.out` = 1, and `grep -c
   '^FAIL' $S/bg.out` = 0.
4. Script mutants. Each is an exact-once replace in a copy, and the suite
   runs against it in the foreground:
   ```bash
   mut() { mkdir -p "$S/m$1/scripts"
     python3 - scripts/probe-hook-identity.sh "$S/m$1/scripts/p.sh" "$2" "$3" <<'PY'
   import sys
   s=open(sys.argv[1]).read(); assert s.count(sys.argv[3])==1, 'not exactly once'
   open(sys.argv[2],'w').write(s.replace(sys.argv[3],sys.argv[4]))
   PY
     PROBE_MUTANT=1 PROBE_UNDER_TEST="$S/m$1/scripts/p.sh" bash tests/probe-hook-identity.test.sh 2>&1; }
   ```
   - M7: `mut 7 ' || { echo "failed: could not create a temp file under $SCRATCH; nothing summarized"; return 1; }' '' | grep -c 'FAIL (I43)'` ≥ 1.
   - M8: `mut 8 '[ -z "$(tail -c 1 "$RAW/teammate-tmux.txt")" ] || echo; ' '' | grep -c 'FAIL (I39b)'` ≥ 1.
   - M9: the output of `mut 9 'END { print m + 1 }' 'END { print m }'` has
     `grep -c 'FAIL (I39)'` ≥ 1 and `grep -c 'FAIL (I39c)'` ≥ 1.
   - MT (the foreground INT check is not weakened): `mut T 'trap cleanup
     EXIT' 'trap - EXIT' | grep -c 'FAIL (I41) INT'` ≥ 1.
5. Suite mutants for item 11. The copies live in the worktree's `tests/`,
   because the suite `cd`s to its own parent:
   ```bash
   tmut() { python3 - tests/probe-hook-identity.test.sh "tests/_rnc2_mut_$1.test.sh" "$2" <<'PY'
   import re,sys
   s=open(sys.argv[1]).read()
   s2,n=re.subn(r'^sigint_ignored\(\) \{.*$', 'sigint_ignored() { %s; }' % sys.argv[3], s, flags=re.M)
   assert n==1, n
   open(sys.argv[2],'w').write(s2)
   PY
   }
   tmut A false; tmut B true
   ```
   - M11a (without the skip, the background run fails): `bash -c
     'PROBE_MUTANT=1 bash tests/_rnc2_mut_A.test.sh > "$1/mA.out" 2>&1 &
     wait $!' _ $S; grep -cF 'FAIL (I41) INT exits 130' $S/mA.out` ≥ 1.
   - M11b (a forced skip is caught by criterion 2): `PROBE_MUTANT=1 bash
     tests/_rnc2_mut_B.test.sh > $S/mB.out 2>&1; grep -c '^SKIP (I41) INT'
     $S/mB.out` = 1 and `grep -cF 'ok   (I41) INT exits 130' $S/mB.out` = 0.
   - Then `rm -f tests/_rnc2_mut_*.test.sh; git status --porcelain` prints
     nothing.
6. `git diff --name-only <unit-base>..HEAD` prints exactly the two Affected
   files.
7. `bash tests/validate.sh` passes in the worktree, foreground, with R2's
   split if needed. Zero `FAIL` lines across all parts, and the tail rc is
   0.

## Pre-resolved context
- Measured at d7c4242: foreground suite rc 0, 95 `ok` lines, 2 job-control
  lines on stderr. Background suite rc 1 with only I41 INT failing (`got
  [3]`). `bash -c 'kill -INT $$'` rc is 130 in the foreground and 0 under
  `& wait`. `wait "$pid" 2>/dev/null` silences the notice and keeps rc
  130/143.
- `tmux_retry_summary` is unreachable with a missing SCRATCH from `main`
  (`setup` creates it). The fix only makes a standalone call loud.
- In-suite mutants (I37, I42) are left as they are. New proofs are
  criteria-only (Clarifications, NFR).

## Escalation
If MT does not FAIL I41 INT, stop and report. The premise that I41 INT
guards the EXIT trap would then be wrong, and that is a spec defect. Do the
same if any exact-once mutant literal is not found once. Never edit the
classification functions to make a criterion pass.

## Out of scope

- Item 13 (false C from teammate-lead selection): Open Question 1.
- Items 1, 2, 3, 12 and 5b: dropped (Context table).
- Any `human-decision-gate.sh` predicate change. Bypass hunting (operator
  step O2: the qp-1 notes about quoted c-clusters and backslash/ANSI-C
  payloads). `hooks/scripts/lib`. reviewed-path-gate F-1. The
  teammate-premise measurement, including esf-eid-probe's user-settings env
  note. CONTEXT.md. The item05-3 untagged glossary notes.
- The gate's own header comment (`hooks/scripts/human-decision-gate.sh`,
  above `glob_scan_shell_payloads()`) still says "at a word start or after
  a `/`", the boundary wording F2 corrects in the glossary. It is a code
  comment under `hooks/`, which rnc-1 may not touch. It is a later
  cleanup note, not part of this fix.
- Making `tests/validate.sh` faster or splitting it permanently.

## Open Questions

1. Item 13: should a later spec fix the false C in `teammate_choose`
   (`scripts/probe-hook-identity.sh:107-116`), which takes the first
   `echo probe-main` line of a run as the lead without checking it?
   **Recommended default: defer to its own spec (opus, after the teammate
   premise is measured), not in this bundle.** Options:
   - (a) defer, the default;
   - (b) add only a Method "honest limit" sentence now;
   - (c) withhold, judging the candidate `no-lead`, when a run's probe-main
     lines span more than one session, plus the Method sentence and a test;
   - (d) require the lead line's `agent_id` to be null. The reviewer's repro
     allows a null-agent_id third session, so (d) alone does not close it.
   Choosing (b) or (c) adds a third unit, and leaves rnc-1 and rnc-2
   unchanged.

## Self-check
- CHK1: Is each of the 13 candidate items given an in, drop or out verdict
  with evidence? — PASS
- CHK2: Do rnc-1 and rnc-2 have disjoint Affected files? — PASS
- CHK3: Does each rnc-2 behaviour change have a revert or mutant criterion
  (items 7 M7, 8 M8, 9 M9 plus I39c, 10 revert count 2, 11 M11a/M11b/MT)? —
  PASS
- CHK4: Is "without weakening the foreground check" machine-checkable? —
  FAIL (ambiguous) — revised in place. Added criterion 2's `ok (I41) INT
  exits 130` = 1 and SKIP = 0, plus M11b and MT.
- CHK5: Do edit B's wording and the rnc-1 check agree on the required
  substrings (`-ec`, `+`, case-insensitiv, not a letter, digit, `=`,
  echo sh -c, the open-ended pinned claim)? — PASS (re-checked after the
  FAIL #1 amendment; the amended texts pass the amended script)
- CHK6: Is the P3 verdict grounded in version-stamp-check.sh's scope, not
  assumed? — PASS
- CHK7: Does the plan say how to run validate.sh within 600 s without
  backgrounding? — PASS (R2)
- CHK8: Is item 13's disposition stated and does it have an Open Question?
  — PASS (Open Question 1)
- CHK9: Does rnc-2 keep the literals the in-suite I42 mutants depend on? —
  FAIL (missing) — revised in place: R4 plus criterion 1's `mktemp` count.
- CHK10: Is rnc-1's check script proven non-vacuous? — PASS. After the
  FAIL #1 amendment: rc 1 with 24 FAILs at the base, rc 1 with 15 at
  `09eb34d`, rc 0 on the amended text. Satisfiability is now dry-run
  proven (R6), not only hand-checked.
- CHK11 (ubiquitous-language, advisory): any drift between the plan and
  the glossary? — PASS. No CONTEXT.md term is used with a new meaning.
  "second shell" stays without an entry (A1).
- CHK12 (FAIL #1): Does any of rnc-1's amended entry texts state a closed
  "only ...:" list of blocked spellings? — PASS. Each now states a rule
  plus "such as" examples. Criterion 1 fails on that form, and it does
  fail at `09eb34d`.
- CHK13 (FAIL #1): Is every row id the amended frozen family table and
  expansion-named token entries name pinned `blocked` in the suite? —
  PASS (criterion 1 checks Q20, FP-ext-1 and FP-nc-1 against
  `tests/human-decision-gate.test.sh`).
- CHK14 (FAIL #1): Do edits A, B and D and fixes F1-F3 give the same
  final text? — PASS. Applying the plan's F1-F3 blocks to `09eb34d` was
  checked byte-equal to the dry-run fixed copy.
- CHK15 (FAIL #1): Is the fix's model tag stated with its ratchet
  reason? — PASS (rnc-1 header and "Fix after FAIL #1": opus, a sonnet
  unit with a FAIL on record).

## Scribe update hint

No CONTEXT.md change. rnc-1 is itself the harness-glossary update. After
both units pass, `scribe` (if present) may add a one-line changelog note in
`.claude/wiki/changelog.md`. It may also, optionally, consider a "second
shell" harness-glossary entry (A1).
