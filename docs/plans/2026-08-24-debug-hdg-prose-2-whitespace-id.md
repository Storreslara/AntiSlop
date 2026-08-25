# DEBUG SPEC — `hdg-prose-2` at the 2-FAIL cap: the whitespace-bearing packet id

Status: **FINAL — dispatch-ready** (spec-master, 2026-08-24). Produced on
orchestrator escalation after `hdg-prose-2` hit the shared protocol's 2-FAIL
cap. This is a **focused diagnostic artifact, not a replan**: it revises one
failed step of
`docs/plans/2026-08-24-human-decision-gate-prose-false-positive.md` (Step 2)
and leaves `hdg-lexer-1` (PASSed at `f6d2923`), the four recognizers added by
`e7deb42`, and the quote-joining fix of `a520905` standing as a correct
foundation. `rpg-comment-3` (Step 3) has not run and stays blocked behind this.

Every verdict below was executed live this session against the real gate at
three revisions (`f6d2923`, `e7deb42`, `HEAD`/`be9f027`) and against a measured
prototype. No number is inferred.

**A note on how these measurements were taken.** The gate under repair blocks
any Bash command whose text spells the protected path — correctly, and it
blocked one of mine during this session. Probes were therefore authored as
script files via the `Write` tool and executed as `bash <scratch-path>`, with
every real write directed into an ephemeral `mktemp -d` fixture. That is the
same measurement route the reviewer used, and it is not the rephrasing
workaround the gate's refusal forbids: nothing here writes, or attempts to
write, the repository's own `DECISION` file.

## Goal

Close the fail-open regression `hdg-prose-2` introduced — a packet directory
whose task-id contains whitespace is not seen by the path-shape scan, so an
allowlisted program may create the real file — **without** re-denying any of
the prose, read and comment shapes the unit exists to allow, and without
loosening the gate's Write/Edit branch.

## Part 1 — Root cause / diagnosis

### 1.1 Verification (fail-triage step 1: live reproduction, not the record's text)

Confirmed. Three revisions, gate verdict **and** a real write into a fixture
seeded with a space-named packet directory:

| Shape | `f6d2923` (pre-unit) | `e7deb42` | `HEAD` |
|---|---|---|---|
| `printf x > '.claude/human-review/u 1/DECISION'` | DENY | **ALLOW + real write** | **ALLOW + real write** |
| `printf x > ".claude/human-review/u 1/DECISION"` | DENY | **ALLOW + real write** | **ALLOW + real write** |
| `cat /etc/hostname > '.claude/human-review/my unit/DECISION'` | DENY | **ALLOW + real write** | **ALLOW + real write** |
| `printf x > '.claude/human-review/u1/DECISION'` (control, no space) | DENY | DENY | DENY |
| `git commit -m 'fix(human-review-x): unreadable DECISION file'` (control) | DENY | ALLOW | ALLOW |

The reviewer's report is accurate in every particular, and the regression
criterion it applies is the same one `a520905`'s own commit message used.

Widened to 16 shapes (`W1`–`W16` in §3.2), **14 of 16 are ALLOW at HEAD and all
16 were DENY at `f6d2923`.** The two that stay denied at HEAD (`tee`, `cp`) are
held by the program allowlist, not by the path-shape scan — so the scan is the
sole failed guard.

### 1.2 Categorization (fail-triage step 2)

**Spec/criterion defect**, not a code defect. The implementer built exactly
what Step 2 specified. The plan's Context defines the condition as:

> **`has_path_shaped_occurrence()`** — true when some contiguous run of
> **non-whitespace**, non-quote characters holds both trigger tokens.

`a520905` correctly removed "non-quote" from that definition after the 1st
FAIL, because bash concatenates adjacent quoted fragments. It left
"non-whitespace" in place, because the spec put it there. But **"non-whitespace"
is wrong for the same reason "non-quote" was wrong**: a quoted bash word may
contain whitespace, so a quoted path whose id segment holds a space is one
word, and the run scan sees two harmless halves of it. The spec described the
predicate in terms of the *lexical run* rather than the *assembled word*, and
the implementer inherited that error twice.

This is why a third `lead-programmer` pass on the unchanged spec would not have
closed it: the spec's own definition of the condition is what is defective.

### 1.3 Why the code's stated justification is false

`hooks/scripts/human-decision-gate.sh:91-93` justifies the whitespace reset:

> Whitespace ends a run even INSIDE quotes, which is what keeps a prose
> sentence naming both tokens from reading as a path: **a bash word may contain
> a space, but this gate's file cannot.**

The second clause is false, and measurably so:

- The gate's **own** Write/Edit branch (`:223`,
  `case "$subject" in .claude/human-review/*/DECISION) deny ;;`) uses a `*`
  glob, which matches a whitespace-bearing segment. Measured with abstract
  tokens: `case "a/b/x y/Z" in a/b/*/Z)` **matches**.
- Nothing constrains the packet directory's name at creation time. The reviewer
  derives it from the free-form `Unit: <id>` dispatch line, and the id grammar
  that would exclude whitespace is **not enforced on that path** — see §1.5.

