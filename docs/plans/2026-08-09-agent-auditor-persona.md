# agent-auditor: a read-only observability persona for agent activity

Status: **FINALIZED 2026-08-09.** OQ1-OQ3 were answered by the requester (all
three recommended defaults taken); see Clarifications and Resolved Questions.
Ready for `task-master` slicing.

Author: spec-master | Date: 2026-08-09 | Plugin version at drafting: 0.29.0
Resolves to **8 dispatchable units** (Step 0 plus Steps 1-7).

---

## Goal

Add a cheap, read-only persona that answers, on demand:

> Which agents were deployed, what tools and skills did each invoke, and does
> anything about that activity look wrong?

It reads only artifacts that **already exist on disk**. It writes no code,
gates nothing, blocks nothing, fixes nothing, and re-dispatches nothing. Its
sole output is a report.

Success is binary and machine-checkable: a single command produces a report
that (a) enumerates every agent dispatch in a chosen window with its tool and
skill inventory, and (b) flags a fixed, calibrated set of anomaly classes,
with a measured false-positive rate stated in this document.

---

## Context

### The decisive discovery: no new instrumentation is needed

The user's request implies always-on capture of agent dispatches, tool calls,
and skill invocations. **Claude Code already persists all three**, per-project
and per-subagent. Verified live in this repo on 2026-08-09:

| Artifact | Path | Contents |
|---|---|---|
| Main-session transcript | `~/.claude/projects/<project-slug>/<session-id>.jsonl` | every `tool_use` block, incl. `Agent` dispatches |
| Subagent metadata | `~/.claude/projects/<project-slug>/<session-id>/subagents/agent-<id>.meta.json` | `{agentType, description, toolUseId, spawnDepth, model}` |
| Subagent transcript | `~/.claude/projects/<project-slug>/<session-id>/subagents/agent-<id>.jsonl` | every `tool_use` that subagent made |

Measured corpus in this repo as of 2026-08-09:

- **38** session transcripts, **235 MB** total
- **636** subagent dispatches (`*.meta.json` files under `subagents/`)
- **15,991** subagent tool calls, broken down as: Bash 11038, Read 2803,
  Edit 1150, Write 469, SendMessage 238, Agent 96, MCP graph tools 119
  (7 distinct), Skill 36, WebFetch 18, WebSearch 5, ToolSearch 3, `bash`
  (lowercase) 3
- Skill invocations are fully captured: a `tool_use` with `name: "Skill"` and
  `input: {"skill":"antislop:tdd"}`
- `Agent` dispatch inputs carry `subagent_type`, `description`, and optionally
  `model`, `name`, `isolation`
- **Agent-teams (teammate) dispatches also land under `subagents/`** - verified
  against the live session that produced this document, whose `subagents/`
  directory holds both the teammate and its own nested `explorer`

### What the repo's own logs capture (almost nothing of this)

| Log | Lines | Every distinct record shape |
|---|---|---|
| `.claude/dispatch-audit.log` | 21 | `<ts> blocked=H4 target=<persona>` only |
| `.claude/review-audit.log` | 343 | `<ts> cleared-by=reviewer`, `<ts> marker-check=bootstrap`, `<ts> defer: <prose>` |
| `.claude/wip-audit.log` | 1 | `<ts> agent=<id> reason=<prose>` |

None records a tool call. None records a skill invocation. None records a
successful dispatch - `dispatch-audit.log` records only *blocked* ones. These
are gate-outcome logs, not activity logs, and they are complements to the
transcript store, not substitutes.

### Why this makes the design cheap

Building a new always-on activity log would fan out well beyond one hook
script. A new log file alone must be added to **four** separate gitignore
scaffold lists in `bin/cli.js` (`:883`, `:1378-1381`, `:1754-1757`,
`:2035-2038`), because the Cursor and Codex adapters each maintain their own
mirror set. A new hook script additionally needs `hooks/hooks.json` wiring and
a decision about adapter mirrors (`adapters/{codex,cursor}/hooks/scripts/`
currently mirror 5 of the 10 Claude-side scripts). Reading what already exists
avoids all of it, adds zero per-tool-call latency, and - unlike new
instrumentation - works **retroactively** over all 636 historical dispatches
from day one.

### Registration surface for a new persona (measured, not inferred)

- **Source of truth is `agents/*.md`**, not `.claude/agents/*.md`. The latter
  are generated mirrors written by `bin/cli.js`, with the shared protocol block
  inlined and a stamp line prepended. `researcher` is the exception: its source
  is `templates/researcher.md.tmpl`.
- `bin/cli.js` enumerates personas at: `CORE_PERSONAS` (`:25`),
  `OPTIONAL_PERSONAS` (`:26`), `SLIM_TIER_PERSONAS` (`:34`), the
  `PROTOCOL_SECTIONS_BY_PERSONA` matrix (row per persona, `milestone-auditor`
  at `:632`), and the persona-selection wizard's descriptions (`:1903`).
- `assertProtocolMatrixComplete` (`bin/cli.js:654`) requires **every** matrix
  row to classify **every** canonical protocol section as either `include` or
  `drop`. A missing row, or a row that omits one section, fails at load - this
  is the exact bug class recorded in the `224` FAIL record.
- `templates/persona-config.schema.json` hardcodes the optional-persona list in
  the `personaSelection` description prose, and names the code-writing-persona
  rule in `gatedAgents`.
- `tests/validate.sh:141` runs `for p in scribe reviewer researcher` to enforce
  constitution P4 (conditional phrasing) across `agents/orchestrator.md`,
  `agents/lead-programmer.md`, `commands/start-feature-team.md`.
- `tests/cli-backfill.test.js` enumerates personas at `:50`, `:55`, `:150`
  (`TRIMMED_PERSONAS`), `:366`, `:1085`, `:1113`.
- `.claude-plugin/plugin.json`'s `description` field lists the personas by name.
- Adapters mirror only four core personas (`explorer`, `lead-programmer`,
  `orchestrator`, `reviewer`), so **a new optional persona needs no adapter
  agent mirror**.
- `agents/orchestrator.md:34-36` states explicitly: "A well-described new
  persona needs no edit here beyond an optional disambiguation line - routing
  is primarily description-based auto-delegation."

### The last precedent is stale

The only prior "add a persona" commit is `90d3fca` (milestone-auditor,
2026-07-09), which touched `skills/setup-personas/SKILL.md` - a path that no
longer exists. `bin/cli.js` did not yet own scaffolding. **Do not use that
commit as a template**; use the enumeration list above.

---

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Missing
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-08-09 Functional scope & success criteria: Q Which anomaly classes are
  in scope for v1, and is the persona allowed to gate anything? -> A
  (self-resolved): six anomaly checks plus two inventories, enumerated in
  Step 1; strictly non-gating, per the requester's explicit boundary. Scope
  size carried to Open Question 3 for sign-off.
- 2026-08-09 Domain entities / data model: Q What is the unit of observation -
  a session, a dispatch, or a tool call? -> A (self-resolved): the **dispatch**
  (one `agent-<id>.meta.json` plus its sibling `.jsonl`), keyed by
  `(session-id, agent-id)`. Tool calls are attributes of a dispatch; a session
  is a grouping of dispatches. This is the natural grain of the on-disk data
  and needs no synthesis.
