# AntiSlop quick wins after pilot 4 (spec)

Date: 2026-10-20. Author: spec-master. Status: finalized; operator rulings on OQ1 to OQ4 recorded 2026-10-20
(Clarifications). Source: `docs/plans/antislop-speed-architecture/findings.md` ("Solution variations",
"Recommendation" stage 2). 6 units (qw-u1 to qw-u6), all contracted. Contracts:
`docs/plans/antislop-quick-wins/contracts/qw-uN.md`. With aof-u3b (a fix-forward on aof-u3, added 2026-10-20) and aof-u4 still
ahead of them, 8 dispatchable units remain; see "Dispatch section" for why the fast path is kept.

## Goal

Cut the orchestrator's per-unit model calls and the per-call prompt size without changing any gate, the
Writer/Reviewer split, the downgrade-only reviewer-tier rule or the sensitive-path rule:

- G1 (c2): the per-unit bookkeeping (ladder tier, reviewer tier, RULING lines, reviewer dispatch header) is one
  script call per phase instead of two to four orchestrator calls. Step 1.
- G2 (b): the orchestrator prompt and the inlined protocol block lose duplicates, incident narratives and a
  rarely used procedure that is moved to an on-demand file, with every live rule mapped to where it survives.
  Steps 2, 3 and 4.
- G3 (c1, operator ruling "script first"): the reviewer re-derives blast radius with a script it runs
  itself and spawns the explorer only when the script has no answer. Step 5.
- G4 (e3): dropped, with evidence (Context, "e3"); operator ruling "leave as is". No unit.
- G5 (e1): operator ruling "no change to reviewer-tier.sh". No unit.
- G6 (e2, operator ruling "set sonnet in the product"): the main session, which runs as the orchestrator,
  uses sonnet by default, with a per-project opt-out that keeps the user's own session model. Step 6.

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
  `decide:` rules of the escalation steps in `agents/orchestrator.md`, and `tests/packet-view-script.test.sh`
  T10 counts `without the Read tool's line-number prefixes` (44 characters) twice in it. The earlier claim
  that the parity test was the only pin came from a 45-character window, which cannot see a 44-character
  literal; corrected 2026-10-20 and carried into qw-u4. `tests/persona-prose-pins.test.sh` and
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

### c1: reviewer packet with scripted callers (Step 5, qw-u5; ruled 2026-10-20: c1-B)

