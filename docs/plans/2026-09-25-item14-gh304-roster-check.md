# Item 14: gh-304 SendMessage roster-check paragraph — proposed revert

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 14 of 19
Source: Fable adversarial review 2026-09-25, reactive-complexity table (gh-304)
Disposition: **REJECT the revert — the premise is false.** One small clarifying edit accepted instead.

## Goal

Evaluate the review's proposal to delete `agents/orchestrator.md`'s
"check the roster before resuming" paragraph on the grounds that the real fix
(unnamed reviewer dispatch) already exists. Verify the premise, and act on
what the verification actually shows.

## Context

The review's verdict reads: *"Revert to a structural fix. The prose ('check
the roster before resuming') doesn't generalize; the actual fix is 'reviewer
dispatches are unnamed' — which is already the default. Delete the paragraph;
keep the default."*

**The premise is false, and deleting the paragraph would remove the only
guard on the incident path.** Verified 2026-09-25 by reading both passages:

The unnamed-dispatch default and the roster check govern **two different
mechanisms**:

- **`Agent` dispatch** — the default is to pass no `name:` parameter. This is
  the structural fix the review points at, and it does work: `name:` is
  omitted, so there is nothing to collide.
- **`SendMessage` resume** — you address an agent **by name**. There is no
  `name:` parameter to omit; naming is the addressing mechanism itself. The
  unnamed-dispatch default therefore cannot apply here even in principle.

The gh-304 incident was a **`SendMessage`** bare-name resolution reaching an
idle session from an unrelated plan, which then performed a genuine review and
wrote a conflicting verdict. The orchestrator's own text says so: *"a
bare-name `SendMessage` resolves to its most recent holder — possibly a stale
session from an unrelated plan."*

So the structural fix covers the `Agent` path and leaves the `SendMessage`
path entirely uncovered. The roster-check paragraph is the only thing
standing on that path. Deleting it would reopen the exact incident it was
written for.

**A second reason the paragraph earns its place.** The same passage documents
a residual that no structural fix covers at all: `reviewer-route-gate.sh`
inspects only the *requested* `tool_input.name` at dispatch time, never the
harness's post-spawn `agent_type`, so a correctly-named dispatch can still
run under a name-collision auto-suffix the gate cannot see. That is
independently recorded in this project's memory
(`reviewer-dispatch-name-gate`).

**What the review does get right.** The surrounding prose is long, and the
distinction that makes it necessary — `Agent` naming versus `SendMessage`
addressing — is never stated outright. A reader can finish the section
believing the two are the same mechanism, which is precisely the inference
the review made. That is a real defect, and it is a *clarity* defect, not a
*reactive-complexity* one. Step 1 fixes it in about two sentences.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-25 User interaction flow: Q Does the unnamed-dispatch default cover
  the `SendMessage` resume path? → A (self-resolved): **no.**
  `SendMessage` addresses by name by construction; there is no name to omit.
  The review's revert premise fails on this point, so the revert is rejected.
- 2026-09-25 Terminology consistency: Q Are "dispatch naming" and "resume
  addressing" distinguished anywhere? → A (self-resolved): **no** — and that
  omission is what made the review's misreading reasonable. Step 1 states the
  distinction and adds a glossary entry.

## Risks and dependencies

- **R1. Do not shorten by deleting the residual.** The name-collision
  auto-suffix residual has no structural fix and is separately recorded in
  memory. A "compression" edit that drops it would lose real information.
  Acceptance criteria pin it.
- **R2. Version-stamp discipline applies** — `agents/orchestrator.md` is
  version-stamped. Bump + CHANGELOG required; two prior units FAILed for
  omitting exactly this.
- **R3. Low blast radius but non-zero:** this passage is also restated in the
  adapter ports, which per `adapter-ports-are-hand-maintained` are **not**
  rendered by `cli.js` and whose parity test asserts literal strings.
- **R4.** No prior `.fail` record known (new work); marker-directory sweep is
  Bash-gated for this persona.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the revert premise was checked
  against both mechanisms and found false; this spec records the check rather
  than the conclusion alone.
- P2 "Prefer deterministic scripts over LLM re-derivation": deviation — the
  `SendMessage` path genuinely cannot be gated by a script today (the hook
  sees no unit id on that path, per ADR-0016), so prose is the only available
  control. This is the justification for keeping a rule as prose.
