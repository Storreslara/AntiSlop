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

        test -z "$(git status --porcelain -uno)"
        node bin/cli.js --update --check >/dev/null 2>&1; rc=$?
        test "$rc" -eq 0
        test -z "$(git status --porcelain -uno)"

   Measured post-fix: every managed file reports `already current`.

   **Retroactive correction (F2, 2026-08-09).** As originally run, this
   criterion used the single-line grep-based form quoted and analyzed in F2
   below, which is vacuous: it discards the exit code and can match only one
   of the six per-file summary shapes `bin/cli.js` emits. The underlying
   requirement nonetheless converged - the milestone-auditor's independent
   clean-room reconstruction at `d50b8f2` confirmed no residual drift in the
   shipped mirror set. The two-assertion form above is the corrected
   criterion; see F2 for the full drift-shape analysis.
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

---

## Convergence follow-ups - 2026-08-09

**Origin.** Raised by the pre-audit checkpoint after all 8 units (Step 0 plus
Steps 1-7) reached reviewer PASS at `d50b8f2`, and confirmed by the requester
as a real but **non-blocking** drift. This section is **append-only**: Steps
0-7 are merged, PASSed, and untouched. Nothing here invalidates them, and
nothing here is urgent.

### F1 - Goal criterion (a) is only half delivered

The Goal states success as a report that "(a) enumerates every agent dispatch
in a chosen window **with its tool and skill inventory**, and (b) flags a
fixed, calibrated set of anomaly classes". Criterion (b) shipped in full
(A1-A6, a good/bad fixture pair per class, mutation-proven for A1 and A5).
Criterion (a) did not:

| Goal clause | Shipped? | Evidence |
|---|---|---|
| enumerate every dispatch | **no** | no per-dispatch record in either output mode |
| ...its tool inventory | **no, at any granularity** | nothing anywhere reports tool names or counts |
| ...its skill inventory | yes, aggregate only | I2, grouped by `(persona, skill)` |

Re-verified in the current tree on 2026-08-09: the `--json` payload is exactly
`{findings, distribution, skills}` (`scripts/agent-audit.sh:490`), and text
mode renders exactly eight section headers - `A1`-`A6`, `I1`, `I2`. No
per-dispatch record reaches either.

The tool-inventory half is the sharper miss: I1 covers models, I2 covers
skills, and **nothing reports tools at all**. This was found independently
twice by the reviewer - during the gh-286-docs FAIL/fix cycle and again at the
gh-287 final review - which is why Amendment A2's CHANGELOG accuracy
constraint forbids claiming either. The shipped documentation is therefore
**honest about the gap**; no user is currently misled. The drift is between
the Goal prose and Step 1's table, not between the docs and the code.

**Where the drift entered: at spec time, not implementation time.** Steps 1-7
were faithful to Step 1's table, which enumerates exactly six checks and two
inventories with no ninth section, and OQ3 signed that eight-section shape off
explicitly. The Goal sentence was simply never reconciled with the table it
was decomposed into. **That is a spec-authoring defect, not a
`lead-programmer` or `reviewer` miss** - worth recording, because this failure
mode is invisible to a reviewer by construction: the reviewer checks code
against steps, and the steps were internally consistent.

### Is it worth building? Yes - but at low priority, and for one specific reason

**The argument against, which is real.** The requester approved the
eight-section shape at OQ3. The aggregates largely serve the diagnostic
purpose: I1 answers "who ran at what model", I2 answers "which skills fired".
Reading criterion (a) as "the report accounts for every dispatch in the
window" rather than "the report prints a line per dispatch" is a defensible
reading in hindsight, and on that reading the only thing genuinely missing is
a tool inventory.

**The argument for, which is stronger but narrow.** Two things the aggregates
cannot do:

1. **No tool inventory exists at any granularity.** This is not a granularity
   mismatch - one of the two named inventories was never built. Adding it
   aggregate-only costs the same as adding it per-dispatch, so per-dispatch
   strictly dominates.
2. **Anomaly findings are not self-contained.** Every A1-A5 finding prints
   `session=<sid> agent=<aid> persona=<p>` and nothing more. Answering "what
   else did that dispatch do?" currently means hand-grepping the transcript
   store. A per-dispatch line makes the report answer its own immediate
   follow-up question - which is a better reason to build this than
   criterion-(a) compliance is.

**It is cheap where the logic lives.** The enumeration already exists
internally: `$DISPATCHES` is a per-dispatch TSV (`session, agent, persona,
timestamp, depth, model, teammate, description, transcript-path`) that all six
checks already iterate, and the A1 loop already extracts each dispatch's
`tool_use` names. I3 is **render-only** - no new parsing and no new
transcript-format coupling, so R1's exposure does not widen.

**But the ceremony tail is the larger half, and must not be underestimated.**
`agents/agent-auditor.md` names the inventory count in its body (`:10`, `:59`),
so adding I3 edits a **version-stamped** file and thereby drags in constitution
P3 and the whole Amendment A2 mechanism: a version bump in both
`.claude-plugin/plugin.json` and `package.json`, a CHANGELOG entry, and
`node bin/cli.js --update` to regenerate the mirrors. The ~20 lines of render
logic are the small part of this unit.

### Step 8 - I3, a bounded per-dispatch tool-and-skill inventory

**One unit, deliberately.** Splitting the script edit from the persona-doc edit
would recreate Amendment A2's exact defect - a source edit landing after the
regen window, leaving `.claude/agents/agent-auditor.md` silently stale.

**Affected files**: `scripts/agent-audit.sh`, `tests/agent-auditor.test.sh`,
`agents/agent-auditor.md`, `commands/audit-agents.md`, `CHANGELOG.md`,
`.claude-plugin/plugin.json`, `package.json`, plus the generated files
`--update` rewrites (`.claude/persona-config.json` and the stamped `.claude/**`
mirror set). As in A2, the generated files are listed because they appear in
the diff, never because anything in them may be hand-edited.

**Output shape** - one line per dispatch, counts only:

    I3 Per-dispatch inventory (showing 200 of 1254)
      session=<sid> agent=<aid> persona=<p> model=<m> tools=Bash:41,Read:12 skills=antislop:tdd

**Three scoping decisions, each with its reason:**

- **Bounded in text mode, uncapped in JSON.** Cap the text render at 200
  dispatch lines, with the header always stating `showing <shown> of <total>`;
  emit the full `dispatches` array under `--json`. Measured 2026-08-09:
  **1254** dispatches corpus-wide, but a single session's window is **11 at the
  median and 68 at the observed maximum** (across 34 sessions with subagents in
  this project), so the default window never truncates and only `--all` ever
  does. JSON stays uncapped because its consumer is `jq`, which filters for
  itself.
- **No `description` field (R5).** A dispatch `description` is author-written
  free text, and R5 confines the report to metadata, names, paths and counts.
  `agent=<aid>` already correlates a line with its anomaly finding, which is
  the entire point of the section. Reinstating `description` later is a
  decision that requires re-reading R5, not a formatting tweak.
- **Informational, never a flag.** I3 is an `I`-series section: it never fires,
  never counts as a finding, and never affects an exit code. The persona's "an
  observation for a human, not a verdict" boundary is unchanged.

