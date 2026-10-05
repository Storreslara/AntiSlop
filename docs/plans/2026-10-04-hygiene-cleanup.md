# Test and doc hygiene cleanup after rnc-1, rnc-2, esc-fu-1, esc-chat-7-record (2026-10-04)

Status: FINAL (spec-master, 2026-10-04). Three units, fast path (five or
fewer units): this document holds the dispatch contracts. No task-master
slicing, no tracker issue. Base: HEAD `fcfcc47`. Spec only; nothing here is
implemented.

## Goal

Close seven small hygiene items raised in review notes:

- G1 (hyg-1, item 1). `tests/validate.sh` reports how many `SKIP` lines
  reached its output, and lists them, in an advisory section after the
  run. The count never changes the exit code.
- G2 (hyg-1, item 4). `tests/validate.sh` checks that every residual pin
  the `docs/harness-glossary.md` frozen family table entry names (today
  `pin N21`, `pin R5`) is an `allowed` row in
  `tests/human-decision-gate.test.sh`, and that the entry's claim that NL1
  is "the only `TRACKED-OPEN` pin" matches the suite.
- G3 (hyg-2, item 2). `fence_case` check (c) in
  `tests/probe-hook-identity.test.sh` counts every inner backtick-only
  line of N or more, as its `ok` text says. It stops dropping inner lines
  that equal the fence.
- G4 (hyg-2, item 6). `sigint_ignored()` carries a comment saying it is
  safe only with job control off, and a guard that reports a FAIL instead
  of probing when job control is on.
- G5 (hyg-3, item 3). The frozen family table entry mentions FP-ext-1
  once, not twice.
- G6 (hyg-3, item 5). `docs/harness-glossary.md` has a **second shell**
  entry that states the qp-1 recognition rule as
  `glob_scan_shell_payloads()` implements it. The entry does not say the
  quote-joined text masks a quoted payload: that text only deletes quote
  characters. The frozen family table and expansion-named token entries
  point to the new entry for the rule instead of carrying their own copy.
- G7 (item 7). No change. The four citations were already re-pointed to
  `7e04acd` by commit `9b4afd9` (see Context).

## Context

### Item verification at fcfcc47

| # | Source | Verdict | Evidence |
|---|---|---|---|
| 1 | rnc-2.pass NOTE[code] | **in, hyg-1** | `tests/validate.sh:1152-1153` checks the probe suite's rc only. 81 sub-suite calls; SKIP emitters exist in at least 6 suites plus 4 sites in validate.sh itself (:58, :134, :342, :774). |
| 2 | rnc-2.pass NOTE[spec] | **in, hyg-2 (code fix, not a wording fix)** | `tests/probe-hook-identity.test.sh:287` filters `$0 != f`. Measured 2026-10-04: a scratch mutant of `pane_fence` printing `m` instead of `m + 1`, with the I39 fixture's expected length changed from 5 to 4, gives `ok   (I39) ... no inner run that long` although the pane holds a 4-backtick line equal to the fence. The candidate fix below turns that into `FAIL (I39) ... inner [1]` and leaves the unmutated suite at rc 0, 0 FAIL. |
| 3 | rnc-1.pass NOTE[code] | **in, hyg-3** | `docs/harness-glossary.md:2318-2320` and `:2325-2326` both mention FP-ext-1. |
| 4 | coordinator brief | **in, hyg-1** | rnc-1's check script (plan `docs/plans/2026-10-04-review-note-cleanup.md:438-511`) checks only `Q`, `FN`, `FP` ids for a `blocked` verdict. The entry's `pin N21` and `pin R5` (`:2333`) and its "the only `TRACKED-OPEN` pin" claim (`:2333-2334`) are not checked. Rows exist today: `N21` (:208, allowed), `R5` (:619, allowed), `NL1` (:839, allowed, the only row whose name holds `tracked-open`). The check is made durable in validate.sh, not by amending the PASSed rnc-1 plan script. |
| 5 | coordinator brief, esc-fu-1.pass NOTE[spec], rnc-1.pass NOTE[code] | **in, hyg-3** | Rule source: `hooks/scripts/human-decision-gate.sh:466-480` (regex `(^|[^[:alnum:]_.-])(sh\|bash\|dash)(${s}[-+]${o})*${s}-[[:alpha:]]*c[[:alpha:]]*${s}`, read off the skeleton, under nocasematch). `joined` (`:738-739`) deletes only `'` and `"`. The rule is called only when `command_skeleton()` succeeds (`:438-445`); on lex failure every glob is scanned anyway. |
| 6 | rnc-2.pass NOTE[code] | **in, hyg-2** | `sigint_ignored` at `tests/probe-hook-identity.test.sh:324`; `int41` runs `set -m` ... `set +m` (`:315`, `:319`) before it. |
| 7 | esc-chat-7-record.pass NOTE[spec] x3 | **drop, done in 9b4afd9** | At fcfcc47: `CONTEXT.md:1043` cites `7e04acd` and names 229138e only as superseded; `:1045-1046` give default 2.1.288 and acceptEdits/auto 2.1.289; `:1051-1052` "Not measured: ... teammate identity". ADR-0039 `:121-146` cites 7e04acd, per-mode versions, teammate unmeasured. Glossary `:2064-2068` cites 7e04acd, "never restate it as one version". `docs/trust-model.md:58` cites 7e04acd, 2.1.288 and 2.1.289, "Not measured: ... teammates". `git grep -n "2.1.288 only\|does not capture\|does not document"` over those four files prints nothing. Criterion V7 below lets a reviewer re-confirm. |

