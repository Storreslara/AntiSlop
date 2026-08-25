# Redesign the Microworlds workflow: a committed watch-map, a detectable layer, reviewer-authored escalation manifests, and a demand-gated dashboard

Status: **FINAL — dispatch-ready** (spec-master, 2026-08-25). Baseline HEAD `09cc304`.
Spec 4 of 5 derived from the 2026-08-25 adversarial architecture critique.

Every count, file path, line number and verdict below was executed live against
the working tree at `09cc304`. Nothing here is inferred from the critique's
prose — two of its five findings did **not** survive verification and are
corrected rather than implemented (see "Verification of the critique" first;
it changes what this spec builds).

## Goal

Make the Microworlds sub-feature cost what it is worth at each stage of its own
lifecycle: a **zero-ceremony reactive check** that survives a fresh clone, a
**loud absence** instead of a silent one, a **reviewer-vouched manifest** at the
one moment a human actually reads it, and a **demand-gated dashboard** whose
capabilities are documented as load-bearing or speculative rather than assumed.

Non-goal: shrinking the dashboard. ADR 0019's two-layer human/machine split is
sound and stays.

## Verification of the critique

The critique was checked finding by finding against the repo. Two findings are
materially wrong at HEAD.

| # | Critique claim | Verified verdict |
|---|---|---|
| 1 | "**every** current bundle's `run.sh` is a thin wrapper over `tests/*.test.sh`" | **7 of 9 true, 2 false.** Corrected below — the fix changes shape. |
| 2 | `microworlds/` gitignored; rerun hook exits 0 silently when absent | **True.** `hooks/scripts/microworld-rerun.sh:17`. Build it. |
| 3 | implementer authors `functions[]`; reviewer copies it over unverified | **True, and sharper than stated.** Build it. |
| 4 | dashboard productized ahead of its consumer (`humanReviewMode: "off"`) | **True.** `.claude/persona-config.json` last key is `"humanReviewMode": "off"`. Build the demand gate. |
| 5 | "dashboard doesn't surface CHANGES.md in escalation packets" | **STALE — already closed.** Do **not** implement. |

### Finding 1, corrected: 7 of 9 bundles are thin wrappers; 2 carry real logic

Measured (`run.sh` lines after stripping comments, `set -`, and `cd`):

| Bundle | Substantive lines | Shape |
|---|---|---|
| `gh338` | 1 | `exec node tests/cli-backfill.test.js` |
| `gh347-1` | 1 | `exec bash tests/reviewer-route-gate-caller.test.sh` |
| `gh351` | 1 | `exec node tests/dashboard-decision-block.test.js` |
| `hdg-lexer-1` | 2 | two committed suites |
| `hdg-prose-2` | 2 | two committed suites |
| `hdg-prose-2-fix2` | 2 | two committed suites |
| `rpg-comment-3` | 2 | two committed suites |
| **`hdg-anchor-1`** | **29** | two suites **+ a mutation control**: deletes only the anchored arm, asserts ≥126 kills and zero `rc=1` crashes |
| **`rpg-canon-2`** | **32** | two suites **+ two mutation proofs** via `fn/mutate.py`, asserting each call site of `mentions_marker_dir()` is independently load-bearing |

The two outliers are exactly the two most recent and most rigorous units, and
their mutation proofs exist **nowhere in the committed test suite** —
`git ls-files | grep -i mutate` returns nothing; `fn/mutate.py` is untracked.
A blanket "replace bundles with a watch-map" would therefore **silently delete
the strongest verification artifacts in the repo**, which is the opposite of the
critique's intent.

So the redesign is a **two-tier split keyed on `run.sh` substance**, not a
replacement.

### Finding 5, corrected: the CHANGES.md gap was closed by gh375

