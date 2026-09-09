# Debug spec — `harness-integrity-gate-hardening` (2-FAIL cap escalation)

Status: FINAL — ready for dispatch
Date: 2026-09-09
Unit under diagnosis: `harness-integrity-gate-hardening`
Prior attempts: `c71ed27` (attempt 1), `341ec67` (attempt 2)
Latest FAIL record: `.claude/reviewed/harness-integrity-gate-hardening.fail` (2026-09-09T20:47:49Z)

This is a **debug spec**, not a replan. The original goal — harden
`set_a_mentioned()`'s Set A glob-detection fallback in
`hooks/scripts/harness-integrity-gate.sh` — stands unchanged. Scope is
bounded to that fallback and to the claims made about it.

---

## Goal

Bring the gate's glob-detection fallback and the claims made about it into
exact agreement, by (a) closing the one remaining reachable hole that sits
**inside a family attempt 2 already claims closed**, and (b) replacing every
unbounded universal claim about the gate with a bounded, enumerated,
machine-checked family table.

---

## Context

### fail-triage step 1 — VERIFY (live reproduction, not a re-read of the record)

Re-ran the acceptance surface fresh against the shipped gate at `341ec67`.

- `bash tests/harness-integrity-gate.test.sh` → exit 0, "All
  harness-integrity-gate tests passed." (62 cases, both mutation controls green)
- `bash tests/validate.sh` → previously reported exit 0 by the reviewer;
  the gate suite it invokes at `tests/validate.sh:337-341` passes.
- Mirror parity holds: both copies at sha256 `3e8d93dc…`, matching the single
  `fileHashes` entry for `.claude/hooks/scripts/harness-integrity-gate.sh`.

**FAIL #2's cited family reproduces — confirmed ALLOWED** (probed via the
gate's own piped-JSON invocation). All four reviewer spellings, plus two I
added that the reviewer did not test:

```
ALLOWED | cd .claude; rm -f persona-config.json
ALLOWED | cd .claude && git add persona*.json
ALLOWED | git -C .claude add persona*.json
ALLOWED | a=.claude; b=persona-config.json; git add $a/$b
ALLOWED | pushd .claude >/dev/null; rm persona-config.json; popd     <-- new
ALLOWED | (cd .claude; git checkout -- persona*.json)                <-- new
```

The four families attempt 2 claims closed **are** genuinely closed — verified
directly, not taken on trust (anchoring/metachar, backslash-escape,
depth-1 brace, absolute/`$VAR`/assignment-prefixed: all BLOCKED, exit 2).

### The finding neither review pass caught

The prior review flagged the non-recursive brace-collapse loop as a
roast-level cosmetic note ("can leave stray unmatched `{`/`}` on nested
braces"). **It is not cosmetic. It is a live, reachable bypass inside the
brace family that `341ec67`'s own commit message claims to have closed.**

Measured, both halves:

```
$ for x in .claude/{persona-config,{x,y}}.json; do echo "$x"; done
  .claude/persona-config.json      <-- bash really does produce the protected file
  .claude/x.json
  .claude/y.json

ALLOWED | git add .claude/{persona-config,{x,y}}.json
ALLOWED | git add .claude/{persona-config,{x,y}}.json    (second nesting shape too)
```

Cause: the collapse loop is correct only at nesting depth 1. On a nested
group it consumes the outer `{` and the *inner* `}`, leaving a stray literal
`}` in the pattern, which then fails the match:

```
.claude/{persona-config,x}.json      ->  .claude/*.json     -> matches   -> BLOCKED
.claude/{persona-config,{x,y}}.json  ->  .claude/*}.json    -> no match  -> ALLOWED
.claude/{{persona-config,q},x}.json  ->  .claude/*,x}.json  -> no match  -> ALLOWED
```

This is the deciding fact for scoping below: it is not a new family, it is an
**incomplete closure of a claimed-closed family**, and it is squarely inside
this unit's stated scope.

### fail-triage step 2 — CATEGORIZE

**Spec/criterion defect**, not a code defect — with one code-defect rider.

The FAIL ground itself (a memory note asserting a universal its own code does
not hold) is a documentation-truthfulness defect, and the reviewer's own
instruction was explicit: *"Do not fix by widening the gate in this unit."*
But the nested-brace hole above is a plain code defect inside the existing
claim, so this unit carries both.

### Prior-defect history and marker sweep

- `.claude/reviewed/harness-integrity-gate-hardening.fail` — exactly one
  record exists at that path (a second FAIL overwrites the first; there is no
  append/rotation mechanism), so the record read here is FAIL #2. FAIL #1's
  content is available only through the escalation summary and `c71ed27`.
- `bash bin/marker-audit.sh . --notes --surface=hooks/scripts/harness-integrity-gate.sh`
  → `markers=317 spec=0 code=0 untagged=1 malformed=3`. The single untagged
  note is gh418's line-forging analysis (`…gate.sh:154` scrubs with `tr`; no
  printf-format vector; "No residual injection vector found") — **disposition:
  informational, already resolved, no action in this unit.** No `NOTE[spec]`
  entries. The same sweep over `tests/harness-integrity-gate.test.sh` returned
  nothing.