**Acceptance criteria.** Criteria 1 and 8 were executed against the current
tree on 2026-08-09 and confirmed **RED**, so the section cannot pass vacuously
(R9's lesson).

1. The section exists in both modes. Confirmed RED - the JSON payload has no
   `dispatches` key and no `^I3` header renders:

        bash scripts/agent-audit.sh --all | grep -qE '^I3 '
        bash scripts/agent-audit.sh --all --json | jq -e '.dispatches | length > 0'

2. **Enumeration is complete, not a sample** - against the test fixture, the
   array holds exactly one entry per `*.meta.json`:

        n=$(find "$FIXTURE_ROOT" -name 'agent-*.meta.json' | wc -l)
        test "$(AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all --json \
          | jq '.dispatches|length')" -eq "$n"

3. **Tool counts are real, not placeholders** - the existing `a1bad` fixture's
   transcript contains exactly one `Write`:

        AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all --json |
          jq -e '.dispatches[] | select(.agent=="a1bad") | .tools == [{"name":"Write","count":1}]'

4. **Every anomaly finding is correlatable** - this is the diagnostic value,
   asserted rather than hoped for. No A1-A5 finding may name a dispatch that is
   absent from the enumeration:

        AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all --json | jq -e '
          ([.findings[] | select(.id | test("^A[1-5]$")) | {s:.session, a:.agent}] -
           [.dispatches[] | {s:.session, a:.agent}]) | length == 0'

5. **The bound holds and truncation is stated honestly.** Generate a fixture of
   201 minimal dispatches - deterministic on purpose, because a criterion
   pinned to the live corpus staying above 200 is a baseline that expires:

        out=$(AGENT_AUDIT_ROOT=$BIG_ROOT bash scripts/agent-audit.sh --all)
        test "$(printf '%s\n' "$out" | sed -n '/^I3 /,$p' | grep -c '^  session=')" -eq 200
        printf '%s\n' "$out" | grep -qE '^I3 .*showing 200 of 201'
        test "$(AGENT_AUDIT_ROOT=$BIG_ROOT bash scripts/agent-audit.sh --all --json \
          | jq '.dispatches|length')" -eq 201

6. **R5 privacy extends to I3** - the same canary pattern Step 1 criterion 7
   established, applied to the new field that carries free text. A fixture whose
   `.meta.json` `description` is `CANARY-DISPATCH-DESC` must not leak it:

        ! AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all | grep -q CANARY-DISPATCH-DESC
        ! AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all --json | grep -q CANARY-DISPATCH-DESC

7. **No regression in the eight shipped sections** (Step 1 criterion 1,
   re-run with I3 added):

        for id in A1 A2 A3 A4 A5 A6 I1 I2 I3; do
          bash scripts/agent-audit.sh --all | grep -q "^$id" || exit 1
        done
        bash tests/agent-auditor.test.sh    # exits 0

8. **Docs and mirror agree** - closes A2's stale-mirror class. Confirmed RED:
   `grep -c 'I3' agents/agent-auditor.md` returns 0 today, and both docs still
   advertise two inventories:

        grep -q 'I3' agents/agent-auditor.md
        ! grep -q 'two informational inventories I1-I2' agents/agent-auditor.md
        ! grep -q 'two informational summaries' commands/audit-agents.md
        test "$(grep -c 'I3' .claude/agents/agent-auditor.md)" \
           = "$(grep -c 'I3' agents/agent-auditor.md)"

9. **Version discipline (P3)**, binding because `agents/agent-auditor.md` is
   version-stamped. Read the pre-edit version at execution time rather than
   assuming today's value (measured `0.30.0` on 2026-08-09):

        pj=$(jq -r .version .claude-plugin/plugin.json)
        test "$pj" = "$(jq -r .version package.json)"   # and strictly greater than the pre-edit value
        head -40 CHANGELOG.md | grep -q "$pj"
        test -z "$(git status --porcelain -uno)"
        node bin/cli.js --update --check >/dev/null 2>&1; rc=$?
        test "$rc" -eq 0
        test -z "$(git status --porcelain -uno)"

   **Corrected per F2** (2026-08-09): the drift-check line above replaces the
   single-line grep-based form this criterion originally carried, which is
   vacuous for the reasons F2 analyzes. The two assertions are load-bearing
   together - neither alone discriminates both drift shapes in F2's table.

10. `bash tests/validate.sh` exits 0 **and prints zero `^FAIL` lines**;
    `node tests/cli-backfill.test.js` exits 0; and after the commit
    `git status --porcelain -uno` is empty (`-uno` per A1/A2 - the untracked
    `.claude/.review-join.*` stamp is open issue #277).

**CHANGELOG accuracy constraint** carries forward from Amendment A2, with one
amendment of its own: the entry may now claim a per-dispatch tool-and-skill
inventory, because I3 delivers one. It must still not imply the render is
unbounded - `--all` truncates the text output at 200 dispatches.

**Model floor: not `haiku`.** Two reasons. The unit ends in a version bump plus
mirror regen, the surface carrying FAIL records `gh-212-version-bump` and
`224`; and the R5 call about `description` is exactly the kind of omission a
cheap pass "helpfully" adds back.

### Clarifications addendum

The 9-category scorecard is not re-run - this section adds no work beyond the
named finding, and the relevant category was already scored. One dated line,
appended per the incremental rule:

- 2026-08-09 Functional scope & success criteria: Q Does Goal criterion (a)'s
  "enumerates every agent dispatch ... with its tool and skill inventory"
  require a per-dispatch render, or is an aggregate accounting sufficient? -> A
  it required a per-dispatch render and one was not delivered; the category was
  scored **Partial** at drafting and this residual ambiguity was never closed
  before Step 1's table fixed the scope at eight sections. Resolved
  retroactively by Step 8, filed as a non-blocking follow-up per the
  requester's 2026-08-09 decision to file rather than re-plan.

### Self-check (Convergence follow-ups)

- CHK25: Does the finding cite evidence from the shipped artifact rather than
  from the plan's own prose? - PASS (the `{findings, distribution, skills}`
  payload shape at `scripts/agent-audit.sh:490` and the eight rendered headers
  were both re-read in the tree on 2026-08-09)
- CHK26: Is every Step 8 criterion confirmed RED before handoff, so none can
  pass vacuously? - PASS (criteria 1 and 8 executed against the current tree:
  no `dispatches` key, no `^I3` header, no `I3` in `agents/agent-auditor.md`)
- CHK27: Do the Affected files and the stated model floor agree about whether
  this unit touches version-stamped surfaces? - FAIL (conflicting, on first
  draft: the unit was scoped as a script-and-test change with no floor, while
  `agents/agent-auditor.md:10,59` names the inventory count and must therefore
  change) - revised in place: the P3 tail now appears in Affected files, in
  criterion 9, and in the floor's justification.
- CHK28: Is the truncation bound machine-checkable without depending on a live
  corpus whose size changes? - FAIL (ambiguous, on first draft: the bound was
  to be proven against the live store, measured at 1254 today but not stable) -
  revised in place: criterion 5 generates a deterministic 201-dispatch fixture.
- CHK29: Does this section avoid reopening Steps 0-7? - PASS (append-only; no
  existing step, criterion or amendment is edited or renumbered, and Step 8
  continues the existing numbering rather than displacing it)

**No FAILs remain.** Two were revised in place during the single permitted
revision pass. **No new Open Questions**: whether to build Step 8 at all is a
prioritization call for the requester, not missing information - the
recommendation and its counter-argument are both stated above.

### Incidental observation - not part of Step 8

`--json` on an empty window prints the plain-text string `no data for window`
rather than valid JSON (reproduced 2026-08-09 against an empty
`AGENT_AUDIT_ROOT`). Harmless today, since no shipped criterion parses an empty
window - but Step 8's criteria 2-4 pipe JSON mode into `jq`, so whoever
implements it should use non-empty fixtures rather than "fix" this in passing.
If it is ever worth fixing, it is its own unit.

### Routing

Convergence follow-ups take the **standard path**. When someone picks this up,
`task-master` slices it with `to-tickets` - one issue, labelled
`ready-for-agent` + `plan/2026-08-09-agent-auditor-persona` per this plan's
Handoff retrieval contract - assigns the model tag, and writes the dispatch
prompt; it then flows through the normal `lead-programmer` -> `reviewer`
pipeline like any other step. **Not urgent, and not a prerequisite for the
milestone audit.**

---

## Convergence follow-ups, round 2 - 2026-08-09 (post-ship audit, CRITICAL)

Source: the `milestone-auditor` post-ship audit of this plan at commit
`d50b8f2` (all 8 units merged and PASSed, version 0.30.0). Two findings were
accepted as CRITICAL by the requester with an explicit instruction to fix now,
not to track. Append-only: Steps 0-8 and the F1 section above are not edited,
renumbered, or reopened. Numbering continues at Step 9.

**These two are independent units** - different files, different failure
classes - and are scoped as such. They are ordered only by criterion reuse:
Step 9 defines the corrected drift-check form that Step 10's criterion 9 then
uses.

### F2 - the `--update --check` acceptance-criterion form is structurally broken

**The finding.** The criterion

    ! node bin/cli.js --update --check 2>&1 | grep -qE ': (updated|created|pending)$'

appears twice in this plan: in the **already-merged Step 7 criterion 7**
(`:1077`) and, carried verbatim, in the **not-yet-built Step 8 criterion 9**
(`:1340`). It cannot detect what it claims to detect.

`bin/cli.js` emits six per-file summary shapes (`bin/cli.js:1016`, `:1031`,
`:1034`, `:1042`, `:1049`, `:1060`). Anchored at `$`, the regex matches exactly
one of them, `: created`. `: updated (no local edits detected)` can never match
because of the parenthetical, and no line of the form `: pending$` is emitted
anywhere. The pipe additionally discards `bin/cli.js`'s own exit code, which is
the only signal that actually carries the divergence verdict.

**The requirement itself converged.** The auditor's independent clean-room
reconstruction confirmed `d50b8f2`'s shipped mirror set has no residual drift.
Nothing currently shipped needs re-touching. The defect is in the verification
wording alone.

**Correction to the audit's own proposed remedy.** The audit concluded that "a
bare exit-code check would have discriminated correctly." Measured on a
throwaway clone at `d50b8f2` on 2026-08-09, **it would not** - it discriminates
one of the two drift shapes and misses the other, which is the #291 shape:

| Drift shape | real exit code | broken grep form | bare exit-code check | exit code **and** post-run tree clean |
|---|---|---|---|---|
| none (baseline, genuinely current) | 0 | GREEN | GREEN | **GREEN** (correct) |
| A - source edited, mirror stale (**the #291 shape**) | **0** | GREEN | **GREEN** | **RED** (correct) |
| B - mirror carries local edits | **2** | GREEN | RED | **RED** (correct) |

Shape A is the dangerous one and is the shape the auditor reproduced: `--check`
is not a dry run (`checkFlag` is consulted only at `bin/cli.js:984`, to bypass
the fast-path, and gates no write), so it **silently self-heals the drift it
was asked to report** and then exits 0. In the measured run it wrote
`.claude/agents/orchestrator.md` and `.claude/persona-config.json`. Only a
post-run working-tree assertion catches it.

**The corrected form.** Both assertions are load-bearing - neither alone covers
both shapes:

    # Precondition: everything committed. The run below WRITES; a dirty tree
    # makes the post-run assertion unreadable.
    test -z "$(git status --porcelain -uno)"

    node bin/cli.js --update --check >/dev/null 2>&1; rc=$?
    test "$rc" -eq 0                          # catches shape B (exit 2)
    test -z "$(git status --porcelain -uno)"  # catches shape A (silent self-heal)

`-uno` throughout, for the same reason Amendment A2 gives: the untracked
`.claude/.review-join.*` stamp is **open issue #277** and out of scope.

**Relationship to issue #291** (`--check` is misleadingly named; it writes).
**A corrected criterion is sufficient on its own; #291 stays separate and is
not a blocker.** The form above is proven against `--check`'s *current*
semantics, so it does not wait on #291; and #291's own suggested fixes (add a
real dry-run, or rename the flag) are an interface change whose blast radius is
~40 references across nine plan docs, two test files, and three agent-memory
files - bundling it would make a CRITICAL fix wait on a much larger change.

#### Step 9 - correct the drift-check criterion form

**Affected files**: `docs/plans/2026-08-09-agent-auditor-persona.md` (this
file), `tests/cli-backfill.test.js`.

**Explicitly NOT touched**: `bin/cli.js` (its behaviour is #291's business),
and any shipped mirror or version-stamped file - this unit changes no rendered
output, so P3 does not fire.

**Ordered edits**

1. Rewrite **Step 8 criterion 9**'s drift line (`:1340`) to the corrected form
   above, before that step is ever built.
2. Append a **retroactive correction note** to Step 7 criterion 7 (`:1073-1079`)
   - as a note, not a rewrite of the merged step's history - recording that the
   criterion as run was vacuous, that the requirement nonetheless converged per
   the auditor's clean-room reconstruction, and that the corrected form is the
   one above.
3. Add one regression test to `tests/cli-backfill.test.js`, alongside the
   existing `--update --check` drift tests (`:860`, `:975`), that pins the
   discrimination property: in a throwaway tree, shape A must be detectable.
   This is what makes F2 an executable guard rather than a prose edit.

**Acceptance criteria**

1. **Both criterion sites carry the corrected form and no longer carry the
   broken one.** The check is *section-scoped* rather than whole-file, and this
   is load-bearing: the broken pattern legitimately survives elsewhere in this
   file - F2's narrative quotes it as the defect under discussion, and so does
   this criterion - so any whole-file `grep` counts itself and can never pass.
   Confirmed **RED** today: in both sections the corrected form is absent and
   the broken one present.

        P=docs/plans/2026-08-09-agent-auditor-persona.md
        for h in '### Step 7 - corrected Acceptance Criteria' '### Step 8 - I3'; do
          sec="$(sed -n "/^$h/,/^### /p" "$P")"
          printf '%s\n' "$sec" | grep -qF 'test "$rc" -eq 0'             || exit 1
          printf '%s\n' "$sec" | grep -qF ': (updated|created|pending)$' && exit 1
        done

2. **Each corrected site points back at F2**, so a reader landing on the merged
   Step 7 finds the rationale rather than an unexplained change of form.
   Confirmed **RED** today - 0 matches in each section:

        for h in '### Step 7 - corrected Acceptance Criteria' '### Step 8 - I3'; do
          sed -n "/^$h/,/^### /p" "$P" | grep -qF 'F2' || exit 1
        done

   Note for the implementer: do **not** substitute a whole-file `grep -c` for
   either check. `vacuous` is already present in the Step 7 section, and a
   whole-file count of any phrase in this section is satisfied by this section
   itself - both traps were hit and measured while drafting.

3. The new regression test exists and passes:

        node tests/cli-backfill.test.js    # exits 0

4. **The new test is non-vacuous, proven by mutation** - the property it pins
   must actually be able to fail. In a throwaway copy of the tree, introduce
   shape A (append a line to `agents/orchestrator.md`, leave the mirror alone)
   and confirm the test's assertion goes RED there while the old grep form
   stays GREEN. Measured on a clone at `d50b8f2`: grep form GREEN, corrected
   form RED, per the table above.
5. **Scope is respected** - `bin/cli.js` is not modified by this unit:

        git diff --name-only <base>..HEAD | grep -qx 'bin/cli.js' && exit 1

6. `bash tests/validate.sh` exits 0 **and prints zero `^FAIL` lines**; after
   the commit `git status --porcelain -uno` is empty.

**Model floor: not `haiku`.** Not because of R2 (this unit does not touch
`bin/cli.js`) but because the subtlety is the whole unit: the milestone-auditor
itself proposed a remedy that measurement showed to be insufficient. A cheap
pass will reproduce that same plausible-but-wrong fix.

### F3 - R1's own most-dangerous-failure-mode mitigation does not work

**The finding.** R1 (`:220-227`), this plan's self-declared most dangerous
failure mode, requires that "'No anomalies' and 'could not read' must never
render alike." The shipped `--format-probe` does not separate them. Step 1
criterion 5 (`:463-467`) tests only *live vs malformed* and never *empty vs
malformed*, so it passed while the stated requirement went unmet.

**This is a real functional gap in shipped code**, not a wording defect.

**Scope is larger than the audit stated.** Measured against
`scripts/agent-audit.sh` on 2026-08-09, `run_format_probe` (`:156-206`) returns
`FORMAT-UNRECOGNIZED` for **four** distinct operator conditions, and the
`--all` render collapses them further:

| Store condition | `--format-probe` today | `--all` today | should mean |
|---|---|---|---|
| live, with dispatches | `FORMAT-OK` | full report | data is readable |
| valid sessions, **zero dispatches** | `FORMAT-UNRECOGNIZED` | `no data for window` | readable, nothing dispatched yet |
| root exists, empty | `FORMAT-UNRECOGNIZED` | `no data for window` | no data yet |
| root does not exist | `FORMAT-UNRECOGNIZED` | `no data for window` | misconfigured root |
| records exist, none parse | `FORMAT-UNRECOGNIZED` | `no data for window` | **format broke; report untrustworthy** |

The second row is a **false alarm in the opposite direction**, not reported by
the audit and found while scoping this: a perfectly readable store that simply
has no subagent dispatches yet reports the format as unreadable, because `ok=0`
is set when `found_subagent=0` (`:199`). That is the normal first-session case.
A banner that fires on the normal case is a banner operators learn to ignore,
which defeats R1 by a second route.

**Prior defect history on this exact surface.** The reviewed-records directory
holds a FAIL record for `gh-281-detection` (Step 1, `scripts/agent-audit.sh`).
Its **non-blocking note 6 raised this very class and mis-cleared it**,
asserting that "the probe does distinguish them (FORMAT-OK /
FORMAT-UNRECOGNIZED, verified against both an empty dir and a dir with
malformed JSONL)." That verification established live-vs-{empty, malformed}; it
never compared empty against malformed, which are identical. Note 6's proposed
mitigation - "Step 2's persona should always run `--format-probe` before
presenting a report" - was also never implemented: `agents/agent-auditor.md:26`
still lists the probe as optional "debugging". Both halves of note 6 are closed
by this step.

#### Step 10 - make the probe's states genuinely distinguishable

**Affected files**: `scripts/agent-audit.sh`, `tests/agent-auditor.test.sh`,
`agents/agent-auditor.md` **and** its shipped mirror
`.claude/agents/agent-auditor.md`, plus the P3 tail
(`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`, the stamped
mirror set and `.claude/persona-config.json`).

The source doc and its mirror are **one unit, never two**: `tests/validate.sh`
asserts parity between them, so a unit that lands only the source fails the
merge gate.

**Proposed state set** - five conditions, five renders:

| State | Fires when |
|---|---|
| `FORMAT-OK` | session records and dispatch records both parse with the expected keys |
| `FORMAT-OK-NO-DISPATCHES` | session records parse; the window holds zero dispatch records (normal, not a format problem) |
| `FORMAT-EMPTY` | root exists, zero candidate files |
| `FORMAT-NO-STORE` | the root path does not exist (see Open Question 1) |
| `FORMAT-UNRECOGNIZED` | candidate files exist but none parse with the expected keys |

The discriminator is *did a candidate file exist* versus *did it parse* - the
current code conflates the two by testing only the latter.

**Two hard constraints on the implementation**, stated so they are not
rediscovered by trial:

- **Exit codes stay 0 in every mode.** The persona is explicitly non-gating
  (`agents/agent-auditor.md:68-77`), and Step 1 criteria 5-6 pin exit 0. The
  distinction R1 asks for is in the rendered *text*, never in an exit code.
- **The empty-store render stays byte-identical.** `--all` and `--all --json`
  on an empty store must still print exactly `no data for window`. Step 8's
  criteria and the "Incidental observation" at `:1400-1407` both depend on it.
  Only the **malformed** path gains a loud banner.

**Acceptance criteria** (each run in a clean checkout; fixtures built per the
existing pattern in `tests/agent-auditor.test.sh`)

Let `LIVE`, `NODISP`, `EMPTY`, `NOSTORE`, `MALFORMED` be the five roots.

1. **Five conditions render five distinct probe outputs.** Confirmed **RED**
   today - measured 2 distinct values, not 5:

        n=$(for r in "$LIVE" "$NODISP" "$EMPTY" "$NOSTORE" "$MALFORMED"; do
              AGENT_AUDIT_ROOT="$r" bash scripts/agent-audit.sh --format-probe
            done | sort -u | wc -l)
        test "$n" -eq 5

2. **The specific R1 pair, named explicitly** so it cannot pass vacuously the
   way Step 1 criterion 5 did. Confirmed **RED** today - both sides print
   `FORMAT-UNRECOGNIZED`:

        test "$(AGENT_AUDIT_ROOT="$EMPTY" bash scripts/agent-audit.sh --format-probe)" \
          != "$(AGENT_AUDIT_ROOT="$MALFORMED" bash scripts/agent-audit.sh --format-probe)"

3. **No false alarm on a readable store with no dispatches.** Confirmed **RED**
   today:

        ! AGENT_AUDIT_ROOT="$NODISP" bash scripts/agent-audit.sh --format-probe | grep -q FORMAT-UNRECOGNIZED

4. **The primary render is loud on a malformed store**, so R1 holds for a
   consumer who reads `--all` alone. Confirmed **RED** today - prints
   `no data for window`:

        AGENT_AUDIT_ROOT="$MALFORMED" bash scripts/agent-audit.sh --all | grep -q FORMAT-UNRECOGNIZED

5. **Guard - the empty render is unchanged.** GREEN today and must stay GREEN:

        test "$(AGENT_AUDIT_ROOT="$EMPTY" bash scripts/agent-audit.sh --all)" = "no data for window"
        test "$(AGENT_AUDIT_ROOT="$EMPTY" bash scripts/agent-audit.sh --all --json)" = "no data for window"

6. **Guard - exit codes stay 0 everywhere:**

        for r in "$LIVE" "$NODISP" "$EMPTY" "$NOSTORE" "$MALFORMED"; do
          AGENT_AUDIT_ROOT="$r" bash scripts/agent-audit.sh --format-probe >/dev/null || exit 1
          AGENT_AUDIT_ROOT="$r" bash scripts/agent-audit.sh --all          >/dev/null || exit 1
        done

7. **The criteria live in the suite, and are non-vacuous by mutation** -
   following the existing mutation-proof section at
   `tests/agent-auditor.test.sh:255`. `bash tests/agent-auditor.test.sh` exits
   0; and in a `MUTANT_DIR` copy whose probe collapses `FORMAT-EMPTY` back into
   `FORMAT-UNRECOGNIZED`, the suite exits **non-zero**.
8. **Docs and mirror agree, and the probe is no longer optional** - closes both
   halves of `gh-281-detection` note 6. Confirmed **RED** today: `grep -c
   'FORMAT-EMPTY' agents/agent-auditor.md` is 0, and the "debugging" label is
   present at `:26`:

        grep -q 'FORMAT-EMPTY' agents/agent-auditor.md
        ! grep -q 'Format probe (debugging)' agents/agent-auditor.md
        test "$(grep -c 'FORMAT-' .claude/agents/agent-auditor.md)" \
           = "$(grep -c 'FORMAT-' agents/agent-auditor.md)"

   The persona doc must additionally state that the probe is run **first**, and
   that a `FORMAT-UNRECOGNIZED` result means the report is untrustworthy and
   must not be presented as "no anomalies".
9. **P3 version discipline**, binding because `agents/agent-auditor.md` is
   version-stamped. Read the pre-edit version at execution time rather than
   assuming today's value (measured `0.30.0` on 2026-08-09). **Uses Step 9's
   corrected drift-check form** - this is the dependency between the two units:

        pj=$(jq -r .version .claude-plugin/plugin.json)
        test "$pj" = "$(jq -r .version package.json)"   # and strictly greater than the pre-edit value
        head -40 CHANGELOG.md | grep -q "$pj"
        node bin/cli.js --update --check >/dev/null 2>&1; rc=$?
        test "$rc" -eq 0
        test -z "$(git status --porcelain -uno)"

10. `bash tests/validate.sh` exits 0 **and prints zero `^FAIL` lines**; and
    after the commit `git status --porcelain -uno` is empty.

**Model floor: not `haiku`**, on two independent grounds. `scripts/agent-audit.sh`
carries a FAIL record (`gh-281-detection`) whose note 6 mis-cleared this exact
class - the surface has already defeated one reviewer's judgment. And the unit
ends in a version bump plus mirror regen, the surface carrying FAIL records
`gh-212-version-bump` and `224`.

### Sequencing

1. **Step 9 before Step 10** - Step 10's criterion 9 uses Step 9's corrected
   drift-check form.
2. **Step 8 (F1) after Step 10, if it is built at all.** Step 8 and Step 10
   both edit `agents/agent-auditor.md` and both end in a version bump; built
   concurrently they collide. Step 8 remains low-priority per its own section;
   Steps 9 and 10 are CRITICAL and take precedence.

### Clarifications (round 2)

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-08-09 Functional scope & success criteria: Q Does "genuinely
  distinguishable output" mean only that empty and malformed differ, or that
  every operator-visible store condition gets its own render? -> A
  (self-resolved): every condition, expressed as a five-distinct-outputs count
  in Step 10 criterion 1. Fixing only the named pair leaves the no-dispatch
  false alarm in place and would need a third follow-up.
- 2026-08-09 Domain entities / data model: Q What is the probe's output
  vocabulary after the fix? -> A (self-resolved): the five-state table above.
  Whether `FORMAT-NO-STORE` is separate from `FORMAT-EMPTY` is the one part
  left to the requester - Open Question 1.
- 2026-08-09 User interaction flow: Q Must the persona run the probe before
  presenting a report, and must `--all` also be loud on a malformed store? -> A
  (self-resolved): yes to both. `gh-281-detection` note 6 proposed the first
  and it was never implemented; the second is required because R1 constrains
  what the operator *sees*, and the operator reads `--all`.
- 2026-08-09 External dependencies & integrations: Q Does F2 depend on issue
  #291 being fixed first? -> A (self-resolved): no. The corrected form is
  proven against `--check`'s current semantics, and #291's interface change has
  a far larger blast radius; they stay separate.
- 2026-08-09 Edge cases / failure handling: Q Which store conditions must the
  probe separate? -> A (self-resolved): the five in the table, including the
  zero-dispatch case found during scoping and not present in the audit.
- 2026-08-09 Technical constraints & tradeoffs: Q May the fix change exit codes
  or the empty-store render? -> A (self-resolved): neither. Exit 0 everywhere
  (the persona is non-gating and Step 1 criteria 5-6 pin it), and the empty
  render stays byte-identical so Step 8 and the incidental observation at
  `:1400` are not disturbed. Both are pinned as guard criteria.
- 2026-08-09 Completion / acceptance signals: Q What is the correct
  drift-detection criterion, given the broken one? -> A (self-resolved): exit
  code **and** post-run working-tree cleanliness, both load-bearing. The
  audit's own proposed remedy (a bare exit-code check) was measured
  insufficient for the #291 drift shape; see the table in F2.

### Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied - every RED claim in both steps was
  executed against the tree or a throwaway clone on 2026-08-09, and the audit's
  own proposed remedy was measured rather than accepted.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied - the fix
  keeps all detection in `scripts/agent-audit.sh` and adds assertions to
  `tests/agent-auditor.test.sh`; no judgment moves into the model.
- P3 "Version-stamp discipline": satisfied - Step 10 touches
  `agents/agent-auditor.md` and carries the full bump-plus-regen tail as
  criterion 9. Step 9 touches no version-stamped file, so P3 does not apply to
  it.
- P5 "`tests/validate.sh` is the merge gate": satisfied - both steps assert
  exit 0 with zero `^FAIL` lines, and Step 10 keeps the source/mirror pair in
  one unit precisely because `validate.sh` gates their parity.

### Open Questions (round 2)

1. **Is `FORMAT-NO-STORE` worth its own state, or should a missing root render
   as `FORMAT-EMPTY`?** *Recommended: keep it separate.* A typo'd
   `AGENT_AUDIT_ROOT` silently reading as "no activity yet" is the same
   absence-of-data-looks-like-absence-of-findings failure R1 exists to prevent.
   Cost is one branch. **If the requester prefers four states**, the only
   change is Step 10 criterion 1's count, `-eq 5` becoming `-eq 4`, and
   dropping the `FORMAT-NO-STORE` row; nothing else moves.
2. **Confirm Step 8 (F1) is deferred behind these two.** *Recommended: yes,
   defer.* It is low-priority by its own section, and it collides with Step 10
   on `agents/agent-auditor.md` and the version bump. This needs a decision
   only if someone wants F1 built in the same pass.

### Self-check (Convergence follow-ups, round 2)

- CHK30: Does the plan state a corrected drift-check form verified against
  **both** drift shapes? - FAIL (missing, on first draft: the audit's "a bare
  exit-code check would have discriminated correctly" was adopted verbatim,
  and it does not catch the #291 shape) - revised in place: the form now pairs
  the exit code with a post-run tree assertion, and the measured table in F2
  shows each half catching a shape the other misses.
- CHK31: Does the plan say what must **not** change, so Step 10 cannot regress
  Step 8's JSON criteria or the incidental observation at `:1400`? - FAIL
  (missing, on first draft) - revised in place: Step 10 criteria 5 and 6 pin
  the empty render byte-identical and the exit codes at 0, and both are
  labelled guards rather than new behaviour.
- CHK32: Is "genuinely distinguishable" backed by a machine-checkable
  criterion rather than prose? - PASS (criterion 1 counts five distinct probe
  outputs; criterion 2 asserts the specific R1 pair by name, which is the
  assertion Step 1 criterion 5 omitted).
- CHK33: Do Steps 9 and 10 agree about which unit owns the version bump? -
  PASS (Step 9's Affected files exclude every stamped surface and say so
  explicitly; Step 10 carries the whole P3 tail).
- CHK34: Is the `FORMAT-NO-STORE` decision represented in Open Questions
  rather than silently chosen? - PASS (Open Question 1, with the exact
  downgrade path spelled out so either answer leaves the criteria
  machine-checkable).
- CHK35: Is every RED claim in both steps one that was actually executed, not
  inferred? - PASS (all seven RED claims were run on 2026-08-09; the two GREEN
  guard claims in criterion 5 were run as well).
- CHK36: Do both model floors cite concrete FAIL-record evidence rather than
  a general caution? - PASS (Step 10 names `gh-281-detection`,
  `gh-212-version-bump` and `224`; Step 9 explicitly declines to invoke R2 and
  gives its own reason instead).
- CHK37: Does this section avoid reopening Steps 0-8? - PASS (append-only; no
  existing step, criterion, amendment or the F1 section is edited or
  renumbered. Step 9's ordered edit 2 appends a *note* to Step 7's criterion 7
  and rewrites Step 8's criterion 9 - Step 8 is unbuilt and unshipped, so this
  corrects a proposal rather than reopening merged work.)

- CHK38: Are Step 9's own criteria satisfiable and non-vacuous **after** this
  section is appended, given that the section quotes the broken pattern it is
  removing? - FAIL (conflicting: a criterion that greps the file it lives in
  counts itself. Executed against the file post-append, criterion 1's absence
  test could never pass - F2's narrative and the criterion line both carry the
  pattern - and criterion 2's whole-file count was already satisfied by this
  section's own prose. A first repair attempt using an exact count and a
  `[F2-corrected]` marker reproduced the same trap, measuring 4 and 3 where 3
  and 0 were predicted) - revised in place: both criteria are now section-scoped
  via `sed -n "/^<heading>/,/^### /p"`, which structurally excludes this
  section, and both were re-executed against the two target sections to confirm
  RED.

**No FAILs remain.** Three were revised in place. CHK38 is the reason every
criterion here was executed against the file rather than reasoned about: two
of them were wrong in a way only running them exposes. Two Open Questions carry
recommended defaults; neither blocks dispatch, since the criteria are written
against the recommended answers.

### Scribe update hint (round 2)

Once Step 10 lands, `scripts/agent-audit.sh`'s probe contract has changed from
two states to five, and `agents/agent-auditor.md` now mandates running it
first. Worth a CONTEXT.md line. The durable lesson from F2 is worth recording
somewhere a future implementer reads: **asserting on `--update --check` means
asserting on its exit code *and* on the working tree afterwards, because it
writes.** Existing records state only half of this
(`docs/plans/2026-08-03-efficiency-audit-remediation-pass3.md` R-A says exit
code; the lead-programmer agent-memory note `project_cli_check_is_a_write.md`
says it writes) and neither says both halves are needed.

### Routing (round 2)

**Standard path, and CRITICAL rather than deferred.** `task-master` slices this
into **two** issues - one per step, since they touch disjoint files and have
different model rationales - each labelled `ready-for-agent` +
`plan/2026-08-09-agent-auditor-persona` per this plan's Handoff retrieval
contract, with Step 9 sequenced first. Both are `lead-programmer` -> `reviewer`
like any other step. Neither may be tagged `haiku`.

---

## Convergence follow-ups, round 3 - 2026-08-11 (accuracy and calibration)

Closes `milestone-auditor` findings #5, #6 and #7 from the post-Step-7 audit,
filed as issues **#293** (A2/A3 uncalibrated), **#294** (Step 1 criterion 2
asserts a live-corpus bound), and **#295** sub-items 1-4 (four concrete
accuracy defects). Append-only: Steps 1-10 above are unchanged and
un-renumbered.