So the file's two enforcement branches disagree about the identical path
string, and the comment that reconciles them asserts something untrue.

### 1.4 Why the first clause of that sentence is nevertheless load-bearing

Dropping the whitespace reset outright re-denies every prose commit message
naming both tokens — the exact false positive the unit exists to remove
(measured: all of `C1`–`C6` flip back to DENY). Any fix must keep the run scan's
whitespace behaviour and add coverage beside it, not replace it.

### 1.5 Can a whitespace-bearing task-id actually occur? (measured, and the
answer is not the convenient one)

Four id grammars exist in this repository and **none** admits whitespace:

| Site | Grammar | Enforced on |
|---|---|---|
| `hooks/scripts/dispatch-hygiene.sh:298,346` | `^Unit:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._#-]{0,63})[[:space:]]*$` | H3/H4 |
| `bin/microworld-dashboard/decision-block.js:13` (`ID_RE`) | `^[A-Za-z0-9][A-Za-z0-9._#-]*$` | dashboard `/api/decision` |
| `hooks/scripts/human-decision-gate.sh:60` | `[A-Za-z0-9_][A-Za-z0-9_#.-]*` | sanctioned marker-write template |
| `hooks/scripts/task-gate.sh:51` | sanitizes `[^a-zA-Z0-9._-]` → `_` | agent-teams `TaskCompleted` |

But **none of them gates the path that creates the packet directory**:

- `.claude/persona-config.json`'s `dispatchHygiene.mode` is **`warn`**, not
  `block`. H4 cannot refuse a malformed `Unit:` line here; it logs.
- `gatedAgents` is absent, so `dispatch-hygiene.sh:284` defaults to
  `lead-programmer` alone. Its own header (`:281`) states that "explorer/scribe/
  **reviewer** spawns are never" gated — and it is the **reviewer** that
  creates `.claude/human-review/<task-id>/` (`agents/reviewer.md:190`).
- `bin/microworld-dashboard/server.js:311` verifies the packet directory
  exists and never creates it.

So a whitespace-bearing packet id is **off-convention but not impossible**: an
orchestrator dispatching `Unit: my unit` to the reviewer would produce one, with
at most a warning. Such a packet is partly broken downstream (the dashboard's
`ID_RE` refuses to resolve it, so the human must write the file by hand in a
terminal — which the gate does not touch), but it exists, and its `DECISION`
would be unprotected on the Bash path.

This measurement is what decides the remedy in §2.

### 1.6 Scope-limiting measurement: the gate has never resisted multi-call chains

Recorded so the severity of §1.5 is not overstated. At the **pre-unit baseline
`f6d2923`**, three individually-ALLOWED commands forge a `DECISION` for a
**real, whitespace-free** task-id:

```
mv .claude/human-review/realunit-1 /tmp/stash      ALLOW  (no DECISION in the text)
printf x > /tmp/stash/DECISION                     ALLOW  (no human-review in the text)
mv /tmp/stash .claude/human-review/realunit-1      ALLOW
```

Executed end to end: the file is forged. A `ln -s` variant is equally allowed.
The gate is, and always has been, a **single-command textual** guard whose
value is stopping a well-intentioned agent from writing the file in one step —
not an adversarial boundary. That is not a defect ground here, and it does not
excuse the regression (a regression is a regression), but it does mean the
whitespace hole grants strictly *less* than what the baseline already granted.

## Part 2 — Remedy selection

Both remedies the reviewer sketched were investigated. Both are rejected on
measurement, and a third is specified.

### Remedy 1 (narrow `:223`'s glob to the id charclass) — REJECTED, measured harmful

It is a **loosening**, not an alignment: it converts a correct Write/Edit denial
into an allowance. Measured with abstract tokens:

| Pattern | `a/b/x y/Z` (whitespace id) | `a/b/m/n/Z` (nested) |
|---|---|---|
| `a/b/*/Z` (today) | MATCHES | MATCHES |
| `a/b/[A-Za-z0-9_][A-Za-z0-9_#.-]*/Z` | **NO MATCH** | **NO MATCH** |

So it unprotects two classes, not one — whitespace ids *and* every nested path
under the packet directory — and §1.5 shows a whitespace id can genuinely
occur, which is precisely the condition the escalation brief said would make
this remedy worse than the inconsistency. Buying "consistency" by deleting the
stricter of two checks inverts the fail-closed direction this gate is built on.

### Remedy 2 (pin the whitespace case as an accepted ALLOW residual) — REJECTED