- 2026-08-09 User interaction flow: Q Slash command, orchestrator routing, or
  both - and what default time window? -> A (self-resolved): both surfaces
  (an `/audit-agents` command in `commands/`, plus one orchestrator
  disambiguation line), defaulting to the **current session**, with
  `--sessions=N` and `--all` for history. Rationale: `commands/` already holds
  two commands, so the surface exists; scanning all 235 MB by default would be
  unusable at haiku speed.
- 2026-08-09 Non-functional attributes: Q Is scanning 235 MB of transcripts
  viable, and what about the user prompts inside them? -> A (self-resolved):
  viable only because detection is a `jq`-based script, not model reading -
  the prototype run while drafting this document scanned all 636 dispatches in
  seconds. The report emits metadata and counts only and never quotes a prompt
  or a tool input body; see R5.
- 2026-08-09 External dependencies & integrations: Q Does this add a
  dependency? -> A (self-resolved): no. `jq` is already a hard dependency of
  all ten hook scripts (`hooks/scripts/lib/agent-identity.sh` and the nine
  others each shell out to it), and Node is required by `bin/cli.js`.
- 2026-08-09 Edge cases / failure handling: Q What happens when the transcript
  store is absent, empty, or in a future unrecognized format? -> A
  (self-resolved): the script exits 0 and reports "no data for window" rather
  than erroring, and a format probe (Step 1, criterion 5) distinguishes
  "no data" from "format changed"; see R1.
- 2026-08-09 Technical constraints & tradeoffs: Q Is `model: haiku` fit for
  this scope? -> A (self-resolved): yes, **because** detection is deterministic
  and lives in a script. See "Haiku fitness" below.
- 2026-08-09 Terminology consistency: Q Does "agent-auditor" collide with
  existing vocabulary? -> A: it does, three ways - `milestone-auditor` (an
  existing persona), `reviewer` (the existing verdict-issuing auditor), and
  the three existing `*-audit.log` files. Carried to Open Question 2.
- 2026-08-09 Completion / acceptance signals: Q What proves this is done? -> A
  (self-resolved): `bash tests/validate.sh` exits 0 in a **clean checkout**,
  `node bin/cli.js --update` exits 0, and the new
  `tests/agent-auditor.test.sh` passes, including a fixture asserting each
  anomaly class fires on a known-bad input and stays silent on a known-good
  one.

- 2026-08-09 Functional scope & success criteria: Q Ship all six v1 anomaly
  checks, including A4 and A6 which overlap the review pipeline's own gates? ->
  A: yes, ship all six, per the requester. A4 and A6 stay in scope knowingly:
  they observe the gates rather than enforce them, and reporting a gate that
  *should* have fired but did not is exactly the "verify the agent actions"
  the request asked for.
- 2026-08-09 Terminology consistency: Q Keep the colliding name
  `agent-auditor`, or take one of the three alternatives? -> A: keep
  `agent-auditor`, per the requester. R7's collision is therefore accepted and
  mitigated by Step 6's disambiguation line rather than avoided by renaming.
- 2026-08-09 Completion / acceptance signals: Q Ship as a plugin persona or
  repo-local only? -> A: plugin persona, full scope, per the requester. Steps
  4, 5 and 7 (cli.js registration, mirror regeneration, version bump) are
  therefore all in scope, and constitution P3/P4 both bind.

### Haiku fitness

`model: haiku` is confirmed appropriate, and it is not a compromise. Three
existing personas already run on haiku (`explorer`, `lead-programmer`,
`scribe`), and `explorer` - read-only tools, `maxTurns: 10` - is the direct
structural analogue.

The fitness argument is conditional on one design decision: **all detection
logic lives in a deterministic script, and the persona's job is to run it,
interpret the output, and present it.** The persona performs no
cross-referencing in-context. If detection were left to model judgment over
235 MB of JSONL, haiku would not be fit - and neither would opus, at
reasonable cost. Keeping the logic in a script is therefore what makes the
requested model correct, and it is simultaneously what makes the acceptance
criteria machine-checkable. Should a future revision move judgment back into
the model, this fitness conclusion must be re-derived.

---

## Risks / dependencies

**R1 - The transcript format is undocumented and version-coupled.** Records
carry a `version` field; the schema is an internal Claude Code detail with no
stability guarantee. A silent format change would make the auditor report
"nothing happened" - the most dangerous possible failure for an observability
tool, since absence of findings is indistinguishable from absence of data.
*Mitigation*: Step 1 criterion 5 requires an explicit format probe that
asserts the expected keys are present and emits a loud `FORMAT-UNRECOGNIZED`
banner otherwise. "No anomalies" and "could not read" must never render alike.

**R2 - Every registration surface has prior FAIL history. No step touching
`bin/cli.js` may be tagged `haiku`.** The reviewed-records directory holds 28
FAIL records; **12** name `bin/cli.js`: 124, 128, 191, 192, 197, 224, 225,
237, 238, 261, 269, and gh-228-deepmerge-dedup. Three are directly on this
plan's path:

- **191** - `bin/cli.js` has **two independent render paths** (fresh scaffold
  at `:1882`/`:1890`, and `renderCleanBody` at `:728` used by `--update`). A
  change threaded into one and not the other produces different bodies for
  identical inputs at the same version, and a fresh install reports drift on
  its very first `--update`. The record notes "no test covers the scaffold
  render path." **A new persona must be verified through both paths.**
- **224** - adding or altering a persona regenerates four stamped mirrors
  (`.claude/persona-config.json`, `.claude/persona-protocol.md`,
  `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`).
  Committing only some of them makes `validate.sh` exit 1 and `--update` exit
  2 **in a clean checkout, while passing in the author's dirty tree.** Every
  criterion in this plan must therefore be run in a clean checkout.
- **128** - documentation drift about tier membership and parity-test scope,
  i.e. the failure mode for Step 6's doc updates.

**R3 - The headline anomaly check has a 98% false-positive rate if naively
implemented.** Prototyped live on 2026-08-09 against all 636 dispatches, "tool
used outside the persona's declared `tools:` list" produced **115 raw hits**,
of which **2** were real. The noise has two distinct causes, and a correct
implementation must model both:

1. *The `memory:` auto-grant.* A persona with a `memory:` field is
   auto-granted Read/Write/Edit regardless of its `tools:` list - this is
   documented in the protocol's own "A note on `memory`" section. Five
   personas have it (`spec-master`, `task-master`, `scribe`,
   `lead-programmer`, `researcher`); four do not (`reviewer`, `explorer`,
   `milestone-auditor`, `orchestrator`). This alone accounts for 113 hits.
2. *User-scope auto-memory.* The single `reviewer uses Write` hit - from a
   persona with **no** `memory:` field - resolved on inspection to a write
   into `~/.claude/projects/<slug>/memory/`, i.e. the user-level auto-memory
   directory, not the repo. Benign.

The one genuinely interesting residual hit is `explorer uses bash` (lowercase,
3 occurrences corpus-wide) - a tool-name casing variant worth surfacing.
**Effective-tools formula**: declared UNION (has memory ? {Read,Write,Edit} :
empty), with Write/Edit whose `input.file_path` resolves under a memory
directory excluded, and `mcp__*` matched against declared `mcpServers` rather
than `tools`.

**R4 - Model divergence is normal here and must not be reported as an
anomaly.** 195 of 636 dispatches ran at a model other than the persona's
declared default (`lead-programmer` at sonnet x54 and opus x39 against a
declared `haiku`; `reviewer` at fable x43 and sonnet x21 against a declared
`opus`). This is `task-master`'s per-unit model tagging and the reviewer-tier
gate working as designed. Report it as a **distribution table**, never as a
flag.

