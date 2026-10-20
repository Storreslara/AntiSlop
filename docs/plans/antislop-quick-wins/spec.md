# AntiSlop quick wins after pilot 4 (spec)

Date: 2026-10-20. Author: spec-master. Status: finalized for qw-u1 to qw-u4; qw-u5 is **pending ruling** (OQ1).
Source: `docs/plans/antislop-speed-architecture/findings.md` ("Solution variations", "Recommendation" stage 2).
5 units, fast path (no task-master). Contracts: `docs/plans/antislop-quick-wins/contracts/qw-uN.md`.

## Goal

Cut the orchestrator's per-unit model calls and the per-call prompt size without changing any gate, the
Writer/Reviewer split, the downgrade-only reviewer-tier rule or the sensitive-path rule:

- G1 (c2): the per-unit bookkeeping (ladder tier, reviewer tier, RULING lines, reviewer dispatch header) is one
  script call per phase instead of two to four orchestrator calls. Step 1.
- G2 (b): the orchestrator prompt and the inlined protocol block lose duplicates, incident narratives and a
  rarely used procedure that is moved to an on-demand file, with every live rule mapped to where it survives.
  Steps 2, 3 and 4.
- G3 (c1, pending ruling): the reviewer re-derives blast radius with a script it runs itself and spawns the
  explorer only when the script has no answer. Step 5.
- G4 (e3): dropped, with evidence (Context, "e3"). No unit.
- G5 (e1, e2): not decided here; Open Questions 2 and 3. No unit.

## Context

### Verified evidence this spec relies on

All re-measured on 2026-10-20 from the repo and the pilot-4 streams (`eval/abtest/.runs/e0*_B_uniform_1/`).

- Per-unit orchestrator bookkeeping today: `agents/orchestrator.md` "Per-unit model routing" runs
  `.claude/bin/ladder-tier.sh` before each lead-programmer dispatch; on `reason=guard-demotion` it reruns
  `contract-guard.js` and appends a RULING line, on `reason=no-contract` it appends another; "Reviewer gate
  model selection" runs `.claude/hooks/scripts/reviewer-tier.sh <task-id> <baseline>..HEAD` before each
  reviewer dispatch. `ladder-tier.sh` never writes (its header, line 6). Nothing parses the rulings ledger.
- Hook facts (Claude Code docs, via the claude-code-guide agent): SubagentStop input carries `agent_id`,
  `agent_type`, `agent_transcript_path`, `last_assistant_message`; its `additionalContext` goes to the
  **subagent**, not the parent. Only a PostToolUse hook on a **foreground** `Agent` call can add context to the
  parent; for a background dispatch this is not documented. stop-gate's pending-review flag carries no unit id
  or baseline (`stop-gate-core.sh` writes `<ts> agent=<id>`).
- Explorer cost in review: the reviewer spawned a nested explorer in 8 of 10 reviews (findings, finding 7),
  required by `agents/reviewer.md` "Scope the review via the explorer" and the protocol's "Reuse over
  re-derivation" paragraph ("never applies to the reviewer, which always re-derives blast radius").
  `code-review-graph impact --base <ref>` exists as a CLI (checked with `--help`) and needs no MCP.