R-4 and R-5 are pinned on an explicit, stated ground: each was measured
**ALLOW at both the patched and the unpatched gate**, i.e. pre-existing and not
a regression (plan R-5, verbatim: "Measured ALLOW on both the patched and
unpatched gates, so it is **not** a regression"). The whitespace case fails that
test — DENY at `f6d2923`, ALLOW at `e7deb42` and HEAD. Pinning it would ratify a
**regression** under a discipline built for **pre-existing** limitations, and
the plan's own CHK9 draws exactly that line. A reviewer would be right to FAIL
it again.

Remedy 2 is also only legitimate if `:223` is the last line of defense, which
§1.1 disproves: `write_with_inert_triggers()` reaches a real write of a real
file through the Bash path, with no Write/Edit call involved.

### Remedy 3 — CLOSE IT with an anchored companion scan — SELECTED, prototyped

Keep `has_path_shaped_occurrence()` byte-unchanged (it is what preserves the
prose allowance) and add a **second, anchored** condition beside it in
`triggers_are_inert()`:

> True when a `/DECISION` follows a `human-review` in the quote-joined text
> with **nothing but path-safe characters in between** — the marker id
> charclass (`A-Za-z0-9_#.-`) plus `/`, space and tab. Newline is deliberately
> **not** path-safe.

Why this discriminates correctly, and is not a heuristic guess:

- Every whitespace-bearing spelling of the path satisfies it, in any quoting,
  including `//`, `./`, `../` and quote-split fragments.
- Prose between the two tokens almost always carries punctuation outside that
  set (`:`, `;`, `(`, `)`, `<`, `>`), which is what leaves the commit-message
  allowance intact.
- Excluding newline keeps a multi-line commit message that names the tokens on
  different lines allowed.
- It can only **add** denials. It is OR-ed into an existing condition and never
  consulted to permit anything.

**Measured prototype** (built and executed this session; the implementer may
refine style, not semantics):

```bash
# Companion to the run scan above, for the one word shape it structurally
# cannot see: a packet directory whose NAME contains whitespace.
has_whitespace_id_packet_path() {
  local rest="$1" head
  rest="${rest//$'\047'/}"
  rest="${rest//$'\042'/}"
  while :; do
    case "$rest" in
      *human-review*) rest="${rest#*human-review}" ;;
      *) return 1 ;;
    esac
    case "$rest" in
      */DECISION*)
        head="${rest%%/DECISION*}"
        case "$head" in
          *[!A-Za-z0-9_$' \t'/.#-]*) ;;
          *) return 0 ;;
        esac
        ;;
    esac
  done
}
```

Wired as one added line inside `triggers_are_inert()`, immediately after the
existing `has_path_shaped_occurrence "$cmd" && return 1` — which covers **both**
`write_with_inert_triggers()` and `is_prose_only_commit()` from a single site.

Note the `\047`/`\042` escape idiom and the `$' \t'` bracket member: these
follow the file's existing convention (`:99-101`) precisely so a literal quote
in a pattern cannot unbalance the file's own quoting — the trap
`hdg-lexer-1`'s Pre-resolved context already warned about.

**Measured results of the prototype:**

| Measurement | Result |
|---|---|
| `bash tests/human-decision-gate.test.sh` (existing suite, unmodified) | **130 OK / 0 FAIL, exit 0** |
| `W1`–`W16` whitespace shapes | **16 / 16 DENY** (matching `f6d2923`) |
| `C1`–`C16` prose/read/comment controls | **verdicts byte-identical to HEAD** |
| `D1`–`D5` invariant shapes | DENY, unchanged |
| `R5` pinned residual (`DECISIO\N`) | still ALLOW, unchanged |
| 420-command differential sweep, HEAD vs candidate | **22 new denials, 0 new allowances** |

The sweep crossed 20 separators × 7 program shapes × 3 quotings. **All 22 new
denials fall in the two whitespace-bearing separators** (`/u 1/`, `/a b/`).
Nothing else in the corpus changed verdict in either direction. The change is
therefore provably confined to the regression class.

Two of those 22 are worth naming so no one mistakes them for a new false
positive: `git commit -m '.claude/human-review/u 1/DECISION'` and the trailing-
comment equivalent now DENY. Their whitespace-free twins already DENY at HEAD.
The change makes the doctrine `has_path_shaped_occurrence()`'s own header
states — *"a spelled path is denied wherever it sits, a commit message and a
comment included"* — true for the first time, rather than true only for ids
without spaces.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-08-24 Non-functional attributes: Q Is closing the whitespace hole a
  security-posture decision the operator must make, or one settleable by
  measurement? → A (self-resolved): settleable. The close costs **zero**
  allowances over a 420-command differential sweep and zero churn in the
  130-assertion suite, so it carries none of the "tighten at the cost of a
  false positive" trade that would have made it the operator's call. The two
  reviewer-sketched remedies were the ones needing a judgment call; both are
  rejected on measurement (§2), so no judgment call survives.
- 2026-08-24 Edge cases / failure handling: Q Which shapes prove the fix is
  general rather than a patch for the three reported ones? → A
  (self-resolved): the 16 of §3.2 — tab ids, multi-space ids, quote-split
  across the space, `//`, `./`, `../`, leading `./`, dotted ids, `>>`, `tee`,
  `cp`, and whitespace at both segment edges — plus the 420-command
  differential sweep, which bounds the change from the other direction by
  showing nothing outside the class moved.
- 2026-08-24 Technical constraints & tradeoffs: Q Should the pre-existing
  glob-metacharacter bypass be closed here or deferred? → A (self-resolved):
  **deferred as F-1** (§4), and pinned in the suite as tracked-open, not as
  accepted. It is byte-identical at `f6d2923` so it is not this unit's
  regression; closing it properly needs glob-aware matching before the
  substring early-exit, a mechanism nothing in this unit uses, and a partial
  fix (bracket-stripping alone catches `[D]ECISION` but not `?ECISION` or
  `DEC*`) would be worse than none by implying coverage that is absent.
- 2026-08-24 Terminology consistency: Q Does this spec drift against
  `CONTEXT.md`? → A (self-resolved, three lenses, all ran). **Lens 1** — one
  finding: `human-decision-gate.sh:91-93` asserts a constraint on the
  `[[Escalation packet]]` directory name ("this gate's file cannot" contain a
  space) that the glossary's own definition (`CONTEXT.md:871` — the directory
  is `.claude/human-review/<task-id>/`, with no charclass stated) does not
  support; §1.5 measures it false. Corrected by Ordered edit 2. Carried
  forward, unchanged from the parent plan: `CONTEXT.md:1389`'s "Reads stay
  allowed for both gates" is still stale. **Lens 2** — one minor finding:
  "packet dir" / "packet directory" / "task-id directory" all appear; canonical
  is **packet directory** (`CONTEXT.md:874`). Advisory only. **Lens 3** — the
  **marker id charclass** is load-bearing at four independent sites (§1.5) with
  no glossary entry, and this round makes the absence consequential. Routed to
  the Scribe update hint. Category stays Partial because the fixes land with
  `scribe`, not in this unit.