**R5 - Transcripts contain full user prompts and full tool inputs.** The
report must emit metadata, paths, names, and counts only. It must never quote
a prompt body or a tool input, because an audit report is exactly the kind of
artifact a user pastes into an issue.

**R6 - This persona is Claude-only.** Neither the Cursor nor the Codex adapter
has an equivalent transcript store. This is a stated limitation, not a gap to
close, and is why no adapter mirror work appears in the steps below.

**R7 - Naming collides three ways** with `milestone-auditor`, with `reviewer`,
and with the existing `*-audit.log` files. Carried to Open Question 2.

**R8 - The reviewed-records path gate.** `reviewed-path-gate.sh` blocks
non-reviewer personas by *command text*. Anomaly check A6 needs to read the
marker directory, and does so legitimately: the invoking command is
`bash scripts/agent-audit.sh`, whose text never spells the path, while bare
`ls`/`cat` on that directory is permitted for read-only inspection anyway. The
script must not be invoked via a wrapper that inlines the path.

**R9 - This working tree is already two versions behind. RESOLVED: it becomes
Step 0 of this spec.** Measured 2026-08-09: `.claude-plugin/plugin.json`
is at `0.29.0`, while `.claude/persona-config.json`'s `pluginVersion` and every
stamped mirror (`persona-protocol.md`, `persona-protocol-slim.md`,
`protocol-digest.md`, and all nine `.claude/agents/*.md`) are still stamped
`v0.27.0`. This is the drift the SessionStart check exists to report, and it is
pre-existing - not caused by this plan.

**The explicit call**: the resync is **Step 0 of this spec** - in scope,
ordered first, and dispatched as its own unit with its own commit and its own
reviewer pass. Not a separate out-of-band chore, and not out of scope.
Reasoning:

1. **It is a hard blocker, not hygiene.** Step 5 criterion 2
   (`git status --porcelain` empty after `--update`) is literally unreachable
   while the tree is two versions behind, so leaving it out would ship a spec
   with an unsatisfiable criterion.
2. **Its own unit, so it never contaminates the feature diff.** Bundled into
   Step 5, a two-version protocol sweep and this persona's mirrors land in one
   commit and no reviewer can separate them - the exact 224 failure mode.
3. **In-spec rather than out-of-band, so it is tracked.** A prerequisite that
   lives only in a hand-off note is a prerequisite that gets skipped.

**It is provably mechanical, which is why it is cheap.** Verified read-only on
2026-08-09 by recomputing each recorded digest with `bin/cli.js`'s own exported
`sha256Hex(stripStamp(...))`: **all 12 files in `fileHashes` match their
recorded hash, zero local edits.** Per `bin/cli.js:1023` that is precisely the
`noLocalEdits` condition, so `--update` will regenerate silently and exit 0 -
no `--accept=`/`--keep=` decisions, no human judgment, no AskUserQuestion
round-trip. Step 0 is therefore the **one step in this plan with no prior-FAIL
exposure and no judgment content.**

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied - every quantitative claim in Context
  and Risks was measured live on 2026-08-09 against this repo, including a
  working prototype of the two headline anomaly checks; R3's calibration
  exists *because* the prototype was run rather than reasoned about.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied, and
  load-bearing twice - detection is a script rather than model judgment (which
  is what makes `model: haiku` correct), and Step 5 regenerates the stamped
  mirrors via `node bin/cli.js --update` rather than hand-editing
  `fileHashes`.
- P3 "Version-stamp discipline": satisfied - Step 7 bumps
  `.claude-plugin/plugin.json` and adds a CHANGELOG entry, required for **two
  independent reasons** (reason 2 added 2026-08-09 by Amendment A2; it did not
  exist when this note was first written):
  1. Step 2 adds a versioned `agents/*.md` file.
  2. **Step 6 modifies an existing versioned source, `agents/orchestrator.md`,
     after Step 5's mirror regen had already run.** `--update`'s fast-path is
     gated on the version stamp and on file absence, never on source-content
     drift (`bin/cli.js:984`), so that edit cannot reach
     `.claude/agents/orchestrator.md` until the version moves. Step 7 is
     therefore load-bearing for **functional** correctness rather than
     bookkeeping: `.claude/agents/*.md`, not `agents/*.md`, is what a deployed
     project actually loads. See Amendment A2 at the end of this document.
- P4 "Optional personas degrade gracefully": satisfied - the persona is
  optional, its orchestrator reference is conditionally phrased, and Step 4
  adds it to the `tests/validate.sh:141` enforcement loop so the phrasing is
  mechanically checked rather than merely intended.
- P5 "`tests/validate.sh` is the merge gate": satisfied - every step's
  acceptance criteria include it, and per R2 each must be run in a clean
  checkout, not the author's working tree.

---

## Deliberate non-changes

- **No new hook, and no new hook event.** Justified by the Context section: the
  data already exists. This also preserves the persona's read-only boundary -
  an always-on hook is, by construction, a thing that runs whether or not
  anyone asked.
- **No adapter mirrors** (R6).
- **No new log file**, therefore no gitignore changes in any of the four
  scaffold lists.
- **No gating, blocking, or re-dispatch capability**, and no `Write`, `Edit`,
  or `Agent` tool. Notably **no `memory:` field either** - adding one would
  auto-grant Write/Edit and silently defeat the read-only boundary, which is
  precisely the mechanism R3 documents.

---

## Step 0 - resync the project to the current plugin version (prerequisite)

