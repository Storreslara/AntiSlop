# Marker commit attribution — the `commit:` field must name the unit's own commit

Status: **FINAL** 2026-08-15 — unconditional. All three Open Questions were
answered by the human on 2026-08-15 (recommended default chosen in every case)
and are closed below; no step body changed as a result. Ready for
`task-master` slicing.
Published: umbrella `[spec]` issue
https://github.com/Storreslara/AntiSlop/issues/385 (label `ready-for-agent`),
via the `to-spec` PRD mapping. That issue is the PRD *view*; this document
remains the canonical artifact. Per-step units are sliced from it by
`task-master` under label `plan/2026-08-15-marker-commit-attribution`.
Amended 2026-08-15 by an append-only **Post-finalization addendum** (A1-A3)
recording three verified blast-radius findings. It re-scopes criterion C4.5's
stated cover and adds one Out-of-scope entry; no step was rewritten and no
filed unit was re-scoped.
Author: spec-master. Implementation is **explicitly deferred by the human**;
no `lead-programmer` dispatch may follow from this pass.

## Goal

Make it structurally impossible — or, where a heuristic is the only available
instrument, mechanically *visible* — for a `.claude/reviewed/<task-id>.pass`
marker's required-first-line `commit:` field to name a commit that does not
belong to the unit the marker is about.

Three separable outcomes, in descending order of certainty:

- **G1 (deterministic).** The escalation-resolution `approve` route stops
  re-deriving the commit at all. It copies the `commit:` value verbatim from
  the standing `.escalated` marker, which already records the commit the
  review was actually performed against. This closes the four observed events
  (units 299, 375, 376, 373) with no heuristic and no false-negative surface.
- **G2 (deterministic).** The protocol stops *prescribing* the defect. Every
  surface that today tells a marker writer to use `git rev-parse HEAD` is
  corrected to prescribe the unit's own final commit — the tip of the range
  the reviewer actually reviewed — with `HEAD` accepted only when the writer
  has verified the two are equal.
- **G3 (heuristic safety net).** A new shared script classifies any marker's
  `commit:` field as `ok` / `mismatch` / `unverifiable` and is consulted at
  reviewer turn-end, where the unit id is already known. Its output is logged
  to `.claude/review-audit.log`, replacing the manual orchestrator-level
  cross-checking the human correctly called unsustainable.

Explicit non-goal: G3 is **not** a substitute for G1/G2. A heuristic that
catches 12% of a defect it did not prevent is a worse outcome than a protocol
that does not create the defect.

## Context

### The defect as shipped

`agents/reviewer.md:115` instructs the reviewer to `Capture the commit SHA via
sha="$(git rev-parse HEAD)"`, and `:124` bakes `$(git rev-parse HEAD)` into
the literal `printf` template for the v3 marker. The same idiom is printed
back at the reviewer as remediation text by two gates
(`hooks/scripts/stop-gate.sh:283`, `hooks/scripts/task-gate.sh:67`) and
codified in `docs/adr/0015-commit-anchored-pass-markers.md:41,87`. The defect
is therefore not reviewer sloppiness; it is what the protocol asks for.

`HEAD` equals the unit's own final commit only when nothing has landed on top
since. In this repo's actual operating mode — several units dispatched into
one shared working tree, and escalation resolution deferred until a human is
available — that assumption is routinely false.

### Why `dispatch-hygiene.sh`'s H3 cannot see it

`hooks/scripts/dispatch-hygiene.sh:318-335` reads the marker's first line,
extracts the `commit:` SHA, and suppresses H3 only when
`git merge-base --is-ancestor <sha> HEAD` **fails**. A SHA belonging to an
unrelated sibling unit on the same branch is an ancestor of HEAD in every
observed case, so H3 is satisfied by exactly the wrong value. H3's question is
"is this attestation still reachable"; it has no notion of "does this
attestation belong to this unit." That is the precise gap.

### Measured incidence (this repo, 2026-08-15)

Measured by enumerating **every** `.pass` marker in `.claude/reviewed/`, not a
sample, and resolving each `commit:` field against `git log`:

| Population | Count |
|---|---|
| `.pass` markers total | 224 |
| carrying no `commit:` field (pre-v3 markers) | 109 |
| carrying a resolvable `commit:` SHA | 115 |
| — classified `ok` by the G3 algorithm below | 97 (84.3%) |
| — classified `mismatch` (proven) | 14 (12.2%) |
| — classified `unverifiable` | 4 (3.5%) |

The 14 proven mismatches are not four escalation events plus noise. They are
the same defect across the whole corpus — markers citing
`chore(memory): commit stray agent-memory files`, or a *different unit's*
feature commit. Concrete examples: `263.pass` cited `feat(unit #264)`;
`265.pass` and `266.pass` both cited `chore(unit #267)`; `gh341.pass` cited
`fix(gh288-2)`; `gh339.pass` cited `docs(#273)`. In 13 of the 14, a correctly
named commit for that unit **exists in history** — so the marker is not
recording an unconventional commit, it is recording the wrong one.

The four units the human named (299, 375, 376, 373) all classify `ok`
**today**, because each was already corrected by hand. That is the point: the
corpus is only clean where a human happened to look.

### Commit-message convention survey (drives the G3 algorithm)

The dominant convention is `type(gh<N>): subject`, with live variants
`type(#<N>)`, `type(unit #<N>)`, `type(unit <N>)`, `type(gh-<N>)`,
`type(gh<N>-<step>)`, and `type(adhoc-<date>-<slug>)`. Marker task-ids are
correspondingly heterogeneous: bare numerics (`373`), `gh`-prefixed
(`gh348-13`), hyphenated (`gh-140-hardening`), and date-slugged
(`adhoc-2026-08-14-fill-348-advisory-gaps`).

A naive `grep -qi "gh<id>\|(<id>)\|#<id>"` — the shape the human's brief
floated — was measured and is **not** safe: it reports `mismatch` for `137`
against `docs(gh137): ...` (the id `137` is not word-boundaried inside
`gh137`), and it degenerates on `adhoc-*` ids whose first digit run is the
year `2026`. The refined algorithm in Step 6 was measured on the same corpus
and produced the table above with **zero** false positives among the 97 `ok`
markers.

### Where the seam is

`hooks/scripts/stop-gate.sh:265-272` already iterates
`JOIN_SATISFIED_UNITS[]` at reviewer `SubagentStop`, immediately after the
marker was written, with the unit id in hand and the marker path derivable.
This is the highest existing seam and the only one where "which unit is this
marker about" is known without re-deriving it. No new seam is proposed.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-15 Functional scope & success criteria: Q Does "fix this" include
  retro-correcting the 14 already-mismatched markers in
  `.claude/reviewed/`? → A (self-resolved): no — out of scope, and recorded
  as Open Question 3 so the human can add it. Rewriting historical verdict
  records is a different risk class from correcting the protocol that
  produced them, only the reviewer may write those files, and 109 of the 224
  markers predate the field entirely. Step 9 delivers a read-only audit
  report instead.