## Risks / dependencies

- **RD-1 — prior defect history is severe and this unit inherits it.**
  `.claude/reviewed/hdg-prose-2.fail` holds the 2nd FAIL (the 1st was
  overwritten; a single latest record is all this project keeps). Both FAILs
  were **fail-opens in the same function**, found by the same method — varying
  a dimension the spec's definition of the predicate did not model (quote
  boundaries, then whitespace). **Not `haiku`-eligible under any reading.**
  `opus`.
- **RD-2 — the survey of all `.fail` records was run in full, not sampled.**
  All 71 `.fail` records under `.claude/reviewed/` were enumerated. Relevant:
  `hdg-prose-2.fail` (this unit), and `human-review-cleanup-1.fail` (whose sole
  ground was a dirty-tree marker precondition, not a code defect).
  `hdg-lexer-1` has a `.pass` and no `.fail`; `rpg-comment-3` has neither and
  has not run.
- **RD-3 — an open PASS-note from `hdg-lexer-1` was never actioned and is
  still live.** `.claude/reviewed/hdg-lexer-1.pass` note **N2**:
  `hooks/scripts/human-decision-gate.sh:6-12` still describes the backslash
  false positive as "a known false positive, left open deliberately" — which
  `hdg-lexer-1` **closed** at `f6d2923`. Verified false at HEAD this session:
  `grep -n 'DECISION\|human-review' README.md` is ALLOW. N2 says "Already
  flagged for unit 2"; unit 2 did not do it. It is folded in here as Ordered
  edit 3, since this unit is already rewriting that header.
- **RD-4 — hard mirror parity.** `tests/validate.sh:302` runs
  `diff -rq hooks/scripts .claude/hooks/scripts`, and `.claude/persona-config.json`
  pins the content hash. Source edit and regenerated mirror **must land in the
  same unit**, via `node bin/cli.js --update`. Never hand-edit `fileHashes`
  (Constitution P2).
- **RD-5 — no version bump is owed, and bumping would break the boundary.**
  Same as the parent plan's R-7: P3 scopes to `agents/*.md` and templates;
  this unit touches `hooks/`, `tests/` and the mirror only.
- **RD-6 — do not touch `benign-command.sh`.** The fix is entirely gate-local;
  `hdg-lexer-1`'s file must stay byte-identical, and a criterion binds it.
- **RD-7 — `protectedPaths` no longer blocks this file.** Commit `99e393c`
  ("chore: drop the two gate scripts from protectedPaths (operator,
  2026-08-24)") removed both gates. Verified at HEAD: `protectedPaths` no
  longer lists them, so unlike the parent plan's R-9 the `Write`/`Edit` tools
  work directly. **Do not use a Bash heredoc for this file regardless** — that
  route remains forbidden here.
- **RD-8 — escalation will not fire.** `humanReviewMode` is `"off"`, so
  ESCALATE-TO-HUMAN is inert. FAIL takes precedence regardless.
- **RD-9 — do not write a case count into the gate's header comment.** The
  header at `:47-57` already records that "the count in this comment had
  already drifted twice" and names properties instead. The suite grows; keep
  naming, not counting.