**Affected files**: `.claude/persona-config.json`, `.claude/persona-protocol.md`,
`.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, and all nine
`.claude/agents/*.md`.

Pre-existing 0.27.0 -> 0.29.0 drift, unrelated to this feature (R9). Run
`node bin/cli.js --update` from the project root and commit the whole sweep as
one commit. Do **not** begin Step 1 until this is merged.

Expected to exit 0 with no prompts - all 12 recorded files were verified
unedited (R9). **If it exits 2** the premise has changed since 2026-08-09:
stop and escalate rather than choosing `--accept`/`--keep`, because
`commands/update-antislop.md` is explicit that only a human decides those.

**Acceptance criteria** (clean checkout):

1. `node bin/cli.js --update` exits 0.
2. Version is fully propagated - currently RED, verified 2026-08-09 (the
   mirrors read `v0.27.0`):

        v=$(jq -r .version .claude-plugin/plugin.json)
        test "$(jq -r .pluginVersion .claude/persona-config.json)" = "$v"
        for f in .claude/persona-protocol.md .claude/persona-protocol-slim.md \
                 .claude/protocol-digest.md; do
          grep -q "antislop v$v" "$f" || exit 1
        done

3. Idempotent - a second `node bin/cli.js --update` exits 0 and leaves
   `git status --porcelain` empty.
4. `bash tests/validate.sh` exits 0 and `node tests/cli-backfill.test.js`
   exits 0.
5. This commit contains **no** `agent-auditor` content:
   `! git show --stat HEAD | grep -q 'agent-auditor'`

**Prior-FAIL exposure**: none. This is the only step in the plan with no
judgment content (R9).

## Step 1 - the detection script

**Affected files**: `scripts/agent-audit.sh` (new).

Reads the transcript store; emits a plain-text report. No dependency beyond
`jq` and coreutils. Flags: `--sessions=N` (default 1, current session),
`--all`, `--json`, `--format-probe`. Root overridable via `AGENT_AUDIT_ROOT`
for fixtures.

Report sections - six anomaly checks and two inventories:

| ID | Check | Fires when |
|---|---|---|
| A1 | Undeclared tool use | a `tool_use` name is outside effective-tools (R3 formula) |
| A2 | Unregistered agent type | canonicalized `agentType` has no `.claude/agents/<name>.md` |
| A3 | Nested spawn | `spawnDepth` >= 2 |
| A4 | Gated dispatch without review | a `gatedAgents` persona dispatched with no `reviewer` dispatch later in the same session |
| A5 | Missing terminal status line | a subagent's final assistant text does not match the protocol's `STATUS:` regex |
| A6 | Orphan PASS marker | a `.pass` marker whose task-id has no `reviewer` dispatch in the window |
| I1 | Model distribution | informational table, dispatched vs declared (R4) |
| I2 | Skill inventory | informational, `input.skill` grouped by persona |

A2 canonicalizes `antislop:reviewer` to `reviewer` before lookup, matching
`hooks/scripts/lib/agent-identity.sh`'s `identity_persona_name`. A5 is the
turn-cutoff detector the shared protocol's terminal-status-line rule exists to
enable; the protocol states a missing line is "a prompt to resume, not a
defect", so A5 must be reported as such and not as an error.

**Acceptance criteria** (each run in a clean checkout):

1. `bash scripts/agent-audit.sh --all` exits 0 and stdout contains all eight
   section IDs:
   `for id in A1 A2 A3 A4 A5 A6 I1 I2; do bash scripts/agent-audit.sh --all | grep -q "^$id" || exit 1; done`
2. A1 calibration holds - against the full corpus, A1 reports **at most 5**
   findings, not 115:
   `test "$(bash scripts/agent-audit.sh --all --json | jq '[.findings[]|select(.id=="A1")]|length')" -le 5`
3. A1 is non-vacuous - it still catches the lowercase-`bash` case:
   `bash scripts/agent-audit.sh --all --json | jq -e '[.findings[]|select(.id=="A1" and .tool=="bash")]|length >= 1'`
4. I1 reports the known divergence rather than suppressing it:
   `test "$(bash scripts/agent-audit.sh --all --json | jq '[.distribution[]|select(.dispatched!=.declared)]|length')" -ge 1`
5. Format probe distinguishes no-data from bad-data:
   `bash scripts/agent-audit.sh --format-probe` exits 0 and prints `FORMAT-OK`
   on the live store; pointed at a directory of malformed JSONL via
   `AGENT_AUDIT_ROOT`, it prints `FORMAT-UNRECOGNIZED` and exits 0 (never
   silently empty).
6. Empty store:
   `AGENT_AUDIT_ROOT=$(mktemp -d) bash scripts/agent-audit.sh --all` exits 0
   and prints `no data for window`.
7. Privacy (R5): no prompt or tool-input body reaches stdout. The implementer
   renders this as a concrete fixture assertion in Step 3: a fixture whose
   prompt contains the sentinel string `CANARY-PROMPT-BODY` must produce a
   report where `! grep -q CANARY-PROMPT-BODY` holds.
8. `bash -n scripts/agent-audit.sh` exits 0 and `bash tests/validate.sh`
   exits 0.

**Suggested model note**: not `haiku` - R3's calibration is the substance of
this step.

## Step 2 - the persona source file

**Affected files**: `agents/agent-auditor.md` (new).

Frontmatter, exactly:

    name: agent-auditor
    description: <read-only observability; see Open Question 2 on the final name>
    model: haiku
    tools: Read, Grep, Glob, Bash
    maxTurns: 10

No `memory:` (see Deliberate non-changes). No `Write`, `Edit`, `Agent`, or
`SendMessage`. Body: run `scripts/agent-audit.sh`, interpret, present; an
explicit statement that it never gates, blocks, fixes, or re-dispatches, and
that a finding is an observation for a human, not a verdict.

**Acceptance criteria**:

1. `bash tests/validate.sh` exits 0 (covers frontmatter `name:`/`description:`
   at `tests/validate.sh:109`).
2. Tool list is exactly the four read-only tools:
   `test "$(awk '/^tools:/{sub(/^tools: */,"");print;exit}' agents/agent-auditor.md)" = "Read, Grep, Glob, Bash"`
3. No write-capable surface:
   `! grep -qE '^(memory|skills):' agents/agent-auditor.md` and
   `! grep -qE '^tools:.*(Write|Edit|Agent)' agents/agent-auditor.md`
4. `grep -q '^model: haiku' agents/agent-auditor.md`

## Step 3 - the test

**Affected files**: `tests/agent-auditor.test.sh` (new), `tests/validate.sh`
(register the new test if the harness enumerates tests).

Fixture-driven: a synthetic `AGENT_AUDIT_ROOT` containing one known-good
dispatch and one known-bad dispatch per anomaly class.

**Acceptance criteria**:

1. `bash tests/agent-auditor.test.sh` exits 0.
2. Each of A1-A6 has both a positive and a negative fixture:
   `for id in A1 A2 A3 A4 A5 A6; do grep -q "${id}_bad" tests/agent-auditor.test.sh && grep -q "${id}_good" tests/agent-auditor.test.sh || exit 1; done`
3. Mutation proof (non-vacuity): deleting the A1 branch from
   `scripts/agent-audit.sh` makes `bash tests/agent-auditor.test.sh` exit
   non-zero. The implementer must perform and report this mutation for at
   least A1 and A5.
4. `bash tests/validate.sh` exits 0.

## Step 4 - register the persona in `bin/cli.js` and the schema

**Affected files**: `bin/cli.js`, `templates/persona-config.schema.json`,
`tests/validate.sh`, `tests/cli-backfill.test.js`.

- `OPTIONAL_PERSONAS` (`:26`) - add.
- `SLIM_TIER_PERSONAS` (`:34`) - add; this persona is slim-tier, matching
  `explorer`. It owns no review, no dispatch, and no retrieval duty, so the
  full protocol block is dead weight in its context.
- `PROTOCOL_SECTIONS_BY_PERSONA` - add a **complete** row (`include` plus
  `drop` must together classify every canonical section, or load fails; see
  R2 / the 224 record).
- Persona-selection wizard descriptions (`:1903`) - add.
- `templates/persona-config.schema.json` - extend the `personaSelection`
  description's persona list.
- `tests/validate.sh:141` - add to the `for p in scribe reviewer researcher`
  conditional-phrasing loop (constitution P4).
- `tests/cli-backfill.test.js` - extend the persona enumerations at `:50`,
  `:55`, `:150`, `:1085`, `:1113` as each assertion requires.

**Acceptance criteria** (clean checkout):

1. `node tests/cli-backfill.test.js` exits 0.
2. `bash tests/validate.sh` exits 0.
3. **Both render paths agree** (R2 / the 191 record) - scaffold into a temp
   dir, then run `--update`, and assert the second pass reports no divergence
   and rewrites nothing:

        d=$(mktemp -d)
        (cd "$d" && node /abs/path/bin/cli.js --yes --personas=agent-auditor)
        test -f "$d/.claude/agents/agent-auditor.md"
        (cd "$d" && node /abs/path/bin/cli.js --update)   # must exit 0

4. Matrix completeness is exercised, not assumed:
   `node -e 'require("/abs/path/bin/cli.js")'` loads without throwing.

**Suggested model note**: not `haiku` (R2 - 12 prior FAIL records on
`bin/cli.js`, including two on this exact surface).

