# Gateless mode: a runtime switch that turns off review gating

Status: **FINAL — dispatch-ready** (spec-master, 2026-09-29). All four
round-1 Open Questions have been answered by the human, and every answer took
the recommended default. The answers are recorded in Clarifications and
folded into the steps below. Branch `gateless_mode`, baseline HEAD `4051d45`,
plugin version `0.31.98`.

## Goal

Add a per-project runtime switch in `.claude/persona-config.json`, **off by
default**, that turns the harness gateless. While the switch is set to
gateless:

- G1. Every persona and all orchestrator routing stay as they are. The
  reviewer is still dispatched once per unit and still returns a verdict and
  findings. That verdict is **advisory**: the reviewer writes no
  `.pass`/`.fail`/`.blocked`/`.escalated` marker, and nothing blocks on it.
- G2. These review-enforcement mechanisms go inert: the pending-review flags
  and the reviewer-join verdict check in `stop-gate.sh`, the unit-exclusivity
  block in `reviewer-route-gate.sh`, `task-gate.sh`, and `dispatch-hygiene.sh`'s
  marker-based H3 check. `dispatch-hygiene.sh`'s audit log and H1/H2/H4 checks
  keep running.
- G3. Human escalation goes away entirely: no ESCALATE-TO-HUMAN verdict, no
  `.escalated` marker, no escalation packet, and `human-decision-gate.sh` is
  inert. The 2-FAIL cap no longer stops for the human. At a unit's second
  advisory FAIL, the orchestrator lists the remaining defects and carries on.
- G4. `protected-paths.sh` keeps working exactly as it does now.
- G5. The installer asks for the mode once. A slash command changes it later.
- G6. The persona prose (orchestrator, reviewer, shared protocol, and every
  hand-synced copy) describes gateless behaviour, so personas don't fight the
  disabled hooks.
- G7. Nothing changes for a project whose config does not have the key.

It is a runtime switch, not a forked branch.

## Context — the measured situation

**Premise correction 1 — the key is already reserved.** Spec 6
(`docs/plans/2026-08-25-ci-shaped-review-architecture-d.md`, D0) designed a
`reviewGating.mode` key (`enforce|warn|off`, absent resolves to `enforce`) for
exactly this purpose. That spec was never executed: no hook reads the key
today. The key is still partly wired:

- `bin/harness-integrity.sh:106` already treats `"reviewGating.mode":
  ($c.reviewGating.mode // "enforce")` as one of the nine **disarm surface**
  fields. That means config-drift detection already notices a flip to `off`.
- `docs/harness-glossary.md:2333-2337` documents the key.
- Comments mention it at `hooks/scripts/lib/stop-gate-core.sh:54` and
  `.claude/hooks/scripts/session-start.sh:111`.

So the human's `gateMode: gated|gateless` would be a **second** key for the
same concept. This plan reuses `reviewGating.mode` with the values
`enforce|off` (Open Question 1, resolved 2026-09-29: reuse). "Gateless" stays as the user-facing name for
`off`.

**Premise correction 2 — "gateless" is not literally gateless.** Several gates
stay armed in this design:

- `protected-paths.sh`, which the human asked to keep.
- `harness-integrity-gate.sh`, which by design reads no config.
- `reviewed-path-gate.sh`, `heavy-trigger.sh`, `reviewer-tier.sh`, and the
  config-drift block.

The accurate glossary term is **review gating off**. See "Draft glossary
entries" below.

**How the switch gets flipped (security).** `.claude/persona-config.json` is
in `harness-integrity-gate.sh`'s Set A (`harness-integrity-gate.sh:21-28`).
That gives three routes, with different outcomes:

- Bash writes whose command text names the file are denied outright.
- Write/Edit from the main session gets `permissionDecision: "ask"`, meaning a
  human confirms. Write/Edit from a subagent is denied.
- A new `bin/cli.js --set-review-gating` flag would **not** name the path in
  its command text. It would therefore give any agent a way to switch off its
  own review.

Decision (self-resolved): the slash command flips the switch **only** by
having the main session `Edit` the file, which triggers the human-confirmation
ask. The plan adds no CLI write path. The installer already writes this file
through the same ask branch (`skills/install-antislop/SKILL.md:318-330`).

**Config-drift interaction.** `stop-gate-core.sh:601-640` blocks a gated
agent's SubagentStop whenever a disarm surface field differs from the session
baseline commit's config. The block can be cleared with a
`.config-drift-override.<agent-id>` file (`defer:` or `skip:`).

A flip is therefore visible as drift until the human **commits** the config
and a new session starts. That is the intended tamper signal, so it stays
armed in **both** modes. If it were disabled in `off` mode, an unauthorized
flip would switch off its own detector. Agents also cannot `git add` the file,
because the path is in Set A for Bash. So the human commits it.

**Hook inventory.** Measured at `4051d45`. Registration is in
`hooks/hooks.json`.

| Hook | Event | Class | Change under `off` |
|---|---|---|---|
| `stop-gate.sh` → `lib/stop-gate-core.sh` | Stop, SubagentStop | mixed | reviewer-join verdict block (`:334-488`) inert; main-Stop pending-review block (`:501-546`) inert; gated SubagentStop writes no pending-review flag (`:583-585`). **Kept:** microworld deferred-result block (`:64-90`), WIP sentinel, config-drift block (`:601-640`), test+lint (`:646-665`) (Open Question 3, resolved: kept) |
| `reviewer-route-gate.sh` → `lib/reviewer-route-gate-core.sh` | PreToolUse Agent | mixed | pending-review unit-exclusivity block (core `:30-50`) and `.review-join.*` stamp writes (core `:95-150`) inert. **Kept:** entry-script identity guards ("lead-programmer may not spawn reviewer", "only orchestrator dispatches reviewer") and the privileged-name guard (core `:54-66`) (Open Question 3, resolved: kept) |
| `task-gate.sh` | TaskCompleted | review-enforcement | whole gate inert (exit 0) |
| `dispatch-hygiene.sh` | PreToolUse Agent | mixed | H3 (`:303-354`) skipped; H1/H2/H4 and the dispatch-audit.log line kept |
| `human-decision-gate.sh` | PreToolUse Bash, Write/Edit | escalation | inert (exit 0). It currently reads no config at all, so this adds its first config read |
| `session-start.sh` | SessionStart | reporter | **adds** a one-line banner when effective mode is `off` |
| `protected-paths.sh` | PreToolUse Write/Edit | protection | unchanged (G4) |
| `harness-integrity-gate.sh`, `reviewed-path-gate.sh`, `heavy-trigger.sh`, `reviewer-tier.sh`, `marker-*.sh`, `microworld-rerun.sh`, `lint-on-edit.sh`, `graph-update.sh`, `version-stamp-check.sh` | — | — | unchanged |

**Copies.**