- Prompt sizes (bytes, working tree at bce2ded2): `.claude/agents/orchestrator.md` 79,940 (body 55,574 plus a
  24,166 protocol block); reviewer 44,399 (21,363 plus 22,852); lead-programmer 28,177 (7,512 plus 20,468).
  Largest protocol sections: "Review markers and gate mechanics (owner-facing)" 5,826 bytes (in 5 of 6
  full-tier rows), "Terminal status line" 2,459 (in every row). The orchestrator's ESCALATE-TO-HUMAN steps are
  8,855 bytes (130 lines) and largely restate the protocol's "Fourth verdict" section, which no persona
  inlines and the reviewer already reads on demand (`agents/reviewer.md`, "Escalation packet and resolution
  (read on demand)").
- Prose pins that a move must carry: `tests/adapter-protocol-parity.test.js` pins the fold-line and
  `decide:` rules of the escalation steps in `agents/orchestrator.md` (the only test pin on that 130-line
  block, by a 45-char sliding search over all of `tests/`); `tests/persona-prose-pins.test.sh` and
  `tests/writer-tier-consistency.test.js` pin phrases in "Per-unit model routing" and the contract-score
  guard, which Step 1 keeps verbatim.
- Glossary: `docs/harness-glossary.md` already defines **review-packet** (the contract key) and **advisory
  review packet** (lead-programmer's report). The findings' "per-unit review-packet file" would be a third
  meaning, so this spec calls the c2 file the **reviewer dispatch header** (see Clarifications, item 8).

### c2: bookkeeping hook (Step 1, qw-u1)

| Alt | Mechanism | Saving per unit | Risk to the Writer/Reviewer split | Effort | Testability |
|---|---|---|---|---|---|
| c2-A | A SubagentStop step for lead-programmer runs both tier scripts and writes the header; the unit id and baseline come from a new PreToolUse(Agent) record, because the flag has neither | 1 to 2 calls: the orchestrator still needs one call to read the file, since SubagentStop output never reaches the parent | none in principle, but it edits `stop-gate-core.sh` (just changed by aof-u2), its three mirrors and a PreToolUse hook: gate surfaces | M-L | medium (hook fixtures) |
| **c2-B (chosen)** | `bin/unit-bookkeeping.sh`, installed to `.claude/bin/` like aof-u1's helpers. `dispatch <unit> [--contract <path>]` runs ladder-tier, appends the guard-demotion, no-contract and helper-missing RULING lines, records the implementer tier; `review <unit> <baseline>` runs reviewer-tier, writes `.claude/bookkeeping/<unit>.header` and prints it | 1 to 2 calls (ladder plus ledger plus guard rerun become one; reviewer-tier plus header become one) | none: no gate, hook or marker changes; the script prints reviewer-tier's word or `opus`, so it can only keep or raise the tier | S-M | high (stubbed helpers, temp repo) |
| c2-C | PreToolUse(Agent) rewrites `tool_input.model` from the scripts | about 2 calls | invisible input mutation; rejected as 1D in the aof spec for the same reason | M | medium |

c2-B wins: the same call saving as c2-A (the parent must read the result either way), with no gate edits.
Interface left open for the structural stage: the header file and the script are hook-callable (no tty, exit
0 except on bad arguments), so variation f (`review-precheck.sh` at SubagentStop) can call
`unit-bookkeeping.sh review` itself and extend the header with its own checks; variation a can reuse the
`dispatch` subcommand's tier record as its lane input.

### b: prompt diet (Steps 2 to 4, qw-u2 to qw-u4)

| Alt | Mechanism | Saving | Risk | Effort |
|---|---|---|---|---|
| **b-1 (chosen)** | Several small text units, safest first: (i) incident narratives and rationale out of the orchestrator body into `docs/orchestrator-rationale.md`, teams-only text into `commands/start-feature-team.md`; (ii) narrative trim inside two protocol sections every full-tier persona inlines; (iii) the orchestrator's 130-line ESCALATE-TO-HUMAN procedure moved verbatim into the protocol's Fourth verdict section and replaced by a stub naming it and carrying its invariants | orchestrator mirror about -12k bytes (-15%), every full-tier persona -0.7k to -1.9k | low per unit: each unit lists its rules by id and pins where each survives | S each |
| b-2 | A third matrix state "pointer" in `PROTOCOL_SECTIONS_BY_PERSONA` (inline a one-line stub, read the section on demand) | larger: protocol block 20-24k toward ~6k | medium: changes `inlineProtocolBlock`, the matrix assertions and the cross-reference check in `bin/cli.js` | M-L |
| b-3 | One big rewrite of the orchestrator to ~25k | largest | high: a single change set too large to review against a rule map | L |

b-1 is chosen for the quick-win stage. b-2 is the structural follow-up that the reviewer's 44k -> ~20k target
needs; this stage leaves its interface open by moving text only into sections that are already dropped from
every inlined block. The four-copy hand-sync: the template and `.claude/` copies change together through
`node bin/cli.js --update`; the codex and cursor ports already carry condensed versions of every paragraph
these units shorten (checked by grep for each phrase), so they need no edit, and each contract says so and
pins it.

### c1: reviewer packet with scripted callers (Step 5, qw-u5, pending ruling)

| Option | Mechanism | Saving | Independence |
|---|---|---|---|
| c1-A | Keep "always via the explorer" | 0 | unchanged |
| **c1-B (recommended)** | The reviewer itself runs `.claude/bin/blast-radius.sh <baseline>` (graph CLI when the repo has `.code-review-graph/`, else `git grep` on file stems) and spawns the explorer only when the script prints `provenance=none`, is missing, or leaves a deciding question open | about 8 nested spawns x 10-25 s per pilot, about -200 s, -0.5M tokens | kept: the reviewer still derives blast radius itself, from a deterministic script it runs, not from the writer's or orchestrator's claim |
| c1-C | The orchestrator puts the script output in the reviewer dispatch; the reviewer trusts it and spawns the explorer only when it is empty | slightly more (one reviewer Bash call) | weakened: the reviewer consumes a third party's structural claim, contrary to the protocol rule |

The protocol rule is not changed silently: OQ1 holds the ruling and qw-u5's contract is written for c1-B and
marked pending.

### e3: cache hygiene (dropped, no unit)

What the plugin controls: agent frontmatter `experimental.cacheTtl: 5m|1h` (subagents only, CLI >= 2.1.248;
reviewer and task-master carry `1h`), and settings keys `promptCacheTtl` (main session) and
`subagentPromptCacheTtl` (subagents) that the settings fragment could set. What it does not control: where
Claude Code places cache breakpoints and what it injects into a subagent's first message.

Stream measurement (first call of each subagent, pilot 4): every repeat dispatch of the same persona reads a
fixed prefix from cache (opus reviewer 22,990 tokens; sonnet lead-programmer 20,016; haiku scribe 16,768;
haiku explorer 7,868) and re-creates 8.7k to 12.2k tokens, even at 100-150 s cadence. So the persona body is
already reused across dispatches, and the re-created part is first-message context after the last breakpoint,
which the dispatch text cannot move. Conclusions:
- "Stable prefix order" (persona body before dispatch text) is already true: the body is the system prompt
  and the dispatch is the first user message. Reordering inside a dispatch changes nothing measurable.
- 1h on every persona would raise cost: a 1h write costs 2x base input against 1.25x for 5m, and the
  re-created 9-12k per dispatch is never reused; at pilot cadence 5m already keeps the prefix warm.
- Per-segment re-creation in the main session is CLI behaviour.
The one plugin-side lever is the size of what Claude Code injects (skill and agent descriptions); it is
recorded for the structural stage's b-2 work, not measured here. OQ4 asks whether to leave the two 1h
personas as they are.

A prior FAIL is relevant: `cache-ttl-gapped-personas` FAILed (2026-09-24) because `cacheTtl` was placed at the
frontmatter top level, where Claude Code silently ignores it. Any later TTL unit must nest it under
`experimental:` and prove it from a stream (`ephemeral_1h_input_tokens > 0`), as the reviewer rows above do.

### Prior defect history (FAIL-record screen) and note sweep

Screened all `.claude/reviewed/*.fail` records naming `orchestrator.md`, `persona-protocol`, `reviewer.md` or
`BIN_HELPER` (58 records). The ones that shape these steps:
- `aof-u1` (2026-10-20, sonnet): moving a pinned phrase broke `tests/writer-tier-consistency.test.js`.
  Every b unit therefore lists the tests that pin the text it moves (searched by a 45-char sliding window
  over `tests/`) and edits those tests in the same commit.
- `gh348-14`, `gh348-4`: trimming orchestrator sections left other live docs (README, ADR) asserting the old
  text. Each b unit greps README.md, CONTEXT.md and docs/adr for the moved phrases.
- `item10-1-name-the-two-axes`: the two-axes paragraph Step 3 shortens was itself added by a unit; its terms
  (**unit-exclusivity axis**, **advisory-reviewer axis**) are glossary terms in CONTEXT.md and are kept in
  the shortened text.
- `cache-ttl-gapped-personas`: see e3.
- `docs/audits/unit-outcomes/2026-10-06.jsonl` lists `vacuous` units on `agents/orchestrator.md` (gh307,
  gh310, gh348-14) and on `tests/validate.sh` registration (mw-step1, mw-step2, gh317, gh320). Every criterion
  below names a mutation, and every new test is registered so that its failure fails validate.sh.
- `bash bin/marker-audit.sh . --notes --surface=<path>` over agents/orchestrator.md,
  templates/persona-protocol.md, bin/cli.js, agents/reviewer.md: no `NOTE[spec]` lines; the untagged notes are
  historical. Two bear on this plan: unit 163 (`appendUnique` matches `.gitignore` entries by substring), which
  is harmless for the new `.claude/bookkeeping/` line, and unit 236 ("explanation dropped that is not a
  rule"), the precedent for moving narrative to docs. The sweep is best-effort, not proof that nothing else
  exists.
- 2026-10-20: aof-u2's own AC2.2 and AC2.3 were found weak (a behaviour test cited as a mirror check; a
  negative grep matching the new text). They were amended in e24b17b1. The quick-win contracts avoid both
  patterns: mirror equality is checked with `cmp`, and every prose grep flattens whitespace and is proven to
  fail on the pre-unit file.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-20 Functional scope & success criteria: Q Must c2 be a SubagentStop hook, or is an equivalent mechanical step acceptable? → A (self-resolved): an equivalent step (c2-B). The brief allows it, and SubagentStop output cannot reach the orchestrator, so a hook saves no extra call and would touch gate files.
- 2026-10-20 Functional scope & success criteria: Q Which parts of e3 are both controllable and beneficial? → A (self-resolved): none in this stage (Context, e3). The TTL question for the two 1h personas goes to OQ4.
- 2026-10-20 Non-functional attributes (perf, security, scale): Q May c1 relax "the reviewer always re-derives blast radius"? → A: pending, OQ1 (operator ruling). The contract is written for c1-B, under which the reviewer still re-derives blast radius itself.
- 2026-10-20 Non-functional attributes (perf, security, scale): Q May e1 or e2 change tier rules in this plan? → A: pending, OQ2 and OQ3. No unit until ruled.
- 2026-10-20 External dependencies & integrations: Q Does the c1 script depend on the code-review-graph MCP? → A (self-resolved): no. It uses the `code-review-graph impact` CLI when `.code-review-graph/` exists, else `git grep`, and prints which one it used.
- 2026-10-20 Edge cases / failure handling: Q What happens when a helper is missing or prints something unexpected? → A (self-resolved): the tier falls to `opus` (both scripts choose tiers), a `helper missing` RULING is appended, and the wrapper exits 0. If the wrapper itself is missing, the orchestrator runs the two tier scripts directly, as today.
- 2026-10-20 Edge cases / failure handling: Q What if the on-demand escalation file cannot be read when an ESCALATE-TO-HUMAN verdict arrives? → A (self-resolved): the orchestrator stub keeps the five invariants inline (verbatim card, never run run.sh or view.sh, one AskUserQuestion with the answer relayed verbatim, DECISION only through the prompt-confirmed write, reviewer re-dispatched with `subagent_type: reviewer` and no relayed decision).
- 2026-10-20 Technical constraints & tradeoffs: Q How are four-copy hand-sync and version-stamp discipline kept? → A (self-resolved): template and `.claude/` change together via `node bin/cli.js --update`; codex and cursor ports already carry condensed text and are pinned unchanged; every unit bumps the patch version and adds a CHANGELOG line in the same commit (constitution P3), checked by `version-stamp-check.sh` over the unit's own commits.
- 2026-10-20 Terminology consistency: Q The brief's "per-unit review-packet file" collides with the glossary's **review-packet** (contract key) and **advisory review packet** (lead-programmer report). What is the c2 file called? → A (self-resolved): **reviewer dispatch header** (`.claude/bookkeeping/<unit>.header`). Proposed glossary entry in the Scribe update hint.
- 2026-10-20 Completion / acceptance signals: Q What shows the quick wins worked in the next pilot? → A (self-resolved): orchestrator calls per unit (stream count) fall by at least 1 on E5; the orchestrator's first-call cache creation falls by at least 3k tokens; nested explorer spawns under the reviewer fall to 0-2 of 10 if OQ1 = c1-B; defect and security checks unchanged.

## Risks / dependencies

- R1: every unit edits `agents/orchestrator.md`, `templates/persona-protocol.md` or `agents/reviewer.md`, and
  each bumps the version, so all units run strictly after aof-u4 and one at a time, in the order below.
- R2 (qw-u1): `.claude/bin/unit-bookkeeping.sh` is new trusted executable state, hash-tracked by `--update`
  like aof-u1's helpers and, like them, not in harness-integrity Set A. A tampered copy could only change a
  tier toward `opus` or the header text; the reviewer gate is unaffected.
- R3 (qw-u1): the orchestrator runs the wrapper with Bash, the same permission path as aof-u1's ladder-tier
  call; no new allow rule is needed.
- R4 (qw-u4): moving the escalation procedure behind a Read is a behaviour change on a rare, human-facing
  path. Mitigations: the stub's inline invariants, the reviewer's identical precedent, and the moved text kept
  verbatim (zero rule loss by construction). Re-pilot cannot exercise it (no escalation in pilot 4).
- R5 (qw-u5): blocked on OQ1. If OQ1 = c1-A, qw-u5 is withdrawn and the plan has 4 units.
- R6: the byte targets are relative to each unit's own parent commit, never absolute (absolute pins expire
  when an earlier unit lands).
- R7: aof-u3 adds a paragraph after "... before routing it." and aof-u4 rewrites "Scribe dispatch convention"
  and one sentence in the review-gating-off paragraph. No quick-win edit overlaps those spans; each contract
  anchors on text, not line numbers, and stops if an anchor is missing.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every number in Context was re-measured; each criterion below was run
  against the current tree (it fails before the unit where it should).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. c2 moves bookkeeping into a script;
  c1-B replaces a model hop with a script; mirrors change only through `node bin/cli.js --update`.
- P3 "Version-stamp discipline": satisfied. Each unit bumps `.claude-plugin/plugin.json` and `package.json`
  and adds a CHANGELOG line in the same commit; criterion: `version-stamp-check.sh` over the unit's commits.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. New prose keeps "(if present)" wherever it
  names reviewer, scribe or spec-master.
- P5 "`tests/validate.sh` is the merge gate": satisfied. Every unit ends with `bash tests/validate.sh` exit 0
  and registers its new test there.

## Steps

### Step 1 (qw-u1): bookkeeping wrapper (c2-B)
Contract: `docs/plans/antislop-quick-wins/contracts/qw-u1.md`.
Affected files: `bin/unit-bookkeeping.sh` (new), `bin/cli.js` (`BIN_HELPER_FILES`,
`OPERATIONAL_GITIGNORE_PATTERNS`), `agents/orchestrator.md` ("Per-unit model routing", "Contract-score guard",
"Reviewer gate model selection", "Rulings ledger"), `tests/unit-bookkeeping.test.sh` (new),
`tests/bin-helpers-scaffold.test.sh`, `tests/validate.sh`, `.gitignore`, generated `.claude/` copies,
`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`.
Acceptance criteria (full set in the contract): AC1.1 `bash tests/unit-bookkeeping.test.sh` exit 0; AC1.2
scaffold test finds six helpers; AC1.3 the source and installed wrapper are byte-identical (`cmp`); AC1.4 the
orchestrator source and mirror name both subcommands and keep the downgrade-only sentence; AC1.5 no file under
`hooks/` changed in the unit's commits; AC1.6 version-stamp-check ok; AC1.7 validate.sh exit 0.

### Step 2 (qw-u2): orchestrator narrative trim (b-1 i)
Contract: `docs/plans/antislop-quick-wins/contracts/qw-u2.md`.
Affected files: `agents/orchestrator.md` (4 paragraphs shortened, 2 deleted, 1 subsection moved),
`commands/start-feature-team.md` (receives the roster-row subsection), `docs/orchestrator-rationale.md`
(new, receives the narratives), `tests/prompt-diet-pins.test.sh` (new), `tests/validate.sh`, generated
mirror, bump files.
Rule map (rule id -> where it survives): O1 unnamed reviewer dispatch / exact name `reviewer` -> orchestrator
(kept); O2 roster check before resuming a reviewer by name -> orchestrator (kept); O3 SendMessage cannot
re-task for another unit -> orchestrator (kept); O4 a missing roster row is not proof of death; SendMessage
first; file a bug only on contradiction -> `commands/start-feature-team.md`; O5 a persona that spawns a
subagent collects its result explicitly -> orchestrator (kept, one sentence); O6 named dispatch under the
agent-teams flag launches a teammate; shipped default `"0"` -> orchestrator (kept, one sentence). Narratives
N1 to N5 (gh-304 incident, name-collision residual, docs quotes, observed-incident story, mechanism
explanation) -> `docs/orchestrator-rationale.md`.
Acceptance criteria: the pins test (survivors present, narratives absent, flattened greps) exit 0; the
orchestrator mirror is at least 3,500 bytes smaller than at the unit's parent; codex and cursor orchestrator
ports unchanged; version-stamp-check ok; validate.sh exit 0.

### Step 3 (qw-u3): protocol narrative trim (b-1 ii)
Contract: `docs/plans/antislop-quick-wins/contracts/qw-u3.md`.
Affected files: `templates/persona-protocol.md` ("Review markers and gate mechanics (owner-facing)":
paragraphs 1 and 2 and one back-reference; "Terminal status line": three paragraphs), generated
`.claude/persona-protocol.md` and the six full-tier mirrors, `tests/prompt-diet-pins.test.sh` (extended),
bump files.
Rule map: P1 one unit mid-review, `.blocked` keeps the flag -> kept; P2 marker check scoped to the stopping
reviewer's stamped units, ADR-0028 -> kept (one sentence); P3 the two axes named with their glossary terms,
ADR-0016 -> kept (one sentence); P4 status-line format, regex, when it applies -> kept; P5 why it exists, no
hook replacement -> kept (one sentence); P6 co-occurs with the WIP sentinel, same reason -> kept (one
sentence); P7 confirmation resume stays cheap -> kept. Narrative removed: the "Moved here" provenance note,
the ADR-0028 test-hygiene cause, the "trigger condition, not an exemption" aside, the closing "defeats the
whole point" sentence.
Acceptance criteria: pins test exit 0; each of the five mirrors that inline "Review markers" is at least
1,200 bytes smaller, lead-programmer at least 500; codex and cursor protocol ports unchanged;
`node tests/adapter-protocol-parity.test.js` and `node tests/protocol-doc-drift.test.js` exit 0;
version-stamp-check ok; validate.sh exit 0.

### Step 4 (qw-u4): escalation procedure loaded on demand (b-1 iii)
Contract: written at the next checkpoint (`contracts/qw-u4.md`).
Affected files: `agents/orchestrator.md` (the block from "**On an `ESCALATE-TO-HUMAN` verdict**" up to the
line before "If no `reviewer` persona exists in this project", 130 lines, replaced by a stub of at most 12
lines), `templates/persona-protocol.md` (new `### Orchestrator steps on an ESCALATE-TO-HUMAN verdict` at the
end of "Fourth verdict", holding the moved block verbatim), `tests/adapter-protocol-parity.test.js` (the
fold-line and `decide:` pins move to the template and `.claude/persona-protocol.md`),
`tests/prompt-diet-pins.test.sh`, generated copies, bump files.
Rule map: steps 1 to 7 and the untyped-agent rule -> template subsection, verbatim; the five invariants ->
also in the stub.
Acceptance criteria: parity test exit 0; pins test (stub names the subsection; each of steps 1 to 7 has a
survivor phrase in both protocol copies; `Make **one** \`AskUserQuestion\` call` absent from the orchestrator
mirror); orchestrator mirror at least 7,000 bytes smaller than at the parent; version-stamp-check ok;
validate.sh exit 0.

### Step 5 (qw-u5, pending ruling OQ1 = c1-B): reviewer blast-radius script
Contract: written at the next checkpoint, marked pending.
Affected files: `bin/blast-radius.sh` (new), `bin/cli.js` (`BIN_HELPER_FILES`), `agents/reviewer.md` ("Scope
the review via the explorer" bullet; "still derive blast radius via the explorer"),
`templates/persona-protocol.md` ("Reuse over re-derivation": one clause naming the script),
`tests/blast-radius.test.sh` (new), `tests/validate.sh`, generated copies, bump files. Codex and cursor
reviewer ports keep the explorer (they ship no `.claude/bin`), pinned as unchanged.
Output contract of the script: line 1 `blast-radius: provenance=<graph|grep|none> files=<n>`, then
`changed: <path>`, `caller: <path> -> <changed path>`, `test: <path> -> <changed path>`; exit 0; exit 2 on a
bad baseline; `provenance=none` exactly when the range has no changed file.
Acceptance criteria: the script test (temp repo: a caller, a test, a self-reference excluded, an empty range,
a bad baseline) exit 0; reviewer source and mirror name the script and the `provenance=none` trigger;
version-stamp-check ok; validate.sh exit 0.

## Dispatch order

One unit at a time; each starts only after the previous unit's reviewer PASS.

1. aof-u2 (implemented, 0.31.184; criteria amended e24b17b1) -> review
2. aof-u3 (depends on aof-u2: shared `agents/orchestrator.md` and bump files)
3. aof-u4 (depends on aof-u3: unit scope)
4. qw-u1 (depends on aof-u4: shared orchestrator.md, bump files; uses aof-u1's `BIN_HELPER_FILES`)
5. qw-u2 (depends on qw-u1: shared orchestrator.md)
6. qw-u3 (depends on qw-u2: shared bump files; template)
7. qw-u4 (depends on qw-u3: shared template and orchestrator.md)
8. qw-u5 (depends on qw-u4 and on OQ1 = c1-B; withdrawn if OQ1 = c1-A)

Expected versions if no fix round bumps in between: aof-u4 0.31.186, qw-u1 0.31.187, ..., qw-u5 0.31.191.
Each contract bumps from whatever the version is at its start.

## Open Questions

1. **c1: may the reviewer stop spawning the explorer by default?** (from CHK7)
   - (a) **c1-B, recommended**: the reviewer runs `.claude/bin/blast-radius.sh` itself and spawns the explorer
     only on `provenance=none`, a missing script, or an open deciding question. It still re-derives blast radius
     itself. About -200 s and -0.5M tokens per pilot.
   - (b) c1-A: keep always-explorer; qw-u5 is withdrawn.
   - (c) c1-C: the orchestrator's dispatch carries the script output and the reviewer trusts it. This weakens
     the protocol rule; not recommended.
2. **e1: stop counting test-file lines in `reviewer-tier.sh`?** (from CHK8)
   - (a) **No change, recommended until a riskier-task eval exists**: pilot 4 had zero defect catches on
     either tier, so it is not evidence for relaxing. E4 (the security eval) would move to sonnet, because
     consumer `src/` paths are not on the sensitive list.
   - (b) Exclude test-file lines from the 40-line cap; sensitive paths, the FAIL ratchet and downgrade-only
     unchanged. About -$1 and -60 s per pilot. A contract would follow at the next checkpoint.
   - (c) Count test-file lines at half weight; same guards.
3. **e2: run the main orchestrator session on sonnet?** (from CHK9)
   - (a) No product change. The orchestrator is `model: inherit`, so the session model is the user's choice.
   - (b) **Recommended: eval-only.** Add a declared model-policy label to the A/B harness (orchestrator on
     sonnet, every other persona as under `uniform`), so aof-u6's `uniform` rows stay pure, and measure cost,
     wall time and routing errors first. The work belongs to the antislop-vs-fable-evals plan, not this one.
   - (c) Ship `"model": "sonnet"` in the settings fragment. This overrides every user's session model; not
     recommended.
4. **e3: the 1h TTL on reviewer and task-master?** (from CHK10)
   - (a) **Leave as is, recommended**: they were set for human-review gaps longer than 5 minutes, and the cost
     difference at pilot cadence is about 9k token-equivalents per review.
   - (b) Extend 1h to every persona: raises cost (Context, e3).
   - (c) Remove 1h from both: saves a little at pilot cadence and loses the gap case.

## Self-check
- CHK1: Is every Goal clause (G1 to G5) mapped to a step criterion or an Open Question? — PASS (G1 Step 1;
  G2 Steps 2 to 4; G3 Step 5 and OQ1; G4 Context e3 and OQ4; G5 OQ2 and OQ3)
- CHK2: Do Step 1 and Risk R2 agree that no gate, hook or marker changes? — PASS (AC1.5 checks `hooks/` is
  untouched)
- CHK3: Is the downgrade-only rule defined for the wrapper's unexpected-output case? — PASS (anything other
  than `sonnet` or `opus` becomes `opus`; test case g)
- CHK4: Does each b step list its rules by id with a surviving location and a pin? — PASS (Steps 2 to 4 rule
  maps; the pins test asserts each survivor)
- CHK5: Are byte targets relative to the unit's own parent rather than absolute? — PASS (R6; each criterion
  reads the parent with `git show <first-unit-commit>^:<path>`)
- CHK6: Do the steps agree on the four-copy hand-sync for codex and cursor? — PASS (Steps 2 to 5 each pin the
  ports unchanged, with a reason)
- CHK7: Is the c1 protocol conflict decided anywhere in the plan? — FAIL (missing): operator decision —
  converted to Open Question 1
- CHK8: Is e1's tier relaxation decided? — FAIL (missing): operator decision — converted to Open Question 2
- CHK9: Is e2's orchestrator model decided? — FAIL (missing): operator decision — converted to Open Question 3
- CHK10: Is the TTL of the two 1h personas decided? — FAIL (missing) — converted to Open Question 4
- CHK11: Does criterion AC1.7 (validate.sh) still fail under its own `mutation:` line, given mw-step1's
  recorded class vacuous (tests/validate.sh registration)? — PASS (the mutation is `exit 1` as line 2 of the
  new test; the registration block is a standalone `if` section)
- CHK12: Does each prose criterion fail on the pre-unit file, given gh348-14's and aof-u2's weak criteria? —
  PASS (each contract's criteria were run on the current tree; the survivor greps that must be new are absent
  today, and the absence greps match today)
- CHK13: Does the plan say where the c2 file lives and what it is called, without colliding with glossary
  terms? — PASS (`.claude/bookkeeping/<unit>.header`, **reviewer dispatch header**)

Terminology check (prose mode, advisory): lens 1, "review packet" in the brief has a different meaning from
the glossary's **review-packet**, so it is renamed (Clarifications 8). Lens 2: "blast radius" and "rulings
ledger" are used in their glossary sense; no new synonyms. Lens 3: new load-bearing terms **reviewer
dispatch header**, **bookkeeping wrapper** and **provenance** (blast-radius output) are proposed below.

## Scribe update hint
- Propose harness-glossary entries (docs/harness-glossary.md, not CONTEXT.md): **reviewer dispatch header**
  (the `.claude/bookkeeping/<unit>.header` file and the lines it opens a reviewer dispatch with);
  **bookkeeping wrapper** (`unit-bookkeeping.sh`, which runs the tier helpers and writes the mechanical RULING
  lines); **blast-radius provenance** (`graph|grep|none`, if OQ1 = c1-B).
- After qw-u4: note in the glossary's **prompt-confirmed decision write** entry that the orchestrator's
  procedure now lives in the protocol's Fourth verdict section.
- Carried from the aof spec: CONTEXT.md:1220 cites a stale `stop-gate.sh:188-198` line (not taken up).

## Dispatch section (fast path)
- qw-u1: [contracts/qw-u1.md](contracts/qw-u1.md)
- qw-u2: [contracts/qw-u2.md](contracts/qw-u2.md)
- qw-u3: [contracts/qw-u3.md](contracts/qw-u3.md)
- qw-u4: pending, next checkpoint
- qw-u5: pending ruling (OQ1), next checkpoint