Closed at commit `0779929` ("feat(gh375): dashboard renders CHANGES.md/QUIZ.md,
quiz select, reveal"). Verified end to end:

- **Data layer** — `bin/microworld-dashboard/decisions.js:59-63` reads
  `CHANGES.md` into `entry.changesBody`, fail-soft to `null` when absent.
- **Render layer** — `bin/microworld-dashboard/index.html:635-637` renders it,
  labelled, in the reading order CHANGES.md → PACKET.md → EXAMPLES.md, omitting
  the pane entirely (not an empty pane) when null.
- **Regression coverage** — `tests/dashboard-decisions.test.js` Test (i)
  (data layer, presence + fail-soft absence) and
  `tests/dashboard-decisions-client.test.js` Test (g) (render, presence,
  ordering, clean absence).
- **In the merge gate** — every one of the 37 files matching
  `tests/*.test.{sh,js}` is registered in `tests/validate.sh`; there are zero
  unregistered test files. The guard is not vacuous.

The project memory note `project_gh299_known_gaps.md` still lists this as the
"highest priority" open gap and cites `decisions.js:48`. That note is stale.
Correcting it is Step 5 of this spec — the gap is closed, and re-implementing it
would be duplicated work.

## Problem Statement

As the operator, four things about Microworlds cost more than they return:

1. I pay full bundle ceremony (`manifest.json` with `unit`/`description`/
   `timeoutSeconds`/`watch`/`functions[]`, plus `run.sh`) for seven of nine
   units whose entire machine-facing contract is "run this committed test file"
   — information a one-line glob→command mapping already carries.
2. If I clone this repo fresh, the entire reactive-check layer is gone and
   nothing tells me. The hook `exit 0`s on a missing directory, by design
   (ADR 0017 calls this "the **normal** state"), so absence and health are
   indistinguishable.
3. When a unit escalates, the human reads a `manifest.json` and `functions[]`
   authored by the **implementer** — the party whose work is under review —
   copied across verbatim by `cp -a` and never checked. ADR 0019 already accepts
   this as costs R1 (bundle-authorship unverifiability) and R9 (stale `location`
   line numbers).
4. The dashboard is 1,872 lines of JS across nine modules (plus a 1,369-line
   `index.html`), serving eight HTTP route keys, built against
   `humanReviewMode: "off"`. Nothing records which of its capabilities
   are earning their keep and which were built on spec, so the next capability
   gets built the same way.

## Solution

1. **A committed watch-map** (`tests/watch-map.json`) carries the glob→command
   mapping for every unit whose check is just "run these committed suites."
   Those units need no bundle at all. A bundle is reserved for the two cases
   that genuinely need one: a `run.sh` carrying logic beyond test invocation, or
   a unit that actually escalates.
2. **The microworld layer reports its own presence** at SessionStart, alongside
   the existing `code-review-graph status` line, and warns loudly on the two
   states that are actually dangerous: an escalation pending with no packet, and
   `humanReviewMode` on with zero bundles present.
3. **The reviewer vouches for the escalation manifest.** At escalation, after
   the would-be verdict is settled, the reviewer verifies every
   `functions[].location` against the escalation commit (authoring `functions[]`
   outright when the unit has none) and stamps a `verifiedBy` block into the
   **packet copy only**. The dashboard renders that provenance — and renders its
   **absence** just as visibly.
4. **Dashboard build-out becomes demand-driven.** A committed capability
   register classifies every route as load-bearing (with the escalation or
   debugging session that cites it) or speculative, and a bijection test keeps
   the register honest as routes are added.
5. **The CHANGES.md gap is recorded as closed**, not rebuilt.

## User Stories

1. As the operator, I want a unit whose check is a committed test file to need
   no bundle at all, so that the reactive layer costs one line of JSON instead
   of a directory of ceremony.
2. As the operator, I want the two bundles carrying mutation proofs to keep
   carrying them, so that redesigning the layer does not delete my strongest
   verification artifacts.
3. As the operator cloning this repo fresh, I want the reactive-check layer to
   work immediately from committed files, so that a clone is not silently
   degraded.
4. As the operator, I want SessionStart to tell me how many bundles are present,
   so that "absent" and "healthy" are distinguishable states.
5. As the operator, I want a loud warning when an `.escalated` marker exists
   with no packet directory behind it, so that an evaporated escalation is
   detected rather than discovered later.
6. As the operator, I do **not** want a warning on every fresh clone in the
   normal `humanReviewMode: "off"` posture, so that the signal does not become
   noise I learn to ignore.
7. As a human reading an escalation packet, I want the `functions[]` I explore
   to have been checked by the reviewer, not the implementer, so that the party
   vouching for the evidence is not the party who produced the code.
8. As a human reading an escalation packet, I want a stale `location` line range
   to have been corrected at escalation time, so that clicking a function shows
   me the right code.
9. As a human reading an escalation packet, I want to see plainly when a
   manifest was **not** verified, so that unverified evidence is visibly
   unverified rather than silently indistinguishable from verified evidence.
10. As a reviewer, I want manifest verification to happen after my verdict is
    settled, so that exploring a `functions[]` entry never becomes an input to
    the verdict.
11. As the operator, I want the working-tree bundle to stay untouched by
    verification, so that bundles remain gitignored scratch and never enter a
    diff.
12. As the operator, I want a written record of which dashboard capabilities are
    load-bearing today, so that I can tell maintenance from speculation.
13. As the operator, I want a new dashboard route to be blocked from merging
    until it is registered and classified, so that the register cannot silently
    rot the way the gh299 note did.
14. As the operator, I want the `why`/`differential` gate-debugging functions to
    keep working exactly as they do, so that the one dashboard use case with
    demonstrated value is not disturbed.
15. As the operator, I want the stale gh299 memory note corrected, so that I do
    not re-dispatch work that shipped at `0779929`.
16. As a lead-programmer, I want to stop authoring `functions[]` at
    implementation time for heavy units, so that I am not producing an artifact
    that will be re-derived anyway.
17. As a reviewer, I want the bundle-presence check to accept "covered by the
    watch-map" as a valid state, so that a tier-A unit is not failed for a
    missing directory it is not supposed to have.
18. As the operator, I want the watch-map's commands to be the same ones the
    merge gate runs, so that the two cannot drift apart.

## Implementation Decisions

### D1 — Two tiers, keyed on `run.sh` substance

- **Tier A (watch-map).** A unit whose machine-facing check is one or more
  invocations of committed test files gets an entry in `tests/watch-map.json`
  and **no bundle directory**.
- **Tier B (bundle).** A unit gets a full `microworlds/<slug>/` bundle only when
  either: (a) its check needs logic beyond invoking committed suites — a
  mutation proof, a sandbox differential, a fixture perturbation; or (b) it
  escalates to a human, which requires `functions[]` for exploration.

A unit may be promoted A→B mid-flight. Demotion is never required; existing
bundles are not migrated by this spec (see Out of Scope).

### D2 — `tests/watch-map.json` shape

Committed, at `tests/` so it sits beside the suites it names. Deliberately
reuses the manifest's existing field vocabulary (`watch`, `timeoutSeconds`) so
`microworld-rerun.sh`'s glob-matching and timeout logic is **shared, not
duplicated**:

```json
{
  "entries": [
    {
      "id": "gate-suites",
      "watch": ["hooks/scripts/human-decision-gate.sh",
                "hooks/scripts/reviewed-path-gate.sh",
                "hooks/scripts/lib/benign-command.sh",
                "tests/human-decision-gate.test.sh",
                "tests/reviewed-path-gate.test.sh"],
      "run": ["bash tests/human-decision-gate.test.sh",
              "bash tests/reviewed-path-gate.test.sh"],
      "timeoutSeconds": 180
    }
  ]
}
```

- `run` is an array of commands executed from the project root, in order; the
  entry fails on the first non-zero exit.
- `id` is for audit-log attribution only; it occupies the same `unit=` slot the
  existing log format already defines, so **the audit log format does not
  change** and `bin/microworld-dashboard/audit-log.js` and
  `tests/microworld-audit-contract.test.js` need no modification.
- No `functions[]`, no `description`, no `run.sh`, no directory.

### D3 — `microworld-rerun.sh` reads both sources

The hook's early exit becomes: proceed if **either** `microworlds/` exists **or**
`tests/watch-map.json` exists. Watch-map entries and bundles are both matched
against the edited path and both reported into the same audit log with the same
line format. The hook remains a **reporter, not a gate** (exit 2 surfaces
breakage to the model; every infrastructure problem still logs and exits 0) —
that contract is unchanged.

### D4 — Watch-map commands must be merge-gate commands

Every command string in `run` must correspond to a test file that
`tests/validate.sh` also registers. This is what stops the watch-map from
becoming a second, drifting test registry. Enforced by test, not by prose.

### D5 — SessionStart microworld-layer status

`hooks/scripts/session-start.sh` gains a fourth job, emitted through the existing
`context_parts` / `additionalContext` mechanism (no new output channel). It
computes: bundle count, watch-map entry count, pending `.escalated` marker
count, and orphaned-marker count (an `.escalated` whose
`.claude/human-review/<task-id>/` directory is absent).

Emission rules — deliberately quiet in the normal posture, per ADR 0017's
"absence is normal" and user story 6:

| Condition | Emit |
|---|---|
| any orphaned `.escalated` marker | **always warn**, naming each task-id |
| `humanReviewMode` != `"off"` **and** bundle count == 0 | **warn**, naming zero present bundles |
| `humanReviewMode` != `"off"` and bundles present | one status line with the counts |
| `humanReviewMode` == `"off"` and no orphans | **silent** |

This amends ADR 0017's "Consequences → For CI and fresh clones" paragraph, which
currently states the silent no-op is unconditionally correct. The amendment is
narrow: silence stays correct in the `off` posture and for the hook itself; only
SessionStart reporting changes.

### D6 — `verifiedBy`, written into the packet copy only

At escalation, **after the would-be verdict is settled** — the same phase in
which `CHANGES.md` and `EXAMPLES.md` are already authored, and therefore not a
verdict input — the reviewer:

1. Copies the bundle as today (`cp -a`), unchanged.
2. For each `functions[]` entry, verifies `location.file` exists at the
   escalation commit and `startLine`/`endLine` lie within that file's line count
   and still bracket the named `group`. Corrects any stale range **in the packet
   copy**.
3. Authors `functions[]` outright when the escalating unit has none.
4. Stamps into `.claude/human-review/<task-id>/manifest.json`:

```json
"verifiedBy": {
  "agent": "reviewer",
  "timestamp": "2026-08-25T12:00:00Z",
  "commit": "<40-hex sha at escalation>",
  "functionsAuthoredBy": "reviewer",
  "locationsChecked": "2/2",
  "locationsCorrected": 1
}
```

`functionsAuthoredBy` is `"reviewer"` when the reviewer authored the array, or
`"implementer-verified"` when it was carried over and checked.

**The working-tree bundle is never modified.** `verifiedBy` exists only in the
packet, which preserves ADR 0017's gitignored-scratch property and keeps bundles
out of every diff.

This closes ADR 0019's accepted cost R9 for escalated units specifically (R9
remains accepted for non-escalated bundles, which no human reads) and converts
R1 from "nothing can assert authorship" to "the packet asserts it, for the only
copy a human sees."

