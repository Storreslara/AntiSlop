# Item 01: Hook-authored markers — feasibility probe before redesign

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 1 of 19
Source: Fable adversarial review 2026-09-25, Gating Complaint 1 Alt A + "three things" #1
Disposition: **DEFER pending probe** — the proposal's central premise is unverified and contradicted by this repo's own measured ADR.

## Goal

Decide on measured evidence whether hook-authored markers (`stop-gate.sh`
parses the reviewer's final message on `SubagentStop` and writes
`.pass`/`.fail`/`.blocked` itself) is implementable **at all** here. This spec
does not implement the redesign; it settles the premise that the redesign
requires.

## Context

The review proposes deleting `reviewed-path-gate.sh` (299 lines),
`lib/benign-command.sh` (233), `marker-write.sh`, the v3 printf ceremony, the
review-join stamp stack, and a large bypass-test corpus. Its stated mechanism:
*"the payload also carries a transcript path."*

**That premise is unverified here and contradicted by measurement:**

- `grep -rn 'transcript' hooks/scripts/` returns **zero** occurrences
  (measured 2026-09-25). No hook in this repo has ever read a transcript.
- [ADR-0016](../adr/0016-per-unit-review-join.md) § Problem enumerates the
  payload, written from measurement for exactly this question: *"the
  `SubagentStop` payload carries `agent_type`, `agent_id` and `session_id`,
  but not unit id or prompt."* `transcript_path` is absent from that list.
- ADR-0016 concludes: *"Any per-unit join must be established at dispatch
  time, not at stop time."* The stamp stack exists **because** of this.

`stop-gate.sh:144-147` confirms the fields actually parsed:
`hook_event_name`, `agent_type`, `session_id`, `agent_id`. Nothing else.

If the probe returns viable, ADR-0016's premise is partly wrong and a large
simplification genuinely opens. If not, the stamp stack is load-bearing and
this item — plus item 10's "revert the chain" — closes permanently. Both
answers are cheap and decisive.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Missing
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-25 External dependencies & integrations: Q Does `SubagentStop`
  expose a transcript path in the installed harness? → A (self-resolved):
  **unknown, and that is the finding** — zero hook references, ADR-0016's
  measured enumeration omits it. Becomes Step 1 rather than an assumption.
- 2026-09-25 Non-functional attributes: Q Is the coupling risk acceptable? →
  A (self-resolved): unanswerable before Step 1; a documented field and an
  internal format carry very different risk. Deferred to Open Question 1.
- 2026-09-25 Edge cases / failure handling: Q What if the probe is
  inconclusive? → A (self-resolved): `unknown` is an explicit permitted
  outcome that keeps the status quo and closes this spec. A probe may fail to
  conclude; it may not guess.
- 2026-09-25 Technical constraints & tradeoffs: Q Would hook-authored markers
  fail loudly or silently if the format changed? → A (self-resolved):
  **silently** — markers would simply stop being written, and the
  pending-review flag would clear with no verdict recorded. This asymmetry is
  the core of Open Question 1.

## Risks and dependencies

- **R1.** A `viable` result invalidates part of ADR-0016 and transitively
  ADR-0028; Step 3 must say so rather than quietly noting it.
- **R2.** Hook primitives were last measured against Claude Code **2.1.281**
  (`claude-code-hook-and-effort-primitives` memory note), which itself says
  re-probe on a newer version. Step 1 must record the version measured.
- **R3.** Scope discipline: Steps 1–2 must not edit gate logic. "Just trying
  it" is the main failure mode.
- **R4.** No prior `.fail` record known (new work). The `.claude/reviewed/`
  sweep could not be run from this persona via Bash — it is gated, reproduced
  live 2026-09-25. Treat as unverified, not proven-clean.
- **D1.** Step 3 depends on Steps 1 and 2.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — this spec exists because the premise
  was assumed; Step 1 verifies it.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — a
  binary/payload probe, not a model opinion.
- P3 "Version-stamp discipline": deviation — no version-stamped file
  (`agents/*.md`, templates) is touched; if an implementer's diff reaches one,
  P3 re-applies.
- P4 "Optional personas degrade gracefully": satisfied — no persona reference
  changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied — Step 2 runs it.

## Step 1 — Probe the installed harness for a stop-time transcript

**Affected files:** `docs/research/2026-09-25-subagent-stop-payload-probe.md`
(new). Nothing else modified.

`strings`-probe the versioned binary and its docs for a transcript path or any
field carrying a subagent's final message, using the technique recorded in the
`claude-code-hook-and-effort-primitives` memory note.

**Acceptance criteria**
- `test -f docs/research/2026-09-25-subagent-stop-payload-probe.md` exits 0.
- Line 1 matches `^probed-version: [0-9]+\.[0-9]+\.[0-9]+$`, and that version
  equals `claude --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'`.
- Exactly one line matches
  `^transcript-field: (present|absent|inconclusive)$`.
- A `## Payload fields` heading lists every `SubagentStop` field found, one
  per line.
- `grep -c 'ADR-0016' <file>` ≥ 1 — the probe must state whether it confirms
  or contradicts ADR-0016's enumeration.

## Step 2 — Capture one real payload (empirical confirmation)

**Affected files:** temporary hook instrumentation, **reverted**; appends to
the Step 1 document.

Static probing can miss a field. Instrument a `SubagentStop` hook to dump raw
JSON to the session scratchpad, dispatch a trivial subagent, capture, revert.