| Option | Mechanism | Saving | Independence |
|---|---|---|---|
| c1-A | Keep "always via the explorer" | 0 | unchanged |
| **c1-B (ruled)** | The reviewer itself runs `.claude/bin/blast-radius.sh <baseline>` (`git grep` on each changed file's basename and stem) and spawns the explorer only when the script prints `provenance=none`, is missing, or leaves a deciding question open | about 8 nested spawns x 10-25 s per pilot, about -200 s, -0.5M tokens | kept: the reviewer still derives blast radius itself, from a deterministic script it runs, not from the writer's or orchestrator's claim |
| c1-C | The orchestrator puts the script output in the reviewer dispatch; the reviewer trusts it and spawns the explorer only when it is empty | slightly more (one reviewer Bash call) | weakened: the reviewer consumes a third party's structural claim, contrary to the protocol rule |

The operator ruled c1-B on 2026-10-20. The protocol's reviewer sentence ("always re-derives blast radius and
re-runs the checks itself regardless of what the packet claims") is kept word for word and extended with the
script-first rule; the exact wording is qw-u5's `amended-rule` line. The graph mode the earlier draft named
is dropped: measured on this repo, `code-review-graph impact --depth 1` found 0 cross-file edges for a shell
script, and the default depth returned 1422 impacted nodes for two files, mostly unrelated. Line 1 of the
script is `blast-radius: provenance=<grep|none> files=<n>`; `none` means an empty range or a failed search.
The script and the prose ship as one unit: either half alone changes nothing or sends every review to the
fallback.

### e2: orchestrator on sonnet (Step 6, qw-u6; ruled 2026-10-20: "set sonnet in the product")

What sets the orchestrator's model today: `agents/orchestrator.md` frontmatter `model: inherit`, and
`templates/settings-fragment.json` `"agent": "orchestrator"`, which makes the main session run as that agent.
Nothing else (no settings `model` key, no cli.js rendering). Claude Code documents that an `agent`-driven main
thread takes the agent's model; it does not document where that frontmatter ranks against `/model` or
`--model` (claude-code-guide, 2026-10-20).

| Alt | Mechanism | Scope | Opt-out | Verdict |
|---|---|---|---|---|
| e2-A | frontmatter `model: sonnet` only | the main thread only, when it runs as the orchestrator | hand-edit the managed mirror; `--update` then reports it diverged | too weak an opt-out |
| e2-B | `"model": "sonnet"` in the settings fragment | the session model from project settings | delete the key | rejected: ranks below `/model`, `--model` and `ANTHROPIC_MODEL`, still applies when a user drops `"agent"`, leaves the frontmatter saying `inherit` |
| **e2-C (chosen)** | e2-A plus a persona-config key `orchestratorModel` (`sonnet`, `opus`, `haiku`, `inherit`; default `sonnet`) that `bin/cli.js` renders into the installed orchestrator's frontmatter | same as e2-A | `"orchestratorModel": "inherit"`, then `--update --force-render` | narrowest with a documented, update-safe opt-out |

Guardrails: the renderer touches only the `orchestrator` persona, only an existing frontmatter `model:` line,
and only for a recognised value; subagent frontmatter is unchanged (qw-u6 criterion 3); no settings key is
added (criterion 5).

Eval interaction: aof-u6 (OD-23) strips every frontmatter `model:` line from Arm B's plugin copy under
`uniform`, before the scaffold, and the scaffold runs before any persona-config exists, so the renderer sees a
stripped source and adds nothing: the `uniform` arm stays uniform, and `tests/abtest-arms.test.sh` (108 checks,
run on a clone with qw-u6 applied) proves it. No eval amendment and no OD number are needed, so there is no
qw-u7. Under `shipped`, the worktree orchestrator reads `model: sonnet` while the harness passes
`--model "$ABTEST_MODEL"`; which wins is undocumented, so the next shipped-policy run should read the
orchestrator's model from the result's `modelUsage` before its cost is compared (R9).

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
recorded for the structural stage's b-2 work, not measured here. OQ4 asked whether to leave the two 1h
personas as they are; the operator ruled "leave as is" (2026-10-20).

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
- 2026-10-20 Non-functional attributes (perf, security, scale): Q May c1 relax "the reviewer always re-derives blast radius"? → A: pending, OQ1 (operator ruling). The contract is written for c1-B, under which the reviewer still re-derives blast radius itself. (Ruled below, 2026-10-20: c1-B.)
- 2026-10-20 Non-functional attributes (perf, security, scale): Q May e1 or e2 change tier rules in this plan? → A: pending, OQ2 and OQ3. No unit until ruled. (Ruled below, 2026-10-20: e1 no change; e2 sonnet in the product, qw-u6.)
- 2026-10-20 External dependencies & integrations: Q Does the c1 script depend on the code-review-graph MCP? → A (self-resolved): no. It uses the `code-review-graph impact` CLI when `.code-review-graph/` exists, else `git grep`, and prints which one it used.
- 2026-10-20 Edge cases / failure handling: Q What happens when a helper is missing or prints something unexpected? → A (self-resolved): the tier falls to `opus` (both scripts choose tiers), a `helper missing` RULING is appended, and the wrapper exits 0. If the wrapper itself is missing, the orchestrator runs the two tier scripts directly, as today.
- 2026-10-20 Edge cases / failure handling: Q What if the on-demand escalation file cannot be read when an ESCALATE-TO-HUMAN verdict arrives? → A (self-resolved): the orchestrator stub keeps the five invariants inline (verbatim card, never run run.sh or view.sh, one AskUserQuestion with the answer relayed verbatim, DECISION only through the prompt-confirmed write, reviewer re-dispatched with `subagent_type: reviewer` and no relayed decision).
- 2026-10-20 Technical constraints & tradeoffs: Q How are four-copy hand-sync and version-stamp discipline kept? → A (self-resolved): template and `.claude/` change together via `node bin/cli.js --update`; codex and cursor ports already carry condensed text and are pinned unchanged; every unit bumps the patch version and adds a CHANGELOG line in the same commit (constitution P3), checked by `version-stamp-check.sh` over the unit's own commits.
- 2026-10-20 Terminology consistency: Q The brief's "per-unit review-packet file" collides with the glossary's **review-packet** (contract key) and **advisory review packet** (lead-programmer report). What is the c2 file called? → A (self-resolved): **reviewer dispatch header** (`.claude/bookkeeping/<unit>.header`). Proposed glossary entry in the Scribe update hint.
- 2026-10-20 Completion / acceptance signals: Q What shows the quick wins worked in the next pilot? → A (self-resolved): orchestrator calls per unit (stream count) fall by at least 1 on E5; the orchestrator's first-call cache creation falls by at least 3k tokens; nested explorer spawns under the reviewer fall to 0-2 of 10 (OQ1 = c1-B, ruled); defect and security checks unchanged.
- 2026-10-20 Non-functional attributes (perf, security, scale): Q (OQ1) May the reviewer stop spawning the explorer by default? → A: (a) script first, per operator. The reviewer runs `.claude/bin/blast-radius.sh` itself and spawns the explorer only on `provenance=none`, a missing script, or an open question that decides a finding; the protocol rule is amended accordingly (qw-u5 `amended-rule`), and the independence property stays: the reviewer never takes a blast radius from the orchestrator or the writer.
- 2026-10-20 Non-functional attributes (perf, security, scale): Q (OQ2) Stop counting test-file lines in `reviewer-tier.sh`? → A: no change, per operator. e1 is dropped; no unit.
- 2026-10-20 Technical constraints & tradeoffs: Q (OQ3) Run the main orchestrator session on sonnet? → A: (c) set sonnet in the product, per operator. Implemented as e2-C (Context, e2): frontmatter `model: sonnet` plus the `orchestratorModel` opt-out; qw-u6.
- 2026-10-20 Technical constraints & tradeoffs: Q (OQ4) The 1h TTL on reviewer and task-master? → A: leave as is, per operator. No unit.
- 2026-10-20 External dependencies & integrations: Q Does the blast-radius script use the code-review-graph CLI? → A (self-resolved): no. Measured on this repo, `impact` gives no cross-file edges for shell scripts and hundreds of unrelated nodes at default depth; the script is `git grep` only and the explorer (graph-backed) is the fallback. This supersedes the earlier line that named a graph mode.
- 2026-10-20 Functional scope & success criteria: Q Is the c1 script its own unit or part of qw-u5? → A (self-resolved): part of qw-u5. The prose names the script, so either half alone is inert or sends every review to the fallback.
- 2026-10-20 Edge cases / failure handling: Q Does the sonnet default leak into the A/B `uniform` arm? → A (self-resolved): no. aof-u6's strip removes the orchestrator's `model:` line before the scaffold, and the renderer never adds a line (qw-u6 test (f); abtest-arms 108/108 on a clone). No qw-u7.
- 2026-10-20 Edge cases / failure handling: Q aof-u3 passed review, but its scope rule forbids the version-stamp files the constitution requires and a fix round's FAIL-named files, and leaves the reviewer a judgement clause; what happens to it? → A: fix forward with aof-u3b, per the coordinator (relaying the reviewer finding): standing exceptions in both rules (version-stamp files, paths an acceptance-criteria command names literally, paths a `.fail` defect or fix contract names), the judgement clause replaced by those couplings, and the codex and cursor orchestrator ports given the sending half of the rule because their reviewer ports already enforce it. Contract `docs/plans/antislop-overhead-fixes/contracts/aof-u3b.md`, dispatched first.
- 2026-10-20 Edge cases / failure handling: Q Can a user keep their own session model? → A (self-resolved): yes, `"orchestratorModel": "inherit"` in the project's persona-config, then `node <plugin>/bin/cli.js --update --force-render`; documented in README. `/model` and `--model` are not offered as the opt-out because their rank against agent frontmatter is undocumented.

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
  verbatim (zero rule loss by construction, checked byte for byte by qw-u4 criterion 3). Re-pilot cannot
  exercise it (no escalation in pilot 4). The stub names the packet directory and the DECISION file, so it is
  authored with the Write tool; `human-decision-gate.sh` refuses Bash text that spells both.
- R5 (qw-u5): every full-tier mirror inlines "Structural questions", so each grows about 400 bytes (reviewer
  +936 with its body). This offsets part of qw-u3's saving; the reviewer's explorer spawns it removes are worth
  far more (findings, c1).
- R8 (qw-u6): this plugin's own persona-config has no `orchestratorModel`, so after qw-u6 lands and
  `--update` runs, this repo's main session also runs on sonnet. Opting the repo out is an operator decision
  outside the unit.
- R9 (qw-u6, eval): under the A/B `shipped` policy the harness passes `--model` while the orchestrator
  frontmatter reads `sonnet`, and Claude Code does not document which wins. Read the orchestrator's model from
  the next shipped run's `modelUsage` before comparing its cost. `uniform` is unaffected (Context, e2).
- R11 (aof-u3b): it edits the reviewer's Materiality bullet and lead-programmer's Unit scope bullet, and adds a
  paragraph to the codex and cursor orchestrator ports. No quick-win `before:` payload includes those spans
  (checked by grep over qw-u1 to qw-u6), so it only shifts every expected version by one.
- R6: the byte targets are relative to each unit's own parent commit, never absolute (absolute pins expire
  when an earlier unit lands).