- P3 "Version-stamp discipline": **applies** — see R2, asserted in Step 1.
- P4 "Optional personas degrade gracefully": satisfied — reviewer references
  stay conditionally phrased.
- P5 "`tests/validate.sh` is the merge gate": satisfied — asserted.

## Step 1 — State the `Agent`-naming vs `SendMessage`-addressing distinction

**Affected files:** `agents/orchestrator.md` ("Dispatch naming" / "Reviewer
re-tasking discipline"); regenerated `.claude/agents/orchestrator.md`;
`CONTEXT.md`; `.claude-plugin/plugin.json`; `CHANGELOG.md`; adapter ports if
they restate the passage.

Add an explicit sentence that the unnamed-dispatch default applies to `Agent`
dispatches only, and that `SendMessage` addresses by name by construction, so
the roster check is the control on that path. Keep the paragraph.

**Acceptance criteria**
- `agents/orchestrator.md` contains a sentence naming both mechanisms in
  contrast — assert both tokens co-occur within the section:
  `grep -c 'SendMessage' <section>` ≥ 1 and `grep -c 'Agent' <section>` ≥ 1
  in the same passage that carries the roster rule.
- The roster rule survives: `grep -c 'roster' agents/orchestrator.md` ≥ 1.
- The auto-suffix residual survives:
  `grep -ci 'auto-suffix\|name-collision' agents/orchestrator.md` ≥ 1.
- `CONTEXT.md` gains an entry distinguishing **dispatch naming** from
  **resume addressing**.
- Version bumped and named in `CHANGELOG.md`.
- `bash tests/validate.sh` exits 0 (also covers adapter-port parity).

## Open Questions

None. The revert premise was verifiable from the codebase and was falsified;
the residual clarity defect is settled by Step 1 without needing a policy
call.

## Self-check

- CHK1: Is the rejection grounded in a verifiable fact rather than a
  preference? — PASS (`SendMessage` has no `name:` to omit; the incident was
  on that path, stated in the orchestrator's own text).
- CHK2: Does the spec still act on the part of the review that was right? —
  PASS (Step 1 fixes the unstated distinction that caused the misreading).
- CHK3: Do Context and Step 1 agree that the paragraph is kept? — PASS (both
  say keep; only a clarifying sentence is added).
- CHK4: Could Step 1's criteria pass while the paragraph was gutted? — FAIL
  (missing) — revised in place: added explicit survival criteria for both the
  roster rule and the auto-suffix residual, so a deletion cannot pass.
- CHK5: Is the P2 deviation justified rather than waved through? — PASS (the
  hook sees no unit id on the `SendMessage` path per ADR-0016, so no script
  control is available).

## Scribe update hint

Add **dispatch naming** (the `Agent` `name:` parameter, omitted by default)
and **resume addressing** (`SendMessage` by name, where omission is
impossible) as distinct `CONTEXT.md` entries. Cross-reference the existing
**gh-304 dual-marker incident** entry so the next reader does not re-derive
the same false equivalence.

## Dispatch contract (fast path — 1 unit)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item14-gh304-roster-check.md`.

### Unit: item14-1-naming-vs-addressing
- **Objective:** State the `Agent`-naming vs `SendMessage`-addressing distinction; keep the roster rule.
- **Retrieval:** Step 1.
- **Affected files:** `agents/orchestrator.md`, regenerated `.claude/agents/orchestrator.md`, `CONTEXT.md`, `.claude-plugin/plugin.json`, `CHANGELOG.md`, adapter ports if applicable.
- **Ordered edits:** add the contrast sentence → verify roster rule and auto-suffix residual survive → glossary entries → regenerate → bump → CHANGELOG.
- **Do NOT touch:** the roster rule itself; the auto-suffix residual paragraph; the unnamed-dispatch default.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** the revert this item was raised to perform is **rejected** — `SendMessage` addresses by name by construction, so the unnamed-dispatch default cannot cover the gh-304 path. Do not delete the paragraph. Adapter ports are hand-maintained, not rendered.
- **Escalation:** if a reviewer or auditor argues for the deletion anyway, point at this spec's Context section rather than re-deriving the analysis.