### Goal

Make the auditor's own reports and its own plan document *accurate*: every
anomaly count means what the persona doc says it means, every stated bound is
reproducible, and the plan's description of the shipped formula matches the
shipped formula.

### Context - what was re-verified on 2026-08-11, and what had drifted

Every finding below was re-measured against the live tree at commit `33c4960`,
not taken from the issue text. Three had drifted materially since filing.

| # | Finding as filed | State on 2026-08-11 |
|---|---|---|
| 293-A2 | 23 findings, all false positives | **45** findings, still 100% false positive |
| 293-A3 | 62 findings, 53 `explorer` | **89** findings, **79** `explorer` |
| 294 | `A1 <= 5` has zero headroom | **already RED - A1 = 6.** The predicted break has happened |
| 295-1 | plan documents 2 union terms, code has 3 | confirmed; code correct, doc wrong |
| 295-2 | 4 of 5 A1 hits are `is_error=true` | **5 of 6**; the 6th (`ToolSearch`) genuinely executed |
| 295-3 | `MARKER_DIR`/`AGENT_AUDIT_ROOT` undocumented | **half-stale**: `AGENT_AUDIT_ROOT` *is* documented at `:429`; `MARKER_DIR` appears nowhere in this plan |
| 295-4 | `--format-probe` labelled "debugging" | **ALREADY CLOSED by Step 10** (`22f5bb2`). No work remains |

