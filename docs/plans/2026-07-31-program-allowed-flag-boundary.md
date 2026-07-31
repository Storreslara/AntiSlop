# Flag-scan word-boundary hardening in `program_allowed()`

**Status:** finalized spec, ready for `task-master` slicing.
**Tracker:** issue **#184**. **Not** part
of #182, #183, or the remaining scope of the
`docs/plans/2026-07-31-reviewed-path-gate-write-intent.md` epic. That epic's
Step 5 release (#181, v0.16.0) shipped on 2026-07-31 with this gap recorded in
the CHANGELOG as a known, open, separately-tracked limitation, per human
decision.

**Sibling debug spec (methodology source, not scope):**
`docs/plans/2026-07-31-debug-182-step6-word-boundary.md`.

---

## Goal

Make the two flag-scans inside `program_allowed()` —
`rg --pre` / `--hostname-bin`, and `git --output` / `-o` — recognize an option
flag at a **bash word boundary**, rather than at a literal space character, so
that the guard's strictness matches the property it was written to assert. The
boundary must be pinned by a **closed enumeration stated in this spec**, and by
an exhaustive per-byte assertion in the suite, so a fourth instance of this bug
class cannot land silently.

Non-goal, stated up front: this changes **which text counts as a flag**. It does
**not** revisit **which flags** are on the inventory, and it does not touch any
other function, gate, or persona rule.

---

## Context

### The site

`hooks/scripts/reviewed-path-gate.sh:39-59`. `program_allowed()` is the
allowlist half of the Bash-path write-intent carve-out: past the
`.claude/reviewed` substring early-exit, a command is allowed only if every
segment invokes an allowlisted program. Two allowlisted programs carry an
extra flag-scan, because they are read-only *except* under a specific option:

```
rg)  case " $1 " in *' --pre '*|*' --pre='*|*' --hostname-bin'*) return 1 ;; esac
git) ... case "$1" in *' -o'*|*' --output'*) return 1 ;; esac
```

Both scans model a bash word boundary as **one literal space character**
(`' --pre '`, `' -o'`). Bash's actual rule is different in two independent ways,
and each is separately exploitable:

1. **The boundary byte set is wider than a space.** A word also begins after tab
   `0x09`, newline `0x0A`, and the operators `;` `&` `|` `(` `)` `<` `>`.
2. **Quote characters are not part of the word at all.** Bash removes them
   during word splitting, so `""--output=X`, `-"-output=X"` and `--out"put"=X`
   are all the single word `--output=X`. A scan over raw segment text cannot see
   that, and no boundary-byte fix alone addresses it.

Point 2 is the reason the answer to the orchestrator's question 1 is **"yes, and
not only that"** — see Clarifications and Risks RD2.

### Prior-defect history (per the `.fail`-record rule)

`.claude/reviewed/` carries durable FAIL records for **both** units that have
previously edited this file: `177.fail` and `182.fail`. #182 additionally hit
the shared protocol's 2-FAIL cap and required a debug spec (#183) after three
attempts, all on the same bug class — an ad-hoc word-boundary predicate in this
same file. Recorded explicitly so `task-master` **never** tags this unit
`haiku`, and so no pass proposes "just swap the pattern" without the enumerated
boundary criteria below. This unit is reviewer-mandatory and `fable`-roast-worthy.

### Established evidence (prior reviewers)

Two reviewers (one opus, one fable) independently reproduced the bypass against
live bash in their own isolated fixtures, and bisected it as present and
unchanged since Step 1's commit `273c7b1` — i.e. it was never introduced by
#182's fix attempts, and #182's debug spec explicitly placed "the program
allowlist" out of its scope (RD5, criterion 6R-1.6). **That severity finding is
taken as established and is not re-demonstrated here.** No payload in this
session was executed against any real path under `.claude/reviewed/`; every
measurement below is either a pure string-predicate evaluation, a gate exit
code, or a question about git/rg's own CLI answered in a throwaway directory.

### Measured this session (constitution P1)

All numbers below were measured on 2026-07-31 against the live file and against
a scratch candidate copy. None is quoted from a prior round.

**(a) The current scan, evaluated as a pure string predicate** (function lifted
verbatim, benign `/scratch/x` target, nothing executed). `ALLOW` = the guard
does not fire:

| form | current |
|---|---|
| `git diff --output=X HEAD` (space) | block |
| `git diff HEAD --output=X` (trailing) | block |
| `git diff<TAB>--output=X HEAD` | **ALLOW** |
| `git diff ""--output=X HEAD` | **ALLOW** |
| `git diff ''--output=X HEAD` | **ALLOW** |
| `git diff -"-output=X" HEAD` | **ALLOW** |
| `git diff --out"put"=X HEAD` | **ALLOW** — *not in either reviewer's list* |
| `rg --pre /bin/sh pat X` (space) | block |
| `rg<TAB>--pre /bin/sh pat X` | **ALLOW** |
| `rg --pre<TAB>/bin/sh pat X` | **ALLOW** — *terminator side; not in either reviewer's list* |
| `rg ""--pre /bin/sh pat X` | **ALLOW** |
| `rg --pretty pat X` | ALLOW (correct — must stay) |

Two forms above are **new findings from this session**, and they matter for the
fix's shape:

- **Quote *inside* the flag name** (`--out"put"=`). Adjacency is not the
  mechanism; arbitrary interior quoting is. A fix that only widens the boundary
  byte set leaves this open.
- **The `rg --pre` terminator side.** The pattern `*' --pre '*` requires a
  trailing **space**, so `--pre<TAB>cmd` evades it even though the leading
  boundary is a real space. Both ends of the flag token need the same rule.

**(b) The real flag surface** (git 2.43.0, ripgrep 14.1.1; throwaway `git init`
directory, benign `out*` targets):

- `git diff --output=F`, `git diff --output F`, `git log --output=F`,
  `git show --output=F` all **write**. `git status --output=F` → rc 129.
- `git diff -o F` → rc **128**; `git diff -oF` → rc **129**. `-o` is **not** a
  short option on the allowlisted subcommands, so **short-option bundling
  (`-poF`) is not a vector here** — recorded so a reviewer does not have to
  re-derive it, and so nobody widens the scan to "any single-dash word
  containing `o`" (which would over-block for no gain).
- ripgrep spells them `--pre=COMMAND`, `--pre-glob=GLOB`,
  `--hostname-bin=COMMAND`; the space-separated forms also parse. The current
  three-pattern inventory is therefore correct and is carried over unchanged.

**(c) Candidate fix, measured end-to-end** (scratch copy of the whole gate,
suite pointed at it with the suite's existing `GATE_UNDER_TEST` hook):

- All **12** blocked forms from table (a), plus `git diff<LF>--output=X`, now
  block; all **8** over-block controls still allow.
- **77 / 77** existing suite assertions still `OK`, suite exit 0, no `FAIL`
  lines. (Baseline on the live gate, measured this session: also 77 `OK`.)
- Case 26's non-vacuity counter: **257** gate-allowed probes of 635 (live gate:
  same 635-probe shape). Comfortably above the existing `>= 200` floor.
- Suite wall clock: **12.7 s** with the candidate; the new byte sweep specified
  in Step 1 adds a measured **3.7 s** → ~16.4 s total.

**(d) The exact boundary-byte behaviour, swept.** Injecting every byte
`0x01`-`0x7F` at the flag boundary of two templates and recording the gate's
exit code:

| | bytes BLOCKED |
|---|---|
| live gate | `0x0A 0x20 0x22 0x26 0x27 0x3B 0x3E 0x5C 0x60 0x7C` (10) |
| candidate | `0x09 0x0A 0x20 0x22 0x26 0x27 0x28 0x29 0x3B 0x3C 0x3E 0x5C 0x60 0x7C` (14) |

Identical for both templates. The delta is exactly `0x09` (TAB), `0x28` `(`,
`0x29` `)`, `0x3C` `<` — the four bash metacharacters that were reachable at
this site and previously accepted as ordinary text. VT `0x0B`, FF `0x0C` and CR
`0x0D` remain **allowed** under the candidate, which is correct: bash treats
them as ordinary word characters, so blocking them would be the mirror-image
over-block that #182's criterion 6R-1.5 exists to catch.

### Blast radius (exact)

`grep -rln 'program_allowed'` over the tree, excluding `.git`/`node_modules`,
returns exactly two files: `hooks/scripts/reviewed-path-gate.sh` and
`CHANGELOG.md` (prose). `find` for `reviewed-path-gate*` returns the script, its
test file, and one stale `.claude/worktrees/` copy that is not part of the
build. **There is no `.claude/` mirror and no `adapters/{cursor,codex}` copy of
this script** — the adapter trees carry `graph-update.sh`, `lint-on-edit.sh`,
`protected-paths.sh`, `reviewer-route-gate.sh` and `stop-gate.sh` only. So the
production change is single-file.

`bin/cli.js --update` copies `hooks/scripts/*.sh` wholesale, so this fix reaches
every already-adapted project — which is what makes the version bump in Step 2 a
constitutional requirement (P3), not bookkeeping.

---

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-07-31 Functional scope & success criteria: Q Does this unit cover only
  the `program_allowed()` flag-scan fix, or also the three open review notes
  from #182's final round (a T6 sweep template, the T3/T4 vacuity defect, and
  the A4 wording overclaim)? → A (self-resolved): the fix plus its own
  regression machinery plus the A4/CHANGELOG wording narrowing; the T3/T4
  vacuity defect is **explicitly deferred**. Full reasoning in "Scoping call"
  below.
