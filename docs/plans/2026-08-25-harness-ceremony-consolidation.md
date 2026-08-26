# Harness ceremony reduction: consolidation and single-sourcing

Status: **FINAL — dispatch-ready, revised 2026-08-25 after spec 6 adoption**
(spec-master). Resolves to **seven units** across four milestones — **unchanged
from the original**; M1-M3 dispatchable now, M4 still blocked on its own
precondition. Tracker publication applies (≥6, per ADR-0024 Step 3) — see
[Further notes](#further-notes).

> **Revision note (2026-08-25).** The operator has adopted **spec 6, CI-shaped
> review** (`docs/plans/2026-08-25-ci-shaped-review-architecture-d.md`, "D") as
> a full replacement for **this repository's own operational gate enforcement**.
> Spec 6's blocking **OQ1 is resolved to "full replacement of this repo's own
> enforcement path, product untouched"**: this repo stops *using* the in-session
> gate battery on itself, while the plugin **continues to ship it** for adopting
> projects. Nothing is deleted from the repo or the product — spec 6's D11 is a
> **disablement manifest** (a `reviewGating.mode: "off"` config flip), not a
> deletion manifest.
>
> **Net effect on this spec: all four milestones survive unchanged.** Spec 6's
> own reconciliation row is explicit — *"Land M1, M2 and M3 on their own
> schedule — no OQ1 dependency remains. Leave M4 blocked and do not fold it into
> D."* What changes is **justification and urgency, not scope**, and those
> changes are recorded per-milestone in [Solution](#solution). No measured
> number in this document is affected; all measurements stand as taken at
> `09cc304`.
>
> **A correction worth recording.** An intermediate draft of spec 6 claimed that
> D *dissolved* M4's blocking precondition by deleting the marker directory, and
> that M4's deletion manifest should be reused as D's Phase 2 manifest. **Spec
> 6's D11 has since reversed that claim in its own words** — *"Under the OQ1
> ruling that claim is false, and it would have been an expensive error to act
> on"* — because the marker directory and its gates remain in the product. This
> spec's M4 therefore **stays blocked exactly as originally written**, and its
> OQ2 remains live. See [M4](#m4--retire-the-textual-gate-corpus-still-blocked).

Scope: **process/artifact volume that exceeds what the actual risk justifies** —
consolidation and single-sourcing only. This is spec 3 of 6 derived from one
adversarial architecture critique. It deliberately does **not** address trust
properties (sibling 1), token/latency cost (sibling 2), the microworld bundle
lifecycle's conceptual shape (sibling 4), general streamlining (sibling 5), or
the CI-shaped review architecture (spec 6). Overlaps are noted inline; every
acceptance criterion below is scoped to ceremony volume.

Every count in this document was measured live against the working tree at
`09cc304` on 2026-08-25. No number is inferred, and where the originating
critique's figure differs from the measured one, **both are shown**.

**A note on how these measurements were taken.** `reviewed-path-gate.sh` blocked
one of this session's own read-only census commands (a `for` loop over `ls`,
using command substitution) — a first-person instance of the false-positive
class ADR-0025 exists to bound. The census was re-taken with `find`, which does
not spell the protected path contiguously. Nothing here wrote, or attempted to
write, this repository's marker or `DECISION` files.

---

## Problem statement

The operator maintains a review-gating harness whose *mechanism* is about 7,800
lines and whose *surrounding process artifacts* are about 84,700 — a ratio near
**11:1**. The mechanism is not the problem; the volume of hand-maintained
material orbiting it is, and three specific shapes of that volume cost the
operator real time on every change:

| Area | Files | Lines |
|---|---|---|
| `hooks/scripts/` (canonical mechanism) | 16 | 2,673 |
| `.claude/hooks/scripts/` (generated mirror) | 16 | 2,673 |
| `adapters/` (total) | 30 | 3,438 |
| — of which `adapters/*/hooks/scripts/` | 14 | 1,995 |
| `agents/` | 9 | 1,660 |
| `templates/` | 6 | 932 |
| `bin/cli.js` | 1 | 2,499 |
| `tests/` | 39 | 19,687 |
| `docs/plans/` | 57 | 51,405 |
| `docs/adr/` | 24 | 2,063 |
| `docs/specs/` | 6 | 1,948 |
| `.claude/wiki/` | 13 | 2,337 |
| `.claude/agent-memory/` | 115 | 5,584 |
| `CONTEXT.md` | 1 | 1,680 |

**1. A hook change must be hand-propagated, and in practice is not.** Of the
last 15 commits touching `hooks/scripts/`, **13 also updated the `.claude/`
mirror** (which `bin/cli.js` generates and `tests/validate.sh` transitively
enforces) but only **3 also updated the adapters**. The adapter ports therefore
drift by default — 12 of 15 changes skipped them — and the project's response
was a **624-line parity test that detects the drift after the fact** rather than
a generator that prevents it. The same duplication has already reproduced itself
in a second organ: the operational `.gitignore` list exists in **four**
hand-maintained copies (this repo's own `.gitignore`, plus three literal arrays
in `bin/cli.js` at the `--update` backfill, the cursor scaffold and the codex
scaffold), and it has **already drifted** — `.review-join.*` appears in this
repo's `.gitignore` but in **zero** of the three arrays `cli.js` writes, so no
adapted downstream project ignores it.

**2. The textual-gate layer is defended out of all proportion to its size.**
861 lines of gate (`reviewed-path-gate.sh` 286 + `human-decision-gate.sh` 342 +
the exclusively-theirs lexer `lib/benign-command.sh` 233) are surrounded by
roughly **10,100 lines** of dedicated test corpus, plans, ADR text, glossary and
README treatment — a **11.7:1** defence-to-mechanism ratio. The layer still does
not close: a standing `.fail` record in this repo enumerates live fail-opens
(backslash removal, ANSI-C escapes, and a glob sub-class that overwrites an
already-made human decision) that the corpus does not catch. Meanwhile the layer
blocks the operator's own read-only commands.

**3. On-disk coordination state has accreted into many small species that
nothing sweeps.** Thirteen live artifact species (the critique said nine),
plus one dead-but-git-tracked artifact, one orphan with a reader and no writer,
and one adapter-only species. They accumulated over six weeks — session-baseline
and wip-handoff (Jul 4), pending-review (Jul 13), dispatch-override (Jul 30),
review-join (Aug 7), marker-commit (Aug 16) — each patching a gap the previous
one opened. Nothing prunes them: **342 files / 16,619 lines** in the marker
directory, **120** session baselines dating to 2026-07-28, **12** stale WIP
handoffs from agents that never re-stopped, and four append-only logs that are
never rotated (`review-audit.log` alone is 4,114 lines / 255 KB). Exactly one
sweeper exists in the whole system (`bin/human-review-cleanup.sh`), covering
exactly one species.

**4. The operator has already voted on which ceremony is worth its friction.**
The live `.claude/persona-config.json` carries `humanReviewMode: "off"`,
`dispatchHygiene.mode: "warn"` and `markerCommitCheck.mode: "warn"`. The
human-review surface is consequently **live-dead in this repo**: zero packets on
disk. That is prioritisation evidence — consolidating a surface that is
currently inert costs nothing observable — but it is **not** licence to remove
the capability, and this spec removes none.

---

## Solution

Four milestones, ordered by *(volume removed) ÷ (risk taken)*. Each one
**single-sources or consolidates**; none removes a capability. The governing
precedent is ADR-0024's own framing, which this spec adopts verbatim as a
constraint: *reduce friction and duplication, keep every mechanism reachable.*

Post-adoption verdicts, stated explicitly so nothing is ambiguous. All four
milestones survive; the column that changes is *why*, not *what*:

| Milestone | Verdict under spec 6 | What changed | Units |
|---|---|---|---|
| **M1** — Reclaim dead and unswept artifacts; single-source the ignore list | **SURVIVES intact.** Orthogonal to D; land regardless. | M1.3 gains a second audience (below). | 2 |
| **M2** — Single-source the hook ports | **SURVIVES intact.** The ports are product; D0 keeps the product. | Justification moves from posture to product; the dogfooding drift-detector is lost. | 3 |
| **M3** — Consolidate state artifacts by key domain | **SURVIVES intact.** The state artifacts remain the shipped mechanism. | Becomes product work; this repo stops *populating* the artifacts. | 1 |
| **M4** — Retire the textual-gate corpus | **STILL BLOCKED**, on exactly the precondition originally written. | Off this repo's critical path; urgency drops to "schedulable whenever". | 1 |

**Why M2 survives.** The test the coordinator set is whether the milestone
still applies to the *shipped* hook battery now that this repo stops running it.
For M2 the answer is unambiguous yes, for three reasons and one that spec 6
states itself:

1. **M2's subject is the adapter ports** (`adapters/codex/`,
   `adapters/cursor/`), which are separate products D does not touch at all.
   The cost M2 removes — hand-propagating every hook change into two adapter
   trees, which measurement showed **12 of the last 15 commits failed to do** —
   is a *product maintenance* cost, not a *this-repo-enforcement* cost. D
   changes the latter and leaves the former exactly as it was.
2. **Spec 6's own conditional returns "survives."** Its OQ1 answer (a) — the one
   adopted — reads: *"this repo stops using the battery on itself; the plugin
   still ships it. Sibling 3's M2/M3 stay valuable."*
3. **D strengthens M2's rationale rather than weakening it.** Until now,
   dogfooding was an informal drift detector: a broken hook eventually bit the
   operator. Once this repo stops running the battery, **that detector is gone**,
   and generation (M2.2) plus the retargeted parity tests (M2.3) become the
   *only* remaining defence against adapter drift in shipped code. A milestone
   whose value depends on losing a feedback loop becomes *more* valuable when
   that loop is removed, not less.

**Why M3 survives intact.** M3 passes the same test: the 13 species are created
by the shipped hooks in **every adopting project**, so consolidating them is a
product improvement that D does not touch. Spec 6 initially advised against
executing M3's Unit domain, then **withdrew that guidance in its own words**:
*"An earlier draft of this spec said not to execute it because D would delete
that domain. Under D0 that is wrong and the guidance is withdrawn: the marker
directory remains the product's mechanism, M3 is product work, and it should
proceed. This repo will simply stop populating it."*

Two honest qualifications, which change how M3 is executed but not whether:

1. **It becomes product work executed without dogfooding.** This repo will stop
   populating `.claude/reviewed/`, `.pending-review.*` and the rest, so the
   consolidation cannot be validated by simply using it. **ADR-0016 is a
   standing warning about precisely this code** — it *de*-consolidated a global
   watermark into per-unit stamps to fix a deadlock. This raises the burden of
   proof on M3's tests rather than lowering M3's value: A19's mutation proofs and
   A20's concurrency test are now the only feedback loop, and neither may be
   relaxed.
2. **Its local volume motivation is frozen, not removed.** The 342 markers, 120
   baselines, 12 handoffs and 4,114-line log stop growing here. That backlog is
   M1.3's one-time reclaim; M3's remaining justification is the product's
   ongoing complexity, which is real but no longer something the operator feels
   daily. **Sequence M3 after M1 and M2 accordingly.**

**Why M4 stays blocked — and why an intermediate draft said otherwise.** M4 is
**not superseded**. An intermediate draft of spec 6 claimed D dissolved M4's
precondition by deleting the marker directory; **spec 6's current D11 reverses
that finding explicitly**, and the reversal is load-bearing:

- The marker directory and its gates **remain in the product**, so the question
  M4 asks — *how is a marker write denied mechanically rather than lexically?* —
  is still live for every downstream adopter.
- D11's own words: *"Under the OQ1 ruling that claim is false, and it would have
  been an expensive error to act on."*
- What actually changed is M4's **urgency and critical path**: it moves from
  "blocking this repo's ceremony reduction" to "product hardening, schedulable
  whenever," because this repo no longer depends on the answer.
- **This spec's OQ2 is therefore still live**, not moot, and spec 6 says so
  directly: *"Spec 3's OQ2 … is unaffected and still needs its answer."*
- **Do not execute any part of M4 as part of D.** The two are cleanly disjoint:
  D changes which mechanism decides *this repo's* merges; M4 changes what the
  *product* ships. M4's standing warning applies unchanged — *do not partially
  delete the corpus on a partial fix.*

### Correcting the critique before building on it

Three of the critique's premises do not survive measurement, and building on
them as stated would cause damage:

| Critique claim | Measured reality |
|---|---|
| "Four hand-maintained copies of every hook script" | **Two** identical trees and **two** partial ports. `.claude/hooks/scripts/` is **already machine-generated** by `buildHookScriptSpecs()` (`bin/cli.js`), content-hash-tracked in `persona-config.json`, and currently **`diff -rq` clean**. The adapters carry **7 of 16** scripts each. |
| "These already diverge" | True of the **adapters** (by design *and* by drift); **false** of the `.claude/` mirror, which is byte-identical. |
| "`cli.js` should generate the adapter copies from canonical `hooks/scripts/`" | **Not implementable as stated.** The ports genuinely differ in payload extraction: codex resolves the project dir from the payload's `.cwd` and parses OpenAI `apply_patch` multi-file patch headers; cursor reads `.workspace_roots[0]`, downcases event names, uses `subagent_type` not `agent_type`, and replaces `stop_hook_active` with a `loop_count` guard. Verbatim generation would destroy real logic. |
| "Parity tests become redundant and should be removable" | **Half true.** `adapter-stop-gate-parity.test.sh` (624) can shrink once the shared core is generated. `adapter-protocol-parity.test.js` (176) must **stay**: the two protocol ports are *abridged rewrites* (331 and 342 lines against 570 non-blank canonical lines), not mechanical transforms, so they can never be generated. |
| "Nine dotfile species" | **13 live + 1 dead + 1 orphan + 1 adapter-only.** |
| "Gate headers say the layer is fundamentally incomplete lexically" | The phrase appears in **no** script header. The scripts say *"advisory, not airtight"* with enumerated `STILL OPEN` residuals; *"fundamental hazard"* is ADR-0025's wording and *"not a security boundary"* is README.md's. |
| "~628 lines of gate, ~1,900 of test corpus" | **Exactly right**: 628 and 1,892. |
| "Q1-Q16" / "P13" | **Q1-Q22** (three sections; the critique stopped at the first) and **P13-a…P13-l** (12 sub-cases). W1-W16 and U1-U126 are correct. |

### Seams

Per the `to-spec` seam discipline — prefer existing seams, take the highest one,
add as few as possible. This spec **widens two existing seams and adds one**.

1. **`hooks/scripts/lib/` — existing, and already proven.**
   `lib/agent-identity.sh` is **byte-identical across all three ports** (one
   distinct MD5 across `hooks/scripts/lib/`, `adapters/codex/.../lib/` and
   `adapters/cursor/.../lib/`). The mechanism this spec needs is therefore not
   hypothetical — it is already load-bearing for one file. M2 widens it.
2. **`buildHookScriptSpecs()` in `bin/cli.js` — existing.** It already
   enumerates `hooks/scripts/` at runtime (never a hardcoded list) and syncs
   `.claude/hooks/scripts/` by content hash. M2 extends the same enumeration to
   the adapter `lib/` directories; M1 reuses the same "one list, rendered per
   target" idea for the ignore list.
3. **One new seam: a state-access lib in `hooks/scripts/lib/`.** M3's
   consolidation is expressed as a single sourced shell library with
   read/write/sweep entry points, so every hook that touches state goes through
   one file. This is the highest available seam: the alternative is editing
   eight hook scripts independently.

M4 needs **no** seam — it is deletion.

---

## User stories

1. As the operator, I want a hook fix to reach every port without me remembering to copy it, so that a security-relevant change cannot silently apply to Claude only.
2. As the operator, I want the adapter ports to be small enough to read in one sitting, so that I can tell at a glance whether a port is correct.
3. As the operator, I want the parity tests to check the part that can actually drift, so that a green parity run means something stronger than "the copies match today."
4. As the operator, I want one canonical list of operational ignore patterns, so that adding a new state artifact ignores it in this repo *and* in every downstream adapted project in the same edit.
5. As the operator, I want `.review-join.*` ignored in adapted projects, so that downstream users do not see harness stamps as untracked noise.
6. As a downstream user adopting the plugin for Cursor or Codex, I want the port I install to carry the same decision logic as the Claude one, so that my review gate behaves the way the documentation says.
7. As the operator, I want dead artifacts deleted rather than left inert, so that reading the repo does not require knowing which files nothing reads any more.
8. As the operator, I want an artifact that has a reader but no writer to be resolved one way or the other, so that the dashboard does not present a surface that can never populate.
9. As the operator, I want the marker directory to have a retention policy, so that 342 accumulated files do not become the permanent cost of having reviewed 264 units.
10. As the operator, I want session baselines and stale WIP handoffs swept, so that abandoned agents do not leak files indefinitely.
11. As the operator, I want the four audit logs bounded, so that `review-audit.log` does not grow without limit while remaining a control input.
12. As the operator, I want the number of distinct state-file conventions reduced, so that reasoning about "what state is the harness in" means reading a small number of places.
13. As the operator, I want every distinction the current dotfiles encode listed and explicitly preserved, so that consolidation cannot silently drop one.
14. As the operator, I want per-unit keying preserved through consolidation, so that ADR-0016's concurrency deadlock is not reintroduced.
15. As the operator, I want existence-signals and mtime-signals re-encoded explicitly when they move into a structured file, so that a check that currently means "this file exists" keeps meaning the same thing.
16. As the operator, I want the ordering constraints between artifacts documented as executable tests, so that a consolidation cannot reorder two writes whose order is load-bearing.
17. As the operator, I want the textual-gate test corpus retired *only* once writes are denied mechanically, so that I never trade a real guardrail for a smaller repo.
18. As the operator, I want the gate deletion expressed as a manifest I can execute in one unit, so that the reduction is not spread across months of incidental edits.
19. As the operator, I want ADR-0002's ownership invariant to survive gate deletion, so that "the reviewer owns the marker directory" remains a stated rule even when its enforcement changes shape.
20. As the operator, I want the plans that are entirely about a retired mechanism archived rather than silently deleted, so that the reasoning stays recoverable.
21. As the operator, I want the glossary to shrink when the vocabulary it defines stops existing, so that CONTEXT.md describes the current system.
22. As a future contributor, I want the count of hand-maintained copies of anything to be zero or one, so that "where do I change this?" has one answer.
23. As the operator, I want capability-bearing config (`humanReviewMode`, `dispatchHygiene`) untouched by this work, so that turning a mechanism back on still works.
24. As a reviewer of this work, I want every acceptance criterion to be a command with an exit code, so that "ceremony was reduced" is measured, not asserted.
25. As the operator, I want each milestone to be independently landable, so that M4 being blocked does not hold up M1.

---

## Implementation decisions

### M1 — Reclaim dead and unswept artifacts; single-source the ignore list

**M1.1 Retire the dead and orphan artifacts.**
- `.claude/.last-review-clear` is the global clear-watermark that ADR-0016
  replaced with per-unit stamps. It has **zero readers and zero writers**, is
  **0 bytes**, is **tracked in git**, and is **not gitignored**. ADR-0016
  declined to delete existing ones ("they become inert once nothing reads
  them"); that deferral is now discharged. Delete the tracked file; add no
  ignore pattern (nothing will recreate it).
- `.claude/milestone-audit/<slug>/FINDINGS.md` has a **reader**
  (`bin/microworld-dashboard/decisions.js`) and a test fixture, but **no
  writer** — the `milestone-auditor` persona instruction that
  `docs/plans/2026-08-13-dashboard-decision-approval-surface.md` specified was
  never written. **DECIDED** (this spec's OQ1, resolved 2026-08-25 by applying
  its recommended default; the operator did not object): resolve in the
  volume-reducing direction — **remove the reader and its fixture**, and record
  the removal so the capability can be restored deliberately. Writing the
  missing writer was the alternative; it *adds* ceremony, so it is out of scope.
  This decision is compatible with either outcome of spec 6's OQ5 (whether the
  dashboard's decision panes are retired under D): if they are retired, this
  removal is subsumed; if they are kept, the removal is still correct, because
  a pane fed by a writer that does not exist can never populate.

**M1.2 Single-source the operational ignore list.** Introduce one canonical
array of operational ignore patterns expressed **relative to a dot-dir token**,
and render it per target (`.claude`, `.cursor`, `.codex`). The three literal
arrays in `bin/cli.js` (cursor scaffold, codex scaffold, claude install) and the
`--update` backfill list all read from it. This closes the four measured gaps in
one edit:
- `.review-join.*` — present in this repo's `.gitignore`, absent from all three
  rendered lists.
- `.dispatch-override.consumed` and its `.tmp.$$.$RANDOM` siblings — the
  existing `.dispatch-override` pattern does not glob the suffix.
- `milestone-audit/` — **moot**, since OQ1 resolved toward removing the reader
  (M1.1). Do not add the pattern.

**M1.3 Add retention.** Extend the one existing sweeper
(`bin/human-review-cleanup.sh`) into a general, **dry-run-by-default** sweeper
covering the four leaking classes: marker files, session baselines, WIP
handoffs, and the four logs. Design decisions:
- Dry-run default with an explicit `--apply`, matching the existing sweeper's
  contract and this repo's "never silently clobber" posture.
- Markers are **never** deleted while a same-unit `.review-join.*` stamp
  stands, and never below a configurable retention window. Marker deletion is
  a write to the protected directory, so the sweeper runs as the operator, not
  as a persona.
- Logs are **rotated, not truncated**, because `review-audit.log`'s last line is
  a control input (`stop-gate.sh` reads `tail -n 1` to suppress a duplicate
  sticky `defer:`). Rotation must preserve the tail.

**M1.3 has two audiences after spec 6, and both still need it.** For **this
repo**, D freezes the backlog rather than clearing it: the 342 markers, 120
session baselines, 12 stale handoffs and 4,114-line log are all still on disk
and stop growing, so the sweeper's local job becomes a **one-time reclaim**
rather than a recurring one. For the **shipped product**, which continues to run
the battery in adopting projects, the sweeper remains an ongoing need and is the
only retention mechanism the product would have. Build it once, ship it, and run
it locally once. The tail-preserving rotation rule stays load-bearing for
adopters even after `stop-gate.sh` stops running here.

### M2 — Single-source the hook ports *(survives, re-scoped to the shipped product)*

**Scoping after spec 6.** M2's deliverable is unchanged, but its *justification*
now rests on the product rather than on this repo's own posture: the hook
battery and both adapter ports **continue to ship** under OQ1(a), so the
duplication M2 removes is still paid on every future change. Two consequences
follow, and both are constraints on how M2 is dispatched:

- **Every script in M2's phasing table is retained by spec 6, so the table
  stands as measured.** D11 is a *disablement* manifest: `graph-update.sh`,
  `lint-on-edit.sh`, `microworld-rerun.sh` and `session-start.sh` are
  "Retained and still enforcing"; the ten gate scripts, `lib/benign-command.sh`,
  both gate suites and **the adapter ports** are "Retained, no longer enforcing
  here, still shipped — **untouched**." No file M2 touches is scheduled for
  deletion, so no unit here is at risk of being wasted work. *(An intermediate
  draft of spec 6 did list several of these under "Deleted"; that table was
  rewritten by the OQ1 ruling.)*
- **The dogfooding drift detector is gone**, so A11's drift-detection criterion
  and A13's mutation proof are no longer belt-and-braces — they are the whole
  belt. Neither may be relaxed.

**M2.1 Extract the port-invariant core.** Measured per-script divergence, in
**code lines only** (comments and blanks stripped), against canonical:

| Script | Canonical code lines | Codex Δ | Cursor Δ |
|---|---|---|---|
| `graph-update.sh` | 27 | 54 | **6** |
| `lint-on-edit.sh` | 12 | 26 | **6** |
| `microworld-rerun.sh` | 57 | 92 | **8** |
| `protected-paths.sh` | 23 | 47 | **11** |
| `reviewer-route-gate.sh` | 92 | 89 | 87 |
| `stop-gate.sh` | 275 | 101 | 184 |

This dictates the phasing. The first four are, for cursor, already thin payload
shims (6–11 differing code lines); codex diverges more only because
`apply_patch` can touch multiple files in one call. The last two are effectively
independent implementations and need real design work.

Structure: each script becomes `lib/<name>-core.sh` (the ordered decision logic,
port-invariant) plus a per-port entry script that sets a small, **explicitly
enumerated** contract — project dir, dot-dir, config path, event-name casing,
the agent-identity field name, and the loop guard — then sources the core. The
enumeration is the deliverable: an undocumented sixth variable is how a port
drifts.

**M2.2 Generate the shared core into the adapter trees.** Extend the existing
runtime enumeration so the shared portion of `hooks/scripts/lib/` is copied into
`adapters/*/hooks/scripts/lib/` by the same content-hash machinery that already
keeps `.claude/hooks/scripts/` clean. This is safe by inspection: the one file
already shared is byte-identical in all three trees today. Generated files must
be identifiable as generated, and a post-generation `diff -r` must be empty.

**`hooks/scripts/lib/` is not uniformly shared, and the generator must say so.**
It currently holds two files with opposite port status: `agent-identity.sh` is
**shared** (byte-identical in all three trees), while `benign-command.sh` is
**Claude-only** — it is sourced exclusively by the two unported gates and exists
in neither adapter tree. A generator that copies the directory wholesale would
push a Claude-only lexer into ports that have nothing to call it, and a parity
check that only compares hashes would **pass vacuously** on a file that is
simply absent. The shared set therefore has to be **declared**, not inferred
from directory membership — either by a subdirectory split (`lib/shared/` vs
`lib/claude/`) or by an explicit manifest the generator reads. Whichever is
chosen, A10 asserts **presence in all three trees and byte-identity**, so an
undeclared or missing file fails rather than passing silently. This is the same
class of vacuity ADR-0025's consequence #3 warns about, reaching the generator
instead of a gate.

**M2.3 Retarget the parity tests.**
- `adapter-stop-gate-parity.test.sh` (624) **shrinks**: the scenarios that
  exercise the shared core become redundant once the core is one file, but the
  scenarios that drive **each port's own payload shape** are exactly what the
  shim contract needs. Convert it from "do three implementations agree?" to "does
  each shim populate the core's contract from its own payload?"
- `adapter-protocol-parity.test.js` (176) **stays unchanged**. Its subject is
  the two prose ports, which are abridged rewrites and cannot be generated. Its
  `ESCALATION_PROBES` array asserts literal strings precisely because a
  header-only probe would pass on a port that had silently dropped a concept.

**M2.4 Ports stay hand-written where they must.** `reviewed-path-gate.sh`,
`human-decision-gate.sh`, `dispatch-hygiene.sh`, `heavy-trigger.sh`,
`marker-commit-check.sh`, `reviewer-tier.sh`, `session-start.sh` and
`task-gate.sh` have **no adapter port** and this spec adds none — adding ports
would *increase* ceremony. The absence is deliberate and already documented in
`human-decision-gate.sh`'s own header.

### M3 — Consolidate state artifacts by key domain *(survives; now product work)*

> **Scoping after spec 6.** This is **product** work: the shipped hook battery
> continues to create all 13 species in every adopting project. This repo will
> stop *populating* them, which removes the dogfooding feedback loop — so A19's
> mutation proofs and A20's concurrency test carry the whole verification
> burden and may not be relaxed. Sequence after M1 and M2.

The critique proposed "one JSON state file per unit." That is right in spirit
and wrong in shape: **only some artifacts are keyed by unit.** Consolidating
across key domains would be the very error ADR-0016 corrected — it replaced a
single global watermark with per-unit stamps *specifically to fix a concurrency
deadlock*. The consolidation therefore proceeds **by key domain**, from 13
species to **5 domains**, and per-unit keying is preserved as an invariant.

| Domain | Key | Absorbs today's | Must keep |
|---|---|---|---|
| **Unit** | unit id | `.review-join.<unit>`, the five marker verbs, the `human-review/<id>/` packet + `DECISION` | per-unit file granularity (ADR-0016); the DECISION zero-identity write ban; the DECISION↔`.escalated` timestamp binding |
| **Agent** | agent id | `.pending-review.<agent>`, `wip-handoff.<agent>` | opposite polarities — pending-review persists, handoff is consumed-on-read; existence vs. content as two independent signals |
| **Session** | session id | `.session-baseline.<session>` | create-only-if-absent; content is a git ref |
| **One-shot** | none (global) | `.dispatch-override`, `.dispatch-override.consumed` + tmp | the `.consumed`-before-`rm` ordering; content-embedded epoch (deliberately not mtime); dispatch-identity hash |
| **Log** | none (append-only) | the four logs | append-only semantics; `review-audit.log`'s tail as a readable control input |

**Distinctions that must survive, enumerated so none is silently dropped.** Each
is a property no other artifact encodes:

- `.pending-review.<agent>` — a gated writer finished and no reviewer has run.
  Keyed by **agent**, the only artifact naming the writer. Its **existence**
  blocks the next gated dispatch (content-blind by design); its **content**
  (`defer:` / `skip:`) gates only main-session turn-end. `defer:` is sticky;
  `skip:` is one-shot. Created **only if absent**, so a later check-in cannot
  clobber a reason the main session wrote.
- `.review-join.<unit>` — which unit(s) this reviewer owes a verdict for,
  established at dispatch because the SubagentStop payload carries no unit id.
  Its `prior_mtime` field is the **staleness anchor** that makes "a marker
  exists" mean "a *new* marker was written this turn."
- `.session-baseline.<session>` — did HEAD move during this session. The only
  artifact holding a **git object reference**, and the only one answering
  "commits happened even though the tree is clean now."
- `wip-handoff.<agent>` — a legitimate mid-task pause. The only artifact that
  suppresses the **test/lint** check. Empty ≠ absent: an empty file is deleted
  and *not* honoured (the anti-`touch` rule).
- `.dispatch-override` — a human waiver of the H1–H4 prompt-hygiene checks, one
  dispatch. Keyed to nothing; a global one-shot token. Reason-less ⇒ deleted and
  not honoured.
- `.dispatch-override.consumed` — a 10-second replay window for a double-fired
  identical dispatch. Carries a **content-embedded epoch** (deliberately
  mtime-independent) and a **dispatch-identity hash** binding the waiver to one
  (target, prompt) pair. Asymmetric expiry: positive drift past 10s deletes;
  negative drift (clock skew) never counts as expiry. A key-mismatched-but-fresh
  stamp is deliberately **not** deleted.
- `.pass` — the unit is done. The only marker carrying a **commit attestation**.
- `.fail` — a real defect, and the only marker consuming a **2-FAIL-cap slot**.
  No hook gates on it. Overwritten in place, so the cap count is **not**
  filesystem-derivable — a property consolidation must not accidentally "fix"
  without a decision.
- `.blocked` — the reviewer could not reach the constraint. Keeps pending-review
  flags standing; never consumes a cap slot; read by **existence glob only**.
- `.escalated` — policy wants human eyes on a unit that would have passed. Its
  **first-line timestamp is the staleness key** the DECISION must echo. A
  separate audit token from `.blocked`, and both globs are checked independently
  so neither masks the other.
- `.directed` — a human prescribed the fix. **Deliberately absent** from
  stop-gate's globs: including it would deadlock the very dispatch it authorises.
  Currently read by nothing mechanical.
- `human-review/<id>/` packet — human-facing comprehension material, held
  outside the marker directory precisely so the gate's allowlist does not make
  its `run.sh` unrunnable.
- `DECISION` — the **only** artifact no agent identity may ever write.
- The four logs — `review-audit.log` is the only artifact whose own audit line
  is a **control input**.
- `.codex/.stop-loop-guard.<session>` — a **consecutive-block counter**, a
  monotone integer nothing else carries. Exists only because Codex lacks
  Claude Code's native 8-block turn-end.

**Ten ordering and atomicity constraints** become executable tests before any
artifact moves (see Testing decisions).

**Sequencing.** M3 lands **after** M1 (which removes artifacts M3 would
otherwise have to model) and **after** M2 (which reduces the number of scripts
that must be edited to change state access from eight to one plus shims).

### M4 — Retire the textual-gate corpus *(still blocked)*

> **Unchanged by spec 6.** D does **not** dissolve this precondition — D11
> reverses an intermediate draft that claimed it did. What changed is urgency,
> not scope: M4 leaves this repo's critical path and becomes product hardening,
> schedulable whenever. **Do not fold M4 into D.** The precondition, the
> manifest and the standing "do not partially delete on a partial fix" warning
> all stand exactly as written below.

**Precondition, and this spec asserts nothing without it:** sibling spec 1's
mechanical fix must land — writes to `.claude/reviewed/` and
`.claude/human-review/*/DECISION` denied at the tool layer rather than screened
lexically — **and be demonstrated to deny the shapes the corpus currently
covers**. Until then, M4 is not dispatchable. Two honest caveats the operator
must weigh before treating M4 as reachable:

- ADR-0025 was accepted **2026-08-24, one day before this spec**, and its
  consequence #3 mandates the mutation-proving corpus. Deleting that corpus
  **supersedes a just-accepted ADR** and must be recorded as such.
- Tool-layer path denial covers `Write`/`Edit` cleanly. The Bash branch — which
  is where essentially all 1,892 corpus lines live — cannot be denied by target
  path, because a shell command's write target is not knowable before execution.
  A mechanical fix for the Bash half therefore has to be something other than a
  permission glob (a write-only-through-a-helper contract with the directory
  made non-writable is the shape most likely to work). **If sibling 1's fix
  covers only the Write/Edit half, M4's deletable set is close to empty** — the
  ADR-0020 asymmetry means that half is already a simple path check.

**Deletion manifest, if and only if the precondition holds:**

| Deletable | Lines |
|---|---|
| `tests/reviewed-path-gate.test.sh` | 986 |
| `tests/human-decision-gate.test.sh` | 906 |
| `hooks/scripts/lib/benign-command.sh` (sourced by these two gates and nothing else) | 233 |
| `hooks/scripts/reviewed-path-gate.sh` + `human-decision-gate.sh` | 628 |
| CONTEXT.md gate-lexer glossary (13 entries) | 154 |
| README.md "Known limitations" gate treatment | ~80 |
| **Surgical edits** across 6 shared suites (not deletions) | ~70 |

**Not deletable, and the distinction matters:**
- **ADR-0002** (`reviewed-dir-owned-by-reviewer`, 67 lines) states the
  **invariant**, not the enforcement. It survives; only the enforcement changes
  shape.
- **ADR-0025** (111) and **ADR-0020** (82) become moot but are **annotated
  `Superseded by`, never rewritten**, per this repo's convention (ADR-0005:82).
- **ADR-0008** (114) covers the GATE/GRANT normalization contract shared with
  stop-gate and reviewer-route-gate. Survives.
- The **5,431 lines** across six shared suites
  (`agent-auditor`, `agent-identity-namespace`, `cli-backfill`,
  `cli-hook-propagation`, `human-review-cleanup`, `validate.sh`) that reference
  the gates only as fixture text, as an arbitrary real hook file, or as a runner
  block. These need ~70 lines of surgical edits, **not** deletion.
- The **7,718 lines** of plans across 10 files that are entirely about this
  layer are **archived, not deleted** — they are the recoverable reasoning.

---

## Testing decisions

**What makes a good test here.** These are external-behaviour tests over
observable artifacts: a hook's **exit code** and the **audit records** it wrote,
a generator's **post-run `diff`**, a sweeper's **dry-run manifest**. No test
should assert on a shell function's internals — the ports differ internally by
design, and asserting internals is what makes a parity test brittle.

**Prior art in this repo, to be followed rather than reinvented:**
- `tests/adapter-stop-gate-parity.test.sh` — drives all three ports through the
  same scenarios via **each port's own payload shape** and asserts the same
  observable outcome. This is exactly the shape M2.3's retargeted test needs.
- `tests/microworld-audit-contract.test.js` — pins a **bash-writer ↔
  Node-parser** contract across a format boundary. This is the model for M3's
  state-format tests, since `decisions.js` and `server.js` parse the same
  artifacts the hooks write.
- `tests/cli-backfill.test.js` — copies the **real repo root** into a fixture
  and asserts `--update --dry-run` exits 0 on the copy, which makes it
  transitively a live-tree parity check. M1.2 and M2.2 must keep it green.
- `tests/human-review-cleanup.test.sh` — the dry-run-default sweeper contract
  M1.3 extends.
- Both gate suites — hermetic, `mktemp -d`, nothing written inside the repo.
  Every new test follows this.

**Modules under test:** `bin/cli.js` (ignore-list rendering, lib generation),
`hooks/scripts/lib/*` (extracted cores), the three port entry scripts, the
extended sweeper, and the state-access lib.

**Specific obligations:**
1. **Ordering constraints become tests before M3 moves anything.** All ten
   listed constraints — most importantly `.consumed`-before-`rm`,
   `.blocked`/`.escalated` glob → review-join eval → `rm -f .pending-review.*`,
   create-only-if-absent on both `.pending-review` and `.session-baseline`, and
   `.directed`'s **exclusion** from stop-gate's globs — get a failing-first test
   against the *current* implementation. A consolidation that reorders a
   load-bearing write must turn one red.
2. **Existence-signals and mtime-signals get explicit round-trip tests**, since
   they are the distinctions most likely to be lost in a structured file:
   content-blind existence checks, marker-mtime vs. stamp `prior_mtime`,
   `<unit>.pass` mtime vs. stamp mtime (the only file-to-file mtime comparison),
   `.consumed`'s content-embedded epoch, and `wip-handoff`'s empty-≠-absent rule.
3. **Mutation-prove the retargeted parity test.** Per ADR-0025's consequence #3
   and this repo's standing practice: revert the shim contract and re-run; a
   parity test that still passes is vacuous and must be rewritten. Landing M2.3
   without this proof reproduces the exact failure the current parity test's own
   header records ("nothing checked that claim, so the defer: dedupe drifted").
4. **`bash tests/validate.sh` exits 0 at each unit's own commit**, verified in a
   clean detached worktree, never the live tree. Any unit touching `agents/*.md`
   or `templates/*.md` regenerates its `.claude/` mirrors **in the same unit**
   via `node bin/cli.js --update --force-render` — plain `--update` returns early
   on a version match and will not repair it.
5. **No unit is sliced across a parity test.** A change and the parity probes
   that assert it land together, or the test asserts strings the code no longer
   contains (fails) or nothing about what replaced them (vacuous).

---

## Acceptance criteria

All commands run from the repo root. Baselines measured at `09cc304`,
2026-08-25.

> **Correction note (2026-08-26) — A8 and A16 only.** Two **M2** criteria below
> carried arithmetic defects that predate any implementation work. Both were
> found and measured by the reviewer during M2's own reviews and are recorded
> verbatim in `.claude/reviewed/gh411.pass` (notes **N1** and **N2**) and
> `.claude/reviewed/gh410.pass` (finding **2**). **This corrects the criteria,
> not the code.** M2 tier 1 and tier 2 are implemented correctly and
> reviewer-PASSed; both corrected criteria are **already satisfied** at
> `96ce365`, so **no re-dispatch is needed** and this amendment generates no new
> unit. Nothing outside A8 and A16 changes — no other criterion, milestone or
> wave is reopened.
>
> - **A8 was arithmetically unreachable, not merely mis-baselined.** It counted
>   adapter `hooks/scripts/` **recursively**, which sweeps in each port's
>   generated `lib/` **core files** — but **A10** requires every declared-shared
>   file to be byte-identical in all three `lib/` trees, i.e. physically copied
>   into both adapters. Single-sourcing therefore *raises* the recursive count
>   by design: 1,995 at `09cc304` → 2,252 at gh410's tip → 2,447 at gh411's →
>   **3,175** at `96ce365` (the last step from unrelated later `lib/` growth,
>   such as the `memo-key-1` re-render of `microworld-queue.sh`). No
>   implementation satisfying A10 could ever have reached the old **≤1,097**
>   target. A8's own rationale text confirms the modelling error: it derived the
>   floor from "the shared portion of `stop-gate.sh`" treated as **removed**
>   from the adapter trees, when A10 mandates it be **duplicated** into them.
>   A8 now measures the hand-maintained thin-entry-script set, which is what the
>   45% floor was always about.
> - **A16's baseline was a `git ls-tree` miscount.** `git ls-tree <commit>
>   adapters/<port>/hooks/scripts/` lists seven entries per port, but one of
>   them is the `lib` **tree** entry, not a script; blobs alone number **6**, at
>   `09cc304` and `96ce365` alike. The old wording ("**7** scripts plus `lib/`")
>   double-counted `lib`. Confirmed independently by both PASS markers; no M2
>   unit added or removed an adapter script.

### M1

- **A1.** `git ls-files | grep -c 'last-review-clear'` returns **0** (baseline: 1).
- **A2.** `grep -rc 'milestone-audit' bin/microworld-dashboard/decisions.js` returns **0**, and `node --test tests/dashboard-decisions.test.js` exits 0 (baseline: reader present, fixture at `tests/dashboard-decisions.test.js:218-221`).
- **A3.** The count of literal operational-ignore arrays in `bin/cli.js` is **1**. Machine-check: `grep -c "wip-handoff\.\*'" bin/cli.js` returns **1** (baseline: **3**, at the cursor, codex and claude-install scaffolds).
- **A4.** Every pattern in this repo's own `.gitignore` operational block is produced by the single renderer for each of the three dot-dirs. Machine-check: `node bin/cli.js --target=cursor --dry-run` and `--target=codex --dry-run` each emit an ignore list containing a `review-join` entry — `grep -c 'review-join'` on each output returns **≥1** (baseline: **0** for both).
- **A5.** `git check-ignore -q .claude/.dispatch-override.consumed` exits **0** (baseline: exits 1 — not ignored).
- **A6.** The sweeper reports a non-empty dry-run manifest over all four leaking classes and writes nothing: after `bash bin/<sweeper> ` (no `--apply`), `git status --porcelain` is empty **and** the on-disk counts are unchanged. Baselines to reduce under `--apply` with a retention window: marker files **342**, session baselines **120**, stale WIP handoffs **12**, `review-audit.log` **4,114** lines.
- **A7.** Log rotation preserves the tail: after rotation, `stop-gate.sh`'s sticky-`defer:` dedupe still suppresses a duplicate — a test asserting exactly one `defer:` audit line across a rotation boundary exits 0.

### M2

- **A8.** *(Corrected 2026-08-26 — see the correction note above.)* Hand-maintained adapter **thin entry script** volume drops by **≥45%**: `find adapters/codex/hooks/scripts adapters/cursor/hooks/scripts -maxdepth 1 -type f -exec cat {} + | wc -l` returns **≤893** (baseline: **1,625** at `09cc304`). The `-maxdepth 1` scope is load-bearing: it counts the two ports' hand-maintained thin entry scripts and excludes their generated `lib/` core files, which A10 requires to be byte-identical copies and which therefore *add* volume by design. `lib/` is the only subdirectory under either port's `hooks/scripts/`, at baseline and now, so `-maxdepth 1` and `! -path '*/lib/*'` are equivalent here — both return 581. The **≥45%** floor is carried over unchanged from the original criterion; what was defective was the measurement set and its baseline, not the target reduction. **Already satisfied at `96ce365`: 581 lines, −64.2%.**
- **A9.** Generation is proven equivalent, not asserted: after `node bin/cli.js --update --force-render`, `diff -r hooks/scripts/lib adapters/codex/hooks/scripts/lib` and `diff -r hooks/scripts/lib adapters/cursor/hooks/scripts/lib` both exit **0** with empty output.
- **A10.** Every file in the declared **shared** set exists in all three `lib/` trees **and** is byte-identical. Both halves are required: a hash-only check silently passes on a file that is simply absent from the adapters. Machine-check — for each file in the shared set, `test -f` in both adapter trees succeeds **and** `md5sum` across the three copies yields **1** distinct hash. Baseline: `agent-identity.sh` present-in-all-3 with 1 distinct hash; `benign-command.sh` **absent from both adapters** and therefore must **not** be in the shared set.
- **A11.** Regeneration is idempotent and drift is detectable: running `--update --force-render` twice leaves `git status --porcelain` empty on the second run; and after hand-mutating one byte in an adapter `lib/` file, `node bin/cli.js --update --check` exits **non-zero**.
- **A12.** `tests/adapter-stop-gate-parity.test.sh` is **retargeted, not deleted**: the file still exists, `bash tests/adapter-stop-gate-parity.test.sh` exits 0, and its line count is **≤400** (baseline: **624**).
- **A13.** The retargeted parity test is **non-vacuous**: reverting any one port's shim contract assignment causes it to exit non-zero. Verified by mutation, recorded in the unit's marker.
- **A14.** `tests/adapter-protocol-parity.test.js` is **byte-unchanged**: `git diff --quiet HEAD~ -- tests/adapter-protocol-parity.test.js` exits 0 for every unit in M2.
- **A15.** No new adapter ports appear: `find adapters -name 'reviewed-path-gate.sh' -o -name 'human-decision-gate.sh' -o -name 'dispatch-hygiene.sh' | wc -l` returns **0**.
- **A16.** *(Corrected 2026-08-26 — see the correction note above.)* Per-port hook counts are unchanged: each adapter tree still carries **6** thin entry scripts plus a `lib/` directory (baseline: **6** each — only 6 of the 14 `hooks/scripts/*.sh` files have any adapter port at all). Machine-check: `find adapters/codex/hooks/scripts adapters/cursor/hooks/scripts -maxdepth 1 -type f | wc -l` returns **12**, and `test -d adapters/codex/hooks/scripts/lib && test -d adapters/cursor/hooks/scripts/lib` exits **0**. **Already satisfied at `96ce365`.**

### M3

- **A17.** Distinct state-artifact **species** drop from **13 live to 5 key domains**, machine-checked by an enumeration test that asserts the exact set of filename patterns the harness may create, and fails if any hook writes a pattern outside it.
- **A18.** **Every distinction listed in M3 is covered by a named test.** A manifest test asserts one test id per bullet in the "distinctions that must survive" list; a missing id fails the suite. This is the criterion that makes "not silently dropped" machine-checkable.
- **A19.** All ten ordering/atomicity constraints have a test that is **red against a deliberately reordered implementation** — each proved by mutation, recorded per constraint.
- **A20.** Per-unit keying is preserved: a test dispatches two units concurrently and asserts neither blocks the other, exercising the deadlock ADR-0016 fixed.
- **A21.** `bash tests/validate.sh` exits 0, and `node bin/cli.js --update --check` exits 0, at each unit's own commit in a clean detached worktree.
- **A22.** No capability regression: `humanReviewMode` and `dispatchHygiene` remain readable and effective. Setting `humanReviewMode: "all"` in a fixture still produces an escalation path — asserted by test, since this repo's live value is `"off"` and would otherwise never exercise it. **This criterion becomes more load-bearing under spec 6, not less:** once this repo also stops enforcing locally, a fixture test is the *only* thing standing between a shipped capability and silent rot, because no local usage will reveal a regression.

### M4 *(only dispatchable once the precondition is demonstrated)*

- **A23.** **Precondition gate.** A test demonstrates that a write to `.claude/reviewed/<id>.pass` from a non-reviewer identity is denied **without** either gate script registered — covering the Bash path, not only Write/Edit. Until this exits 0, no other M4 criterion may be evaluated.
- **A24.** Textual-gate mechanism drops to 0 lines: `wc -l hooks/scripts/reviewed-path-gate.sh hooks/scripts/human-decision-gate.sh hooks/scripts/lib/benign-command.sh` — all three absent (baseline: 286 + 342 + 233 = **861**).
- **A25.** Dedicated corpus removed: `tests/reviewed-path-gate.test.sh` and `tests/human-decision-gate.test.sh` absent (baseline: **1,892** lines, **775** runtime assertions).
- **A26.** Shared suites **survive**: all six still exist and `bash tests/validate.sh` exits 0; the total diff across them is **≤120 lines** (estimate: ~70).
- **A27.** CONTEXT.md gate-lexer glossary removed. Machine-check, naming all thirteen entries so the criterion cannot pass by matching a subset:
  ```
  grep -cE '^\*\*(narrate-versus-target distinction|trigger token|marker id charclass|path-safe charclass|path-shaped run|run scan|quote-joined text|sanctioned marker-write template|single-quoted span|skeleton|prose mention|inert triggers|prose-only commit)' CONTEXT.md
  ```
  returns **0** (baseline: **13**, at CONTEXT.md:1527-1680).
- **A28.** ADR-0002 survives byte-unchanged; ADR-0025 and ADR-0020 carry a `Superseded by` annotation and are **not** rewritten or deleted: `git diff --stat` shows additions only on those two files, and `docs/adr/0002-*.md` unchanged.
- **A29.** The 10 layer-specific plans are **archived, not deleted**: `ls docs/plans/ | wc -l` does not decrease by more than the number moved, and each moved file is retrievable at its new path (baseline: **7,718** lines across 10 files).

### Cross-cutting

- **A30.** No unit changes `humanReviewMode`, `dispatchHygiene.mode`, or `markerCommitCheck.mode` values in `.claude/persona-config.json`: `git diff HEAD~ -- .claude/persona-config.json` shows changes confined to `fileHashes` and `pluginVersion` for every unit in this spec.
  **Scoped to this spec's own units** (agreed with spec 6). Spec 6's Phase 2 flip adds a **different** key — `reviewGating.mode: "off"` — so there is no literal conflict, and that flip is a declared posture change guarded by spec 6's own criterion. A30 constrains *volume* work from silently changing capability posture; it does not constrain spec 6's deliberate, visible posture change.
- **A31.** Net artifact reduction is reported, not assumed: each milestone's marker records the before/after of its own criteria, so the spec's total claim is auditable from the markers alone.

---

## Out of scope

- **Trust properties** (sibling 1). Whether a gate *can* be bypassed, and moving
  enforcement out of agent reach, is that spec's subject. M4 consumes its
  outcome as a precondition and specifies nothing about how it is achieved.
- **Token and latency cost** (sibling 2). No criterion here measures tokens or
  wall-clock.
- **The microworld bundle lifecycle's conceptual shape** (sibling 4).
  `microworlds/` (9 bundles, 36 files) and `microworld-rerun.sh` are touched
  here only as an M2 port-extraction subject and an M3 ignore-pattern entry.
- **General streamlining** (sibling 5).
- **`docs/plans/` total volume.** At **51,405 lines across 57 files** this is the
  single largest artifact class in the repo and is plainly ceremony-adjacent,
  but a retention policy for finalized plans is a different decision from
  consolidating duplicated *mechanism*. Flagged for sibling 5; only the 10
  gate-specific plans are touched, and only under M4.
- **Removing human-review or dispatch-hygiene capability.** Explicitly
  prohibited. A1–A31 change volume and duplication only.
- **Adding adapter ports** for the nine unported hooks.
- **Writing the missing `milestone-auditor` FINDINGS writer** — that adds
  ceremony (OQ1, closed toward removing the reader).
- **`.claude/agent-memory/`** (115 files, 5,584 lines).
- **The CI-shaped review architecture itself** (spec 6). This spec asserts
  nothing about branch protection, the verdict contract, the `reviewGating`
  mode switch, or `reviewer-tier.sh`'s fate — the last belongs to sibling 2.
  Spec 6's Phase 2 flip is **not** one of this spec's seven units, and no
  criterion here depends on D landing.

---

## Further notes

**Tracker publication is owed, not done.** This spec resolves to seven units,
above ADR-0024 Step 3's ≥6 publish threshold, so `to-spec` would normally file
it. It is deliberately deferred: sibling spec-master sessions are drafting from
the same critique in parallel, and filing now risks duplicate or conflicting
issues before the set has been reconciled. Spec 6's adoption **does not change
the unit count** — all four milestones survive — so the threshold verdict is
unchanged. File after reconciliation, with the `ready-for-agent` label.

**Sequencing is load-bearing, and spec 6 reinforces it.** M1 → M2 → M3, with M4
parked on its precondition. M3 after M2 is not cosmetic: it reduces the edit
surface for state access from eight scripts to one lib plus shims. Spec 6's own
instruction is *"Land M1, M2 and M3 on their own schedule — no OQ1 dependency
remains."* Spec 4 (Microworlds) is a **prerequisite** and should land first.

**Do not slice a unit across a parity test.** On model tagging: `bin/cli.js` has
prior FAIL history, so its units must not be **downgraded** below the default
writer tier. Note that the default has changed — sibling spec 2 **ratified the
reversal of ADR-0010, moving `lead-programmer` from `haiku` back to `sonnet`**
(2026-08-25) — so the current default is already `sonnet` and the guidance here
is simply "do not hand-tag these units cheaper," not a warning about a live
haiku default.

**The critique's strongest point is the one it made only implicitly.** Its four
findings are all instances of a single pattern: *when a copy drifts, this repo
writes a test that detects the drift rather than a generator that prevents it.*
The parity tests, the ignore-list arrays, and the accreted state species are the
same failure three times. M1.2 and M2.2 are the direct fix; A3, A9 and A17 are
what make it stick.

---

## Open questions

One remains open. The other is now closed.

**OQ1 — CLOSED (2026-08-25).** *`milestone-audit/FINDINGS.md`: remove the
reader, or write the missing writer?* Resolved by applying this spec's own
recommended default — the operator did not object. **Remove the reader and its
fixture** (M1.1), since writing the missing writer *adds* ceremony and this spec
reduces it. The removal is recorded so the capability can be restored
deliberately, and it is compatible with either outcome of spec 6's OQ5 on the
dashboard's decision panes.

**OQ2 — STILL OPEN, and confirmed still necessary.** *What is M4's deletable set
if the mechanical fix covers only `Write`/`Edit`?* Tool-layer path denial handles
Write/Edit cleanly, but the Bash branch — where essentially all 1,892 corpus
lines live — cannot be denied by target path. Spec 6 considered this question
mooted in an intermediate draft and then **explicitly restored it**: *"Spec 3's
OQ2 … is unaffected and still needs its answer."* *Recommended default:* treat
A23 as a **hard gate**. If the Bash half is not mechanically covered, M4 reduces
to the Write/Edit slice, which ADR-0020 already establishes is a simple
destination-path check, and the corpus stays. **Do not partially delete the
corpus on a partial fix** — a half-covered Bash path with a deleted corpus is
strictly worse than today.

**Not an open question, but a standing caution.** Two successive drafts of spec
6 reached opposite conclusions about whether M4 was superseded. Anyone acting on
a *summary* of spec 6 rather than its current text should re-read D11 first;
this spec's M4 has been re-verified against spec 6 at 1,003 lines and stands
blocked.