Five measurements below are load-bearing and were not available when the
issues were filed:

1. **`spawnDepth` never exceeds 2 anywhere in the corpus** (99 dispatches at
   depth 0, 677 at depth 1, 102 at depth 2). Issue #293's suggestion to
   "require a higher depth" would make A3 **identically zero** - a vacuous
   check. Depth is not a usable dial; the dispatched persona is.
2. **A2's false positives partition perfectly on a field the script already
   reads.** Every unresolvable dispatch is either a Claude Code built-in
   (`general-purpose` x18, `claude-code-guide` x4 - `taskKind` absent) or an
   agent-teams named teammate (28 of them - `taskKind ==
   "in_process_teammate"`). **Residual genuinely-unregistered personas: zero.**
   No alias table and no maintained built-in name list is required.
3. **`customAgentType` cannot be relied on to map a teammate back to its
   persona.** Only 103 of 878 `meta.json` records carry it at all; `lp-238`
   has `"lead-programmer"` but `lp-gh309` has `null`. Issue #293's "map a
   named-teammate spawn back to its underlying persona" is therefore **not
   implementable as stated** - the datum is absent. Sub-classification (below)
   is what is achievable.
4. **Excluding `is_error=true` from A1 would break this plan's own Step 1
   criterion 3 and delete R3's own headline finding.** Of the 6 current A1
   hits, 5 are refusals: 3x `explorer`/`bash` and 2x `reviewer`/`Write`
   (`"No such tool available"`). The 3 lowercase-`bash` hits are precisely
   what R3 (`:267-268`) calls "the one genuinely interesting residual hit" and
   what criterion 3 asserts at `>= 1`. Excluding refusals drops A1 to 1 and
   turns criterion 3 RED. **This decides #295 sub-item 2 by evidence:
   label, never exclude.**
