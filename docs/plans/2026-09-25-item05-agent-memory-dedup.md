# Item 05: Agent-memory namespace deduplication and pruning policy

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 5 of 19
Source: Fable adversarial review 2026-09-25, Token/cost overhead #3
Disposition: **ACCEPT — dedupe namespaces; adopt a pruning policy.** Counts re-measured and confirmed.

## Goal

Collapse the duplicated agent-memory namespaces, and adopt a policy that
stops per-unit completion notes from accumulating in a store that nothing
prunes.

## Context

Measured 2026-09-25:

| Namespace | Files | Size |
|---|---|---|
| `lead-programmer/` | 57 | 324K |
| `spec-master/` | 55 | 308K |
| `scribe/` | 51 | 224K |
| `task-master/` | 19 | 84K |
| `antislop-lead-programmer/` | 8 | 44K |
| `antislop-task-master/` | 5 | 24K |
| `antislop-scribe/` | 4 | 20K |
| `antislop-spec-master/` | 4 | 20K |
| **Total** | **203** | **1.1M** |

Four personas each have **two** namespaces — a bare name and an
`antislop-`-prefixed one. This is a plugin-namespacing artifact: an agent
dispatched as `antislop:lead-programmer` resolves its memory directory
differently from one dispatched as `lead-programmer`. Both dispatch forms are
live (the available-agents list shows both), so **both directories are
currently reachable** and memories written under one are invisible to the
other.

That is the substantive defect, and it is worse than the byte count suggests:
it is a **silent correctness problem**, not a cost problem. A persona that
records a hard-won finding under one namespace may not see it on the next
run, which defeats the entire point of durable memory. The 1.1 MB is the
symptom; the split-brain is the disease.

**On pruning.** `agents/lead-programmer.md` states nothing prunes these. The
review observes that entries like "hcb-release completion — PASS 2026-09-24"
are changelog material, not memory — and this project's own memory guidance
agrees: completion records are derivable from the `.pass` marker and
`CHANGELOG.md`, and the guidance explicitly excludes "git history, recent
changes, or who-changed-what". So the accumulation is partly a policy
failure, not just absent tooling.

**What must not be lost.** Many of these files encode expensive, non-obvious
findings ("do not re-derive them"). Deduplication must **merge**, never
overwrite: the smaller `antislop-` directories are not obviously the stale
copies, and one contains content the other does not.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-25 Domain entities / data model: Q Which namespace is canonical? →
  A (self-resolved): **the bare name** (`lead-programmer/`), since it holds
  the large majority of content (57 vs 8, 55 vs 4, 51 vs 4, 19 vs 5) and is
  the form the persona files use. The `antislop-` copies merge into it.
- 2026-09-25 External dependencies & integrations: Q Does the harness choose
  the directory by dispatch name, and can that be controlled? → A
  (self-resolved): **not verified, and it must be before merging** — if the
  harness keeps resolving `antislop:lead-programmer` to the prefixed path,
  merging will silently re-split. Step 1 measures this first; the merge is
  worthless without it.
- 2026-09-25 Edge cases / failure handling: Q What if the same filename exists
  in both namespaces with different content? → A (self-resolved): **merge by
  hand, never overwrite.** Step 2 requires a per-collision disposition in the
  report; an automated overwrite would silently destroy an expensive finding.
- 2026-09-25 Technical constraints & tradeoffs: Q Should pruning be automated?
  → A (self-resolved): **no automated deletion.** A policy plus a size check
  that *warns* is proportionate; automatic deletion of memory whose value is
  "do not re-derive this" is the wrong default for an irreversible operation.

## Risks and dependencies

- **R1. Irreversibility.** These files are the only record of several
  expensive findings and are gitignored per-clone state with no recovery
  source. Any deletion is unrecoverable. This is why Step 2 merges and Step 3
  warns rather than deletes.
