# Item 19: Did the microworld subsystem earn its footprint?

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 19 of 19
Source: Fable adversarial review 2026-09-25, reactive-complexity table (Microworld subsystem)
Disposition: **REJECT the review's evidence — its central number is a counting error.** A real, smaller defect found instead: 3 orphaned bundles.

## Goal

Answer the review's "did it earn its footprint" question on correct numbers,
and close the actual gap the correct numbers reveal.

## Context

The review's evidence: *"10 bundles exist, 1 watch-map entry, 0 escalation
packets. ~160 lines in the stop gate to skip `validate.sh` when bundles
proved files clean. Ask whether it earned its footprint."*

**The "1 watch-map entry" figure is wrong, and it is the load-bearing half of
the argument.** Measured 2026-09-25:

- `tests/watch-map.json` has **7** entries (`jq '.entries|length'` → 7).
- The figure 1 is what you get from `jq 'keys|length'` on the top-level
  object — which counts the single `entries` key, not its contents.

So the picture is not "10 bundles, 1 registration" (a 10% utilization that
would indeed look abandoned) but **10 bundles, 7 registered** — 70%. That is
an actively used subsystem, and the footprint question it was asked to answer
does not arise on these numbers.

**The real finding, which the wrong number obscured.** Three bundles exist
with no watch-map entry:

- `hdg-anchor-1`
- `rev-gh377-5-probe`
- `rpg-canon-2`

An unregistered bundle is inert: nothing watches its files, so nothing runs
it. That is a small, concrete, closable gap — and it is the opposite of the
review's conclusion. The subsystem is not unearned; it is slightly
under-wired.

**On the remaining figures.** "0 escalation packets" is true but is an
artifact of `humanReviewMode` being off (item 20), not of the microworld
subsystem — the dashboard/countersign half is unreachable while the mode is
off, which the review itself notes. And the ~160 stop-gate lines that skip
`validate.sh` when bundles proved files clean are a *performance* mechanism;
judging them requires knowing how often they fire, which nobody has measured.

**A known trap for anyone measuring this.** Per the
`microworld-memo-defeats-mutation-proofs` memory note, the queue memoizes on
test **path** alone, so mutation-proof bundles report **false** passes when
run through the queue. Any measurement here must re-run standalone before
believing the audit log — this has bitten before.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-25 Non-functional attributes: Q Is the subsystem under-used? → A
  (self-resolved): **no** — 7 of 10 bundles are registered. The review's 10%
  figure came from a `jq` counting error; the real figure is 70%.
- 2026-09-25 Edge cases / failure handling: Q What does an unregistered
  bundle do? → A (self-resolved): **nothing** — no watch entry means nothing
  triggers it. Three such bundles exist; that is the actual defect.
- 2026-09-25 External dependencies & integrations: Q Is "0 escalation
  packets" evidence against the microworld subsystem? → A (self-resolved):
  **no** — it is evidence about `humanReviewMode` being off (item 20). The
  two are being conflated.
- 2026-09-25 Technical constraints & tradeoffs: Q Do the ~160 stop-gate lines
  earn their place? → A (self-resolved): **unmeasured.** Step 2 measures the
  skip rate rather than guessing; a performance optimization that never fires
  is dead weight, and one that fires often is not.

## Risks and dependencies

- **R1. Memoization trap** — see Context. Any measurement that runs a bundle
  through the queue may observe a false pass. Re-run standalone.
- **R2. Orphaned bundles may be deliberate.** A probe bundle
  (`rev-gh377-5-probe` is named like one) may have been one-shot and never
  intended for registration. Step 1 must classify before acting; deleting a
  deliberate artifact is as wrong as leaving an accidental orphan.
- **R3. Bundles are gitignored** (ADR-0017), so they are per-clone state with
  no recovery source. Deletion is irreversible — prefer registration or an
  explicit retirement note over `rm`.
- **R4.** No prior `.fail` record known (new work); marker sweep Bash-gated.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — this spec exists because the
  review's headline number was re-measured and found wrong.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  Step 3's registration check is mechanical.
- P3 "Version-stamp discipline": deviation — tests and `tests/watch-map.json`
  are not version-stamped. If `agents/*.md` prose changes, P3 re-applies.
- P4 "Optional personas degrade gracefully": satisfied — untouched.
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Classify the three unregistered bundles

**Affected files:** none modified; findings in the report.

**Acceptance criteria**
- Each of `hdg-anchor-1`, `rev-gh377-5-probe`, `rpg-canon-2` is classified
  **register** (should have a watch-map entry), **retire** (a deliberate
  one-shot, to be recorded as retired), or **delete** (genuinely spurious),
  with a one-line justification each.
- For any classified `register`, the report names the `watch` paths and `run`
  command it would need.
- If a bundle is run as part of classification, it is run **standalone**, not
  through the queue (R1) — state which method was used.
- `git status --porcelain` is empty.

## Step 2 — Measure the stop-gate skip rate

**Affected files:** none modified; findings in the report.

**Acceptance criteria**
- The report states how many times the bundle-proved-clean path caused a
  `validate.sh` skip, over a stated date range, and the count of
  microworld runs in the same range.
- It states a disposition: **earning** (the skip fires regularly) or
  **dead weight** (it rarely fires).