- 2026-08-15 Domain entities / data model: Q Does the fix introduce a second
  marker field (the ad-hoc `reviewed-commit:` line that appeared in
  `373.pass` during the manual correction), or redefine the existing
  `commit:` field? → A (self-resolved): redefine the existing field. A second
  field would need every consumer (`dispatch-hygiene.sh` H3, `task-gate.sh`,
  `stop-gate.sh`) taught which one wins, and the v3 first-line format is
  already load-bearing for `marker_valid()`. `reviewed-commit:` is not
  promoted to the spec; it stays a free-form note line where a reviewer wants
  to record escalation-time HEAD separately.
- 2026-08-15 User interaction flow: Q At reviewer turn-end, does a `mismatch`
  classification block the turn or warn? → A (self-resolved): warn by
  default, `block` and `off` available via config, mirroring
  `dispatchHygiene`'s posture vocabulary. Blocking by default is not
  defensible at a measured ~1-2% hard-false-positive rate (`gh-304`'s marker
  legitimately cites a commit naming the *subject* issue `gh-303` rather than
  the unit id), and a false block on a gate the reviewer does not own invites
  exactly the bypass the shared protocol forbids. Recorded as Open Question 1.
- 2026-08-15 Edge cases / failure handling: Q What does the check do for a
  non-git project, `commit: none`, a pre-v3 marker with no `commit:` field, a
  SHA absent from history, or an `adhoc-*` id no commit references? →
  A (self-resolved): every one of these classifies `unverifiable` and is
  silent. The check fails open in all five, consistent with H3's own
  governing rule and with `review_join_state()`'s fail-open posture. Only a
  *positively proven* mismatch — the cited commit does not reference the
  unit AND some other reachable commit does — is ever reported.
- 2026-08-15 Technical constraints & tradeoffs: Q What is the true blast
  radius of a `hooks/scripts/stop-gate.sh` change? → A (self-resolved): four
  copies, not one. `tests/validate.sh:302` gates
  `.claude/hooks/scripts` byte-identical to `hooks/scripts`, and
  `tests/adapter-stop-gate-parity.test.sh` drives all three ports
  (`hooks/scripts/`, `adapters/codex/hooks/scripts/`,
  `adapters/cursor/hooks/scripts/`) through the same scenarios. Per the
  "don't gate a source edit apart from its shipped copy" rule, each step's
  affected-files list below carries its ports and mirror in the **same**
  unit; they are never sliced apart.
- 2026-08-15 Terminology consistency: Q Does the request's phrase "the unit's
  own actual final commit" agree with the shipped glossary? →
  A (self-resolved): no, and the disagreement is the defect. `CONTEXT.md:183`
  defines the field as recording "the commit at which the unit was **marked
  done**" — which is marker-write time, i.e. HEAD. The glossary encodes the
  wrong semantics and is corrected in Step 1. (Full three-lens result under
  "Ubiquitous-language check" below.)
- 2026-08-15 Completion / acceptance signals: Q What proves the fix works,
  given the observable defect only appears when units interleave? →
  A (self-resolved): a synthetic git repo built by the test itself, with
  three commits whose subjects name three different units, asserting the
  classifier's three states. No criterion is pinned to a live SHA in this
  repo's history, so no criterion expires on a rebase.

The three lines below were appended after the Open Questions round-trip, when
the human answered on 2026-08-15. They are recorded rather than merely
consumed; each confirms the corresponding self-resolution above rather than
overturning it.

- 2026-08-15 User interaction flow: Q At reviewer turn-end, does a `mismatch`
  classification block the turn or warn? → A: **warn**, per human, closing
  Open Question 1 with option (a) — `warn` by default, `block` opt-in.
  Confirms the self-resolution above. Step 7's `warn` default is now locked
  rather than provisional; no step text changed.
- 2026-08-15 Domain entities / data model: Q Should the `.escalated` marker's
  `commit:` line be promoted from a body line to the marker's required first
  line? → A: **no**, per human, closing Open Question 2 with option (a).
  The `.escalated` format is untouched by this milestone; only the `approve`
  route's copy behaviour changes, and Step 3 parses `commit:` out of the
  marker body exactly as drafted. Re-verified against the tree:
  `agents/reviewer.md:186` still carries it as a body line.
- 2026-08-15 Functional scope & success criteria: Q Should this milestone
  retro-correct the 14 already-mismatched markers? → A: **no**, per human,
  closing Open Question 3 with option (a) — report only. Confirms the
  self-resolution above. Step 9 stays read-only, no rewrite step is added,
  and the Out of scope exclusion stands, because only the reviewer may
  legitimately write into the reviewed-markers directory (R7).

### Ubiquitous-language check (prose mode, advisory)

Glossary read: `CONTEXT.md`. All three lenses ran.

- **Lens 1 — a glossary term used with a different meaning.** `CONTEXT.md:183-185`
  defines the v3 `commit:` field as "records the commit at which the unit was
  marked done." The request (and this plan) use it to mean the unit's own
  final commit. These are different commits whenever a sibling unit lands in
  between. Canonical definition must move, not the usage. Anchor:
  `CONTEXT.md:183`; addressed by Step 1.
- **Lens 2 — a new synonym for an already-defined term.** Two. (a) The
  request's "ESCALATION-RESOLUTION path" names what `agents/reviewer.md:247`
  and `CONTEXT.md`'s **DECISION channel** entry already call *resolving a
  standing escalation (transcription, never re-review)*; this plan uses the
  canonical phrasing. (b) The `reviewed-commit:` line introduced ad hoc in
  `373.pass` is a synonym for what `commit:` should already have meant; it is
  deliberately not promoted (see Clarifications).
- **Lens 3 — a load-bearing new domain term with no glossary entry.**
  *Attested commit* is already load-bearing — `dispatch-hygiene.sh:333`
  emits "its attested commit is gone" — with no entry of its own. This plan
  adds a second: *commit attribution*, the property that a marker's `commit:`
  names a commit belonging to that marker's unit. Both are scribe candidates;
  Step 1 adds them rather than deferring, since the ADR is meaningless
  without them.

## Risks and dependencies

