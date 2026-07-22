# Spec: Correct the subagent self-wake fallacy for backgrounded acceptance-criteria commands

Source: GitHub issue #89 — "Subagents falsely assume a self-wake mechanism
for their own backgrounded Bash tasks, causing silent idle stalls."

Revision (2026-07-21): task-master routed back a spec gap before slicing —
the original draft wrongly declared no `.claude/constitution.md` existed and
targeted the four `.claude/…` mirror files for hand-editing. Corrected here:
Steps 1-4 now edit the SOURCE files and regenerate mirrors via
`node bin/cli.js --update` (constitution P2); new Step 5 adds the mandatory
version bump + CHANGELOG + merge gate (constitution P3/P5). The 4-step
protocol-wording design is otherwise unchanged.

## Goal

Stop personas (lead-programmer, reviewer, and any persona that runs an
acceptance-criteria command) from backgrounding a slow test/build/lint run and
ending their turn on the false belief that they will be autonomously woken when
it finishes. Make the shared protocol state the truth explicitly, prescribe the
correct synchronous-foreground default, define the only legitimate escalation
path (the existing WIP sentinel with mandated wording), and give dispatchers
explicit guidance to distrust "I set up a background watcher" claims and
proactively verify + resume.

This is a documentation/protocol change only. No application code, no new hook,
no new file format.

## Context

