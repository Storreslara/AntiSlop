# Efficiency audit remediation — Pass 1 (F1, F2, F3)

Date: 2026-08-01
Status: Finalized spec, ready for `task-master` slicing
Amended: 2026-08-01 (A1, mid-flight — see **Amendment A1** at the end; it
replaces two of *Step 2*'s acceptance criteria and two of *Step 9*'s. Execute
those two steps from A1, not from the criteria printed under the steps
themselves.)
Amended: 2026-08-01 (A2, mid-flight — see **Amendment A2** at the end; it
replaces *Step 3*'s acceptance criteria 1–4, corrects its affected-files list,
and rules on the fix shape. Execute Step 3 from A2, not from the criteria
printed under the step itself.)
Amended: 2026-08-01 (A3, mid-flight — see **Amendment A3** at the end; it is
**additive** to *Step 4*: its six acceptance criteria all stand, A3 appends five
more, resolves the matrix's memory-section contradiction, and rules on a
completeness guard. Read Step 4 together with A3.)
Amended: 2026-08-01 (A4, orchestrator-applied, no spec-master ceremony — see
**Amendment A4** at the end. Corrects Step 4's force-include/drop conflict for
`lead-programmer` and tightens the verification methodology for Steps 5-10.)
Scope: the three Critical findings (F1, F2, F3) of the Fable Pass-1 efficiency
audit. F4–F9, the contradictions list, and the trigger-happiness list are
explicitly deferred — see "Deferred to later passes" at the end.

## Goal

Cut the per-dispatch token cost and the per-turn bookkeeping churn of this
repo's own persona orchestration, without weakening the reviewer gate (the
system's core safety property), by fixing exactly three things:

- **F1** — the shared protocol is physically inlined into all six full-tier
  persona mirrors at full length (2,806 words each) regardless of role, and
  the prose describing *how* it is delivered is stale everywhere it appears.
- **F2** — the reviewer's `sonnet` escape hatch is unreachable in practice, so
  every unit is opus-reviewed regardless of size or risk.
- **F3** — the pending-review `defer:` escape hatch is documented as one-shot
  but implemented as sticky, causing redundant orchestrator writes and
  duplicate audit-log lines on every turn while a background reviewer runs.

The acceptance bar is a *fresh Fable re-audit confirming these are fixed*, not
merely "criteria technically pass."

## Context

### F1 — verified mechanism (the audit's framing was wrong; the correction was right)

I read `bin/cli.js` directly. The audit treated the stale
"`@.claude/persona-protocol.md` line in root CLAUDE.md" comment as a bug to be
fixed by restoring that include. It is not. The migration away from the global
include is **deliberate and load-bearing**:

- `bin/cli.js:29-38` — `protocolTierFor()` and the comment
  *"@import does not resolve inside a subagent body — proven in issue #121
  Step 2 … Replaces the single global `@.claude/persona-protocol.md`
  CLAUDE.md import."*
- `bin/cli.js:520-528` — `migrateGlobalProtocolImport()` actively **strips**
  that line from `CLAUDE.md` on `--update`, and returns `true` to force
  re-inlining.
- `bin/cli.js:535-540` — `removeStaleProtocolCopy()` **deletes**
  `.claude/persona-protocol.md` (recorded as decision `OQ11=DROP`/U12).
- `bin/cli.js:473-479` — `inlineProtocolBlock()` physically appends the
  tier-appropriate protocol to each persona body.

So the include cannot be restored: `@import` provably does not resolve inside a
subagent body. Restoring it would silently deliver the protocol to nobody. This
repo's own `CLAUDE.md` correctly contains no such line today.

**Confirmed generated surface** (explorer, grep-fallback provenance, verified
against the working tree): nine mirrors — `.claude/agents/{orchestrator,
lead-programmer,reviewer,spec-master,task-master,milestone-auditor}.md` (full
tier) and `.claude/agents/{explorer,scribe,researcher}.md` (slim tier).

**Confirmed NOT generated:** `adapters/cursor/rules/persona-protocol.mdc` and
`adapters/codex/agents-md-fragment.md` are hand-adapted condensed rewrites
copied byte-for-byte at scaffold time; `bin/cli.js` never regenerates them from
the canonical template. **Consequence: per-persona trimming applies only to the
Claude Code `.claude/agents/*.md` mirrors.** Cursor's `.mdc` is a project-wide
`alwaysApply` rule and Codex's `AGENTS.md` block is a single shared document —
neither has a per-persona seam, so both must keep carrying the union. This is
what bounds Step 4's blast radius.

Two live contradictions surfaced while verifying, both in scope for F1(a):

1. `skills/install-antislop/SKILL.md:362-372` still instructs the installer to
   copy `templates/persona-protocol.md` into `.claude/persona-protocol.md`
   **and** to add the `@.claude/persona-protocol.md` line to `CLAUDE.md` —
   both of which `bin/cli.js --update` then undoes. Install and update
   currently disagree.
2. `bin/cli.js:1134` claims Codex differs from *"Claude's single
   `@.claude/persona-protocol.md` line"* — stale; Claude physically inlines
   too, so the stated contrast no longer exists.

**Section-cost measurement** (`templates/persona-protocol.md`, 16 `##`
sections, 2,806 words total):

| Words | Section |
|---|---|
| 397 | Review ownership — one unit, one review, single owner |
| 297 | Terminal status line |
| 265 | Reviewer roast-work advisory pass trigger (fable) |
| 204 | Agent-teams mode |
| 198 | Third verdict: insufficient-context |
| 195 | Continuing after a FAIL verdict |
| 183 | Running acceptance-criteria commands |
| 159 | Structural questions go to the explorer |
| 157 | WIP sentinel |
| 152 | Pending-review flag |
| 100 | Scope Bash output |
| 97 | FAIL record |
| 79 | A note on `memory` |
| 59 | Machine-checkable criteria |
| 54 | Answer shape |
| 33 | Retrieval contract |

**Mechanically provable inertness** (this is what makes trimming defensible
rather than taste): `hooks/scripts/stop-gate.sh:156-173` early-exits any
`SubagentStop` whose `agent_type` is not in `gatedAgents` (default:
`["lead-programmer"]`) **before** the WIP-sentinel check at line 179.
Therefore the "WIP sentinel" section (157 words) is *inert* for `reviewer`,
`spec-master`, `task-master`, and `milestone-auditor` — writing a sentinel as
any of those does literally nothing. Likewise `lead-programmer` never writes a
`.pass`/`.fail`/`.blocked` marker, never clears a pending-review flag, and
never fires a roast pass, so those four sections (712 words, 27% of the
document) are cost with no corresponding action.

### F2 — verified circularity

`agents/task-master.md:65-70` emits `Suggested reviewer model: sonnet`
**iff** the unit's own `Suggested model:` tag is `haiku` **and** the unit is not
heavy. `agents/reviewer.md:4` sets `model: opus` as the default. ADR-0006
(`docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md:24-32`) records
this as a deliberate conjunctive gate.

The live evidence the audit cited is real and I confirmed it verbatim at
`docs/plans/wip/2026-07-30-master-cross-plan-attack-order.md:357-363`:

> **Model tags.** No unit in this batch is `haiku`-eligible. … Consequently
> **no unit carries a `Suggested reviewer model: sonnet` tag either** — that
> tag is emitted only for a non-heavy `haiku` unit — so the reviewer's `opus`
> default applies throughout.

The structural defect is a **timing mismatch**, which is the part the audit
missed: `task-master` emits the tag *before implementation*, when no diff
exists, so condition (1) is a **prediction** (`haiku`-eligibility) standing in
for the thing actually wanted (mechanical, low-risk change). Meanwhile the
reviewer is dispatched *after implementation*, when the diff **is** measurable.
The fix direction is therefore not "loosen the conjunction" but "move the
decision to the point where evidence exists."

**Empirical grounding** — I measured the last 50 commits (`git show --numstat`
per commit). Mechanical units in this repo are small and clearly separable:

- Genuinely mechanical: `1f 2L` (schema doc), `1f 3L` (hook registration),
  `1f 9L` (`stampVersionOf` reader), `1f 11L` (re-stamp branch), `11f 22L`
  (stamp true-up across mirrors), `2f 38L` (config surface), `5f 38L`
  (`maxTurns` frontmatter), `3f 44L` (`.gitignore` backfill).
- Small but **not** mechanical: `1f 28L` *"close five fail-open bypasses in the
  write-intent matcher"*, `2f 41L` *"narrow the marker-dir Bash gate"*,
  `1f 25L` *"defeat the top-level fast-path"* — all small, all
  security/logic-critical.

**Conclusion the data forces: size alone is unsafe.** A size-only threshold
would have sonnet-gated three security fixes. Size must be conjunctive with a
path-class exclusion. Note also that `11f 22L` (a purely mechanical mirror
true-up) trips the existing heavy trigger's `≥~8 files` criterion — the
file-count proxy misfires on generated-file regeneration.

Under a size **AND** path-class rule, roughly 6–8 of the last 50 commits
(~15%) become sonnet-eligible. That is bounded but non-zero — today it is
exactly zero.

### F3 — verified root cause (differs from all three directions filed on #152)