**Acceptance criteria**
- The captured file is valid JSON (`jq -e . <file>` exits 0).
- The Step 1 document gains `## Observed payload keys`, and those keys are a
  superset of `agent_type`, `agent_id`, `session_id` — if these three are
  absent the capture is not a `SubagentStop` and is void.
- `git status --porcelain hooks/ .claude/hooks/` produces **no output**.
- `bash tests/validate.sh` exits 0.

## Step 3 — Record the feasibility verdict as an ADR

**Affected files:** one new `docs/adr/` file — re-derive the number at
execution time as `max(existing)+1`; **never** backfill the 0007 hole, which
`CONTEXT.md` links.

Exactly one verdict:
- `viable` — a usable field exists; ADR-0016's dispatch-time-join premise is
  superseded in part; the redesign becomes specifiable. **Does not authorize
  the redesign.**
- `not-viable` — no such field; the review's Complaint 1 Alt A, Complaint 3
  Alt B and "three things" #1 close as not-implementable, and the review-join
  stamp stack is load-bearing. This also settles item 10.
- `unknown` — inconclusive; status quo stands; re-probe on next upgrade.

**Acceptance criteria**
- The ADR exists and `bash tests/validate.sh` exits 0.
- `grep -cE '^feasibility: (viable|not-viable|unknown)$' <file>` equals **1**.
- `grep -c '2026-09-25-subagent-stop-payload-probe' <file>` ≥ 1.
- `grep -c 'ADR-0016' <file>` ≥ 1.
- If and only if the verdict is `not-viable`, the file contains
  `review-join stamp stack: load-bearing`.

## Open Questions

1. **Even if viable, is hook-authored marker writing worth its coupling
   risk?** Trade: delete ~1,180 lines of gate code plus a large bypass corpus,
   against coupling marker correctness to a possibly-undocumented transcript
   format whose breakage is **silent** (no marker written, flag clears, no
   verdict recorded) rather than loud. Recommended default: **do not adopt
   wholesale even if viable.** Take the narrower win — let the hook
   *validate* the reviewer's marker against the transcript rather than
   *author* it. That captures most of the integrity benefit, keeps the
   reviewer as writer, and degrades safely if the format changes. Requires a
   human decision.

## Self-check

- CHK1: Does Step 1 have a machine-checkable pass/fail even though its result
  is unknown by design? — PASS (criteria check document shape and
  version-agreement, never the conclusion).
- CHK2: Do Steps 1 and 3 agree on the verdict vocabulary? — PASS
  (deliberately different: `present|absent|inconclusive` is a field-level
  observation, `viable|not-viable|unknown` a design verdict derived from it).
- CHK3: Does the spec anywhere authorize the redesign? — PASS (Step 3 states
  a `viable` verdict does not).
- CHK4: Is the coupling tradeoff decided silently? — FAIL (missing) —
  converted to Open Question 1.
- CHK5: Does Step 2 guarantee no instrumentation is left behind? — PASS
  (empty `git status --porcelain` is an acceptance criterion).

## Scribe update hint

Add a **hook-authored marker** glossary entry carrying the feasibility
verdict. If `not-viable`, amend **review-join stamp** to record that the
stack is load-bearing by measurement, so this proposal is not re-raised.

## Dispatch contract (fast path — 3 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item01-hook-authored-markers.md`.

### Unit: item01-1-payload-probe
- **Objective:** Determine whether `SubagentStop` exposes a transcript/final-message field.
- **Retrieval:** Step 1.
- **Affected files:** `docs/research/2026-09-25-subagent-stop-payload-probe.md` (new only).
- **Ordered edits:** probe binary → record version → enumerate fields → state `transcript-field:` → relate to ADR-0016.
- **Do NOT touch:** anything under `hooks/`, `agents/`, `templates/`.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** `grep -rn 'transcript' hooks/scripts/` = 0 (measured). `stop-gate.sh:144-147` parses only `hook_event_name`, `agent_type`, `session_id`, `agent_id`. Probe technique in memory note `claude-code-hook-and-effort-primitives` (measured against 2.1.281).
- **Escalation:** if the binary cannot be probed, record `inconclusive` and hand back — do not guess.

### Unit: item01-2-payload-capture
- **Objective:** Empirically capture one real `SubagentStop` payload.
- **Retrieval:** Step 2.
- **Affected files:** temporary instrumentation (reverted); appends to Step 1 doc.
- **Ordered edits:** instrument → dispatch trivial subagent → capture → **revert** → append observed keys.
- **Do NOT touch:** gate logic, marker code, any marker-directory path.
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** depends on item01-1. Reverting is itself a criterion.
- **Escalation:** if instrumenting trips a harness gate, **report and wait** — do not rephrase to evade (shared protocol, "Blocked by a gate you do not own").

### Unit: item01-3-feasibility-adr
- **Objective:** Record the verdict as an ADR.
- **Retrieval:** Step 3.
- **Affected files:** one new `docs/adr/` file.
- **Ordered edits:** re-derive ADR number → write verdict → state ADR-0016 disposition.
- **Do NOT touch:** ADR-0016 itself (amendment is follow-up work).
- **Acceptance criteria:** as Step 3.
- **Pre-resolved context:** depends on item01-1 and item01-2. Increment ADR number from max; never backfill 0007.
- **Escalation:** if Steps 1 and 2 disagree, record `unknown`.
