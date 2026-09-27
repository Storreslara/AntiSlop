# Item 11: Replace ADR-0011's 10-second replay window with an id-keyed override list

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 11 of 19
Source: Fable adversarial review 2026-09-25, Gating Complaint 4 Alt B
Disposition: **ACCEPT in principle — but sequenced behind item 20's sibling question about H4.** The clock-based design is confirmed; the replacement is specced with an explicit correctness proof obligation.
Amended 2026-09-26: **Step 2 is PARKED** and Step 3 replaces it. See
[§ Scope reconsideration (2026-09-26)](#scope-reconsideration-2026-09-26).
Step 1 (item11-1) is PASSed and unaffected.

## Goal

Replace the cksum-keyed, clock-based 10-second replay window in
`dispatch-hygiene.sh` with a unit-id-keyed override list, removing clock-skew
handling from a hook.

## Context

Verified 2026-09-25 by reading `hooks/scripts/dispatch-hygiene.sh:157-245`:

- The dispatch identity key is `cksum` over `target_type` + `\x1e` + `prompt`.
- On finding an `override: <reason>` sentinel, the hook writes a consumed
  stamp `<epoch-seconds> <dispatch-key> <reason>`, deletes the sentinel, and
  exits 0.
- A replay path then honours a *consumed* stamp within 10 seconds if the
  dispatch key matches, so a `PreToolUse` double-fire does not force the
  operator to write the sentinel twice.
- The parsing code carries extensive defensive commentary about `set -u`
  arithmetic aborts, malformed lines, and leading-zero values like `008`
  passing a "purely numeric" regex.

That commentary is the strongest argument for the change: the current design
requires a hook to reason about clock skew, epoch parsing and arithmetic
safety in order to deliver *idempotency* — a property an id-keyed list gets
structurally, for free.

The review's alternative: make the override a list of unit ids
(`override: <id> <reason>`); any dispatch whose `Unit:` line matches is
allowed; the line is removed when that unit reaches PASS. No timing, no
cksum, no double-fire problem.

**One consequence the review states and accepts, which this spec must not
lose:** an id-keyed override cannot cover dispatches with no `Unit:` line —
non-gated targets that H1/H2 also apply to. The review says "accept that".
That is a **coverage reduction**, and accepting it silently would be exactly
the kind of unexamined trade this whole review is objecting to. Step 1
measures how many real dispatches would lose coverage before the change
lands.

**Related but separate:** the review also proposes deleting H4 (the
nine-element contract check), citing a ~100% warn rate. That is a different
decision about a different check and is raised here only as Open Question 2,
not bundled into the override change.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-25 Domain entities / data model: Q What removes an entry from the
  id-keyed list? → A (self-resolved): the unit reaching PASS. This creates a
  dependency on marker state that the current clock-based design does not
  have — a real new coupling, recorded in R2 rather than glossed.
- 2026-09-25 Edge cases / failure handling: Q What about dispatches with no
  `Unit:` line? → A (self-resolved): they lose override coverage. The review
  accepts this; this spec requires it to be **measured** (Step 1) before it
  is accepted.
- 2026-09-25 Technical constraints & tradeoffs: Q Is the double-fire the
  replay window handles real? → A (self-resolved): **yes** — ADR-0011 exists
  because `PreToolUse` was observed double-firing. Any replacement must be
  idempotent under double-fire, which the id-keyed design is by construction.
  This is the property to test, not assume.

## Risks and dependencies

- **R1. Idempotency is the whole point.** A replacement that is not
  double-fire-safe reintroduces the original bug. Step 2's criteria test this
  directly.
- **R2. New coupling to marker state.** Entry removal on PASS makes
  `dispatch-hygiene.sh` depend on marker state it does not read today. If the
  marker is never written, the override persists indefinitely — a failure
  mode the clock-based design does not have (it expires). Step 2 must define
  what bounds a stale entry.
- **R3. Coverage reduction** for `Unit:`-less dispatches — see Context.
- **R4. Mirror multiplication** — `dispatch-hygiene.sh` is 410 lines with
  mirror copies; `validate.sh` asserts parity.
- **R5. Large existing test surface** — `tests/dispatch-hygiene.test.sh` is
  1,055 lines. Expect substantial test rework; that is a cost of the change,
  not a surprise.
- **R6.** No prior `.fail` record known (new work); marker sweep Bash-gated.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the mechanism was read directly,
  including its defensive commentary.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  change replaces a timing heuristic with a structural rule.
- P3 "Version-stamp discipline": deviation — hook scripts and tests are not
  version-stamped. If ADR-0011 is superseded by a new ADR, that is a docs
  change, not a version-stamped file. If an implementer's diff reaches
  `agents/*.md` or templates, P3 re-applies.
- P4 "Optional personas degrade gracefully": satisfied — untouched.
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Measure the coverage that an id-keyed override would lose

**Affected files:** none modified; findings in the report.

Count, over the existing dispatch audit history, how many override uses were
for dispatches **without** a `Unit:` first line — i.e. how much real coverage
the change would drop.

**Acceptance criteria**
- The report states the count of historical override uses and how many
  carried a `Unit:` line.
- It states explicitly whether the coverage loss is **acceptable** (zero or
  near-zero non-unit overrides) or **material**, and if material, Step 2 does
  not proceed without a human decision.
- Read the audit log with the `Read` tool or another permitted route: a
  `wc -l`/`grep` Bash command naming an audit log is blocked by
  `harness-integrity-gate.sh` (reproduced live 2026-09-25). Do not rephrase
  to evade the gate.
- `git status --porcelain` is empty.

## Step 2 — Implement the id-keyed override list — **PARKED 2026-09-26, NOT DISPATCHABLE**

> Parked by § Scope reconsideration (2026-09-26) after item11-1's measurement.
> The body below is preserved verbatim as the *rejected-for-now* proposal so a
> future re-open has the original design to work from. **Do not dispatch it.**
> The live successor is Step 3.

**Affected files:** `hooks/scripts/dispatch-hygiene.sh` + mirrors;
`hooks/scripts/lib/state-access.sh` if the override accessors move;
`tests/dispatch-hygiene.test.sh`; a new ADR superseding ADR-0011.

**Acceptance criteria**
- Format: an override entry is `override: <unit-id> <reason>`; a dispatch
  whose first non-blank line is `Unit: <unit-id>` is allowed.
- **Double-fire idempotency proven:** invoking the hook twice with identical
  input allows **both** invocations, with no sentinel consumption between
  them. This is the property ADR-0011's window existed to provide.
- **Clock independence proven:** the test suite passes with the system clock
  perturbed (or with any epoch-dependent code removed) — assert that
  `grep -c 'date +%s' hooks/scripts/dispatch-hygiene.sh` is **0** in the
  override path.
- `cksum`-keyed replay machinery is gone:
  `grep -c 'cksum' hooks/scripts/dispatch-hygiene.sh` is **0**.
- Stale entries are bounded (R2): the implementation defines and the tests
  cover what happens to an override for a unit that never reaches PASS.
- Non-vacuity by mutation: break the id match, confirm the relevant tests
  **fail**, revert, confirm they pass. Recorded in the report.
- `bash tests/dispatch-hygiene.test.sh` exits 0; `bash tests/validate.sh`
  exits 0; mirror parity holds.
- A new ADR supersedes ADR-0011 and states the accepted coverage reduction
  from Step 1 as a number, not as prose.

## Open Questions

1. **If Step 1 finds the coverage loss is material, is it still acceptable?**
   Recommended default: **do not proceed on a material loss** — the clock
   handling is ugly but working, and trading working coverage for elegance is
   the wrong direction. Requires a human decision only if Step 1 reports
   material loss.
2. **Should H4 (the nine-element contract check) be deleted?** The review
   reports it fired on 58 of the first 60 dispatches; the first 15 lines of
   `.claude/dispatch-audit.log` are `warned=H4 target=lead-programmer`
   without exception, which corroborates a very high rate. In `warn` mode it
   blocks nothing. The review proposes enforcing the contract where prompts
   are *authored* instead. Recommended default: **do not delete; move
   enforcement to authoring time** — a ~100% trip rate means the orchestrator
   is not emitting the contract, which is a real finding H4 is currently the
   only thing surfacing. Deleting the check would delete the evidence.
   Deserves its own spec; flagged here because it shares a file. Requires a
   human decision.

## Self-check

- CHK1: Is the coverage reduction measured rather than assumed acceptable? —
  PASS (Step 1 gates Step 2).
- CHK2: Is idempotency tested rather than argued? — PASS (Step 2's
  double-fire criterion).
- CHK3: Does the new design introduce an unbounded stale state? — FAIL
  (missing) — revised in place: R2 names the coupling and Step 2 requires
  stale-entry bounding to be defined and tested.
- CHK4: Is H4 bundled into this change? — PASS (explicitly separated into
  Open Question 2).
- CHK5: Is the clock-independence claim checkable? — PASS (explicit
  `grep -c 'date +%s'` assertion on the override path).
- CHK6: Does Step 1 respect the gate that blocks audit-log reads? — PASS (it
  names the permitted route and forbids rephrasing).

## Scribe update hint

Add **id-keyed dispatch override** and retire the **replay window** entry
in place (per the repo's retirement-note convention) once the new ADR lands.
Record the accepted coverage reduction as a number in the glossary entry.

## Dispatch contract (fast path — 2 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item11-dispatch-override-replay-window.md`.
Order: Step 1 strictly gates Step 2.

### Unit: item11-1-measure-coverage-loss
- **Objective:** Measure how many historical overrides lacked a `Unit:` line.
- **Retrieval:** Step 1.
- **Affected files:** none.
- **Ordered edits:** read override history → classify by `Unit:` presence → state acceptable/material.
- **Do NOT touch:** the hook, its tests, or any audit log.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** a Bash `wc -l`/`grep` naming an audit log is blocked by `harness-integrity-gate.sh` (Set A) — reproduced live 2026-09-25; the `Read` tool succeeds on the same file. Use `Read`. Never rephrase a command to evade the gate.
- **Escalation:** if override history is too sparse to classify, report "insufficient data" — that blocks Step 2 pending a human decision rather than defaulting to "acceptable".

### Unit: item11-2-id-keyed-override — **SUPERSEDED / NOT DISPATCHABLE (2026-09-26)**
Parked; replaced by `item11-3-record-override-disposition` in § Scope
reconsideration. Preserved verbatim for a future re-open.
- **Objective:** Replace the clock-based replay window with an id-keyed list.
- **Retrieval:** Step 2. **Conditional on item11-1 reporting acceptable loss.**
- **Affected files:** `hooks/scripts/dispatch-hygiene.sh` + mirrors, possibly `lib/state-access.sh`, `tests/dispatch-hygiene.test.sh`, a new superseding ADR.
- **Ordered edits:** implement id-keyed list → prove double-fire idempotency → remove cksum/epoch machinery → bound stale entries → rework tests → mutate-prove → propagate mirrors → write ADR.
- **Do NOT touch:** H1/H2/H3 logic; H4 (Open Question 2 owns it).
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** current mechanism at `dispatch-hygiene.sh:157-245`; key is `cksum` over `target_type`+`\x1e`+`prompt`; consumed stamp is `<epoch> <key> <reason>`. `tests/dispatch-hygiene.test.sh` is 1,055 lines — expect substantial rework. ADR-0011 exists because `PreToolUse` was observed double-firing; that must not regress.
- **Escalation:** if double-fire idempotency cannot be achieved without reintroducing timing, report — that would mean the review's premise is wrong and the window is load-bearing.

---

## Scope reconsideration (2026-09-26)

**Decision: option (c) — park the id-keyed rework.** Keep the existing
clock-based, `cksum`-keyed replay window and the escape hatch exactly as they
are. Ship one small documentation-correction unit (Step 3) so the same
zero-usage inference is not re-derived from the same audit log next quarter.
Neither (a) proceed as specced nor (b) delete the escape hatch is adopted, for
the reasons below.

### Why the zero-usage measurement cannot support the change

item11-1's finding is correct and independently re-verified here. Its
*interpretation* is what changes the decision: the zero is explained by
configuration, not by lack of value.

1. **This repo runs `dispatchHygiene.mode: "warn"`.** Verified live:
   `jq -r '.dispatchHygiene.mode' .claude/persona-config.json` prints `warn`.
   It became `warn` in commit `0f6efa7` ("config(gh401): adopt solo-operator
   posture per ADR-0018", authored `2026-08-16T00:51:15-05:00` =
   `2026-08-16T05:51:15Z`, a 2-line diff touching only that config).
2. **In `warn` mode nothing is ever blocked**, so nothing ever needs
   overriding. `dispatch-hygiene.sh:390-396` selects `warned=` and `:409`
   exits 0; only `block` mode reaches `exit 2` at `:410`.
3. **The entire recorded history is warn-mode.** Re-read the full log
   (229 lines as of 2026-09-26T17:38Z, one more than item11-1 saw): **every
   line** carries `warned=`. Zero `blocked=`, zero `override=`, zero
   `override-replay=`, zero `h3-stale-marker=`. Because `warned=` is emitted
   *only* when `mode = warn`, the log itself proves the posture for every
   recorded event — including the very first line
   (`2026-08-16T05:51:06Z warned=H4`), which precedes the posture commit by
   9 seconds and is therefore already warn-mode.
4. **So the escape hatch's trigger condition never occurred in the recorded
   window.** Zero uses of a bypass during a period containing zero blocks is a
   tautology, not evidence. The one window in which the hatch *could* have
   fired — block mode, from the override's landing (`37fec4b`, 2026-08-02; the
   hook itself `6829050`, 2026-07-30) to the posture flip on 2026-08-16 — is
   exactly the ~2-week blind gap at the front of the log, with no rotation
   archive to recover it (item11-1 non-blocking note 2). **The measurement is
   structurally incapable of answering the question item11-2 needs answered.**

### Why not (b) delete the escape hatch

- **Downstream installs run `block`, not `warn`.** The hook defaults `mode` to
  `block` (`dispatch-hygiene.sh:124`) and no scaffold path writes the key —
  `git grep dispatchHygiene -- bin/cli.js` returns nothing; only
  `templates/persona-config.schema.json` mentions it, and its own prose at
  `:126` names `dispatchHygiene`'s default as `"block"`. Every freshly
  installed project therefore blocks, where the hatch is the **only
  per-dispatch bypass**. This repo's `warn` posture is a local, deliberate
  exception ([ADR-0024](../adr/0024-ceremony-reduction-solo-operator.md)), not
  the product default. Deleting a product-wide escape hatch on the strength of
  one repo's local posture is the wrong inference from the wrong denominator.
- **The only remaining route would be worse.** A blocked downstream operator
  with no hatch must edit `dispatchHygiene.mode` to `warn`/`off` — disarming
  the gate **globally and persistently** instead of once, audited, and
  self-expiring. That trades a bounded per-dispatch exception for an unbounded
  posture change, and it leaves no `override=` line in the audit trail.
- **ADR-0014 cites the hatch as the justification for shipping hygiene as a
  hook at all** (`docs/adr/0014-…:66-69`: "`.claude/.dispatch-override` exists
  precisely because a hook…"). Deleting it invalidates that ADR's reasoning,
  which is a much larger change than the one being proposed.
- **ADR-0011's own governing sentence cuts against removal:** "The mechanism's
  failure is worse than having no escape hatch, because the operator
  *believes* they have one" (`:18-19`). That argues for a hatch that works —
  which is what exists today — not for removing a working one.
- **It also contradicts the shared protocol.** "Blocked by a gate you do not
  own" instructs every persona to use *sanctioned* exits and names
  self-authorized bypasses as violations. Removing a sanctioned exit leaves
  only unsanctioned routes for a real false-positive block.

### Why not (a) proceed as specced

- **Step 1's own gate fired the other way.** item11-1's escalation clause says
  "if override history is too sparse to classify, report 'insufficient data' —
  that blocks Step 2 pending a human decision rather than defaulting to
  'acceptable'." Zero overrides is zero data, so the *insufficient-data*
  branch is what the measurement actually hit; the "acceptable (zero or
  near-zero non-unit overrides)" branch reads as satisfied only if a zero
  denominator is mistaken for a zero numerator. Open Question 1's recommended
  default ("do not proceed on a material loss") therefore governs, because
  immateriality was never demonstrated.
- **The id-keyed design has a measured, not hypothetical, coverage hole.** H1
  and H2 fire *outside* the `is_gated` block (`dispatch-hygiene.sh:272` and
  `:299`), so they block **non-gated** targets, which carry no `Unit:` line and
  which an id-keyed override structurally cannot authorize. The log contains a
  real instance: `2026-09-25T18:07:55Z warned=H1 target=spec-master` — the only
  non-gated event in 229 lines, and precisely the category the replacement
  cannot cover. `gatedAgents` is `["lead-programmer"]` alone, so every
  `explorer`/`scribe`/`reviewer`/`spec-master` dispatch is in this uncovered
  class. The current `cksum`-over-`target_type`+prompt key covers all of them.
  R3 is thus not a rounding error to "accept"; it is a hole aimed squarely at
  the only observed non-gated block.
- **ADR-0011's named root cause has since been fixed at source**, further
  lowering the return. The double *registration* that produced the double-fire
  came from `deepMerge` deduping arrays by reference (issue #228); commit
  `2db2503` ("deepMerge uses structural equality for array dedup with
  key-order tolerance") closed it. ADR-0011's *cross-file* registration path
  (`.claude/settings.json` + the plugin's `hooks.json`) remains explicitly
  unfixable by any settings-merge (`:56-72`), so the window still has a live
  reason to exist — but reworking it buys structural idempotency for a
  mechanism that already has *tested* idempotency (sequential double-fire was
  measured at 100% failure before the window, 15% parallel; `:13-16`) against a
  trigger that is now rarer than when it was written.
- **Measured cost of the rework** (blast radius, this session): 84 lines of
  hook logic (`:162-181` sentinel path, `:188-245` replay path); 9
  `state-access.sh` accessors plus their two byte-identity-asserted adapter
  mirrors (`adapters/codex/`, `adapters/cursor/` — `tests/validate.sh:28,48`);
  10 test cases (T14, T15, T28, T31, T32, T33, T35, T36, T39, T42) inside a
  1,055-line suite, two of which (T33, T42) are mutation controls that exist
  only to prove the window non-vacuous; the `.claude/hooks/scripts/` mirror and
  its `fileHashes` entry; a superseding ADR; plus `agents/orchestrator.md`
  (3 references), the wiki, and glossary prose. That is a five-plus-artifact
  change to a passing, zero-incident mechanism.

**Net:** (a) spends a large, multi-artifact change to make a never-triggered
path *structurally* idempotent while *reducing* its coverage on the one
category actually observed tripping a check. (b) removes the product's only
sanctioned per-dispatch bypass on evidence drawn from a repo that has disabled
blocking. (c) keeps working, tested, audited machinery and spends one docs unit
making the record accurate. (c) wins.

### Re-open triggers (the park is conditional, not permanent)

Re-open item11-2 — from the preserved Step 2 body — if **either** occurs:

1. **`dispatchHygiene.mode` in `.claude/persona-config.json` returns to
   `"block"`** in this repo, or a downstream install reports a real block. That
   restores the hatch's trigger condition, and the *first* `override=` or
   `blocked=` line in `.claude/dispatch-audit.log` makes the coverage question
   measurable for the first time. At that point re-run item11-1's measurement
   against the *newly* recorded window before touching the design.
2. **A double-fire recurs** (two `override=`/`override-replay=` lines for one
   operator action, or a re-registration of the hook across
   `.claude/settings.json` and the plugin's `hooks.json`). That is the only
   condition under which the window's correctness is load-bearing again, and
   the id-keyed design's idempotency-by-construction becomes worth its cost.

Absent both, the clock machinery's ugliness is a cosmetic complaint about code
that works, is tested, and has never failed — the trade Open Question 1
already named as "the wrong direction".

### Premise corrections to the inputs

Recorded so a future reader does not inherit them:

- **item11-1's note about glossary `:370` ("escape hatch" under `_Avoid_`) vs
  the hook's `:401` message is a false positive.** `_Avoid_` is
  **entry-scoped** in this glossary, not global — `:1533` says so in its own
  text ("use 'bootstrap window' *for this specific*…"), and `:370` belongs to
  the human-confirmation-branch entry, which deprecates "escape hatch" as a
  name for *that* branch. The dispatch override's own entries (`:648`, `:851`)
  use "escape hatch" as the canonical phrasing. **The hook's `:401` message
  needs no change.**
- **item11-1's note that no "replay window" glossary entry exists is correct**
  and is carried into Step 3, so the original "Scribe update hint" is wrong on
  that point: Step 3 *creates* the entry rather than retiring one.
- **The `explorer`'s blast-radius report was wrong on two negatives** (it
  claimed `docs/harness-glossary.md` contains no `dispatch-override`
  references, and that no mirror of `dispatch-hygiene.sh` exists). Both are
  false: the glossary references it at `:366`, `:648-649`, `:827`, `:851-852`,
  and `.claude/hooks/scripts/dispatch-hygiene.sh` is a managed mirror
  (`tests/validate.sh:330-331`). Its positive findings (line ranges, accessor
  names, the 10 test ids) were spot-checked and hold. Figures above are from
  first-hand reads, not that report.
- **Step 1's `git status --porcelain` criterion was unsatisfiable** (19
  pre-existing untracked plan docs). Not re-litigated — Step 1 is PASSed — but
  Step 3 below uses `git diff --quiet HEAD` plus a path-scoped
  `git status --porcelain <paths>` instead, and that is the form to use in
  future criteria.
- **229 (or 228) log lines is not an exposure denominator:** a clean dispatch
  logs nothing (`:388`) and one dispatch can emit two lines. Step 3 forbids
  citing it as one. Event breakdown, counted from the full read: H4 ×222,
  H3 ×4, H2 ×2, H1 ×1.

### Clarifications (amendment round, 2026-09-26)

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-26 Edge cases / failure handling: Q What happens to this decision if
  the posture flips back to `block`? → A (self-resolved): the park is
  conditional — re-open trigger 1 names that exact event, and requires
  re-measuring against the newly recorded window rather than reusing this zero.
- 2026-09-26 Technical constraints & tradeoffs: Q Is R3's coverage reduction
  actually immaterial, as the review assumed? → A (self-resolved): **no** —
  H1/H2 fire on non-gated targets (`:272`, `:299`), which have no `Unit:` line;
  the log's single non-gated event (`warned=H1 target=spec-master`,
  2026-09-25) is exactly that class. The id-keyed design cannot cover it. This
  is the decisive technical reason (a) is not adopted.
- 2026-09-26 Terminology consistency: Q Does the harness glossary describe the
  mechanism accurately? → A (self-resolved): **no** — `:648` and `:851` both
  call it a "single-use escape hatch", false since ADR-0011 landed 2026-08-02
  (single use **plus** a bounded 10-second replay), and no "replay window"
  entry exists at all. Step 3 fixes both. `antislop:ubiquitous-language`
  (prose mode) against the domain glossary `CONTEXT.md` returns **no findings
  on any of its three lenses**: `CONTEXT.md` contains zero references to
  `dispatch-override`, "replay", "escape hatch", or "Dispatch hygiene" — every
  term at issue is harness-mechanics vocabulary living in
  `docs/harness-glossary.md`, which that skill explicitly scopes out. The
  drift is real but belongs to the harness glossary (same `scribe` custody).

### Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the posture, the full 229-line log,
  the `warned=`-implies-warn coupling, the non-gated H1/H2 placement, the
  `#228` fix, and the glossary's `_Avoid_` scoping were each read directly, and
  two of the explorer's negatives were caught and corrected by re-checking.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step 3
  changes only prose and asserts it with greps; no script-managed file is
  hand-edited.
- P3 "Version-stamp discipline": **not triggered** — Step 3 touches only
  `docs/adr/0011-*.md` and `docs/harness-glossary.md`, neither of which is
  `agents/*.md` nor a template. AC3.7 forbids a version bump or any
  mirror-regeneration cascade, so `--update` semantics are unaffected.
- P4 "Optional personas degrade gracefully": satisfied — no persona prose
  changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied — AC3.6 runs it, which
  includes the `[[link]]`-integrity guard at `validate.sh:809`.

## Step 3 — Record the disposition and correct the glossary's account of the mechanism

**Affected files:** `docs/adr/0011-dispatch-override-idempotency-window.md`
(annotate; **do not** supersede, do not change its `Status:` line) and
`docs/harness-glossary.md`. Nothing else.

This is documentation only. No hook, test, mirror, adapter, config, or persona
file is touched. The reason it is worth shipping at all is that three
grep-verifiable inaccuracies are what allowed the "unused, therefore delete it"
reading to be generated in the first place, and they will keep generating it.

**Why an annotation and not a new ADR:** ADR-0011 already owns this mechanism,
and by `domain-modeling`'s three tests a *decision not to change* it adds no
new hard-to-reverse commitment of its own. A fresh ADR whose entire content is
"we kept ADR-0011" splits one authority into two, and would also have to
re-derive a free ADR number — which sibling item specs in this same batch are
concurrently competing for. Annotating in place avoids both.

**Acceptance criteria**

- **AC3.1 — the "single-use" claim is gone.**
  `git grep -c "single-use" -- docs/harness-glossary.md` is **0**. Measured
  baseline: it is **2** today, at `:648` and `:851`, and those are the *only*
  two occurrences in the whole file, so a 0 target is exact and cannot be
  satisfied by deleting unrelated prose. **Grep the hyphenated word alone, not
  the phrase** — "single-use escape hatch" is line-wrapped at both sites
  (`:648-649`, `:851-852`), so a phrase grep matches nothing before *or* after
  the fix and would be a vacuous criterion (verified 2026-09-26: it returns no
  match on the current tree). Paired positive check:
  `git grep -c "bounded 10-second replay" -- docs/harness-glossary.md` is
  **≥ 2** (it is 0 today), so both sites state the actual behaviour rather than
  one being fixed and the other left stale. If a replacement wording other
  than that exact phrase is chosen, keep the same shape: one grep that must
  reach 0 and one that must reach 2.
- **AC3.2 — a `replay window` entry exists and is anchored to its evidence.**
  `docs/harness-glossary.md` gains a `**replay window**` entry containing all
  of: the string `10-second`, the two measured pre-window failure rates `100%`
  and `15%` (verifiable against
  `docs/adr/0011-dispatch-override-idempotency-window.md:13-16`), a link to
  that ADR, and the fact that the key is a `cksum` over `subagent_type` plus
  the prompt. Checkable as five greps scoped to the new entry.
- **AC3.3 — ADR-0011 gains a dated reconsideration section** headed exactly
  `## Reconsidered 2026-09-26: id-keyed replacement parked`, stating these six
  facts, each verifiable against the named source:
  1. this repo runs `dispatchHygiene.mode: "warn"` since commit `0f6efa7`
     (2026-08-16), per [ADR-0024](0024-ceremony-reduction-solo-operator.md);
  2. `warned=` is emitted only in `warn` mode
     (`hooks/scripts/dispatch-hygiene.sh:390-396`), so an all-`warned=` log
     proves the posture for every recorded event;
  3. the recorded `.claude/dispatch-audit.log` history contains zero
     `override=`, zero `override-replay=` and zero `blocked=` entries — i.e.
     **zero blocked dispatches**, so the hatch's trigger condition never
     occurred and the zero is not evidence about the hatch;
  4. the record begins 2026-08-16 while the hook landed 2026-07-30
     (`6829050`) and the override 2026-08-02 (`37fec4b`) — a ~2-week
     unrecoverable blind window, no rotation archive;
  5. the log's line count is **not** an exposure denominator, because a clean
     dispatch logs nothing (`:388`) and one dispatch can emit two lines;
  6. H1/H2 fire on non-gated targets (`:272`, `:299`) that carry no `Unit:`
     line, so an id-keyed override cannot cover them — with the observed
     instance (`2026-09-25T18:07:55Z warned=H1 target=spec-master`) named.
  The section must also state the decision (id-keyed rework parked, window and
  hatch retained) and both re-open triggers from § Scope reconsideration.
- **AC3.4 — ADR-0011 is annotated, not superseded.**
  `git grep -c "^Status: Accepted" -- docs/adr/0011-dispatch-override-idempotency-window.md`
  is **1**, the file contains no `Superseded` string, and
  `git status --porcelain docs/adr/` reports **exactly one** entry, the
  modified `0011-…md` — i.e. no new ADR file was created.
- **AC3.5 — claim accuracy is verified, not assumed.** The report quotes, for
  each of AC3.3's six facts, the command or file:line that confirms it, and
  states that the reviewer can re-run it. Read `.claude/dispatch-audit.log`
  with the `Read` tool: a Bash command naming an audit log is blocked by
  `harness-integrity-gate.sh` (Set A), and a Bash command spelling a reviewed-
  marker path is blocked by `reviewed-path-gate.sh` (this plan's own append hit
  that gate, via a heredoc, and was rerouted through the `Edit` tool rather
  than reworded). **Never rephrase a command to evade either gate** — report
  the block instead.
- **AC3.6 — `bash tests/validate.sh` exits 0**, which includes the
  `CONTEXT.md`/`docs/harness-glossary.md` `[[link]]`-integrity guard at
  `tests/validate.sh:809` (`node tests/context-glossary-links.test.js` may be
  run directly for a faster inner loop). Any `[[…]]` link the new entry
  introduces must resolve.
- **AC3.7 — no cascade, measured against a dispatch-time baseline (NOT against
  a clean tree).** `git diff --name-only HEAD -- docs/adr docs/harness-glossary.md`
  lists **exactly** the two files named above, and
  `git diff --name-only HEAD -- hooks adapters agents templates tests .claude-plugin .claude`
  is **byte-identical to the same command's output captured as the unit's first
  action**, quoted in the report. No `.claude-plugin/plugin.json` version bump.
  **Do not assert that those paths are clean:** verified 2026-09-26, the tree
  carries unrelated in-flight work — `hooks/scripts/lib/state-access.sh`,
  `hooks/scripts/marker-write.sh`, `tests/marker-write.test.sh`, the two
  `adapters/*/hooks/scripts/lib/state-access.sh` mirrors, their two `.claude/`
  mirrors, and `.claude/persona-config.json` are all modified-uncommitted (that
  is item12's `state_append_unit_marker`, confirmed not to touch any
  `dispatch_override`/`dispatch_consumed` accessor). A clean-tree assertion
  here would be unsatisfiable by any correct execution — the same defect class
  the reviewer flagged in Step 1. The baseline-comparison form still catches a
  cascade while attributing pre-existing dirt to its real owner.
- **AC3.8 — the hook's operator-facing message is unchanged.**
  `git diff --quiet HEAD -- hooks/scripts/dispatch-hygiene.sh` exits 0. Its
  `:401` "Escape hatch, audited and bounded replay" wording is **correct as
  written** (see the `_Avoid_`-scoping correction above) and must not be
  "fixed".
- **AC3.9 — this unit adds no tracked modification outside the two targets.**
  Do **not** use a bare `git status --porcelain` emptiness check, and do not use
  a bare `git diff --quiet HEAD`: 19 untracked `docs/plans/2026-09-25-item*.md`
  files and 8 modified-uncommitted tracked files (AC3.7) both pre-exist, so
  either bare form is unsatisfiable by a correct execution. Use the
  baseline-delta form in AC3.7, and never `git add`, `git commit -a`, `git
  stash`, or `git checkout` anything outside the two target files — another
  unit's uncommitted work is live in this tree.

## Dispatch contract (amendment — 1 unit, fast path)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item11-dispatch-override-replay-window.md`,
§ Scope reconsideration (2026-09-26) and Step 3. No tracker issue exists for
this unit; there is nothing for `scribe` to close.

### Unit: item11-3-record-override-disposition
- **Objective:** Record the parked disposition as a dated annotation on
  ADR-0011, and correct `docs/harness-glossary.md`'s account of the dispatch
  override (drop the false "single-use" characterization; create the missing
  `replay window` entry). No behaviour change.
- **Retrieval:** Step 3 and § Scope reconsideration (2026-09-26) of this
  document. Read `docs/adr/0011-dispatch-override-idempotency-window.md` and
  `docs/harness-glossary.md:635-660`, `:843-856`, `:360-370` before editing.
- **Affected files:** `docs/adr/0011-dispatch-override-idempotency-window.md`,
  `docs/harness-glossary.md`. Exactly two files.
- **Ordered edits:** (1) append the `## Reconsidered 2026-09-26: id-keyed
  replacement parked` section to ADR-0011, above its `## Related` section, with
  AC3.3's six facts plus the decision and both re-open triggers; (2) add
  ADR-0024 and this plan path to ADR-0011's `## Related` list; (3) replace
  "single-use escape hatch" at `docs/harness-glossary.md:648` and `:851` with
  wording that says single use **plus a bounded 10-second replay**; (4) add the
  `**replay window**` glossary entry per AC3.2, adjacent to the existing
  **Dispatch hygiene** entry (`:635`), in the file's prevailing entry format
  (`**term**:` at column 0, opening `(unit item11-3, 2026-09-26) — …`, matching
  neighbours). **The glossary is not alphabetically ordered** — verified
  2026-09-26: it has a single `## Language` header and entries run
  `registration-presence assertion` `:488`, `review-join stamp` `:776`,
  `results-reported cursor` `:895`, `reason class` `:2401` — so do not attempt
  to find an alphabetical slot; (5) run AC3.6 and AC3.7's checks; (6) write the
  report
  with AC3.5's per-fact verification.
- **Do NOT touch:** `hooks/**` (especially `dispatch-hygiene.sh` — AC3.8),
  `adapters/**`, `tests/**`, `.claude/**`, `agents/**`, `templates/**`,
  `.claude-plugin/plugin.json`, `CHANGELOG.md`, `CONTEXT.md`. Do not create a
  new ADR. Do not change ADR-0011's `Status:` line. Do not rewrite Step 2 or
  the item11-2 contract block — they are preserved deliberately.
- **Acceptance criteria:** AC3.1 – AC3.9 as written in Step 3.
- **Pre-resolved context:** all figures are first-hand measurements from this
  session, safe to reuse without re-deriving: `dispatchHygiene.mode` = `warn`
  (commit `0f6efa7`, 2026-08-16T05:51:15Z); the audit log is 229 lines, **all**
  `warned=`, breakdown H4 ×222 / H3 ×4 / H2 ×2 / H1 ×1, the single H1 being
  `2026-09-25T18:07:55Z warned=H1 target=spec-master`; `gatedAgents` =
  `["lead-programmer"]`; the log's first line is
  `2026-08-16T05:51:06Z warned=H4`, 9 seconds before the posture commit;
  ADR-0011's measured pre-window failure rates are 100% sequential and 15%
  (3/20) parallel at `:13-16`; the override path is
  `dispatch-hygiene.sh:162-181` + `:188-245` (84 lines); H1/H2 fire at `:272`
  and `:299`, outside the `is_gated` block; `#228` was fixed by `2db2503`.
  `_Avoid_` in the glossary is entry-scoped (`:1533` states this in its own
  text), so `:370` does not deprecate "escape hatch" for the dispatch override.
  **Gates:** use `Read` for `.claude/dispatch-audit.log`
  (`harness-integrity-gate.sh`, Set A) and never spell a reviewed-marker path
  inside a Bash command where bash would act on it (`reviewed-path-gate.sh`);
  `git` is not allowlisted by that gate at all. Report a block, never rephrase
  around one.
- **Escalation:** if the `[[link]]`-integrity guard (AC3.6) rejects a link the
  new `replay window` entry needs — e.g. it must point at a term that has no
  entry — report it rather than inventing a target entry; that is a glossary
  gap for `scribe`, not this unit's to fill. If any of AC3.3's six facts fails
  to verify on re-check, stop and report: the disposition's reasoning rests on
  them, and a false one must reach `spec-master` before it is written into an
  ADR.

## Self-check (amendment round)

- CHK7: Does the amendment state which of (a)/(b)/(c) was chosen, in one place,
  unambiguously? — PASS (§ Scope reconsideration opens with "option (c)"; Step 2
  and the item11-2 contract block are both marked non-dispatchable).
- CHK8: Is the claim "zero usage is not evidence" backed by something a
  reviewer can re-run, rather than by argument? — PASS (the
  `warned=`-implies-`warn`-mode coupling at `:390-396`/`:409-410`, the live
  `jq` on the config, and the all-`warned=` log are each independently
  checkable).
- CHK9: Does the amendment say what would make the parked step live again? —
  PASS (two named re-open triggers, each a specific observable event, not a
  time limit).
- CHK10: Do the amendment and the preserved Step 2 disagree about whether the
  id-keyed design is correct? — FAIL (conflicting) — revised in place: Step 2's
  heading and the item11-2 contract block now both carry an explicit PARKED /
  SUPERSEDED marker naming this section, and state that the body is retained as
  the rejected-for-now proposal.
- CHK11: Is every acceptance criterion in Step 3 runnable, given that the
  deliverable is prose accuracy? — PASS (AC3.1/AC3.2/AC3.4 are greps that catch
  the *wrong* text rather than merely confirming new text exists; AC3.6–AC3.9
  are exit-code checks; AC3.3's six facts are each anchored to a named
  file:line or commit the reviewer can re-read, and AC3.5 requires that
  verification to be reported).
- CHK12: Does Step 3 avoid the unsatisfiable-criterion defect item11-1 hit? —
  PASS (AC3.9 names the 19 pre-existing untracked plan docs and mandates
  path-scoped checks instead of bare `git status --porcelain` emptiness).
- CHK13: Is the one non-trivial risk of parking — that the hatch is left
  unexercised and could be silently broken — stated? — FAIL (missing) —
  revised in place: see R7 below.
- CHK14: Were AC3.1's greps actually run against the current tree before
  handoff, rather than assumed to match? — FAIL (ambiguous) — revised in place:
  the first draft asserted `git grep -c "single-use escape hatch"` → 0, which
  **already returns no match today** because the phrase is line-wrapped at both
  sites, i.e. it would have passed vacuously. AC3.1 now greps the hyphenated
  word alone (measured: exactly 2 occurrences, both at the target sites) and
  records why the phrase form is wrong.
- CHK15: Does the plan's placement instruction match the glossary's actual
  ordering? — FAIL (missing) — revised in place: the first draft said
  "alphabetical position"; the file is **not** alphabetically ordered (one
  `## Language` header, entries at `:488`/`:776`/`:895`/`:2401` out of order).
  Ordered edit 4 now says "adjacent to the **Dispatch hygiene** entry" and
  states the non-ordering as a verified fact.
- CHK16: Are AC3.7/AC3.9's tree-state checks satisfiable on the tree the unit
  will actually run against? — FAIL (missing) — revised in place: 8 tracked
  files are modified-uncommitted (item12 in flight), so the original
  clean-tree/`git diff --quiet` forms were unsatisfiable. Both now use a
  dispatch-time baseline delta, and AC3.9 forbids git operations that would
  absorb another unit's work.
- CHK17: Does the disposition's load-bearing config claim survive the tree's
  uncommitted state? — PASS, with the caveat recorded in R9: the *runtime*
  value is what the hook reads, and `jq -r '.dispatchHygiene.mode'` on the
  working tree prints `warn`. AC3.3 fact 1 must be re-verified with that
  command at execution time rather than inferred from commit `0f6efa7`.

## Risks added by the amendment

- **R7. An unexercised hatch could be silently broken.** Parking leaves a
  mechanism with zero production traffic in this repo, so a regression in it
  would not be noticed by use. This is bounded, not ignored: the 10 test cases
  (T14/T15/T28/T31/T32/T33/T35/T36/T39/T42) exercise the path on every
  `bash tests/dispatch-hygiene.test.sh` run, and two of them (T33, T42) are
  mutation controls proving those tests are non-vacuous. The test suite, not
  production traffic, is what keeps the hatch honest — the same arrangement
  every other `block`-mode-only path in the hook relies on. No new work is
  warranted for R7.
- **R8. The park's premise is config-dependent.** Everything above rests on
  `dispatchHygiene.mode` being `warn`. If that key changes, re-open trigger 1
  fires. It is deliberately not asserted by any test: the posture is an
  operator choice
  ([ADR-0024](../adr/0024-ceremony-reduction-solo-operator.md)), and pinning it
  with a guard would freeze a decision this repo may reverse.
- **R9. `.claude/persona-config.json` is modified-uncommitted as of
  2026-09-26**, and `harness-integrity-gate.sh` (Set A) blocks any Bash command
  naming it, so its uncommitted delta could not be diffed from this session —
  reported, not worked around. This does **not** weaken the decision: the hook
  reads the *working-tree* file at runtime, and
  `jq -r '.dispatchHygiene.mode' .claude/persona-config.json` prints `warn`
  there (verified). But it does mean the provenance half of AC3.3 fact 1
  ("`warn` since commit `0f6efa7`") must be stated as "the runtime value is
  `warn`, set by `0f6efa7` on 2026-08-16", re-verified with that `jq` command at
  execution time. If it ever prints `block`, re-open trigger 1 has already
  fired and this unit should stop and report instead of writing the annotation.