- **R1 — prior FAIL history on adjacent units.** All `.fail` records in
  `.claude/reviewed/` were enumerated (not sampled). Two are directly
  adjacent to this work: `gh274.fail` (a BSD/macOS `stat` fallback missing
  from `stop-gate.sh`'s review-join read) and `gh346-1.fail`/`gh346-2.fail`
  (the `.claude/` hook-script mirror drift gate). Both live in the exact
  files Steps 5 and 7 touch. **No step in this plan may be tagged `haiku`
  if it edits `hooks/scripts/stop-gate.sh`** — that file has a demonstrated
  history of portability and mirror-parity defects that survived a first
  implementation pass.

  **Note, 2026-08-15 (human decision).** R1 states a *floor*, not the whole
  tagging rule, and a human raised one unit above it. Step 6 (the new
  classifier, filed as #391) does **not** edit `stop-gate.sh` and carries no
  prior failure record, so R1's ban did not reach it and `haiku` was literally
  eligible — it was the original tag. It was raised to `sonnet` on **judgment
  density**: Step 6 carries this milestone's only non-trivial algorithm, and
  its correctness is defined mostly by what it must *refuse* to match (the two
  pinned false positives, the ban on relaxing the id-bearing-context match to
  a bare digit match, and the R2/R3 portability constraints). Generalizable
  reading for anyone re-deriving tags: R1's letter is "no `haiku` where defects
  have already survived a pass"; its spirit is "demonstrated need for judgment
  outranks literal eligibility," and the second can bind where the first does
  not. This plan carries no per-step model tags of its own — tagging is
  `task-master`'s ticket-level dispatch decision under ADR-0003's split — so
  the override lives on #391, and this note exists only so the reasoning is not
  lost with the ticket.
- **R2 — `stat -L -c %Y` portability.** `stop-gate.sh:195` carries a
  BSD/macOS fallback that had to be added by a follow-up fix (`cad6794`).
  Any new `stop-gate.sh` code in Step 7 that shells out must not reintroduce
  a GNU-only invocation.
- **R3 — `grep` is wrapper-shadowed inline.** A bare `grep` in this session
  resolves to `ugrep`; inside `bash script.sh` it is GNU grep. Acceptance
  criteria below therefore use `git grep` or `grep -cF` with explicit flags,
  and the new script must not depend on GNU-only `grep` extensions.
- **R4 — constitution P3 (version-stamp discipline).** Steps 2, 3, 4 edit
  version-stamped files (`agents/reviewer.md`,
  `templates/persona-protocol.md`). The version bump + CHANGELOG + mirror
  regeneration (Step 8) must land **last** in the milestone, and no earlier
  step may hand-edit `.claude/agents/**` or `.claude/hooks/scripts/**`
  (constitution P2 — those are script-driven paths).
- **R5 — ADR numbering.** The highest ADR on disk is `0022`. `0007` is a
  hole and is **not** free (`CONTEXT.md` links it). Step 1 must re-derive the
  next number at execution time rather than trusting a number written here;
  a sibling spec landing first will collide.
- **R6 — second-order H3 consequence, deliberately not fixed here.** Once
  `commit:` names the unit's own commit, H3's reachability test becomes
  *more* correct (a marker whose unit's work was rebased away now correctly
  goes void). But a marker that today cites a sibling's still-reachable
  commit makes H3 block re-dispatch of a unit whose real work is gone. That
  is a real bug, it is fixed *by* G1/G2 going forward, and no change to
  `dispatch-hygiene.sh` is proposed. See Out of scope.
- **R7 — the reviewed directory is reviewer-owned.** `reviewed-path-gate.sh`
  blocks every non-reviewer identity from writing under
  `.claude/reviewed/` via Bash. Step 9's audit unit is therefore **read-only
  by construction** and must be implemented with plain `ls`/`cat`/`grep -r`
  or an out-of-band interpreter script, never a shell loop naming the path.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every count in Context and every
  acceptance criterion below was executed against the live tree before this
  plan was finalized; the classifier algorithm was measured on all 115
  commit-carrying markers rather than reasoned about.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no
  step hand-edits `.claude/agents/**` or `.claude/hooks/scripts/**`; Step 8
  regenerates them via `node bin/cli.js --update`. The design itself is an
  application of this principle: G1 replaces an LLM re-derivation
  (`rev-parse HEAD` at transcription time) with a verbatim copy.
- P3 "Version-stamp discipline": satisfied — Step 8 bumps
  `.claude-plugin/plugin.json` and adds a CHANGELOG entry, gated by an
  explicit criterion, because Steps 2-4 touch version-stamped files.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — the new
  check is inert in a project with no `reviewer` persona, because no
  `.review-join.*` stamp is ever written there and `review_join_state()`
  short-circuits at `JOIN_STAMP_COUNT == 0`. Step 7's criterion C7.5 asserts
  this rather than assuming it.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every step's
  criteria terminate in `bash tests/validate.sh` exit 0, and Step 6 wires
  the new test into it.

---

## Step 1 — Redefine `commit:` as the unit's own commit (ADR + glossary)

The semantic change, landed before any prose that depends on it.

**Affected files**
- `docs/adr/00NN-marker-commit-attribution.md` (new; **re-derive `NN` at
  execution time** — highest on disk is `0022`, and `0007` is not free)
- `docs/adr/0015-commit-anchored-pass-markers.md` (amend in place: a dated
  note that its `<sha> == rev-parse HEAD` reading at `:41` and `:87` is
  superseded in part, following the document set's existing
  `**SUPERSEDED YYYY-MM-DD —**` convention)
- `CONTEXT.md` (`:183-185` redefinition; two new glossary entries)

**Content**
- The ADR records: the field means the unit's own final commit; the
  measured 14/115 incidence; why H3's ancestor test is necessary but not
  sufficient; the three-layer G1/G2/G3 design; and why G3 warns rather than
  blocks.
- `CONTEXT.md:183-185` replaces "the commit at which the unit was marked
  done" with the unit-attributed reading.
- New glossary entries for **Attested commit** and **Commit attribution**,
  cross-linked `[[...]]` to the existing `[[PASS marker]]` /
  `[[.escalated marker]]` entries.

**Acceptance criteria** (each must exit 0)
- C1.1 `test "$(grep -cF 'the commit at which the unit was marked done' CONTEXT.md)" = 0`
  — pre-change count is **1** (measured), so this criterion is non-vacuous.
- C1.2 `grep -qF 'Attested commit' CONTEXT.md && grep -qF 'Commit attribution' CONTEXT.md`
- C1.3 `ls docs/adr/ | grep -qE '^00[0-9][0-9]-marker-commit-attribution\.md$'`
- C1.4 `grep -qF 'marker-commit-attribution' docs/adr/0015-commit-anchored-pass-markers.md`
  (0015 points forward to its own partial supersession)
- C1.5 `grep -qE 'SUPERSEDED 2026-[0-9]{2}-[0-9]{2}' docs/adr/0015-commit-anchored-pass-markers.md`
- C1.6 `bash tests/validate.sh` exits 0
- C1.7 `node tests/protocol-cross-references.test.js` exits 0 (the new
  `[[...]]` links resolve)

---

## Step 2 — Reviewer prose: stop prescribing `git rev-parse HEAD` on the first-time PASS path

**Affected files**
- `agents/reviewer.md` (`:110-124`, the "On PASS (marker format v3)" bullet)

**Content.** Replace both occurrences. The corrected instruction must state,
in the reviewer's own voice:

> Capture the SHA of **the unit's own final commit** — the tip of the range
> you actually reviewed — never `HEAD` at marker-write time. In a session
> where nothing landed on top they are the same commit; when a sibling unit
> has since landed they are not, and the marker must name the unit's own.
> Derive it from the range you reviewed, then confirm before writing:
> `git log -1 --format=%s "$sha"` must name this unit. If it does not, and
> the unit's own commit genuinely does not name it (an unconventional
> subject), say so on a note line rather than substituting `HEAD`.

`git rev-parse HEAD` may still be named, but only as the value to *verify*,
never as the value to *use unverified*.

**Acceptance criteria**
- C2.1 `test "$(grep -cF 'rev-parse HEAD' agents/reviewer.md)" -le 1` —
  pre-change count is **2** (measured). At most one survivor, and only in a
  verify-this-equals context.
- C2.2 `grep -qF "the unit's own final commit" agents/reviewer.md`
- C2.3 `grep -qF 'git log -1 --format=%s' agents/reviewer.md`
- C2.4 `test "$(grep -cF 'commit: %s criteria:' agents/reviewer.md)" = 1` —
  the `printf` template's first-line shape is unchanged (only the value
  substituted into it changes), so `marker_valid()` is untouched.
