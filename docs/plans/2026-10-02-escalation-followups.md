# Escalation follow-ups: teammate `agent_id`, probe-script tests, stale pending-review flag

Status: **FINAL** (spec-master, 2026-10-02). The user answered all four Open
Questions on 2026-10-02 and took every recommended default (see
Clarifications). This is the fast path. It started with 5 units, and
Amendment B1 (2026-10-02) adds a sixth, `esf-eid-probe-fix`, and Amendment C1
(2026-10-03) a seventh, `esf-gate-bytes`. Their dispatch contracts are below.
The fast path still applies: the five original units were already dispatched,
and each amendment adds one unit. **The operator must not run `scripts/probe-hook-identity.sh`
until `esf-eid-probe-fix` holds a reviewer PASS.**

Parent plan: `docs/plans/2026-10-01-in-session-escalation-decision.md`. It is
untracked, and this plan does not edit it.

## Goal

Close three gaps that the in-session-escalation work exposed but did not plan:

- **G1.** Measure, without inferring, which identity fields the PreToolUse
  payload carries for the main session, a subagent and an agent-teams
  teammate. Then apply a pre-decided gate action for each possible outcome.
- **G2.** Give `scripts/probe-bash-ask.sh` the regression tests that
  currently exist only in reviewers' scratch directories, run them from
  `tests/validate.sh`, and pin them with mutation controls.
- **G3.** Stop a pending-review flag from outliving every review: a flag
  that comes back after a reviewer cleared it must not block turn-end or the
  next gated dispatch. Pin this with a hermetic regression test, and correct
  the protocol prose, which still claims "clears every such flag".

## Context

### Item 3: root cause, established read-only and reproduced

**Diagnosis: flag resurrection.** A reviewer's bounded clear (gh442 "M3",
`hooks/scripts/lib/stop-gate-core.sh:435-458`) deletes flag file X. The
orchestrator then writes `defer: ...` into X with `printf ... > X`, as
`agents/orchestrator.md:155-161` tells it to do when it dispatches a reviewer.
The redirect **re-creates** X. From then on there is one more flag than there
are unreviewed units, and the later reviews can never bring the count to zero.

Evidence from `.claude/review-audit.log`, lines 10575-10624 (read with the
Read tool; Bash access to that file is Set A):

| time (UTC) | line | meaning |
|---|---|---|
| 17:06:49, 17:09:39 | `grant-denied hook=stop-gate identity=lead-programmer` (x2) | two lead-programmer stops (tidy3 and esc-chat-2), so two flags |
| 17:10:02, 17:14:01 | two `defer:` lines each | the orchestrator rewrote **both** flags in the same second, so their mtimes tie |
| 17:19:16 | `join-consumed=esc-chat-1-tidy3` / `cleared=1 remaining=1` | the tidy3 review clears one flag. That is correct by count, but the flag it picks is decided by a lexical tie-break, not by unit |
| 17:19:38 | two `defer:` lines (`...for esc-chat-2...`, `...for esc-chat-1-tidy3...`) | **two flags exist again**. No `grant-denied identity=lead-programmer` line falls between 17:19:16 and 17:19:38, so no gated agent stopped in that window. The only writer was the orchestrator's `printf` |
| 17:41:48 | `join-consumed=esc-chat-2` / `cleared=1 remaining=1` | one flag is stale and stays standing |
| 17:48:00 | `skip: esc-chat-2 already holds a reviewer PASS ...` | the orchestrator works around it by hand |

**Reproduction.** Run 2026-10-02 against HEAD `8428fab`, in a scratch mktemp
project, using the real `stop-gate.sh` and `reviewer-route-gate.sh`:

```
u1 reviewer stop rc=0 flags=1
cleared by u1 review: lp-a                      <- u2's flag, by tie-break
after orchestrator defer write to lp-a: flags=2 <- resurrection
u2 reviewer stop rc=0 flags=1                   <- stale flag survives
next lead-programmer dispatch rc=2              <- blocked
cleared-by=reviewer cleared=1 remaining=1       (x2, identical to the incident)
```

**Candidate hypotheses from the brief:**

- **(a) The `defer:` rewrite happens after the reviewer's stop.** CONFIRMED.
  This is the mechanism.
- **(b) Several reviewers dispatched one after another, with parallel flags.**
  CONTRIBUTING. Two flags have to exist for bounded clearing to delete the
  "wrong" one. With a single flag, a re-deferred flag would still be
  resurrected, but the orchestrator would only re-defer a flag it believes is
  still owed, which needs a second unit.
- **(c) Review-join / watermark.** RULED OUT. The global watermark
  (`.last-review-clear`) was replaced by per-unit stamps. Both stops logged
  `join-consumed`, and neither logged `marker=MISSING`.
- **(d) Order of the flag rewrite against the reviewer's stop.** This is (a).

**Contributing factor.** The bounded clear treats flags as interchangeable,
because flags are keyed by the lead-programmer's `agent_id` and not by unit.
It clears "oldest by mtime", and a `defer:` rewrite resets mtime, so the
choice falls back to a tie-break on the path. The orchestrator prose assumes
a flag belongs to "its" unit. Nothing in the gate makes that true.

**Protocol prose is stale.** `templates/persona-protocol.md:312` and
`adapters/codex/agents-md-fragment.md:103` both say the reviewer's stop
"clears every such flag". Since gh442 (`0f8f11b`), it clears at most one flag
per satisfied stamp. The zero-stamp bootstrap path still clears all of them.

### Item 1: what is already measured

`docs/experiments/2026-07-probe-hook-payloads.md` contains these captured
payloads:

- **Main session** PreToolUse(Agent): `agent_id` absent, and
  `agent_type: "orchestrator"` when settings `.agent` is set.
- **Subagent** PreToolUse(Bash): `agent_id` present, `agent_type` set.

**Never measured:** a teammate spawned while
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set. With teams enabled, any
named `Agent` dispatch launches as a teammate (`agents/orchestrator.md:623`).
This repo ships the variable as `"0"` (`.claude/settings.json:4`), so
teammates exist only after a deliberate opt-in through
`/antislop:start-feature-team`.

**Blast radius: wider than the brief states.** Three gate sites rely on the
same "empty `agent_id` means main session" or "empty `agent_type` means main
session" premise:

1. `hooks/scripts/human-decision-gate.sh:129`, which guards
   `is_prompt_eligible_decision_write`. This is the brief's case.
2. `hooks/scripts/harness-integrity-gate.sh:127` `ask_allowed`. This gate asks
   for Set A and Set B writes. Same premise, and also reachable by a teammate.
3. `hooks/scripts/reviewer-route-gate.sh:68-71`, the caller allowlist: empty
   `agent_type` is admitted as the main session. If a teammate's `agent_type`
   is empty, that teammate could dispatch the reviewer. That is a different
   failure (dispatch, not ask), and it is recorded here as out of scope; see
   Risks R5.

### Item 1: what the residual risk actually is

`ask` is never `allow`. Whatever the outcome, the parent plan's narrowed
guarantee still holds: **"if DECISION exists, a human approved its exact bytes
at the permission prompt"**. A teammate reaching the prompt can only
*propose*. What changes in agent-teams mode is where the proposal comes from:

- the prompt may come from an agent the human never asked, for example a
  reviewer teammate proposing approval of its own escalation;
- in a split-pane or in-process team UI, the human may not be able to tell
  which agent is asking, and may approve out of habit.

The `decision-gate-asked identity=<agent_type>` audit line still records who
asked, as long as `agent_type` is set. So the residual is a social-engineering
and approval-fatigue surface, not a bypass. It exists only while
agent-teams mode is enabled. It matters enough for a cheap, fail-closed fix
because the in-session route is meant for the orchestrator alone, and the
terminal `printf` route remains available as the fallback.

### Item 2: what exists

`scripts/probe-bash-ask.sh` calls `main` unconditionally on its last line, so
it cannot be sourced. The tests extract functions with
`sed -n '/^NAME()/,/^}/p'`, the same idiom the parent plan's esc-chat-1-fix
criterion uses (parent plan, line 396).

`tests/validate.sh` runs each suite as `if bash tests/X; then OK; else FAIL;
fail=1; fi` and ends with `exit "$fail"` at line 1139. A new block has to sit
above that line, or its failure can never change the exit code.

No committed probe record exists yet:
`docs/experiments/2026-10-01-probe-bash-ask.md` is absent, because the
esc-chat-1 operator re-run is still owed.

### Prior FAIL history and marker-audit sweep (best effort; `.claude/reviewed/` is untracked)

**Gate surfaces.** `hdg-prose-2` hit the 2-FAIL cap on branch disagreement in
`human-decision-gate.sh`. `harness-integrity-gate-hardening` FAILed. In
`stop-gate-core.sh`, `gh425-3` and `gh425-4` FAILed on scoped marker relevance,
and `gh-281-detection` and `222` also touched this area. **Units esf-eid-gate
and esf-flag-fix are therefore tagged opus.**

**The probe script.** `esc-chat-1-fix` FAILed once (the Info-row order).

**`bash bin/marker-audit.sh . --notes --surface=<path>` dispositions:**

- `scripts/probe-bash-ask.sh`:
  - NOTE[code] esc-chat-1-tidy3 "no file under tests/ exercises gate()": this
    plan's esf-probe-tests.
  - NOTE[code] esc-chat-1-fix "no test coverage; validate.sh does not glob
    scripts/": esf-probe-tests.
  - NOTE[code] esc-chat-1-fix ":139 yes when hooks.json missing": already
    fixed in `7bcc038` (`test -f "$1" &&`). esf-probe-tests case T6 pins it.
  - NOTE[code] esc-chat-1-fix "BSD sed `}` without `;`": that line no longer
    exists after tidy3. No action.
  - NOTE[spec] esc-chat-1-tidy "Method prose vs EOF rule": out of scope (prose
    in the script). Recorded under Risks R7.
  - NOTE[code] tidy3 ":106-108 one-line if/else": out of scope, because
    esf-probe-tests must not touch the script (see its "Do NOT touch").
  - NOTE[spec] tidy3 "fence rule not in plan": esf-probe-tests T3 pins the
    rule in a test.
- `hooks/scripts/lib/stop-gate-core.sh`:
  - NOTE[spec] gate-audit-step3 (stale CONTEXT.md line cite): not this plan.
  - untagged gh411, gh415 and gh424 notes: not about flag clearing. No action.
  - untagged gh425-3 "protectedPaths entry for stop-gate-core.sh":
    `protectedPaths` is `[]` today (`.claude/persona-config.json:5`), so no
    protected-path ask applies. See the Constitution check.
- `hooks/scripts/lib/state-access.sh`:
  - NOTE[code] item12-1 (append without trailing newline) and gate-audit-step5
    (`unit_id_sanitize` echo options): neither is touched by esf-flag-fix's new
    functions. No action.
  - untagged gh425-1 (`audit_append` bypasses the Set A gate): known,
    tracked separately (spec-master memory). No action.
- `hooks/scripts/lib/reviewer-route-gate-core.sh`: NOTE[code] gh429 (two
  loops). No action.
- `hooks/scripts/human-decision-gate.sh` and `harness-integrity-gate.sh`:
  untagged and code notes from gh345-1, gh360, gh417, hdg-lexer-1, hcb-*.
  None of them bears on the agent_id condition. The `[[:space:]]` note
  (gh345-1 N1) is esc-chat-2b's subject, not this plan's.

### Assumption about esc-chat-2b (not in any plan file)

`esc-chat-2b` is not defined in any committed or untracked plan. From the
`esc-chat-2.pass` notes, this plan assumes it edits
`hooks/scripts/human-decision-gate.sh`, `tests/human-decision-gate.test.sh`,
possibly `bin/microworld-dashboard/decision-block.js`, the `.claude/hooks/`
mirror, `plugin.json`/`package.json` and `CHANGELOG.md`. The ordering below
depends on that assumption.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Missing
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-02 Functional scope & success criteria: Q Does item 1 include the
  gate change, or only the measurement? → A (self-resolved): both. The probe
  is unconditional. The gate unit `esf-eid-gate` is dispatched only for
  outcome B or C (decision tree below).
