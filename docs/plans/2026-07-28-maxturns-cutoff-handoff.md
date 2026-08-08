# Spec (FINAL): maxTurns cutoff must produce a handoff, not a silent truncation

Status: **FINAL — ready for `task-master` slicing.** All five Open Questions
from the 2026-07-28 draft are answered by the user and recorded in
Clarifications below. Steps are numbered, affected files are exact, and every
acceptance criterion is a runnable command.

Source: observed live 2026-07-28 — a `spec-master` dispatch (`maxTurns: 30`)
was mid-way through editing a spec doc and republishing a GitHub issue, hit
its cap, and was force-ended. The Agent-tool result the orchestrator received
was a dangling half-sentence ("Now the Open Questions section.") with no error,
no marker, and no indication anything was wrong — visually indistinguishable
from a completed dispatch.

Distinct from the already-in-flight microworlds/human-review spec
(`docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md`,
issue #122). No file overlap intended, and none found: that spec touches
`agents/reviewer.md`, `templates/persona-config.schema.json`, `bin/cli.js`,
and `README.md`; this one touches the protocol templates, `agents/orchestrator.md`,
`agents/spec-master.md`, `agents/task-master.md`, the two adapter protocol
ports, `tests/adapter-protocol-parity.test.js`, and three `docs/` files.

## Goal

When a dispatched persona's turn is force-ended by its `maxTurns` cap, the
orchestrator must be able to tell — **mechanically, not by reading the prose
shape of the result** — that the dispatch was cut off mid-task rather than
completed. Today the only signal is the orchestrator noticing the result
"looks like a fragment," which is a fragile heuristic and the actual defect
being fixed.

Secondary, bundled at the user's explicit direction (see
"Bundled scope change" below): raise `spec-master` and `task-master` from
`maxTurns: 30` to `maxTurns: 40`, so the two personas actually observed
hitting the cap hit it less often.

## Context

### Existing mechanisms this builds on (not replacing)

- **WIP sentinel** (`templates/persona-protocol.md` §"WIP sentinel", canonical
  line 67): `.claude/wip-handoff.<agent-id>`, non-empty reason required,
  logged to `.claude/wip-audit.log` by `hooks/scripts/stop-gate.sh`, self-
  deleting, allows exactly one turn-end. Entirely **voluntary** — the persona
  writes it before ending its own turn.
- **Pending-review flag** (§"Pending-review flag", canonical line 158):
  `.claude/.pending-review.<agent-id>`, written automatically by
  `stop-gate.sh` on a **gated** agent's `SubagentStop` when no WIP sentinel
  honored the stop. Closest existing precedent for "the hook layer notices an
  unflagged stop and marks it" — but scoped to `gatedAgents`
  (`["lead-programmer"]` in `.claude/persona-config.json`) and semantically
  about "awaiting review," not "cut off."
- **Orchestrator §"Managing a long-running background dispatch"**
  (`agents/orchestrator.md` line 329): already establishes the
  three-state (Still running / Finished / Killed) verify-then-resume idiom for
  a dormant subagent, and already forbids re-`Agent`-ing a live persona to
  resume it. A maxTurns-cutoff state is a natural fourth sibling to this
  section rather than a new concept.