**Scope boundary.** This is a Microworlds-local authoring step. It does not
introduce, and must not be read as introducing, a general mechanical-enforcement
regime for reviewer self-report — that is sibling spec 1's territory.
`verifiedBy` is a self-reported stamp with a machine-checkable *shape*, not a
proof.

### D7 — `lead-programmer` stops authoring `functions[]`

`agents/lead-programmer.md:41` currently requires `functions[]` authoring for
heavy-trigger units at implementation time. That instruction is removed:
`functions[]` is authored at escalation, by the reviewer. The implementer's
Microworlds obligation reduces to a tier-A watch-map entry, or a tier-B bundle
when D1's criteria apply.

### D8 — `reviewer` bundle-presence check accepts tier A

`agents/reviewer.md:57-58` requires confirming `microworlds/<unit-slug>/`
exists with a `manifest.json` and `run.sh`. This is amended: a unit covered by a
`tests/watch-map.json` entry satisfies the check with no directory. The
prohibitions are **unchanged and restated**: never invoke a `functions[]` entry
to adjudicate the unit; the dashboard is never an acceptance criterion.

### D9 — Dashboard capability register, demand-gated

A committed `docs/microworld-dashboard-capabilities.md` holds one row per
dashboard capability, with a `status` of `load-bearing` or `speculative` and,
for load-bearing rows, the citing escalation or debugging session. A row's
`Route` cell may name **more than one** route key when several keys share a
capability (`/api/bundles` + `/api/status`; `/api/decision/arm` +
`/api/decision/run`); D11's test extracts **every** route literal from every
`Route` cell, so the six seed rows below cover all eight route keys. Seeded from
the verified inventory at `09cc304`:

| Route | Capability | Status | Cited by |
|---|---|---|---|
| `POST /api/invoke` | run a `functions[]` entry (notebook cells) | load-bearing | gate debugging on `hdg-prose-2`, `hdg-anchor-1`, `rpg-canon-2` (`why`, `differential`, `branch`, `arms`, `spelling`, `sites`) |
| `GET /api/bundles`, `GET /api/status` | bundle enumeration + rerun status | load-bearing | surfaces the machine layer; every bundle listing |
| `GET /api/decisions` | four human-decision touchpoints | load-bearing | ADR 0018; inert while `humanReviewMode: "off"` |
| `GET /api/context` | git HEAD sha + userName for decision stamps | load-bearing | stamps every composed decision block |
| `POST /api/decision/arm`, `POST /api/decision/run` | arm/execute a composed decision | load-bearing | ADR 0018 decision surface |
| `GET /api/source` | bounded source excerpt for `location` | **load-bearing as `location` click-through; speculative as general code exploration** | classified per D10 |

**The demand gate:** a new route, a new manifest field consumed by the
dashboard, or a new pane may be added only with a register row citing an actual
escalation or debugging session that needed it, or explicitly marked
`speculative` with a rationale. This is a documented policy plus the bijection
test in D11 — it is not a hook and does not block anything at runtime.