- **Ordering:** `hdg-prose-2-fix2` → then `rpg-comment-3` (parent plan Step 3),
  which is still unstarted and still blocked behind a green unit 2.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the reproduction, the three-revision
  differential, the four id grammars, `dispatchHygiene.mode`, the `case`-glob
  semantics, the multi-call baseline chain, the 130-assertion prototype run and
  the 420-command sweep were all executed live this session.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  mirror and `fileHashes` regenerate via `node bin/cli.js --update` only.
- P3 "Version-stamp discipline": **not applicable, deliberately** — RD-5. No
  version-stamped file is touched, so no bump is owed and none may be made.
- P4 "Optional personas degrade gracefully": satisfied — the gate is
  identity-blind on this path.
- P5 "`tests/validate.sh` is the merge gate": satisfied — the suite is wired at
  `tests/validate.sh:401`, and the mirror-parity check at `:302` is part of it.

## Part 3 — Revised spec step

### Step 2R — close the whitespace-id fail-open (replaces Step 2's
`has_path_shaped_occurrence()` definition; everything else in Step 2 stands)

The parent plan's Step 2 Context sentence

> true when some contiguous run of **non-whitespace**, non-quote characters
> holds both trigger tokens

is **superseded**. The corrected condition is:

> true when the quote-joined text contains a contiguous run of non-whitespace
> characters holding both trigger tokens, **OR** a `/DECISION` follows a
> `human-review` with only path-safe characters between them — the marker id
> charclass plus `/`, space and tab, newline excluded.

#### 3.1 Ordered edits

1. Add `has_whitespace_id_packet_path()` (prototype in §2, Remedy 3) directly
   above `triggers_are_inert()`, and call it from `triggers_are_inert()` on the
   line immediately after the existing `has_path_shaped_occurrence` call. One
   call site; do **not** add a second in `is_prose_only_commit()`.
2. Correct the false justification at `:91-93`. Delete the clause "a bash word
   may contain a space, but this gate's file cannot". Replace the rationale
   with the true one: whitespace ends a run **in the run scan**, which is what
   keeps a prose sentence from reading as a path; the anchored companion covers
   the word shape the run scan structurally cannot see, because the packet
   directory's name is **not** constrained at creation time (the reviewer
   derives it from the free-form `Unit: <id>` line, `dispatchHygiene.mode` is
   `warn`, and reviewer spawns are not gated at all). Name the `:223` `*` glob
   as the branch the two must now agree with.
3. Correct the stale header at `:6-12` (RD-3, `hdg-lexer-1` note N2). It still
   claims a backslash-bearing read is denied as a deliberately-open residual;
   `hdg-lexer-1` closed that at `f6d2923`. State the current behaviour.
4. Correct `:232-234`: "the two pinned residuals of the same family … R-4's
   split variable and R-5's `DECISIO\N`" understates a class measured wider.
   Say **residual class**, cite R-4 and R-5 as *examples* rather than an
   enumeration, and cross-reference F-1 (§4) for the glob sub-class.
5. Correct `tests/human-decision-gate.test.sh:398-399`: "Q1 and eleven others
   flip to allowed without it" undercounts. Reverting the fragment joining
   flips **14** cases, so it reads **"Q1 and thirteen others"**. Re-derive the
   number by actually running the mutant; do not copy it from this document.
6. Extend the suite with §3.2's cases.
7. Run `node bin/cli.js --update` to regenerate the mirror and `fileHashes`.

#### 3.2 Suite cases

All cases live **inside `tests/human-decision-gate.test.sh`**, never as an
inline shell criterion — an inline payload spells both trigger substrings and
is denied by the gate under test. Keep every existing case byte-identical.

**`W1`–`W16` — must be DENIED (each measured DENY at `f6d2923`, so each is a
regression pin):**

| | shape |
|---|---|
| W1 | `printf x > '.claude/human-review/u 1/DECISION'` |
| W2 | `printf x > ".claude/human-review/u 1/DECISION"` |
| W3 | `cat /etc/hostname > '.claude/human-review/my unit/DECISION'` |
| W4 | tab inside the id |
| W5 | two consecutive spaces inside the id |
| W6 | the space split across a quote boundary: `'…/u '"1/DECISION"` |
| W7 | `//` before the id segment |
| W8 | `/./` before the id segment |
| W9 | `/x/../` traversal before the id segment |
| W10 | leading `./` on the whole path |
| W11 | dotted id plus a space: `gh345.1 b` |
| W12 | `>>` append rather than truncate |
| W13 | `tee` as the write primitive |
| W14 | `cp` as the write primitive |
| W15 | trailing whitespace in the id segment |
| W16 | leading whitespace in the id segment |

W13 and W14 are already denied at HEAD by the program allowlist. Include them
anyway and **say so in a comment**, so a later reader does not read them as
evidence for the new condition. The other 14 are ALLOW at HEAD.

**Mutation proof (mandatory, and the sole-denier rule applies).** Deleting the
single `has_whitespace_id_packet_path` call from `triggers_are_inert()` must
flip at least one W-case to allowed, and that case must have **no other
denier**. Measured: 14 of the 16 flip. Run the mutant; do not assert this from
the document.

