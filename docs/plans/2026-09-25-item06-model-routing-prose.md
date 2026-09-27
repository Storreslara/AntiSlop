# Item 06: Reconcile `orchestrator.md` model-routing prose with real frontmatter

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 6 of 19
Source: Fable adversarial review 2026-09-25, Workflow seam 1 + "three things" #3
Disposition: **ACCEPT — fix the prose and add a re-drift guard.** Staleness confirmed.

## Goal

Correct `agents/orchestrator.md`'s model-routing prose to match the personas'
actual frontmatter, and add a `validate.sh` check so the same claim cannot rot
silently again.

## Context

Verified 2026-09-25:

- `agents/lead-programmer.md:4` is `model: sonnet`.
- `agents/orchestrator.md` § "Per-unit model routing" still says *"so
  lead-programmer's `model: haiku` frontmatter is the default, not an
  absolute"* and describes the chain as *"(haiku → FAIL → sonnet → FAIL)"*.
- [ADR-0026](../adr/0026-writer-tier-reversed-to-sonnet.md) reversed the haiku
  default on **2026-08-25**, a month before this review.

The prose is not merely out of date, it is operationally misleading: an
orchestrator following it would omit the `model` parameter expecting haiku and
silently get sonnet, then reason about cost and escalation from a false
baseline.

Note the same file also still describes the escalation ladder from the old
starting rung, while separately (and correctly) stating *"Sonnet units
escalate on first FAIL… re-dispatches on `opus`"*. So the file currently
contradicts itself, not just the frontmatter.

**A token ban is the wrong fix.** `haiku` remains a legitimate value in the
`Suggested model: haiku|sonnet|opus` tag vocabulary, so any guard must assert
*agreement between a prose claim about a named persona's frontmatter and that
persona's actual frontmatter* — not the absence of a word. Per the
`branch-agreement-criterion` technique, assert the textual claim agrees with
its structural sibling.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-25 Edge cases / failure handling: Q Should the guard ban the token
  `haiku` in persona prose? → A (self-resolved): **no** — `haiku` is still a
  valid `Suggested model` tag value; a token ban would break the routing
  vocabulary. Guard on claim-vs-frontmatter agreement instead.
- 2026-09-25 Technical constraints & tradeoffs: Q Does the guard need to cover
  every persona, or only lead-programmer? → A (self-resolved): **every
  persona** — the defect class is "prose asserts a frontmatter value", and
  scoping it to the one instance that rotted would leave the class open.

## Risks and dependencies

- **R1. False positives.** A naive grep trips on legitimate tag-vocabulary
  mentions. The guard must be targeted; per `verify-own-criteria-nonvacuous`
  it must also be proven non-vacuous by mutation before the unit is done.
- **R2. Version-stamp discipline applies** — `agents/orchestrator.md` is
  version-stamped. Bump + CHANGELOG. Two prior units FAILed for this omission
  (`version-stamp-discipline-gap`).
- **R3. Adapter ports** may restate the chain; they are hand-maintained, not
  rendered by `cli.js`, and their parity test asserts literal strings.
- **R4. Ordering.** The guard must land **after** the prose fix, or it fails
  on the very text it is meant to protect.
- **R5.** No prior `.fail` record known (new work); marker sweep Bash-gated.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — frontmatter and prose both read
  directly.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step 2
  replaces prose-trust with a mechanical check.
- P3 "Version-stamp discipline": **applies** — see R2, asserted in Step 1.
- P4 "Optional personas degrade gracefully": satisfied — the guard must skip
  personas a project did not select rather than failing on their absence;
  asserted in Step 2.
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Correct the stale prose

**Affected files:** `agents/orchestrator.md`; regenerated
`.claude/agents/orchestrator.md`; `.claude-plugin/plugin.json`;
`CHANGELOG.md`; adapter ports if they restate the chain.

Fix the default-model claim and the escalation chain to match ADR-0026
(`sonnet` default; `sonnet → FAIL → opus`). Keep `haiku` where it is a valid
tag value. Resolve the file's internal contradiction with its own
"Sonnet units escalate on first FAIL" rule.

**Acceptance criteria**
- `grep -c 'model: haiku' agents/orchestrator.md` is **0**.
- `grep -c 'haiku → FAIL → sonnet' agents/orchestrator.md` is **0**.
- `grep -c '0026' agents/orchestrator.md` is ≥ 1 (corrected prose cites the
  reversing ADR).
- `haiku` survives as a tag value: `grep -c 'haiku' agents/orchestrator.md`
  is ≥ 1 — asserted **together with** the two zeros above, which is what
  proves the edit was targeted rather than a purge.
