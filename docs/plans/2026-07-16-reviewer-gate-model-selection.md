# Plan: Signal-gated sonnet on the reviewer's authoritative PASS/FAIL gate

Date: 2026-07-16
Author: spec-master
Status: Finalized (human resolved OQ1–OQ5 on 2026-07-16)

## Goal
Let the `reviewer` persona's authoritative PASS/FAIL gate run on `sonnet`
for **demonstrably-mechanical units only**, instead of always on `opus`.
`opus` stays the default; `fable` stays permanently excluded from the gate
(fable remains advisory-`roast-work`-pass-only, exactly as ADR-0004 left it).
The selection is driven by existing signals, pre-tagged on the plan step by
`task-master`, honored by the orchestrator at dispatch, with escalation and
`.fail`-disqualifier symmetry mirroring the patterns already in
`agents/orchestrator.md`.

## Context
- `agents/reviewer.md` frontmatter is a fixed `model: opus`.
- `agents/orchestrator.md`'s "Reviewer roast-work advisory pass (fable
  heavy-lifting)" section (currently lines ~186–223) states the authoritative
  gate *"always runs on reviewer's frontmatter `model: opus` default — this
  never moves to fable, for any unit, regardless of size."* Fable is confined
  to a separate, non-authoritative advisory `roast-work` dispatch on heavy
  units.
- `docs/adr/0004-reviewer-roast-work-dual-model-routing.md` (Accepted)
  ratified that split as a deliberate protection of the system's core safety
  property (the Writer/Reviewer split).
- This change **amends, not supersedes** ADR-0004: the principle "the gate is
  judgment-capable and opus by default" survives; only a bounded,
  signal-gated exception is added so a genuinely mechanical unit may be gated
  on sonnet. Fable remains permanently barred from the gate.
- The three reused signals already exist in the codebase — no new taxonomy is
  introduced:
  - the unit's own `Suggested model: haiku` tag (task-master's existing
    lead-programmer mechanical-work signal) is the cheap-end signal;
  - the existing heavy-unit trigger (`≥~8 impacted files OR ≥~400 changed
    lines`; structural/cross-cutting; security-sensitive surface) is the
    opus-required signal — the same trigger task-master already uses for its
    `Roast pass: fable` tag;
  - a prior `.claude/reviewed/<task-id>.fail` record forces opus regardless.

Human decisions (2026-07-16): OQ1=B, OQ2=B, OQ3=A, OQ4=A, OQ5=A.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-16 Technical constraints & tradeoffs: Q May the authoritative
  PASS/FAIL gate run on a cheaper model, or stay opus always (contradicts
  ADR-0004)? → A: OQ1=B — sonnet permitted on the gate for demonstrably-
  mechanical units only; opus default; fable permanently excluded from the
  gate; requires a new ADR amending (not superseding) ADR-0004.
- 2026-07-16 User interaction flow: Q Who selects the reviewer model —
  orchestrator per-dispatch, or task-master pre-tag on the plan step? → A:
  OQ2=B — task-master pre-tags the step (mirrors `Suggested model` /
  `Roast pass: fable`); orchestrator honors the tag at dispatch and applies
  the dispatch-time overrides.
- 2026-07-16 Functional scope & success criteria: Q What signals define
  simple vs complex? → A: OQ3=A — reuse existing signals only (the unit's own
  `Suggested model: haiku` tag at the cheap end; the existing heavy-unit
  trigger as the opus-required signal). No new taxonomy.
- 2026-07-16 Edge cases / failure handling: Q Should a wrong sonnet-gated
  review escalate, and on what trigger (there is no reviewer-FAIL concept)? →
  A: OQ4=A — escalation keyed on the unit: a sonnet-gated PASS later found to
  have missed a defect (human catch, milestone-auditor finding, or downstream
  FAIL on that unit) re-reviews on opus and is never sonnet-gated again,
  mirroring "haiku FAILs escalate to sonnet, never haiku again."
- 2026-07-16 Non-functional attributes (perf, security, scale): Q Should a
  prior `.fail` record disqualify sonnet-gated reviewer dispatch? → A: OQ5=A —
  yes; a prior `.claude/reviewed/<task-id>.fail` forces opus review
  regardless of complexity signals, mirroring the existing fable disqualifier.
- 2026-07-16 Terminology consistency: Q (self-resolved) Is `sonnet` currently
  in reviewer's range? → A (self-resolved): No — today only opus (gate) and
  fable (advisory pass) appear. This spec introduces `sonnet` as a net-new
  gate tier via a new tag `Suggested reviewer model: sonnet`.
