# Spec: heavy-unit trigger concretization and unconditional `.fail`-check wording

Date: 2026-07-17
Author: spec-master
Status: Finalized — ready for task-master slicing

## Goal
Tighten model-tiering wording in two persona source files so each persona's
own instructions are correct on their own terms, without relying on another
persona's backstop:
1. `agents/task-master.md` inherits the concrete numeric heavy-unit trigger
   that its consumer (`agents/orchestrator.md`) already defines, and emits
   `Roast pass: fable` mandatorily (not discretionarily) when it fires.
2. `agents/task-master.md`'s two `.claude/reviewed/<task-id>.fail` checks
   become unconditional on every unit, not only "re-scoped" ones.
3. `agents/spec-master.md`'s comment block gains a 2-3 line summary of the
   fable-eligibility conditions and `.fail` disqualifier for its own
   dispatch, citing `orchestrator.md` as authoritative.

No behavioral mechanism changes; this is documentation tightening of
already-confirmed gaps (verified independently by the orchestrator before
dispatch and re-verified against source during drafting).

## Context
A fable-model advisory audit of the model-tiering scheme found three gaps,
each orchestrator-confirmed against the actual files:

- **Gap A (real cost impact)** — `agents/task-master.md:66-74` defines the
  heavy-unit trigger for `Roast pass: fable` with a vague parenthetical
  ("roughly, a large blast radius (many files or a big diff), a
  structural/cross-cutting change, or a security-sensitive surface") and
  discretionary emission ("you MAY additionally emit"). The same fuzzy
  trigger is reused as the load-bearing negative condition at
  `agents/task-master.md:75-78` gating the `Suggested reviewer model:
  sonnet` tag ("the unit does not meet the heavy-unit trigger above").
  Meanwhile the consumer, `agents/orchestrator.md:202-208` ("Reviewer
  roast-work advisory pass"), already defines the identical trigger with
  three concrete numbered criteria (Large surface ≥ ~8 files OR ≥ ~400
  lines; Structural / cross-cutting; Security-sensitive surface) that
  task-master.md never inherited. Vague + MAY means a run can reasonably
  under-fire the tag and makes the two tags' relationship hard to apply
  consistently and audit.
- **Gap B (defense-in-depth)** — `agents/task-master.md:62-65` ("Check
  `.claude/reviewed/<task-id>.fail` before tagging a re-scoped unit") and
  `:82-84` ("Before emitting `sonnet` on a re-scoped unit, check…") scope
  the `.fail` check to re-scoped units only. The scheme's intent
  (`agents/orchestrator.md:128-133`: "Check for a prior `.fail` record
  before ANY per-unit dispatch") is unconditional. No live correctness gap —
  the orchestrator's own unconditional backstop (orchestrator.md "Per-unit
  model routing" and "Reviewer gate model selection", incl. the `.fail`
  disqualifier at :242-246) mitigates it — but task-master's wording
  currently depends on that other persona's backstop instead of being
  correct standalone.
- **Gap C (lowest severity, fail-safe direction)** —
  `agents/spec-master.md:20-21` says only "`model: opus` is the default;
  orchestrator may override per-dispatch (orchestrator.md). Never change the
  tier here." It omits WHEN the fable override applies and the
  `.fail`-record disqualifier; that logic lives solely in
  `agents/orchestrator.md:144-173` ("Opus|Fable routing for spec-master and
  milestone-auditor"). Because the default is `opus`, an uninformed
  orchestrator over-spends rather than wrong-cheaps — low severity, closed
  for resilience against a foreign orchestrator session.

Out of scope by dispatch instruction: `agents/reviewer.md` (confirmed
correct as-is — it intentionally never self-selects its model), the
completed `docs/plans/2026-07-17-suggested-model-tier-routing-consistency.md`
work (independently confirmed done; plugin.json already at 0.13.6, mirrors
in sync), and any new agent-memory entries.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-17 Technical constraints & tradeoffs: Q Should task-master.md
  carry a verbatim copy of the trigger or a bare pointer to
  orchestrator.md? → A (self-resolved): verbatim copy of the three numbered
  criteria PLUS a one-line citation naming orchestrator.md's "Reviewer
  roast-work advisory pass" section as the authoritative definition.
  Task-master is a one-shot subagent that does not load orchestrator.md, so
  a bare pointer would leave it unable to apply the trigger; the citation
  line prevents the copy from drifting into a second source of truth
  unnoticed (both files must satisfy the same threshold grep — Step 1
  acceptance criteria enforce sync).
- 2026-07-17 Edge cases / failure handling: Q Does changing "MAY" to "MUST"
  create a new hard dependency on the tag? → A (self-resolved): no —
  orchestrator.md:210-215 already states "the trigger conditions above — not
  the tag's mere presence or absence — are what actually decide 'heavy'";
  the tag stays advisory downstream, MUST only removes needless under-firing
  at emission time. Step 1 preserves a clause saying so.
- 2026-07-17 Terminology consistency: Q Does dropping "re-scoped" from the
  two check instructions break the legitimate use of "re-scoped" at
  task-master.md:61 ("a unit re-scoped after a prior FAIL", an opus
  criterion describing a unit type, not gating a check)? → A
  (self-resolved): no — that occurrence is untouched, and Step 2's
  acceptance criteria explicitly require it to survive.
- 2026-07-17 Completion / acceptance signals: Q Version bump target? → A
  (self-resolved): `.claude-plugin/plugin.json` is currently `0.13.6`
  (verified); this change bumps to `0.13.7` with a matching CHANGELOG entry
  (constitution P3 — patch-level, doc-wording-only change).

## Risks / dependencies
- **P2 — do NOT hand-edit the mirrors.** Both `.claude/agents/task-master.md`
  and `.claude/agents/spec-master.md` are `fileHashes`-tracked in
  `.claude/persona-config.json` (verified). Edit only the sources under
  `agents/`, then regenerate via `node bin/cli.js --update` (Step 4).
- **P3 — version-stamp coupling.** Editing `agents/*.md` mandates the
  plugin.json bump + CHANGELOG entry (Step 3); `--update` depends on the
  version actually changing when content does.
- **Prior defect history on the adjacent surface.**
  `.claude/reviewed/reviewer-gate-model-step-1.fail` exists (2026-07-16):
  the reviewer-gate work that established the `Suggested reviewer model`
  tag machinery Gap B touches FAILed once for cross-file staleness between
  orchestrator.md and ADR-0006 — exactly the "copy drifts from its
  authoritative source" failure mode Step 1's sync-grep criteria exist to
  prevent. The units sliced from this spec are new task-ids (no `.fail`
  disqualifier applies mechanically), but task-master should NOT tag any of
  them `haiku`: the constitution-MUST coupling (P2/P3) plus the
  demonstrated cross-file-staleness risk make this more than mechanical
  word-swapping.
- **Wording collision risk in Step 1 greps.** The phrase "MAY additionally
  emit" occurs exactly once in `agents/task-master.md` (verified); if the
  implementer rewords surrounding prose, the absence-greps below still hold
  as long as the old discretionary/vague phrases are fully removed.

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume": satisfied — all cited line ranges, the
  fileHashes tracking of both mirrors, the current 0.13.6 version, and the
  prior `.fail` record were verified against source during drafting; every
  acceptance criterion is a runnable grep/exit-code check.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  Step 4 mandates `node bin/cli.js --update` for both tracked mirrors; no
  hand-edit of `.claude/agents/`.
- P3 "Version-stamp discipline": satisfied — Step 3 bumps plugin.json
  0.13.6 → 0.13.7 with a matching CHANGELOG entry.
- P4 "Optional personas degrade gracefully": satisfied — edits stay inside
  two optional-persona files' own bodies/comments; no new unconditional
  cross-persona reference is added to shared prose (validate.sh, Step 5,
  confirms).
- P5 "`tests/validate.sh` is the merge gate": satisfied — Step 5 gates on a
  green run.

## Steps

### Step 1 — Concretize the heavy-unit trigger and mandate emission (Gap A)
Affected files: `agents/task-master.md`
Rewrite the `Roast pass: fable` bullet (currently lines 66-74) so that:
- The vague parenthetical ("roughly, a large blast radius (many files or a
  big diff), a structural/cross-cutting change, or a security-sensitive
  surface") is replaced by the three numbered criteria copied verbatim from
  `agents/orchestrator.md:202-208`:
  1. **Large surface** — blast radius ≥ ~8 impacted files OR diff ≥ ~400
     changed lines.
  2. **Structural / cross-cutting change** — e.g. a persona split, an
     orchestrator routing rewrite, or a `bin/cli.js` migration.
  3. **Security-sensitive surface** — auth, input parsing/validation,
     secret handling, or migrations touched.
- A one-line citation states that `agents/orchestrator.md`'s "Reviewer
  roast-work advisory pass" section is the authoritative definition and the
  two files must be kept in sync.
- "you MAY additionally emit" becomes "you MUST additionally emit" when the
  trigger fires — with a retained clause noting the tag remains advisory
  downstream (the orchestrator independently re-derives "heavy" from the
  same trigger conditions; the tag's presence or absence is never itself
  the deciding classification, per orchestrator.md).
- The now-contradictory clause "don't invent the exact trigger thresholds
  or dispatch mechanics yourself" is adjusted: drop the thresholds half
  (they are now given), keep dispatch mechanics as the orchestrator's job.
- The downstream reference at lines 75-78 ("the heavy-unit trigger above")
  needs no text change — it now resolves to concrete criteria.

Acceptance criteria (run from repo root):
- `grep -qF 'blast radius ≥ ~8 impacted files OR diff ≥ ~400' agents/task-master.md` → exit 0.
- `grep -qF 'blast radius ≥ ~8 impacted files OR diff ≥ ~400' agents/orchestrator.md` → exit 0 (sync check: emitter now matches consumer verbatim on the numeric threshold).
- `grep -q 'Security-sensitive surface' agents/task-master.md && grep -q 'Structural / cross-cutting change' agents/task-master.md` → exit 0.
- `grep -q 'MUST additionally emit' agents/task-master.md` → exit 0.
- `grep -q 'MAY additionally emit' agents/task-master.md` → exit 1 (discretionary form gone).
- `grep -qF 'roughly,' agents/task-master.md` → exit 1 (vague parenthetical gone).
- `grep -q 'Reviewer roast-work advisory pass' agents/task-master.md` → exit 0 (authoritative-source citation present).

### Step 2 — Make both `.fail` checks unconditional (Gap B)
Affected files: `agents/task-master.md`
- Line 62-65: change "Check `.claude/reviewed/<task-id>.fail` before
  tagging a re-scoped unit" to "Check `.claude/reviewed/<task-id>.fail`
  before tagging any unit" (rest of the sentence unchanged).
- Line 82-84: change "Before emitting `sonnet` on a re-scoped unit, check
  `.claude/reviewed/<task-id>.fail`" to "Before emitting `sonnet` on any
  unit, check `.claude/reviewed/<task-id>.fail`" (rest unchanged).
- Do NOT touch line 61's "a unit re-scoped after a prior FAIL" (legitimate
  opus-criterion usage, not a check gate).

Acceptance criteria:
- `grep -q 'before tagging any unit' agents/task-master.md` → exit 0.
- `grep -q 'on any unit, check' agents/task-master.md` → exit 0.
- `grep -q 'before tagging a re-scoped unit' agents/task-master.md` → exit 1.
- `grep -q 're-scoped unit, check' agents/task-master.md` → exit 1.
- `grep -q 'a unit re-scoped after a prior FAIL' agents/task-master.md` → exit 0 (legitimate usage survives).

### Step 3 — Summarize fable-eligibility in spec-master's comment block (Gap C)
Affected files: `agents/spec-master.md`
In the frontmatter-adjacent comment block, immediately after the existing
"`model: opus` is the default; orchestrator may override per-dispatch
(orchestrator.md). Never change the tier here." (lines 20-21), add a 2-3
line summary — a pointer, not a duplicate source of truth — stating:
- fable override is eligible only when ALL of: scope already enumerated,
  rides existing seams, no interrogation needed;
- any relevant `.claude/reviewed/*.fail` record forces `opus` regardless;
- `agents/orchestrator.md`'s "Opus|Fable routing for spec-master and
  milestone-auditor" section is authoritative.

Acceptance criteria:
- `grep -q 'scope already enumerated' agents/spec-master.md` → exit 0.
- `grep -q 'rides existing seams' agents/spec-master.md` → exit 0.
- `grep -q 'no interrogation needed' agents/spec-master.md` → exit 0.
- `grep -qF '.fail' agents/spec-master.md` → exit 0 (disqualifier stated).
- `grep -qF 'Opus|Fable routing' agents/spec-master.md` → exit 0 (authoritative-source citation present).

### Step 4 — Version-stamp the change (constitution P3)
Affected files: `.claude-plugin/plugin.json`, `CHANGELOG.md`
- Bump `"version"` from `0.13.6` to `0.13.7`.
- Add a `CHANGELOG.md` entry for `0.13.7` covering: task-master heavy-unit
  trigger concretized (verbatim from orchestrator.md) with mandatory
  emission; both task-master `.fail` checks made unconditional; spec-master
  comment block now summarizes fable-eligibility + `.fail` disqualifier.

Acceptance criteria:
- `grep -q '"version": "0.13.7"' .claude-plugin/plugin.json` → exit 0.
- `grep -q '0.13.7' CHANGELOG.md` → exit 0.

### Step 5 — Regenerate mirrors deterministically (constitution P2)
Affected files: `.claude/agents/task-master.md`,
`.claude/agents/spec-master.md`, `.claude/persona-config.json` (their
`fileHashes` entries) — all produced by the script, never hand-edited.
- Run `node bin/cli.js --update` so both tracked mirrors regenerate from
  the edited sources.

Acceptance criteria:
- `grep -qF 'blast radius ≥ ~8 impacted files OR diff ≥ ~400' .claude/agents/task-master.md` → exit 0.
- `grep -q 'before tagging any unit' .claude/agents/task-master.md` → exit 0.
- `grep -q 'rides existing seams' .claude/agents/spec-master.md` → exit 0.
- `node bin/cli.js --update` re-run reports no pending drift for either
  mirror (fileHashes in sync — verify the output per P1, don't assume).

### Step 6 — Merge gate (constitution P5)
Affected files: none (verification only)
Acceptance criteria:
- `bash tests/validate.sh; echo "exit=$?"` → `exit=0`.

## Open Questions
None. All three gaps were pre-verified by the orchestrator and re-verified
against source during drafting; no category needed human interrogation.

## Self-check
- CHK1: Are the exact current-text locations for all three gaps cited with verified line numbers? — PASS (task-master.md:62-65/66-74/82-84, spec-master.md:20-21, orchestrator.md:202-208/144-173, all read during drafting)
- CHK2: Do all acceptance criteria reduce to runnable grep/exit-code checks? — PASS (every criterion is a grep or command exit code; no prose-only criteria)
- CHK3: Do Steps 1 and 5 agree on the exact grep the copied trigger must satisfy in both source and mirror? — PASS (same `grep -qF` threshold string applied to agents/task-master.md, agents/orchestrator.md, and .claude/agents/task-master.md)
- CHK4: Does the plan prevent a P2-violating hand-edit of the fileHashes-tracked mirrors? — PASS (Step 5 mandates `--update`; both mirrors confirmed tracked in persona-config.json)
- CHK5: Does the plan mandate the P3 bump + CHANGELOG? — PASS (Step 4, 0.13.6 → 0.13.7, current version verified)
- CHK6: Is the MAY→MUST change reconciled with the tag remaining advisory downstream? — PASS (Clarifications line 2; Step 1 retains the advisory-downstream clause, matching orchestrator.md:210-215)
- CHK7: Does Step 2 protect the legitimate "re-scoped" usage at task-master.md:61 while removing the two gating usages? — PASS (explicit do-not-touch instruction + survival grep)
- CHK8: Are the dispatch boundaries (no reviewer.md, no prior-spec re-verification, no memory entries, no self-slicing) reflected? — PASS (Context out-of-scope paragraph; slicing deferred to task-master in Handoff notes)

## Scribe update hint
No ADR needed — this tightens wording toward decisions already recorded
(ADR-0006 and orchestrator.md's routing sections define the mechanisms;
nothing new is decided here). The Step 4 CHANGELOG entry is the sufficient
institutional-knowledge record. Optionally note in the changelog line that
the heavy-unit trigger is now defined identically in emitter
(task-master.md) and consumer (orchestrator.md).

## Handoff notes
- **Slicing:** a normal `task-master` dispatch slices this. Natural shape is
  one unit (Steps 1-6 are tightly coupled through the shared version bump
  and single `--update` run); if split, Steps 1-3 must precede 4-6.
  Per the Risks section, do not tag any sliced unit `haiku` — the
  constitution-MUST coupling (P2/P3) plus prior cross-file-staleness defect
  history (`reviewer-gate-model-step-1.fail`) put this above mechanical.
  Note the self-referential wrinkle: the unit edits `agents/task-master.md`
  itself, but task-master runs from the already-installed
  `.claude/agents/` mirror, so slicing is unaffected; the mirror updates in
  Step 5.
- **Tracker publish:** the `to-spec` skill is not available in this teammate
  session, so no automated PRD publish was run. Per project convention,
  filing is via `gh issue create` (repo Storreslara/AntiSlop) with the
  `ready-for-agent` label; this canonical `docs/plans/` document is the
  authoritative artifact regardless.
