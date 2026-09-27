# Item 18: `defaultImplementerModel` as a `persona-config.json` field

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 18 of 19
Source: Fable adversarial review 2026-09-25, reactive-complexity table (ADR-0010 → ADR-0026)
Disposition: **ACCEPT — with a mandatory backfill step**, because a new config key is inert here without one.

## Goal

Make the implementer default a config value rather than a frontmatter value
restated in prose, so the next tier reversal is a one-line diff instead of an
ADR plus scattered prose edits.

## Context

The review's case: ADR-0010 set haiku as the implementer default;
[ADR-0026](../adr/0026-writer-tier-reversed-to-sonnet.md) reversed it 23 days
later after the FAIL rate doubled (16.7% → 32.5%). That reversal is good —
it is measurement-driven — but it required an ADR, a frontmatter change, and
prose edits, **and the prose edits were missed**: `agents/orchestrator.md`
still described the haiku default a month later (item 6). A config knob would
have made the reversal atomic.

**A defect class this repo has already paid for, which must be designed
around here.** Per the `cli-update-never-reaches-settings-fragment` memory
note: `runUpdate` returns at `bin/cli.js:2188`, while the settings fragment
merges at `2387`. A **new config key is therefore inert for already-adapted
projects** unless `runUpdate` explicitly backfills it. Adding the field
without a backfill would ship a knob that silently does nothing in every
existing installation — including this one.

This is not a hypothetical: the same memory note records it as a measured
property of the update path, and the cost-governance spec had to design
around it. Step 2 exists solely because of it.

**A second constraint.** Per `escalation-vs-protectedpaths` and the Set B
machinery, `persona-config.json` is a protected path: agents cannot hand-edit
it, and changes route through `node bin/cli.js --update`. So the field's
*default* must be written by `cli.js`, not by an agent editing the file.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-25 Domain entities / data model: Q What is the precedence between
  the config field, the persona's frontmatter, and a per-dispatch `model`
  parameter? → A (self-resolved): per-dispatch `model` > config field >
  frontmatter default, mirroring the existing documented precedence (env var
  > per-call param > frontmatter). The config field supplies the value the
  orchestrator passes when a unit carries no `Suggested model` tag. Step 1
  must state this explicitly or the knob's effect is undefined.
- 2026-09-25 External dependencies & integrations: Q Will a new key reach
  existing projects? → A (self-resolved): **not without a backfill** —
  `runUpdate` returns before the settings fragment merges. Step 2 is
  mandatory, not optional.
- 2026-09-25 Edge cases / failure handling: Q What if the key is absent or
  holds an unrecognised value? → A (self-resolved): an absent key resolves to
  the persona's frontmatter (`sonnet` today), and an unrecognised value must
  fail toward **more** capability, never less — matching the repo's
  documented direction that judgment may only move toward more capability
  (see the terminology trap in `claude-code-hook-and-effort-primitives`:
  "downgrade" here means `sonnet` → `opus`).

## Risks and dependencies

- **R1. Inert-key defect** — see Context. The single most likely way this
  item ships broken.
- **R2. Silent precedence ambiguity.** If the field and a `Suggested model`
  tag disagree, behaviour must be defined. Step 1 defines it.
- **R3. Protected path.** `persona-config.json` is Set B; the default must be
  written by `cli.js`. An agent attempting a hand-edit will be blocked, and
  that block must be reported, not routed around.
- **R4. Overlap with item 6.** Item 6 fixes the stale prose; this item removes
  the need for that prose to state a value at all. They must not contradict:
  item 6 must not hardcode `sonnet` in a way this field would have to undo.
  Sequence item 6 first, then this.
- **R5. Version-stamp discipline applies** if `agents/*.md` prose changes.
- **R6.** No prior `.fail` record known (new work); marker sweep Bash-gated.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the inert-key path and the protected
  status of `persona-config.json` were both checked against recorded
  measurements rather than assumed.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — this
  is the principle's own use case: a config value read by a script, replacing
  a value an agent must re-derive from prose.
- P3 "Version-stamp discipline": **applies** if persona prose changes — R5.
- P4 "Optional personas degrade gracefully": satisfied — an absent key must
  resolve to frontmatter, so a project that never adopts the field is
  unaffected; asserted in Step 1.
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Add the field and define its precedence

**Affected files:** `bin/cli.js` (default emission + schema/validation);
`agents/orchestrator.md` (read the field at dispatch time); regenerated
`.claude/agents/orchestrator.md`; `.claude-plugin/plugin.json`;
`CHANGELOG.md`.

**Acceptance criteria**
- A fresh scaffold emits `defaultImplementerModel` into
  `persona-config.json` with the value matching
  `agents/lead-programmer.md`'s frontmatter (`sonnet` today) — assert the two
  agree programmatically, not by eye.
