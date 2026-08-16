# Ceremony reduction for the solo-operator posture

Date: 2026-08-15
Status: **FINAL** 2026-08-15 — unconditional. All four Open Questions were
answered by the operator on 2026-08-15, choosing the recommended default in
every case; each is marked RESOLVED below with its effect on the spec. The
two placeholder literals are now fixed: `<TRIGGER-PHRASE>` is
**`only when the operator explicitly asks`** (AC2.3) and `<ASK-MECHANISM>` is
**`AskUserQuestion`** (AC4.2). Ready for `task-master` slicing.
**Blocking dependency:** Step 3 must not begin until the in-flight
`docs/plans/2026-08-15-marker-commit-attribution.md` work has landed — see R4
and the sequencing note in Step 3.
Published: umbrella `[spec]` issue
https://github.com/Storreslara/AntiSlop/issues/395 (label `ready-for-agent`),
via the `to-spec` PRD mapping. That issue is the PRD *view*; this document
remains the canonical artifact. Per-step units are sliced from it by
`task-master` under label
`plan/2026-08-15-ceremony-reduction-solo-operator`.
Source audit: independent read-only `fable` review of this repo's own
agent-team workflow (review frequency, gate self-interference, ceremony/
progress token ratio), relayed via the orchestrator. Five recommendations.
Author: `spec-master`. Slicing and per-unit dispatch prompts belong to
`task-master` (this spec resolves to 5 units, above the ≤2 fast path).

## Goal

Cut the per-unit ceremony cost of this repo's own persona workflow along
five axes the audit named, **without deleting a single load-bearing rule**:

1. Stop escalating heavy units to a human by default (operator opt-out).
2. Stop *blocking* dispatch on hygiene violations; log them instead.
3. Stop running the milestone audit unconditionally; make it on-demand.
4. Widen the `spec-master` fast path from ≤2 to ≤5 dispatchable units, so
   mid-size specs skip `to-tickets` slicing and tracker round-tripping.
5. Stop auto-spawning an `opus` debug-spec cycle at the 2-FAIL cap; ask the
   human first.

Every change is a reduction in *automatic* friction. None removes a
capability: each mechanism survives and remains reachable, either by config
value or by explicit request.

## Context

Verified against the tree at `d25419c` (2026-08-15). Three of the audit's
characterizations needed correction before speccing — noted inline below.