- Generated copies are regenerated by `node bin/cli.js --update`. They must
  never be hand-edited (constitution P2). Their `fileHashes` entries are
  refreshed by the same run. The generated copies are:
  - every `.claude/hooks/scripts/**` mirror;
  - `.claude/agents/*.md`;
  - `.claude/persona-protocol*.md`;
  - `.claude/protocol-digest.md`;
  - `adapters/{codex,cursor}/hooks/scripts/lib/{stop-gate-core,reviewer-route-gate-core}.sh`,
    which are shared byte-for-byte and generated with
    `--update --force-render`, per the core header.
- Hand-maintained copies are:
  - `adapters/codex/agents-md-fragment.md`
  - `adapters/cursor/rules/persona-protocol.mdc`
  - `adapters/codex/agents/{reviewer,orchestrator}.toml`
  - `adapters/cursor/agents/{reviewer,orchestrator}.md`

  `tests/adapter-protocol-parity.test.js` checks the two protocol ports only
  through literal probes. A new clause needs a new probe in the same unit.
- `task-gate.sh`, `dispatch-hygiene.sh`, `human-decision-gate.sh` and
  `session-start.sh` have no adapter ports.

**Version stamping.** `hooks/scripts/version-stamp-check.sh` treats only
`agents/*.md` and `templates/*` as version-stamped. Even so, `--update` does
nothing when the version is unchanged (it prints "already current"). Every
unit therefore follows the order **bump version in `.claude-plugin/plugin.json`
and `package.json` → CHANGELOG entry → `node bin/cli.js --update` → commit**.
The bump, the CHANGELOG entry and the content change go in the same commit
(constitution P3 v1.1.0, which is checked per commit). Take the next patch
version from the tree when the unit runs. Do not hard-code it.

**Canonical resolution rule.** It is used identically at every consumer. Hook
consumers use this literal expression:

    [ "$(jq -r '.reviewGating.mode // "enforce"' "$config" 2>/dev/null || echo enforce)" = "off" ]

- Only the exact string `off` disables review gating.
- An absent key, a missing config, invalid JSON, or any other value (junk
  included) resolves to `enforce`. This fails toward enforcement.
- Persona prose states the same rule in words.

This follows the item18-1 FAIL (`.claude/reviewed/item18-1-add-config-field.fail`).
In that case the prose, the schema and the code disagreed about how an
unrecognised value resolves. Here, one test fixture matrix asserts that every
consumer agrees.

**Prior defect history.** These `.fail` records are relevant, and all of them
already have a later `.pass`:

- item18-1: disagreement about unrecognised-value fallback. The resolution
  rule above and the four-value test matrix address it.
- reviewer-changes-examples-lean-2 and item17-1/3/4: missing version bump.
- item19-3: registration gap, where a new test was not wired into
  `validate.sh`.

Every unit below therefore requires registration in `validate.sh` and the
bump-then-update order. No earlier unit touched this feature, so no escalated
unit is being re-scoped. `bin/marker-audit.sh --notes` was not run this
session; the dispatcher should run it for each surface before dispatch. The
sweep is best-effort, and an empty sweep proves nothing.

**Draft ADR.** For `scribe` to number and land. Re-derive the number when the
unit runs; the next free number today is 0038.

> **ADR-00NN: Review gating is a runtime switch (`reviewGating.mode`), not a
> fork.** Context: operators want a fast mode without the reviewer-marker
> ceremony. Alternatives were a permanent `gateless` branch (two products to
> maintain), spec 6's CI-shaped replacement (never executed; it also disarmed
> `protected-paths.sh`), and a runtime key. Decision: reuse spec 6's reserved
> `reviewGating.mode` key with `enforce|off`, absent resolving to `enforce`.
> `off` demotes the reviewer to advisory and makes the review-enforcement and
> escalation gates inert. The protection gates (`protected-paths.sh`,
> `harness-integrity-gate.sh`, `reviewed-path-gate.sh`) and config-drift
> detection stay armed. The switch is flipped only through the
> human-confirmed Edit path. This supersedes spec 6 D0's exemption list and
> its `warn` value. Consequence: CONTEXT.md's "Writer/Reviewer split"
> statement ("enforced mechanically") becomes conditional on `enforce`.

**Draft glossary entries.** For `scribe`, Step 5. `CONTEXT.md` was not edited
in this session because the caller's boundary forbids edits outside this
document.

- **review gating off** (alias for users: *gateless mode*) — the project state
  where `reviewGating.mode` is exactly `off`. Reviewer verdicts are advisory,
  and the review-enforcement and escalation gates are inert. The protection
  gates stay armed. _Avoid_: "gateless" in technical prose, because some gates
  stay armed.
- **advisory verdict** — the reviewer's verdict under review gating off. It is
  returned to the orchestrator, recorded in no marker, and blocks nothing. It
  is distinct from the **advisory-reviewer axis**: that axis is about a
  *second* reviewer with no verdict. An advisory verdict is the *only*
  reviewer's verdict, and it is non-binding. _Avoid_: "advisory reviewer" for
  this meaning.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-09-29 Functional scope & success criteria: Q Which parts of the mixed
  hooks (reviewer-route-gate identity guards, stop-gate test+lint and
  config-drift) go inert, and what does the orchestrator do after an advisory
  FAIL? → A: pending; Open Questions 2 and 3 (defaults: keep the non-review
  parts; keep the fix loop and continue at the cap)
- 2026-09-29 Functional scope & success criteria: Q (Open Question 2) How far
  does dropping human escalation go? → A: option B, per the human. ESCALATE
  machinery is dropped and `human-decision-gate.sh` is inert. The fix loop
  stays; at a unit's second advisory FAIL the orchestrator lists the
  remaining defects in its report and carries on, with no human stop.
- 2026-09-29 Functional scope & success criteria: Q (Open Question 3) Which
  parts of the mixed hooks stay armed? → A: per the human, all three stay on:
  the reviewer-dispatch identity guards, stop-gate's test+lint check, and the
  config-drift block.
- 2026-09-29 Functional scope & success criteria: Q (Open Question 4) How
  does scribe close issues when review gating is off? → A: per the human,
  scribe closes an issue when the dispatch quotes the reviewer's PASS verdict
  line verbatim, with a closing comment labelled "advisory PASS".
- 2026-09-29 Domain entities / data model: Q New `gateMode` key, or the
  reserved `reviewGating.mode`? → A: pending; Open Question 1 (default: reuse
  `reviewGating.mode`, `enforce|off`)
- 2026-09-29 Domain entities / data model: Q (Open Question 1) Which key
  name? → A: `reviewGating.mode` with `enforce|off`, per the human. The slash
  command stays `/antislop:gate on|off`.
- 2026-09-29 User interaction flow: Q How does the slash command flip a file
  that agents cannot write? → A (self-resolved): the main session `Edit`s it,
  which triggers the harness-integrity-gate human-confirmation ask. No CLI
  write path. The human commits the config and starts a new session so
  config-drift clears. npx-route projects, which get no plugin commands, edit
  the file by hand.
