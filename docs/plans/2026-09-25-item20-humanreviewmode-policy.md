# Item 20: Should `humanReviewMode` be ON? — standalone policy decision

Status: FINAL (as an Open-Question spec) | Date: 2026-09-25 | Author: spec-master | Item 20 of 19
**Kept standalone rather than folded into item 4**, because items 2, 4, 16 and 19 each depend on its answer. Folding it into item 4 would hide a decision three other specs are waiting on.
Source: Fable adversarial review 2026-09-25, Workflow seam 3
Disposition: **OPEN QUESTION — requires a human decision.** No implementation is specced until it is answered.

## Goal

Put one question to the operator and record the answer durably: is the
human-in-the-loop review layer worth its cost here — turn it on, drop it, or
keep it off but stop paying for it?

This is a "do we want the feature" question, not a bug. It is specced
separately because it **blocks four other items**, and because answering it
wrongly in either direction is expensive.

## Context — the measured situation

Verified 2026-09-25 (the first two independently confirmed by the
orchestrator):

- `.claude/persona-config.json:111` → `"humanReviewMode": "off"`.
- `README` states the feature is *"On by default. The friction is the
  feature."* The repo that dogfoods it has it off.
- `.claude/human-review/` contains **0** packets.
- `.claude/orchestrator-rulings.log` has **1** line.
- `agents/reviewer.md` is 401 source lines; roughly half describe escalation
  machinery — `CHANGES.md` shape, `EXAMPLES.md` before/afters,
  `examples: reviewed|skipped|none-offered`, `via: terminal|dashboard`,
  `verifiedBy` stamping, packet deletion. All of it loads into an **opus**
  context on every review. All of it is inert while the mode is `off`.
- `ADR-0018` turned the mode on; `ADR-0024` turned it off two weeks later.

So the cost is paid on every review and the benefit is currently zero. That
is the whole of the case for acting; the question is which direction.

**One correction to the review's framing.** It proposes moving the escalation
prose *"to an optional persona-protocol section the
`PROTOCOL_SECTIONS_BY_PERSONA` matrix drops when mode is off; the matrix
already exists at `bin/cli.js:698`."* The matrix does exist and is already
per-persona — but this does **not** work as described, for two verified
reasons:

1. **The escalation prose lives in `agents/reviewer.md`, the persona body —
   not in `templates/persona-protocol.md`.** The matrix trims only the shared
   protocol block. It cannot touch a persona body. Making this work requires
   *first* relocating the prose into the protocol, which is itself a
   substantial change.
2. **No config value affects rendering today.** `grep -n 'humanReviewMode'
   bin/cli.js` returns exactly one hit, line 2486, where it is written as a
   *default value* — never read to decide what gets rendered. Conditional
   loading would be a **new mechanism**, and it would introduce a new
   coupling: persona bodies would become a function of a config value, so
   flipping `humanReviewMode` would require re-running `--update` to
   regenerate them, and would interact with `fileHashes` and the mirror-parity
   assertions.

Neither point kills the idea. Both mean item 4's "use the existing matrix more
aggressively" is not a small change in this direction, and the decision below
should be made knowing that.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Missing

- 2026-09-25 Functional scope: Q Is this a cost problem or a feature-value
  problem? → A (self-resolved): **both, and they must be decided in that
  order.** If the feature is wanted, the cost is a shrink-the-ceremony
  problem; if not, it is a delete problem. Deciding cost first would
  presuppose the answer.
- 2026-09-25 User interaction flow: Q Who is the human in "human review" for a
  solo operator? → A (self-resolved): the operator themself, per ADR-0024's
  stated solo-operator posture. This matters: the feature's value proposition
  is self-imposed friction, which is exactly the kind a solo operator
  switches off — as in fact happened two weeks after ADR-0018.
- 2026-09-25 Edge cases / failure handling: Q If the mode stays off, is the
  escalation path safe to delete outright? → A (self-resolved): **no, not
  outright.** `agents/reviewer.md` states an absent key resolves to
  `critical`, so the shipped default for *other* projects is on. This is a
  plugin distributed to other repos; deleting the path would break them.
  Any "drop it" answer means drop it *from this project's rendered prompt*,
  never from the plugin.
- 2026-09-25 Completion / acceptance signals: Q What counts as this item
  being done? → A (self-resolved): a recorded decision (ADR or
  `persona-config.json` change) plus unblocking of items 2, 4, 16, 19. No
  code change is in scope until the decision lands.

## Risks and dependencies

- **R1. This is a plugin, not just a project.** The escalation path ships to
  other repos where the absent-key default is `critical` (on). Any option
  must distinguish "off in this project" from "removed from the plugin".
  Option C below is the only one that touches the plugin, and it does not
  remove the feature.
- **R2. Conditional rendering is a new coupling.** See Context point 2.
  Persona bodies would depend on config, so a mode flip would need
  `--update`, and would interact with `fileHashes` and mirror parity.
- **R3. Reversal history.** ADR-0018 → ADR-0024 flipped this in two weeks.
  Whatever is chosen should record *what evidence would flip it back*, so the
  next reversal is a measurement rather than a mood.
- **D1. Blocks items 2, 16, 19** (each guards or serves a path with zero live
  traffic while the mode is off) **and shapes item 4** (whether the escalation
  section is a conditional-loading target at all).

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the config value, packet count,
  ruling count and the `cli.js` rendering claim were each measured, and the
  review's matrix proposal was checked and partly corrected.
- P2 "Prefer deterministic scripts over LLM re-derivation": not applicable —
  no derivation is being performed; this is a policy decision.
- P3 "Version-stamp discipline": not applicable — no file is edited by this
  spec.
