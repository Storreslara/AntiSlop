# Refutation pass: challenge the reviewer's judgment defects before a FAIL verdict

Status: spec finalized 2026-10-27 (spec-master), fast path, 2 units. Contracts:
[rfp-u1](2026-10-27-refutation-pass/contracts/rfp-u1.md) (lead-programmer),
[rfp-u2](2026-10-27-refutation-pass/contracts/rfp-u2.md) (scribe, after rfp-u1 PASS).
Open Questions 1 to 4 carry recommended defaults that the contracts already apply. A different answer
changes rfp-u1's payload before dispatch.

## Goal

A FAIL defect the reviewer found by reading code (a **judgment defect**) reaches the lead-programmer only after
a fresh-context subagent has tried to disprove it against the real code: the whole file, its callers and the
baseline, not only the flagged hunk. If every defect is refuted, the unit passes and **no FAIL block is
written**, so no Escalation-ladder attempt is used up. Mechanical FAIL grounds are never re-checked. The pass
writes no marker. It leaves the one-unit-one-review invariant, the route gate, the stop gate and the ladder
arithmetic unchanged, and it costs nothing on PASS paths beyond the reviewer prompt's own size.

## Context

### Where the review path lives (verified, file:line at HEAD 1073743d)

- The reviewer's verdict rules are persona-specific prose in `agents/reviewer.md`: "Verdict" :127-143,
  "On FAIL" :241-256, "On INSUFFICIENT-CONTEXT" :257-269, precedence `FAIL > INSUFFICIENT-CONTEXT >
  ESCALATE-TO-HUMAN > PASS` :272. `.claude/agents/reviewer.md` is generated from it by
  `node bin/cli.js --update` (inlineProtocolBlock, bin/cli.js:1089). Hand-editing it is a P2 violation.
- The codex and cursor reviewer ports (`adapters/codex/agents/reviewer.toml`,
  `adapters/cursor/agents/reviewer.md`) are hand-authored. Neither has a verified subagent-spawn primitive
  (codex :136-139 "not empirically confirmed"; cursor :136 "UNVERIFIED"). Precedent: st-u2 changed the
  reviewer's FAIL-ground rules in `agents/reviewer.md` alone and left both ports untouched (commit 952a8796).
- The shared protocol (`templates/persona-protocol.md`, "FAIL record" :343, "Third verdict" :358) does
  **not** need to change. The FAIL record stays "the defect list from the verdict, verbatim". The pass only
  changes which defects reach that list.
- The FAIL-block count is the ladder's `n`: `bin/ladder-tier.sh` header, `bin/fail-count.sh`. A FAIL that
  never happens writes no block, so the ladder needs no new state and no new marker type.

### Gate interaction (verified by reading the gates and running their tests)

- **Route gate.** `hooks/scripts/lib/reviewer-route-gate-core.sh` acts only on a target that matches
  `reviewer`: the name check at :78-85, the review-join stamp at :94-153. The pending-review block at :37-52
  stops only `gatedAgents` targets (`lead-programmer`). So a reviewer that spawns `explorer` writes no stamp
  and is never blocked. A reviewer cannot spawn a `reviewer` (caller allowlist, fails closed:
  `tests/reviewer-route-gate-caller.test.sh:66`, `caller-reviewer ... reviewer 2`). That rules out a nested
  `Mode: advisory` reviewer. spec-master ran the new test case in a scratch copy: it prints `OK` twice, and
  with the core's `persona_matches_gate "$target_type" reviewer` condition removed, its no-stamp check prints
  `FAIL`.
- **Markers.** `hooks/scripts/reviewed-path-gate.sh` grants writes under `.claude/reviewed/` to the reviewer
  identity only (:249). An `explorer` falls through to the denial path (:292-299; pinned by
  `tests/reviewed-path-gate.test.sh:798-807`), and `explorer` has no Write/Edit tool. "The pass writes no
  marker" is therefore mechanically enforced, not only instructed.
- **Stop gate.** The explorer's `SubagentStop` takes the non-reviewer branch
  (`hooks/scripts/lib/stop-gate-core.sh:573-581`). While the reviewer's pending-review flag stands, that
  branch logs one `grant-denied hook=stop-gate identity=explorer` line to `review-audit.log`. Every
  reviewer-to-explorer spawn already does this today. It is noise, not a block (Risk R4).