- 2026-09-29 Non-functional attributes (perf, security, scale): Q Can an agent
  switch off its own review, and what does the extra config read cost? → A
  (self-resolved): no. Set A blocks Bash, subagent Write/Edit is denied, and
  the plan adds no CLI flag. Config-drift detection stays armed in both
  modes. Latency: at most one `jq` per consumer per invocation, bounded by
  `tests/hook-latency-budget.test.sh`, which already runs in `validate.sh`.
- 2026-09-29 Edge cases / failure handling: Q What happens to pending-review
  flags, markers or packets that already exist when the mode flips, and to
  junk values? → A (self-resolved): they are ignored, never deleted, and
  apply again if the mode goes back to `enforce`. The slash command warns
  about standing flags and undecided packets. Junk, absent, or unreadable
  values resolve to `enforce`.
- 2026-09-29 Technical constraints & tradeoffs: Q Should the gating logic go
  in a shared lib or inline? → A (self-resolved): inline the canonical
  expression at each consumer, following the `dispatchHygiene.mode` and
  `markerCommitCheck.mode` precedent. A new lib would add five copies and
  fileHashes entries. Agreement between consumers is proven by one fixture
  matrix. For stop-gate and route-gate, the logic goes in the core libs so
  the codex and cursor ports inherit it.
- 2026-09-29 Terminology consistency: Q Are "gateless" and "advisory reviewer"
  accurate? → A (self-resolved): no. Canonical terms are "review gating off"
  and "advisory verdict"; see the draft glossary entries.
- 2026-09-29 Completion / acceptance signals: Q What proves the feature is
  done? → A (self-resolved): a new fixture-driven
  `tests/review-gating-off.test.sh` registered in `tests/validate.sh`. It
  covers the {`off`, `enforce`, absent, junk} matrix per hook, and the
  per-step criteria below all run through it.

## Risks and dependencies

- **R1 — Units run in order.** Hooks first (Steps 1-2), then prose (Step 4).
  If the prose landed first, a reviewer told to skip markers would be blocked
  by a stop-gate that still demands them. In the reverse order, a reviewer
  writes markers nobody checks, which is harmless.
- **R2 — Stale-packet window.** Suppose a packet exists under `enforce` plus
  `critical`, and the human flips to `off`. `human-decision-gate.sh` is then
  inert, so an agent could write `DECISION`. If the human later flips back,
  the reviewer would honour it. Mitigation (Step 3): the slash command lists
  undecided packets and tells the human to resolve them before switching off.
  The human chose option B for Open Question 2, which accepts this residual
  window; option C, which would have closed it, was declined.
- **R3 — Drift friction.** Every flip, including off→enforce, shows as
  config-drift until the change is committed and a new session starts. This
  is accepted, because it is the tamper signal. The slash command's output
  states it.
- **R4 — Latency budget.** `tests/hook-latency-budget.test.sh` must stay
  green. Read the key only inside the branches that need it.
- **R5 — Loss of durable history under `off`.** No `.fail` records are
  written, so `task-master`'s Implementer-tier ratchet and spec-master's
  prior-FAIL screen see nothing. This is accepted and documented in Step 4's
  prose.
- **R6 — This repo stays `enforce`.** It has no key, which resolves to
  `enforce`. The units themselves run under full gating. The hooks that
  actually fire here are the installed plugin snapshot's, not
  `hooks/scripts/`.
- **R7 — Protocol-matrix forcing.** Adding a `## ` section to
  `templates/persona-protocol.md` would force a per-persona decision in
  `bin/cli.js` `PROTOCOL_SECTIONS_BY_PERSONA` and in the parity maps. Step 4
  avoids that by adding a paragraph inside the existing "Review ownership —
  one unit, one review, single owner" section. That section already reaches
  the orchestrator, lead-programmer and reviewer.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every step's criteria are runnable
  commands, and the fixture matrix asserts both directions.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. All
  mirrors, adapter core copies and fileHashes are regenerated by `node
  bin/cli.js --update` (`--force-render` where the core header says so),
  never hand-edited. No new hand-edit path is added.
- P3 "Version-stamp discipline": satisfied. Every unit bumps
  `.claude-plugin/plugin.json` and `package.json` and adds a CHANGELOG entry
  in the same commit as its content change, checked per commit by
  `version-stamp-check.sh`.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. The new
  prose keeps conditional phrasing ("if `reviewer` is present"). With no
  reviewer selected, `off` changes nothing about verdicts.
- P5 "`tests/validate.sh` is the merge gate": satisfied. The new test is
  registered in `validate.sh`, and every step ends with `bash
  tests/validate.sh` exiting 0.

## Step 1 — Config key and the core review gates (unit `rgo-1`)

Affected files:

- `templates/persona-config.schema.json`: add a `reviewGating` object with
  `mode` enum `["enforce","off"]`, default `"enforce"`, and a description that
  states the resolution rule.
- `hooks/scripts/lib/stop-gate-core.sh`
- `hooks/scripts/lib/reviewer-route-gate-core.sh`
- new `tests/review-gating-off.test.sh`
- `tests/validate.sh` (registration)
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`
- generated by `--update`: the `.claude/hooks/scripts/lib/` mirrors,
  `adapters/{codex,cursor}/hooks/scripts/lib/{stop-gate-core,reviewer-route-gate-core}.sh`,
  and the `.claude/persona-config.json` fileHashes

Behaviour under `off` is as listed in the hook inventory table: stop-gate
reviewer-join, main-Stop flag block and flag write inert; route-gate
exclusivity block and stamps inert. Everything else is unchanged.

Acceptance criteria:
- `jq -e '.properties.reviewGating.properties.mode.enum == ["enforce","off"] and .properties.reviewGating.properties.mode.default == "enforce"' templates/persona-config.schema.json` exits 0.
- `bash tests/review-gating-off.test.sh` exits 0. It must assert all of the
  following, using fixture project dirs in the `tests/stop-gate-escalated.test.sh`
  style:
  - (a) Under `off`, a gated `lead-programmer` SubagentStop creates no
    `.claude/.pending-review.*`.
  - (b) Under `off`, a main-session `Stop` with a standing
    `.pending-review.x` flag exits 0.
  - (c) Under `off`, a reviewer SubagentStop with a `.review-join.<unit>`
    stamp and no marker exits 0.
  - (d) Under `off`, a lead-programmer Agent dispatch with a standing flag
    exits 0 through `hooks/scripts/reviewer-route-gate.sh` and writes no
    `.review-join.*`.
  - (e) Under `off`, a `lead-programmer` Agent dispatch that targets
    `reviewer` still exits 2 (identity guard kept).
  - (f) Cases a, b, c and d each re-run with the mode `enforce`, the key
    absent, and the junk value `"OFF "`. Every one of them reproduces
    today's blocking behaviour: exit 2 or flag written.
  - (g) Under `off`, a gated SubagentStop whose `testAndLintCommand` is
    `false` still exits 2 (test+lint kept).
- `grep -c 'review-gating-off.test.sh' tests/validate.sh` prints ≥1.
- `cmp hooks/scripts/lib/stop-gate-core.sh adapters/codex/hooks/scripts/lib/stop-gate-core.sh && cmp hooks/scripts/lib/stop-gate-core.sh adapters/cursor/hooks/scripts/lib/stop-gate-core.sh && cmp hooks/scripts/lib/reviewer-route-gate-core.sh adapters/codex/hooks/scripts/lib/reviewer-route-gate-core.sh && cmp hooks/scripts/lib/reviewer-route-gate-core.sh adapters/cursor/hooks/scripts/lib/reviewer-route-gate-core.sh` exits 0.
- `git grep -c 'reviewGating.mode // "enforce"' -- hooks/scripts/lib/stop-gate-core.sh hooks/scripts/lib/reviewer-route-gate-core.sh` reports ≥1 for each file.
- `bash tests/adapter-stop-gate-parity.test.sh`, `node tests/filehashes-currency.test.js`, and `bash tests/validate.sh` each exit 0.
- `git diff --name-only HEAD~1 -- .claude-plugin/plugin.json CHANGELOG.md package.json | wc -l` prints 3.

## Step 2 — Claude-only gates: task-gate, H3, human-decision-gate (unit `rgo-2`)

Affected files:

- `hooks/scripts/task-gate.sh`: exit 0 under `off`, after
  `harness_arm_or_deny`.
- `hooks/scripts/dispatch-hygiene.sh`: skip H3 under `off`. H1, H2, H4 and
  the audit line still run.
- `hooks/scripts/human-decision-gate.sh`: exit 0 under `off`. It sets
  `config="${CLAUDE_PROJECT_DIR:-.}/.claude/persona-config.json"` itself.
- `tests/review-gating-off.test.sh` (extend)
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`
- generated `.claude/hooks/scripts/` mirrors and fileHashes