## Step 5 - regenerate the mirrors

> **SUPERSEDED 2026-08-09 by Amendment A1** (end of document). The Ordered
> Edit and criteria below are retained for the record but are **not
> executable as written** - `node bin/cli.js --update` alone cannot create
> `.claude/agents/agent-auditor.md` in this already-adapted repo. Execute
> Amendment A1's version instead.

**Affected files**: `.claude/agents/agent-auditor.md` (new, generated),
`.claude/persona-config.json`, `.claude/persona-protocol.md`,
`.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`.

Run `node bin/cli.js --update`. **Commit all regenerated files together** -
the 224 record is a partial commit of exactly this set.

**Precondition (R9)**: the 0.27.0 -> 0.29.0 sweep must already be committed as
a separate unit. Without it this step's diff is inseparable from a two-version
protocol sweep.

**Acceptance criteria** (clean checkout, all mirrors committed):

1. `node bin/cli.js --update` exits 0 and reports no divergence.
2. `git status --porcelain` is empty after the run.
3. `bash tests/validate.sh` exits 0.
4. Stamp consistency, asserted positively so it cannot pass vacuously - every
   stamped mirror carries the *new* version. Verified RED on 2026-08-09: the
   mirrors are stamped `v0.27.0`, so a negative `! grep -q '<new version>'`
   check would have passed while doing nothing (R9).

        v=$(jq -r .version .claude-plugin/plugin.json)
        for f in .claude/persona-protocol.md .claude/persona-protocol-slim.md \
                 .claude/protocol-digest.md .claude/agents/agent-auditor.md; do
          grep -q "antislop v$v" "$f" || exit 1
        done
        test "$(jq -r .pluginVersion .claude/persona-config.json)" = "$v"

**Suggested model note**: not `haiku` (R2 / the 224 record).

## Step 6 - invocation surfaces and docs

**Affected files**: `commands/audit-agents.md` (new),
`agents/orchestrator.md` (one disambiguation line), `README.md`, `CONTEXT.md`.

The orchestrator edit is **one disambiguation line only**, per
`agents/orchestrator.md:34-36`, conditionally phrased per P4. It must
distinguish the new persona from `milestone-auditor` (audits the *plan*) and
`reviewer` (issues a *verdict* on code) - this persona audits *agent activity*
and issues no verdict.

**Acceptance criteria**:

1. `bash tests/validate.sh` exits 0 - this mechanically enforces the
   conditional phrasing once Step 4 has added the persona to the `:141` loop.
2. The disambiguation line names its nearest neighbour:
   `grep -A3 'agent-auditor' agents/orchestrator.md | grep -q 'milestone-auditor'`
3. The orchestrator edit is genuinely minimal - added lines only, and `0`
   when the file is untouched, so the check never errors on an empty diff:
   `test "$(git diff --numstat HEAD -- agents/orchestrator.md | awk '{print $1} END{if(NR==0)print 0}')" -le 6`
4. `grep -q 'agent-auditor' README.md CONTEXT.md commands/audit-agents.md`

## Step 7 - version bump and CHANGELOG

> **SUPERSEDED 2026-08-09 by Amendment A2** (end of document). The Affected
> files, Ordered Edits and criteria below are retained for the record but are
> **not executable as written** - they omit both the `package.json` bump
> (without which criterion 4, `tests/validate.sh`, cannot pass) and the
> `node bin/cli.js --update` mirror regen (without which the live
> `.claude/agents/orchestrator.md` never gains Step 6's routing line). Execute
> Amendment A2's version instead.

**Affected files**: `.claude-plugin/plugin.json`, `CHANGELOG.md`.

Minor bump 0.29.0 -> 0.30.0 (new delivered function). Update the
`plugin.json` `description`, which lists personas by name.

**Acceptance criteria**:

1. `jq -r .version .claude-plugin/plugin.json` returns a version greater than
   `0.29.0`.
2. `jq -r .description .claude-plugin/plugin.json | grep -q 'agent-auditor'`
3. `head -40 CHANGELOG.md | grep -q '0.30.0'` and the entry names the persona.
4. `bash tests/validate.sh` exits 0.

---

## Resolved Questions

All three were answered by the requester on 2026-08-09, each taking the
recommended default. Retained as a record of what was decided and why, not as
outstanding work. **No open questions remain.**

**OQ1 - Ship scope: plugin persona, or repo-local only?** **ANSWERED: (a)
plugin persona, full 7-step scope.**

- **(a) Plugin persona (recommended).** Lives in `agents/`, ADAPT-selectable,
  ships to every AntiSlop user. This is the plan as written: 7 steps. Chosen
  as the default because AntiSlop's entire value proposition is
  agent-discipline machinery, and "verify what your agents actually did" is
  squarely that - a purely local tool would be the odd one out.
- (b) Repo-local only. A file in `.claude/agents/` plus the script; Steps 4,
  5 and 7 disappear entirely and Step 6 shrinks. Roughly 3 steps. Cheaper and
  reversible, at the cost of not shipping and of being silently overwritten by
  a future `--update`.

**OQ2 - Final persona name.** **ANSWERED: (a) keep `agent-auditor`.** The R7
collision is accepted, mitigated by Step 6's disambiguation line.

- **(a) `agent-auditor` - keep it (recommended).** It is what was asked for,
  and the disambiguation line in Step 6 resolves the ambiguity where it
  actually bites (orchestrator routing).
- (b) `activity-auditor` - collides only on the `-auditor` suffix.
- (c) `dispatch-auditor` - most precise, and matches the data's actual grain
  (a dispatch), but invites confusion with `dispatch-hygiene.sh`.
- (d) `observer` - no collision at all, but weaker description-based
  auto-delegation, which is the primary routing mechanism.

**OQ3 - Is the v1 anomaly set right?** **ANSWERED: ship all six (A1-A6) plus
the two inventories.** A4 and A6 stay in scope knowingly: they *observe* the
review pipeline's gates rather than duplicate them, and a gate that should
have fired but did not is the highest-value thing this persona can surface.

---

## Self-check

- CHK1: Is the data source for "which skills are being invoked" identified
  with a concrete record shape? - PASS (Context: `tool_use` name `Skill`,
  `input.skill`, 36 occurrences measured)
- CHK2: Is the read-only boundary enforced mechanically, not just stated? -
  PASS (Step 2 criteria 2-3 assert the tool list and the absence of
  `memory:`/`Write`/`Edit`/`Agent`; Deliberate non-changes explains why
  `memory:` is the subtle one)
- CHK3: Does every anomaly class have a runnable pass/fail check? - PASS
  (Step 3 criterion 2 requires a good/bad fixture pair per class; criterion 3
  requires mutation proof for A1 and A5)
- CHK4: Do Steps 1 and 3 agree on the anomaly identifiers? - PASS (A1-A6,
  I1-I2 in both)
- CHK5: Is "anomaly" defined concretely enough to avoid false positives? -
  FAIL (ambiguous, on first draft: the check as originally written produced
  115 hits of which 2 were real) - revised in place: R3 now specifies the
  effective-tools formula and Step 1 criterion 2 bounds the finding count at 5
- CHK6: Is the haiku fitness claim justified rather than asserted? - FAIL
  (missing, on first draft) - revised in place: the "Haiku fitness" subsection
  states the conditional (detection in a script) and the re-derivation trigger
- CHK7: Does the plan state what happens when the data source is missing or
  changes format? - PASS (R1; Step 1 criteria 5-6)
- CHK8: Is the ship scope decided, and does the step list depend on it? -
  PASS (was FAIL/missing -> Open Question 1; answered 2026-08-09, plugin
  persona, full scope, recorded in Clarifications)
- CHK9: Is the persona's name settled? - PASS (was FAIL/conflicting -> Open
  Question 2; answered 2026-08-09, `agent-auditor` retained, collision
  accepted and mitigated by Step 6)