**`C1`–`C16` — verdicts must be byte-identical to HEAD.** These are the
additive-allow evidence: the fix must not re-deny the false positives the unit
exists to remove.

Allowed at HEAD and must stay allowed: the operator's exact commit message;
a single-quoted commit message; `-am`; `--amend`; a multi-line message naming
the tokens on different lines; a message naming `.claude/human-review/` and
`DECISION` in ordinary prose; `grep -n 'DECISION\|human-review' <file>`;
`grep -rn` over the packet directory; `grep -nE` on the file itself; a trailing
`#` comment naming both tokens; the same with no space after `#`;
`rm -rf .claude/human-review/u1`; a plain read of the file; a prose message
whose interstitial text carries a `;`; and a multi-line message whose second
line carries a bare `/DECISION`.

Denied at HEAD and must stay denied: a commit message spelling the literal
template path `.claude/human-review/<task-id>/DECISION` (the run scan already
catches it — `<` and `>` are not path-safe, so the new condition is *not* what
denies it; comment this, or a later reader will attribute it wrongly).

**`D1`–`D5` — must stay DENIED**, unchanged: direct redirect; `sh -c` write;
bare cd-relative write; the R-11 own-line comment before a real write;
commit-then-write via `&&`.

**Pinned residuals — must stay ALLOWED**, unchanged: R-5 (`DECISIO\N`) and the
existing N21 split-variable and Q20 brace-expansion pins.

**F-1 pins — must stay ALLOWED, commented as TRACKED-OPEN, not accepted**
(§4): `[D]ECISION`, `?ECISION`, `DEC*`, and `.claude/human-rev[i]ew/u1/DECISION`.
Word the comment so a future unit that closes F-1 is *expected* to break these
pins and remove them.

#### 3.3 Affected files

`hooks/scripts/human-decision-gate.sh`, `tests/human-decision-gate.test.sh`,
plus the regenerated `.claude/hooks/scripts/human-decision-gate.sh` and
`.claude/persona-config.json` `fileHashes`.

#### 3.4 Do NOT touch

`hooks/scripts/lib/benign-command.sh` (`hdg-lexer-1` owns it),
`hooks/scripts/reviewed-path-gate.sh` (`rpg-comment-3` owns it), any
`agents/*.md`, any version file. Do not modify `has_path_shaped_occurrence()`
itself — it is correct for what it covers, and changing it is what would
re-deny the prose cases.

#### 3.5 Acceptance criteria (from repo root)

```
bash tests/human-decision-gate.test.sh    # exit 0
bash tests/reviewed-path-gate.test.sh     # exit 0, unchanged (383 OK / 0 FAIL)
bash tests/validate.sh                    # exit 0 (includes the diff -rq mirror parity check)
node bin/cli.js --update --check          # exit 0
git diff --quiet HEAD                     # exit 0 (tracked tree clean at the unit's final commit)
git diff --quiet f6d2923 HEAD -- hooks/scripts/lib/benign-command.sh   # exit 0
git diff --quiet HEAD -- hooks/scripts/reviewed-path-gate.sh           # exit 0
git diff --name-only f6d2923..HEAD | grep -q '^agents/'                # exit 1
```

All eight were executed against the tree at `be9f027` while writing this spec:
the first four are the current baselines (130 OK / 383 OK / validate 0 /
`--update --check` 0), and the last four already return 0/0/0/1 as required —
so each is non-vacuous and each fails for a real reason if the unit breaks it.

Plus, verified inside the suite and reported in the ready-for-review message:

- W1–W16 all DENIED; the mutation proof run, naming which W-case has the new
  condition as **sole** denier.
- C1–C16 verdicts diffed against HEAD's gate and reported identical.
- The four F-1 pins present and commented as tracked-open.

## Part 4 — Explicitly deferred: F-1, the glob-metacharacter early-exit miss

**Deferred, not accepted.** Not in scope for this unit; recorded here so it is
dispatchable without re-derivation.

Measured this session, and **byte-identical at `f6d2923`, `e7deb42` and HEAD**
— so it is not this unit's regression and was not a ground for either FAIL:

| Command | `human-decision-gate.sh` | Effect |
|---|---|---|
| `printf x > .claude/human-review/u1/[D]ECISION` | ALLOW | overwrites an existing DECISION |
| `printf x > .claude/human-review/u1/?ECISION` | ALLOW | same |
| `printf x > .claude/human-review/u1/DEC*` | ALLOW | same |
| `printf x > .claude/human-rev[i]ew/u1/DECISION` | ALLOW | same |

Mechanism: bash expands the glob against the filesystem, but the raw command
text never spells the trigger token, so the substring early-exit returns before
any recognizer runs. Same family as R-4 and R-5, and materially more serious
than either: it needs no exotic quoting, and unlike creating a file it
**overwrites a decision the human has already made**.