- **R2. Silent re-split.** If the harness's namespace resolution is not
  understood first (Step 1), the merge undoes itself on the next
  plugin-prefixed dispatch.
- **R3. Index truncation.** `MEMORY.md` is always loaded and truncates after
  200 lines. Per-namespace indexes must be merged too, or entries become
  unreachable even though the files survive.
- **R4. Version-stamp discipline** applies to Step 3 if it edits
  `agents/*.md` memory guidance.
- **R5.** No prior `.fail` record known (new work); marker sweep Bash-gated.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — counts measured per namespace;
  Step 1 exists precisely because the resolution mechanism is *not* yet
  verified.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  Step 3's size check is mechanical; the merge is deliberately manual because
  it is irreversible.
- P3 "Version-stamp discipline": **applies** to Step 3 if persona guidance
  changes — see R4.
- P4 "Optional personas degrade gracefully": satisfied — a project selecting
  fewer personas has fewer namespaces; checks must not fail on an absent one.
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Determine how the harness resolves the memory namespace

**Affected files:** none modified. Produces findings recorded in the
ready-for-review report.

Establish whether the directory is chosen by the dispatch name
(`lead-programmer` vs `antislop:lead-programmer`), by the persona's `name:`
frontmatter, or by plugin context — and whether the prefixed path can be
avoided.

**Acceptance criteria**
- The report states, with evidence, which input selects the namespace and
  whether both forms remain reachable after a merge.
- It states explicitly whether merging is **safe** (no re-split) or
  **unsafe** (re-split expected). If unsafe, Step 2 does **not** proceed and
  this spec stops at Step 1 with that finding — a correct and acceptable
  outcome.
- `git status --porcelain` is empty (a measurement step changes nothing).

## Step 2 — Merge the duplicated namespaces

**Affected files:** `.claude/agent-memory/*` (gitignored, per-clone state).
*Conditional on Step 1 reporting "safe".*

Merge each `antislop-<persona>/` into `<persona>/`, hand-resolving filename
collisions and merging the `MEMORY.md` indexes.

**Acceptance criteria**
- After the merge, no `antislop-`-prefixed namespace directory remains.
- File conservation: total distinct memory files after ≥ the count of
  distinct files before, minus only those explicitly reported as merged
  duplicates. Every collision is listed in the report with its disposition
  (kept / merged / superseded) — an unreported deletion is a defect.
- Each surviving `MEMORY.md` is ≤ 200 lines (R3) and every index line points
  at a file that exists — assert by resolving every index link.
- No file is deleted whose content is not present, in full, in a surviving
  file. Report the verification method used.

## Step 3 — Adopt a pruning policy and a size warning

**Affected files:** `agents/lead-programmer.md` and sibling persona memory
guidance; `agents/scribe.md` (prune-on-release duty);
`tests/validate.sh` (warning only); `.claude-plugin/plugin.json`;
`CHANGELOG.md`.

State that per-unit completion records do **not** belong in memory (they are
derivable from the `.pass` marker and `CHANGELOG.md`), and add a
**non-blocking** size warning.

**Acceptance criteria**
- Persona memory guidance names completion records as out-of-scope:
  `grep -ci 'completion' agents/lead-programmer.md` ≥ 1 in the memory section.
- `scribe` carries a prune-on-release duty:
  `grep -ci 'prune' agents/scribe.md` ≥ 1.
- The size check **warns and exits 0** — it must never block: confirm by
  running `bash tests/validate.sh` with a namespace deliberately over the
  threshold and observing exit 0 with the warning on stderr.
- Degrades gracefully (P4): with a namespace directory absent, the check
  exits 0 — assert by temporarily moving one aside.