- R7: aof-u3 (landed 1d4abf5a) added a paragraph after "... before routing it." and a bullet to the
  reviewer's Materiality filter; aof-u4 rewrites "Scribe dispatch convention", one sentence in the
  review-gating-off paragraph, `--update` argument handling and the schema (`knowledgeWrites`). No quick-win
  edit overlaps those spans; each contract anchors on text, not line numbers, and stops if an anchor is
  missing.
- R10 (shared regions): qw-u4 and qw-u5 both edit `templates/persona-protocol.md` (Fourth verdict vs
  Structural questions); qw-u1, qw-u5 and qw-u6 all edit `bin/cli.js` and `tests/validate.sh`; qw-u5 extends
  qw-u1's `BIN_HELPER_FILES` line and scaffold test; qw-u6 anchors on qw-u5's validate.sh block. The order
  qw-u4 -> qw-u5 -> qw-u6 is therefore required, and each contract's `before:` payloads assume it.

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
orchestrator mirror is at least 3,400 bytes smaller than at the unit's parent (3,759 measured); codex and cursor orchestrator
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
Contract: `docs/plans/antislop-quick-wins/contracts/qw-u4.md`.
Affected files: `agents/orchestrator.md` (the 129-line block from "**On an `ESCALATE-TO-HUMAN` verdict**" up to
the blank line before "If no `reviewer` persona exists in this project", replaced by a 12-line stub),
`templates/persona-protocol.md` (new `### Orchestrator steps on an ESCALATE-TO-HUMAN verdict` at the end of
"Fourth verdict", holding the moved block byte for byte), `tests/adapter-protocol-parity.test.js` (fold-line
and `decide:` pins move to the template and `.claude/persona-protocol.md`), `tests/packet-view-script.test.sh`
(T10 moves the same way), `tests/prompt-diet-pins.test.sh`, generated copies, bump files.
Rule map: steps 1 to 7 and the untyped-agent rule -> template subsection, verbatim; invariants I1 to I5 (card
verbatim; never run run.sh or view.sh; one AskUserQuestion, answer relayed verbatim; DECISION only through the
prompt-confirmed decision write; fresh reviewer dispatch with `subagent_type: reviewer`, no relayed decision)
-> also in the stub, plus a fallback when the section cannot be read.
Acceptance criteria: pins test exit 0; orchestrator mirror at least 7,000 bytes smaller than at the parent
(7,647 measured); the moved block found exactly once in both protocol copies; no other mirror changes beyond
its stamp; adapters, bin, hooks and reviewer.md untouched; parity, packet-view, doc-drift, cross-reference,
prose-pin and writer-tier suites exit 0; version-stamp-check ok; validate.sh exit 0.