5. **`tests/validate.sh` was RED on the committed tree** (exit 1) at `33c4960` -
   see the blocker below. **Superseded 2026-08-12: the gate is GREEN again**
   (exit 0, zero `^FAIL` lines) at `ba1ad48`; see the blocker section.

### Blocker - the merge gate was RED, for an unrelated reason (CLOSED 2026-08-12)

> **Status as of 2026-08-12 (pre-dispatch audit): CLOSED by commit `f2654dc`
> (`fix(gh340)`), out-of-band, before this round was dispatched.** That commit
> made exactly the call described below - bump first (`0.31.24` -> `0.31.25`),
> then `node bin/cli.js --update --check` to re-render the mirror under the new
> stamp, with `agents/agent-auditor.md` itself untouched. Re-measured at
> `ba1ad48`: `bash tests/validate.sh` exits **0** with zero `^FAIL` lines, and
> both mirror paragraphs are present. **Step 11 therefore has no work left**;
> it is retained, un-renumbered, as a closed record - see its own status note.
> The analysis below is preserved as the diagnosis of record.

`bash tests/validate.sh` exited **1** at `33c4960`. The failing check was
`tests/cli-backfill.test.js`'s F2 regression:

    FAIL F2 regression: shape B (mirror locally edited+committed) ...
    got:  M .claude/agents/agent-auditor.md