- 2026-07-31 Domain entities / data model: Q Are "segment", "word",
  "metacharacter", "boundary byte" and "flag scan" used with the same meaning
  here as in the #182 debug spec and the gate's own header? → A (self-resolved):
  yes, inherited unchanged. This spec adds exactly one term, **flag token** — the
  word that a flag scan is trying to recognize, defined in Step 1's boundary
  contract.
- 2026-07-31 User interaction flow: Q What is the observable contract? → A
  (self-resolved): unchanged — hook exit 0 = allowed, exit 2 + non-empty stderr
  = blocked. The suite's `check()` already asserts exact codes; no change to the
  block message text is in scope.
- 2026-07-31 Non-functional attributes: Q Does adding a second exhaustive byte
  sweep push the suite past a usable runtime, given it already runs from
  `tests/validate.sh`? → A (self-resolved): no. Measured 3.7 s for the new
  254-probe sweep on top of a 12.7 s suite → ~16.4 s. Budget pinned at 60 s in
  AC1.11, the same figure #182 pinned.
- 2026-07-31 External dependencies & integrations: Q Does anything here need a
  tool the suite does not already use? → A (self-resolved): no — `bash`, `jq`,
  `mktemp` only. The new sweep is **block-direction only** and therefore needs
  **no** real-bash execution half at all, unlike case 26 (see AC1.9's rationale).
- 2026-07-31 Edge cases / failure handling: Q Exactly which bytes must be
  treated as a word boundary, and exactly which quote-structural forms must be
  seen through? → A (self-resolved): the ten bash metacharacters (space `0x20`,
  tab `0x09`, newline `0x0A`, `;` `&` `|` `(` `)` `<` `>`) plus start-of-segment
  and end-of-segment, **and nothing else** — VT `0x0B`, FF `0x0C`, CR `0x0D`
  explicitly excluded; and `'`/`"` treated as absent from the word entirely, so
  empty-string-adjacent, quote-adjacent and quote-interior spellings all
  collapse to the bare flag. Both enumerated normatively in Step 1 and asserted
  by AC1.7 and AC1.8.
- 2026-07-31 Technical constraints & tradeoffs: Q Is over-blocking acceptable,
  and if so where is the line? → A (self-resolved): yes, over-blocking is the
  safe direction and the fix is deliberately a fail-closed over-approximation of
  bash word splitting (Step 1, "Direction"). The line is drawn by AC1.8's eight
  named allow-controls and AC1.6's 77-assertion no-regression bound, plus the
  ratified residual R-1 below.
- 2026-07-31 Terminology consistency: Q Does the gate's header or the epic doc
  describe this guard in terms that will be false after the fix? → A
  (self-resolved): yes, in two places — Amendment A4's claim that the sweep
  "checks the matcher against real bash across every byte", and the 0.16.0
  CHANGELOG paragraph declaring this gap open and untracked. Both handled in
  Step 2; the first is subject to Open Question 1.
- 2026-07-31 Completion / acceptance signals: Q What distinguishes "the five
  forms the reviewers named are blocked" from "the boundary predicate is
  correct"? → A (self-resolved): AC1.7's exact 14-byte blocked set, stated as a
  set equality over the whole range `0x01`-`0x7F` rather than as examples, plus
  AC1.9's mutation control proving the new assertion can actually fail.

---

## Scoping call (orchestrator question 2)

**IN — the fix, and only the regression machinery that pins the fix itself.**

- **Step 1: the `program_allowed()` boundary + quote-transparency fix, its
  enumerated fixtures, and a new exhaustive flag-boundary byte assertion (case
  28) with a mutation control.** The byte assertion is not a bundled extra: it
  *is* the acceptance criterion the orchestrator asked for in question 3, and
  #182 escalated precisely because example-based criteria cannot fail an
  implementation that is wrong on constructs nobody wrote a fixture for.
- **Step 2: release hygiene** — version bump, CHANGELOG, gate header comment,
  and the two prose corrections (A4's overclaim, the 0.16.0 "still open" note).
  Constitutionally mandatory (P3) because `--update` propagates this file.

**IN, narrowed — the A4 wording fix (review note 3).** One sentence of the epic
plan doc claims the differential sweep "checks the matcher against real bash
across every byte", when it checks filesystem effects under five fixed payload
shapes. Leaving a false completeness claim in the canonical doc is actively
harmful *now that a second boundary bug has been found at a site that sweep
never covered* — the overclaim is exactly what would let a reader conclude the
class was already closed. Cost: a few lines of prose, no code. Its form is
Open Question 1.

**OUT — the T3/T4 vacuity defect (review note 2), deferred.** A reviewer found
case 26's T3/T4 templates structurally incapable of ever failing. That finding
is correct and should be tracked, but it does **not** belong here:

- It is a defect in a *different* function's test coverage
  (`mask_inert_redirections()`'s trailing anchors), not in `program_allowed()`.
  Bundling it forces one reviewer to hold two independent lexer surfaces in
  their head — the exact large-multi-concern shape that cost #182 three rounds.
- It is **not** the "minutes, zero risk" job that #182's own 6R-3 folded in.
  Making T3/T4 able to fail means constructing a payload where the fd/`/dev/null`
  anchor divergence produces a *real* filesystem effect — and #182's debug spec
  already recorded, with measurements, that it **could not construct one**
  ("latent divergence, not a demonstrated fail-open"). The task may well have no
  solution, and its scope is "determine whether this divergence is exploitable
  at all". That is a research question, not a test edit.
- It has no bearing on whether this fix is correct. Nothing in Step 1 touches
  case 26.

Action instead: Step 2 files a tracking issue so the finding does not decay into
folklore, and this spec's text is the durable record of why it was split out.

**OUT — a "T6" template inside case 26 (review note 1), superseded.** The
reviewer's instinct was right, but bolting it onto case 26 would have
reproduced the T3/T4 bug on day one: case 26's second half executes the payload
with real bash in a bare `mktemp -d`, and `git diff --output=F` outside a git
repository writes **nothing** (measured: rc 128/129). A differential T6 would
therefore have been green forever regardless of the gate's behaviour. So the
recommendation is honoured in a **different shape** — case 28, a block-direction
exhaustive assertion needing no execution half, whose ability to fail is proven
by an explicit mutation control (AC1.9). This is called out because it is the
single most likely way an implementer could satisfy the letter of this spec and
still ship a vacuous test.

**OUT — the flag inventory.** Whether `gh`'s subcommand allowlist needs a flag
scan of its own (it has none today), and whether `rg` has other
command-executing flags, are **inventory-completeness** questions, orthogonal to
this **boundary-correctness** fix. Mixing them would make the diff impossible to
review against a single property. Noted in Step 2's tracking issue.

---

## Risks / dependencies

- **RD1 — Third bug of this class in this file; two durable FAIL records.**
  Default-to-block posture; **not `haiku`-eligible** under any slicing; reviewer
  mandatory; `fable` roast pass advised. See "Prior-defect history".
- **RD2 — A boundary-byte-only fix is insufficient and will look sufficient.**
  The reviewers' five named forms include three quote-structural ones, and this
  session found two more (quote-interior, and the `rg --pre` terminator side).
  An implementer who reads only #182's debug spec will reach for the enumerated
  metacharacter set alone and close four of the twelve measured forms. AC1.8's
  fixture list exists specifically to fail that implementation.
- **RD3 — Quote removal must not be reinvented as a lexer.** The fix is sound
  *only because* `command_skeleton()` has already refused every segment
  containing a backslash, a heredoc, or an unbalanced quote before
  `program_allowed()` is reached, which makes naive quote deletion a total
  function at this site. If a future change relaxes any of those three
  fail-closed refusals, this scan's soundness argument lapses. Step 1 requires
  that dependency to be written into the code comment, not just this doc.
- **RD4 — Over-approximation is intended, under-approximation is the bug.**
  Deleting quotes can expose a boundary bash would have kept quoted (`a" "b`),
  which only *adds* blocks. That direction is safe and must not be "corrected"
  by a later pass. Pinned by AC1.8's allow-controls so the over-approximation
  cannot silently grow into a usability problem either.
- **RD5 — Do not widen scope.** Any diff touching the reviewer GRANT, the
  no-reviewer fallback, the substring early-exit, `normalize_path()`,
  `command_skeleton()`, `mask_inert_redirections()`, `identity_drift_log`
  placement, the Write/Edit path, or the block messages is out of scope by
  construction. The only production function that may change is
  `program_allowed()` (plus a new helper adjacent to it).
- **RD6 — `.claude/reviewed` in command text (epic spec R4).** Every assertion
  that spells the marker directory stays inside `tests/reviewed-path-gate.test.sh`
  and is built from the existing `$marker` variable, never a literal. This
  applies to case 28 too. The rule is load-bearing: an attempt to write this
  spec's own verification inline in a shell command was correctly blocked by
  the very gate under test during this session.
- **RD7 — No epic dependency.** #181 (v0.16.0) has already shipped; there is no
  downstream release step to defer the version bump to, so this unit owns its
  own bump. Nothing here blocks or is blocked by remaining epic work.

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every claim in Context was measured
  this session (12-form predicate table, 77/77 suite run against a patched
  scratch copy, the 127-byte × 2-template blocked-set sweep on both live and
  candidate, git 2.43.0 / ripgrep 14.1.1 flag behaviour, and the blast-radius
  `find`/`grep`). AC1.7 and AC1.9 make the same discipline permanent.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — verified
  by `find` that this script has no `.claude/` mirror and no
  `adapters/{cursor,codex}` copy, so no script-driven path is being hand-edited.
  The version bump goes through the two files `tests/validate.sh` already
  cross-checks for sync.
- P3 "Version-stamp discipline": satisfied — Step 2 bumps `0.16.0` → `0.16.1` in
  **both** `.claude-plugin/plugin.json` and `package.json` (validate.sh enforces
  they match) and adds a CHANGELOG entry. Required because `bin/cli.js --update`
  copies `hooks/scripts/*.sh` wholesale, so without a bump the fix does not
  reach adapted projects.
- P4 "Optional personas degrade gracefully": satisfied — no persona-conditional
  prose is added or changed.
- P5 "`tests/validate.sh` is the merge gate": satisfied — AC1.12 and AC2.6;
  `validate.sh` already invokes `tests/reviewed-path-gate.test.sh`.

---

## Step 1 — Recognize flag tokens at a bash word boundary, quote-transparently

**Affected files (exact):**
- `hooks/scripts/reviewed-path-gate.sh` — `program_allowed()` (lines 39-59) and
  its header comment; a new helper function may be added immediately adjacent to
  it. No other function's body.
- `tests/reviewed-path-gate.test.sh` — new cases only; no existing case's
  fixture or expected verdict changes.

### Normative contract

**Flag token.** A *flag token* is recognized only when it begins a **word**.

**Boundary set (closed enumeration).** A word begins at the **start of the
segment**, or immediately after one of bash's ten metacharacters:

> space `0x20`, tab `0x09`, newline `0x0A`, `;` `&` `|` `(` `)` `<` `>`
> — **and nothing else.**

In particular **not** vertical tab `0x0B`, **not** form feed `0x0C`, **not**
carriage return `0x0D` (bash treats all three as ordinary word characters), and
not `=`, `-`, `.` `/` or any alphanumeric. A word **ends** at the same set or at
the end of the segment — both ends of a flag token use this one rule. This is
the identical enumeration #182's 6R-1 established for `command_skeleton()`; it
is restated in full here so that this site can be read off rather than derived.

**Quote transparency.** `'` and `"` are not characters of a word — bash removes
them. The scan must therefore see all of `""--output=X`, `''--output=X`,
`-"-output=X"` and `--out"put"=X` as the single word `--output=X`.

**Soundness precondition (must appear in the code comment).** Treating quote
characters as simply absent is sound **at this site only** because
`command_is_provably_benign()` has already routed the command through
`command_skeleton()`, which fails closed on any backslash, any heredoc and any
unbalanced quote before `program_allowed()` is ever reached. If any of those
three refusals is relaxed, this scan's soundness argument lapses (RD3).

**Direction.** The resulting word-start set must be a **superset** of bash's,
never a subset. Quote removal may join characters bash would have kept apart
(`a" "b`), which can only add boundaries and therefore only add blocks.
Over-blocking is the safe direction; AC1.8's allow-controls bound how far.

**Flag inventory — unchanged, carried over verbatim:**
- `git`, on subcommands `commit|log|show|diff|status|tag|blame`: a word
  beginning with `-o`, or a word beginning with `--output`.
- `rg`: a word exactly `--pre`; a word beginning with `--pre=`; a word beginning
  with `--hostname-bin`.

Measured note for the reviewer, so it is not re-derived: `-o` is **not** a short
option on any allowlisted `git` subcommand (`git diff -o F` → rc 128,
`-oF` → rc 129 on git 2.43.0), so short-option bundling is not a vector and the
`-o` half is defensive breadth. Do **not** widen it to "any single-dash word
containing `o`" — that would over-block for no measured gain.

### Prototype (measured; illustrative, not binding)

A candidate satisfying every criterion below was measured this session. The
implementer is **not** bound to this syntax, only to the criteria:

```
# Fail-closed over-approximation of bash word splitting, for the flag scans
# only. Sound here because command_skeleton() already refused backslashes,
# heredocs and unbalanced quotes (see RD3).
flag_scan_form() {
  local s="${1//[\'\"]/}"                 # quotes are not part of a word
  s="${s//[$' \t\n;&|()<>']/ }"           # every metacharacter -> one space
  printf ' %s ' "$s"                      # pad, so a glob can test word-start
}
```
…after which each existing `case` pattern keeps its exact spelling
(`*' --pre '*`, `*' --pre='*`, `*' --hostname-bin'*`, `*' -o'*`,
`*' --output'*`) but is matched against `flag_scan_form "$1"` instead of `"$1"`
or `" $1 "`. Measured with this prototype: 12/12 bypass forms blocked, 8/8
allow-controls preserved, 77/77 existing assertions `OK`.

### Acceptance criteria

**Fix**

1. `bash -n hooks/scripts/reviewed-path-gate.sh` exits 0.
2. `git diff --numstat -- hooks/scripts/reviewed-path-gate.sh` shows the change
   confined to `program_allowed()`, its header comment, and at most one new
   helper function adjacent to it. `command_skeleton`, `mask_inert_redirections`,
   `segment_allowed`, `command_is_provably_benign`, `normalize_path` and the
   main body are byte-identical. Checkable by inspecting the diff hunks' context
   headers.
3. The file names the three excluded bytes and says why:
   `grep -cE '0x0B|0x0C|0x0D' hooks/scripts/reviewed-path-gate.sh` prints `>= 1`
   **and** the surrounding comment states they are ordinary word characters to
   bash. The comment must also record the RD3 soundness precondition:
   `grep -c 'command_skeleton' hooks/scripts/reviewed-path-gate.sh` prints
   `>= 1` within `program_allowed()`'s comment block.
4. The flag inventory is unchanged: the five pattern spellings `--pre `,
   `--pre=`, `--hostname-bin`, `-o`, `--output` are the only flag texts the
   function tests for. No flag is added or removed.

**No regression**

5. `bash tests/reviewed-path-gate.test.sh` exits 0 with **no** line starting
   `FAIL`, and the count of lines starting `OK` is **>= 77** (baseline measured
   this session at `9dc6654`: exactly 77). **No pre-existing case's expected
   verdict changes** — in particular cases 12e/12f, 20/21/22, 25.x and 27.x keep
   their verdicts, and case 26's non-vacuity floor still passes (measured with
   the candidate: 257 of 635 allowed, floor `>= 200`).

**Boundary, pinned exactly**

6. New **case 28** in `tests/reviewed-path-gate.test.sh`: a loop over every byte
   `0x01`-`0x7F` **inclusive, with no exclusions**, crossed with exactly two
   templates, `<M>` being the existing `$marker` and `<B>` the injected byte:

   | id | template | boundary pinned |
   |---|---|---|
   | G | `git diff HEAD<B>--output=<M>/9.pass` | leading boundary of a `git` flag token |
   | R | `rg pat <M><B>--pre=/bin/sh` | leading boundary of an `rg` flag token |

7. **Exact blocked-byte set (the criterion that constrains the predicate).** For
   **each** of the two templates, the set of injected bytes at which the gate
   exits 2 must be **exactly**:

   > `0x09 0x0A 0x20 0x22 0x26 0x27 0x28 0x29 0x3B 0x3C 0x3E 0x5C 0x60 0x7C`

   — 14 bytes, identical for both templates — and the gate must exit 0 for the
   other 113. Case 28 asserts **set equality**, not a subset: a byte blocked
   that is not on this list fails the case just as a byte on the list that is
   allowed does. Every failure line must name the template id and the byte **in
   hex** (`0x0D`, not `13`).

   Notes for the implementer and reviewer, so the list is not misread:
   - Ten of the fourteen are bash's metacharacters. Four — `0x22 "`, `0x27 '`,
     `0x5C \`, `0x60` backtick — are blocked by the **pre-existing**
     skeletonizer / substitution machinery, not by the flag scan; they are on
     the list so the expected set is complete and mechanically diffable.
   - VT `0x0B`, FF `0x0C` and CR `0x0D` are deliberately in the **allowed** 113.
     Blocking them is an over-block and fails this criterion.
   - Measured this session: the live gate blocks only 10 of the 14 (it is
     missing `0x09`, `0x28`, `0x29`, `0x3C`); the candidate blocks all 14.

**Quote structure, pinned by enumeration** (not byte-sweep reachable)

8. Named cases, all built from `$marker`, all asserting **blocked**:

   | # | fixture |
   |---|---|
   | a | `git diff ""--output=<M>/9.pass HEAD` |
   | b | `git diff ''--output=<M>/9.pass HEAD` |
   | c | `git diff -"-output=<M>/9.pass" HEAD` |
   | d | `git diff --out"put"=<M>/9.pass HEAD` (quote **inside** the flag name) |
   | e | `git diff<TAB>--output=<M>/9.pass HEAD` |
   | f | `rg pat <M> ""--pre=/bin/sh` |
   | g | `rg pat <M> -"-pre" /bin/sh` |
   | h | `rg --pre<TAB>/bin/sh pat <M>` (flag **terminator** side) |
   | i | `rg --p"re"=/bin/sh pat <M>` |

   …and the following asserting **allowed**, pinning that the narrowing did not
   overshoot: `rg --pretty pat <M>`; `rg --pre-glob *.md pat <M>`;
   `git log --oneline -- <M>`; `git commit -m "fix: record the verdict under
   <M>"`; `git diff --stat HEAD -- <M>`;
   `gh issue close 9 --comment "see <M>/9.pass"`; `cat <M>/9.pass`;
   `ls -la <M>`. All sixteen verdicts were measured against the candidate this
   session.

**Anti-vacuity**

9. **Mutation control, recorded in a comment above case 28 and re-runnable by
   the reviewer.** Reverting the scan to match against the raw segment (i.e.
   removing the quote-deletion and metacharacter-normalization step, restoring
   the literal-space check) in a scratch copy, and running the suite against it
   via the suite's existing `GATE_UNDER_TEST` variable, must exit non-zero with
   **at least 6** `FAIL` lines — at least one from case 28's G template, at
   least one from case 28's R template, and at least four of AC1.8's nine
   blocked fixtures. The exact mutant command and the expected FAIL count must
   be written in that comment, mirroring case 26's existing mutation-control
   block, so the next reviewer need not reconstruct it.
10. Case 28's comment must state, in one sentence, **why it has no real-bash
    execution half** — that `git diff --output=F` outside a git repository
    writes nothing (measured: rc 128/129), so a differential template here would
    be green forever regardless of the gate, which is the same structural
    vacuity a reviewer already found in case 26's T3/T4. Checkable:
    `grep -c 'vacuous\|vacuity' tests/reviewed-path-gate.test.sh` prints `>= 2`
    (case 26's existing floor comment plus this one).

**Budget and gate**

11. `bash tests/reviewed-path-gate.test.sh` completes in **under 60 seconds**
    wall clock. (Measured this session: 12.7 s for the suite with the candidate,
    plus 3.7 s for the 254-probe case-28 sweep ≈ 16.4 s.)
12. `bash tests/validate.sh` exits 0.

---

## Step 2 — Release hygiene and the two prose corrections

**Affected files (exact):** `.claude-plugin/plugin.json`, `package.json`,
`CHANGELOG.md`, `docs/plans/2026-07-31-reviewed-path-gate-write-intent.md`
(append-only — see Open Question 1).

### Acceptance criteria

1. Version bumped `0.16.0` → `0.16.1` in **both** `.claude-plugin/plugin.json`
   and `package.json`. Checkable: `bash tests/validate.sh` prints the
   `OK   package.json version (0.16.1) matches` line. Patch level, not minor:
   this is a bug fix to shipped behaviour, unlike 0.16.0's deliberate
   enforcement increase.
2. A `## [0.16.1]` CHANGELOG section under `### Fixed` that (a) describes the
   defect as a flag-scan boundary check that was less strict than intended,
   naming both mechanisms (metacharacter set, quote transparency), (b) states
   that `--update` propagates it because `bin/cli.js` copies `hooks/scripts/*.sh`
   wholesale, and (c) **explicitly closes the loop on the 0.16.0 entry** by
   referencing this unit's issue number. The 0.16.0 section itself is **not
   rewritten** — its "not yet filed as a tracked issue" sentence was accurate on
   its date. Checkable:
   `git diff --numstat -- CHANGELOG.md` shows `0` deletions.
3. The A4 overclaim is narrowed: the sentence stating that the differential
   boundary-byte sweep "checks the matcher against real bash across every byte"
   must be corrected to say it checks **filesystem effects under five fixed
   payload shapes**, at five named lexing decision points, for every byte — i.e.
   it is exhaustive in the byte dimension and example-based in the construct
   dimension. It must also note that this unit found a boundary bug at a site
   the sweep does not cover. **Form subject to Open Question 1**; under the
   recommended default this is an appended `## Amendment A5`, and
   `git diff --numstat -- docs/plans/2026-07-31-reviewed-path-gate-write-intent.md`
   shows `0` deletions.
4. A tracking issue is filed (not fixed) for the deferred items, naming exactly
   three: (i) case 26's T3/T4 templates are structurally incapable of failing,
   and the prior finding that the underlying fd/`/dev/null` anchor divergence
   could not be shown exploitable — so the first question is whether the
   templates *can* be made to fail at all; (ii) `gh`'s subcommand allowlist
   carries no flag scan; (iii) whether `rg`'s flag inventory beyond `--pre` /
   `--hostname-bin` needs auditing. Checkable: the issue exists and this plan
   doc's Step 2 records its number.
5. `git diff --stat` for the whole unit touches **exactly**:
   `hooks/scripts/reviewed-path-gate.sh`, `tests/reviewed-path-gate.test.sh`,
   `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`,
   `docs/plans/2026-07-31-reviewed-path-gate-write-intent.md`, and this plan
   doc. Any other file is out of scope (RD5).
6. `bash tests/validate.sh` exits 0.

---

## Open Questions

1. **Should A4's overclaim be corrected in place, or superseded by an appended
   A5?** The epic plan doc has an explicit append-only invariant — #182's
   criterion 6R-4.4 required `0` deletions from it, and A4 itself opens
   "Nothing above this line is modified." Correcting a factual overclaim *inside*
   an already-appended amendment is a different act from appending, and the
   project's convention for it is not derivable from the doc.

   - **(a) Append `## Amendment A5` that supersedes A4's sentence — recommended
     default.** Preserves the append-only invariant exactly, keeps the
     historical record of what was believed on 2026-07-31, and matches the
     handling already chosen for the 0.16.0 CHANGELOG section (AC2.2). Cost: a
     reader of A4 must read on to find the correction, mitigated by requiring
     A5 to quote the superseded sentence verbatim.
   - **(b) Edit A4's sentence in place**, breaking the `0`-deletions invariant
     once, deliberately. Cheaper to read; costs the invariant, and invariants
     that are broken "just once" stop being checkable.
   - **(c) Do nothing**, and let the new `## [0.16.1]` CHANGELOG entry carry the
     correction alone. Cheapest; leaves a false completeness claim in the
     canonical plan doc, which is the specific harm this item exists to prevent.

   **The plan is dispatchable under (a) without waiting for an answer.**

---

## Self-check

- CHK1: Is the legal word-boundary set enumerated exhaustively, by byte value,
  in this plan's own text? — PASS (Step 1 "Boundary set", restated in
  Clarifications under Edge cases, and asserted as a set equality by AC1.7)
- CHK2: Does the plan state a criterion that a boundary-byte-only fix would
  fail? — PASS (AC1.8 fixtures d, g, i are quote-structural and unreachable by
  any byte sweep; RD2 says so explicitly)
- CHK3: Is AC1.7's blocked set stated as an equality or as a lower bound? —
  PASS (equality, both directions, stated in the criterion body)
- CHK4: Can the new case 28 pass vacuously? — FAIL (missing) — revised in place
  (added AC1.9's mutation control with a `>= 6` FAIL floor, and AC1.10 requiring
  the no-execution-half rationale in the comment)
- CHK5: Do the Context measurements and AC1.7 agree on how many bytes the live
  gate blocks versus the fixed one? — PASS (both say 10 live, 14 fixed, delta
  `0x09 0x28 0x29 0x3C`)
- CHK6: Does the plan bound "no regression" with a number rather than a word? —
  PASS (AC1.5: `>= 77` OK lines, baseline 77 measured at `9dc6654`)
- CHK7: Does the plan say what happens to the 0.16.0 CHANGELOG paragraph that
  declares this gap open and untracked? — FAIL (missing) — revised in place
  (added AC2.2(c): closed by reference from a new 0.16.1 section, 0.16.0 itself
  not rewritten, `0` deletions asserted)
- CHK8: Is the A4 correction's form resolvable from this plan's own text without
  asking a human? — FAIL (conflicting) — the doc's append-only invariant and the
  instruction to narrow A4's wording point opposite ways — converted to Open
  Question 1
- CHK9: Do Step 1 and Step 2's affected-file lists agree, and is their union
  closed? — PASS (AC2.5 enumerates the union and asserts nothing else is touched;
  Step 1's list is a subset of it)
- CHK10: Is the scoping decision on T6 / T3-T4 / A4 stated with reasons, or just
  asserted? — PASS ("Scoping call", one reasoned paragraph per item, including
  the measured reason a naive T6 would have been vacuous)
- CHK11: Does the plan say whether `-o` short-option bundling is a vector, so a
  reviewer does not open it as a finding? — PASS (Step 1 "Measured note", rc
  128/129 on git 2.43.0)
- CHK12: P1 (verify, don't assume) — is any Context claim unmeasured? — FAIL
  (ambiguous) — revised in place (the severity claim inherited from the prior
  reviewers is now explicitly labelled as established evidence that this session
  deliberately did **not** re-derive, with the reason; every other Context claim
  now carries its own measurement)
- CHK13: P3 (version-stamp discipline) — does the plan say who bumps the version
  and to what? — PASS (AC2.1: 0.16.1, both files, with the `--update`
  propagation reason; RD7 records there is no downstream release step to defer
  to)
- CHK14: P5 (`validate.sh` is the merge gate) — is it a criterion? — PASS
  (AC1.12 and AC2.6)
- CHK15: Is it stated anywhere that this unit is not `haiku`-eligible, given the
  prior FAIL records on this file? — PASS (RD1 and "Prior-defect history",
  citing `177.fail` and `182.fail`)
- CHK16: Does the plan state the runtime budget for the enlarged suite? — PASS
  (AC1.11: 60 s, measured ~16.4 s)
- CHK17: Is the soundness precondition for quote deletion written where a future
  editor will see it, not only in this doc? — PASS (AC1.3 requires it in
  `program_allowed()`'s comment; RD3 states the failure mode)

---

## Scribe update hint

After this unit lands: update `.claude/wiki/modules/hooks.md` so the
`reviewed-path-gate` section describes **two** standing regression techniques,
not one — case 26's differential byte sweep for `command_skeleton()`, and case
28's exhaustive flag-boundary assertion for `program_allowed()` — and states the
distinction plainly, since it is the reusable lesson: a *differential* sweep
needs the reference implementation to produce an observable effect in the
sandbox, and where it cannot (`git --output` outside a repo), the honest form is
a one-directional block assertion with a mutation control rather than a
differential test that can never fail. Record that this file has now produced
three bugs of one class (ad-hoc word-boundary predicates) across #177, #182 and
this unit, and that the enumerated ten-metacharacter set is the project's single
answer to it. Correct any wiki prose inherited from A4's overclaim. No ADR —
this refines ADR 0007/0008's existing decisions rather than making a new one.

---

## Publication

Published to the project issue tracker via `to-spec` as
**https://github.com/Storreslara/AntiSlop/issues/184**, with the
`ready-for-agent` label. This document remains the canonical artifact; the issue
is the dispatch surface.

---

## Amendment B — the expansion-forged flag token (third mechanism)

Appended during implementation, 2026-07-31. Nothing above this line is modified.
A5 of the epic doc and the `## [0.16.1]` CHANGELOG entry both reflect this
amendment; the body of this spec above does not, and is superseded where they
conflict. Recorded because two of this spec's own acceptance criteria turned out
to be **wrong**, not merely incomplete, and a reviewer reading only the body
above would hold the implementation to a set it must not satisfy.

### B1 — Context "Point 2" is incomplete: a third, independent mechanism

The spec's Context enumerates two ways bash's word rule differs from a literal
space (metacharacter set; quote transparency) and RD2 warns that a
boundary-byte-only fix will *look* sufficient. That warning was correct and did
not go far enough. A fix closing **both** stated mechanisms is still bypassable,
because **expansion forges a flag token out of text that spells no flag
anywhere** — so no scan over the raw segment text, however correct its notion of
a word boundary and however quote-transparent, can see it.

Measured during implementation against the two-mechanism fix, in an isolated
sandbox (fake marker directory under `mktemp -d`; nothing executed against this
repository's real marker directory at any point): three forms were **allowed by
the gate** and **overwrote a seeded sentinel under real bash** — an empty
variable expansion at the flag boundary, the same expansion *inside* the flag
name, and a brace list assembling the flag name from fragments. The rg analogue
was likewise allowed. Exact forms are pinned as cases 29.j-29.n in the suite and
are deliberately not restated here.

**Resolution.** Expansion cannot be normalized away without running the command,
which a `PreToolUse` hook must not do. `flag_scan_form()` therefore **refuses**
the segment outright when it carries one of bash's expansion characters — the
same fail-closed choice `command_skeleton()` already makes for backslashes and
heredocs. The refusal is scoped to the **negative** flag scans only; the positive
matches (program name, `gh` subcommand allowlist) already fail closed under
obfuscation, since an obfuscated name simply misses the allowlist.

### B2 — AC1.10's rationale is factually wrong, and it mattered

AC1.10 requires case 28's comment to justify having **no** real-bash execution
half, on the ground that `git diff --output=F` outside a git repository "writes
nothing (measured: rc 128/129)". The exit code was measured correctly; the
inference from it was not. Measured directly (git 2.43.0): git parses `--output`
and **opens — hence truncates — the target to 0 bytes** *before* it discovers
there is no repository, then exits 129. `git log --output=F` genuinely does not
write (rc 128, file untouched), so the behaviour is per-subcommand, not per-flag.

Had this gone in unverified, case 28 would have shipped as precisely the vacuous
differential the spec was written to avoid — the exact defect it diagnosed in
case 26's T3/T4. Case 28 therefore **has** a differential half on its `git`
template, and it demonstrably fires: under mutation control 1 it independently
reports a real filesystem effect at byte `0x09`.

### Superseded acceptance criteria

| criterion | as written | as implemented and verified |
|---|---|---|
| AC1.7 | blocked set is exactly **14** bytes | exactly **20** — the 14, plus the six expansion bytes `0x24 $`, `0x2A *`, `0x3F ?`, `0x5B [`, `0x7B {`, `0x7E ~`. `0x60` backtick was already in the 14. Still asserted as a **set equality**, still identical for both templates. `0x0B`/`0x0C`/`0x0D` remain allowed as required, and so does `0x7D }` — `{` alone catches brace expansion, so blocking its partner would be an over-block with nothing to show for it. |
| AC1.8 | nine blocked fixtures (a-i) | **fourteen** — a-i unchanged, plus j-n for the expansion forms. |
| AC1.9 | one mutation control, floor **>= 6** FAIL | **two disjoint** controls, one per mechanism pair. Mutant 1 (boundary + quote transparency): 18 FAIL. Mutant 2 (expansion refusal): 18 FAIL. Neither kill set overlaps the other's, which is what shows the third mechanism is independent rather than a restatement. Both measured with every FAIL line reading `rc=0` — a real fail-open — not `rc=1`, which would be a void run. |
| AC1.10 | comment must justify having **no** execution half | comment must record the **corrected** measurement and the differential half it enables. Verbatim rationale in the spec body is void. |
| AC1.8 allow-controls | eight, including `rg --pre-glob *.md` | **seven**. `rg --pre-glob *.md` moves to a **ratified residual over-block** (new case 29.o), because its glob metacharacters are exactly what a forged flag hides behind. Not carved out: deciding which `*` is a glob and which is a forged flag is the "model one more construct" move that produced all three bugs of this class. Recorded in the CHANGELOG as a known over-block with a workaround. |

Direction is unchanged and remains the spec's: over-blocking is safe,
under-blocking is the bug (RD4). The refusal only ever *adds* blocks.

### Step 2 tracking issue

The three deferred items (case 26's T3/T4 vacuity and whether that divergence is
reachable at all; `gh`'s missing flag scan; `rg`'s unaudited flag inventory) are
filed as **https://github.com/Storreslara/AntiSlop/issues/185**, satisfying AC2.4.