**Change 1 — `humanReviewMode`.** The key is present and explicit in
`.claude/persona-config.json` (`"critical"`). Its default is stated in three
places: `templates/persona-config.schema.json:35-39` (`default: "critical"`),
`bin/cli.js:2396` (fresh-scaffold skeleton), and `agents/reviewer.md:167`
(the consumer-side absent-key fallback, which is the *behavioral* default —
`--update` deliberately does not backfill the key, per ADR-0018's R1 hazard).
Because the key is already present here, flipping this repo's posture is a
one-value edit. ADR-0018 itself designates this exact edit as the supported
exit: *"Opt-out is real and easy: Setting `"humanReviewMode": "off"` in
`.claude/persona-config.json` silently disables the feature entirely."*
**Correction to the audit:** the default does not "fail toward escalation
when absent" *in this repo* — the key is set, not absent. The fail-toward
behavior is real but applies to consumers who never set it.

**Change 2 — `dispatchHygiene`.** `hooks/scripts/dispatch-hygiene.sh`
**already fully implements a warn mode**: it reads
`jq -r '.dispatchHygiene.mode // "block"'` at line 111, and at lines 365-384
branches to `key="warned"`, logs `warned=<check> target=<t>` to
`.claude/dispatch-audit.log`, and `exit 0`. The schema
(`templates/persona-config.schema.json:87-92`) enumerates
`["block","warn","off"]`. **Correction to the audit:** no script change is
needed — this is purely a config-value edit. (The audit's H4 observation is
accurate and unchanged: H4 checks the nine dispatch-contract elements by
presence only, per the script's own header, which is precisely why blocking
on it costs more than it catches.)

**Change 3 — auditor mandatoriness.** Only `milestone-auditor` carries
mandatory framing: `agents/orchestrator.md:379`, *"This gate is not optional:
the auditor always runs."*, inside the `## Milestone audit gate` section
(lines 375-400), reached from routing-table line 32. **Correction to the
audit:** `agent-auditor` is **already on-demand**. Its routing row
(`agents/orchestrator.md:33-35`) reads "Observe agent activity and flag
anomalies → `agent-auditor` if present", it has no gate section, no "always
runs" sentence, and no mandatory framing anywhere in `agents/`, `templates/`,
`adapters/`, `CONTEXT.md`, or `.claude/wiki/`. Change 3 therefore touches
`milestone-auditor` only; `agent-auditor` needs no edit.

**Change 4 — fast-path threshold.** Stated in 12 lines across 5 source/doc
files, plus 6 generated mirrors, plus one ADR:
`agents/orchestrator.md:16,256-259,278,284-285`;
`agents/spec-master.md:164,180-181,189,231-233`;
`agents/task-master.md:17-18,25-26`; `templates/persona-protocol.md:582`;
`CONTEXT.md:544,546`; `docs/adr/0003-hivemind-split-spec-master-task-master.md:43,49-50`.
Adapters (`adapters/codex/`, `adapters/cursor/`),
`templates/persona-protocol-slim.md`, and `templates/protocol-digest.md`
carry **no** occurrence — verified by grep, so they are out of scope.
**Trap:** `agents/spec-master.md:121` says "when the plan has ≥3 steps" —
that is the *Self-check* threshold, semantically unrelated, and must not be
swept up by a bulk replace. Step 3 carries an explicit anti-collateral
criterion for it.

**Change 5 — the 2-FAIL cap.** `agents/orchestrator.md:249-261` already
surfaces the defect history, then says *"but instead of only stopping there,
also spawn `spec-master` to produce a **debug spec**"*. The change removes
the automatic spawn and puts a human decision in front of it. Two coupled
statements move with it: `agents/orchestrator.md:293-295` (an `opus` tag
"normally appears only after a unit hits the 2-FAIL cap ... and gets a
`spec-master` debug spec") and `CONTEXT.md:541-547` (the "FAIL routing
(post-reviewer)" glossary entry).

**Mirror-sync mechanism (repo convention, cited not invented).**
`.claude/agents/*.md` and `.claude/persona-protocol*.md` are ADAPT-rendered
mirrors of `agents/*.md` and `templates/*.md`, tracked by `fileHashes` in
`.claude/persona-config.json`. Constitution **P2** forbids hand-editing any
file with a script-driven path, `fileHashes` named explicitly. The mechanism
is `node bin/cli.js --update`; `node bin/cli.js --update --dry-run` is the
genuine no-write verifier, whose exit code is a direct promise about the tree
(`0` iff a live update would leave it byte-identical, `3` if any write would
fire) — see CONTEXT.md's `--update --dry-run` entry. Commits `c40cf22` /
`aaca613` are the hand-sync-plus-heal fallback used when `--update` is not
viable; this plan uses the script path, which the constitution prefers.
**Measured now:** `--update --dry-run` already exits **3** on the current
tree, because of unrelated in-flight edits (see Risks). Steps 2-4 edit
sources only; Step 5 regenerates all mirrors and `fileHashes` in one run.

**Validation surfaces available for acceptance criteria.**
`bash tests/validate.sh` (the constitution's **P5** merge gate — bash syntax,
hook exec bits, JSON validity of `.claude-plugin/*` and `templates/*`,
`package.json`/`plugin.json` version sync, frontmatter shape and YAML
parseability, hook-script mirror parity) and `node tests/protocol-doc-drift.test.js`
(CONTEXT.md/wiki section counts vs live templates). Note: `validate.sh` does
**not** validate `.claude/persona-config.json` against the schema — so Step 1
asserts that directly with `jq` rather than leaning on the suite.

> **CORRECTION (2026-08-16, gh403 debug spec).** This paragraph originally
> also claimed `validate.sh` does "**not** check `agents/` ↔
> `.claude/agents/` content parity". **That claim is false and was the root
> cause of gh403's second FAIL.** `validate.sh:520` runs
> `node tests/cli-backfill.test.js`, whose `buildF2GitFixture` helper copies
> the **real repository root** verbatim into a fixture; its C2.12 check then
> asserts `node bin/cli.js --update --dry-run` exits `0` on that copy. Since
> `--dry-run` implies `--force-render` (CONTEXT.md, `--update --dry-run`
> entry), that assertion is transitively a **source-mirror parity check on
> the live tree**. Measured 2026-08-16: `bash tests/validate.sh` exits `0` at
> `1ec63c7` and `1` at `46b21da`, which edited four sources and no mirror.
> Consequence: **any step that edits `agents/*.md` or `templates/*.md` and
> defers its mirror regeneration turns the P5 merge gate red.** See the
> `## Debug spec (2026-08-16)` section for the resolution.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-15 Functional scope & success criteria: Q Do changes 1 and 2 flip
  only *this repo's* operator posture, or the *shipped plugin default* every
  consumer inherits? → A raised as Open Question 1 (recommended default:
  this repo's config only)
- 2026-08-15 User interaction flow: Q What does "stop and ask the human" at
  the 2-FAIL cap mean mechanically — free-text report, or a structured
  choice? → A raised as Open Question 4 (recommended default:
  `AskUserQuestion` with three discrete options)
- 2026-08-15 Non-functional attributes: Q Is the security consequence of
  `humanReviewMode: "off"` — security-sensitive and structural units ship
  with no forced human comprehension pause — accepted? → A (self-resolved):
  yes, explicitly accepted in the originating request and named as the
  stated tradeoff; recorded as Risk R1 rather than an Open Question, since
  the operator already named it
- 2026-08-15 Edge cases / failure handling: Q What happens to a standing
  `.escalated` marker / escalation packet if `humanReviewMode` flips to
  `"off"` while one is open? → A (self-resolved): nothing — the flag is read
  by the reviewer at verdict time only (`agents/reviewer.md:167`), so an
  already-written marker still requires its normal DECISION-channel
  resolution; the flip changes future verdicts, not standing ones. Recorded
  as Risk R2 with a pre-flight check rather than a code change
- 2026-08-15 Technical constraints & tradeoffs: Q Does changing shipped
  persona prose oblige a version bump, CHANGELOG entry, and ADR? →
  A (self-resolved): yes — constitution P3 makes version bump + CHANGELOG
  mandatory for any version-stamped file; the ADR follows this repo's
  in-body `**Supersedes ADR-000X**` convention (`docs/adr/0013-*.md:14`) and
  inline `**Superseded by #NNN:**` annotations (`docs/adr/0013-*.md:21,24,31`),
  since ADR-0005:82 records that no status-header supersession convention
  exists here. Scoped as Step 5
- 2026-08-15 Terminology consistency: Q Does the request's vocabulary match
  CONTEXT.md's glossary? → A (self-resolved): three drifts found, all
  advisory (see "Terminology check" below); none blocks. One new term
  ("on-demand milestone audit") is flagged for `scribe`
- 2026-08-15 Completion / acceptance signals: Q Which existing suite is
  authoritative for "done"? → A (self-resolved): `bash tests/validate.sh`
  (constitution P5, the declared merge gate and this repo's
  `testAndLintCommand`) plus `node tests/protocol-doc-drift.test.js` and
  `node bin/cli.js --update --dry-run`; verified all three run and their
  current exit codes are recorded as baselines in each step
- 2026-08-15 Functional scope & success criteria: Q Does raising the fast
  path to ≤5 also raise the `to-spec` tracker-publish threshold at
  `agents/spec-master.md:164`? → A raised as Open Question 3 (recommended
  default: yes, couple them)
- 2026-08-15 Functional scope & success criteria: Q Should the milestone
  audit gate become fully manual, or manual-plus-release-boundary? →
  A raised as Open Question 2 (recommended default: explicit-request-only,
  with a release-boundary reminder that does not gate)

The four lines below were appended after the Open Questions round-trip, when
the operator answered on 2026-08-15. They are recorded rather than merely
consumed; each confirms the corresponding recommendation above rather than
overturning it.

- 2026-08-15 Functional scope & success criteria: Q Do changes 1 and 2 flip
  only this repo's operator posture, or the shipped plugin default? →
  A: **this repo's `.claude/persona-config.json` only**, per operator,
  closing Open Question 1 with the recommended option. The shipped default
  stays `"critical"` / `"block"`; ADR-0018 is annotated, not reversed. Risk
  R1 (sensitive units ship on reviewer PASS with no forced human
  comprehension pause) is **explicitly accepted** as a local posture. Step 1
  and Step 5 stand as drafted; no step text changed.
- 2026-08-15 User interaction flow: Q What exactly triggers the milestone
  audit now? → A: **explicit operator request only**, per operator, closing
  Open Question 2 with the recommended option. The literal trigger string is
  fixed as **`only when the operator explicitly asks`**; AC2.3 now greps that
  literal instead of the `<TRIGGER-PHRASE>` placeholder. The non-gating
  release-boundary reminder is retained. `agent-auditor` confirmed out of
  scope (already on-demand).
- 2026-08-15 Functional scope & success criteria: Q Does the `to-spec`
  tracker-publish threshold move with the fast path? → A: **yes, couple
  them**, per operator, closing Open Question 3 with the recommended option.
  Both thresholds move together: fast path handles **≤5** units, tracker
  publish triggers at **≥6**. `agents/spec-master.md:164` is therefore
  unconditionally in Step 3's affected-files list, and AC3.7 is added to
  assert it.
- 2026-08-15 User interaction flow: Q What is the mechanism for "ask the
  human" at the 2-FAIL cap? → A: **`AskUserQuestion` with three discrete
  options**, per operator, closing Open Question 4 with the recommended
  option — (a) debug spec via `spec-master`, (b) re-dispatch
  `lead-programmer` with a human-supplied directive, (c) park the unit.
  AC4.2 now greps the literal `AskUserQuestion`, and AC4.7 is added to assert
  all three options survive.

### Terminology check (`antislop:ubiquitous-language`, prose mode — advisory)

Anchored on the originating request; glossary read once from `CONTEXT.md`
and reused for the draft-plan check below.

- **Lens 1 (glossary term, different meaning).** The request says "the gate
  system steps on its own toes". CONTEXT.md defines **Gate** narrowly as *"a
  hook script that mechanically blocks an action rather than relying on a
  persona to comply"*. Of the five changes, only change 2 touches an actual
  Gate; changes 3-5 are persona *prose*, not Gates, and have no hook behind
  them. This plan uses "gate" only for change 2 and the surviving
  `## Milestone audit gate` heading (a pre-existing name, kept for
  continuity). Also: the request uses "review" to span four distinct
  glossary entries — the Writer/Reviewer split, ESCALATE-TO-HUMAN,
  the milestone audit, and agent audit; this plan names each separately.
- **Lens 2 (new synonym for a defined term).** "fast-path bypass threshold"
  is a new phrasing of the corpus's own "≤2-unit fast path"; this plan uses
  the canonical form throughout (soon "≤5-unit fast path"). "warn mode"
  matches the script's and schema's existing vocabulary — no drift.
- **Lens 3 (load-bearing new term, no glossary entry).** Two, both for
  `scribe` to consider in Step 5: **"on-demand milestone audit"** (the post-
  change trigger semantics of the milestone gate) and **"solo-operator
  posture"** (the named configuration stance combining `humanReviewMode:
  off` with `dispatchHygiene: warn`). Neither exists in CONTEXT.md today.

### Terminology check on this draft (advisory, non-blocking)

### Terminology check on the 2026-08-15 finalization pass (advisory, non-blocking)

Re-run over the text added when the four answers were recorded. Two findings,
both **advisory — neither blocks publication or `task-master` handoff**, and
neither overturns the operator's chosen literal.

- **Lens 2 (new synonym for a defined term) — `operator` vs `human`.**
  Measured: `operator` occurs **0** times in `CONTEXT.md`, whose glossary and
  the whole persona corpus consistently say **human** (`humanReviewMode`,
  `.claude/human-review/`, the human-decision gate, ESCALATE-TO-HUMAN). The
  trigger literal fixed by OQ-2 — `only when the operator explicitly asks` —
  therefore introduces a synonym into *shipped persona prose*, not just into
  this plan. **The literal is kept as the operator chose it**; changing it
  unilaterally would silently overturn an answer given to a question that
  asked for the exact string, and this check is advisory by construction.
  Routed to `scribe` in Step 5 instead: either add `operator` to `CONTEXT.md`
  as an explicit synonym of `human` in this system's sense, or record the
  distinction if one is intended. Flagging it now matters because AC2.3
  greps this literal — a later "consistency" rewrite to `human` would turn
  AC2.3 red without touching behaviour.
- **Lens 3 (load-bearing new term, no glossary entry) — "park the unit".**
  `park` occurs **0** times in `CONTEXT.md`. It becomes a named outcome of
  the 2-FAIL cap under OQ-4's option (c), so it is load-bearing. Added to the
  scribe hint. Note what it must specify: parking writes no marker and
  deletes none, so a parked unit is distinguishable from a passed, failed,
  blocked, or escalated one only by the absence of further dispatch.
- **Lens 1 (glossary term used with a different meaning).** Nothing found in
  the added text.

### Terminology check on this draft (advisory, non-blocking)

Re-run against the draft above: no Lens 1 divergence (the plan uses
**Gate**, **Persona**, **Escalation packet**, **`.escalated` marker**,
**2-FAIL cap**, **FAIL routing (post-reviewer)**, and **`--update`
semantics** in their canonical senses). No Lens 2 synonym introduced. Lens 3
repeats the two new terms above, already routed to `scribe`. Advisory only;
does not block.

## Risks and dependencies

- **R1 (accepted, operator-stated).** With `humanReviewMode: "off"`, units
  meeting ADR-0004's heavy-unit trigger — security-sensitive surface,
  structural change, large diff — ship on reviewer PASS with no forced human
  comprehension pause. ADR-0018 argued this posture is the wrong *default
  for consumers*; the operator is accepting it as a *local* posture. This is
  the single largest safety reduction in the plan and must be stated plainly
  in the ADR, not softened.
- **R2 (edge case).** A standing `.escalated` marker or escalation packet
  open at flip time is unaffected — the flag is read at verdict time only —
  but the packet directory is gitignored and destroyed unrecoverably by a
  clean (CONTEXT.md, "Escalation packet"). Step 1 carries a pre-flight
  `ls .claude/reviewed/*.escalated` check so the operator resolves any open
  escalation through the DECISION channel *before* the flip, rather than
  leaving an orphan.
- **R3 (H3 coverage loss).** `dispatchHygiene: "warn"` de-fangs H3, the
  re-dispatch guard that blocks respawning a unit already holding a
  `.pass` marker. That guard is anchored on attested commits per ADR-0023
  and is genuinely load-bearing against duplicate work. Warn mode keeps the
  `.claude/dispatch-audit.log` record (`warned=H3 target=...`), so the
  signal survives as an audit trail, but nothing stops the dispatch. This is
  the ceremony/safety trade being bought.
- **R4 (in-flight collision — schedule dependency).** The working tree at
  authoring time has uncommitted edits to `templates/persona-protocol.md`,
  `adapters/codex/agents-md-fragment.md`, and
  `adapters/cursor/rules/persona-protocol.mdc` (the in-flight
  `docs/plans/2026-08-15-marker-commit-attribution.md` work), and
  `node bin/cli.js --update --dry-run` already exits **3** because of them.
  Step 3 edits `templates/persona-protocol.md:582`. **That in-flight work
  must land before Step 3 begins**, or the two will conflict and Step 5's
  dry-run criterion cannot be attributed. Step 5 carries a second,
  attributable criterion (AC5.5) for exactly this reason.
- **R5 (file serialization).** Steps 2, 3, and 4 all edit
  `agents/orchestrator.md`; Steps 3 and 4 both edit `CONTEXT.md`. They are
  **not** parallelizable. Dispatch order must be 2 → 3 → 4 → 5 (Step 1 is
  independent and may run any time).
- **R6 (prior defect history — `.fail` record check).** `.claude/reviewed/`
  holds 64 `.fail` records. None is for a unit in this plan's scope (no
  prior unit has touched the fast-path threshold, the milestone gate's
  mandatoriness, or the 2-FAIL cap paragraph). However, the adjacent
  precedent `docs/plans/2026-08-13-persona-efficiency-audit-gh348.md`
  records that a byte-pinned criterion there was *silently invalidated by an
  unrelated reflow commit* mid-flight and had to be re-anchored to a
  content-equality check. Every criterion in this plan is therefore phrased
  as a content/count assertion, never a line-number or byte pin. Relatedly,
  `.claude/reviewed/gh385-2.fail` and `gh385-1.fail` are recent and concern
  mirror-sync and prose-accuracy defects in this same corpus — Step 5's
  mirror work should **not** be tagged `haiku`.
- **R7 (`--update` rewrites the config Step 1 edits).** `bin/cli.js --update`
  reports `.claude/persona-config.json: would be rewritten`. ADR-0018 states
  the branch holds a "preserve-every-field contract", but that is prose, not
  a test here. Step 5 carries AC5.6 to prove Step 1's two values survived
  the rewrite rather than assuming it.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every audit claim was re-checked
  against the tree, three were corrected (warn mode already exists;
  `agent-auditor` is already on-demand; `humanReviewMode` is set, not
  absent, in this repo), and every acceptance criterion's baseline was
  measured and recorded, not estimated.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  ~~Steps 2-4 edit sources only; mirrors and `fileHashes` are regenerated by
  `node bin/cli.js --update` in Step 5.~~ **Revised 2026-08-16 (gh403 debug
  spec):** every source-editing step regenerates its own mirrors in-unit via
  `node bin/cli.js --update --force-render`, the canonical force-the-loop
  control per CONTEXT.md's `--update` entry. P2's substance is unchanged and
  still satisfied: no step hand-edits `fileHashes` or any `.claude/agents/*.md`
  mirror — the regeneration is script output, byte-for-byte.
- P3 "Version-stamp discipline": satisfied — Step 5 bumps
  `.claude-plugin/plugin.json` (and `package.json`, whose sync `validate.sh`
  enforces) and adds a CHANGELOG entry, because Steps 2-4 modify
  version-stamped files.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — Step 2
  reframes the milestone gate's mandatoriness while preserving its "If this
  project has a `milestone-auditor` (check `.claude/agents/`)" conditional
  and its "If there's no milestone-auditor, skip this entire gate" fallback;
  AC2.4 asserts the conditional phrasing count does not regress.
- P5 "`tests/validate.sh` is the merge gate": **deviation, now closed —
  see the `## Debug spec (2026-08-16)` section.** The original claim
  ("satisfied — every step from 2 onward carries `bash tests/validate.sh`
  exit 0 as a criterion") was *stated* correctly but was **unsatisfiable as
  scoped**: it rested on the falsified parity premise corrected above, so
  Steps 3-4 carried a criterion their own write-scope forbade them from
  meeting. Commits `46b21da` and `0611bea` were in fact landed with the P5
  merge gate **red**, and this plan recorded no deviation at the time — the
  precise silent degradation this section exists to prevent. Recorded here
  explicitly rather than retro-justified. The debug spec's resolution
  (in-unit mirror regeneration) makes the criterion satisfiable, so P5 is
  satisfied *going forward* from the remediation unit onward; the historical
  red window across `46b21da..0611bea` stands on the record as a deviation
  and is closed by that unit, not erased. Step 1 additionally carries a
  direct `jq`/`json.tool` assertion because the suite does not cover
  `.claude/persona-config.json`.

---

## Debug spec (2026-08-16) — gh403 hit the 2-FAIL cap

Produced under `spec-master`'s debug-spec path after issue #403 (Step 3)
FAILed twice. **This is a focused diagnosis plus revised criteria, not a
replan.** Steps 1-2 are landed and correct; Steps 3-5 keep their objectives
unchanged. Only acceptance criteria and mirror write-scope move.

### Verification (fail-triage step 1)

Reproduced live, not read off the `.fail` record:

| Commit | `bash tests/validate.sh` |
|---|---|
| `1ec63c7` (pre-unit base) | **exit 0** — "All checks passed." |
| `0611bea` (HEAD, post-fix) | **exit 1** |

Sole failing check is `tests/cli-backfill.test.js`, with two assertions:
C2.12 (*"a genuinely current tree must exit 0, got 3"*) and the F2 shape-B
post-run-clean assertion (*"got: M .claude/agents/lead-programmer.md"*).
`node bin/cli.js --update --dry-run` exits **3** at HEAD, naming six stale
mirrors plus `persona-config.json`.

### Categorization (fail-triage step 2)

**Spec/criterion defect**, not a code defect. The implementer followed its
contract exactly; the contract was self-contradictory.

### Root cause

Three findings, in order of depth.

1. **The falsified premise.** Plan `:127-130` asserted `validate.sh` does not
   check source-mirror parity. It does, transitively:
   `validate.sh:520` → `tests/cli-backfill.test.js` →
   `buildF2GitFixture` copies the **real repo root** → C2.12 asserts
   `--update --dry-run` exits 0 on that copy. Corrected in place above.
2. **The resulting contradiction.** Step 3's write-scope forbade touching any
   `.claude/` mirror ("Step 5's job") while AC3.5 required
   `validate.sh` exit 0. Post-finding 1, those two are **mutually
   unsatisfiable**. AC3.5 could not be met inside the unit's own scope, so
   the FAIL was structurally guaranteed. Step 4 inherits this identically
   (same file, same deferral) and Step 2 already hit it.
3. **The missed warning — the most important finding.** This was *already
   correctly diagnosed and written down*, and carried forward anyway. The
   `gh402` PASS marker's note 1 states: *"AC2.5 is internally unsatisfiable
   as written … Steps 3 and 4 edit the same file and will hit the identical
   dilemma — task-master should re-phrase AC before dispatch."* Step 2's
   implementer had silently resolved it by regenerating the mirror in-unit
   (commit `3932cb1` touches `.claude/agents/orchestrator.md` and
   `.claude/persona-config.json`), which satisfied AC2.5's `validate.sh` half
   at the cost of its "only modified file" half. **A correct diagnosis
   parked in a non-blocking PASS note did not reach the next dispatch.**

**Correcting the escalation's working hypothesis.** The escalation supposed
Steps 1/2 "got lucky" — that they never edited `templates/persona-protocol.md`
so only one mirror went stale, and that gh385-8's unrelated regen (`0335534`)
incidentally caught them up. Measured, that is **not** what happened:

- **Step 1** (`0f6efa7`) touched only `.claude/persona-config.json` — no
  source with a mirror at all. It never exercised the failure mode.
- **Step 2** (`3932cb1`) *did* exercise it, fully and immediately — and
  resolved it by regenerating its mirror inside the unit. Measured at
  `3932cb1` in an isolated worktree: `cli-backfill` exit **0**, `--dry-run`
  exit **0**. It was self-consistently green on its own commit, needing no
  later rescue. `0335534` is not load-bearing here.

So the real distinction is not luck: **Step 2 broke the mirror-deferral rule
and went green; Step 3 obeyed it and went red.** The rule was the defect.

**Systemic scope.** This is the third recorded instance of this one failure
class. `.claude/reviewed/gh385-2.fail` (2026-08-16, a *different* milestone)
is the same C2.12 + shape-B signature from an uncommitted `fileHashes` heal.
The general rule now recorded in this plan: **a unit that edits `agents/*.md`
or `templates/*.md` must regenerate its mirrors in the same unit.**

### A second, latent defect found while verifying the fix (NOT in scope)

`node bin/cli.js --update` **cannot** repair this state on its own. Its fast
path at `bin/cli.js:1269` returns early when `config.pluginVersion === version`
and every mirror's stamp matches, and the pre-scan at `:1263` compares the
**stamp**, not the **content**. Because `0335534` bumped to `0.31.58` and
re-stamped every mirror, a plain `--update` at HEAD prints *"already current.
Nothing to update."* and rewrites nothing, while `--dry-run` (which implies
`--force-render`) correctly reports six stale mirrors. Measured both ways.

Two consequences:

- **In scope, and reflected in the criteria below:** the remediation must use
  `node bin/cli.js --update --force-render`. Verified: it rewrites all seven
  paths and turns `validate.sh` green.
- **Out of scope, flagged for a future unit:** this falsifies CONTEXT.md's
  `--update --dry-run` contract, which promises exit `0` *"if and only if a
  live `--update` with the same arguments would leave the whole tree byte-
  and mode-identical."* In this shape `--dry-run` exits 3 while a live
  `--update` writes nothing. `tests/cli-backfill.test.js`'s C2.14
  biconditional rows do not cover it. **Recommend a separate issue**; it is a
  genuine `bin/cli.js` defect, unrelated to ceremony reduction, and folding
  it in here would be exactly the from-scratch-replan scope creep a debug
  spec must avoid.

### Resolution chosen, and the alternative rejected

**Chosen — in-unit mirror regeneration.** Each source-editing step
regenerates its own mirrors via `--force-render`. Keeps P5 green at every
commit, needs no ongoing deviation, is P2-compliant (script output, never
hand-edited), and matches what Step 2 already did successfully.

**Rejected — drop `validate.sh` from AC3.5/AC4.6 under a recorded P5
deviation.** This was the escalation's first suggested option. It buys
nothing the chosen option doesn't, and costs real coverage: `validate.sh`'s
frontmatter-shape and YAML-parseability checks run over exactly the
`agents/*.md` files these steps edit — the historically-worst bug class this
repo has (constitution P5's own rationale). Suppressing the gate on the steps
most likely to trip it inverts its purpose. The P5 deviation that *is*
recorded above is therefore historical and closed, not standing.

---

## Step 1 — Adopt the solo-operator posture in this repo's config

Flip two values in `.claude/persona-config.json`. No script, schema, or
persona-prose change. This is the documented opt-out path, not a workaround.

**Affected files**
- `.claude/persona-config.json` — `humanReviewMode`: `"critical"` → `"off"`;
  `dispatchHygiene.mode`: `"block"` → `"warn"`. **Touch no other key**, and
  in particular do not hand-edit `fileHashes` (constitution P2).

**Pre-flight (R2)**
- Run `ls .claude/reviewed/*.escalated 2>/dev/null`. If any marker exists,
  stop and resolve it through the DECISION channel before flipping; do not
  delete it (CONTEXT.md, "Blocked by a gate you do not own").

**Acceptance criteria** (baselines measured 2026-08-15 at `d25419c`)
- **AC1.1** `jq -r '.humanReviewMode' .claude/persona-config.json` prints
  exactly `off`. Baseline today: `critical`.
- **AC1.2** `jq -r '.dispatchHygiene.mode' .claude/persona-config.json`
  prints exactly `warn`. Baseline today: `block`.
- **AC1.3** Two-assertion collateral check: `python3 -m json.tool
  .claude/persona-config.json >/dev/null` exits 0, **and**
  `jq -r '.fileHashes | length' .claude/persona-config.json` prints `28`
  (its value today) — proving no `fileHashes` entry was added, dropped, or
  rewritten.
- **AC1.4** Mutation proof that warn mode is *live*, not merely configured.
  Invoke `hooks/scripts/dispatch-hygiene.sh` directly on a synthetic
  gated-persona dispatch payload that fires H4 (a `lead-programmer` prompt
  missing the nine contract elements), and record **both** runs:
  - with the pre-change config (`mode: "block"`): exit **2**, and a new
    `blocked=H4` line appended to `.claude/dispatch-audit.log`;
  - with the post-change config (`mode: "warn"`): exit **0**, and a new
    `warned=H4` line appended to `.claude/dispatch-audit.log`.
  A run that exits 0 under *both* configs does not satisfy this criterion —
  it would mean the probe never fired a check.

---

## Step 2 — Milestone audit becomes on-demand

**Depends on:** nothing. **Must precede:** Steps 3 and 4 (same file, R5).

Rewrite the mandatoriness of `## Milestone audit gate` in
`agents/orchestrator.md` (lines 375-400) and its routing-table entry (line
32) so the auditor runs **only when explicitly requested**. Per Open
Question 2's resolution (2026-08-15), the section must contain the literal
string **`only when the operator explicitly asks`** — that exact wording is
what AC2.3 greps, so it is a required output of this step, not a paraphrase
the implementer may reword. A non-gating reminder that a release boundary is
a good moment to *ask for* an audit may be kept; it must not read as an
automatic trigger. Everything else in the section — the
never-per-task rule, the "not a replacement for the reviewer" rule, the
human-flagged-premises pass-through, the findings-relay protocol, the
challenged-premise re-plan route, and the `unconverged-requirement` →
`## Convergence follow-ups` route — is **preserved verbatim**. This step
changes *when* the gate fires, not *what it does*.

`agent-auditor` is **out of scope** — already on-demand (see Context).

**Affected files**
- `agents/orchestrator.md` — line 379's mandatoriness sentence; the section
  intro at 375-378; routing-table line 32.

**Not affected** (verified by grep; do not edit): `agents/milestone-auditor.md`,
`templates/persona-protocol.md`, `adapters/**`, `CONTEXT.md`,
`.claude/wiki/**`, and every `.claude/agents/*.md` mirror (Step 5 regenerates
those).

**Acceptance criteria**
- **AC2.1** `grep -c 'This gate is not optional' agents/orchestrator.md`
  prints `0`. Baseline today: `1`.
- **AC2.2** `grep -c '## Milestone audit gate' agents/orchestrator.md`
  prints `1` — the section survives; this is a reframing, not a deletion.
- **AC2.3** The section states the on-demand trigger, using the literal
  string fixed by Open Question 2 (**resolved 2026-08-15**):
  `sed -n '/## Milestone audit gate/,/## Graph freshness/p' agents/orchestrator.md
  | grep -cF 'only when the operator explicitly asks'` is ≥ 1. Baseline today:
  `0` (measured — the literal appears nowhere in the file). Both `sed`
  anchors were verified present at authoring time
  (`## Milestone audit gate` at :375, `## Graph freshness` at :402), so the
  range is non-empty.
- **AC2.4** Constitution P4 guard:
  `sed -n '/## Milestone audit gate/,/## Graph freshness/p' agents/orchestrator.md
  | grep -c 'milestone-auditor'` is ≥ `3` (its measured value today), proving the
  conditional-presence phrasing and the "skip this entire gate" fallback
  were not collaterally removed.
- **AC2.5** `bash tests/validate.sh` exits 0, **and**
  `git status --porcelain -uno` lists `agents/orchestrator.md` as the only
  modified tracked file for this unit.

---

## Step 3 — Raise the fast path from ≤2 to ≤5 dispatchable units

**Depends on:** Step 2 (same file), and R4's in-flight work landing.
**Must precede:** Step 4 (shares `agents/orchestrator.md` and `CONTEXT.md`).

> ### ⛔ BLOCKING SEQUENCING NOTE — do not start this step yet
>
> This step edits `templates/persona-protocol.md:582`. That file is
> **currently modified and uncommitted** in the working tree by the in-flight
> `docs/plans/2026-08-15-marker-commit-attribution.md` milestone (published as
> GitHub issue #385, units #386-#394), together with
> `adapters/codex/agents-md-fragment.md` and
> `adapters/cursor/rules/persona-protocol.mdc`. Measured 2026-08-15:
> `node bin/cli.js --update --dry-run` exits **3** on the current tree
> *because of that uncommitted work*, not because of anything in this plan.
>
> **Gate before dispatching this step** — all three must hold:
> 1. `git status --porcelain -uno` lists **no** modification to
>    `templates/persona-protocol.md`;
> 2. `node bin/cli.js --update --dry-run` exits **0** (this is the same
>    promise AC5.4 depends on, checked early so the collision is caught
>    before edits are made rather than after);
> 3. the marker-commit-attribution units that touch
>    `templates/persona-protocol.md` (its Step 4 / issue #389) have landed on
>    the branch this step will build on.
>
> If the gate does not hold, **do not** edit around the conflict and do not
> commit the other milestone's work as collateral — report the block upward.
> This is a scheduling dependency between two milestones, not a defect in
> either.

Replace every statement of the ≤2/≥3 dispatchable-unit fast-path threshold
with ≤5/≥6, across sources and docs only. Mirrors are regenerated in Step 5.

**Open Question 3 is resolved (2026-08-15): the two thresholds are coupled.**
The `to-spec` tracker-publish threshold at `agents/spec-master.md:164`
("specs resolving to ≥3 units") moves to **≥6** in the same step, so the fast
path handles ≤5 units and tracker publication triggers at ≥6. That line is
therefore **unconditionally in scope**, not conditional as the draft had it.

**Affected files** (12 threshold lines, verified by grep at `d25419c`)
- `agents/orchestrator.md` — lines 16, 256, 257, 259, 278, 284, 285
- `agents/spec-master.md` — lines 180, 181, 189, 231, 232, 233, **and line
  164** (the `to-spec` publish threshold — now unconditional, per Open
  Question 3's resolution)
- `agents/task-master.md` — lines 17, 18, 25, 26
- `templates/persona-protocol.md` — line 582
- `CONTEXT.md` — lines 544, 546 ("FAIL routing (post-reviewer)")
- `docs/adr/0003-hivemind-split-spec-master-task-master.md` — lines 43,
  49-50. **Annotate, do not rewrite**: follow the inline
  `**Superseded by #NNN:**` convention established at
  `docs/adr/0013-fable-removed-from-roast-work-advisory-pass.md:21,24,31`,
  since ADR-0005:82 records that this repo has no status-header supersession
  convention. **Corrected 2026-08-16 (gh403 debug spec):** an earlier
  revision of this bullet offered `**Amends ADR-0003**` as a fallback when
  the Step 5 ADR number is unknown. That fallback is **unsatisfiable against
  AC3.6**, which greps for the literal `Superseded by`. Use
  `**Superseded by (ADR TBD, Step 5):**` — as landed in `0611bea` — which
  satisfies AC3.6 without inventing an ADR number.

**Do NOT touch**
- `agents/spec-master.md:121` and its mirror — *"when the plan has ≥3
  steps"* is the **Self-check** threshold, not the fast path. AC3.3 guards
  it.
- `adapters/**`, `templates/persona-protocol-slim.md`,
  `templates/protocol-digest.md` — zero occurrences, confirmed by grep.
- ~~Any `.claude/` mirror — Step 5's job.~~ **Revised 2026-08-16 (gh403
  debug spec): this line was the defect.** Mirrors are no longer deferred to
  Step 5; this step regenerates its own, and **only** via
  `node bin/cli.js --update --force-render`. The prohibition that survives is
  narrower and still absolute: **never hand-edit a mirror or `fileHashes`**
  (constitution P2). Any `.claude/` path in this unit's diff must be
  byte-identical to script output.

**Acceptance criteria**
- **AC3.1** `grep -rn '≤2-unit\|≤2 dispatchable\|two or fewer dispatchable\|two
  or fewer independently-grabbable\|≤2 units' agents/ templates/ CONTEXT.md
  | wc -l` prints `0`. Baseline today: `12`.
- **AC3.2** Each of `agents/orchestrator.md`, `agents/spec-master.md`,
  `agents/task-master.md`, `templates/persona-protocol.md`, `CONTEXT.md`
  has `grep -c '≤5'` ≥ 1. Baseline today: `0` in all five.
- **AC3.3** Anti-collateral:
  `grep -c 'the plan has ≥3 steps' agents/spec-master.md` prints `1`
  — unchanged from today, proving the Self-check threshold was not swept up
  by a bulk replace.
- **AC3.4** `node tests/protocol-doc-drift.test.js` exits 0 (currently 0;
  this is a regression guard — `CONTEXT.md` is edited here, and this test is
  what catches CONTEXT/wiki-vs-template drift).
- **AC3.5** `bash tests/validate.sh` exits 0. **Revised 2026-08-16 (gh403
  debug spec) — measured, not assumed.** This criterion is unchanged in
  wording and is now *satisfiable* because the step's write-scope was
  widened above to include its own mirror regeneration. It must be verified
  in a **clean detached worktree at the unit's own commit**, never in the
  live working tree, because an uncommitted mirror can make it pass locally
  and fail for everyone else (the exact shape of `.claude/reviewed/gh385-2.fail`
  defect 1):
  `git worktree add --detach /tmp/gh403-verify HEAD && cd /tmp/gh403-verify
  && bash tests/validate.sh; echo $?` prints `0`.
- **AC3.9** (new, 2026-08-16) Source-mirror parity, the criterion whose
  absence let this step land red: `node bin/cli.js --update --dry-run`
  exits **0**, verified in the same clean detached worktree as AC3.5.
  Measured baseline at `0611bea`: exits **3**. This is the direct promise
  about the tree that AC3.5 depends on transitively; asserting it separately
  means a future `validate.sh` refactor cannot silently drop the coverage.
- **AC3.10** (new, 2026-08-16) The regeneration is script output, not a
  hand-edit (constitution P2). After the unit's commit, in a clean detached
  worktree: `node bin/cli.js --update --force-render` leaves
  `git status --porcelain -uno` **empty**. A non-empty result means a
  `.claude/` path in the commit differs from what the script produces.
- **AC3.6** `grep -c 'Superseded by' docs/adr/0003-hivemind-split-spec-master-task-master.md`
  is ≥ 1. Baseline today: `0`.
- **AC3.7** Publish-threshold coupling (Open Question 3):
  `test "$(grep -cF 'specs resolving to ≥3 units' agents/spec-master.md)" = 0`
  — baseline today `1`, measured — **and**
  `grep -cF 'specs resolving to ≥6 units' agents/spec-master.md` is ≥ 1
  (baseline today `0`). Both halves are required: the first alone could be
  satisfied by deleting the sentence, the second alone by adding a duplicate.
  Note the `test "$(grep -c …)"` wrapper on the `= 0` half is deliberate —
  a bare `grep -c` exits **1** when the count is zero, so a criterion phrased
  as "`grep -c` returns 0" could never be satisfied.
- **AC3.8** Fast-path/publish agreement across personas: after the edit, no
  file in `agents/` states a fast-path or publish threshold of `≥3` units.
  `grep -rnF '≥3 units' agents/ | wc -l` prints `0`. Baseline today: `4`
  (measured — `agents/orchestrator.md:257` and `agents/spec-master.md:164,
  189, 233`). All four are already inside this step's affected-files list, so
  this criterion adds coverage, not scope. This is distinct from AC3.3's
  `the plan has ≥3 steps` guard, which counts **steps**, not units, and must
  stay at `1`.

---

## Step 4 — The 2-FAIL cap stops and asks the human

**Depends on:** Steps 2 and 3 (shared files, R5).

Rewrite `agents/orchestrator.md:249-261` so the cap surfaces the two-attempt
defect history and then **asks the human how to proceed** instead of
automatically spawning `spec-master`. The debug-spec route is **preserved as
one of the offered options**, together with its downstream routing prose
(fast path, `task-master` re-derivation for larger debug specs) — this step
gates that route behind a human choice, it does not delete it.

**Open Question 4 is resolved (2026-08-15): the mechanism is
`AskUserQuestion` with exactly three discrete options.** The orchestrator
already holds `AskUserQuestion` (4 existing uses in the file), so no new tool
grant and no new hook is needed; the cap is prose, not a Gate, so nothing
mechanical changes. The three options are:

- **(a) Debug spec** — dispatch `spec-master` to produce the focused
  diagnostic artifact, exactly as the current automatic path does. Its
  downstream routing prose is preserved verbatim, except that the ≤2-unit
  fast-path number becomes ≤5 by Step 3 (Step 3 must land first, per R5).
- **(b) Re-dispatch with a human directive** — re-dispatch
  `lead-programmer` on the same unit carrying an operator-supplied
  correction. Note this is the existing human-directed-correction shape,
  which `agents/orchestrator.md:245-247` already states **does not count
  against the 2-FAIL cap**; that counting rule is unchanged by this step and
  is listed under "Do NOT touch".
- **(c) Park the unit** — stop work on it, leave the defect history standing,
  and move on. No marker is written and none is deleted.

The rewritten paragraph must make clear the orchestrator **waits** for the
answer rather than picking a default, since the whole point of the change is
to stop the automatic `opus` debug-spec cycle from firing unasked.

Two coupled statements move with it.

**Affected files**
- `agents/orchestrator.md` — the `**At the 2-FAIL cap**` paragraph
  (249-261); **and** the per-unit-model-routing sentence at 293-295, whose
  claim that an `opus` tag appears after a cap "and gets a `spec-master`
  debug spec" becomes conditional on the human's choice.
- `CONTEXT.md` — the "FAIL routing (post-reviewer)" entry at 541-547, whose
  first clause *"At the 2-FAIL cap, the orchestrator routes to `spec-master`"*
  is no longer unconditional.

**Do NOT touch**
- `agents/spec-master.md:219` — *"produce this artifact only when the
  orchestrator escalates a unit that hit the ... 2-FAIL cap"* remains true
  under the new flow and needs no edit.
- The three "does not count against the 2-FAIL cap" statements at
  `agents/orchestrator.md:96,169,246` and `CONTEXT.md:349` — counting rules
  are unchanged.
- **Never hand-edit** a `.claude/` mirror or `fileHashes` (constitution P2).
  Note this is now the *only* mirror prohibition on this step — see the
  scope revision immediately below.

**Mirror scope — revised 2026-08-16 (gh403 debug spec).** This step edits
`agents/orchestrator.md`, so it inherits gh403's defect **identically**: its
own AC4.6 (`bash tests/validate.sh` exits 0) is unsatisfiable while mirror
regeneration is deferred to Step 5. The `gh402` PASS marker predicted this in
writing ("Steps 3 and 4 edit the same file and will hit the identical
dilemma"), and that prediction was not acted on. Resolution is the same as
Step 3's: **this step regenerates its own mirrors in-unit via
`node bin/cli.js --update --force-render`**, and its diff may therefore
contain `.claude/agents/*.md`, `.claude/persona-protocol*.md`, and
`.claude/persona-config.json` — each byte-identical to script output.

**Acceptance criteria**
- **AC4.1** ``grep -c 'also spawn `spec-master` to produce a'
  agents/orchestrator.md`` prints `0`. Baseline today: `1`.
- **AC4.2** The cap paragraph names the ask mechanism fixed by Open
  Question 4 (**resolved 2026-08-15**):
  `sed -n '/At the 2-FAIL cap/,/spec gap/p' agents/orchestrator.md
  | grep -cF 'AskUserQuestion'` is ≥ 1. Baseline today: `0` **inside this
  range** — note `AskUserQuestion` occurs 4 times elsewhere in the file, so
  the criterion is deliberately range-scoped and a whole-file `grep` would be
  vacuous.
- **AC4.3** Capability-preservation guard:
  `sed -n '/At the 2-FAIL cap/,/spec gap/p' agents/orchestrator.md
  | grep -c 'debug spec'` is ≥ 1 — the route still exists as an option.
  Baseline today: ≥ 1; this criterion must stay green, i.e. it fails if the
  route was deleted rather than gated.
- **AC4.4** ``grep -c 'and gets a `spec-master` debug spec'
  agents/orchestrator.md`` prints `0` — the coupled model-routing sentence
  at 293-295 was updated, not left contradicting the new flow. Baseline
  today: `1`.
- **AC4.5** `grep -c 'At the 2-FAIL cap, the orchestrator routes to' CONTEXT.md`
  prints `0` — the glossary entry no longer states the route as
  unconditional. Baseline today: `1`.
- **AC4.6** `bash tests/validate.sh` exits 0 **and**
  `node tests/protocol-doc-drift.test.js` exits 0. **Revised 2026-08-16
  (gh403 debug spec):** verify both in a **clean detached worktree at the
  unit's own commit**, not the live working tree, for the reason given at
  AC3.5.
- **AC4.8** (new, 2026-08-16) Source-mirror parity, mirroring AC3.9:
  `node bin/cli.js --update --dry-run` exits **0** in that same clean
  detached worktree, **and** a subsequent
  `node bin/cli.js --update --force-render` leaves `git status --porcelain
  -uno` empty (P2 script-output proof, mirroring AC3.10).
- **AC4.9** (new, 2026-08-16) Attributable mirror content — proves this
  step's own edit reached the mirror rather than relying on a prior step's
  regeneration: ``grep -c 'and gets a `spec-master` debug spec'
  .claude/agents/orchestrator.md`` prints `0`, the mirror-side counterpart
  of AC4.4. Measure the baseline at dispatch time; at `0611bea` it is `1`.
- **AC4.7** All three offered options survive, per Open Question 4's
  resolution. Within the same `sed -n '/At the 2-FAIL cap/,/spec gap/p'`
  range: `grep -cF 'debug spec'` ≥ 1 (option a — this is AC4.3, restated here
  so the option set is checkable as a set), `grep -cF 'lead-programmer'` ≥ 1
  (option b), and `grep -ciF 'park'` ≥ 1 (option c). Baselines measured
  2026-08-15 inside the range: `debug spec` = `3`, `lead-programmer` = `2`,
  `park` = `0`. The third is the RED assertion that proves the rewrite
  happened; the first two are green-must-stay-green guards against the
  options being dropped rather than offered.

---

## Step 5 — Release hygiene: version, CHANGELOG, ADR, glossary, mirror re-render

**Depends on:** Steps 1-4 all complete. **Not `haiku`** — see R6.

**Affected files**
- `.claude-plugin/plugin.json` and `package.json` — version bump from
  `0.31.57` (constitution P3; `validate.sh` enforces the two stay in sync).
- `CHANGELOG.md` — entry naming the new version and all four behavioural
  changes, stating R1 and R3 plainly rather than softening them (ADR-0018's
  own "Documentation is mandatory" consequence applies by analogy).
- `docs/adr/00NN-<slug>.md` — new ADR covering Steps 2-4 as one decision.
  **Re-derive `NN` at execution time**: the highest on disk is `0023`
  (`0023-marker-commit-attribution.md`, landed since this plan's first
  draft), so `0024` is next free *today*, but the in-flight
  marker-commit-attribution milestone or any sibling spec may consume it
  first. `0007` is a hole and is **not** free (`CONTEXT.md` links it). The
  slug is `ceremony-reduction-solo-operator`
  ("ceremony reduction for the solo-operator posture"), with an in-body
  `**Amends ADR-0003**` line for the fast-path threshold, per the
  `docs/adr/0013-*.md:14` convention.
- `docs/adr/0018-human-in-the-loop-review-on-by-default.md` — inline
  annotation only, recording that this repo now runs the documented opt-out
  locally. ADR-0018's *decision* (the shipped default stays `critical`) is
  **not** reversed — Open Question 1 resolved to local-posture-only on
  2026-08-15, so no reversal is in scope.
- `CONTEXT.md` and `.claude/wiki/**` — `scribe`'s glossary additions for the
  two Lens-3 terms ("on-demand milestone audit", "solo-operator posture").
- Regenerated, **never hand-edited** (constitution P2): every
  `.claude/agents/*.md`, `.claude/persona-protocol*.md`, and
  `.claude/persona-config.json`'s `fileHashes` — all via
  `node bin/cli.js --update`.

**Acceptance criteria**
- **AC5.1** `jq -r .version .claude-plugin/plugin.json` does **not** equal
  `0.31.57`, **and** equals `jq -r .version package.json`.
- **AC5.2** `grep -cF "$(jq -r .version .claude-plugin/plugin.json)" CHANGELOG.md`
  is ≥ 1.
- **AC5.3** `ls docs/adr/ | grep -qE '^00[0-9][0-9]-ceremony-reduction-solo-operator\.md$'`
  exits 0 — matched by slug rather than by a pinned number, so a sibling ADR
  landing first does not invalidate the criterion (per R5-style
  re-derivation) — **and** that file has `grep -c 'ADR-0003'` ≥ 1 (the
  fast-path amendment) **and** `grep -c 'ADR-0018'` ≥ 1 (the local
  `humanReviewMode` opt-out).
- **AC5.4** Two-assertion mirror-sync proof: run `node bin/cli.js --update`,
  then `node bin/cli.js --update --dry-run` exits **0** (per CONTEXT.md,
  exit 0 iff a live update would leave the tree byte-identical), **and**
  `git status --porcelain -uno` shows no `.claude/` path left unstaged by
  the unit's own commit. ~~Baseline today: `--dry-run` exits **3**.~~
  **Revised 2026-08-16 (gh403 debug spec) — ORDERING IS LOAD-BEARING.**
  Steps 3 and 4 now regenerate their own mirrors, so by the time this step
  runs, `--dry-run` already exits **0** and this criterion is a
  must-stay-green guard rather than a RED assertion. Re-measure the baseline
  at dispatch time rather than trusting the stale `3`. Critically:
  **the version bump (AC5.1) must be performed BEFORE `node bin/cli.js
  --update` is run.** Measured 2026-08-16: `--update`'s fast path at
  `bin/cli.js:1269` skips the render loop entirely when
  `config.pluginVersion === version` and every mirror's stamp already
  matches — it checks the *stamp*, not the *content*, so a plain `--update`
  on a version-current project prints "already current. Nothing to update."
  and re-renders nothing even when a source has moved on. With the bump
  applied first, the stamp mismatch forces the full render (verified: all
  ten mirrors rewritten). If for any reason `--update` must run before the
  bump, use `--force-render`.
- **AC5.5** Attributable mirror content. ~~(independent of R4's in-flight
  work, which also moves AC5.4): `grep -c '≤5' .claude/agents/orchestrator.md`
  is ≥ 1 (baseline today `0`), **and** `grep -c '≤2-unit'
  .claude/persona-protocol.md` prints `0` (baseline today `1`).~~ **Revised
  2026-08-16 (gh403 debug spec):** both halves are now satisfied upstream by
  Steps 3-4's in-unit regeneration, so as written this criterion can no
  longer fail and is **vacuous as an attribution proof for this step**. Keep
  both halves as must-stay-green regression guards, and add the assertion
  that is genuinely RED for *this* step — that every mirror carries the
  **new** version stamp: `grep -L "antislop v$(jq -r .version
  .claude-plugin/plugin.json)" .claude/agents/*.md .claude/persona-protocol.md
  | wc -l` prints `0` (`grep -L` lists files *not* matching, so `0` means
  every mirror was re-stamped). Baseline before the bump: non-zero, since
  every mirror still carries the pre-bump version.
- **AC5.6** Step 1 survived the config rewrite (R7):
  `jq -r '.humanReviewMode' .claude/persona-config.json` still prints `off`
  **and** `jq -r '.dispatchHygiene.mode'` still prints `warn`, **after**
  `--update` has rewritten the file.
- **AC5.7** `bash tests/validate.sh` exits 0 **and**
  `node tests/protocol-doc-drift.test.js` exits 0.

---

## Open Questions

**All four resolved by the operator on 2026-08-15. The recommended default
was chosen in every case, so no step body required substantive revision —
each resolution below records its effect on the spec. This plan carries no
unresolved question and is unconditional.** The questions are retained rather
than deleted so the record shows what was asked and what was decided; the
same answers are logged as dated lines in Clarifications above.

**OQ-1 — RESOLVED 2026-08-15 — local posture only.** *Local posture, or
shipped plugin default? (governs Steps 1 and 5)* Chosen: this repo's
`.claude/persona-config.json` only; the shipped default stays `"critical"` /
`"block"` and ADR-0018's decision is **not** reversed. **Risk R1 is
explicitly accepted by the operator**: with `humanReviewMode: "off"`,
security-sensitive and structural units ship on reviewer PASS with no forced
human comprehension pause. **Effect on the spec: none** — Step 1 is already
the two-value local edit, Step 5 already annotates ADR-0018 rather than
reversing it, and Step 5's CHANGELOG criterion already requires R1 be stated
plainly rather than softened. The alternative (change the shipped default,
touching the schema, `bin/cli.js`, `agents/reviewer.md`, README, adapters,
every mirror, `tests/cli-backfill.test.js`, plus a full ADR-0018 reversal)
was declined.

**OQ-2 — RESOLVED 2026-08-15 — explicit operator request only.** *What
triggers the milestone audit now? (governs Step 2, AC2.3)* Chosen: explicit
request only, as a literal greppable trigger string. The literal is fixed as
**`only when the operator explicitly asks`**. The non-gating release-boundary
reminder is retained; the automatic-at-tagged-releases alternative was
declined for want of a detectable signal. **Effect on the spec: AC2.3's
`<TRIGGER-PHRASE>` placeholder is replaced by that literal and its baseline
re-measured at `0`; no other text changed.** Also confirmed: `agent-auditor`
needs no edit (already on-demand).

**OQ-3 — RESOLVED 2026-08-15 — yes, couple them.** *Does the `to-spec`
tracker-publish threshold move with the fast path? (governs Step 3)* Chosen:
raise both together — fast path handles **≤5** units, tracker publish
triggers at **≥6**. **Effect on the spec: `agents/spec-master.md:164` moves
from conditional to unconditional in Step 3's affected-files list, and two
criteria are added — AC3.7 (the `≥3 units` → `≥6 units` swap, both
directions) and AC3.8 (no `≥3 units` threshold survives anywhere in
`agents/`).** The decoupled alternative was declined because a 4-unit spec
would skip `task-master` yet still file a tracker issue nobody slices from,
leaving `scribe`'s issue-closing duty holding an issue number with no
matching dispatch.

**OQ-4 — RESOLVED 2026-08-15 — `AskUserQuestion`, three options.**
*Mechanism for "ask the human" at the 2-FAIL cap? (governs Step 4)* Chosen:
`AskUserQuestion` with (a) debug spec via `spec-master`, (b) re-dispatch
`lead-programmer` with a human directive, (c) park the unit. **Effect on the
spec: AC4.2's `<ASK-MECHANISM>` placeholder is replaced by the literal
`AskUserQuestion` and scoped to the `sed` range (the token occurs 4 times
elsewhere in the file, so a whole-file grep would be vacuous); Step 4's body
now enumerates the three options; and AC4.7 is added to assert all three
survive.** The plain-text-report alternative was declined — the orchestrator
has no structured signal to resume on and the choice space is genuinely
discrete.

<details>
<summary>Original recommendations as drafted (retained for the record)</summary>

**OQ-1 — Local posture, or shipped plugin default? (governs Steps 1 and 5)**

**Recommendation: this repo's `.claude/persona-config.json` only. Do not
change the shipped default.** Three reasons. (a) ADR-0018 designates this
exact edit as the supported exit — *"Opt-out is real and easy"* — so using it
is the *intended* path, not a workaround, and requires no ADR reversal.
(b) The originating audit was about *this repo's own* workflow for a solo
developer; ADR-0018's argument that an off-by-default is protective-in-
reverse for *consumers* is untouched by that. (c) The blast radius differs by
an order of magnitude: local is a two-value edit, whereas changing the
shipped default means `templates/persona-config.schema.json:35-39`,
`bin/cli.js:2396`, `agents/reviewer.md:167`, README, CHANGELOG, adapters,
every mirror, `tests/cli-backfill.test.js`, and a full ADR-0018 reversal.
Alternative: change the shipped default too — adds roughly one more
milestone and reverses a deliberately-reasoned ADR. **Note this question
does not reach Steps 2-4**: those have no config surface at all, so editing
only `.claude/agents/*.md` would drift from `fileHashes` and be overwritten
by the next `--update`. They are necessarily plugin-source changes either
way.

**OQ-2 — What exactly triggers the milestone audit now? (governs Step 2,
AC2.3)**

**Recommendation: explicit operator request only**, with the section keeping
a non-gating reminder that a release boundary is a good moment to ask for
one. Pin the literal trigger phrase as **"only when the operator explicitly
asks"** so AC2.3 has a machine-checkable string. Rationale: "genuine release
boundaries" is not machine-detectable by the orchestrator and would
reintroduce exactly the judgment-call ambiguity the change is meant to
remove. Alternative: keep an automatic trigger at tagged releases — needs a
detectable signal (a version bump? a git tag?) that does not exist today.
Also confirms: **`agent-auditor` needs no edit** (already on-demand); say so
if you disagree.

**OQ-3 — Does the `to-spec` tracker-publish threshold move with the fast
path? (governs Step 3, `agents/spec-master.md:164`)**

**Recommendation: yes, couple them — raise the publish threshold to ≥6.**
Rationale: `spec-master.md:164` currently publishes to the GitHub tracker for
"specs resolving to ≥3 units", which is precisely the 3-5 band the fast path
is about to absorb. Leaving them decoupled means a 4-unit spec skips
`task-master` but still files a tracker issue nobody slices from — ceremony
with no consumer, and `scribe`'s issue-closing duty would then have an issue
number with no matching dispatch. Alternative: leave publish at ≥3, keeping
a tracker record for mid-size specs at the cost of an orphan issue per spec.

**OQ-4 — Mechanism for "ask the human" at the 2-FAIL cap? (governs Step 4,
AC4.2)**

**Recommendation: `AskUserQuestion` with three discrete options** — (a)
dispatch `spec-master` for a debug spec, (b) re-dispatch `lead-programmer`
with an operator-supplied directive, (c) park the unit. The orchestrator
already holds `AskUserQuestion`, the existing milestone-findings relay
already uses it *"where its findings reduce to discrete choices"*, and a
fixed literal gives AC4.2 something to grep. No new hook or gate; the cap
itself is prose, not a Gate, so nothing mechanical changes. Alternative:
plain-text report and wait — cheaper to write, but the orchestrator has no
structured signal to resume on and the choice space here is genuinely
discrete.

</details>

## Self-check

- **CHK1**: Does every step carry at least one criterion that is measurably
  RED today and would fail if the step were skipped? — PASS (baselines
  measured at `d25419c` and recorded inline: AC1.1 `critical`, AC1.2
  `block`, AC2.1 `1`, AC3.1 `12`, AC3.2 `0`, AC4.1 `1`, AC4.4 `1`, AC4.5
  `1`, AC5.4 exit `3`, AC5.5 `0`/`1`).
- **CHK2**: Is the scope of changes 1 and 2 — local config versus shipped
  plugin default — defined anywhere in the plan? — FAIL (missing) —
  converted to Open Question 1.
- **CHK3**: Do the Context section and Step 2 agree on whether
  `agent-auditor` is in scope? — PASS (both state it is already on-demand
  and out of scope; Step 2's "Affected files" lists only
  `agents/orchestrator.md`, and OQ-2 restates the finding for confirmation).
- **CHK4**: Is the on-demand trigger for the milestone audit stated as a
  machine-checkable literal? — FAIL (ambiguous) — converted to Open
  Question 2; AC2.3 is written with a `<TRIGGER-PHRASE>` placeholder that
  OQ-2 fills, rather than an unverifiable "make it on-demand".
- **CHK5**: Do Steps 3 and 5 agree on which files carry the ≤5 threshold
  after the change? — PASS (Step 3 edits 6 source/doc files and explicitly
  defers all `.claude/` mirrors to Step 5; AC5.5 asserts two specific mirror
  files, both of which appear in Step 3's source list as
  `agents/orchestrator.md` and `templates/persona-protocol.md`).
- **CHK6**: Is "the plan has ≥3 steps" distinguished from the fast-path
  threshold anywhere a bulk-replace implementer would see it? — PASS (named
  as a trap in Context, listed under Step 3's "Do NOT touch", and guarded by
  AC3.3).
- **CHK7**: Is the `to-spec` publish threshold's fate defined? — FAIL
  (missing) — converted to Open Question 3; Step 3's affected-files list
  makes `agents/spec-master.md:164` conditional on its resolution rather
  than silently including or excluding it.
- **CHK8**: Is "stop and surface to the human" backed by a machine-checkable
  criterion? — FAIL (ambiguous) — converted to Open Question 4; AC4.2 uses
  an `<ASK-MECHANISM>` literal that OQ-4 fixes.
- **CHK9**: Does the plan say how `.claude/` mirrors and `fileHashes` get
  updated, and is that consistent with constitution P2? — PASS (Context's
  "Mirror-sync mechanism" names `node bin/cli.js --update`; every step from
  2-4 lists mirrors under "Do NOT touch"; Step 5 owns the regeneration; the
  P2 line of the Constitution check states the same).
- **CHK10**: Does the plan state what happens if `--update` rewrites the
  config Step 1 edited? — FAIL (missing on first draft) — revised in place;
  now R7 plus AC5.6.
- **CHK11**: Do Risks and the Steps agree on dispatch order? — PASS (R5
  fixes 2 → 3 → 4 → 5 with Step 1 independent; each of Steps 2, 3, 4 repeats
  its own "Depends on / Must precede" line, and they match).
- **CHK12**: Is the security consequence of `humanReviewMode: "off"` stated
  rather than implied? — PASS (R1 names it explicitly, the Clarifications
  log records it as operator-accepted, and Step 5's CHANGELOG criterion
  requires it be stated plainly rather than softened).
- **CHK13**: Does any criterion use a line-number or byte pin that an
  unrelated reflow could silently invalidate? — FAIL (conflicting, first
  draft: AC2.3 and AC4.2/AC4.3 originally pinned line ranges) — revised in
  place; all three now use `sed` range extraction anchored on stable heading
  or sentence text plus a content count, per R6's cited precedent.
- **CHK14**: Is every FAIL above either revised in place or matched to a
  numbered Open Question? — PASS (CHK2→OQ-1, CHK4→OQ-2, CHK7→OQ-3,
  CHK8→OQ-4, CHK10 and CHK13 revised in place; and every one of OQ-1..OQ-4
  has an originating CHK).

Added by the 2026-08-15 finalization pass, after the operator answered all
four Open Questions. The four drafting-pass FAILs that were converted to Open
Questions (CHK2→OQ-1, CHK4→OQ-2, CHK7→OQ-3, CHK8→OQ-4) are now **closed** —
each question is answered and the answer is written into the plan text, so
re-checking those four items now finds the plan's own text answers them:
CHK2 by OQ-1's resolution plus the Clarifications line, CHK4 by AC2.3's
literal, CHK7 by AC3.7/AC3.8 and Step 3's coupling paragraph, CHK8 by AC4.2
and AC4.7.

- **CHK15**: Do the two placeholder literals still appear anywhere in the
  plan? — FAIL (missing, first finalization draft: the Status line asserted
  they were filled while AC2.3/AC4.2 still carried them) — revised in place;
  both are now replaced by their fixed literals. Verified by measurement, and
  stated precisely rather than absolutely: the placeholder tokens still occur
  in this document (5 and 4 times respectively, at the Status line, the
  Clarifications and Open Questions resolution notes, and the drafting-pass
  CHK4/CHK8 entries), but **every one is a meta-reference recording what the
  placeholder was** — none survives inside an acceptance criterion, which is
  the property that matters. Machine-checkable form: no line matching
  `^- \*\*AC` contains either token.
- **CHK16**: Is AC4.2 non-vacuous, given `AskUserQuestion` already occurs in
  `agents/orchestrator.md`? — FAIL (ambiguous, first finalization draft) —
  revised in place; the criterion is `sed`-range-scoped and the baseline is
  now recorded as `0` **inside the range** (measured), with the whole-file
  count of `4` stated so no implementer or reviewer mistakes a whole-file
  grep for the criterion.
- **CHK17**: Do Step 3's affected-files list and its acceptance criteria
  agree about `agents/spec-master.md:164` after OQ-3's resolution? — PASS
  (the line is unconditional in the affected-files list, the coupling
  paragraph states ≤5/≥6, and AC3.7 asserts both directions of the swap).
- **CHK18**: Is AC3.8's baseline a measured count rather than an estimate?
  — FAIL (missing, first finalization draft: written as `1` from inspection
  of a single file) — revised in place; re-measured as `4`
  (`agents/orchestrator.md:257`, `agents/spec-master.md:164,189,233`), and
  all four confirmed already inside Step 3's affected-files list, so the
  criterion adds coverage without widening scope.
- **CHK19**: Is the blocking dependency on the in-flight
  marker-commit-attribution work stated where an implementer of Step 3 will
  actually see it, rather than only in Risks? — FAIL (missing) — revised in
  place; R4 already named it, but it is now also a blockquoted gate at the
  top of Step 3 with three checkable conditions, and it is restated in the
  document's Status line.
- **CHK20**: Does AC5.3 survive a sibling ADR consuming the next number?
  — FAIL (ambiguous, first draft pinned `0024`) — revised in place; the
  criterion now matches on the slug `ceremony-reduction-solo-operator` with a
  `00NN` wildcard, and Step 5's affected-files entry instructs re-derivation
  at execution time (`0023` has landed since the first draft, so the pinned
  number was already one collision away from wrong).
- **CHK21**: Is each of the four operator answers recorded in Clarifications
  as a dated line, not merely consumed in the Open Questions section? — PASS
  (four dated 2026-08-15 lines appended, one per answered category:
  functional scope ×2, user interaction flow ×2).
- **CHK22**: Does any step body still read as conditional on an unresolved
  question? — PASS (Step 2's "exact trigger wording pinned by Open Question
  2" is now backed by a fixed literal in AC2.3; Step 3's conditional
  affected-file is now unconditional; Step 4's "mechanism pinned by Open
  Question 4" is now enumerated in the body; Step 5's OQ-1 reference now
  states the resolved outcome).

All five finalization FAILs (CHK15, CHK16, CHK18, CHK19, CHK20) were resolved
by revision in place — one revision pass, then a re-check of only the failed
items, which found no residual failure. No CHK item is left represented in
Open Questions as unresolved.

## Scribe update hint

After Step 5, `scribe` should add four `CONTEXT.md` glossary entries —
**"on-demand milestone audit"**, **"solo-operator posture"**, **"parked
unit"** (OQ-4's option (c): no marker written, none deleted; distinguishable
only by the absence of further dispatch), and an **`operator` / `human`**
reconciliation (measured 2026-08-15: `operator` occurs 0 times in
`CONTEXT.md`, yet the OQ-2 trigger literal `only when the operator explicitly
asks` puts it into shipped persona prose — add it as an explicit synonym
rather than silently rewriting the literal, which AC2.3 greps) — and update
the existing **"FAIL routing (post-reviewer)"** and **"Dispatch hygiene"**
entries to reflect the human-decision gate at the cap and this repo's `warn`
posture. The `--update semantics` entry needs no change. On the fast path
threshold, the existing wording "the same ≤2-unit fast path" appears in
CONTEXT.md at 544 and 546 and is edited by Step 3 itself, so scribe's pass is
additive only. No issue-closing duty fires for Steps 1-4 unless `task-master`
files tracker issues.