- CHK10: Is the v1 anomaly-set size signed off? - PASS (was FAIL/missing ->
  Open Question 3; answered 2026-08-09, all six checks plus two inventories)
- CHK11: Do the acceptance criteria account for the clean-checkout
  requirement? - PASS (R2; stated on Steps 0, 1, 4, 5)
- CHK12: Does the plan avoid tagging prior-FAIL surfaces as cheap work? -
  PASS (Steps 1, 4, 5 each carry an explicit "not haiku" note citing R2)
- CHK13: Is P4 (graceful degradation) enforced or merely intended? - PASS
  (Step 4 adds the persona to the `tests/validate.sh:141` loop, so Step 6's
  phrasing is machine-checked)
- CHK14: Was every acceptance criterion executed against the current tree to
  confirm it is RED rather than vacuous? - FAIL (ambiguous, on first draft:
  Step 5 criterion 4 asserted the *absence* of a version string that appears
  nowhere in the tree, so it passed while checking nothing; Step 6 criterion 3
  errored outright on an empty diff) - revised in place, and the underlying
  cause recorded as R9
- CHK15: Do R2's clean-checkout requirement and Step 5's `git status
  --porcelain` criterion agree, given the tree's actual state? - FAIL
  (conflicting) - revised in place: R9 adds the sweep-first precondition that
  makes the criterion reachable

- CHK16: Is the R9 resync's disposition stated explicitly rather than left
  implicit? - PASS (R9 names it Step 0, in scope, its own unit, with the
  reasoning and the measurement that makes it cheap)
- CHK17: Does Step 0's existence make Step 5's criterion 2 reachable? - PASS
  (Step 0 criterion 3 leaves the tree clean at 0.29.0, which is the state
  Step 5 criterion 2 assumes)

**No FAILs remain.** Five were revised in place during the single permitted
revision pass; three (CHK8-CHK10) were converted to OQ1-OQ3 and have since
been answered by the requester.

---

## Amendment A1 - 2026-08-09 - Step 5 cannot add an opt-in persona via `--update` alone

Raised mid-flight by `lead-programmer` while executing Step 5 (gh-285) and
correctly escalated rather than routed around. Steps 0-4 are merged and
PASSed. **This amendment supersedes Step 5's Ordered Edits and Acceptance
Criteria; every other step is unaffected.**

### Confirmed diagnosis

The report is accurate and I reproduced it in a throwaway copy of this repo:
`node bin/cli.js --update` exits 0 with "already current... Nothing to
update" and creates no mirror.

`runUpdate()` derives its work list from **this project's own recorded
selection** - `config.personaSelection || []` at `bin/cli.js:862` - and never
parses `--personas=`. That flag is read only in the scaffold path
(`bin/cli.js:1814`), so appending it to an `--update` invocation is silently
ignored. This repo's `personaSelection` does not contain `agent-auditor`, so
there is nothing for `--update` to do.

**This is a recurrence of the `191` defect class**, and worth naming as such:
two code paths that must agree about persona rendering, verified through only
one of them. Step 4's criterion 3 exercised `--personas=agent-auditor` against
a **fresh temp-dir scaffold**, which is precisely the path that *does* honour
the flag - so it passed while the already-adapted path stayed broken. R2 warned
that `bin/cli.js` has two render paths; the criterion still only covered one.
Amendment criterion 6 below closes that specific hole. Step 4 is merged and
PASSed and is **not** reopened.

### Decision: dogfood, via an explicit config edit. No `bin/cli.js` change.

Direction **(a), narrowed** - this repo self-selects `agent-auditor` by adding
it to `.claude/persona-config.json`'s `personaSelection`, which is a
spec-sanctioned edit authorised *here* rather than a `lead-programmer`
judgment call. Direction (b) is rejected: without the mirror the persona is
registered but unusable in the one repo whose own transcripts the entire spec
was derived from, and it would hollow Step 5 out to nothing.

Two alternatives were considered and rejected:

- **`node bin/cli.js --overwrite --personas=<full list>`** is a real sanctioned
  path, but wrong here. Its own console message states it re-copies
  agents/hooks/skills/protocol **unconditionally**, without the diffing that
  `--update` does, so it discards the divergence protection this plan relies
  on. Worse, `--personas=` is **replacement**, not additive
  (`OPTIONAL_PERSONAS.filter((p) => requested.includes(p))`, `:1863`) - omit a
  persona already selected and it is silently dropped.
- **Teaching `runUpdate` an additive `--personas=` flag** is the
  product-correct fix, but it is a genuine feature affecting every AntiSlop
  user who adopts any newly-registered optional persona - not this plan's job.
  Doing it mid-flight reopens R2's `bin/cli.js` exposure and widens scope.
  **Recommend filing it as its own issue** (see Follow-up below).

`personaSelection` is *input* to the generator, not generated content, so
editing it and letting the script derive everything else is exactly what
constitution P2 prescribes. P2's named hazards (`fileHashes`, the
`substitutions` slots) stay script-written: the new `fileHashes` entry is
added by `--update` itself, never by hand.

### Step 5 - corrected Ordered Edits

1. Add `"agent-auditor"` to the **end** of `personaSelection` in
   `.claude/persona-config.json`. Append only - do not reorder or drop any
   existing entry. This one-line data edit is authorised by this amendment.
2. Run `node bin/cli.js --update` from the repo root.
3. Commit **both** changed files in a single commit (see criterion 3 for the
   exact expected set).

**Expected output**, verified in a throwaway copy on 2026-08-09: exit 0, one
line reading `.claude/agents/agent-auditor.md: created`, and every other
mirror reporting `already current`.

**One expected warning, which is NOT a regression.** The run prints
`WARNING: unresolved placeholder(s) remain in: .../.claude/agents/orchestrator.md`.
It names `orchestrator.md` only - never `agent-auditor.md` - and is the known
false positive tracked as **open issue #275** (`PLACEHOLDER_RE` matching the
literal `<HEAD>` in that file's body). Exit code is still 0. Do not chase it,
and do not "fix" `orchestrator.md` in this unit.

### Step 5 - corrected Acceptance Criteria

All verified against a throwaway copy of this repo on 2026-08-09, so each is
known reachable rather than hoped-for.

1. `node bin/cli.js --update` exits 0 and its output contains
   `.claude/agents/agent-auditor.md: created`.
2. The mirror exists, is slim-tier, and carries the current stamp:

        test -f .claude/agents/agent-auditor.md
        v=$(jq -r .version .claude-plugin/plugin.json)
        grep -q "antislop v$v" .claude/agents/agent-auditor.md

3. **The change set is exactly two files** - no other mirror is touched
   (measured: the only diffs are the new persona file, plus
   `personaSelection` gaining one entry and `fileHashes` gaining one key):

        test "$(git status --porcelain -uno | wc -l)" -eq 1   # persona-config.json
        git status --porcelain | grep -q '^?? .claude/agents/agent-auditor.md'