- Version bumped beyond `HEAD` and named in `CHANGELOG.md`.
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **Should existing completion-record memories be deleted retroactively?**
   The policy in Step 3 is forward-looking. Retroactive deletion would reclaim
   the most space but is irreversible (R1) and some "completion" notes carry
   findings beyond the completion fact itself — this project's own memory
   index shows several that do. Recommended default: **do not bulk-delete.**
   Have `scribe` prune them individually at the next release, keeping any
   entry that records a finding rather than a fact. Requires a human decision
   only if bulk deletion is wanted.

## Self-check

- CHK1: Does the spec verify the namespace mechanism before merging? — PASS
  (Step 1 gates Step 2 and may terminate the spec).
- CHK2: Is any irreversible deletion performed without a report? — PASS
  (Step 2 requires a per-collision disposition; Step 3 only warns).
- CHK3: Is the duplication characterised as cost or correctness? — FAIL
  (ambiguous) — revised in place: Context now states the split-brain
  visibility problem is the substantive defect and the byte count is the
  symptom.
- CHK4: Is the index truncation limit accounted for? — PASS (R3 and Step 2's
  ≤200-line criterion).
- CHK5: Could Step 3's warning silently become a blocker? — PASS (explicit
  exit-0-with-warning observation required).
- CHK6: Is the canonical namespace chosen on evidence? — PASS (file counts
  per namespace, stated in the Clarifications entry).

## Scribe update hint

Add a **memory namespace** glossary entry recording the canonical form and
the historical `antislop-` duplication, so the split-brain is not
rediscovered. Record the completion-record policy alongside it.

## Dispatch contract (fast path — 3 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item05-agent-memory-dedup.md`.
Order: Step 1 strictly gates Step 2; Step 3 is independent.

### Unit: item05-1-namespace-resolution-probe
- **Objective:** Determine what selects the agent-memory namespace.
- **Retrieval:** Step 1.
- **Affected files:** none (measurement only).
- **Ordered edits:** probe resolution → determine merge safety → report.
- **Do NOT touch:** any memory file.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** 8 namespaces, 4 personas duplicated (bare + `antislop-` prefix); both dispatch forms appear in the live agent list, so both paths are reachable. Counts: lead-programmer 57/8, spec-master 55/4, scribe 51/4, task-master 19/5.
- **Escalation:** if resolution cannot be determined, report "unsafe" — that correctly stops the merge rather than risking a silent re-split.

### Unit: item05-2-merge-namespaces
- **Objective:** Merge `antislop-<persona>/` into `<persona>/`.
- **Retrieval:** Step 2. **Conditional on item05-1 reporting "safe".**
- **Affected files:** `.claude/agent-memory/*` (gitignored per-clone state).
- **Ordered edits:** enumerate collisions → hand-merge each → merge indexes → verify every index link resolves → report dispositions.
- **Do NOT touch:** file content beyond merging; never overwrite on collision.
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** irreversible — these files are gitignored with no recovery source. The `antislop-` copies are smaller but not necessarily stale; at least one contains content the bare namespace lacks.
- **Escalation:** if item05-1 reported "unsafe", do not run this unit; report that it is correctly blocked.

### Unit: item05-3-pruning-policy
- **Objective:** State the completion-record policy and add a non-blocking size warning.
- **Retrieval:** Step 3.
- **Affected files:** `agents/lead-programmer.md`, sibling persona memory guidance, `agents/scribe.md`, `tests/validate.sh`, `.claude-plugin/plugin.json`, `CHANGELOG.md`.
- **Ordered edits:** add policy prose → add scribe prune duty → add warn-only size check → verify exit 0 → regenerate → bump → CHANGELOG.
- **Do NOT touch:** existing memory files (retroactive pruning is Open Question 1).
- **Acceptance criteria:** as Step 3.
- **Pre-resolved context:** independent of items 05-1/05-2, may run first. The check must WARN, never block — an exit-nonzero here would gate turn-end on memory hygiene, which nothing else in the repo does.
- **Escalation:** if a warn-only check cannot be expressed in `validate.sh` without affecting its exit code, report rather than making it blocking.