### Step 5 (qw-u5): reviewer blast-radius script (operator ruling c1, "script first")
Contract: `docs/plans/antislop-quick-wins/contracts/qw-u5.md`. The script is part of this unit, not its own
unit (Clarifications).
Affected files: `bin/blast-radius.sh` (new), `bin/cli.js` (`BIN_HELPER_FILES`), `tests/bin-helpers-scaffold.test.sh`
(seven helpers), `agents/reviewer.md` ("Scope the review with the blast-radius script" bullet; the advisory
packet bullet), `templates/persona-protocol.md` ("Structural questions go to the explorer": a pointer in the
first paragraph and the amended reuse rule), `tests/blast-radius.test.sh` (new), `tests/validate.sh`,
generated copies, bump files. Codex and cursor reviewer ports keep the explorer (no `.claude/bin` there).
Output contract of the script: line 1 `blast-radius: provenance=<grep|none> files=<n>`, then one `changed:
<path>` per file, then per changed file at most 40 `test: <path> -> <changed>` and `caller: <path> ->
<changed>` lines (tests first) and `truncated: <changed> shown=40 total=<n>` when cut; exit 0; exit 2 on a bad
or missing baseline; `provenance=none` when the range is empty or a search failed. Read-only.
Amended protocol rule (operator ruling): the reviewer "always re-derives blast radius and re-runs the checks
itself regardless of what the packet claims", and now "re-derives it with a script: it runs
`.claude/bin/blast-radius.sh <baseline>` itself and spawns the `explorer` only when the script prints
`provenance=none`, the script is missing, or a question that decides a finding stays open; it never takes a
blast radius from the dispatch, the orchestrator or the writer."
Acceptance criteria: the script test (29 checks: caller by stem, test class, self excluded, whole-word only,
empty range, bad baseline, no argument, cap and truncation, short stem skipped, deleted file, subdirectory, and
the prose rows) exit 0; `cmp` source and installed script; scaffold test exit 0; the installed script reports
`provenance=grep` on HEAD~1; adapters, hooks, orchestrator and explorer untouched; protocol suites and
cli-backfill exit 0; version-stamp-check ok; validate.sh exit 0.

