# Item 03: Split `CONTEXT.md` into a domain glossary and a harness glossary

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 3 of 19
Source: Fable adversarial review 2026-09-25, Token/cost overhead #1
Disposition: **ACCEPT — split.** Sizes independently re-measured and the review's structural claim holds.

## Goal

Reduce the fixed per-run cost of `CONTEXT.md` by separating domain vocabulary
from harness-mechanics vocabulary, so `ubiquitous-language` and `scribe` load
only what they need.

## Context

Measured 2026-09-25:

- `CONTEXT.md` is **221,639 bytes** (~55K tokens) and defines **234** terms.
- Its structure is a single `## Language` section; every term is a
  `**term**:` bold entry. There are no per-category headings at all, which is
  why nothing can currently be loaded selectively.
- A keyword sweep for harness-mechanics vocabulary (gate, marker, stamp,
  hook, seal, audit, flag, dispatch, sentinel, watermark, override, bundle,
  review-join, packet, Set A/B, path, mode, record) matches **60** term
  names. The review said 47; the difference is keyword breadth, not a
  contradiction — which is precisely why the split must be defined by an
  explicit, reviewable classification rather than a regex.
- Representative harness entries: `asked audit record`, `completed audit
  record`, `advisory review-join stamp`, `marker-out-of-scope`, `Marker
  classifier states`, `hook block event`, `Reviewer-gate ratchet`. The
  `ask-eligible` entry alone runs ~20 lines describing a 5-path subset of one
  hook's allowlist.

Two consumers pay this on every run: `spec-master` and `reviewer` read it via
`ubiquitous-language` (once per session), and `scribe` reads and edits it.
`scribe` runs on **haiku** with a small prompt and then loads a 221 KB file —
the file dominates that persona's cost entirely.

**The split is load-bearing for correctness too, not just cost.** The
`ubiquitous-language` skill's three lenses compare a diff or a draft against
"the canonical glossary". With harness internals in the same file, a lens-3
finding ("a load-bearing new domain term with no glossary entry") competes
with 60 mechanics entries for attention, and the skill's advisory output gets
noisier the more the harness documents itself.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-25 Domain entities / data model: Q What is the classification rule
  between "domain" and "harness"? → A (self-resolved): a term is **harness**
  if understanding it requires knowing this repo's hooks, markers, gates or
  dispatch plumbing; **domain** if it describes the persona system's concepts
  as a user of the plugin would meet them. The boundary is judgment, so
  Step 1 requires an explicit per-term classification list that a reviewer can
  check, not a regex.
- 2026-09-25 Edge cases / failure handling: Q What happens to cross-references
  (`[[term]]`) that cross the split? → A (self-resolved): they must keep
  resolving. Step 2 asserts every `[[link]]` resolves to an entry in one of
  the two files — a dangling link is the predictable failure mode of any
  split and is the single most likely cause of a FAIL here.
- 2026-09-25 Technical constraints & tradeoffs: Q Should `CONTEXT.md` keep its
  name? → A (self-resolved): **yes.** `CONTEXT.md` is the name the
  `domain-modeling` and `ubiquitous-language` skills look for, and both are
  vendored from an upstream project. Renaming it would deviate a vendored
  skill; the harness file takes the new name instead.
- 2026-09-25 Terminology consistency: Q Does "glossary" now mean one file or
  two? → A (self-resolved): two, and they need distinct names —
  **domain glossary** (`CONTEXT.md`) and **harness glossary**
  (`docs/harness-glossary.md`). Both need entries in the domain glossary.

## Risks and dependencies

- **R1. Dangling cross-references.** Entries link with `[[name]]`. Splitting
  will separate linked pairs. Step 2's link check is mandatory and must be
  proven non-vacuous.
- **R2. Vendored-skill constraint.** `ubiquitous-language` and
  `domain-modeling` are vendored from `mattpocock/skills`; `domain-modeling`
  names `CONTEXT.md` explicitly. Per ADR-0012 (declared deviations), any
  change to a vendored skill must be recorded as a declared deviation rather
  than silently edited.
- **R3. `scribe` custody.** `scribe` owns `CONTEXT.md`. After the split it
  owns two files, and its persona file must say so or entries will land in
  the wrong one.