### Item 1 decision: count, not fail

Failing on a `SKIP` line would turn the merge gate red on every CI run:
`.github/workflows/validate.yml` installs only jq, so validate.sh's own
claude-CLI section (`:134`) prints `SKIP` on every CI run. Other SKIPs are
legitimate per machine (root, no localedef, Python before 3.11, shallow
history). The vacuous-skip case rnc-2 named (a forced-true
`sigint_ignored`) is caught by making the count visible to the person or
reviewer reading the run, plus each unit's own `SKIP=0` criterion where it
matters. An opt-in strict mode is out of scope.

Mechanism (prototyped in scratch, 2026-10-04): a wrapper block placed after
`fail=0` (line 9) re-runs the script with `ANTISLOP_VALIDATE_INNER=1`,
stdout and stderr teed to a temp file, then prints a `Skipped checks: N`
line and the SKIP lines indented, and exits with the inner rc. The summary
line does not start with `SKIP`, so it never counts itself. Measured with a
truncated copy: 3 SKIP lines (one on stderr, one `OK ... SKIP` line not
counted) give `Skipped checks: 3` and rc 0; an inner `exit 1` gives rc 1;
`timeout 2` gives rc 124 with no surviving inner process and no leftover
temp file. Lines a suite captures and discards (for example `out=$(...)`
patterns) never reach the output and are not counted; the section says so
and claims no more.

R2-split compatibility: the split procedure runs prologue lines 1-9 plus a
tail from a later header. The wrapper sits at lines 10 and later, so neither
part contains it; a split run prints no summary. That is accepted.

### Prior defect history (`.fail` screen)

