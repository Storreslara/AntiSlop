# A decision surface in the Microworld dashboard

**STATUS: FINAL.** Both Open Questions of the 2026-08-13 draft were answered
by the human on 2026-08-13 and are recorded in Clarifications below. This
document supersedes that draft in place.

**Routing: this does NOT fit the ≤2-unit fast path — it resolves to five
units. Hand to `task-master` for `to-tickets` slicing.** See "Unit count" for
the reassessment.

Published as the PRD-view issue
[#349](https://github.com/Storreslara/AntiSlop/issues/349) (`ready-for-agent`).
This document is canonical where the two differ.

Origin: user request 2026-08-13 — "I want all the user decision commands to
be routed over to MicroWorlds. So I want a separate section within
MicroWorlds where the user can interactively approve the decisions. That
will then be reviewed by a reviewer." Scope expanded by the human's OQ1
answer to four named touchpoints.

## Goal

Give the human one place — a Decisions section in the Microworld dashboard —
where the four human-facing decision points of this persona system can be
read in full and answered, without hand-assembling a command from a template
recited into chat scrollback. The dashboard **composes**; it never writes.

The four touchpoints, and what "routed through the dashboard" resolves to for
each (the architectural determination this document exists to make):

| # | Touchpoint | Durable artifact today | Resolution |
|---|---|---|---|
| 1 | `ESCALATE-TO-HUMAN` resolution (the DECISION file) | Yes — `.claude/reviewed/<id>.escalated` + `.claude/human-review/<id>/` | **Read + compose the write command.** No new artifact. |
| 2 | Milestone pre-audit checkpoint | Yes, for its *inputs* (the `docs/plans/` doc); no artifact for its answer | **Read surface only.** The answer stays in `AskUserQuestion`. No new artifact. Deliberately not fully routed — see D-4. |
| 3 | Milestone-auditor findings relay | **No** | **One new durable artifact** (the findings record), then read + compose a paste-back block. |
| 4 | Pending-review `defer:`/`skip:` | Yes — `.claude/.pending-review.<agent-id>` | **Read + compose both commands.** No new artifact. New human-facing surface over an existing agent-facing one. |

Net new architecture across all four: **exactly one durable artifact** (the
milestone findings record, touchpoint 3). Everything else is read and
composition over artifacts that already exist.

## Context

### The tension this document had to resolve, resolved

Touchpoints 2 and 3 are synchronous `AskUserQuestion` calls today — the
orchestrator's turn blocks and gets an answer in the same turn, with no
durable artifact and no async window. Touchpoint 4 has no human involvement
at all. The question was whether forcing any of these into an async,
dashboard-composable shape is coherent, or whether it fights design intent.

The answer differs per touchpoint, and the difference is not arbitrary — it
falls out of one property: **whether the decision's cost is dominated by
reading or by answering.**

- Where a decision is **expensive to read and cheap to answer** (touchpoint
  2 — the pre-audit checkpoint is a quick yes/no gate over a long premise
  list), route the *reading* to the dashboard and leave the *answering*
  native.
- Where a decision is **expensive to read and expensive to answer**
  (touchpoints 1 and 3 — a full escalation packet; a severity-tagged
  findings list that may trigger a convergence re-plan), route both.
- Where a decision is **currently invisible to the human entirely**
  (touchpoint 4), the win is surfacing it at all; reading and composing both
  belong in the dashboard, and nothing about the existing agent-side write
  path changes.

An important asymmetry made this cheaper than it first looks: the
orchestrator is the **main session**. Its turn-end already returns control to
the human, so "async" for touchpoints 2–4 costs no new blocking-wait
mechanism, no resume machinery, and no gate. This is why touchpoint 3's
conversion is affordable at all, and it is why touchpoint 2's is not worth
paying for regardless — see D-4.

### The three fixed premises this feature must leave standing

1. **The dashboard writes nothing.** Re-verified 2026-08-13:
   `grep -rn "writeFileSync\|writeFile\|appendFile\|createWriteStream\|mkdirSync\|rmSync\|unlinkSync\|mkdir" bin/microworld-dashboard/`
   returns **0 hits** across all 7 modules. Under the human's OQ2 answer
   (compose only) this stays 0, and Step 1 carries that as an executable
   criterion rather than an assurance.
2. **The DECISION file's trust anchor is untouched.**
   `human-decision-gate.sh` is a PreToolUse hook that sees agent tool calls
   only; a dashboard `fs.writeFile` would be invisible to it, and an agent
   with `Bash` could start the server, read the per-launch token off its own
   stdout (`bin/microworld-dashboard/server.js:222`), and POST a forged
   approval. That is the laundering path the draft identified. **Compose-only
   does not open it**: no endpoint accepts a decision, so there is nothing to
   POST. The gate, its no-grant-branch property, and the inference "a file at
   this path was created by a human outside the harness" all stand verbatim.
3. **The dashboard is never a gate.** The shared protocol, mirrored into
   every full-tier persona, states the dashboard "is a human-facing
   exploration surface and **never an acceptance criterion** — no hook
   registers it, no gate consults it." This feature must not make any gate,
   hook, or workflow *depend* on the dashboard running. Touchpoint 2's
   orchestrator pointer is therefore phrased optionally, and Step 4 carries a
   criterion that the milestone gate's four numbered steps are unmodified.

   Note the reading that governs here, stated so a reviewer does not have to
   guess: "never an acceptance criterion" bars the dashboard's *rendered
   output* from adjudicating a unit under review. It does not bar acceptance
   criteria that test dashboard *code* — Step D8 of the dashboard plan itself
   has exactly such criteria, which settles the reading by precedent.

### Correction to the draft: D8's decoupling criterion was already vacuous

The draft's Step 2 proposed amending Step D8's standing decoupling criterion
(`grep -rc 'humanReviewMode' bin/dashboard/ | grep -v ':0$' | wc -l` is 0,
and the same for `escalated`) on the grounds that this feature contradicts
it. Measured directly on 2026-08-13, that criterion **never had force**: it
greps `bin/dashboard/`, which does not exist. The real directory is
`bin/microworld-dashboard/`. `ugrep` warns "No such file or directory",
exits 0, and the pipeline reports 0 unconditionally — it would report 0 for
any code whatsoever.

Two consequences, both load-bearing:

- The correct remediation is not "amend a constraint we are breaking" but
  "record that a shipped criterion is vacuous, and do not re-inherit its
  broken path." Step 5 marks it superseded **and states the vacuity**, so the
  record is accurate rather than merely updated.
- Every new criterion in this document that greps the dashboard must name
  `bin/microworld-dashboard/`, and Step 1's zero-write criterion is written
  so that it is non-vacuous by construction (it greps a directory that
  exists, for terms that appear elsewhere in the repo).

The constraints that *do* have force are D8's prose ("never reads a
`.escalated` marker, never writes anything under `.claude/`") and the shared
protocol sentence in premise 3. This feature genuinely narrows the first —
the decision surface must read `.escalated` to know an escalation is live —
and leaves the second intact.

### The seam

The highest existing seam, and the one this feature should use rather than
inventing a new one: **a pure formatter module, loaded two ways**.
`bin/microworld-dashboard/feedback-block.js` is exactly this — a dual-environment
CommonJS module `require()`d directly by `tests/dashboard-feedback.test.js`,
and injected verbatim into `index.html` by `server.js`'s `GET /` handler via
the `__FEEDBACK_BLOCK_SOURCE__` placeholder, becoming a page global. All
command/block composition for all four touchpoints goes through one new
module of that exact shape. Composition is then testable as a pure function,
with no server and no DOM.

For rendering, the second existing seam is `tests/dashboard-client.test.js`,
which extracts the client's inline module script and executes it under `vm`
against a stub DOM — proving **rendered output**, not source-text presence.
Step 3's criteria use that technique, not existence greps.

For reading, no new plumbing is needed: `GET /api/source`
(`bin/microworld-dashboard/source.js`) is already a bounded, symlink-resolved,
root-confined excerpt reader, and `.claude/` is inside the project root. Only
*enumeration* is missing.

### This is still not covered by #122 — re-verified

The draft's overlap table stands unchanged; #299, #300 and #137 remain open
and are being dispatched separately by the orchestrator — none is folded into
this spec. #331 (`docs/microworld/README.md`) also remains open, so R5 below
still applies. The nearest neighbour is still #321 (Step D8), which surfaces
escalation packets as a **read** source in a separately-labelled section; what
does not exist is any ability to act on what is read.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-08-13 Domain entities / data model: Q Which touchpoints require a new
  durable artifact, and what is its grammar? → A: exactly one — touchpoint 3.
  `milestone-auditor` writes `.claude/milestone-audit/<plan-slug>/FINDINGS.md`,
  first line exactly
  `FINDINGS <plan-slug> <UTC ISO-8601 timestamp> count: <n>`, then its findings
  list verbatim. Touchpoints 1 and 4 reuse artifacts that already exist;
  touchpoint 2 introduces none. See D-2.
- 2026-08-13 Domain entities / data model: Q A pending-review flag is keyed by
  agent-id and its auto-created form carries no unit id — how does the
  dashboard say *which unit* is awaiting review? → A (self-resolved): join to
  the newest `.claude/.review-join.<task-id>` stamp that has no
  `.claude/reviewed/<task-id>.pass` written after it. The protocol's
  one-unit-at-a-time invariant makes that join unambiguous. With no stamp, the
  entry carries `unit: null` — never a guess. See D-5.
- 2026-08-13 User interaction flow: Q Is forcing the milestone pre-audit
  checkpoint async coherent? → A (self-resolved): **no** — and this is the one
  place the request is deliberately not taken literally. See D-4 and R6.
- 2026-08-13 User interaction flow: Q How does the human answer touchpoint 3
  once the findings are rendered? → A (self-resolved): a copyable paste-back
  markdown block, pasted into the conversation — the same mechanism the
  dashboard already uses for function feedback. No RESPONSE artifact, no
  second lifecycle. See D-3.
- 2026-08-13 Edge cases / failure handling: Q What does the decision surface
  do for an escalation whose packet has no `manifest.json`? → A
  (self-resolved): renders normally. `discover.js`'s `discoverPackets` marks
  such a packet `disabled` with "manifest.json not found", and that is the
  **common** case — the reviewer writes `PACKET.md` alone when a unit has no
  bundle. The decision surface must not route through bundle discovery at
  all. Step 1 case (a) asserts it.
- 2026-08-13 Technical constraints & tradeoffs: Q Does this feature break
  D8's standing decoupling criterion? → A (self-resolved): the criterion is
  vacuous as shipped (wrong directory) and never constrained anything. The
  feature does narrow D8's *prose*. Recorded, not silently inherited — see
  Context and Step 5.
- 2026-08-13 Terminology consistency: Q Do the new concepts have glossary
  entries? → A (self-resolved): no. Three are new and load-bearing —
  **decision surface**, **milestone findings record**, **composed decision
  command**. Routed to `scribe` in Step 5; see the terminology check below.
  Advisory, did not gate.

### Terminology check (`antislop:ubiquitous-language`, prose mode, against `CONTEXT.md`)

- **Lens 1 (glossary term used with a different meaning):** none found. This
  document uses **Microworld dashboard** for the server/UI process and
  **Microworld** for a rendered entry, matching `CONTEXT.md`'s explicit
  distinction. The request's "MicroWorlds" maps to **Microworld dashboard**;
  casing/pluralization drift only.
- **Lens 2 (new synonym for a defined term):** "approval surface" (draft) and
  "user decision commands" (request) are new names for what the glossary
  already carries as the **DECISION file** / **DECISION channel**. This
  document uses **decision surface** for the UI section only, never for the
  artifact, so the two do not collapse.
- **Lens 3 (load-bearing new term with no entry):** three — **decision
  surface** (the dashboard section), **milestone findings record** (the new
  durable artifact), **composed decision command** (a ready-to-run command the
  dashboard renders and never executes). Suggested for `scribe` in Step 5.

Advisory only; did not affect dispatch.

## Design decisions

- **D-1 — One composer module, four decision kinds.**
  `bin/microworld-dashboard/decision-block.js`, shaped exactly like
  `feedback-block.js` (dual-environment CommonJS + injected classic script).
  A single entry point discriminates on `kind`:
  `escalation-decision`, `pending-review-defer`, `pending-review-skip`,
  `milestone-findings-response`. It returns a discriminated result —
  `{ kind: 'command' | 'block', text, warnings[] }` — so touchpoint 3's
  paste-back block and touchpoints 1/4's shell commands share one tested seam
  and one clipboard path. Rejected alternative: a composer per touchpoint —
  four near-identical modules, four test files, and four places for the
  quoting rules of D-6 to drift.

- **D-2 — Touchpoint 3 gets one new durable artifact, written by the
  auditor.** `milestone-auditor` writes the findings record itself, via
  `Bash`, as a **named bookkeeping exception** — the identical carve-out the
  reviewer already has for `.pass`/`.fail`/`.escalated` markers, and for the
  identical reason: it is a record *about* the work, not a change *to* the
  work. The auditor has no `Write`/`Edit` tool by design and does not gain
  one.

  Rejected alternative: the orchestrator transcribes the findings into the
  file. Rejected for the same reason the reviewer transcribes a DECISION file
  verbatim rather than paraphrasing it — an intermediary that re-states a
  judgment can quietly alter it, and the auditor is the only party that
  actually holds the findings.

  Lifecycle: the orchestrator deletes the directory
  (`rm -rf .claude/milestone-audit/<plan-slug>`) once the human's decision has
  been acted on. Leaving a stale record is a defect, not untidiness — nothing
  else globs that directory, so a human can mistake an old findings list for a
  live one. This is the same rule the escalation packet already carries.
  `.claude/milestone-audit/` is gitignored, joining its sibling operational
  markers.

- **D-3 — Touchpoint 3's answer is a paste-back block, not a second
  artifact.** The durable record solves the problem that actually exists —
  findings vanishing into scrollback, unciteable later by `spec-master`'s
  convergence follow-ups. The *answer* does not need a file: unlike DECISION,
  no trust anchor requires it, nothing is being forged, and the durable record
  of the decision is the `## Convergence follow-ups` section `spec-master`
  appends to the plan doc anyway. A RESPONSE artifact would duplicate that and
  add a lifecycle (who writes it, who reads it, who deletes it, what happens
  when it is stale) for no gain.

  This is a deliberate, narrow deviation from the human's "composes the exact
  ready-to-run command" phrasing, and it is flagged as R7 rather than hidden:
  for touchpoint 3 the composed object is a message, not a command, because
  the recipient is the conversation, not the filesystem.

- **D-4 — Touchpoint 2 is a read surface; its answer stays in
  `AskUserQuestion`.** The pre-audit checkpoint is documented in
  `agents/orchestrator.md` as a quick synchronous gate whose entire purpose is
  deciding whether to spend an expensive audit dispatch. Its inputs are
  already durable (the `docs/plans/` doc and its tracker publication); only
  its *presentation* is poor, because `AskUserQuestion` option labels truncate
  a long premise list. So the dashboard supplies the briefing — the plan doc's
  Goal, stated assumptions and Open Questions, alongside the milestone's units
  and their `.pass`/`.fail` history — and the four-step gate is otherwise
  untouched.

  Converting the *answer* would add an artifact, a wait and a resume in order
  to save one Opus dispatch, making the gate cost more coordination than the
  thing it guards. It would also make a gate's operation depend on a browser,
  which premise 3 forbids. Rejected on both counts.

  The orchestrator gains exactly one **optional** sentence in step 2 of the
  gate, pointing at the briefing if the dashboard is running. The gate must
  remain fully functional with no dashboard running — Step 4 asserts the four
  numbered steps are unmodified.

- **D-5 — Touchpoint 4 is in scope, narrowly: read and compose, nothing
  else.** The artifact is already durable and ungated; the win is that a
  standing pending-review flag is currently invisible to the human except as
  a `stop-gate.sh` block message in a terminal. The decision surface renders
  which unit is awaiting review, since when, and what its last verdict was,
  then composes both escape commands.

  Explicitly **out of scope**, as over-scoping this touchpoint was the named
  risk: no queue, no workflow, no notion of the dashboard deciding on the
  orchestrator's behalf, and **no change whatsoever** to who may write the
  flag or to `stop-gate.sh`. This adds a parallel human path; it removes
  nothing.

  One guard is mandatory rather than nice-to-have: `skip:` **deletes** the
  flag and abandons the review permanently. Putting a one-click copy button in
  front of that makes the destructive path the easiest one. The composer
  therefore refuses to compose a `skip:` (or `defer:`) command with an
  empty or whitespace-only reason — which `stop-gate.sh` rejects anyway — and
  the `skip:` view renders the consequence in words.

- **D-6 — Composition safety is a correctness requirement, not polish.** A
  composed command is text a human will paste into a shell. Three rules,
  each carrying a criterion in Step 2:
  1. **No command substitution in composed content.** The DECISION timestamp
     is a literal captured at compose time (the preview says so), never
     `$(date ...)` — inside the single-quoted heredoc of rule 2 it would not
     expand anyway, and outside it, it would be an injection surface.
  2. **Multi-line bodies use a single-quoted heredoc**, and the composer
     refuses a body containing a line equal to the delimiter — otherwise a
     human-typed reason could close the heredoc early and everything after it
     runs as shell.
  3. **Interpolated ids are validated before use.** Task-ids and agent-ids
     are checked against the protocol's own id grammar (alphanumeric first
     char, then `A-Za-z0-9._#-`, no `/`, ≤64 chars) and a value outside it
     throws rather than composing.