### D10 — `/api/source` classification

Kept, classified as load-bearing **only** in its `location` click-through role
(it is what makes `functions[].location` useful, and `location` is exactly what
D6 has the reviewer verify). Its use as a general code browser is marked
speculative in the register. No code change; this is a classification decision
so that the next capability in this area has a stated precedent.

### D11 — The register cannot rot

A test extracts every `pathname === '/api/...'` literal from
`bin/microworld-dashboard/server.js` and every route row key from
`docs/microworld-dashboard-capabilities.md` and asserts the two sets are equal.
Adding a route without a register row fails the merge gate; deleting a route
without deleting its row fails too. This is the mechanism the gh299 note lacked,
which is why that note went stale unnoticed for ten days.

## Testing Decisions

A good test here asserts **external behaviour at the highest existing seam** and
does not reach into implementation. The seams already exist and are preferred to
new ones:

- **`tests/microworld-rerun.test.sh`** (existing, in the merge gate) is the seam
  for D2–D4. It already builds throwaway project trees with fixture manifests
  and asserts hook behaviour and audit-log lines; watch-map cases are new
  fixtures in the same harness. Prior art: its existing malformed-manifest and
  missing-`run.sh` cases, which assert the fail-soft-and-log contract.
- **A new `tests/session-start-microworld-status.test.sh`** for D5, modelled on
  `tests/stop-gate-escalated.test.sh` (throwaway tree, seeded
  `.claude/reviewed/*.escalated` markers, hook invoked with piped JSON stdin,
  assertions on emitted text). Must assert the **silent** case as sharply as the
  warning cases — a warning that always fires is the failure mode.
- **`tests/dashboard-packets.test.js`** (existing) is the seam for `verifiedBy`
  surfacing: it already covers `discover.js`'s packet-bundle path. Assert both
  that a `verifiedBy` block is exposed and that its **absence** is exposed as an
  explicit unverified state, not as a missing key.
- **`tests/dashboard-decisions-client.test.js`** (existing) is the seam for the
  provenance line rendering, following its Test (g) pattern for
  presence/ordering/absence.
- **A new `tests/dashboard-capability-register.test.js`** for D11 — a pure
  set-equality bijection over two committed files, no server started.
- **`tests/adapter-protocol-parity.test.js`** (existing) already guards the
  codex/cursor ports against drift on reviewer/orchestrator prose; the D6–D8
  persona edits must keep it green, and the adapter ports are hand-maintained,
  so they need explicit updating.
- Every new test file must be registered in `tests/validate.sh` — the repo
  currently has **zero** unregistered test files and that invariant holds.

Anti-vacuity discipline applies throughout: for each new criterion, revert the
fix and confirm the test actually flips. A criterion that survives its own
mutation is vacuous and does not count as met.

## Steps

### Step 1 — `tests/watch-map.json` + rerun hook reads it

Add the committed watch-map, seeded with entries covering the seven tier-A
bundles' suites. Teach `hooks/scripts/microworld-rerun.sh` to match watch-map
entries in addition to bundles, sharing the existing glob and timeout logic, and
to proceed when `microworlds/` is absent but the watch-map is present.

**Acceptance criteria (machine-checkable):**

- **AC1.1** `jq -e '.entries | length >= 1' tests/watch-map.json` exits 0, and
  `git ls-files tests/watch-map.json` prints the path (it is committed).
- **AC1.2** In a throwaway tree with **no** `microworlds/` directory but with
  `tests/watch-map.json` present, editing a file matching an entry's `watch`
  glob causes that entry's `run` commands to execute; the audit log gains a line
  matching `^[0-9TZ:-]* unit=<id> result=(pass|fail|timeout|error) file=<path>$`.
- **AC1.3** With neither `microworlds/` nor `tests/watch-map.json` present, the
  hook still exits 0 and writes no audit line (the pre-existing contract is not
  broken).
- **AC1.4** A watch-map entry whose first `run` command exits non-zero logs
  `result=fail` and the hook exits 2; a later command in the same entry is not
  executed.
- **AC1.5** A malformed `tests/watch-map.json` logs `result=error` with a reason
  and the hook exits **0** (infrastructure problems never gate), matching the
  existing malformed-manifest behaviour.