Acceptance criteria:
- `bash tests/review-gating-off.test.sh` exits 0, including new cases:
  - (h) Under `off`, a TaskCompleted payload for `impl:x` with no marker
    exits 0; under `enforce`, absent and junk it exits 2.
  - (i) Under `off`, a dispatch whose first line is `Unit: u1`, with
    `.claude/reviewed/u1.pass` present, gets no H3 block when
    `dispatchHygiene.mode` is `block`; under `enforce` it does.
  - (j) Under `off`, a dispatch-audit.log line is still appended for that
    dispatch.
  - (k) Under `off`, a Bash `printf approve > .claude/human-review/u1/DECISION`
    exits 0; under `enforce`, absent and junk it exits 2.
- `bash tests/human-decision-gate.test.sh`, `bash tests/dispatch-hygiene.test.sh`, `bash tests/task-gate.test.sh` each exit 0. These are the unchanged enforce-mode suites.
- `git grep -c 'reviewGating.mode // "enforce"' -- hooks/scripts/task-gate.sh hooks/scripts/dispatch-hygiene.sh hooks/scripts/human-decision-gate.sh` reports ≥1 for each file.
- `bash tests/hook-latency-budget.test.sh` and `bash tests/validate.sh` exit 0.
- The same bump/CHANGELOG `git diff` check as Step 1 prints 3.

## Step 3 — Operator surfaces: banner, slash command, installer, README (unit `rgo-3`)

Affected files:

- `hooks/scripts/session-start.sh`: when the effective mode is `off`, print
  one line to its report containing the literal `review gating: off`.
- new `commands/gate.md` (`/antislop:gate off|on`, where on means `enforce`).
  The prose instructs the main session to:
  - (1) read the current value and state it;
  - (2) list standing `.claude/.pending-review.*` flags and undecided
    `.claude/human-review/*/` packets, which covers R2;
  - (3) apply the change with the `Edit` tool only, never Bash, never
    `bin/cli.js`, and state that a human-confirmation prompt will appear;
  - (4) tell the human to commit `.claude/persona-config.json` themselves and
    start a new session, and explain the config-drift block they will see
    until then (R3);
  - (5) say that the command does nothing from a subagent or under a
    permission mode where the gate denies.
- `skills/install-antislop/SKILL.md` step 6: one AskUserQuestion for review
  gating, `enforce` listed first as the recommended option. Write
  `reviewGating.mode` only when the answer is `off`; `enforce` is the absent
  default.
- `README.md`: a section headed "Review gating off (gateless mode)" that
  states what stays armed.
- `tests/review-gating-off.test.sh` (extend)
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`
- generated mirror and fileHashes

Acceptance criteria:
- `bash tests/review-gating-off.test.sh` exits 0, including case (l): the
  session-start output contains `review gating: off` under `off`, and does
  not contain it under `enforce` or absent.
- `test -f commands/gate.md && grep -c 'Edit' commands/gate.md` prints ≥1.
- `grep -cE 'bin/cli\.js|> *\.claude/persona-config' commands/gate.md` prints `0`, meaning no CLI or Bash write route is offered.
- `grep -c 'reviewGating' skills/install-antislop/SKILL.md` prints ≥1.
- `grep -c 'Review gating off' README.md` prints ≥1.
- `grep -c 'protected-paths' README.md` prints ≥1.
- `bash tests/validate.sh` exits 0, and the bump/CHANGELOG check prints 3.

## Step 4 — Persona prose and every hand-synced copy (unit `rgo-4`)

One unit, because the parity test spans source and ports. Per spec-master
memory, a source edit is never sliced apart from its shipped copy.

Affected files:

- `templates/persona-protocol.md`: a paragraph at the end of "## Review
  ownership — one unit, one review, single owner" that opens with the literal
  sentence `When reviewGating.mode is off (review gating off)`. It states:
  - the resolution rule;
  - advisory verdicts, with no markers of any kind (`.pass`, `.fail`,
    `.blocked`, `.escalated`);
  - no ESCALATE-TO-HUMAN;
  - that pending-review, task-gate, H3 and human-decision-gate are inert;
  - which gates stay armed;
  - R5.
- `agents/orchestrator.md` "Review routing" section:
  - under `off`, still dispatch the reviewer with `Unit: <task-id>`;
  - treat the verdict as advisory;
  - on an advisory FAIL, route the defects back to lead-programmer exactly
    as today, counting advisory FAILs per unit in-session (there are no
    `.fail` records). At the second advisory FAIL, do **not** stop for the
    human: list the remaining defects under a heading containing the literal
    `Unresolved advisory findings` in the report, and move on to the next
    unit;
  - no marker checks before the milestone audit gate.
- `agents/reviewer.md`:
  - under `off`, return the verdict and findings only;
  - do not run any marker write;
  - never return ESCALATE-TO-HUMAN (effective `humanReviewMode` is `off`);
  - INSUFFICIENT-CONTEXT may still be returned as an advisory word, with no
    `.blocked` marker.
- `agents/scribe.md` "Issue closing" section: under `off`, the PASS-marker
  condition is replaced by "the dispatch quotes the reviewer's PASS verdict
  line verbatim". The closing comment cites that line and carries the literal
  label `advisory PASS (review gating off)`. The other three conditions and
  every never-close rule still apply, with an advisory FAIL taking the place
  of the `.fail` marker.
- `adapters/codex/agents-md-fragment.md`
- `adapters/cursor/rules/persona-protocol.mdc`
- `adapters/codex/agents/{reviewer,orchestrator}.toml`
- `adapters/cursor/agents/{reviewer,orchestrator}.md`
- `tests/adapter-protocol-parity.test.js`: add the probe `reviewGating.mode
  is off` to the Review-ownership row for both ports.
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`
- generated `.claude/agents/*.md`, `.claude/persona-protocol*.md`,
  `.claude/protocol-digest.md`, fileHashes