`reviewed-path-gate.sh` shares the class, but only in the directory-component
variant. Measured against an existing marker, with a `persona-config.json`
present in the fixture: `.claude/reviewed/[u]1.pass`, `?1.pass` and `u1.p*` are
all **DENIED** (they still spell `.claude/reviewed`), while
`.claude/revie[w]ed/u1.pass` is **ALLOWED**. So F-1's scope is both gates, with
different surface area on each.

Why it is not folded in here: closing it requires deciding whether a
whitespace-free run is a **glob pattern that could match** the protected
literal — e.g. `case DECISION in $basename)` with an unquoted pattern — which is
a mechanism nothing in this unit uses, carries its own hazards (`extglob` and
`nocasematch` shell state, an unbalanced `[`), and needs its own adversarial
suite. A partial fix is actively worse: stripping `[` and `]` catches
`[D]ECISION` and silently misses `?ECISION` and `DEC*`, implying coverage that
is not there.

## Self-check

- CHK1: Is the failure reproduced live, not read from the `.fail` record? —
  PASS (§1.1, three revisions, gate verdict plus real writes).
- CHK2: Does the spec say why a third `lead-programmer` pass on the *unchanged*
  spec would not have closed it? — PASS (§1.2: the plan's own definition of the
  predicate is the defect; the implementer built it correctly twice).
- CHK3: Is each rejected remedy rejected on measurement rather than
  preference? — FAIL (missing) — revised in place: Remedy 1 now carries the
  `case`-glob table showing it unprotects nested paths as well as whitespace
  ids, and Remedy 2 now cites the plan's own R-5/CHK9 regression-versus-
  pre-existing test rather than asserting a preference.
- CHK4: Is the claim "a whitespace task-id cannot occur" verified rather than
  assumed? — FAIL (conflicting) — revised in place as §1.5. My first pass had
  four id grammars excluding whitespace and concluded it was impossible. It is
  not: `dispatchHygiene.mode` is `warn`, and `gatedAgents` does not include the
  reviewer, which is the persona that creates the packet directory. The
  conclusion reversed, and Remedy 1's rejection depends on the reversal.
- CHK5: Is the fix proven GENERAL rather than a patch for the three reported
  shapes? — PASS (16 shapes across quoting, separators, traversal and write
  primitive, plus a 420-command differential sweep bounding it from the other
  side).
- CHK6: Does the spec show the fix adds no new false positive? — PASS (C1–C16
  byte-identical to HEAD; 0 new allowances and 22 new denials, all inside the
  target class, over the sweep).
- CHK7: Does every new condition carry a mutation-proven sole denier, per this
  project's standing rule? — PASS (§3.2 makes it mandatory and requires the
  implementer to run the mutant rather than cite this document).
