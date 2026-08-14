# Persona system efficiency audit remediation (issue #348)

Date: 2026-08-13 (revised 2026-08-13 after operator resolution of all five
Open Questions)
Status: **FINAL** — all Open Questions resolved; one new, narrow Open Question
raised during revision (OQ-N1, Step 14 only; see "Open Questions")
Finalization pass: 2026-08-13, after the revision session was cut off
mid-edit. Re-ran every numeric baseline and every internal cross-reference
against the tree; wrote the missing R13 and Self-check items CHK25-CHK32,
both of which earlier text already pointed at; corrected five gaps
(CHK33-CHK38). Substance of the operator's rulings is untouched.
Source audit: GitHub issue #348 (fable critic, filed 2026-08-12 20:20)

## Goal

Remediate the verified subset of issue #348's 24 findings across three
classes — token bloat (Section 1), internal contradictions (Section 2), and
over-engineered workflows (Section 3) — reducing per-invocation persona
prose without removing a single load-bearing rule, and correcting every
statement in the persona corpus that is factually false about the system's
own behavior today.

**Final scope: 22 of 24 findings accepted** (materially the draft's Tier C),
plus one net-new finding (N1) surfaced during verification. Two findings are
rejected outright: 1.10 (violates constitution P4, and its premise is
factually wrong) and 3.7 (not an implementable finding). Eighteen steps.

Three constraints bound the whole effort:

- **Subtraction must not become capability loss.** Every deletion is either
  (a) provably dead text (expired dates, superseded policy), (b) a duplicate
  whose surviving copy is named in the same step, or (c) a correction of a
  false statement. No step removes a rule that is live and singly-stated.
  Where a step removes persona-side prose whose rule is enforced elsewhere
  (Steps 13 and 17), the step names the surviving enforcement point and
  pins it unmodified.
- **The audit's own claims are not taken on trust.** Every finding below was
  independently re-verified against the tree — first at commit `ba1ad48`
  (2026-08-12), then **re-run in full against `d1f232f` (2026-08-13 16:37,
  current HEAD)**, which landed #346's implementation and moved
  `bin/cli.js`, `tests/validate.sh` and the version stamp underneath the
  first pass. Findings whose premises had already gone stale, whose
  severity the audit overstated, or whose proposed fix is technically
  unsound are marked as such, with the correction. **Every acceptance
  criterion below was executed against `d1f232f` and confirmed RED**; the
  re-run corrected eight criteria that had gone vacuous, unsatisfiable, or
  non-executable — see the Self-check items CHK25-CHK32.
- **This is the fourth efficiency pass, and three predecessors already
  ruled on much of this surface.** `#348` was produced by an auditor
  dispatched "with no prior context on this repo", so it re-derives
  several proposals that passes 1-3 assessed and the operator
  **explicitly rejected** — in two cases with anti-re-litigation markers
  written into the plan docs specifically to stop a Pass 4 re-filing them.
  **The operator has now deliberately reversed six of those prior rulings**
  (see "Prior rulings that bind this spec" and R9). Those reversals are
  recorded prominently so a future reader does not mistake them for this
  spec quietly ignoring settled policy.

## Context

`.claude/agents/*.md` are **rendered mirrors**, not source. Source lives in
`agents/*.md` (9 files) plus `templates/persona-protocol.md` (**18** canonical
`## ` sections) and `templates/persona-protocol-slim.md` (**7** sections);
`bin/cli.js`'s `PROTOCOL_SECTIONS_BY_PERSONA` matrix selects which sections
each full-tier persona's mirror inlines (the **protocol excerpt**, per
`CONTEXT.md`). Consequences that shape every step below:

- No step hand-edits `.claude/agents/*.md` (constitution P2). Each unit
  edits source, then re-renders with `node bin/cli.js --update`.
- `.claude/persona-protocol.md` and `.claude/persona-protocol-slim.md` are
  **also rendered copies** (`bin/cli.js:503-511`), so any template edit
  restamps them too. They belong in every template-editing step's affected
  files.
- The slim tier has **no** per-persona trimming at all —
  `selectProtocolSections` throws for it by design (`bin/cli.js:776-778`);
  a slim persona gets `persona-protocol-slim.md` wholesale. Any slim-tier
  trim therefore hits all four slim personas (explorer, researcher, scribe,
  agent-auditor) or none.
- `gatedAgents` is `["lead-programmer"]` only, so the `GATED_AGENT_SECTIONS`
  force-include does not currently rescue any other persona's dropped
  sections.
- **`tests/adapter-protocol-parity.test.js` fails closed on a new canonical
  section.** `checkPort()` asserts every canonical `## ` header has an entry
  in both `codexMap` and `cursorMap`, and that no map key names a header
  that no longer exists. Adding, renaming, or deleting a canonical section
  therefore *requires* a paired map edit or `bash tests/validate.sh` goes
  red. This binds Steps 11 and 17 concretely.
- **`assertProtocolMatrixComplete` forbids a header appearing in both a
  row's `include` and `drop`** (`bin/cli.js:707-719`; the throw is at 719).
  A section spread in via `UNIVERSAL_PROTOCOL_CORE` (`bin/cli.js:565`)
  cannot be dropped by any row. This is the structural reason Step 11 cannot
  simply add a drop entry — see that step.
- **`CANONICAL_PROTOCOL_HEADERS` is derived from the template, not declared
  beside it** (`bin/cli.js:562`:
  `parseProtocolSections(canonicalProtocolText()).sections.map(s => s.header)`).
  Any criterion asserting that a template header "appears in
  `CANONICAL_PROTOCOL_HEADERS`", or that the two agree on order, is
  tautological and proves nothing — the list *is* the template's headers.
  This is why C11.1 asserts placement in the template instead.
- **All `bin/cli.js` and `tests/validate.sh` line numbers in this document
  were re-derived at `d1f232f`.** The first verification pass cited them at
  `ba1ad48`, before that commit inserted ~50 lines; every such citation
  below has been corrected. Treat them as navigational, and re-grep the
  symbol name if a unit finds one off.