- **AC1.6** For every command string in every entry's `run`, the test file it
  names is registered in `tests/validate.sh` — asserted by a test, so a
  watch-map naming an unregistered suite fails the merge gate.
- **AC1.7** `bash tests/microworld-audit-contract.test.js`'s asserted log format
  is unchanged: the file `tests/microworld-audit-contract.test.js` is not
  modified by this step and still passes.
- **AC1.8** Mutation proof: revert the hook's watch-map branch, re-run
  `tests/microworld-rerun.test.sh`, and confirm the new cases fail. A surviving
  suite means the criteria are vacuous.

### Step 2 — SessionStart reports the microworld layer

Add the fourth job to `hooks/scripts/session-start.sh` per D5.

**Acceptance criteria (machine-checkable):**

- **AC2.1** In a throwaway tree with `persona-config.json` holding
  `"humanReviewMode": "critical"` and **zero** bundle directories, the hook's
  `additionalContext` contains a warning naming zero present bundles.
- **AC2.2** In an otherwise identical tree with `"humanReviewMode": "off"` and
  no orphaned markers, the hook emits **no** microworld line at all (silence in
  the normal posture).
- **AC2.3** With an `.claude/reviewed/<id>.escalated` marker present and
  `.claude/human-review/<id>/` **absent**, the hook warns and names `<id>`,
  **regardless** of `humanReviewMode` — including `"off"`.
- **AC2.4** With marker and packet directory both present, no orphan warning is
  emitted.
- **AC2.5** With no `persona-config.json`, the hook still exits 0 emitting
  nothing (the existing unconditional early return is preserved).
- **AC2.6** The hook's output remains valid JSON in every branch:
  `jq -e '.hookSpecificOutput.hookEventName == "SessionStart"'` exits 0 whenever
  output is produced, and output is empty otherwise.
- **AC2.7** Mutation proof: revert the emission block; AC2.1 and AC2.3 flip to
  failing.

### Step 3 — Reviewer authors and stamps the escalation manifest

Edit `agents/reviewer.md` (escalation bullet, ~`:189-200`) per D6 and the
bundle-presence bullet (~`:57-58`) per D8. Edit
`agents/lead-programmer.md:41` per D7. Propagate to
`templates/persona-protocol.md` and both adapter ports (`adapters/codex`,
`adapters/cursor`) — these are hand-maintained and will not update themselves.
Surface `verifiedBy` in `bin/microworld-dashboard/discover.js`'s packet path and
render a provenance line in `index.html`'s escalation view.

**Acceptance criteria (machine-checkable):**

- **AC3.1** For a packet produced by an escalation after this step,
  `jq -e '.verifiedBy.agent == "reviewer"' .claude/human-review/<id>/manifest.json`
  exits 0, and `jq -re '.verifiedBy.commit' <same> | grep -Eq '^[0-9a-f]{40}$'`
  exits 0.
- **AC3.2** `jq -e '.verifiedBy.functionsAuthoredBy | . == "reviewer" or . == "implementer-verified"'`
  exits 0 — the field distinguishes reviewer authorship from verified
  carry-over, so implementer-authored-and-unchecked is not expressible.
- **AC3.3** The working-tree bundle is unmodified by escalation: for every
  `microworlds/<slug>/manifest.json`,
  `jq -e 'has("verifiedBy") | not'` exits 0.
- **AC3.4** `discover.js`'s packet path exposes `verifiedBy` on the packet
  bundle object when present, and exposes an explicit unverified marker (not an
  absent key) when the packet manifest has no `verifiedBy` — asserted in
  `tests/dashboard-packets.test.js` for both cases.
- **AC3.5** The escalation view renders a provenance line naming the verifying
  agent and commit when `verifiedBy` is present, and renders an explicit
  "unverified — carried over from implementation" line when it is absent —
  asserted in `tests/dashboard-decisions-client.test.js` for both cases.
- **AC3.6** `grep -c 'functions\[\]' agents/lead-programmer.md` returns 0 for
  the authoring instruction: the implementer no longer owns `functions[]`.
- **AC3.7** `agents/reviewer.md` still contains the prohibition "Never invoke a
  `functions[]` entry to adjudicate the unit" and the clause that the dashboard
  is never an acceptance criterion — verification must not have made the
  dashboard adjudicative.
- **AC3.8** `node tests/adapter-protocol-parity.test.js` passes: both adapter
  ports carry the amended reviewer/lead-programmer language.