### Step 6 (qw-u6): orchestrator on sonnet by default (operator ruling e2)
Contract: `docs/plans/antislop-quick-wins/contracts/qw-u6.md`.
Affected files: `agents/orchestrator.md` (frontmatter `model: sonnet`), `bin/cli.js` (`applyOrchestratorModel`,
called from `renderCleanBody` and the scaffold loop, exported), `templates/persona-config.schema.json`
(`orchestratorModel`), `README.md` (persona row, config row), `tests/orchestrator-model.test.js` (new),
`tests/validate.sh`, generated copies, bump files.
Acceptance criteria: the model test (9 checks, including a scaffold plus `inherit` opt-out round trip and the
uniform-strip case) exit 0; `model: sonnet` in the source and mirror frontmatter; no other persona's `model:`
line changed; the schema property's default and enum; settings fragment, eval, adapters and hooks untouched;
abtest-arms, cli-backfill, default-implementer-model, writer-tier and effort-tier suites exit 0;
version-stamp-check ok; validate.sh exit 0.

## Dispatch order

One unit at a time; each starts only after the previous unit's reviewer PASS.

Already landed: aof-u2 (0.31.184), aof-u3 (1d4abf5a, 0.31.185).

0. aof-u3b (fix-forward on aof-u3; contract `docs/plans/antislop-overhead-fixes/contracts/aof-u3b.md`)
1. aof-u4 (depends on aof-u3b: unit-scope wording and bump files)
2. qw-u1 (depends on aof-u4: shared orchestrator.md, bump files; uses aof-u1's `BIN_HELPER_FILES`)
3. qw-u2 (depends on qw-u1: shared orchestrator.md)
4. qw-u3 (depends on qw-u2: shared bump files; template; extends qw-u2's pins test)
5. qw-u4 (depends on qw-u3: shared template and orchestrator.md; extends the pins test)
6. qw-u5 (depends on qw-u4: shared template; extends qw-u1's `BIN_HELPER_FILES`, scaffold test and validate.sh block)
7. qw-u6 (depends on qw-u5: shared `bin/cli.js` and validate.sh anchor; needs aof-u4's schema property in place)

Expected versions if no fix round bumps in between: aof-u3b 0.31.186, aof-u4 0.31.187, qw-u1 0.31.188, qw-u2
0.31.189, qw-u3 0.31.190, qw-u4 0.31.191, qw-u5 0.31.192, qw-u6 0.31.193. Each contract adds one to whatever the version is at
its start.

## Open Questions

None. OQ1 to OQ4 were ruled by the operator on 2026-10-20 and are recorded in Clarifications.

## Self-check
- CHK1: Is every Goal clause (G1 to G6) mapped to a step criterion or a recorded ruling? — PASS (G1 Step 1;
  G2 Steps 2 to 4; G3 Step 5; G4 Context e3 and the OQ4 ruling; G5 the OQ2 ruling; G6 Step 6)
- CHK2: Do Step 1 and Risk R2 agree that no gate, hook or marker changes? — PASS (AC1.5 checks `hooks/` is
  untouched)
- CHK3: Is the downgrade-only rule defined for the wrapper's unexpected-output case? — PASS (anything other
  than `sonnet` or `opus` becomes `opus`; test case g)
- CHK4: Does each b step list its rules by id with a surviving location and a pin? — PASS (Steps 2 to 4 rule
  maps; the pins test asserts each survivor)
- CHK5: Are byte targets relative to the unit's own parent rather than absolute? — PASS (R6; each criterion
  reads the parent with `git show <first-unit-commit>^:<path>`)
- CHK6: Do the steps agree on the four-copy hand-sync for codex and cursor? — PASS (Steps 2 to 6 each pin the
  ports unchanged, with a reason)
- CHK7: Is the c1 protocol conflict decided, with the amended wording stated? — PASS (operator ruling
  2026-10-20; Step 5 and qw-u5 `amended-rule` give the exact text)
- CHK8: Is e1's tier relaxation decided? — PASS (ruling: no change; no unit)
- CHK9: Is e2's orchestrator model decided, with an opt-out and the eval interaction? — PASS (ruling (c);
  Context e2; qw-u6 test (f) and criterion 6 cover the uniform arm; R9 the shipped arm)
- CHK10: Is the TTL of the two 1h personas decided? — PASS (ruling: leave as is)
- CHK11: Does criterion AC1.7 (validate.sh) still fail under its own `mutation:` line, given mw-step1's
  recorded class vacuous (tests/validate.sh registration)? — PASS (the mutation is `exit 1` as line 2 of the
  new test; the registration block is a standalone `if` section). The same holds for qw-u4 to qw-u6's
  validate.sh criteria.
- CHK12: Does each prose criterion fail on the pre-unit file, given gh348-14's and aof-u2's weak criteria? —
  PASS (each contract's criteria were run on the current tree or a clone; the qw-u4 pin rows fail on the
  pre-move tree, the qw-u5 rows (j) fail on the current reviewer.md)
- CHK13: Does the plan say where the c2 file lives and what it is called, without colliding with glossary
  terms? — PASS (`.claude/bookkeeping/<unit>.header`, **reviewer dispatch header**)
- CHK14: Do Step 4 and qw-u4 agree on every test that pins the moved block? — FAIL (missing): the spec named
  only the parity test; T10 in tests/packet-view-script.test.sh was missed by the 45-character window — revised
  in place (Context, Step 4, qw-u4 edit 7)
- CHK15: Do Steps 5 and 6 and R10 agree on the order of the shared `bin/cli.js` and validate.sh edits? — PASS
  (qw-u5 anchors on qw-u1's block; qw-u6 anchors on qw-u5's)
- CHK16: Is the uniform-arm claim for qw-u6 backed by a runnable check rather than prose? — PASS (qw-u6
  test (f) and criterion 6; abtest-arms run on a clone with qw-u6 applied: 108 passed)
- CHK17: Does each new criterion fail under its own mutation line? — PASS (spec-master ran the mutations for
  qw-u4 criteria 3 and 6, qw-u5 criterion 1 and qw-u6 criterion 1 on clones; the rest follow the qw-u1 to
  qw-u3 patterns already proven)
- CHK18: Do aof-u3b and the quick-win contracts agree on versions and on the reviewer.md and
  lead-programmer.md spans they touch? — PASS (expected versions shifted by one in qw-u1 to qw-u6 and the
  aof-u4 bump edit; no quick-win payload includes the Materiality or Unit scope bullets, R11)

Terminology check (prose mode, advisory): lens 1, "review packet" in the brief has a different meaning from
the glossary's **review-packet**, so it is renamed (Clarifications 8). Lens 2: "blast radius" and "rulings
ledger" are used in their glossary sense; no new synonyms. Lens 3: new load-bearing terms **reviewer
dispatch header**, **bookkeeping wrapper**, **blast-radius provenance** and **orchestratorModel** are proposed
below.

## Scribe update hint
- Propose harness-glossary entries (docs/harness-glossary.md, not CONTEXT.md): **reviewer dispatch header**
  (the `.claude/bookkeeping/<unit>.header` file and the lines it opens a reviewer dispatch with);
  **bookkeeping wrapper** (`unit-bookkeeping.sh`, which runs the tier helpers and writes the mechanical RULING
  lines); **blast-radius provenance** (`grep|none`; `none` sends the reviewer to the explorer).
- After qw-u4: note in the glossary's **prompt-confirmed decision write** entry that the orchestrator's
  procedure now lives in the protocol's Fourth verdict section.
- After qw-u5: the glossary's **F11 convention** entry stays true; add one sentence that the reviewer's
  independent re-derivation now runs `.claude/bin/blast-radius.sh` first.
- After qw-u6: a glossary entry for **orchestratorModel** (the persona-config key rendered into the installed
  orchestrator's frontmatter; `inherit` keeps the user's session model).
- Carried from the aof spec: CONTEXT.md:1220 cites a stale `stop-gate.sh:188-198` line (not taken up).

## Dispatch section (fast path)
- aof-u3b (first): [../antislop-overhead-fixes/contracts/aof-u3b.md](../antislop-overhead-fixes/contracts/aof-u3b.md)
- qw-u1: [contracts/qw-u1.md](contracts/qw-u1.md)
- qw-u2: [contracts/qw-u2.md](contracts/qw-u2.md)
- qw-u3: [contracts/qw-u3.md](contracts/qw-u3.md)
- qw-u4: [contracts/qw-u4.md](contracts/qw-u4.md)
- qw-u5: [contracts/qw-u5.md](contracts/qw-u5.md)
- qw-u6: [contracts/qw-u6.md](contracts/qw-u6.md)
- qw-u7: none (no eval amendment is needed; Context, e2)

Unit count: 6 quick-win units plus aof-u3b and aof-u4 = 8 dispatchable units, above the fast-path limit of 5. Every unit
already has a committed contract of record that scores 7/7 on `contract-score.js --rubric=v2`, so nothing is
left for task-master to slice; the orchestrator can dispatch from the contract files in the order above. If
the operator prefers a task-master pass anyway, it should take these contracts as input, not the spec.
