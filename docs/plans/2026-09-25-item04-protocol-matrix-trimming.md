# Item 04: Use `PROTOCOL_SECTIONS_BY_PERSONA` more aggressively

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 4 of 19
Source: Fable adversarial review 2026-09-25, Token/cost overhead #2 + "three things" #2
Disposition: **ACCEPT the trimming; REJECT the "drop escalation when mode is off" sub-proposal as described** — it targets prose the matrix structurally cannot reach.

## Goal

Reduce per-persona inlined protocol size using the existing matrix, and
record precisely why the conditional-loading half of the proposal is not a
small change.

## Context

Measured 2026-09-25.

**The matrix exists and is already per-persona.** `bin/cli.js:698`,
`PROTOCOL_SECTIONS_BY_PERSONA`, keys each full-tier persona to explicit
`include` and `drop` lists over the canonical section headers, on top of a
shared `UNIVERSAL_PROTOCOL_CORE` of 6 sections. `lead-programmer` already
drops 4 sections; `orchestrator` already drops 5, including
`Fourth verdict: escalate-to-human`.

**Two load-bearing guards constrain how far trimming can go**, and the review
does not account for either:

- `assertProtocolMatrixComplete` — every row must exhaustively classify the
  canonical section list, so adding a section forces a decision for every
  persona.
- `assertNoDanglingCrossReferences` — throws if a *kept* section's text
  references a *dropped* one. This is the real limiter: dropping a section is
  only free if nothing retained refers to it. So "cut lead-programmer to ~60
  lines" is not a matrix edit; it requires rewriting retained sections to be
  self-contained first.

**A second tier already exists.** `templates/persona-protocol-slim.md` (90
lines) is delivered to `explorer`, `researcher` and `scribe` in place of the
685-line full protocol. So the two-tier idea is built and shipping; what the
review is really asking for is either a third tier or a re-tiering.

Current inlined deltas (source `agents/` → adapted `.claude/agents/`):
orchestrator 612→921, reviewer 401→721, lead-programmer 76→457, spec-master
260→556, task-master 153→425, milestone-auditor 87→350. The
`lead-programmer` ratio is the most lopsided: 76 source lines carrying 381
inlined.

**Why the escalation sub-proposal fails as described.** The review proposes
the matrix drop the escalation section when `humanReviewMode` is off. Two
verified obstacles:

1. **The bulk of the escalation prose is in `agents/reviewer.md`, the persona
   body — not in `templates/persona-protocol.md`.** `reviewer.md` is a flat
   bullet list with no section headings, and its escalation content is
   interleaved with its marker-writing bullets rather than sitting in a
   separable block. The matrix trims only the shared protocol; it cannot
   reach a persona body, and it could not cleanly excise this even if it
   could.
2. **No config value affects rendering today.** `grep -n 'humanReviewMode'
   bin/cli.js` returns exactly one hit — line 2486, a *default value*, never
   read to decide rendering. Conditional loading is a new mechanism, and it
   would make persona bodies a function of config: flipping the mode would
   require re-running `--update`, and would interact with `fileHashes` and
   mirror-parity assertions.

So the unconditional trimming is real and available now; the conditional half
depends on **item 20**'s decision and, if pursued, on relocating prose first.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-25 Technical constraints & tradeoffs: Q Can the matrix drop the
  escalation section as proposed? → A (self-resolved): **not usefully** — the
  bulk of that prose is in the persona body, which the matrix cannot reach.
  Recorded rather than attempted.
- 2026-09-25 External dependencies & integrations: Q Does any config value
  drive rendering? → A (self-resolved): **no** — one hit in `cli.js`, a
  default value only. Conditional loading would be new machinery.
- 2026-09-25 Edge cases / failure handling: Q What stops a drop from breaking
  a retained cross-reference? → A (self-resolved): `assertNoDanglingCross-
  References` throws at load. It is a guard, not an obstacle — but it means
  each drop must be paired with making retained text self-contained.
- 2026-09-25 Terminology consistency: Q Is there a name for the
  full-vs-slim delivery tiers? → A (self-resolved): **no glossary entry
  exists** for `persona-protocol-slim.md` or for "protocol tier". Needed, since
  this spec reasons about re-tiering.