Acceptance criteria:
- `git grep -l 'reviewGating.mode is off' -- templates/persona-protocol.md agents/orchestrator.md agents/reviewer.md agents/scribe.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc adapters/codex/agents/reviewer.toml adapters/codex/agents/orchestrator.toml adapters/cursor/agents/reviewer.md adapters/cursor/agents/orchestrator.md | wc -l` prints `10`.
- `grep -c 'reviewGating.mode is off' .claude/agents/reviewer.md .claude/agents/orchestrator.md .claude/agents/lead-programmer.md` shows ≥1 for each. This proves the paragraph survives protocol trimming. It is claim-anchored, not an existence grep of the template alone.
- Branch-agreement check: `git grep -n -A3 'reviewGating.mode is off' -- agents/reviewer.md agents/orchestrator.md templates/persona-protocol.md | grep -c 'only the exact'` prints ≥3. Each of the three restates the exact-`off` rule.
- `node tests/adapter-protocol-parity.test.js` exits 0. Mutation proof: delete the paragraph from `adapters/cursor/rules/persona-protocol.mdc`, and the test must exit non-zero. The reviewer runs this.
- Claim-anchored orchestrator check: `git grep -c 'Unresolved advisory findings' -- agents/orchestrator.md` prints ≥1. `git grep -n -B2 -A8 'reviewGating.mode is off' -- agents/orchestrator.md | grep -ci 'second advisory FAIL'` prints ≥1.
- Claim-anchored scribe check: `git grep -c 'advisory PASS (review gating off)' -- agents/scribe.md` prints ≥1.
- Claim-anchored reviewer check: `git grep -n -A8 'reviewGating.mode is off' -- agents/reviewer.md | grep -c 'ESCALATE-TO-HUMAN'` prints ≥1. That sentence must forbid the verdict under `off`; the reviewer reads it to confirm.
- `bash tests/validate.sh` exits 0, the bump/CHANGELOG check prints 3, and `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD` exits 0.

## Step 5 — Institutional record (unit `rgo-5`, scribe)

Affected files:

- `CONTEXT.md`:
  - add the two draft glossary entries above;
  - amend "The Writer/Reviewer split" to make it conditional on `enforce`;
  - amend "humanReviewMode" to note that `off` overrides it.
- `docs/adr/00NN-review-gating-runtime-switch.md`: the draft ADR above.
- `docs/harness-glossary.md` "disarm surface": the key is live, with values
  `enforce|off`, and spec 6's `warn` was not adopted.
- `docs/plans/2026-08-25-ci-shaped-review-architecture-d.md`: a dated
  superseded-D0 note, append-only.

Acceptance criteria:
- `grep -c '^\*\*review gating off\*\*' CONTEXT.md` prints 1.
- `grep -c '^\*\*advisory verdict\*\*' CONTEXT.md` prints 1.
- `ls docs/adr | grep -c 'review-gating-runtime-switch'` prints 1.
- `grep -c 'reviewGating.mode' docs/adr/*review-gating-runtime-switch.md` prints ≥1.
- The claim-anchored check `git grep -n -A6 '^\*\*The Writer/Reviewer split\*\*' CONTEXT.md | grep -c 'reviewGating'` prints ≥1.
- `node tests/context-glossary-links.test.js`, `node tests/ubiquitous-language.test.js`, and `bash tests/validate.sh` exit 0.

## Open Questions

None open. Round 1 was resolved by the human on 2026-09-29, and every answer
took the recommended default:

1. The key is `reviewGating.mode` (`enforce|off`), and the command is
   `/antislop:gate on|off`.
2. Option B. Escalation is dropped entirely and `human-decision-gate.sh` is
   inert. The fix loop stays. At the second advisory FAIL, the orchestrator
   lists the remaining defects and carries on. R2's residual window is
   accepted.
3. The reviewer-dispatch identity guards, stop-gate's test+lint check and the
   config-drift block all stay armed.
4. Scribe closes an issue on a quoted reviewer PASS line, with a closing
   comment labelled `advisory PASS (review gating off)`.

## Self-check
- CHK1: Is every Goal clause G1-G7 mapped to a step criterion?
  - G1 → Step 1 (a-d) and Step 4.
  - G2 → Steps 1-2.
  - G3 → Step 2 (k) and Step 4.
  - G4 → no step touches `protected-paths.sh`; Step 3's README criterion.
  - G5 → Step 3.
  - G6 → Step 4.
  - G7 → the absent-key cases in (f), (h), (i), (k) and (l).

  — PASS
- CHK2: Do Steps 1, 2 and 4 agree on the resolution rule (exact `off`,
  everything else `enforce`)? — FAIL (conflicting): a draft of Step 4 said
  "`off` or `gateless`". Revised in place.
- CHK3: Is the flip mechanism defined so that no agent can use it? — PASS
  (Context, Step 3 criterion forbidding `bin/cli.js`).
- CHK4: Is behaviour defined for flags and packets that already exist when
  the mode flips? — PASS (Clarifications edge-cases line, R2, Step 3 item 2).
- CHK5: Is the orchestrator's advisory-FAIL handling defined? — FAIL
  (missing): converted to Open Question 2. The human answered it (B), and
  it has been revised in place in Step 4 with a claim-anchored criterion.
- CHK6: Is which parts of the mixed hooks stay armed defined? — FAIL
  (ambiguous): converted to Open Question 3. The human answered it (keep
  all), and it has been revised in place in the inventory table and in Step
  1 criteria (e) and (g).
- CHK7: Is scribe's issue-closing behaviour under `off` defined? — FAIL
  (missing): converted to Open Question 4. The human answered it, and it has
  been revised in place in Step 4 with a scribe criterion.