- C2.5 `bash tests/validate.sh` exits 0
- C2.6 `node tests/protocol-doc-drift.test.js` exits 0

---

## Step 3 — Reviewer prose: the `approve` route copies `commit:` from the `.escalated` marker

The deterministic fix for the four observed events. Kept a separate step
from Step 2 because it is the one change that closes the reported defect
even if every other step is dropped.

**Affected files**
- `agents/reviewer.md` (`:265-277`, the `approve` bullet under "Resolving a
  standing escalation")

**Content.** The `approve` bullet gains an explicit exception to
"per the PASS rules above":

> `approve` → write `.pass` per the PASS rules above, **with one exception:
> the `commit:` field is copied verbatim from the standing `.escalated`
> marker's own `commit:` line.** Never re-derive it. Resolution is a
> transcription, not a re-review: the escalated marker already records the
> commit the review was performed against, and by the time a human decides,
> `HEAD` has normally moved on to other units' work — a marker written from
> `HEAD` here names a different unit's commit. If the `.escalated` marker
> carries no parseable `commit:` line, fall back to the Step 2 derivation
> and record on a note line that you did.

**Acceptance criteria**
- C3.1 `grep -qF 'copied verbatim from the standing' agents/reviewer.md`
- C3.2 `grep -qF 'Never re-derive it' agents/reviewer.md`
- C3.3 The exception is inside the `approve` bullet, not merely somewhere in
  the file — region-scoped, following the pattern
  `tests/…` uses elsewhere:
  `A(){ sed -n '/^  - `approve` →/,/^  - `reject` →/p' agents/reviewer.md; }; A | grep -qF 'verbatim from the standing'`
- C3.4 The `reject` and `direct` bullets are intact and singular:
  `test "$(grep -cF '  - `reject` → write `.fail` per the FAIL rules above' agents/reviewer.md)" = 1`
  and
  `test "$(grep -cF '  - `direct` → write `.claude/reviewed/<task-id>.directed`' agents/reviewer.md)" = 1`.
  Written as `test "$(grep -c …)" = N` rather than `grep -c … ` alone
  **deliberately**: bare `grep -c` exits **1** when the count is zero, so a
  criterion phrased as "grep -c returns 0" can never be satisfied. Verified
  by execution while this plan was written. Every `= 0` criterion in this
  document uses the `test "$(…)"` wrapper for the same reason.
- C3.5 `bash tests/validate.sh` exits 0

---

## Step 4 — Port the two prose corrections into the protocol template and both adapters

**Affected files** (must move together — `tests/adapter-protocol-parity.test.js`
maps canonical sections onto both ports)
- `templates/persona-protocol.md` (`:234` v3 format definition; `:349` the
  `.escalated` marker's `commit: <sha>` line)
- `adapters/codex/agents-md-fragment.md` (`:147`)
- `adapters/cursor/rules/persona-protocol.mdc` (`:155`)
- `docs/design.md` (`:46`)

**Content.** The v3 format line keeps its literal shape
`commit: <sha|none>` (a `grep -cF 'commit: <sha|none> criteria:'` = 1
criterion already exists in a sibling plan and must stay satisfiable); what
changes is the sentence defining what `<sha>` is. The `.escalated` marker's
`commit: <sha>` gains the words "the commit the review was performed
against — the value the `approve` route copies verbatim."

Note for the implementer: in both adapter ports the surrounding prose is
line-wrapped differently from the source and dashes are ASCII-ized. Do not
assume a source string greps identically in a port; verify each port's own
wrap before writing a criterion against it.

**Acceptance criteria**
- C4.1 `test "$(grep -cF 'commit: <sha|none> criteria:' templates/persona-protocol.md)" = 1`
  (unchanged shape — pre-change count is **1**, measured)
- C4.2 `grep -qF "the unit's own final commit" templates/persona-protocol.md`
- C4.3 `grep -qF 'copied verbatim' adapters/codex/agents-md-fragment.md`
- C4.4 `grep -qF 'copied verbatim' adapters/cursor/rules/persona-protocol.mdc`
- C4.5 `node tests/adapter-protocol-parity.test.js` exits 0
- C4.6 `node tests/protocol-doc-drift.test.js` exits 0
- C4.7 `grep -qF "unit's own final commit" docs/design.md`
- C4.8 `bash tests/validate.sh` exits 0

---

## Step 5 — Correct the remediation text the gates print back at the reviewer

Two gates hand the reviewer a ready-to-paste `printf` that hard-codes
`$(git rev-parse HEAD)`. A reviewer that follows the block message verbatim
reproduces the defect, which makes this the highest-leverage prose surface
after Step 3.

**Affected files** (all five copies in one unit — the mirror and both ports
are gated)
- `hooks/scripts/stop-gate.sh` (`:283`)
- `hooks/scripts/task-gate.sh` (`:67`)
- `adapters/codex/hooks/scripts/stop-gate.sh`
- `adapters/cursor/hooks/scripts/stop-gate.sh`
- `.claude/hooks/scripts/**` — **not hand-edited**; regenerated in Step 8

**Content.** The pasted template's `$(git rev-parse HEAD ...)` is replaced by
a placeholder plus a one-line caution, e.g.
`commit: <the unit's own final commit, not HEAD>`. The remediation must not
grow into a paragraph; it is printed inside a block message.

**Constraint.** `hooks/scripts/stop-gate.sh:422` also calls
`git rev-parse HEAD` for the **session baseline**, which is correct and must
be preserved. The criterion below is scoped so it cannot pass by deleting
that line.

**Acceptance criteria**
- C5.1 `test "$(grep -cF 'rev-parse HEAD' hooks/scripts/stop-gate.sh)" = 1`
  — pre-change count is **2** (measured); the survivor must be the session
  baseline.
- C5.2 `grep -qF 'current_sha=' hooks/scripts/stop-gate.sh` (the session
  baseline call is still present — makes C5.1 non-vacuous in the deletion
  direction)
- C5.3 `test "$(grep -cF 'rev-parse HEAD' hooks/scripts/task-gate.sh)" = 0`
  — pre-change count is **1** (measured).
- C5.4 `test "$(grep -cF 'rev-parse HEAD' adapters/codex/hooks/scripts/stop-gate.sh)" = 1`
  and the same for `adapters/cursor/…` — pre-change count is **2** each
  (measured).
- C5.5 `bash tests/adapter-stop-gate-parity.test.sh` exits 0
- C5.6 `bash tests/stop-gate-blocked.test.sh` and
  `bash tests/stop-gate-escalated.test.sh` and `bash tests/review-join.test.sh`
  each exit 0
- C5.7 `bash tests/validate.sh` exits 0 (which includes the
  `.claude/hooks/scripts` byte-identity check at `:302` — so this step must
  either land with Step 8's regeneration or run `node bin/cli.js --update`
  itself; whichever `task-master` chooses, the two must not be sliced apart)

---

## Step 6 — New shared classifier: `hooks/scripts/marker-commit-check.sh`

**Affected files**
- `hooks/scripts/marker-commit-check.sh` (new, executable `755`)
- `tests/marker-commit-check.test.sh` (new)
- `tests/validate.sh` (wire the new test; the loops at `:12`, `:28` and `:48`
  already sweep `hooks/scripts/*.sh` for syntax and mode, so the new script
  is picked up automatically — verify, do not assume)

**Interface.** `marker-commit-check.sh <task-id> [project-dir]`. Prints
exactly one line to stdout and **always exits 0**:

```
marker-commit-check=<ok|mismatch|unverifiable> unit=<id> commit=<sha|none> [candidates=<sha,sha,sha>]
```

Always-exit-0 is deliberate: the script classifies, it never decides policy.
Every caller chooses its own posture from the token.

**Algorithm** (measured; see Context)

1. Read the first line of `<project-dir>/.claude/reviewed/<task-id>.pass`.
   Absent file, absent `commit:` field, or `commit: none` ⇒ `unverifiable`.
2. Not a git work tree, or `git cat-file -e <sha>^{commit}` fails ⇒
   `unverifiable`.
3. Build the id token set: the task-id itself (case-insensitive substring),
   plus — only if the id matches `^(gh-?)?([0-9]+)([-.].*)?$` — the numeric
   core from group 2.
4. `references(<sha>)` is true when `git log -1 --format=%s%n%b <sha>`
   contains the literal task-id, **or** contains the numeric core in an
   id-bearing context: `gh<N>`, `gh-<N>`, `#<N>`, `unit <N>`, `unit #<N>`,
   each with a trailing non-digit boundary.
   The id-bearing-context requirement is load-bearing and must not be
   relaxed to a bare digit match: a bare match reports `ok` for a unit id of
   `31` against the subject `version bump 0.31.53 -> 0.31.54`.
5. `references(marker_sha)` ⇒ `ok`.
6. Else, if any commit reachable from `HEAD` satisfies `references()` ⇒
   `mismatch`, listing up to 3 candidates.
7. Else ⇒ `unverifiable`.

**Constraints.** POSIX-portable: no GNU-only `grep` extension, no `stat -c`
without a BSD fallback (see R2/R3). Step 6 whole-history scan is bounded by
`git log --format=%H%x01%s%x02%b` piped once, not a per-commit `git log -1`
loop.

**Testing.** `tests/marker-commit-check.test.sh` builds its **own** throwaway
git repo in `mktemp -d` with three commits whose subjects name three
different units (mirroring the observed defect: a marker for unit A citing
unit B's commit), plus a `.claude/reviewed/` fixture. **No test may pin a SHA
from this repo's real history** — a rebase would expire it.

Required cases:
- (a) marker cites its own unit's commit ⇒ `ok`
- (b) marker cites a *sibling unit's* commit, and the unit's own commit
  exists ⇒ `mismatch`, with the correct SHA among `candidates=`
- (c) marker cites a commit naming no unit, and no commit anywhere names the
  unit ⇒ `unverifiable`
- (d) `commit: none` ⇒ `unverifiable`
- (e) missing marker file ⇒ `unverifiable`
- (f) SHA not in history ⇒ `unverifiable`
- (g) bare-numeric id `137` against subject `docs(gh137): …` ⇒ `ok`
  (the naive-pattern false positive, pinned as a regression)
- (h) id `31` against subject `chore(gh299): version bump 0.31.53 -> 0.31.54`
  ⇒ **not** `ok` (the bare-digit false positive, pinned as a regression)
- (i) `adhoc-2026-08-14-<slug>` id against a subject naming no such slug, in
  a repo where no commit names it ⇒ `unverifiable`, **never** `mismatch`
- (j) not a git repo ⇒ `unverifiable`, exit 0

**Acceptance criteria**
- C6.1 `test -x hooks/scripts/marker-commit-check.sh`
- C6.2 `bash -n hooks/scripts/marker-commit-check.sh` exits 0
- C6.3 `bash tests/marker-commit-check.test.sh` exits 0
- C6.4 `bash tests/validate.sh | grep -qF 'tests/marker-commit-check.test.sh'`
  (the new test is actually reached by the merge gate, not merely present)
- C6.5 **Non-vacuity by mutation, run by the reviewer, not trusted from the
  implementer**: replace step 4's id-bearing-context regex with a bare digit
  match and re-run `bash tests/marker-commit-check.test.sh` — it must exit
  non-zero (case (h) catches it). Restore and confirm `git diff --quiet HEAD`.
- C6.6 **Corpus check.** Run the finished script against every task-id with a
  `.pass` marker in this repo and confirm the totals are
  `ok=97 mismatch=14 unverifiable=4` out of 115 commit-carrying markers.
  This is a *reproduction of the plan's own measurement*, and it expires the
  moment new markers are written or history is rewritten — so it is recorded
  as an **informational** check with its measurement date, not a merge-gate
  criterion. If the numbers have moved, report the delta rather than
  adjusting the script to match.
- C6.7 `bash tests/validate.sh` exits 0

---

## Step 7 — Wire the classifier into the reviewer turn-end seam

**Affected files** (four copies in one unit)
- `hooks/scripts/stop-gate.sh` (inside the `JOIN_SATISFIED_STAMPS`
  consumption loop, `:265-272`)
- `adapters/codex/hooks/scripts/stop-gate.sh`
- `adapters/cursor/hooks/scripts/stop-gate.sh`
- `templates/persona-config.schema.json` (new `markerCommitCheck` object,
  modeled on the existing `dispatchHygiene` entry at `:83-92`)
- `.claude/persona-config.json` (set the key explicitly for this project)
- `tests/review-join.test.sh` and `tests/adapter-stop-gate-parity.test.sh`
  (extend)
- `.claude/hooks/scripts/**` — regenerated in Step 8, never hand-edited

**Behaviour.** For each unit in `JOIN_SATISFIED_UNITS[]`, immediately before
the stamp is consumed, invoke the classifier and:

- append `marker-commit-check=<state> unit=<id>` to
  `.claude/review-audit.log` in **all** states, so the audit trail is
  complete rather than exception-only;
- `mode: warn` (default) and state `mismatch` ⇒ print a one-line warning
  naming the unit, the cited SHA, and the candidates, to stderr; exit path
  unchanged;
- `mode: block` and state `mismatch` ⇒ print the same message plus the
  remediation, and `exit 2`, leaving the pending-review flags standing so
  the reviewer gets a second attempt;
- `mode: off` ⇒ skip entirely, not even the audit line;
- `ok` / `unverifiable` in any mode ⇒ silent apart from the audit line.

**Config.** `markerCommitCheck: { "mode": "off"|"warn"|"block" }`. An absent
object resolves to `warn`. Note this default differs from `dispatchHygiene`'s
`block`, deliberately — see Open Question 1.

**Failure posture.** If the classifier is missing, non-executable, or errors,
`stop-gate.sh` must log `marker-commit-check=unavailable` and continue. A
turn-end gate must never be broken by its own advisory helper.

**Acceptance criteria**
- C7.1 `grep -qF 'marker-commit-check' hooks/scripts/stop-gate.sh` and the
  same for both adapter ports
- C7.2 `grep -qF 'markerCommitCheck' templates/persona-config.schema.json`
  and `jq -e '.markerCommitCheck.mode' .claude/persona-config.json` exits 0
- C7.3 `jq -e '.properties.markerCommitCheck.properties.mode.enum
  | index("warn") and index("block") and index("off")'
  templates/persona-config.schema.json` exits 0
- C7.4 `bash tests/review-join.test.sh` exits 0, and its output names a new
  case asserting each of: `warn`+`mismatch` ⇒ exit 0 with the warning on
  stderr; `block`+`mismatch` ⇒ exit 2 with the pending-review flag still
  present afterwards; `off` ⇒ no audit line written.
- C7.5 **Degrade-gracefully assertion (constitution P4).** A fixture project
  with zero `.review-join.*` stamps produces **no** `marker-commit-check=`
  line in its audit log — proving the check is inert where no reviewer
  persona is selected.
- C7.6 **Helper-unavailable assertion.** With
  `hooks/scripts/marker-commit-check.sh` renamed away, `stop-gate.sh` exits
  0 on an otherwise-clean turn and logs `marker-commit-check=unavailable`.
- C7.7 `bash tests/adapter-stop-gate-parity.test.sh` exits 0 (all three
  ports behave identically on the new branch)
- C7.8 **Non-vacuity by mutation**: force the classifier to always print
  `ok`; `tests/review-join.test.sh` must exit non-zero. Restore, confirm
  `git diff --quiet HEAD`.
- C7.9 `bash tests/validate.sh` exits 0

---

## Step 8 — Version bump, CHANGELOG, mirror regeneration

Must land **last**. Constitution P3.

**Affected files**
- `.claude-plugin/plugin.json`, `package.json` (version — re-derive from the
  current value at execution time; it was `0.31.57` when this plan was
  written)
- `CHANGELOG.md`
- `.claude/agents/*.md`, `.claude/hooks/scripts/**`,
  `.claude/persona-config.json` `fileHashes` — **all** produced by
  `node bin/cli.js --update`, never hand-edited (constitution P2)
- `.claude/wiki/modules/hooks.md` (scribe surface: document the new hook
  script and config key)

**Acceptance criteria**
- C8.1 `node bin/cli.js --update` exits 0, and a second consecutive run
  leaves `git status --porcelain` empty (idempotent)
- C8.2 `diff -rq hooks/scripts .claude/hooks/scripts` exits 0
- C8.3 The versions in `.claude-plugin/plugin.json`, `package.json`,
  `.claude/persona-config.json`'s `pluginVersion`, and the newest
  `CHANGELOG.md` heading are all equal, and strictly greater than the
  pre-change value
- C8.4 `grep -qF 'marker-commit-check' CHANGELOG.md`
- C8.5 `grep -qF 'marker-commit-check' .claude/wiki/modules/hooks.md`
- C8.6 `bash tests/validate.sh` exits 0
- C8.7 `git status --porcelain` is empty at the end of the step

---

## Step 9 — Read-only audit of existing markers (report only, no rewrites)

Deliberately last and deliberately inert. Produces a report; changes no
marker. See Open Question 3 — if the human wants the 14 corrected, that is a
separate reviewer-authored pass, since only the reviewer may write there
(R7).

**Affected files**
- `bin/marker-commit-audit.sh` **or** an extension to the existing
  `agent-audit.sh` surface — `task-master` picks, based on where the
  `agent-auditor` persona already reads from
- `tests/` coverage for whichever is chosen

**Acceptance criteria**
- C9.1 The audit runs against every `.pass` marker (enumerated, not sampled)
  and prints a per-state count plus one line per `mismatch`
- C9.2 The audit performs **no** write under `.claude/reviewed/` — asserted
  by comparing `find .claude/reviewed -newer <sentinel>` before and after,
  which must be empty
- C9.3 `bash tests/validate.sh` exits 0

---

## Out of scope

- Correcting the 14 already-mismatched markers (Step 9 reports; it does not
  rewrite). See Open Question 3.
- Backfilling a `commit:` field into the 109 pre-v3 markers. The v2 format
  remains valid and is never retroactively rejected — that is an explicit
  property of `marker_valid()` and must not change.
- Any change to `dispatch-hygiene.sh`'s H3. Its ancestor test stays as-is;
  G1/G2 make its input correct going forward (R6).
- Any change to the `.fail`, `.blocked`, or `.directed` marker formats.
  Only `.pass` carries a `commit:` field.
- Enforcing a commit-message convention. The classifier reads conventions; it
  never requires one, which is exactly why `unverifiable` exists as a state.
- Grading, gating, or otherwise re-adjudicating the human's DECISION. Step 3
  narrows *one field* of a transcription; it does not add a verification the
  human must pass.
- **Closing the adapter marker-format parity gap.** No test asserts that the
  marker format agrees across `hooks/`, `adapters/codex/` and
  `adapters/cursor/` — `tests/adapter-protocol-parity.test.js` probes section
  presence and escalation-prose only (verified 2026-08-15; see addendum A3).
  The gap is pre-existing and wider than marker `commit:` semantics; closing it
  requires deciding which marker-format substrings are load-bearing across
  three ports. Recorded as the top follow-on candidate, not scoped here.

## Open Questions

**All three resolved by the human on 2026-08-15. The recommended default was
chosen in every case, so no step body required revision — each resolution
below records "Effect on the spec: none" against the text as drafted. This
spec carries no unresolved question and is unconditional.** The questions are
retained rather than deleted so the record shows what was asked and what was
decided; the same answers are logged as dated lines in Clarifications above.

1. **RESOLVED 2026-08-15 — `warn`.** *Should Step 7 default to `warn` or
   `block`?* Chosen: option (a) — `warn` by default, `block` available
   opt-in. Basis as drafted and unchanged: ~1-2% of `mismatch`
   classifications are hard false positives (`gh-304`'s marker legitimately
   cites a commit naming the subject issue `gh-303`), and a false block at
   reviewer turn-end is a gate the reviewer does not own and cannot legally
   route around — a worse failure than a missed warning, especially since G1
   and G2 already remove the defect's source. Options (b) `block` by default
   and (c) `warn` for one milestone then re-measure were both declined.
   **Effect on the spec: none.** Step 7 already specifies `mode: warn` as the
   default with an absent `markerCommitCheck` object resolving to `warn`, and
   C7.4 already asserts the behaviour of all three modes.
2. **RESOLVED 2026-08-15 — no.** *Should the `.escalated` marker's own
   `commit:` line be promoted to the required first line?* Chosen: option (a)
   — leave it as a body line. Re-verified against the tree while finalizing:
   it is a body line at `agents/reviewer.md:186`. Promoting it would migrate a
   shipped marker format that `stop-gate.sh` already globs on, for no benefit
   this milestone needs. Option (b) (promote, accept a format migration) was
   declined. **Effect on the spec: none.** Step 3 parses `commit:` from the
   marker body as drafted, and its documented fallback for an `.escalated`
   marker carrying no parseable `commit:` line stands unchanged.
3. **RESOLVED 2026-08-15 — no.** *Do you want the 14 existing mismatched
   markers corrected?* Chosen: option (a) — report only, Step 9 as written.
   Options (b) (a reviewer-authored correction pass as a later milestone) and
   (c) (drop Step 9 entirely) were declined; (b) remains available as a
   follow-on once Steps 1-8 have landed. **Effect on the spec: none.** Step 9
   stays read-only, C9.2 still asserts that it performs no write, the Out of
   scope exclusion is retained, and no correction step is added — only the
   reviewer may legitimately write into the reviewed-markers directory (R7).

## Self-check

- CHK1: Does the plan define what value the `commit:` field must hold, in one
  place, without two parts disagreeing? — PASS (Step 1 defines it; Steps 2,
  3, 4 reference that definition rather than restating a threshold)
- CHK2: Does every step have at least one criterion that is a runnable
  command with a pass/fail, not a prose assertion? — PASS
- CHK3: Are the "count must become N" criteria non-vacuous — i.e. is the
  pre-change count recorded and different? — PASS (C1.1, C2.1, C4.1, C5.1,
  C5.3, C5.4 each cite a measured pre-change count; all six were executed
  against the live tree)
- CHK4: Can C5.1 pass by deleting the wrong line? — FAIL (ambiguous) —
  revised in place (C5.2 added, pinning the session-baseline call that must
  survive)
- CHK5: Is the escalation-resolution fallback defined for an `.escalated`
  marker with no `commit:` line? — FAIL (missing) — revised in place (Step 3
  content now specifies the fallback and the note line)
- CHK6: Do Steps 5 and 7 agree about who regenerates `.claude/hooks/scripts`?
  — FAIL (conflicting) — revised in place (both now name Step 8 as the
  regenerator and forbid hand-editing; C5.7 states the slicing constraint
  explicitly)
- CHK7: Is the classifier's behaviour defined for a non-git project? — PASS
  (Step 6 algorithm case 2, test case (j), and the Clarifications
  edge-case line)
- CHK8: Is any acceptance criterion pinned to a SHA that a rebase would
  invalidate? — FAIL (ambiguous) — revised in place (Step 6 testing now
  mandates a self-built throwaway repo; C6.6, the only live-corpus check, is
  demoted to informational with its measurement date)
- CHK9: Does the plan say what happens if the classifier itself is broken or
  missing? — FAIL (missing) — revised in place (Step 7 "Failure posture" and
  C7.6)
- CHK10: Do the Goal's three outcomes G1/G2/G3 each map to at least one step
  with a criterion? — PASS (G1 → Step 3 / C3.1-C3.3; G2 → Steps 2, 4, 5 /
  C2.1-C2.3, C4.2, C5.1-C5.4; G3 → Steps 6, 7 / C6.1-C6.5, C7.1-C7.8)
- CHK11: Is constitution P4 ("optional personas degrade gracefully") checked
  by something runnable rather than asserted? — PASS (C7.5)
- CHK12: Does the plan avoid proposing a new test seam where an existing one
  serves? — PASS (Step 7 reuses `stop-gate.sh`'s existing review-join loop;
  one new script, one new test, no new seam)
- CHK13: Is the "warn vs block" decision represented in Open Questions, given
  it was self-resolved? — PASS (Open Question 1)
- CHK14: Is the retro-correction scope decision represented in Open
  Questions? — PASS (Open Question 3)
- CHK15: Does the plan name a prior-FAIL history that should suppress a
  `haiku` tag on any step? — PASS (R1, naming `gh274.fail`, `gh346-1.fail`,
  `gh346-2.fail` and the files they bind to; all three re-confirmed present
  on disk during the 2026-08-15 finalization pass)

Added by the 2026-08-15 finalization pass, after the human answered the three
Open Questions:

- CHK16: Does every "see Open Question <N>" cross-reference point at the
  question it actually names? — FAIL (conflicting) — revised in place (the
  Clarifications user-interaction-flow line and Step 7's `Config` note both
  cited "Open Question 2" for the warn-vs-block decision, which is Open
  Question 1; both corrected)
- CHK17: Does the Status line agree with the state of the Open Questions
  section? — FAIL (conflicting) — revised in place (Status read FINALIZED
  while three questions still stood open; Status now reads FINAL/unconditional
  and each question is marked RESOLVED with the option chosen)
- CHK18: After the human's answers, does any step body still read as
  conditional on an unresolved question? — PASS (all three answers selected
  the recommended default the draft already encoded, so no step text changed;
  each resolved question states "Effect on the spec: none" and names the
  criterion that already covers it — C7.4, Step 3's body-line parse, C9.2)
- CHK19: Is each of the three human answers recorded in Clarifications as a
  dated line, not merely consumed in the Open Questions section? — PASS
  (three dated 2026-08-15 lines appended to Clarifications, one per answered
  category: user interaction flow, domain entities, functional scope)

All seven FAILs across both passes (CHK4, CHK5, CHK6, CHK8, CHK9 in the
drafting pass; CHK16, CHK17 in the finalization pass) were resolved by
revision in place. Each re-check found no residual failure, and no CHK item is
represented in Open Questions as an unresolved item.

Open Questions 1-3 originated from Clarifications self-resolutions, not from
Self-check failures, and were surfaced for human veto because implementation
is deferred and a veto was therefore free. The human answered all three on
2026-08-15, choosing the recommended default in each case; they are now closed
and this spec is unconditional. No Self-check item remains open.

## Post-finalization addendum — 2026-08-15 (blast-radius relay)

Append-only. Three structural findings arrived from an `explorer` sweep after
this spec was marked FINAL and published as #385 with units #386-#394 filed.
Each was spot-verified against the tree rather than taken on report. **No step
was rewritten and no unit was re-scoped**; two findings are recorded as
amendments below, and one is recorded as explicitly *not* warranting a change
so it is not re-opened later.

### A1 — `human-decision-gate.sh` is NOT a G2 surface (no change warranted)

The relay described `hooks/scripts/human-decision-gate.sh:56-76` as validating
"sanctioned marker-write templates for all five marker types," which reads like
a missed surface for G2's "every surface that prescribes `rev-parse HEAD`."
Verified: it is not. `is_sanctioned_marker_write()` validates only the *shell
shape* of the write — the `cat > <path> << 'DELIM'` form, a single-quoted
delimiter, an inert body, and the delimiter as the last line — across the
`.pass|.fail|.directed|.blocked|.escalated` suffixes. It never inspects marker
*content*: `grep -nE 'rev-parse|commit:'` against that file returns **zero**
matches (measured 2026-08-15).

G2's surface list (Steps 2, 4, 5) is therefore complete as drafted. This file
is additionally in `protectedPaths`, so an unnecessary edit here would have
been actively costly. **No unit changes.**

### A2 — `decisions.js` corroborates Open Question 2's resolution

`bin/microworld-dashboard/decisions.js` is a third `.escalated` parsing site
not named in the original Context. Verified behaviour: it reads **only the
marker's first line** and matches it against the anchored regex
`^ESCALATE-TO-HUMAN (\S+) (\S+) trigger: (.*) microworld: (\S+)$`, then reads
sibling packet artifacts. It never reads the marker body.

Two consequences, both favourable:

- **Step 3 (G1) is unaffected.** It copies `commit:` from the marker *body*,
  which `decisions.js` does not parse. No new consumer must be taught anything,
  and #388's affected-files list stays correct.
- **Open Question 2's "do not promote `commit:` to the first line" is
  independently corroborated, and by a sharper argument than the one
  recorded.** The resolution cited `stop-gate.sh` globbing the shipped format.
  The stronger reason is this regex: it is anchored at both ends, so inserting
  a `commit:` field into the `.escalated` first line would not degrade it — it
  would fail the match outright, silently emptying `timestamp`, `trigger`, and
  `microworld` for every escalation in the dashboard. Recorded here so a future
  reader cannot re-open OQ2 without meeting this constraint first.

### A3 — C4.5 does not guard what Step 4 changes (criterion amended in scope)

Verified: `tests/adapter-protocol-parity.test.js` probes section headings and
escalation-prose artifacts (`ESCALATION_PROBES` — `Comprehension material
only`, `QUIZ.md`, `QUIZ-ANSWERS.md`, the `quiz:` tokens, `never graded by the
reviewer`). **Nothing in it asserts marker-format syntax.** No test anywhere
detects marker-format divergence between `adapters/codex/` and
`adapters/cursor/`.

Step 4 is **not** left ungated by this — C4.2, C4.3 and C4.4 grep the changed
prose directly in each port, and they remain the real gates. But C4.5 was
implicitly credited with regression cover it does not provide. Amendment:

> **C4.5 (amended).** `node tests/adapter-protocol-parity.test.js` exits 0.
> Scope note: this asserts *section presence and escalation-prose parity only*.
> It does **not** probe marker-format syntax, so it cannot detect a `commit:`
> divergence between ports. C4.2-C4.4 are the load-bearing criteria for this
> step; C4.5 is an unrelated-regression guard. Do not treat a green C4.5 as
> evidence the ports' marker format agrees.

The underlying coverage gap — no marker-format parity assertion in any test —
is **pre-existing, wider than this milestone, and deliberately not closed
here** (see Out of scope). Closing it means choosing which marker-format
substrings are load-bearing across three ports, which is its own scoping
question and would expand a milestone whose implementation is already deferred.
It is recorded as the top follow-on candidate.

### Self-check items for this addendum

- CHK20: Was each relayed finding verified against the tree before being
  acted on, rather than trusted from the report? — PASS (A1 by `grep -nE
  'rev-parse|commit:'` returning zero; A2 by reading the regex and its
  surrounding read; A3 by reading `ESCALATION_PROBES` and the port maps)
- CHK21: Does any finding invalidate a filed unit's affected-files list or
  acceptance criteria? — PASS (none does; A1 removes a surface that was never
  claimed, A2 confirms #388 as filed, A3 amends a criterion's stated scope
  without removing it or changing #389's edits)
- CHK22: Is the pre-existing adapter marker-format coverage gap represented
  somewhere a future reader will find it, rather than only in this addendum?
  — FAIL (missing) — revised in place (added to Out of scope and to the
  Scribe update hint)

## Scribe update hint

After Steps 1-8 land:

- `CONTEXT.md` — the two new glossary entries land in Step 1, but three
  pre-existing gaps surface alongside them and are scribe's, not this plan's:
  *comprehension material*, *measured heavy-unit surface*, and the
  `**CORRECTED YYYY-MM-DD —**` / `**SUPERSEDED YYYY-MM-DD —**` in-place
  annotation convention (all three carried over from `.pass` marker
  ubiquitous-language notes on units 299, 373, and 376).
- `.claude/wiki/modules/hooks.md` — new hook script, new config key, and the
  `warn` default with its rationale.
- The adapter parity coverage gap (addendum A3) — worth a durable note
  wherever adapter drift risks are tracked, since a green
  `adapter-protocol-parity.test.js` is easy to misread as marker-format cover.
- The wiki changelog — record that marker `commit:` semantics changed, since
  every marker written before this milestone means something subtly
  different from every marker written after it. That distinction is not
  recoverable from the markers themselves.