- 2026-09-25 Non-functional attributes: Q How much reduction is achievable? →
  A (self-resolved): unknown until measured per persona; the review's
  "40-60%" is an estimate over both this item and item 3 combined. Step 1
  measures rather than asserts.

## Risks and dependencies

- **R1. A drop that breaks a cross-reference fails loudly at load** — good,
  but it means trimming is iterative. Budget for rewriting retained sections.
- **R2. Dropping a section a persona actually relies on is a silent
  behavioural regression.** The protocol carries real rules (WIP sentinel,
  status line, no-self-wake, gate doctrine). A persona that stops being told
  a rule will break it. Every drop needs a stated justification, not just a
  token saving.
- **R3. Version-stamp discipline applies** — persona bodies and templates are
  version-stamped. Bump + CHANGELOG.
- **R4. Mirror/hash interaction.** Regenerated persona bodies interact with
  `fileHashes` and `validate.sh`'s parity assertions; per
  `validate-sh-is-a-mirror-parity-check` a direct hash check must
  `stripStamp`. Prefer `validate.sh`.
- **R5.** No prior `.fail` record known (new work); marker sweep Bash-gated.
- **D1.** The conditional-loading half is blocked on **item 20**.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — matrix structure, guards, slim tier,
  deltas and the config-rendering claim all measured; the review's proposal
  corrected on two points.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — the
  matrix is the deterministic mechanism; this spec uses it rather than
  hand-editing rendered files.
- P3 "Version-stamp discipline": **applies** — see R3.
- P4 "Optional personas degrade gracefully": satisfied — matrix rows must
  remain exhaustive for every persona, selected or not.
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Measure the per-persona protocol footprint

**Affected files:** none modified; findings recorded in the report.

For each full-tier persona, report the inlined line count, the sections
included, and — for each included section — whether the persona has a stated
need for it (a rule it must follow) or carries it only by default.

**Acceptance criteria**
- The report names, per persona, every included section and classifies it
  `needed` or `candidate-for-drop`, with a one-line justification each.
- It states the achievable reduction per persona as a line count, replacing
  the review's estimate with a measurement.
- `git status --porcelain` is empty.

## Step 2 — Apply the justified drops

**Affected files:** `bin/cli.js` (`PROTOCOL_SECTIONS_BY_PERSONA` rows);
possibly `templates/persona-protocol.md` (to make retained sections
self-contained); regenerated `.claude/agents/*.md`;
`.claude-plugin/plugin.json`; `CHANGELOG.md`.

Apply only the drops Step 1 justified.

**Acceptance criteria**
- `node bin/cli.js` loads without throwing — this is the
  `assertProtocolMatrixComplete` / `assertNoDanglingCrossReferences` gate and
  must pass, not be worked around.
- Every persona's inlined line count is **≤** its Step 1 measurement, and at
  least one persona's is strictly lower (proving the change had an effect).
- No `UNIVERSAL_PROTOCOL_CORE` section is dropped for any persona — assert
  explicitly; these are the rules every persona must carry.
- Behavioural rules survive where needed: for each persona retaining a rule
  per Step 1's classification, the regenerated body still contains it —
  assert per persona, not in aggregate.
- Version bumped beyond `HEAD` and named in `CHANGELOG.md`.
- `bash tests/validate.sh` exits 0.

## Step 3 — Record the protocol-tier vocabulary

**Affected files:** `CONTEXT.md` (or `docs/harness-glossary.md` if item 3 has
landed — coordinate; do not create a duplicate entry).

**Acceptance criteria**
- Entries exist for the full protocol tier, the slim tier
  (`persona-protocol-slim.md`), and which personas receive each.
- The entry is in exactly **one** glossary file, not both.
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **Should conditional, config-driven protocol rendering be built?** Blocked
   on **item 20**. If item 20 chooses Option C, this becomes a real spec of
   its own — relocate escalation prose from `agents/reviewer.md` into the
   protocol, *then* make rendering config-aware. Recommended default:
   **do not build it speculatively.** The unconditional trimming in Steps 1–2
   delivers measurable savings with no new coupling; the conditional half
   adds a config→rendering dependency that makes a mode flip require
   `--update`. Requires item 20's decision first.