- Precedence is documented and checkable: `agents/orchestrator.md` states
  per-dispatch tag > config field > frontmatter.
- Absent key degrades to frontmatter: with the key removed from a test
  config, routing still resolves to the frontmatter value — assert by test.
- An unrecognised value resolves toward more capability, never less; assert
  by test with a junk value.
- Version bumped beyond `HEAD` and named in `CHANGELOG.md`.
- `bash tests/validate.sh` exits 0.

## Step 2 — Backfill the key into already-adapted projects

**Affected files:** `bin/cli.js` `runUpdate` path.

**Acceptance criteria**
- Running `node bin/cli.js --update` against a project config **lacking**
  `defaultImplementerModel` adds it, with the correct default, without
  disturbing other fields.
- Non-vacuity proven: construct a fixture config without the key, run
  `--update`, assert the key is present afterwards; then assert an unrelated
  field (e.g. `humanReviewMode`) is **byte-identical** before and after.
  Record both observations in the report.
- Idempotent: running `--update` twice leaves the config unchanged after the
  first run.
- A project that has **deliberately set** the field to a non-default value
  keeps that value across `--update` — assert explicitly; a backfill that
  overwrites an operator's choice is worse than no backfill.
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **Should the reviewer tier get the same treatment?** `reviewer-tier.sh`
   already measures eligibility, and the review calls `SENSITIVE_PATHS` "the
   single best-designed thing in the recent layer". Adding a config override
   there could weaken a measured gate with a config line. Recommended
   default: **no — leave the reviewer tier measured.** The implementer
   default is a *policy* value that has genuinely reversed once; the reviewer
   tier is a *measurement* and should not become an opinion. Flagged so the
   symmetry is declined deliberately rather than by omission.

## Self-check

- CHK1: Does the spec guard against the inert-key defect? — PASS (Step 2 is
  mandatory and proven by fixture).
- CHK2: Is precedence defined, or left to be inferred? — PASS (Step 1 states
  and tests it).
- CHK3: Could the backfill overwrite a deliberate operator setting? — FAIL
  (missing) — revised in place: Step 2 now carries an explicit
  preserve-non-default criterion.
- CHK4: Do this item and item 6 contradict? — PASS (R4 sequences item 6
  first and forbids it hardcoding a value this field would undo).
- CHK5: Is the unrecognised-value direction consistent with the repo's
  "toward more capability" rule? — PASS (stated in Clarifications and
  asserted by test in Step 1).
- CHK6: Is the protected-path constraint respected? — PASS (R3; the default is
  written by `cli.js`, never by an agent hand-edit).

## Scribe update hint

Add **defaultImplementerModel** with its precedence rule and its absent-key
behaviour. Cross-reference ADR-0010 and ADR-0026 so the reversal history
stays attached to the knob that now encodes it.

## Dispatch contract (fast path — 2 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item18-default-implementer-model-config.md`.
Order: item 6 first (external dependency), then Step 1, then Step 2.

### Unit: item18-1-add-config-field
- **Objective:** Add the field and define its precedence.
- **Retrieval:** Step 1.
- **Affected files:** `bin/cli.js`, `agents/orchestrator.md`, regenerated `.claude/agents/orchestrator.md`, `.claude-plugin/plugin.json`, `CHANGELOG.md`.
- **Ordered edits:** emit default in scaffold → add validation → document precedence in orchestrator prose → tests for absent/junk values → regenerate → bump → CHANGELOG.
- **Do NOT touch:** `.claude/persona-config.json` by hand (Set B protected path — route through `cli.js`); `reviewer-tier.sh`.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** depends on item 6 landing first. `agents/lead-programmer.md:4` = `model: sonnet`. Repo direction: judgment may move toward MORE capability only — "downgrade" here means `sonnet` → `opus`.
- **Escalation:** if editing `persona-config.json` is blocked by a gate, that is expected — route the default through `cli.js` and report if that is insufficient.

### Unit: item18-2-backfill-existing-configs
- **Objective:** Make the key reach already-adapted projects.
- **Retrieval:** Step 2.
- **Affected files:** `bin/cli.js` `runUpdate` path.
- **Ordered edits:** add backfill in `runUpdate` → fixture without the key → prove addition → prove unrelated fields untouched → prove idempotency → prove non-default preservation.
- **Do NOT touch:** the settings-fragment merge path (it is unreachable from `runUpdate` by design — do not "fix" that here).
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** `runUpdate` returns at `bin/cli.js:2188`; the settings fragment merges at `2387`. A new key is therefore inert without an explicit `runUpdate` backfill — this is a measured property, not a guess.
- **Escalation:** if backfill cannot preserve a deliberately-set non-default value, report rather than shipping an overwrite.