- The failure mode (issue #89): a subagent runs an acceptance-criteria command
  with `run_in_background: true`, ends its turn asserting it will be
  "notified"/"poll again shortly," and then goes fully dormant at `SubagentStop`
  until the dispatcher manually resumes it — even after the process has long
  since finished. Reproduced twice in one session (lead-programmer on an impl
  unit, reviewer on the verdict) against a ~9-10 min integration suite.
- Why the belief is false: only a *dispatching* session's own `Agent`-tool
  calls receive an autonomous `task-notification` when the dispatched
  subagent's turn ends. A subagent's own nested background `Bash` job has no
  equivalent — nothing wakes the subagent when that shell job exits.
- Existing mechanisms this plan reuses (does NOT replace):
  - The WIP sentinel (`.claude/persona-protocol.md` "WIP sentinel" section):
    write a non-empty reason into `.claude/wip-handoff.<agent-id>`, honored for
    exactly one turn-end, logged to `.claude/wip-audit.log`. This is already the
    designed "end my turn with work in progress" exit.
  - The orchestrator's "Managing a long-running background dispatch" section
    (`.claude/agents/orchestrator.md`, ~line 315): covers polling a dispatched
    *Agent-tool task*'s liveness via `TaskOutput`. This plan extends that
    section with the distinct nested-background-Bash case rather than
    duplicating it.
- Confirmed facts from exploration:
  - Bash tool `timeout` ceiling is 600000 ms (10 min); default 120000 ms.
  - No hook currently references `run_in_background` — enforcement here is by
    instruction only, consistent with the issue framing this as docs-only.
  - Issue tracker: GitHub issues (repo Storreslara/AntiSlop, `gh` CLI). Triage
    label `ready-for-agent` already exists.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-07-21 Functional scope & success criteria: Q Should acceptance be a
  grep-based machine-checkable check or review-only? → A (self-resolved): both —
  each step carries a runnable `grep -q` anchor check (satisfying the protocol's
  own Machine-checkable-criteria rule, which I am editing and must not violate)
  PLUS a review-only editorial check for correctness/placement. A grep anchor
  alone is tautological; pairing it with editorial review is the groundable
  best-of-both.
- 2026-07-21 Domain entities / data model: Q Does the WIP-sentinel escalation
  need a new file format or does it reuse `.claude/wip-handoff.<agent-id>`? → A
  (self-resolved): reuse the existing sentinel unchanged. It already requires a
  non-empty reason, is honored once, and is audit-logged — exactly what is
  needed. The only new requirement is the *wording* of the reason string. A new
  format would be redundant surface area.
- 2026-07-21 Completion / acceptance signals: Q grep-based vs review-only
  acceptance? → A (self-resolved): see the Functional-scope line above — both.
- 2026-07-21 Edge cases / failure handling: Q Is the ban on all subagent
  `run_in_background` use, or only acceptance-criteria commands? → A
  (self-resolved): only acceptance-criteria commands (test/build/lint gating a
  verdict or a ready-for-review). The broader "no self-wake for any nested
  background Bash job" fact is stated as context so personas generalize
  correctly, but the hard ban is scoped to acceptance-criteria commands per the
  issue's framing.
- 2026-07-21 Edge cases / failure handling: Q What about a command that
  genuinely exceeds the 600000 ms ceiling? → A (self-resolved): that is the sole
  case where ending the turn is allowed — via the WIP sentinel with the mandated
  "no autonomous wake-up available — requires the dispatcher to resume me later"
  wording, never language implying self-notification.
- 2026-07-21 User interaction flow: Q Do lead-programmer.md / reviewer.md need
  their own copies of the rule? → A (self-resolved): no — the rule lives once in
  persona-protocol.md; both personas get a one-line cross-reference pointer at
  their existing acceptance-criteria-running guidance so they never drift from
  the shared rule.
- 2026-07-21 Technical constraints & tradeoffs: Q Are the four affected files
  hand-editable, or are they script-regenerated mirrors? → A (task-master
  gap-relay, corrected): all four (`.claude/persona-protocol.md`,
  `.claude/agents/{orchestrator,reviewer,lead-programmer}.md`) are
  `fileHashes`-tracked mirrors regenerated by `node bin/cli.js --update` from
  sources `templates/persona-protocol.md` and `agents/{orchestrator,reviewer,
  lead-programmer}.md`. The original draft's "no constitution exists" claim
  was factually wrong; constitution P2 requires editing the SOURCE and
  regenerating. Steps 1-4 re-targeted accordingly (precedent: issue #87).
- 2026-07-21 External dependencies & integrations: Q Does editing these
  version-stamped files require a version bump? → A (task-master gap-relay,
  corrected): yes — constitution P3 requires bumping
  `.claude-plugin/plugin.json` (and, per merge-gate commit `e0080d9`,
  `package.json` in sync) plus a CHANGELOG entry. Added as Step 5
  (0.13.8 → 0.13.9). The original draft had no such step.

## Risks / dependencies

- Drift risk: if the rule is duplicated into lead-programmer.md / reviewer.md
  verbatim, the three copies diverge over time. Mitigated by keeping the
  normative text solely in persona-protocol.md and using pointers elsewhere.
- Over-broad ban risk: banning *all* `run_in_background` for subagents would
  break legitimate uses (e.g. a genuinely fire-and-forget task the subagent
  does not depend on). Mitigated by scoping the ban to acceptance-criteria
  commands only.
- Reconciliation risk: adding dispatcher guidance as a new orchestrator section
  would duplicate the existing "Managing a long-running background dispatch"
  section and create two overlapping playbooks. Mitigated by extending that
  section in place.
- **Mirror hand-edit risk (constitution P2).** All four targets are
  `fileHashes`-tracked mirrors regenerated by `node bin/cli.js --update`. A
  hand-edit of any `.claude/…` mirror is silently overwritten back to the
  unfixed source content on the next `--update`, so the fix would vanish
  unnoticed. Mitigated by editing SOURCE files only (Steps 1-4) and pairing
  each grep anchor on both source and regenerated mirror to confirm
  propagation. This was the exact gap task-master relayed back.
- **Version-stamp risk (constitution P3).** Editing version-stamped
  `agents/*.md` / `templates/*` without a version bump breaks the `--update`
  mechanism (which depends on the version changing when content does) and
  fails the `e0080d9` merge-gate sync check. Mitigated by Step 5 (mandatory,
  gated on `tests/validate.sh`).
- **Step-ordering dependency.** Step 5's version bump must land after Steps
  1-4's source edits + regenerations, so it records a real content change.
- No prior `.claude/reviewed/*.fail` record exists for this work (fresh spec);
  no elevated-judgment flag carried in.

## Constitution check (.claude/constitution.md v1.0.0)

Correction (2026-07-21): the original draft wrongly declared no constitution
existed. `.claude/constitution.md` is git-tracked (added in `2aaead4`,
ratified 2026-07-14). All four affected files are mechanically-regenerated
mirrors, which triggers P2 and P3 directly; this section and the steps below
are revised to comply.

- P1 "Verify, don't assume": satisfied — every acceptance criterion is a
  runnable `grep`/exit-code check the implementer and reviewer must actually
  run; the source→mirror propagation is checked by pairing grep anchors on
  BOTH the source and the regenerated mirror, and the merge gate runs
  `bash tests/validate.sh` rather than eyeballing.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied (was
  the original defect). The four edit targets —
  `.claude/persona-protocol.md`, `.claude/agents/orchestrator.md`,
  `.claude/agents/reviewer.md`, `.claude/agents/lead-programmer.md` — are
  `fileHashes`-tracked mirrors in `.claude/persona-config.json`, regenerated
  from their sources (`templates/persona-protocol.md`, `agents/orchestrator.md`,
  `agents/reviewer.md`, `agents/lead-programmer.md`) by `node bin/cli.js
  --update`. Steps 1-4 now edit the SOURCE and regenerate via `--update`;
  no mirror is hand-edited. Precedent: issue #87
  (`docs/plans/2026-07-17-suggested-model-tier-routing-consistency.md`).
- P3 "Version-stamp discipline": satisfied by Step 5 — editing
  version-stamped `agents/*.md` and `templates/*` mandates bumping
  `.claude-plugin/plugin.json` (and, per merge-gate commit `e0080d9`,
  `package.json` in sync) and adding a CHANGELOG entry. Current version
  0.13.8 → 0.13.9.
- P4 "Optional personas degrade gracefully": satisfied — the added text is a
  role-agnostic protocol rule plus two persona cross-reference pointers; it
  introduces no new unconditional optional-persona reference.
- P5 "`tests/validate.sh` is the merge gate": satisfied — Step 5 gates on a
  green `bash tests/validate.sh`.

## Steps

### Step 1 — Add the shared-protocol rule to `templates/persona-protocol.md` (source)

Add one new top-level section (role-agnostic, consistent with the file's
"role-agnostic content only" header constraint). Suggested placement:
immediately after the existing "WIP sentinel" section (it is the natural
companion — the escalation path reuses that sentinel). Suggested heading:
`## Running acceptance-criteria commands (there is no self-wake)`.

The section must state, in the protocol's existing voice:
1. The rule: run acceptance-criteria commands (test suites, build/lint checks)
   **synchronously in the foreground** via the `Bash` tool's `timeout`
   parameter set as high as needed, up to its **600000 ms (10 min) ceiling** —
   do **not** background them with `run_in_background: true` and end the turn
   assuming self-notification. Scope the hard ban explicitly to
   acceptance-criteria commands.
2. The reason (the truth that corrects the fallacy): only a *dispatching*
   session's own `Agent`-tool calls get an autonomous wake-up when a subagent's
   turn ends; a subagent's own nested background `Bash` job has **no** such
   mechanism and the subagent goes dormant at `SubagentStop` until the
   dispatcher explicitly resumes it.
3. The single escalation path: if a command genuinely cannot finish within the
   600000 ms ceiling, the only legitimate way to end the turn is the existing
   WIP sentinel (`.claude/wip-handoff.<agent-id>`), and its reason string must
   plainly state that there is **no autonomous wake-up available — requires the
   dispatcher to resume me later**. Personas must never use language implying
   they will "get notified" or "poll again shortly" on their own. Cross-
   reference the "WIP sentinel" section rather than re-describing its mechanics.

Affected files: `templates/persona-protocol.md` (SOURCE — add one `## `
section; no existing text removed or reordered). The mirror
`.claude/persona-protocol.md` is regenerated, not hand-edited.

Regeneration (constitution P2): after editing the source, run
`node bin/cli.js --update` to regenerate the `fileHashes`-tracked mirror
`.claude/persona-protocol.md`. Do NOT hand-edit the mirror — a hand-edit is
silently overwritten by the next `--update`.

Acceptance criteria (all runnable from repo root; each anchor is checked on
BOTH the source and the regenerated mirror, so the criterion confirms
propagation, not just the source edit):
- `grep -q "there is no self-wake" templates/persona-protocol.md && grep -q "there is no self-wake" .claude/persona-protocol.md` exits 0 (new section heading anchor, source + mirror).
- `grep -q "no autonomous wake-up available" templates/persona-protocol.md && grep -q "no autonomous wake-up available" .claude/persona-protocol.md` exits 0 (mandated WIP-sentinel wording anchor, source + mirror).
- `grep -q "600000" templates/persona-protocol.md && grep -q "600000" .claude/persona-protocol.md` exits 0 (synchronous-timeout ceiling, source + mirror).
- `grep -qi "run_in_background" templates/persona-protocol.md && grep -qi "run_in_background" .claude/persona-protocol.md` exits 0 (banned pattern named explicitly, source + mirror).
- `node bin/cli.js --update` re-run reports no pending drift for
  `.claude/persona-protocol.md` (fileHashes in sync — verify per P1, don't
  assume the mirror matches).
- Review-only editorial check: the new section names the acceptance-criteria-
  command scope for the ban, states the dispatcher-only-wake-up reason, and
  cross-references (does not duplicate) the WIP sentinel section; heading is a
  new top-level `## ` consistent with surrounding style.

### Step 2 — Extend the orchestrator's background-dispatch section with the nested-Bash / false-watcher case

In `agents/orchestrator.md` (SOURCE), extend the existing
`## Managing a long-running background dispatch` section (do not add a second
section; reconcile in place). Add dispatcher-side guidance for the distinct
case the existing text does not cover: a subagent that ended its turn claiming
it "set up a background watcher" / will self-notify for its **own** nested
background `Bash` job.

The added guidance must state:
1. Such a self-wake claim is false and must not be trusted at face value — the
   subagent will not resume on its own.
2. The dispatcher should independently verify the backgrounded command's real
   state (e.g. `ps`, git/file state) rather than passively waiting.
3. If the command has plausibly already finished, the dispatcher should
   proactively resume the subagent (via `SendMessage` by name, consistent with
   the existing resume guidance) so it checks its own result and continues.

Keep it distinct from — and cross-referencing, not duplicating — the existing
`TaskOutput`/`TaskStop` liveness-poll guidance (which is about a dispatched
Agent-tool task, not a subagent's nested Bash job).

Affected files: `agents/orchestrator.md` (SOURCE — extend one existing
section). The mirror `.claude/agents/orchestrator.md` is regenerated, not
hand-edited.

Regeneration (constitution P2): after editing the source, run
`node bin/cli.js --update` to regenerate the `fileHashes`-tracked mirror
`.claude/agents/orchestrator.md`. Do NOT hand-edit the mirror.

Acceptance criteria (each anchor checked on BOTH source and regenerated
mirror):
- `grep -q "background watcher" agents/orchestrator.md && grep -q "background watcher" .claude/agents/orchestrator.md` exits 0 (false-claim guidance anchor, source + mirror).
- `grep -q "independently verify" agents/orchestrator.md && grep -q "independently verify" .claude/agents/orchestrator.md` exits 0 (independent-verification anchor, source + mirror — use this literal string so the anchor is stable).
- `node bin/cli.js --update` re-run reports no pending drift for
  `.claude/agents/orchestrator.md` (fileHashes in sync — verify, don't assume).
- Review-only editorial check: the new guidance lives inside the existing
  `## Managing a long-running background dispatch` section (no duplicate
  section added), covers all three points (distrust the self-wake claim,
  verify via ps/git state, proactively resume via SendMessage), and is
  visibly distinguished from the existing TaskOutput/TaskStop poll guidance.

### Step 3 — Add a cross-reference pointer in `agents/reviewer.md` (source)

At the reviewer's existing "Run the checks yourself" guidance, add a one-line
pointer to the new shared-protocol rule: run the acceptance-criteria command
synchronously in the foreground with a high `timeout`, never backgrounded with
an assumed self-wake. Do not restate the full rule — point to
persona-protocol.md.

Affected files: `agents/reviewer.md` (SOURCE — one added pointer line/clause).
The mirror `.claude/agents/reviewer.md` is regenerated, not hand-edited.

Regeneration (constitution P2): after editing the source, run
`node bin/cli.js --update` to regenerate the `fileHashes`-tracked mirror
`.claude/agents/reviewer.md`. Do NOT hand-edit the mirror.

Acceptance criteria (checked on BOTH source and regenerated mirror):
- `grep -qi "synchronous\|foreground\|no self-wake\|self-wake" agents/reviewer.md && grep -qi "synchronous\|foreground\|no self-wake\|self-wake" .claude/agents/reviewer.md`
  exits 0 (pointer present, source + mirror).
- `node bin/cli.js --update` re-run reports no pending drift for
  `.claude/agents/reviewer.md` (fileHashes in sync — verify, don't assume).
- Review-only editorial check: the addition is a pointer to the
  persona-protocol rule (not a duplicated copy of it) and is attached to the
  existing acceptance-criteria-running guidance.

### Step 4 — Add a cross-reference pointer in `agents/lead-programmer.md` (source)

At the lead-programmer's existing acceptance-criteria / ready-for-review
guidance, add the same one-line pointer to the new shared-protocol rule. Same
pointer-not-copy discipline as Step 3.

Affected files: `agents/lead-programmer.md` (SOURCE — one added pointer
line/clause). The mirror `.claude/agents/lead-programmer.md` is regenerated,
not hand-edited.

Regeneration (constitution P2): after editing the source, run
`node bin/cli.js --update` to regenerate the `fileHashes`-tracked mirror
`.claude/agents/lead-programmer.md`. Do NOT hand-edit the mirror.

Acceptance criteria (checked on BOTH source and regenerated mirror):
- `grep -qi "synchronous\|foreground\|no self-wake\|self-wake" agents/lead-programmer.md && grep -qi "synchronous\|foreground\|no self-wake\|self-wake" .claude/agents/lead-programmer.md`
  exits 0 (pointer present, source + mirror).
- `node bin/cli.js --update` re-run reports no pending drift for
  `.claude/agents/lead-programmer.md` (fileHashes in sync — verify, don't assume).
- Review-only editorial check: the addition is a pointer to the
  persona-protocol rule (not a duplicated copy) attached to the existing
  ready-for-review / acceptance-criteria guidance.

### Step 5 — Version-stamp + merge gate (constitution P3 and P5, MANDATORY)

Depends on Steps 1-4 all landing first (the version bump records that the
version-stamped sources actually changed; do this once, after all four source
edits and their `--update` regenerations are in place).

Affected files: `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`.
- Check the current version first (do not assume): it is `0.13.8` at drafting
  time. Bump `.claude-plugin/plugin.json` `"version"` from `0.13.8` to
  `0.13.9`.
- Bump `package.json` `"version"` to the SAME `0.13.9` — the merge-gate check
  added in commit `e0080d9` requires `.claude-plugin/plugin.json` and
  `package.json` versions to stay in sync.
- Add a `CHANGELOG.md` entry for `0.13.9` describing the "no self-wake for a
  subagent's own backgrounded acceptance-criteria command" protocol fix and
  citing "Fixes #89".

Acceptance criteria:
- `grep -q '"version": "0.13.9"' .claude-plugin/plugin.json` exits 0.
- `grep -q '"version": "0.13.9"' package.json` exits 0.
- The two versions match:
  `test "$(node -p "require('./.claude-plugin/plugin.json').version")" = "$(node -p "require('./package.json').version")"` exits 0.
- `grep -q '0.13.9' CHANGELOG.md` exits 0.
- `grep -q '#89' CHANGELOG.md` exits 0.
- `python3 -m json.tool .claude-plugin/plugin.json >/dev/null && python3 -m json.tool package.json >/dev/null` exits 0 (both JSON files remain valid).
- Merge gate: `bash tests/validate.sh; echo "exit=$?"` → `exit=0` (includes the
  package.json/plugin.json version-sync check from `e0080d9`).

## Open Questions

None. Every Partial taxonomy category was resolved with a default grounded in
the existing protocol text or the issue itself (see Clarifications), including
the two categories (5, 7) re-scored to Partial and resolved by the task-master
gap relay (source/mirror regeneration + version-stamp). If the maintainer
disagrees with any self-resolved default — most likely the grep-anchor
acceptance style (Steps 1-4) or the exact new section heading wording — that
is a review-time editorial adjustment, not a blocking unknown.

## Self-check

- CHK1: Is the ban's scope (acceptance-criteria commands vs all backgrounding)
  defined unambiguously? — PASS
- CHK2: Is the sole legitimate turn-end escalation path defined, including the
  exact mandated wording? — PASS
- CHK3: Do Steps 1 and 3-4 agree that the normative rule lives only in
  persona-protocol.md and the personas only point to it? — PASS
- CHK4: Does each step carry at least one runnable (grep) acceptance check, per
  the protocol's own Machine-checkable-criteria rule? — PASS
- CHK5: Is the synchronous-timeout ceiling stated as a concrete, verifiable
  value (600000 ms) rather than "as high as needed" alone? — PASS
- CHK6: Does Step 2 avoid creating a duplicate orchestrator section and instead
  reconcile with the existing one? — PASS (extends in place; review check
  enforces it)
- CHK7: Is the ">10 min command" edge case handled? — PASS (WIP-sentinel path,
  Step 1 point 3)
- CHK8: Are the grep anchor strings in the acceptance criteria the same literal
  strings the step body instructs the implementer to write? — PASS ("there is
  no self-wake", "no autonomous wake-up available", "600000", "run_in_background",
  "background watcher" all appear in both the step prose and its checks)
- CHK9: Do Steps 1-4 edit the SOURCE files (not the `.claude/…` mirrors), per
  constitution P2? — PASS (all four re-targeted to `templates/…` / `agents/…`;
  each carries a `node bin/cli.js --update` regeneration instruction and a
  no-hand-edit-the-mirror clause)
- CHK10: Does each of Steps 1-4 confirm source→mirror PROPAGATION, not just the
  source edit? — PASS (every functional grep anchor is checked on both the
  source and the regenerated mirror, plus a `--update` no-drift check)
- CHK11: Is the constitution P3 version bump covered, including package.json/
  plugin.json sync per `e0080d9`? — PASS (Step 5 bumps both to 0.13.9, adds a
  CHANGELOG entry, asserts version equality, and gates on `tests/validate.sh`)
- CHK12: Does the Constitution check section correctly state the constitution
  EXISTS and that P2/P3 apply (correcting the original "no constitution" claim)?
  — PASS (section rewritten; correction note dated 2026-07-21)
- CHK13: Is Step 5's dependency on Steps 1-4 landing first stated? — PASS (Step
  5 header "Depends on Steps 1-4 all landing first"; Risks step-ordering bullet)
- CHK14: Is the current version verified rather than assumed (0.13.8 → 0.13.9)?
  — PASS (checked `.claude-plugin/plugin.json` and `package.json`, both 0.13.8;
  Step 5 also instructs re-checking before bumping)

## Scribe update hint

This changes cross-cutting persona behavior (how every persona runs
acceptance-criteria commands and how the orchestrator supervises long-running
work). If a wiki/CONTEXT page documents the persona protocol or the
orchestrator's supervision duties, add the "no self-wake for a subagent's own
nested background Bash job" rule and the WIP-sentinel escalation wording. No
ADR needed (behavioral clarification, not an architectural decision); the
Step 5 `CHANGELOG.md` entry (0.13.9) is the sufficient institutional record.

---

## Follow-up (2026-07-21): advisory roast-work robustness gaps

Append-only follow-up. Steps 1-5 shipped, committed, and reviewer-PASSed
(#90-#94); their goal and scope were confirmed correct by the maintainer at
the milestone pre-audit checkpoint. This is **not** a re-plan. An advisory
`roast-work` pass during review flagged three residual gaps, all inside the
single paragraph Step 2 (#91, commit 87c8842) added to the
`## Managing a long-running background dispatch` section of
`agents/orchestrator.md`. The maintainer asked to fix them now rather than
defer. No taxonomy grill was re-run for the #89 project as a whole — the
problem statement below was handed over pre-agreed; the compact scorecard
that follows is scored against the follow-up delta only, not the whole
project.

Steps 1, 3, 4, and 5's already-shipped content is out of scope and must not
be reopened. This follow-up touches only `agents/orchestrator.md` (SOURCE)
plus the mandatory P3 version bump.

### The three gaps (all in the Step-2 paragraph, `agents/orchestrator.md`)

1. **Trigger-wording mismatch.** Step 2's guidance keys narrowly on detecting
   a subagent's FALSE claim of having "set up a background watcher" (the exact
   phrase #91's acceptance criteria required, because Step 1 was designed to
   eliminate that specific false claim going forward). But once Step 1's fix
   takes hold, a compliant subagent instead ends its turn honestly via the WIP
   sentinel with Step 1's mandated wording ("no autonomous wake-up available —
   requires the dispatcher to resume me later"). The dispatcher still owes the
   same verify-then-resume response in that corrected case, yet the current
   text does not say so — it only names the legacy false-watcher symptom. The
   trigger must explicitly cover BOTH: (a) the legacy false self-wake claim
   (keep detecting it — an un-migrated persona or old habit may still say it),
   and (b) the Step-1-compliant WIP-sentinel path with the mandated wording.
   Both require the identical dispatcher response.
2. **Missing "still running" inverse branch.** The current text states only
   "if the command has plausibly already finished, proactively resume." It is
   silent on the inverse, which reads as "resume regardless of real state."
   Add the symmetric branch: if independent verification shows the command is
   still genuinely running, do **not** resume prematurely — re-check later.
3. **`ps` process-namespace assumption.** The "verify via `ps`" suggestion
   silently assumes the dispatcher and the subagent's nested `Bash` process
   share a process namespace. That holds for default local dispatch but not
   necessarily for `isolation: "worktree"`/`"remote"` `Agent` dispatch or
   other sandboxed execution. Add a caveat: `ps` is a valid signal only when
   dispatcher and subagent share a process namespace; git/file state is the
   primary/fallback signal otherwise (not merely an alternative "or").

### Clarifications (follow-up delta only)

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-21 Functional scope & success criteria: Q Is this a re-plan or an
  append-only follow-up? → A (self-resolved): append-only follow-up; goal and
  scope of Steps 1-5 confirmed correct by the maintainer, only the three named
  Step-2-paragraph gaps are in scope.
- 2026-07-21 Edge cases / failure handling: Q Must the legacy false-watcher
  detection be kept, or replaced by the WIP-sentinel trigger? → A
  (self-resolved): kept AND broadened — the trigger must list both (a) the
  legacy false claim and (b) the compliant WIP-sentinel path, per the handed
  problem statement.
- 2026-07-21 Technical constraints & tradeoffs: Q Does editing
  `agents/orchestrator.md` require a version bump per constitution P3, or can
  it fold under a note? → A (self-resolved): version bump required; see the
  Constitution check below — P3 admits no size-based "fold under a note"
  exemption.
- 2026-07-21 External dependencies & integrations: Q Current version to bump
  from? → A (self-resolved): verified `0.13.9` in both
  `.claude-plugin/plugin.json` and `package.json` → bump to `0.13.10`.
- 2026-07-21 Terminology consistency: Q Which literal wording anchors the new
  content to Step 1's rule? → A (self-resolved): Step 1's mandated string "no
  autonomous wake-up available" — reused verbatim so the orchestrator
  guidance and the persona-protocol rule stay lexically tied.

### Risks / dependencies (follow-up)

- **Regression risk.** The three gaps live inside the paragraph Step 2
  shipped; a rewrite could drop the #91 acceptance anchors ("background
  watcher", "independently verify"). Mitigated: Step 6's acceptance criteria
  re-assert both anchors on source AND mirror as regression guards, so #91's
  own criteria still pass after the edit.
- **Mirror hand-edit risk (constitution P2).** `.claude/agents/orchestrator.md`
  is a `fileHashes`-tracked mirror; hand-editing it is silently reverted on
  the next `--update`. Mitigated: Step 6 edits SOURCE only and regenerates via
  `node bin/cli.js --update`, pairing each grep anchor on source + mirror.
- **Version-stamp risk (constitution P3).** Editing version-stamped
  `agents/orchestrator.md` without a bump breaks `--update` and fails the
  `e0080d9` merge-gate sync check. Mitigated: Step 7 (mandatory).
- **Step-ordering dependency.** Step 7's bump must land after Step 6 so it
  records a real content change.
- No `.claude/reviewed/*.fail` record exists for this follow-up work (the
  underlying units #90-#94 all PASSed); no elevated-judgment flag carried in.

### Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every acceptance criterion is a
  runnable `grep`/exit-code check on both source and regenerated mirror; the
  merge gate runs `bash tests/validate.sh`; the current version was read from
  disk (0.13.9), not assumed.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step 6
  edits the SOURCE `agents/orchestrator.md` and regenerates the
  `fileHashes`-tracked mirror `.claude/agents/orchestrator.md` via
  `node bin/cli.js --update`; no mirror is hand-edited.
- P3 "Version-stamp discipline": **satisfied via Step 7 — and the version bump
  IS required, not optional.** Reasoning (the maintainer asked me to state
  this rather than assume): P3 reads "Any change to a version-stamped file
  (`agents/*.md`, templates) must bump `.claude-plugin/plugin.json`'s version
  and add a CHANGELOG entry." `agents/orchestrator.md` matches `agents/*.md`
  exactly, and P3 sets no size threshold and grants no "fold a small change
  under a note" exemption — the "note instead of a bump" option floated in the
  task framing has no basis in the constitution's actual text. The `--update`
  mechanism further depends on the version changing when content does, so
  skipping the bump would also risk mirror-regeneration drift. Therefore
  Step 7 bumps 0.13.9 → 0.13.10 and adds a CHANGELOG entry. (Patch-level bump
  chosen: this is a small behavioral clarification within an existing section,
  consistent with the 0.13.x patch cadence used for #90-#94.)
- P4 "Optional personas degrade gracefully": satisfied — the added text is
  role-agnostic dispatcher guidance and introduces no new unconditional
  optional-persona reference.
- P5 "`tests/validate.sh` is the merge gate": satisfied — Step 7 gates on a
  green `bash tests/validate.sh`.

### Step 6 — Broaden and harden the Step-2 nested-Bash dispatcher guidance (`agents/orchestrator.md` source)

In `agents/orchestrator.md` (SOURCE), edit the existing paragraph beginning
"**A distinct case: a subagent's own nested background Bash job.**" inside the
`## Managing a long-running background dispatch` section. Do NOT add a new
section and do NOT touch any other section. The revised paragraph must:

1. **Broaden the trigger (gap 1)** to explicitly name BOTH cases as requiring
   the same dispatcher response (verify real state, resume only when
   appropriate):
   - (a) the legacy symptom — a subagent falsely claiming it "set up a
     background watcher" / will self-notify (keep this detection; an
     un-migrated persona or old habit may still emit it), AND
   - (b) the Step-1-compliant path — a subagent that correctly ended its turn
     via the WIP sentinel with the mandated "no autonomous wake-up available"
     wording for a command exceeding the 600000 ms ceiling. In this case the
     subagent did the right thing; the dispatcher still owes the verify-then-
     resume-when-done response because the WIP sentinel's own design is that
     the dispatcher resumes it later.
2. **Add the "still running" inverse branch (gap 2).** Alongside the existing
   "if plausibly finished, resume" guidance, state the symmetric case: if
   independent verification shows the command is still genuinely running, do
   NOT resume prematurely — re-check later. The two branches together must
   make clear the resume decision follows the command's real state, not a
   blanket "resume regardless."
3. **Add the `ps` process-namespace caveat (gap 3).** Qualify the `ps`
   suggestion: `ps` is a valid signal only when the dispatcher and the
   subagent's nested `Bash` process share a process namespace (true for
   default local dispatch, not necessarily for `isolation: "worktree"` /
   `"remote"` `Agent` dispatch or other sandboxed execution); git/file state
   is the primary/fallback signal otherwise, not merely an alternative "or."

Preserve the existing cross-reference discipline: the paragraph stays distinct
from — and does not duplicate — the `TaskOutput`/`TaskStop` liveness-poll
guidance for a dispatched Agent-tool task, and continues to point at the
`SendMessage`-by-name resume mechanism rather than restating it.

Affected files: `agents/orchestrator.md` (SOURCE — edit one existing
paragraph; no section added, no other section touched). The mirror
`.claude/agents/orchestrator.md` is regenerated, not hand-edited.

Regeneration (constitution P2): after editing the source, run
`node bin/cli.js --update` to regenerate the mirror. Do NOT hand-edit the
mirror.

Acceptance criteria (all runnable from repo root; each functional anchor
checked on BOTH source and regenerated mirror to confirm propagation):
- Regression guard (#91 anchors survive):
  `grep -q "background watcher" agents/orchestrator.md && grep -q "background watcher" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#91 anchors survive):
  `grep -q "independently verify" agents/orchestrator.md && grep -q "independently verify" .claude/agents/orchestrator.md` exits 0.
- Gap 1, trigger (b) named and tied to Step 1's wording:
  `grep -q "WIP sentinel" agents/orchestrator.md && grep -q "WIP sentinel" .claude/agents/orchestrator.md` exits 0.
- Gap 1, mandated wording anchor (lexical tie to persona-protocol Step 1):
  `grep -q "no autonomous wake-up available" agents/orchestrator.md && grep -q "no autonomous wake-up available" .claude/agents/orchestrator.md` exits 0.
- Gap 2, inverse "still running" branch present:
  `grep -q "still genuinely running" agents/orchestrator.md && grep -q "still genuinely running" .claude/agents/orchestrator.md` exits 0.
- Gap 3, process-namespace caveat present:
  `grep -q "process namespace" agents/orchestrator.md && grep -q "process namespace" .claude/agents/orchestrator.md` exits 0.
- No-drift check:
  `node bin/cli.js --update` re-run reports no pending drift for
  `.claude/agents/orchestrator.md` (fileHashes in sync — verify per P1, don't
  assume the mirror matches).
- Review-only editorial check: all three gaps are addressed inside the single
  existing `## Managing a long-running background dispatch` section (no
  duplicate section created); the trigger explicitly lists BOTH the legacy
  false-watcher case and the compliant WIP-sentinel case as requiring the same
  response; the resume guidance is symmetric (finished → resume / still
  running → don't resume yet); the `ps` caveat names `isolation`/sandboxed
  execution and makes git/file state the primary fallback; Steps 1, 3, 4, 5's
  content is untouched.

### Step 7 — Version-stamp + merge gate (constitution P3 and P5, MANDATORY)

Depends on Step 6 landing first (records that version-stamped
`agents/orchestrator.md` actually changed). Do this once, after Step 6's
source edit and `--update` regeneration are in place.

Affected files: `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`.
- Verify the current version first (do not assume): read at drafting time as
  `0.13.9` in both `.claude-plugin/plugin.json` and `package.json`. Bump both
  to `0.13.10` (kept in sync per the `e0080d9` merge-gate check).
- Add a `CHANGELOG.md` entry for `0.13.10` describing the follow-up: broaden
  the orchestrator's nested-background-Bash dispatcher guidance to cover both
  the legacy false-watcher claim and the compliant WIP-sentinel path, add the
  "still running → don't resume prematurely" branch, and add the `ps`
  process-namespace caveat. Cite "Fixes #89" (or reference the follow-up
  tracker issue task-master slices).

Acceptance criteria:
- `grep -q '"version": "0.13.10"' .claude-plugin/plugin.json` exits 0.
- `grep -q '"version": "0.13.10"' package.json` exits 0.
- Versions match:
  `test "$(node -p "require('./.claude-plugin/plugin.json').version")" = "$(node -p "require('./package.json').version")"` exits 0.
- `grep -q '0.13.10' CHANGELOG.md` exits 0.
- `grep -q '#89' CHANGELOG.md` exits 0.
- `python3 -m json.tool .claude-plugin/plugin.json >/dev/null && python3 -m json.tool package.json >/dev/null` exits 0 (both JSON files remain valid).
- Merge gate: `bash tests/validate.sh; echo "exit=$?"` → `exit=0` (includes the
  package.json/plugin.json version-sync check from `e0080d9`).

### Open Questions (follow-up)

None. The problem statement was handed over pre-agreed and every follow-up
taxonomy category scored Clear against the delta. If the maintainer disagrees
with a self-resolved default — most plausibly the exact literal anchor strings
in Step 6 or the patch-vs-minor bump level in Step 7 — that is a review-time
editorial adjustment, not a blocking unknown.

### Self-check (follow-up)

- CHK-F1: Does the trigger explicitly cover BOTH the legacy false-watcher case
  AND the compliant WIP-sentinel case (gap 1)? — PASS (Step 6 point 1; anchors
  "background watcher" + "WIP sentinel" + "no autonomous wake-up available").
- CHK-F2: Is the "still running → don't resume prematurely" inverse branch
  defined (gap 2)? — PASS (Step 6 point 2; anchor "still genuinely running").
- CHK-F3: Is the `ps` process-namespace caveat defined, with git/file state as
  the primary fallback (gap 3)? — PASS (Step 6 point 3; anchor "process
  namespace"; editorial check requires `isolation`/sandboxed mention).
- CHK-F4: Do the acceptance criteria preserve #91's shipped anchors so Step 2
  does not regress? — PASS (regression-guard criteria re-assert "background
  watcher" and "independently verify" on source + mirror).
- CHK-F5: Does each follow-up step carry at least one runnable acceptance
  check, per the Machine-checkable-criteria rule? — PASS (Steps 6 and 7 are
  entirely grep/exit-code checks).
- CHK-F6: Do Step 6 and Step 7 agree the edit is SOURCE-only with mirror
  regeneration (no hand-edited mirror, P2)? — PASS (Step 6 edits
  `agents/orchestrator.md` + `--update`; Step 7 touches only version files).
- CHK-F7: Is the P3 version-bump requirement resolved with stated reasoning
  rather than assumed either way? — PASS (Constitution-check P3 argues the bump
  is mandatory because P3 admits no size exemption; Step 7 implements it; the
  "fold under a note" option is explicitly considered and rejected).
- CHK-F8: Is the current version verified from disk, not assumed? — PASS (read
  0.13.9 from both JSON files; Step 7 also instructs re-checking before
  bumping).
- CHK-F9: Is Steps 1/3/4/5's shipped content confirmed out of scope? — PASS
  (follow-up preamble and Step 6 editorial check both assert it is untouched).
- CHK-F10: Is Step 7's dependency on Step 6 landing first stated? — PASS (Step
  7 header "Depends on Step 6 landing first"; Risks step-ordering bullet).

### Scribe update hint (follow-up)

Same surface as the original hint above (orchestrator supervision of
long-running background work). If a wiki/CONTEXT page documents the
orchestrator's nested-background-Bash dispatcher guidance, note that the
verify-then-resume duty now applies to BOTH the legacy false-watcher claim and
the compliant WIP-sentinel path, that resume follows the command's real state
(finished → resume / still running → wait), and that `ps` is trustworthy only
within a shared process namespace. No ADR needed; the 0.13.10 CHANGELOG entry
is the sufficient institutional record.

---

## Follow-up 2 (2026-07-21): third remediation branch — foreground timeout-kill

Append-only follow-up, layered on Follow-up 1 (Steps 6-7, #95-96), both
shipped and committed (Step 6 as commit `394b88f`, Step 7 as `5604aa1`). This
is **not** a re-plan and does **not** reopen any shipped substantive content
of Steps 1-7. It touches only the single paragraph beginning "**A distinct
case: a subagent's own nested background Bash job.**" in
`agents/orchestrator.md` (SOURCE) plus the mandatory P3 version bump. The
maintainer explicitly approved one more follow-up round after reviewing the
advisory finding below; no taxonomy grill was re-run for the #89 project as a
whole — the scorecard below is scored against this follow-up delta only.

### The gap to fix (advisory `roast-work` finding on #95)

After #95, the paragraph's broadened trigger reads: a subagent ran a `Bash`
command with `run_in_background: true` **"(or one exceeding the 600000 ms
per-call ceiling)"** — bundling the timeout-exceeded case into the SAME
"verify real state, resume when finished / wait when still running"
remediation as an intentionally-backgrounded command. But those are two
different mechanisms with two different real states:

1. **`run_in_background: true`** — an intentionally detached command. Its
   process is (or was) genuinely running in the background; there IS something
   that can finish, so "verify state, resume when finished" is correct.
2. **A foreground `Bash` command that hits its own `timeout` ceiling** — per
   the Bash tool's timeout semantics (default 120000 ms, max/ceiling 600000
   ms), a foreground command that exceeds its `timeout` is **terminated
   (killed) by the harness**, which returns a timeout error. There is no
   surviving process and no completed output — **nothing left to "finish."**
   The current remediation ("resume so it checks its own result", or "still
   running → wait") is wrong for this state: the correct action is to resume
   the subagent so it can **retry** the command (longer `timeout`, or narrower
   scope), not wait for a result that will never exist.

The #95 reviewer's own judgment (recorded as context, not gospel): this is a
"legitimate but out-of-scope robustness gap — Step 6 only committed to
covering the backgrounded-command and WIP-sentinel-escalation cases, not a
third killed-by-timeout state." This follow-up scopes that third state.

**Verification of the timeout-kill assumption (constitution P1 — verify,
don't assume).** Checked against the Bash tool's documented timeout behavior
(`timeout` in ms, default 120000, ceiling 600000) and standard timeout
semantics: on exceeding `timeout` the harness terminates the foreground
process and returns a timeout error; nothing keeps running. The spec below is
additionally **robust even if that assumption is imperfect**, because the
"killed" branch keys on an *observed* state ("no live process AND no/partial
expected output"), not on asserting the kill happened — so a lingering remnant
process would simply be caught by the "still running" branch instead. The one
thing that would be an editorial correction (not a blocking unknown): if the
maintainer knows the harness detaches rather than kills on foreground timeout.

### Is the killed-vs-still-running state distinguishable by the dispatcher? (honest answer)

Partially — and the residual ambiguity is documented as a limitation rather
than papered over with an invented signal (per the task's explicit
instruction). From the dispatcher's point of view the subagent's turn has
already ended in BOTH cases, and the dispatcher does **not** directly observe
which Bash mechanism (foreground `timeout` vs explicit `run_in_background`)
the subagent used. What the dispatcher CAN observe is external real state:

- A live matching process → still running (only possible for the backgrounded
  case) → don't resume yet.
- No live process, expected output present and complete → finished → resume to
  check the result.
- No live process, expected output absent or partial → the command did not
  finish (a killed foreground-timeout command, or a background job that died)
  → resume so it can **retry**, not wait for a result that will never come.

External inspection cannot always tell a *finished background job* from a
*killed foreground command* apart beyond the output-presence heuristic above,
and cannot see which mechanism was used. The reliable disambiguator lives in
the subagent's OWN transcript (a timeout error vs. a background-job handle).
Since resuming is the correct move whenever no live process is found, and the
resumed subagent can read its own transcript, the safe default is: resume on
"no live process" and let the resumed subagent choose between checking a
finished result and retrying a killed command. This is a sound spec with a
documented limitation — hence **no Open Question** (see below).

### In-scope, as low-cost additions on the same paragraph

- **Light restructure into a sub-list (recommended, in-scope).** Two prior
  advisory passes both flagged this paragraph as too dense/unbroken after two
  edit rounds; adding a third case inline would worsen that. Restructure the
  single dense block into a short lead-in plus a sub-list of the real states,
  preserving every shipped anchor. Judgment call made: in-scope, because it is
  the natural vehicle for the third branch, not separable from it.
- **Polish note 1 (#95 review): orphaned-referent sentence.** The sentence
  ending "…git/file state … is the primary/fallback signal otherwise, not
  merely an alternative 'or'." is hard to parse. Rewrite/split it and drop the
  confusing "not merely an alternative 'or'" trailer.
- **Polish note 2 (#95 review): over-width line.** Line 348 is 81 chars,
  exceeding the paragraph's prevailing 68-76 width. Reflow the edited region to
  the prevailing width.

Out of scope: Steps 1-7's shipped content beyond this one paragraph; any new
section, file, or hook.

### Clarifications (Follow-up 2 delta only)

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-21 Functional scope & success criteria: Q Is this a re-plan or an
  append-only follow-up? → A (self-resolved): append-only follow-up; only the
  single named paragraph and the P3 bump are in scope, Steps 1-7 untouched.
- 2026-07-21 Edge cases / failure handling: Q Is a foreground command that hits
  its `timeout` ceiling killed, leaving nothing to finish? → A (self-resolved):
  yes — verified against the Bash tool's timeout semantics (ceiling 600000 ms);
  the harness terminates the process. The spec keys the branch on observed
  state so it stays robust even if the harness detached instead.
- 2026-07-21 Technical constraints & tradeoffs: Q Can the dispatcher tell a
  timeout-killed foreground command apart from a still-running backgrounded
  one? → A (self-resolved): only partially — via an external "live process? /
  output complete?" heuristic; it does not observe which Bash mechanism was
  used. Documented as a limitation, resolved by deferring the final
  classification to the resumed subagent's own transcript. Not an Open Question
  because the resulting spec is sound.
- 2026-07-21 Technical constraints & tradeoffs: Q Does editing
  `agents/orchestrator.md` require a version bump per constitution P3? → A
  (self-resolved): yes — same reasoning as Follow-up 1 Step 7; P3 admits no
  size-based "fold under a note" exemption. See Constitution check.
- 2026-07-21 External dependencies & integrations: Q Current version to bump
  from? → A (self-resolved): verified `0.13.10` in both
  `.claude-plugin/plugin.json` and `package.json` (after #96 landed as commit
  `5604aa1`) → bump to `0.13.11`.
- 2026-07-21 Terminology consistency: Q Which literal wording anchors the new
  killed-state content? → A (self-resolved): new anchors "nothing left to
  finish", "retry the command", "its own transcript"; all six shipped anchors
  (background watcher / independently verify / WIP sentinel / no autonomous
  wake-up available / still genuinely running / process namespace) are
  re-asserted as regression guards.

### Risks / dependencies (Follow-up 2)

- **Regression risk (highest).** The edit rewrites a paragraph carrying SIX
  shipped acceptance anchors from #91 and #95. A restructure could silently
  drop any of them. Mitigated: Step 8's acceptance criteria re-assert all six
  on source AND mirror as regression guards, so #91's and #95's own criteria
  still pass after the edit.
- **Unsound-distinction risk.** Inventing a false external signal to
  "distinguish" the two states would be worse than the current gap. Mitigated:
  the spec keys branches on observed state (live process? / output complete?),
  documents the residual ambiguity as a limitation, and defers final
  classification to the resumed subagent's transcript — no invented signal.
- **Mirror hand-edit risk (constitution P2).** `.claude/agents/orchestrator.md`
  is a `fileHashes`-tracked mirror; hand-editing it is silently reverted on the
  next `--update`. Mitigated: Step 8 edits SOURCE only and regenerates via
  `node bin/cli.js --update`, pairing each grep anchor on source + mirror.
- **Version-stamp risk (constitution P3).** Editing version-stamped
  `agents/orchestrator.md` without a bump breaks `--update` and fails the
  `e0080d9` merge-gate sync check. Mitigated: Step 9 (mandatory).
- **Step-ordering dependency.** Step 9's bump must land after Step 8 so it
  records a real content change.
- No `.claude/reviewed/*.fail` record exists for this work (units #90-#96 all
  PASSed / landed); no elevated-judgment flag carried in.

### Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every acceptance criterion is a
  runnable `grep`/`awk`/exit-code check on both source and regenerated mirror;
  the merge gate runs `bash tests/validate.sh`; the current version (0.13.10)
  and the timeout-kill behavior were both verified from disk / tool docs, not
  assumed, and the killed-state branch keys on observed state to stay robust
  if the assumption is imperfect.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step 8
  edits the SOURCE `agents/orchestrator.md` and regenerates the
  `fileHashes`-tracked mirror via `node bin/cli.js --update`; no mirror is
  hand-edited.
- P3 "Version-stamp discipline": satisfied via Step 9 — and the bump IS
  required, not optional. `agents/orchestrator.md` matches `agents/*.md`; P3
  sets no size threshold and grants no "fold under a note" exemption, and
  `--update` depends on the version changing when content does. Step 9 bumps
  0.13.10 → 0.13.11 (patch level, consistent with the #90-#96 cadence for
  small behavioral clarifications).
- P4 "Optional personas degrade gracefully": satisfied — the added text is
  role-agnostic dispatcher guidance; no new unconditional optional-persona
  reference.
- P5 "`tests/validate.sh` is the merge gate": satisfied — Step 9 gates on a
  green `bash tests/validate.sh`.

### Step 8 — Add the third (timeout-kill) remediation branch and restructure the paragraph (`agents/orchestrator.md` source)

In `agents/orchestrator.md` (SOURCE), edit **only** the existing paragraph
beginning "**A distinct case: a subagent's own nested background Bash job.**"
inside the `## Managing a long-running background dispatch` section. Do NOT add
a new section and do NOT touch any other section or any of Steps 1-7's other
shipped content. Restructure the single dense block into a short lead-in plus a
sub-list of the real states (recommended restructure, in-scope). The revised
paragraph must:

1. **Keep the trigger covering both prior cases (regression, gaps 1 from #95).**
   Still name (a) the legacy false "set up a background watcher" claim and (b)
   the compliant WIP-sentinel path with the mandated "no autonomous wake-up
   available" wording, both requiring the dispatcher to independently verify
   real state. Preserve the literal strings "background watcher",
   "independently verify", "WIP sentinel", and "no autonomous wake-up
   available".
2. **Separate the two mechanisms in the lead-in.** State that this case covers
   BOTH a `run_in_background: true` command AND a foreground `Bash` command
   that hit the 600000 ms `timeout` ceiling and was killed by the harness — no
   longer bundling the timeout case into the backgrounded case's remediation.
3. **Present the resume decision as three real states (sub-list):**
   - *Still running* — a live matching process is found → do NOT resume
     prematurely; re-check later. Preserve the literal "still genuinely
     running".
   - *Finished* — no live process, expected output present and complete →
     resume via `SendMessage` by name so it checks its own result and
     continues.
   - *Killed / never finished* — no live process, expected output absent or
     partial → the command did not finish (a foreground command that hit the
     600000 ms ceiling is killed by the harness — there is **nothing left to
     finish**). Resume the subagent so it can **retry the command** (e.g. with
     a longer `timeout` or narrower scope), not wait for a result that will
     never come.
4. **Add the honest-limitation sentence.** State that external inspection
   cannot always tell a finished background job from a killed foreground
   command apart, and the dispatcher does not directly observe which mechanism
   was used; so whenever no live process is found, resume and let the resumed
   subagent — which can read **its own transcript** (a timeout error vs. a
   background-job handle) — make the final choice.
5. **Fix polish note 1 (orphaned "or").** Rewrite/split the `ps`-caveat
   sentence so it no longer ends with "not merely an alternative 'or'". Keep
   the substance: `ps` is valid only within a shared **process namespace**
   (naming `isolation: "worktree"`/`"remote"` / sandboxed execution); git/file
   state is the primary/fallback signal otherwise. Preserve the literal
   "process namespace".
6. **Fix polish note 2 (width).** Reflow the edited region to the paragraph's
   prevailing width (68-76 chars); no line in the section may exceed 80.

Preserve the existing cross-reference discipline: the paragraph stays distinct
from — and does not duplicate — the `TaskOutput`/`TaskStop` liveness-poll
guidance for a dispatched Agent-tool task, and continues to point at the
`SendMessage`-by-name resume mechanism rather than restating it.

Affected files: `agents/orchestrator.md` (SOURCE — edit one existing
paragraph; no section added, no other section touched). The mirror
`.claude/agents/orchestrator.md` is regenerated, not hand-edited.

Regeneration (constitution P2): after editing the source, run
`node bin/cli.js --update` to regenerate the mirror. Do NOT hand-edit the
mirror.

Acceptance criteria (all runnable from repo root; each functional anchor
checked on BOTH source and regenerated mirror to confirm propagation):
- Regression guard (#91 anchor survives):
  `grep -q "background watcher" agents/orchestrator.md && grep -q "background watcher" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#91 anchor survives):
  `grep -q "independently verify" agents/orchestrator.md && grep -q "independently verify" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#95 anchor survives):
  `grep -q "WIP sentinel" agents/orchestrator.md && grep -q "WIP sentinel" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#95 anchor survives):
  `grep -q "no autonomous wake-up available" agents/orchestrator.md && grep -q "no autonomous wake-up available" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#95 anchor survives — still-running inverse branch kept):
  `grep -q "still genuinely running" agents/orchestrator.md && grep -q "still genuinely running" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#95 anchor survives — ps caveat kept):
  `grep -q "process namespace" agents/orchestrator.md && grep -q "process namespace" .claude/agents/orchestrator.md` exits 0.
- New: killed-state truth present:
  `grep -q "nothing left to finish" agents/orchestrator.md && grep -q "nothing left to finish" .claude/agents/orchestrator.md` exits 0.
- New: resume-to-retry remediation present:
  `grep -q "retry the command" agents/orchestrator.md && grep -q "retry the command" .claude/agents/orchestrator.md` exits 0.
- New: honest-limitation / defer-to-transcript present:
  `grep -q "its own transcript" agents/orchestrator.md && grep -q "its own transcript" .claude/agents/orchestrator.md` exits 0.
- Polish note 1: the confusing trailer is gone (negative anchor, source + mirror):
  `! grep -q "not merely an alternative" agents/orchestrator.md && ! grep -q "not merely an alternative" .claude/agents/orchestrator.md` exits 0.
- Polish note 2: no over-width line remains in the section (source):
  `awk '/^## Managing a long-running background dispatch/{f=1;next} /^## /{f=0} f && length($0)>80{c++} END{exit (c>0)}' agents/orchestrator.md` exits 0.
- No-drift check:
  `node bin/cli.js --update` re-run reports no pending drift for
  `.claude/agents/orchestrator.md` (fileHashes in sync — verify per P1, don't
  assume the mirror matches).
- Review-only editorial check: the paragraph now reads as a lead-in plus a
  three-state sub-list; the timeout-kill mechanism is separated from the
  backgrounded mechanism; the killed state's remediation is resume-to-retry
  (not resume-to-check-result and not "wait"); the honest-limitation sentence
  is present and does not invent a false external distinguishing signal; the
  `ps` caveat reads cleanly without the "not merely an alternative 'or'"
  trailer; the paragraph stays inside the one existing section and does not
  duplicate the `TaskOutput`/`TaskStop` guidance; Steps 1-7's other content is
  untouched.

### Step 9 — Version-stamp + merge gate (constitution P3 and P5, MANDATORY)

Depends on Step 8 landing first (records that version-stamped
`agents/orchestrator.md` actually changed). Do this once, after Step 8's
source edit and `--update` regeneration are in place.

Affected files: `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`.
- Verify the current version first (do not assume): read at drafting time as
  `0.13.10` in both `.claude-plugin/plugin.json` and `package.json`. Bump both
  to `0.13.11` (kept in sync per the `e0080d9` merge-gate check).
- Add a `CHANGELOG.md` entry for `0.13.11` describing the follow-up: add the
  third (foreground-timeout-kill) remediation branch to the orchestrator's
  nested-background-Bash dispatcher guidance — resume-to-retry rather than
  resume-to-check-result — restructure the paragraph into a three-state
  sub-list, and apply the two #95 polish notes. Cite "Fixes #89" (or reference
  the follow-up tracker issue task-master slices).

Acceptance criteria:
- `grep -q '"version": "0.13.11"' .claude-plugin/plugin.json` exits 0.
- `grep -q '"version": "0.13.11"' package.json` exits 0.
- Versions match:
  `test "$(node -p "require('./.claude-plugin/plugin.json').version")" = "$(node -p "require('./package.json').version")"` exits 0.
- `grep -q '0.13.11' CHANGELOG.md` exits 0.
- `grep -q '#89' CHANGELOG.md` exits 0.
- `python3 -m json.tool .claude-plugin/plugin.json >/dev/null && python3 -m json.tool package.json >/dev/null` exits 0 (both JSON files remain valid).
- Merge gate: `bash tests/validate.sh; echo "exit=$?"` → `exit=0` (includes the
  package.json/plugin.json version-sync check from `e0080d9`).

### Open Questions (Follow-up 2)

None. The one place this could have escalated — whether the timeout-killed vs
still-running distinction is observable by the dispatcher — was worked through
(see "Is the killed-vs-still-running state distinguishable" above) and yields a
sound spec: an external observed-state heuristic plus a documented limitation
resolved by deferring final classification to the resumed subagent's own
transcript. No false distinguishing signal was invented, so there is no
unsound-branch escalation. If the maintainer disagrees with a self-resolved
default — most plausibly the exact literal anchor strings in Step 8, the
patch-vs-minor bump level in Step 9, or (the one factual correction that would
matter) the harness's foreground-timeout behavior being detach rather than
kill — that is a review-time editorial adjustment, not a blocking unknown.

### Self-check (Follow-up 2)

- CHK-G1: Is the third (foreground-timeout-kill) state defined as distinct from
  the backgrounded still-running state, with its own remediation? — PASS (Step
  8 points 2-3; anchors "nothing left to finish", "retry the command").
- CHK-G2: Is the killed-state remediation resume-to-RETRY rather than
  resume-to-check-result or "wait"? — PASS (Step 8 point 3 third bullet;
  editorial check enforces it).
- CHK-G3: Does the plan answer scope item (a) — how the dispatcher tells the
  two apart — honestly, without inventing a false signal? — PASS (documented as
  partially observable via the live-process/output heuristic + deferral to the
  subagent's transcript; anchor "its own transcript").
- CHK-G4: Does the plan answer scope item (b) — the correct killed-case action?
  — PASS (resume-to-retry; Step 8 point 3).
- CHK-G5: Do the acceptance criteria preserve ALL six shipped anchors from #91
  and #95 so the paragraph does not regress? — PASS (six regression-guard
  criteria on source + mirror).
- CHK-G6: Are polish notes 1 (orphaned "or") and 2 (over-width line) both
  covered with a runnable check? — PASS (negative-anchor grep for
  "not merely an alternative"; awk width check ≤80 in-section).
- CHK-G7: Does each follow-up step carry at least one runnable acceptance
  check, per the Machine-checkable-criteria rule? — PASS (Steps 8 and 9 are
  grep/awk/exit-code checks).
- CHK-G8: Do Step 8 and Step 9 agree the edit is SOURCE-only with mirror
  regeneration (no hand-edited mirror, P2)? — PASS (Step 8 edits
  `agents/orchestrator.md` + `--update`; Step 9 touches only version files).
- CHK-G9: Is the P3 version-bump requirement resolved with stated reasoning
  rather than assumed either way? — PASS (Constitution-check P3 argues the bump
  is mandatory; Step 9 implements 0.13.10 → 0.13.11).
- CHK-G10: Is the current version verified from disk (0.13.10), not assumed? —
  PASS (read from both JSON files after #96; Step 9 also instructs re-checking).
- CHK-G11: Is the timeout-kill assumption verified rather than asserted, and is
  the spec robust if it is imperfect? — PASS (verified against tool timeout
  docs; the killed branch keys on observed state, not on the kill having
  happened).
- CHK-G12: Is Steps 1-7's shipped content (beyond the one paragraph) confirmed
  out of scope? — PASS (follow-up preamble, Step 8 header, and Step 8 editorial
  check all assert it is untouched).
- CHK-G13: Is Step 9's dependency on Step 8 landing first stated? — PASS (Step
  9 header "Depends on Step 8 landing first"; Risks step-ordering bullet).

### Scribe update hint (Follow-up 2)

Same surface as the prior hints (orchestrator supervision of long-running
background work). If a wiki/CONTEXT page documents the orchestrator's
nested-background-Bash dispatcher guidance, note that the resume decision now
has THREE states, not two: still running → wait; finished → resume to check
result; killed (a foreground command that hit the 600000 ms timeout ceiling
and was terminated) → resume to RETRY, because nothing is left to finish. Also
note the documented limitation: external inspection cannot always tell a
finished background job from a killed foreground command apart, so the
dispatcher resumes on "no live process" and lets the subagent's own transcript
settle it. No ADR needed; the 0.13.11 CHANGELOG entry is the sufficient
institutional record.

---

## Follow-up 3 (2026-07-21): reconcile the lead-in enumeration with the three real mechanisms

Append-only follow-up, layered on Follow-up 2 (Steps 8-9, #97-98, both
shipped and committed). This is **not** a re-plan and does **not** reopen
any shipped substantive content of Steps 1-9. It touches only the lead-in
sentences of the single paragraph beginning "**A distinct case: a
subagent's own nested background Bash job.**" in `agents/orchestrator.md`
(SOURCE) plus the mandatory P3 version bump. This is a maintainer-approved
fix for a `milestone-auditor` finding (run after all prior #89 work
shipped), not a re-plan; no taxonomy grill was re-run — the scorecard below
is scored against this follow-up delta only. **This is intended to be the
FINAL edit to this paragraph** — after three prior rounds the goal is to
converge, not to reopen debate or restructure further.

### The gap to fix (milestone-auditor finding on the shipped paragraph)

After #97 (Follow-up 2, Step 8) the paragraph's *sub-list* correctly handles
three real states (still running / finished / killed-by-timeout), but its
*lead-in* still frames the turn-ending as "one of two trigger cases":
(a) the legacy false "background watcher" claim, or (b) the subagent
correctly followed the WIP-sentinel path. #97 introduced a THIRD mechanism —
a foreground `Bash` command killed by its own 600000 ms `timeout` — that fits
NEITHER (a) nor (b): it produced no "background watcher" claim (nothing was
backgrounded), and being killed mid-run is precisely the *failure* of NOT
having proactively escalated via the WIP sentinel (Step 1/#90 defines the WIP
sentinel as the only legitimate >10 min turn-end path). The lead-in conflates
two orthogonal taxonomies — *which Bash mechanism ran* vs. *how the subagent's
turn ended / what it claimed* — and the newest mechanism falls through the
"one of two" framing.

**Outcome impact is limited (auditor's own assessment, recorded as context):**
the downstream three-state sub-list DOES handle the killed case correctly, and
the honest-limitation sentence already concedes the dispatcher cannot observe
which mechanism ran, so the prescribed *action* is still correct. This is a
readability/accuracy defect in the lead-in, not a wrong action. The fix is
therefore tightly scoped to reconciling the lead-in's stated claim with the
reality the rest of the paragraph already handles.

**Also folded in (same auditor finding, cosmetic):** the doubled "Either way"
— the phrase appears in two consecutive sentences of the lead-in (once after
the Bash-mechanism list at line 331, once after the trigger-case list at line
337), redundant residue of the layered edits. Fixed as part of the same edit.

### Chosen reconciliation approach (option b — drop the pre-enumeration)

Of the maintainer's offered options — (a) broaden "one of two trigger cases"
to name all three appearances, (b) drop the "trigger cases" framing entirely
in favor of directly introducing the (already-present) three-state sub-list,
or (c) something else — this spec selects **(b)**, because it reads cleanest
and best serves convergence: the sub-list below the lead-in *already*
enumerates the real states, so a second, differently-shaped pre-enumeration in
the lead-in is redundant surface area and is exactly what drifted out of sync.
Rather than maintain a parallel "two trigger cases" list, the lead-in should
state the one durable truth (whichever mechanism ran and whatever the subagent
claimed — a false watcher claim, an honest WIP-sentinel escalation, or nothing
because it was killed mid-run — it cannot resume itself; independently verify)
and let the sub-list carry the per-state decision. The (a)/(b) content is
preserved as non-exhaustive illustrative examples of what a subagent may report
on the way out, with the killed-mid-run case added so nothing falls through.

Recommended target lead-in (implementer/reviewer may adjust non-anchor wording,
but the required literal anchors below must hold and the lead-in must no longer
claim an exhaustive "two" enumeration):

```
**A distinct case: a subagent's own nested background Bash job.** The
above `TaskOutput`/`TaskStop` polling is about YOUR dispatched Agent-tool
task's liveness, not a subagent's own nested Bash call. This case covers
two different mechanisms: a subagent's own `Bash` command run with
`run_in_background: true`, and a foreground `Bash` command that hit the
600000 ms per-call ceiling and was killed by the harness. Whichever ran,
the subagent has no mechanism to resume itself and stays dormant at
`SubagentStop` — regardless of what it claimed on the way out, or whether
it said anything at all. Don't trust a self-wake claim at face value: it
may have falsely asserted it "set up a background watcher" (that claim is
false), honestly escalated via the WIP sentinel with the mandated wording
"no autonomous wake-up available — requires the dispatcher to resume me
later", or simply been killed mid-run with no parting message. The
response is the same in every case — don't wait for a self-notification
that will never come; independently verify the real state yourself. `ps`
for the process is a valid signal only when the dispatcher and the
subagent share a process namespace (true for default local dispatch, not
necessarily for `isolation: "worktree"`/`"remote"` Agent dispatch or other
sandboxed execution); when it isn't, fall back to git/file state for the
expected output as the primary signal instead.
```

The three-state sub-list, the honest-limitation/defer-to-transcript sentence,
and every other paragraph and section stay exactly as shipped by #97 — this
follow-up rewrites only the lead-in sentences between the "two different
mechanisms" sentence and the `ps` caveat.

### Clarifications (Follow-up 3 delta only)

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-21 Functional scope & success criteria: Q Is this a re-plan or an
  append-only follow-up? → A (self-resolved): append-only follow-up; only the
  lead-in of the one named paragraph and the P3 bump are in scope, Steps 1-9's
  shipped substantive content untouched.
- 2026-07-21 Technical constraints & tradeoffs: Q Which reconciliation approach
  (broaden the "two" list vs. drop the pre-enumeration)? → A (self-resolved):
  drop it (option b) — the sub-list already enumerates the real states, so a
  parallel lead-in enumeration is the redundant surface that drifted; removing
  it converges rather than adding a third parallel list. See "Chosen
  reconciliation approach" above.
- 2026-07-21 Terminology consistency: Q Which literal wording must survive vs.
  be removed? → A (self-resolved): preserve all nine prior anchors (background
  watcher / independently verify / WIP sentinel / no autonomous wake-up
  available / still genuinely running / process namespace / nothing left to
  finish / retry the command / its own transcript); remove the conflated
  literal "one of two trigger cases"; reduce the doubled "Either way" to at
  most one occurrence in the section; name the killed-silently case in the
  lead-in via the literal "killed mid-run".
- 2026-07-21 Edge cases / failure handling: Q Does dropping the (a)/(b)
  enumeration lose any case the sub-list doesn't cover? → A (self-resolved):
  no — (a) and (b) are preserved as inline illustrative examples, the
  killed-mid-run third case is added, and the per-state decision was already
  carried by the sub-list; nothing the paragraph acts on is lost.
- 2026-07-21 Technical constraints & tradeoffs: Q Does editing
  `agents/orchestrator.md` require a version bump per constitution P3? → A
  (self-resolved): yes — same reasoning as Follow-ups 1 and 2; P3 admits no
  size-based "fold under a note" exemption. See Constitution check.
- 2026-07-21 External dependencies & integrations: Q Current version to bump
  from? → A (self-resolved): verified `0.13.11` in both
  `.claude-plugin/plugin.json` and `package.json` (after #98 landed) → bump to
  `0.13.12`.

### Risks / dependencies (Follow-up 3)

- **Regression risk (highest).** The edit rewrites lead-in sentences of a
  paragraph carrying NINE shipped acceptance anchors from #91/#95/#97; five of
  them (`background watcher`, `independently verify`, `WIP sentinel`, `no
  autonomous wake-up available`, `process namespace`) live in the lead-in
  region being rewritten and could be dropped. Mitigated: Step 10's acceptance
  criteria re-assert all nine on source AND mirror as regression guards.
- **Over-reach risk.** Tempting to "clean up" the sub-list or the
  honest-limitation sentence while here; that would reopen #97's shipped
  content and break convergence. Mitigated: Step 10 rewrites ONLY the lead-in
  sentences between the "two different mechanisms" sentence and the `ps` caveat;
  editorial check asserts the sub-list and honest-limitation sentence are
  byte-unchanged in substance.
- **Mirror hand-edit risk (constitution P2).** `.claude/agents/orchestrator.md`
  is a `fileHashes`-tracked mirror; hand-editing it is silently reverted on the
  next `--update`. Mitigated: Step 10 edits SOURCE only and regenerates via
  `node bin/cli.js --update`, pairing each grep anchor on source + mirror.
- **Version-stamp risk (constitution P3).** Editing version-stamped
  `agents/orchestrator.md` without a bump breaks `--update` and fails the
  `e0080d9` merge-gate sync check. Mitigated: Step 11 (mandatory).
- **Step-ordering dependency.** Step 11's bump must land after Step 10 so it
  records a real content change.
- No `.claude/reviewed/*.fail` record exists for this work (units #90-#98 all
  PASSed / landed); no elevated-judgment flag carried in.

### Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every acceptance criterion is a
  runnable `grep`/`awk`/exit-code check on both source and regenerated mirror;
  the merge gate runs `bash tests/validate.sh`; the current version (0.13.11)
  and the two target phrases' occurrences were read from disk, not assumed.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — Step 10
  edits the SOURCE `agents/orchestrator.md` and regenerates the
  `fileHashes`-tracked mirror via `node bin/cli.js --update`; no mirror is
  hand-edited.
- P3 "Version-stamp discipline": satisfied via Step 11 — and the bump IS
  required, not optional. `agents/orchestrator.md` matches `agents/*.md`; P3
  sets no size threshold and grants no "fold under a note" exemption, and
  `--update` depends on the version changing when content does. Step 11 bumps
  0.13.11 → 0.13.12 (patch level, consistent with the #90-#98 cadence for small
  behavioral/readability clarifications).
- P4 "Optional personas degrade gracefully": satisfied — the edited text is
  role-agnostic dispatcher guidance; no new unconditional optional-persona
  reference.
- P5 "`tests/validate.sh` is the merge gate": satisfied — Step 11 gates on a
  green `bash tests/validate.sh`.

### Step 10 — Reconcile the lead-in enumeration and fix the doubled "Either way" (`agents/orchestrator.md` source)

In `agents/orchestrator.md` (SOURCE), edit **only** the lead-in sentences of
the existing paragraph beginning "**A distinct case: a subagent's own nested
background Bash job.**" inside the `## Managing a long-running background
dispatch` section — specifically the sentences between the "This case covers
two different mechanisms…" sentence and the `ps` process-namespace caveat. Do
NOT add a new section, do NOT touch the three-state sub-list, the
honest-limitation/defer-to-transcript sentence, or any other section or any of
Steps 1-9's other shipped content. Apply the recommended target lead-in in
"Chosen reconciliation approach" above. The edit must:

1. **Remove the conflated "one of two trigger cases" enumeration (the auditor
   finding).** The lead-in must no longer claim the turn-ending is exhaustively
   one of two cases. Reframe the durable truth as: whichever Bash mechanism ran
   and whatever the subagent claimed on the way out (or if it said nothing at
   all), it cannot resume itself — so independently verify the real state.
2. **Preserve (a)/(b) as non-exhaustive illustrative examples AND add the
   third.** Keep the legacy false "background watcher" claim and the compliant
   WIP-sentinel "no autonomous wake-up available" path as inline examples, and
   add the killed-mid-run case (a foreground command killed by the 600000 ms
   ceiling with no parting message) so the newest mechanism no longer falls
   through the framing. Use the literal "killed mid-run".
3. **Fix the doubled "Either way" (auditor cosmetic finding).** Reduce the two
   consecutive "Either way" occurrences to at most one in the section.
4. **Keep the paragraph within the prevailing width** (no line in the section
   may exceed 80 chars; the Follow-up-2 width guard is re-asserted).

Preserve the existing cross-reference discipline: the paragraph stays distinct
from — and does not duplicate — the `TaskOutput`/`TaskStop` liveness-poll
guidance, and continues to point at the `SendMessage`-by-name resume mechanism
(in the untouched sub-list) rather than restating it.

Affected files: `agents/orchestrator.md` (SOURCE — edit the lead-in of one
existing paragraph; no section added, no other section or paragraph-region
touched). The mirror `.claude/agents/orchestrator.md` is regenerated, not
hand-edited.

Regeneration (constitution P2): after editing the source, run
`node bin/cli.js --update` to regenerate the mirror. Do NOT hand-edit the
mirror.

Acceptance criteria (all runnable from repo root; each functional anchor
checked on BOTH source and regenerated mirror to confirm propagation):
- Regression guard (#91 anchor survives):
  `grep -q "background watcher" agents/orchestrator.md && grep -q "background watcher" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#91 anchor survives):
  `grep -q "independently verify" agents/orchestrator.md && grep -q "independently verify" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#95 anchor survives):
  `grep -q "WIP sentinel" agents/orchestrator.md && grep -q "WIP sentinel" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#95 anchor survives):
  `grep -q "no autonomous wake-up available" agents/orchestrator.md && grep -q "no autonomous wake-up available" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#95 anchor survives — still-running branch untouched):
  `grep -q "still genuinely running" agents/orchestrator.md && grep -q "still genuinely running" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#95 anchor survives — ps caveat kept):
  `grep -q "process namespace" agents/orchestrator.md && grep -q "process namespace" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#97 anchor survives — killed-state branch untouched):
  `grep -q "nothing left to finish" agents/orchestrator.md && grep -q "nothing left to finish" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#97 anchor survives — retry remediation untouched):
  `grep -q "retry the command" agents/orchestrator.md && grep -q "retry the command" .claude/agents/orchestrator.md` exits 0.
- Regression guard (#97 anchor survives — honest-limitation sentence untouched):
  `grep -q "its own transcript" agents/orchestrator.md && grep -q "its own transcript" .claude/agents/orchestrator.md` exits 0.
- New (fix): the conflated enumeration is gone (negative anchor, source + mirror):
  `! grep -q "one of two trigger cases" agents/orchestrator.md && ! grep -q "one of two trigger cases" .claude/agents/orchestrator.md` exits 0.
- New (fix): the third mechanism is named in the lead-in (source + mirror):
  `grep -q "killed mid-run" agents/orchestrator.md && grep -q "killed mid-run" .claude/agents/orchestrator.md` exits 0.
- New (fix): the doubled "Either way" is reduced to at most one in the section
  (source):
  `awk '/^## Managing a long-running background dispatch/{f=1;next} /^## /{f=0} f{n+=gsub(/Either way/,"&")} END{exit (n>1)}' agents/orchestrator.md` exits 0.
- Polish (kept from #97): no over-width line remains in the section (source):
  `awk '/^## Managing a long-running background dispatch/{f=1;next} /^## /{f=0} f && length($0)>80{c++} END{exit (c>0)}' agents/orchestrator.md` exits 0.
- No-drift check:
  `node bin/cli.js --update` re-run reports no pending drift for
  `.claude/agents/orchestrator.md` (fileHashes in sync — verify per P1, don't
  assume the mirror matches).
- Review-only editorial check: the lead-in no longer claims an exhaustive "two"
  enumeration; the (a) false-watcher claim, (b) WIP-sentinel path, and the new
  killed-mid-run case appear as non-exhaustive illustrative examples of what a
  subagent may report at turn-end; the doubled "Either way" is fixed; the
  three-state sub-list and the honest-limitation/defer-to-transcript sentence
  are substantively unchanged from #97; the paragraph stays inside the one
  existing section, does not duplicate the `TaskOutput`/`TaskStop` guidance, and
  Steps 1-9's other content is untouched. This is the final edit to this
  paragraph.

### Step 11 — Version-stamp + merge gate (constitution P3 and P5, MANDATORY)

Depends on Step 10 landing first (records that version-stamped
`agents/orchestrator.md` actually changed). Do this once, after Step 10's
source edit and `--update` regeneration are in place.

Affected files: `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`.
- Verify the current version first (do not assume): read at drafting time as
  `0.13.11` in both `.claude-plugin/plugin.json` and `package.json`. Bump both
  to `0.13.12` (kept in sync per the `e0080d9` merge-gate check).
- Add a `CHANGELOG.md` entry for `0.13.12` describing the follow-up: reconcile
  the "distinct case" dispatcher-supervision lead-in in `agents/orchestrator.md`
  with the three real mechanisms — drop the inaccurate "one of two trigger
  cases" enumeration (a foreground command killed by the 600000 ms timeout fits
  neither the false-watcher nor the WIP-sentinel case), reframing them as
  non-exhaustive examples plus the killed-mid-run case; and fix the doubled
  "Either way". Cite "Fixes #89" (or reference the follow-up tracker issue
  task-master slices).

Acceptance criteria:
- `grep -q '"version": "0.13.12"' .claude-plugin/plugin.json` exits 0.
- `grep -q '"version": "0.13.12"' package.json` exits 0.
- Versions match:
  `test "$(node -p "require('./.claude-plugin/plugin.json').version")" = "$(node -p "require('./package.json').version")"` exits 0.
- `grep -q '0.13.12' CHANGELOG.md` exits 0.
- `grep -q '#89' CHANGELOG.md` exits 0.
- `python3 -m json.tool .claude-plugin/plugin.json >/dev/null && python3 -m json.tool package.json >/dev/null` exits 0 (both JSON files remain valid).
- Merge gate: `bash tests/validate.sh; echo "exit=$?"` → `exit=0` (includes the
  package.json/plugin.json version-sync check from `e0080d9`).

### Open Questions (Follow-up 3)

None. The reconciliation approach was a bounded design choice among options the
maintainer pre-enumerated (broaden vs. drop vs. other); option (b) was selected
with stated reasoning and does not require information only the user holds. If
the maintainer prefers option (a) (broaden the enumeration to name all three)
or disagrees with an exact literal anchor (`killed mid-run`) or the
patch-vs-minor bump level, that is a review-time editorial adjustment, not a
blocking unknown.

### Self-check (Follow-up 3)

- CHK-H1: Does the fix make the lead-in's claim accurate against the three real
  mechanisms the rest of the paragraph handles (the auditor finding)? — PASS
  (Step 10 point 1 drops the exhaustive "two" claim; point 2 names the third
  case; negative anchor `! grep -q "one of two trigger cases"` + positive anchor
  `killed mid-run`).
- CHK-H2: Is the doubled "Either way" fixed with a runnable check? — PASS (Step
  10 point 3; awk count `Either way` ≤ 1 within the section).
- CHK-H3: Do the acceptance criteria preserve ALL nine shipped anchors from
  #91/#95/#97 so the paragraph does not regress? — PASS (nine regression-guard
  criteria on source + mirror).
- CHK-H4: Is the edit confined to the lead-in, leaving the three-state sub-list
  and honest-limitation sentence (#97) substantively unchanged? — PASS (Step 10
  scope clause + editorial check assert it).
- CHK-H5: Does each follow-up step carry at least one runnable acceptance check,
  per the Machine-checkable-criteria rule? — PASS (Steps 10 and 11 are
  grep/awk/exit-code checks).
- CHK-H6: Do Step 10 and Step 11 agree the edit is SOURCE-only with mirror
  regeneration (no hand-edited mirror, P2)? — PASS (Step 10 edits
  `agents/orchestrator.md` + `--update`; Step 11 touches only version files).
- CHK-H7: Is the P3 version-bump requirement resolved with stated reasoning
  rather than assumed either way? — PASS (Constitution-check P3 argues the bump
  is mandatory; Step 11 implements 0.13.11 → 0.13.12).
- CHK-H8: Is the current version verified from disk (0.13.11), not assumed? —
  PASS (read from both JSON files; Step 11 also instructs re-checking).
- CHK-H9: Is Steps 1-9's shipped content (beyond the one lead-in) confirmed out
  of scope? — PASS (follow-up preamble, Step 10 scope clause + editorial check
  all assert it is untouched).
- CHK-H10: Is Step 11's dependency on Step 10 landing first stated? — PASS (Step
  11 header "Depends on Step 10 landing first"; Risks step-ordering bullet).
- CHK-H11: Is the chosen reconciliation approach (option b) stated with a reason,
  rather than silently picked? — PASS ("Chosen reconciliation approach" section
  names option b and why; the alternatives are recorded in Open Questions as a
  review-time swap, not a blocking unknown).

### Scribe update hint (Follow-up 3)

Same surface as the prior hints (orchestrator supervision of long-running
background work). This round is a readability/accuracy reconciliation, not a
behavior change: if a wiki/CONTEXT page enumerates the "distinct case"
dispatcher-supervision trigger as "one of two cases", update it to note the
lead-in no longer enumerates an exhaustive two — the durable truth is that
whichever Bash mechanism ran and whatever the subagent claimed (false watcher
claim / honest WIP-sentinel escalation / killed mid-run with no message), it
cannot resume itself, and the three-state sub-list carries the per-state
decision. No ADR needed; the 0.13.12 CHANGELOG entry is the sufficient
institutional record.