- Sweep caveat per protocol: `.claude/reviewed/` is gitignored, untracked,
  per-clone state. An empty sweep is not proof a note never existed.

### Terminology (advisory, `antislop:ubiquitous-language` prose mode)

Glossary read once at `CONTEXT.md` and reused across both check points.

- Lens 1 (glossary term used with a different meaning): nothing found.
- Lens 2 (new synonym for a defined term): nothing found.
- Lens 3 (load-bearing new domain term, no glossary entry): **"Set A" / "Set B"
  have no `CONTEXT.md` glossary entry** despite being load-bearing across this
  gate, its tests, and two plan docs — `CONTEXT.md` mentions the gate only
  incidentally at lines 2244 and 2297. "bypass family" and "documented
  residual", introduced by this spec, are likewise undefined. Suggested for
  `scribe`; advisory only, blocks nothing.

Caveat carried from prior sessions: `CONTEXT.md`'s gate glossary has known
wrong entries elsewhere — do not treat it as authority for gate behavior.

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
9. Completion / acceptance signals: Missing

- 2026-09-09 Functional scope & success criteria: Q Is the unit's scope "close
  every bypass a reviewer can find" or a fixed enumerated list? → A
  (self-resolved): a fixed enumerated family table, frozen in this spec and
  encoded as a test table. This is the direct remedy for the root cause; see
  Diagnosis.
- 2026-09-09 Non-functional attributes: Q Does the brace-collapse fix risk the
  hot-path perf budget the C2.3 pin protects? → A (self-resolved): no — the
  collapse sits in the already-cold per-chunk branch, reached only for
  `.claude`-containing chunks. Termination at nesting depth 200 measured
  instant. Pinned anyway by AC10.
- 2026-09-09 Edge cases / failure handling: Q Is the nested-brace stray-brace
  issue cosmetic (as the roast framed it) or reachable? → A (self-resolved):
  reachable and demonstrated — bash expands the spelling to the protected file
  and the gate allows it. Promoted from roast note to in-scope code defect.
- 2026-09-09 Edge cases / failure handling: Q Is the new over-block on
  unrelated `.claude`-suffixed directories (`rm -rf ~/.claude/*`) acceptable? →
  A (self-resolved): accept as fail-closed, but **pin it with a test** so it is
  intentional rather than accidental. It was introduced by `341ec67`'s
  re-anchoring and is currently undocumented.
- 2026-09-09 Technical constraints & tradeoffs: Q Fix the
  working-directory-relative family now, or document it as a residual? → A
  (self-resolved): **document as a named residual; do not fix in this unit.**
  Reasoning in Risks R1. Reversible — see Open Questions 1.
- 2026-09-09 Completion / acceptance signals: Q What signal ends this unit, given
  two prior passes each found "one more" bypass? → A (self-resolved): the family
  table in AC1 is exhaustive by construction — every row is either closed
  (BLOCKED) or a named residual (ALLOWED, documented). A spelling outside the
  table is out of scope for this unit by definition, not a FAIL ground.

---

## Root-cause diagnosis

Two attempts each "closed the glob-detection hole" and each left something
open. Three distinct causes, in order of leverage.

### RC1 — The unit had no closure condition, so no attempt could ever satisfy it (primary)