Measured baseline (2026-08-13, matches the audit's headline numbers exactly):
total persona prose 43,198 words; `orchestrator.md` 10,927 words / 1,069
lines (534 source + 535 inlined excerpt); `reviewer.md` 7,652 words / 745
lines. Section-level baselines measured for this revision:
`## Per-unit model routing` **111 lines**; its
`### Dispatch-model routing for spec-master and milestone-auditor`
subsection **40 lines**; `### task-master model routing` **11 lines**;
`## Milestone audit gate` **35 lines** with **2** `AskUserQuestion`
mentions; `## Graph freshness (backstop duty)` **8 lines**.

## Prior rulings that bind this spec

Read from `docs/plans/2026-08-01-efficiency-audit-remediation-pass1.md`,
`...-pass2.md`, and `2026-08-03-...-pass3.md`, and verified in place. Six of
#348's findings are not new proposals — they reverse decisions already taken.
**The operator reviewed each reversal on 2026-08-13 and accepted all six.**
The "Final disposition" column records that decision per row.

| #348 finding | Prior ruling | Verified at | Final disposition |
|---|---|---|---|
| **1.1** trim the orchestrator's excerpt | **Settled against, twice.** Pass 1 Step 4: "The `orchestrator` row is deliberately untrimmed: it routes every one of these mechanisms and is the one persona that genuinely executes on all of them." Pass 1 Amendment A3: "**Ruling: the table wins.** `orchestrator` is `include` = all 16 canonical headers, `drop` = `[]`." Trimming its memory section was Open Question A3-1(b), answered "Not recommended for 84 words." | pass1:483, 1767, 1913-1921, 2027 | **REVERSED (partial)** — Step 11, option (a). The status-line section is **kept**, honoring its stated design intent; only the Write/Edit-fallback half, `A note on memory`, and `Microworld bundles` are dropped. |
| **1.6** delete the belt-and-suspenders `.fail` paragraph | **Byte-pinned as an anti-regression control.** Pass 3 Step 4 criterion 6c is headed "**Anti-regression control — the reviewer gate was NOT loosened**"; 6c pins three safety paragraphs of § "Reviewer gate model selection" byte-identical to `e5b908f`, extracted by bold lead — and the second of the three is literally `` `.fail` disqualifier ``, the paragraph 1.6 proposes deleting. | pass3:1088-1100 | **REVERSED** — Step 13. The Pass-3 byte pin on that one paragraph is deliberately overridden; the other two pinned paragraphs stay pinned. |
| **3.1** delete the debug-spec detour | **A deliberately landed carve-out**, not an oversight. Pass 3 Step 9 (F7) created the ≤2-unit fast path and carved this out in the same breath: task-master stays mandatory for "≥3 units, any debug-spec re-derivation, and any `## Convergence follow-ups` slice", pinned by that step's criterion 1 across all three persona files. No operator ruling was taken on the carve-out itself. | pass3 Step 9; `agents/orchestrator.md:17-18` | **REVERSED** — Step 9, now unconditional. |
| **3.4** collapse model-routing rules | **Partially settled.** Operator OQ3 = (a): "implementer tiers only — R2 (the reviewer gate) and `hooks/scripts/reviewer-tier.sh` stay permanent and untouched." Operator OQ5 = (a) rejected more-aggressive compression of sections that "encode gate mechanics". The section was already compressed 192 → ≤110 lines in Pass 3 Step 6c. **Additionally** (found during this revision, not in the draft): `docs/adr/0013:22` records the `milestone-auditor` `fable` tier as "per the operator's 2026-08-06 correction", with explicit anti-overstatement language. | pass3 operator ruling summary; pass3:1703; `docs/adr/0013-...:22` | **REVERSED (scoped)** — Step 14. OQ3's protection of R2 and `reviewer-tier.sh` is **honored, not reversed**: Step 14 touches neither. What is reversed is OQ5's rejection of further compression, and ADR-0013:22's fable tier. |
| **3.5** trim the STATUS-line ceremony | **Protected.** Pass 3 placed the section's rationale paragraph on its protected-rationale list, explicitly out of scope for compression. The paragraph carries its own anti-re-litigation marker in the shipped text: "**Why it exists** (stated as fact, so nobody later 'fixes' it with a hook)". | `templates/persona-protocol.md:154`; pass3 Step 6 criterion 7 | **SPLIT.** The protocol-compression half rides Step 4's excerpt trim and does **not** touch the protected rationale paragraph. The **"drop A5" half is REVERSED and accepted** — Step 18. |
| **3.3** drop the pre-audit checkpoint | **Hard rejected on assessment, then re-affirmed.** Operator OQ4 = (a) "keep it". Pass 3 Step 12: "F10 is **rejected on assessment**, not deferred and not unassessed." Re-checked 2026-08-06: "Leg (i) alone sustains the rejection... **Recorded so a Pass 4 does not re-open it.**" The protected principle traces to `docs/plans/2026-07-13-persona-review-hardening.md:583` and carries a pinned acceptance criterion there. | pass3 Step 12; ADR-0013:28 | **REVERSED — the most consequential reversal in this spec.** Step 15. See R9. The operator was shown the anti-re-litigation marker verbatim and chose to override it. **Scope nuance, verified:** F10 proposed making the *audit itself* opt-in; #348's 3.3 removes only the *pre-audit checkpoint*. Step 15 keeps the audit unconditional and mandatory, so ADR-0013:28's core claim survives; what is reversed is OQ4's "keep it as-is" and the 2026-07-13 pinned criterion. |

Findings **not** present in any prior pass, and therefore cleanly
proposable: 1.2, 1.3, 1.4, 1.7, 1.9, all of Section 2, 3.2, 3.6, and N1.

Two findings are **deferred-but-never-rejected** across all three passes,
which makes them the best-supported work in this spec:

- **2.2** (dangling cross-references in trimmed bodies) was deferred by
  Pass 1 *and* Pass 2, each time for scope reasons — "needs a template
  restructure making cross-references section-local or conditional", "a
  restructure is a pass of its own". It has been open since 2026-08-01.
- **1.8** (slim-tier delivery, tracked as F9) was carried by Pass 1 and
  Pass 2 and never picked up by Pass 3. Pass 2 bounded its own scope to
  "fail loudly, not 'make slim trimming work' — the latter is F9 and stays
  in Pass 3." It never got a step. **Now accepted — Step 12.**

**Cost precedent.** Pass 1's own post-mortem records that it "spent ~2.45M
tokens across 29 dispatches against a projected total saving of ~30-40k
tokens." That produced Amendment A4.2's six standing verification rules,
which Pass 2 adopted as binding. This fourth pass proposes **18 units** and
is justified on **correctness value** — 9 verified false or dead statements
in the persona corpus, plus one latent dead-end (2.3) — not on token
savings. The savings alone have never paid for the passes that produced
them, and this spec does not claim otherwise.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-08-13 Functional scope & success criteria: Q Which of #348's 24
  findings are accepted into this spec vs deferred vs rejected? → A
  **Resolved by the operator, 2026-08-13**: all findings accepted except
  1.10 and 3.7, which are rejected outright. See "Resolved decisions".
- 2026-08-13 User interaction flow: Q Findings 3.3 and 3.6 change how the
  system interrogates and serves the human operator (dropping an
  `AskUserQuestion` checkpoint; dropping a manual freshness step) — is that
  the operator's preference? → A **Resolved by the operator, 2026-08-13**:
  yes, both accepted, 3.3 with the prior hard-rejection shown verbatim
  first. Steps 15 and 16.
- 2026-08-13 User interaction flow: Q 3.3's fix says "drop step 1-2 of the
  checkpoint" — but step 3 (stop on a challenged premise) is unreachable
  without step 2. What happens to it? → A (self-resolved): step 3's re-plan
  route is preserved and re-homed onto the **findings relay**, which the
  finding's own text names ("could be a single question folded into the
  findings relay"). Removing the route entirely would delete a live,
  singly-stated rule, which this spec's first constraint forbids. Step 15
  criterion C15.3 pins it.
- 2026-08-13 Non-functional attributes: Q Does finding 2.3 (marker-filename
  charclass narrower than the dispatch-id grammar) represent live risk or a
  latent one? → A (self-resolved): latent. Zero of the 183 markers in
  `.claude/reviewed/` use `.` or `#` inside the task-id itself; the naming
  convention in use (`gh345-1`, `229-CF2`, `adhoc-2026-08-11-...`) stays
  inside `[A-Za-z0-9_-]`. Still worth the one-regex fix, but the audit's
  Top-5 placement overstates its urgency.
- 2026-08-13 Non-functional attributes: Q Does Step 14's collapse of
  spec-master/milestone-auditor routing raise or lower cost, given both
  personas' frontmatter default is `model: opus`? → A **Unresolved —
  raised as OQ-N1.** Verified: `agents/spec-master.md:4` and
  `agents/milestone-auditor.md:4` are both `model: opus`, so a literal
  reading of 3.4's fix ("frontmatter default; opus after any `.fail` or
  human challenge") makes both **always opus** — removing the sonnet and
  fable downgrades. This is a cost-direction decision the operator has not
  been shown. Step 14 is authored against the recommended default and only
  criterion C14.2 turns on the answer.
- 2026-08-13 Edge cases / failure handling: Q Does fixing 1.2 (dropping
  Fourth-verdict/Resolution from the reviewer's excerpt) create new dangling
  references of exactly the kind 2.2 reports? → A (self-resolved): yes —
  they are coupled. 2.2's fix must land first, and the cross-reference guard
  must be in place, or 1.2 reproduces the bug it is being fixed alongside.
  Step ordering below enforces this.
- 2026-08-13 Edge cases / failure handling: Q Does deleting the
  `` `.fail` disqualifier `` paragraph (Step 13) create a dangling
  reference of the same class as 2.2? → A (self-resolved): **yes, and the
  draft missed it.** Verified: `agents/orchestrator.md:355` reads "which via
  the `.fail` disqualifier above permanently forces opus" — a back-reference
  from the surviving `Escalation.` paragraph into the paragraph being
  deleted. Step 13 must repoint it at `reviewer-tier.sh` directly. C13.3
  pins this.
- 2026-08-13 Edge cases / failure handling: Q Does removing the pre-audit
  checkpoint (Step 15) dangle the model-routing rule that cites it? → A
  (self-resolved): yes. `agents/orchestrator.md:290` cites "a human
  challenge at the step-9 pre-audit checkpoint" as a judgment signal. Step
  14 collapses that very rule and lands **before** Step 15, so the citation
  is gone before its referent is. C14.4 and C15.4 both pin this.
- 2026-08-13 Technical constraints & tradeoffs: Q Can the orchestrator's
  "Agent-teams mode" and "Terminal status line" sections be dropped as
  finding 1.1 proposes? → A **Resolved by the operator, 2026-08-13**:
  option (a) — split "Agent-teams mode" in two, drop only the
  Write/Edit-fallback half, **keep** the status-line section.
- 2026-08-13 Technical constraints & tradeoffs: Q How does the section split
  interact with `UNIVERSAL_PROTOCOL_CORE` and the adapter parity test? → A
  (self-resolved): both bind concretely. The fallback half must be **removed
  from `UNIVERSAL_PROTOCOL_CORE`** and listed explicitly per row, because
  `assertProtocolMatrixComplete` rejects a header present in both a row's
  `include` and `drop` (`bin/cli.js:717-719`). And the new canonical header
  needs an entry in **both** `codexMap` and `cursorMap`
  (`tests/adapter-protocol-parity.test.js`), or `tests/validate.sh` goes
  red. Step 11's ordered edits carry both.
- 2026-08-13 Technical constraints & tradeoffs: Q How must units be sliced
  given the source/mirror split? → A (self-resolved): per `CONTEXT.md`'s
  **source-artifact + render-step gating rule**, a source edit and its
  mirror re-render can never be gated as separate units. Every step below
  bundles edit + `--update` + version bump + CHANGELOG into one unit.
- 2026-08-13 Technical constraints & tradeoffs: Q Does Step 17 (3.2) leave
  the persona corpus without the sanctioned marker-write template, which the
  2026-08-12 incident exists to teach? → A (self-resolved): no. Verified
  first-hand **during this session**: `reviewed-path-gate.sh` refused two of
  my own Bash calls and its refusal text printed the complete remediation
  *including* the two-gate distinction ("That rephrasing workaround is
  sanctioned for THIS gate only... never for human-decision-gate.sh"). And
  `hooks/scripts/human-decision-gate.sh:78-95` prints the full sanctioned
  `cat > ... <<'EOF'` template with its four rules. The refusal-text-is-the-
  documentation premise holds, measured, not assumed.
- 2026-08-13 Terminology consistency: Q Does #348's vocabulary match the
  glossary? → A (self-resolved): partially. #348 says "protocol block" /
  "protocol copy"; the canonical term is **protocol excerpt**
  (`CONTEXT.md:201`). This spec uses the canonical term. Lens 3 also
  surfaced a live glossary defect — see finding N1.
- 2026-08-13 Terminology consistency: Q Does the paragraph Step 13 deletes
  have a canonical glossary name? → A (self-resolved): yes —
  **reviewer-gate ratchet** (`CONTEXT.md:256`), defined as "the `.fail`
  disqualifier on the reviewer's own model eligibility... never expires",
  and explicitly distinct from the **implementer-tier ratchet**
  (`CONTEXT.md:248`). Step 13 uses the canonical terms and must not blur
  them; deleting the persona-side prose leaves `reviewer-tier.sh:73-75` as
  the sole, fail-closed enforcement of the reviewer-gate ratchet, which
  C13.2 pins unmodified.

**Terminology drift check (prose mode, three lenses, against `CONTEXT.md`).**
Lens 1 (glossary term used with a different meaning): none found in this
revision. Lens 2 (new synonym for a defined term): #348's "protocol
block"/"protocol copy" for **protocol excerpt**, and its "belt-and-suspenders
paragraph" for the **reviewer-gate ratchet** — this spec uses the canonical
terms in both cases. Lens 3 (load-bearing new domain term with no glossary
entry): four — **pre-audit checkpoint**, **graph-freshness backstop duty**,
**anomaly check (A1-A6)**, and the new canonical protocol section Step 11
creates. All four are load-bearing and undefined in `CONTEXT.md`; three of
them are being *removed or renamed* by this spec, so the useful glossary
work is post-hoc. Handed to the Scribe update hint, advisory only.

## Risks / dependencies

- **R1 — Source/render slicing (standing rule).** `CONTEXT.md`'s
  "Source-artifact + render-step gating rule" states that a step editing a
  source artifact and a separate step regenerating its shipped copy **can
  never be gated independently** under `tests/validate.sh`. `task-master`
  must not split any step below into an edit unit and a render unit. Prior
  incident: units #265-267.
- **R2 — Constitution P3 applies to every step.** Every step here touches a
  version-stamped file, so each unit bumps `.claude-plugin/plugin.json` and
  adds a CHANGELOG entry. Sequential landing is therefore mandatory; two
  units cannot bump the same version. With 18 units this is the dominant
  scheduling constraint.
- **R3 — Coupling of 1.2 and 2.2.** Dropping sections from an excerpt is
  what *created* 2.2's dangling references. Step 2 (self-contained
  references + build-time guard) must land before Step 4 (further drops), or
  Step 4 reintroduces the defect class. The same guard is what makes Step
  11's new drops safe.
- **R4 — `hooks/scripts/human-decision-gate.sh` is a protected path**
  (`.claude/persona-config.json` `protectedPaths`) and security-sensitive,
  so Step 7 meets the ADR-0004 heavy-unit trigger (criterion 3) and must
  draw an opus reviewer.
- **R5 — `--update` restamps all mirrors.** Every unit's diff will show more
  files touched than edited, including `.claude/persona-protocol.md` and
  `.claude/persona-protocol-slim.md`. Reviewers should key on `agents/*.md`,
  `templates/*`, `bin/cli.js` and `scripts/*` source diffs, not mirror
  churn.
- **R6 — No prior `.fail` record exists for any unit in this spec** (it is
  net-new work) — re-verified twice on 2026-08-13 by enumerating the
  **whole** marker directory, not a sample. **Second pass census (at
  `d1f232f`): 48 `.fail` records against 177 `.pass`, 226 files total**,
  plus one `gh-304.fail.overturned`. None names a gh348 unit. The first
  pass counted 47; the difference is **`gh346-1.fail`, written
  2026-08-13T21:52Z against commit `d1f232f` itself** — i.e. the blocking
  dependency in R8 has now FAILed review once. See R13, which is the
  operational consequence for this spec's own 18 units. However, the
  surrounding surface has a heavy defect history:
  the protocol/persona surface specifically produced `gh-304.fail` (later
  overturned), `gh277.fail` (dispatch hygiene), `gh274.fail`, and the three
  prior efficiency passes. Docs-and-prose units on this surface have a
  documented history of passing vacuous existence-grep criteria while
  shipping inaccurate prose — **every prose step below therefore carries a
  claim-anchored criterion, not a bare `grep -c ... == 0`**, and every new
  criterion in this revision was run against the tree and confirmed RED
  before being written down.
- **R7 — Issue collisions.** #334/#337/#290 edit `scripts/agent-audit.sh`,
  `tests/agent-auditor.test.sh` and `agents/agent-auditor.md` — the exact
  three files Step 18 edits. See R10.
- **R8 — HARD SEQUENCING PRECONDITION: #346 and #347 land first.**
  Operator ruling, 2026-08-13 (draft OQ4 = option (a)). **No unit of this
  spec is dispatchable until both `docs/plans/2026-08-12-standalone-hook-propagation-gap.md`
  (#346) and `docs/plans/2026-08-12-reviewer-dispatch-caller-allowlist.md`
  (#347) are implemented and reviewer-PASSed.** This is a precondition on
  dispatch, not something `task-master` or the orchestrator should discover
  mid-flight.
  - **#347** edits `agents/orchestrator.md` (its Step 2 rewrites step 4 of
    the `ESCALATE-TO-HUMAN` section). Steps 5, 9, 13, 14, 15 and 16 of this
    spec rewrite other regions of the same file; #347's edit is surgical and
    would be painful to rebase across them.
  - **#346** Step 2 creates `.claude/hooks/scripts/human-decision-gate.sh`.
    **PREMISE CORRECTED 2026-08-13 (second verification pass):** the first
    pass recorded "that path does not exist today", verified at `ba1ad48`.
    It exists now — commit **`d1f232f`** ("fix(standalone-hook-gap):
    propagate hook scripts and registrations on --update", 2026-08-13 16:37,
    current HEAD) landed #346's implementation, creating that mirror plus
    `lib/benign-command.sh` and `microworld-rerun.sh`, and it is
    byte-identical to its source (`diff` exits 0). **The operator's
    sequencing ruling is unchanged and still binding**: #346 is
    *implemented* but **not reviewer-PASSed** — no `gh346*.pass` marker
    exists in the marker directory and issue #346 is still `OPEN`. #347 is
    `OPEN` with no marker and no landed commit. The precondition is
    therefore still unmet; what changed is only that #346's remaining work
    is review, not implementation. This spec's **Step 7** is the step that
    needs the mirror — it edits `hooks/scripts/human-decision-gate.sh`, and
    source and mirror must move in one coherent unit.
    *(Correction to the dispatch briefing: the #346 dependency binds Step 7,
    not the Step-13 finding-1.6 work. Step 13 edits `agents/orchestrator.md`
    model-routing prose and touches no hook.)*
    *(Second-order consequence: `d1f232f` also bumped the version to
    **0.31.28** and edited `bin/cli.js` and `tests/validate.sh`. C1.5's
    hardcoded `> 0.31.27` went vacuous as a result and has been rewritten;
    see CHK25.)*
  - **#345 is already CLOSED** (verified via `gh issue view 345`); its scope
    was complete and the orchestrator closed it directly. It is not a
    dependency of this spec. No step here closes any issue.
- **R9 — SIX PRIOR OPERATOR/PASS RULINGS ARE DELIBERATELY REVERSED.**
  Recorded here prominently and deliberately, so no future reader mistakes
  this for the spec quietly ignoring settled policy. Every reversal was put
  to the operator on 2026-08-13 with the binding prior ruling quoted, and
  accepted:
  1. **Pass 1's "the table wins"** (orchestrator excerpt untrimmed, ruled
     twice) → partially reversed by **Step 11**.
  2. **Pass 3 Step 4 criterion 6c's byte pin** on the
     `` `.fail` disqualifier `` paragraph, an explicitly-labeled
     "**Anti-regression control — the reviewer gate was NOT loosened**"
     → reversed by **Step 13**. The other two pinned paragraphs
     (`Downgrade-only asymmetry`, `Escalation.`) remain pinned, and C13.2
     re-runs the pin on them.
  3. **Pass 3 Step 9's debug-spec carve-out** → reversed by **Step 9**.
  4. **Operator OQ5** (rejecting further compression of gate-mechanics
     prose) **and ADR-0013:22's 2026-08-06 operator correction** retaining a
     `fable` tier for `milestone-auditor` → reversed by **Step 14**.
     Operator OQ3's protection of R2/`reviewer-tier.sh` is **not** reversed.
  5. **Operator OQ4 = (a) "keep it as-is"** on the milestone pre-audit
     checkpoint, plus Pass 3 Step 12's "F10 is **rejected on assessment**"
     and its 2026-08-06 re-affirmation "**Recorded so a Pass 4 does not
     re-open it**", plus the pinned acceptance criterion at
     `docs/plans/2026-07-13-persona-review-hardening.md:588-593` → reversed
     by **Step 15**. This is the reversal with the strongest prior
     protection in the whole repo. The operator was shown that
     anti-re-litigation marker verbatim and confirmed the override anyway.
     Step 15 is narrower than the rejected F10: the audit itself stays
     unconditional and mandatory.
  6. **Pass 3's protected-rationale list** covering the STATUS-line section
     → reversed only for the **A5 half** (Step 18). The protected rationale
     paragraph in `templates/persona-protocol.md:154` is **not** touched by
     any step.
- **R10 — Step 18 (drop A5) ships onto contested ground, knowingly.**
  Operator ruling, 2026-08-13: proceed now rather than defer. Three facts a
  future reader needs:
  1. **A5 is one of exactly two mutation-proved anomaly checks.**
     `tests/agent-auditor.test.sh:255-301` runs `mutation_proof A1 a1bad`
     and `mutation_proof A5 a5bad`. Verified: `mutation_proof` is a generic
     helper and **A1's proof stands alone** — dropping A5 does not break
     A1's proof, contrary to the draft's stronger claim. What is genuinely
     lost is mutation-proof coverage falling from 2 checks to 1.
  2. **File collision with three open issues.** #334 Step 1, #337, and #290
     all edit `scripts/agent-audit.sh`, `tests/agent-auditor.test.sh` and/or
     `agents/agent-auditor.md`. **Whoever works #334, #337 or #290 after
     this lands must re-baseline against a corpus with no A5**: the check,
     its fixtures (`a5bad`/`a5good`), its `--json` finding id, its plain-text
     summary line, its mutation proof, and its `agent-auditor.md` entry are
     all gone, and the script header's "six anomaly checks (A1-A6)" becomes
     "five (A1-A4, A6)". This ground has shifted; that is recorded here
     rather than discovered later.
  3. **A5 is not renumbered.** A6 keeps its id. Renumbering would silently
     invalidate every historical finding record and every cross-reference in
     #337's and #290's plans.
- **R11 — Adapter parity is a merge gate, not a nicety.**
  `tests/adapter-protocol-parity.test.js` fails closed on an unmapped
  canonical section *and* on a stale map key. Steps 11 and 17 must carry
  paired `codexMap`/`cursorMap` edits or `bash tests/validate.sh` goes red
  for reasons unrelated to their actual subject.
- **R12 — Step 14 has one unresolved sub-decision (OQ-N1).** The step is
  fully authored and dispatchable against the recommended default; only
  criterion C14.2 changes if the operator answers otherwise. `task-master`
  should not gate the whole unit on it — see OQ-N1.
- **R13 — `gh346-1` has FAILed review once; R8's precondition must be
  re-checked at dispatch time, not read off this document.** This is the
  operational consequence R6's census points at. State verified at this
  document's finalization (2026-08-13, tree at `d1f232f`):
  1. **The record.** `.claude/reviewed/gh346-1.fail` exists, written
     `2026-08-13T21:52Z` against `d1f232f`. **No `gh346-1.pass` stands
     beside it**, and **no `gh347` marker of either kind exists at all.**
     Both #346 and #347 are still `OPEN` with `ready-for-agent`. Marker
     directory total is unchanged at 226 files, so nothing has resolved
     since R6's second-pass census.
  2. **The FAIL is not a code defect, and must not be read as one.** The
     record states that all nine of unit gh346-1's acceptance criteria
     (AC1.1-AC1.9) were verified green at `d1f232f` *and* re-verified
     against a pristine `git archive HEAD` extraction, so they are satisfied
     by committed content rather than by working-tree state. The sole
     ground was the v3 marker's committed-state precondition:
     `git diff --quiet HEAD` exited 1 because eight tracked files carried
     uncommitted changes — two of them the unit's own `lead-programmer`
     agent-memory writes, made *after* its commit, and six belonging to
     other agents entirely. The record closes with an explicit
     "no code defect was found. ... Do not change `bin/cli.js` or the
     tests." **The remedy is a commit and a re-review, not a re-implementation.**
  3. **R8 is unchanged, unmet, and not weakened by any of this.** R8's
     precondition is a *current `.pass`* on both #346 and #347 — not "work
     attempted", not "implementation landed", and not "the FAIL was only
     hygiene". A `.fail` is not a `.pass`. **No unit of this spec is
     dispatchable until both dependencies carry a `.pass`.**
  4. **Whoever dispatches re-checks the precondition live.** `task-master`
     and the orchestrator must satisfy R8 by listing the marker directory
     for `gh346*` and `gh347*` at the moment of dispatch. This document's
     snapshot is authoring-time evidence with a known expiry: the FAIL's
     remedy was already in progress when this was written, so the state is
     *expected* to have moved by the time anyone reads it. Re-derive it;
     do not quote item 1 back as if it were current.
  5. **No gh348 unit's model tag changes because of it.** R6's finding
     stands: `gh346-1` is not a gh348 unit, so the shared protocol's
     `.fail`-record screen and the implementer-tier ratchet do not reach
     any step below. `task-master` must not up-tag a gh348 unit on account
     of this record, and must not down-tag one either.
  6. **One genuine second-order consequence for this spec's own 18 units.**
     The failure mode was working-tree hygiene at review time, and it
     generalizes: per R2 *every* step here ends in a commit and is reviewed
     under the same v3 committed-state precondition, while personas on this
     surface write agent memory as a matter of course. **Each unit must
     commit its own memory writes before reporting ready-for-review**, and
     a reviewer that finds the tree dirty from *another* agent's files
     should say so rather than attributing them to the unit. Verified at
     finalization: `git diff --quiet HEAD` now exits 0 (the tracked half
     has been committed); the residue is untracked files only, which that
     precondition does not see. The stray `.claude/settings.local.jso`
     among them is the user-owned file the Rejected-findings table already
     flags for the operator — not an agent's to delete.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every finding re-verified against
  the tree; five of the audit's or the draft's claims corrected as a result
  (2.1's proposed wording, 2.3's severity, 1.10's premise, the draft's
  claim that A5 is A1's mutation-proof *partner*, and the draft's
  attribution of the #346 dependency to finding 1.6 rather than 2.3). Every
  acceptance criterion added in this revision was executed against the tree
  and confirmed RED before being written.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no
  step hand-edits a rendered mirror; all mirrors regenerate via
  `node bin/cli.js --update`.
- P3 "Version-stamp discipline": satisfied — every step bumps
  `.claude-plugin/plugin.json` and adds a CHANGELOG entry (see R2).
- P4 "Optional personas degrade gracefully" (SHOULD): **satisfied by
  rejecting finding 1.10.** #348 proposes pruning the orchestrator's
  "if present / if no X exists" fallback branches because this deployment
  installs all 7 optional personas. That is precisely what P4 forbids —
  the branches exist so a project that skips a persona does not ship broken
  prose. 1.10 is rejected on constitutional grounds, not deferred. Note
  `tests/validate.sh:155-185` mechanically enforces this for
  scribe/reviewer/researcher/agent-auditor, so 1.10 is also unimplementable
  without weakening a live merge-gate check.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every step's
  acceptance criteria include `bash tests/validate.sh`.

## Issue disposition

Verified by reading each canonical plan doc and each issue body. Nothing in
this table is conditional; every row states a firm, final action.

| Issue | Overlap with #348 | Final action |
|---|---|---|
| #345 human-decision gate marker template | **Partial** — its own scope was complete (`gh345-1.pass`, `gh345-2.pass` both exist, no `.fail`), but its landed patch left the charclass narrower than the dispatch grammar, which is #348's finding 2.3. | **CLOSED already** (verified 2026-08-13, `state: CLOSED`), by the orchestrator. Not a dependency. 2.3 is net-new follow-on work, landing as Step 7. |
| #346 `--update` hook propagation | **No overlap** in scope. Its Step 2 creates `.claude/hooks/scripts/human-decision-gate.sh`, the mirror Step 7's source edit needs. **Status corrected on re-verification:** that mirror now exists — `d1f232f` (current HEAD) landed the implementation. Issue still `OPEN`, no `.pass` marker. | **STILL BLOCKS this spec** (R8). Implementation has landed; **reviewer-PASS has not**. Land the review before any gh348 unit dispatches. Closed by the orchestrator, not by this spec. |
| #347 reviewer-dispatch caller allowlist | **No overlap** in substance — it edits `reviewer-route-gate.sh` and step 4 of orchestrator's `ESCALATE-TO-HUMAN` section. #348's 2.4 edits a *different* region of `agents/orchestrator.md` (the dispatch-naming warning, source line 134). File collision, not scope collision. | **BLOCKS this spec.** Land and reviewer-PASS before any gh348 unit dispatches (R8). Closed by the orchestrator, not by this spec. |
| #334 (covers #288) Write/Edit content asymmetry | **No overlap** with 2.1. Its subject is `reviewed-path-gate.sh`'s *Write/Edit* path; it explicitly does **not** edit that hook, does **not** touch `templates/`, and ratifies a no-content-scan ADR. **But its Step 1 collides with Step 18** — both edit `scripts/agent-audit.sh` and `tests/agent-auditor.test.sh`. | **Leave open.** Whoever picks it up after Step 18 lands must re-baseline against an A5-free corpus (R10.2). |
| #335 / #336 / #338 / #339 `--update` flag surface | **No overlap.** All edits are inside `runUpdate` (`bin/cli.js:827-1131`); this spec edits `PROTOCOL_SECTIONS_BY_PERSONA` and `UNIVERSAL_PROTOCOL_CORE` (`bin/cli.js:515-700`). Disjoint regions of one file. | **Leave open, unrelated.** |
| #337 agent-audit accuracy/calibration | **Direct collision** with Step 18 — same anomaly-check subsystem, same three files. | **Leave open.** Re-baseline against an A5-free corpus after Step 18 (R10.2). The operator chose to proceed rather than defer Step 18 behind it. |
| #290 agent-auditor.md corrections | **Direct collision** with Step 18 — same file. | **Leave open.** Same treatment as #337. |
| #292, #275, #276, #277, #278, #279 | **No overlap.** Checked: #292 edits `bin/cli.js:1904` (ADAPT wizard string, disjoint region); #275 is a render-warning false positive; #276 is orchestrator frontmatter YAML (this spec edits body prose only); #277-#279 are dispatch-hygiene/review-join runtime stamps. | **Leave open, unrelated.** |

**On the #334 / 2.1 hypothesis specifically.** #334's plan resolves issue
#288 by *rejecting* content scanning and closing the detection gap in
`scripts/agent-audit.sh` (new sections A7/A8). It adds no hook change and
its criterion C2.9 explicitly asserts that no path under `agents/` or
`templates/` is touched. Implementing #334 therefore neither fixes nor
subsumes 2.1: the false "read-only ones included" sentence would survive
#334 verbatim in all three of its locations. 2.1 remains a distinct step
(Step 3).

## Findings triage

Verified status of all 24 findings plus N1, with the final disposition.
"Corrected" marks a finding where independent verification changed the
audit's claim. **Nothing in these tables is conditional.**

### Accepted into this spec — 22 findings + N1

| # | Verified | In which step |
|---|---|---|
| 1.1 | Confirmed — orchestrator's row is `drop: []`, carrying all 18 sections. **Corrected**: two of the four proposed drops are unsound as stated; option (a) takes three of four | Step 11 |
| 1.2 | Confirmed — DECISION template appears 3x in `reviewer.md`, 3x in `orchestrator.md`, 2x in the template | Step 4 |
| 1.3 | Confirmed — microworld section (42 lines) in 5 personas | Step 4 |
| 1.4 | Confirmed — expired 2026-07-27 text live in 7 files, 17 days dead | Step 1 |
| 1.5 | Confirmed — `agents/orchestrator.md:496` | Step 5 |
| 1.6 | Confirmed verbatim — "The script checks this too, but you check it as a belt-and-suspenders backstop"; `reviewer-tier.sh:73-75` is fail-closed. **Corrected — broader**: deleting it dangles the surviving `Escalation.` paragraph's back-reference at `orchestrator.md:355` | Step 13 |
| 1.7 | Confirmed — `agents/reviewer.md` frontmatter preloads `antislop:coding-discipline` | Step 6 |
| 1.8 | Confirmed — ~30 lines of Write/Edit fallback in a slim template with no trimming seam, and `scribe` genuinely holds Write/Edit (`agents/scribe.md:7`) | Step 12 |
| 1.9 | Confirmed — `orchestrator.md:94` ≡ `task-master.md:144` | Step 5 |
| 2.1 | Confirmed at 3 sites. **Corrected**: the audit's proposed replacement ("blocks any non-read-only Bash command") is also false | Step 3 |
| 2.2 | Confirmed. **Corrected — broader**: `lead-programmer.md:293` also dangles, which the audit missed | Step 2 |
| 2.3 | Confirmed. **Corrected — lower severity**: latent, never fired | Step 7 |
| 2.4 | Confirmed — `agents/orchestrator.md:134` vs `reviewer-route-gate.sh:71-72` | Step 5 |
| 2.5 | Confirmed. **Corrected — broader**: ADR-0006:34,41 and ADR-0010:76 carry the same dead policy, not just ADR-0004:33 | Step 8 |
| 2.6 | Confirmed (cosmetic) | Step 2 |
| 2.7 | Confirmed (cosmetic) | Step 5 |
| 3.1 | Confirmed — carve-out in `orchestrator.md:17-18`, `task-master.md:18-19`, `spec-master.md:180` | Step 9 |
| 3.2 | Confirmed — rephrasing doctrine in all 10 personas + both templates. **Corrected**: the "refusal text is complete" premise was verified first-hand this session, not assumed | Step 17 |
| 3.3 | Confirmed — 35-line gate, 2 `AskUserQuestion` mentions. **Corrected — narrower than F10**: 3.3 removes the checkpoint, not the audit | Step 15 |
| 3.4 | Confirmed — 111 lines of routing prose; the two collapsible subsections are 40 + 11 lines. **Corrected**: also reverses ADR-0013:22, which the draft missed | Step 14 |
| 3.5 | Confirmed, **split**: the protocol-compression half rides Step 4; the "drop A5" half is Step 18. **Corrected**: A1's mutation proof stands alone — A5 is not its structural partner | Steps 4 + 18 |
| 3.6 | Confirmed — three-way graph freshness; `hooks/hooks.json:7` registers `graph-update.sh`, `.git/hooks/pre-commit` verified installed, `agents/orchestrator.md:405-412` is the manual third | Step 16 |
| N1 | **Net-new, not in #348** — `CONTEXT.md:202` and `.claude/wiki/protocol-delivery-tiers.md:24,54` claim 16 canonical sections; there are **18**. The wiki's enumeration lists a section that no longer exists ("Reviewer roast-work advisory pass trigger") and omits three that do; it says slim has 6 sections, actual is **7** | Step 10 |

### Rejected — 2 findings

| # | Why |
|---|---|
| 1.10 | **Violates constitution P4** (optional personas degrade gracefully). The conditional branches are required, not dead — and `tests/validate.sh:155-185` mechanically enforces exactly this phrasing for four of the personas, so implementing 1.10 would require weakening a live merge-gate check. Also factually off: 15 branches, not 17. **Not reversible by operator preference** — this is the one rejection grounded in the constitution rather than in a prior ruling |
| 3.7 | Not an implementable finding — it is a process recommendation ("adopt refusal-text-is-the-documentation"; "move incident narratives to ADRs"). Its concrete sub-items are already covered: the expired grace text is Step 1, the gh-304 triple-restatement is Step 5, and Step 17 *is* refusal-text-is-the-documentation applied concretely. The stray untracked `.claude/settings.local.jso` is a user-owned file; flagged for the operator, not deleted by an agent |

## Steps

Eighteen units. Ordering is load-bearing:

- Step 2 before Step 4 and Step 11 (R3 — the cross-reference guard must
  exist before any further excerpt drop).
- Step 11 before Step 12 before Step 17 (the section split creates the seam;
  the slim cut removes the slim copy; the compression then targets the full
  template alone).
- Step 14 before Step 15 (Step 14 removes the citation whose referent Step
  15 deletes).
- Step 11 and Step 17 both change the canonical section list, so Step 10
  (documentation of that list) lands **after** both. Its criteria are
  written as equalities for exactly this reason.
- Every step is one unit bundling source edit + `--update` + version bump +
  CHANGELOG (R1, R2).
- **Nothing dispatches until #346 and #347 are reviewer-PASSed (R8).**

**Standing rule for every `grep`-based criterion below — line-join first.**
These files are hard-wrapped prose. A multi-word phrase can and does split
across a line break, and a line-based `grep -c` then reports zero matches
for text that is plainly present. This is not hypothetical: it was measured
twice while writing this spec (`agents/orchestrator.md:16-17` splits "any
debug-spec / re-derivation", and
`tests/adapter-protocol-parity.test.js:125-126` splits "three / personas
receive"), and in both cases the obvious criterion would have gone green
against unfixed text. **Unless a criterion says otherwise, evaluate every
phrase search on the line-joined normalization**
`tr '\n' ' ' < "$f" | tr -s ' '` — the idiom Pass 3 established for exactly
this reason. Two caveats the executing unit must respect: line-joining does
**not** rescue a phrase split by a comment prefix (`// `, `# `), which needs
a single-line anchor instead (see C12.5); and a criterion scoped by `sed -n
'/START/,/END/p'` must join *after* extracting, not before.

### Step 1 — Delete the expired legacy-marker grace-period paragraph (1.4)

Affected files: `templates/persona-protocol.md`; regenerated mirrors
`.claude/agents/{orchestrator,reviewer,lead-programmer,spec-master,task-master,milestone-auditor}.md`
and `.claude/persona-protocol.md`; `.claude-plugin/plugin.json`;
`CHANGELOG.md`; `.claude/persona-config.json` (`fileHashes`).

Do NOT touch: `hooks/scripts/task-gate.sh` (the expiry handling stays; only
the prose describing it goes).

Acceptance criteria:
- C1.1 `grep -rc "2026-07-27" templates/ .claude/agents/ agents/` returns 0
  for every file.
- C1.2 `grep -rc "legacy-marker grace period" templates/ .claude/agents/`
  returns 0 for every file.
- C1.3 `git diff --exit-code hooks/scripts/task-gate.sh` exits 0.
- C1.4 `bash tests/validate.sh` exits 0.
- C1.5 Version bump, stated **relatively so it cannot go vacuous**:
  `.claude-plugin/plugin.json` and `package.json` carry the *same* version;
  that version is strictly greater than the one at this unit's base commit
  (`git show <base>:.claude-plugin/plugin.json`); and it equals the topmost
  `## [x.y.z]` heading in `CHANGELOG.md`, whose entry names this change.
  *(Rewritten. The original form hardcoded `> 0.31.27`, and `d1f232f`'s bump
  to **0.31.28** made it vacuously true — it would have passed with no bump
  at all. Every later step states "version bumped" with no literal and is
  unaffected. See CHK25.)*

### Step 2 — Make cross-section references self-contained, and guard them (2.2, 2.6)

The root cause of 2.2 is that `selectProtocolSections` drops sections
without checking whether surviving text points into them. Two halves, one
unit: fix the existing dangles by making each reference self-contained, then
add the build-time guard so the class cannot recur (this is what makes Steps
4 and 11's further drops safe).

Affected files: `templates/persona-protocol.md`, `bin/cli.js`
(cross-reference validation next to `assertProtocolMatrixComplete`), a new
test file, `tests/validate.sh`, plus mirrors/version/CHANGELOG.

Do NOT touch: `PROTOCOL_SECTIONS_BY_PERSONA`'s row contents (Step 4 and Step
11 own those); no section is added or removed from the canonical list here.

Acceptance criteria:
- C2.1 For each of `reviewer`, `spec-master`, `task-master`,
  `milestone-auditor`, `lead-programmer`: the rendered mirror contains no
  reference to a WIP sentinel that is not accompanied, in that same mirror,
  by the sentinel's file path (`.claude/wip-handoff.<agent-id>`) and its
  non-empty-reason requirement. Verified by a test asserting that any mirror
  matching `WIP sentinel` also matches `wip-handoff`.
- C2.2 No mirror contains the string `"Fourth verdict" below` unless that
  mirror also contains a line matching `^## Fourth verdict`. Same assertion
  for `"Third verdict"`. This currently fails for `spec-master`,
  `task-master`, `milestone-auditor`, and `lead-programmer` — the test must
  be shown red before the fix and green after.
- C2.3 A new automated check rejects a matrix row whose `include` set
  retains a section whose text names a `## ` header in that row's `drop`
  set. Non-vacuity: the check must be demonstrated failing on a synthetic
  matrix row that reproduces today's reviewer/WIP-sentinel dangle, and that
  demonstration must be part of the test file.
- C2.4 The `<!-- ANTISLOP:BEGIN persona-protocol -->` header comment no
  longer claims the block is "Role-agnostic content only" (2.6); the
  replacement wording states accurately that the block is trimmed per
  persona and does contain role-specific sections.
- C2.5 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry.

### Step 3 — Correct the false `reviewed-path-gate.sh` description (2.1)

**The audit's proposed replacement is itself wrong and must not be used.**
The audit recommends "blocks any non-read-only Bash command". Verified
live during this spec's authoring — and re-confirmed during this revision,
where two of my own read-only-looking commands were refused: a purely
read-only `head -1 <marker> ... 2>&1` was blocked (a redirect disqualifies),
and `sed`, `awk`, `git`, and `rg` are not allowlisted at any subcommand. The
gate's actual predicate is `command_is_provably_benign()` — an allowlist of
programs (`ls cat head tail wc stat file test [ grep diff cmp sha256sum
md5sum basename dirname readlink realpath echo printf`, plus `gh
issue|pr|search`) with no redirect, substitution, or unlexable construct.

Affected files: `templates/persona-protocol.md` (~line 370),
`agents/reviewer.md` (body, ~line 198), `agents/orchestrator.md` (body),
plus mirrors/version/CHANGELOG.

Do NOT touch: `hooks/scripts/reviewed-path-gate.sh`,
`hooks/scripts/lib/benign-command.sh`. This step is prose-only.

Acceptance criteria:
- C3.1 `grep -rc "read-only" templates/persona-protocol.md agents/reviewer.md
  agents/orchestrator.md` shows no surviving claim that read-only commands
  are blocked.
- C3.2 The replacement sentence in each of the three locations names the
  actual predicate — it must contain the phrase `provably benign` (or name
  `command_is_provably_benign`), and must not assert that read-only
  inspection is blocked.
- C3.3 The surviving *conclusion* is preserved and still correct in all
  three locations: the escalation packet must not be sited under the marker
  directory, because executing a `run.sh` there is not a benign command.
  A reviewer verifies this claim is still stated, not merely that the old
  sentence is gone.
- C3.4 `git diff --exit-code hooks/scripts/reviewed-path-gate.sh` and
  `git diff --exit-code hooks/scripts/lib/benign-command.sh` both exit 0.
- C3.5 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry.

### Step 4 — Trim duplicated excerpt sections (1.2, 1.3, and 3.5's protocol half)

Depends on Step 2. A `PROTOCOL_SECTIONS_BY_PERSONA` drop-list edit only —
no prose rewrite. Each drop is justified by a surviving copy named here:

- reviewer: drop `Fourth verdict: escalate-to-human` (its body carries the
  full escalation procedure at `agents/reviewer.md:165-254`) and
  `Microworld bundles` (its body states its whole duty at lines 57-66).
- orchestrator: drop `Third verdict` / `Fourth verdict` (body lines
  176-235) and `Microworld bundles` (it neither authors nor verifies
  bundles).
- spec-master, task-master: drop `Microworld bundles`.
- lead-programmer: **retains** the full microworld schema — it is the
  author.

Affected files: `bin/cli.js` (`PROTOCOL_SECTIONS_BY_PERSONA` only), mirrors,
version, CHANGELOG.

Do NOT touch: `templates/persona-protocol.md` (no canonical section is added
or removed here, so no adapter-parity map edit is needed);
`UNIVERSAL_PROTOCOL_CORE` (Step 11 owns it); the protected STATUS-line
rationale paragraph at `templates/persona-protocol.md:154`.

Acceptance criteria:
- C4.1 Step 2's cross-reference guard passes for every persona row after the
  drops — the guard, not a human reading, is what proves no new dangle.
- C4.2 `.claude/agents/lead-programmer.md` still contains the `functions[]`,
  `inputs`, and `location` field definitions; the other four mirrors do not.
- C4.3 Each trimmed mirror retains a one-line pointer to where the dropped
  content lives (for microworlds, `lead-programmer.md` / ADR-0017).
  Verified by a reviewer reading each trimmed mirror, not by a grep.
- C4.4 Measured saving is recorded in the CHANGELOG entry: `wc -w` before
  and after for each of the five mirrors.
- C4.5 `bash tests/validate.sh` exits 0; version bumped.

### Step 5 — Orchestrator body corrections and deletions (1.5, 1.9, 2.4, 2.7)

Finding 1.6 is **excluded** from this step and lands as its own unit (Step
13), because reversing a byte-pinned anti-regression control deserves an
isolated, individually-reviewable diff rather than a line inside a
four-finding step.

Affected files: `agents/orchestrator.md`, `agents/task-master.md`, and a
destination doc for the relocated deferral record (a new `docs/adr/` entry
at the next unused number — **never** backfilling the `0007` hole — or an
appendix in this plan doc; the executing unit picks one and states which),
plus mirrors/version/CHANGELOG.

Do NOT touch: the three byte-pinned safety paragraphs of § "Reviewer gate
model selection"; `hooks/scripts/reviewer-tier.sh`; the `## Milestone audit
gate`, `## Graph freshness` and `## Per-unit model routing` sections (Steps
13-16 own those).

Acceptance criteria:
- C5.1 (1.5) `grep -c "Deferred: mechanical report-loss backstop"
  agents/orchestrator.md` returns 0, and the relocated content exists at the
  named destination with its investigation notes intact.
- C5.2 The three byte-pinned safety paragraphs of § "Reviewer gate model
  selection" (`Downgrade-only asymmetry`, `` `.fail` disqualifier ``,
  `Escalation.`) are **unchanged** by this step — the same anti-regression
  control Pass 3 applied, re-run here. `hooks/scripts/reviewer-tier.sh` is
  likewise unmodified (`git diff --exit-code` exits 0). *(Step 13, and only
  Step 13, is licensed to change the second of the three.)*
- C5.3 (2.4) The dispatch-naming warning no longer claims a mis-named
  reviewer dispatch fails *silently*: `grep -c "persists in no durable
  record" agents/orchestrator.md` returns 0. The replacement names the
  actual residual (harness name-collision auto-suffixing, which
  `reviewer-route-gate.sh` cannot see at dispatch time) and the reviewer's
  mirror-image paragraph in `agents/reviewer.md` is updated consistently.
  A reviewer confirms the new text is true against
  `reviewer-route-gate.sh:71-72`.
- C5.4 (1.9) The dispatch-hygiene rules exist in one canonical location with
  a pointer from the other; the `Unit:` grammar
  `[A-Za-z0-9][A-Za-z0-9._#-]{0,63}` is stated in exactly one persona-facing
  place. Both `orchestrator` and `task-master` still carry rule 3 (both
  dispatch gated agents).
- C5.5 (2.7) The absolute "You have no Write/Edit tool — anything requiring
  a file change routes to the lead-programmer, however trivial" is rephrased
  so it does not read as forbidding the orchestrator's own documented Bash
  writes (`.claude/.dispatch-override`, the `defer:` flag write). Both
  escape hatches remain documented.
- C5.6 The gh-304 triple-restatement (source lines 134-140: naming rule,
  re-tasking discipline, roster check) is consolidated to at most two
  paragraphs with no rule lost — each of the three rules must still be
  findable by a reviewer.
- C5.7 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry.

### Step 6 — Remove `antislop:coding-discipline` from the reviewer (1.7)

Affected files: `agents/reviewer.md` frontmatter, mirror, version, CHANGELOG.

Do NOT touch: the reviewer's body; the other two preloaded skills.

Acceptance criteria:
- C6.1 `agents/reviewer.md`'s `skills:` line lists exactly
  `antislop:roast-work, antislop:ubiquitous-language`.
- C6.2 The reviewer's body contains no instruction that depends on the
  removed skill — verified by grepping the body for `coding-discipline` and
  confirming 0 matches.
- C6.3 `bash tests/validate.sh` exits 0 (its frontmatter-shape check is the
  historically-worst bug class per constitution P5); version bumped.

### Step 7 — Widen the marker-filename charclass to match the dispatch grammar (2.3)

**Protected path, security-sensitive — heavy unit, opus reviewer (R4).**
**Blocked on #346** (R8, R13) — but **not** for the reason the draft gave.
*Premise corrected at finalization:* `.claude/hooks/scripts/human-decision-gate.sh`
**now exists** and is byte-identical to its source (`diff` exits 0), created
by `d1f232f`. What still blocks this step is #346's *review*, not its
implementation: no `gh346-1.pass` exists and the unit has FAILed once on
working-tree hygiene (R13). This step must still move source and mirror
together in one unit (R1).

Affected files: `hooks/scripts/human-decision-gate.sh` (the
`is_sanctioned_marker_write()` regex at line 53), its test suite, and
`.claude/hooks/scripts/human-decision-gate.sh` (the mirror #346 creates).

Do NOT touch: the gate's `is_decision_path()` logic; the 22 existing attack
cases; `hooks/scripts/reviewed-path-gate.sh`.

Acceptance criteria:
- C7.1 The marker-filename charclass accepts the same id grammar the
  dispatch gates accept, minus the characters the traversal argument
  genuinely requires excluding. Concretely: a sanctioned write to
  `.claude/reviewed/gh345.1.pass` and to `.claude/reviewed/gh#348.pass` is
  accepted, while `../escape`, a leading `.`, and any id containing `/`
  remain refused.
- C7.2 The existing 22-case attack suite still passes unchanged — no case is
  weakened or deleted to accommodate the widened charclass.
- C7.3 New cases cover: a `.`-containing id, a `#`-containing id, a
  traversal attempt using the newly-allowed `.` (e.g. `gh..345`), and a
  leading-`.` id. Mutation proof: reverting the regex change must make at
  least one new case fail.
- C7.4 The four safety properties named in the function's header comment
  (`hooks/scripts/human-decision-gate.sh:45-50`) still hold and the comment
  is updated to state the widened charclass and why traversal is still
  impossible.
- C7.5 Source and mirror are byte-identical after `--update`:
  `diff hooks/scripts/human-decision-gate.sh .claude/hooks/scripts/human-decision-gate.sh`
  exits 0.
- C7.6 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry.

### Step 8 — Annotate superseded fable-roast-pass policy in three ADRs (2.5)

The audit named only ADR-0004. Verification found the same dead policy in
two more accepted ADRs, neither marked:

- `docs/adr/0004-...:33` — "Task-master tags heavy units with an advisory
  `Roast pass: fable` marker … and the orchestrator honors it at dispatch."
  Removed by ADR-0013, which states it "**Supersedes ADR-0004 § Decision
  Tension 2**". Directly contradicts `agents/task-master.md:68-70`.
- `docs/adr/0006-...:34-35` — "Fable stays confined to the separate advisory
  `Roast pass: fable` dispatch defined in ADR-0004, **unchanged**." Now
  false. Its Status line reads "amends ADR-0004; does not supersede it".
- `docs/adr/0010-...:76` — "A haiku-implemented unit satisfying the heavy
  criteria still receives the advisory fable roast pass." Now false.

Affected files: those three ADRs. In-place annotation has precedent —
ADR-0004 already carries a "Cost claim superseded" note at line 51.

Do NOT touch: ADR-0013 (Step 14 annotates it, for a different reason); the
`0007` number hole; any persona file.

Acceptance criteria:
- C8.1 Each of the three passages carries an inline marker naming ADR-0013
  as the superseding decision. Reviewer confirms each annotation sits
  adjacent to the dead text, not only in a footer.
- C8.2 No ADR body text is deleted (ADRs are an append/annotate record).
  `git diff` shows additions only in these three files.
- C8.3 No new ADR number is allocated, and the `0007` hole is untouched.
- C8.4 A reader following the pointer from `agents/reviewer.md:176-179` to
  ADR-0004's heavy-unit trigger encounters the supersession marker before
  the dead tagging instruction. Reviewer-verified by reading the rendered
  section in order.
- C8.5 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry.

### Step 9 — Route debug specs through the ≤2-unit fast path (3.1)

**Accepted unconditionally** (operator ruling 2026-08-13; reverses Pass 3
Step 9's carve-out — R9.3).

Deletes the `any debug-spec re-derivation` carve-out so a 1-unit debug spec
uses the fast path spec-master already owns, saving a full `task-master`
dispatch per 2-FAIL-capped unit.

**The draft undercounted the carve-out's locations, and the phrasing is not
uniform — re-verified 2026-08-13.** There are **four** statements across
**four** files, and only two of them use the searchable phrase:

| Location | Exact wording today |
|---|---|
| `agents/orchestrator.md:16-17` | "any debug-spec re-derivation" — **wrapped across a line break** |
| `agents/orchestrator.md:239` | "any debug-spec re-derivation" |
| `agents/task-master.md:17` | "any debug-spec re-derivation" |
| `agents/task-master.md:25` | "any debug-spec re-derivation" |
| `agents/spec-master.md:189` | "**Standard path (≥3 units, debug spec, Convergence follow-ups)**" |
| `templates/persona-protocol.md:479` | "which flows back through `task-master` for re-dispatch" |

Two separate traps here, both measured:

1. **A line-based `grep -c` undercounts.** The occurrence at
   `agents/orchestrator.md:16-17` is split mid-phrase ("...any debug-spec" /
   "re-derivation, or any..."), so `grep -c "debug-spec re-derivation"
   agents/orchestrator.md` returns **1** while the true count is **2**. A
   naive `== 0` criterion would go green with a live carve-out still shipped
   in the orchestrator's opening routing bullet — the most-read paragraph in
   the file. Every criterion below that searches a multi-word phrase uses
   the line-joining idiom Pass 3 established (`tr '\n' ' ' | tr -s ' '`).
2. **Two locations do not contain the phrase at all.**
   `agents/spec-master.md` and `templates/persona-protocol.md` state the same
   rule in different words, so no amount of grepping for
   `debug-spec re-derivation` will ever see them. Each gets its own
   locally-anchored criterion.

**This is a template-editing step.** `templates/persona-protocol.md:474-482`
("Cap at 2 FAILs per unit") is inside the `## Continuing after a FAIL
verdict` canonical section, which is `include`d by orchestrator,
lead-programmer, spec-master and milestone-auditor — so the stale rule
currently reaches four personas twice over. No `## ` header changes, so no
adapter-parity map edit is needed; verified that neither
`adapters/codex/agents-md-fragment.md` nor
`adapters/cursor/rules/persona-protocol.mdc` carries this sentence, so
neither port needs a matching edit.

Affected files: `agents/orchestrator.md` (line 239 and the 2-FAIL-cap
section ~210-222), `agents/task-master.md` (lines 17 and 25),
`agents/spec-master.md` (line 189's Standard-path clause and the
debug-spec bullet), `templates/persona-protocol.md` (line 479), plus all
rendered mirrors, `.claude/persona-protocol.md`, version, CHANGELOG.

Do NOT touch: `## Convergence follow-ups` routing, which stays
mandatory-through-task-master in all four locations — it is named in the
same breath as the debug-spec carve-out everywhere and is the single most
likely thing to be deleted by accident; the ≥3-unit threshold itself; the
adapter ports.

Acceptance criteria:
- C9.1 **Line-join normalized**, per trap 1 above: for each of
  `agents/orchestrator.md`, `agents/task-master.md`,
  `agents/spec-master.md` and `templates/persona-protocol.md`,
  `tr '\n' ' ' < "$f" | tr -s ' ' | grep -c "debug-spec re-derivation"`
  returns 0. *(Baseline, re-measured at finalization. `grep -c` on a
  line-joined file is a **boolean** — the file is one line, so it returns 0
  or 1, never a tally. Joined `grep -c`: orchestrator = **1**, task-master =
  **1**, spec-master = 0, template = 0. The underlying **occurrence** counts,
  via `grep -o ... | wc -l`, are orchestrator = **2**, task-master = **2**.
  An earlier revision recorded the occurrence counts as if they were the
  criterion's return value; corrected here — see CHK26. The line-joining is
  still load-bearing and must not be dropped: a naive line-based `grep -c`
  also returns 1 today, but it falls to 0 as soon as the unwrapped occurrence
  at `orchestrator.md:239` is fixed, going green while the wrapped one at
  lines 16-17 still ships. The joined form stays at 1 until **both** are
  gone.)*
- C9.2 `agents/spec-master.md`'s Standard-path clause no longer names debug
  specs: `grep -c "≥3 units, debug spec" agents/spec-master.md` returns 0.
  *(Baseline: 1 — this location is invisible to C9.1's phrase.)*
- C9.3 `templates/persona-protocol.md`'s "Cap at 2 FAILs per unit" paragraph
  no longer routes the debug spec through `task-master`:
  `sed -n '/Cap at 2 FAILs per unit/,/^$/p' templates/persona-protocol.md |
  grep -c "task-master"` returns 0. *(Baseline: 1 — this location is also
  invisible to C9.1.)* The paragraph must still route to `spec-master` for
  the debug spec itself.
- C9.4 All four locations agree on the resulting rule — `task-master` is
  mandatory for ≥3 units and `## Convergence follow-ups` slices only. A
  reviewer confirms no file still names debug specs as a task-master
  trigger, and that the four statements are mutually consistent. **This is
  the failure mode this step is most likely to hit: fixing the two greppable
  locations and leaving the other two.**
- C9.5 `## Convergence follow-ups` still routes through `task-master` in all
  four locations — `grep -rc "Convergence follow-ups" agents/ templates/`
  is unchanged from its pre-step value, and a reviewer confirms the meaning
  survived the edit rather than the string merely surviving.
- C9.6 `agents/spec-master.md`'s debug-spec section states explicitly that a
  debug spec resolving to ≤2 units emits the nine-element dispatch contract
  directly, and that a debug spec resolving to ≥3 units still routes to
  `task-master`.
- C9.7 ADR-0003's hivemind split is not violated — a **survival pin**, not a
  deletion check: `agents/spec-master.md` still states that spec-master never
  runs `to-tickets` on any path.
  ``tr '\n' ' ' < agents/spec-master.md | tr -s ' ' | grep -c 'never run `to-tickets` on any path'``
  returns 1. *(Baseline: 1 — this criterion is RED-proof by mutation, not by
  its current value: deleting the prohibition makes it 0.)*
  **Rewritten — the draft's form was self-contradictory and would have caused
  the exact capability loss it claims to prevent.** It demanded
  `grep -c "to-tickets" agents/spec-master.md` return **0**, but all three
  live occurrences (lines 186, 191, 200) are correct statements, and line 186
  **is the ADR-0003 prohibition itself** ("You never run `to-tickets` on any
  path (ADR-0003 preserved)"); the other two correctly describe
  `task-master`'s slicing. Satisfying the old criterion literally would have
  deleted the rule it names. See CHK33.
- C9.8 The 2-FAIL-cap escalation path in `agents/orchestrator.md` **and** in
  `templates/persona-protocol.md` still routes to `spec-master` for a debug
  spec — the step removes the mandatory `task-master` hop, not the debug
  spec itself. Reviewer-verified against both rewritten passages.
- C9.9 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry.

### Step 10 — Correct the protocol-excerpt documentation drift (N1) [scribe]

**Lands after Steps 11 and 17**, both of which change the canonical section
list. Its criteria are equalities, not literals, for exactly this reason.

Affected files: `CONTEXT.md` (the **Protocol excerpt** entry, line 201),
`.claude/wiki/protocol-delivery-tiers.md` (lines 24, 33, 54), and — if the
mechanical check of C10.4 is added — `tests/validate.sh` plus a test file.

Do NOT touch: `templates/*` (this step documents the templates, it does not
change them); `bin/cli.js`.

Acceptance criteria:
- C10.1 Both documents state the correct canonical section count, equal to
  `grep -c "^## " templates/persona-protocol.md` **at the time this step
  lands** — the criterion is the equality, not a hardcoded literal.
  *(Baseline today: documented 16, actual 18.)*
- C10.2 The wiki's enumerated full-tier section list matches the template's
  actual `## ` headers exactly — no missing entries, and no entry naming a
  section that no longer exists (it currently lists "Reviewer roast-work
  advisory pass trigger", which is gone, and omits "Blocked by a gate you do
  not own", "Fourth verdict: escalate-to-human", and "Microworld bundles").
- C10.3 The slim-tier list matches `grep -c "^## "
  templates/persona-protocol-slim.md` (currently 7, documented as 6).
- C10.4 A test or `tests/validate.sh` check asserts C10.1/C10.3's equality
  so the drift cannot silently recur. If adding the check is
  disproportionate, the step states why and the criterion falls back to
  reviewer verification — but the default is the mechanical check.
- C10.5 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry.

### Step 11 — Orchestrator excerpt trim via an Agent-teams section split (1.1)

**Accepted, option (a)** (operator ruling 2026-08-13; partially reverses
Pass 1's "the table wins" — R9.1). Depends on Step 2 (R3).

**The status-line section is KEPT.** Its own text at
`templates/persona-protocol.md:137-179` was written expressly to forbid this
trim ("lives in the one shared section every persona carries"; the
main-session case is "a trigger condition, **not an exemption**"). Dropping
it is out of scope for this step and for this spec.

Three drops for `orchestrator`, one of which requires a template
restructure:

1. **`A note on memory`** — cleanly inert. The orchestrator has no `memory:`
   frontmatter; `bin/cli.js:544-547` already documents that its inclusion is
   a deliberate table override of the iff-frontmatter rule.
2. **`Microworld bundles (format and the check contract)`** — cleanly inert.
   The orchestrator neither authors nor verifies bundles. *(Step 4 already
   drops this for the orchestrator; if Step 4 has landed, this item is
   already satisfied and the step says so rather than re-doing it.)*
3. **The Write/Edit-fallback half of `Agent-teams mode`** — requires the
   split below, because trimming granularity is whole `## ` sections and the
   section's `SendMessage`/nested-teams bullets **do** apply to the
   orchestrator as team lead.

**Ordered edits:**

1. In `templates/persona-protocol.md`, split
   `## Agent-teams mode (only relevant if you were spawned as a teammate)`
   (lines 53-90) into two canonical sections at the natural seam:
   - `## Agent-teams mode (only relevant if you were spawned as a teammate)`
     keeps bullets 1-3 (`skills:`/`mcpServers:` non-application, foreground
     subagents vs nested teams, `SendMessage` reporting).
   - a **new** canonical section carries bullets 4-7 (the `Write`/`Edit`
     call-time rejection, the Bash-heredoc fallback, the
     `reviewed-path-gate.sh` command-text constraint and the two-gate
     rephrasing doctrine, and the grant-independence note). The executing
     unit picks the exact heading and states it; it must be a new `## `
     header, not a `### ` nested under the first.
2. In `bin/cli.js`, **remove the new fallback header from
   `UNIVERSAL_PROTOCOL_CORE`** (`bin/cli.js:515-522`) and add it explicitly
   to the `include` list of every full-tier row **except** `orchestrator`,
   whose row gains it in `drop`. This indirection is mandatory:
   `assertProtocolMatrixComplete` throws if a header appears in both a row's
   `include` and `drop` (`bin/cli.js:717-719`), and a `UNIVERSAL_PROTOCOL_CORE`
   spread puts it in `include` unconditionally.
3. In `bin/cli.js`, add `'A note on \`memory\`'` and
   `'Microworld bundles (format and the check contract)'` to the
   `orchestrator` row's `drop` (removing them from its `include`).
4. In `tests/adapter-protocol-parity.test.js`, add an entry for the new
   canonical header to **both** `codexMap` and `cursorMap`. Both already
   mark `Agent-teams mode` as `deferred` for their ports, so `deferred` with
   a matching justification is the consistent choice — but the entry must
   exist or `checkPort()` throws (R11).
5. Re-render: `node bin/cli.js --update`.

Affected files: `templates/persona-protocol.md`, `bin/cli.js`,
`tests/adapter-protocol-parity.test.js`, all rendered mirrors,
`.claude/persona-protocol.md`, `.claude/persona-config.json` (`fileHashes`),
version, CHANGELOG.

Do NOT touch: `templates/persona-protocol-slim.md` (Step 12 owns the slim
copy of this same doctrine); the `Terminal status line` section, in any
persona's row or in the template; the protected rationale paragraph at
`templates/persona-protocol.md:154`; `GATED_AGENT_SECTIONS`.

Acceptance criteria:
- C11.1 `grep -c "^## " templates/persona-protocol.md` returns exactly one
  more than before this step (18 → 19), and both new headers appear in
  `CANONICAL_PROTOCOL_HEADERS` order in the template.
  *(Baseline: 18.)*
- C11.2 `node -e "require('./bin/cli.js')"` loads without throwing — i.e.
  `assertProtocolMatrixComplete` and `assertGatedSectionsCanonical` both
  pass with the new header. Non-vacuity: temporarily leaving the new header
  in `UNIVERSAL_PROTOCOL_CORE` *and* the orchestrator's `drop` must make
  this throw; the executing unit demonstrates that throw once and records
  the message.
- C11.3 `.claude/agents/orchestrator.md` contains **none** of: the
  `<tool> exists but is not enabled in this context` string, the
  `A note on \`memory\`` header, or the `Microworld bundles` header.
  *(Baseline: all three present.)*
- C11.4 `.claude/agents/orchestrator.md` **still** contains
  `STATUS: complete` and the `SendMessage` teammate-reporting bullet — the
  kept halves, proving the split did not overshoot.
- C11.5 Every other full-tier mirror still contains the
  `<tool> exists but is not enabled in this context` string — the fallback
  doctrine reached everyone it reached before, minus the orchestrator.
- C11.6 Step 2's cross-reference guard passes: no surviving orchestrator
  text points into a section the split dropped. Specifically,
  `.claude/agents/orchestrator.md` contains no unresolved reference to the
  Write/Edit fallback (a reviewer confirms the claim; the guard proves the
  mechanical half).
- C11.7 `node tests/adapter-protocol-parity.test.js` exits 0. Non-vacuity:
  removing the new map entry from either port map must make it fail.
- C11.8 Measured saving recorded in the CHANGELOG: `wc -w
  .claude/agents/orchestrator.md` before and after.
- C11.9 `bash tests/validate.sh` exits 0; version bumped.

### Step 12 — Slim-tier Write/Edit fallback trim, with a scribe-only line (1.8)

**Accepted, option (a)** (operator ruling 2026-08-13). Lands after Step 11
and before Step 17.

The slim tier has no per-persona trimming seam
(`selectProtocolSections` throws for it by design, `bin/cli.js:737-738`), so
the cut hits explorer, researcher, agent-auditor **and** scribe. Scribe is
the one slim persona that genuinely holds `Write, Edit` (verified,
`agents/scribe.md:7`), so the doctrine it needs is re-homed into
`agents/scribe.md` rather than deleted outright.

**Ordered edits:**

1. In `templates/persona-protocol-slim.md`, cut the Write/Edit-fallback
   bullets from `## Agent-teams mode` (lines 53-79: the call-time rejection,
   the Bash-heredoc fallback, the `reviewed-path-gate.sh` constraint and
   two-gate rephrasing sentence, and the grant-independence note). Keep
   bullets 1-3 (`skills:`/`mcpServers:`, foreground subagents vs nested
   teams, `SendMessage` reporting) — those apply to all four slim personas.
2. Add a scribe-only replacement to `agents/scribe.md`'s body: the
   Write/Edit call-time rejection, the Bash-heredoc fallback idiom, and a
   pointer to the gates' own refusal text for the rephrasing rules. Keep it
   to a short paragraph — this is the whole point of the finding.
3. Correct the stale comment in `tests/adapter-protocol-parity.test.js`
   (~line 126) that says "**three** personas receive persona-protocol-slim.md".
   Verified: it is **four** (explorer, researcher, scribe, agent-auditor).
   In scope because this spec's Goal covers every factually false statement
   in the persona corpus, and this step is already in that file's
   neighborhood.
4. Re-render: `node bin/cli.js --update`.

Affected files: `templates/persona-protocol-slim.md`, `agents/scribe.md`,
`tests/adapter-protocol-parity.test.js` (comment only), mirrors
`.claude/agents/{explorer,researcher,scribe,agent-auditor}.md` and
`.claude/persona-protocol-slim.md`, version, CHANGELOG.

Do NOT touch: `templates/persona-protocol.md` (Step 17 owns the full-tier
copy); the slim template's `Blocked by a gate you do not own` and
`Terminal status line` sections; `selectProtocolSections`'s slim-tier throw
— **no slim trimming mechanism is built here** (option (c) was rejected as
disproportionate to an audit whose thesis is subtraction).

Acceptance criteria:
- C12.1 `grep -c "heredoc" templates/persona-protocol-slim.md` returns 0.
  *(Baseline: 3.)*
- C12.2 `grep -c "heredoc" agents/scribe.md` returns at least 1.
  *(Baseline: 0.)*
- C12.3 `.claude/agents/explorer.md`, `.claude/agents/researcher.md` and
  `.claude/agents/agent-auditor.md` contain no `heredoc` and no
  `exists but is not enabled in this context` string; `.claude/agents/scribe.md`
  contains both — proving the doctrine reached exactly the one slim persona
  that needs it.
- C12.4 `wc -w .claude/agents/explorer.md` is measurably lower and the
  before/after numbers are recorded in the CHANGELOG entry. The explorer is
  the persona whose purpose is to be fast and cheap; this is the finding's
  headline win and it must be measured, not asserted.
- C12.5 `grep -c "fan-out: three" tests/adapter-protocol-parity.test.js`
  returns 0 and `grep -c "fan-out: four"` returns 1. *(Baseline: 1 and 0.)*
  **Anchor chosen deliberately:** the phrase "three personas receive" is
  wrapped across a comment line break at
  `tests/adapter-protocol-parity.test.js:125-126`, so grepping it — in
  either naive or line-joined form, since the `// ` prefix lands mid-phrase —
  returns 0 today and would be a vacuous criterion. `fan-out: three` is on
  one line and is the wrap-proof anchor.
- C12.6 `grep -c "^## " templates/persona-protocol-slim.md` is unchanged at
  7 — bullets were cut, no section was removed.
- C12.7 `node tests/adapter-protocol-parity.test.js` exits 0 (its slim-tier
  checks still pass), and `bash tests/validate.sh` exits 0; version bumped.

### Step 13 — Delete the reviewer-gate-ratchet belt-and-suspenders paragraph (1.6)

**Accepted; overrides a Pass-3 byte pin** (operator ruling 2026-08-13 —
R9.2). This unit exists separately from Step 5 precisely so the override is
a small, isolated, individually-reviewable diff.

**What is being reversed, named explicitly so a future pass does not read
this as an oversight:** Pass 3 Step 4 criterion 6c
(`docs/plans/2026-08-03-efficiency-audit-remediation-pass3.md:1088-1100`),
headed "**Anti-regression control — the reviewer gate was NOT loosened**",
pinned three paragraphs of § "Reviewer gate model selection" byte-identical
to commit `e5b908f`, extracted by bold lead. The second of the three is
`` **`.fail` disqualifier.** `` — the paragraph this step deletes. The other
two (`Downgrade-only asymmetry`, `Escalation.`) stay pinned.

**Why the deletion is safe (capability, not just bytes).** The rule is the
canonical **reviewer-gate ratchet** (`CONTEXT.md:256`), and it is enforced
mechanically and fail-closed at `hooks/scripts/reviewer-tier.sh:73-75`
(`if [ -f "${marker_dir}/${safe_id}.fail" ]; then opus; fi`, preceded by
`[ -d "$marker_dir" ] || opus`). The prose itself concedes redundancy: "The
script checks this too, but you check it as a belt-and-suspenders backstop."
Deleting the prose leaves the script as sole enforcement — which C13.2 pins
unmodified and C13.5 re-proves by test.

**The draft missed a dangling reference; this step fixes it.** Verified
2026-08-13: `agents/orchestrator.md:355` (inside the surviving `Escalation.`
paragraph) reads "...writes the standard `.fail` record, which via the
`.fail` disqualifier above permanently forces opus for that unit id
thereafter." Deleting the disqualifier paragraph orphans that back-reference
— exactly finding 2.2's defect class. The `Escalation.` paragraph must be
repointed at `reviewer-tier.sh` directly. **Note this is a licensed,
minimal edit to a paragraph Step 5's C5.2 pins**; the pin is re-run here
against everything except that one clause.

Affected files: `agents/orchestrator.md` (§ "Reviewer gate model selection"),
`.claude/agents/orchestrator.md` (regenerated), version, CHANGELOG.

Do NOT touch: `hooks/scripts/reviewer-tier.sh`;
`tests/reviewer-tier.test.sh`; the `Downgrade-only asymmetry` paragraph; the
`Fable is never valid on the gate` paragraph; `CONTEXT.md`'s
**Reviewer-gate ratchet** glossary entry (it describes the mechanism, which
is unchanged); `## Per-unit model routing`'s implementer-tier paragraphs
(Step 14 owns that region, and the **implementer-tier ratchet** is a
different rule — do not conflate them).

Acceptance criteria:
- C13.1 `grep -c "belt-and-suspenders" agents/orchestrator.md` returns 0.
  *(Baseline: 1.)*
- C13.2 Anti-regression control, re-run and narrowed: the
  `Downgrade-only asymmetry` paragraph is byte-identical to `e5b908f` (same
  bold-lead extraction Pass 3 used), and
  `git diff --exit-code hooks/scripts/reviewer-tier.sh` exits 0.
- C13.3 No dangling reference survives:
  `grep -c "the \`.fail\` disqualifier above" agents/orchestrator.md`
  returns 0, and the surviving `Escalation.` paragraph instead names
  `reviewer-tier.sh` (or the **reviewer-gate ratchet** by its canonical
  glossary name) as what forces opus thereafter. *(Baseline: 1.)*
  Step 2's cross-reference guard must also pass.
- C13.4 A reviewer confirms the surviving § "Reviewer gate model selection"
  still states, in some form, that a prior `.fail` forces an opus review —
  the *rule* survives even though the redundant paragraph does not. If it
  does not survive anywhere in the persona corpus, this criterion FAILS:
  the deletion would then be capability loss, not de-duplication.
- C13.5 `bash tests/reviewer-tier.test.sh` exits 0, proving the surviving
  mechanical enforcement is intact and this was a prose-only change.
- C13.6 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry
  explicitly naming the Pass-3 byte-pin override so `git log` carries the
  record too.

### Step 14 — Collapse spec-master / milestone-auditor / task-master dispatch routing (3.4)

**Accepted** (operator ruling 2026-08-13 — R9.4). Lands **before** Step 15.

**Scope is deliberately narrow.** Operator OQ3's ruling that "R2 (the
reviewer gate) and `hooks/scripts/reviewer-tier.sh` stay permanent and
untouched" is **honored, not reversed**. This step touches neither
`### Reviewer gate model selection` nor the implementer-tier paragraphs. It
collapses exactly two subsections:
`### Dispatch-model routing for spec-master and milestone-auditor` (**40
lines**, measured) and `### task-master model routing` (**11 lines**,
measured) — 51 of the section's 111 lines.

**What is being reversed:** operator OQ5 (which rejected more-aggressive
compression of routing prose), and — found during this revision, missing
from the draft — `docs/adr/0013-fable-removed-from-roast-work-advisory-pass.md:22`,
which records the `milestone-auditor` `fable` tier as "per the operator's
2026-08-06 correction (Revision 6 of the efficiency audit plan)" and warns
"Do not overstate this decision as 'fable is retired everywhere' — that is
false." Collapsing the tier table makes that ADR text false, so the ADR
must be annotated in the same unit (Step 8's precedent, different ADR).

**Ordered edits:**

1. Replace the two subsections in `agents/orchestrator.md` with a compact
   rule for all three personas. Recommended default (see OQ-N1): the
   collapsed rule is *"frontmatter default; `opus` after any `.fail` record
   for a unit in scope, or after a human challenge"* — which, given
   `agents/spec-master.md:4` and `agents/milestone-auditor.md:4` are both
   `model: opus`, means those two become always-opus and `task-master` stays
   at its `model: sonnet` frontmatter default.
2. Remove the now-vestigial `Escalation symmetry` paragraph — with nothing
   dispatching below opus for those two personas, there is no cheaper tier
   to escalate *from*. If OQ-N1 resolves to keep cheap defaults, this
   paragraph stays; see C14.2.
3. Remove the `**fable** is excluded for task-master` paragraph's *dispatch*
   prose but **keep one line of the standing exclusion** — Pass 3 Step 6's
   own note records that "the standing exclusion guard in
   `agents/task-master.md` is deliberately *kept* (it is one line and
   prevents a future re-introduction on the wrong persona)". Do not delete
   what a prior pass deliberately kept without saying so.
4. Remove the citation "a human challenge at the **step-9 pre-audit
   checkpoint**" (`agents/orchestrator.md:290`) — Step 15 deletes that
   checkpoint, and this step landing first is what keeps the reference from
   dangling.
5. Annotate `docs/adr/0013-...:22` in place, marking the `milestone-auditor`
   fable-tier caveat superseded by this change and naming issue #348.
   Additive annotation only, per Step 8's convention.
6. Re-render: `node bin/cli.js --update`.

Affected files: `agents/orchestrator.md`, `agents/task-master.md` (the
one-line exclusion guard, if its wording needs to match),
`docs/adr/0013-fable-removed-from-roast-work-advisory-pass.md`, mirrors,
version, CHANGELOG.

Do NOT touch: `### Reviewer gate model selection` in any form;
`hooks/scripts/reviewer-tier.sh`; `## Per-unit model routing`'s
implementer-tier ratchet paragraphs (`Implementer-tier fail ratchet expiry`,
`Haiku units escalate on first FAIL`, `Check for a prior .fail record`);
`CONTEXT.md`'s two ratchet glossary entries; `## Milestone audit gate`
(Step 15).

Acceptance criteria:
- C14.1 `sed -n '/^## Per-unit model routing/,/^## Relaying spec-master/p'
  agents/orchestrator.md | wc -l` returns **at most 75**.
  *(Baseline: 111. The two collapsed subsections total 51 lines; a
  replacement of ~15 lines lands comfortably under the cap.)*
- C14.2 **Turns on OQ-N1.** Under the recommended default: `sed -n '/^##
  Per-unit model routing/,/^## Relaying spec-master/p' agents/orchestrator.md
  | grep -c "fable"` returns at most 1 (the surviving task-master exclusion
  guard line), and no surviving text assigns `milestone-auditor` a `fable`
  or `sonnet` tier. Under the alternative answer, this criterion instead
  requires the tier table to survive in compressed form with the `8+ units`
  threshold intact. *(Baseline: the subsection names `fable` for both
  milestone-auditor and task-master.)*
- C14.3 `git diff --exit-code hooks/scripts/reviewer-tier.sh` exits 0, and
  the `### Reviewer gate model selection` subsection is byte-identical to
  its pre-step state (`diff` of the `sed`-extracted section). This is the
  mechanical proof that OQ3's protection was honored.
- C14.4 `grep -c "pre-audit checkpoint" agents/orchestrator.md` returns
  exactly 1 — the `## Milestone audit gate` section's own use, which Step 15
  removes next. The routing citation is gone. *(Baseline: 2.)*
- C14.5 `docs/adr/0013-...` carries an inline annotation adjacent to line 22
  naming #348 as superseding the fable-tier caveat, with no body text
  deleted (`git diff` on that file shows additions only). A reviewer
  confirms adjacency, not merely presence.
- C14.6 The implementer-tier ratchet survives verbatim: `sed -n '/^## Per-unit
  model routing/,/^### /p' agents/orchestrator.md` still matches
  `Implementer-tier fail ratchet expiry`, `Haiku units escalate on first
  FAIL`, and `Check for a prior`. A reviewer confirms none of the three
  rules changed meaning.
- C14.7 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry
  naming both the OQ5 and the ADR-0013:22 reversal.

### Step 15 — Drop the milestone pre-audit human-confirm checkpoint (3.3)

**Accepted — the most heavily-protected reversal in this spec** (operator
ruling 2026-08-13 — R9.5). Lands **after** Step 14.

**What is being reversed, in full, so this is unmistakably deliberate:**

- **Operator OQ4 = (a) "keep it as-is"** (pass3 ruling summary, line 82).
- **Pass 3 Step 12**: "F10 is **rejected on assessment**, not deferred and
  not unassessed."
- Its **2026-08-06 re-affirmation**: "Leg (i) alone sustains the rejection,
  so F10 stays rejected on assessment. **Recorded so a Pass 4 does not
  re-open it** on the strength of the narrowed leg (ii)." This spec *is*
  Pass 4, and it is re-opening it, by explicit operator instruction after
  being shown that sentence verbatim.
- The **pinned acceptance criteria** at
  `docs/plans/2026-07-13-persona-review-hardening.md:588-593`, which assert
  the section names `AskUserQuestion` and makes the BEFORE ordering explicit.
  Those criteria are retired by this step and must not be re-run against the
  new text.
- The underlying reasoned principle at that same doc, line 581-583: "The
  checkpoint is a quick human confirm pass; the auditor remains the deeper
  automated adversarial pass — the former does not replace the latter."

**What is NOT reversed — verified, and narrower than the draft implied.**
Pass 3's F10 proposed making the *audit itself* opt-in. #348's 3.3 removes
only the *pre-audit checkpoint*. `docs/adr/0013-...:28`'s core claim — "the
milestone-audit gate remains unconditional and mandatory; 'a clean
checkpoint is not a reason to skip the audit' is unchanged" — **survives
this step**, and C15.2 pins it. No ADR annotation is required here.

**One stale premise cleared.** The 2026-07-13 plan's fourth pinned criterion
diffs the section against `eval/variants/review-packet/agents/orchestrator.md`.
Verified 2026-08-13: **`eval/variants/` does not exist**, and nothing in
`tests/`, `bin/cli.js` or `hooks/` references it. That criterion is dead;
no variant file needs syncing.

**Ordered edits:**

1. In `agents/orchestrator.md`'s `## Milestone audit gate` (35 lines),
   delete numbered steps 1 and 2 (fetch the spec's Goal/assumptions/Open
   Questions; `AskUserQuestion` confirm-challenge pass).
2. Re-home step 3's re-plan route onto the **findings relay**, which the
   finding's own text proposes ("could be a single question folded into the
   findings relay"). The rule "if the human materially challenges a premise,
   that's a re-plan back to `spec-master`, not an audit" is live and singly
   stated — it must survive, or this is capability loss (see Clarifications).
3. Keep step 4's dispatch, and keep passing "human-flagged premises" **only
   when the human volunteered any**, per the finding.
4. Re-render: `node bin/cli.js --update`.

Affected files: `agents/orchestrator.md` (`## Milestone audit gate` only),
mirror, version, CHANGELOG.

Do NOT touch: `agents/milestone-auditor.md`; the findings-relay paragraph's
existing `AskUserQuestion` use; the orchestrator's `AskUserQuestion`
frontmatter declaration (still needed by the findings relay and by
`## Relaying spec-master open questions`); `## Per-unit model routing`
(Step 14 already handled its checkpoint citation);
`eval/variants/` (it does not exist).

Acceptance criteria:
- C15.1 `sed -n '/^## Milestone audit gate/,/^## Graph freshness/p'
  agents/orchestrator.md | grep -c "AskUserQuestion"` returns exactly **1** —
  the findings relay only. *(Baseline: 2.)*
- C15.2 The same section extract still asserts the audit is unconditional:
  a reviewer confirms text equivalent to "a clean checkpoint is not a reason
  to skip the audit" / "the gate is not optional" survives, so
  `docs/adr/0013-...:28` remains true. **If the audit becomes skippable,
  this step has overshot into F10 territory and the criterion FAILS.**
- C15.3 The re-plan-on-challenged-premise route survives: the same extract
  still routes a materially challenged premise back to `spec-master` rather
  than into an audit. Reviewer-verified claim, not a grep — this is the one
  live rule the deletion could silently drop.
- C15.4 `grep -c "pre-audit checkpoint" agents/orchestrator.md` returns 0.
  *(Baseline after Step 14: 1.)* Step 2's cross-reference guard passes.
- C15.5 `sed -n '1,10p' agents/orchestrator.md | grep -c "AskUserQuestion"`
  returns at least 1 — the frontmatter tool declaration is untouched, since
  two other relays still depend on it.
- C15.6 A reviewer reads the rewritten section end-to-end and confirms the
  numbered flow is internally coherent after the deletion (no orphaned
  "Otherwise, THEN", no step referring to a removed step). This is the
  failure mode a grep cannot see.
- C15.7 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry
  explicitly naming the OQ4 / F10-adjacent reversal.

### Step 16 — Make the graph-freshness backstop staleness-triggered (3.6)

**Accepted** (operator ruling 2026-08-13).

Finding 3.6's fix offers two variants: "drop the per-unit manual step, **or**
trigger it only when the explorer reports staleness". This step takes the
**second**, self-resolved for a stated reason: the draft's own deferral
rationale was that removing the step "removes a correctness backstop
protecting the explorer's blast-radius answers, which the reviewer depends
on". The staleness-triggered variant removes the per-unit cost (the entire
point of the finding) while keeping the backstop reachable — strictly better
against the only objection on record, and squarely inside the finding as
filed.

**Premises re-verified 2026-08-13:** `hooks/hooks.json:7` registers
`graph-update.sh` on `PostToolUse`; `.git/hooks/pre-commit` exists and is
executable; `agents/orchestrator.md:405-412` is the manual third. The
explorer's staleness signal already exists and is already required of it —
`agents/explorer.md:34-36`: "if the graph index is missing, stale, or the
MCP server is [unavailable] ... the answer is grep-derived, not
graph-derived."

Affected files: `agents/orchestrator.md` (`## Graph freshness (backstop
duty)`, 8 lines), mirror, version, CHANGELOG.

Do NOT touch: `hooks/hooks.json`; `hooks/scripts/graph-update.sh`;
`.git/hooks/pre-commit`; `agents/explorer.md` (its fallback bullet is the
trigger and stays exactly as-is); `CLAUDE.md`'s Code Review Graph note.

Acceptance criteria:
- C16.1 The section no longer instructs an unconditional per-unit run:
  `sed -n '/^## Graph freshness/,/^## Managing a long-running/p'
  agents/orchestrator.md | grep -c "BEFORE routing to the reviewer"` returns
  0. *(Baseline: 1.)*
- C16.2 The section names the explorer's staleness report as the trigger —
  the extract matches `stale` and names `explorer`. A reviewer confirms the
  resulting instruction is actionable (it says what signal to watch for and
  what to run), not merely that the old sentence is gone.
- C16.3 The two automatic updaters are still described as primary: the
  extract still names the `PostToolUse` hook. A reviewer confirms no reader
  could conclude graph freshness is now unmaintained.
- C16.4 `git diff --exit-code hooks/hooks.json` and
  `git diff --exit-code hooks/scripts/graph-update.sh` both exit 0, and
  `agents/explorer.md` is unmodified — this step removes a manual duty, it
  does not weaken either mechanical updater or the signal it now depends on.
- C16.5 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry.

### Step 17 — Compress the two-gate rephrasing doctrine to a pointer (3.2)

**Accepted** (operator ruling 2026-08-13). Lands **after** Steps 11 and 12.

**The premise was verified first-hand, not assumed.** During this spec's
revision, `reviewed-path-gate.sh` refused two of my own Bash calls and its
refusal text printed the complete remediation *including* the two-gate
distinction verbatim: "That rephrasing workaround is sanctioned for THIS
gate only, which grants the reviewer an identity — it is never for
human-decision-gate.sh, which grants no identity at all, and rewording a
command so that gate's scan stops seeing the path it protects is a
self-authorized bypass. Use the sanctioned marker-write template that gate
prints in its own refusal instead." And
`hooks/scripts/human-decision-gate.sh:78-95` prints the full sanctioned
`cat > .claude/reviewed/<task-id>.pass <<'EOF'` template with all four of
its rules. Both gates are self-documenting at the moment of refusal, which
is the only moment the doctrine is actionable.

**This reverses nothing, but it is one day old.** The doctrine was added by
`ba1ad48` (2026-08-13) scoping a real 2026-08-12 incident. The operator was
told this and accepted 3.2 anyway. The rule is **not** being deleted — it is
being moved from ten always-loaded copies to the two refusal messages that
already carry it, which is what makes this subtraction rather than loss.

**Ordered edits:**

1. In `templates/persona-protocol.md`, replace the two rephrasing bullets
   in the Write/Edit-fallback section Step 11 created (the
   `reviewed-path-gate.sh` command-text constraint bullet and the
   `That rephrasing move is sanctioned for reviewed-path-gate.sh only`
   bullet) with a single sentence pointing at the gates' own refusal text.
   Retain, in that sentence, the one non-derivable fact: that rewording to
   dodge `human-decision-gate.sh` is a self-authorized bypass. Everything
   else — the heredoc template's four rules, the placeholder-substitution
   idiom, the `git commit -F` example — is printed by the gates.
2. Leave the `## Blocked by a gate you do not own` section intact; it
   already states the general rule and is the pointer's natural home.
3. If the compressed section's remaining content no longer justifies a
   distinct `## ` header, **do not** re-merge it into `Agent-teams mode` —
   Step 11's per-persona drop depends on the split. Verify it still carries
   the Write/Edit rejection, the heredoc idiom, and the grant-independence
   note (~12 lines), and say so in the unit report.
4. If the header text changes at all, update **both** `codexMap` and
   `cursorMap` in `tests/adapter-protocol-parity.test.js` (R11).
5. Re-render: `node bin/cli.js --update`.

Affected files: `templates/persona-protocol.md`, possibly
`tests/adapter-protocol-parity.test.js`, mirrors,
`.claude/persona-protocol.md`, version, CHANGELOG.

Do NOT touch: `hooks/scripts/human-decision-gate.sh`;
`hooks/scripts/reviewed-path-gate.sh`; either gate's refusal text — this
step's entire safety argument is that those messages are complete, so
weakening one would invalidate the step retroactively.
`templates/persona-protocol-slim.md` (Step 12 already removed the slim
copy). `## Blocked by a gate you do not own`.

Acceptance criteria:
- C17.1 `grep -c "That rephrasing move is sanctioned"
  templates/persona-protocol.md` returns 0. *(Baseline: 1.)*
- C17.2 The surviving sentence still states that rewording a path to evade
  `human-decision-gate.sh` is a self-authorized bypass:
  `grep -c "self-authorized bypass" templates/persona-protocol.md` returns
  at least 1. This is the one fact a persona must hold *before* it is
  refused, since a bypass that succeeds prints no refusal.
- C17.3 **Anti-regression on the premise.**
  `git diff --exit-code hooks/scripts/human-decision-gate.sh` and
  `git diff --exit-code hooks/scripts/reviewed-path-gate.sh` both exit 0,
  and `bash hooks/scripts/human-decision-gate.sh` still prints the
  sanctioned template in its refusal (exercised by the gate's existing test
  suite, which must pass). If the refusal text ever stops printing the
  template, this step's justification evaporates — so the criterion pins it.
- C17.4 A reviewer confirms that a persona reading only the compressed
  protocol, on being refused by either gate, has enough to act: the pointer
  names both gates and says the refusal text carries the remediation. Claim
  verified by reading, not by grep (R6).
- C17.5 `grep -c "^## " templates/persona-protocol.md` is unchanged from its
  post-Step-11 value — content was compressed, no section added or removed.
- C17.6 `node tests/adapter-protocol-parity.test.js` exits 0;
  `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry.

### Step 18 — Remove anomaly check A5 from the agent auditor (3.5, A5 half)

**Accepted; ships onto contested ground by explicit operator choice**
(2026-08-13 — R9.6, R10). The operator was told A5 is one of only two
mutation-proved checks and that #334/#337/#290 all touch these files, and
chose to proceed rather than defer.

A5 flags a subagent whose final assistant message lacks the `STATUS:` line,
and `agents/agent-auditor.md:70-74` instructs that the finding "**is a
prompt to resume the subagent, not a defect** ... Do not flag it as an
error." An audit check defined to be non-actionable is the finding's whole
argument.

**Correction to the draft, verified:** `tests/agent-auditor.test.sh:255-301`
defines a generic `mutation_proof()` helper invoked twice —
`mutation_proof A1 a1bad` and `mutation_proof A5 a5bad`. A1's proof is
self-contained and survives A5's removal. The real cost is mutation-proof
coverage dropping from two anomaly checks to one, which C18.4 records
rather than hides.

**Ordered edits:**

1. `scripts/agent-audit.sh`: delete the `# --- A5: missing terminal status
   line ---` block (the `while` loop and its `emit_finding A5` call), the A5
   plain-text summary line (~534) and its `jq` detail line (~535). Update
   the file header (line 3) from "six anomaly checks (A1-A6)" to five,
   enumerating `A1-A4, A6`. **Do not renumber A6** (R10.3).
2. `tests/agent-auditor.test.sh`: delete the `a5bad`/`a5good` fixtures in
   the `s4` block, the two `assert_agent_finding A5` assertions, the
   `mutation_proof A5 a5bad` invocation, and update the header comment at
   line 8 ("Non-vacuity for A1 and A5 is proven by mutation") to name A1
   alone. Keep `mutation_proof()` itself and the `MUTANT_DIR` scaffolding —
   A1 still uses both.
3. `agents/agent-auditor.md`: delete the `**A5 — Missing terminal status
   line**` entry and correct any surrounding count of the checks.
4. Re-render: `node bin/cli.js --update`.

Affected files: `scripts/agent-audit.sh`, `tests/agent-auditor.test.sh`,
`agents/agent-auditor.md`, `.claude/agents/agent-auditor.md`, version,
CHANGELOG.

Do NOT touch: A1, A2, A3, A4, A6 or the I1-I2 inventories; the `A6`
identifier (no renumbering); `mutation_proof()` and the `MUTANT_DIR`
scaffolding; `templates/persona-protocol.md`'s `## Terminal status line`
section — **the STATUS line itself is not being removed from the protocol
by this step**, only the audit check that reports its absence. Anyone
reading this later: dropping A5 does **not** mean the status line became
optional.

Acceptance criteria:
- C18.1 `grep -c "A5" scripts/agent-audit.sh` returns 0.
  *(Baseline: 4.)* `grep -c "A5" tests/agent-auditor.test.sh` returns 0.
  *(Baseline: 9.)* `grep -c "A5" agents/agent-auditor.md` returns 0.
  *(Baseline: 1.)*
- C18.2 `grep -c "A1-A6" scripts/agent-audit.sh` returns 0 and the header
  states five checks, enumerating them. *(Baseline: 1.)*
- C18.3 `grep -c "A6" scripts/agent-audit.sh` is unchanged from its
  pre-step value — A6 was not renumbered.
- C18.4 `bash tests/agent-auditor.test.sh` exits 0 **and** its output still
  contains `mutation proof for A1` — A1's non-vacuity proof survives intact.
  The CHANGELOG entry states plainly that mutation-proof coverage fell from
  two checks to one, and names #334/#337/#290 as issues whose baseline
  shifted (R10.2).
- C18.5 `bash scripts/agent-audit.sh --all --json | jq '[.findings[] |
  select(.id=="A5")] | length'` returns 0 on a live run, and the command
  exits 0 — the script is still well-formed after the excision.
- C18.6 A reviewer confirms `agents/agent-auditor.md` contains no dangling
  reference to A5 and that its remaining check list is internally consistent
  (no "six checks" prose, no gap in the narrative between A4 and A6).
- C18.7 `bash tests/validate.sh` exits 0; version bumped; CHANGELOG entry.

## Resolved decisions

*This section replaces the draft's "## Open Questions". All five draft
questions were answered by the human operator on 2026-08-13, relayed through
the orchestrator. Recorded here verbatim in effect, with the resulting
step, so the decisions are auditable rather than merely absorbed.*

**A note on the draft's numbering defect, for the record.** The draft's
Findings-triage heading "Requires reversing a prior ruling (Open Question 2)"
listed {1.1, 1.6, 3.1, 3.4, 3.5}, while the draft's actual Open Question 2
asked about {3.2, 3.3, 3.4, 3.6} — two different sets sharing only 3.4, and
Step 9 (finding 3.1) was labeled "CONDITIONAL on Open Question 2" though
that question never mentioned 3.1. Verified against the draft text at lines
265-277, 537 and 613-623 before rewriting. Consequence: **1.6, 3.1, and
3.5's A5 half were never actually put to the operator through that
question.** The orchestrator caught this and asked separately; their answers
below are standalone operator decisions, not readings of the malformed
question. The tables above are now keyed to findings and steps only — no
table references an Open Question number.

| # | Decision (operator, 2026-08-13) | Lands as |
|---|---|---|
| **Scope tier** (draft OQ1) | Materially **Tier C**: every finding accepted except the two flatly rejected ones (1.10, 3.7) | Steps 1-18 |
| **1.1** (draft OQ3) | **Option (a)**: split `Agent-teams mode` into two canonical sections, drop only the Write/Edit-fallback half from the orchestrator, plus `A note on memory` and `Microworld bundles`. **Keep the Terminal status line section** — the draft's reasoning that the trim is unsound was accepted | Step 11 |
| **1.8** (draft OQ5) | **Option (a)**: cut the fallback bullets from `persona-protocol-slim.md`, add a scribe-only line to `agents/scribe.md`. Option (c) — building a slim trimming seam — stays rejected as disproportionate | Step 12 |
| **1.6** (never posed via OQ2; asked standalone) | **Accept — override the Pass-3 byte pin** | Step 13 |
| **3.1** (mislabeled CONDITIONAL on OQ2; asked standalone) | **Accept — override the Pass-3 carve-out.** Step 9's CONDITIONAL label removed | Step 9 |
| **3.2** (draft OQ2) | **Accept**, one day after `ba1ad48` landed the doctrine | Step 17 |
| **3.3** (draft OQ2) | **Accept**, with the prior hard-rejection and its "Recorded so a Pass 4 does not re-open it" marker shown verbatim first. Override confirmed | Step 15 |
| **3.4** (draft OQ2) | **Accept**, scoped so OQ3's protection of R2 / `reviewer-tier.sh` is honored | Step 14 |
| **3.6** (draft OQ2) | **Accept** | Step 16 |
| **3.5 A5 half** (never posed via OQ2; asked standalone) | **Accept — drop A5 now**, despite the mutation-proof cost and the #334/#337/#290 collision. Deferral was offered and declined | Step 18 |
| **Sequencing** (draft OQ4) | **Option (a)**: land #346 and #347 **before** any gh348 unit dispatches. #345 already closed | R8 |

## Open Questions

**One question, raised during this revision. It was not among the five the
operator has already answered, and it is not resolvable by reading the
repo — it is a cost-direction preference.** Step 14 is fully authored and
dispatchable against the recommended default; only criterion C14.2 turns on
the answer, so `task-master` should gate that criterion, not the unit.

**OQ-N1. Step 14 (finding 3.4): does "collapse to frontmatter default" mean
`spec-master` and `milestone-auditor` become always-opus?**

Verified facts behind the question: `agents/spec-master.md:4` and
`agents/milestone-auditor.md:4` are both `model: opus`. #348's fix text says
"collapse spec-master/milestone-auditor/task-master routing to *frontmatter
default; opus after any `.fail` or human challenge*" — read literally, that
deletes the `sonnet` and `fable` downgrades and makes both personas always
opus. `docs/adr/0013-...:22` measured the `milestone-auditor` fable tier as
firing on ~25% of this repo's milestones, so the removal has a real,
measured cost. The audit's own argument is that ~110 lines of always-loaded
routing prose costs more than that tier saves — a defensible trade, but a
trade, and the operator has not been shown this framing.

- (a) **Recommended — take the literal reading.** Both personas dispatch on
  their `opus` frontmatter default; `task-master` stays `sonnet`. Deletes
  ~51 lines of routing prose and the `Escalation symmetry` paragraph
  (vestigial once nothing dispatches below opus). Simplest surviving rule,
  and it matches #348's fix text word for word. Accepts a modest dispatch-
  cost increase on the ~25% of milestones that used fable, plus every
  `sonnet`-eligible spec-master dispatch.
- (b) **Compress the prose, keep the cheap defaults.** Collapse the two
  subsections to ~15 lines but retain, in compact form, spec-master's
  sonnet-eligibility test and milestone-auditor's `8+ units → fable`
  threshold. Captures most of the token saving with no cost increase, but
  keeps two conditional rules the finding wanted gone, and still reverses
  ADR-0013:22 only partially (the threshold survives).
- (c) **Split the difference**: always-opus for `spec-master` (whose
  sonnet-eligibility test is the more judgment-laden of the two), keep
  milestone-auditor's measured size threshold. Least defensible as a rule
  anyone will remember; listed for completeness.

## Self-check

18 steps and three categories still scored Partial, so the full checklist
applies. Every item interrogates this document's own text.

Three groups, written in three passes. **CHK1-CHK24** interrogate the plan's
structure and its handling of the prior rulings. **CHK25-CHK32** are the
eight criterion corrections the second verification pass made against
`d1f232f` — the items the Context section points at. **CHK33-CHK38** were
added by the finalization pass, which re-ran every numeric baseline and
every internal cross-reference in this document against the tree, and found
five gaps the interrupted revision sessions had left behind.

- CHK1: Is every one of #348's 24 findings assigned an explicit accepted /
  rejected disposition, with no "conditional" or "requires an Open Question"
  status surviving? — PASS (Findings triage, two tables: 22 accepted + N1,
  2 rejected; the four-table draft structure is gone).
- CHK2: Does the plan state which of the audit's own claims failed
  verification? — PASS (five "Corrected" rows plus the Constitution P1 line,
  which now names all five including the two the draft itself got wrong).
- CHK3: Is the draft's Open-Questions-vs-triage-table numbering mismatch
  resolved rather than papered over? — PASS ("Resolved decisions" opens with
  the defect recorded, the two conflicting sets named, and the three
  findings that fell through it identified; no table now cites an Open
  Question number).
- CHK4: Do Steps 2, 4 and 11 agree about ordering, given that Steps 4 and 11
  perform the same drop operation that caused 2.2? — PASS (R3 states the
  dependency; the Steps preamble orders 2 → 4 → 11; C4.1 and C11.6 both make
  Step 2's guard the proof).
- CHK5: Does every step have at least one runnable acceptance criterion? —
  PASS (all 18 end with a `bash tests/validate.sh` criterion plus
  step-specific greps, diffs or tests).
- CHK6: Are prose-only steps protected against the vacuous-existence-grep
  failure mode this repo has hit before? — PASS (R6 states the rule; C3.3,
  C4.3, C5.3, C5.6, C8.1, C8.4, C9.2, C9.5, C10.2, C11.6, C13.4, C14.6,
  C15.2, C15.3, C15.6, C16.2, C16.3, C17.4 and C18.6 each name a
  reviewer-verified claim rather than a bare `grep -c == 0`).
- CHK7: Does every criterion added in this revision state its RED baseline?
  — FAIL (missing) — revised in place: baselines were measured against the
  tree and are now inlined as *(Baseline: N)* on C9.1, C10.1, C11.1, C11.3,
  C12.1, C12.2, C12.5, C13.1, C13.3, C14.1, C14.2, C14.4, C15.1, C15.4,
  C16.1, C17.1, C18.1 and C18.2.
- CHK8: Is the source/mirror slicing constraint stated so `task-master`
  cannot split an edit from its render? — PASS (R1, quoting `CONTEXT.md`'s
  standing rule by name; the Steps preamble repeats it; every step bundles
  edit + `--update` + bump).
- CHK9: Is the constitution's P4 conflict with finding 1.10 resolved rather
  than ignored, and is it distinguished from the reversible rejections? —
  PASS (Constitution check + the Rejected table's note that 1.10 is "not
  reversible by operator preference", grounded in `tests/validate.sh:155-185`).
- CHK10: Does the plan record every prior ruling it reverses, by name, where
  a future reader will hit it? — PASS (R9 enumerates all six with citations;
  the Prior-rulings table gained a "Final disposition" column; Steps 13, 14
  and 15 each restate their own reversal in the step body, and C13.6, C14.7
  and C15.7 push it into the CHANGELOG).
- CHK11: Do Steps 14 and 15 agree about which one removes the "step-9
  pre-audit checkpoint" citation? — PASS (Step 14 ordered edit 4 removes the
  routing citation with C14.4 pinning the count at 1; Step 15's C15.4 then
  pins it at 0; the Steps preamble states the ordering and why).
- CHK12: Do Steps 5 and 13 agree about the byte-pinned paragraphs, given
  that C5.2 pins all three and Step 13 deletes one? — FAIL (conflicting) —
  revised in place: C5.2 now carries the parenthetical "*(Step 13, and only
  Step 13, is licensed to change the second of the three.)*", and C13.2
  narrows the re-run to the one remaining prose paragraph plus the script.
- CHK13: Is the #346 dependency attributed to the correct step? — FAIL
  (conflicting) — revised in place: the dispatch briefing attributed it to
  the finding-1.6 step, but Step 13 touches no hook. **Step 7** is the step
  needing `.claude/hooks/scripts/human-decision-gate.sh`; R8 states the
  correction explicitly. *(The "that file is absent" half of this item's
  original evidence has since been superseded — `d1f232f` created the
  mirror. The attribution to Step 7 is unaffected. See CHK34.)*
- CHK14: Does Step 11's plan account for `UNIVERSAL_PROTOCOL_CORE` making
  the new section undroppable? — PASS (ordered edit 2 states the
  remove-from-core-then-list-per-row indirection and cites
  `bin/cli.js:717-719`; C11.2 requires the throw to be demonstrated).
- CHK15: Does any step that changes the canonical section list account for
  the adapter-parity merge gate? — PASS (R11; Step 11 ordered edit 4 with
  C11.7's non-vacuity requirement; Step 17 ordered edit 4 and C17.5/C17.6).
- CHK16: Is Step 17's safety argument — that the gates' refusal text is
  complete — verified rather than assumed? — PASS (the step quotes the
  refusal text observed first-hand this session and cites
  `human-decision-gate.sh:78-95`; C17.3 pins both gates unmodified so the
  argument cannot silently rot).
- CHK17: Does Step 13 state what happens to the rule it deletes, not just
  the text? — PASS (the step names the **reviewer-gate ratchet** glossary
  term and `reviewer-tier.sh:73-75` as surviving enforcement; C13.4 FAILS
  the step if the rule survives nowhere, and C13.5 runs the gate's test).
- CHK18: Does Step 15 distinguish what it reverses (the checkpoint) from
  what it does not (the mandatory audit)? — PASS (the step's "What is NOT
  reversed" paragraph, with C15.2 failing the step if the audit becomes
  skippable).
- CHK19: Is Step 18's collision with #334/#337/#290 recorded where the
  people working those issues will find it? — PASS (R10.2, the Issue
  disposition table's three rows, and C18.4 forcing it into the CHANGELOG).
- CHK20: Is the draft's claim that A5 is A1's "mutation-proof partner"
  checked rather than inherited? — FAIL (missing) — revised in place:
  verified `mutation_proof()` is a generic helper with two independent
  invocations; the claim is corrected in R10.1, the triage table and Step
  18, and restated as coverage falling 2 → 1.
- CHK21: Is the `eval/variants/` sync obligation in the 2026-07-13 pinned
  criterion still live? — FAIL (missing) — revised in place: verified
  `eval/variants/` does not exist and nothing references it; Step 15 records
  the criterion as dead so no unit wastes a dispatch chasing it.
- CHK22: Does the plan distinguish the **implementer-tier ratchet** from the
  **reviewer-gate ratchet**, which Steps 13 and 14 touch adjacently? —
  PASS (Clarifications names both glossary entries with line numbers; Step
  13's Do-NOT-touch and Step 14's Do-NOT-touch each name the other's rule;
  C14.6 pins all three implementer-tier paragraphs).
- CHK23: Does every step have a Do-NOT-touch list? — PASS (all 18; Step 1's
  is `task-gate.sh`, Steps 2-10 gained explicit lists in this revision).
- CHK24: Is the one new ambiguity surfaced rather than guessed, with a
  recommended default and a bounded blast radius? — PASS (OQ-N1, three
  options, recommended first; R12 and C14.2 bound it to a single criterion
  so Step 14 stays dispatchable).

*The eight criterion corrections from the second verification pass
(`d1f232f`), referenced by the Context section:*

- CHK25: Is C1.5's version criterion still non-vacuous after `d1f232f`
  bumped the tree to 0.31.28? — FAIL (ambiguous) — revised in place: the
  criterion hardcoded `> 0.31.27`, which the bump made true with no bump at
  all. **The interrupted session recorded this correction as done but never
  applied it**; the finalization pass applied it, restating the bump
  relative to the unit's base commit and pinning it to the CHANGELOG's top
  heading and to `package.json`.
- CHK26: Does C9.1 detect the occurrence that is wrapped across
  `agents/orchestrator.md:16-17`, and does its stated baseline match what
  its own command returns? — FAIL (ambiguous) — revised in place: the
  line-joining normalization is correct and load-bearing (a naive
  line-based `grep -c` goes green while the wrapped occurrence still
  ships), but the recorded baseline of "2" was the *occurrence* count, and
  `grep -c` on a joined single-line file is a boolean returning 1. Both
  numbers are now stated, with which command produces which.
- CHK27: Is `agents/spec-master.md`'s carve-out — which states the rule in
  different words and is invisible to C9.1's phrase — covered by its own
  criterion? — PASS (C9.2 anchors on `≥3 units, debug spec`; baseline
  re-measured at 1).
- CHK28: Is the same true of `templates/persona-protocol.md`, the second
  location that never contains C9.1's phrase? — PASS (C9.3 extracts the
  "Cap at 2 FAILs per unit" paragraph with `sed` *first*, then counts
  `task-master` within it; baseline re-measured at 1).
- CHK29: Is C12.5 anchored on text that a `grep` can actually see? — PASS
  (the natural phrase "three personas receive" is split across a `// `
  comment break at `tests/adapter-protocol-parity.test.js:125-126`, which
  line-joining cannot rescue, so the criterion anchors on the single-line
  `fan-out: three`; re-measured at 1 and 0).
- CHK30: Can C10.1 be stated as a literal, given that Steps 11 and 17 both
  move the canonical section count before Step 10 lands? — PASS (stated as
  an equality against `grep -c "^## "` at landing time; the *(documented 16,
  actual 18)* baseline re-confirmed, and `CONTEXT.md`'s "16" verified in
  place).
- CHK31: Does C11.1 avoid asserting a literal post-state that Step 17 may
  move again? — PASS (stated as "exactly one more than before this step",
  with the 18 baseline re-measured; and the Context section separately
  records why an assertion about `CANONICAL_PROTOCOL_HEADERS` membership
  would be tautological, since that list is derived from the template).
- CHK32: Is C14.1's line cap executable and grounded in a measurement
  rather than an estimate? — PASS (`sed -n '/^## Per-unit model
  routing/,/^## Relaying spec-master/p' | wc -l`, baseline re-measured at
  exactly 111, cap 75 against 51 lines of collapsible subsections).

*Finalization pass, 2026-08-13 — gaps left by the interrupted sessions:*

- CHK33: Does C9.7 protect the ADR-0003 rule it names, or delete it? — FAIL
  (conflicting) — revised in place: the criterion asserted "spec-master
  still never runs `to-tickets`" and then demanded
  `grep -c "to-tickets" agents/spec-master.md` return 0. All three live
  occurrences are correct statements and `agents/spec-master.md:186` **is
  the prohibition itself**, so satisfying the criterion literally would have
  deleted the rule — capability loss of exactly the class this spec's first
  constraint forbids. Reworded as a survival pin returning 1.
- CHK34: Do Step 7's body and R8 agree about whether
  `.claude/hooks/scripts/human-decision-gate.sh` exists? — FAIL
  (conflicting) — revised in place: R8 and the Issue-disposition table were
  corrected when `d1f232f` landed the mirror, but Step 7's own body still
  read "does not exist today", and CHK13 still cited its absence as
  evidence. Both corrected; the file is present and byte-identical to
  source. The *blocking* relationship is unchanged — what blocks Step 7 is
  #346's review, not its implementation.
- CHK35: Does R6's forward reference to R13 resolve? — FAIL (missing) —
  revised in place: R6 pointed at "R13, which is the operational consequence
  for this spec's own 18 units" and no R13 existed. Written, stating that a
  `.fail` on a blocking dependency is not a `.pass`, that R8's precondition
  must be re-checked live at dispatch rather than quoted from this
  document's snapshot, that no gh348 unit's model tag changes because of it,
  and that the hygiene failure mode generalizes to all 18 units.
- CHK36: Does the Context section's promise of "Self-check items
  CHK25-CHK32" resolve to eight actual items? — FAIL (missing) — revised in
  place: the Self-check ended at CHK24, so both that reference and the
  "see CHK25" pointer inside R8 dangled. The eight items are now written,
  one per corrected criterion.
- CHK37: Is every numeric baseline in this document still reproducible
  against the tree at finalization? — PASS: all of C1.1, C1.2, C2.1, C2.2,
  C5.1, C5.3, C6.1, C9.1, C9.2, C9.3, C10.1, C10.3, C11.1, C11.3, C12.1,
  C12.2, C12.5, C13.1, C13.3, C14.1, C14.4, C15.1, C15.5, C16.1, C17.1,
  C17.2, C18.1 and C18.2 were re-executed and match the recorded values
  (C9.1's is corrected per CHK26). C2.2's claimed red state — the dangling
  `"Fourth verdict" below` reference present in `spec-master`,
  `task-master`, `milestone-auditor` and `lead-programmer` but not in
  `reviewer` or `orchestrator` — reproduces exactly as stated. R6's marker
  census (226 files) is also unchanged.
- CHK38: Do this document's three citations of the include/drop throw agree
  with each other? — FAIL (conflicting) — revised in place: the Context
  cited `bin/cli.js:707-719` with "the throw is at 719" (correct, verified),
  while the Clarifications entry, Step 11's ordered edit 2 and CHK14 all
  cited `bin/cli.js:677-680` — a stale `ba1ad48` citation pointing into the
  middle of a persona row's section list, not at the throw. All three
  corrected to `bin/cli.js:717-719`. This mattered beyond tidiness: Step
  11's ordered edit 2 is what a dispatched unit follows, and the throw is
  the whole reason its remove-from-`UNIVERSAL_PROTOCOL_CORE` indirection is
  mandatory. Also re-verified in the same sweep: `protectedPaths` contains
  `hooks/scripts/human-decision-gate.sh` (R4), `gatedAgents` is
  `["lead-programmer"]` alone (Context), `mutation_proof()` is a generic
  helper invoked independently for A1 and A5 (R10.1), the slim tier's
  `selectProtocolSections` throw is present (Context), and `eval/variants/`
  is absent with nothing referencing it (Step 15, CHK21).

## Scribe update hint

On completion:

- `CONTEXT.md`: correct the **protocol excerpt** section count (Step 10);
  add glossary entries for the cross-reference guard introduced in Step 2
  and for the new canonical protocol section Step 11 creates.
- Four load-bearing terms surfaced by the terminology check have no glossary
  entry: **pre-audit checkpoint**, **graph-freshness backstop duty**,
  **anomaly check (A1-A6)**, and the new fallback section's name. Three of
  the four are removed or renamed by this spec, so record the *outcome*, not
  the removed mechanism — a stale entry for a deleted checkpoint is worse
  than none.
- `CONTEXT.md`'s **Reviewer-gate ratchet** entry must survive Step 13
  unchanged in substance but should gain a note that persona-side prose no
  longer restates it and `reviewer-tier.sh` is the sole statement.
- `.claude/wiki/protocol-delivery-tiers.md` needs its full-tier and
  slim-tier section enumerations **rebuilt from the templates** rather than
  hand-patched — Steps 11 and 17 both move the count, which is why Step 10's
  criteria are equalities.
- CHANGELOG entries per step, three of which (Steps 13, 14, 15) must name
  the prior ruling they reverse so `git log` carries the record
  independently of this document.
- ADR candidates: none required by this spec. Steps 8 and 14 annotate
  existing ADRs in place rather than allocating new numbers, and the `0007`
  hole stays empty (never backfill it).
