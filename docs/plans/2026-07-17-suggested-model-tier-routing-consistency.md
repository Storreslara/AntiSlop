# Spec: three-tier `Suggested model` routing consistency (orchestrator consumer)

Date: 2026-07-17
Author: spec-master
Status: Finalized — awaiting human go/no-go before tracker filing (see Open Questions)

## Goal
Make the orchestrator's *documented* per-unit model routing enumerate and
explicitly handle the full three-tier `Suggested model: haiku|sonnet|opus`
range that `task-master` already emits — closing a documentation
inconsistency where the consumer (`orchestrator.md`) documents reading only
two of the three tiers task-master produces.

## Context
This spec is the resolved outcome of a request to give `task-master` "new
behavior" to "decide which task require review and which lead programmers
need sonnet/haiku … use tokens effectively, not just throw a heavyweight
model." The request forked on a safety-relevant axis; the user resolved it
(see Clarifications OQ1) to interpretation **(a): purely tune the existing
model-tiering mechanism; no unit ever ships unreviewed.**

Investigation of interpretation (a) (OQ3) produced two findings:

1. **The user's stated cost concern needs no change — it is already covered
   by design.** Cited:
   - `lead-programmer` defaults to `sonnet`, not opus, when a unit is
     untagged (`README.md:56`, `agents/orchestrator.md:110-111`) — so
     implementation never defaults to a heavyweight model.
   - `opus` for implementation is reserved for "genuinely hard-judgment or
     high-stakes units" only (`agents/task-master.md:60`).
   - Mechanical units already get `haiku` implementation
     (`agents/task-master.md:58-59`) *and* sonnet-gated review
     (`agents/task-master.md:75-88`, ADR-0006).
   - The reviewer's `opus` default is the deliberate core safety property and
     was *already* narrowed to sonnet for demonstrably-mechanical units by
     ADR-0006. Widening it further would weaken the Writer/Reviewer split,
     which the user explicitly ruled out (OQ1).