Neither attempt was ever given an enumerated list of what "closed" means. The
acceptance criterion was effectively *"no bypass exists"* — an unbounded
universal over an infinite input space (arbitrary shell text). A reviewer
testing an unbounded universal only ever needs **one** counterexample, and for
a text-scanning gate over shell syntax there is always one more: `cd`,
`pushd`, `-C`, `$VAR` splitting, `eval`, command substitution, base64. So the
loop is structural, not a failure of diligence by either attempt. This is
exactly the read the escalation proposed, and the evidence supports it: each
attempt closed strictly more than the last (1 family → 4 families) and each
still FAILed.

The tell is in the artifact itself. Attempt 2's memory note escalates to a
**bolded universal** — "any spelling that still contains the literal substring
`.claude` and would expand to a protected file is detected. That is the whole
claim" — with a single named exception. A universal with one exception is not
a bounded claim; it is the same unbounded criterion restated, and it is
falsified by exactly one counterexample. FAIL #2 supplied it.

**Remedy:** invert the quantifier. Replace "no bypass exists" with an
enumerated table of families, each row carrying an expected verdict, encoded
in the test suite so the claim and the code cannot drift. A spelling outside
the table is then out of scope by construction rather than a fresh FAIL.

### RC2 — The test suite grew by example, so a depth-1-only transform passed 62/62

Attempt 2 expanded coverage impressively along the axes it could see — 9 Set A
literals × 2 glob spellings × 6 command shapes — but every one of those 62
cases is a **syntactic example**. None tests an *algebraic property of the
normalizer itself*. The brace-collapse loop is correct at depth 1 and wrong at
depth ≥2; no example in the suite used depth 2, so the suite reported 62 OK /
0 FAIL over a transform with a live hole in it.

Example-count is not the same as coverage. The property that would have caught
this in one line is an invariant on the transform's output:

> after collapse, the candidate pattern contains no `{` and no `}`

The shipped code violates that invariant on any nested input, and the
violation is precisely the bypass. This is the second-order lesson from
`c71ed27` → `341ec67`: attempt 2 diagnosed *"the match was anchored wrong"* and
fixed four anchoring/normalization inputs, but never asked whether each
normalization reaches a fixpoint.

**Remedy:** AC4 adds fixpoint/invariant criteria on the normalizer alongside
the example rows, and AC3 adds a reachability precondition so a BLOCKED row is
only credited when the spelling provably expands to a protected path.

### RC3 — The claim lived only in prose, so nothing could mechanically falsify it

The FAIL ground is a sentence in a markdown memory note. No test, hook, or
check reads that note. Attempt 2 corrected the sentence by hand and it went
stale again within the same commit that wrote it — because the code it
describes was changing in that same commit and nothing tied the two together.
Prose that describes code, and is verified only by a human reading both, will
drift on exactly the commits where accuracy matters most.

**Remedy:** AC7 makes the family slugs a shared token between the test table
and the memory note, greppable in both directions; AC6 makes unbounded
universal phrasing itself a check-failure rather than a matter of taste.

### Category (fail-triage step 2)

**Spec/criterion defect** (RC1, RC3) with a **code-defect rider** (RC2's
nested-brace hole). Routes to a corrected spec — this document — whose single
unit carries both halves.

---

## Risks and dependencies

- **R1 — Deferring the working-directory-relative family is a deliberate
  security tradeoff.** The family is real, trivially discoverable, and one
  spelling was proven destructive in a scratch repo. Deferring it anyway,
  because: (a) the reviewer explicitly instructed not to widen the gate in
  this unit; (b) it is **pre-existing and not a regression** — verified
  identical at `35df52e`, so no attempt made anything worse; (c) it is a
  different failure axis from this unit's stated goal — it is a
  *working-directory modelling* defect, not a *glob-detection* defect, and
  closing it means the gate begins modelling shell execution semantics
  (`cd`/`pushd`/`-C`/subshell scoping/variable expansion) on a hook that fires
  on **every Bash call in the session**; (d) bundling an unrelated
  architectural widening into a unit already at its 2-FAIL cap is the very
  pattern that produced the cap. It gets a named residual entry here and a
  follow-up spec of its own — it is not being dropped.
- **R2 — Nested-brace fix is a widening, and could be misread as a scope
  violation.** It is inside a family `341ec67` already claims closed, so it
  completes an existing claim rather than adding a new one. Called out
  explicitly so the reviewer does not read it as defiance of "do not widen".