4. `.claude/persona-config.json` records both halves:

        jq -e '.personaSelection | index("agent-auditor")' .claude/persona-config.json
        jq -e '.fileHashes | has(".claude/agents/agent-auditor.md")' .claude/persona-config.json

5. **Idempotent** - a second `node bin/cli.js --update` exits 0, reports
   `already current`, and creates or updates nothing.
6. **Both persona-render paths are covered** (closes the Step 4 gap, and the
   `191` recurrence). After committing, a fresh scaffold into a temp dir must
   also produce the persona, proving the two paths agree:

        d=$(mktemp -d)
        (cd "$d" && node /home/sebas/AntiSlop/bin/cli.js --yes)
        test -f "$d/.claude/agents/agent-auditor.md"

7. `bash tests/validate.sh` exits 0 and `node tests/cli-backfill.test.js`
   exits 0.
8. After the commit, `git status --porcelain -uno` is empty. Note the
   untracked `.claude/.review-join.*` stamp is **not** in scope - it is the
   review mechanism's own artifact and a known gitignore gap (**open issue
   #277**), which is why this criterion uses `-uno`.

**Model floor unchanged**: still **not `haiku`** (R2).

### Follow-up recommended, not in this plan

`--update` has no way to add a newly-registered optional persona to an
already-adapted project. Every project that has already run ADAPT hits this
the moment any new optional persona ships - so it is a product gap, not a
quirk of this repo. Suggested shape: make `--update --personas=` **additive**
(union with the recorded selection, never replacement, so it cannot silently
drop a persona the way the scaffold path's semantics would). Worth filing as
its own issue; it must not be tagged `haiku` (R2).

### Routing

**No `task-master` round-trip needed.** This changes one step's edits and
criteria - no new units, no re-slicing, no changed dependencies, and Steps 6-7
are untouched. Hand it straight back for a corrected `lead-programmer`
dispatch on the existing gh-285 issue. The dispatch prompt must state that
Amendment A1 **supersedes** the issue body's Ordered Edits, since gh-285 still
carries the stale "run `--update`" instruction.

## Scribe update hint

On completion: a CONTEXT.md glossary entry distinguishing the three auditing
roles (`reviewer` = verdict on code, `milestone-auditor` = audit of the plan,
`agent-auditor` = observation of agent activity, no verdict), and a wiki page
documenting the transcript store's layout - the latter is the higher-value
artifact, since R1 makes that layout a load-bearing external dependency this
repo now relies on but does not control.

## Handoff

**8 dispatchable units** (Step 0 plus Steps 1-7), so this takes the **standard
path**: `task-master` slices it with `to-tickets`, assigns each unit's
`Suggested model` tag, and writes the per-unit dispatch prompts. Not the
<=2-unit fast path.

**Ordering.** Step 0 is a hard prerequisite and must be merged before any other
unit starts (R9). Steps 1-3 (script, persona file, test) are independent of
Steps 4-5 (registration, mirrors) and may run in parallel. Step 5 depends on
Steps 2 and 4. Steps 6-7 come last; Step 7 must be the final commit so the
version bump covers everything.

**Retrieval contract.** Per `.claude/persona-config.json`'s `issueTracker`:
GitHub issues in `Storreslara/AntiSlop`, `gh` CLI already authenticated.
`task-master` files one issue **per step** with `to-tickets`, labelled
`ready-for-agent` + `plan/2026-08-09-agent-auditor-persona`. Each unit's
dispatch prompt states, verbatim:

> Fetch your unit with `gh issue view <N>`. The full spec is
> `docs/plans/2026-08-09-agent-auditor-persona.md` in the repo root; read your
> step's section plus Risks R1-R9 before starting.

List the slice with
`gh issue list --label plan/2026-08-09-agent-auditor-persona`. Per repo
convention no umbrella issue is filed for the spec itself.

**Model-floor constraints carried to `task-master`** (the floor is mine; the
actual tag is task-master's call):

| Unit | Floor | Evidence |
|---|---|---|
| Step 0 | `haiku` is fine | no prior-FAIL exposure, provably mechanical (R9) |
| Step 1 | **not `haiku`** | R3 - the calibration is the substance of the step |
| Step 4 | **not `haiku`** | R2 - 12 prior FAILs on `bin/cli.js`, incl. 191 (dual render paths) and 224 |
| Step 5 | **not `haiku`** | R2 - 224 is a partial commit of exactly this file set |
| Steps 2, 3, 6, 7 | no floor stated | no prior-FAIL record on these surfaces |

---

## Amendment A2 - 2026-08-09 - Step 7 must regenerate the stamped mirrors, and must bump `package.json`

Raised mid-flight by `reviewer` in the gh-286 (Step 6) verdict and recorded as
non-blocking note 1 of its FAIL record. Steps 0-6 are merged and PASSed.
**This amendment supersedes Step 7's Affected files, Ordered Edits and
Acceptance Criteria; every other step is unaffected.** No new units, no
re-slice, no changed dependencies.

### Confirmed diagnosis

Every claim below was re-verified independently on 2026-08-09 in a throwaway
`git clone` of this repo at HEAD - measured, not read off the source.

**1. The orchestrator mirror is stale, and silently so.**

        grep -c 'agent-auditor' agents/orchestrator.md          -> 1
        grep -c 'agent-auditor' .claude/agents/orchestrator.md  -> 0

**2. `--update` at the current version is a no-op.** Measured: `node
bin/cli.js --update` prints `antislop v0.29.0 - already current ... Nothing to
update.` and exits 0, creating nothing.

The mechanism is the version-match fast-path at `bin/cli.js:984`. Its
`needsRender` guard (`:965-983`) is computed from **file absence or a stale
stamp only** - it never compares a mirror against its re-rendered source. So a
source edit landing while `pluginVersion === version` is structurally
invisible to a plain `--update`. Step 5 ran `--update` at `e6cb79a`; Step 6
edited `agents/orchestrator.md` afterwards (`502fdd8`), missing the regen
window entirely.

**3. Bumping the version does fix it, and the content change is confined to
that one file.** Measured after setting `version` to `0.30.0` and re-running:

        .claude/agents/orchestrator.md: updated (no local edits detected)
        <12 others>: stamp refreshed (v0.29.0 -> v0.30.0, content unchanged)

`grep -c 'agent-auditor' .claude/agents/orchestrator.md` then returns 1, and
the rendered text is Step 6's routing bullet verbatim. `--update` also rewrites
`.claude/persona-config.json`'s `pluginVersion` and its `fileHashes` entries
itself, so **nothing here is hand-edited** - constitution P2 holds exactly as
it did for Step 5.

**4. Independent second gap, not in the reviewer's report: Step 7's criterion
4 is unsatisfiable as written.** `tests/validate.sh:38-40` asserts that
`package.json`'s version equals `.claude-plugin/plugin.json`'s. Bumping only
the latter yields:

        FAIL package.json version (0.29.0) != .claude-plugin/plugin.json version (0.30.0)

and exit 1. Step 7's Affected files omit `package.json`, and issue #287's
"Do NOT touch" section forbids touching it while instructing the implementer to
"treat that as a spec gap rather than adding it unilaterally". That escape
hatch was correctly designed and has now fired: **this amendment is the spec
resolving it.** With both files bumped, `bash tests/validate.sh` exits 0 with
zero `FAIL` lines (measured).

### Step 7 - corrected Affected files

`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`,
`.claude/persona-config.json`, and the 13 stamped mirrors (ten
`.claude/agents/*.md`, plus `.claude/persona-protocol.md`,
`.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`).

**17 files.** The mirrors are *generated*: they are listed because they will
appear in the diff, not because anything in them may be hand-edited.

### Step 7 - corrected Ordered Edits

1. Bump `version` in `.claude-plugin/plugin.json` (minor bump above whatever
   the live pre-edit value is; measured 2026-08-09 as `0.29.0 -> 0.30.0`).
2. Bump `version` in `package.json` to **the identical string**. Authorised
   here, superseding #287's "Do NOT touch `package.json`".
3. Update `.claude-plugin/plugin.json`'s `description` to name `agent-auditor`.
4. Run `node bin/cli.js --update` from the repo root. Pass no other flag -
   `--personas=`, `--overwrite`, `--accept=` and `--keep=` are all unnecessary
   here and A1's reasoning against them applies unchanged.
5. Add the dated `CHANGELOG.md` entry under the new version (see the accuracy
   constraint below).
6. Commit all of it as the single final commit of the feature.

**Hand-edit nothing under `.claude/`** - edit 4 generates all of it.

**One expected warning, which is NOT a regression**, identical to A1's:
`WARNING: unresolved placeholder(s) remain in: .../.claude/agents/orchestrator.md`.
Exit code is still 0. This is the known false positive tracked as **open issue
#275** (`PLACEHOLDER_RE` matching the literal `<HEAD>` in that file's body). Do
not chase it, and do not "fix" `orchestrator.md`.

**CHANGELOG accuracy constraint.** Two prior FAILs of exactly this shape make
this non-optional. `gh-212-version-bump` FAILed with all six of its criteria
green, because the CHANGELOG entry described a mechanism that did not exist;
`gh-286-docs` FAILed because, in its reviewer's words, "every one of them is a
membership grep ... the criteria set cannot distinguish accurate documentation
from confident fiction". The entry must therefore describe only what ships, as
measured in the gh-286 verdict: six anomaly checks (A1-A6) plus two
informational sections (I1 model distribution, I2 skill inventory). It must
**not** claim a tool inventory or a per-dispatch enumeration - neither is
emitted in either output mode.

### Step 7 - corrected Acceptance Criteria

Each was executed on 2026-08-09 and confirmed **RED against the pre-edit tree
and GREEN after the corrected edits**, so none is vacuous (R9).

1. Both version files agree, and the version moved:

        pj=$(jq -r .version .claude-plugin/plugin.json)
        test "$pj" = "$(jq -r .version package.json)"
        # and "$pj" is strictly greater than the pre-edit value read at execution time

2. `jq -r .description .claude-plugin/plugin.json | grep -q 'agent-auditor'`
3. `head -40 CHANGELOG.md | grep -q "$pj"`, and the entry names the persona.
4. **The mirror actually gained the routing line.** This is the point of the
   amendment, so it asserts content, never the stamp:

        grep -q 'agent-auditor` if present' .claude/agents/orchestrator.md

   Measured: 0 matches before, 1 after.
5. **Source/mirror parity**, so the check cannot rot if Step 6's wording is
   ever revised:

        test "$(grep -c 'agent-auditor' .claude/agents/orchestrator.md)" \
           = "$(grep -c 'agent-auditor' agents/orchestrator.md)"

   Measured: `0 = 1` (RED) before, `1 = 1` (GREEN) after.
6. The mirror carries the new stamp and the script updated the config itself:

        grep -q "antislop v$pj" .claude/agents/orchestrator.md
        test "$(jq -r .pluginVersion .claude/persona-config.json)" = "$pj"

7. **No residual drift anywhere in the mirror set.** `--update --check` forces
   the render loop past the fast-path, making this the general form of the bug
   this amendment fixes rather than a one-file spot check:

        ! node bin/cli.js --update --check 2>&1 | grep -qE ': (updated|created|pending)$'

   Measured post-fix: every managed file reports `already current`.
8. `bash tests/validate.sh` exits 0 **and prints zero `^FAIL` lines**, and
   `node tests/cli-backfill.test.js` exits 0.
9. **Idempotent**: a second `node bin/cli.js --update` exits 0, reports
   `already current`, and changes nothing.
10. After the commit, `git status --porcelain -uno` is empty. As in A1, the
    untracked `.claude/.review-join.*` stamp is out of scope (**open issue
    #277**), which is why this uses `-uno`.

### Model floor - corrected

The Handoff table's row `Steps 2, 3, 6, 7 | no floor stated | no prior-FAIL
record on these surfaces` is **wrong for Step 7**, and is superseded here. A
FAIL record exists for `gh-212-version-bump` - a version-bump-plus-CHANGELOG
unit, i.e. precisely this surface - and another for `gh-286-docs`, the
immediately preceding step whose carried-forward defect this amendment exists
to close. Step 7 is therefore **not `haiku`**. The floor is mine; the tag
remains `task-master`'s call.

### Routing and the #287 ticket

**No `task-master` round-trip needed**, exactly as for A1: one step's edits and
criteria change, with no new units and no re-slicing. Following the A1
precedent set earlier in this same plan, the issue body is **not patched** -
the corrected `lead-programmer` dispatch prompt must state that **Amendment A2
supersedes issue #287's Affected files, Ordered edits, Do NOT touch, and
Acceptance criteria sections**, since #287 still carries all four in their
stale form. Two of its lines are now actively misleading and the dispatch must
name them explicitly:

- "**Do NOT touch** `package.json`" - reversed by corrected Ordered Edit 2.
- "**Do NOT touch** any stamped mirror under `.claude/` - already current from
  Steps 0 and 5" - false; they are stale, and corrected Ordered Edit 4
  regenerates them (via the script, still never by hand).

### Self-check (Amendment A2)

- CHK18: Does the amendment assert, machine-checkably, that the mirror gained
  the routing line rather than merely that the stamp advanced? - PASS
  (criteria 4 and 5, both confirmed RED pre-edit)
- CHK19: Do the corrected Affected files and corrected Ordered Edits agree
  about `package.json`? - FAIL (conflicting, on first draft: the edits bumped
  it while the file list still omitted it) - revised in place; both now carry
  it, and #287's contrary instruction is explicitly superseded.
- CHK20: Is the pre-existing criterion "`tests/validate.sh` exits 0" reachable
  given the repo's actual version-parity check? - FAIL (missing, in the
  pre-amendment plan: `package.json` was never in scope, so the criterion was
  unsatisfiable) - revised in place by corrected Ordered Edit 2 and criterion 1.
- CHK21: Does the plan now state a reason for the mirror regen that matches
  reality? - PASS (the P3 note lists Step 6's edit as reason 2 and names the
  `bin/cli.js:984` mechanism)
- CHK22: Do the P3 note and this amendment agree on whether Step 7 is
  bookkeeping or functional? - PASS (both say functional; the P3 note points
  here)
- CHK23: Is the expected change-set size stated, so a reviewer can distinguish
  a correct 17-file diff from an over-broad one? - PASS (corrected Affected
  files, with the 13 mirrors marked generated)
- CHK24: Is the CHANGELOG entry's content constrained, given two prior FAILs
  where membership greps passed over inaccurate prose? - PASS (the accuracy
  constraint names the shipped surface and the two forbidden claims)

**No FAILs remain.** Two were revised in place during the single permitted
revision pass. No new Open Questions: the one genuine decision - bumping
`package.json` - is settled by measurement rather than preference, since
criterion 4 is otherwise unsatisfiable.