Cause: commit `c6ac6e9` (`docs(gh290)`) edited `agents/agent-auditor.md` and
committed **neither** the regenerated `.claude/agents/agent-auditor.md` mirror
**nor** a version bump - a constitution principle 3 violation, and exactly the
"Source-artifact + render-step gating rule" `CONTEXT.md` records. Because the
mirror's stamp still equalled `plugin.json`'s version, a plain `--update` took
the fast path and reported "already current"; only `--update --check` forced
the render (`bin/cli.js:975`, `:1005`).

This was **pre-existing and not caused by this round**, but every acceptance
criterion in this repo asserts `tests/validate.sh` exits 0, so no unit here
could pass until it was cleared. It was scoped as Step 11, sequenced first -
the same call R9 made for the Step 0 resync, and for the same three reasons
(hard blocker, own commit so it never contaminates a feature diff, in-spec so
it is tracked). It was then cleared out-of-band by `f2654dc` before dispatch,
which is Open Question 4's "land it out-of-band first" alternative resolving
itself by event.

### Explicitly out of scope

**Issue #295's systemic recommendation is deferred and NOT addressed here.**
That issue's "why this matters beyond the individual items" section proposes a
lighter-weight channel for a reviewer's advisory notes on a *PASSing* review to
reach `spec-master`. This round fixes the four concrete artifacts those lost
notes describe; it builds **no** routing mechanism, adds **no** hook, and
changes **no** persona's reporting duty. Nobody should read this round as
having closed #295's systemic half - it remains open, alongside the already
queued claim-anchored-criteria follow-up (gh260 / gh-286-docs / gh138).