- **R3 — Shippability escape valve.** If the nested-brace fix proves harder
  than the validated sketch suggests, the fallback is to move `brace-nested`
  from the closed column to the residual column in the same family table. AC1
  and AC7 still pass; only AC2 is dropped. The unit stays shippable and the
  documentation stays true. Do **not** ship a half-fix with a stale claim.
- **R4 — Mirror + hash ceremony is a known FAIL source.** The gate has two
  byte-identical copies, and `.claude/persona-config.json` carries a
  `fileHashes` entry for the `.claude/` copy. All three must move together or
  `tests/validate.sh` fails.
- **R5 — Committing is itself gate-constrained.** The regenerated file set
  includes the protected config file, so `git commit -- <paths>` naming it is
  BLOCKED by this very gate. Use the sanctioned technique already recorded in
  the memory note (verify `git status --short`, then `git add -A`, then plain
  `git commit -m`). Encountered live while producing this spec: two
  diagnostic commands were blocked for naming the path in their own text.
- **R6 — The C2.3 hot-path pin greps for `case "$cmd" in` and `while :; do`
  by line number.** The brace-collapse edit sits after both and uses a
  `while [[ … ]]`, so the pin holds — but any restructuring of
  `set_a_mentioned()` must re-check it.
- Dependency: none external. No new tool, no new hook, no config schema change.

---

## Constitution check

`.claude/constitution.md` does not exist in this repo (checked 2026-09-09), so
no constitution section applies.

---

## Family table (frozen — this is the unit's closure condition)

Every row carries a stable slug. The slugs are the shared token between the
test suite and the memory note (AC7). **This table is exhaustive for this
unit**: a spelling outside it is out of scope, not a FAIL ground.

### Closed — must be BLOCKED (regression-protected, do not break)

| slug | representative spelling | closed by |
|---|---|---|
| `anchoring` | `git add .claude/persona*.json;` and `…|cat`, `…>/dev/null`, `(…)` | `341ec67` |
| `backslash-escape` | `git add .claude/persona\*.json` | `341ec67` |
| `brace-depth1` | `git add .claude/{persona-config,x}.json` | `341ec67` |
| `prefixed-path` | `/abs/…`, `$CLAUDE_PROJECT_DIR/…`, `F=.claude/persona*.json` | `341ec67` |
| `brace-nested` | `git add .claude/{persona-config,{x,y}}.json` | **this unit** |

### Documented residuals — ALLOWED, and that is intentional

| slug | representative spelling | why out of scope |
|---|---|---|
| `hidden-claude-segment` | `.c*/persona-config.json` | hides the `.claude` token the whole Bash branch keys on |
| `wd-relative` | `cd .claude; rm -f persona-config.json`, `git -C .claude add persona*.json`, `a=.claude; b=…; git add $a/$b` | working-directory modelling, not glob detection — see R1; follow-up spec |

### Accepted over-block — BLOCKED though unrelated to project Set A

| slug | representative spelling | disposition |
|---|---|---|
| `foreign-claude-dir` | `rm -rf ~/.claude/*`, `rm -rf /tmp/x/.claude/*` | fail-closed false positive introduced by `341ec67`'s re-anchoring; accepted, pinned by test, documented |

---

## Steps

### Step 1 — Close `brace-nested`; freeze the family table in tests; make every claim bounded

Single unit. Code and documentation move together deliberately: the memory
note describes behavior this same commit changes, and RC3 is precisely the
failure of letting those two drift apart.

**Affected files**

- `hooks/scripts/harness-integrity-gate.sh` — collapse loop + comment rewrite
- `.claude/hooks/scripts/harness-integrity-gate.sh` — byte-identical mirror
- `.claude/persona-config.json` — `fileHashes` entry for the `.claude/` copy
- `tests/harness-integrity-gate.test.sh` — family table, reachability proofs,
  invariant checks, negative controls, perf pin
- `.claude/agent-memory/lead-programmer/project_harness_integrity_gate_persona_config_commit.md`
  — replace the bolded universal at lines 58-63 with the family table

**Change sketch** (pseudo-code — validated in a scratch harness, not shipped
code; the implementer owns the final form)

The existing loop consumes the outer `{` with the *inner* `}`. Collapse
**innermost-first** to a fixpoint instead, then strip any residual lone brace
as a fail-closed backstop:

```
while g still contains a '{' … '}' pair:
    head  = g up to the FIRST '}'
    inner = head after its LAST '{'          # innermost group body
    g     = (head minus "{inner}") + '*' + (g after that '}')
g = g with any remaining '{' or '}' replaced by '*'
```

Measured in a scratch harness against the real Set A literals: all 7 reachable
nested spellings tried → match (BLOCKED); all 5 unrelated spellings, including
the existing `h9` negative control `.claude/agents/{commands,skills}/*.md` and
lone-brace `weird{name.md` → no match (ALLOWED); a 200-deep nesting terminates
instantly (each pass removes ≥1 pair, so termination is structural).

Note the naive one-line alternative — keeping the current loop and only
stripping residual braces — was tried and is **insufficient**: it closes
`{persona-config,{x,y}}` but leaves `{{persona-config,q},x}` open. Use the
fixpoint form.

**Acceptance criteria**

- **AC1 — Family table encoded and green.** `tests/harness-integrity-gate.test.sh`
  contains one table whose rows carry the exact slugs above, each with an
  expected verdict. `bash tests/harness-integrity-gate.test.sh` → exit 0 and
  final line `All harness-integrity-gate tests passed.`
- **AC2 — `brace-nested` closed.** Both nesting shapes
  `git add .claude/{persona-config,{x,y}}.json` and
  `git add .claude/{{persona-config,q},x}.json`, plus one audit-log sibling,
  return exit 2 with non-empty stderr. (Droppable only under R3, and only
  together with moving the slug to the residual column.)
- **AC3 — Reachability precondition on every BLOCKED row.** For each row
  marked reachable, the test itself proves the spelling expands to a Set A
  path before asserting BLOCKED — e.g. expand the spelling and assert a Set A
  literal is among the results. A row that cannot prove reachability must not
  be credited as a closed bypass. This is the guard whose absence let a
  cosmetic-looking defect hide behind 62 green examples.
- **AC4 — Normalizer invariant, not just examples.** A test asserts the
  post-collapse candidate contains **no `{` and no `}`** across the table's
  brace inputs plus at least three synthetic nestings of depth ≥3. Independently:
  a termination check on a ≥200-deep nesting completes within 5s.
- **AC5 — Non-vacuity by mutation.** Running the new suite against the
  pre-fix gate via `GATE_UNDER_TEST=<path-to-341ec67-copy>` produces FAIL lines
  for the `brace-nested` rows specifically (not merely "some failures"), and
  the new suite against the new gate produces 0 FAIL. Report both counts.
- **AC6 — No unbounded universal language.** A grep over the gate source and
  the memory note for unbounded-claim phrasing — at minimum `any spelling`,
  `all spellings`, `no glob can`, `every spelling`, `is always detected` —
  returns **0 matches**. The code comment's current parity claim ("keep this
  test as permissive-to-detect as the substring cases above") is false for junk
  *inside* the anchored span (`git add .claude/persona*.json.bak` is ALLOWED,
  while the substring test would catch `.claude/persona-config.json.bak`) and
  must be corrected or removed.
- **AC7 — Doc/test slug parity, both directions.** Every slug in the test
  table appears in the memory note under the matching heading (closed /
  residual / accepted over-block), and every slug in the memory note appears in
  the test table. A grep-based check reports 0 slugs in either set difference.
- **AC8 — Residuals are pinned as ALLOWED.** `hidden-claude-segment` and each
  of the four `wd-relative` spellings from the FAIL record assert exit 0. These
  are characterization tests: they record a known, documented hole so the
  documentation is falsifiable. Comment them as such so a future reader cannot
  mistake them for desired behavior.
- **AC9 — Accepted over-block pinned.** `rm -rf ~/.claude/*` and
  `rm -rf /tmp/x/.claude/*` assert exit 2, with a comment naming it a
  fail-closed false positive introduced by `341ec67`'s re-anchoring.
- **AC10 — No new false positives, and hot path intact.** The six existing
  negative controls (`h3`, `h9`, `h14`, `h15`, and the benign/`jq` cases) still
  pass. C2.3's hot-path ordering pin still passes. No `$( )`, backtick, or
  pipeline is added outside the existing cold per-chunk branch — verifiable by
  diffing the function and confirming added lines use only bash builtins.