- **R4. Classification disputes are not defects.** A reviewer may disagree
  with individual placements. The acceptance criteria therefore check
  completeness and link integrity — properties that are objectively
  checkable — not placement taste.
- **R5. Version-stamp discipline** applies to Step 3 (`agents/scribe.md` is
  version-stamped) and to any skill edit under `skills/`.
- **R6.** No prior `.fail` record known (new work); marker sweep Bash-gated.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — byte count, term count, file
  structure and classification breadth all re-measured; the review's 47 was
  checked rather than copied.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  Step 2 adds a mechanical link/completeness check rather than trusting the
  split was done correctly.
- P3 "Version-stamp discipline": **applies** to Step 3 — see R5.
- P4 "Optional personas degrade gracefully": satisfied — a project without
  `scribe` must still work; the harness glossary is additive and its absence
  must not break `ubiquitous-language` (which already degrades when no
  glossary exists).
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Classify and split

**Affected files:** `CONTEXT.md`; `docs/harness-glossary.md` (new).

Move harness-mechanics entries out. Produce the classification as a
reviewable artifact, not an implicit outcome.

**Acceptance criteria**
- Term conservation is exact: (terms in `CONTEXT.md` after) + (terms in
  `docs/harness-glossary.md`) equals **234**, counted with the same pattern
  used to measure it (`grep -cE '^\*\*[^*]+\*\*'`). No term is lost or
  duplicated — assert the union has no duplicate term names.