- P4 "Optional personas degrade gracefully": **load-bearing here** — see R1.
  Any option must preserve correct behaviour for a project that selects a
  reviewer and leaves the key absent.
- P5 "`tests/validate.sh` is the merge gate": not applicable — no change yet.

## The decision (Open Question 1)

**Should `humanReviewMode` be ON in this repo, and if not, should the
escalation ceremony keep loading into every reviewer context?**

Four options, each with its consequence stated:

- **A. Turn it on (`critical`) and shrink the ceremony until it is
  tolerable.** Honours the README's stated posture. Cost: escalation prose
  becomes live, so its ~195 lines are *earned* rather than wasted — but the
  operator now services packets, and ADR-0024 turned this off for a reason
  that has not changed.
- **B. Leave it off; accept the prompt cost as the price of a shipped
  feature.** Zero work, zero risk, status quo. Items 2, 16 and 19 then stay
  deferred indefinitely, and every review keeps paying opus tokens for inert
  prose.
- **C. Leave it off here; make the escalation layer conditionally loaded.**
  The review's proposal. Requires relocating prose from the persona body into
  the protocol **and** building config-driven rendering that does not exist
  (Context point 2, R2). Largest payoff on token cost, largest new coupling,
  and it is the only option that changes the plugin.
- **D. Leave it off here; delete the escalation layer from this project's
  rendered prompt only, without building a general mechanism.** A narrower,
  cruder version of C — a one-project carve-out rather than a feature. Cheaper
  than C and reversible, but it makes this repo's persona files diverge from
  the plugin's, which `fileHashes` and mirror-parity checks will notice.

**Recommended default: A is the honest answer and B is the safe one — and the
recommendation is B, with a deliberate re-evaluation trigger.** The README's
claim should then be corrected to describe the shipped default rather than
this repo's posture, because "On by default. The friction is the feature."
next to `"humanReviewMode": "off"` is the single most quotable inconsistency
an adversarial reader found, and it will be found again. C is attractive on
token math alone but should not be chosen until item 4 has measured how much
of the reviewer prompt it would actually remove; on present evidence that
measurement does not exist.

**Whichever is chosen, record the flip-back evidence** (R3): name the
observation that would justify revisiting — for example a defect reaching a
commit that a human pass would plausibly have caught.

## Open Questions

1. The decision above. **Requires a human decision; nothing else in this spec
   proceeds without it.**
2. **Should the README be corrected regardless of the outcome?** It currently
   describes a posture this repo does not hold. Recommended default: **yes,
   and independently of Option A–D** — the README describes the *plugin's*
   default, which is genuinely `critical`, so the fix is a sentence
   distinguishing the shipped default from this repo's setting, not a reversal.
   This is the one piece of item 20 that is safe to action immediately, and it
   is specced as Step 1 below.

## Step 1 — Correct the README's default-vs-local-setting ambiguity

**Affected files:** `README.md`. *(Independent of the Option A–D decision;
may be dispatched immediately.)*

Distinguish the plugin's shipped default (`critical` when the key is absent)
from this project's own setting, without asserting which posture is right.

**Acceptance criteria**
- `README.md` states the shipped default and notes that a project may set
  `humanReviewMode` explicitly; both facts present in the same section:
  `grep -c 'humanReviewMode' README.md` ≥ 1.
- The README no longer asserts, unqualified, that the feature is on in this
  repo: no sentence claims an on-state without naming it as the *default for
  a new project*.
- The claim matches reality: the documented default equals the value
  `bin/cli.js:2486` writes (`critical`) — assert by comparing the README's
  stated default against that line's value.
- `bash tests/validate.sh` exits 0.

## Self-check

- CHK1: Does the spec present options without silently picking one? — PASS
  (four options, consequences each, an explicit recommendation, and the
  decision left open).
- CHK2: Is the review's matrix proposal repeated uncritically? — PASS
  (corrected on two verified points: prose location and absent config-driven
  rendering).
- CHK3: Does any option risk breaking other projects using the plugin? — PASS
  (R1 states it; every option is scoped to "off in this project" vs "removed
  from the plugin", and none removes the feature).
- CHK4: Is there anything actionable now, or is the whole spec blocked? —
  FAIL (missing) — revised in place: added Step 1, the README correction,
  which is independent of the decision.
- CHK5: Are the dependent items named so they are not silently stalled? —
  PASS (D1 names items 2, 4, 16, 19).
- CHK6: Does the spec record what would reverse the decision? — PASS (R3 and
  the closing instruction require flip-back evidence to be named).

## Scribe update hint

Once the decision lands, record it as an ADR amending or superseding
ADR-0024, and add/refresh a **humanReviewMode** glossary entry stating the
shipped default, this project's setting, and the flip-back evidence. Do not
let the glossary repeat the README's current ambiguity.

## Dispatch contract (fast path — 1 unit now; remainder blocked on the decision)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item20-humanreviewmode-policy.md`.

### Unit: item20-1-readme-default-clarification
- **Objective:** Distinguish the plugin's shipped default from this repo's setting.
- **Retrieval:** Step 1.
- **Affected files:** `README.md`.
- **Ordered edits:** locate the on-by-default claim → state the shipped default (`critical` when absent) → note a project may set it explicitly → verify against `bin/cli.js:2486`.
- **Do NOT touch:** `.claude/persona-config.json`; `agents/reviewer.md`; any escalation prose. The Option A–D decision is NOT made by this unit.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** `.claude/persona-config.json:111` = `"humanReviewMode": "off"`; `bin/cli.js:2486` writes `critical` as the default; `agents/reviewer.md` states an absent key resolves to `critical`. 0 packets in `.claude/human-review/`; 1 line in `orchestrator-rulings.log`.
- **Escalation:** if correcting the README appears to require taking a position on Option A–D, stop and report — that decision is the operator's.