- **Prior art for a docs-only protocol fix**:
  `docs/plans/2026-07-21-subagent-background-self-wake-protocol.md` (issue #89)
  fixed a structurally identical "persona believes something false about the
  harness" bug with protocol wording + orchestrator guidance and **no new
  hook**. That precedent is what OQ4 was ultimately decided on.

### Which personas actually carry a cap

Verified across both `agents/` (source) and `.claude/agents/` (mirror) — they
agree:

| Persona | `maxTurns` (today) | After this change |
|---|---|---|
| `explorer` | 10 | 10 (unchanged) |
| `milestone-auditor` | 20 | 20 (unchanged) |
| `lead-programmer` | 30 | 30 (unchanged) |
| `reviewer` | 30 | 30 (unchanged) |
| `spec-master` | 30 | **40** |
| `task-master` | 30 | **40** |
| `scribe` | *(none)* | *(none)* |
| `researcher` | *(none)* | *(none)* |
| `orchestrator` | *(none — main agent)* | *(none)* |

### How the shared protocol actually fans out (verified, and it is not one file)

This is the single most consequential structural fact for the universal-scope
decision (OQ1), and the draft did not have it:

- `bin/cli.js` **inlines** the protocol into each persona body at
  `.claude/agents/*.md` generation time (`inlineProtocolBlock`, cli.js:466-472;
  `renderCleanBody`, cli.js:475-490; `--update` path, cli.js:1610-1621). There
  is no `@import` — that was proven not to resolve inside a subagent body
  (issue #121 Step 2).
- There are **two** canonical protocol texts, not one
  (`SLIM_TIER_PERSONAS`, cli.js:34-38):
  - **full tier** → `templates/persona-protocol.md`: `orchestrator`,
    `lead-programmer`, `spec-master`, `task-master`, `reviewer`,
    `milestone-auditor`.
  - **slim tier** → `templates/persona-protocol-slim.md`: **`explorer`,
    `researcher`, `scribe`**. The slim file carries only 5 sections
    (Structural questions / Answer shape / Scope Bash output / Agent-teams
    mode / A note on `memory`).
- **`tests/adapter-protocol-parity.test.js` does not guard the slim file at
  all** — it derives the canonical section list from
  `templates/persona-protocol.md` and checks only
  `adapters/codex/agents-md-fragment.md` and
  `adapters/cursor/rules/persona-protocol.mdc`.

Consequence: adding the new section to `templates/persona-protocol.md` alone
would leave `explorer`, `researcher`, and `scribe` **silently exempt** — the
exact outcome OQ1's "all personas" answer exists to prevent — and `explorer`
carries the *tightest* cap in the repo (10) and is the highest-frequency
persona, i.e. the single most likely victim. Step 2 exists solely because of
this, and Step 3c adds the one mechanical guard that the universal scope
actually held.

### Empirical findings — what Claude Code actually exposes

Investigated directly against the installed binary
(`/home/sebas/.local/share/claude/versions/2.1.220`, ELF, **not stripped**),
plus session sidecar files and official docs, by the prior session.
Constitution P1 ("Verify, don't assume") — these are observed, not inferred,
and are **not re-derived here**; they are settled inputs.

**F1. Internally, max-turns termination IS a first-class, distinguishable
state.** The agent loop returns a reason from a fixed enum:

```
["stop_hook_prevented","hook_stopped","tool_deferred","max_turns",
 "background_requested","completed"]
```

with the max-turns path returning `{reason:"max_turns", turnCount:N}`.

**F2. The capped agent is never told.** On hitting the cap the harness yields
an attachment `{type:"max_turns_reached", maxTurns, turnCount}` — but the
attachment renderer registry maps it to **zero content blocks**:

```
... goal_status:()=>[], structured_output:()=>[], max_turns_reached:()=>[], ...
```

So the attachment renders nothing into the model's context. **A persona
cannot see that it hit its cap, cannot see its turn count, and cannot see its
own limit at runtime.** This kills any "react at the moment of the cap"
design, and makes proactive self-checkpointing unreliable (see F3).

**F3. No turn counter is observable from inside a subagent.** No env var, no
tool, no system-reminder, no injected message. (`CLAUDE_CODE_MAX_TURNS` exists
as an *input* env var only — it sets the cap, it does not report progress.)
A persona can read its own `maxTurns` from its frontmatter but has **no way to
know how many turns it has consumed**, so "self-checkpoint at N-5" is not
implementable as a counted rule — only as a vague "checkpoint often" heuristic.

**F4. Blocking from a Stop hook cannot rescue a capped turn.** In the path
where a stop hook blocks and continuing would exceed the cap, the harness
returns `max_turns` immediately (telemetry `tengu_stop_hook_block_count` with
`hit_max_turns:true`). The cap dominates the hook. Separately there is a stop-
hook block cap (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`, default 8) already noted in
the protocol.

**F5. `SubagentStop` almost certainly does NOT fire on the mid-tool-loop cap.**
The mid-loop check returns *before* the recursive query call and *before* the
stop-hook runner is invoked. Official docs corroborate: "Hooks may not fire
when the agent hits the `max_turns` limit because the session ends before
hooks can execute." This was the one item static inspection could not settle
conclusively. **It is now moot** — it gated only the hook-enforcement variants
of OQ4, which the user did not choose (see Clarifications / "Deferred").

**F6. The `SubagentStop` payload has no termination-reason field — but it does
carry the final message text.** Verified schema in v2.1.220:

```
hook_event_name:"SubagentStop", stop_hook_active, agent_id,
agent_transcript_path, agent_type,
last_assistant_message  // optional string:
                        // "Text content of the last assistant message before
                        //  stopping. Avoids the need to read and parse the
                        //  transcript file."
background_tasks, session_crons, session_id, transcript_path, cwd,
permission_mode
```

No `stop_reason` / `termination_reason` / `max_turns_reached`. But
`last_assistant_message` means a hook **could** machine-check the terminal
status line *if* the hook fired (F5) — retained here only as the seed for the
deferred future follow-up, not as part of this spec's scope.

**F7. The subagent sidecar metadata records no termination reason.** Inspected
`~/.claude/projects/<proj>/<session>/subagents/agent-*.meta.json`; keys are
only `agentType, description, parentAgentId, spawnDepth, toolUseId, model`.
No turn count, no exit reason. Post-hoc file inspection cannot recover it.

**F8. The distinguishable error subtype exists, but not on the path we need.**
`{subtype:"error_max_turns", errors:["Reached maximum number of turns (N)"],
is_error:true, num_turns:N}` is produced for the **top-level query result**
(SDK / `--print`), not for an `Agent`-tool result delivered to a parent
agent inside an interactive session. So the SDK surfaces this cleanly and
Claude Code's in-session subagent path does not — the asymmetry is real.

**F9. The gap is acknowledged inside the product.** A verbatim string in the
binary: *"Known gap: folds consumed by turns ending via max_turns /
hook_stopped / tool_deferred / background_requested report 'completed' even
though their content may only be answered on continuation/resume. 'completed'
means the consuming turn ended, not that the result frame was delivered."*
This is the exact failure observed, confirmed as a known harness-level gap —
so a workaround in this plugin is warranted rather than a bug to wait out.

### What the findings imply for the design

The cutoff itself is **undetectable** — by the persona (F2, F3), by a hook on
the failing path (F4, F5), and post-hoc from metadata (F7).

The tractable inversion: **stop trying to detect the cutoff; detect the absence
of a proper completion signature.** If every persona is required to end its
final message with a machine-checkable terminal status line, then a result
lacking that line was, by construction, not a clean finish. This works on the
parent side with no hook and no harness support, because the Agent-tool result
*is* the persona's last message.

Tradeoff to state plainly: this converts a **false-negative** (a truncation
that silently reads as success — the current, dangerous failure) into a
possible **false-positive** (a persona that legitimately finished but forgot
the line, prompting an unnecessary resume — cheap and self-correcting, since
the resumed persona simply says it was already done). That asymmetry is the
justification, not an accident.

### The terminal status line — exact definition

Canonical form, as the **last non-empty line** of the message the persona
returns to its caller, with nothing after it:

```
STATUS: complete
```

or

```
STATUS: incomplete — <one-line reason, non-empty>
```

An ASCII hyphen is an accepted substitute for the em dash
(`STATUS: incomplete - <reason>`), so that any check written against this is
encoding-robust. Reference regex, used verbatim in the acceptance criteria
below:

```
^STATUS: (complete|incomplete [—-] .+)$
```

Trigger condition: **every turn-end at which the persona hands control back to
a caller** — a dispatched subagent's returned result, and an agent-teams
teammate's `SendMessage` report to the lead (which is that mode's report
channel per the protocol's §"Agent-teams mode"). It does *not* apply to the
main-session `orchestrator` answering the user directly: there is no caller to
signal, the orchestrator is deliberately uncapped (`docs/design.md`), and
printing `STATUS: complete` at the end of every user-facing reply would be
pure noise. This is a trigger condition, not an exemption — the rule text
still lives in the one shared section every persona carries, so a persona that
gains a cap later is covered automatically, which is what OQ1 asked for.

Relationship to the WIP sentinel (they are not alternatives): the sentinel is
a **file** written before a voluntary pause; the status line is a **report
line** emitted on every turn-end. A turn ended via the WIP sentinel is
`STATUS: incomplete — <the same reason written into the sentinel>`.

### Bundled scope change: raising `spec-master`/`task-master` to 40

**This is the user's deliberate override of this plan's own earlier
recommendation.** The draft recommended keeping cap tuning out of scope, on
the grounds that `docs/self-improvement-loops.md`'s measurement harness exists
precisely so cap changes are measured rather than guessed (E1 measured a real
−10.4% cost effect from capping `lead-programmer`; E5's `explorer` tightening
came back INCONCLUSIVE with ~2x variance). The user overrode that and directed
the raise be bundled here.

State it plainly, as an accepted, informed tradeoff — the same posture the
sibling microworlds spec takes on the `humanReviewMode` default (issue #122):
**the raise ships without running the measurement harness first.** The user is
knowingly accepting an unmeasured cost effect on two Opus-tier personas because
closing the cutoff-detection gap matters more right now than precisely pricing
a higher cap. This is not an oversight, is not to be softened in the CHANGELOG,
and is not something a reviewer should "fix" by reverting it. What the spec
does add — because honesty about the gap costs nothing — is Step 5d: record the
raise in `docs/self-improvement-loops.md` as an explicitly **unmeasured**
shipped change with a named future hypothesis, rather than letting it
disappear into the changelog as if it had been trialled like E1 and E2 were.

**Scope of the raise: `spec-master` and `task-master` only.** Reasoning for
each persona *not* raised, since the user asked for judgment here:

- **`lead-programmer` (30) — do not raise.** Its cap is the only one in this
  repo backed by a CONFIRMED measurement: E1 (`docs/self-improvement-loops.md`)
  found capping it at 30 cut cost 10.4%, turns 38.1%, and wall time 15.4% with
  a 5/5 quality holdout, and it shipped in 0.5.1 on that evidence. Raising it
  would actively undo a measured, shipped win — a strictly worse tradeoff than
  the untested raise the user asked for, and one they did not ask for. Its
  work is also naturally bounded per unit (task-master slices units to be
  independently grabbable), and no `lead-programmer` cutoff has been observed.
- **`explorer` (10) — do not raise.** Highest-frequency persona and therefore
  the repo's main cost lever; E5 already showed its cap region is noisy
  (~2x variance). Its output contract is a distilled answer, so a long
  traversal is a symptom to fix in the query, not a cap to raise.
- **`reviewer` (30) — do not raise.** Bounded work by construction: read the
  diff, run the acceptance-criteria command, emit a verdict. E2 additionally
  tightened its output contract specifically to make it *shorter*.
- **`milestone-auditor` (20) — do not raise.** Runs at milestone boundaries
  only (lowest frequency of any capped persona), Opus-tier, and produces a
  findings list rather than a long authored artifact. No cutoff observed.

`spec-master` and `task-master` are the two that do long authored output plus
tracker publication in a single dispatch, and `spec-master` is the one actually
observed being cut off. They are the correct and minimal target.

## Clarifications

The scorecard below is the **post-resolution** state; the draft's pre-answer
state (three Partial, one Missing) is recoverable from this file's git history.

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-07-28 User interaction flow: Q What does the orchestrator actually do
  once it detects a non-clean finish? → A (self-resolved): reuse the existing
  verify-then-resume idiom already documented in `agents/orchestrator.md`
  §"Managing a long-running background dispatch" (resume via `SendMessage` by
  name, never re-`Agent` which spawns an unrelated `-2` sibling); this plan
  adds a state to that section rather than inventing a parallel mechanism.
- 2026-07-28 Non-functional attributes: Q Are there perf/security/scale
  constraints on this change? → A (self-resolved): none. The change is prose
  plus at most one status-line check; no new runtime cost on any hot path, no
  new attack surface, no data retained beyond existing audit logs.
- 2026-07-28 External dependencies & integrations: Q What exactly does the
  harness expose, and what must stay in sync? → A (self-resolved): established
  empirically as F1-F9 against Claude Code v2.1.220; integration surface is
  `templates/persona-protocol.md` **and** `templates/persona-protocol-slim.md`
  (two tiers, per `SLIM_TIER_PERSONAS` in `bin/cli.js`), whose section list is
  enforced against the Codex and Cursor ports by
  `tests/adapter-protocol-parity.test.js` (fail-closed on an unmapped section).
- 2026-07-28 Technical constraints & tradeoffs: Q What does adding a protocol
  section actually cost? → A (self-resolved): a new `## ` heading in
  `templates/persona-protocol.md` **throws** the parity test until both the
  Codex and Cursor maps gain an explicit `probe` or `deferred` entry — so any
  protocol-section change is inherently a 4-file minimum (canonical + slim +
  two ports) plus the test, plus constitution P3 (version bump + CHANGELOG) and
  P5 (`tests/validate.sh`, which runs the parity test at line 276), plus P2
  (edit `agents/`+`templates/` sources and regenerate `.claude/` mirrors via
  `node bin/cli.js --update`, never hand-edit mirrors).
- 2026-07-28 Terminology consistency: Q Does a new marker collide with existing
  vocabulary? → A (self-resolved): "WIP sentinel", "pending-review flag",
  "FAIL record", and "PASS marker" are all taken and load-bearing. `STATUS:`
  as a trailing message line collides with nothing — verified by grep across
  `agents/`, `templates/persona-protocol.md`, and `hooks/scripts/`; the
  reviewer's `PASS <task-id> …` format is a *marker file's first line*, not a
  message line, so the two never meet.
- 2026-07-28 Functional scope & success criteria: Q Which personas get the
  STATUS-line rule — the 6 with a cap today, the 3 turn-heaviest, or all of
  them? → A: **all personas**, as one protocol section covering everyone, so a
  persona that gains a cap later is not silently exempt (user, answering OQ1).
- 2026-07-28 Domain entities / data model: Q What is the bookkeeping mechanism —
  a new marker file, or a message convention? → A: **the same status line with
  distinct values**, `STATUS: complete` vs `STATUS: incomplete — <reason>`. No
  new marker file and no new `.claude/` artifact; purely a required trailing
  line in each persona's final message (user, answering OQ3).
- 2026-07-28 Technical constraints & tradeoffs: Q What enforcement level —
  docs/protocol-only, a Stop-hook check, or a hard gate? → A:
  **docs/protocol-only.** No hook changes, no adapter-mirror hook cost, no new
  `stop-gate.sh` branch. Personas are instructed via the shared protocol; the
  orchestrator is instructed to check the line before treating a dispatch as
  done (user, answering OQ4).
- 2026-07-28 Technical constraints & tradeoffs: Q Should a `maxTurns` raise be
  bundled into this fix, or kept out of scope as a separately-measured tuning
  change? → A: **bundled** — `spec-master` and `task-master` 30→40, overriding
  this plan's own recommendation, with the unmeasured-cost tradeoff accepted
  explicitly and stated in the rationale (user, answering OQ2). Which *other*
  capped personas to raise was delegated to this plan's judgment; resolved to
  "none," reasoned per-persona in Context.
- 2026-07-28 Completion / acceptance signals: Q Should the live experiment on
  whether `SubagentStop` fires on a cutoff be run before shipping? → A: **no,
  it is moot** — it gated only the hook-enforcement variants of OQ4, which were
  not chosen. Deferred, not abandoned; recorded below in case hook enforcement
  is revisited (user, answering OQ5).
- 2026-07-28 Edge cases / failure handling: Q What stops a missing STATUS line
  from causing an infinite resume loop, since a persona that never emits the
  line will still not emit it after being resumed? → A (self-resolved): the
  orchestrator resumes **at most once** per dispatch for a missing line; if the
  resumed turn also returns no line, it accepts the result at face value and
  says so in its report. Encoded in Step 4b.
- 2026-07-28 Edge cases / failure handling: Q Does the universal-scope answer
  reach `explorer`, `researcher`, and `scribe`, given how the protocol is
  delivered? → A (self-resolved): **not automatically** — those three are
  slim-tier (`SLIM_TIER_PERSONAS`, `bin/cli.js:34`) and receive
  `templates/persona-protocol-slim.md`, which the parity test does not guard.
  Step 2 adds the section there and Step 3c adds the guard.

### Deferred, not abandoned

The live `SubagentStop`-on-cutoff probe (former OQ5) is unnecessary for this
spec and must not be run as part of it. If hook-level enforcement is ever
revisited — the only reason to revisit it being F6's `last_assistant_message`,
which would let a hook machine-check the status line — that probe is the first
thing to run, because F4/F5 say the hook most likely never fires on the failing
path, which would make the whole hook approach a no-op.

## Risks / dependencies

- **R1. Multi-tier + multi-adapter fan-out.** A new canonical protocol section
  is fail-closed against `tests/adapter-protocol-parity.test.js`, and the
  *slim* tier is a second, currently-unguarded fan-out path. Step 2 and Step 3c
  exist for this. Getting Step 1 without Step 2 ships a change that looks
  universal and is not.
- **R2. Instruction-only enforcement is soft.** A status-line convention is
  followed by an LLM, not enforced by the harness — it will sometimes be
  missed. This is the accepted cost of OQ4's docs-only answer. Mitigation is
  the false-positive-safe direction (Context): a missed line costs one cheap
  resume, a missed cutoff costs a silently-wrong result. **No acceptance
  criterion in this spec asserts runtime compliance, because none can**; the
  criteria verify the instruction is present and fans out correctly.
- **R3. The `explorer` cap (10) is the tightest and `explorer` is the highest-
  frequency persona.** A status-line requirement adds output to every explorer
  return; the slim-tier wording (Step 2) must be one short paragraph plus the
  grammar, not a copy of the full-tier section.
- **R4. The `maxTurns` raise is unmeasured, by explicit user decision.**
  `docs/self-improvement-loops.md` E1/E5 establish that cap changes have real,
  measurable cost effects, and this repo's own norm (stated at the end of that
  doc) is that a change with a genuine cost/quality tradeoff goes through the
  harness, unlike a pure instruction-text fix. Skipping it here is the accepted
  tradeoff, mitigated only by recording it honestly (Step 5d).
- **R5. Harness-version coupling.** F1-F9 are observed against v2.1.220. If a
  future release adds a real termination-reason field to the Agent-tool result
  or to `SubagentStop`, this workaround should be revisited rather than kept
  forever. Step 6c requires the CHANGELOG entry to name the version.
- **R6. Step 3c mildly extends OQ4's boundary.** OQ4 forbade *runtime*
  enforcement (hooks). Step 3c adds a *build-time* assertion to a test file
  Step 3 must edit anyway. It is called out as its own severable sub-item so a
  reviewer can drop it without touching anything else.
- **R7. Working-tree state.** `.claude/agents/explorer.md` and
  `.claude/persona-config.json` are currently modified (a local
  `graphMcpLaunch` substitution; `fileHashes` already updated to match), so
  `node bin/cli.js --update` in Step 6a should not escalate on divergence — but
  the implementer must confirm rather than assume, per P1.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the mechanical question was settled by
  direct binary/sidecar inspection (F1-F9), the fan-out question by reading
  `bin/cli.js`'s actual tier logic rather than assuming one protocol file, and
  the residual unknown (F5) is explicitly deferred rather than guessed.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — all
  edits target `agents/` and `templates/` sources with `.claude/` mirrors
  regenerated via `node bin/cli.js --update` (Step 6a); no hand-edited mirrors,
  and idempotency is an acceptance criterion.
- P3 "Version-stamp discipline": satisfied — Steps 1-5 touch `agents/*.md` and
  templates, so Step 6b bumps `.claude-plugin/plugin.json` to `0.14.0` and
  Step 6c adds the CHANGELOG entry.
- P4 "Optional personas degrade gracefully": satisfied — the status-line rule
  lives in the shared protocol both tiers carry, phrased about "your caller"
  rather than about any named persona, so a project that deselected
  `spec-master`/`task-master`/`reviewer` still ships coherent prose. The
  orchestrator-side wording (Step 4) likewise names no optional persona.
- P5 "`tests/validate.sh` is the merge gate": satisfied — Step 6d runs it, and
  it invokes `tests/adapter-protocol-parity.test.js` (validate.sh:276), which
  fails closed on the new canonical section until Step 3 completes.

## Steps

### Step 1 — Add the terminal status line to the canonical protocol

**Affected files:** `templates/persona-protocol.md` (insert a new `## ` section
between §"WIP sentinel (mid-task handoff, not a bypass)", which ends at line
80, and §"Running acceptance-criteria commands (there is no self-wake)" at
line 82 — adjacent to the sibling handoff mechanism it must be distinguished
from).

**Exact heading (load-bearing — Step 3's parity-map keys must match it
character for character):**

```
## Terminal status line (every dispatched turn)
```

**Content requirements** (prose, author's wording, but each of these must be
present):

1. The grammar, verbatim: last non-empty line, nothing after it, either
   `STATUS: complete` or `STATUS: incomplete — <reason>`; reason non-empty and
   one line; ASCII hyphen accepted in place of the em dash.
2. The trigger: every turn-end where control returns to a caller — a dispatched
   subagent's returned result, and a teammate's `SendMessage` report to the
   lead in agent-teams mode. Not the main-session orchestrator answering the
   user (no caller).
3. **Why it exists**, stated as fact so a future maintainer does not "fix" it
   with a hook: you cannot see your own turn count, you cannot see your own
   cap being hit, and the harness renders the `max_turns_reached` attachment as
   zero content blocks — so a truncated turn is indistinguishable from a
   finished one *unless* a finished one carries a signature. Cite F2/F3 in
   substance.
4. The relationship to the WIP sentinel: not alternatives; a sentinel turn-end
   is `STATUS: incomplete — <the same reason written into the sentinel>`.
5. That a missing line is a *prompt to resume*, not a defect and not a FAIL.

**Acceptance criteria:**
- `grep -qxF '## Terminal status line (every dispatched turn)' templates/persona-protocol.md`
  exits 0.
- `grep -qF 'STATUS: complete' templates/persona-protocol.md` exits 0 and
  `grep -qE 'STATUS: incomplete' templates/persona-protocol.md` exits 0.
- The section is positioned between the two named sections:
  `awk '/^## /{n++; print n": "$0}' templates/persona-protocol.md` shows
  `Terminal status line` immediately after `WIP sentinel` and immediately
  before `Running acceptance-criteria commands`.
- `grep -qF 'wip-handoff' templates/persona-protocol.md` still exits 0 (the
  sentinel section was not replaced).

### Step 2 — Add the same rule to the SLIM protocol tier

**Affected files:** `templates/persona-protocol-slim.md` (new `## ` section,
placed immediately before its existing final section ``## A note on `memory` ``).

Without this, `explorer`, `researcher`, and `scribe` never receive the rule
(`SLIM_TIER_PERSONAS`, `bin/cli.js:34`) and OQ1's "all personas" answer is
false in practice. Keep it to one short paragraph plus the grammar (R3) — the
slim tier exists to be small, and `explorer` pays this cost on every return.

**Exact heading:** identical to Step 1's, character for character, so the two
tiers stay greppable as one rule.

**Acceptance criteria:**
- `grep -qxF '## Terminal status line (every dispatched turn)' templates/persona-protocol-slim.md`
  exits 0.
- `grep -qF 'STATUS: complete' templates/persona-protocol-slim.md` exits 0 and
  `grep -qE 'STATUS: incomplete' templates/persona-protocol-slim.md` exits 0.
- The slim section is at most 12 lines:
  `awk '/^## Terminal status line/{f=1;next} f&&/^## /{exit} f{c++} END{exit !(c<=12)}' templates/persona-protocol-slim.md`
  exits 0.
- The slim file still has exactly 6 `## ` sections:
  `test "$(grep -c '^## ' templates/persona-protocol-slim.md)" -eq 6`.

### Step 3 — Adapter ports and the fail-closed parity guard

`tests/adapter-protocol-parity.test.js` derives its canonical section list from
`templates/persona-protocol.md`, so Step 1 makes the suite **throw** until this
step lands. That coupling is deliberate and is why this cannot be deferred.

**3a — Codex port.** `adapters/codex/agents-md-fragment.md`: add the section in
that port's established condensed style (not a verbatim copy of the canonical
text — the ports are hand-adapted on purpose, per the test file's own header
comment). Place it near the existing platform note at line 148 ("No per-agent
turn cap (`maxTurns` equivalent): treat any turn budget as a soft target"),
and connect the two: the port has no `maxTurns` primitive, but it does have a
soft budget, and the status line is what tells a caller a turn ended cleanly
regardless of *why* it stopped. **Present, not deferred** — a `deferred` entry
here would reintroduce exactly the silent exemption OQ1 ruled out.

**3b — Cursor port.** `adapters/cursor/rules/persona-protocol.mdc`: same, near
its equivalent note at line 147.

**3c — Parity test.** `tests/adapter-protocol-parity.test.js`:
- Add `'Terminal status line (every dispatched turn)': { probe: 'STATUS: complete' }`
  to **both** `codexMap` (lines 54-70) and `cursorMap` (lines 72-88).
- **Severable sub-item (R6):** add one new `check(...)` asserting the slim
  tier carries the section too — read `templates/persona-protocol-slim.md` and
  assert it contains the exact heading and `STATUS: complete`. This is the only
  mechanical guard that Step 2 stays true; nothing else in the repo reads the
  slim file's section list. Build-time only; adds no hook and no runtime cost.

**Acceptance criteria:**
- `node tests/adapter-protocol-parity.test.js` exits 0.
- `grep -qF 'STATUS: complete' adapters/codex/agents-md-fragment.md` exits 0.
- `grep -qF 'STATUS: complete' adapters/cursor/rules/persona-protocol.mdc` exits 0.
- Neither map marks the section deferred:
  `grep -A1 "Terminal status line" tests/adapter-protocol-parity.test.js | grep -qv deferred`
  — i.e. `grep -c "'Terminal status line (every dispatched turn)': { probe:" tests/adapter-protocol-parity.test.js`
  returns `2`.
- Negative proof the guard is live: temporarily removing the section from
  `templates/persona-protocol-slim.md` makes `node tests/adapter-protocol-parity.test.js`
  exit non-zero (then restore). The existing self-verifying negative cases at
  lines 127-140 remain passing.

### Step 4 — Orchestrator checks the line before calling a dispatch done

**Affected files:** `agents/orchestrator.md` — two edits, both additive.

**4a — Receiving side of the delegation contract.** §"Delegation contract"
(lines 44-47) currently covers only what a dispatch prompt must *state*. Add
the symmetric receiving rule: before treating any dispatched persona's result
as done, read its last non-empty line.
- `STATUS: complete` → proceed normally.
- `STATUS: incomplete — <reason>` → do not proceed; resume the persona by name
  via `SendMessage`, quoting the reason back.
- No `STATUS:` line at all → treat as a **suspected `maxTurns` cutoff** (the
  harness gives no other signal — the result of a cut-off turn is
  indistinguishable from a completed one); resume by name and ask it to
  confirm whether it finished and to re-emit the line.
- Never re-`Agent` a persona to resume it (existing rule, cross-reference it):
  that spawns an unrelated `-2` sibling.
- A missing line is **not** a defect: it never routes to the reviewer, never
  writes a `.fail`, and never counts against the 2-FAIL cap.

**4b — Fourth state in the background-dispatch section.** §"Managing a
long-running background dispatch" (the three-state list at lines 363-376,
"Still running / Finished / Killed, nothing to finish"): add a fourth state,
**"Cut off mid-task"** — no `STATUS:` line, or `STATUS: incomplete` — whose
response is resume-by-name, same mechanism as "Finished." Include the
**anti-loop bound**: resume at most **once** per dispatch for a *missing*
line; if the resumed turn also returns no line, accept the result at face
value, stop resuming, and say so explicitly in the report to the user. (An
explicit `STATUS: incomplete` is not subject to this bound — that is the
persona deliberately asking to be resumed, and it is bounded by the reason
being resolved.)

**Acceptance criteria:**
- `grep -qF 'STATUS: complete' agents/orchestrator.md` exits 0 and
  `grep -qE 'STATUS: incomplete' agents/orchestrator.md` exits 0.
- Both sections are touched:
  `awk '/^## Delegation contract/{f=1} f&&/STATUS:/{print;exit}' agents/orchestrator.md`
  prints a line, and
  `awk '/^## Managing a long-running background dispatch/{f=1} f&&/STATUS:/{print;exit}' agents/orchestrator.md`
  prints a line.
- The anti-loop bound is stated:
  `grep -qEi 'resume .*at most once|at most once' agents/orchestrator.md` exits 0.
- The existing three states survive: `grep -c '^- \*\*' agents/orchestrator.md`
  increases by exactly 1 relative to `git show HEAD:agents/orchestrator.md`,
  and `grep -qF 'Killed, nothing to finish' agents/orchestrator.md` exits 0.
- `bash tests/validate.sh` still reports OK for `agents/orchestrator.md`
  frontmatter.

### Step 5 — Raise `spec-master`/`task-master` to 40 and reconcile the docs

**5a — The caps.** `agents/spec-master.md` line 9 and `agents/task-master.md`
line 9: `maxTurns: 30` → `maxTurns: 40`. No other persona file changes.

**5b — `docs/design.md`.** Line 65-66 currently reads
`` `maxTurns` caps (explorer=10, milestone-auditor=20, hivemind/reviewer/lead-programmer=30) ``.
`hivemind` is the pre-split name for `spec-master`+`task-master` (ADR-0003), so
this line becomes wrong in two ways at once. Rewrite it to name the personas
post-split with current values: explorer=10, milestone-auditor=20,
reviewer/lead-programmer=30, spec-master/task-master=40.

**5c — `docs/persona-design-notes.md`.** Line 34 (`spec-master`: ``` `maxTurns: 30` — starting bound, adjust after real usage ```)
and line 61 (`task-master`: ``` `maxTurns: 30` — starting bound, matching `spec-master`'s ```):
update both to 40, and replace "adjust after real usage" with a pointer to the
actual reason it was adjusted (the 2026-07-28 observed cutoff), so the next
reader does not re-tune it blind. Do **not** touch line 90 (`reviewer`) or
line 115 (`milestone-auditor`) or line 122 (`explorer`).

**5d — `docs/self-improvement-loops.md`.** Append a short note under the E1-E5
experiment table (table at lines 264-271) recording the raise as
**shipped un-measured**, naming it as a future hypothesis (e.g. "E6 —
`spec-master`/`task-master` `maxTurns` 30→40"), and stating plainly that it
was shipped on a product decision rather than a trial, unlike E1/E2. This is
the honest counterpart to that doc's existing note that Loop A's W1 was
patched directly "without a controlled trial — reasonable, since it's an
instruction-text fix with no real cost/quality tradeoff to weigh"; a cap raise
*does* have such a tradeoff, so it must not be filed the same way.

**Acceptance criteria:**
- `grep -qx 'maxTurns: 40' agents/spec-master.md` and
  `grep -qx 'maxTurns: 40' agents/task-master.md` both exit 0.
- No other source persona changed cap:
  `grep -h '^maxTurns:' agents/*.md | sort | uniq -c` yields exactly
  `1 maxTurns: 10`, `1 maxTurns: 20`, `2 maxTurns: 30`, `2 maxTurns: 40`.
- `grep -q 'hivemind' docs/design.md` exits **non-zero** for the cap line
  specifically: `grep -n 'maxTurns.*hivemind' docs/design.md` returns nothing.
- `grep -qF 'spec-master/task-master=40' docs/design.md` exits 0.
- `grep -c 'maxTurns: 30' docs/persona-design-notes.md` returns `1` (only the
  reviewer's line at ~90 remains), and
  `grep -c 'maxTurns: 40' docs/persona-design-notes.md` returns `2`.
- `grep -qiE 'un-?measured|without a controlled trial|not (been )?measured' docs/self-improvement-loops.md`
  exits 0 within 25 lines after the E5 table row:
  `awk '/\| E5 \|/{f=NR} f&&NR>f&&NR<=f+25' docs/self-improvement-loops.md | grep -qiE 'un-?measured|no controlled trial|not measured'`.
- `bash tests/validate.sh` reports OK for both changed agent files' frontmatter
  and `node tests/cli-backfill.test.js` still exits 0 (it asserts
  `explorer.md`'s `maxTurns: 10`, which must be untouched).

### Step 6 — Regenerate mirrors, stamp, changelog, gate

**6a — Mirrors.** Run `node bin/cli.js --update`. This regenerates
`.claude/agents/*.md` from `agents/*.md` with the tier-appropriate protocol
inlined (`inlineProtocolBlock`, cli.js:466-472) and refreshes
`.claude/persona-config.json`'s `fileHashes`. Commit whatever it changes.
Never hand-edit a `.claude/` mirror (P2). Confirm — do not assume (R7, P1) —
that it does not escalate on the pre-existing local divergence in
`.claude/agents/explorer.md`.

**6b — Version.** `.claude-plugin/plugin.json`: `0.13.16` → `0.14.0` (minor:
new shared-protocol section plus a behavioural cap change, not a fix).
`.claude/persona-config.json`'s `pluginVersion` follows via 6a.

**6c — CHANGELOG.** `CHANGELOG.md`: new `## [0.14.0] - <date>` section. It must
**lead with the cap raise stated plainly as an intentional, unmeasured
change** — not buried under "Added," not softened — and must name the observed
Claude Code version (v2.1.220) that F1-F9 were verified against, per R5.

**6d — Gate.** `bash tests/validate.sh` exits 0.

**Acceptance criteria:**
- `node bin/cli.js --update` exits 0, and a second immediate run reports no
  changes (idempotent, per `inlineProtocolBlock`'s deterministic contract).
- `grep -qF 'STATUS: complete' .claude/agents/spec-master.md` and
  `grep -qF 'STATUS: complete' .claude/agents/explorer.md` both exit 0 — the
  full-tier and slim-tier mirrors respectively, proving both fan-out paths
  carried the rule.
- `grep -qx 'maxTurns: 40' .claude/agents/spec-master.md` and
  `grep -qx 'maxTurns: 40' .claude/agents/task-master.md` exit 0.
- `python3 -c "import json,sys; sys.exit(0 if json.load(open('.claude-plugin/plugin.json'))['version']=='0.14.0' else 1)"`
  exits 0.
- `grep -qF '## [0.14.0]' CHANGELOG.md` exits 0 and
  `grep -qF '2.1.220' CHANGELOG.md` exits 0.
- `bash tests/validate.sh` exits 0.
- `git status --porcelain .claude/` shows only regenerated mirrors and
  `persona-config.json`, no unexpected file.

## Open Questions

**None.** All five of the draft's Open Questions were answered by the user on
2026-07-28 and are recorded, with their answers, in Clarifications above:
OQ1 (universal scope), OQ2 (bundle the cap raise, overriding this plan's
recommendation), OQ3 (status line with distinct values, no new marker file),
OQ4 (docs/protocol-only enforcement), OQ5 (the live `SubagentStop` probe is
moot — see "Deferred, not abandoned").

The delegated judgment call inside OQ2 — whether any capped persona beyond
`spec-master`/`task-master` warrants a bump — is resolved to "none," reasoned
per-persona in Context §"Bundled scope change." Bundling the raise surfaced no
new ambiguity requiring the user; it surfaced two *findings* (the stale
`hivemind` cap line in `docs/design.md`, and the un-measured-change honesty gap
in `docs/self-improvement-loops.md`), both absorbed as Steps 5b and 5d.

## Self-check

- CHK1: Is the terminal status line's exact grammar defined precisely enough
  that a `grep -E` acceptance criterion can be written against it? — PASS
  (Context §"The terminal status line — exact definition" gives the regex
  `^STATUS: (complete|incomplete [—-] .+)$` and the em-dash/hyphen tolerance;
  Steps 1-4 grep it).
- CHK2: Does the plan define which personas are in scope, and does that
  definition survive contact with how the protocol is actually delivered? —
  PASS (Context §"How the shared protocol actually fans out" names both tiers
  and `SLIM_TIER_PERSONAS`; Steps 1 and 2 cover full and slim respectively).
- CHK3: Do Step 1 and Step 3 agree on the exact section heading string? — FAIL
  (conflicting) — revised in place. Step 3's parity-map key initially read
  "Terminal status line" while Step 1's heading carried the parenthetical;
  the test keys on the *exact* canonical header, so the mismatch would have
  thrown. Both now state the identical string and Step 1 flags it as
  load-bearing.
- CHK4: Is it defined what the orchestrator does when a result has no STATUS
  line, and is that response bounded? — PASS (Step 4a defines the response,
  Step 4b bounds it at one resume with a stated fallback).
- CHK5: Do the Clarifications and Step 4 agree that a missing line is not a
  review defect? — PASS (Step 4a states it explicitly: no reviewer routing, no
  `.fail`, no 2-FAIL-cap credit).
- CHK6: Is "cut off by maxTurns" distinguished, in the plan's own vocabulary,
  from the voluntary WIP sentinel? — PASS (Context, Step 1 requirement 4, and
  the Terminology clarification line all state the semantics differ and that a
  sentinel turn-end emits `STATUS: incomplete`).
- CHK7: Does the plan say whether raising `maxTurns` is in scope, for which
  personas, and why not for the others? — PASS (Context §"Bundled scope
  change" reasons per-persona; Step 5a lists the two files; Step 5's
  `uniq -c` criterion mechanically pins every other cap).
- CHK8: Does the plan state, for each acceptance criterion, something an agent
  can run? — PASS (every criterion in Steps 1-6 is a `grep`/`awk`/`node`/
  `python3`/`bash` invocation with a defined exit code or exact expected
  output).
- CHK9: Is the un-measured nature of the cap raise recorded somewhere durable,
  or only in this plan? — FAIL (missing) — revised in place; Step 5d now
  requires it in `docs/self-improvement-loops.md` next to the E1-E5 table, and
  Step 6c requires the CHANGELOG entry to lead with it.
- CHK10: Do the Risks and the Steps agree about whether any criterion tests
  runtime LLM compliance? — PASS (R2 states none can and none does; no step
  claims otherwise).
- CHK11 (P1): Does the plan distinguish verified findings from inferences? —
  PASS (F1-F9 cite the artifact inspected; F5 is marked as the one static
  inspection could not settle, and is explicitly deferred rather than
  asserted; the fan-out facts cite `bin/cli.js` line numbers).
- CHK12 (P2): Do the Steps and the Constitution check agree that sources are
  edited and mirrors regenerated, never hand-edited? — PASS (Step 6a, P2 line).
- CHK13 (P3): Does the plan require a version bump + CHANGELOG for touched
  version-stamped files, with a specific target version? — PASS (Step 6b
  specifies `0.14.0`; Step 6c specifies the entry and a machine-checkable
  criterion).
- CHK14 (P4): Does the plan state how the new prose degrades in a project that
  deselected an optional persona? — PASS (P4 line: the rule is phrased about
  "your caller," names no optional persona, and lives in the shared protocol
  both tiers carry).
- CHK15 (P5): Is `tests/validate.sh` named as the gate, and is the plan's
  interaction with the fail-closed parity test stated? — PASS (P5 line; Step 3
  preamble states Step 1 makes the suite throw until Step 3 lands; Step 6d
  runs the gate).
- CHK16: Does the plan say what happens to the deferred `SubagentStop` probe,
  rather than dropping it? — PASS (§"Deferred, not abandoned").
- CHK17: Do Step 2 and Step 3c agree about what guards the slim tier? — PASS
  (Step 2 adds the section, Step 3c adds the only assertion covering it, and
  Step 3c is labelled severable per R6 with the consequence — nothing else
  reads the slim file's section list — stated).

**One revision pass applied**, covering CHK3 (heading-string mismatch between
Steps 1 and 3, corrected in both places) and CHK9 (the un-measured cap raise
was recorded only in this plan, which is not durable once the plan is
archived; Steps 5d and 6c added). Re-check of those two items: both PASS. No
item remains failing, so nothing routes to Open Questions.

## Scribe update hint

Once this ships, the wiki page covering persona handoff mechanisms needs a
**third** entry alongside "WIP sentinel" and "pending-review flag" — the
terminal status line / cutoff detection. It must carry F2, F3, and F5 in
substance as the *reason* the design is a convention rather than a hook, so a
future maintainer doesn't "fix" it by reaching for a hook that cannot fire on
the failing path. Note the harness-version coupling from R5 (verified against
Claude Code v2.1.220) and the deferred `SubagentStop` probe as the first thing
to run if hook enforcement is ever revisited.

Second item: the two-tier protocol delivery (`templates/persona-protocol.md`
vs `templates/persona-protocol-slim.md`, `SLIM_TIER_PERSONAS = ['explorer',
'researcher', 'scribe']`) is not documented anywhere a reader would find it,
and it silently determines whether a protocol change reaches a persona at all.
It deserves its own short wiki entry, cross-referenced from the parity-test
notes.

Third item: `docs/self-improvement-loops.md` gains its first
shipped-without-a-trial cap change (Step 5d). If the experiment ledger is
mirrored in the wiki, the un-measured status must be mirrored with it — the
value of that ledger is that a reader can tell measured changes from decided
ones.