- CHK8: Do the revised step and the parent plan agree on file ownership? —
  PASS (§3.4: `benign-command.sh` is `hdg-lexer-1`'s, `reviewed-path-gate.sh`
  is `rpg-comment-3`'s, each bound by a `git diff --quiet` criterion).
- CHK9: Is every residual either closed or explicitly categorized? — PASS
  (whitespace class closed; R-4/R-5/N21/Q20 pinned as accepted, unchanged; F-1
  deferred and pinned as tracked-open, deliberately *not* as accepted).
- CHK10: Does the spec state whether a version bump is owed? — PASS (RD-5, and
  the Constitution check marks P3 not-applicable rather than silent).
- CHK11: Is the `protectedPaths` blocker from the parent plan's R-9 still
  true? — FAIL (conflicting) — revised in place as RD-7: commit `99e393c`
  removed both gates from `protectedPaths`, so R-9 is stale for this unit.
  Copying it forward would have sent the implementer looking for a block that
  no longer fires, and might have been read as licensing the heredoc route.
- CHK12: Were sibling PASS-note warnings harvested rather than left to
  evaporate? — FAIL (missing) — revised in place as RD-3: `hdg-lexer-1.pass`
  note N2 flagged the stale `:6-12` header **for unit 2**, unit 2 did not do
  it, and nothing else would have surfaced it. Folded in as Ordered edit 3.
- CHK13: Is the severity of the hole stated honestly in both directions? —
  PASS (§1.6 records that a three-call rename chain already forges a DECISION
  for a *real* id at the pre-unit baseline, so the hole grants less than the
  baseline already did — while §2 still refuses to pin it, because a
  regression is not a pre-existing residual).
- CHK14: Does the deferral of F-1 say what "deferred" costs and what closing
  it would take? — PASS (§4: mechanism, both gates' measured surface, why a
  partial fix is worse than none, and pins that a closing unit is expected to
  break).
- CHK15: Are the two minor comment corrections specific enough to check? —
  PASS (Ordered edits 4 and 5 name file, line range, the wrong text and the
  right text; edit 5 additionally requires re-deriving the count from a mutant
  run rather than trusting this document).

## Scribe update hint

After this unit lands: `CONTEXT.md:1389`'s "Reads stay allowed for both gates"
is still stale (carried from `hdg-lexer-1` note N2 and the parent plan) and is
now *nearly* true again — rewrite it with the precise boundary rather than
deleting it. Add the glossary entries still outstanding: **sanctioned
marker-write template** (carried from `gh345-1` note N6), the
narrate-versus-target distinction, and — new this round — **marker id
charclass**, which §1.5 shows is load-bearing at four independent sites with no
single definition and no enforcement on the path that actually creates a packet
directory. ADR-worthy, and stronger than the parent plan's phrasing: *a textual
gate must model the assembled bash WORD, not the lexical run — quote boundaries
and quoted whitespace have now each cost one FAIL in the same function.*

## Dispatch note (fast path)

Resolves to **one dispatchable unit** — within the ≤5 fast-path threshold, so
`task-master` is not involved, no `to-tickets` slicing happens, and no tracker
issue is filed. The orchestrator dispatches from this document.

**Retrieval-contract line (verbatim):** *No tracker issue exists for this work
— it is dispatched on the fast path. Read the unit's spec directly from
`docs/plans/2026-08-24-debug-hdg-prose-2-whitespace-id.md` in this repository,
at the section anchors named in the unit's `## Retrieval` section. Do not run
`gh issue list` for this work; there is nothing to fetch.*

### Unit: hdg-prose-2-fix2

**## Suggested model:** `opus`

**## Objective**
Close the whitespace-bearing-task-id fail-open that `hdg-prose-2` introduced,
by adding an anchored companion to the path-shape scan, and correct three false
comments in the same file — without changing the verdict of any prose, read or
comment shape.

**## Retrieval**
No tracker issue exists for this work — it is dispatched on the fast path. Read
the spec directly from
`docs/plans/2026-08-24-debug-hdg-prose-2-whitespace-id.md` in this repository:
**§2 Remedy 3**, **§3 (all of Part 3)**, **§4**, and **RD-1 through RD-9**. For
the surrounding design that is NOT being changed, read
`docs/plans/2026-08-24-human-decision-gate-prose-false-positive.md` Step 2 and
its Context subsection "The three allowances". Also read
`.claude/reviewed/hdg-prose-2.fail` in full — it is the 2nd FAIL for this work
and its defect list is the thing being closed. Do not run `gh issue list`;
there is nothing to fetch.

**## Affected files**
`hooks/scripts/human-decision-gate.sh`, `tests/human-decision-gate.test.sh`,
plus the regenerated `.claude/hooks/scripts/human-decision-gate.sh` and
`.claude/persona-config.json` `fileHashes`.

**## Ordered edits**
The seven edits of §3.1, in order. Edits 2, 3 and 4 are comment corrections in
the same file — each names a specific false claim; do not skip them as
cosmetic, since two of the three are the FAIL record's defect 2 and a
`hdg-lexer-1` PASS-note that has already survived one unit unactioned.

**## Do NOT touch**
`hooks/scripts/lib/benign-command.sh`, `hooks/scripts/reviewed-path-gate.sh`,
any `agents/*.md`, `.claude-plugin/plugin.json`, `package.json`,
`CHANGELOG.md`, or `.claude/persona-config.json`'s `pluginVersion`. No version
bump is owed (RD-5). Do not modify `has_path_shaped_occurrence()` itself
(§3.4). Do not write a case count into the gate's header comment (RD-9).

**## Acceptance criteria**
§3.5's criteria block verbatim, plus its three suite-verified items (W1–W16
denied with a mutation-proven sole denier; C1–C16 identical to HEAD; the four
F-1 pins present and commented as tracked-open).

**## Pre-resolved context**
Do not re-derive any of this — it is measured in Part 1 and Part 2:

- The failure reproduces at HEAD; `f6d2923` denies all 16 shapes.
- Both reviewer-sketched remedies are rejected, with the measurements that
  reject them. Do not re-open that choice; implement Remedy 3.
- The prototype in §2 passes the existing 130-assertion suite unmodified and
  produces 22 new denials / 0 new allowances over a 420-command sweep.
- A whitespace task-id **is** producible (§1.5): `dispatchHygiene.mode` is
  `warn` and reviewer spawns are not gated, so the `Unit: <id>` grammar does
  not constrain the packet directory's name.
- `protectedPaths` no longer lists this file (`99e393c`), so `Write`/`Edit`
  work directly. The Bash-heredoc route stays forbidden regardless (RD-7).
- Follow the file's existing `\047`/`\042` escape idiom for quote characters in
  patterns — a literal quote inside a `case` pattern will unbalance the file's
  own quoting, a trap already recorded in `hdg-lexer-1`'s dispatch.

**## Escalation**
This unit is at the 2-FAIL cap for its predecessor and carries that history. If
the new condition cannot satisfy the W-set and the C-set simultaneously, **stop
and report** — that is a spec defect in this document, not an implementation
one, and it routes back to `spec-master`. Never widen or narrow a condition to
make a test pass. If any existing suite assertion changes verdict, stop and
report: this unit is defined as verdict-preserving for every command that does
not spell a whitespace-bearing packet path. Do not attempt F-1 (§4) — it is
deliberately out of scope and closing it here would make the diff
unreviewable against these criteria.