- 2026-07-16 Domain entities / data model: Q (self-resolved) Does OQ4 need a
  new durable marker type for "never sonnet again"? → A (self-resolved): No —
  OQ4 and OQ5 share the existing `.fail` record. A confirmed sonnet-gated miss
  re-reviews on opus; the opus re-review returns FAIL and writes the standard
  `.claude/reviewed/<task-id>.fail`, which via OQ5 permanently forces opus for
  that unit id. No new marker-writer is introduced (this also respects
  reviewed-dir ownership — only the reviewer writes there).

## Risks / dependencies
- **Core-safety-property risk.** Moving any gate off opus weakens the
  Writer/Reviewer split if the "mechanical" signal is wrong. Mitigation: the
  sonnet path is conjunctive-gated (haiku-tagged AND not-heavy-trigger AND no
  prior `.fail`), fable is never permitted on the gate, and any confirmed miss
  escalates to opus permanently via the `.fail` record. reviewer.md warns the
  most common defect is a plausible-looking implementation that quietly misses
  edge cases — the conjunctive gate is deliberately conservative for exactly
  this reason.
- **Version-stamp discipline (Constitution P3).** Editing `agents/*.md`
  requires a `plugin.json` version bump + CHANGELOG entry + re-stamped
  `.claude/agents/` copies + refreshed `persona-config.json` fileHashes. Done
  via the deterministic `bin/cli.js --update` path (Constitution P2), never by
  hand-editing hashes.
- **Prose-coherence risk.** The three edited persona files must not
  contradict one another or ADR-0004/0006. The reviewer step verifies
  cross-file consistency.
- **Depends on** nothing outside this repo; all changes are prose/config.
- **Blast radius (enumerated, docs/config only):** `agents/orchestrator.md`,
  `agents/reviewer.md`, `agents/task-master.md`, `docs/adr/0006-*.md` (new),
  `docs/adr/0004-*.md` (amendment note), `.claude-plugin/plugin.json`,
  `CHANGELOG.md`, and the script-regenerated `.claude/agents/{orchestrator,
  reviewer,task-master}.md` + `.claude/persona-config.json`. No hook, no
  `persona-protocol.md`, no `protocol-digest.md` change (reviewer-model
  routing lives in orchestrator.md, matching where existing model-routing
  lives).

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume": satisfied — every acceptance criterion below is a
  runnable command (`grep`/`diff`/`node`/`bash tests/validate.sh`) whose exit
  code is checked, not an eyeballed "looks fine."
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  `.claude/agents/` re-stamp and `persona-config.json` fileHashes refresh are
  done via `node bin/cli.js --update`, never hand-edited.
- P3 "Version-stamp discipline": satisfied — Step 5 bumps
  `.claude-plugin/plugin.json`, adds a CHANGELOG entry, and re-stamps the
  copies; it is a hard acceptance criterion, not optional.
- P4 "Optional personas degrade gracefully": satisfied — new prose about
  `reviewer`/`task-master`/`milestone-auditor` stays conditionally phrased
  ("if present, ...") so a project that skipped one still ships valid prose;
  Step-level criteria assert this.
- P5 "`tests/validate.sh` is the merge gate": satisfied — Step 5's final
  criterion is `bash tests/validate.sh` exiting 0.

## Steps

### Step 1 — Orchestrator: amend the "always opus" gate language and add the reviewer-gate selection subsection
Affected files: `agents/orchestrator.md`

Changes:
- (1a) In the "Reviewer roast-work advisory pass (fable heavy-lifting)"
  section, amend the sentence asserting the gate *always* runs on opus so it
  reads that the gate **defaults to opus and may run on sonnet for
  demonstrably-mechanical units per the new "Reviewer gate model selection"
  subsection, but never on fable, for any unit, regardless of size.** Leave
  the rest of the advisory-pass section (the fable `roast-work` mechanics,
  triggers, and "strictly advisory / never writes the marker" rules)
  unchanged.