- Audit logs are read with the `Read` tool — a Bash command naming
  `.claude/microworld-audit.log` is blocked by `harness-integrity-gate.sh`
  (Set A; reproduced live 2026-09-25). Do not rephrase to evade.
- `git status --porcelain` is empty.

## Step 3 — Close the registration gap and guard it

**Affected files:** `tests/watch-map.json`;
`tests/watch-map-registration.test.sh`.

Register the bundles Step 1 classified `register`, record retirements, and
add a check so a bundle cannot silently go unregistered again.

**Acceptance criteria**
- Every bundle directory under `microworlds/` either has a watch-map entry or
  is recorded as retired — assert mechanically: the set difference between
  bundle directories and (watch-map ids ∪ retired ids) is **empty**.
- Non-vacuity by mutation: add a dummy bundle directory with no entry,
  confirm the check **fails** naming it, remove it, confirm it passes. Record
  both observations in the report.
- The existing registration test still passes:
  `bash tests/watch-map-registration.test.sh` exits 0.
- `jq '.entries|length' tests/watch-map.json` is ≥ 7 (no existing entry was
  lost).
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **If Step 2 reports the skip path is dead weight, should the ~160
   stop-gate lines be removed?** Recommended default: **do not remove on this
   evidence alone.** The skip is a performance optimization on a gate whose
   correctness matters more than its speed, and removing it touches
   `stop-gate-core.sh` — the same file item 10 recommends leaving alone.
   Prefer recording the measured rate and revisiting if it stays near zero
   across a longer window. Requires a human decision only if removal is
   wanted.
2. **Is the microworld dashboard/countersign half worth keeping while
   `humanReviewMode` is off?** The review notes it is unreachable in that
   state. This is genuinely **item 20's** question wearing a different hat,
   and is listed here only so it is not double-counted as microworld
   footprint. No separate decision needed.

## Self-check

- CHK1: Is the review's headline number verified rather than inherited? —
  PASS (7 entries, not 1; the counting error is identified precisely).
- CHK2: Does the spec still find a real defect after correcting the number? —
  PASS (3 unregistered bundles, named).
- CHK3: Is the memoization trap accounted for? — PASS (R1, and Step 1's
  standalone-run requirement).
- CHK4: Could Step 3 delete a deliberate artifact? — PASS (Step 1 classifies
  first; R3 prefers registration or retirement over deletion).
- CHK5: Is "0 escalation packets" attributed to the right cause? — PASS
  (item 20's mode setting, not the microworld subsystem).
- CHK6: Could Step 3's set-difference criterion pass by emptying the
  watch-map? — PASS (the `≥ 7` entry-count criterion prevents it).

## Scribe update hint

Record the corrected utilization figure (7 of 10 registered) against the
microworld glossary entries, and add **orphaned bundle** as a term with the
registration rule. Note explicitly that `tests/watch-map.json` nests its
entries under an `entries` key — the counting error this item began as is
easy to repeat.

## Dispatch contract (fast path — 3 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item19-microworld-footprint.md`.
Order: Step 1 gates Step 3; Step 2 independent.

### Unit: item19-1-classify-orphans
- **Objective:** Classify the three unregistered bundles.
- **Retrieval:** Step 1.
- **Affected files:** none.
- **Ordered edits:** inspect each bundle → classify register/retire/delete → for `register`, name watch paths and run command.
- **Do NOT touch:** `tests/watch-map.json`; any bundle directory.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** unregistered bundles are `hdg-anchor-1`, `rev-gh377-5-probe`, `rpg-canon-2` (measured 2026-09-25). The queue memoizes on test path alone, so a bundle run through it may report a FALSE pass — run standalone. Bundles are gitignored (ADR-0017); deletion is irreversible.
- **Escalation:** if a bundle's intent is unclear, classify `retire` rather than `delete` — the reversible direction.

### Unit: item19-2-measure-skip-rate
- **Objective:** Measure how often the bundle-proved-clean skip fires.
- **Retrieval:** Step 2.
- **Affected files:** none.
- **Ordered edits:** read microworld audit log via `Read` → count skips and runs over a stated range → state earning/dead-weight.
- **Do NOT touch:** `stop-gate-core.sh`; any log.
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** independent of the other units, may run first. A Bash command naming `.claude/microworld-audit.log` is blocked by Set A — reproduced live 2026-09-25; `Read` succeeds. Never rephrase to evade a gate.
- **Escalation:** if the log lacks the granularity to distinguish a skip from a run, report that as the finding rather than estimating.

### Unit: item19-3-close-registration-gap
- **Objective:** Register or retire every bundle; guard against recurrence.
- **Retrieval:** Step 3.
- **Affected files:** `tests/watch-map.json`, `tests/watch-map-registration.test.sh`.
- **Ordered edits:** apply Step 1's classifications → add a set-difference check → mutate-prove → confirm no existing entry lost.
- **Do NOT touch:** `stop-gate-core.sh`; the microworld queue.
- **Acceptance criteria:** as Step 3.
- **Pre-resolved context:** depends on item19-1. `tests/watch-map.json` currently has 7 entries nested under an `entries` key — count with `jq '.entries|length'`, never `jq 'keys|length'` (that returns 1 and is the error this whole item originated from).
- **Escalation:** if a bundle classified `register` cannot produce a runnable command, report rather than registering an entry that will fail.
