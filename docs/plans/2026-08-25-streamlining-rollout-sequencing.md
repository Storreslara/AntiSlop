# Rollout sequencing across the six 2026-08-25 specs: wave order, dependency edges, file-ownership locks, and machine-checkable gates

Status: **FINAL — dispatch-ready** (spec-master, 2026-08-25). Resolves to **one
unit**, fast path.

**Revision 3 (2026-08-25, after the Fable review of the finalized set).** The
review found five issues in this document and one meta-finding. Its verdict on
the graph: *"the wave ordering itself survives all my findings — I would change
no wave sequence, only edge semantics and the two spec 6 criteria it feeds."*
Revision 3 therefore changes **no wave sequence**. It corrects:

- **H2 ownership rows.** `session-start.sh` listed spec 1's Step 1, which spec 1
  explicitly names a **non-adopter** (*"reporters, not trust gates"*), and
  omitted Step 7; corrected to **Steps 4, 7**. `stop-gate.sh` omitted spec 1's
  Step 4, which wires drift-blocking into it; added.
- **E2** now cites and reconciles spec 3's explicit *"Spec 4 (Microworlds) is a
  prerequisite and should land first"*, which revision 2 inverted silently. A
  second, unflagged contradiction with spec 3's *"M1 → M2 → M3"* was found in
  the same pass and **resolved** by moving M1 into W1 (see E2's closing note) —
  the one composition change in this revision, and it removes a contradiction
  rather than creating one.
- **E8 re-ruled** — the consequential fix. Revision 2's ordering would have let
  spec 6's A22 mirror an expanded `protectedPaths` into a zero-bypass-actor
  ruleset, freezing `hooks/scripts/**` server-side against the operator as well
  as the agent. E8 now carries a four-point tagging contract and fails loudly
  rather than shipping the freeze.
- **ADR 0027** pinned to one ADR for spec 6 with D0 as a *section*, closing a
  hedge in spec 6's scribe hint that a slicer could read as licence to take 0028.
- **W3's gate** gains Unit B's `AC-B1`–`AC-B6`, which revision 2 omitted.
- **`--reverify`**, a fourth preflight mode, added for the meta-finding.

Siblings 1, 2 and 6 are being corrected in parallel; all five were re-read on
disk for this revision, and none had been amended at the time of writing. E8 and
the ADR ruling are both written to be correct in either order of completion.

**Revision 2 (2026-08-25, after spec 6 landed).** Revision 1 sequenced specs 1–4
and was written before Architecture D (spec 6) existed. Spec 6's R7 and its
reconciliation table both flagged that gap and declined to patch it here,
correctly, since this document owns the map. This revision:

- **retires M0** (plugin-snapshot drift) — re-measured green today, with one
  residual that survives as a standing precondition rather than a milestone;
- **renames the milestone namespace** from `M0–M6` to `W0–W10`, because spec 3
  uses `M1`–`M4` as its own milestone labels **115 times** and "M4" was
  ambiguous between two documents;
- **inserts spec 6** with explicit edges (P0 → Phase 1 → Phase 2) and resolves
  the two resources it contends for;
- **re-derives the whole graph from the siblings' landed text**, which moved
  several edges. Revision 1's edges were inferred from the critique's seven
  recommendations; the siblings restructured that work, so the edges are now
  keyed to their actual units.

Every claim below was verified by reading the sibling documents on disk and by
re-measuring this repository today. Where a sibling's own text is the evidence,
it is quoted. Two of the coordinating relay's premises did not survive that
check and are corrected in **C1** and **C2**; one collision that no sibling
flagged is raised in **H7**.

## Goal

Give the six specs a single dispatch order with explicit blocking edges, so
that:

1. no two specs hand-edit the same script concurrently, or in an order that
   forces the same edit to be made three times and then discarded;
2. the serialized resources (ADR numbers, the plugin version stamp, CHANGELOG,
   `protectedPaths`) are allocated once rather than raced;
3. the ordering hazards the siblings raised against each other — spec 1's R6,
   spec 6's R7, spec 3's M4 precondition — are encoded as edges with
   measurements, not left as prose notes;
4. nothing silently drops between specs.

Non-goal, binding: **this spec changes no gate behaviour, no marker format, no
packet format, no bundle contract, and no CI configuration.** It re-specifies
none of the seven streamlining recommendations. If a reader finds a requirement
here that alters any sibling's substance, that is a defect in this document.

## Context

### The seven streamlining recommendations still defer in full

Revision 1's deferral verdicts were re-checked against the landed siblings and
all seven hold. Spec 6 changed the *justification* for several, never the
destination.

| # | Recommendation (abbrev.) | Verdict | Change since revision 1 |
|---|---|---|---|
| 1 | Stop hook writes the verdict markers | **Superseded by spec 1 — not respecified here** | Reshaped by spec 6's D0: under `reviewGating.mode: "off"` this repo stops *populating* `.claude/reviewed/`, but the mechanism ships on. Spec 1 Steps 6 and 9 carry the trust half. |
| 2 | Deny-all on the root of trust | **Superseded by spec 1 — not respecified here** | Landed **narrower than the recommendation**: spec 1's Step 2 protects five literals, not five path *classes*. See H5 for the residual. |
| 3 | Generate the hook ports; delete the parity tests | **Superseded by spec 3 (M2) — not respecified here** | Revision 1's pin ("do not delete the parity tests") is now **satisfied by spec 3's own M2.3**, which shrinks and retargets `adapter-stop-gate-parity.test.sh` rather than deleting it, and leaves `adapter-protocol-parity.test.js` unchanged. Pin withdrawn as redundant. |
| 4 | One state file per unit | **Superseded by spec 3 (M3) — not respecified here** | Spec 6's D0 confirms the state artifacts remain the shipped mechanism, so M3 survives as product work. |
| 5 | Asynchronous microworld rerun | **Superseded by spec 2 (Unit A) — not respecified here** | Spec 2 states the merge explicitly: *"If the streamlining spec also lands an async design, these are one unit, not two — coordinate rather than implement twice."* **This document lands no async design.** Spec 2 Unit A is the single implementation. |
| 6 | Committed watch-map instead of bundle-per-unit | **Superseded by spec 4 — not respecified here** | Revision 1's H6 (the ADR-0017 conflict) is **resolved**: spec 4 places `tests/watch-map.json` outside the gitignored `microworlds/` tree and *amends* ADR 0017 rather than superseding it. |
| 7 | Mechanical ground truth in escalation packets | **Superseded by spec 4 (Step 3) — not respecified here** | Container moves to spec 6's D4 verdict JSON under Phase 2; spec 4's criteria are about detection and provenance and survive. |

**Spec 6 introduces no new streamlining item to defer.** It is sequenced here as
a sixth participant, not as a source of requirements.

### Corrections to the coordinating relay

**C1 — the four-way ignore-list drift is spec 3's, and it is not dropping.**
The relay attributed a *".gitignore hand-copy drift"* to this document's H5 and
asked whether spec 1 addressed it. It was never in H5. The item is real and it
is **spec 3's M1.2**, which single-sources one canonical ignore array across the
**four** hand-maintained copies (`bin/cli.js`'s cursor scaffold, codex scaffold
and claude install lists, plus the `--update` backfill list) and closes three
measured gaps by name. Nothing is dropping; it is owned, specified, and
scheduled here as part of W3.

**C2 — this document's H5 was about a different thing, and it *was* answered.**
Revision 1's H5 measured that item 2's premise ("these paths rarely legitimately
appear in agent commands") is false here, and asked for the false-positive
question to be answered explicitly rather than by omission. **Spec 1 answered
it**: Step 2's C2.4 carries four GUARD cases requiring `node bin/cli.js
--update`, `cat .claude/persona-config.json`, `jq -r .gatedAgents
.claude/persona-config.json` and a Write to `.claude/settings.local.json` to all
still exit 0, plus a case requiring the gate to deny with no config present at
all. That is the reconciliation H5 asked for, resolved in the direction the
measurement recommended. H5 is closed; what remains of it is the narrowing
residual in the new H5 below.

### Measured facts, re-taken today

**F1 — the plugin-snapshot drift is closed; one residual is session-scoped.**
Revision 1 measured the executing plugin at v0.31.57 against a repo at 0.31.63.
Re-measured now: the install record resolves to
`…/antislop-marketplace/antislop/0.31.63`, the snapshot's `plugin.json` reads
`0.31.63`, and `diff -rq hooks/scripts <snapshot>/hooks/scripts` is **empty** —
byte-identical. Spec 2 records the same closure independently. **W0's
predecessor from revision 1 is therefore retired.**

The residual is narrow and real: the update **changed the install path** (from
`…/0.31.57` to `…/0.31.63`) and **the 0.31.57 directory still exists on disk**
(as does `0.25.0`). A session whose `CLAUDE_PLUGIN_ROOT` was resolved before the
update at 2026-08-25T15:09:01Z therefore still executes the *old* scripts, which
differ by 227 lines in `human-decision-gate.sh` and 172 in
`reviewed-path-gate.sh`. This is carried as standing precondition **P-live**,
not as a wave.

**F2 — CI is red on `master`, measured directly.** `gh run list --branch master
--workflow validate --limit 3` returns `failure` for `09cc304a` (today),
`cea73d2a` (2026-08-20) and `b63638ed` (2026-08-18). Spec 6's A0 baseline is
confirmed by independent measurement, not taken on its word. Spec 1's R9
corroborates it and correctly notes that spec 1's own criteria all run locally,
so this is **not** a blocker for specs 1–4.

**F3 — adapter divergence, with spec 3's better measurement adopted.** Revision
1 measured raw `diff` line counts; spec 3's M2.1 measures **code lines only**
(comments and blanks stripped), which is the number that predicts porting
effort. Both are true; spec 3's is the one to plan from:

| script | canonical code lines | codex Δ | cursor Δ | tier |
|---|---|---|---|---|
| `graph-update.sh` | 27 | 54 | 6 | thin shim |
| `lint-on-edit.sh` | 12 | 26 | 6 | thin shim |
| `microworld-rerun.sh` | 57 | 92 | 8 | thin shim |
| `protected-paths.sh` | 23 | 47 | 11 | thin shim |
| `reviewer-route-gate.sh` | 92 | 89 | 87 | independent impl |
| `stop-gate.sh` | 275 | 101 | 184 | independent impl |

**This two-tier split is what makes the rollout parallelizable** rather than one
long chain, and it is the single most load-bearing structural fact in the new
graph (see W1 and W4).

*Count reconciliation:* this document says the adapters carry **6** scripts;
spec 1's R7 says **seven** and then names six. Both are right about the files —
six top-level `*.sh` plus `lib/agent-identity.sh`. Planners should read "six
top-level ports plus one shared library file" and not chase the discrepancy.

**F4 — reactive-rerun latency, unchanged and still the iteration tax.** Measured
in revision 1 by running the real bundles: **161.4 s** of synchronous blocking
for one Edit to `hooks/scripts/human-decision-gate.sh` (3 matched bundles),
**117.9 s** for `reviewed-path-gate.sh` (2 bundles), **0 s** for `stop-gate.sh`
(no bundle watches it). Spec 2's own baseline (211.96 s p50, AC-A1) is measured
differently and is the one its criteria bind to; these figures are contributed
as the per-file breakdown, not as a competing baseline.

**F5 — spec 1's Step 2 protects five literals, not five classes.** Verified from
its text: `.claude/persona-config.json`, `.claude/review-audit.log`,
`.claude/dispatch-audit.log`, `.claude/microworld-audit.log`,
`.claude/wip-audit.log`, plus each log's `.seal` sidecar. `hooks/`,
`.claude/hooks/` and `settings.json` — three of the five classes the original
recommendation named — are **not** in that set.

**F6 — `protectedPaths` now has a different writer than revision 1 assumed.**
Spec 1's Step 2 is *configless by design* and writes nothing to config. Spec 2's
**Unit E** is what writes `protectedPaths`: it requires every script under
`hooks/scripts/` to be *"either listed in `protectedPaths` or recorded in a
declared, reasoned exemption list."* Revision 1 allocated that resource to spec
1. **Reallocated to spec 2 Unit E.**

**F7 — ADR demand, read from the siblings rather than assumed.** Highest ADR on
disk is **0025**; next free is **0026**. Revision 1 pre-allocated 0026–0030
against milestone names the siblings did not adopt, and **no sibling claims any
number in that range**. Actual demand, quoted from each:

| spec | new ADR? | evidence |
|---|---|---|
| 1 | **none** | scribe hint asks for glossary terms and `docs/trust-model.md` only; the only ADR references are 0010 and 0003 |
| 2 | **one, unconditional** | Unit D Deliverable 2: *"the decision, recorded as an ADR amending ADR-0010"* |
| 3 | **none while M4 is blocked** | M4 would annotate 0025/0020 `Superseded by`; annotations take no number |
| 4 | **one, conditional** | *"Consider a new ADR for D9/D11 (demand-gated dashboard build-out)"*; its 0017 and 0019 changes are amendments |
| 6 | **one, unconditional** | R9: *"adds one new ADR for the CI-shaped architecture"*; its A25b and A27 both cite `docs/adr/<new>.md` |

**F8 — version-stamp obligations are declared unevenly.** Constitution P3 is
triggered by `agents/*.md` and `templates/*`; hook scripts are raw
content-hash-tracked copies, not stamped files, so editing `hooks/scripts/`
alone owes no bump. Verified per spec:

| spec | touches `agents/`/`templates/`? | bump declared? |
|---|---|---|
| 1 | yes (Steps 1, 2, 3, 5, 7, 9) | **yes**, explicitly |
| 2 | **yes** — Unit D Deliverable 3 edits `agents/lead-programmer.md`, `agents/orchestrator.md`, `agents/task-master.md` | **no — spec 2 has no Constitution check section at all** |
| 3 | no `agents/` or `templates/` path found | no section; likely owes none |
| 4 | yes (Step 3) | **yes**, AC3.9 |
| 6 | yes (Phase 2 persona edits) | **yes**, §3 |

Specs 2 and 3 have no Constitution check section. For spec 3 that is probably
correct; **for spec 2 it is a gap**, since Unit D demonstrably edits three
stamped persona files. Raised as Open Question 1 rather than asserted as an
obligation this document may impose on another spec.

### Cross-spec hazards

**H1 — measuring the wrong binary. DOWNGRADED to precondition P-live (F1).** The
drift is closed. What remains: a session started before today's plugin update
still executes the 0.31.57 snapshot, which is still on disk. **P-live:** any
unit whose acceptance criteria assert live gate behaviour must either run in a
session started after 2026-08-25T15:09:01Z, or name the script path it exercises
explicitly. Spec 1's Step 5 already works this way (it drives the gates by path
in `tests/refusal-disclosure.test.sh`), which is the pattern to copy.

**H2 — file contention, re-derived from the landed specs.** Rows are files;
a cell marks a spec that edits it.

| file | 1 | 2 | 3 | 4 | 6 | contention note |
|---|---|---|---|---|---|---|
| `hooks/scripts/stop-gate.sh` | Steps 1, 3, **4** | Unit B | M2, M3 | | | three-way; M2 restructures it into a core + shims. Step 4 wires drift-blocking into it: *"a **gated agent's** `SubagentStop` with `config=drift` **blocks**"* |
| `hooks/scripts/microworld-rerun.sh` | Step 9 | Unit A | M2 | Step 1 | | **four-way** — the most contended file in the rollout |
| `hooks/scripts/reviewer-route-gate.sh` | Steps 1, 3 | | M2, M3 | | | M2 restructures |
| `hooks/scripts/protected-paths.sh` | Step 1 | Unit E | M2 | | | |
| `hooks/scripts/reviewed-path-gate.sh` | Steps 1, 5 | Unit C | M4 (blocked) | | | **see H7** |
| `hooks/scripts/human-decision-gate.sh` | Step 5 | Unit C | M4 (blocked) | | | **see H7** |
| `hooks/scripts/session-start.sh` | Steps **4, 7** | | M2 | Step 2 | | **corrected in revision 3**: Step 1 is *not* a claimant — spec 1 names `session-start.sh` a **non-adopter** (*"reporters, not trust gates"*). Step 4 emits the drift `additionalContext` line; Step 7 surfaces the self-report tally here |
| `.claude/persona-config.json` | Step 4 (reads) | Unit E (`protectedPaths`) | A30 (constrains) | | Phase 2 (`reviewGating.mode`) | three writers, three different keys |
| `agents/reviewer.md` | Step 9 | out of scope (AC-B4) | | Step 3 | Phase 2 (D3 shim) | |
| `agents/lead-programmer.md`/`orchestrator.md`/`task-master.md` | | Unit D | | Step 3 (D7) | Phase 2 | |
| `bin/cli.js` | | | M1.2, M2.2 | | | |
| `adapters/*/hooks/scripts/**` | Steps 1, 3, 9 | Unit A | M2 | | | |
| `tests/watch-map.json` | | | | Step 1 (author) | A10–A12 (consumer) | one file, three consumers after D |
| `tests/validate.sh` | several | Units A–E | M1–M3 | AC1.6 | A4, A12 | everyone registers suites here |
| `.github/workflows/**` | | | | | P0, Phase 1 | sole owner |

**H3 — serialized-resource races, now with verified demand (F7, F8).** Four
resources, and the allocation below is this document's ruling.

**H4 — ordering inversions.** Three, all measured:

- *Inversion A (the multi-copy edit), sharpened.* Every hook change is a
  four-copy change today (spec 2 says so in its own cross-cutting constraints).
  Spec 3's M2 collapses that to one. Four specs edit ported scripts. **Whichever
  edits land before M2 are paid four times and then rewritten by M2's
  extraction.** F3's two-tier split means this does not force one long chain:
  M2's thin-shim tier unblocks the `microworld-rerun.sh` / `protected-paths.sh`
  contenders, and M2's independent-implementation tier unblocks the
  `stop-gate.sh` / `reviewer-route-gate.sh` contenders, and those two tiers run
  in parallel.
- *Inversion B (the baseline that already contains the weakening).* Spec 1's R6,
  verbatim: *"If D's flip unit lands **first**, Step 4's baseline is a config
  already carrying `"off"`, and the weakening it exists to catch is already in
  the baseline. **Step 4 should land before D's flip**, or its baseline must be
  pinned to a pre-flip commit and that choice recorded in the PASS marker."*
  Encoded as edge **E7** with spec 1's own escape hatch preserved, because
  over-tightening a sibling's stated option would be a scope violation.
- *Inversion C (the protected set the ruleset must mirror).* Spec 6's A22
  requires the Phase 2 ruleset to cover *"every path `protected-paths.sh` guards
  today"*, and measures that list as two entries. Spec 2's Unit E expands
  `protectedPaths` to cover the hook scripts (F6). **If Unit E lands after Phase
  2, A22 is satisfied against a stale, smaller list** and the ruleset silently
  under-covers. Encoded as edge **E8**.

**H5 — item 2's scope narrowed, and three path classes now have no owner.**
Spec 1's Step 2 protects five literals (F5). The original recommendation named
`hooks/`, `.claude/hooks/` and `settings.json` as well. Under spec 6's Phase 2,
A22's ruleset covers `.github/workflows/*` and `.claude/constitution.md` — still
not those three. **So `hooks/`, `.claude/hooks/` and `settings.json` are, at the
end of this rollout, protected by nothing.**

This document does **not** propose protecting them, and takes the position that
the narrowing is correct: revision 1's own H5 measurement (158 `hooks/scripts`
mentions across 19 test files, 4 microworld `run.sh` files, plus
`tests/validate.sh`'s own `diff -rq hooks/scripts .claude/hooks/scripts`), read
together with ADR-0025's accepted holding against presence-of-word triggers,
says a `hooks/` deny-all would be a false-positive generator. **The requirement
here is only that the gap be recorded rather than assumed closed** — which is
what this paragraph is, and what Open Question 2 asks the operator to ratify.

**H6 — RESOLVED.** Revision 1 raised the ADR-0017 conflict with a "committed
watch-map". Spec 4 resolved it: `tests/watch-map.json` sits outside the
gitignored `microworlds/` tree (its OQ1 explains why), and ADR 0017 is
**amended**, not superseded. No action.

**H7 — NEW: spec 1's Step 5 and spec 2's Unit C rewrite the same denial text,
and neither spec flags the other.** This is the one collision no sibling caught.

- Spec 1 **Step 5** rewrites the denial stderr of `reviewed-path-gate.sh`
  (`:270`, `:278`, `:285`) and `human-decision-gate.sh` (`deny()`, `:270-298`)
  so each message contains *"exactly three things: what was blocked; the one
  sanctioned route for this gate; and a flat, technique-free prohibition"*. Its
  C5.1–C5.6 pin eleven phrases by measured baseline, and **C5.5 requires
  identical assertion counts to the pre-step run**.
- Spec 2 **Unit C** restructures each block message to *"what was blocked → the
  exact remediation → a pointer"*, moving the general reasoning to a referenced
  document, while requiring the sanctioned marker-write template to *"survive
  verbatim"*.

Same files, same lines, near-identical target shape, two specs. Spec 2's
relationship section names the *ceremony* spec on denial messages and does not
mention spec 1's Step 5; spec 1's Step 5 does not mention Unit C. Their
*intents* are compatible — both keep the sanctioned route and cut exposition —
but whichever lands second invalidates the other's measured phrase baselines,
and spec 1's C5.5 exact-count criterion fails outright.

**Ruling (edge E9): spec 1's Step 5 lands first; spec 2's Unit C is then reduced
to its helper half.** Rationale: Step 5 carries six criteria with per-phrase
baselines measured at `09cc304`, so it is the more brittle of the two and the
more expensive to re-baseline; Unit C's message-shortening bullets are largely
subsumed by Step 5's three-part shape, while Unit C's distinct deliverable — the
single invocable marker-writing helper that collapses the two-call dance — is
untouched by Step 5 and survives whole. If the operator prefers, merging both
into one unit is equally acceptable and is the cheaper option; what is not
acceptable is dispatching them independently.

**H8 — spec 3's M4 stays blocked and stays scheduled nowhere.** Spec 3's own
text: *"still blocked"*, *"Do not fold M4 into D"*, and its **OQ2 is still
open**. Spec 6's D11 and spec 1's opening section both note that spec 1's Step 2
— which registers on `PreToolUse (Bash)` as well as `Write|Edit` — *may*
independently satisfy M4's precondition as a side effect. **This graph does not
assume it.** M4 sits in W10 (unscheduled), and the only action is: after Step 2
lands, someone evaluates spec 3's A23 against it. Spec 3's standing warning
applies — *"Do not partially delete the corpus on a partial fix."*

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-08-25 Edge cases / failure handling: Q What happens if a sibling lands a
  wave out of order anyway? → A (self-resolved): nothing is force-blocked — this
  document adds no gate. `scripts/rollout-preflight.sh` reports the violated
  edge and the file the out-of-order commit touched. Adding a new enforcement
  gate to sequence six specs whose shared theme is that the harness has too many
  gates would be self-refuting. Unchanged from revision 1.
- 2026-08-25 Edge cases / failure handling: Q Does this document have standing
  to rule on H7, which is a conflict *inside* two siblings' scope? → A
  (self-resolved): yes for the **ordering**, no for the **substance**. E9 orders
  the two units and states which criteria break if the order is violated; it
  does not rewrite either spec's message design, and it offers the merge option
  the operator may prefer. Substance stays with specs 1 and 2.
- 2026-08-25 Terminology consistency: Q The revision-1 label space `M0–M6`
  collides with spec 3's own `M1`–`M4`. → A (self-resolved): renamed to
  `W0`–`W10` ("wave"). Verified free: `wave`/`W0`–`W7` returns 0 hits in five of
  the six specs and 1 incidental hit in spec 3, against 115 uses of `M1`–`M4`
  there. Every cross-reference in this document now says either `W<n>` (this
  graph) or `<spec> <its own label>` (a sibling's unit), never a bare `M<n>`.
- 2026-08-25 Terminology consistency: Q Does "wave" collide with `CONTEXT.md`'s
  existing "milestone" sense (`milestone-auditor`, on-demand milestone audit)? →
  A (self-resolved): no — which is the second reason to prefer it over
  "milestone". The scribe hint asks for one glossary entry.

## Risks / dependencies

- **R-1 (accepted, unchanged).** This document has no enforcement and
  deliberately adds none. Its value depends on the dispatcher consulting it.
- **R-2 (RETIRED).** Revision 1's R-2 carried the plugin-refresh dependency.
  Closed by F1; the residual is precondition P-live.
- **R-3.** Any wall-clock gate is machine-dependent; W3's latency gate is
  delegated to spec 2's AC-A1 rather than restated here, so this document
  introduces no second threshold that could disagree with a sibling's.
- **R-4.** F3's line counts and F7's ADR demand will move as specs land. They
  are dated 2026-08-25 readings recorded as *why the order is what it is*. No
  acceptance criterion asserts one; every criterion re-measures.
- **R-5.** `.claude/reviewed/` holds no `.fail` record for `rollout-map-1`,
  which is this spec's only unit id and has no history. No step here re-scopes a
  previously failed unit.
- **R-6.** This unit edits `tests/validate.sh`, which is the merge gate (P5) and
  is not in `protectedPaths` today. **Spec 2's Unit E may add it** (F6), since
  `tests/validate.sh` is not under `hooks/scripts/` but Unit E's rationale could
  extend there. Edge **E10** places this unit before Unit E for that reason, and
  Open Question 2 asks Unit E to say whether it claims that path.
- **R-7 (RETIRED and replaced).** Revision 1's R-7 said no version bump is owed
  here. Still true — `scripts/*.sh` and `tests/*.sh` carry no ADAPT stamp, and
  this unit touches no `agents/*.md` or `templates/*`. Restated as part of the
  allocation ruling rather than as a standalone risk.
- **R-8 — the graph can be wrong in a way this document cannot detect.** Every
  edge below is derived from the siblings' text as landed. A sibling that
  revises a unit's scope after today invalidates the edge silently. Mitigation:
  each edge names the sibling sentence it rests on, so a reviewer can re-check
  the edge by re-reading one paragraph rather than the whole document.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — F1, F2 and F3 were re-measured today
  rather than carried forward; the relay's two mistaken premises were caught by
  that check (C1, C2), as was H7, which no sibling had found.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied, and it is
  the justification for the single unit — six specs authored in separate
  sessions would otherwise each re-derive "may I start?" and "who owns this
  file?" from five other documents.
- P3 "Version-stamp discipline": **not applicable, deliberately** — this unit
  touches no version-stamped file, so no bump is owed and none may be taken;
  taking one would consume the number a sibling needs. The *serialization* of
  other specs' bumps is this document's subject and is not the same as owing
  one.
- P4 "Optional personas degrade gracefully": satisfied — the script names
  personas only in stderr prose and requires none to exist.
- P5 "`tests/validate.sh` is the merge gate": satisfied — the unit's test is
  wired into it, while the wave gates deliberately are **not**, since a
  repository sitting legitimately between W3 and W4 must not fail its own merge
  gate.

## Steps

### Step 1 — the wave graph and its preflight check

Add `scripts/rollout-preflight.sh`, embedding the tables below as data and
answering three questions:

- `scripts/rollout-preflight.sh <wave>` — may this wave's first unit be
  dispatched? Exit **0** if every predecessor edge is green; exit **1** naming
  each unmet edge and the measurement that found it unmet.
- `scripts/rollout-preflight.sh --owner <path>` — which specs edit this file
  during the rollout? Prints every claimant from the H2 table and the wave each
  claim belongs to. Exit 0 always (informational).
- `scripts/rollout-preflight.sh --resource <name>` — who owns
  `adr` | `version` | `changelog` | `protected-paths`? Prints the allocation
  ruling. Exit 0 always.
- `scripts/rollout-preflight.sh --reverify <spec>` — **the end-state check**,
  described below. Re-*executes* the named spec's still-mechanical acceptance
  criteria against a simulated end state, and exits non-zero on any that no
  longer hold.

#### The end-state check (`--reverify`)

Every defect the Fable review found — and both defects revision 3 corrects
here — belongs to one class, which the review named directly: *specs evaluated
at different times against a moving baseline, checked for text-consistency
rather than by executing each spec's criteria against the others' end states.*
Text-consistency review cannot catch it, because each document is individually
correct at the moment it is written. Two exemplars, both in spec 6 and both
being fixed directly by its own author rather than here:

- **A24** asserts `ls hooks/scripts/*.sh | wc -l` still returns **14**
  (re-measured today: it is 14). Spec 1's Step 2 adds
  `harness-integrity-gate.sh`, and spec 2's Unit C may add a marker-writing
  helper under the same directory. Against the rollout's end state the literal
  `14` is stale even though nothing in spec 6 is wrong.
- **A13** asserts a `git diff --stat <phase-1-base>..HEAD` over four reporter
  scripts is empty. Spec 2's Unit A and spec 4's Steps 1–2 modify two of those
  four. Whether A13 holds depends entirely on where `<phase-1-base>` lands
  relative to those waves — a diff range, not a claim.

**Requirement.** `--reverify <spec>` takes a spec id, materializes a scratch
worktree, applies every sibling change that has already landed, and re-runs that
spec's acceptance criteria that are *mechanical and end-state-sensitive* —
concretely: any criterion whose command contains a literal count, a file-path
glob, a `git diff` range, or a `grep -c` expectation. Criteria that are
reviewer-judgement (spec 6's A25b second half) or that require network/CI state
are listed as **skipped, with the reason**, never silently dropped.

**Process obligation this encodes:** after any sibling spec is amended, run
`--reverify` for every *other* spec that has landed units, before dispatching
anything further. The check is advisory in the sense that it gates no commit,
and binding in the sense that a wave gate reports it as unmet if it was never
run since the last amendment. It is scaffolding and sunsets with the script.

#### The wave graph

| id | wave | owner | blocking predecessors |
|---|---|---|---|
| **W0** | unbrick CI (`tests/cli-backfill.test.js` runner-only regression) | spec 6's P0, dispatched as an ordinary `lead-programmer` unit | — |
| **W1** | spec 3's M1 (reclaim dead artifacts; single-source the ignore list), then single-source the **thin-shim** ports: `graph-update.sh`, `lint-on-edit.sh`, `microworld-rerun.sh`, `protected-paths.sh` | spec 3, M1 → M2 tier 1 | — |
| **W2** | Microworlds workflow redesign, all 5 steps | spec 4 | W1 |
| **W3** | rerun latency + coverage on the now-single-sourced shim tier: spec 2 Unit A → Unit B; spec 2 Unit E | spec 2 | W1, W2 |
| **W4** | single-source the **independent-implementation** ports: `reviewer-route-gate.sh`, `stop-gate.sh` | spec 3, M2 tier 2 | W1 |
| **W5** | spec 1's ported steps, in its own order — Step 3 (seals) → Step 1 (`harness_armed`) → Step 9 (countersign); plus spec 3 M3 | specs 1, 3 | W3, W4 |
| **W6** | spec 1's unported steps — Step 2 (integrity gate), Step 5 (refusal hygiene), Step 6, Step 7, Step 8 | spec 1 | W5 |
| **W7** | spec 1 Step 4 — disarm-surface drift, incl. `reviewGating.mode` detection | spec 1 | W6 |
| **W8** | spec 6 Phase 1 — the CI path stands up beside the current one | spec 6 | W0, W2 |
| **W9** | spec 6 Phase 2 — `reviewGating.mode: "off"` + the ruleset | spec 6 | W3, W7, W8 |
| **W10** | **unscheduled**: spec 3 M4 (retire the textual-gate corpus) | spec 3 | W6, **plus spec 3's own A23 precondition and its open OQ2** |
| **float** | spec 2 Unit C (reduced per E9), spec 2 Unit D | spec 2 | Unit C: W6. Unit D: none |

#### The edges, each with the sibling sentence it rests on

- **E1: W0 → W8, W9.** Spec 6 A0: *"No other criterion in this spec may be
  evaluated until A0 holds."* W0 blocks **only** spec 6 — spec 1's R9 confirms
  specs 1–4 run locally and are unaffected, so W0 runs in parallel with W1–W7.
- **E2: W1 → W2. DECLARED OVERRIDE of a sibling's explicit sentence.** Spec 4's
  Step 1 edits `microworld-rerun.sh`, a thin-shim port (F3). Before M2 tier 1
  that is a four-copy hand edit which M2 then re-extracts; after it, one edit to
  the core.

  **This inverts spec 3's own stated ordering.** Spec 3's Further Notes says, in
  terms: *"Spec 4 (Microworlds) is a **prerequisite** and should land first."*
  E2 says the opposite. Recorded here rather than left silent, because this
  document's method is that every edge names the sibling sentence it rests on,
  and an edge that *contradicts* one owes at least as much.

  **Override rationale.** Spec 3's sentence is about *dependency* — spec 4
  produces `tests/watch-map.json`, which spec 3's M2 does not consume — while E2
  is about *edit cost*: with M2 tier 1 unlanded, spec 4's Step 1 pays the
  four-copy hand edit spec 2 documents as the current cost of every hook change,
  and M2 then re-extracts a file that just moved. Nothing in spec 3's M2 reads
  the watch-map, so reversing the order breaks no dependency in either
  direction; it only moves the cost. **If spec 3 disagrees, the fallback is
  cheap and safe:** run W2 before W1 and accept one four-copy edit to
  `microworld-rerun.sh`. No other edge changes, because nothing downstream of
  either wave distinguishes them. This is a preference backed by a measurement,
  not a correctness claim, and spec 3 may overrule it.

  *Second contradiction, resolved rather than overridden.* Spec 3 also states
  *"M1 → M2 → M3"*. Revision 2 scheduled M2 tier 1 in W1 and M1 in W3, inverting
  that too. **Fixed in revision 3 by moving M1 into W1 ahead of M2 tier 1**,
  which restores spec 3's order and is independently better: M1.2 and M2.2 both
  extend `bin/cli.js`'s generation machinery, and M1.1 removes a dashboard
  reader that spec 4's Step 4 register/bijection test would otherwise have to be
  authored against and then corrected.
- **E3: W1, W2 → W3.** Spec 2's Unit A edits `microworld-rerun.sh` (same
  inversion-A argument), and spec 4's D3 makes the rerun hook read the
  watch-map, so Unit A must be written against the post-spec-4 hook rather than
  the current one. Spec 2's own internal edge **Unit A → Unit B** (*"Unit B's
  skip precondition reads the queue state Unit A introduces"*) is preserved
  inside W3.
- **E4: W1 → W4.** Both are spec 3's M2; tier 1 establishes the
  `lib/<name>-core.sh` + shim contract that tier 2 reuses. Tier 2 is the hard
  half — spec 3 calls `reviewer-route-gate.sh` and `stop-gate.sh` *"effectively
  independent implementations"* that *"need real design work"*.
- **E5: W3, W4 → W5.** Spec 1's R7: Step 1 touches three ported scripts and
  Step 3 touches two, *"six hand-edits plus a copy of `lib/harness-arm.sh` into
  both adapter `lib/` directories"* — the cost M2 removes. Step 9 edits
  `microworld-rerun.sh` after spec 2's Unit A has restructured it.
- **E6: W5 → W6.** Spec 1's Step 2: *"Denials append one line to
  `.claude/review-audit.log` via Step 3's `audit_append`"* — Step 2 consumes a
  library Step 3 ships.
- **E7: W7 → W9.** Spec 1's R6 (Inversion B). **Escape hatch, preserved from
  spec 1's own wording:** if Step 4 cannot precede the flip, its baseline must be
  pinned to a pre-flip commit **and that choice recorded in the PASS marker**.
  The preflight check reports the edge as unmet-with-escape rather than
  unmet-flat, so the operator sees both options.
- **E8: W3 → W9. RE-RULED in revision 3 — the ordering stands, the semantics
  change.** Inversion C. Spec 6's A22 covers *"every path `protected-paths.sh`
  guards today"*; spec 2's Unit E changes what that set is (F6).

  **The defect revision 2 introduced.** Revision 2 ordered Unit E before Phase 2
  and stopped there — leaving A22's own wording ("every path") to drag the
  **expanded** `protectedPaths` list into the ruleset's `file_path_restriction`.
  Unit E's rule is that *every script under `hooks/scripts/`* is listed or
  exempted, so the expanded list plausibly covers most of `hooks/scripts/**`.
  Spec 6's **A17 requires the ruleset to have zero bypass actors**
  (`.bypass_actors | length` returns `0`). A server-side path restriction over
  `hooks/scripts/**` with no bypass actors blocks **the operator's own deliberate
  merges**, not only an agent's — on the single most-edited directory in this
  rollout, and permanently, not just for the rollout window. W10 (spec 3's M4)
  edits that directory and is still unscheduled, and ordinary maintenance of the
  14 hook scripts continues indefinitely. **Mirroring the full list is a
  self-inflicted freeze.**

  **Required semantics (this document's side of the contract).**
  1. Unit E's output tags **every** `protectedPaths` entry as either
     `local-only` or `server-mirror-eligible`. The tag is part of Unit E's
     deliverable, not an afterthought — an untagged entry is a Unit E defect.
  2. `server-mirror-eligible` means *"changes rarely, and freezing it
     server-side impedes no scheduled or foreseeable work."* At the time of
     writing that set is `.github/workflows/*` and `.claude/constitution.md` —
     which is exactly the live two-entry list A22 already measures today.
  3. **`hooks/scripts/**` and every entry Unit E adds for a hook script are
     `local-only` by default.** Promoting one to `server-mirror-eligible`
     requires a stated reason recorded with the entry.
  4. A22's `file_path_restriction` mirrors **only the `server-mirror-eligible`
     subset**, never the whole array.

  **Compatibility, either order of completion.** Spec 6's A22 is being corrected
  in parallel and this document does not declare its wording changed. Two cases,
  both safe:
  - *A22 is corrected to mirror only the eligible subset* — E8 is met; the edge
    is satisfied by Unit E's tagging existing before Phase 2 is evaluated.
  - *A22 lands unchanged, still reading "every path `protected-paths.sh` guards
    today"* — then after Unit E that phrase denotes the expanded list, and **the
    E8 gate reports unmet and W9 is not dispatchable** until the two documents
    are reconciled. It fails loudly rather than shipping the freeze.

  Note that A22 *as written today*, evaluated *before* Unit E, happens to
  produce the correct two-entry restriction. The hazard is created only by the
  combination of Unit E's expansion with A22's unqualified "every path" — which
  is precisely the seam-between-specs class the meta-finding names, and why this
  edge carries a gate rather than a note. Confirmation that spec 6's A22 landed
  compatibly is **Open Question 3**.
- **E9: W6 → spec 2's Unit C.** Hazard H7. Spec 1's Step 5 lands first; Unit C
  is then reduced to its marker-writing-helper deliverable. Merging the two into
  one unit is an equally acceptable alternative; independent dispatch is not.
- **E10: this unit → spec 2's Unit E.** R-6: Unit E rules on what belongs in
  `protectedPaths`, and this unit edits `tests/validate.sh`. Cheap to honour,
  since this unit has no other predecessor.
- **E11 (evaluation, not a blocker): W6 → W10.** Spec 6's D11 and spec 1's
  opening both observe that Step 2's Bash-half coverage *may* satisfy spec 3's
  M4 precondition. **Not assumed.** After W6, evaluate spec 3's A23 against the
  landed Step 2 gate; spec 3 adjudicates, and its OQ2 must be answered first.

#### The wave gates

Each re-measures at call time. **No constant from the Context section is
asserted by any gate**; where a sibling already owns a threshold, the gate
defers to that sibling's criterion by name instead of restating it.

- **P-live** (standing, not a wave): the session dispatching a unit whose
  criteria assert live gate behaviour was started after the plugin snapshot's
  `lastUpdated`, **or** every such criterion names the script path it exercises.
  Reported on every invocation, never blocking.
- **W0**: `gh run list --branch master --workflow validate --limit 1 --json conclusion --jq '.[0].conclusion'`
  prints `success` (measured `failure` at `09cc304a` today), plus spec 6's A0b
  non-vacuity proof on a pushed branch.
- **W1**: spec 3's M1 criteria, then its M2 criteria for the four thin-shim
  scripts, plus `bash tests/adapter-stop-gate-parity.test.sh` exit 0 and
  `bash tests/validate.sh` exit 0. The M1-before-M2 order inside the wave is
  spec 3's own (*"M1 → M2 → M3"*) and the gate must check them in that order.
  **No pin against deleting the parity tests is restated** — spec 3's M2.3
  already retargets rather than deletes, and duplicating the constraint here
  would create two owners for it.
- **W2**: `tests/watch-map.json` exists and spec 4's AC1.x–AC5.x are green.
- **W3**: spec 2's **AC-A1–AC-A7** (Unit A), **AC-B1–AC-B6** (Unit B) and
  **AC-E1–AC-E4** (Unit E), as written. Revision 2 omitted Unit B's criteria
  even though W3 contains Unit B; the wave gate must cover **every** unit in the
  wave, not only the ones named in the wave's one-line description. Delegated to
  spec 2's thresholds, not restated (R-3).
- **W4**: spec 3's M2 criteria for `reviewer-route-gate.sh` and `stop-gate.sh`,
  and `diff -r` over the generated trees is empty.
- **W5, W6, W7**: the named spec 1 steps' own criteria (`C1.x`, `C2.x`, `C3.x`,
  `C4.x`, `C5.x`, …) exit 0.
- **W8**: spec 6's A1–A16.
- **W9**: spec 6's A17–A28, **and** E7's and E8's predecessors green.
- **W10**: not dispatchable — spec 3's A23 precondition demonstrated **and** its
  OQ2 answered. The gate reports "blocked, by design" rather than failing.

#### Serialized-resource allocation (H3)

**ADR numbers.** Next free is **0026** (F7). Allocated to unconditional demand
first, then conditional:

| number | allocated to | basis |
|---|---|---|
| **0026** | spec 2, Unit D (amending ADR-0010) | unconditional; Unit D is a float with no predecessors, so it may write first |
| **0027** | spec 6 — **exactly one ADR**, covering both the CI-shaped architecture **and the D0 scope split as a section of it** | unconditional; cited by its own A25b and A27. **Spec 6's scribe hint currently hedges** — it asks for a *"New ADR (or a section of the same one) for the D0 scope split"*. That hedge is what a slicer would read as licence to take a second number. **Ruling: one ADR, 0027, D0 as a section.** Spec 6 is being corrected to pin this; if its text still hedges at dispatch time, the slicer follows this table, not the hedge |
| **0028** | spec 4, the conditional D9/D11 ADR | conditional — *"consider"*. **If declined, 0028 stays unused. Do not backfill it**, per this project's increment-never-backfill convention |
| 0029+ | unallocated | specs 1 and 3 owe none today; if spec 3's M4 ever unblocks and needs a supersession record, it takes the lowest free number at that time |

A pre-allocated number may land out of chronological order. That is accepted and
strictly preferable to a collision.

**Version stamp and CHANGELOG.** One bump per unit that edits `agents/*.md` or
`templates/*`, in that unit's own commit, with one CHANGELOG entry per bump.
Because the waves already serialize those units, no separate lock is needed; the
check is that `.claude-plugin/plugin.json`'s version strictly increases across
those commits and each bump has a matching CHANGELOG entry. Editing
`hooks/scripts/` alone owes no bump (F8). **This unit takes no version number.**

**`protectedPaths`.** Written by **spec 2's Unit E** (F6), and by nothing else.
Spec 1's Step 2 is configless and writes no config; spec 3's A30 constrains its
own units from changing config posture; spec 6's Phase 2 writes a *different*
key (`reviewGating.mode`), which spec 3 and spec 6 have already agreed is not a
literal conflict.

**Affected files**

- `scripts/rollout-preflight.sh` (new)
- `tests/rollout-preflight.test.sh` (new)
- `tests/validate.sh` (one wiring block, in the established
  `if bash …; then OK … else FAIL … fail=1 fi` shape)

**Acceptance criteria**

1. `bash -n scripts/rollout-preflight.sh` exits 0 and `bash tests/validate.sh`
   exits 0 at the unit's own commit.
2. `bash scripts/rollout-preflight.sh W0` exits non-zero **today** and prints the
   `validate` workflow's latest conclusion on `master` — i.e. the check
   reproduces F2 rather than asserting it. Reviewer verifies against a direct
   `gh run list`.
3. `bash scripts/rollout-preflight.sh W9` exits non-zero and names **W3, W7 and
   W8** as the unmet blocking predecessors — not a generic failure. Mutation
   proof: deleting the `W7 → W9` edge from the embedded table makes this
   criterion fail, so that edge is the sole denier of the assertion.
4. `bash scripts/rollout-preflight.sh W7` reports E7's **escape hatch** in its
   output — the message names both "land Step 4 before the flip" and "pin the
   baseline to a pre-flip commit and record it in the PASS marker". A message
   offering only the first is a criterion failure, because it would overstate a
   sibling's own stated option.
5. `bash scripts/rollout-preflight.sh W10` exits non-zero with a reason
   containing `blocked` and naming spec 3's A23 **and** its OQ2 — W10 must never
   report as merely "not yet reached".
6. `--owner hooks/scripts/microworld-rerun.sh` prints **four** claimants (specs
   1, 2, 3, 4) with their waves; `--owner hooks/scripts/reviewed-path-gate.sh`
   prints specs 1, 2 and 3 **and** the H7/E9 note; `--owner .github/workflows/`
   prints spec 6 alone.
7. `--resource protected-paths` prints spec 2 Unit E, **not** spec 1 — the
   revision-2 reallocation is the thing this criterion pins, since revision 1
   said the opposite. It also prints the E8 tagging rule, including the sentence
   that `hooks/scripts/**` entries are `local-only` by default. `--resource adr`
   prints the 0026/0027/0028 table including **both** the do-not-backfill rule
   and the "one ADR for spec 6, D0 as a section" ruling.
7b. `bash scripts/rollout-preflight.sh W9` names E8's required semantics in its
   output when the edge is unmet — specifically that only the
   `server-mirror-eligible` subset feeds spec 6's A22. A W9 report that names
   E8 as unmet without naming the subset rule fails this criterion, because the
   bare edge name is what revision 2 had and it was not enough to prevent the
   freeze.
8. `bash scripts/rollout-preflight.sh` with an unknown wave id, and with
   `--owner ''`, both exit non-zero with a named reason and no `set -e` abort or
   stack trace.
9. `bash tests/rollout-preflight.test.sh` exits 0, contains **at least one
   assertion per wave id W0–W10**, and each is mutation-proved: the test file's
   header records, per wave, which single line of the embedded table was deleted
   to make that assertion fail. A wave whose assertion survives its own edge's
   deletion is vacuous and fails this criterion.
10. `grep -c 'rollout-preflight' tests/validate.sh` returns exactly 1 wiring
    block, and `tests/validate.sh` never invokes the script **with a wave
    argument** — the wave gates must not become part of the merge gate (P5).
11. **Sunset criterion.** The script's help text and file header both state,
    verbatim: *"delete this file, its test, and its `tests/validate.sh` block
    once W9 is green and W10 is adjudicated; it is rollout scaffolding, not a
    harness feature."* Checked by `grep`.
12. **`--reverify` is real, not a stub.** `--reverify 6` selects spec 6's
    end-state-sensitive criteria and, on a scratch worktree seeded so that
    `hooks/scripts/` holds **15** scripts rather than 14, **reports A24 as
    failing**. On an unmodified worktree it reports A24 as passing. Both halves
    asserted — a `--reverify` that always passes, or always fails, is vacuous.
13. **`--reverify` never silently drops a criterion.** For the spec named, the
    count of `checked` plus `skipped` equals the count of criteria the script
    selected, every `skipped` entry carries a reason string, and spec 6's A25b
    appears as `skipped: reviewer-judgement` rather than as checked or absent.
14. **The staleness gate is wired to amendments.** A wave gate whose spec has
    been amended since the last recorded `--reverify` run reports that as an
    unmet condition naming the spec and the amendment time. Mutation proof:
    touching a sibling spec file makes the affected wave's report flip from
    green to unmet-on-staleness.
15. `git diff --quiet hooks/ .claude/ agents/ templates/ adapters/ bin/
    microworlds/ .github/ docs/adr/ CHANGELOG.md .claude-plugin/` at the unit's
    own commit — this unit touches nothing any sibling owns and takes no
    serialized resource.

**Do NOT touch**: anything under `hooks/`, `.claude/`, `agents/`, `templates/`,
`adapters/`, `bin/`, `microworlds/`, `.github/`, `docs/adr/`;
`.claude-plugin/plugin.json`; `CHANGELOG.md`; and the substance of any sibling
spec.

## Open Questions

1. **Does spec 2 owe a version bump and CHANGELOG entry it has not declared?**
   Unit D's Deliverable 3 edits `agents/lead-programmer.md`,
   `agents/orchestrator.md` and `agents/task-master.md` — three version-stamped
   files — and spec 2 has **no Constitution check section at all** (F8).
   Constitution P3 is a MUST. **Recommended default: yes — Unit D takes one
   version bump plus one CHANGELOG entry, in its own commit, alongside ADR-0026.**
   This document allocates the resources on that assumption but cannot impose
   the obligation on another spec. *(Originates from CHK6.)*
2. **Is the H5 gap ratified, and does spec 2's Unit E claim `tests/validate.sh`?**
   Two halves of one operator decision about what `protectedPaths` covers.
   (a) At the end of this rollout, `hooks/`, `.claude/hooks/` and `settings.json`
   are protected by nothing (F5, H5). **Recommended default: accept the gap** —
   revision 1's own measurement and ADR-0025 both argue a `hooks/` deny-all
   would generate false positives faster than it prevents tampering — but record
   the acceptance rather than inheriting it by omission. (b) Unit E's rule
   ("every script under `hooks/scripts/` is listed or exempted") does not say
   whether `tests/validate.sh` is in scope; if it is, edge E10 matters and this
   unit must land first. **Recommended default: no, the merge gate is not a
   protected path** — protecting it makes every future test wiring an operator
   interruption. *(Originates from CHK9.)*

3. **Did spec 6's A22 land compatibly with E8's required semantics?** E8 needs
   A22 to mirror only the `server-mirror-eligible` subset of `protectedPaths`
   into the ruleset's `file_path_restriction`, never the whole array, and needs
   spec 2's Unit E to emit that tag. Spec 6's A22 is being corrected in parallel
   and this document does not declare its wording changed. **Recommended
   default: confirm by reading spec 6's A22 immediately before dispatching W9**
   — if it still reads "every path `protected-paths.sh` guards today"
   unqualified, W9 is not dispatchable until reconciled, which is what the E8
   gate reports. Both completion orders are safe; only *skipping the check* is
   not. *(Originates from CHK19.)*

## Self-check

- CHK1: Was every claim in the coordinating relay verified against the files
  rather than accepted? — PASS (all five sibling documents read on disk; two
  premises failed the check and are corrected in C1 and C2; M0 and the CI state
  were re-measured independently rather than taken on report).
- CHK2: Does the graph actually contain spec 6, with P0 before Phase 1 before
  Phase 2? — PASS (W0 → W8 → W9, each with the spec-6 sentence it rests on;
  E1 additionally records that W0 blocks *only* spec 6).
- CHK3: Is spec 1's Step 4 placed relative to D's flip as a real edge rather
  than a note? — PASS (E7, `W7 → W9`, with a mutation-proved criterion in AC3
  and a dedicated criterion in AC4 for the escape hatch).
- CHK4: Does the plan preserve spec 1's *stated alternative* to that edge, or
  does it over-tighten a sibling? — FAIL (missing) — revised in place: the first
  draft made E7 an unconditional hard edge, which would have overridden spec 1's
  own "or pin the baseline to a pre-flip commit and record it in the PASS
  marker". AC4 now requires the preflight message to offer both routes.
- CHK5: Are the ADR and version-stamp contentions resolved against **verified**
  demand, or against revision 1's stale allocation? — FAIL (conflicting) —
  revised in place: revision 1 allocated 0026–0030 to milestone names no sibling
  adopted, and **no sibling claims any of them**. F7 re-derives demand by
  quotation, and the table is rebuilt: 0026 → spec 2, 0027 → spec 6, 0028 →
  spec 4 (conditional, do not backfill).
- CHK6: Does the plan state whether spec 2 owes a P3 bump? — FAIL (missing) —
  revised in place: F8 tabulates every spec's obligation and finds spec 2's
  undeclared; converted to Open Question 1 rather than asserted, since this
  document cannot impose an obligation on a sibling.
- CHK7: Is spec 3's M4 kept blocked, without being silently dropped or wrongly
  unblocked? — PASS (H8 and W10; the W10 gate reports "blocked, by design", AC5
  requires it to name both A23 and OQ2, and E11 is explicitly an evaluation edge
  rather than a blocker).
- CHK8: Did the plan find anything the siblings missed, or only re-file what
  they already said? — PASS (H7: spec 1's Step 5 and spec 2's Unit C rewrite the
  same denial stderr lines in the same two gates; neither spec names the other;
  spec 1's C5.5 exact-assertion-count criterion fails if Unit C lands first).
- CHK9: Is the `hooks/` protection gap recorded rather than assumed closed? —
  FAIL (missing) — revised in place: the first draft treated item 2 as fully
  discharged by spec 1's Step 2. F5 shows Step 2 protects five *literals*, not
  the five *classes* the recommendation named; H5 records the residual and Open
  Question 2 asks for ratification.
- CHK10: Does the label space avoid collision with any sibling's? —
  FAIL (conflicting) — revised in place: revision 1's `M0–M6` collided with spec 3's
  `M1`–`M4` (115 uses). Renamed to `W0`–`W10`, verified nearly free across all
  six documents.
- CHK11: Does any wave gate restate a threshold a sibling already owns? — PASS
  (W3 defers to spec 2's AC-A1 by name; W1/W2/W5–W9 defer to their owners'
  criteria; R-3 records why, and revision 1's own 5 s latency threshold was
  deliberately dropped rather than left to disagree with spec 2's 211.96 s
  baseline).
- CHK12: Does the plan avoid re-asserting constraints a sibling has since
  encoded better? — PASS (revision 1's "do not delete the parity tests" pin is
  withdrawn, because spec 3's M2.3 retargets rather than deletes; W1's gate says
  so explicitly rather than creating a second owner).
- CHK13: Does every Self-check FAIL have a resolution, and every Open Question
  an originating CHKn? — PASS (**eight** FAILs across both revisions — CHK4,
  CHK5, CHK6, CHK9, CHK10 from revision 2 and CHK16, CHK17, CHK18 from revision
  3 — all "revised in place"; OQ1←CHK6, OQ2←CHK9, OQ3←CHK19, each cited in the
  question itself).
- CHK14: Does the plan avoid becoming the ceremony it sequences? — PASS (one
  script, one test, one wiring block, no new gate, and AC11 pins a verbatim
  sunset condition tied to W9 and W10; `--reverify` is scaffolding that sunsets
  with the rest of the script rather than a permanent process).
- CHK15: Is the retirement of M0 justified by measurement rather than by the
  relay's say-so, and is the residual carried? — PASS (F1 re-measures the
  install path, version and byte-parity directly; the residual — the 0.31.57
  directory still on disk, so a pre-update session still executes it — is
  carried as standing precondition P-live and reported on every invocation).
- CHK16: Does any wave gate omit a unit the wave contains? — FAIL (missing) —
  revised in place (revision 3): W3 contains spec 2's Unit B, but its gate cited
  only AC-A1 and AC-E. The gate now names AC-A1–A7, AC-B1–B6 and AC-E1–E4, and
  the wave-gate rule is stated generally — cover every unit in the wave, not
  only those named in the wave's one-line description.
- CHK17: Does every edge that *contradicts* a sibling's explicit sentence cite
  and reconcile it, as the plan's own method requires? — FAIL (missing) —
  revised in place (revision 3): E2 inverts spec 3's *"Spec 4 (Microworlds) is a
  prerequisite and should land first"* and revision 2 said nothing. E2 now
  quotes it, gives the edit-cost rationale, and names the cheap fallback if
  spec 3 overrules. A second contradiction found in the same pass — spec 3's
  *"M1 → M2 → M3"* versus revision 2's M2-tier-1-before-M1 — was **resolved**
  rather than overridden, by moving M1 into W1 ahead of M2 tier 1.
- CHK18: Does E8 state what spec 6's A22 must mirror, or only when Unit E must
  land? — FAIL (ambiguous) — revised in place (revision 3): revision 2 gave an
  ordering with no semantics, which would have let A22's unqualified "every
  path" mirror the expanded `protectedPaths` into a zero-bypass-actor ruleset
  and freeze `hooks/scripts/**` server-side, permanently, against the operator
  too. E8 now carries the four-point tagging contract, and AC7b requires the W9
  report to name the subset rule rather than the bare edge.
- CHK19: Does the plan resolve E8 without asserting a change to a sibling's
  criterion that sibling has not made? — PASS (E8 states this document's
  required semantics and enumerates both completion orders; if spec 6's A22
  lands unchanged the gate reports unmet and W9 is undispatchable, so the
  failure mode is a loud block rather than a silent freeze. Confirmation is
  Open Question 3, not an assumption).
- CHK20: Does the plan address the review's meta-finding with a mechanism, or
  only by acknowledging it? — PASS (`--reverify <spec>`, with AC12 requiring a
  seeded 15-script worktree to make spec 6's A24 actually fail and an unmodified
  one to make it pass, AC13 forbidding silent drops, and AC14 tying wave-gate
  staleness to sibling-spec amendment time).
- CHK21: Is the ADR hedge closed in a way a slicer will actually follow? — PASS
  (the 0027 row quotes spec 6's *"New ADR (or a section of the same one)"*
  hedge, rules one ADR with D0 as a section, and states that the table wins if
  spec 6's text still hedges at dispatch time — so the slicer needs no second
  document to resolve it).
## Scribe update hint

After the unit lands, in one pass:

- `CONTEXT.md`: add **rollout wave** as a glossary entry, distinguished from the
  existing `milestone-auditor` / on-demand-milestone-audit sense, and noting the
  deliberate rename away from `M<n>` to avoid collision with spec 3's labels.
- `CONTEXT.md`: the **Harness** and **Gate** entries should say which copy of a
  hook actually executes (the plugin snapshot, not the working tree) and that
  the snapshot changes path on update — the P-live residual in one sentence.
- No ADR is owed by this spec. The numbers it *allocates* (0026–0028) are written
  by the specs that use them; the allocation table is rollout scaffolding and is
  removed with the script at sunset.
- No CHANGELOG entry and no version bump (P3, above).

## Dispatch note (fast path)

One unit; no tracker issue is filed, so the retrieval contract points at this
document by path.

### Unit: rollout-map-1

## Objective

Add `scripts/rollout-preflight.sh` encoding the W0–W10 wave graph, the eleven
edges, the file-ownership table and the serialized-resource allocation from
Step 1, plus `tests/rollout-preflight.test.sh`, wired into `tests/validate.sh`.
The script reports; it gates nothing.

## Retrieval

`docs/plans/2026-08-25-streamlining-rollout-sequencing.md`, Step 1. The wave
table, the edge list with their quoted bases, the wave gates and the
serialized-resource allocation are all normative and must be encoded verbatim as
data, not paraphrased into control flow.

## Affected files

- `scripts/rollout-preflight.sh` (new)
- `tests/rollout-preflight.test.sh` (new)
- `tests/validate.sh` (one wiring block)

## Ordered edits

1. Write `scripts/rollout-preflight.sh` with the wave graph, edge list,
   ownership table and resource allocation as embedded data at the top of the
   file, and the four entry points (`<wave>`, `--owner <path>`,
   `--resource <name>`, `--reverify <spec>`) below it. Include the verbatim
   sunset sentence from AC11 in both the file header and the help text.
2. Implement the wave gates. Every one re-measures at call time; none may
   hard-code a version, line count, timing or ADR number from the Context
   section. Where a gate defers to a sibling's criterion, it prints that
   criterion's identifier rather than re-implementing its threshold.
3. Implement P-live as a line printed on every invocation, never as a blocking
   condition.
4. Write `tests/rollout-preflight.test.sh` with at least one assertion per wave
   id and the per-wave mutation record required by AC9.
5. Wire the test into `tests/validate.sh` in the established shape. Do not
   invoke the script with a wave argument from `tests/validate.sh`.

## Do NOT touch

`hooks/**`, `.claude/**`, `agents/**`, `templates/**`, `adapters/**`, `bin/**`,
`microworlds/**`, `.github/**`, `docs/adr/**`, `.claude-plugin/plugin.json`,
`CHANGELOG.md`, and the substance of any sibling spec — no gate, marker, packet,
bundle or CI behaviour changes in this unit.

## Acceptance criteria

Criteria 1–15 of Step 1 verbatim, including 7b.

## Pre-resolved context

- **W0 is red today and that is expected.** `validate` on `master` concluded
  `failure` at `09cc304a`; AC2 requires the check to *reproduce* that. A green
  W0 at this unit's commit is a bug in the check, not good news.
- **The plugin snapshot drift is closed** (repo and cache both 0.31.63,
  byte-identical), but the 0.31.57 directory still exists, so a session started
  before today's update still executes it. That is P-live, and it is a report
  line, not a gate.
- **`hooks/scripts/stop-gate.sh` has no microworld bundle watching it**, so this
  unit's own edits pay none of the 117.9–161.4 s reactive-rerun cost. Do not add
  a bundle for it; W3 reduces that coverage rather than extending it.
- **Revision 1 said `protectedPaths` was spec 1's to write. It is spec 2 Unit
  E's.** AC7 pins the corrected allocation specifically because the earlier
  reading was the opposite; do not restore it from memory of the older document.
- No file in this unit is version-stamped. Taking a version number or an ADR
  number here would consume one a sibling needs.

## Escalation

If a wave gate cannot be measured without invoking a sibling's not-yet-existing
code, do **not** invent a placeholder that returns green. Report the wave and
the missing dependency; a gate that cannot be measured must exit non-zero and
say so, which is what W0 and W10 already do by design.

---

### Amendment A1 (2026-09-23, unit rollout-a24-remechanize-1)

**AC12 deviation recorded.** AC12 (Step 1) demands: *"a `--reverify` that always
passes, or always fails, is vacuous."* The spec measured two halves: (1) `--reverify 6`
selects spec 6's end-state criteria and (2) on a mutated worktree seeded with 15 scripts
instead of 14, reports A24 as failing. That second half is no longer measurable post this unit.

**Reason for acceptance:** A24 itself has been converted from a hardcoded script-count
assertion to a documented skip. A24's criterion is scoped to a not-yet-authored **flip unit**
commit (the Phase 2 disablement-flip) whose own `git diff --diff-filter=D` will be the
assertion; with no diff-range yet defined and no code in-tree to measure, A24 correctly
reports "skipped" and cannot fail. The treadmill that motivated A24's redesign (manual
baseline bumps each time a new `hooks/scripts/*.sh` landed: gh418, gh420, spec2-unitC,
version-stamp-guard-1) is now permanently ended.

**Implication for future measurement:** AC12's second half (--reverify response to mutation)
becomes a deferred property: it will become measurable only after the flip unit lands and
A24 transitions from skip to live assertion. The first half (--reverify exists and selects
spec 6) remains live and verified. Per the "if a gate cannot be measured" rule in
Escalation, a criterion that cannot be measured must report that state explicitly — A24's
`skipped: flip unit` entry satisfies this; a gate that *stops skipping* after the flip unit
lands will naturally re-measure the deviation at that time.