- (1b) Add a new subsection under "Per-unit model routing", titled
  **"Reviewer gate model selection (sonnet for mechanical units)"**, stating:
  - Read the sliced unit's `Suggested reviewer model: sonnet` tag
    (task-master's judgment that the unit is mechanical enough to gate on
    sonnet); pass it as the reviewer dispatch's `model` parameter. Omit the
    parameter when the tag is absent, so reviewer's `model: opus` frontmatter
    applies as the default. Same `CLAUDE_CODE_SUBAGENT_MODEL` caveat as the
    other routing subsections.
  - **Fable is never valid on this tag / the gate.** Fable stays confined to
    the separate advisory `Roast pass: fable` dispatch — unchanged.
  - **`.fail` disqualifier (OQ5):** before dispatching the reviewer, check
    `.claude/reviewed/<task-id>.fail`; if it exists, ignore any sonnet tag and
    dispatch the reviewer on opus — extending the existing "check for a prior
    `.fail` before ANY per-unit dispatch" rule to the reviewer dispatch.
  - **Escalation (OQ4):** if a unit that received a sonnet-gated PASS is later
    found to have missed a defect (a human catch, a `milestone-auditor`
    finding, or a downstream FAIL on that unit), re-dispatch that unit's
    review on opus, never sonnet. The opus re-review, on confirming the miss,
    returns FAIL and writes the standard `.claude/reviewed/<task-id>.fail`
    record, which via the `.fail` disqualifier permanently forces opus for
    that unit id thereafter — so OQ4 and OQ5 share one durable mechanism and
    no new marker type is introduced. Mirrors "Haiku units escalate on first
    FAIL … never haiku again."

Acceptance criteria (run from repo root):
- `grep -q "Reviewer gate model selection" agents/orchestrator.md`
- `grep -q "Suggested reviewer model: sonnet" agents/orchestrator.md`
- The amended sentence no longer claims the gate is unconditionally opus:
  `! grep -Eq "gate always runs on reviewer's frontmatter .model: opus. default — this never moves to fable, for any unit, regardless of size" agents/orchestrator.md`
- Fable-exclusion-from-gate is still asserted:
  `grep -Eiq "never (on |run[s]? on )?fable|fable.*never.*gate|never.*fable.*gate" agents/orchestrator.md`
- `grep -q "\.claude/reviewed/<task-id>\.fail" agents/orchestrator.md` (the
  `.fail` disqualifier is referenced in the new subsection)

### Step 2 — Reviewer: note the overridable frontmatter default
Affected files: `agents/reviewer.md`