2. **Should `lead-programmer` move to the slim tier instead of a trimmed full
   tier?** Its 76→457 ratio is the worst in the repo, and a third option
   exists that the review did not consider: deliver it the slim protocol plus
   a few full-tier sections. Recommended default: **decide from Step 1's
   measurement** — if its `needed` set is close to the slim tier's contents,
   re-tiering is cleaner than trimming. Not blocking; Step 1 produces the
   evidence.

## Self-check

- CHK1: Does the spec repeat the review's matrix claim uncritically? — PASS
  (corrected on prose location and absent config-driven rendering).
- CHK2: Is there a guard against dropping a section a persona needs? — PASS
  (R2, Step 1's per-section classification, and Step 2's per-persona survival
  criterion).
- CHK3: Could Step 2 pass without actually reducing anything? — FAIL
  (missing) — revised in place: added "at least one persona's count is
  strictly lower".
- CHK4: Is the `assertNoDanglingCrossReferences` guard treated as an obstacle
  to route around? — PASS (Step 2 requires `node bin/cli.js` to load, and the
  spec states the guard must pass rather than be worked around).
- CHK5: Is the escalation sub-proposal silently dropped? — PASS (explicitly
  rejected as described, with reasons, and re-opened as Open Question 1 under
  item 20).
- CHK6: Do Steps 3 and item 3 risk duplicate glossary entries? — PASS
  (Step 3 requires exactly one file and names the coordination).

## Scribe update hint

Add **protocol tier** (full vs slim), name which personas receive each, and
record that `PROTOCOL_SECTIONS_BY_PERSONA` trims the full tier per persona
under two load-bearing assertions. `persona-protocol-slim.md` currently has
no glossary entry at all.

## Dispatch contract (fast path — 3 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item04-protocol-matrix-trimming.md`.
Order: Step 1 → Step 2 → Step 3.

### Unit: item04-1-measure-footprint
- **Objective:** Measure and classify each persona's protocol sections.
- **Retrieval:** Step 1.
- **Affected files:** none (measurement only).
- **Ordered edits:** enumerate matrix rows → per section, classify `needed` / `candidate-for-drop` with justification → state achievable reduction.
- **Do NOT touch:** `bin/cli.js`, templates, persona files.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** matrix at `bin/cli.js:698`; `UNIVERSAL_PROTOCOL_CORE` has 6 sections; guards are `assertProtocolMatrixComplete` and `assertNoDanglingCrossReferences`. Inlined deltas: orchestrator 612→921, reviewer 401→721, lead-programmer 76→457, spec-master 260→556, task-master 153→425, milestone-auditor 87→350. A slim tier already exists at `templates/persona-protocol-slim.md` (90 lines, for explorer/researcher/scribe).
- **Escalation:** if a section's necessity is genuinely unclear for a persona, classify it `needed` and say why — the safe direction is to keep.

### Unit: item04-2-apply-drops
- **Objective:** Apply only the justified drops.
- **Retrieval:** Step 2.
- **Affected files:** `bin/cli.js` matrix rows, possibly `templates/persona-protocol.md`, regenerated `.claude/agents/*.md`, `.claude-plugin/plugin.json`, `CHANGELOG.md`.
- **Ordered edits:** edit rows → make retained sections self-contained where a cross-reference breaks → regenerate → verify per-persona rule survival → bump → CHANGELOG.
- **Do NOT touch:** any `UNIVERSAL_PROTOCOL_CORE` section; the slim template.
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** depends on item04-1. `assertNoDanglingCrossReferences` throws when a kept section references a dropped one — expect iteration. Never hand-edit `.claude/agents/`; regenerate.
- **Escalation:** if making a retained section self-contained would change a rule's meaning, report rather than rewording the rule.

### Unit: item04-3-protocol-tier-glossary
- **Objective:** Record the full/slim tier vocabulary.
- **Retrieval:** Step 3.
- **Affected files:** `CONTEXT.md` or `docs/harness-glossary.md` (exactly one).
- **Ordered edits:** check whether item 3 has landed → write entries in the correct single file.
- **Do NOT touch:** the other glossary file.
- **Acceptance criteria:** as Step 3.
- **Pre-resolved context:** `persona-protocol-slim.md` has no glossary entry today (measured). If item 3 has landed, this is harness-glossary content.
- **Escalation:** if both glossary files already carry a tier entry, report the duplication rather than choosing one silently.