- **INSUFFICIENT-CONTEXT path.** The reviewer writes `.blocked`, which uses no 2-FAIL-cap slot and keeps the
  pending-review flag standing. The orchestrator fetches the named constraint through the explorer or the
  scribe and resumes the same reviewer (`agents/orchestrator.md:276-292`). An UNCERTAIN-only refutation
  reuses this path unchanged, so the orchestrator needs no edit.

### Design decision (ADR draft; scribe numbers and lands it in rfp-u2)

> **ADR-draft: the refutation pass runs inside the reviewer's turn, not as an orchestrator dispatch.**
> *Context.* A hallucinated or already-mitigated FAIL defect uses up an Escalation-ladder attempt, because
> `n` is the FAIL-block count. *Decision.* Before returning FAIL, the reviewer spawns one foreground,
> unnamed `explorer` subagent to disprove its own judgment defects. Only defects that survive reach the FAIL
> record. *Alternatives rejected.* (C) The orchestrator dispatches a refuter after the reviewer's FAIL. By
> then the FAIL block has been written and `n` has already gone up. Undoing that would need a new marker
> written by the refuter, or a change to `ladder-tier.sh`, plus filtering in task-master's fix-contract
> dispatch. It would also need a second dispatch shape for the route gate. (A nested `Mode: advisory`
> reviewer) The caller allowlist refuses it, and it would still need the orchestrator. (New `refuter`
> persona) It costs a persona file, two adapter ports, personaSelection, cli.js lists and frontmatter
> checks, and it buys nothing that `explorer` (read-only, graph access, cheapest tier) does not already
> have. *Consequences.* No hook, marker, ladder or orchestrator change. The ports keep today's behaviour.
> The reviewer still owns the verdict, but it may not argue away a refutation whose artifact reproduces.
> The pass's verdict is evidence only. The three ADR tests: hard to reverse (moving to (C) later needs new
> state machinery), surprising (a reader expects a "second gate" to be a second dispatch), and a real
> trade-off (all three alternatives were viable).

### Per-defect protocol (wording is ours; the research gave none)

The reviewer sends the explorer one `D<n>: <file:line> <claim>` line per deduplicated judgment defect, plus
the baseline and the changed-file list. It sends no diff and no defect prose beyond the claim, which keeps
the prompt far below `dispatchHygiene.maxPromptBytes` (30000). The explorer answers three questions per
defect: (1) does the issue exist at the cited line, (2) is it in the change or already at the baseline,
(3) is the impact real or already mitigated by a guard, earlier validation or config elsewhere. It answers
with one line: `D<n>: REFUTED|CONFIRMED|UNCERTAIN — artifact: <command and output line, or file:line quote>`.