Also out of scope: A4, A5 and A6 calibration (unbounded, but not named by
#293); `--sessions=N` validation ordering and A6's substring matching
(`gh-281-detection` notes 7 and 8, both marked cosmetic); and any change to
R5 privacy behaviour.

### Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Missing

- 2026-08-11 Functional scope & success criteria: Q What is A3's recalibrated
  bar, given #293 suggests "a higher depth"? → A (self-resolved): not depth -
  measurement shows depth caps at 2 corpus-wide, so any threshold raise is
  vacuous. Recalibrate on the dispatched persona instead; carried to Open
  Question 1 for the exact exclusion set.
- 2026-08-11 Domain entities / data model: Q Which `meta.json` field maps a
  named teammate (`lp-246`) back to its persona? → A (self-resolved): none
  reliably - `customAgentType` is present on only 103 of 878 records. Use
  `taskKind == "in_process_teammate"` to sub-classify rather than to resolve.
- 2026-08-11 Non-functional attributes: Q Does joining `tool_result.is_error`
  back to `tool_use` regress `--all` runtime? → A (self-resolved): baseline
  measured 2026-08-11 at **28.73 s / 9.4 MB peak RSS** over 836 transcripts
  (346 MB). Pinned as a Step 12 guard; **re-measure at execution time rather
  than trusting this number** - the corpus grows every session.
- 2026-08-11 External dependencies & integrations: Q Can this round's units
  assume a green merge gate? → A (self-resolved): no - `tests/validate.sh` is
  RED at `33c4960` from unrelated gh290 mirror drift. Pinned as Step 11,
  sequenced first. **Updated 2026-08-12: yes, they now can** - `f2654dc`
  cleared it out-of-band; re-measured GREEN at `ba1ad48`, and Step 11 is closed.
- 2026-08-11 Edge cases / failure handling: Q For A1's refused calls, exclude
  or label? → A (self-resolved): **label**. Excluding breaks this plan's own
  Step 1 criterion 3 and deletes R3's named headline hit (measurement 4 above).
- 2026-08-11 Technical constraints & tradeoffs: Q May the persona source doc
  and its shipped mirror be separate units? → A (self-resolved): no - the
  "Source-artifact + render-step gating rule" (`CONTEXT.md`) and this round's
  own blocker both forbid it. Always one unit.
- 2026-08-11 Completion / acceptance signals: Q What replaces a live-corpus
  bound as a completion signal? → A: a fixture-pinned corpus of known size, per
  #294; scope of the repointing carried to Open Question 3.

### Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied - all seven findings re-measured live;
  three had drifted, one (295-4) is already closed and is dropped rather than
  re-specified.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied -
  Step 11 regenerates the mirror via `bin/cli.js --update --check`, never by
  hand-editing `.claude/agents/agent-auditor.md`.
- P3 "Version-stamp discipline": satisfied - Steps 11 and 15 each touch a
  version-stamped file and each carries its own bump + CHANGELOG entry.
  (Step 11's bump landed as `f2654dc`; Step 15's remains to be made.)
- P4 "Optional personas degrade gracefully": satisfied - no shared prose
  changes; `agent-auditor` prose is confined to its own file.
- P5 "`tests/validate.sh` is the merge gate": satisfied. It was RED when this
  round was drafted (see Blocker) and Step 11 was scoped to clear it;
  `f2654dc` did so out-of-band, and it is **GREEN at `ba1ad48`**. Every
  remaining step still asserts it exits 0.

### Step 11 - clear the pre-existing merge-gate RED (mechanical, no judgment)

**Affected files**: `.claude/agents/agent-auditor.md` (regenerated, never
hand-edited), `.claude/persona-config.json`, `.claude-plugin/plugin.json`,
`package.json`, `CHANGELOG.md`, plus any other file `--update --check`
rewrites. **No content decisions** - `agents/agent-auditor.md` is NOT edited
by this step.

Ordered: bump the version first, then regenerate, so the mirror lands with the
new stamp in one commit.

**Acceptance criteria** (clean checkout):

1. The gate is green, which is the whole point. Confirmed **RED** today:

        bash tests/validate.sh   # exit 0, and zero '^FAIL' lines

2. The mirror agrees with its source on the two paragraphs gh290 changed.
   Confirmed **RED** today (mirror lacks both):

        grep -q 'benign classes' .claude/agents/agent-auditor.md
        grep -q 'full per-persona model-dispatch distribution' .claude/agents/agent-auditor.md

3. The tree is clean afterwards, and stays clean under a re-run - this is the
   F2 lesson from round 2 (`--update --check` **writes**; assert the exit code
   *and* the tree):

        node bin/cli.js --update --check >/dev/null 2>&1; test "$?" -eq 0
        test -z "$(git status --porcelain -uno)"

4. P3 discipline. Read the pre-edit version at execution time; do not assume
   today's measured `0.31.24`:

        pj=$(jq -r .version .claude-plugin/plugin.json)
        test "$pj" = "$(jq -r .version package.json)"   # and strictly greater than pre-edit
        head -40 CHANGELOG.md | grep -q "$pj"

5. Scope: no behaviour file is touched.

        git diff --name-only <base>..HEAD | grep -qE '^(scripts/agent-audit\.sh|tests/agent-auditor\.test\.sh|agents/)' && exit 1

**Model note**: mechanical, but `bin/cli.js`-adjacent and R2 names 12 prior
FAILs on that surface. **Not `haiku`.**

### Step 12 - A1 distinguishes a refused tool call from an executed one

**Affected files**: `scripts/agent-audit.sh`, `tests/agent-auditor.test.sh`.

Closes #295 sub-item 2. **Label, never exclude** (Context measurement 4).

A1's emitter currently reads only `tool_use` records. A `tool_result` carrying
`is_error` lives in a *later* record of the same transcript, joined by
`tool_use.id` == `tool_result.tool_use_id`; both sit under `.message.content[]`.
Intent, as pseudo-code - the implementer picks the actual form:

    # build id -> is_error from the tool_result records, then tag each tool_use
    $err[.id] // false   ->  emitted as a new "status" field on the A1 finding

Each A1 finding gains a status of `executed` or `refused`; the plain-text A1
section prints a split count. R5 is unchanged: `is_error` is a boolean and
`tool_use_id` is an identifier - **no `tool_result` body text may reach
stdout**, since a refusal message can quote a file path or command.

**Acceptance criteria** (clean checkout):

1. Both statuses are emitted, proven against a fixture (not the live corpus):
   the suite gains an `A1_refused` and an `A1_executed` fixture pair, and

        for s in refused executed; do
          grep -q "A1_${s}" tests/agent-auditor.test.sh || exit 1
        done

2. The JSON finding carries the status, and both values occur, against the
   fixture root:

        AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all --json \
          | jq -e '[.findings[]|select(.id=="A1")|.status]|(index("refused") and index("executed"))'

3. The plain-text render states the split rather than one opaque total:

        AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all \
          | grep -qE '^A1 .*refused'

4. **Non-vacuous by mutation**, following the existing pattern at
   `tests/agent-auditor.test.sh:255`: in a `MUTANT_DIR` copy whose A1 branch
   hard-codes `status` to `executed`, `bash tests/agent-auditor.test.sh` exits
   **non-zero**.
5. **R5 guard**: a fixture whose `tool_result.content` carries the sentinel
   `CANARY-ERROR-BODY` must not leak it:

        ! AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all | grep -q CANARY-ERROR-BODY
        ! AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all --json | grep -q CANARY-ERROR-BODY

6. **Runtime guard.** Baseline measured 2026-08-11: 28.73 s wall, 9.4 MB peak
   RSS, 836 transcripts. **Re-measure the pre-change baseline at execution
   time** (the corpus grows every session; this number is a reference, not a
   constant), then show `--all` is within 1.5x of *that* freshly-measured
   baseline. Rationale: a naive whole-file `jq -s` slurp per transcript is the
   obvious implementation and the one most likely to regress here.
7. `bash -n scripts/agent-audit.sh` exits 0; `bash tests/agent-auditor.test.sh`
   exits 0; `bash tests/validate.sh` exits 0.

**Model note**: not `haiku` - the join is where a plausible-looking wrong
implementation (matching on array position rather than id) passes a weak test.

### Step 13 - A2 and A3 recalibration

**Affected files**: `scripts/agent-audit.sh`, `tests/agent-auditor.test.sh`.
**Depends on Step 12** (same two files; sequence after it).

Closes #293. Both checks currently fire at 100% and ~89% false-positive rates
respectively, which is what makes them unreadable.

**A2** sub-classifies rather than resolves (Context measurement 3 - the
persona datum is simply absent from most records). Three classes, decided by
data the script already has in `$DISPATCHES`:

| Class | Test | Meaning |
|---|---|---|
| `teammate-name` | unresolvable **and** `taskKind == "in_process_teammate"` | an agent-teams spawn name, never a persona name |
| `foreign-type` | unresolvable, not a teammate | a Claude Code built-in or other non-AntiSlop type; cannot have a source file by construction |
| *(residual)* | unresolvable, neither of the above | a genuinely unregistered persona - the only real signal |

**A3** excludes the one nested pattern the shared persona protocol explicitly
prescribes - a nested `explorer` dispatch ("Structural questions go to the
explorer": every persona is *instructed* to do this). 79 of the 89 current
hits are exactly that. The suppression must be **visible**, not silent: the
A3 section prints the suppressed count alongside the residual. Depth is
deliberately **not** touched - see Context measurement 1.

The residual A3 is then a genuinely useful signal rather than noise: a nested
`reviewer` dispatch (1 in the corpus today) is a candidate **review-ownership
violation**, since the protocol states only the orchestrator routes to the
reviewer.

**A fixture trap, stated so it is not rediscovered by trial**: the existing
`A3_bad` fixture (`tests/agent-auditor.test.sh:67`) is an **`explorer` at
`spawnDepth: 2`** - under this step it becomes a *good* fixture. `A3_bad` must
be re-based onto a non-`explorer` persona, and a new fixture must assert the
explorer case is suppressed. A step that edits the script without re-basing
this fixture will fail its own suite.

**Acceptance criteria** (clean checkout; all counts against `$FIXTURE_ROOT`,
never the live corpus):

1. A2 findings carry a class, and the fixture exercises all three:

        AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all --json \
          | jq -e '[.findings[]|select(.id=="A2")|.class]|(index("teammate-name") and index("foreign-type"))'

2. **A2 gains a real bound**: against a fixture holding one genuinely
   unregistered persona plus one of each benign class, the residual is exactly
   1 - proving both that benign classes are classified and that a real one is
   still caught:

        test "$(AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all --json \
          | jq '[.findings[]|select(.id=="A2" and (.class|not))]|length')" -eq 1

3. A3 suppresses nested `explorer` and keeps the rest:

        AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all --json \
          | jq -e '[.findings[]|select(.id=="A3")|.persona]|(index("explorer")|not)'
        AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all --json \
          | jq -e '[.findings[]|select(.id=="A3")]|length >= 1'

4. The A3 suppression is visible in the plain-text render, not silent:

        AGENT_AUDIT_ROOT=$FIXTURE_ROOT bash scripts/agent-audit.sh --all \
          | grep -qE '^A3 .*suppressed'

5. Fixtures re-based, both directions present:

        grep -q 'A3_sanctioned' tests/agent-auditor.test.sh
        sed -n '/A3_bad/,/^$/p' tests/agent-auditor.test.sh | grep -q '"agentType":"explorer"' && exit 1

6. **Non-vacuous by mutation**: in a `MUTANT_DIR` copy whose A3 branch drops
   the explorer exclusion, `bash tests/agent-auditor.test.sh` exits non-zero;
   likewise for a copy whose A2 branch emits no `class`.
7. **Live-corpus sanity, reported not asserted.** The implementer runs
   `bash scripts/agent-audit.sh --all` once and reports the new A2 residual and
   A3 residual in the ready-for-review packet. Deliberately **not** an
   acceptance criterion - that is the exact #294 mistake this round exists to
   stop repeating.
8. `bash -n scripts/agent-audit.sh` exits 0; `bash tests/agent-auditor.test.sh`
   exits 0; `bash tests/validate.sh` exits 0.

**Model note**: not `haiku` - this is calibration judgment, the same rationale
Step 1 carried.

### Step 14 - correct this plan document

**Affected files**: `docs/plans/2026-08-09-agent-auditor-persona.md` only.
Prose accuracy IS the deliverable, so every criterion is claim-anchored: a
negative on the wrong phrasing plus a positive on the canonical one. Each was
confirmed **RED** on 2026-08-11.

Three edits, all in the pre-existing body (not this section):

1. **R3's Effective-tools formula (`:269-272`) - closes #295 sub-item 1.**
   The doc documents two union terms; `scripts/agent-audit.sh` implements
   three. The **code is correct** - independently confirmed by
   `gh-281-detection`'s own mutation test (removing the term yields 11
   findings, 6 of them `milestone-auditor`/`SendMessage`), and the shared
   protocol does grant a teammate `SendMessage` regardless of its declared
   `tools:`. Bring the doc to the code, ratifying the third term.
2. **Step 1 criteria 2-4 (`:456-462`) - closes #294.** Repoint from the live
   corpus to the fixture corpus. Criterion 2 is a *ceiling* and is already RED
   (A1 = 6 as of 2026-08-11). Criteria 3 and 4 are *floors*, safe only while
   transcripts are never pruned - see Open Question 3 for whether both are in
   this unit's scope. Leave a one-line note at the amended criteria recording
   that they formerly asserted against `--all` and why that was wrong.
3. **`MARKER_DIR` (#295 sub-item 3).** Step 1's inputs/outputs (`:427-430`)
   documents `AGENT_AUDIT_ROOT` but never records that the same variable also
   relocates the marker directory to `$AGENT_AUDIT_ROOT/reviewed`
   (`scripts/agent-audit.sh:52-62`) - which is what makes A6 testable at all.
   Record it where `AGENT_AUDIT_ROOT` is already described. **`AGENT_AUDIT_ROOT`
   itself is already documented; do not re-add it.**

**Acceptance criteria**:

1. R3 names three terms including the teammate one (positive), and the
   two-term phrasing is gone (negative). Scope both to the formula paragraph -
   a whole-file `grep` is satisfied by this very section:

        P=docs/plans/2026-08-09-agent-auditor-persona.md
        sed -n '/^\*\*Effective-tools formula\*\*/,/^$/p' "$P" | grep -q 'in_process_teammate'
        sed -n '/^\*\*Effective-tools formula\*\*/,/^$/p' "$P" | grep -q 'SendMessage'
        sed -n '/^\*\*Effective-tools formula\*\*/,/^$/p' "$P" | grep -q 'declared UNION (has memory' && exit 1

2. **No criterion in Step 1 invokes `--all --json` against the live store.**
   Every such invocation must carry a fixture root. Confirmed **RED** today -
   it names exactly criteria 2, 3 and 4, the three #294 points at:

        sed -n '/^## Step 1 - the detection script/,/^## Step 2/p' "$P" \
          | grep -F 'agent-audit.sh --all --json' \
          | grep -vq 'AGENT_AUDIT_ROOT=' && exit 1

   Note a bare `grep -q 'AGENT_AUDIT_ROOT'` over the Step 1 section is
   **already GREEN today** (`:429` mentions the variable in prose) and was
   measured vacuous while drafting - do not substitute it. This criterion
   encodes Open Question 3's default (all three move); if the answer is
   "criterion 2 only", narrow the `grep -F` to that one line.

3. `MARKER_DIR` is documented in the Step 1 section specifically, not merely
   somewhere in the file:

        sed -n '/^## Step 1 - the detection script/,/^## Step 2/p' "$P" \
          | grep -q 'MARKER_DIR'

4. **Append-only respected** - Steps 1-10's headings survive unrenumbered:

        for n in 1 2 3 4 5 6 7; do grep -q "^## Step $n - " "$P" || exit 1; done
        for n in 9 10; do grep -q "^#### Step $n - " "$P" || exit 1; done

5. Scope: only the plan document changes.

        test "$(git diff --name-only <base>..HEAD)" = 'docs/plans/2026-08-09-agent-auditor-persona.md'

6. `bash tests/validate.sh` exits 0.

**Model note**: not `haiku`. Three units in this repo have already FAILed on
docs work gated only by existence greps; the negative/positive pairing above is
the correction, and judging whether an edit actually *says the right thing* is
not a cheap-tier task.

### Step 15 - the persona doc tells the truth about the new output

**Affected files**: `agents/agent-auditor.md` **and** its mirror
`.claude/agents/agent-auditor.md` (**one unit, never two** - the
"Source-artifact + render-step gating rule"; the mirror is regenerated via
`bin/cli.js --update --check`, never hand-edited), plus the P3 tail
(`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`,
`.claude/persona-config.json`).

**Depends on Steps 12 and 13** - this documents behaviour they introduce, so
it must land after both, or it documents a report that does not exist.

Three interpretation blocks change:

- **A1** gains the executed/refused distinction, and states plainly that a
  refused call means the tool was *attempted and blocked*, never invoked -
  the exact misreading that produced `gh-281-detection`'s own note 1.
- **A2** replaces the gh290 prose (which correctly names the two benign
  classes but describes them as *unclassified noise*) with the shipped
  three-class output, and states that the residual is the only real signal.
- **A3** states that nested `explorer` is protocol-sanctioned and suppressed,
  that the suppressed count is printed, and that a nested `reviewer` in the
  residual is a candidate review-ownership violation.

**Acceptance criteria** (each claim-anchored; all confirmed **RED** today):

1. A1's block names both statuses:

        sed -n '/^\*\*A1 —/,/^\*\*A2 —/p' agents/agent-auditor.md | grep -q 'refused'
        sed -n '/^\*\*A1 —/,/^\*\*A2 —/p' agents/agent-auditor.md | grep -q 'executed'

2. A2's block names the three classes and drops the stale "no calibration
   bound" claim (negative), which Step 13 makes false:

        sed -n '/^\*\*A2 —/,/^\*\*A3 —/p' agents/agent-auditor.md | grep -q 'teammate-name'
        sed -n '/^\*\*A2 —/,/^\*\*A3 —/p' agents/agent-auditor.md | grep -q 'foreign-type'
        sed -n '/^\*\*A2 —/,/^\*\*A3 —/p' agents/agent-auditor.md | grep -q 'carries no' && exit 1

3. A3's block names the sanction and the visible suppression:

        sed -n '/^\*\*A3 —/,/^\*\*A4 —/p' agents/agent-auditor.md | grep -q 'suppress'
        sed -n '/^\*\*A3 —/,/^\*\*A4 —/p' agents/agent-auditor.md | grep -q 'explorer'

4. **Mirror parity** on every claim above - the whole reason this is one unit:

        for t in refused executed teammate-name foreign-type suppress; do
          test "$(grep -c -- "$t" agents/agent-auditor.md)" \
             = "$(grep -c -- "$t" .claude/agents/agent-auditor.md)" || exit 1
        done

5. The persona's read-only contract is untouched - no scope creep into its
   frontmatter:

        test "$(awk '/^tools:/{sub(/^tools: */,"");print;exit}' agents/agent-auditor.md)" = "Read, Grep, Glob, Bash"
        grep -q '^model: haiku' agents/agent-auditor.md

6. P3 discipline and a clean tree, both halves per the F2 lesson:

        pj=$(jq -r .version .claude-plugin/plugin.json)
        test "$pj" = "$(jq -r .version package.json)"   # and strictly greater than pre-edit
        head -40 CHANGELOG.md | grep -q "$pj"
        node bin/cli.js --update --check >/dev/null 2>&1; test "$?" -eq 0
        test -z "$(git status --porcelain -uno)"

7. `bash tests/validate.sh` exits 0 and prints zero `^FAIL` lines.

**Model note**: not `haiku` - docs-accuracy work with a mirror-parity gate, the
`gh-286-docs` FAIL profile exactly.

### Sequencing

    Step 11  (clears the RED gate)  ──▶ Step 12 ──▶ Step 13 ──▶ Step 15
                                     └─▶ Step 14 (independent, doc-only)

Step 11 is a hard prerequisite for all four - until it lands, every other
step's `tests/validate.sh` criterion fails for a reason that has nothing to do
with that step. Steps 12 and 13 share two files and are strictly ordered.
Step 14 touches only the plan document and may run in parallel with 12/13,
but still after 11.

### Open Questions

Each carries a recommended default; if unanswered, the default above is what
the steps already encode.

1. **A3's exclusion set.** Suppress only nested `explorer`, or all nested
   foreground spawns (which the protocol's "you CAN spawn foreground
   subagents" arguably sanctions wholesale)?
   *Recommended: `explorer` only.* Suppressing everything makes A3 identically
   zero and deletes the nested-`reviewer` signal, which is a real
   review-ownership violation. Options: (a) `explorer` only [default];
   (b) `explorer` + `scribe` (9 hits, arguably also routine); (c) all nested
   foreground spawns, i.e. retire A3.
2. **A2's benign classes - suppressed from the count, or counted with a
   label?** *Recommended: classified and excluded from the headline residual,
   with the per-class counts printed*, so A2 gains a meaningful bound (residual
   should be 0 on a healthy corpus) without hiding anything. Alternative: keep
   all 45 in the count and label them, which preserves the raw number but
   leaves A2 as unreadable as it is today.
3. **Scope of the #294 fixture repointing.** Criterion 2 is a ceiling and is
   already RED - it must move. Criteria 3 and 4 are floors (`>= 1`), which only
   break if transcripts are pruned. *Recommended: repoint all three*, since
   #294's own wording says "any other criteria asserting fixed bounds against
   `--all`'s live corpus output" and pruning is outside this repo's control.
   Alternative: move only criterion 2, leaving 3 and 4 as live smoke tests.
4. **Does Step 11's version bump belong to this round at all?** It carries
   gh290's un-bumped change, not this round's. *Recommended: yes, in-scope as
   its own unit* - exact R9 precedent, and the gate is RED until someone does
   it. Alternative: land it out-of-band first and start this round at Step 12.

### Self-check

- CHK1: Is the exclude-vs-label decision for A1 (#295 sub-item 2) stated with
  a reason a reviewer can check? — PASS (Context measurement 4 names the
  criterion that would break).
- CHK2: Do the Context table and Step 14 agree about which #295 sub-items are
  still open? — PASS (both carry 295-4 as already closed by Step 10; Step 14
  scopes only sub-items 1 and 3).
- CHK3: Is A3's recalibrated bar defined, given #293 proposed a depth
  threshold? — FAIL (ambiguous) — revised in place: depth is ruled out by
  measurement and the bar is redefined on the dispatched persona; the residual
  exclusion-set choice is converted to Open Question 1.
- CHK4: Does every step have at least one criterion that is RED today, so none
  can pass vacuously? — PASS (each was executed on 2026-08-11 and its RED state
  recorded).
- CHK5: Is it defined what happens to the existing `A3_bad` fixture, which this
  round inverts? — FAIL (missing) — revised in place: the fixture trap is now
  stated explicitly in Step 13 with its own criterion 5.
- CHK6: Do Steps 12 and 13 agree about who owns `tests/agent-auditor.test.sh`?
  — PASS (Step 13 declares the dependency and the strict ordering).
- CHK7: Is the source/mirror pairing rule applied consistently to both files
  that have a mirror? — PASS (Steps 11 and 15; Step 15 states "one unit, never
  two" and criterion 4 gates parity).
- CHK8: Is the runtime baseline stated as a measurement with an expiry rather
  than a constant? — PASS (Step 12 criterion 6 requires re-measuring at
  execution time).
- CHK9: Is #295's systemic half unambiguously excluded, so this round is not
  read as having closed it? — PASS (its own "Explicitly out of scope" section).
- CHK10: Is the completion signal for #294 defined, given category 9 scored
  Missing? — FAIL (missing) — converted to Open Question 3 (which criteria move
  to the fixture).

### Terminology (advisory, `ubiquitous-language` prose mode vs `CONTEXT.md`)

Lens 1 (glossary term used with a different meaning): none found. Lens 2 (new
synonym for a defined term): none found - "refused" is used throughout for a
blocked tool call rather than minting a second word, and "block" stays reserved
for **Gate** semantics. Lens 3 (load-bearing new terms with no glossary entry):
**anomaly check (A1-A6)**, **informational inventory (I1-I2)**, **calibration
bound**, and this round's **refused vs executed tool call** and **fixture-pinned
criterion**. Suggested for `scribe` to consider adding to `CONTEXT.md`; advisory
only, gates nothing.

### Scribe update hint

Once Steps 12-13 land, A1 carries an executed/refused split, A2 carries three
classes, and A3 suppresses a sanctioned pattern - all three change what the
persona's report *means*, which is a `CONTEXT.md` line. Also worth recording:
`spawnDepth` is a 3-valued field (0/1/2) in this harness, which is why a
depth-threshold dial does not exist. And the durable lesson behind this whole
round: **an acceptance criterion asserting a ceiling against a live, growing
corpus is a criterion with an expiry date** - `A1 <= 5` went RED on its own,
with no code change, in under three days.

### Routing

**Standard path.** Five steps, five units, touching four distinct file sets -
well past the two-unit fast path. `task-master` slices via `to-tickets`, each
labelled `ready-for-agent` + `plan/2026-08-09-agent-auditor-persona` per this
plan's Handoff retrieval contract, with **Step 11 sequenced first and blocking
the other four**. All are `lead-programmer` -> `reviewer`. **None may be tagged
`haiku`** - see each step's model note.