2. **One concrete, verifiable gap exists — in the consumer, not in
   task-master.** `task-master` emits three tiers
   (`agents/task-master.md:57`: "tag every sliced unit `Suggested model:
   haiku|sonnet|opus`"; documented in `docs/adr/0003-...:27` as
   "haiku/sonnet/opus"). Its consumer, the orchestrator, documents reading
   only two:
   - `agents/orchestrator.md:108` ("## Per-unit model routing"): "check the
     sliced unit's `Suggested model: haiku|sonnet` tag … pass it as the
     dispatch's `model` parameter; omit … when the tag is absent."
   - `agents/orchestrator.md:207` (roast-work parenthetical): "mirroring its
     `Suggested model: haiku|sonnet` per-unit tag".

   The routing instruction never states how an `opus` tag routes. A strict
   reading — where `haiku|sonnet` is treated as the closed set of routable
   values — would treat `opus` as unrecognized and fall through to "omit the
   parameter," silently **downgrading a high-stakes unit to the sonnet
   default**. No `tests/validate.sh` check catches this cross-file
   inconsistency (verified: validate.sh has no tier-enumeration check).

**Framing note (honesty):** the original request named "task-master," but
task-master's tagging is already correct and complete (three tiers). The gap
is downstream, in the orchestrator's consumption docs. Consequently this spec
does **not** modify `agents/task-master.md`, which also resolves the
"fresh task-master required to slice" caveat from the first Open-Questions
report — a normal `task-master` dispatch can slice this.

**Direction note (honesty):** this fix is *off* the user's stated cost axis.
It improves tiering *correctness/completeness* (so an opus-tagged unit isn't
silently downgraded); it does not reduce token use. It is included because it
is a real, grep-verifiable inconsistency in the exact mechanism the user
pointed at, and the coordinator asked for concrete gaps to be specced. It is
not dressed up as fulfilling the cost request — that request needs no change.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-17 Functional scope & success criteria: Q Does "which task require
  review" mean (a) tune existing model-tiering only, or (b) a new capability
  where some units ship with no reviewer pass? → A: (a) — user confirmed no
  unit ever skips review; this is purely token efficiency via the existing
  model-tiering mechanism.
- 2026-07-17 Completion / acceptance signals: Q Is there a concrete, citable
  gap in how the tiering is applied, or does the mechanism already work? → A
  (self-resolved): the cost concern needs no change (covered by design,
  cited in Context finding 1); the one concrete gap is the orchestrator
  documenting only `haiku|sonnet` while task-master emits
  `haiku|sonnet|opus` (Context finding 2). This spec addresses only that.
- 2026-07-17 Terminology consistency: Q Should the three-tier enumeration be
  consistent across task-master.md, orchestrator.md, and ADR-0003? → A
  (self-resolved): yes — task-master.md and ADR-0003 already say three
  tiers; orchestrator.md is the outlier and is corrected here. Closed
  historical plan docs are left untouched (see Risks).

## Risks / dependencies
- **P2 (deterministic scripts) — do NOT hand-edit the mirror.**
  `.claude/agents/orchestrator.md` is `fileHashes`-tracked in
  `.claude/persona-config.json`. Per constitution P2 it must be regenerated
  from source via `node bin/cli.js --update` (which "regenerates a
  version-stamped file straight from the plugin's own source" —
  `bin/cli.js:159-166`), never hand-edited. Editing only the source
  `agents/orchestrator.md` and regenerating is the compliant path.
- **P3 (version-stamp) — editing `agents/*.md` mandates a version bump.**
  `.claude-plugin/plugin.json` (currently `0.13.5`) must bump to `0.13.6`
  with a matching `CHANGELOG.md` entry; `--update` depends on the version
  actually changing when content does.
- **Closed historical plan doc is out of scope.**
  `docs/plans/2026-07-14-threefold-update.md:475` also carries the two-tier
  form, but it is a closed planning artifact — not rewritten.
- **Low severity / off cost-axis.** Functionally, an orchestrator reading
  "pass it as the model parameter" likely already routes `opus` correctly;
  the defect is documentation completeness plus a small silent-downgrade
  risk on a strict reading. This is a correctness cleanup, not a cost win —
  the human should weigh whether it is worth executing (Open Questions).

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume": satisfied — every acceptance criterion is a
  runnable grep/exit-code check the implementer and reviewer must actually
  run; the source→mirror propagation mechanism was verified against
  `bin/cli.js:159-166`, not assumed.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  Step 3 mandates `node bin/cli.js --update` to regenerate the
  `fileHashes`-tracked mirror; no hand-edit of `.claude/agents/`.
- P3 "Version-stamp discipline": satisfied — Step 2 bumps `plugin.json` and
  adds a CHANGELOG entry for the `agents/orchestrator.md` change.
- P4 "Optional personas degrade gracefully": satisfied — the edit is a tag
  enumeration change; it introduces no new unconditional optional-persona
  reference (validate.sh's paragraph check, Step 4, confirms).
- P5 "`tests/validate.sh` is the merge gate": satisfied — Step 4 gates on a
  green `tests/validate.sh`.

## Steps

### Step 1 — Correct the tier enumeration in source `agents/orchestrator.md`
Affected files: `agents/orchestrator.md`
- In the "## Per-unit model routing" section (~line 108): change the
  enumeration `Suggested model: haiku|sonnet` to `haiku|sonnet|opus`, and add
  one clause stating an `opus` tag routes identically (passed through as the
  `model` parameter), reserved by task-master for genuinely hard-judgment /
  high-stakes units — so `opus` is documented as an expected, routable value,
  not an anomaly that falls through to "omit the parameter."
- In the roast-work parenthetical (~line 207): change
  `Suggested model: haiku|sonnet` to `Suggested model: haiku|sonnet|opus`.

Acceptance criteria (run from repo root):
- `grep -n 'Suggested model: haiku|sonnet' agents/orchestrator.md | grep -v 'haiku|sonnet|opus'` → prints nothing (no bare two-tier form remains).
- `awk '/## Per-unit model routing/,/^## /' agents/orchestrator.md | grep -qi 'opus'` → exit 0 (the routing section now addresses opus).
- `grep -q 'haiku|sonnet|opus' agents/task-master.md && grep -q 'haiku|sonnet|opus' agents/orchestrator.md` → exit 0 (consumer now agrees with emitter).

### Step 2 — Version-stamp the change (constitution P3)
Affected files: `.claude-plugin/plugin.json`, `CHANGELOG.md`
- Bump `.claude-plugin/plugin.json` `"version"` from `0.13.5` to `0.13.6`.
- Add a `CHANGELOG.md` entry for `0.13.6` describing the orchestrator
  per-unit-routing three-tier enumeration fix.

Acceptance criteria:
- `grep -q '"version": "0.13.6"' .claude-plugin/plugin.json` → exit 0.
- `grep -q '0.13.6' CHANGELOG.md` → exit 0.

### Step 3 — Regenerate the mirror deterministically (constitution P2)
Affected files: `.claude/agents/orchestrator.md`,
`.claude/persona-config.json` (its `fileHashes` entry) — both produced by the
script, not hand-edited.
- Run `node bin/cli.js --update` so the `.claude/agents/orchestrator.md`
  mirror is regenerated from the edited source and its `fileHashes` entry is
  refreshed. Do NOT hand-edit the mirror.

Acceptance criteria:
- `grep -n 'Suggested model: haiku|sonnet' .claude/agents/orchestrator.md | grep -v 'haiku|sonnet|opus'` → prints nothing (mirror carries the corrected enumeration).
- `awk '/## Per-unit model routing/,/^## /' .claude/agents/orchestrator.md | grep -qi 'opus'` → exit 0.
- `node bin/cli.js --update` re-run reports no pending drift for
  `.claude/agents/orchestrator.md` (fileHashes is in sync — verify per P1,
  don't assume).

### Step 4 — Merge gate (constitution P5)
Affected files: none (verification only)
Acceptance criteria:
- `bash tests/validate.sh; echo "exit=$?"` → `exit=0`.

## Open Questions
- **Go/no-go on executing this off-axis cleanup (decision for the human, not
  a spec ambiguity).** Recommended default: **proceed** — the fix is small,
  constitution-compliant as specced, and removes a real silent-downgrade
  risk for opus-tagged high-stakes units. But it does not serve the original
  token-efficiency motivation (which needs no change), so a "not worth the
  version bump / CHANGELOG churn right now" answer is equally legitimate. No
  spec ambiguity blocks finalization; only this priority call is open.

## Self-check
- CHK1: Are the exact `agents/orchestrator.md` locations to edit enumerated? — PASS
- CHK2: Do all acceptance criteria reduce to runnable grep/exit-code checks? — PASS
- CHK3: Does the plan prevent a P2-violating hand-edit of the fileHashes-tracked mirror? — PASS (Step 3 mandates `--update`)
- CHK4: Does the plan mandate the P3 version bump + CHANGELOG? — PASS (Step 2)
- CHK5: Is the source→mirror propagation mechanism verified rather than assumed? — PASS (confirmed against bin/cli.js:159-166)
- CHK6: Does the plan state that `agents/task-master.md` is NOT modified (so no fresh-task-master handoff is needed)? — PASS (Context framing note)
- CHK7: Do Steps 1 and 3 agree on the exact grep the corrected enumeration must satisfy in both source and mirror? — PASS (same two-tier-absence + opus-presence checks applied to each file)

## Scribe update hint
No ADR needed — this is a consistency correction, not a new decision. The
`CHANGELOG.md` entry (Step 2) is the sufficient institutional-knowledge
record. Optionally, the scribe may note in the changelog line that the
three-tier `Suggested model` enumeration is now consistent across
`agents/task-master.md`, `agents/orchestrator.md`, and ADR-0003.

## Handoff notes
- **Slicing:** a normal `task-master` dispatch slices this (it does not touch
  `agents/task-master.md`). Likely one small unit; task-master assigns the
  `Suggested model` tag — note the constitution-MUST coupling (P2/P3) means
  it is not purely mechanical, so `haiku` may under-serve it.
- **Tracker publish:** the `to-spec` skill is not installed in this session
  (local skills are only debug-issue/explore-codebase/refactor-safely/
  review-changes), so no automated PRD publish was run. Per
  `.claude/persona-config.json`, filing is one command on approval:
  `gh issue create` (repo Storreslara/AntiSlop) with the `ready-for-agent`
  label. This canonical `docs/plans/` document is the authoritative artifact
  regardless.