- **AC3.9** Per constitution §3, `.claude-plugin/plugin.json`'s version is
  bumped and a CHANGELOG entry added (this step edits version-stamped
  `agents/*.md` and `templates/`).

### Step 4 — Dashboard capability register + bijection test

Add `docs/microworld-dashboard-capabilities.md` seeded from D9, and
`tests/dashboard-capability-register.test.js` per D11. Register the new test in
`tests/validate.sh`.

**Acceptance criteria (machine-checkable):**

- **AC4.1** The set of `/api/*` route literals extracted from
  `bin/microworld-dashboard/server.js` equals the set of route row keys in
  `docs/microworld-dashboard-capabilities.md`. At `09cc304` both sets have
  **eight** members: `/api/bundles`, `/api/context`, `/api/decision/arm`,
  `/api/decision/run`, `/api/decisions`, `/api/invoke`, `/api/source`,
  `/api/status`. Note that `/api/bundles` and `/api/status` share a single
  handler block, so the eight keys sit across seven handlers; the test asserts
  on **route keys**, not handlers.
- **AC4.2** Every row's `status` is exactly `load-bearing` or `speculative`; any
  other value fails.
- **AC4.3** Every `load-bearing` row has a non-empty "Cited by" cell.
- **AC4.4** Mutation proof: add a dummy `/api/zzz` route literal to
  `server.js`; the register test fails. Remove it; the test passes. Then delete
  a register row without touching `server.js`; the test fails.
- **AC4.5** `bash tests/validate.sh` registers and runs the new test (zero
  unregistered test files invariant holds).

### Step 5 — Record the CHANGES.md closure; correct the stale note

No code change. Update `project_gh299_known_gaps.md` to mark the dashboard
CHANGES.md gap **closed at `0779929`**, citing
`bin/microworld-dashboard/index.html:635-637` and the two covering tests. Note
the closure in the capability register's `/api/decisions` row.

**Acceptance criteria (machine-checkable):**

- **AC5.1** `node tests/dashboard-decisions-client.test.js` passes with its
  Test (g) assertions on CHANGES.md presence, ordering before PACKET.md, and
  clean omission when absent — confirming the guard is live, not that new code
  was written.
- **AC5.2** The memory note no longer describes the gap as open and no longer
  cites `decisions.js:48` as reading only `PACKET.md`.