- **D-7 — Enumeration lives in a new module behind a new endpoint.**
  `bin/microworld-dashboard/decisions.js` + `GET /api/decisions`, leaving
  `discover.js` and `GET /api/bundles` untouched. Decisions are a different
  entity from bundles; interleaving them would fight D8's "separately
  labelled, never interleaved" rule and force the client to filter. It also
  keeps blast radius off `discover.js`, which has a heavy defect history
  (R3).

## Risks / dependencies

- **R1 — the laundering path stays closed, and must be kept closed.** Under
  compose-only no endpoint accepts a decision. The standing risk is a *later*
  well-meaning change adding one. Step 1's zero-write criterion and Step 3's
  "no POST from the decision surface" criterion exist to make that regression
  loud.
- **R2 — a shipped criterion in `docs/plans/2026-08-10-microworld-dashboard.md`
  is vacuous** (D8's `bin/dashboard/` greps). This document does not inherit
  it; Step 5 records the vacuity. Do not "fix" the path in that historical
  document as if the unit had passed a real check — it did not.
- **R3 — this code has a real defect history; it is not `haiku` territory.**
  The full `.claude/reviewed/` listing was enumerated (not sampled) on
  2026-08-13. Dashboard units `gh315`, `gh317`, `gh318`, `gh319`, `gh320`,
  `gh323` and `adhoc-2026-08-11-dashboard-gvx-restyle-fix1` each carry a
  `.fail` alongside their `.pass`. `gh321` (the packets step, the nearest
  neighbour) passed first time. No unit in this area was ever escalated or
  abandoned, and no `.fail` exists for any unit this spec re-scopes.
  `task-master` should not tag Steps 1–3 `haiku`.
- **R4 — the G1 version-bump triple fires for Step 4** (constitution P3):
  `agents/*.md` edits require the `.claude/agents/*.md` mirrors regenerated,
  `.claude/persona-config.json`'s `fileHashes` updated, `.claude-plugin/plugin.json`
  bumped and a `CHANGELOG.md` entry. `tests/validate.sh` asserts source/mirror
  parity, so **the persona edit and its mirror regeneration must be one unit**
  — splitting them ships a red merge gate.
- **R5 — `docs/microworld/` does not exist yet** (#331 open). If it lands
  first, this feature's documentation belongs there; otherwise `README.md`.
  Sequence-sensitive, not blocking; Step 5 resolves at execution time.
- **R6 — touchpoint 2 is deliberately not fully routed.** The human asked for
  four touchpoints routed through the dashboard; touchpoint 2's *answer*
  stays in `AskUserQuestion` for the reasons in D-4. Surfaced here rather
  than buried so it can be overruled cheaply: if the human wants the answer
  async too, that is an additive follow-up (a briefing artifact plus a
  composed response command), not a redesign of anything below.
- **R7 — touchpoint 3 composes a message, not a command** (D-3). Same class
  of deliberate deviation as R6; same cheap-to-overrule property.
- **R8 — touchpoint 4's flag→unit join relies on the one-unit-at-a-time
  invariant.** If that invariant is ever broken (concurrent gated dispatches),
  the join becomes ambiguous. The mitigation is already specified: emit
  `unit: null` rather than guess. Step 1 case (d) asserts the null path.

  **Correction (2026-08-14):** the claim above was inaccurate. Step 1 case
  (d) as shipped asserted only the zero-stamp `unit: null` path; the
  multi-stamp (invariant-broken) case instead picked the newest stamp and
  applied it to every pending-review entry, found live in this repo by
  `gh350`'s reviewer (`.claude/reviewed/gh350.pass`, non-blocking note 1).
  Fixed by `docs/plans/2026-08-14-decision-join-ambiguity-fix.md`, which
  makes the multi-stamp case also return `unit: null`.
- **R9 — the milestone findings record is gitignored and therefore
  destructible.** Same property the escalation packet already has, same
  accepted tradeoff: it is an operational marker, not project history. The
  durable record of a *decision* remains the plan doc's
  `## Convergence follow-ups` section.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every claim here was re-derived on
  2026-08-13 from source: the zero-write grep over the real module directory,
  the D8-criterion vacuity (run, not inferred), the full `.claude/reviewed/`
  listing, the live pending-review flag and review-join stamp, the gate
  scripts, `.gitignore`, and the tracker.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step
  4's `fileHashes` and mirror updates go through `bin/cli.js`'s script-driven
  path, never a hand-edit.
- P3 "Version-stamp discipline": satisfied — fires for Step 4 only
  (`agents/*.md`); see R4. Steps 1–3 touch only `bin/` and `tests/` and do
  not fire it. Confirm at execution time rather than assuming.
- P4 "Optional personas degrade gracefully": satisfied — each of the four
  groups is absent from `GET /api/decisions` when its source does not exist,
  which is exactly what happens in a project that selected no `reviewer`
  (touchpoint 1 inert, no `.escalated` marker can exist) or no
  `milestone-auditor` (touchpoints 2 and 3 inert). Step 1 case (g) asserts
  the all-absent case; prose stays `(if present)` phrased.
- P5 "`tests/validate.sh` is the merge gate": satisfied — each new test file
  is **explicitly registered**; `validate.sh` has no glob auto-discovery, so
  an unregistered test silently never runs. Every step that adds a test file
  carries the registration criterion.

## Unit count — reassessment

The draft's provisional 2 steps assumed the DECISION file alone. With four
touchpoints, one new durable artifact, persona edits carrying the G1 triple,
and client rendering across four packet types, this resolves to **five
units**, exceeding the ≤2-unit fast path. Per this project's routing rules
`spec-master` does not slice — **hand to `task-master` for `to-tickets`**.

Dependency edges: Steps 1 and 2 are independent of each other and of Step 4.
Step 3 depends on 1 and 2. Step 4 is independent (Step 1 reads the findings
record from a fixture, so it does not wait on the auditor gaining the write
duty) — but the touchpoint-3 path is not live until both land. Step 5 is
last.

## Steps

### Step 1 — `decisions.js`: read-only enumeration of all four sources, behind `GET /api/decisions`

A new module enumerating the four decision sources and a new authenticated
endpoint serving them. Reads only; `discover.js` and `GET /api/bundles` are
not touched. Fails soft on every malformed input, per the module conventions
already established in `discover.js`.

Sources: (1) `.claude/reviewed/*.escalated` joined to
`.claude/human-review/<task-id>/`; (2) `docs/plans/*.md` as briefing
candidates (path + first `# ` heading); (3)
`.claude/milestone-audit/*/FINDINGS.md`; (4) `.claude/.pending-review.*`
joined per D-5.

**Affected files:** `bin/microworld-dashboard/decisions.js` (new),
`bin/microworld-dashboard/server.js` (route + auth, mirroring the existing
`/api/bundles` handler), `tests/dashboard-decisions.test.js` (new),
`tests/validate.sh` (register it).

**Acceptance criteria**
- `node tests/dashboard-decisions.test.js` exits 0, with cases asserting:
  - (a) a fixture `.claude/reviewed/<id>.escalated` plus a packet directory
    containing `PACKET.md` and **no `manifest.json`** yields an escalation
    entry carrying the packet body and the marker's own first-line
    timestamp — the no-bundle case, which is the common one.
  - (b) an `.escalated` marker whose packet directory is absent yields an
    entry flagged `packetMissing: true`, and the response is still `200`.
  - (c) a `.claude/.pending-review.<agent-id>` in the auto-created
    `<timestamp> agent=<id>` form yields a pending-review entry; one whose
    content begins `defer: ` yields the same entry with `state: "deferred"`
    and the reason verbatim.
  - (d) unit linkage is the newest `.claude/.review-join.<task-id>` stamp
    with no `.claude/reviewed/<task-id>.pass` written after it; with no stamp
    present the entry carries `unit: null` — assert the null path explicitly,
    not only the happy path.
  - (e) a fixture `.claude/milestone-audit/<slug>/FINDINGS.md` yields a
    findings entry with `slug`, timestamp and `count` parsed from the first
    line and the body verbatim; a file whose first line does not parse yields
    an entry flagged malformed rather than throwing.
  - (f) `docs/plans/*.md` are enumerated with path and first `# ` heading.
  - (g) with none of the four sources present, the response is `200` and each
    group is an empty array — the all-absent case, which is also the
    no-`reviewer`/no-`milestone-auditor` degradation case (P4).
  - (h) a request with no `?t=` token and no `X-Antislop-Token` header
    returns `401`.
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `tests/dashboard-decisions.test.js`.
- `git status --porcelain` is byte-identical before and after a full
  `GET /api/decisions` cycle against a fixture project root.
- `grep -rn "writeFileSync\|writeFile\|appendFile\|createWriteStream\|mkdirSync\|rmSync\|unlinkSync" bin/microworld-dashboard/`
  returns **0 hits** — the executable proof that premise 1 still stands.
  (Non-vacuity: this greps a directory that exists and terms that occur
  elsewhere in the repo; it currently returns 0 and must keep returning 0.)

### Step 2 — `decision-block.js`: the composer

A pure, dual-environment formatter shaped exactly like `feedback-block.js`
(same CommonJS-export guard, same `server.js` injection, same
`__..._SOURCE__` placeholder convention in `index.html`). It composes; it
never executes and never writes.

**Affected files:** `bin/microworld-dashboard/decision-block.js` (new),
`bin/microworld-dashboard/server.js` (inject the source, as it already does
for `feedback-block.js`), `bin/microworld-dashboard/index.html` (the
placeholder), `tests/dashboard-decision-block.test.js` (new),
`tests/validate.sh` (register it).

**Acceptance criteria**
- `node tests/dashboard-decision-block.test.js` exits 0, with cases
  asserting:
  - (a) `kind: 'escalation-decision'` composes content whose first line
    matches the protocol grammar
    `DECISION <task-id> <UTC ISO-8601> route: approve|reject|direct escalation: <timestamp>`.
  - (b) the composed `escalation:` value equals the `.escalated` marker
    timestamp passed in context, so a stale composition is impossible; a
    context missing that value throws rather than composing.
  - (c) a `route` outside `approve|reject|direct` throws.
  - (d) the composed content contains no `$(`, no backtick, and no `${` —
    D-6 rule 1, asserted by string search on the composed text.
  - (e) a multi-line body is wrapped in a single-quoted heredoc, and a body
    containing a line equal to the delimiter is refused (no command
    composed, a `warnings` entry instead) — D-6 rule 2.
  - (f) a `task-id` or `agent-id` outside the protocol id grammar
    (alphanumeric first char, then `A-Za-z0-9._#-`, no `/`, ≤64 chars)
    throws — D-6 rule 3. Include at least one case with a shell
    metacharacter and one exceeding 64 chars.
  - (g) `kind: 'pending-review-defer'` and `'pending-review-skip'` each
    compose a command writing the corresponding `defer: <reason>` /
    `skip: <reason>` line to `.claude/.pending-review.<agent-id>`; an empty
    or whitespace-only reason composes **no** command and returns a
    `warnings` entry instead (matching `stop-gate.sh`, which rejects an
    empty reason).
  - (h) the `pending-review-skip` result carries a consequence string stating
    that the flag is deleted and the review abandoned — D-5's guard.
  - (i) `kind: 'milestone-findings-response'` returns `{ kind: 'block' }`
    markdown, **not** a command: assert the text contains no `>` redirection
    and no `cat <<`.
  - (j) an unknown `kind` throws.
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `tests/dashboard-decision-block.test.js`.
- `grep -c "decision-block" bin/microworld-dashboard/server.js` is ≥ 1 **and**
  `node -e "require('./bin/microworld-dashboard/decision-block.js')"` exits 0
  — the dual-environment contract holds in both directions.

### Step 3 — the Decisions section in the client

A separately-labelled Decisions section in `index.html`, never interleaved
with Working Bundles or Escalation Packets (D8's rule), with one view per
touchpoint. Each view renders what it read and offers a copy button using the
existing clipboard path (`doCopyFeedback`'s pattern, including its
hidden-textarea fallback). No view issues a POST.

Views: (1) escalation — packet body, route picker, reason field, name field,
composed command; (2) milestone briefing — the selected plan doc's Goal /
assumptions / Open Questions via `GET /api/source`, plus the milestone's unit
markers, and **no** answer control (D-4); (3) milestone findings — the
findings record, plus a composed paste-back block; (4) pending review — unit,
age, last verdict, and both composed escape commands with the `skip:`
consequence text shown.

**Affected files:** `bin/microworld-dashboard/index.html`,
`tests/dashboard-decisions-client.test.js` (new), `tests/validate.sh`
(register it).

**Acceptance criteria**
- `node tests/dashboard-decisions-client.test.js` exits 0. Every case
  executes the client's inline module script under `vm` against a stub DOM
  and asserts **rendered output**, following
  `tests/dashboard-client.test.js`'s existing technique — source-text
  presence greps do not satisfy any case here. Cases:
  - (a) with a stubbed `/api/decisions` carrying one escalation, the rendered
    output contains a Decisions section header distinct from the "Working
    Bundles" and "Escalation Packets" headers, and the escalation's composed
    command appears in it.
  - (b) with all four groups empty, the Decisions section is **absent** from
    the rendered output rather than rendered empty — matching D2's empty-state
    rule and D8's separately-labelled rule.
  - (c) the milestone-briefing view renders no control that submits an answer:
    assert the rendered briefing contains no `<form`, no `<button` whose
    handler posts, and no `fetch(` targeting a non-`GET` method — D-4's
    "read surface only".
  - (d) the pending-review view renders the `skip:` consequence string from
    Step 2 (h) verbatim.
  - (e) a decision-surface interaction issues no POST: with `fetch` stubbed to
    record calls, rendering and composing across all four views produces zero
    non-`GET` requests — R1's regression guard.
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `tests/dashboard-decisions-client.test.js`.
- `git status --porcelain` is byte-identical before and after rendering and
  composing a decision in each of the four views.

### Step 4 — the milestone findings record: persona edits, mirrors, version triple

`milestone-auditor` gains the duty to write its findings list to
`.claude/milestone-audit/<plan-slug>/FINDINGS.md` via `Bash`, as a named
bookkeeping exception (D-2), with the first-line grammar from Clarifications.
`orchestrator` gains: the deletion duty for that directory once the decision
is acted on, and **one optional sentence** in step 2 of the Milestone audit
gate pointing at the dashboard briefing (D-4). `.gitignore` gains
`.claude/milestone-audit/`.

Per R4, the persona edits and their mirror regeneration are **one unit** —
`tests/validate.sh` asserts source/mirror parity.

**Affected files:** `agents/milestone-auditor.md`, `agents/orchestrator.md`,
`.claude/agents/milestone-auditor.md`, `.claude/agents/orchestrator.md`
(regenerated, not hand-edited — P2), `.claude/persona-config.json`
(`fileHashes`, via the script-driven path), `.claude-plugin/plugin.json`
(version bump), `CHANGELOG.md`, `.gitignore`.

**Acceptance criteria**
- `bash tests/validate.sh` exits 0 — this is what asserts source/mirror
  parity and frontmatter shape, and it is the merge gate (P5).
- `grep -c 'milestone-audit' .gitignore` is ≥ 1.
- `git diff -- agents/orchestrator.md` shows **no modification** to the four
  numbered steps of the Milestone audit gate: the diff for that section
  contains added lines only, no removed or changed lines. This is D-4's and
  premise 3's guarantee that the gate does not come to depend on the
  dashboard.
- The added orchestrator sentence is conditionally phrased against the
  dashboard's presence: `grep -c 'if the Microworld dashboard is running' agents/orchestrator.md`
  is ≥ 1 (baseline 0, measured 2026-08-13). The gate must read as functional
  with no dashboard running — P4's phrasing rule, applied to a non-persona
  dependency. A criterion matching only the word `if` would pass on any
  sentence in the file and is explicitly not sufficient.
- `grep -c 'FINDINGS' agents/milestone-auditor.md` is ≥ 1 **and** the persona
  file states the exact first-line grammar — verify by `grep -c` for the
  literal string `FINDINGS <plan-slug>`, so the criterion is anchored to the
  claim rather than to the word.
- `.claude-plugin/plugin.json`'s version differs from its value at `HEAD`
  before this unit (`git diff HEAD -- .claude-plugin/plugin.json` is
  non-empty) and `CHANGELOG.md` gains an entry naming this change — P3's
  triple.

### Step 5 — documentation, glossary, ADR, and the vacuity record (scribe)

**Affected files:** `README.md` (Microworld dashboard section + Dashboard-specific
limitations), `CONTEXT.md` (glossary), `docs/adr/00NN-*.md` (new),
`docs/plans/2026-08-10-microworld-dashboard.md` (the vacuity record).

Content: the Decisions section and what it composes for each of the four
touchpoints; that it composes and never writes, and that this is what keeps
the DECISION file's trust anchor mechanical; the two deliberate deviations
(R6, R7); glossary entries for **decision surface**, **milestone findings
record**, **composed decision command**; and an ADR recording the one new
durable artifact, the write duty on a `Write`-less persona, and the decision
*not* to convert touchpoint 2's answer.

**Acceptance criteria**
- `grep -c 'decision surface' CONTEXT.md` is ≥ 1, and the same for
  `milestone findings record` and `composed decision command` — three
  distinct glossary entries, not one entry mentioning three names.
- The new ADR file exists and its number is the next unused one in
  `docs/adr/`, re-derived at execution time. **Do not backfill the 0007
  hole** — it is referenced as absent by `CONTEXT.md`, and sibling specs in
  flight may collide, so re-derive rather than trusting this document's
  guess.
- `docs/plans/2026-08-10-microworld-dashboard.md`'s D8 decoupling criterion
  is marked superseded **and** the mark states that the criterion was vacuous
  because it greps a non-existent `bin/dashboard/`. Anchor the check to that
  claim, not to the word: `grep -c 'bin/dashboard/ does not exist'` (or the
  exact wording chosen) is ≥ 1 in the same paragraph as `SUPERSEDED`. A bare
  `grep -q 'SUPERSEDED'` does not satisfy this criterion — the accuracy of
  the statement is the deliverable.
- `README.md` gains an entry stating that the dashboard composes decision
  commands but never runs them, and why that is what keeps the DECISION
  file's guarantee mechanical. Anchored to the claim, not the word:
  `grep -c 'composes the command; you run it' README.md` (or the exact
  wording chosen) is ≥ 1, and `grep -c 'never runs' README.md` is ≥ 1.
  Baseline for both is 0, and `grep -ci 'compose' README.md` is 0, measured
  2026-08-13 — so no form of this criterion can pass vacuously.
- `bash tests/validate.sh` exits 0.

## Open Questions

None. Both of the draft's Open Questions were answered by the human on
2026-08-13 (recorded in Clarifications); the three architectural questions
this document was asked to resolve are resolved in D-2 through D-5. R6 and R7
record the two places the request is deliberately not taken literally —
each is stated plainly, each is cheap to overrule, and neither is a question
being deferred back.

## Self-check

- CHK1: Does the plan state, per touchpoint, whether a new durable artifact
  is required? — PASS (Goal table + D-1 through D-5; exactly one, touchpoint
  3).
- CHK2: Does the plan resolve whether the milestone pre-audit checkpoint can
  coherently go async, rather than assuming either answer? — PASS (D-4 gives
  the reasoning and the rejected alternative; R6 flags it as a deviation).
- CHK3: Does the plan define what "route touchpoint 4 through the dashboard"
  means operationally, and bound it against over-scoping? — PASS (D-5 states
  the surface and lists four things explicitly out of scope).
- CHK4: Do the Goal table and the Steps agree on how many touchpoints get a
  composed command? — PASS (table says 1 and 4 compose commands, 3 composes a
  block, 2 composes nothing; Step 2 cases (a)/(g)/(i) and Step 3 case (c)
  match).
- CHK5: Is the pending-review flag→unit join defined for the case where no
  linkage exists? — PASS (Clarifications and Step 1 case (d): `unit: null`,
  asserted explicitly).
- CHK6: Is the no-`manifest.json` escalation packet case defined? — FAIL
  (missing in the draft) — revised in place; Clarifications records it and
  Step 1 case (a) asserts it as the common case.
- CHK7: Does the plan still assert that D8's decoupling criterion constrains
  this work? — FAIL (conflicting: the draft said so; measurement says the
  criterion is vacuous) — revised in place; Context and Step 5 record the
  vacuity, and R2 warns against inheriting the broken path.
- CHK8: Does every step name a command producing a pass/fail? — PASS (every
  criterion is an exit code, a `grep -c` bound, or a `git diff`/`git status`
  comparison).
- CHK9: Is any acceptance criterion satisfiable by a check that cannot fail?
  — FAIL (ambiguous, as first drafted: a `grep -q 'SUPERSEDED'` in Step 5 and
  a bare `grep` of a possibly-absent directory in Step 1) — revised in place;
  Step 1's grep names the directory that exists, and Step 5's is anchored to
  the claim's wording with the bare-`SUPERSEDED` form explicitly rejected.
- CHK10: Do Steps 1 and 3 agree that the dashboard issues no write and no
  POST from the decision surface? — PASS (Step 1's zero-write grep, Step 3
  case (e)'s zero-non-GET assertion).
- CHK11: Is the constitution's P3 version triple attached to the step that
  actually triggers it, and only that step? — PASS (Step 4 only; R4 states
  it; P3 says Steps 1–3 do not fire it).
- CHK12: Does the plan say who deletes the new durable artifact, and what
  happens if it is left standing? — PASS (D-2: the orchestrator deletes it;
  a stale record is a defect for the same reason a stale escalation packet
  is).
- CHK13: Does the plan avoid making any gate, hook or workflow depend on the
  dashboard running? — PASS (premise 3; D-4; Step 4's added-lines-only diff
  criterion and its conditional-phrasing criterion).
- CHK14: Are the two deliberate deviations from the human's literal request
  stated where a reader will find them, rather than only implied? — PASS (R6
  and R7, plus the Open Questions section stating there are none precisely
  because these are recorded as risks instead).

## Scribe update hint

On ship: three `CONTEXT.md` glossary entries (**decision surface**,
**milestone findings record**, **composed decision command**), each
contrasted with its nearest existing neighbour — decision surface vs. the
**DECISION file** (the surface that composes it versus the artifact that
carries it), milestone findings record vs. the **escalation packet** (both
gitignored durable snapshots, different producers and different consumers),
composed decision command vs. the **feedback block** (both copyable
compositions, one addressed to a shell and one to a conversation). An ADR is
mandatory, not optional: this introduces a durable artifact and a write duty
on a persona deliberately built without `Write`, and records a decision not
to convert a synchronous gate.