- CHK8: Is the config key name settled? — FAIL (conflicting; the reserved key
  and the human's example differ): converted to Open Question 1. The human
  answered it (`reviewGating.mode`), so every step's literals stand as
  written.
- CHK9: Does every unit that edits a hook or a stamped path carry a
  bump/CHANGELOG criterion in the bump→CHANGELOG→`--update` order? — PASS
  (Steps 1-4; Step 5 touches no stamped path).
- CHK10: Is each constitution MUST principle mapped? — PASS.
- CHK11: Is the new test wired into `validate.sh`, given the item19-3 history?
  — PASS (Step 1 criterion).

Advisory prose-mode `ubiquitous-language` pass on this draft, with no effect
on handoff:

- lens 1: "advisory reviewer" is overloaded, which the draft entry resolves.
- lens 2: "gateless" is a synonym of "review gating off".
- lens 3: "advisory verdict" is a new term, now drafted.

## Scribe update hint

Step 5 is the scribe unit. After Steps 1-4 land, also add a wiki note that
this repo stays on `enforce`, and that "gateless" is the user-facing alias
only.

## Dispatch (fast path — 5 units, no task-master)

The plan is not published through `to-spec`, because it is below the publish
threshold. Retrieval for every unit is this document,
`docs/plans/2026-09-29-gateless-mode.md`. There is no tracker issue, so
scribe's issue-closing duty does not fire for these units.

Order: `rgo-1` → `rgo-2` → `rgo-3` → `rgo-4` → `rgo-5`. The order is
strictly sequential. Every unit edits the shared test file or the version
files, and R1 requires the hooks to land before the prose. Each unit goes
through the normal reviewer PASS before the next one is dispatched. This
repo runs with gating on (`enforce`).

### Pre-dispatch step (orchestrator, once, before `rgo-1`)

1. Run the note sweep over every surface this plan touches, one call per
   path, from the repo root:

   ```
   for s in templates/persona-config.schema.json hooks/scripts/lib/stop-gate-core.sh hooks/scripts/lib/reviewer-route-gate-core.sh hooks/scripts/task-gate.sh hooks/scripts/dispatch-hygiene.sh hooks/scripts/human-decision-gate.sh hooks/scripts/session-start.sh commands skills/install-antislop/SKILL.md README.md templates/persona-protocol.md agents/orchestrator.md agents/reviewer.md agents/scribe.md adapters/codex adapters/cursor tests/adapter-protocol-parity.test.js tests/validate.sh CONTEXT.md docs/harness-glossary.md; do bash bin/marker-audit.sh . --notes --surface="$s"; done
   ```

2. For each `NOTE[spec]` line, and each `untagged` line naming an
   undispatched step, append it to the matching unit's "Pre-resolved
   context" when you dispatch that unit. Add a one-line disposition: fold it
   in, or explain why it doesn't apply.
3. If any note contradicts a step, stop and route it back to spec-master
   before dispatching. An empty sweep is not proof that no note exists,
   because the marker directory is untracked per-clone state.

### Unit: rgo-1

Suggested model: opus. This unit changes the core security-relevant gate
logic, and the libs are shared byte-for-byte with the adapters.

## Objective
Add `reviewGating.mode` (`enforce|off`, absent → `enforce`) to the config
schema. When the mode is exactly `off`, make stop-gate's reviewer-join
verdict block, stop-gate's main-Stop pending-review block, stop-gate's
pending-review flag write on gated SubagentStop, reviewer-route-gate's
unit-exclusivity block, and its `.review-join.*` stamping inert. Everything
else in both hooks stays unchanged. That includes the microworld block, the
WIP sentinel, the config-drift block, test+lint, the identity guards, and the
privileged-name guard.

## Retrieval
`docs/plans/2026-09-29-gateless-mode.md`, sections "Context" (hook inventory
table, canonical resolution rule, Copies, Version stamping) and "Step 1".

## Affected files
- `templates/persona-config.schema.json`
- `hooks/scripts/lib/stop-gate-core.sh`
- `hooks/scripts/lib/reviewer-route-gate-core.sh`
- `tests/review-gating-off.test.sh` (new)
- `tests/validate.sh`
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`
- Generated only, never hand-edited:
  - `.claude/hooks/scripts/lib/{stop-gate-core,reviewer-route-gate-core}.sh`
  - `adapters/{codex,cursor}/hooks/scripts/lib/{stop-gate-core,reviewer-route-gate-core}.sh`
  - `.claude/persona-config.json` `fileHashes`

## Ordered edits
1. Write `tests/review-gating-off.test.sh` first (red), with cases (a)-(g)
   from Step 1. Use the fixture-dir style of `tests/stop-gate-escalated.test.sh`.
   Register it in `tests/validate.sh` next to the other stop-gate suites.
2. Schema: add a top-level `reviewGating` object with property `mode`:
   `enum ["enforce","off"]`, `default "enforce"`. The description must say
   "only the exact string off disables; absent, unreadable or any other value
   resolves to enforce". Do not add it to `required`.
3. In both core libs, read the mode with the canonical expression, verbatim:
   `[ "$(jq -r '.reviewGating.mode // "enforce"' "$config" 2>/dev/null || echo enforce)" = "off" ]`.
   Read it only inside the branches it governs (R4 latency). In
   `stop-gate-core.sh`:
   - at `:334`, the reviewer SubagentStop branch allows when `off`;
   - at `:501`, the main-Stop pending-flag branch is skipped when `off`;
   - at `:583-585`, the flag write is skipped when `off`.

   In `reviewer-route-gate-core.sh`:
   - the pending-flag block at `:30-50` is skipped when `off`;
   - the whole `Unit:` stamping branch at `:69-150` is skipped when `off`.
   - The identity-drift log call and the privileged-name guard at `:54-66`
     run unchanged.
4. Bump the next patch version in both `.claude-plugin/plugin.json` and
   `package.json` (they must be equal). Add a CHANGELOG entry. Run `node
   bin/cli.js --update --force-render`, and confirm it does not print
   "already current".
5. Run all criteria, then make one commit containing the content, bump,
   CHANGELOG and regenerated files.

## Do NOT touch
- `bin/harness-integrity.sh`. It already normalizes `reviewGating.mode` with
  default `enforce`.
- The config-drift block (`stop-gate-core.sh:601-640`), test+lint
  (`:646-665`), and the microworld block (`:64-90`).
- The Claude entry script `hooks/scripts/reviewer-route-gate.sh`'s identity
  guards.
- `protected-paths.sh`, `harness-integrity-gate.sh`, `reviewed-path-gate.sh`.
- Any adapter or `.claude/` copy by hand.
- `.claude/persona-config.json` values other than the fileHashes that
  `--update` writes. Do not add the key to this repo's config.

## Acceptance criteria
- `jq -e '.properties.reviewGating.properties.mode.enum == ["enforce","off"] and .properties.reviewGating.properties.mode.default == "enforce"' templates/persona-config.schema.json` exits 0.
- `bash tests/review-gating-off.test.sh` exits 0, covering cases (a)-(g) from
  Step 1. Cases a-d must also be run with `enforce`, absent, and
  `"OFF "`, and must block in each.
- `grep -c 'review-gating-off.test.sh' tests/validate.sh` ≥ 1.
- The four `cmp` commands in Step 1 exit 0.
- `git grep -c 'reviewGating.mode // "enforce"' -- hooks/scripts/lib/stop-gate-core.sh hooks/scripts/lib/reviewer-route-gate-core.sh` ≥ 1 per file.
- `bash tests/adapter-stop-gate-parity.test.sh`, `node tests/filehashes-currency.test.js`, and `bash tests/validate.sh` exit 0.
- `git diff --name-only HEAD~1 -- .claude-plugin/plugin.json CHANGELOG.md package.json | wc -l` prints 3.

## Pre-resolved context
- `reviewGating.mode` is already a disarm-surface field
  (`bin/harness-integrity.sh:106`), so a flip to `off` is detected as
  config-drift. That is intended.
- The core-lib header (`reviewer-route-gate-core.sh:1-6`) says the adapter
  copies are generated by `--update --force-render`.
- Constitution P3 is checked per commit. The item18-1 FAIL was an
  unrecognised-value disagreement, which is why the junk-value case is
  mandatory.
- Any `NOTE[spec]` lines from the pre-dispatch sweep go here.

## Escalation
If `--update` prints "already current", the bump did not land. Stop and
report; do not work around it. If the fixture harness cannot reach a case
because `harness_arm_or_deny` refuses the fixture, report it with the refusal
text; do not stub the arm check out. If any criterion looks unsatisfiable as
written, report to the orchestrator for spec-master. Do not reinterpret it.

### Unit: rgo-2

Suggested model: opus. `human-decision-gate.sh` is a 352-line lexer-based
gate with a long FAIL history. The edit is small, but the surrounding code is
easy to break.

## Objective
When `reviewGating.mode` is exactly `off`:
- `task-gate.sh` exits 0;
- `dispatch-hygiene.sh` skips H3 but still runs H1, H2, H4 and the
  dispatch-audit line;
- `human-decision-gate.sh` exits 0.

Behaviour under `enforce`, an absent key, or junk is byte-for-byte unchanged.

## Retrieval
`docs/plans/2026-09-29-gateless-mode.md`, "Context" and "Step 2".

## Affected files
- `hooks/scripts/task-gate.sh`
- `hooks/scripts/dispatch-hygiene.sh`
- `hooks/scripts/human-decision-gate.sh`
- `tests/review-gating-off.test.sh`
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`
- generated `.claude/hooks/scripts/{task-gate,dispatch-hygiene,human-decision-gate}.sh` and fileHashes

## Ordered edits
1. Extend `tests/review-gating-off.test.sh` with cases (h)-(k) from Step 2
   (red).
2. `task-gate.sh`: after `harness_arm_or_deny` and the `[ -f "$config" ]`
   guard, exit 0 when the canonical expression is true.
3. `dispatch-hygiene.sh`: wrap only the H3 block (`:303-354`) in the
   canonical check. The audit write and H1/H2/H4 stay outside it.
4. `human-decision-gate.sh`: define
   `config="${CLAUDE_PROJECT_DIR:-.}/.claude/persona-config.json"`. Right
   after `input="$(cat)"` (`:57`), exit 0 when the canonical expression is
   true. Add a header line stating that this is the gate's only config read
   and why.
5. Bump, CHANGELOG, `node bin/cli.js --update`, run the criteria, then make
   one commit.

## Do NOT touch
- `human-decision-gate.sh`'s lexer, `is_sanctioned_marker_write()`, or any
  other branch.
- The H1/H2/H4 logic, `dispatchHygiene.*` reads, and `requireContract`
  handling.
- `task-gate.sh`'s marker validation under `enforce`.
- The files from rgo-1.
- `docs/adr/0036-*` (scribe amends the record in rgo-5 if needed).

## Acceptance criteria
- `bash tests/review-gating-off.test.sh` exits 0, including (h)-(k) under
  `off`, `enforce`, absent and junk.
- `bash tests/human-decision-gate.test.sh`, `bash tests/dispatch-hygiene.test.sh`, and `bash tests/task-gate.test.sh` exit 0.
- `git grep -c 'reviewGating.mode // "enforce"' -- hooks/scripts/task-gate.sh hooks/scripts/dispatch-hygiene.sh hooks/scripts/human-decision-gate.sh` ≥ 1 per file.
- `bash tests/hook-latency-budget.test.sh` and `bash tests/validate.sh` exit 0.
- The bump/CHANGELOG `git diff` check prints 3.

## Pre-resolved context
- `human-decision-gate.sh` currently reads no config. This is its first config
  read, which the human approved (Open Question 2, option B).
- The stale-packet window (R2) is accepted; the rgo-3 slash command warns
  about it.
- None of these three hooks has an adapter port.
- Sweep notes go here.

## Escalation
If any enforce-mode suite changes result, stop. That means a regression, not
a test to update. Report it. The same `--update` "already current" rule as
rgo-1 applies.

### Unit: rgo-3

Suggested model: sonnet. These are operator surfaces with a well-specified
shape.

## Objective
Add the operator surfaces for the mode:
- a `session-start.sh` banner;
- the `/antislop:gate on|off` command, which changes the setting only through
  the main session's `Edit` tool (human-confirmation ask);
- an installer question;
- a README section.

## Retrieval
`docs/plans/2026-09-29-gateless-mode.md`, "Context" (flip mechanism,
config-drift interaction), R2, R3, and "Step 3".

## Affected files
- `hooks/scripts/session-start.sh`
- `commands/gate.md` (new)
- `skills/install-antislop/SKILL.md`
- `README.md`
- `tests/review-gating-off.test.sh`
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`
- generated `.claude/hooks/scripts/session-start.sh` and fileHashes

## Ordered edits
1. Add test case (l) (red).
2. `session-start.sh`: when the canonical expression is true, add a line
   containing `review gating: off` to its report output.
3. `commands/gate.md`: frontmatter `description:` in the style of the other
   files in `commands/`. The body covers items (1)-(5) from Step 3, with
   `on` meaning `enforce`. For `on`, delete the key or set it to `enforce`.
4. Installer step 6: one AskUserQuestion bullet, `enforce` listed first as
   recommended. Write the key only for `off`.
5. README: add a section "Review gating off (gateless mode)" covering what
   goes inert, what stays armed (`protected-paths`, `harness-integrity-gate`,
   `reviewed-path-gate`, config-drift, test+lint), how to flip it, and that
   the human commits the config.
6. Bump, CHANGELOG, `--update`, run the criteria, then make one commit.

## Do NOT touch
- `bin/cli.js`. Add no write path for the key.
- `.claude/persona-config.json` values.
- `harness-integrity-gate.sh`.
- Any persona prose (that is rgo-4).

## Acceptance criteria
- `bash tests/review-gating-off.test.sh` exits 0, including (l).
- `test -f commands/gate.md && grep -c 'Edit' commands/gate.md` ≥ 1.
- `grep -cE 'bin/cli\.js|> *\.claude/persona-config' commands/gate.md` prints 0.
- `grep -c 'reviewGating' skills/install-antislop/SKILL.md` ≥ 1.
- `grep -c 'Review gating off' README.md` ≥ 1.
- `grep -c 'protected-paths' README.md` ≥ 1.
- `bash tests/validate.sh` exits 0, and the bump/CHANGELOG check prints 3.

## Pre-resolved context
- `skills/install-antislop/SKILL.md:318-330` already documents the
  harness-integrity-gate ask branch for writing this file. Reuse its wording.
- Plugin commands are auto-discovered from `commands/`. npx-route projects
  don't get them, so the README must give the manual-edit route.
- Sweep notes go here.

## Escalation
If `session-start.sh`'s output channel for the banner is unclear (stdout
report vs `additionalContext`), match how the existing `humanReviewMode`
microworld message at `:96` is emitted, and say which one you chose in the
ready-for-review report. Otherwise, report blockers.

### Unit: rgo-4

Suggested model: opus. This unit covers ten hand-synced prose surfaces plus a
parity test, and docs units in this repo have repeatedly failed on prose
accuracy.

## Objective
Make every persona surface describe review gating off accurately, so that
personas cooperate with the inert hooks:
- advisory verdicts, with no markers;
- no ESCALATE-TO-HUMAN;
- the orchestrator's fix loop, where the second advisory FAIL lists
  `Unresolved advisory findings` and carries on;
- scribe closing issues on a quoted PASS line, labelled `advisory PASS
  (review gating off)`;
- which gates stay armed;
- the loss of `.fail` history (R5).

## Retrieval
`docs/plans/2026-09-29-gateless-mode.md`, "Context", "Draft glossary
entries", R5, R7, "Step 4", and resolved Open Questions 2 and 4.

## Affected files
- `templates/persona-protocol.md`
- `agents/orchestrator.md`, `agents/reviewer.md`, `agents/scribe.md`
- `adapters/codex/agents-md-fragment.md`
- `adapters/cursor/rules/persona-protocol.mdc`
- `adapters/codex/agents/{reviewer,orchestrator}.toml`
- `adapters/cursor/agents/{reviewer,orchestrator}.md`
- `tests/adapter-protocol-parity.test.js`
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json`
- generated `.claude/agents/*.md`, `.claude/persona-protocol*.md`,
  `.claude/protocol-digest.md`, fileHashes

## Ordered edits
1. Add the parity probe `reviewGating.mode is off` to the Review-ownership
   row for both ports (red).
2. Protocol template: add a paragraph at the end of "## Review ownership —
   one unit, one review, single owner", opening with `When reviewGating.mode
   is off (review gating off)`, with the content listed in Step 4. Do not add
   a new `## ` section (R7).
3. `agents/orchestrator.md` "Review routing": add a paragraph containing
   `reviewGating.mode is off`, the exact-`off` rule ("only the exact string
   `off`"), the advisory-FAIL loop, the second-advisory-FAIL behaviour, and
   the `Unresolved advisory findings` heading.
4. `agents/reviewer.md`: add a paragraph containing `reviewGating.mode is
   off` and the exact-`off` rule. It says no marker writes of any kind, the
   ESCALATE-TO-HUMAN verdict is never returned, INSUFFICIENT-CONTEXT is
   advisory only, and the verdict and findings are returned as usual.
5. `agents/scribe.md` "Issue closing": add the `off` variant from Step 4.
6. Port the same content into the six adapter files, keeping each port's own
   format (toml or md). Include the literal `reviewGating.mode is off` in
   each.
7. Bump, CHANGELOG, `--update`, run the criteria, then make one commit.

## Do NOT touch
- `bin/cli.js` `PROTOCOL_SECTIONS_BY_PERSONA`. No new section means no
  matrix change.
- Hooks.
- `CONTEXT.md` and ADRs (that is rgo-5).
- Generated `.claude/` files by hand.
- Enforce-mode prose, apart from the added conditional paragraphs.

## Acceptance criteria
- All Step 4 criteria:
  - the 10-file `git grep -l` count;
  - the three generated-persona greps;
  - the branch-agreement `only the exact` count ≥ 3;
  - the orchestrator, scribe and reviewer claim-anchored greps;
  - `node tests/adapter-protocol-parity.test.js` exits 0, including the
    mutation proof;
  - `bash tests/validate.sh` exits 0;
  - the bump check prints 3;
  - `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD` exits 0.

## Pre-resolved context
- The "Review ownership" section already reaches the orchestrator,
  lead-programmer and reviewer through the trimmed protocol block. Verify
  with the generated-persona greps.
- The hand-maintained ports are not rendered by `cli.js`. The parity test
  checks only literal probes.
- The "advisory verdict" term must not be confused with the
  advisory-reviewer axis (`Mode: advisory` second-reviewer dispatch). Do not
  use `Mode: advisory` for gateless reviews.
- Sweep notes go here.

## Escalation
If a port has no natural place for the paragraph, add it next to that port's
review-ownership text, and name the location in the ready-for-review report.
If the generated-persona grep fails for lead-programmer because of trimming,
stop and report it. Do not move the text into a new section.

### Unit: rgo-5

Suggested model: sonnet (scribe).

## Objective
Record the institutional side of the change:
- land the glossary entries and the ADR;
- make the Writer/Reviewer split and `humanReviewMode` entries conditional
  on the mode;
- update the harness glossary's disarm-surface entry;
- append a superseded-D0 note to spec 6.

## Retrieval
`docs/plans/2026-09-29-gateless-mode.md`, "Draft ADR", "Draft glossary
entries", and "Step 5".

## Affected files
- `CONTEXT.md`
- `docs/adr/<next-number>-review-gating-runtime-switch.md` (new)
- `docs/harness-glossary.md`
- `docs/plans/2026-08-25-ci-shaped-review-architecture-d.md` (append only)

## Ordered edits
1. Derive the next ADR number from `ls docs/adr`. Increment it; never
   backfill a gap.
2. Write the ADR from the draft, adding the human's 2026-09-29 answers as
   the decision record.
3. Add the CONTEXT.md entries **review gating off** and **advisory verdict**
   (with their `_Avoid_` lines), and amend "The Writer/Reviewer split" and
   "humanReviewMode". Where the `humanReviewMode` entry points to ADR-0036,
   add a note that `human-decision-gate.sh` is now inert under `off`.
4. Update `docs/harness-glossary.md` "disarm surface": the key is live,
   `enforce|off`, and there is no `warn`.
5. Append a dated "Superseded in part (D0) by
   `docs/plans/2026-09-29-gateless-mode.md`" note to spec 6.
6. Run the criteria, then make one commit.

## Do NOT touch
- Code, hooks, agents, templates.
- The existing ADR bodies (append-only pointers at most).

## Acceptance criteria
- All Step 5 criteria:
  - the two CONTEXT.md heading counts;
  - the ADR file and key greps;
  - the Writer/Reviewer claim-anchored grep;
  - `node tests/context-glossary-links.test.js`,
    `node tests/ubiquitous-language.test.js`, and `bash tests/validate.sh`
    exit 0.
- `grep -c 'Superseded in part' docs/plans/2026-08-25-ci-shaped-review-architecture-d.md` ≥ 1.

## Pre-resolved context
- There is no tracker issue (fast path), so issue closing does not apply.
- No version-stamped path is touched, so no bump is needed.
- Sweep notes go here.

## Escalation
If the glossary-links test rejects a new `[[link]]`, rephrase it without the
link rather than editing the test. Report anything else that blocks.