- `CONTEXT.md` is **under 60,000 bytes** after the split. (The review
  proposed ≤20 KB / ≤40 terms; that is not achievable without deleting
  domain content, since 174 terms remain even if all 60 harness-keyword
  matches move. This criterion targets the achievable reduction and is
  deliberately looser than the review's figure.)
- `docs/harness-glossary.md` opens with a one-line statement of what belongs
  in it, so future entries route correctly.
- The classification list is recorded in the ready-for-review report: every
  moved term, named.
- `bash tests/validate.sh` exits 0.

## Step 2 — Guard link integrity and completeness

**Affected files:** `tests/validate.sh` or a new registered test.

**Acceptance criteria**
- Every `[[link]]` in either file resolves to a defined term in one of the
  two files; the check fails naming the dangling link otherwise.
- Non-vacuity by mutation: introduce a `[[deliberately-missing-term]]`,
  confirm the check **fails** and names it, revert, confirm it passes. Record
  both observations in the report.
- The check also fails if a term is defined in **both** files.
- Degrades gracefully (P4): with `docs/harness-glossary.md` absent, the check
  exits 0 rather than erroring — assert by temporarily moving it aside.
- `bash tests/validate.sh` exits 0.

## Step 3 — Repoint the consumers

**Affected files:** `skills/ubiquitous-language/SKILL.md` (declared deviation
per ADR-0012 if the vendored text changes); `agents/scribe.md`;
`agents/spec-master.md` and `agents/reviewer.md` where they name the glossary;
regenerated `.claude/` copies; `.claude-plugin/plugin.json`; `CHANGELOG.md`.

`ubiquitous-language` points at the domain glossary. `scribe` gains explicit
custody of both files and a rule for which entry goes where.

**Acceptance criteria**
- `agents/scribe.md` names both files:
  `grep -c 'harness-glossary' agents/scribe.md` ≥ 1 and
  `grep -c 'CONTEXT.md' agents/scribe.md` ≥ 1.
- Every persona or skill that previously named `CONTEXT.md` as *the* glossary
  now either points at the domain glossary or names both — assert per-file,
  not in aggregate, so a missed surface cannot hide behind a passing total.
- If `skills/ubiquitous-language/SKILL.md` diverges from its vendored
  upstream, the deviation is declared per ADR-0012:
  `grep -c 'deviation' <file or the deviations register>` ≥ 1.
- Version bumped beyond `HEAD` and named in `CHANGELOG.md`.
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **Should `scribe` additionally maintain a `CONTEXT.index.md` (term → one
   line), loading only the index and fetching full entries on demand?** This
   is the review's Alt B, and it composes with the split rather than
   competing: even a 60 KB domain glossary is large for a haiku persona.
   Recommended default: **defer to a follow-up spec and measure first** — the
   split's own reduction should be observed before adding an index that must
   itself be kept in sync (a new drift surface, and this repo has a
   documented history of hand-synced copies drifting). Not blocking.

## Self-check

- CHK1: Is the target size justified rather than copied from the review? —
  PASS (Step 1 explains why ≤20 KB is unachievable and states the achievable
  figure instead).
- CHK2: Is the domain/harness boundary defined well enough to review? — FAIL
  (ambiguous) — revised in place: the Clarifications entry now gives a
  one-sentence test, and Step 1 requires an explicit per-term classification
  list rather than leaving placement implicit.
- CHK3: Are cross-references protected? — PASS (Step 2, with a
  mutate-revert proof).
- CHK4: Could Step 1's conservation criterion pass while terms were silently
  duplicated? — PASS (explicit no-duplicate-names assertion, reinforced by
  Step 2's both-files check).
- CHK5: Is the vendored-skill constraint honoured? — PASS (R2 and Step 3's
  ADR-0012 declared-deviation criterion).
- CHK6: Does the spec avoid renaming the file the vendored skills look for? —
  PASS (`CONTEXT.md` keeps its name; the new file takes the new one).

## Scribe update hint

Add **domain glossary** and **harness glossary** as terms in the domain
glossary, each stating what belongs in it and who owns it. Also add
**`persona-protocol-slim.md`**, which exists in-repo with no glossary entry —
a pre-existing gap this spec's terminology check surfaced, not one it
created.

## Dispatch contract (fast path — 3 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item03-context-glossary-split.md`.
Order: Step 1 → Step 2 → Step 3.

### Unit: item03-1-classify-and-split
- **Objective:** Split the glossary into domain and harness files.
- **Retrieval:** Step 1.
- **Affected files:** `CONTEXT.md`, `docs/harness-glossary.md` (new).
- **Ordered edits:** classify every term → move harness entries → record the classification list → verify conservation.
- **Do NOT touch:** term *content* (this is a move, not a rewrite); `CONTEXT.md`'s filename.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** 234 terms, 221,639 bytes, single `## Language` section, `**term**:` entry format (measured 2026-09-25). A keyword sweep matches 60 harness-ish names; the review said 47 — use explicit classification, not a regex.
- **Escalation:** if a term is genuinely both (e.g. one a plugin user meets *and* a hook implements), report it with your proposed placement rather than splitting the entry.

### Unit: item03-2-link-integrity-guard
- **Objective:** Prevent dangling or duplicated glossary links.
- **Retrieval:** Step 2.
- **Affected files:** `tests/validate.sh` or a new registered test.
- **Ordered edits:** implement resolve-check across both files → duplicate-definition check → mutate-prove → graceful-degradation check.
- **Do NOT touch:** glossary content.
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** depends on item03-1. Entries cross-link with `[[name]]`; splitting separates linked pairs, so dangling links are the expected failure mode.
- **Escalation:** if pre-existing dangling links exist *before* the split, report the count and fix them as part of this unit rather than grandfathering them.

### Unit: item03-3-repoint-consumers
- **Objective:** Point `ubiquitous-language` and `scribe` at the right files.
- **Retrieval:** Step 3.
- **Affected files:** `skills/ubiquitous-language/SKILL.md`, `agents/scribe.md`, `agents/spec-master.md`, `agents/reviewer.md`, regenerated `.claude/` copies, `.claude-plugin/plugin.json`, `CHANGELOG.md`.
- **Ordered edits:** enumerate every surface naming the glossary → repoint each → declare any vendored deviation per ADR-0012 → regenerate → bump → CHANGELOG.
- **Do NOT touch:** the vendored skills' unrelated text.
- **Acceptance criteria:** as Step 3.
- **Pre-resolved context:** depends on item03-1. `domain-modeling` and `ubiquitous-language` are vendored from `mattpocock/skills`; ADR-0012 governs declared deviations. Version-stamped files are touched, so P3 applies — two prior units FAILed for omitting the bump.
- **Escalation:** if repointing requires changing vendored text beyond a declared deviation's scope, report before editing.