Changes: add a short note (frontmatter comment and/or a bullet) that the
`model: opus` frontmatter is a **default** the orchestrator may override to
`sonnet` for demonstrably-mechanical units (per orchestrator's "Reviewer gate
model selection"), that the gate **never runs on fable**, and that regardless
of the dispatch model the materiality filter, machine-checkable criteria, and
PASS/FAIL marker format are unchanged. Do not change the frontmatter value
itself (stays `model: opus`).

Acceptance criteria:
- Frontmatter default unchanged:
  `grep -Eq "^model: opus" agents/reviewer.md`
- `grep -Eiq "sonnet" agents/reviewer.md` (the override is documented)
- `grep -Eiq "never.*fable|fable.*never" agents/reviewer.md` (gate never on
  fable is restated)

### Step 3 — task-master: emit the `Suggested reviewer model: sonnet` tag
Affected files: `agents/task-master.md`

Changes: add a bullet (alongside the existing "Per-unit model tag" and
"Optional `Roast pass: fable` tag" bullets) defining the reviewer-model tag:
- Emit `Suggested reviewer model: sonnet` on a sliced unit **iff BOTH**: the
  unit's own `Suggested model:` tag is `haiku` (mechanical, low-judgment), AND
  the unit does **not** meet the heavy-unit trigger (`≥~8 files OR ≥~400
  lines`; structural/cross-cutting; security-sensitive surface — the same
  trigger already used for `Roast pass: fable`).
- Otherwise omit the tag (→ reviewer's opus default). **Never** emit any value
  other than `sonnet` on this tag — never fable, never haiku, never an
  explicit opus (opus is the omitted default).
- Before emitting `sonnet` on a re-scoped unit, check
  `.claude/reviewed/<task-id>.fail` — a prior FAIL means the unit is not
  "mechanical to verify"; never sonnet-tag it (mirrors the existing
  never-`haiku` check for `Suggested model`). The orchestrator re-checks this
  at dispatch (Step 1b) as a belt-and-suspenders backstop.

Acceptance criteria:
- `grep -q "Suggested reviewer model: sonnet" agents/task-master.md`
- `grep -Eiq "haiku" agents/task-master.md` (cheap-end signal named — already
  present; assert the reviewer-tag bullet references it)
- `grep -Eiq "\.claude/reviewed/<task-id>\.fail" agents/task-master.md`

### Step 4 — ADR 0006 (amends 0004) + amendment note on 0004
Affected files: `docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md`
(new), `docs/adr/0004-reviewer-roast-work-dual-model-routing.md` (append a
"Amended by ADR-0006" line under its Status/Related).

The ADR-0006 content is fully specified in the "ADR-0006 content" appendix
below — the implementing persona writes that verbatim (adjusting only the
date/status header if needed). It must: (a) state it amends, not supersedes,
ADR-0004; (b) record that "opus by default, judgment-capable gate" is
preserved; (c) record the bounded, signal-gated sonnet exception (the
conjunctive trigger); (d) record that fable remains permanently excluded from
the gate; (e) record the OQ4 escalation and OQ5 disqualifier and that they
share the `.fail` mechanism.

Acceptance criteria:
- `test -f docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md`
- `grep -Eiq "amend" docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md`
- `grep -Eiq "supersed" docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md`
  (present, in the context of "amends, not supersedes")
- `grep -Eiq "fable.*exclud|exclud.*fable|never.*fable" docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md`
- `grep -Eiq "0006" docs/adr/0004-reviewer-roast-work-dual-model-routing.md`
  (0004 carries a back-reference to the amending ADR)

### Step 5 — Version-stamp discipline (Constitution P3 + P2)
Affected files: `.claude-plugin/plugin.json`, `CHANGELOG.md`, and the
script-regenerated `.claude/agents/{orchestrator,reviewer,task-master}.md` +
`.claude/persona-config.json`.

Changes:
- Bump `.claude-plugin/plugin.json` `version` from `0.12.1` to `0.13.0`
  (new feature → minor bump).
- Add a `## [0.13.0] - 2026-07-16` CHANGELOG entry under `### Added`
  describing the signal-gated sonnet reviewer-gate tier and citing ADR-0006.
- Run `node bin/cli.js --update` to deterministically re-stamp the three
  edited `.claude/agents/` copies with the new version stamp and refresh
  `.claude/persona-config.json`'s `pluginVersion` + `fileHashes` (Constitution
  P2 — never hand-edit hashes).

Acceptance criteria:
- `grep -q '"version": "0.13.0"' .claude-plugin/plugin.json`
- `grep -q "0.13.0" CHANGELOG.md`
- `grep -q '"pluginVersion": "0.13.0"' .claude/persona-config.json`
- Each re-stamped copy matches its source modulo the stamp line — for
  X in orchestrator, reviewer, task-master:
  `diff <(grep -v 'ADAPT-substituted' .claude/agents/X.md) <(grep -v 'ADAPT-substituted' agents/X.md)` is empty
- The stamp reflects the new version:
  `grep -q 'antislop v0.13.0' .claude/agents/reviewer.md` (and orchestrator,
  task-master)
- `bash tests/validate.sh` exits 0 (Constitution P5 — the merge gate).

## Open Questions
None — all five (OQ1–OQ5) were resolved by the human on 2026-07-16 (see
Clarifications). No remaining item requires information only the user has.

## Self-check
- CHK1: Is the exact condition under which the gate may run on sonnet defined
  (not just "mechanical")? — PASS (Step 3: haiku-tagged AND not-heavy-trigger
  AND no prior `.fail`, conjunctive).
- CHK2: Do the orchestrator (Step 1), reviewer (Step 2), and task-master
  (Step 3) descriptions agree on which model the gate defaults to and that
  fable is never on the gate? — PASS (all three assert opus default + fable
  never on gate; asserted by grep criteria in each step).
- CHK3: Is OQ4's "never sonnet-gated again" backed by a durable, machine-
  checkable mechanism rather than session memory? — PASS (Steps 1b/4:
  escalation re-reviews on opus; a confirmed miss produces the standard
  `.fail` record, which OQ5's disqualifier reads — shared mechanism, no new
  marker).
- CHK4: Does every step carry at least one runnable pass/fail criterion (no
  prose-only "works correctly")? — PASS (each step lists `grep`/`test`/`diff`/
  `bash`/`node` commands with checked exit codes).
- CHK5: Is Constitution P3 (version-stamp) represented as a hard criterion,
  not an aside? — PASS (Step 5, with `bash tests/validate.sh` exit 0).
- CHK6: Is fable's status on the gate stated unambiguously and consistently as
  permanently excluded (no "regardless of size" contradiction left behind)? —
  PASS (Step 1a removes the stale unconditional-opus sentence and restates
  fable-exclusion; ADR-0006 records it; grep criteria assert both).
- CHK7: Does the plan avoid touching `persona-protocol.md`/`protocol-digest.md`
  when the routing belongs in orchestrator.md? — PASS (Risks/blast-radius:
  explicitly no protocol-file change; reviewer-model routing colocated with
  existing model-routing in orchestrator.md).
- CHK8: Is the `.fail` disqualifier applied at BOTH task-master tag-time and
  orchestrator dispatch-time (belt-and-suspenders, matching the existing
  haiku pattern)? — PASS (Step 3 tag-time check + Step 1b dispatch-time
  re-check).

All CHK items PASS; no item converted to an Open Question.

## Scribe update hint
On completion: ADR-0006 is authored under Step 4 (scribe owns ADRs — the
implementing persona may be `scribe` for that step). The wiki/CONTEXT entry
for "reviewer model routing" should note the new sonnet gate tier and point at
ADR-0006 as amending ADR-0004. No glossary term changes ("gate", "advisory
pass", "heavy-unit trigger" already defined).

---

## Appendix: ADR-0006 content (verbatim for Step 4)

```markdown
# ADR 0006: Signal-gated sonnet on the reviewer's authoritative PASS/FAIL gate (amends ADR-0004)

Date: 2026-07-16
Status: Accepted (amends ADR-0004; does not supersede it)

## Context
ADR-0004 fixed the reviewer's authoritative PASS/FAIL gate on `opus` and
excluded `fable` from it entirely, confining fable to a separate,
non-authoritative advisory `roast-work` pass on heavy units. That protected
the system's core safety property (the Writer/Reviewer split) by keeping the
judgment-critical gate on the strongest model.

Follow-up request: allow flexible reviewer-gate model selection so a
genuinely mechanical unit is not always reviewed on opus. The tension is that
ADR-0004 blanket-states the gate is always opus. The resolution must not
weaken the gate for anything but demonstrably-mechanical work, and must keep
fable off the gate permanently.

## Decision
Amend ADR-0004 (do NOT supersede it). The principle "the gate is judgment-
capable and opus **by default**" is preserved. A single bounded, signal-gated
exception is added:

- The authoritative PASS/FAIL gate MAY run on `sonnet` for a unit iff ALL of:
  1. the unit carries `Suggested model: haiku` (task-master's mechanical,
     low-judgment lead-programmer signal), AND
  2. the unit does NOT meet the existing heavy-unit trigger (`≥~8 impacted
     files OR ≥~400 changed lines`; structural/cross-cutting; security-
     sensitive surface), AND
  3. no prior `.claude/reviewed/<task-id>.fail` record exists for the unit.
- Otherwise the gate runs on `opus` (the default): any sonnet/untagged
  lead-programmer unit, any heavy-unit-trigger hit, or any prior `.fail`.
- `fable` remains PERMANENTLY excluded from the gate. Fable stays confined to
  the separate advisory `Roast pass: fable` dispatch defined in ADR-0004,
  unchanged.

**Who tags / who dispatches:** `task-master` pre-tags the plan step with
`Suggested reviewer model: sonnet` when conditions (1)+(2) hold (and not (3)
for a re-scoped unit it can see). The orchestrator honors the tag at dispatch
and re-applies the `.fail` disqualifier (condition 3) as a dispatch-time
backstop — mirroring the existing `Suggested model` / `Roast pass: fable`
tagging pattern.

**Escalation (mirrors "haiku FAILs escalate to sonnet, never haiku again"):**
if a unit that received a sonnet-gated PASS is later found to have missed a
defect — a human catch, a milestone-auditor finding, or a downstream FAIL on
that unit — it re-reviews on `opus` and is never sonnet-gated again. The opus
re-review, on confirming the miss, returns FAIL and writes the standard
`.claude/reviewed/<task-id>.fail` record; the `.fail` disqualifier then
permanently forces opus for that unit id. OQ4 (escalation) and OQ5
(disqualifier) therefore share one durable mechanism — no new marker type is
introduced, and reviewed-dir ownership (only the reviewer writes there) is
respected.

## Consequences
- **Core safety property preserved for real judgment work:** the gate is opus
  for everything except a conjunctively-gated mechanical slice; fable is never
  on the gate. The Writer/Reviewer split is intact.
- **Bounded cost saving:** mechanical, low-risk units are gated on sonnet
  instead of opus.
- **Conservative by construction:** the conjunction (haiku AND not-heavy AND
  no-prior-fail) plus permanent-opus-on-any-miss means the exception cannot
  quietly erode the gate; a single confirmed miss removes sonnet eligibility
  for that unit forever.
- **No new durable state:** escalation reuses the existing `.fail` record.
- **PASS marker unchanged:** a sonnet-gated review writes the same v2 PASS
  marker (`criteria: <command(s) run>`); no marker-format change.

## Related
- Amends ADR-0004 (reviewer roast-work / dual-model routing) — the fable
  advisory pass and its heavy-unit trigger are unchanged; only the "gate is
  always opus" blanket is narrowed to "opus by default, sonnet for
  demonstrably-mechanical units, never fable."
- Plan: docs/plans/2026-07-16-reviewer-gate-model-selection.md
```