- 2026-10-02 Functional scope & success criteria: Q Does item 1's gate change
  also cover `harness-integrity-gate.sh`'s `ask_allowed`, which rests on the
  same premise? → A: yes, in the same unit (OQ3 (a), per user, 2026-10-02).
- 2026-10-02 Domain entities / data model: Q Is a pending-review flag bound to
  a unit? → A (self-resolved, measured): no. A flag is keyed by the gated
  agent's `agent_id`, and the bounded clear treats flags as interchangeable by
  count. The fix keeps that model and adds a per-agent-id **flag tombstone**
  (see Step esf-flag-fix), not a unit binding.
- 2026-10-02 Non-functional attributes: Q What is the security residual of a
  teammate reaching `ask`? → A (self-resolved): a proposal surface only, with
  the human click still required (see Context, "what the residual risk
  actually is").
- 2026-10-02 External dependencies & integrations: Q Can a teammate be driven
  unattended? → A (self-resolved): unknown. The probe tries `claude -p`
  first, then a tmux interactive session. If neither yields a
  marker-attributed row, there is no row and the outcome is D.
- 2026-10-02 Edge cases / failure handling: Q What happens when a resumed
  lead-programmer (same `agent_id`) stops after its flag was cleared and then
  resurrected by a `defer:`? → A (self-resolved): the gate-side creation
  re-arms the flag. It overwrites the flag with gate content and removes the
  tombstone, so a genuine completion is never dropped. This is case R3b.
- 2026-10-02 Technical constraints & tradeoffs: Q How should item 3 be fixed:
  a mechanical tombstone, prose only, or reverting M3 to clear-all? → A: a
  flag tombstone, with resurrected flags dropped in both gates (OQ1 (a), per
  user, 2026-10-02).
- 2026-10-02 Technical constraints & tradeoffs: Q What does the gate do when
  teammates cannot be told apart from the main session by payload (outcome C)?
  → A: deny `ask` in both gates while the hook sees
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (OQ2 (a), per user, 2026-10-02).
  Under C′ the residual is documented.
- 2026-10-02 Technical constraints & tradeoffs: Q Does esc-chat-4 wait for the
  identity record? → A: no. esc-chat-4 describes the teammate premise as
  unmeasured and cites this plan (OQ4 (a), per user, 2026-10-02).
- 2026-10-02 Edge cases / failure handling: Q What outcome does a run print
  when the named dispatch was never really a teammate? → A (self-resolved,
  Amendment B1): D. `Teammate check:` names the reason (`teams-off` or
  `subagent-shaped`). A missing control row now gives the new outcome U, not
  X.
- 2026-10-02 External dependencies & integrations: Q Can a teammate be spawned
  headless? → A (self-resolved, Amendment B1): unknown. The probe tries
  headless, then tmux, and reports what `teammate_check` saw.
- 2026-10-03 Edge cases / failure handling: Q Should the gate and the composer
  refuse bidi and zero-width characters, and non-ASCII lead-ins on
  continuation lines? → A (self-resolved, Amendment C1): yes, both refuse the
  same sets. A continuation line starting with a non-ASCII letter is refused
  (it fails closed to the terminal route); non-ASCII text after an ASCII
  alphanumeric still asks.
- 2026-10-03 Functional scope & success criteria: Q Should esf-gate-bytes
  ship before the escalation work? → A: yes, as its own unit, before
  esc-chat-3 (per user, AskUserQuestion, relayed 2026-10-03).
- 2026-10-02 Terminology consistency: Q Is "flag resurrection" a new term, or
  a synonym for an existing glossary entry? → A (self-resolved): new. Scribe
  hint: add **flag resurrection** and **flag tombstone**. "Bounded flag
  clearing" was already routed to the glossary by the 2026-09-09 plan.
- 2026-10-02 Terminology consistency: Q Does this plan use "teammate" and
  "main session" as the glossary does? → A (self-resolved): yes. CONTEXT.md
  has no separate entry for either, and the prose-mode check found no
  conflicting meaning.

## Risks / dependencies

- **R1 (ordering, file collision).**
  - `esf-flag-fix` edits `lib/stop-gate-core.sh`, `lib/state-access.sh` and
    `lib/reviewer-route-gate-core.sh`, plus the generated copies, the version
    and the CHANGELOG. `esc-chat-2b` edits `human-decision-gate.sh` and also
    bumps the version, changes the CHANGELOG and runs `--update`. The two
    touch no file in common except the version/CHANGELOG/`fileHashes` triple,
    so they must **land serially**, not concurrently.
  - `esf-eid-gate` edits `human-decision-gate.sh`, so it waits for
    `esc-chat-2b`.
  - `esf-flag-prose` edits `templates/persona-protocol.md` and
    `agents/orchestrator.md`, which `esc-chat-3` also rewrites. It waits for
    `esc-chat-3`.
- **R2 (one-unit-at-a-time).** "May run in parallel" below means *no ordering
  dependency*. Review stays one unit at a time, and `reviewer-route-gate.sh`
  blocks a second gated dispatch while a flag stands. Until `esf-flag-fix`
  lands, the orchestrator should write `defer:` only into a flag that `ls`
  shows exists (an interim workaround, not a fix).
- **R3 (item 1 needs the real CLI).** The record comes from an operator run.
  Probe rows are honest-only. Outcome D (teammate not observed) is a
  legitimate result, and it triggers no gate change.
- **R4 (`esc-chat-4` ADR premise).** The ADR that `esc-chat-4` lands should
  describe the teammate premise as **unmeasured, see
  docs/plans/2026-10-02-escalation-followups.md**, unless this plan's record
  exists by then. The orchestrator should pass this to esc-chat-4 as
  pre-resolved context. This plan does not edit the parent plan. Open
  Question 4, answered 2026-10-02 (a): esc-chat-4 does not wait.
- **R5 (out of scope).** The `reviewer-route-gate.sh` caller allowlist treats
  empty `agent_type` as the main session. The probe's `agent_type` column
  shows whether teammates hit that case. If they do, file a follow-up issue.
  No unit here.
- **R6 (gate prose false positives while authoring).**
  - Test fixtures for `esf-flag-fix` spell `.claude/reviewed` inside mktemp
    projects, so `reviewed-path-gate.sh` refuses heredocs that spell it.
    Author test files with Write/Edit, or with the Bash fallback whose
    command text does not spell the path (protocol "Teammate Write/Edit
    fallback"). Never target the real marker directory.
  - Commit with `git commit -F <file>`.
- **R7 (deferred).** The Method prose in `probe-bash-ask.sh` versus its EOF
  rule (esc-chat-1-tidy NOTE[spec]) is not fixed here.
- **R8 (vacuity).** Every new suite carries a mutation control. A mutant
  that does not apply (`cmp` equal) is itself a failure.

## Constitution check (.claude/constitution.md)

Re-derive the version when dispatching.

- **P3 "version stamp per commit".** Satisfied:
  - `esf-flag-fix` and `esf-eid-gate` bump the version and add a CHANGELOG
    entry in the same commit as the hook change.
  - `esf-flag-prose` edits `agents/*.md` and `templates/*`, so P3 applies per
    commit there too.
  - `esf-eid-probe` and `esf-probe-tests` touch neither `agents/` nor
    `templates/`, so no bump is needed. They add CHANGELOG lines only if the
    repo's convention requires it.
- **Every other MUST principle.** The dispatcher re-reads
  `.claude/constitution.md` and appends a line per principle. This plan
  deviates from none it knows of. Self-check CHK10 covers this.

## Decision tree for item 1 (applied after the operator run)

The record's `Outcome:` line is computed by the probe's pure `outcome()`
function (step esf-eid-probe). Controls: the main row must show
`agent_id=absent` and the subagent row `agent_id=present`. If either control
fails, the outcome is **X**.

| Outcome | Rows show | Gate action | Unit |
|---|---|---|---|
| **A** | teammate `agent_id=present` (non-empty) | none: PG2 already denies, and `harness-integrity-gate` `ask_allowed` already denies | no dispatch; record only |
| **B** | teammate `agent_id` absent/empty, but a field separates it from the main row (a teammate-only key, or an `agent_type` value the main row never carries) | add a deny condition on that field to `is_prompt_eligible_decision_write` and `ask_allowed` (OQ3) | `esf-eid-gate` |
| **C** | teammate indistinguishable from main by payload, and `teams_env=1` visible in the teammate's hook | deny `ask` in both gates whenever the hook sees `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (OQ2), so the orchestrator falls back to `printf` | `esf-eid-gate` |
| **C′** | as C, but the hook cannot see the env var | no mechanical fix exists. Document the residual (OQ2) | no dispatch; esc-chat-4/scribe note |
| **D** | no **genuine** teammate row (none captured, the lead ran the marker, run 2's hook did not see `teams_env=1`, or the "teammate" was subagent-shaped; Amendment B1) | none. Residual stays documented as unmeasured. Re-run when a teammate can be driven | no dispatch |
| **U** | a control row (main, main-teams or subagent) is **missing** (Amendment B1) | none. The run is incomplete, not contradictory. Re-run | no dispatch |
| **X** | a control row that **exists** disagrees with the 2026-07 record | stop. The main-session premise itself is in doubt. Escalate to the user before any gate unit | none |

---

## Units and dispatch contracts

### Unit: esf-eid-probe

Suggested model: sonnet. This is a new script with no prior FAIL history,
modelled on `scripts/probe-bash-ask.sh`, whose FAIL taught that Method prose
must match the code.

## Objective
Add an operator-run probe that records which identity fields the PreToolUse
payload carries for main, subagent and teammate, computes the decision-tree
outcome, and is covered by an offline test that needs no `claude`.

## Retrieval
This plan, § "Decision tree for item 1", § Context "Item 1".
`scripts/probe-bash-ask.sh` (structure, honest-rows rule, Cleanup checks).
`docs/experiments/2026-07-probe-hook-payloads.md:31-80` (prior payloads).

## Affected files
- `scripts/probe-hook-identity.sh` (new)
- `tests/probe-hook-identity.test.sh` (new)
- `tests/validate.sh` (one new block above `exit "$fail"`)

## Ordered edits
1. The script ends with `[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@"`, so a
   test can source it without running anything. It uses
   `SCRATCH=/tmp/hook-identity-probe` (outside the repo) and
   `REC=${1:-docs/experiments/<DATE>-probe-hook-identity.md}`.
2. In `setup()`, write a scratch `.claude/settings.json` that registers one
   capture hook on `PreToolUse` (matcher `Bash|Agent`), `Stop` and
   `SubagentStop`. For each event, the hook appends one JSON line to
   `$SCRATCH/capture.jsonl`. It always exits 0 with no stdout. The line is:
   `{event, keys:(keys), agent_id, agent_type, session_id, permission_mode,
   cmd:.tool_input.command, name:.tool_input.name, transcript_path,
   teams_env:$ENV.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS}`
3. Drive three actors. Each one runs a marker command,
   `echo probe-main` / `echo probe-subagent` / `echo probe-teammate`.
   - **main + subagent:** one `claude -p` run with
     `--allowedTools 'Bash(echo probe-*)' Agent`. The subagent comes from an
     unnamed `Agent` call.
   - **teammate:**
     `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude -p`, asking for a
     **named** `Agent` dispatch (`name: probe-mate`). If no teammate marker
     row is captured within 180 s, retry once in a detached tmux interactive
     session (as `probe_mode` does) with the same env var.
   - Also record a **main-with-teams** row (the main marker under teams=1) as
     a control.
4. Add the pure function `classify_rows <capture.jsonl>`. It emits
   `Identity row: <actor> agent_id=<present|empty|absent>
   agent_type=<value|absent> teams_env=<value|unset> stop_event=<Stop|SubagentStop|none>
   <DATE> observed`. It emits a row only when:
   - a PreToolUse(Bash) line has `cmd` exactly `echo probe-<actor>`; and
   - for subagent and teammate, the **main** session's transcript (the
     `transcript_path` of the main row) does NOT contain a Bash `tool_use`
     whose command is `echo probe-<actor>`. If it does, the lead ran the
     command itself, so the actor is ambiguous and gets no row.
   `stop_event` is the event of the Stop/SubagentStop line whose `session_id`
   and `agent_id` match that actor's row, or `none`.
5. Add the pure function `outcome <rows-file>`. It prints exactly one of
   `A B C C' D X`, following the decision tree. The B test is: the teammate
   row has `agent_id` absent/empty, and its `agent_type` value differs from
   both main rows' `agent_type` values, or its `keys` contain a key that no
   main row's `keys` contain. To support that, `classify_rows` also emits
   `Keys row: <actor> <sorted keys>`.
6. `write_record` writes these sections: Method, Version, Status, Rows (in a
   fenced block), `Outcome: <X>`, and an Appendix with the raw
   `capture.jsonl`. Every Method sentence must describe what the code does.
   The Cleanup checks follow the probe-bash-ask pattern:
   - the scratch directory is removed;
   - `git status --porcelain -- hooks .claude/settings.json` is empty.
7. Write the test (`tests/probe-hook-identity.test.sh`). It sources the
   script, feeds fixture `capture.jsonl` and transcript files built in
   mktemp, and asserts these cases, each labelled `(I<n>)`:
   - **I1** controls OK and teammate `agent_id` present → `A`.
   - **I2** teammate `agent_id` absent with a distinct `agent_type` → `B`.
   - **I3** teammate absent, same `agent_type` as main, and `teams_env=1` →
     `C`.
   - **I4** as I3 with `teams_env` unset → `C'`.
   - **I5** no teammate marker line → `D`, and no teammate row.
   - **I6** the main row carries `agent_id` → `X`.
   - **I7** the teammate marker appears in the main transcript → no teammate
     row → `D`.
   - **I8** sourcing the script calls neither `claude` nor `tmux`: shadow both
     on `PATH` with stubs that touch a sentinel, then assert the sentinel is
     absent.
   - **I9** a Bash line whose `cmd` is `echo probe-teammate; true` (not exact)
     gives no row.
8. Add to `tests/validate.sh`, above line `exit "$fail"`:
   `if bash tests/probe-hook-identity.test.sh; then echo "OK   tests/probe-hook-identity.test.sh"; else echo "FAIL tests/probe-hook-identity.test.sh"; fail=1; fi`

## Do NOT touch
`hooks/`, `.claude/`, `agents/`, `templates/`, `scripts/probe-bash-ask.sh`,
and the parent plan. Do not run the probe (that is the operator's job), and
do not commit any record.

## Acceptance criteria
Save as a file and run it with `bash`:
```sh
set -e
s=scripts/probe-hook-identity.sh; t=tests/probe-hook-identity.test.sh
bash -n "$s"
bash "$t"
for i in 1 2 3 4 5 6 7 8 9; do grep -qE "\(I$i\)" "$t" || { echo "missing I$i"; exit 1; }; done
grep -qF '[ "${BASH_SOURCE[0]}" = "$0" ] && main' "$s"
grep -qF 'bash tests/probe-hook-identity.test.sh' tests/validate.sh
awk '/bash tests\/probe-hook-identity.test.sh/{a=NR} /^exit "\$fail"$/{b=NR} END{exit !(a && b && a<b)}' tests/validate.sh
# mutation control: outcome() that never returns A must fail the suite
d=$(mktemp -d); sed 's/echo A$/echo D/' "$s" > "$d/p.sh"; ! cmp -s "$d/p.sh" "$s"
if PROBE_UNDER_TEST="$d/p.sh" bash "$t" >/dev/null 2>&1; then echo VACUOUS; exit 1; fi; rm -rf "$d"
bash tests/validate.sh
```
The test must source `${PROBE_UNDER_TEST:-scripts/probe-hook-identity.sh}`.
The mutation `sed` requires `outcome()` to print A through a line ending in
`echo A`. If the implementation spells it differently, the implementer must
keep that line form; it is a precondition of the criterion.

## Pre-resolved context
- The main and subagent payload shapes were already measured
  (`docs/experiments/2026-07-probe-hook-payloads.md`). The new rows re-measure
  them as controls.
- `grep` in an inline Bash call is ugrep, while inside `bash script.sh` it is
  GNU grep. Use portable ERE and no PCRE.
- Honest rows only: a missing row is never inferred, and the Status line names
  what was not driven.

## Escalation
If `claude -p` refuses `--allowedTools` patterns or `Agent` in 2.1.287, keep
the tmux route as primary and say so in Method. Never invent a row.

---

### Operator step (not a unit): run the identity probe

**Blocked until `esf-eid-probe-fix` holds a reviewer PASS** (Amendment B1).
Then `bash scripts/probe-hook-identity.sh`, and commit the record. Its `Outcome:`
line selects a branch of the decision tree. Only outcomes **B** and **C**
dispatch `esf-eid-gate`.

---

### Unit: esf-eid-gate  (CONDITIONAL: only if the committed record reads `Outcome: B` or `Outcome: C`; after esc-chat-2b lands)

Suggested model: opus. `hdg-prose-2` hit the 2-FAIL cap on this file,
`harness-integrity-gate-hardening` FAILed, and esc-chat-2 needed a frozen case
table.

## Objective
Make the two `ask` branches deny for a teammate, using exactly the field the
record shows (B), or the agent-teams env var (C).

## Retrieval
The committed identity record (its Rows and Appendix). This plan, § Decision
tree. Read `hooks/scripts/human-decision-gate.sh` in full, and
`hooks/scripts/harness-integrity-gate.sh:100-130`.

## Affected files
- `hooks/scripts/human-decision-gate.sh` (`is_prompt_eligible_decision_write`)
- `hooks/scripts/harness-integrity-gate.sh` (`ask_allowed`; OQ3 = yes). This file is Set B: Write/Edit asks a human (see Constitution
  check). Edit it surgically through Bash, or have the human approve the
  prompt.
- `tests/human-decision-gate.test.sh`, `tests/harness-integrity-gate.test.sh`
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated by `node bin/cli.js --update`: both `.claude/hooks/scripts/`
  mirrors and their `fileHashes`

## Ordered edits
1. In both functions, directly after the existing `[ -z "$agent_id" ]` line,
   add one condition line that ends with the comment
   `# TEAMMATE-GUARD (docs/plans/2026-10-02-escalation-followups.md)`.
   - **B:** return 1 when the record's distinguishing field is present or
     holds its teammate value. Take the field name and value literally from
     the record's `Keys row` / `Identity row`.
   - **C:** `[ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}" != 1 ] || return 1`.
2. Tests:
   - **TG1** feeds the record's teammate PreToolUse payload verbatim from its
     Appendix (with the command swapped for the PG1 command) and expects exit
     2.
   - **TG2** feeds the record's main-session payload and expects `ask`.
   - In harness-integrity-gate.test.sh, **TG3**/**TG4** are the same pair for
     a Set A write.
   - For C, TG1 sets the env var instead of using a payload field.
3. Bump the version, update the CHANGELOG and run `node bin/cli.js --update`,
   all in the same commit.

## Do NOT touch
Any existing case's verdict, the mode allowlists, `reviewer-route-gate.sh`
(R5), `agents/` and `templates/`.

## Acceptance criteria
```sh
set -e
bash tests/human-decision-gate.test.sh
bash tests/harness-integrity-gate.test.sh
grep -q 'TG1' tests/human-decision-gate.test.sh && grep -q 'TG2' tests/human-decision-gate.test.sh
test "$(grep -c 'TEAMMATE-GUARD' hooks/scripts/human-decision-gate.sh)" = 1
d=$(mktemp -d); cp -r hooks "$d/"; grep -v 'TEAMMATE-GUARD' hooks/scripts/human-decision-gate.sh > "$d/hooks/scripts/human-decision-gate.sh"; chmod +x "$d/hooks/scripts/human-decision-gate.sh"
if GATE_UNDER_TEST="$d/hooks/scripts/human-decision-gate.sh" bash tests/human-decision-gate.test.sh >/dev/null 2>&1; then echo VACUOUS; exit 1; fi; rm -rf "$d"
grep -q 'TEAMMATE-GUARD' .claude/hooks/scripts/human-decision-gate.sh
test "$(jq -r .version .claude-plugin/plugin.json)" = "$(jq -r .version package.json)"
grep -qF "$(jq -r .version .claude-plugin/plugin.json)" CHANGELOG.md
bash tests/validate.sh
```
Then, for `harness-integrity-gate.sh` (OQ3 = yes; its suite honours
`GATE_UNDER_TEST`, measured at `tests/harness-integrity-gate.test.sh:14`):
```sh
set -e
grep -q 'TG3' tests/harness-integrity-gate.test.sh && grep -q 'TG4' tests/harness-integrity-gate.test.sh
test "$(grep -c 'TEAMMATE-GUARD' hooks/scripts/harness-integrity-gate.sh)" = 1
d=$(mktemp -d); cp -r hooks "$d/"; grep -v 'TEAMMATE-GUARD' hooks/scripts/harness-integrity-gate.sh > "$d/hooks/scripts/harness-integrity-gate.sh"; chmod +x "$d/hooks/scripts/harness-integrity-gate.sh"
if GATE_UNDER_TEST="$d/hooks/scripts/harness-integrity-gate.sh" bash tests/harness-integrity-gate.test.sh >/dev/null 2>&1; then echo VACUOUS; exit 1; fi; rm -rf "$d"
grep -q 'TEAMMATE-GUARD' .claude/hooks/scripts/harness-integrity-gate.sh
```

## Pre-resolved context
- Test through the suites with `GATE_UNDER_TEST`, never through the live hook.
- The gate's prose false positive fires on Bash text that spells both the
  packet segment and the decision token. Commit with `-F`.

## Escalation
If the record's B field is also present on the subagent row, or on any main
row, stop: the field does not distinguish teammates.

---

### Unit: esf-probe-tests

Suggested model: sonnet. Tests only, and the script itself is not changed. The
probe surface's FAIL history (esc-chat-1-fix) was about prose, not tests.

## Objective
Commit fixture tests for `scripts/probe-bash-ask.sh`'s `gate()`,
`display_and_decline()`, `finish_record()` and `unseen()`, with mutation
controls. The tests never invoke `claude` or `tmux`.

## Retrieval
`scripts/probe-bash-ask.sh` (all of it). This plan, § Context "Item 2". The
`esc-chat-1-tidy3.pass` notes, read with the Read tool.

## Affected files
- `tests/probe-bash-ask.test.sh` (new). Fixtures are generated inline in
  mktemp. No committed fixture files.
- `tests/validate.sh` (one block above `exit "$fail"`)

## Ordered edits
1. The test reads `P=${PROBE_UNDER_TEST:-scripts/probe-bash-ask.sh}` and
   defines `extract() { sed -n "/^$1()/,/^}/p" "$P"; }`. It never sources
   `$P` whole, because the last line calls `main`.
2. Stubs, defined after extraction:
   - `tm` records its arguments to a file;
   - `wait_for` returns `${WAIT_RC:-0}`;
   - `sleep` is a no-op;
   - `cleanup` is a no-op;
   - `dialog` echoes `$DIALOG`.
   `row`, `miss` and `yn` are one-line functions with no column-0 `}`, so
   the range idiom would run past them. Extract them with
   `sed -n '/^row()/p'` (and the same for `miss` and `yn`), never with the
   range form.
   `finish_record` gets `ROOT=<mktemp git repo>`,
   `SCRATCH=<mktemp path, removed>` and `REC=<mktemp file>`. `gate` is
   extracted too, so `finish_record` calls the real one.
3. Cases, each labelled `(T<n>)` in its OK/FAIL line:
   - **T1 committed-record re-grade.** Build a full-layout record:
     - pre-appendix Rows for default/acceptEdits/auto;
     - an `Info row: plan not-driven <DATE> informational`;
     - `## Appendix` with fenced panes;
     - `## Cleanup checks` with the three `yes` lines;
     - a trailing `Ship gate: GREEN`.

     Expect `gate` = GREEN, and the result to equal the record's own
     `Ship gate:` value. **T1b:** if
     `docs/experiments/2026-10-01-probe-bash-ask.md` exists, assert that
     `gate` on it equals its own last `Ship gate:` value. If it does not exist,
     print `SKIP (T1b) no committed record`. T1b is never counted as a pass.
   - **T2 no-heading appendix tail.** No `## Cleanup checks` heading. The three
     `Cleanup check: ... yes` lines sit only inside the appendix. Expect RED.
   - **T3 heading forged inside a pane.** No real heading. An appendix pane
     contains `## Cleanup checks` plus the three `yes` lines, then the pane's
     closing fence. Expect RED.
   - **T4 forged Cleanup lines.**
     - **T4a:** the appendix carries `yes` lines, and the real final block says
       `scratch-removed no`. Expect RED.
     - **T4b:** the real block lists `scratch-removed yes` twice. Expect RED.
   - **T5 missing acceptEdits row.** T1's record without its three acceptEdits
     rows. Expect RED.
   - **T6 hooks.json.** Run `finish_record` with ROOT's `hooks/hooks.json`:
     - missing → `repo-hooks-probe-free no`, and the record ends
       `Ship gate: RED`;
     - present and probe-free → `yes`;
     - containing `probe` → `no`;
     - unreadable (`chmod 000`; skip this sub-case with a printed SKIP when
       running as root) → `no`.
   - **T7 plan Info row forms.**
     - `unseen plan readiness` appends exactly
       `Info row: plan not-driven <DATE> informational`;
     - `unseen default x` appends no row and adds `default` to `MISSING`;
     - T1's record with its plan line replaced by
       `Info row: plan denied <DATE> observed informational`, or with no plan
       line, is still GREEN;
     - the static line `row "Info row: plan $v $DATE observed informational"`
       is present in `$P`.
   - **T8 sed extraction is self-contained.** For each of `gate`,
     `display_and_decline`, `finish_record` and `unseen`:
     - the extracted text's first line starts `NAME() {` and its last line is
       exactly `}`;
     - `bash -n` passes;
     - sourcing it in a clean `bash -c` defines `NAME` and no other new
       function (compare `declare -F` before and after).
   - **T9 closing EOF.** `display_and_decline default s` with `$DIALOG` set to:
     - a full dialog with `line-1`..`line-6-END` and then `EOF` on its own
       line → `full-heredoc-visible yes`;
     - a framed `│ EOF │` on its own line → `yes`;
     - no closing EOF → `no`;
     - `EOF` only before `line-6-END` → `no`;
     - `EOFX` → `no`;
     - `line-3` missing → `no`.

     Decline: `$SCRATCH/out.txt` absent → `Decline row: default file-absent
     yes`; present → `no`; `WAIT_RC=1` → no Decline row and `MISSING`
     non-empty.
4. Wire the suite into `tests/validate.sh` above `exit "$fail"`, in the same
   form as esf-eid-probe edit 8.

## Do NOT touch
`scripts/probe-bash-ask.sh` (no refactor, no sourcing guard; the tests adapt
to it), `hooks/`, `.claude/`, `docs/experiments/`.

## Acceptance criteria
Save as a file and run it with `bash`:
```sh
set -e
t=tests/probe-bash-ask.test.sh
bash "$t"
for c in T1 T2 T3 T4 T5 T6 T7 T8 T9; do grep -qE "\($c[a-z]?\)" "$t" || { echo "missing $c"; exit 1; }; done
grep -qF 'bash tests/probe-bash-ask.test.sh' tests/validate.sh
awk '/bash tests\/probe-bash-ask.test.sh/{a=NR} /^exit "\$fail"$/{b=NR} END{exit !(a && b && a<b)}' tests/validate.sh
# never reaches the real CLI
f=$(mktemp -d); for b in claude tmux; do printf '#!/bin/sh\ntouch %s/CALLED\nexit 99\n' "$f" > "$f/$b"; chmod +x "$f/$b"; done
PATH="$f:$PATH" bash "$t" >/dev/null; test ! -e "$f/CALLED"; rm -rf "$f"
# mutation controls: each mutant must apply, and each must turn the suite red
mut() { d=$(mktemp -d); sed "$2" scripts/probe-bash-ask.sh > "$d/p.sh"; if cmp -s "$d/p.sh" scripts/probe-bash-ask.sh; then echo "mutant $1 did not apply"; exit 1; fi
  if PROBE_UNDER_TEST="$d/p.sh" bash "$t" >/dev/null 2>&1; then echo "VACUOUS $1"; exit 1; fi; rm -rf "$d"; }
mut fence-rule   '/a fence after it means/d'
mut eof-rule     '/closing EOF as its own line/d'
mut accept-edits 's/for m in default acceptEdits auto; do/for m in default auto; do/'
mut count-once   's/ = 1 \] \&\& grep -qxF/ -ge 1 ] \&\& grep -qxF/'
mut hooks-json   's/test \$? -eq 1/test $? -ne 0/'
bash tests/validate.sh
```
Each of the five `sed` expressions was measured on 2026-10-02 at `8428fab` to
change exactly one line of the script.

## Pre-resolved context
- The script's last line is `main`, which is why the tests extract functions
  instead of sourcing the script.
- `finish_record` runs `git -C "$ROOT" status`, so ROOT must be a real
  `git init` repo with one commit.
- T6's "missing → no" behaviour comes from `test -f "$1" &&` (`7bcc038`). The
  `hooks-json` mutant flips the exit-status test, because removing
  `test -f` alone still yields `no` (grep exits 2, not 1).

## Escalation
If any case cannot be expressed without editing the script, stop and report.
Do not add a sourcing guard to `probe-bash-ask.sh` in this unit.

---

### Unit: esf-flag-fix  (after esc-chat-2b lands; design per OQ1 (a))

Suggested model: opus. Units on `stop-gate-core.sh` FAILed in gh425-3 and
gh425-4, the file is a port-invariant core with generated copies, and the
parity checks span five artifacts.

## Objective
A pending-review flag that a non-gate writer re-creates after the hook
deleted it (**flag resurrection**) must neither block turn-end nor the next
gated dispatch. A genuine new completion by the same agent must still raise a
flag. The hook ships with a hermetic reproduction test and a mutation
control.

## Retrieval
This plan, § Context "Item 3" (evidence table and reproduction). Read
`hooks/scripts/lib/stop-gate-core.sh` lines 334-600,
`hooks/scripts/lib/state-access.sh` lines 100-150 and
`hooks/scripts/lib/reviewer-route-gate-core.sh` lines 30-50. For fixture
style, read `tests/review-join.test.sh:1-50` and `:580-615`.

## Affected files
- `hooks/scripts/lib/state-access.sh`
- `hooks/scripts/lib/stop-gate-core.sh`
- `hooks/scripts/lib/reviewer-route-gate-core.sh`
- `tests/pending-review-resurrection.test.sh` (new) and `tests/validate.sh`
- `.gitignore` and `bin/cli.js` (`OPERATIONAL_GITIGNORE_PATTERNS`, around line
  160): add `.claude/.pending-review-cleared.*` and
  `{{DOTDIR}}/.pending-review-cleared.*`
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated: `.claude/hooks/scripts/lib/{state-access,stop-gate-core,reviewer-route-gate-core}.sh`,
  `adapters/{codex,cursor}/hooks/scripts/lib/` copies of the same three, and
  their `fileHashes` (run `node bin/cli.js --update` and
  `node bin/cli.js --update --force-render`, as the core headers direct)

## Ordered edits
1. `state-access.sh`:
   - **`state_tombstone_pending_review <agent-id>`** writes
     `${dot}/.pending-review-cleared.<agent-id>`, containing a UTC timestamp.
   - **`state_drop_resurrected_flags`**: for every `.pending-review.<id>` that
     has a matching tombstone, delete the flag (keeping the tombstone) and
     append `<ts> flag-resurrected-dropped=<id>` through
     `state_append_audit_log "review-audit.log"`.
   - **`state_write_pending_review`** (gate-side creation): if a tombstone
     exists for that id, overwrite the flag with the gate content and delete
     the tombstone (re-arm). Otherwise keep the existing create-only-if-absent
     behaviour.
   - **`state_clear_all_pending_review`**: tombstone each flag before deleting
     it.
2. `stop-gate-core.sh`:
   - the M3 bounded-clear loop calls `state_tombstone_pending_review` for each
     flag it deletes;
   - the Stop branch's `skip:` arm tombstones the flag it deletes;
   - `state_drop_resurrected_flags` is called once at the top of the
     `hook_event = Stop` branch, before the pending-flag glob.
3. `reviewer-route-gate-core.sh`: call `state_drop_resurrected_flags` once,
   before `pending_flags=( ... )`.
4. Every call to `state_drop_resurrected_flags` in edits 2 and 3 is on a single
   line that ends with `# RESURRECTION-GUARD`. There are exactly two such
   lines across the two core files.
5. Update the Stop-branch `block` message and the grant-denied recovery
   message so they say that flags are not bound to units (one flag is cleared
   per satisfied stamp), and that `defer:`/`skip:` should be written only into
   a flag that currently exists.
6. Write `tests/pending-review-resurrection.test.sh`. It is hermetic: mktemp
   projects, the real entry scripts under `${HOOKS_UNDER_TEST:-hooks/scripts}`,
   and canned payloads in the shape `review-join.test.sh` uses. Cases, each
   labelled `(R<n>)`:
   - **R1 incident replay.** This is this plan's reproduction: two flags with
     same-second `defer:` rewrites; u1 satisfied; reviewer stop; a `defer:`
     written into whichever flag was deleted; u2 satisfied; reviewer stop.
     Expect 0 flags, an audit line `flag-resurrected-dropped=`, and the last
     `cleared-by=reviewer` line reading `remaining=0`.
   - **R2 route gate.** Only a resurrected flag is standing. A lead-programmer
     PreToolUse(Agent) dispatch exits 0.
   - **R3 re-arm.**
     - **R3a:** id `lp-a` is tombstoned and a gated `SubagentStop` with
       `agent_id:"lp-a"` arrives. The flag exists with gate content, the
       tombstone is gone, and a main `Stop` exits 2.
     - **R3b:** as R3a, but a resurrecting `defer:` was written before the
       stop. Same expectations.
   - **R4 skip then defer.** A `skip:` is honoured, so the flag is deleted and
     tombstoned. A later `defer:` into the same path is dropped on the next
     Stop.
   - **R5 bootstrap.** Zero stamps and two flags. The reviewer stop clears
     both and tombstones both.
   - **R6 live defer is unchanged.** A flag with `defer:` content and no
     tombstone: main Stop exits 0 and the flag stays (sticky); a lead
     dispatch exits 2.
   - **R7 tombstone ignored by globs.** A tombstone alone triggers no block, no
     `grant-denied` line, and no `join` effect.
7. Wire the suite into `tests/validate.sh` above `exit "$fail"`.
8. Bump the version, update the CHANGELOG, run `--update` and
   `--update --force-render`, all in the same commit.

## Do NOT touch
- the M3 bound itself (one flag per satisfied stamp);
- `review_join_state`;
- the `.blocked`/`.escalated` scoping;
- `human-decision-gate.sh`;
- `templates/` and `agents/` (prose is `esf-flag-prose`);
- every existing test's expected verdict, with **one** authorised exception
  (ruled 2026-10-03, see "Amendment D1" below): case (h) in
  `tests/stop-gate-blocked.test.sh`.

**Amendment D1 (2026-10-03): the authorised edit to case (h).**

*Why (h) needs editing.* Case (h) is meant to prove one thing: only
**consecutive** duplicate `defer:` lines are suppressed. It does this by
writing its second, identical `defer:` into `lp-1` after the reviewer's
bootstrap clear-all has deleted `lp-1`. That write is a flag resurrection,
which this unit drops by design. So (h) asserts its point through the
behaviour this unit removes, and that removed behaviour is now pinned in the
inverse direction by R4 in `pending-review-resurrection.test.sh`.

*The authorised edit.* Ruling: option A, with a mutation proof. Only these
changes are allowed:

1. In case (h), the **second** `printf 'defer: reviewer already
   dispatched
' > "$flag"` writes instead to
   `"$dir/.claude/.pending-review.lp-2"`. `lp-2` is a flag id that was never
   created or cleared, so it has no tombstone. The first write, the reviewer
   stop, the `want` string and the OK/FAIL messages are byte-for-byte
   unchanged.
2. Update (h)'s comment to say that the second `defer:` targets a fresh flag
   `lp-2`, because writing into the cleared `lp-1` would be a flag
   resurrection, and that case is covered by R4.

No other line of `tests/stop-gate-blocked.test.sh` changes. No other existing
test file changes, apart from the one new `validate.sh` block (edit 7).

*Why the re-pointed case still proves the claim.* The second `defer:` has the
same content, and the audit log's last line before it is
`cleared-by=reviewer`. It is still appended only because the dedupe compares
against the **last** line. The mutation below shows the case still binds to
that rule.

*Expected flips: none other.* The lead-programmer reports `validate.sh` green
apart from (h), R1-R7 passing, and the base mutations confirmed. The criteria
below re-run `stop-gate-blocked.test.sh` and `review-join.test.sh` in full. Any
other changed verdict is an Escalation, not a further exemption.

## Acceptance criteria
Save as a file and run it with `bash`:
```sh
set -e
t=tests/pending-review-resurrection.test.sh
bash "$t"
bash tests/review-join.test.sh
for i in 1 2 3a 3b 4 5 6 7; do grep -qF "(R$i)" "$t" || { echo "missing R$i"; exit 1; }; done
test "$(cat hooks/scripts/lib/stop-gate-core.sh hooks/scripts/lib/reviewer-route-gate-core.sh | grep -c 'RESURRECTION-GUARD')" = 2
grep -qF '.pending-review-cleared.*' .gitignore
grep -qF '{{DOTDIR}}/.pending-review-cleared.*' bin/cli.js
awk '/bash tests\/pending-review-resurrection.test.sh/{a=NR} /^exit "\$fail"$/{b=NR} END{exit !(a && b && a<b)}' tests/validate.sh
# mutation control: with the guard lines removed, R1 and R2 must fail
d=$(mktemp -d); cp -r hooks/scripts "$d/scripts"
for f in stop-gate-core.sh reviewer-route-gate-core.sh; do grep -v 'RESURRECTION-GUARD' "hooks/scripts/lib/$f" > "$d/scripts/lib/$f"; done
if HOOKS_UNDER_TEST="$d/scripts" bash "$t" >/dev/null 2>&1; then echo VACUOUS; exit 1; fi; rm -rf "$d"
for f in state-access.sh stop-gate-core.sh reviewer-route-gate-core.sh; do cmp -s "hooks/scripts/lib/$f" ".claude/hooks/scripts/lib/$f"; cmp -s "hooks/scripts/lib/$f" "adapters/codex/hooks/scripts/lib/$f"; cmp -s "hooks/scripts/lib/$f" "adapters/cursor/hooks/scripts/lib/$f"; done
test "$(jq -r .version .claude-plugin/plugin.json)" = "$(jq -r .version package.json)"
grep -qF "$(jq -r .version .claude-plugin/plugin.json)" CHANGELOG.md
bash tests/adapter-stop-gate-parity.test.sh
bash tests/validate.sh
test -z "$(git status --porcelain -- .claude/.pending-review-cleared.* 2>/dev/null)"
# Amendment D1: (h) is the ONLY change to an existing test, and it still catches duplicate-defer suppression
bash tests/stop-gate-blocked.test.sh
B=0e99a27   # the unit's base commit; if esf-flag-fix's commit has a different parent, set B to that parent
test "$(git diff --numstat "$B" -- tests/ | awk '$3!="tests/pending-review-resurrection.test.sh" && $3!="tests/validate.sh" && $3!="tests/stop-gate-blocked.test.sh"' | wc -l)" = 0
test "$(git diff -U0 "$B" -- tests/stop-gate-blocked.test.sh | grep -cE '^[-+][^-+]')" -le 6
git diff -U0 "$B" -- tests/stop-gate-blocked.test.sh | grep -qE '^\+.*\.pending-review\.lp-2'
! git diff -U0 "$B" -- tests/stop-gate-blocked.test.sh | grep -qE '^[-+]want='
d=$(mktemp -d); mkdir -p "$d/tests"; cp -r hooks "$d/"; cp tests/stop-gate-blocked.test.sh "$d/tests/"
sed -i 's/last_logged="\$(tail -n 1 "\$review_audit"/last_logged="$(head -n 1 "$review_audit"/' "$d/hooks/scripts/lib/stop-gate-core.sh"
! cmp -s "$d/hooks/scripts/lib/stop-gate-core.sh" hooks/scripts/lib/stop-gate-core.sh
bash "$d/tests/stop-gate-blocked.test.sh" 2>/dev/null | grep -q '^FAIL (h)'; rm -rf "$d"
```
The `cmp` mirror checks are valid as written: on 2026-10-02 at `8428fab`, all
nine copies of these three libs (`.claude/` plus both adapters) were
byte-identical to `hooks/scripts/lib/`, with no stamp header.

## Pre-resolved context
- **The reproduction is already measured** (§ Context). On current code, R1
  ends with `remaining=1` and R2 with rc 2, so both cases are RED before the
  fix.
- **Gates that apply here:**
  - `protectedPaths` is `[]`, so no protected-path ask applies.
  - None of the three lib files is in `harness-integrity-gate.sh` Set A or
    Set B (Set B is exactly `hooks/hooks.json`, `.claude/settings.json` and
    the two `harness-integrity-gate.sh` copies), so Write/Edit is not gated.
  - `fileHashes` in the persona-selection config is Set A. Change it only
    through `node bin/cli.js --update`, never by direct write. A direct write
    raises a human `ask`, which must be declined.
  - With `humanReviewMode: "off"`, the reviewer cannot escalate. **No human
    approval is mechanically required.** The human approved the design
    (OQ1 (a), 2026-10-02).
- Test fixtures spell `.claude/reviewed` inside mktemp projects (R6). Author
  them with Write/Edit.

## Escalation
- If the codex or cursor entry scripts do not source `state-access.sh` before
  the core, so that the new function is undefined there, stop and report.
  Never stub it inline per port.
- If any pre-existing `review-join.test.sh` case changes verdict, stop.
- Amendment D1: case (h) in `tests/stop-gate-blocked.test.sh` is the only
  pre-existing case allowed to change, and only through the re-point to
  `lp-2` defined under "Do NOT touch". If any other existing case in any
  suite changes verdict, or if (h) cannot pass without changing its `want`
  string, stop and report. Never exempt or delete a case.

---

### Unit: esf-flag-prose  (after esc-chat-3 lands)

Suggested model: sonnet. This is a prose unit with claim-anchored criteria.
`lean-1`, `lean-2` and `gh377-7` FAILed on prose and P3.

## Objective
Make every prose surface describe bounded clearing and the
resurrection-dropping that is actually implemented, instead of "clears every
such flag". Correct the orchestrator's `defer:` instruction to match.

## Retrieval
`esf-flag-fix`'s landed diff. Spec-master memory "Protocol amendments don't
propagate": the six surfaces, the inlined block is TRIMMED, the digest is not
a mirror, and the version is bumped BEFORE `--update`.

## Affected files
- `templates/persona-protocol.md` (§ "Pending-review flag", around 307-337)
- `adapters/codex/agents-md-fragment.md` (around 103-110) and the cursor
  equivalent, if one exists (grep `clears every such flag` under `adapters/`)
- `agents/orchestrator.md:155-161`
- `templates/protocol-digest.md:24` (only if its wording claims all flags
  clear)
- version files, `CHANGELOG.md`, and the outputs of `node bin/cli.js --update`
  (persona mirrors, inlined protocol blocks, `fileHashes`)

## Ordered edits
1. Replace "clears every such flag" with wording that says the stop clears
   one flag per satisfied review-join stamp (oldest first), and all flags
   only on the zero-stamp bootstrap path. Flags are not bound to units, and
   a flag re-created after the hook deleted it is dropped and logged as
   `flag-resurrected-dropped=<id>`.
2. `orchestrator.md`: write the background-dispatch `defer:` only into a
   pending-review flag that currently exists (check with `ls` first). Never
   recreate a deleted one.
3. Bump the version, update the CHANGELOG and run `--update`, in one commit.

## Do NOT touch
Hooks, tests (other than via validate.sh), and esc-chat-3's in-session
escalation wording.

## Acceptance criteria
Save as a file and run it with `bash`:
```sh
set -e
! git grep -n 'clears every such flag' -- templates adapters agents .claude
git grep -q 'flag-resurrected-dropped' -- templates/persona-protocol.md
git grep -q 'flag-resurrected-dropped' -- hooks/scripts/lib/state-access.sh   # claim anchored to code
git grep -qE 'one flag per satisfied' -- templates/persona-protocol.md
git grep -qE 'currently exists' -- agents/orchestrator.md .claude/agents/orchestrator.md
test "$(jq -r .version .claude-plugin/plugin.json)" = "$(jq -r .version package.json)"
grep -qF "$(jq -r .version .claude-plugin/plugin.json)" CHANGELOG.md
bash tests/validate.sh
```

## Pre-resolved context
The adapter protocol ports are hand-maintained, not rendered by `cli.js`. The
parity test asserts literal strings, so edit both ports by hand.

## Escalation
If esc-chat-3 has already rewritten the § "Pending-review flag" text, apply
the claim to the current wording. Never restore older wording.

---

## Amendment B1 (2026-10-02): `esf-eid-probe-fix`

`esf-eid-probe` (`2ef26a2`) received a reviewer PASS against this plan as it
was written. The reviewer then ran it by accident against the real `claude`
2.1.287. Record:
`/tmp/claude-1000/-home-sebas-AntiSlop/74132c4b-fe3f-4a87-85fc-d5c06728bf25/scratchpad/accidental-real-run-record.md`.

That run exposed gaps in this plan, not only in the code:

- **The settings layer won.** `~/.claude/settings.json` sets
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="0"`, which overrode the command-line
  env prefix. Every captured line had `teams_env:"0"`, so `pick` (which keys
  on `""` and `"1"`) matched nothing: zero rows and `Outcome: X`. That X is
  false. The payloads agree with the 2026-07 record, and teams were never on.
- **The plan's outcome rules let a subagent count as a teammate.** The named
  `probe-mate` dispatch ran as a plain subagent:
  - `agent_id` present, `agent_type: general-purpose`;
  - the same `session_id` as the lead;
  - a `SubagentStop` in the lead's session;
  - exactly the subagent control's keys.

  With teams_env fixed, `outcome()` would have printed a **false A**.
- The code gaps (a)-(f) in the coordinator's report are carried into the unit
  below.

### Unit: esf-eid-probe-fix

Suggested model: sonnet.
- **Survey:** no `.fail` record exists for `esf-eid-probe` or
  `esf-probe-tests`; both PASSed first time.
- **Caveat:** that PASS let a false-A classification through, so the reviewer
  must mutation-check every outcome branch (the criteria below enforce this).
  If this unit FAILs once, the ratchet moves it to opus.

## Objective
Make the identity probe's outcome trustworthy before its first real run:
- control rows are found by run, not by the env value the hook saw;
- only a **genuine teammate** can yield A/B/C/C′;
- a missing control yields **U**, never X;
- the reviewer's code gaps (a)-(f) are closed, each with a test and, for every
  outcome branch, a mutation control.

## Retrieval
- This plan: § Decision tree (A/B/C/C′/D/U/X as amended), and this amendment.
- `scripts/probe-hook-identity.sh` and `tests/probe-hook-identity.test.sh` at
  `2ef26a2`.
- The accidental-run record above, in particular its Appendix lines 33-44:
  the real main, subagent and false-teammate payload shapes. Use them as
  fixtures.

## Affected files
- `scripts/probe-hook-identity.sh`
- `tests/probe-hook-identity.test.sh`

## Ordered edits
1. **Resolve paths at top level, before any `cd`.** These assignments sit at
   the top level, so that sourcing the script sets them:
   - **REC (gap f):**
     `case $REC in /*) ;; *) REC="$PWD/$REC" ;; esac`.
   - **SCRATCH:**
     `SCRATCH="${PROBE_SCRATCH:-/tmp/hook-identity-probe}"`, with CAP and RAW
     derived from it.
2. **Set the env per run in project settings (fact 1).** Before each run,
   `setup_run <run-id> <0|1>` rewrites the scratch `.claude/settings.json`:
   - the hooks block stays as it is;
   - `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` becomes `"0"` for run 1 and
     `"1"` for run 2. Project settings take precedence over user settings;
     whether that held is read back from the `teams_env` column, never assumed;
   - `<run-id>` (`run1`/`run2`/`run2-tmux`) is written to `$SCRATCH/run-id`.

   The capture hook adds `run:` (the contents of that file) to every line.
   Drop the command-line env prefix from `run_headless`.
3. **Pick by run.** `actor_line` selects:
   - main: `run=="run1"`, marker `echo probe-main`;
   - main-teams: `run` starts with `run2`, same marker;
   - subagent: `run=="run1"`, marker `echo probe-subagent`;
   - teammate: `run` starts with `run2`, marker `echo probe-teammate`.

   `teams_env` is reported, never used to pick.
4. **Add the teammate-genuineness check (fact 2).** This is a pure function
   `teammate_check <capture> <teammate-line> <main-teams-line>`. It prints
   exactly one of `genuine`, `teams-off`, `subagent-shaped`:
   - **`teams-off`**: the teammate line's `teams_env` is not `1`.
   - **`subagent-shaped`**: the teammate line has a non-empty `agent_id`,
     **and** the same `session_id` as the main-teams line, **and** a
     `SubagentStop` line with that `agent_id` and `session_id` exists, **and**
     its keys are a subset of the subagent control row's keys.
   - **`genuine`**: anything else. This includes a different `session_id`, a
     key that the subagent control lacks, or no `agent_id` at all. The last
     case is the indistinguishable-from-main C path; attribution there still
     rests on the lead-transcript check.

   `classify_rows` emits `Teammate check: <value>`, and emits the teammate's
   Identity/Keys rows only when the value is `genuine`. So a non-genuine
   teammate yields no row and the outcome is **D**. The record's Status names
   the check value.

   Honest limit, written into Method: a genuine in-process teammate that
   carries an `agent_id` and a lead-session `SubagentStop` cannot be told from
   a subagent. It is classified `subagent-shaped`, so D. That is conservative:
   both gates already deny any non-empty `agent_id`.
5. **Rework `outcome()`.**
   - Return `U` when the main, main-teams or subagent row is missing.
   - Return `X` only when such a row exists and disagrees with the 2026-07
     record.
   - Otherwise keep the existing logic.
6. **Sanitize and parse safely (gap a).**
   - Add the one-line function
     `clean() { tr -c 'A-Za-z0-9:._\n-' '_'; }`.
   - `emit_row` passes every payload-derived value through `clean`.
   - `rf` reads the **first** `key=value` token whose key equals the field,
     with no greedy `(.* )?`.
7. **Make the tmux path wait properly (gap b).**
   - **Spawn prompt.** Tmux is retried whenever run 2 produced no `genuine`
     teammate, not only when the marker is missing. The run-2 and tmux
     prompts ask for an agent team in the agent-teams docs' wording:
     *"Create an agent team with one teammate named probe-mate. Its only task
     is to run the Bash command `echo probe-teammate`, then message the lead
     `done`."* Use the same wording headless and in tmux.

     Whether headless can spawn a teammate at all is not known. Method says
     so, and a headless run that yields no genuine teammate is reported as
     such, never inferred.
   - **Pure `pane_state <pane-text>`.** It prints `ready` for a line matching
     `^❯` when the pane contains no `trust` (case-insensitive); `trust` when a
     workspace-trust prompt is visible; `wait` otherwise. On `trust`, the
     script presses Enter once (the scratch dir is the script's own) and
     records `Tmux note: workspace-trust prompt accepted for <SCRATCH>`.
   - **Pure `teammate_done <capture>`.** It returns 0 only when the teammate
     marker's PreToolUse line exists **and** a `Stop`/`SubagentStop` line
     with the same `session_id` and `agent_id` follows it. The wait loop
     (up to 180 s) uses this, not `have_marker`.
8. **Make the record say what happened (gap d).**
   - Add a `Tmux retry: ran (<teammate_check value from run 2>)` or
     `Tmux retry: not-run (genuine teammate captured headless)` line.
   - Method names every captured field, including `permission_mode`, `name`
     and `run`, and describes the genuineness check and U.
9. **Test hygiene (gaps e and d).**
   - The test creates its PATH stubs **before** its first `source`. The
     stubbed binaries are `claude`, `tmux` and `sleep`.
   - Every mktemp lives under one root, removed by `trap ... EXIT`.
   - `PROBE_SCRATCH` points inside that root.
10. **Tag each guarded branch.** Each branch below is one complete statement on
    one line, ending with its tag. Each tag appears exactly once in the
    script.

    | Tag | Branch |
    |---|---|
    | `# BR-maint-aid` | main-teams `agent_id` not absent → X (gap c, :95) |
    | `# BR-sub-missing` | subagent row missing → U (gap c, :93) |
    | `# BR-sub-aid` | subagent `agent_id` not present → X (gap c, :94) |
    | `# BR-tx-unreadable` | unreadable transcript → withheld (gap c, :53) |
    | `# BR-tx-noref` | no reference transcript → withheld (gap c, :65) |
    | `# BR-teams-off` | the `teams-off` arm of `teammate_check` |
    | `# BR-subagent-shaped` | the `subagent-shaped` arm |
11. **New test cases.** Keep I1-I9 green. Retarget I1's fixture so its
    teammate is genuine (distinct `session_id`); the old I1 fixture is now
    expected to give D (I13). Cases:
    - **I10.** A teammate `agent_type` of `x agent_id=present`: the outcome is
      not A, and the row matches `agent_type=x_agent_id_present `.
    - **I10b.** `rf` on `Identity row: teammate agent_id=absent agent_type=y teams_env=1 x agent_id=present`
      returns `absent`.
    - **I11.** The accidental run: every line has `teams_env:"0"`, with correct
      `run` fields. The main and main-teams rows are found,
      `Teammate check: teams-off`, outcome D.
    - **I12.** Main-teams carries an `agent_id` → X (BR-maint-aid).
    - **I13.** The accidental-run false teammate (fixture copied from Appendix
      lines 39-44, with `teams_env` `1`): `Teammate check: subagent-shaped`,
      no teammate row, outcome D.
    - **I14.** No subagent row → U (BR-sub-missing).
    - **I15.** The subagent `agent_id` is absent → X (BR-sub-aid).
    - **I16.** The reference transcript is unreadable (`chmod 000`; SKIP with
      a printed reason when running as root) → the teammate row is withheld
      (BR-tx-unreadable).
    - **I17.** There is no main-teams line, so no reference transcript → the
      teammate row is withheld (BR-tx-noref).
    - **I18.** `pane_state`: a trust-prompt text gives `trust`; `❯` alone gives
      `ready`; an empty pane gives `wait`.
    - **I19.** `teammate_done`: a marker PreToolUse with no matching stop gives
      1; with a matching stop it gives 0; a stop with a different `agent_id`
      gives 1.
    - **I20.** Sourcing the script with a relative record path from another
      cwd leaves `$REC` absolute.
    - **I21.** `method_text` names `permission_mode`, `name`, `run` and
      `subagent-shaped`. A `write_record` call with stubbed state prints
      exactly one `Tmux retry:` line.

## Do NOT touch
- any file except the two above;
- `hooks/`, `.claude/`, `docs/experiments/`;
- the decision-tree gate actions;
- the parent plan.

Do not run the probe against the real CLI. The operator does that after
PASS.

## Acceptance criteria
Save as a file and run it with `bash`. No real `claude`: every run of the suite
is under stubs.
```sh
set -e
s=scripts/probe-hook-identity.sh; t=tests/probe-hook-identity.test.sh
bash -n "$s"
bash "$t"
for i in 1 2 2b 3 4 5 6 7 8 9 10 10b 11 12 13 14 15 16 17 18 19 20 21; do grep -qF "(I$i)" "$t" || { echo "missing I$i"; exit 1; }; done
for b in maint-aid sub-missing sub-aid tx-unreadable tx-noref teams-off subagent-shaped; do test "$(grep -c "# BR-$b\$" "$s")" = 1 || { echo "tag BR-$b not exactly once"; exit 1; }; done
grep -qE '^clean\(\) \{ .*\}$' "$s"
# branch mutation controls: deleting any tagged branch, or neutering clean(), must turn the suite red
mut() { d=$(mktemp -d); sed "$2" "$s" > "$d/p.sh"; if cmp -s "$d/p.sh" "$s"; then echo "mutant $1 did not apply"; exit 1; fi
  if PROBE_UNDER_TEST="$d/p.sh" bash "$t" >/dev/null 2>&1; then echo "VACUOUS $1"; exit 1; fi; rm -rf "$d"; }
for b in maint-aid sub-missing sub-aid tx-unreadable tx-noref teams-off subagent-shaped; do mut "BR-$b" "/# BR-$b\$/d"; done
mut clean 's/^clean() {.*$/clean() { cat; }/'
# gap e: a guard-less mutant must hit the TEST's stubs, never an outer claude/tmux
o=$(mktemp -d); for b in claude tmux; do printf '#!/bin/sh\ntouch %s/OUTER\nexit 99\n' "$o" > "$o/$b"; chmod +x "$o/$b"; done
d=$(mktemp -d); sed 's/^\[ "\${BASH_SOURCE\[0\]}" = "\$0" \] && main "\$@"$/main "$@"/' "$s" > "$d/p.sh"; ! cmp -s "$d/p.sh" "$s"
PATH="$o:$PATH" PROBE_UNDER_TEST="$d/p.sh" timeout 120 bash "$t" >/dev/null 2>&1 || true
test ! -e "$o/OUTER"; rm -rf "$o" "$d"
# gap d: the suite leaves no temp dirs behind
tt=$(mktemp -d); TMPDIR="$tt" bash "$t" >/dev/null; test -z "$(ls -A "$tt")"; rm -rf "$tt"
bash tests/validate.sh
```

## Pre-resolved context
- **Real payload shapes**, from the accidental run's Appendix:
  - main: no `agent_id` or `agent_type` keys;
  - subagent: `agent_id` and `agent_type: general-purpose`, the lead's
    `session_id`, and a `SubagentStop` carrying `agent_transcript_path`.
- The false teammate was byte-for-byte subagent-shaped. Run 2 never had teams
  enabled, so this does not show that a named dispatch with teams on still
  yields a subagent.
- `grep` in an inline Bash call is ugrep, while inside `bash script.sh` it is
  GNU grep.

## Escalation
If project-settings `env` cannot be written without touching anything outside
`$SCRATCH`, stop and report. Never edit `~/.claude/settings.json`.

### Self-check (Amendment B1)
- CHK14: Can any outcome other than D, U or X arise from a teammate that is
  not genuine? — PASS. `classify_rows` emits a teammate row only when the
  check reads `genuine` (edit 4); I13 pins it, and the `BR-subagent-shaped`
  mutant must turn the suite red.
- CHK15: Do the decision tree and the unit agree on U and the narrowed X? —
  PASS (the table rows above, edit 5, I14/I15).
- CHK16: Is every branch the reviewer listed under gap (c) mutation-checked? —
  PASS (five tags, each deleted by `mut`).
- CHK17: Is the headless-teammate question answered without inference? — PASS
  (edit 7: Method states it is unknown; the result is whatever
  `teammate_check` reports).
- CHK18: Do the criteria call the real CLI? — PASS (stubs throughout; the
  gap-e check fails if an outer stub is reached).

---

## Amendment C1 (2026-10-03): `esf-gate-bytes`

The user approved this through AskUserQuestion: plan it as its own unit and
land it **before the escalation work ships** (that is, before `esc-chat-3`).

It comes from the `esc-chat-2b` reviewer's advisory findings (PASS at
`012e7d8`).

**Verified by spec-master on 2026-10-03.** I re-ran finding 3 against
`hooks/scripts/reviewed-path-gate.sh` in a scratch mktemp project. With
`cat<sep>> .claude/reviewed/x.pass <<'EOF'` and `<sep>` in
{space, `\v`, `\r`, `\f`}:
- the gate exits **2 for `lead-programmer`** for every separator;
- it exits **0 for `reviewer`** for every separator. That is the reviewer's
  existing grant, not a parser hole.

**No reviewed-path-gate change is planned.** The hole is real only in
`human-decision-gate.sh`'s `is_sanctioned_marker_write`. That function is
reached only when the command text spells both the packet-directory token and
the decision token. There, a `\v`, `\f` or `\r` after `cat` matches
`[[:space:]]`, so the gate allows a command that bash does not split. The
redirect then creates an empty or truncated marker, and `cat<VT>` fails with
rc 127.

### Unit: esf-gate-bytes

Suggested model: opus.
- `hdg-prose-2` hit the 2-FAIL cap on this file.
- `379` and `380` FAILed on the composer.
- `esc-chat-2b` only passed with advisory findings, and this unit is those
  findings.

## Objective
Make the prompt-route grammar in `human-decision-gate.sh` independent of the
inherited locale, and make the gate agree byte-for-byte with
`decision-block.js` on lookalike, bidi and zero-width characters. Close the
`[[:space:]]` hole in `is_sanctioned_marker_write`. Check refused corpus
entries against the gate as well as emitted ones. Each fix gets a mutation
control.

## Retrieval
- This amendment.
- `hooks/scripts/human-decision-gate.sh` in full, especially:
  - `is_sanctioned_marker_write` (around line 87);
  - `decision_body_ok` (around lines 160-194);
  - the `ws=$' \t'` convention in `is_prompt_eligible_decision_write` (around
    line 137).
- `bin/microworld-dashboard/decision-block.js`, especially `CONTROL_RE` (around
  line 81), the leading-space screen (around line 41) and `RESERVED_KEY_RE`.
- `tests/human-decision-gate.test.sh` PG13-PG19 (around lines 1085-1166).
- `tests/microworld/dashboard-decision-block.test.js`.

## Affected files
- `hooks/scripts/human-decision-gate.sh`
- `bin/microworld-dashboard/decision-block.js`
- `tests/human-decision-gate.test.sh`
- `tests/microworld/dashboard-decision-block.test.js`
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (patch bump
  from the current `0.31.111`; re-derive it)
- generated by `node bin/cli.js --update`: the
  `.claude/hooks/scripts/human-decision-gate.sh` mirror and its `fileHashes`
  entry

## Ordered edits
1. **Byte screen (finding 1).** Add `forbidden_bytes()`. It takes one line and
   returns 0 when the line holds a forbidden byte sequence.
   - Its first statement is `local LC_ALL=C`, so matching is bytewise in every
     inherited locale.
   - Each screen is one standalone statement of the form
     `[[ $1 == *<pattern>* ]] && return 0`, ending with its tag:

     | Tag | Bytes | Characters |
     |---|---|---|
     | `# BYTE-C0` | `[[:cntrl:]]` under C | C0 and DEL |
     | `# BYTE-C1` | `$'\xc2'[$'\x80'-$'\x9f']` | U+0080-U+009F, including U+009B CSI |
     | `# BYTE-LS` | `$'\xe2\x80'[$'\xa8\xa9']` | U+2028, U+2029 |
     | `# BYTE-BIDI` | `$'\xe2\x80'[$'\x8b'-$'\x8f'$'\xaa'-$'\xae']`, `$'\xe2\x81'[$'\xa0'$'\xa6'-$'\xa9']`, `$'\xef\xbb\xbf'` and `$'\xd8\x9c'` (one tagged line per pattern) | zero-width U+200B-U+200D, U+2060, U+FEFF; bidi U+200E/U+200F, U+202A-U+202E, U+2066-U+2069, U+061C |

     The function ends with `return 1`.
2. **Apply the screen.** In `decision_body_ok`, `forbidden_bytes` rejects:
   - the `by:` line;
   - the `reason:` line;
   - every continuation line.

   The `[^[:cntrl:]]` in `by_re`/`reason_re` and the `[[:cntrl:]]` test on
   continuation lines may stay. They become redundant, not wrong.
3. **Lookalike leading characters (finding 2).** For continuation lines,
   reject the line when the run of characters before its first ASCII
   alphanumeric holds any byte >= 0x80. This is one standalone statement,
   under `LC_ALL=C`, ending with `# LEAD-NONASCII`. It covers NBSP, U+3000,
   U+202E and every other non-ASCII lead-in.
   - Accepted false refusal: a continuation line that *starts* with a
     non-ASCII letter, such as `Ñ...`, is refused. That fails closed, and the
     orchestrator falls back to the terminal route.
   - Non-ASCII text **after** an ASCII alphanumeric still asks, so PG13 "a
     non-ASCII reason still asks" keeps its verdict.
4. **Composer parity.** `decision-block.js` refuses exactly the same sets:
   - Widen the `by`/reason control screen to the edit-1 set:
     `/[\u0000-\u001f\u007f-\u009f  ​-‏‪-‮⁠⁦-⁩﻿؜]/`.
   - Add `LEAD_NONASCII_RE = /^[^A-Za-z0-9]*[^\x00-\x7f]/` for continuation
     lines.
   - Every gate/composer disagreement must fail closed, which means the
     composer refuses whatever the gate refuses.
5. **Marker separators (finding 3).** In `is_sanctioned_marker_write`, right
   after `first=` is set, add this standalone statement:
   `[[ $first == *[$'\v\f\r']* ]] && return 1  # MARKER-WS`.
   Leave the existing regex as it is, since the guard is what the mutation
   deletes.
6. **Test the locale matrix.** In `tests/human-decision-gate.test.sh`, add:
   - **PG20.** For each locale in `C`, `POSIX` and `C.UTF-8`, run every PG13
     case and one case per byte class from edit 1 with `LC_ALL` set to that
     locale in the gate's environment. The expected verdict is identical
     across all three locales: blocked for each class, and PG13's
     non-ASCII-reason case still asks.
   - **PG21.** Lookalike lead-ins: a continuation line `<X>via: dashboard`
     for X in NBSP, U+3000 and U+202E → blocked. `résumé follows` → ask.
   - **PG22.** Marker separators: a sanctioned `.pass` marker heredoc whose
     body spells both tokens (built at runtime), with `\v`, `\f` or `\r`
     after `cat` → exit 2. With a space or a tab → exit 0, unchanged.
7. **Refused corpus entries (finding 4).** Extend PG19 so every corpus entry
   the composer **refuses** is also built raw, with a test-side builder that
   emits the same heredoc shape without screening, and run through the gate,
   expecting `blocked`.
   - Exactly one exemption, frozen in a commented table:
     `NUL: harmless — a NUL cannot reach the gate as part of a bash command
     string, so no DECISION file can carry it; gate acceptance of the
     NUL-truncated remainder is not a disagreement`.
   - Add a PG19 count assertion that the refused-and-checked total equals the
     corpus size, minus the 4 emitted entries, minus the 1 exemption.
   - Add a corpus entry per byte class in edit 1 and per lookalike in PG21.
8. **Composer test.** In `dashboard-decision-block.test.js`, add one refusal
   assertion per added character class and per lookalike lead-in, and one
   acceptance for non-ASCII text after an ASCII letter.
9. **Fixtures.** Every fixture that spells both the packet-directory path and
   the decision name builds them at runtime, in mktemp projects (plan R6).
   Commit with `git commit -F <file>`.
10. **Release.** Bump the patch version in `plugin.json` and `package.json`,
    add a CHANGELOG entry, and run `node bin/cli.js --update`, all in the same
    commit.

## Do NOT touch
- `hooks/scripts/reviewed-path-gate.sh` (finding 3's check there was negative;
  see above);
- `harness-integrity-gate.sh`;
- the mode allowlist;
- the absolute-target rule;
- every pre-existing test case's verdict;
- `agents/`, `templates/`, `adapters/` (these belong to esc-chat-3).

The prompt branch must never print `allow`.

## Acceptance criteria
Save as a file and run it with `bash`:
```sh
set -e
g=hooks/scripts/human-decision-gate.sh; t=tests/human-decision-gate.test.sh
bash "$t"
node tests/microworld/dashboard-decision-block.test.js
for c in PG19 PG20 PG21 PG22; do grep -qE "$c[^0-9]" "$t" || { echo "missing $c"; exit 1; }; done
! grep -q '"allow"' "$g"
grep -q 'local LC_ALL=C' "$g"
for tag in BYTE-C0 BYTE-C1 BYTE-LS LEAD-NONASCII MARKER-WS; do test "$(grep -c "# $tag\$" "$g")" = 1 || { echo "tag $tag not exactly once"; exit 1; }; done
test "$(grep -c '# BYTE-BIDI$' "$g")" -ge 1
# mutation controls: deleting any guard line must turn the suite red
mut() { d=$(mktemp -d); cp -r hooks "$d/"; sed "$2" "$g" > "$d/$g"; chmod +x "$d/$g"; if cmp -s "$d/$g" "$g"; then echo "mutant $1 did not apply"; exit 1; fi
  if GATE_UNDER_TEST="$d/$g" bash "$t" >/dev/null 2>&1; then echo "VACUOUS $1"; exit 1; fi; rm -rf "$d"; }
for tag in BYTE-C1 BYTE-LS BYTE-BIDI LEAD-NONASCII MARKER-WS; do mut "$tag" "/# $tag\$/d"; done
# Amendment C2: the locale mutant is killed by PG20-gb18030, which needs localedef and the GB18030 charmap
if command -v localedef >/dev/null 2>&1 && [ -e /usr/share/i18n/charmaps/GB18030.gz ]; then
  d=$(mktemp -d); cp -r hooks "$d/"; sed '/^ *local LC_ALL=C$/d' "$g" > "$d/$g"; chmod +x "$d/$g"; ! cmp -s "$d/$g" "$g"
  o="$(GATE_UNDER_TEST="$d/$g" bash "$t" 2>&1 || true)"; rm -rf "$d"
  printf '%s\n' "$o" | grep -q '^FAIL.*PG20-gb18030' || { echo "VACUOUS locale"; exit 1; }
  bash "$t" | grep -q '^OK.*PG20-gb18030' || { echo "PG20-gb18030 did not run on the unmutated gate"; exit 1; }
else
  bash "$t" | grep -qx 'SKIP locale (no localedef)' || { echo "localedef absent but the suite did not print the SKIP line"; exit 1; }
  echo "SKIP locale (no localedef)"   # not a kill: the locale mutant is unproven on this host
fi
grep -q 'MARKER-WS' .claude/hooks/scripts/human-decision-gate.sh
test "$(jq -r .version .claude-plugin/plugin.json)" = "$(jq -r .version package.json)"
grep -qF "$(jq -r .version .claude-plugin/plugin.json)" CHANGELOG.md
bash tests/validate.sh
```
**Amendment C2 (2026-10-03): the locale mutant.** This replaces the paragraph
the plan originally had here, which was false.

*What the plan got wrong.* The plan claimed that removing `local LC_ALL=C`
shows up under `C.UTF-8`. The lead-programmer measured otherwise on bash
5.2.21:
- a pattern containing a partial UTF-8 sequence still matches byte by byte;
- under UTF-8, `[[:cntrl:]]` already covers C1 and U+2028/9.

Over 21,888 byte sequences, `forbidden_bytes` with and without the line
differed **0** times under C and C.UTF-8, and **53** times under a scratch
GB18030 locale (for example bytes `a2 a1` before `via`). So the line is the
correct defence, and it matters only in non-UTF-8 multibyte locales. It
**stays**.

*The new case, PG20-gb18030.* Add it to `tests/human-decision-gate.test.sh`:
- When `localedef` and `/usr/share/i18n/charmaps/GB18030.gz` exist, it builds
  `zh_CN.GB18030` into a mktemp `LOCPATH` (`localedef -f GB18030 -i zh_CN`).
- It runs at least one of the 53 measured differing inputs (one for which the
  mutant reaches `ask`) through the gate with `LOCPATH` and
  `LC_ALL=zh_CN.GB18030` set in the gate's environment, and expects `blocked`.
- It reports through the suite's own `pass`/`bad`, so it prints
  `OK   ... PG20-gb18030 ...` or `FAIL ... PG20-gb18030 ...`.
- When either prerequisite is missing, it prints exactly
  `SKIP locale (no localedef)`. A skip counts as neither a pass nor a failure
  in the suite's own tally.
- The mktemp `LOCPATH` is removed on exit.

*How the acceptance script tells a kill from a skip.*
- **Kill:** the prerequisites exist and the mutated suite prints a
  `FAIL ... PG20-gb18030` line. A kill is identified by that **named FAIL
  line**, not by the suite's exit status, so an unrelated failure cannot pass
  as a kill.
- **VACUOUS:** the prerequisites exist and that line does not appear.
- **Skip:** the prerequisites are missing. The script prints
  `SKIP locale (no localedef)` and continues. It never prints VACUOUS, and a
  skip is never recorded as a kill.

On this host both prerequisites exist (2026-10-03), so the kill is
**required** here.

*BYTE-C0 survives by design.* Its mutant stays green because the retained
`[[:cntrl:]]` checks in `by_re`, `reason_re` and the continuation-line test
cover C0 and DEL (edit 2). That is why the mutation loop above omits it. Only
its presence is asserted, exactly once.

## Pre-resolved context
- **The finding-1 measurement** (reviewer, 53-entry fuzz): under `LC_ALL=C`,
  7 entries that the composer refuses still reach `ask`; under `C.UTF-8` the
  two agree.
- **Available locales here:** `C`, `C.utf8` and `POSIX` (`locale -a`,
  2026-10-03). `en_US.UTF-8` is absent, so do not depend on it.
- **Separator convention:** `is_prompt_eligible_decision_write` already uses
  `ws=$' \t'` (esc-chat-2b). Keep it.
- **The reviewed-path-gate check was negative:** do not edit that file.
- **Test through the suite** with `GATE_UNDER_TEST`, never through the live
  hook.

## Escalation
- If `local LC_ALL=C` inside a function does not make `[[ == ]]` bytewise in
  this bash, stop and report rather than switching to a subprocess. That
  would change the gate's fork profile, which is a separate decision.
- Amendment C2: if `localedef` succeeds but no measured GB18030 input reaches
  `ask` under the mutant, stop and report the measurement. Never weaken
  PG20-gb18030 into an assertion that also passes on the mutant.
- If any pre-existing case changes verdict, stop. That is a branch-agreement
  regression of the `hdg-prose-2` class.

### Self-check (Amendment C1)
- CHK19: Does every finding (1-4) map to an edit and a mutation-checked
  criterion? — PASS:
  - finding 1 → edits 1-2, PG20, and the C1/LS/locale mutants;
  - finding 2 → edits 1, 3 and 4, PG21, and the BIDI/LEAD mutants;
  - finding 3 → edit 5, PG22, and the MARKER-WS mutant;
  - finding 4 → edit 7, with its count assertion.
- CHK20: Is finding 5 handled? — PASS. It was added on 2026-10-03 to the
  esc-chat-3 contract's "Pre-resolved context" in
  `docs/plans/2026-10-01-in-session-escalation-decision.md`. That is a
  one-bullet append; the parent plan is otherwise unchanged.
- CHK21: Is the decision on bidi/zero-width characters stated, and identical
  in gate and composer? — PASS (both refuse, edits 1 and 4; PG19 extended plus
  the composer test).
- CHK22: Is NUL's exemption explicit? — PASS (edit 7 has a frozen one-entry
  table with its reason).

---

## Ordering against in-flight work (esc-chat-2b, esc-chat-3, esc-chat-4)

| Unit | Relation to in-flight units | Why |
|---|---|---|
| esf-eid-probe | **parallel** with all three | new files only (`scripts/`, `tests/`, one `validate.sh` block) |
| esf-eid-probe-fix | **parallel** with all three | the same two files as esf-eid-probe, nothing else |
| operator identity run | parallel, but **only after esf-eid-probe-fix PASS** | out-of-repo scratch dir; commits only a record |
| esf-eid-gate | **after esc-chat-2b**; independent of esc-chat-3 and esc-chat-4 | edits `human-decision-gate.sh`, esc-chat-2b's file. It changes gate behaviour, so if it lands before esc-chat-4, esc-chat-4's docs describe the gate as landed (esc-chat-4's own Escalation rule already requires that) |
| esf-probe-tests | **parallel** with all three | tests only; does not touch the probe script |
| esf-flag-fix | **after esc-chat-2b** (serial: shared version/CHANGELOG/`fileHashes`/`--update`); independent of esc-chat-3 and esc-chat-4 | no file in common with esc-chat-3 or esc-chat-4 except the version triple |
| esf-gate-bytes | **after esc-chat-2b (landed) and after esf-flag-fix**; **before esc-chat-3** | It touches no file esf-flag-fix edits (`human-decision-gate.sh` and the composer, not the stop-gate/route-gate libs), but both bump the version, change CHANGELOG and run `--update`, which rewrites the mirror `fileHashes` in the persona config. Those collide, so the two land sequentially, flag-fix first. It must land before the escalation work ships |
| esf-flag-prose | **after esc-chat-3 and after esf-flag-fix** | same protocol and orchestrator surfaces as esc-chat-3; describes esf-flag-fix's behaviour |

Suggested sequence:

1. `esf-eid-probe` and `esf-probe-tests` (both landed), then
   `esf-eid-probe-fix`, now.
2. `esc-chat-2b` (landed, `012e7d8`).
3. `esf-flag-fix`.
4. `esf-gate-bytes` (Amendment C1). This is **required before esc-chat-3**.
5. `esc-chat-3`.
6. `esf-flag-prose`.
7. `esc-chat-4`.

`esf-eid-gate` slots in after `esc-chat-2b`, once the operator record exists.
It also edits `human-decision-gate.sh`, so it never runs alongside
`esf-gate-bytes`: whichever is dispatched second waits for the first one's
PASS.
That record can only come from a run made after `esf-eid-probe-fix` PASSes.

## Open Questions

None open. All four were answered by the user on 2026-10-02, each with the
recommended default. The answers are recorded in Clarifications:

1. Item 3 fix: (a) a flag tombstone, with resurrected flags dropped in both
   gates.
2. Outcome C: (a) deny `ask` while `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
3. The `harness-integrity-gate.sh` `ask_allowed` guard: (a) yes, in the same
   unit (esf-eid-gate).
4. esc-chat-4: (a) does not wait. The orchestrator tells it to describe the
   teammate premise as unmeasured, citing this plan.

## Self-check

- CHK1: Does each Goal clause (G1-G3) map to a unit criterion? — PASS:
  - G1 maps to esf-eid-probe (I1-I9 and the outcome function) and
    esf-eid-gate (TG1-TG4).
  - G2 maps to esf-probe-tests (T1-T9 and five mutants).
  - G3 maps to esf-flag-fix (R1-R7 and the mutation control) and
    esf-flag-prose (the claim greps).
- CHK2: Is the item 3 root cause stated with evidence that anyone can re-run?
  — PASS (evidence table cites audit-log line numbers; the reproduction output
  is quoted; R1 replays it).
- CHK3: Do the R1/R2 criteria fail on today's code? — PASS (measured
  2026-10-02 at `8428fab`: `remaining=1` twice, dispatch rc=2).
- CHK4: Is each esf-probe-tests mutant shown to apply? — PASS (each `sed`
  measured to change exactly one line at `8428fab`; the criterion also
  `cmp`-checks that each applies).
- CHK5: Does every new suite sit above `exit "$fail"` in validate.sh? — PASS
  (an awk ordering check in all three units).
- CHK6: Is the item 3 fix design one the user has chosen? — FAIL (missing) —
  converted to Open Question 1, answered 2026-10-02 (a).
- CHK7: Is the gate action defined for every identity outcome? — FAIL
  (missing, for outcome C) — converted to Open Question 2, answered 2026-10-02 (a). A, B, C′, D and X
  are defined in the decision tree.
- CHK8: Do the Context's blast-radius list and esf-eid-gate agree on which
  gates get the guard? — FAIL (conflicting: Context names three sites, and the
  unit covers one or two) — revised in place (R5 puts the third site out of
  scope) and converted to Open Question 3 for the second site, answered 2026-10-02 (a).
- CHK9: Do this plan's ordering and the parent plan's esc-chat-4 agree on the
  teammate premise? — FAIL (conflicting: the parent's ADR draft assumes
  "main session = no agent_id" without qualification) — converted to Open
  Question 4, answered 2026-10-02 (a): R4's note travels with the esc-chat-4
  dispatch. This plan does not edit the parent plan.
- CHK10: Is every constitution MUST principle checked? — FAIL (missing: the
  constitution was not re-read in full here, only P3 was checked) — revised in
  place: the Constitution check tells the dispatcher to re-read it and add a
  line per principle. The residual is recorded there, and needs no user
  input.
- CHK11: Is the esf-eid-probe mutation criterion runnable whatever the
  implementation does? — FAIL (ambiguous: the `sed 's/echo A$/echo D/'` only
  bites if `outcome()` prints A with `echo A`) — revised in place: made a
  stated precondition of the criterion.
- CHK12: Does "may run in parallel" conflict with the one-unit-at-a-time
  review invariant? — PASS (R2 defines parallel as "no ordering dependency").
- CHK13: Is it defined how a genuine re-completion by the same agent survives
  the tombstone? — PASS (esf-flag-fix edit 1, re-arm; R3a and R3b).

**Ubiquitous-language check (prose mode, advisory).**

- Lens 1 (a defined term used with a new meaning): none found.
- Lens 2 (a new synonym for a defined term): "stale flag" is used informally
  for what this plan names **flag resurrection**. The plan uses the latter in
  every criterion.
- Lens 3 (a new term with no entry): **flag resurrection**, **flag
  tombstone** and **identity row** are new. All are routed to scribe below.

## Scribe update hint

After esf-flag-fix and esf-flag-prose land:

- add the CONTEXT.md glossary entries **flag resurrection** and **flag
  tombstone**;
- confirm that **bounded flag clearing** exists (it was routed by the
  2026-09-09 plan).

After the identity record lands, add one line to the agent-teams entry, if one
exists, stating the measured teammate `agent_id` behaviour.