| explorer answer | reviewer re-check of the artifact | result |
|---|---|---|
| REFUTED, artifact reproduces | read the line / re-run the command | dropped; `NOTE[code]: refuted:` (PASS) or the `refutation` advisory section (FAIL) |
| REFUTED, defect already at baseline | `git show <baseline>:<file>` | dropped as REFUTED, unless it is an unmet acceptance criterion |
| CONFIRMED, artifact reproduces | same | stays a FAIL defect |
| UNCERTAIN (or a verdict with no artifact) | none | see the decision table below |
| any answer whose artifact does not reproduce, a missing line, or a truncated explorer | none | **stands as found** (today's behaviour) |

Verdict once the pass is done:

| defects standing or CONFIRMED | UNCERTAIN | verdict |
|---|---|---|
| ≥1 | any | FAIL with only the standing and CONFIRMED defects; REFUTED and UNCERTAIN ones go in the `refutation` advisory section (Open Question 1) |
| 0 | ≥1 | INSUFFICIENT-CONTEXT, `missing:` naming the evidence that would settle each; on the resume there is no second pass, and a defect still without an artifact becomes `NOTE[code]: unconfirmed:` |
| 0 | 0 | the PASS rules, escalation included; one `NOTE[code]: refuted:` line per defect |

**Why UNCERTAIN maps to INSUFFICIENT-CONTEXT, not ESCALATE-TO-HUMAN.** ESCALATE-TO-HUMAN gates a would-be PASS
only (precedence :272), and it spends a human. INSUFFICIENT-CONTEXT already means "I could not
authoritatively determine this". It uses no cap slot, keeps the review blocking, and has a working
orchestrator path that fetches the missing evidence and resumes the reviewer. The bias toward refutation
applies here: an unproven defect never uses up a ladder attempt.

### Cost model (an explicit design input)

- **When it runs:** only on a would-be FAIL whose every ground is a judgment defect, with 1 to 5 such defects
  after deduplication. A defect that already carries an artifact the reviewer produced (a command and its
  failing output) counts as mechanical and is not sent.
- **When it is skipped, with the reason:**
  - Any mechanical FAIL ground is present (a precheck failure line, an uncommitted tree, an out-of-scope
    path). The FAIL happens anyway, so the ladder attempt is spent regardless (Open Question 2).
  - More than 5 judgment defects. A full refutation is unlikely, and one explorer has `maxTurns: 10`.
  - The resume after an INSUFFICIENT-CONTEXT the pass caused, so the pass cannot loop.
  - No subagent can be spawned: the codex and cursor ports, or a spawn failure. The defects stand.
  - It never runs on PASS, INSUFFICIENT-CONTEXT or ESCALATE-TO-HUMAN paths of its own.
- **Deliberately NOT skipped:**
  - *A single defect.* This is the case where one refutation turns FAIL into PASS, the highest-value case.
    A "trivial" defect is not a FAIL ground under the materiality filter in the first place.
  - *An opus-tier unit.* An opus attempt is the most expensive fix round and the closest to ladder
    exhaustion, which stops for a human, so refuting there saves the most.
  - *`reviewGating.mode: off`.* Advisory FAILs still drive the in-session ladder count and a fix round.
- **Per-run cost:**
  - One foreground `explorer` on its frontmatter tier (`haiku`, `effort: low`, `maxTurns: 10`;
    Open Question 3), with a prompt under 2 KB.
  - Reviewer overhead of one spawn turn plus one artifact re-check per defect, which can run in parallel:
    about 2 to 6 reviewer turns out of its 50.
  - Latency of one subagent round-trip on the FAIL path only.
- **Standing cost:** the 34-line bullet in `agents/reviewer.md`, paid on every reviewer dispatch
  (`cacheTtl: 1h` caches it). It is budgeted by rfp-u1 criterion 4 (at most 36 added lines). Two on-demand
  placements were rejected:
  - A new skill. Its description would be paid in every session's skill listing, for every persona.
  - A new protocol section. That would touch cli.js's section matrix, the protocol-doc-drift section
    counts and the adapter parity map.
- **Saved per refuted FAIL:**
  - One task-master fix-contract dispatch.
  - One lead-programmer attempt at the ladder's tier.
  - One full reviewer re-review (sonnet or opus, effort high).
  - One ladder attempt. At the top tier, that is a human stop avoided.
  - Possibly the next review's tier: `hooks/scripts/reviewer-tier.sh` reads the FAIL record.

  The fix round includes a full review, so the break-even refutation rate is low (estimated, unmeasured).
- **Measurement:** turned-around FAILs are durable (`grep -l 'NOTE\[code\]: refuted:' .claude/reviewed/*.pass`).
  Eligible runs that ended in FAIL anyway are not recorded durably (Open Question 4). Re-scoping the pass on
  that evidence is a follow-up.

### Prior FAIL history and audit sweep (dispositions)

- `.claude/reviewed/` holds 174 `.fail` records. 21 name `agents/reviewer.md`, and 27 cite a version-stamp /
  P3 defect, including `reviewer-changes-examples-lean-2`, `item17-1-clarify-p3-granularity` and
  `item17-3-wire-p3-check`. The disposition: rfp-u1's ordered edits bump the version and add the CHANGELOG
  entry in the **same commit** as the reviewer.md edit. Criterion 6 runs `version-stamp-check.sh` over every
  commit of the unit. The contract says that each fix-round commit touching `agents/` bumps again.
- `bin/marker-audit.sh --notes` over the touched surfaces:
  - `NOTE[spec]` blf-6: the prose says "FAIL count" where "FAIL-block count" is meant. *Disposition:* the
    new payload says "FAIL-block count", and the glossary's `_Avoid_` is honoured.
  - Untagged 124: "final message is ONLY the verdict" against the trailing STATUS line. *Disposition:*
    unaffected. The new `refutation` section is a third advisory section, placed after the verdict like the
    two existing ones.
  - Every other note is historical and touches no line this plan edits.
- No unit being re-scoped here has a prior `.fail`. Both units are new.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-27 Functional scope & success criteria: Q Are the orphan check (defect→fix, change→defect) and the
  Integrity rubric item in scope? → A (self-resolved): both are out of scope as named follow-ups. The
  "every change maps to a defect" half already exists at file granularity: on a fix round, the reviewer's
  scope rule admits only paths named in the `.fail` record or the fix contract (`agents/reviewer.md:62-63`).
  The rest needs `review-precheck.sh` work.
- 2026-10-27 Domain entities / data model: Q Which defects are refutable, and what are the per-defect
  states? → A (self-resolved): only judgment defects. The states are REFUTED, CONFIRMED and UNCERTAIN, each
  REFUTED or CONFIRMED needing an artifact. A missing, malformed or non-reproducing answer means the defect
  "stands as found".
- 2026-10-27 User interaction flow: Q Who dispatches the refuter, the orchestrator after the FAIL or the
  reviewer before it? → A (self-resolved): the reviewer, as a nested foreground unnamed `explorer` spawn
  (see the ADR draft). The orchestrator flow does not change.
- 2026-10-27 Non-functional attributes (perf, security, scale): Q When must the pass be skipped for cost,
  and on what model does it run? → A (self-resolved): the skip list and the not-skipped list are in the Cost
  model. The model is the explorer's frontmatter `haiku` (Open Question 3 for sonnet).
- 2026-10-27 Edge cases / failure handling: Q What happens to UNCERTAIN defects, to a truncated explorer,
  under review gating off and in the adapters? → A (self-resolved): UNCERTAIN-only becomes
  INSUFFICIENT-CONTEXT; mixed is Open Question 1. Truncated or malformed answers mean the defect stands.
  Under off the notes go in the advisory section. The ports keep today's behaviour.
- 2026-10-27 Technical constraints & tradeoffs: Q Does the pass change the 2-FAIL cap, the ladder count,
  the route gate or the markers? → A (self-resolved): no mechanism changes. A prevented FAIL writes no block,
  and a mixed FAIL writes one block as today.
- 2026-10-27 Terminology consistency: Q Is "refuter" a safe name? → A (self-resolved): no. It is not a
  persona, and `agents/reviewer.md:46` already uses "Refute" for attacking the *change*. The canonical term is
  **refutation pass**, with `refuter` on its `_Avoid_` line and pinned absent from the reviewer prose. Other
  new terms: **judgment defect**, **refutation outcome** (rfp-u2).
- 2026-10-27 Completion / acceptance signals: Q What machine-checkable signal shows the pass was built, and
  does it pay off? → A (self-resolved): "built" is shown by rfp-u1 criteria 1 to 7 and rfp-u2 criteria 1 to
  5. "Pays off" is measurable only on the PASS side today (Open Question 4).

## Risks / dependencies

- **R1: an over-eager refutation drops a real defect.** Mitigations: a REFUTED answer needs an artifact,
  which the reviewer re-checks itself, and the reviewer may not override a reproducing refutation by
  argument. A wrongly dropped defect is cheap to recover, because the next review, the milestone auditor or
  a downstream unit finds it again. That bias is intended.
- **R2: a haiku explorer refutes the findings of an opus or sonnet reviewer.** It is asked for evidence, not
  for a decision, and the decision stays with the reviewer through the artifact re-check. Open Question 3
  offers sonnet.
- **R3: the reviewer's turn budget (`maxTurns: 50`).** The pass costs about 2 to 6 turns and is capped at 5
  defects. A reviewer already near its cap could truncate. The terminal STATUS line makes that visible, and
  resuming it is the existing recovery.
- **R4: audit noise.** Each pass adds one `grant-denied hook=stop-gate identity=explorer` line while the
  flag stands. This already happens for every reviewer-to-explorer spawn. Out of scope; a follow-up could
  exempt read-only identities.
- **R5: dispatch order.** rfp-u2 (glossary and ADR) is dispatched only after rfp-u1 reaches PASS, so the
  glossary documents shipped behaviour. The branch `macos-compat-merge` has other units in flight, so
  rfp-u1's version bump is +1 on whatever version is current at dispatch.
- **R6: a parity seam.** rfp-u1 edits `agents/reviewer.md`, and its prose pins also read
  `.claude/agents/reviewer.md`. The mirror is regenerated by `node bin/cli.js --update` inside the same unit,
  so the source edit and its shipped copy are one gate (spec-master memory: never slice across a parity
  test).

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. A refutation needs a reproducing artifact. spec-master ran the
  route-gate case, its mutation, every prose-pin phrase against a scratch copy of the edited file, and the
  range-criterion shapes.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. `.claude/agents/*` is regenerated
  only by `node bin/cli.js --update`.
- P3 "Version-stamp discipline": satisfied. The bump and the CHANGELOG entry are in the same commit as the
  `agents/reviewer.md` change, per commit including fix rounds (criterion 6).
- P5 "`tests/validate.sh` is the merge gate": satisfied (rfp-u1 criterion 7, rfp-u2 criterion 5).
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. The pass names `explorer`, a core persona
  that is not in the optional list. It degrades to today's behaviour when no subagent can be spawned.

## Step 1 (rfp-u1, lead-programmer): the reviewer runs a refutation pass before any FAIL verdict

Affected files:
- `agents/reviewer.md`
- `tests/persona-prose-pins.test.sh`
- `tests/reviewer-route-gate-caller.test.sh`
- `.claude-plugin/plugin.json`
- `package.json`
- `CHANGELOG.md`
- generated by `node bin/cli.js --update`: `.claude/` mirrors

Acceptance criteria: rfp-u1 contract criteria 1 to 7 (prose pins counted, prose-pin and route-gate suites,
a line budget on the reviewer.md diff, a scope fence, `version-stamp-check.sh` per commit, `validate.sh`).
Each has a `mutation:` line.

## Step 2 (rfp-u2, scribe, after rfp-u1 PASS): glossary entries and ADR

Affected files:
- `CONTEXT.md` (three entries: **refutation pass**, **judgment defect**, **refutation outcome**)
- `docs/adr/<next>-refutation-pass-inside-reviewer-turn.md` (the ADR draft above)

Neither file is version-stamped, so no bump. Acceptance criteria: rfp-u2 contract criteria 1 to 5.

## Out of scope (named follow-ups)

1. **Orphan check** (every CONFIRMED defect maps to a fix commit, every changed hunk maps to a defect).
   This would be a `review-precheck.sh` fix-round extension. The file-granularity half already exists.
2. **Integrity rubric item** (hardcoded expected values, disabled or skipped tests, bypassed validation) for
   the reviewer or `roast-work`.
3. **Durable refutation telemetry on the FAIL side** (Open Question 4) and a kill or re-scope criterion
   based on it.
4. **Codex and cursor reviewer ports.** They have no verified spawn primitive and keep today's FAIL path.
5. **Exempting read-only identities from the stop gate's `grant-denied` audit line** (R4).
6. Any change to the orchestrator, the route or stop gates, `ladder-tier.sh`, `fail-count.sh`, task-master
   or the shared protocol's FAIL-record format.

## Open Questions

1. **The mixed case:** where do UNCERTAIN defects go when at least one defect is CONFIRMED or stands?
   *(Recommended, applied)* (a) They leave the fix list and go in the verdict's `refutation` advisory section,
   which the orchestrator sees. The next review re-checks the whole unit. (b) They stay in the FAIL defect
   list, as today. This is safer, but the lead-programmer may fix non-defects. (c) They stay in the list
   with an `[unconfirmed]` tag. Task-master and the lead-programmer would then need a rule for the tag.
   *(from CHK7)*
2. **Mechanical grounds present:** skip the pass entirely? *(Recommended, applied)* (a) Skip. The ladder
   attempt is spent anyway, and the next review re-checks everything. (b) Still refute the judgment
   defects. This spares the lead-programmer needless fixes, at one explorer run per such FAIL. *(from CHK8)*
3. **Explorer tier:** *(Recommended, applied)* (a) the frontmatter `haiku`, because the reviewer re-checks
   every artifact itself. (b) `model: sonnet` on the spawn, which roughly multiplies the pass's cost for
   better recall on subtle mitigations. (c) Match the reviewer's own tier. *(from CHK9)*
4. **FAIL-side telemetry:** *(Recommended, applied)* (a) Defer it. The value metric (turned-around FAILs)
   is durable in `.pass` notes. (b) Add a `refutation: confirmed=<a> refuted=<b> uncertain=<c>` line to each
   FAIL block now. That is a FAIL-record format change touching `templates/persona-protocol.md`, the cursor
   `.mdc` port, `tests/adapter-fail-tier-pin.test.js` and task-master's fix-contract copy rule, roughly 3
   more files and a third unit. *(from CHK10)*

## Self-check
- CHK1: Is the verdict defined for every combination of standing, CONFIRMED and UNCERTAIN defects? — PASS
  (decision table in Context; rfp-u1 edit 4 payload)
- CHK2: Is the outcome defined when the explorer is truncated, gives no line, or cites an artifact that does
  not reproduce? — PASS ("stands as found")
- CHK3: Do the payload and the Goal agree that a mixed FAIL still writes exactly one FAIL block and a
  prevented FAIL writes none? — PASS
- CHK4: Is the behaviour under `reviewGating.mode: off` defined, including where the `refuted:` notes go? —
  FAIL (missing) — revised in place (the payload now ends its PASS sentence with "under review gating off,
  in the `refutation` section instead", pinned as phrase 11)
- CHK5: Does every rfp-u1 and rfp-u2 criterion have a runnable `run:`, an expected stdout and a `mutation:`
  line? — PASS
- CHK6: Is the P3 bump required in every commit that touches `agents/`, fix rounds included, not once per
  unit? — FAIL (missing) — revised in place (rfp-u1 Escalation and edit 9 note; criterion 6 runs per commit)
- CHK7: Is the mixed-case handling of UNCERTAIN defects settled? — FAIL (missing) — converted to Open
  Question 1
- CHK8: Is it settled whether the pass runs when a mechanical ground is also present? — FAIL (ambiguous) —
  converted to Open Question 2
- CHK9: Is the subagent's model tier settled against its cost? — FAIL (missing) — converted to Open
  Question 3
- CHK10: Is there a machine-checkable measure of whether the pass pays for itself? — FAIL (missing) —
  converted to Open Question 4
- CHK11: Do Step 2's glossary terms match the terms Step 1's payload uses? — PASS ("refutation pass" and
  "judgment defect" appear verbatim in the payload; "refutation outcome" names its REFUTED, CONFIRMED and
  UNCERTAIN answers)
- CHK12: Could a range criterion pass vacuously when no `(rfp-u1)` commit exists? — FAIL (ambiguous) —
  revised in place (criteria 4 to 6 print `no-commits` and exit 1 on an empty range)
- CHK13: Does each Goal clause map to a criterion? — PASS. Disprove before the lead-programmer: crit 1.
  Whole file and callers: crit 1, pin 5. No marker and no stamp: crit 3. Ladder unchanged: crit 1, pin 12.
  Mechanical never re-checked: crit 1, pin 2. Cost bounded: crit 1, pin 3, and crit 4.
- CHK14: Does criterion rfp-u1/7 (`tests/validate.sh`) still fail under its own `mutation:` line, given that
  gh317, gh320, gh346-2, gh409, gh413, human-review-cleanup-1, mw-step1-3, rollout-map-1 and
  spec2-unitA/B recorded class vacuous or host? — PASS (the mutation puts `exit 1` on line 2 of
  `tests/persona-prose-pins.test.sh`, which validate.sh:1571 runs)
- CHK15: Does criterion rfp-u1/4 (reviewer.md numstat) still fail under its own `mutation:` line, given that
  gh307, gh348-3, gh385-2, memdirt-1 and mw-step1-3 recorded class vacuous or host? — PASS (pasting the
  payload twice prints `over`)
- CHK16: Does criterion rfp-u1/6 (`version-stamp-check.sh`) still fail under its own `mutation:` line, given
  that ci-fetch-depth-cleanup and item17-4-name-p3-offenders recorded class host? — PASS (skipping edit 5
  prints `violation`)
- CHK17: Do criteria rfp-u2/1-3 (`CONTEXT.md`) still fail under their own `mutation:` lines, given that
  gh-303, gh339, gh409, human-review-cleanup-1 and spec2-unitA/B recorded class vacuous or host? — PASS
  (they are claim-anchored phrase greps, each with a deletion mutation)

Prose-mode `ubiquitous-language` on this draft (advisory): lens 1 found "Refute" at `agents/reviewer.md:46`,
which means attacking the change, against the new "refutation pass", which means attacking the reviewer's
own defects. This is handled by a separate canonical term and its `_Avoid_` line. Lens 2 found "refuter" and
"verifier" as synonyms for the pass, so both are avoided and "refuter" is pinned absent. Lens 3 found three
new terms (Step 2). "FAIL-block count" is used per its glossary entry.

## Scribe update hint

rfp-u2 is the scribe's unit: three `CONTEXT.md` entries (text pre-drafted in its contract) and the ADR
above, numbered as the next free `docs/adr/` number. After rfp-u1 PASS, quote its PASS verdict line in the
scribe dispatch.