- **AC11 — Mirror, hash, and suite integrity.**
  `sha256sum hooks/scripts/harness-integrity-gate.sh .claude/hooks/scripts/harness-integrity-gate.sh`
  → two identical digests; the `fileHashes` entry for the `.claude/` copy
  equals that digest; `bash tests/validate.sh` → exit 0, "All checks passed."
- **AC12 — Memory-note claim is bounded and true.** Lines 58-63's bolded
  universal is gone, replaced by the three-column family table. The note states
  the guarantee in bounded form — a spelling is detected when a *single chunk*
  both contains `.claude` and glob-matches a Set A literal after normalization
  — and names both residuals, not one. The existing "split the spelling" prose
  hygiene rule (note lines 72-76) still holds for the note's own text.

---

## Open Questions

1. **`wd-relative` deferral is reversible on request.** Recommended default,
   and the one this spec is written against: **document as a residual, do not
   fix now** (R1). If you would rather close it in this unit, say so and the
   scope grows by one step — the bounded subset would be `cd`/`pushd`/`-C` into
   a `.claude` path plus single-pass literal `VAR=` substitution, both
   fail-closed, both in the cold path; spellings like `cd $(echo .claude)` or
   `X=cl; cd .${X}aude` would remain residual regardless. Raised because it is
   the highest-stakes call in this spec, not because the decision is unmade.
2. **Follow-up spec for `wd-relative` is assumed, not yet filed.** Assumption:
   after this unit PASSes, a fresh unit is opened for the
   working-directory-modelling axis, with its own grilling and its own
   false-positive budget. Flag if you would rather it stay a permanent
   documented residual.
3. **`Set A` / `Set B` glossary entries are assumed to be `scribe`'s, not
   this unit's.** Advisory terminology finding; folding it in here would widen
   a capped unit for no correctness gain.

---

## Self-check

- CHK1: Is "closed" defined for this unit by something other than "no reviewer
  can find a bypass"? — PASS (the frozen family table plus AC1/AC7)
- CHK2: Does every acceptance criterion name a command or assertion that
  yields pass/fail? — PASS
- CHK3: Do the Family table and Step 1's criteria agree on which slugs are
  closed vs residual? — FAIL (conflicting) — revised in place; `brace-nested`
  initially appeared in both columns, now closed-only with R3 naming the single
  condition under which it moves
- CHK4: Is the `wd-relative` disposition stated once, unambiguously? — PASS
  (residual, per Clarifications + R1 + Family table + AC8, all agreeing)
- CHK5: Is the nested-brace defect's *reachability* established in the plan
  rather than asserted? — PASS (Context shows the bash expansion producing the
  protected path and the gate's ALLOWED verdict)
- CHK6: Does the plan say what happens if the nested-brace fix proves
  infeasible? — PASS (R3 escape valve, with AC2 named as the only droppable
  criterion)
- CHK7: Is the perf/hot-path constraint expressed as a check rather than an
  intention? — PASS (AC4 termination bound, AC10 builtins-only diff + C2.3 pin)
- CHK8: Is the mirror/hash/commit procedure specified, given it is a known
  FAIL source here? — PASS (R4, R5, AC11)
- CHK9: Is there a criterion preventing the documentation from drifting from
  the code again? — PASS (AC6 phrasing ban, AC7 bidirectional slug parity)
- CHK10: Are the roast-level items each either folded in or explicitly
  declined? — PASS (comment overclaim → AC6; nested brace → AC2, promoted;
  over-broad block → AC9; left-side-metachar coverage → subsumed by the
  `anchoring` and `prefixed-path` rows of AC1)
- CHK11: Does the plan avoid claiming the gate is complete? — PASS (no
  universal appears in this document; the residual columns are load-bearing)
- CHK12: Is the acceptance signal for AC5 specific enough to fail on? — FAIL
  (ambiguous) — revised in place; was "mutation shows failures", now requires
  FAIL lines attributable to the `brace-nested` rows specifically, with both
  counts reported

---

## Scribe update hint

After PASS: consider `CONTEXT.md` glossary entries for **Set A** / **Set B**
(currently undefined despite being load-bearing across the gate, its suite, and
two plan docs) and for **documented residual** as this project's term for a
deliberately-unclosed, test-pinned hole. Also worth recording as durable
guidance: *a security gate's documentation should enumerate its holes rather
than assert their absence* — the unbounded-universal pattern is what cost this
unit two FAIL cycles.