The whole review-marker directory was listed. Records on these surfaces:
- `rnc-1.fail`: a closed list in glossary prose ("the only spellings
  claimed blocked are ...") that was false, passed by a check that only
  tested phrase presence. Hence R1 below, the "such as" form in the new
  entry, and hyg-3's criterion that fails on any "only ...:" list and
  checks every QP/QPF id it names.
- `qp-1.fail`: a missed character dimension in the second-shell regex.
  The new entry describes the shipped regex's boundary and option-word
  classes, measured in rnc-1's Clarifications and re-read here at
  `:466-469`.
- No `.fail` for rnc-2, esc-fu-1 or esc-chat-7-record. The
  Implementer-tier ratchet does not apply to any unit here.

### Marker-audit `--notes` sweep

`bash bin/marker-audit.sh . --notes --surface=<path>`, run at fcfcc47 for
the three touched files (it finished after the first draft):
`tests/validate.sh` 140 notes (spec 14, code 29, untagged 97);
`tests/probe-hook-identity.test.sh` 6 (spec 1, code 5, untagged 0);
`docs/harness-glossary.md` 58 (spec 31, code 25, untagged 2). Every
untagged line names an older PASSed unit (mw-step3/4/5, spec2-unitD/E,
stop-gate-msg-1, item05-3), not a step awaiting dispatch, so all are out
of scope. The dispositions here rest on the four `.pass` markers read in full
(esc-chat-7-record, esc-fu-1, rnc-1, rnc-2) and rnc-1's own sweep at
d7c4242 (`docs/plans/2026-10-04-review-note-cleanup.md:78-97`). Notes
consumed: rnc-1 NOTE[code] x2 (items 3, 5), rnc-2 NOTE[spec] (item 2),
rnc-2 NOTE[code] x2 (items 1, 6), esc-fu-1 NOTE[spec] (item 5's
mechanism constraint), esc-chat-7-record NOTE[spec] x3 (item 7, already
done). Out of scope: rnc-1 NOTE[spec] (double-quoted command-substitution
glob gap, needs a hooks/ unit), esc-fu-1 NOTE[code] on the gate header and
QP-3 reachability, esc-chat-7-record NOTE[code] x2 (record oddities). The
sweep is best-effort; an absent note is not proof none exists.

### Version stamping (P3)

Not triggered. No unit touches `agents/*.md` or `templates/*`.
`package.json` `files` ships neither `tests/` nor `docs/`. No version
bump, no CHANGELOG entry, no `--update`.

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

- 2026-10-04 Functional scope & success criteria: Q Is item 7 still
  open? → A (self-resolved): no. Commit 9b4afd9 (2026-10-03) re-pointed
  all four citations; verified line by line at fcfcc47 (Context row 7).
  No unit; criterion V7 re-confirms.
- 2026-10-04 Functional scope & success criteria: Q For item 4, amend the
  PASSed rnc-1 plan's check script, or add a durable check? → A
  (self-resolved): a durable section in `tests/validate.sh`. A plan-embedded
  script runs once; the drift the note fears happens later.
- 2026-10-04 Non-functional attributes (perf, security, scale): Q Should
  SKIP lines fail validate.sh? → A (self-resolved): no, count and list
  them (Context "Item 1 decision"). CI would always be red otherwise.
- 2026-10-04 Edge cases / failure handling: Q Item 2, fix the wording or
  the check? → A (self-resolved): the check. The `ok` text "no inner run
  that long" is the intended claim, and a measured mutant shows check (c)
  alone does not enforce it.
- 2026-10-04 Edge cases / failure handling: Q Item 6, comment only or a
  guard? → A (self-resolved): both. The guard reports `FAIL (I44)` and
  returns non-ignored without running the probe when `$-` holds `m`, so a
  later reorder fails visibly instead of aborting the suite.
- 2026-10-04 Technical constraints & tradeoffs: Q Where does the wrapper
  go, given the R2 split uses prologue lines 1-9? → A (self-resolved):
  after line 9, re-invoking `tests/$(basename "$0")` (valid after the
  `cd` at line 8, and lets a truncated copy in `tests/` test itself).
- 2026-10-04 Terminology consistency: Q Should the new **second shell**
  entry be a fourth full copy of the rule? → A (self-resolved): no. The
  rule text moves from the frozen family table entry into the new entry;
  the frozen family table and expansion-named token entries link
  `[[second shell]]`. The gate's header comment stays a separate copy
  (hooks/ is out of bounds).
- 2026-10-04 Terminology consistency: Q May the entry list its pins as a
  closed set? → A (self-resolved): no. It names examples after "such as",
  and hyg-3's check confirms each named id is a `blocked` suite row.

## Assumptions

- A1. `antislop:ubiquitous-language` (prose mode, CONTEXT.md): no domain
  drift. All terms here are harness vocabulary (`docs/harness-glossary.md`).
  Lens 3: "second shell" was a load-bearing term without an entry; hyg-3
  adds it.
- A2. GNU `timeout` signals its whole process group, so the wrapper's inner
  run dies with the outer (measured: no surviving process after
  `timeout 2`).

## Risks / dependencies

- R1. **Closed-list prose (rnc-1 FAIL #1).** No text written here may
  claim a list is complete unless a check pins it. hyg-1's SKIP section says
  captured output is not counted. hyg-1's pin check checks only what the
  entry names, plus the one "only" claim the entry already makes (NL1).
  The new entry names pins after "such as". hyg-3's check fails on any
  `only ...:` form in the three edited entries.
- R2. **human-decision-gate on authoring.** hyg-3's text and hyg-1's
  Python mention suite rows whose names hold both trigger tokens only by
  reading files, but authoring a Bash heredoc that spells both tokens is
  blocked. Use the Edit tool for every edit. If a tool call is refused,
  stop and report; never reword to pass the gate.
- R3. `tests/validate.sh` takes over 600 s. Run it foreground in a clean
  `/tmp` worktree as `timeout 580 bash tests/validate.sh`; on rc 124, use
  rnc-1's R2 split (`docs/plans/2026-10-04-review-note-cleanup.md:202-209`):
  prologue lines 1-9 plus a tail script from the last header reached,
  saved inside the worktree's `tests/`. Zero `FAIL` lines across parts and
  tail rc 0. Never background it.
- R4. Mutation proofs below edit files inside the disposable AC worktree
  only, and restore them (`git checkout -- <file>`); the criterion ends
  with `git status --porcelain` empty apart from untracked scratch copies,
  which are removed.
- R5. Order: hyg-1, hyg-2, hyg-3 are independent (no shared file).
  Recommended order hyg-1 first, so hyg-3's validate run exercises the pin
  check against the edited entry (hyg-3 does not touch the residual
  sentence).
- R6. Do-not-touch files from other specs: `hooks/scripts/human-decision-gate.sh`,
  `tests/human-decision-gate.test.sh`, `scripts/probe-hook-identity.sh`.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Items 2, 4 and 1 were measured
  with scratch mutants/prototypes; item 7 was verified done rather than
  re-edited; every behaviour change has a mutant criterion.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied.
  Item 4 becomes a script check in validate.sh.
- P3 "Version-stamp discipline": satisfied (not triggered); no
  `agents/*.md` or `templates/*` change.
- P5 "`tests/validate.sh` is the merge gate": satisfied. Each unit runs it
  (R3); hyg-1 changes it and keeps its exit code semantics.

## Steps (dispatch contracts)

Shared AC setup for every unit: `git worktree add --detach /tmp/<unit>-ac
<sha>` at the unit's final commit, `cd` there; `$S` is a scratch dir
outside the worktree.

### Unit: hyg-1
Suggested model: tagged by the orchestrator (no `.fail` history). Depends
on: none.

## Objective
Add an advisory SKIP count to `tests/validate.sh` (G1) and a durable check
of the frozen family table's residual pins (G2).

## Retrieval
This plan (Context rows 1 and 4, "Item 1 decision", R1, R3, R4).
`tests/validate.sh` at fcfcc47 (prologue :1-9; final sections :1143-1161).

## Affected files
- `tests/validate.sh`

## Ordered edits
Use the Edit tool.

A. After line 9 (`fail=0`) and before the first `echo "== bash syntax =="`,
insert this block verbatim:
```
# >>> skip-summary wrapper (hyg-1): re-run this script with its output teed to
# a temp file, then count the lines that start with SKIP. Advisory only: the
# count never changes the exit code. Lines a suite captures and discards never
# reach this output and are not counted.
if [ -z "${ANTISLOP_VALIDATE_INNER:-}" ]; then
  skip_log="$(mktemp)" || { echo "FAIL could not create the SKIP-summary temp file"; exit 1; }
  trap 'rm -f "$skip_log"' EXIT
  trap 'exit 143' TERM
  trap 'exit 130' INT
  ANTISLOP_VALIDATE_INNER=1 bash "tests/$(basename "$0")" "$@" 2>&1 | tee "$skip_log"
  inner_rc=${PIPESTATUS[0]}
  echo
  echo "== skipped checks (advisory, never affects the exit code) =="
  echo "Skipped checks: $(grep -c '^SKIP' "$skip_log")"
  grep '^SKIP' "$skip_log" | sed 's/^/     /'
  exit "$inner_rc"
fi
# <<< skip-summary wrapper
```

B. Immediately before the line
`echo "== scripts/probe-bash-ask.sh: offline gate/extraction tests (Bash, esf-probe-tests) =="`
(keep the preceding blank `echo`), insert this section followed by a line
`echo`:
```
echo "== docs/harness-glossary.md: frozen family table residual pins exist (Python, hyg-1) =="
if python3 -c "
import re, sys
g = open('docs/harness-glossary.md', encoding='utf-8').read().split('\n')
suite = open('tests/human-decision-gate.test.sh', encoding='utf-8').read()
i = next((k for k, l in enumerate(g) if l.startswith('**frozen family table**:')), None)
if i is None:
    print('FAIL frozen family table entry not found'); sys.exit(1)
j = i
while j < len(g) and g[j].strip():
    j += 1
t = re.sub(r'\s+', ' ', ' '.join(g[i:j]))
def verdict(rid):
    m = re.search(r'^(?:bash|write)_case \"' + re.escape(rid) + r' [^\"\n]*\" (allowed|blocked)\b', suite, re.M)
    return m.group(1) if m else None
bad = 0
pins = re.findall(r'\bpin ([A-Z][A-Za-z0-9-]*)', t)
for need in ('N21', 'R5'):
    if need not in pins:
        print('FAIL entry no longer names pin ' + need); bad = 1
for rid in pins:
    v = verdict(rid)
    if v == 'allowed':
        print('OK   residual pin ' + rid + ' is an allowed suite row')
    else:
        print('FAIL residual pin ' + rid + ': suite verdict ' + str(v) + ', want allowed'); bad = 1
m = re.search(r'\b([A-Z][A-Za-z0-9-]*) \([^)]*the only \x60TRACKED-OPEN\x60 pin\)', t)
if m:
    rows = re.findall(r'^(?:bash|write)_case \"(\S+) [^\"\n]*tracked-open', suite, re.M | re.I)
    if rows == [m.group(1)] and verdict(m.group(1)) == 'allowed':
        print('OK   ' + m.group(1) + ' is the only tracked-open suite row')
    else:
        print('FAIL only-TRACKED-OPEN claim for ' + m.group(1) + ': tracked-open rows ' + str(rows)); bad = 1
sys.exit(bad)
"; then
  echo "OK   frozen family table residual pins"
else
  echo "FAIL frozen family table residual pins"
  fail=1
fi
```
(The section was prototyped verbatim at fcfcc47: 4 `OK` lines, `fail=0`.)

Commit: `test(hyg-1): validate.sh counts SKIP lines; residual-pin check for the frozen family table`.

## Do NOT touch
Everything except `tests/validate.sh`; in particular R6's files, `hooks/`,
`agents/`, `templates/`, `docs/`.

## Acceptance criteria
1. `bash -n tests/validate.sh; echo rc=$?` gives rc=0, and
   `grep -c '^# >>> skip-summary wrapper' tests/validate.sh` and
   `grep -c '^# <<< skip-summary wrapper' tests/validate.sh` each print 1,
   and `sed -n 1,9p tests/validate.sh` equals `git show
   fcfcc47:tests/validate.sh | sed -n 1,9p` (`diff` rc 0).
2. Wrapper proof (truncated copies inside the worktree's `tests/`). Let
   `W=tests/zz-skipwrap`; `pre() { sed -n '1,/^# <<< skip-summary wrapper/p' tests/validate.sh; }`.
   - `{ pre; printf '%s\n' "printf 'SKIP a\nOK b SKIP\nSKIP (I41) c\n'; echo 'SKIP d' >&2; exit 0"; } > $W-0.sh; mkdir -p $S/t; TMPDIR=$S/t bash $W-0.sh > $S/o0; echo rc=$?`
     gives rc=0; `grep -cx 'Skipped checks: 3' $S/o0` = 1; `grep -c '^     SKIP' $S/o0` = 3.
   - same with body `"printf 'SKIP a\n'; exit 1"` as `$W-1.sh`: rc=1 and
     `Skipped checks: 1` present.
   - same with body `"echo OK; exit 0"` as `$W-2.sh`: rc=0 and
     `Skipped checks: 0` present.
   - same with body `"sleep 30; exit 0"` as `$W-3.sh`:
     `TMPDIR=$S/t timeout 2 bash $W-3.sh; echo rc=$?` gives rc=124; after
     `sleep 3`, `pgrep -fc '^bash tests/zz-skipwrap-3.sh'` prints 0 and
     `ls -A $S/t | wc -l` prints 0.
   - `rm -f $W-*.sh`.
3. Pin-check proof. Extract the section:
   `{ echo fail=0; sed -n '/^echo "== docs\/harness-glossary.md: frozen family table residual pins/,/^fi$/p' tests/validate.sh; echo 'echo "fail=$fail"'; } > $S/pins.sh`.
   `bash $S/pins.sh` (from the worktree root) prints `fail=0`, 0 `FAIL`
   lines, and `OK   residual pin N21`, `OK   residual pin R5`,
   `OK   NL1 is the only tracked-open suite row`. Then each mutant below,
   applied to the worktree copy with an exact-once Python replace and
   restored with `git checkout -- <file>` after, makes `bash $S/pins.sh`
   print `fail=1`:
   - M1 suite: `(documented residual)" allowed` → `(documented residual)" blocked` (the N21 row).
   - M2 suite: `bash_case "R5 ` → `bash_case "R5x `.
   - M3 glossary: `pin R5)` → `pin R6)`.
   - M4 suite: `(branch disagreement, tracked-open)` → `(branch disagreement)`.
   - M5 glossary: the two-line `R-4 (split variable, pin\n  N21)` → `R-4 (split variable)`.
   (All five measured as `fail=1` on the prototype, 2026-10-04.) Finish
   with `git status --porcelain` printing nothing.
4. `git diff --name-only fcfcc47..HEAD -- . ':!docs/plans'` over the
   unit's own commits prints exactly `tests/validate.sh`.
5. `bash tests/validate.sh` passes per R3. If the run is not split, its
   output ends with a `Skipped checks: N` line and rc 0, and N equals
   `grep -c '^     SKIP'` of the same output.

## Pre-resolved context
- Prototype results: Context "Item 1 decision" and item 4 mutants.
- `.claude/persona-config.json` `testAndLintCommand` is `bash
  tests/validate.sh`; rc is preserved, and no hook parses the summary
  text (`git grep "All checks passed"` finds no consumer in hooks/,
  scripts/, bin/).

## Escalation
If an insertion point is not found exactly once, or criterion 3's baseline
is not `fail=0`, stop and report. If a hook refuses a tool call, stop and
report (R2).

### Unit: hyg-2
Suggested model: tagged by the orchestrator (no `.fail` history). Depends
on: none.

## Objective
Make `fence_case` check (c) count inner lines equal to the fence (G3), and
guard `sigint_ignored()` against job control (G4).

## Retrieval
This plan (Context rows 2 and 6). `tests/probe-hook-identity.test.sh`
`:279-290`, `:313-326` at fcfcc47.

## Affected files
- `tests/probe-hook-identity.test.sh`

## Ordered edits
Use the Edit tool. Each `old` occurs exactly once.

A. Replace
```
  inner="$(awk -v f="$fence" '/^### tmux retry pane$/ {s=1; getline; getline; next} s && $0 != f' "$REC" | awk
```
with
```
  inner="$(awk '/^### tmux retry pane$/ {s=1; getline; getline; next} s' "$REC" | sed '$d' | awk
```
(the rest of the line is unchanged). Add, on the line above `inner=`, the
comment `  # (c) every pane line between the fences; only the last line (the closing fence, see (b)) is dropped`.

B. Replace
```
sigint_ignored() { bash -c 'kill -INT $$' 2>/dev/null; [ "$?" -eq 0 ]; }
```
with
```
# sigint_ignored is safe only with job control off: a monitor-mode (set -m)
# shell aborts its command list when a foreground child dies of SIGINT. int41
# turns job control off again before returning; keep this call outside any
# set -m region. The guard fails visibly instead of probing.
sigint_ignored() {
  case $- in *m*) bad "(I44) sigint_ignored called with job control on (set -m); probe not run"; return 1 ;; esac
  bash -c 'kill -INT $$' 2>/dev/null; [ "$?" -eq 0 ]
}
```

Commit: `test(hyg-2): fence check (c) counts lines equal to the fence; sigint_ignored job-control guard`.

## Do NOT touch
Everything except `tests/probe-hook-identity.test.sh`; in particular
`scripts/probe-hook-identity.sh` (R6).

## Acceptance criteria
1. `bash -n tests/probe-hook-identity.test.sh; echo rc=$?` gives rc=0.
2. Foreground: `bash tests/probe-hook-identity.test.sh > $S/fg 2>&1; echo rc=$?`
   gives rc=0, `grep -c '^FAIL' $S/fg` = 0, `grep -c '^SKIP' $S/fg` = 0,
   `grep -c 'ok   (I41) INT exits 130' $S/fg` = 1, `grep -c '(I44)' $S/fg` = 0.
3. Check (c) mutant (measured 2026-10-04: base prints `ok   (I39)`):
   write `$S/p.sh` = `scripts/probe-hook-identity.sh` with `print m + 1`
   → `print m` (exactly once), and `tests/zz-t.sh` = the unit's test file
   with `fence_case I39 5 ` → `fence_case I39 4 ` (exactly once).
   `PROBE_MUTANT=1 PROBE_UNDER_TEST=$S/p.sh bash tests/zz-t.sh 2>&1 | grep '(I39) '`
   prints a line starting `FAIL (I39)` with `inner [1]`. Repeating with
   `git show fcfcc47:tests/probe-hook-identity.test.sh` as the source of
   `tests/zz-t.sh` prints `ok   (I39)` (the old gap). `rm -f tests/zz-t.sh`.
4. Guard mutant: `tests/zz-g.sh` = the unit's test file with
   `if sigint_ignored; then` → `set -m; if sigint_ignored; then` (exactly
   once). `PROBE_MUTANT=1 bash tests/zz-g.sh 2>&1 | grep -c '^FAIL (I44)'`
   prints 1. `rm -f tests/zz-g.sh`.
5. `git status --porcelain` prints nothing; `git diff --name-only
   fcfcc47..HEAD -- . ':!docs/plans'` over the unit's own commits prints
   exactly `tests/probe-hook-identity.test.sh`.
6. `bash tests/validate.sh` passes per R3.

## Pre-resolved context
- The candidate edit A was applied to a scratch copy at fcfcc47: the
  unmutated suite gave rc 0, 0 FAIL, 96 ok with `PROBE_MUTANT=1`; the
  mutant gave `FAIL (I39) fence [````] want [````] last [````] inner [1]`.
- The test `cd`s to `$(dirname "$0")/..`, so scratch copies of the test
  must live in the worktree's `tests/`, as above.
- The real suite's I42 `mutrun 39` (`f="```"`) still fails I39 via check
  (a); criterion 2 covers it.

## Escalation
If an `old` is not found exactly once, or criterion 2 shows any FAIL,
stop and report.

### Unit: hyg-3
Suggested model: tagged by the orchestrator (no `.fail` history on this
unit; rnc-1's FAIL is the reason for R1). Depends on: none (R5 suggests
after hyg-1).

## Objective
Remove the duplicated FP-ext-1 mention (G5); add a **second shell**
entry holding the qp-1 recognition rule, and point the frozen family table
and expansion-named token entries to it (G6).

## Retrieval
This plan (Context rows 3 and 5, R1, R2). `docs/harness-glossary.md`
`:2311-2362` and `:2394-2413` at fcfcc47; rule source
`hooks/scripts/human-decision-gate.sh:438-480`, `:738-748`.

## Affected files
- `docs/harness-glossary.md`

## Ordered edits
Use the Edit tool only (R2). Each `old` occurs exactly once.

A (item 3). Replace
```
  [[family table]] with one rule: it is closed only for what it lists. The
  gate also reads extglob words, pinned by FP-ext-1 rather than by a table
  row.
```
with
```
  [[family table]] with one rule: it is closed only for what it lists.
```

B (item 3). Replace
```
  suite row pins it, such as FP-ext-1, FP-nc-1, Q20 and the qp-1 rows
  below; that list is not exhaustive. No unpinned spelling outside the
  table is claimed closed, and the esc-left-3 reviewer did not probe
  beyond it.
```
with
```
  suite row pins it, such as FP-ext-1 (extglob words), FP-nc-1, Q20 and
  the qp-1 rows below; that list is not exhaustive. No unpinned spelling
  outside the table is claimed closed, and the esc-left-3 reviewer did
  not probe beyond it.
```

C (item 5, move the rule out). Replace
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
  over-block. QP-1 (`bash -c`, writes) and QP-2 (`sh -c` with
```
with
```
  breaks the gate's path recognizers. Since qp-1, a glob inside a quoted
  string handed to a [[second shell]] counts as a pattern (that entry
  gives the rule). QP-1 (`bash -c`, writes) and QP-2 (`sh -c` with
```

D (item 5). In the expansion-named token entry replace
```
  handed to a second shell (see [[frozen family table]]), such as `h*` for
```
with
```
  handed to a [[second shell]], such as `h*` for
```
and replace
```
  second-shell rule recognises (see [[frozen family table]]). That rule
```
with
```
  second-shell rule recognises (see [[second shell]]). That rule
```

E (item 5, new entry). Insert after the expansion-named token entry's last
line (`  glob under nocaseglob); no unpinned spelling is claimed.`) a blank
line and then:
```
**second shell**:
(qp-1, qp-2, 2026-10-04) — a shell that [[The human-decision gate]]
  assumes will re-parse a quoted string: an unquoted `sh`, `bash` or
  `dash` name with a `-c` option, whose next word is its payload. The
  gate recognises one from the command text alone
  (`glob_scan_shell_payloads()` in `hooks/scripts/human-decision-gate.sh`),
  reading the text with quoted strings masked, so a quoted name is not
  recognised. The name's preceding character, if any, is not a letter,
  digit, `_`, `.` or `-` (so a blank, `/`, `=`, `$` or a quote
  qualifies); then come any option words that start with `-` or `+`, the
  last a short-option cluster holding `c` (`-c`, `-ec`); words are
  separated by blanks, and matching is case-insensitive. It also matches
  a name that is only an argument, as in `echo sh -c` before a quoted
  glob, although no second shell runs; both widenings can only
  over-block. The gate's glob scan reads the payload with its quote
  characters deleted and every metacharacter live, so a glob there can
  make an [[expansion-named token]]. The rule decides which globs count,
  not which tokens are spelled: the quote-joined text deletes only quote
  characters, so a token spelled inside any quoted string is present
  whether or not a second shell is recognised. The rule applies when the
  command lexes; when it does not, the gate scans the raw text with every
  glob live anyway. Suite rows pin it, such as QP-1, QP-2 and QPF-1 to
  QPF-8; its declared residuals, R-QP-a and R-QP-b, carry no completeness
  claim (see [[frozen family table]]).
```

Commit: `docs(hyg-3): second shell glossary entry; one FP-ext-1 mention`.

## Do NOT touch
Everything except those four entries of `docs/harness-glossary.md`;
`CONTEXT.md`, `hooks/`, `tests/`, `scripts/`, `agents/`, `templates/`.

## Acceptance criteria
1. Save as `$S/hyg3-check.py` and run from the worktree root:
   `python3 $S/hyg3-check.py docs/harness-glossary.md fcfcc47; echo rc=$?`
   gives rc=0 and 0 `FAIL` lines. Revert proof:
   `git show fcfcc47:docs/harness-glossary.md > $S/base.md && python3 $S/hyg3-check.py $S/base.md fcfcc47`
   gives rc=1.
   ```python
   import re, subprocess, sys
   path, base = sys.argv[1], sys.argv[2]
   EDIT = ['frozen family table', 'expansion-named token', 'second shell']
   def entries(lines, names):
       out = {}
       for i, l in enumerate(lines):
           for n in names:
               if l.startswith('**' + n + '**:'):
                   j = i
                   while j < len(lines) and lines[j].strip() != '':
                       j += 1
                   out[n] = (i, j)
       return out
   def rest(lines, names):
       e = entries(lines, names); skip = set()
       for i, j in e.values():
           skip.update(range(i, j + 1))
       return [l for k, l in enumerate(lines) if k not in skip], e
   new = open(path, encoding='utf-8').read().split('\n')
   old = subprocess.run(['git', 'show', base + ':docs/harness-glossary.md'],
                        capture_output=True, text=True, check=True).stdout.split('\n')
   suite = open('tests/human-decision-gate.test.sh', encoding='utf-8').read()
   fails = []
   def chk(c, m):
       print(('ok   ' if c else 'FAIL ') + m)
       if not c: fails.append(m)
   rn, en = rest(new, EDIT); ro, _ = rest(old, EDIT)
   chk(len(en) == 3, 'three entries found')
   chk(rn == ro, 'nothing outside the three entries changed')
   T = {n: re.sub(r'\s+', ' ', ' '.join(new[i:j])) for n, (i, j) in en.items()}
   for n, (i, j) in en.items():
       longl = [i + 1 + k for k, x in enumerate(new[i:j]) if k >= 1 and len(x) > 78]
       chk(not longl, f'{n}: no body line over 78 columns {longl}')
       hits = re.findall(r'\bonly\b[^.:;]*:', T[n])
       chk(not hits, f'{n}: no closed "only ...:" list {hits}')
   F, X, Z = (T.get(n, '') for n in EDIT)
   chk(F.count('FP-ext-1') == 1, 'F: FP-ext-1 mentioned once')
   chk('FP-ext-1 (extglob words)' in F, 'F: extglob meaning kept')
   chk('[[second shell]]' in F and '[[second shell]]' in X, 'F, X link the new entry')
   chk('not a letter, digit' not in F, 'F: rule text moved out')
   chk('(see [[frozen family table]])' not in X, 'X: no stale rule pointer')
   for s in ['glob_scan_shell_payloads()', 'not a letter, digit', '`=`', '`$`',
             '`+`', '`-ec`', 'case-insensitive', 'echo sh -c', 'over-block',
             'quoted name is not', 'deletes only quote', 'when it does not',
             'such as', 'R-QP-a', 'R-QP-b', 'completeness']:
       chk(s in Z, f'Z: names {s}')
   chk(not re.search(r'mask[a-z]* (a|the) quoted payload', Z), 'Z: no joined-masks-payload claim')
   chk('at a word start' not in Z, 'Z: no narrow boundary wording')
   ids = set(re.findall(r'\bQPF?-\d+\b', Z))
   for m in re.finditer(r'\b(QPF?)-(\d+) to \1-(\d+)', Z):
       ids.update(f'{m.group(1)}-{k}' for k in range(int(m.group(2)), int(m.group(3)) + 1))
   chk(len(ids) >= 3, f'Z: names pinned rows {sorted(ids)}')
   arr = {}
   for name in ('qp_rows', 'qpf_rows'):
       m = re.search(r'^' + name + r'=\((.*?)^\)', suite, re.M | re.S)
       arr[name] = set(re.findall(r'^\s*"(\d+)\|', m.group(1), re.M)) if m else set()
   for rid in sorted(ids):
       fam, num = rid.split('-')
       chk(num in arr['qpf_rows' if fam == 'QPF' else 'qp_rows'], f'Z: {rid} is a suite row')
   sys.exit(1 if fails else 0)
   ```
   QP and QPF rows live in the suite's `qp_rows` and `qpf_rows` arrays
   (`tests/human-decision-gate.test.sh:1013-1017`, `:1057-1066` at
   fcfcc47), each asserted `blocked` by the loop that reads it; the check
   confirms each id the entry names is a row there.
2. `node tests/context-glossary-links.test.js && node tests/protocol-doc-drift.test.js; echo rc=$?` gives rc=0.
3. If hyg-1 has landed: the `pins.sh` extraction of hyg-1 criterion 3
   prints `fail=0`.
4. `git diff --name-only fcfcc47..HEAD -- . ':!docs/plans'` over the
   unit's own commits prints exactly `docs/harness-glossary.md`.
5. `bash tests/validate.sh` passes per R3.

## Pre-resolved context
- `joined` deletes only `'` and `"` (`human-decision-gate.sh:738-739`);
  `glob_scan_shell_payloads` runs only on the lexed branch (`:438-445`);
  boundary `(^|[^[:alnum:]_.-])`, option words `[-+]...`, c-cluster
  `-[[:alpha:]]*c[[:alpha:]]*`, blanks `[[:blank:]]+` (`:467-469`).
- The rnc-1 check script would now fail on the frozen family table (its
  rule-wording checks); that script was rnc-1's own one-time criterion at
  its commit and is not re-run.
- Dry run (2026-10-04, a Python file written with the Write tool, never
  Bash text naming both tokens): edits A-E, parsed from this plan and
  applied to `git show fcfcc47:docs/harness-glossary.md`, each `old`
  found exactly once; criterion 1 then gives rc 0, 42 `ok`, 0 `FAIL`,
  widths included. At the base it gives rc 1 with 23 `FAIL`.

## Escalation
If an `old` is not found exactly once, or criterion 1 fails on anything
other than a width, stop and report the failing line. Never reword to get
past a hook (R2).

## Verification of the dropped item (V7)

Run at any HEAD after fcfcc47: `git grep -n "2.1.288 only\|does not capture\|does not document" -- CONTEXT.md docs/adr/0039-prompt-confirmed-decision-write.md docs/harness-glossary.md docs/trust-model.md`
prints nothing, and `git grep -c 7e04acd -- CONTEXT.md
docs/adr/0039-prompt-confirmed-decision-write.md docs/harness-glossary.md
docs/trust-model.md` prints a count of at least 1 for each file. (Checked
at fcfcc47: both hold.)

## Out of scope

- An opt-in fail-on-SKIP mode for validate.sh.
- Counting SKIP lines that a suite captures and discards.
- rnc-1 NOTE[spec]: the double-quoted command-substitution glob gap in the
  gate (needs a hooks/ unit; other specs own the gate and its suite).
- Rewording the gate header comment's "at a word start or after a `/`"
  (hooks/, R6).
- esc-fu-1 NOTE[code] on QP-3 reachability; esc-chat-7-record NOTE[code]
  record oddities; the unmeasured teammate premise.

## Open Questions

None blocking. Every Partial category was self-resolved (Clarifications).
The user may override two choices: item 1's count-not-fail (Context), and
moving the rule text out of the frozen family table (Clarifications,
Terminology).

## Self-check
- CHK1: Is the SKIP-count behaviour defined for a run cut short by
  `timeout`? — PASS (Context "Item 1 decision", hyg-1 criterion 2)
- CHK2: Is the SKIP section's coverage stated without a completeness
  claim? — PASS (wrapper comment, Out of scope)
- CHK3: Do hyg-1 and hyg-3 agree on which glossary text the pin check
  reads, and does hyg-3 leave it intact? — PASS (hyg-3 edits A-D avoid
  the residual sentence; hyg-3 criterion 3)
- CHK4: Is item 2 resolved as code or wording, with a proof that fails at
  the base? — PASS (hyg-2 criterion 3, base `ok`, fixed `FAIL`)
- CHK5: Is the guard's behaviour under job control defined and
  machine-checked? — PASS (hyg-2 criterion 4)
- CHK6: Does the new entry avoid the joined-text masking mechanism esc-fu-1
  flagged? — PASS (edit E; hyg-3 criterion 1 regex)
- CHK7: Does any new prose make a closed-list claim without a pin? — PASS
  ("such as" forms; hyg-3 criterion 1 checks named ids and the `only ...:`
  form)
- CHK8: Is item 7 represented, given no unit implements it? — PASS (G7,
  Context row 7, V7)
- CHK9: Does any unit touch agents/ or templates/ (P3)? — PASS (none;
  Version stamping)
- CHK10: Is every Goal clause mapped to a criterion? — PASS (G1 hyg-1 c2;
  G2 hyg-1 c3; G3 hyg-2 c3; G4 hyg-2 c4; G5-G6 hyg-3 c1; G7 V7)
- CHK11: Were hyg-3 edit E's widths machine-checked before handoff? —
  FAIL (missing) — revised in place: dry run added (hyg-3 Pre-resolved
  context: 42 ok, 0 FAIL after the edits; 23 FAIL at the base).
- CHK12: Does hyg-3's check find the QP/QPF rows where the suite keeps
  them? — FAIL (conflicting; the first draft looked for `bash_case` rows,
  but QP/QPF rows are array entries) — revised in place (array lookup).

## Scribe update hint

After hyg-3: the glossary has a new **second shell** entry; wiki
`architecture.md` text on the human-decision gate may link it. After
hyg-1: validate.sh prints a `Skipped checks: N` advisory section on
unsplit runs. No CONTEXT.md change.