- Version bumped beyond `HEAD` and named in `CHANGELOG.md`.
- `bash tests/validate.sh` exits 0.

## Step 2 — Guard against re-drift

**Affected files:** `tests/validate.sh` or a new
`tests/persona-model-claims.test.sh` registered by it.

Fail when a persona document asserts a *named persona's* frontmatter model and
that assertion disagrees with the actual frontmatter.

**Acceptance criteria**
- On the Step 1 tree, the check exits 0.
- Non-vacuity by mutation: reintroduce the sentence asserting
  lead-programmer's frontmatter is `haiku`; the check **fails** and names the
  file and the disagreement; revert; it passes. Both observations recorded in
  the ready-for-review report.
- No false positive on tag vocabulary: the check exits 0 **while**
  `grep -c 'haiku' agents/orchestrator.md` is ≥ 1.
- Degrades gracefully (P4): with a persona file absent, the check exits 0
  rather than erroring — assert by temporarily moving one persona file aside.
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **Should `defaultImplementerModel` become a `persona-config.json` field?**
   The review argues the haiku→sonnet reversal required an ADR plus prose
   edits across files, and a config knob would make the next reversal a
   one-line diff. That is a real and separable design change — it is
   **item 18's** spec, not this one. Recommended default: **fix the prose
   now (this spec); decide the knob in item 18.** Flagged here only so the
   two are not confused; this spec must not pre-empt item 18 by hardcoding
   `sonnet` in a way that a later config field would have to undo.

## Self-check

- CHK1: Do Step 1's "zero `model: haiku`" and "≥1 `haiku`" criteria conflict?
  — PASS (the banned string is the frontmatter-claim form; the permitted one
  is the bare tag value; asserting both together is deliberate).
- CHK2: Is the guard scoped to avoid banning a legitimate token? — PASS
  (Step 2 carries an explicit no-false-positive criterion).
- CHK3: Do Steps 1 and 2 have a stated order? — PASS (R4 and the dispatch
  contract both state Step 1 first).
- CHK4: Is the guard proven to actually catch the defect it exists for? —
  PASS (mutate-revert observation required in the report).
- CHK5: Does this spec decide item 18's question implicitly? — FAIL
  (ambiguous) — converted to Open Question 1, with an explicit instruction not
  to pre-empt it.
- CHK6: Is P4 (graceful degradation) checked rather than asserted? — PASS
  (Step 2 requires a moved-file observation).

## Scribe update hint

No new domain term required. If `CONTEXT.md` carries a **writer tier** or
**implementer tier** entry, verify it names `sonnet`, not `haiku`, and amend
if stale — the same drift may have reached the glossary.

## Dispatch contract (fast path — 2 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item06-model-routing-prose.md`.
Order: Step 1 strictly before Step 2.

### Unit: item06-1-fix-routing-prose
- **Objective:** Correct the stale haiku-default prose and self-contradiction.
- **Retrieval:** Step 1.
- **Affected files:** `agents/orchestrator.md`, regenerated `.claude/agents/orchestrator.md`, `.claude-plugin/plugin.json`, `CHANGELOG.md`, adapter ports if applicable.
- **Ordered edits:** fix default claim → fix chain → cite ADR-0026 → reconcile with the "Sonnet units escalate on first FAIL" rule → check adapter ports → regenerate → bump → CHANGELOG.
- **Do NOT touch:** `agents/lead-programmer.md` frontmatter (already correct); the `Suggested model` tag vocabulary; `persona-config.json` (item 18 owns that).
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** `agents/lead-programmer.md:4` = `model: sonnet` (measured 2026-09-25). ADR-0026 dated 2026-08-25. The file already contains a correct contradicting rule ("Sonnet units escalate on first FAIL… on `opus`") — align to that.
- **Escalation:** if regeneration rewrites unrelated content, stop and report; never hand-edit `.claude/agents/`.

### Unit: item06-2-model-claim-guard
- **Objective:** Prevent silent re-drift of frontmatter claims.
- **Retrieval:** Step 2.
- **Affected files:** `tests/validate.sh` or a new registered test.
- **Ordered edits:** implement targeted claim-vs-frontmatter check → mutate-prove → confirm no false positive → confirm graceful degradation.
- **Do NOT touch:** persona prose (item06-1 owns it).
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** depends on item06-1. Must assert agreement between a claim and its structural sibling, not ban a token — a bare `haiku` ban breaks the `Suggested model` vocabulary.
- **Escalation:** if a targeted pattern cannot avoid false positives, report the measured false-positive count rather than shipping a broad ban.