Issue #152 offers three non-prescriptive directions (pre-seed a defer at
dispatch; add a grace window; reword the message) and
`docs/plans/wip/2026-07-30-master-cross-plan-attack-order.md:449` notes that
*picking among them is the design decision*. Before picking, I ran the hook
(constitution P1 — verify, don't assume):

```
turn 1: rc=0 flag_exists=yes content=[defer: reviewer already dispatched]
turn 2: rc=0 flag_exists=yes content=[defer: reviewer already dispatched]
turn 3: rc=0 flag_exists=yes content=[defer: reviewer already dispatched]
--- audit log lines written: ---
2026-08-01T02:16:17Z defer: reviewer already dispatched
2026-08-01T02:16:17Z defer: reviewer already dispatched
2026-08-01T02:16:17Z defer: reviewer already dispatched
```

**A single `defer:` write allows every subsequent turn-end, indefinitely, and
`stop-gate.sh:136-138` re-appends the identical line to
`.claude/review-audit.log` on every one of those turns.** The defer is
**sticky**, not one-shot.

The documentation says the opposite. `templates/persona-protocol.md:204` reads
*"(logged, flag KEPT, that one Stop allowed — review still owed next turn)"*,
and the same false claim appears in `hooks/scripts/stop-gate.sh:50`,
`adapters/codex/agents-md-fragment.md:77`, and
`skills/install-antislop/hook-verification.md:63`.

This yields a precise, two-part root cause the issue did not identify:

1. **The orchestrator re-writes the defer every turn because the prose tells it
   the previous one was consumed.** That is the wasted work F3 complains about.
2. **The audit log duplicates the line every turn regardless.** The audit's
   headline evidence — *"5 identical defers for unit #177 in 21 minutes"* — is
   consistent with **one** write plus five turn-ends. I confirmed the five
   lines are byte-identical apart from timestamps
   (`.claude/review-audit.log`, 15:58:06 → 16:17:00). The audit was itself
   misled by this logging defect, which is the strongest possible argument
   that it degrades the audit trail.

**Safety check on the sticky semantics.** Making the prose match the code
(rather than the code match the prose) relaxes turn-end nagging. I verified
this does not weaken the real guard: `hooks/scripts/reviewer-route-gate.sh:46-63`
blocks the next gated dispatch on flag **existence only** — it never reads the
flag's content, so a `defer:` does not unblock it. The strong invariant
("no next implementation unit until the reviewer runs") is untouched. Only the
weaker turn-end nag is relaxed, and relaxing it is the entire point.

This makes the correct fix cheaper and safer than any of #152's three
directions: **no gate-semantics change at all.** Direction 2 (grace window)
becomes unnecessary; direction 3 (reword) is subsumed; direction 1 (pre-seed at
dispatch time) is adopted as a pure orchestrator convention with zero hook risk.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-08-01 Functional scope & success criteria: Q Does Pass 1 cover F4–F9 or
  only F1–F3? → A: only F1, F2, F3; F4–F9 plus the contradictions and
  trigger-happiness lists go to a documented backlog section, per the
  orchestrator's explicit instruction.
- 2026-08-01 Domain entities / data model: Q What exactly is "the protocol
  mirror" being changed — the source template, the generated `.claude/agents/*.md`
  files, or the adapter ports? → A (self-resolved): the source
  (`templates/persona-protocol.md`, `agents/*.md`, `bin/cli.js`) plus
  regeneration; generated mirrors are never hand-edited. Adapter ports are
  hand-maintained and out of the trimming mechanism entirely — verified at
  `bin/cli.js:1017-1022` and `1442-1445`.
- 2026-08-01 User interaction flow: Q At what point in the pipeline is reviewer
  model tier decided, given `task-master` tags pre-implementation but the diff
  only exists post-implementation? → A (self-resolved): move the decision to
  the orchestrator's reviewer-dispatch moment, where the diff is measurable;
  `task-master` stops emitting the tag as a prediction.
- 2026-08-01 Non-functional attributes: Q Is decoupling sonnet-eligibility from
  the `haiku` tag a weakening of the review gate? → A (self-resolved): no, if
  the replacement is fail-closed and conjunctive with a path-class exclusion —
  measured evidence strictly dominates a pre-implementation prediction. The
  *threshold value* was escalated as Open Question 1 and answered by the
  operator on 2026-08-01 (≤40 lines / ≤3 files).
- 2026-08-01 External dependencies & integrations: Q Does trimming break the
  Codex/Cursor ports or the parity test? → A (self-resolved): no. The parity
  test derives canonical sections from `## ` headers in the template
  (`tests/adapter-protocol-parity.test.js:43-48`); trimming *selects* sections
  per persona at inline time and never adds, removes, or renames a canonical
  header, so both parity maps are untouched.
- 2026-08-01 Edge cases / failure handling: Q What happens if a persona is
  later added to `gatedAgents` after its protocol excerpt was trimmed of the
  WIP-sentinel section? → A (self-resolved): `bin/cli.js` force-includes the
  WIP-sentinel and pending-review sections for any persona listed in
  `gatedAgents`, so the matrix cannot go stale against config (Step 4).
- 2026-08-01 Edge cases / failure handling: Q If a trimmed persona needs a
  dropped rule, where does it read it? → A (self-resolved): Step 3 restores
  `.claude/persona-protocol.md` as an on-disk full reference copy. This
  reverses `OQ11=DROP` deliberately, because that decision's stated premise
  ("nothing reads it at runtime") stops being true the moment excerpts are
  trimmed.
- 2026-08-01 Technical constraints & tradeoffs: Q Should `defer:` be made
  one-shot (code matches prose) or sticky (prose matches code)? → A
  (self-resolved): sticky — prose is corrected to match the code. Verified that
  `reviewer-route-gate.sh` blocks on flag existence alone, so the strong guard
  is unaffected; only the turn-end nag relaxes, which is the goal.
- 2026-08-01 Terminology consistency: Q Is "heavy" (roast trigger) the same
  concept as "not sonnet-eligible" (reviewer gate)? → A (self-resolved): no,
  and the spec keeps them distinct — "heavy" keeps its existing three-criteria
  definition for the fable advisory pass; sonnet-eligibility gets its own
  measured definition. Overloading one for the other is what produced F2.
- 2026-08-01 Completion / acceptance signals: Q What proves this pass
  converged? → A: a fresh Fable re-audit against the same findings, not the
  acceptance commands alone; the per-step criteria are necessary but not
  sufficient.
- 2026-08-01 Non-functional attributes: Q What line/file thresholds should
  `reviewer-tier.sh` use for sonnet eligibility (40/3, 25/2, 80/5, or keep
  opus always)? → A: ≤40 changed lines AND ≤3 changed files, per operator —
  the recommended option, grounded in the 50-commit measurement. Closes Open
  Question 1.
- 2026-08-01 Technical constraints & tradeoffs: Q Should `lead-programmer`'s
  protocol excerpt drop the "Pending-review flag" section (152 words), given
  it cannot act on the flag but loses diagnostic context at the route-gate
  block? → A: drop it entirely, as specced, per operator — the recommended
  option; the route-gate's own message names the mechanism and Step 3 puts the
  full protocol on disk. Closes Open Question 2.

## Risks / dependencies

- **R1 — trimming can silently drop a rule a persona needs later.** This is the
  central risk and it is not test-detectable: no existing test asserts the
  content of an inlined block beyond two single-phrase probes
  (`'INSUFFICIENT-CONTEXT'`, `'lead with the direct answer'` —
  `tests/cli-backfill.test.js:44-45`). Mitigations, all required, not optional:
  fail-closed default (unknown persona → all sections); hard error on a matrix
  key that does not match a canonical `## ` header; force-include for gated
  personas; and the on-disk full reference copy (Step 3). Step 2 lands the
  mechanism as a **no-op** so the risky matrix change (Step 4) is isolated and
  independently revertible.
- **R2 — `inlineProtocolBlock` and `protocolTierFor` are not exported**
  (`bin/cli.js:1835-1852`), so they have no direct unit coverage today and are
  reachable only via `renderCleanBody` or a subprocess scaffold. Step 2 must
  export the new selector to make it directly testable.
- **R3 — F2 touches the system's core safety property.** ADR-0004 fixed the
  gate on opus; ADR-0006 narrowed it once. Any change here is an ADR-level
  amendment, not a prose tweak, and must preserve: fable permanently off the
  gate, the `.fail` disqualifier, and the escalation-to-permanent-opus path.
- **R4 — prior defect history on this exact surface.** `.claude/reviewed/` has
  a durable FAIL record for the Step-6 word-boundary unit, and
  `docs/plans/2026-07-31-debug-182-step6-word-boundary.md` records a 2-FAIL-cap
  escalation on `hooks/scripts/` matcher logic — two subtle under-match bugs in
  the same area survived review. **No unit in this plan is `haiku`-eligible**,
  and `task-master` must not tag any of them `haiku`. Step 8 touches
  `stop-gate.sh` and inherits this history directly.
- **R5 — version-stamp coupling.** Every change to `agents/*.md` or
  `templates/*` requires a version bump plus CHANGELOG (constitution P3), and
  the nine `.claude/agents/*.md` mirrors are checked into git, so they must be
  regenerated by the tool — never hand-edited — after all source edits land.
  Step 9 is that single regeneration point and must run last.
- **R6 — ordering dependency:** Step 3 (reference copy) must land before
  Step 4 (matrix application), or trimming ships with no fallback. Step 9 must
  follow Steps 1–8.
- **D1 — issue #152** is the tracker home for F3; Steps 7–8 must reference it
  and record why its directions 2 and 3 were not taken as filed.
- **D2 — `tests/validate.sh` is the merge gate** and runs both Node test files
  (`tests/validate.sh:326-342`); it must pass at every step.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the F1 migration story, the F3 sticky-
  defer semantics, and the `reviewer-route-gate.sh` content-blindness were each
  confirmed by reading the code and running the hook against a fixture, not
  inferred from the audit's prose.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — F2's
  eligibility test is specified as a deterministic script
  (`hooks/scripts/reviewer-tier.sh`) rather than another persona-prose rule the
  orchestrator re-derives per unit; this also directly attacks the audit's F6
  double-derivation complaint. Mirrors are regenerated by `bin/cli.js`, never
  hand-edited.
- P3 "Version-stamp discipline": satisfied — Step 9 bumps
  `.claude-plugin/plugin.json` and adds a CHANGELOG entry covering all
  version-stamped files touched.
- P4 "Optional personas degrade gracefully": satisfied — the per-persona matrix
  is keyed by persona name with a fail-closed default, so a project that omits
  `spec-master`/`task-master`/`milestone-auditor` simply never looks up those
  rows; Step 5's prose keeps the existing conditional phrasing.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every step's
  acceptance criteria include it.

---

## Step 1 — Correct the stale protocol-delivery prose at the source

Replace the "delivered via a single `@.claude/persona-protocol.md` line in root
CLAUDE.md" description with one that accurately describes per-persona physical
inlining, everywhere it appears in *source* (not generated, not historical)
files. Historical design records under `docs/specs/` and `docs/plans/` are
deliberately left alone — they are accurate records of a past decision.

Also fix the two live contradictions: the install skill must stop instructing
the installer to add a line that `--update` strips, and `bin/cli.js:1134`'s
Codex comment must stop asserting a contrast with Claude that no longer exists.

**Affected files**
- `templates/persona-protocol.md` (header comment, lines 1-7)
- `adapters/codex/agents-md-fragment.md` (line 4)
- `adapters/cursor/rules/persona-protocol.mdc` (line 6)
- `bin/cli.js` (comment at line 1134 only — no logic change)
- `skills/install-antislop/SKILL.md` (lines 362-372: drop the "add exactly one
  line to CLAUDE.md" instruction; keep the protocol-copy instruction, which
  Step 3 makes correct again)

**Acceptance criteria**
- `! grep -rn '@\.claude/persona-protocol\.md' templates/ adapters/ skills/` exits 0
  (no matches in these three trees).
- `grep -n '@\.claude/persona-protocol\.md' bin/cli.js` still matches lines 516
  and 524 (the migration function's own identifier string must NOT change) and
  no longer matches line 1134.
- `grep -q 'inlined' templates/persona-protocol.md` and
  `grep -q 'inlined' adapters/cursor/rules/persona-protocol.mdc` both exit 0.
- `bash tests/validate.sh` exits 0.
- `node tests/adapter-protocol-parity.test.js` exits 0.

## Step 2 — Per-persona section selector in `bin/cli.js` (mechanism only, no-op)

Add a section-level selector to the inlining path, shipped as an exact no-op:
every persona is mapped to every section, so regenerated mirrors are
byte-identical to today's.

- Parse `templates/persona-protocol.md` into `## `-delimited sections,
  preserving the file's header comment (which is not a section) and section
  order.
- Add `PROTOCOL_SECTIONS_BY_PERSONA`, a map from persona name to an array of
  exact canonical header strings.
- Add `selectProtocolSections(name, tier)` and have `inlineProtocolBlock` use
  it. Export both `selectProtocolSections` and `protocolTierFor`.
- **Fail-closed, three ways:** an unknown persona name → all sections; a
  matrix entry naming a header that does not exist in the template → `throw`
  (so renaming a heading can never silently drop content); slim tier →
  unchanged, selector not applied.

**Affected files**
- `bin/cli.js` (`inlineProtocolBlock` ~473-479; `renderCleanBody` ~481-499;
  scaffold path ~1660-1675; export block ~1835-1852)
- `tests/cli-backfill.test.js` (new cases)

**Acceptance criteria**
- `node bin/cli.js --update --check` reports **no** content change for any
  `.claude/agents/*.md` mirror (the no-op property).
- `git diff --numstat -- .claude/agents/` produces no output after running
  `node bin/cli.js --update`.
- New test asserts `selectProtocolSections('lead-programmer','full')` returns
  all 16 canonical headers at this step.
- New test asserts a matrix entry with a non-existent header throws.
- New test asserts an unknown persona name returns all 16 headers.
- `bash tests/validate.sh` exits 0.

## Step 3 — Restore `.claude/persona-protocol.md` as the full reference copy

Invert `removeStaleProtocolCopy()` (`bin/cli.js:535-540`): instead of deleting
the file, generate and version-stamp it as the complete, untrimmed protocol.
Nothing auto-loads it, so it costs zero tokens per dispatch; it exists so a
persona carrying a trimmed excerpt can read a rule that was trimmed out.

Record in the function's own comment that this deliberately reverses
`OQ11=DROP`, and why: that decision's premise ("nothing reads it at runtime")
ceases to hold once Step 4 trims excerpts.

**Affected files**
- `bin/cli.js` (`removeStaleProtocolCopy` ~535-540, its call sites at ~606 and
  in the scaffold path; `buildFileSpecs` ~449-460 to register the full doc as a
  managed spec alongside the existing slim one)
- `tests/cli-backfill.test.js` (invert the existing deletion assertion at
  ~409-419)

**Acceptance criteria**
- After `node bin/cli.js --update`, `.claude/persona-protocol.md` exists, is
  non-empty, and carries an `<!-- antislop v` stamp on the line following the
  frontmatter/first line.
- `diff <(tail -n +2 .claude/persona-protocol.md) <(cat templates/persona-protocol.md)`
  reports no differences other than the stamp line.
- Running `node bin/cli.js --update` twice leaves the file byte-identical
  (idempotence).
- The updated test asserting the file is *created* (not deleted) passes.
- `bash tests/validate.sh` exits 0.

## Step 4 — Apply the per-persona matrix and force-include for gated personas

Populate `PROTOCOL_SECTIONS_BY_PERSONA` with the matrix below, and add the
config-driven safety rule: any persona listed in `persona-config.json`'s
`gatedAgents` **always** receives the "WIP sentinel" and "Pending-review flag"
sections regardless of its matrix row, so the matrix cannot go stale against
config.

Universal core for every full-tier persona: *Structural questions go to the
explorer*, *Answer shape*, *Scope Bash output*, *Agent-teams mode*, *Terminal
status line*. *A note on `memory`* is included iff the persona's source file
has a `memory:` frontmatter field.

| Persona | Additional sections | Dropped | Words saved |
|---|---|---|---|
| `orchestrator` | all remaining | none | 0 |
| `lead-programmer` | WIP sentinel; Running acceptance-criteria; Retrieval contract; Machine-checkable criteria; Review ownership; Continuing after a FAIL verdict | Pending-review flag; FAIL record; Third verdict; Roast trigger | 712 (27%) |
| `reviewer` | Running acceptance-criteria; Retrieval contract; Machine-checkable criteria; Review ownership; Pending-review flag; FAIL record; Third verdict; Roast trigger | WIP sentinel; Continuing after a FAIL verdict | 352 (13%) |
| `spec-master` | Running acceptance-criteria; Retrieval contract; Machine-checkable criteria; Review ownership; FAIL record; Continuing after a FAIL verdict | WIP sentinel; Pending-review flag; Third verdict; Roast trigger | 772 (29%) |
| `task-master` | Running acceptance-criteria; Retrieval contract; Machine-checkable criteria; Review ownership; FAIL record; Roast trigger | WIP sentinel; Pending-review flag; Third verdict; Continuing after a FAIL verdict | 702 (27%) |
| `milestone-auditor` | Machine-checkable criteria; Review ownership; FAIL record; Continuing after a FAIL verdict | WIP sentinel; Running acceptance-criteria; Retrieval contract; Pending-review flag; Third verdict; Roast trigger | 1067 (41%) |

The `orchestrator` row is deliberately untrimmed: it routes every one of these
mechanisms and is the one persona that genuinely executes on all of them.

The `lead-programmer` row's drop of "Pending-review flag" is **operator-
confirmed (2026-08-01)** and is not to be softened during implementation: the
full 712-word drop stands, giving that row its 27% saving. Do not re-add the
section on the grounds that it "might be useful context."

**Affected files**
- `bin/cli.js` (`PROTOCOL_SECTIONS_BY_PERSONA`; `selectProtocolSections` to
  read `gatedAgents`)
- `.claude/agents/{lead-programmer,reviewer,spec-master,task-master,milestone-auditor}.md`
  (regenerated output only — never hand-edited)
- `tests/cli-backfill.test.js` (new cases)

**Acceptance criteria**
- For each of the five trimmed personas, a test asserts the regenerated body
  contains every header in its matrix row and contains **none** of the headers
  in its Dropped column.
- A test asserts `.claude/agents/orchestrator.md` still contains all 16
  canonical headers.
- A test sets `gatedAgents` to include `reviewer` in a fixture project and
  asserts the regenerated reviewer body then contains `## WIP sentinel`.
- `node tests/adapter-protocol-parity.test.js` exits 0 (proves canonical
  headers and both adapter maps are untouched).
- `wc -w < .claude/agents/milestone-auditor.md` is strictly less than its
  pre-change value recorded in the commit message.
- `bash tests/validate.sh` exits 0.

## Step 5 — `hooks/scripts/reviewer-tier.sh`: deterministic, fail-closed tier selection

New script — **not registered in `hooks.json`**; it is an orchestrator-invoked
helper, and its header comment must say so explicitly to prevent a future
reader assuming it is a live hook. It lives under `hooks/scripts/` so
`tests/validate.sh`'s bash-syntax sweep covers it automatically.

Interface: `reviewer-tier.sh <task-id> <git-range>` → prints exactly `sonnet`
or `opus` on stdout, exit 0.

Prints `opus` (fail-closed) if **any** of:
1. a FAIL record exists for `<task-id>` in the reviewed-marker directory;
2. `<git-range>` is empty, malformed, or `git diff --numstat` on it errors;
3. any changed path matches the sensitive set: `^hooks/`, `^\.claude/hooks/`,
   `^adapters/.*hooks`, `^bin/cli\.js$`, `^tests/validate\.sh$`,
   `^templates/persona-protocol.*\.md$`, `^templates/settings-fragment\.json$`,
   `^\.claude/settings.*\.json$`, `^\.claude-plugin/`;
4. total changed lines (added + deleted) exceed **40**, or changed file count
   exceeds **3**. Implement both as named constants at the top of the script
   (`MAX_CHANGED_LINES=40`, `MAX_CHANGED_FILES=3`) so the threshold is
   greppable and changeable in one place. Operator-confirmed 2026-08-01;
   the comparison is strictly "greater than", i.e. exactly 40 lines and
   exactly 3 files are both still eligible.

Otherwise prints `sonnet`.

**Affected files**
- `hooks/scripts/reviewer-tier.sh` (new)
- `tests/reviewer-tier.test.sh` (new)
- `tests/validate.sh` (register the new test)

**Acceptance criteria**
- `bash tests/reviewer-tier.test.sh` exits 0, covering at minimum: a
  under-threshold non-sensitive diff → `sonnet`; an under-threshold diff
  touching `hooks/` → `opus`; an over-line-threshold diff → `opus`; an
  over-file-threshold diff → `opus`; an empty range → `opus`; a malformed range
  → `opus`; a unit with an existing FAIL record → `opus`.
- **Boundary sweep, not examples.** Cases must pin both sides of each
  threshold: 39/40/41 changed lines and 2/3/4 changed files, asserting
  `sonnet` at and below the limit and `opus` strictly above it. A test that
  only exercises "small → sonnet, huge → opus" does not satisfy this
  criterion — this repo has a documented 2-FAIL escalation
  (`docs/plans/2026-07-31-debug-182-step6-word-boundary.md`) caused by exactly
  that gap on a different boundary predicate.
- `grep -q 'MAX_CHANGED_LINES=40' hooks/scripts/reviewer-tier.sh` and
  `grep -q 'MAX_CHANGED_FILES=3' hooks/scripts/reviewer-tier.sh` both exit 0.
- Mutation controls: temporarily inverting the sensitive-path check makes at
  least one case fail, AND changing `MAX_CHANGED_LINES` from 40 to 41 makes
  the boundary case fail (proving the assertions bind to the exact value, not
  merely to the direction).
- `bash tests/validate.sh` exits 0 and its output names
  `tests/reviewer-tier.test.sh`.

## Step 6 — Rewire the sonnet-eligibility rule in the personas

Remove the `Suggested model: haiku` coupling. `task-master` stops emitting
`Suggested reviewer model: sonnet` entirely — it cannot measure a diff that
does not exist yet — and instead states in each dispatch prompt that the
reviewer tier is decided at dispatch time. The orchestrator runs
`reviewer-tier.sh` and passes the result as the reviewer dispatch's `model`
parameter.

Preserved unchanged (these are the safety invariants, and the step must not
touch them): fable is permanently off the gate; the `.fail` disqualifier; the
escalation path where a missed defect forces permanent opus for that unit id;
the heavy-unit trigger's own three criteria, which continue to govern the
fable advisory pass only.

The orchestrator's judgment may **downgrade** eligibility (`sonnet` → `opus`)
but may never **upgrade** it (`opus` → `sonnet`). State this asymmetry
explicitly — it is what keeps the script a *necessary* condition rather than a
sufficient one.

**Affected files**
- `agents/task-master.md` (lines 65-78: the `Suggested reviewer model` bullet)
- `agents/orchestrator.md` (lines ~281-305: "Reviewer gate model selection")
- `docs/adr/0007-reviewer-tier-measured-eligibility.md` (new ADR amending
  ADR-0006; do not supersede, mirroring how 0006 amends 0004) — note the
  filename must not collide with the existing
  `docs/adr/0007-agent-identity-audit-logging-hardening.md`; use the next free
  number.

**Acceptance criteria**
- `! grep -q 'Suggested reviewer model' agents/task-master.md` exits 0.
- `grep -q 'reviewer-tier.sh' agents/orchestrator.md` exits 0.
- `grep -q 'never.*sonnet\|never upgrade' agents/orchestrator.md` matches the
  downgrade-only asymmetry statement.
- `grep -qi 'fable' agents/orchestrator.md` still matches the permanent-exclusion
  statement, and `grep -q '\.fail' agents/orchestrator.md` still matches the
  disqualifier.
- The new ADR file exists, has `Status: Accepted`, and names ADR-0006 as the
  ADR it amends.
- `bash tests/validate.sh` exits 0.

## Step 7 — Correct the false one-shot `defer:` claim, and reword the block message

Replace *"that one Stop allowed"* with an accurate statement: a `defer:`
persists on the flag and permits turn-end on **every** subsequent turn until
the reviewer's `SubagentStop` clears it or a `skip:` deletes it; the review is
still owed, and `reviewer-route-gate.sh` continues to block the next gated
dispatch regardless of the defer.

Reword `stop-gate.sh:149`'s block message so it stops asserting "spawn the
reviewer" as fact — it cannot know whether the reviewer is already running.
Phrase it as a confirm-or-defer prompt.

Add the orchestrator convention (#152's direction 1): when dispatching the
reviewer as a background task, write
`defer: reviewer dispatched (agent <id>), awaiting verdict` into the flag in
that same turn. With sticky semantics this is a **one-time** write per unit,
which is what eliminates the churn.

**Affected files**
- `templates/persona-protocol.md` (line 204, "Pending-review flag" section)
- `hooks/scripts/stop-gate.sh` (header comment line 50; block message line 149)
- `adapters/codex/agents-md-fragment.md` (line 77)
- `skills/install-antislop/hook-verification.md` (line 63)
- `agents/orchestrator.md` (dispatch-time defer convention)

**Acceptance criteria**
- `! grep -rn 'one Stop allowed' templates/ adapters/ skills/ hooks/` exits 0.
- `! grep -q 'spawn the reviewer' hooks/scripts/stop-gate.sh` exits 0.
- `grep -q 'reviewer dispatched' agents/orchestrator.md` exits 0.
- A new case in `tests/stop-gate-blocked.test.sh` asserts that after one
  `defer:` write, three consecutive `Stop` events all exit 0 and the flag still
  exists with unchanged content (pins the sticky semantics the prose now
  describes).
- `node tests/adapter-protocol-parity.test.js` exits 0.
- `bash tests/validate.sh` exits 0.

## Step 8 — Suppress consecutive duplicate `defer:` lines in the audit log

`stop-gate.sh:136-138` appends the flag's content on every `Stop`. Append only
when the line differs from the last line already in `.claude/review-audit.log`
(comparing the content after the timestamp field). This preserves every
*distinct* event while removing the noise that misled the audit itself.

Do not change the `skip:` branch, the `cleared-by=reviewer` line, or the
`verdict=blocked flags-kept` line — a repeated `cleared-by=reviewer` is a
genuine distinct event.

**Affected files**
- `hooks/scripts/stop-gate.sh` (the `"defer: "*` case, lines 136-138)
- `tests/stop-gate-blocked.test.sh` (new case)

**Acceptance criteria**
- New test: one `defer:` write followed by three `Stop` events yields exactly
  **one** `defer:` line in `review-audit.log`, and all three exit 0.
- New test: `defer: A` → `Stop` → `defer: B` → `Stop` yields exactly **two**
  `defer:` lines, in order (a changed reason is still recorded).
- New test: a `defer:` line separated from an identical earlier one by a
  `cleared-by=reviewer` line is still appended (only *consecutive* duplicates
  are suppressed).
- Mutation control: reverting the dedupe makes the first test fail.
- `bash tests/stop-gate-blocked.test.sh` exits 0.
- `bash tests/validate.sh` exits 0.

## Step 9 — Version bump, mirror regeneration, CHANGELOG

Must run **after** Steps 1–8. Bump `.claude-plugin/plugin.json` to `0.18.0`,
regenerate all nine `.claude/agents/*.md` mirrors plus
`.claude/persona-protocol.md` and `.claude/persona-protocol-slim.md` via the
tool, and add a CHANGELOG entry.

The CHANGELOG must **lead** with the two behaviour changes an operator would
otherwise be surprised by: (a) reviewer tier is now decided by measured diff at
dispatch time rather than by `task-master`'s `haiku` tag, and (b) `defer:` is
documented as sticky — stating plainly that this was always the implemented
behaviour and the previous documentation was wrong.

**Affected files**
- `.claude-plugin/plugin.json`
- `CHANGELOG.md`
- `.claude/agents/*.md`, `.claude/persona-protocol.md`,
  `.claude/persona-protocol-slim.md` (regenerated output only)

**Acceptance criteria**
- `node -e "process.exit(require('./.claude-plugin/plugin.json').version==='0.18.0'?0:1)"` exits 0.
- `grep -q '## \[0.18.0\]' CHANGELOG.md` exits 0.
- `node bin/cli.js --update --check` reports no pending changes (tree is
  fully regenerated and stamped).
- `git status --porcelain .claude/agents/` is empty after
  `node bin/cli.js --update`.
- `bash tests/validate.sh` exits 0.

## Step 10 (scribe) — institutional record

Update the wiki and `CONTEXT.md` for the three changed mechanisms, and correct
the two stale wiki claims found during verification.

**Affected files**
- `.claude/wiki/architecture.md` (line 49: stale global-include claim)
- `.claude/wiki/modules/adapters.md` (line 10: stale global-include claim)
- `.claude/wiki/modules/hooks.md` (sticky-defer semantics + log dedupe)
- `CONTEXT.md` (glossary: per-persona protocol excerpt; measured reviewer tier)

**Acceptance criteria**
- `! grep -rn '@\.claude/persona-protocol\.md' .claude/wiki/` exits 0.
- `grep -q 'sticky\|persists' .claude/wiki/modules/hooks.md` exits 0.
- `grep -q 'reviewer-tier' CONTEXT.md` exits 0.
- `bash tests/validate.sh` exits 0.

---

## Open Questions

**None outstanding — nothing blocks dispatch.** Both questions raised during
authoring were answered by the operator on 2026-08-01, each matching the
recommended default. Retained here as an audit trail of what was decided and
by whom, so a later pass does not silently re-open them.

1. ~~What line/file thresholds should `reviewer-tier.sh` use?~~ **RESOLVED
   2026-08-01 — option (a): ≤40 changed lines AND ≤3 changed files.** The
   rejected alternatives were (b) ≤25/≤2, (c) ≤80/≤5, and (d) keep opus always.
   Baked into Step 5 as `MAX_CHANGED_LINES=40` / `MAX_CHANGED_FILES=3`, with
   the comparison strictly greater-than and boundary cases required on both
   sides. The path-class exclusion, the `.fail` disqualifier, and the permanent
   fable exclusion are unaffected by the choice and remain in force.

2. ~~Should Step 4's `lead-programmer` row really drop "Pending-review flag"?~~
   **RESOLVED 2026-08-01 — option (a): drop it, as specced.** The rejected
   alternative was (b) keep it for `lead-programmer` only (712 → 560 words,
   27% → 21%). The full drop stands; Step 4 records this as not-to-be-softened.

## Self-check

- CHK1: Is it stated which files are generated versus hand-maintained, so no
  step hand-edits a mirror? — PASS
- CHK2: Do Steps 2 and 4 agree on what `selectProtocolSections` returns for an
  unknown persona? — PASS
- CHK3: Is the trimming mechanism's failure mode defined for a renamed
  canonical heading? — PASS
- CHK4: Is the reviewer-tier threshold defined? — PASS (was FAIL (missing) →
  Open Question 1; answered by operator 2026-08-01 and baked into Step 5 as
  named constants with boundary cases, so the plan's own text now answers it)
- CHK5: Do Steps 5 and 6 agree on who runs `reviewer-tier.sh` and who may
  override its result? — PASS
- CHK6: Is "heavy" (roast trigger) kept distinct from "not sonnet-eligible"
  everywhere both appear? — PASS
- CHK7: Is the defer semantics change stated as prose-matches-code rather than
  a behaviour change, with the safety argument for why? — PASS
- CHK8: Does any step's acceptance criterion lack a runnable command? — FAIL
  (ambiguous) — Step 4's "words saved" column was initially prose only;
  revised in place by adding the `wc -w` assertion.
- CHK9: Is the ordering dependency between Steps 3, 4 and 9 stated? — PASS
- CHK10: Is it stated that no unit in this plan may be tagged `haiku`, given
  the prior FAIL history on `hooks/scripts/`? — PASS
- CHK11: Is the ADR filename collision with the existing
  `0007-agent-identity-audit-logging-hardening.md` addressed? — FAIL
  (conflicting) — revised in place; Step 6 now instructs using the next free
  number.
- CHK12: Is the risk of silently dropping a needed rule (R1) given a concrete,
  non-test mitigation? — PASS
- CHK13: Does the plan say what happens to a trimmed persona later added to
  `gatedAgents`? — PASS
- CHK14: Is Step 3's reversal of `OQ11=DROP` justified against that decision's
  original stated premise? — PASS
- CHK15: Is the `lead-programmer` matrix row's diagnostic risk represented
  somewhere? — PASS (was FAIL (missing) → Open Question 2; answered by operator
  2026-08-01, and Step 4 now records the decision as not-to-be-softened)
- CHK16: Are the Step 5 threshold assertions bound to the exact value rather
  than only to the direction? — PASS (boundary sweep at 39/40/41 lines and
  2/3/4 files, plus a constant-mutation control)

Re-check history: the revision pass closed CHK8 and CHK11 in place. CHK4 and
CHK15 were escalated as Open Questions 1 and 2, and both were answered by the
operator on 2026-08-01; they now PASS on the plan's own text. CHK16 was added
when the thresholds were baked in, since a concrete number introduces a
boundary the earlier abstract phrasing did not have. **All 16 items PASS; no
item is unrepresented and no Open Question is outstanding.**

## Scribe update hint

After Step 9 lands, `.claude/wiki/protocol-delivery-tiers.md` needs a third
concept added — the two-tier split (full/slim) is now a **tier plus a
per-persona section selection**, and the wiki currently describes only the
tier. `.claude/wiki/modules/hooks.md` needs the sticky-defer semantics and the
log-dedupe rule. `CONTEXT.md`'s glossary needs "protocol excerpt" and
"measured reviewer tier" entries. ADR-0004/0006's amendment chain gains a third
link.

---

## Deferred to later passes (backlog — NOT implemented in Pass 1)

Handed to a Pass 2 spec once Pass 1 is implemented, reviewed, and re-confirmed
by a fresh Fable audit.

### Findings
- **F4 — fable roast passes fire too readily.** Reported firing on version
  bumps, `.gitignore` edits, and `hooks.json` registration; 7 units in 36–48h;
  roast work run twice on the same unit (inline by the opus reviewer *and* as a
  separate fable dispatch). Note Pass 1 deliberately does not touch the heavy
  trigger — it keeps it distinct from reviewer tier — so F4 is untouched and
  fully available.
- **F5 — maxTurns-cutoff rework churn.** Unit 182 two rounds; unit 179 STATUS-
  line round-trip; unit 164 paused across 4 log entries spawning 8 new units;
  unit 177 ~40-minute escalation loop.
- **F6 — the 14-subsection model-routing decision tree.** Restated caveats
  (`CLAUDE_CODE_SUBAGENT_MODEL` ×3, `.fail`-check ×3) and the double-derivation
  of "heavy" by both `task-master` and the orchestrator. Pass 1's Step 5
  establishes the script-based precedent this should follow.
- **F7 — `reviewed-path-gate.sh` friction (issue #155) and the #159/#154
  issue-lifecycle deadlock**, where an acceptance criterion reads GitHub issue
  state that no agent in the pipeline ever writes.
- **F8 — no action needed.** `protocol-digest.md` (247 words, injected only on
  resume/compact by `session-start.sh`) is well-designed. Recorded so a later
  pass does not "fix" it.
- **F9 — slim/full split is by role category, not actual per-persona rule
  usage.** *Partially* addressed by Pass 1 Steps 2/4 for the full tier; the
  slim tier (800 words, 3 personas) is untouched and remains open.

### Contradictions / redundant mechanisms
All nine items from the audit's list, carried forward unassessed except where
Pass 1 incidentally resolved them. Pass 1 does resolve: the install-skill vs.
`--update` disagreement over the `CLAUDE.md` include and the protocol copy
(Steps 1 and 3), and the prose-vs-code disagreement over `defer:` semantics
(Step 7). The remainder stand.

### Heavyweight-model trigger-happiness
All six items from the audit's list. Pass 1 addresses only the reviewer-tier
slice (F2); the fable-dispatch triggers, the spec-master/milestone-auditor opus
conditions, and the default-to-opus-when-unsure rule are all untouched.

---

## Amendment A1 — `--update --check` is not a dry run; Step 2's and Step 9's criteria are rewritten

Date: 2026-08-01 | Author: `spec-master` | Trigger: advisory finding raised
during *Step 1*'s (#188) review, non-blocking to that unit.

**Nothing above this line is modified**, with one exception, declared here so it
stays auditable: a single `Amended:` pointer line was **inserted** (not edited
over) into the front-matter block, because a reader landing on a document marked
*Finalized* would otherwise execute the superseded criteria verbatim — which is
the precise failure this amendment exists to prevent. The insertion deletes
nothing — it adds four lines between the existing `Status:` and `Scope:` lines
and rewrites neither.

A note on how that is audited, because the obvious check does not yet apply:
this document is **untracked** at the time of writing (`git status` reports it
`??`), so `git diff --numstat` has no baseline to report `0` deletions against.
The append-only invariant becomes mechanically checkable only from the first
commit that tracks this file onward; until then the auditable record is this
paragraph, which names the single insertion and its location exactly. Any later
amendment **must** use the `git diff --numstat` 0-deletions form once a baseline
exists.

### The reported finding, independently verified

`node bin/cli.js --update --check` is **not** a dry run. It is a *forced write*.

*Static verification.* `checkFlag` occurs exactly twice in `bin/cli.js`: its
definition at `:686`, and one use at `:711`, where it is negated into the
"already current — nothing to update" fast-path guard. It gates **nothing else**.
No write in the render loop is conditioned on it — `copyStampedBody` at `:741`
(create), `:755` (stamp refresh) and `:767` (update) run unguarded, as do both
`fs.writeFileSync(configPath, …)` calls that persist `pluginVersion` and
`fileHashes`. The flag's own comment at `:682-685` is accurate and never claimed
otherwise: it "forces the render/diff loop to run". *Report* was the reviewer's
inference, not the code's promise.

*Live verification*, run in a throwaway `git worktree` at `HEAD` (b943286, Step 1
landed) so the working tree was never at risk:

```
$ node bin/cli.js --update --check
antislop v0.17.0 — update complete in …:
  .claude/agents/orchestrator.md: updated (no local edits detected)
  … 5 more mirrors …
$ git status --porcelain
 M .claude/agents/{lead-programmer,milestone-auditor,orchestrator,reviewer,spec-master,task-master}.md
 M .claude/persona-config.json
```

Six mirrors plus `.claude/persona-config.json`, exactly as reported. Note the
banner says **"update complete"**, not "check complete". **Confirmed.**

### The finding is real but it is not the whole defect

Isolating `--check` surfaced two further problems that a mutation-only fix would
have left in place. Both are **spec/criterion defects** — `bin/cli.js` behaves as
documented; the criteria assumed semantics it never had.

**(i) Step 2's criterion 1 is unsatisfiable at HEAD no matter how correct Step 2
is.** The six-mirror diff above is *Step 1's* template prose change, not yet
regenerated into the mirrors — correctly, since this plan's own invariant makes
*Step 9* the single regeneration point. So a forced render at any point during
Steps 1–8 legitimately differs from the on-disk mirrors, and will differ by
*more* with each landed step. The criterion says "the selector changes nothing"
but measures "the mirrors are in sync with the templates", which this plan
deliberately arranges to be **false** until Step 9.

**(ii) Step 2's criterion 2 is vacuous — it cannot fail.** Verified live in a
second throwaway worktree at the same commit:

```
$ node bin/cli.js --update
antislop v0.17.0 — already current in …. Nothing to update.
$ git status --porcelain
(empty)
```

A *plain* `--update` at HEAD takes the `:711` fast-path — `pluginVersion` matches
and no stamp is stale — and writes nothing. `git diff --numstat -- .claude/agents/`
is therefore trivially empty whether or not Step 2 is a no-op. It proves the
fast-path fired, and nothing else.

The two criteria are exactly inverted: **the one that could detect a regression
is destructive and unsatisfiable; the one that is safe detects nothing.**

### Ruling — Step 2's acceptance criteria 1 and 2 are REPLACED

Direction (b) from the triggering request (run it, assert the expected diff,
`git checkout` to restore) is **rejected**: it fixes the mutation but not defect
(i), since the "expected diff" is Steps 1/3/4's accumulated pending prose and
would have to be re-baselined every time another step lands — a criterion whose
expected value drifts is not machine-checkable.

The no-op property must be measured **differentially between two revisions**,
not between a render and the tree. Both revisions carry the identical pending
template changes, so those cancel and only the unit's own contribution remains.

Criteria 1 and 2 of *Step 2* are struck and replaced by **one** criterion:

```bash
# S2-A1 — the no-op property, measured differentially, mutating nothing tracked.
# BASE = the commit this unit started from; HEAD = that commit + Step 2.
BASE=$(git rev-parse HEAD~1)        # adjust if the unit spans >1 commit
W=$(mktemp -d)
git worktree add "$W/base" "$BASE"
git worktree add "$W/head" HEAD
for t in base head; do ( cd "$W/$t" && node bin/cli.js --update --check >/dev/null 2>&1 ); done

diff -r "$W/base/.claude/agents" "$W/head/.claude/agents"          # MUST print nothing
diff "$W/base/.claude/persona-protocol-slim.md" \
     "$W/head/.claude/persona-protocol-slim.md"                    # MUST print nothing

git worktree remove "$W/base" --force; git worktree remove "$W/head" --force
```

`--check` still writes — but only inside throwaway worktrees, so the invariant
that no step before Step 9 touches the mirrors is preserved. Both controls below
were run against this recipe before it was specified here; **both are required
evidence in the unit's completion report**, not optional:

- **Negative control** — two worktrees at the *same* commit render byte-identical
  trees (`diff -r` silent), despite both carrying Step 1's pending diff against
  their own index. This is what demonstrates the cancellation actually works.
- **Mutation control** — append one comment line to
  `templates/persona-protocol.md` in the head worktree only; `diff -r` **must**
  then report differences in every full-tier mirror; discard the line. Without
  this, a mis-pathed `diff -r` (e.g. a directory compared against itself) is
  green forever and the criterion proves nothing.

Criteria 3–6 of *Step 2* are **unchanged**, including issue #189's note about
deriving `16` from the template rather than hard-coding it.

### Ruling — Step 9's acceptance criteria 4 and 5 are REPLACED

*Step 9* is the one step for which regeneration is the deliverable, so the
mutation is not a hazard here. The defect is **ordering**: criterion 5 as
written ("nothing left dirty after regeneration") is unsatisfiable *before* the
regenerated output is committed — Step 9's entire product is a dirty tree — and
after the commit a plain `--update` takes the fast-path, making it vacuous in the
same way as Step 2's criterion 2. What it was reaching for is **idempotency**,
which has to be asserted against a *forced* re-render, after the commit.

Criteria 4 and 5 of *Step 9* are struck and replaced by:

```bash
# S9-A1a — regenerate and COMMIT; this output IS the deliverable.
# (The version bump to 0.18.0 defeats the :711 fast-path, so this genuinely renders.)
node bin/cli.js --update
git add .claude/agents .claude/persona-protocol.md \
        .claude/persona-protocol-slim.md .claude/persona-config.json
git commit -m "chore(release): regenerate mirrors for 0.18.0 (issue #196, Step 9)"

# S9-A1b — idempotency: a FORCED re-render after the commit must change nothing.
node bin/cli.js --update --check
test -z "$(git status --porcelain .claude/agents/ .claude/persona-protocol.md \
           .claude/persona-protocol-slim.md .claude/persona-config.json)"
```

S9-A1b's `--check` is a real write. It is safe **only because it runs after the
commit** — if the re-render is not byte-identical, the `git status` check catches
it rather than the mutation escaping unnoticed. Run in this order; do not hoist
the `--check` above the commit.

Criteria 1, 2, 3 and 6 of *Step 9* are **unchanged**.

**Step 9's affected-files list gains `.claude/persona-config.json`.** It is
git-tracked and `--update` rewrites both its `pluginVersion` and its `fileHashes`
on every render, but it appears in no step's affected-files list in this plan.
Left out of the commit, Step 9 finishes with a tracked, regenerated, uncommitted
file — which is why it is named explicitly in S9-A1a's `git add`.

### Explicitly rejected: adding a `--dry-run` flag to `bin/cli.js`

Not adopted, and not merely on scope grounds. Worktree isolation makes the
existing options safe today — demonstrated live above, in both directions — so
the "genuinely can't be made safe any other way" bar is not met. A real
`--dry-run` would additionally have to thread a no-write mode through
`copyStampedBody` and both `persona-config.json` writes, i.e. a behaviour change
to the tool that generates every persona mirror for all three adapters, during a
plan whose central invariant is that Step 9 is the sole regeneration point. It
is recorded in the backlog below as a Pass-2 candidate, where it can carry its
own review unit.

### Advisory, NOT amended here: *Step 3* (#190) may share defect (ii)

Flagged, deliberately not fixed, because it is outside this amendment's named
scope and the fix is entangled with Step 3's own design. *Step 3*'s criteria
("after `node bin/cli.js --update`, `.claude/persona-protocol.md` exists…";
"running `node bin/cli.js --update` twice leaves the file byte-identical") use a
plain `--update` and depend on the render loop actually running. Today
`removeStaleProtocolCopy()` (`bin/cli.js:535-540`) returns `true` only when it
*deletes*, and that return is one of the `:711` fast-path defeaters. Under Step
3's inversion to *create-when-missing*, the natural implementation returns `true`
on the creating run — but on the second run the file exists, it returns `false`,
the fast-path fires, and "byte-identical" passes without anything being
re-rendered. Whoever dispatches #190 should confirm the second `--update`
actually re-renders; if it does not, route back here rather than patching the
criterion in place.

### Clarifications (A1)

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-08-01 Completion / acceptance signals: Q What is the correct
  machine-checkable signal that Step 2 is an exact no-op, given the mirrors are
  deliberately stale until Step 9? → A (self-resolved): a differential render
  comparison between two throwaway worktrees (BASE vs BASE+unit), with the
  pending template changes cancelling on both sides; verified live before being
  specified.
- 2026-08-01 Terminology consistency: Q Does `--check` mean "report only"
  anywhere in this plan's vocabulary, or was that read into it? → A
  (self-resolved): read into it. `bin/cli.js:682-685` only ever claimed "forces
  the render/diff loop"; the plan's phrasing "reports no content change" supplied
  the dry-run connotation. A1 stops using "reports" for `--check` entirely.
- 2026-08-01 Edge cases / failure handling: Q What stops the replacement
  criterion from being green-forever if the comparison is mis-pathed? → A
  (self-resolved): a mandatory mutation control plus a negative control, both
  required evidence in the completion report.
- 2026-08-01 External dependencies & integrations: Q Does `--update` write any
  tracked file outside `.claude/agents/`? → A (self-resolved): yes —
  `.claude/persona-config.json` (tracked; `pluginVersion` + `fileHashes`), which
  no step listed; added to Step 9's affected files.
- 2026-08-01 Functional scope & success criteria: Q Should this amendment fix
  Step 3's adjacent vacuity risk too? → A (self-resolved): no — out of the named
  scope; flagged as advisory for #190's dispatch instead.

### Constitution check (.claude/constitution.md v1.0.0) — A1 delta only

- P1 "Verify, don't assume": satisfied — the `--check` claim was re-verified
  statically (`checkFlag` at `:686`/`:711`) *and* live in throwaway worktrees,
  and both replacement recipes were executed with negative and mutation controls
  before being written down. Defects (i) and (ii) were found only because the
  relay was tested rather than trusted.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — both
  replacements are runnable command blocks with binary outcomes; neither asks a
  persona to eyeball a diff.
- P3 "Version-stamp discipline": satisfied — A1 moves no version bump. It
  strengthens Step 9's stamp discipline by naming `.claude/persona-config.json`,
  which carries `pluginVersion`, in the commit.
- P4 "Optional personas degrade gracefully": satisfied — `diff -r` over
  `.claude/agents/` compares whatever mirrors that project selected; no persona
  is named in the recipe.
- P5 "`tests/validate.sh` is the merge gate": satisfied — untouched in both
  steps (Step 2 criterion 6, Step 9 criterion 6).

### Self-check (A1)

- CHK-A1: Is it stated whether `--check` writes, in terms of the code rather
  than the banner text? — PASS
- CHK-A2: Do Step 2's replacement criterion and the plan's "Step 9 is the single
  regeneration point" invariant agree? — PASS (worktree-scoped writes leave the
  tracked tree untouched, stated explicitly)
- CHK-A3: Is the replacement criterion for Step 2 falsifiable — can it fail? —
  PASS (mutation control is mandatory, and was run)
- CHK-A4: Is `BASE` defined for a unit spanning more than one commit? — FAIL
  (ambiguous) — revised in place; `HEAD~1` now carries an explicit "adjust if the
  unit spans >1 commit" qualifier rather than being stated as the value.
- CHK-A5: Do A1 and Step 9's original text agree on which criteria survive? —
  PASS (1, 2, 3, 6 named as unchanged; 4 and 5 named as struck)
- CHK-A6: Is the ordering constraint between S9-A1a's commit and S9-A1b's
  `--check` stated, not just implied by listing order? — FAIL (missing) — revised
  in place; an explicit "run in this order; do not hoist" sentence was added.
- CHK-A7: Is the header-line insertion reconciled with the append-only
  invariant? — FAIL (ambiguous) — revised in place. The first draft cited a
  `git diff --numstat` 0-deletions check as the audit; the file is untracked, so
  that command has no baseline and the "check" was unrunnable. Replaced with the
  exact insertion location plus an explicit statement of when the numstat form
  starts applying.
- CHK-A8: Does A1 avoid re-planning steps it was not asked to touch? — PASS
  (Step 3 is advisory-only and explicitly marked not-amended)

All eight items PASS after one revision pass. CHK-A4, CHK-A6 and CHK-A7 were
closed in place; no item escalated to an Open Question, and A1 opens none — it
resolves a criterion defect with information already on disk. CHK-A7 is worth
noting as an instance of the same class of error A1 was written to fix: an
acceptance-shaped claim asserted from the command's *name* rather than from
running it.

### Backlog addition (Pass 2 candidate)

- **A real `--dry-run` / `--report-only` mode for `bin/cli.js`.** `--check`
  forces a render *and writes it*; there is currently no way to ask "what would
  change?" without a throwaway worktree. Rejected for Pass 1 above on scope and
  invariant grounds, not on merit.

---

## Amendment A2 — Step 3's idempotence criterion is vacuous; the fast path is blind to absent managed files

Date: 2026-08-01 | Author: `spec-master` | Trigger: *Step 3* (#190) self-escalated
a confirmed spec gap. `lead-programmer` verified A1's advisory suspicion live and
stopped without patching it locally, per the standing mid-flight-spec-gap rule.
Full repro:
`.claude/agent-memory/antislop-lead-programmer/project_persona_protocol_second_run_fastpath.md`.

**Nothing above this line is modified**, with one exception, declared here so it
stays auditable and following A1's precedent exactly: a second `Amended:` pointer
block was **inserted** (not edited over) into the front-matter, immediately after
A1's own pointer block and before the `Scope:` line — four added lines, zero
deletions, and A1's pointer text left byte-for-byte intact. This document is
still **untracked** (`git status` reports it `??`), so `git diff --numstat` still
has no baseline to report `0` deletions against; the auditable record remains
this paragraph, naming the single insertion and its exact location. The numstat
form becomes mandatory for any amendment written after the first commit that
tracks this file.

This is **not** a 2-FAIL-cap debug spec. The reviewed-marker directory holds no
`190.fail` record — #190 never produced code, let alone two failed attempts. It
is the same class of artifact as A1: a criterion defect caught before
implementation.

### Front-half (`antislop:fail-triage`): VERIFY, then CATEGORIZE

**VERIFY — confirmed, reproduced live.** Run in throwaway `cp -r` copies of the
repo under the session scratchpad, never in the working tree (`git status
--porcelain bin/cli.js` is empty; `bin/cli.js` was never touched). HEAD is
v0.17.0 and `.claude/persona-config.json` records `pluginVersion` 0.17.0, so the
version-match fast path at `bin/cli.js:767` is live today.

The defect is **strictly larger than #190 reported**. It is not confined to
newly-registered specs; it is already live at HEAD for existing ones:

```
$ rm .claude/protocol-digest.md .claude/agents/reviewer.md
$ node bin/cli.js --update
antislop v0.17.0 — already current in <copy>. Nothing to update.
$ ls .claude/protocol-digest.md .claude/agents/reviewer.md
ls: cannot access '.claude/protocol-digest.md': No such file or directory
ls: cannot access '.claude/agents/reviewer.md': No such file or directory
```

**`--update` cannot self-heal a deleted managed file at all.** Delete a persona
mirror the gate depends on and `--update` reports "already current". The cause is
one line: the `stampStale` pre-scan (`bin/cli.js:751-765`) `continue`s past any
destination that does not exist (`:754`), so *absence* is invisible to it, and no
other term in the `:767` condition walks `specs` for existence.
`removedStaleProtocol` is the only defeater that has ever fired on a missing
file, and it fires for exactly one hard-coded path.

Step 3's own symptom follows directly. With `removeStaleProtocolCopy` inverted to
`return !fs.existsSync(p)`, run 1 creates the file; on run 2 the file exists, that
boolean goes false, the pre-scan skips it, the `:767` fast path returns, and the
`for (const spec of specs)` loop at `:784` never executes — `renderCleanBody` is
not called for `.claude/persona-protocol.md`. Step 3's criterion 3 ("running
`--update` twice leaves the file byte-identical") then passes on *never
re-rendered*, not on *rendered and identical*. Reproduced: run 2 prints
`already current … Nothing to update.` and names no file.

**CATEGORIZE — spec/criterion defect**, spec-master's revised-criteria path. Not
a code defect in the FAIL sense: no implementation of #190 exists to be wrong.
The acceptance criterion is unverifiable as written, and verifying it surfaced a
latent tool defect that Step 3's implementation surface must now cover.

### Root-cause / diagnosis (of the plan, not the code)

Two disjoint mechanisms answer one question — *"must the render loop run?"*:

1. a **general** pre-scan over `specs`, which sees staleness but is blind to
   absence; and
2. a set of **ad-hoc booleans** (`hadLegacyToken`, `backfilled`, `checkFlag`,
   `migratedClaudeMd`, `removedStaleProtocol`), of which exactly one — the
   hard-coded `removedStaleProtocol` — has ever answered for a missing file.

Step 3 as written asks the implementer to keep that split and re-point the
hard-coded boolean at the opposite condition. That is why the criterion could be
satisfied without the behaviour: the plan specified a *file-specific* signal for
a *general* property, then measured the property with a command (`--update`
twice) that the tool is designed never to act on twice. Same root shape as A1's
defect (ii): an acceptance command asserted from its name rather than from its
observed effect.

### Ruling — the fix shape

**Adopted: generalize the pre-scan from "stale" to "absent or stale", and retire
`removeStaleProtocolCopy` entirely.** Concretely, at `bin/cli.js:754`:

```js
if (!fs.existsSync(destAbsPath)) continue;
// becomes
if (!fs.existsSync(destAbsPath)) { needsRender = true; break; }
```

with `stampStale` renamed (`needsRender`, or equivalent) so the identifier stops
under-describing what it detects, its comment updated to say it detects a missing
**or** stale destination, and the function `removeStaleProtocolCopy` (`:591-596`),
its single call site (`:662-665`) and its `!removedStaleProtocol` term in the
`:767` condition all deleted. The defeater list shrinks from six terms to five;
it does not grow.

Verified live that this closes the general class — with only that one line
changed, the deleted `protocol-digest.md` **and** the deleted `reviewer.md`
mirror are both restored (`… : created`) on a plain `--update`, and a subsequent
run correctly returns to the fast path.

Rejected alternatives, both named because either would look reasonable in review:

- **(a) Thread a content/stamp check into an inverted `removeStaleProtocolCopy`**
  — the direction #190's memory note floated. Rejected: it preserves the
  two-mechanism split and is narrow. It closes the hole for one hard-coded path
  while leaving `--update` unable to restore a deleted `reviewer.md`, which the
  repro above shows is broken *today*. The dispatch's own instruction is to prefer
  the fix that closes the class.
- **(b) Add a seventh term to the `:767` condition** (e.g. `!anyDestMissing`,
  computed by its own walk over `specs`). Rejected as redundant: the pre-scan
  already walks `specs` for precisely this question and already feeds `:767`. A
  parallel walk duplicates it and re-creates the very split that caused the
  defect.

Registration of the new managed spec is unchanged from Step 3's intent — add a
`.claude/persona-protocol.md` entry to `buildFileSpecs` (kind `plain`, source
`templates/persona-protocol.md`) immediately before the `persona-protocol-slim.md`
entry. The OQ11=DROP reversal comment Step 3 asked to put "in the function's own
comment" has no function to live in once `removeStaleProtocolCopy` is deleted:
**put it on the `buildFileSpecs` registration**, which is now the artifact that
reverses the decision.

### Ruling — Step 3's acceptance criteria 1–4 are REPLACED

Criteria 1, 2, 3 and 4 of *Step 3* are struck. Criterion 5 (`bash
tests/validate.sh` exits 0) is **unchanged**. Replacements below.

All runnable checks execute in a **throwaway `cp -r` copy of the working tree
outside the repo** — not a `git worktree`, because the copy must carry Step 3's
uncommitted changes, which a worktree does not. `.claude/persona-protocol.md`
does **not** land in the tracked tree during Step 3: Step 9 remains the single
regeneration point, and its `git add` (S9-A1a) already names this file.

**S3-A2a — the general defeater: an absent managed destination forces a render.**
New case in `tests/cli-backfill.test.js`, using the existing
`buildBaselineProject` harness (which, once the spec is registered, creates
`.claude/persona-protocol.md` too — so a create-path test must delete first).

- Control: baseline project at the current `pluginVersion`, plain `--update` →
  exit 0 and stdout contains `Nothing to update` (the fast path still works).
- `fs.unlinkSync('.claude/protocol-digest.md')`, then plain `--update` → exit 0,
  the file exists again, and stdout contains
  `.claude/protocol-digest.md: created`.
- Deliberately asserted on a **non-persona-protocol** spec, so the test cannot
  pass on a path-specific patch.
- **Mutation control (required evidence in the completion report):** reverting
  `:754` to `continue` must make this case fail.

**S3-A2b — `.claude/persona-protocol.md` is a managed spec, created on the first
`--update`.** Replaces criteria 1, 2 and 4, and replaces the existing deletion
test at `tests/cli-backfill.test.js:459-476` (invert it; do not leave both).

- From a baseline with the file removed, plain `--update` → exit 0 and stdout
  contains `.claude/persona-protocol.md: created`.
- Line 1 of the created file is exactly
  `<!-- antislop v<version> | source: templates/persona-protocol.md | ADAPT-substituted -->`.
  Pinned to **line 1**, not "the line following the frontmatter/first line" as
  criterion 1 vaguely had it: `templates/persona-protocol.md` has no frontmatter
  (its first line is an HTML comment), so `insertStampAfterFrontmatter` takes its
  `if (!match) return stamp + body` branch (`:127`). Verified.
- `tail -n +2` of the created file is byte-identical to
  `templates/persona-protocol.md`. Verified.

**S3-A2c — idempotence, measured against a FORCED render.** This is the
replacement for the vacuous criterion 3 and the core of this amendment.

- After the creating run, a second run of `node bin/cli.js --update --check`
  exits 0, its stdout contains the exact line
  `  .claude/persona-protocol.md: already current`, and the file's sha256 is
  unchanged from immediately after the creating run.
- **That summary line is the render-invocation evidence.** It is emitted only on
  the path where `renderCleanBody(spec, config)` returned successfully (`:787`)
  and its hash was compared against the recorded one (`:808-818`). If the loop
  never reaches the spec, the line cannot appear. Verified live.
- **An mtime check is forbidden as the evidence**, contrary to the options
  floated at escalation. Measured: the "already current" branch performs **no
  write**, so mtime is byte-for-byte unchanged across a forced re-render. An
  mtime assertion would fail on a correct implementation.
- **Negative control (required evidence):** the same second run *without*
  `--check` prints `Nothing to update` and its stdout contains no occurrence of
  `persona-protocol.md`. This is what demonstrates the replacement measures
  something the struck criterion structurally could not.
- **Mutation control (required evidence):** append one byte to the created
  `.claude/persona-protocol.md`, re-run `node bin/cli.js --update --check` →
  exits **non-zero** and stdout contains `diverged from a fresh copy`. Measured
  exit status was 2; assert non-zero plus the string rather than pinning 2, which
  no code path documents as a contract.

**S3-A2d — legacy-orphan migration path.** A project adapted before v0.17.0 may
still carry an unmanaged `.claude/persona-protocol.md` with stale content and no
`fileHashes` entry, since `removeStaleProtocolCopy` is being deleted rather than
inverted.

- Fixture: baseline project, `delete config.fileHashes['.claude/persona-protocol.md']`,
  and overwrite the file with stale content carrying an old stamp. Plain
  `--update` → exit 0, stdout contains
  `.claude/persona-protocol.md: updated (no local edits detected)`, stdout does
  **not** contain `diverged from a fresh copy`, and `tail -n +2` of the file is
  byte-identical to the template afterwards.
- Verified live: `backfillFileHashesFromDisk` (`:396-408`) records the orphan as
  the clean baseline, which sets `backfilled` and defeats the fast path, and the
  render loop then takes the `noLocalEdits` update branch. The failure this
  criterion exists to catch is the opposite outcome — the orphan landing in
  `pending` and turning a routine `--update` into an interactive prompt on every
  already-adapted project.

**S3-A2e — fresh-scaffold parity.** After a fresh scaffold into an empty
directory (`node bin/cli.js --personas=<selection> --yes`),
`.claude/persona-protocol.md` exists and its `tail -n +2` matches the template.

- Verified live that registering the spec in `buildFileSpecs` **alone does not
  achieve this**: the scaffold path (`:1707-1746`) hand-lists its copies and never
  calls `buildFileSpecs`. Today it copies `protocol-digest.md` (`:1733-1739`) but
  not `persona-protocol-slim.md`, and a fresh scaffold under a
  `buildFileSpecs`-only Step 3 produced `.claude/protocol-digest.md` and nothing
  else.
- Without this, every fresh install lacks the on-disk full protocol until someone
  runs `--update` — i.e. R1's stated mitigation for Step 4's trimming is absent on
  exactly the installs that have never updated. See Open Question A2-1 for the
  scope call.

**S3-A2f — `bash tests/validate.sh` exits 0.** (Step 3's criterion 5, unchanged.)

### Ruling — Step 3's affected-files list is CORRECTED

The list under Step 3 is inaccurate against HEAD. Replacement:

- `bin/cli.js`:
  - `buildFileSpecs` (`:428-462`) — register `.claude/persona-protocol.md` before
    the slim entry; carry the OQ11=DROP reversal comment here.
  - the pre-scan (`:751-765`) — generalize to absent-or-stale; rename the flag.
  - the fast-path condition (`:767`) — drop the `!removedStaleProtocol` term.
  - `removeStaleProtocolCopy` (`:591-596`) and its call site (`:662-665`) —
    delete. **Correction:** Step 3 says "its call sites at ~606 and in the
    scaffold path". Verified false — there is exactly **one** call site (`:662`),
    and the scaffold path never calls it. An implementer hunting a second call
    site will not find one.
  - the scaffold path (`:1733-1739`) — **new region, not in the original list**:
    add a version-stamped `copyStamped` for `.claude/persona-protocol.md`
    mirroring the adjacent `protocol-digest.md` copy (S3-A2e).
- `tests/cli-backfill.test.js` — invert the deletion test at `:459-476` (Step 3
  cites `~409-419`; the assertion has moved) and add the S3-A2a/c/d cases.
- **Not** `.claude/persona-protocol.md` itself: it materializes at Step 9.

Implementer warning, learned the hard way while verifying this amendment: the
exact line `if (!fs.existsSync(destAbsPath)) continue;` appears **twice** in
`bin/cli.js` — at `:373` (inside the MCP-substitution backfill) and at `:754`
(the pre-scan). Only `:754` is in scope. A first-match string replacement hits
`:373` and produces a green-looking false negative.

### Ruling — model tag: `sonnet` is no longer defensible

The tag is `task-master`'s dispatch decision, not this persona's; what follows is
evidence plus a recommendation, handed back for `task-master` to apply.

`#190` was tagged `sonnet`, no roast pass, when it read as "invert a six-line
delete into a create". It is now a control-flow change to `runUpdate`'s
version-match fast path, plus the deletion of a migration function, plus a
scaffold-path addition — with a live correctness bug (deleted mirrors never
restored) inside its blast radius. Supporting evidence:

- `bin/cli.js` is on *this plan's own* sensitive-path list (Step 5,
  `^bin/cli\.js$`), i.e. the plan already classifies this file as never
  sonnet-eligible for the reviewer tier.
- A1 and A2 are two consecutive spec-gap escalations against this same function.
  Every acceptance criterion written for it so far has been wrong on first
  drafting — a measured base rate, not a hunch.
- R4 already forbids `haiku` for every unit in this plan; that stands.

**Recommendation: raise `#190` to `Suggested model: opus` and add the advisory
`Roast pass: fable` marker.** The unit's reviewer tier will be `opus` regardless
once Step 5 lands, by the plan's own path-class rule.

### Downstream note (changes no criterion)

Step 9's CHANGELOG entry should mention, alongside its two existing headline
items, that `--update` now restores any deleted managed file rather than
reporting "already current". This is an operator-visible behaviour change beyond
Step 3's title. Step 9's criteria are untouched — its criterion 2 greps only for
the version heading.

### Open Questions (A2)

**Non-blocking; the recommended default is already baked into the criteria above,
so #190 can be dispatched without waiting on this.**

1. **Should Step 3 also close the fresh-scaffold gap (S3-A2e), or defer it?**
   - **(a) Adopt in Step 3 — recommended, and specced above.** One `copyStamped`
     call. Without it, Step 4's trimming ships with R1's fallback missing on every
     never-updated install, which is the exact scenario R1 was written for.
   - (b) Defer to a Pass-2 unit that also fixes `persona-protocol-slim.md`'s
     identical absence from the scaffold (a pre-existing gap A2 verified but did
     not fix, being outside Step 3's subject). Cheaper unit now, R1 hole open in
     the interim.

### Clarifications (A2)

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Missing

- 2026-08-01 Functional scope & success criteria: Q Should A2 fix only #190's
  reported symptom, or the general class it belongs to? → A (self-resolved): the
  general class. The dispatch asked for the class-closing design, and the repro
  proves the class is already live at HEAD for existing specs (a deleted
  `reviewer.md` is never restored), so a narrow patch would leave a confirmed bug
  in place.
- 2026-08-01 Domain entities / data model: Q Is `.claude/persona-protocol.md` a
  managed spec, an unmanaged orphan, or a hand-maintained doc after Step 3? → A
  (self-resolved): a managed spec, identical in kind to `persona-protocol-slim.md`
  — generated, version-stamped, git-tracked (verified: its two siblings are
  tracked and none of the three is gitignored), never hand-edited.
- 2026-08-01 User interaction flow: Q Who runs the replacement criteria, and
  where? → A (self-resolved): `lead-programmer`, in a throwaway `cp -r` copy
  outside the repo; the tracked tree gains no `.claude/persona-protocol.md` until
  Step 9. `cp -r` rather than `git worktree` because the copy must carry the
  unit's uncommitted changes.
- 2026-08-01 Non-functional attributes: Q Does making the pre-scan absent-aware
  cost anything at runtime? → A (self-resolved): no — it is the same single pass
  over `specs` with one extra `break`, and it strictly reduces work in the common
  case by shrinking the defeater list from six terms to five.
- 2026-08-01 External dependencies & integrations: Q Does the scaffold path share
  the `--update` file list, so registering a spec reaches fresh installs? → A
  (self-resolved): no. Verified live — the scaffold hand-lists its copies
  (`:1707-1746`), never calls `buildFileSpecs`, and produced only
  `.claude/protocol-digest.md`. Hence S3-A2e and Open Question A2-1.
- 2026-08-01 Edge cases / failure handling: Q What happens on an already-adapted
  project still carrying the pre-0.17.0 orphan copy, now that the delete is being
  removed rather than inverted? → A (self-resolved): it self-heals via
  `backfillFileHashesFromDisk` into an "updated (no local edits detected)" write,
  with no interactive prompt — verified live and pinned as S3-A2d. A hand-edited
  orphan is silently rebaselined by that same backfill, which is the tool's
  pre-existing, self-documented behaviour (it prints the warning at `:686-693`),
  not a regression introduced here.
- 2026-08-01 Technical constraints & tradeoffs: Q Extend the existing staleness
  mechanism, or add a term to the fast-path condition list? → A (self-resolved):
  extend the pre-scan and delete the ad-hoc boolean. Both alternatives are named
  and rejected in the ruling; the deciding evidence is that the pre-scan already
  walks `specs` for this exact question, so a second walk would duplicate it.
- 2026-08-01 Terminology consistency: Q Does "idempotence" in Step 3 mean "the
  tool does nothing twice" or "rendering twice yields the same bytes"? → A
  (self-resolved): the latter, and only the latter is worth asserting. The former
  is the fast path, which is true of every managed spec and proves nothing about
  Step 3. A2 says "forced re-render" wherever the struck criterion said "twice".
- 2026-08-01 Completion / acceptance signals: Q What observable proves
  `renderCleanBody` actually ran for `.claude/persona-protocol.md` on the second
  run? → A (self-resolved): the per-file summary line
  `  .claude/persona-protocol.md: already current`, emitted only after a
  successful render and hash comparison, under `--update --check`. Measured, along
  with the refutation of the mtime alternative.

### Constitution check (.claude/constitution.md v1.0.0) — A2 delta only

- P1 "Verify, don't assume": satisfied — every claim here was reproduced in
  throwaway `cp -r` copies: the fast-path blindness, the one-line fix, the
  create/idempotence/orphan/scaffold paths, and the mtime refutation. Recorded
  against myself: my first patch attempt matched the identical
  `if (!fs.existsSync(destAbsPath)) continue;` line at `:373` instead of `:754`
  and produced a clean-looking false negative. It was caught only because the
  result was re-checked against the code rather than believed — this principle
  working, and the reason the implementer warning above exists.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — every
  replacement criterion is a runnable command or a Node test case with a binary
  outcome, each carrying a named mutation or negative control; none asks a persona
  to judge a diff.
- P3 "Version-stamp discipline": satisfied — A2 moves no version bump. The new
  scaffold copy uses `copyStamped`, so the file is stamped on both the scaffold
  and the update path, and S3-A2b pins the exact stamp line.
- P4 "Optional personas degrade gracefully": satisfied — the generalized pre-scan
  walks whatever `specs` the project's own `personaSelection` produced; A2 names
  no persona, and S3-A2a is deliberately asserted on a non-persona spec.
- P5 "`tests/validate.sh` is the merge gate": satisfied — retained as S3-A2f, and
  every new case lands in `tests/cli-backfill.test.js`, which `validate.sh` already
  runs.

### Self-check (A2)

- CHK-B1: Is the render-invocation evidence defined in terms of an observable the
  code actually produces? — FAIL (ambiguous) — revised in place. The first draft
  carried the escalation's own menu ("a log line, an mtime check, or a
  forced-render assertion") straight into the criterion. mtime was then measured
  across a forced re-render and does not change; it is now named as forbidden
  evidence rather than offered as an option.
- CHK-B2: Do A2 and the plan's "Step 9 is the single regeneration point"
  invariant agree on where `.claude/persona-protocol.md` first lands in the
  tracked tree? — PASS
- CHK-B3: Does the adopted fix close the general class rather than
  `persona-protocol.md` alone? — PASS (asserted on `protocol-digest.md`, and
  demonstrated on a deleted `reviewer.md` mirror)
- CHK-B4: Is Step 3's affected-files list accurate against HEAD? — FAIL
  (conflicting) — revised in place; "call sites at ~606 and in the scaffold path"
  is false (one call site, `:662`; the scaffold never calls it), the test-line
  citation has moved, and the scaffold region is added.
- CHK-B5: Is the stamp's position in the created file pinned to an exact line? —
  FAIL (ambiguous) — revised in place; the template has no frontmatter, so the
  stamp is line 1 and the criterion pins the exact string.
- CHK-B6: Is the migration path defined for an already-adapted project carrying
  the legacy orphan copy? — FAIL (missing) — revised in place; S3-A2d added after
  live verification.
- CHK-B7: Does A2 leave every step it was not asked to touch alone? — PASS (Steps
  1, 2, 4–10 unamended; the Step 9 CHANGELOG remark changes no criterion and is
  labelled as such)
- CHK-B8: Is it stated which of Step 3's original criteria survive? — PASS (1–4
  struck, 5 unchanged, both named)
- CHK-B9: Can every replacement criterion fail? — PASS (S3-A2a and S3-A2c each
  carry a mandatory mutation control; S3-A2c additionally carries a negative
  control; S3-A2d asserts the absence of the interactive-prompt outcome)
- CHK-B10: Is the model-tag question answered without usurping `task-master`'s
  dispatch decision? — PASS (stated as evidence plus a recommendation, explicitly
  handed back)
- CHK-B11: Is the scope expansion in S3-A2e represented where the orchestrator
  can settle it? — FAIL (missing) — revised in place; raised as Open Question A2-1
  with the recommended default already specced, marked non-blocking so it does not
  gate dispatch.

Eleven items, one revision pass: CHK-B1, CHK-B4, CHK-B5, CHK-B6 and CHK-B11 all
closed in place. One Open Question (A2-1) is open by construction rather than by
failure — CHK-B11 required that the scope call be *visible*, not that it be
*answered by someone else* — and it is explicitly non-blocking. No item is
unrepresented.

## Amendment A3 — Step 4's matrix has no completeness guard, and its memory-section rule contradicts its own table

Date: 2026-08-01 | Author: `spec-master` | Trigger: an advisory `roast-work`
(fable) pass during *Step 2*'s (#189) review flagged that `selectProtocolSections`
is fail-closed in one direction only, and explicitly asked that the finding be
recorded so **Step 4** — the step that replaces the derived matrix with literal
rows — inherits it. Not a `.fail` escalation: #191 has no recorded FAIL marker
(verified — the marker directory holds `188.pass`, `189.pass`, `190.pass` and
nothing for `191`), and no implementation of it exists yet. Same class as A1/A2:
a criterion defect caught before implementation.

**Nothing above this line is modified**, with one exception, declared here so it
stays auditable and following A1's and A2's precedent exactly: a third
`Amended:` pointer block was **inserted** (not edited over) into the
front-matter, immediately after A2's pointer block and before the `Scope:` line
— four added lines, zero deletions, A1's and A2's pointer text left byte-for-byte
intact. This document is still **untracked** (`git status` reports it `??`), so
`git diff --numstat` still has no baseline; the auditable record remains this
paragraph. **A3 is additive:** *Step 4*'s acceptance criteria 1–6 all stand
unchanged. A3 appends S4-A3a–e and rules on two design questions Step 4 leaves
open.

### Front-half (`antislop:fail-triage`): VERIFY, then CATEGORIZE

**VERIFY — confirmed, reproduced live under Step 4 conditions.** All runs in a
`cp -r` copy of the working tree under the session scratchpad; the working tree
was never touched (`git status --porcelain bin/cli.js templates/persona-protocol.md`
is empty throughout).

The fable pass's reading of the code holds at HEAD after #189 landed
(`bin/cli.js:513-523`, re-read; the line numbers moved but the shape did not):

```js
for (const header of wanted) {                       // matrix -> template: THROWS
  if (!all.includes(header)) throw new Error(...);
}
return all.filter((h) => wanted.includes(h));        // template -> matrix: SILENT
```

Reproduced end-to-end. In the copy, a fabricated `## Fabricated canonical
section` was appended to `templates/persona-protocol.md`, and
`PROTOCOL_SECTIONS_BY_PERSONA['lead-programmer']` was set to a **literal** list
of the 16 pre-existing headers — i.e. exactly the state *Step 4* creates:

```
threw? no. selected count = 16 of 17
fabricated section selected? false
fabricated section present in rendered lead-programmer body? false
```

No throw, no warning, and the new canonical rule is absent from the rendered
`lead-programmer` body. `node tests/cli-backfill.test.js` in that same copy
prints **"All cli-backfill tests passed."** — nothing in the suite notices.

Two facts that bound the finding, both measured rather than assumed:

1. **The gap is created by Step 4, not by Step 2.** At HEAD the matrix is derived
   by walking the template's own headers (`bin/cli.js:502-507`), so it cannot
   drift and the silent branch is unreachable. #189 was correctly PASSed.
2. **The repo already forces this decision for the two adapter ports, and only
   for them.** With the fabricated section present,
   `tests/adapter-protocol-parity.test.js` fails closed:
   `canonical section "Fabricated canonical section" has no parity-map entry —
   drift, decide present or deferred`, once per port. So an author adding a
   canonical section is already stopped and made to classify it **per consumer**
   — for Codex and Cursor. After Step 4, the six Claude persona mirrors become
   the only consumers of that template with no such guard, and they are the ones
   the review-ownership rules actually gate.

**CATEGORIZE — spec/criterion defect.** Step 4's criteria are all *positive or
per-persona*: they assert what each of the six known rows renders today. None of
them can fail because of a section that no row mentions, because the tests
enumerate rows, not template headers. The missing criterion is a template→matrix
one, and the missing mechanism is the check behind it.

### Root-cause / diagnosis (of the plan, not the code)

*Step 2* specified fail-closed behaviour "three ways" and the implementation
delivered all three faithfully — but all three are guards on the **matrix** as
input (unknown persona, non-`full` tier, bad header name). The **template** is
treated as ground truth that the matrix is measured against, never the reverse.
That framing is correct while the matrix is derived from the template (Step 2)
and becomes wrong the moment the matrix is authored independently (Step 4). The
plan carried the Step-2 framing forward into Step 4 without re-deriving it for
the new relationship between the two artifacts.

Same root shape as A1 and A2 in one respect worth naming, because it is now a
measured base rate across three consecutive amendments to this plan: a criterion
was written from the *name* of a property ("fail-closed") rather than from the
set of drift directions that property has to cover.

### Ruling — the fix shape: per-row exhaustive classification, checked at load

**Adopted.** Each full-tier row in `PROTOCOL_SECTIONS_BY_PERSONA` becomes an
object declaring **both** halves of the Step-4 table, by exact canonical header:

```js
'reviewer': {
  include: [ /* universal core + the row's Additional sections */ ],
  drop:    [ /* the row's Dropped column */ ],
},
```

A pure, **exported** validator — `assertProtocolMatrixComplete(canonicalHeaders,
matrix)`, name at the implementer's discretion, contract fixed here: it takes
the header list and the matrix **as arguments** (it must not read module state,
or S4-A3a and S4-A3c cannot be written) — throws unless, for **every** row:

- **(a)** every header named in `include` or `drop` exists in `canonicalHeaders`
  (the existing check, now also applied to `drop`);
- **(b)** `include ∩ drop = ∅`;
- **(c)** `include ∪ drop` equals `canonicalHeaders` **exactly**.

It is called **once at module load**, immediately after the matrix literal, with
the real canonical headers. Measured consequences of load-time placement, all
verified live in the copy by injecting a top-level throw:

- `node bin/cli.js --update` exits **1**, message on stderr, and **zero mirrors
  are written** (`md5sum -c` over `.claude/agents/*.md` passes unchanged) — the
  throw precedes `main`, so no render can have run.
- `tests/cli-backfill.test.js` fails at its own `require` (`:31`), and
  `bash tests/validate.sh` exits **1** with the message in its log. Constitution
  P5 therefore surfaces it as a merge-gate failure with no extra registration.

Two consequences an implementer must **not** "clean up":

- **Keep the per-call header-existence check inside `selectProtocolSections`.**
  Step 2's landed test at `tests/cli-backfill.test.js:77-85` mutates the exported
  matrix at runtime and asserts the throw comes from the *call*; a load-time-only
  check silently guts it. Existence is checked in both places on purpose;
  completeness is checked at load only.
- **The exported row shape changes from array to `{ include, drop }`**, so the
  two Step-2 tests that assign arrays into the matrix
  (`tests/cli-backfill.test.js:77-85` and `:94-109`) are updated **mechanically**
  to the new shape with their assertions preserved. That is the whole of the
  permitted edit to Step 2's landed tests; neither case may be weakened or
  deleted (pinned as S4-A3e).

**Rejected — union over all rows** (the shape the escalation proposed: the union
of every row's sections must cover the canonical set). Two independent measured
defects:

1. **Vacuous.** Step 4's own table gives `orchestrator` every section. If that
   row participates in the union, the union is identically the canonical set and
   the check can never fire — for any template, forever. If instead
   `orchestrator` is implemented by *omission* (falling through to the fail-closed
   all-sections default, the most natural reading of "all remaining"), the row
   does not exist to be unioned, and the check silently covers five personas
   while the sixth is unexamined. There is no encoding of that row under which
   union-completeness means what it appears to mean.
2. **False-positive-prone.** Union-completeness forbids ever dropping a section
   from *every* trimmed row — a legitimate future outcome. Measured: the union of
   the five trimmed rows is already exactly the 16 canonical headers, but four of
   them survive on a single witness each (WIP sentinel ← `lead-programmer`;
   Pending-review flag, Third verdict, Roast trigger ← `reviewer`). A later pass
   trimming *Third verdict* from `reviewer` would trip a "completeness" error
   that is not a defect. A guard whose failures must be argued with is a guard
   that gets deleted.

Per-row classification has neither property: it is independent of what any other
row says, and dropping a header everywhere is expressed by moving it to the last
row's `drop` list.

**Rejected — drop-lists only** (`include` derived as `canonical − drop`, giving
completeness by construction with no throw at all). This is the *simplest* option
and it fails safe: a new canonical section is automatically carried by every
persona. Rejected on the failure direction, stated plainly rather than softened:
the silent outcome is that the section is re-inlined into all six full-tier
mirrors, permanently, on every dispatch — quietly reintroducing exactly the cost
F1 exists to cut — and nobody is ever made to decide whether each persona needs
it. It trades a loud, cheap, once-per-section decision for an invisible recurring
token cost and no forcing function. The standing preference in this repo is
friction on by default.

**Error message shape.** The message must name (i) the persona row, (ii) each
offending header **verbatim**, and (iii) the fix. The criteria below match on
the header text and the persona name, so any wording carrying both passes:

```
PROTOCOL_SECTIONS_BY_PERSONA['reviewer'] does not classify every canonical
section of templates/persona-protocol.md: "Fabricated canonical section".
Add each to that row's include or drop list.
```

with a distinct message for the `include ∩ drop ≠ ∅` case naming the header
listed twice.

### Ruling — the memory-section rule contradicts the matrix table; literal placement wins

Exhaustive classification forces a question Step 4 currently leaves open, so it
is in scope by necessity rather than by choice. Step 4 states *A note on
`memory`* is included **iff** the persona's source file has a `memory:`
frontmatter field. Verified against `agents/*.md`: exactly `lead-programmer`,
`spec-master`, `task-master` and `scribe` carry `memory:` (`scribe` is slim tier,
so it is out of scope); `orchestrator`, `reviewer` and `milestone-auditor` do
not. Two problems follow.

1. **Direct contradiction on `orchestrator`.** The iff rule drops the section
   (84 words, measured) from a row the table records as `Dropped: none`, `Words
   saved: 0`, and which #191's dispatch protects with "its body must not change".
   **Ruling: the table wins.** `orchestrator` is `include` = all 16 canonical
   headers, `drop` = `[]`. Two deliberate, individually-argued statements outrank
   one general sentence, and the alternative rewrites a file the plan explicitly
   protects to save 84 words on the one persona the plan says not to optimize.
   The iff rule governs the five trimmed rows only.
2. **`reviewer` and `milestone-auditor` have incomplete Dropped columns.** Under
   the iff rule both lose the memory section, but neither row lists it. **Ruling:
   add the *A note on `memory`* header to the `drop` list of `reviewer` and
   `milestone-auditor`**, and to the `include` list of `lead-programmer`,
   `spec-master`, `task-master` and `orchestrator`. The table's word-saving
   figures are advisory and become understated by 84 words for those two rows
   (`reviewer` 352→436, ~13%→~16%; `milestone-auditor` 1067→1151, ~41%→~44%). No
   criterion breaks: Step 4's criterion 5 asserts *strictly less*, and a larger
   saving satisfies it. **The `include`/`drop` lists, not the table, are
   authoritative for what renders.**

**Rejected — keep the rule dynamic by listing the memory section in `include`
for every row and filtering it out at render time from frontmatter.** It
preserves exhaustiveness and Step 4's wording, but it makes `reviewer`'s and
`milestone-auditor`'s rows *claim* a section their rendered bodies will not
contain, which directly contradicts Step 4's criterion 1 ("the regenerated body
contains every header in its matrix row"). Literal placement is the only encoding
under which the matrix and criterion 1 agree.

Because literal placement removes the runtime frontmatter derivation, the iff
**fact** is re-asserted as a test instead (S4-A3d), so adding `memory:` to
`reviewer.md` later without touching the matrix fails loudly.

### Ruling — Step 4's acceptance criteria 1–6 STAND; A3 appends five

Criterion 1 is read against the **amended** drop lists above (so `reviewer` and
`milestone-auditor` must additionally contain no `## A note on` memory heading).
No criterion is struck. The five below are additional and all must pass.

**S4-A3a — the validator rejects an unclassified section, and only that.** Pure,
in-process, synthetic headers; no template mutation:

```
# must FAIL (exit non-zero), message naming both `C` and the row key
node -e "require('./bin/cli.js').assertProtocolMatrixComplete(['A','B','C'],{p:{include:['A'],drop:['B']}})"

# positive control — must SUCCEED (exit 0): the same call, now exhaustive
node -e "require('./bin/cli.js').assertProtocolMatrixComplete(['A','B','C'],{p:{include:['A'],drop:['B','C']}})"

# overlap control — must FAIL, message naming `B`
node -e "require('./bin/cli.js').assertProtocolMatrixComplete(['A','B','C'],{p:{include:['A','B'],drop:['B','C']}})"
```

The positive control is mandatory: without it a validator that throws
unconditionally passes the other two.

**S4-A3b — end-to-end mutation control: the tool errors rather than silently
rendering incomplete mirrors.** In a throwaway `cp -r` copy of the working tree
outside the repo (A2's idiom — a copy, not a `git worktree`, because it must
carry Step 4's uncommitted changes):

```
cp -r <repo> "$T"
md5sum "$T"/.claude/agents/*.md > "$T/before.md5"
printf '\n## Fabricated canonical section\n\nA rule that must reach gated personas.\n' >> "$T/templates/persona-protocol.md"
( cd "$T" && node bin/cli.js --update ) 2>"$T/err.log"; echo "exit=$?"
grep -q 'Fabricated canonical section' "$T/err.log"
md5sum -c --status "$T/before.md5"
```

All three must hold: exit is **non-zero**; `err.log` names the fabricated header
verbatim; **every mirror hash is unchanged**. The hash check is the load-time
placement's whole point and is not optional — an error raised *after* some
mirrors were rewritten is a different, worse outcome than the one being bought.
Negative control, mandatory: the identical sequence **without** the `printf`
line exits **0**, demonstrating the command can pass.

**S4-A3c — the guard is per-row, not per-union.** Clone the real matrix, delete
one canonical header from **one** row's `include` **and** `drop` lists (leaving
it present in other rows), and assert the validator throws naming that row and
that header. This is the criterion the rejected union shape cannot satisfy: under
a union check the header is still covered by another row and the mutation passes
silently. Run it over **every** full-tier row in a loop, not one example row.

**S4-A3d — memory-section placement matches frontmatter.** For each of the five
trimmed personas, assert that the *A note on `memory`* header is in that row's
`include` list **iff** `agents/<persona>.md` contains a line matching `^memory:`.
Both directions, all five rows swept — not a single example. `orchestrator` is
excluded by the ruling above and is pinned separately by Step 4's criterion 2
(all 16 headers).

**S4-A3e — Step 2's landed guards survive the row-shape change.** The two cases
at `tests/cli-backfill.test.js:77-85` and `:94-109` still exist and still pass:
a row naming a header the template does not define throws **from
`selectProtocolSections`** (not only from load), and `renderCleanBody` still
inlines only the selected sections. Mechanical adaptation to `{ include, drop }`
only; no assertion may be weakened or removed.

### Ruling — affected files: unchanged as a file list

Step 4's three-entry list is correct as written and A3 adds no file. What changes
is the work *inside* two of them:

- `bin/cli.js` — additionally: the new `assertProtocolMatrixComplete` (pure,
  exported), its single load-time call site immediately after the matrix literal,
  and one name added to the export block (`:1905-1920`). The per-call existence
  check in `selectProtocolSections` (`:517-521`) is **retained**, not moved.
- `tests/cli-backfill.test.js` — additionally: S4-A3a/c/d as new cases, S4-A3b as
  a `cp -r` subprocess case, and the mechanical `{ include, drop }` adaptation of
  the two existing cases named in S4-A3e.
- `.claude/agents/{lead-programmer,reviewer,spec-master,task-master,milestone-auditor}.md`
  — unchanged in kind: regenerated output only.
- **Not** `.claude/agents/orchestrator.md`: the memory ruling above is precisely
  what keeps that file byte-identical. Had the iff rule won, this list would have
  gained it and #191's "its body must not change" constraint would have needed
  striking.
- **Not** `templates/persona-protocol.md`: no canonical heading is added, removed
  or renamed. The fabricated section in S4-A3b exists only inside a throwaway
  copy.

### Ruling — model tag: `opus` + `Roast pass: fable` remain correctly calibrated

The tag is `task-master`'s dispatch decision; what follows is evidence plus a
recommendation, handed back. **Recommendation: no change — keep `opus`, keep the
advisory `Roast pass: fable`.** A3 does not lower the unit's risk profile, and on
two counts raises it:

- **A new global failure mode.** A load-time throw is the correct design, but it
  means a mistake in the validator makes `bin/cli.js` unloadable for *every*
  command and every test file — verified: `--update`, `cli-backfill.test.js` and
  `validate.sh` all die at `require`. That is a strictly larger blast radius than
  a lazy per-call check, accepted deliberately, and it is not sonnet-shaped work.
- **Two more decisions an implementer could plausibly soften**, on top of the two
  #191 already protects: reverting to the union check (simpler, looks equivalent,
  is not), and "de-duplicating" the retained per-call existence check away
  (which silently deletes a Step-2 guard). Both are named above precisely because
  both are natural instincts.
- `bin/cli.js` is on this plan's own sensitive-path list (Step 5,
  `^bin/cli\.js$`), so the unit's reviewer tier is `opus` regardless once Step 5
  lands. R4 forbids `haiku` plan-wide; that stands.
- The roast trigger is unchanged (#2 structural / cross-cutting). Worth recording
  for the ledger: the roast pass that produced *this* amendment was itself the
  mechanism that caught the defect one step early, on the adjacent unit.

### Open Questions (A3)

**Non-blocking; the recommended default is already specced above, so #191 can be
dispatched without waiting on this.**

1. **Does `orchestrator` keep the *A note on `memory`* section despite having no
   `memory:` frontmatter field?**
   - **(a) Yes — keep it; the table wins. Recommended, and specced above.**
     `orchestrator` stays all-16, its mirror stays byte-identical, the plan's
     "deliberately untrimmed" and "its body must not change" statements both hold.
     Cost: the router carries an 84-word section describing a primitive it does
     not itself use.
   - (b) No — the iff rule wins globally, `orchestrator` drops it. Saves 84 words
     (~3% of that row), but changes a file the plan protects, makes the table's
     `Dropped: none` / `0` row false, and requires striking #191's keep-unchanged
     constraint. Not recommended for 84 words.

### Clarifications (A3)

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-08-01 Functional scope & success criteria: Q Is the reported one-directional
  check already covered by Step 4's existing scope, making A3 redundant? → A
  (self-resolved): no. Step 4's six criteria all enumerate *rows* — five
  per-persona include/exclude assertions, one orchestrator all-16 assertion, one
  `gatedAgents` override, plus the parity test and `wc -w`. None enumerates
  *template headers* against the matrix, so none can fail on a header no row
  mentions. Reproduced live: with a fabricated 17th section present and a literal
  matrix, `tests/cli-backfill.test.js` reports "All cli-backfill tests passed."
- 2026-08-01 Domain entities / data model: Q Is a matrix row an include list, a
  drop list, or both? → A (self-resolved): both, literally — `{ include, drop }`,
  transcribing the two columns Step 4's table already carries. Only that encoding
  makes `include ∪ drop = canonical` checkable, and it is what forces the memory
  contradiction into the open instead of leaving it for the implementer.
- 2026-08-01 User interaction flow: Q Who runs the new criteria and where? → A
  (self-resolved): `lead-programmer`. S4-A3a/c/d/e run in-process against the
  working tree; S4-A3b runs in a throwaway `cp -r` copy outside the repo, per A2's
  established idiom. No canonical template is mutated in the tracked tree.
- 2026-08-01 Non-functional attributes: Q What does a load-time check cost? → A
  (self-resolved): one extra pass over ~16 headers × 6 rows on every `require` of
  `bin/cli.js`, on top of a template read the module already performs at load. The
  security-relevant property is the opposite of a cost: verified that the throw
  precedes `main`, so no mirror can be half-written before it fires.
- 2026-08-01 External dependencies & integrations: Q Does the guard have to be
  taught to the Codex/Cursor ports? → A (self-resolved): no. Both ports are
  hand-adapted condensed rewrites with no per-persona seam
  (`bin/cli.js:1017-1022`, `1442-1445`) and are already guarded per-consumer by
  `tests/adapter-protocol-parity.test.js` — verified firing on the fabricated
  section, once per port. A3 closes the one consumer that had no such guard.
- 2026-08-01 Edge cases / failure handling: Q What happens to already-written
  mirrors when the guard fires mid-run? → A (self-resolved): nothing is written
  at all, because the check runs at module load. Measured with `md5sum -c` over
  `.claude/agents/*.md` across a failed `--update`: all unchanged. This is pinned
  as a mandatory half of S4-A3b rather than left implicit.
- 2026-08-01 Technical constraints & tradeoffs: Q Union-over-rows, per-row
  exhaustive, or drop-lists-only? → A (self-resolved): per-row exhaustive. Union
  is vacuous under either encoding of the all-sections `orchestrator` row and
  false-positives on any future all-rows trim (four headers survive on a single
  witness row today). Drop-lists-only needs no check at all but fails by silently
  re-inlining the section into all six mirrors forever — a quiet recurring cost
  with no forcing function. Both named and rejected in the ruling.
- 2026-08-01 Terminology consistency: Q Does "fail-closed" in Step 2's prose mean
  the same thing in Step 4? → A (self-resolved): no, and that equivocation is the
  root cause. Step 2's three fail-closed guards all treat the template as ground
  truth and the matrix as suspect; Step 4 authors the matrix independently, so the
  drift is bidirectional and "fail-closed" has to be re-earned in the other
  direction. A3 says "matrix→template" and "template→matrix" explicitly wherever
  it would otherwise say "fail-closed".
- 2026-08-01 Completion / acceptance signals: Q What observable distinguishes a
  real completeness guard from one that merely throws? → A (self-resolved): three
  controls, all mandatory — a positive control (an exhaustive synthetic matrix
  must exit 0, defeating an unconditionally-throwing validator), an overlap
  control, and the per-row mutation of S4-A3c (which a union check cannot pass).

### Constitution check (.claude/constitution.md v1.0.0) — A3 delta only

- P1 "Verify, don't assume": satisfied — every claim here was reproduced in a
  `cp -r` copy: the silent-vanish under a literal matrix, the parity test firing
  per port, `cli-backfill` passing regardless, the load-time throw's exit code,
  the untouched mirror hashes, and `validate.sh` surfacing the message. Recorded
  against myself: my first reading of the escalation's union proposal accepted it,
  and only computing the union of the five trimmed rows against the canonical 16
  showed it cannot fail once `orchestrator` participates.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — S4-A3a/b
  are runnable commands with binary outcomes and named controls; S4-A3c/d/e are
  Node cases sweeping every row rather than sampling one. No criterion asks a
  persona to judge a diff. The regenerated mirrors remain generated output only.
- P3 "Version-stamp discipline": satisfied — A3 moves no version bump and adds no
  CHANGELOG entry; Step 9 remains the single bump point. A3 changes no
  version-stamped template: `templates/persona-protocol.md` is untouched, and the
  fabricated section exists only inside a throwaway copy.
- P4 "Optional personas degrade gracefully": satisfied, and this needed care —
  the validator iterates the **matrix's own rows**, not a required persona list,
  so a project omitting `spec-master`/`task-master`/`milestone-auditor` still
  loads. A3 adds no requirement that every row resolve to a selected persona or a
  real file. S4-A3d reads `agents/<persona>.md` from the **plugin** source tree,
  which is always present, not from a project's selection.
- P5 "`tests/validate.sh` is the merge gate": satisfied — measured that a
  load-time throw fails `validate.sh` with the message in its log via
  `tests/cli-backfill.test.js`'s `require`, so the new guard needs no separate
  registration in the gate.

### Self-check (A3)

- CHK-C1: Is the proposed check defined precisely enough that a union
  implementation and a per-row implementation are distinguishable by a criterion?
  — FAIL (ambiguous) — revised in place; the first draft adopted the escalation's
  union wording, which S4-A3c then showed is unfalsifiable. S4-A3c was added
  specifically as the discriminating criterion.
- CHK-C2: Is it stated which of Step 4's original criteria survive? — PASS (all
  six stand; A3 is additive, stated in the front-matter pointer, the preamble and
  the ruling heading)
- CHK-C3: Do Step 4's memory-section rule and its matrix table agree about
  `orchestrator`? — FAIL (conflicting) — revised in place; the table wins, the
  contradiction is named, and the losing option is carried into Open Question A3-1.
- CHK-C4: Is the *A note on `memory`* header classified for every full-tier row?
  — FAIL (missing) — revised in place; explicit `include`/`drop` placement given
  for all six rows, with S4-A3d guarding the frontmatter fact the literal
  placement replaces.
- CHK-C5: Can every new criterion fail, and can it pass? — PASS (S4-A3a carries a
  positive control and an overlap control; S4-A3b carries a negative control and a
  hash-unchanged assertion; S4-A3c is a mutation control by construction)
- CHK-C6: Does A3 say what happens to mirrors already written when the guard
  fires? — FAIL (missing) — revised in place; measured (`md5sum -c` unchanged) and
  pinned as a mandatory half of S4-A3b rather than left as an implication of
  "load time".
- CHK-C7: Do A3 and Step 2's landed tests agree about where the header-existence
  throw comes from? — PASS (per-call check explicitly retained; S4-A3e pins both
  Step-2 cases as surviving, mechanically adapted only)
- CHK-C8: Is the affected-files question answered rather than assumed unchanged?
  — PASS (answered: unchanged as a file list, with the per-file work deltas
  enumerated, and `.claude/agents/orchestrator.md` explicitly named as *not* on the
  list *because* of the memory ruling)
- CHK-C9: Is the model-tag reassessment argued rather than asserted, and left as
  `task-master`'s decision? — PASS (three pieces of evidence, stated as a
  recommendation and handed back, following A2's precedent)
- CHK-C10: Does A3 leave every step it was not asked to touch alone? — PASS (Steps
  1–3 and 5–10 unamended; no canonical template heading added, removed or renamed)
- CHK-C11: Is the new validator's contract defined precisely enough to be called
  with synthetic inputs? — FAIL (missing) — revised in place; "pure, exported,
  takes `(canonicalHeaders, matrix)` as arguments, must not read module state" is
  now stated as a fixed contract, because S4-A3a and S4-A3c are unwritable
  otherwise.

Eleven items, one revision pass: CHK-C1, CHK-C3, CHK-C4, CHK-C6 and CHK-C11 all
closed in place. One Open Question (A3-1) exists by construction — CHK-C3
required that the losing interpretation be *visible*, not that someone else
decide it — and it is explicitly non-blocking, since the recommended default is
already specced. No failed item is unrepresented.

---

## Amendment A4 (2026-08-01, orchestrator-applied — no spec-master ceremony)

**Why this amendment exists, and why it skips the usual process.** After Steps
1-4, a Fable investigation (dispatched by the orchestrator, not part of this
spec's normal pipeline) found that this batch had spent ~2.45M tokens across 29
dispatches against a projected total saving, once finished, of ~30-40k tokens —
a two-orders-of-magnitude inefficiency, caused mostly by this spec's own
methodology escalation (A1-A3 progressively mandating positive + negative +
mutation controls, each re-executed independently by writer, reviewer, and
sometimes a fable roast pass, in fresh throwaway repo copies, over a
2,060-line document that keeps growing). Writing this correction under the
same ceremony (9-category taxonomy, constitution check, multi-item self-check)
would repeat the mistake it exists to fix, so the operator authorized the
orchestrator to apply it directly. This section is deliberately short.

### A4.1 — Step 4 (#191) ruling: force-include wins over the lead-programmer drop

Step 4's FAIL (reviewer verdict, unit 191) found two coupled defects:
1. `gatedAgents` was threaded into `renderCleanBody`'s normal `--update` path
   but not into the fresh-scaffold render path — a real bug, fix it (thread the
   argument through both call sites).
2. Once fixed, `lead-programmer` (the one persona in `gatedAgents`) would have
   the *Pending-review flag* section force-included back in, directly
   conflicting with Step 4's own table, which specified dropping it entirely
   per the operator's 2026-08-01 confirmation ("not to be softened").

**Ruling (operator-confirmed, superseding Step 4's original table for this one
cell): force-include wins.** `lead-programmer` keeps *Pending-review flag*.
Rationale: `gatedAgents` exists specifically so a persona actually gated by a
mechanism cannot lose the section describing that mechanism — awareness of the
gate matters more here than the extra ~150 words, and this is also what
Step 3/pre-existing behavior already shipped before the reviewer caught the
scaffold-path bug. This corrects Step 4's savings table: `lead-programmer`
saves **597 words (17%)**, not 712/27%. No other row changes.

**What Step 4's fix-round must do:**
- Thread `gatedAgents` into the fresh-scaffold render call site (the missing
  4th argument the reviewer identified).
- Fix acceptance criterion 1's test: it currently calls
  `renderCleanBody(spec, {})` with an empty config, so the force-include never
  runs and the test cannot see this class of defect. Render with the real
  `.claude/persona-config.json` (`gatedAgents: ["lead-programmer"]`) instead,
  and assert the shipped mirror — not a config no real project renders.
- Add the one-line load-time assertion the reviewer's logic-gap finding named:
  `GATED_AGENT_SECTIONS` must be a subset of the canonical protocol headers
  (next to the existing `assertProtocolMatrixComplete` call), so a future
  heading rename fails loudly instead of silently making the force-include a
  no-op.
- Update the commit message / savings table to record 597/17%, not 712/27%.

**Backlog, not this fix-round** (both are real findings, neither is
test-detectable-cheaply nor in this unit's scope):
- Dangling cross-references in trimmed persona bodies (e.g. "see the WIP
  sentinel above" in a body where that section was dropped) — needs a template
  restructure making cross-references section-local or conditional; out of
  scope for this pass per "no canonical heading touched," recorded for a later
  pass.
- The persona config file gained a `fileHashes` entry for the on-disk full
  protocol copy (untracked file) as a side effect of this batch; not on any
  unit's affected-files list. Likely Step 3 residue — confirm it resolves
  cleanly on a fresh clone, fold into Step 9 if not.

### A4.2 — Verification methodology correction for Steps 5-10 (and this fix-round)

Governing rules, effective immediately, superseding anything in Steps 5-10's
existing acceptance-criteria text that conflicts:

1. **One mutation control per mechanism, not per criterion.** Where several
   criteria on the same unit bind to the same code path, one throwaway copy and
   one revert-run-restore cycle may serve as evidence for all of them. Do not
   spin up a fresh `cp -r`/worktree per criterion.
2. **Writer records evidence once; reviewer verifies by reading it, not by
   re-executing from scratch by default.** The lead-programmer's ready-for-review
   packet must include the literal command and literal observed output for
   every control it ran. The reviewer's default (Tier 1) check is: re-run the
   packet's stated commands verbatim and diff observed output against claimed
   output, plus a plain read-through for internal consistency. The reviewer
   escalates to Tier 2 (independent from-scratch experiments in a private copy)
   only when: the Tier 1 re-run disagrees with the packet, the evidence looks
   incomplete or suspicious, the unit touches a security-sensitive path, or a
   prior FAIL record exists for this unit. This is not a weakening of
   review independence — the writer still cannot fake a passing exit code the
   reviewer re-observes — it removes only the from-scratch reconstruction that
   was the actual cost driver.
3. **Blast-radius explorer dispatch is conditional, not automatic.** Skip it
   when the diff falls entirely within the issue's own affected-files list
   (already verified at spec/slice time). Only dispatch it when the diff
   touches something outside that list.
4. **Resume messages carry a verification ledger, not just a status question.**
   When resuming a cut-off dispatch, the orchestrator states which
   criteria/controls the prior turn already reported as passing and instructs
   the agent to treat those as done, not to re-run them. A pure status-confirmation
   resume ("did you finish, yes/no") should ask for exactly that — reply with
   STATUS only, run nothing — not "confirm by re-verifying."
5. **Dispatch prompts cite the issue; they do not re-paste the interrogation
   trail.** Implementer warnings, prior-attempt context, and corrections belong
   in the issue text (task-master's job, already largely followed) — the
   dispatch prompt itself should be short: `Unit:` line, retrieval contract,
   and only the delta since the last attempt, if any.
6. **Prefer quiet/scoped tool output where the existing tooling already
   supports it** (e.g., grep for the one assertion that matters instead of
   printing a full verbose test-suite run into context) without requiring new
   engineering work on the CLI/merge-gate scripts themselves — that is a
   separate, later unit if still wanted, not a blocker for Steps 5-10.

This correction is scoped to how Steps 5-10 (and Step 4's fix-round) are
verified and dispatched — it changes no acceptance criterion's substance, only
how expensively it may be proven.


---

## Pass 1 execution backlog (orchestrator-compiled, 2026-08-01)

Everything below surfaced during Pass 1's actual implementation (reviewer and
fable-roast findings across units #186/#188-197 and the ad hoc
`resume-cost-fix` unit) — none of it was known when the "Deferred to later
passes" section above was originally written. Consolidated here, in one
place, before the session that ran Pass 1 is cleared, so Pass 2 doesn't have
to reconstruct it from review threads. Everything here is advisory/backlog —
nothing blocks Pass 1's shipped state (v0.19.0).

### Real bugs, confirmed, deliberately left unfixed (in scope for Pass 2)

- **Multi-line `defer:` reason defeats the audit-log dedupe entirely**
  (`hooks/scripts/stop-gate.sh`, found independently by both the opus reviewer
  and the fable pass on #195). The dedupe compares `tail -n 1` of the log
  against the *whole* flag content; a multi-line reason never matches its own
  last line, so every Stop re-appends forever — silently reinstating the
  original F3 defect for that one input shape. Fix: compare only the first
  line of the flag content, or flatten newlines at write time.
- **Cross-unit dedupe collision**: two *different* pending-review flags (two
  different agent-ids) carrying identical `defer:` text collapse to one log
  line in a single Stop — a distinct event is silently unrecorded. Spec-
  conformant by the dedupe's literal "by line content" definition, but the
  real fix (include the agent-id in the logged line) is a log-format change
  outside Step 8's scope. More likely under agent-teams mode (concurrent
  gated flags).
- **The Codex/Cursor adapter copies of `stop-gate.sh`** (`adapters/codex/hooks/scripts/stop-gate.sh`,
  `adapters/cursor/hooks/scripts/stop-gate.sh`) still append unconditionally —
  neither dedupe fix (#193's prose correction or #195's log dedupe) reached
  them, and `tests/validate.sh` only enforces byte-parity for
  `lib/agent-identity.sh` across ports, so this divergence is currently
  invisible to any test.
- **`adapters/cursor/rules/persona-protocol.mdc`** still contains the old,
  false "one Stop allowed" one-shot claim — missed by #193's acceptance
  criterion because that grep is case-sensitive and the Cursor port
  downcases "stop". This file is hand-adapted and never regenerated, so
  Pass 1's Step 9 regeneration does not touch it.
- **Both adapter hook scripts' block messages** still assert "spawn the
  reviewer" as settled fact (the exact wording #193 corrected in the main
  hook) — #193's affected-files list only covered the main
  `hooks/scripts/stop-gate.sh`.
- **The whitespace-only `defer: ` glob hole**: `"defer: "*` in
  `stop-gate.sh` accepts a reason that's empty after the colon (the glob `*`
  matches empty), silently defeating "empty reason rejected." Flagged and
  deliberately left alone across both #193 and #195 (fixing it would flip
  that input's exit code, which each unit's Keep-unchanged list protected).
  Needs its own unit, plus a decision on whether `skip:` needs the same
  tightening.
- **`hooks/scripts/reviewer-tier.sh` has two more latent, non-adversarial
  correctness gaps**, both confirmed still open by #194's implementer
  (mitigated only by an unenforced "run from the repo root" instruction, not
  fixed in code): (a) a `diff.relative=true` git config strips the cwd
  prefix from numstat paths, breaking every `^`-anchored sensitive-path
  pattern when invoked from a subdirectory; (b) `CLAUDE_PROJECT_DIR`
  defaults to `.` and fails *open* (not closed) if the reviewed-marker
  directory isn't found there, silently losing a real `.fail` disqualifier.
- **`SENSITIVE_PATHS` in `reviewer-tier.sh` does not include `agents/*.md`
  itself** (found by #194's opus reviewer) — a ≤40-line, ≤3-file edit to the
  reviewer-gate's own safety-critical prose currently measures `sonnet`,
  under-reviewing the safety rule that governs review depth for everything
  else.
- **`gatedAgents` force-include silently does nothing for a slim-tier
  persona** (found during #191's fix-round review) — `inlineProtocolBlock`
  returns the slim template wholesale, which contains neither gate section,
  so gating e.g. `scribe` would never actually force-include anything.
  Unreachable under the current shipped config (`gatedAgents: ["lead-programmer"]`,
  a full-tier persona) but latent.
- **Dangling cross-references in trimmed persona bodies** (e.g. "see the WIP
  sentinel above" in a mirror where that section was just dropped) —
  confirmed present in `reviewer.md`/`spec-master.md`/`task-master.md`/
  `milestone-auditor.md` during #191's review. Needs a template restructure
  making cross-references section-local or conditional; out of scope for
  Pass 1's "no canonical heading touched" constraint.
- **`.claude/persona-config.json`'s `fileHashes` carries an entry for
  `.claude/persona-protocol.md`**, an untracked file — harmless today, but
  worth confirming it resolves cleanly on a fresh clone rather than assuming so.
- **`ADR-0006` has no "Amended by ADR-0009" back-pointer** (found during
  #194's review) — this repo's own convention (see ADR-0004's back-pointer to
  ADR-0006) was not applied to the newer amendment, because #194's
  Keep-unchanged list forbade touching ADR-0006 directly. A follow-up unit
  with an explicit allowance to add just that one line is needed.
- **`agents/orchestrator.md`'s prose asserts `reviewer-tier.sh` "always"
  prints exactly `sonnet`/`opus`**, with no stated fallback if the script is
  missing or exits non-zero (found independently by both the opus reviewer
  and the fable pass on #194). Fix: one clause — treat any other outcome as
  `opus`.
- **A task-id mismatch between the orchestrator's `reviewer-tier.sh` call and
  the reviewer's actual marker filename would silently defeat the `.fail`
  disqualifier** (found during #194's review) — currently relies on the
  orchestrator's own discipline ("use the same unit id"), not enforced.

### From the original Fable Pass 1 audit — still fully open

F4 (fable roast passes fire too readily — Pass 1 deliberately left the heavy
trigger untouched), F5 (maxTurns-cutoff churn — **partially addressed** by
raising lead-programmer/reviewer `maxTurns` 30→50 and the `resume-cost-fix`
unit's two prose additions, but the base cost of resuming at all — the
resumed turn re-ingesting the whole prior transcript as input — is a
structural property of the resume mechanism, not something a prose fix can
remove; don't expect Pass 2 to "solve" this further without an actual
compact-resume mechanism), F6 (the model-routing decision tree — Step 5
established a script-based precedent this should generalize to), F7
(`reviewed-path-gate.sh` substring-match friction, issue #155, and the
#159/#154 issue-lifecycle deadlock), F9 (slim-tier protocol delivery,
3 personas, still untouched).

All nine "contradictions/redundant mechanisms" and six
"heavyweight-model-trigger-happiness" items from the original audit not
already resolved by Pass 1 (see the "Deferred to later passes" section
above for the specific list) are still open.

### Process lesson, not a code finding — carry into Pass 2's own execution

Pass 1 itself spent roughly two orders of magnitude more in tokens than the
savings it produced, until Amendment A4 corrected the verification
methodology mid-flight (one control per mechanism not per criterion,
reviewer verifies recorded evidence by default rather than re-executing from
scratch, conditional blast-radius dispatch, shorter dispatch prompts). Start
Pass 2 with A4.2's rules and the raised `maxTurns` already in effect from the
beginning — don't re-derive them, and don't repeat the escalation pattern
that made Pass 1's amendments necessary in the first place.