- **AC5.3** No file under `bin/microworld-dashboard/` is modified by this step
  (`git diff --name-only` for the step's commit contains no such path) — the fix
  already shipped and must not be re-implemented.

## Risks / dependencies

- **R1 — Deleting tier-A bundles would delete the two mutation proofs.** The
  measured 7/2 split is the whole reason D1 is a tier split rather than a
  replacement. Any implementation that migrates `hdg-anchor-1` or `rpg-canon-2`
  into the watch-map is a defect, not a simplification. Guarded by D1 and by
  those bundles' `run.sh` line counts being restated in the spec.
- **R2 — Warning fatigue.** AC2.2 exists specifically to make the silent case
  testable. A build that emits a microworld line unconditionally satisfies AC2.1
  and AC2.3 while defeating the feature's purpose.
- **R3 — `verifiedBy` is a self-report.** It has a machine-checkable shape, not
  a machine-checkable truth: nothing proves the reviewer really re-derived each
  `location`. This is deliberate and scoped — the general self-report-vs-
  mechanical-enforcement question is **sibling spec 1's**, and this spec must not
  pre-empt its mechanism choice. If sibling 1 lands an enforcement primitive,
  `verifiedBy` is a natural first consumer.
- **R4 — Escalation is currently inert.** `humanReviewMode` is `"off"`, so
  Step 3's packet criteria (AC3.1–AC3.5) cannot be observed from a live
  escalation at HEAD. They must be verified against **fixture packets** in the
  dashboard tests, exactly as `tests/dashboard-packets.test.js` already
  constructs packet directories. Do not mark Step 3 met on prose alone.
- **R5 — Marker/dotfile layout is sibling spec 3's.** This spec reads
  `.claude/reviewed/*.escalated` and `.claude/human-review/<id>/` at their
  current paths. If sibling 3 relocates them, D5's orphan check and D6's packet
  path follow that spec's layout; the acceptance criteria here are about
  detection and provenance, not about where the files live.
- **R6 — Model-tier repricing is sibling spec 2's.** Nothing here assigns a
  model tier to any unit.
- **R7 — ADR churn.** Steps 1–3 require ADR amendments: 0017 (silent-absence
  consequence, D5) and 0019 (accepted costs R1/R9 narrowed for escalated units,
  D6). Both are amendments, not supersessions; ADR 0019's two-layer model and
  its "dashboard is never a gate" holding are reaffirmed, not disturbed.
- **R8 — Adapter ports are hand-maintained.** `adapters/codex` and
  `adapters/cursor` do not track `agents/*.md` automatically. AC3.8 is the guard.
- **R9 — Watch-map/validate.sh drift.** AC1.6 is the guard; without it the
  watch-map becomes a second test registry that silently diverges.

## Constitution check (.claude/constitution.md v1.0.0)

- **§1 Verify, don't assume** — honoured, and load-bearing here: two of the five
  critique findings were falsified by direct execution rather than accepted.
- **§2 Prefer deterministic scripts over LLM re-derivation** — the watch-map
  moves a per-unit LLM-authored artifact into one committed deterministic file;
  D11's bijection test replaces a memory note with a mechanical check.
- **§3 Version-stamp discipline** — AC3.9 covers the `agents/*.md` and
  `templates/` edits.
- **§4 Optional personas degrade gracefully** — D8's reviewer amendment and D5's
  escalation reporting must stay conditionally phrased; a project selecting no
  `reviewer` writes no `.escalated` marker, so the orphan check is naturally
  inert there.
- **§5 `tests/validate.sh` is the merge gate** — AC1.6, AC4.5 and the
  zero-unregistered-test-files invariant all bind to it.

## Out of Scope

- **Migrating the nine existing bundles.** They are gitignored working-tree
  scratch; they will age out naturally. This spec changes what the *next* unit
  is asked to produce.
- **Removing or shrinking the dashboard.** ADR 0019 stands.
- **Committing bundles.** ADR 0017's core decision is untouched; only its
  reporting consequence is amended.
- **The marker-file / dotfile consolidation** — sibling spec 3.
- **General model-tier repricing** — sibling spec 2.
- **The general self-report-vs-mechanical-enforcement mechanism** — sibling
  spec 1. D6 is a Microworlds-local authoring step only.
- **Re-implementing CHANGES.md rendering** — shipped at `0779929`.
- **Flipping `humanReviewMode` back on.** That is an operator posture decision
  (ADR 0024), not this spec's.
- **A warm `session` kernel for notebook cells.** ADR 0019 settled cells as
  independent fresh processes.

## Further Notes

The gh299 note going stale for ten days while sitting at the top of a memory
index is itself the strongest argument for D11. A documented gap with no
mechanical check attached decays into a false belief, and a false belief in a
memory index is worse than no note — it caused this spec's brief to carry a
finding that had already shipped. Every classification this spec introduces
therefore carries a test that fails when the classification stops being true.

The second observation worth carrying forward: the critique's "every bundle is a
thin wrapper" was 78% true, and acting on the confident-sounding 78% would have
deleted the repo's only two mutation proofs. The 22% was found by counting lines,
not by reading prose about the bundles.

## Scribe update hint

- Amend **ADR 0017** — "Consequences → For CI and fresh clones": silent no-op
  remains correct for the hook, but SessionStart now reports layer presence per
  D5; add the tier-A/tier-B distinction to the bundle definition.
- Amend **ADR 0019** — narrow accepted costs R1 and R9: for escalated units the
  packet's `verifiedBy` block asserts authorship and the reviewer corrects stale
  `location` ranges at escalation time. R1/R9 remain accepted for
  non-escalated bundles. Reaffirm that the dashboard is still never a gate.
- Consider a **new ADR** for D9/D11 (demand-gated dashboard build-out), since it
  is a standing policy rather than an amendment to an existing decision.
- Update `CONTEXT.md` and `README.md`'s Microworlds sections for the two-tier
  model and the watch-map.
- Correct `project_gh299_known_gaps.md` per Step 5.

## Open Questions

None blocking. Two judgement calls were made rather than escalated, and are
recorded here so a reviewer can overturn them cheaply:

1. **`tests/watch-map.json` location.** Placed under `tests/` rather than
   `microworlds/` because `microworlds/` is gitignored wholesale and the file
   must be committed; `tests/` also puts it beside the suites it names and
   beside `validate.sh`, which AC1.6 binds it to.
2. **`verifiedBy` in the packet only, never the bundle.** The alternative —
   stamping the working-tree bundle — would make verification visible earlier
   but would put a reviewer-authored field into gitignored implementer scratch
   and blur ADR 0017's ownership line. Packet-only keeps the bundle scratch.
