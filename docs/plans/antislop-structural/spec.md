# AntiSlop structural stage after the quick wins (spec)

Date: 2026-10-20. Author: spec-master. Status: **finalized**. The operator ruled OQ1 to OQ3 on 2026-10-20 (Clarifications):
- no architecture change for now (neither c3 nor g3; decided later on S13);
- no spec-master in the medium lane;
- the scope gate blocks all three writers.

Variations (a) and (f) are specified, and contracts st-u1 to st-u4 are written.
Source: `docs/plans/antislop-speed-architecture/findings.md` ("Solution variations" rows a, f, c3, g3;
"Recommendation" stage 3; "Floor and break-even"). Builds on `docs/plans/antislop-quick-wins/spec.md`
(qw-u1 to qw-u6) and `docs/plans/antislop-overhead-fixes/spec.md` (aof-u1 to aof-u6, re-pilot S1 to S8).

## Goal

After the quick-win chain lands, cut the remaining per-unit cost without weakening the one hard guarantee
(an independent reviewer per unit, with a PASS marker that only the reviewer writes):

- G1 (f, mechanised pre-review). The reviewer's deterministic checks run as one script that the reviewer
  runs itself: the unit-scope diff with aof-u3b's standing exceptions, diff size, sensitive paths, the
  version stamp, and the contract's acceptance criteria. Any failure line is a FAIL ground that needs no
  reading. Steps 1 and 2 (st-u1, st-u2).
- G2 (f, writers the reviewer never sees). A SubagentStop gate blocks lead-programmer, scribe and
  spec-master from ending a turn while they leave a net change outside unit scope. This catches the four
  pilot-4 scope leaks mechanically. Step 3 (st-u3).
- G3 (a, size and risk routed lanes). A script picks a lane from the unit's planned `## Affected files`
  before any work is dispatched. The rule is downgrade-only, reuses reviewer-tier.sh's sensitive-path class,
  and fails closed to the full pipeline. Step 4 (st-u4; medium lane without spec-master per the OQ2 ruling).
- G4 (architecture). Operator ruling OQ1 = neither, 2026-10-20: no c3 or g3 units and no probes now.
  After the re-pilot, the operator decides between c3, g3 and staying put, with S13 (orchestrator calls
  per unit) as the decision metric. The analysis is kept in Context for that decision.
- G5 (measurement). A re-pilot plan after the stage (S9 to S16, extending S1 to S8), plus the measurement
  requirements of the larger-task eval that tests the break-even. This is a design only; this spec runs
  no eval.

## Context

### Verified facts this spec relies on (2026-10-20; repo at eb59e217, qw-u1 landed)

- reviewer-tier.sh owns the sensitive-path class: `hooks/scripts/reviewer-tier.sh:22-37` defines
  `SENSITIVE_PATHS` (11 anchored patterns) and `:41-51` defines `touches_sensitive_path`. It takes a git
  range, so it cannot classify the *planned* paths of a unit that has not been written yet. Its suite
  `tests/reviewer-tier.test.sh` (63 checks) contains mutation control mc13, which seds the `'^agents/'` line
  out of the script itself. That control is the one pin that moves if the class moves (verified by running
  the suite on a clone after the move: mc13 alone fails, with "the sed matched nothing").
- Hook libraries: `bin/cli.js` requires each `hooks/scripts/lib/*.sh` to be classified in
  `SHARED_HOOK_LIB_FILES` (copied to both adapter trees) or `CLAUDE_ONLY_HOOK_LIB_FILES`
  (`assertHookLibDeclarationComplete`, which throws at load). Hook scripts install recursively to
  `.claude/hooks/scripts/` (`buildHookScriptSpecs`). `BIN_HELPER_FILES` installs to `.claude/bin/`, so a
  helper reaches the libraries at `$dir/../hooks/scripts/lib/` in both layouts. This is the same resolution
  qw-u1's `unit-bookkeeping.sh` uses for reviewer-tier.sh.
- `--update` copies new files only when `pluginVersion` changes (the early return in `runUpdate`). Every
  unit here bumps the version, even one that touches no `agents/` or `templates/` file (constitution P3
  needs no bump then, but installed projects would never receive the hook).
- Hook semantics (from the Claude Code docs via the agent named `guide-hook-semantics`, 2026-10-20):
  - SubagentStop input carries `agent_id`, `agent_type`, `agent_transcript_path` and `stop_hook_active`.
    Exit 2, or `decision: "block"` with a `reason`, keeps the subagent running and delivers the reason to it.
    Claude Code overrides a block after 8 consecutive continuations.
  - SubagentStart exists but cannot block and does not carry the dispatch prompt.
  - Subagents may spawn subagents, by default up to three layers below the main conversation
    (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`). Tool hooks in a subagent carry its `agent_type`.
  - Whether SubagentStop fires for a nested agent is undocumented. So is whether a main session started
    through settings `"agent"` (rather than `--agent`) carries `agent_type` in hook input.
- A subagent transcript's first record is the dispatch prompt (`type: user`, string content). Write/Edit
  tool_use records carry an absolute `input.file_path`, and Bash results carry git's `[<branch> <sha>]`
  commit line. All three were checked on transcripts in `~/.claude/projects/-home-sebas-AntiSlop/`.
- Gate identity facts (from the agent named `explorer-gate-identity`, grep-derived, spot-checked by Read):
  - `reviewer-route-gate.sh:62-66` blocks a lead-programmer caller from dispatching the reviewer.
  - `:71-74` blocks any non-empty caller `agent_type` other than `orchestrator`.
  - `reviewer-route-gate-core.sh:94` requires the prompt's first line to be `Unit: <id>`. `:139-152`
    writes the review-join stamp, keyed by unit.
  - `stop-gate-core.sh:640-675` raises the pending-review flag, keyed by `agent_id`, on a gated agent's
    SubagentStop (`gatedAgents`, default lead-programmer), and runs `testAndLintCommand` there.
  - `reviewed-path-gate.sh:247-285` allows marker writes for a reviewer grant and for the main session
    only in the no-reviewer fallback.
- `stop-gate.sh` already runs `testAndLintCommand` (here `bash tests/validate.sh`) at every gated
  SubagentStop whose tree changed. The precheck therefore does not re-run it; it runs the contract's
  criteria and defers the long ones.
- `hooks/scripts/lib/audit-log.sh` (sourced by `agent-identity.sh`) turns on `set -e`. A new hook that
  sources agent-identity.sh and branches on exit codes must switch errexit back off. This was found while
  proving the st-u3 test on a scratch implementation: five cases exited 1 until `set +e` was added.
- `tests/trust-model-bijection.test.js` C8.2 requires every `hooks/scripts/*.sh` to be named in
  `docs/trust-model.md`. `tests/abtest-arms.test.sh` checks `hooks.json` and passes with a second
  SubagentStop entry (run on a committed clone). Both were checked.
- Eval: `eval/abtest/checks/scope.sh` counts `git diff START..HEAD` outside `fixtures/<eid>/allowed-paths.txt`
  (excluding `.claude` and `docs/plans`). Stream assistant records carry `subagent_type` and `agent_id`
  for subagent messages, and neither for the main thread (checked on `e05-tags-feature_B_uniform_1`), so
  per-persona call counts come from unique `message.id` grouped by `subagent_type`. E1 to E4 list 2 to 5
  allowed entries; E5 lists 5 entries, of which 4 are directories (`src`, `scripts`, `test`, `data`).

### Interfaces of the quick wins this spec depends on (verified from the contracts; landed status 2026-10-20)

| Interface | From | Used by | Verified how |
|---|---|---|---|
| `bin/unit-bookkeeping.sh review <unit> <baseline>` writes `.claude/bookkeeping/<unit>.header` (`Unit:`, `Implementer tier:`, `Range:`, `Reviewer model:`, changed files) | qw-u1 (landed eb59e217) | st-u2 (the reviewer gets baseline and contract from the dispatch the header opens), st-u4, c3/g3 templated dispatch | qw-u1 script-spec-9; file present in the tree |
| `.claude/bookkeeping/` is gitignored and is the bookkeeping state directory | qw-u1 edit 6 (corrected to `{{DOTDIR}}` 2026-10-20) | st-u2 packet copy, st-u3 log, st-u4 lane and scope records | qw-u1 criterion 6 |
| `BIN_HELPER_FILES` ends `..., 'unit-bookkeeping.sh', 'blast-radius.sh']`; scaffold test says `(a) seven helpers present` | qw-u1 + qw-u5 (qw-u5 not landed) | st-u2 edits 4 and 5 (chained `before:` payloads) | qw-u5 edits 4 and 5 after-payloads |
| `bin/blast-radius.sh <baseline>` and the reviewer bullet `- **Scope the review with the blast-radius script**: run` | qw-u5 | st-u2 inserts its bullet before that line | qw-u5 edit 6 after-payload |
| Protocol reuse sentence ending `stays open; it never takes a blast radius from the dispatch, the orchestrator` / `or the writer.` | qw-u5 edit 9 | st-u2 extends it | qw-u5 edit 9 after-payload; unique in a clone with qw-u5's prose applied |
| validate.sh block `== orchestrator-model: ... (Node, qw-u6) ==` | qw-u6 edit 11 | st-u1 registers its test after it | qw-u6 edit 11 after-payload |
| `orchestratorModel` (main session on sonnet, opt-out `inherit`) | qw-u6 | OQ1 cost arithmetic; the `uniform` eval strips it (aof-u6) | qw-u6 Objective |
| Standing exceptions to `## Affected files`: version-stamp files, paths a criteria `run:` names literally, paths a `.fail` defect or fix contract names | aof-u3b (landed 4a3e8068) | st-u1 `us_classify`, st-u2, st-u3 | aof-u3b edits 3 and 6 |
| `knowledgeWrites` (`scoped` default, `apply` opt-in); knowledge files are CONTEXT.md, `docs/harness-glossary.md`, README.md, `docs/adr/*` | aof-u4 (landed c09e5851) | st-u3 scribe and spec-master rules | aof-u4 Objective; this repo's config reads `apply` |

The automated anchor check (a script that parses every `line matching`/`line ending` anchor and every
inline or fenced `before:` payload) was run over qw-u1 to qw-u6 and over st-u1 to st-u3. Every anchor
either exists in the current file or is created by an earlier contract's after-payload (chained). The one
real defect was qw-u1 edit 6's `{DOTDIR}` (single braces), which was fixed in 758f5ea9.

### f: mechanised pre-review (Steps 1 to 3)

| Alt | Who runs the checks | Independence | Catches scribe/spec-master leaks | Saving | Verdict |
|---|---|---|---|---|---|
| f-A | lead-programmer's SubagentStop writes a "signed" packet; the reviewer trusts it | weakened: the reviewer reads a third party's claim, the case qw-u5's c1-C was rejected for | no (wrong range) | largest | rejected |
| **f-B (chosen)** | the reviewer runs `review-precheck.sh` itself, as qw-u5's ruling has it run `blast-radius.sh`; failure lines are FAIL grounds without reading; a separate SubagentStop gate covers the writers the reviewer never sees | kept: a deterministic script the reviewer runs; nobody else's output stands in for it | yes (st-u3) | reviewer: about 3 to 5 fewer tool calls per review | chosen |
| f-C | `unit-bookkeeping.sh review` runs the checks inside the orchestrator's call and puts the result in the header | weakened, the same way as f-A, and the orchestrator call gets longer | no | about the same as f-B | rejected |

Why a SubagentStop gate (st-u3) is needed and the precheck alone is not: the precheck sees
`<baseline>..HEAD` of one unit. spec-master writes before any unit's baseline, and scribe writes after the
last PASS. Pilot 4's leaks were made by scribe (E1 README, E2 CONTEXT.md, E3 ADR, E5 CONTEXT.md), by
spec-master (E5) and by lead-programmer (E3 CONTEXT.md, which the reviewer passed).

Attribution choice for st-u3:

| Alt | Mechanism | Concurrency-safe | Verdict |
|---|---|---|---|
| time window | commits since the subagent's first transcript timestamp | no: another session's commits count (as now, with a lead-programmer committing beside this spec) | rejected |
| SubagentStart snapshot | record HEAD at start, diff at stop | no, for the same reason; and one more registration | rejected |
| **own transcript (chosen)** | the paths of its own Write/Edit calls, plus the files of each commit whose `[<branch> <sha>]` line appears in its own Bash results; keep only those whose net content still differs from where it started | yes | chosen; residual: an uncommitted Bash heredoc write is not attributed (R3) |

Classification is shared (st-u1 `hooks/scripts/lib/unit-scope.sh`), so the precheck and the gate cannot
disagree. The classes are `listed`, `criteria`, `fail-record`, `fix-contract`, `plugin-version`, `judge`
and `out`.
- The version-stamp exception is mechanical only in this plugin's own layout (`.claude-plugin/plugin.json`
  tracked at the baseline; the three files P3 and validate.sh require).
- In any other project, a common version-file name (`package.json`, `CHANGELOG.md`, `VERSION` and so on)
  is class `judge`, which the reviewer decides. That is the only judgment left, and it is named explicitly
  (Clarifications).

### a: size and risk routed lanes (Step 4; operator ruling OQ2 = ii)

The input is the unit's planned scope: the contract's `## Affected files`, or, with no contract, the paths
the orchestrator writes for the dispatch (aof-u3's rule), passed as arguments. reviewer-tier.sh still
measures the actual diff afterwards and stays unchanged, so lanes only decide the phases before the code.

Proposed `bin/unit-size.sh <unit> (--contract <path> | -- <path>...)`. It prints
`lane: <small|medium|full> files=<n> reason=<word>`, writes `.claude/bookkeeping/<unit>.lane` and
`.claude/bookkeeping/<unit>.scope` (the list, which the st-u2 precheck reads when there is no contract),
and exits 0.
- full: any planned path in the sensitive class (st-u1 lib); a `.fail` record for the unit; more than 10
  entries; a directory entry or glob in a no-contract dispatch (unmeasurable); a missing or unparseable
  input; the script missing (the orchestrator treats it as full).
- small: 4 entries or fewer, none sensitive, no `.fail` record, a single-unit request.
- medium: everything else.

The orchestrator may move a unit to a heavier lane, never a lighter one: the downgrade-only rule, the same
as reviewer-tier.sh's. Lane effects:
- small: no spec-master, no pre-explorer. lead-programmer gets `## Affected files`, the objective, and
  `Pre-resolved context: none (small lane: read the listed files yourself)`. One reviewer follows, fed by
  the precheck. Scribe runs only for an issue to close (aof-u4).
- medium: no spec-master (operator ruling OQ2 = ii). The orchestrator writes `## Affected files` and at
  most 5 steps itself, one lead-programmer per step, each followed by its reviewer. The explorer still runs
  first for a dispatch with no contract. A request needing more than 5 steps is full.
- full: spec-master always, task-master when the spec has 6 or more units, pre-explorer for dispatches
  that have no contract.

### c3 vs g3 (OQ1): the analysis behind the question

All savings are against the predicted post-quick-win baseline (findings, stage 2: wall about 1650 s, cache
read about 9.5M, about $13; A: 363 s, 1.38M, $4.01). My sanity check removes double counting: c2 and aof-u2
already removed part of the same orchestrator calls that c3 and g3 count again.

| | c3 unit runner | g3 writer-as-main | neither for now (a + f only) |
|---|---|---|---|
| Mechanism | the orchestrator dispatches one foreground `unit-runner` per unit; the runner dispatches lead-programmer, then the reviewer with the templated header, and returns the verdict line plus the marker path; the orchestrator verifies the marker with one bookkeeping call | the main session runs as lead-programmer (settings `"agent": "lead-programmer"`); the Stop hook blocks until a PASS marker covers the session's commits; the reviewer dispatch prompt must equal `unit-bookkeeping.sh review` output plus a fixed body, enforced by reviewer-route-gate | the lanes, the precheck and the scope gate; the orchestrator unchanged |
| Findings' estimate | -400 s, -4 to -6M cache read, -$6 | B about 1000 s (2.8x A), about 4.4M cache read, about $9 | -460 s (a) and -250 s (f) |
| My sanity check | per unit, orchestrator calls go from about 6 to 7 after the quick wins down to 3: about -35 calls x 8 s / 65k = -280 s, -2.3M; the runner adds about 4 calls per unit x 25k = +1.0M, +100 to 150 s on sonnet. **Net about -130 to -280 s, -1.3M, -$2 to -3** | the main thread looks like Arm A's (about 45 calls x 31k = 1.4M) plus 10 reviews x 0.3M plus FAIL cycles: **about 3 to 4.5M, 800 to 1000 s, about $8 to 10**. The orchestrator's growing transcript (35k to 84k per call) goes away | (a) -140 s if OQ2 = (i), about -440 s if (ii); (f) -100 to -250 s, -0.6 to -1.8M; **B about 1050 to 1400 s** |
| Writer/Reviewer split | kept: separate agents and contexts; the review routing owner moves from the orchestrator to a thin runner, an LLM that could alter the prompt (mitigated: the gate verifies the templated header) | weakened: the writer launches its own reviewer, mitigated by the gate forcing a template the writer cannot edit; a writer that never dispatches is stopped by the Stop gate; loses spec-master, task-master and scribe routing unless invoked on demand; loses the implementer ladder (the main model is fixed for the session) | unchanged |
| reviewer-route-gate | its caller allowlist (`:71-74`) adds `unit-runner`; the `Unit:` first-line rule is kept; new: the prompt must open with the header file's lines | `:62-66` (lead-programmer may not spawn the reviewer) is inverted for the main session only; new: byte-equal template check; identity of a main session started through settings `"agent"` is undocumented (must be probed first) | unchanged |
| stop-gate | the pending-review flag is raised at lead-programmer SubagentStop; for a nested lead-programmer this is undocumented, so the flag may never be raised and the gate fails open; replacement: the orchestrator's Stop is blocked until every runner-returned unit has a marker (new check) | new main-Stop rule: block while HEAD is past the last PASS marker's commit; `gatedAgents` gains the main session; the WIP sentinel and `defer:`/`skip:` exits must be re-specified for a main-session writer | unchanged |
| Marker-write privileges | unchanged if the nested reviewer's tool hooks carry `agent_type: reviewer` (documented for tool events in subagents) | unchanged for the reviewer; `reviewed-path-gate.sh:263` (main-session fallback branch) must not treat a lead-programmer main session as the orchestrator | unchanged |
| Nesting depth | orchestrator -> runner -> reviewer -> explorer is 3 layers, the default limit; qw-u5 makes the explorer rare; at the limit the reviewer loses the explorer fallback | 2 layers | n/a |
| Effort | L: a new persona, 2 gate edits, a new Stop check, a templated-dispatch check, 4 to 6 units | L+: settings, 3 gate edits, a Stop rule, a protocol rewrite of review ownership, the ladder story, 6 to 8 units | M: 4 units (st-u1 to st-u4) |
| Risk | medium-high: undocumented nested SubagentStop; depth limit | high: changes every gate's identity assumption; undocumented main-session identity | low-medium |
| How the A/B measures it | S13 (orchestrator calls per unit at most 4), S14 wall, S15 cache read; S5 (safety) must hold; plus `subagent_type == "unit-runner"` spawn count equal to the number of units | the B' arm against A directly: S14 and S15 against A (target 3x A wall or less, 3.5x cache read or less), S5, S16; the main thread's calls are about A's | S9 to S12, S14 to S16 |

Recommendation: **neither for now** (OQ1 option c; the operator ruled it on 2026-10-20). Land a + f, re-pilot, then decide between c3 and g3
on measured numbers. Reasons:
- After the quick wins plus a + f, my estimate leaves c3 a net -130 to -280 s on a 1050 to 1400 s run.
  That is real but small next to its undocumented failure mode (a nested SubagentStop that does not fire
  fails the pending-review gate open).
- g3 is the only option that reaches about 2.5x A, but it rewrites the identity model of five gates, and
  its first prerequisite (main-session `agent_type` under settings `"agent"`) is undocumented. A 20-minute
  probe (P1 below) should answer that before any g3 contract is written.
- The re-pilot after a + f measures what remains (orchestrator calls per unit, S13), which is exactly the
  quantity c3 and g3 compete on.

If the operator prefers to commit now, c3 is the lower-risk choice and g3 the higher-payoff one.

Probes that would de-risk OQ1 (design only; each is a `claude -p` session the operator runs, not this
spec): P1 prints the hook input of a main-session Bash call under settings `"agent": "lead-programmer"`
(does `agent_type` appear?); P2 runs a nested lead-programmer under a general-purpose subagent and checks
whether `stop-gate.sh` sees a SubagentStop for it (the audit log line).

### Prior defect history (FAIL-record screen) and note sweep

- `.fail` records naming reviewer-tier.sh describe rename, C-quoted path and unit-id-sanitising defects
  (sensitive paths slipping past anchors; review routing failing open). The precheck therefore lists paths
  with the same `-c core.quotepath=false -c diff.relative=false --no-renames` flags and treats a C-quoted
  path as `scope: out ... unquotable`. st-u1 moves the class without changing one pattern (criterion 3
  diffs the array against the parent commit).
- `spec2-unitB` (vacuous, stop-gate-core.sh and validate.sh), `mw-step1`/`mw-step2`/`gh317` (registration):
  every new test is registered in validate.sh as its own `if` block, and each criterion names a mutation.
- aof-u1 (a moved phrase pinned by a test) and qw-u4's 44-character T10 miss: st-u1 moves code that a
  mutation control pins (mc13), and the contract moves the control in the same commit.
- gh348-14 (trimmed text still asserted by other docs): st-u3 adds the trust-model row that C8.2 requires.
- Note sweep: `bash bin/marker-audit.sh . --notes --surface=<path>` printed these `NOTE[spec]` counts:
  reviewer-tier.sh 0, hooks/hooks.json 4, hooks/scripts/lib 10, agents/reviewer.md 24,
  templates/persona-protocol.md 27, bin/cli.js 15, agents/orchestrator.md 61. The hooks.json and lib lines
  were read in full, and the reviewer, protocol and cli.js lines were filtered for precheck, scope,
  sensitive, criteria, helper and explorer terms. Dispositions:
  - lo2-4 (mutating only a rendered `.claude/hooks/scripts/lib` copy leaves suites green): every unit here
    pins its installed copy with `cmp`.
  - item05-3 (a plugin-internal check never reaches an adapted project): both new scripts are installed
    (`BIN_HELPER_FILES`, hook scripts) and checked by `cmp`.
  - blc-6 (a payload applied on one line instead of wrapped): every prose row flattens whitespace.
  - saa-u7 (a weak mirror loop where any token satisfies each file): the prose rows check each phrase in
    each file.
  - The other lines (stale citations in CONTEXT.md and the protocol, the hcb-branch Step 7 C7.x gap, and
    microworld notes) touch no edited span. They are not taken up.
  - No untagged line names an undispatched step of this plan. The sweep is best-effort and never proof
    that no note exists.
- aof-u3's PASS marker records the design finding that became aof-u3b. st-u1 to st-u3 implement aof-u3b's
  couplings mechanically, and do not re-open them.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Missing
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-20 Functional scope & success criteria: Q Which architecture, c3, g3 or neither? → A: pending, OQ1 (operator ruling). (Ruled below, 2026-10-20: neither for now.)
- 2026-10-20 Functional scope & success criteria: Q Does "medium = today's chain" keep spec-master on a multi-file feature such as E5? → A: pending, OQ2. The findings' E5 saving (-300 s) exists only if it does not. (Ruled below, 2026-10-20: (ii).)
- 2026-10-20 User interaction flow: Q Who runs the precheck: a SubagentStop hook, the bookkeeping script, or the reviewer? → A (self-resolved): the reviewer, itself (f-B). This is the same pattern as the operator's c1 ruling for blast-radius.sh; it keeps independence, and the hook route would cover the wrong range anyway.
- 2026-10-20 Non-functional attributes (perf, security, scale): Q May the reviewer FAIL on a packet line without reading code? → A (self-resolved): yes, for the mechanical lines only (`scope: out`, `scope: no-affected-list`, `criterion <n>: fail`, `version-stamp: ... violation`, `contract: changed-since-baseline`). The brief's variation (f) asks for this, and each line is a check the reviewer already runs by hand today.
- 2026-10-20 Non-functional attributes (perf, security, scale): Q Can a unit weaken its own criteria by editing its contract (docs/plans is exempt from scope)? → A (self-resolved): no. The precheck reads the contract from the baseline commit and fails on `contract: changed-since-baseline`.
- 2026-10-20 External dependencies & integrations: Q Which hook facts are documented? → A (self-resolved): SubagentStop fields and blocking, the nesting limit and SubagentStart are documented (guide-hook-semantics). Nested SubagentStop and main-session identity under settings `"agent"` are not; they are listed as OQ1 risks with probes P1 and P2.
- 2026-10-20 Edge cases / failure handling: Q What does the scope gate do with no transcript, no config, another persona, or a path outside the project? → A (self-resolved): it allows all four. A missing transcript is logged as `unattributable` in `.claude/bookkeeping/scope-gate.log` (st-u3 cases i and j).
- 2026-10-20 Edge cases / failure handling: Q Does the scope gate loop forever on a writer that will not revert? → A (self-resolved): it blocks on every stop while the violation stands, and Claude Code ends the loop after 8 continuations. It does not honour the WIP sentinel: stop-gate.sh consumes that file concurrently, and a leak can always be reverted.
- 2026-10-20 Edge cases / failure handling: Q What is a long criterion? → A (self-resolved): one whose `run:` line carries `(Bash tool timeout`. The precheck defers it, and the reviewer runs it with `--criterion <n>`, so no single Bash call exceeds 600 s.
- 2026-10-20 Technical constraints & tradeoffs: Q How is the sensitive-path class reused without drift? → A (self-resolved): it moves verbatim into `hooks/scripts/lib/sensitive-paths.sh`, sourced by reviewer-tier.sh, the precheck and unit-size.sh. mc13 moves to mutate the library copy (st-u1).
- 2026-10-20 Technical constraints & tradeoffs: Q How are version-stamp files recognised mechanically? → A (self-resolved): in this plugin's own layout (`.claude-plugin/plugin.json` tracked at the baseline), the three P3 files are class `plugin-version`; elsewhere a version-file name is class `judge`, which the reviewer decides. A `scopeStandingPaths` config key was considered and deferred: it needs a new `--update` flag, and every contract here lists the files anyway.
- 2026-10-20 Technical constraints & tradeoffs: Q Is the scope gate a blocking gate or a log? → A: pending, OQ3; contract st-u3 is written for the recommended blocking option. (Ruled below, 2026-10-20: (a).)
- 2026-10-20 Terminology consistency: Q The brief's "packet" collides with the glossary's **review-packet** (contract key) and **advisory review packet**. What is the precheck output called? → A (self-resolved): the **precheck packet** (`.claude/bookkeeping/<unit>.precheck`). Proposed glossary entry in the Scribe update hint.
- 2026-10-20 Completion / acceptance signals: Q What shows the stage worked? → A (self-resolved): S9 to S16 under "Re-pilot plan", each with its measurement.
- 2026-10-20 Functional scope & success criteria: Q (OQ1) Which structural architecture follows a + f? → A: (c) neither c3 nor g3 for now, per operator: land a + f, re-pilot, and decide later with S13 (orchestrator calls per unit) as the decision metric. No architecture contracts and no probes P1/P2 now.
- 2026-10-20 Functional scope & success criteria: Q (OQ2) In the medium lane, does spec-master still run? → A: (ii) no, per operator: the orchestrator writes `## Affected files` and at most 5 steps itself; a request needing more than 5 steps is full. Implemented in st-u4.
- 2026-10-20 Technical constraints & tradeoffs: Q (OQ3) Does the writer scope gate block or only log? → A: (a) block, per operator, for lead-programmer, scribe and spec-master; st-u3 as written, its hold removed.
- 2026-10-20 Technical constraints & tradeoffs: Q Does the small lane need a lead-programmer.md change? → A (self-resolved): no. The protocol already says lead-programmer takes structure from `## Pre-resolved context` and names what is missing; the small-lane dispatch says `none (small lane: read the listed files yourself)`, and lead-programmer has Read and Grep. Fewer files, and no four-copy port sync.

## Risks / dependencies

- R1: every unit edits `tests/validate.sh` and bumps the version, so the units run strictly after qw-u6 and
  one at a time, in the order of the Dispatch section. st-u2's `before:` payloads assume qw-u5 has landed.
- R2 (st-u1): moving the sensitive class is a refactor of a fail-closed tier rule. The mitigations: the
  array moves byte for byte (criterion 3), reviewer-tier.test.sh's 63 checks stay green, and mc13 still
  flips (criterion 2's mutation).
- R3 (st-u3): attribution comes from the writer's own transcript. A Bash heredoc write that is never
  committed is not attributed. The eval's scope.sh counts only committed changes, and the precheck still
  sees a lead-programmer's committed diff, so the residual is uncommitted knowledge-file text left in a
  tree. Recorded in the trust-model row.
- R4 (st-u3): a blocked lead-programmer must revert in a new commit. That is history-safe on a shared
  branch: the block text says `git checkout <start> -- <path>`, never a reset.
- R5 (st-u2): the precheck runs criterion commands, with the same trust the reviewer gives them today. A
  criterion that writes (for example `node bin/cli.js --update`) still writes; that is unchanged
  behaviour, now in one place.
- R6 (st-u2): the reviewer prose changes in `agents/reviewer.md` only. The codex and cursor reviewer ports
  install no `.claude/bin/` and keep running the checks by hand (the qw-u5 precedent).
- R7: OD-23 (`uniform`) puts every B subagent on the run's model, so per-call costs in the next pilot are
  not comparable with pilot 4's mixed tiers. S14 and S15 compare with the quick-win re-pilot, not with
  pilot 4.
- R8 (st-u4, OQ2): a misclassified small unit skips a spec it needed. The mitigations: the lane is
  downgrade-only, the sensitive class forces full, any `.fail` record forces full, and the reviewer still
  reviews every unit.
- R9 (OQ1): c3's nesting depth sits at the default limit of 3. g3 depends on undocumented main-session
  identity. Both need the P1 and P2 probes before contracts.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. The facts in Context were re-measured. The three contracts' tests
  were run green against scratch implementations on a clone, and each red step was observed.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The scope, size, sensitive-path and
  criteria checks move from reviewer reasoning into one script, and lane choice into another.
- P3 "Version-stamp discipline": satisfied. Each unit bumps `.claude-plugin/plugin.json` and `package.json`
  and adds a CHANGELOG line in the same commit. st-u2 touches `agents/reviewer.md` and the protocol template,
  so it carries the `version-stamp-check.sh` criterion. st-u1 and st-u3 touch neither, and instead check
  that the version moved, because `--update` would not install their files otherwise.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. The scope gate allows any persona it does
  not know, and the precheck prose sits in reviewer.md (the reviewer is optional); with no reviewer,
  nothing calls the precheck.
- P5 "`tests/validate.sh` is the merge gate": satisfied. Every unit registers its test there and ends with
  validate.sh exit 0.

## Steps

### Step 1 (st-u1): shared scope libraries (f, part 1)
Contract: `docs/plans/antislop-structural/contracts/st-u1.md`.
Affected files: `hooks/scripts/lib/sensitive-paths.sh` (new), `hooks/scripts/lib/unit-scope.sh` (new),
`hooks/scripts/reviewer-tier.sh` (class moved out, one source line), `tests/reviewer-tier.test.sh` (mc13
mutates the library copy), `bin/cli.js` (`CLAUDE_ONLY_HOOK_LIB_FILES`), `tests/scope-libs.test.sh` (new),
`tests/validate.sh`, bump files, and the generated `.claude/hooks/scripts/` copies.
Acceptance criteria (full set in the contract): scope-libs exit 0; reviewer-tier.test.sh exit 0; the array
in the library equals the array at the parent commit; the source files and their installed copies are
byte-identical (`cmp`); no adapter file and no `hooks.json` changed; the version moved; validate.sh exit 0.
Measurable target: none on its own (an enabler); behaviour unchanged (63 reviewer-tier checks).

### Step 2 (st-u2): the reviewer's mechanical pre-review (f, part 2)
Contract: `docs/plans/antislop-structural/contracts/st-u2.md`. Depends on st-u1 and qw-u5.
Affected files: `bin/review-precheck.sh` (new), `bin/cli.js` (`BIN_HELPER_FILES`),
`tests/bin-helpers-scaffold.test.sh`, `agents/reviewer.md` (new bullet before the blast-radius bullet),
`templates/persona-protocol.md` (one sentence after qw-u5's reuse rule), `tests/review-precheck.test.sh`
(new), `tests/validate.sh`, bump files, generated mirrors.
Output contract: line 1 `precheck: result=<pass|fail> unit=<u> range=<b>..<sha> fails=<n> deferred=<n>
judge=<n>`, then `contract:`, `changed:`, `scope: <ok <class>|out|judge>`, `size:`, `sensitive:`,
`version-stamp:` and `criterion <n>: <pass|fail|deferred|judge>` lines; a copy is written to
`.claude/bookkeeping/<unit>.precheck`; exit 0, or 2 on bad arguments.
Acceptance criteria: the precheck test (30 script checks plus the prose rows) exit 0; `cmp` source and
installed script; scaffold test exit 0; the installed script runs on this repo; adapters, hooks and
orchestrator untouched; protocol suites exit 0; version-stamp-check ok; validate.sh exit 0.
Measurable target: reviewer tool calls per review, median at most 6 (pilot 4: 8 to 13); reviewer span
median at least 15 s shorter than in the quick-win re-pilot (S10).

### Step 3 (st-u3): writer scope gate at SubagentStop (f, part 3; operator ruling OQ3 = a)
Contract: `docs/plans/antislop-structural/contracts/st-u3.md`. Depends on st-u1 (library) and qw-u1
(`.claude/bookkeeping/` gitignored).
Affected files: `hooks/scripts/writer-scope-gate.sh` (new, 755), `hooks/hooks.json` (second SubagentStop
entry), `docs/trust-model.md` (row 26), `tests/writer-scope-gate.test.sh` (new), `tests/validate.sh`, bump
files, generated `.claude/hooks/scripts/` copy.
Acceptance criteria: the gate test (17 checks) exit 0; `cmp` source and installed gate; trust-model
bijection, abtest-arms, cli-hook-propagation and harness-integrity suites exit 0; adapters untouched; the
version moved; validate.sh exit 0.
Measurable target: `scope-outside-allowed` passes in 5 of 5 B rows, and `out_of_scope_files` is 0 in every
B row whose fixture A also keeps clean (S11).

### Step 4 (st-u4): lane script and orchestrator lane routing (a; operator ruling OQ2 = ii)
Contract: `docs/plans/antislop-structural/contracts/st-u4.md`. Depends on st-u3 (validate.sh anchor) and st-u2
(`BIN_HELPER_FILES` and scaffold payloads).
Affected files: `bin/unit-size.sh` (new), `bin/cli.js` (`BIN_HELPER_FILES`), `tests/bin-helpers-scaffold.test.sh`,
`agents/orchestrator.md` (new "Lane routing" section above "Delegation contract"; the routing-table planning
line; the pre-explorer sentence), `tests/unit-size.test.sh` (new), `tests/validate.sh`, bump files, generated
mirrors.
Rules:
- full: a sensitive path, a `.fail` record, more than 10 entries, a glob, a directory or trailing-slash
  entry, a missing contract, no input, or the libraries missing;
- small: 4 entries or fewer;
- medium: everything else, with no spec-master; the orchestrator writes the scope and at most 5 steps;
- `.claude/` and `docs/plans/` entries never count;
- downgrade-only, and a missing script, a non-zero exit or other output means full.
Acceptance criteria: the lane test (19 script checks plus the prose rows) exit 0; `cmp` source and installed
script; scaffold exit 0; the installed script classifies its own contract `full ... reason=sensitive`;
adapters, hooks, templates and the other personas untouched; prose suites exit 0; version-stamp-check ok;
validate.sh exit 0.
Measurable target: on E1 to E4, 0 spec-master spawns and 0 explorer spawns before the first lead-programmer
dispatch; on E5, 0 spec-master spawns; orientation before the first dispatch at most 25 s on E1 to E4
(pilot 4: 16 to 75 s) (S9).

### Architecture (operator ruling OQ1 = neither, 2026-10-20)
No units. After the re-pilot, S13 (orchestrator calls per unit) decides whether c3 or g3 is worth its gate
changes. Context "c3 vs g3" keeps the analysis, and probes P1/P2 the de-risking steps for that decision.

## Re-pilot plan (after st-u1 to st-u4, and again after any architecture units)

Run after all structural units have reached PASS and are committed, with the same commands as the
overhead-fix re-pilot (validate.sh, `--probe-isolation`, `--probe-canary`, `--pilot`). The baseline is the
quick-win re-pilot's B rows (call it QW), not pilot 4 (R7). S1 to S8 must still hold. New criteria, each
measured over `eval/abtest/results.jsonl` and `eval/abtest/.runs/*_B_uniform_1/stream.jsonl`:
- S9, lanes live: every B stream has a Bash tool_result whose first line matches `^lane: (small|medium|full) `.
  E1 to E4 print `small`, and those streams show 0 `spec-master` spawns and 0 `explorer` spawns before the
  first `lead-programmer` spawn.
- S10, precheck live: every reviewer subagent (`subagent_type == "reviewer"`) runs `review-precheck.sh` in
  its first two Bash calls; the median number of tool_use blocks per reviewer dispatch is at most 6; the
  median reviewer span is at least 15 s below QW's.
- S11, scope: `scope-outside-allowed` passes in 5 of 5 B rows, and B's `out_of_scope_files` is at most
  A's in every eval.
- S12, safety kept: S5 holds (reviewer spawns at least `process.units`, and a marker or a FAIL with a
  re-review per unit). No defect or security check that passed in QW fails now. Every reviewer FAIL cites
  either a precheck line or a defect class (counted for the larger eval).
- S13, orchestrator calls per unit: main-thread assistant messages with a unique `message.id`, divided by
  `process.units`. Target at most 5 with a + f only; at most 3.5 with c3. Not defined for g3 (no
  orchestrator).
- S14, wall: the sum of B `wall_clock_ms` is at most 0.75 x QW for a + f, and at most 0.6 x QW with c3 or
  g3. No single eval is more than 10% slower than QW.
- S15, tokens: the sum of B `tokens_cache_read` is at most 0.8 x QW for a + f, and at most 0.55 x QW with
  c3 or g3.
- S16, cost ratio: B/A `total_cost_usd` is at most 2.5 with a + f (predicted 2.6 to 3.2 from 3.3, so this
  is a stretch target that is reported, not gating), and at most 2.2 with c3 or g3.

S12 must hold; a miss means a gate regressed, so stop and diagnose. S9 to S11 test mechanisms and must all
hold. S13 to S16 are targets: a miss on one is re-planned for that problem only. S13 is the number OQ1's
deferred decision is made on.

Reference measurement script (for the operator; not a unit). It extends the aof-u5 script:
```
python3 -I - <<'EOF'
import json,glob,statistics as st
for d in sorted(glob.glob('eval/abtest/.runs/*_B_uniform_1')):
    ids={}; spans={}; tools={}; first_lp=None; pre={'spec-master':0,'explorer':0}; lane=None
    for l in open(d+'/stream.jsonl'):
        r=json.loads(l)
        if r.get('type')!='assistant': continue
        m=r.get('message') or {}; who=r.get('subagent_type') or 'main'; aid=r.get('agent_id') or 'main'
        ids.setdefault(who,set()).add(m.get('id'))
        for c in m.get('content') or []:
            if isinstance(c,dict) and c.get('type')=='tool_use':
                tools[aid]=tools.get(aid,0)+1
                if c.get('name') in ('Agent','Task'):
                    t=(c.get('input') or {}).get('subagent_type')
                    if t=='lead-programmer' and first_lp is None: first_lp=r['timestamp']
                    if first_lp is None and t in pre: pre[t]+=1
    rev=[n for a,n in tools.items() if a!='main']
    print(d.split('/')[-1], {k:len(v) for k,v in ids.items()}, 'pre-first-LP', pre)
EOF
```
Join it with the `results.jsonl` fields `wall_clock_ms`, `tokens_cache_read`, `total_cost_usd`,
`process.units`, `out_of_scope_files` and the `scope-outside-allowed` check. The lane line and the
precheck call are found by grepping Bash tool_results for `^lane: ` and Bash tool_use commands for
`review-precheck.sh`, restricted to records whose `subagent_type` is `reviewer`.

## Larger-task eval: measurement requirements (design only)

The findings' break-even question is whether bare Fable's defect rate on harder tasks, times the cost of
an escaped defect, exceeds B's overhead (about $2 to 4 and 1 to 2 minutes per unit). Requirements for an eval that can
answer it:
- Tasks: 3 to 8 files, and 200 to 600 changed lines in the reference solution. Each task has at least one
  hidden cross-module invariant (for example a store shape that a CLI and an export script both read)
  and at least one security-sensitive path (input validation, auth, injection). The holdout checks are not
  visible to either arm.
- Reps: N of 3 or more per arm per task, at least 5 tasks, all under `uniform`. Medians are reported
  alongside sums.
- Per run:
  - holdout defect and security pass rate;
  - `defects_escaped` per arm;
  - for B, `review_fail_cycles`, with each FAIL's cited class (holdout-detectable defect, criterion-only,
    scope, documentation, precheck line);
  - the lane chosen;
  - wall, cache read, cost and `out_of_scope_files`.
- Pre-registered decision rule:
  - If A's defect rate stays at or under 10% across at least 15 runs, B's value case is scope and audit
    trail, not correctness. Then the target becomes f plus a, at about 1.3x A, and review depth is
    re-planned.
  - If A's defect rate is 25% or more and B's escaped defects are at least 50% fewer, the per-unit review
    is justified at its measured cost, and OQ1's g3 payoff is re-weighed against it.
- Scored blind (`blind.sh`), and every harness change gets an OD amendment as before.

## Open Questions

None. OQ1 to OQ3 were ruled by the operator on 2026-10-20 and are recorded in Clarifications.

## Self-check
- CHK1: Is every Goal clause (G1 to G5) mapped to a step criterion, a placeholder or an Open Question? — PASS (G1 Steps 1-2; G2 Step 3; G3 Step 4 and OQ2; G4 OQ1 and Steps 5+; G5 Re-pilot plan and Larger-task eval)
- CHK2: Do Step 2 and the f table agree on who runs the precheck? — PASS (the reviewer itself; f-B)
- CHK3: Is the precheck's behaviour defined for a unit with no contract? — PASS (`--affected` paths, else the lane scope record, else `scope: no-affected-list` FAIL; test case f)
- CHK4: Is "long criterion" defined, so no Bash call exceeds 600 s? — PASS (the `(Bash tool timeout` marker; `deferred long`; `--criterion <n>`)
- CHK5: Can the unit under review weaken its own criteria? — PASS (criteria come from the baseline commit; `contract: changed-since-baseline` is a FAIL line; test case e)
- CHK6: Do st-u2 and st-u3 classify the same path the same way? — PASS (both call `us_classify` from the st-u1 library)
- CHK7: Is the version-stamp standing exception mechanical, or a judgment? — PASS (mechanical in the plugin layout; `judge` elsewhere, named in Clarifications)
- CHK8: Does each unit that adds an installed file move the version, given `--update`'s early return? — PASS (st-u1 and st-u3 criterion "version moved"; st-u2 version-stamp-check)
- CHK9: Is the architecture decided? — FAIL (missing) — converted to Open Question 1; resolved by operator ruling (neither for now; S13 decides later)
- CHK10: Is the medium lane's spec-master rule decided? — FAIL (missing) — converted to Open Question 2; resolved (ii), implemented in st-u4
- CHK11: Is the scope gate's blocking behaviour decided? — FAIL (missing) — converted to Open Question 3; resolved (a), st-u3 as written
- CHK12: Does criterion st-u1 AC "validate.sh exit 0" still fail under its own `mutation:` line, given mw-step1's recorded class vacuous (tests/validate.sh registration)? — PASS (the mutation is `exit 1` as line 2 of the new test; the registration is its own `if` block)
- CHK13: Does st-u2's prose criterion fail on the pre-unit reviewer.md, given gh348-14's class vacuous on persona prose? — PASS (the (j) rows failed on a clone before the prose edit, and passed after it)
- CHK14: Do st-u1's reviewer-tier criteria still fail under their mutation, given the reviewer-tier defect history? — PASS (reverting the mc13 move makes the suite print "the sed matched nothing", which spec-master observed on the clone)
- CHK15: Do st-u3's gate criteria fail under their mutation, given spec2-unitB's recorded class vacuous on stop-gate-core.sh? — PASS (removing `set +e` fails cases e to h, which spec-master observed before adding it)
- CHK16: Is every number in S9 to S16 measurable from fields the harness already records? — PASS (stream `subagent_type`, `agent_id`, `message.id`, `timestamp`; results.jsonl fields named in each S)
- CHK17: Does the spec state each quick-win interface it depends on, and how each was verified? — PASS (Context, interface table)
- CHK18: Do Step 4, st-u4 and the orchestrator routing table agree that spec-master runs only in the full lane? — PASS (st-u4 edit 6 rewrites the table line; prose row (k) asserts the old line is gone)
- CHK19: Does st-u4 criterion 4 still fail under its own mutation? — PASS (spec-master ran it: without the sensitive loop the script prints `lane: medium files=10 reason=contract`)
- CHK20: Do the four contracts' expected versions agree with the qw-u1 fix at 0.31.189? — PASS (st-u1 0.31.195 to st-u4 0.31.198; each bump is relative)

Terminology check (prose mode, advisory): lens 1, "packet" would collide with **review-packet** and
**advisory review packet**, so it is called the **precheck packet**. Lens 2: "unit scope", "standing
exceptions", "knowledge proposal" and "blast radius" are used in their glossary sense; "lane" is new, not a
synonym. Lens 3: new load-bearing terms **precheck packet**, **lane** (small, medium, full), **scope class**
(the seven words) and **writer scope gate** are proposed below.

## Scribe update hint
- Propose harness-glossary entries (docs/harness-glossary.md): **precheck packet** (the stdout of
  `review-precheck.sh`, copied to `.claude/bookkeeping/<unit>.precheck`; its failure lines are FAIL grounds);
  **scope class** (`listed`, `criteria`, `fail-record`, `fix-contract`, `plugin-version`, `judge`, `out`);
  **writer scope gate** (the SubagentStop gate for lead-programmer, scribe and spec-master); after st-u4,
  **lane**.
- After st-u2: the **F11 convention** entry gains a sentence that the reviewer's re-run of checks now goes
  through the precheck script.
- After OQ1: if c3 or g3 is ruled, its decision meets all three ADR tests (hard to reverse, surprising,
  a real trade-off); draft it in that ruling's follow-up spec for scribe to number.

## Dispatch section

Order, one unit at a time, each after the previous unit's reviewer PASS:
0. qw-u1-fix1 (in review now; landed at 0.31.189 as 4f8a545a), then qw-u2 (0.31.190), qw-u3 (0.31.191),
   qw-u4 (0.31.192), qw-u5 (0.31.193), qw-u6 (0.31.194). The quick-win contracts carry their own,
   older expectations. Each bumps relative to the version it starts from, so their payloads are unaffected.
1. st-u1 (0.31.195), after qw-u6 (its validate.sh anchor is qw-u6's block). [contracts/st-u1.md](contracts/st-u1.md)
2. st-u2 (0.31.196), after st-u1 and qw-u5 (library; chained `BIN_HELPER_FILES`, scaffold test, reviewer bullet and protocol sentence). [contracts/st-u2.md](contracts/st-u2.md)
3. st-u3 (0.31.197), after st-u2 (validate.sh anchor; library). Operator ruling OQ3 = (a). [contracts/st-u3.md](contracts/st-u3.md)
4. st-u4 (0.31.198), after st-u3 (validate.sh anchor; st-u2's `BIN_HELPER_FILES` and scaffold payloads). Operator ruling OQ2 = (ii). [contracts/st-u4.md](contracts/st-u4.md)
5. Re-pilot (S1 to S16) after st-u4 reaches PASS and is committed. Then the operator decides the architecture on S13.

The versions are expected only if no fix round bumps in between.

Unit count: 4 (st-u1 to st-u4), all contracted; no architecture units (OQ1 ruling). Together with the six
quick wins still ahead (including the qw-u1 fix), 10 units remain in the chain. That is over the fast-path
limit, but every contract is written by spec-master and scores 7/7 on `contract-score.js --rubric=v2`, so
task-master would only re-derive them. Recommendation: dispatch from the contract files directly, as for
the quick-win and overhead-fix plans. If the operator wants the protocol followed to the letter,
task-master can adopt the contract files unchanged.

## Amendment 2026-10-20 (antislop-review-patches, Open Question 1, ruled yes)
rp-u1 (`docs/plans/antislop-review-patches/contracts/rp-u1.md`) narrows the criteria standing exception to
paths a criterion reads, never one it runs, and makes a contract's `## Do NOT touch` win over every standing
exception. st-u1's `us_classify` is amended to match: a new first class `excluded` (an exact `## Do NOT
touch` entry, optional seventh argument) and `criteria` now excludes a path `us_executed_in` reports as run
(the script handed to `bash`, `sh`, `node` or `python3`, or a path in command position). `us_entries` takes
an optional section heading. st-u2's precheck passes the contract's `## Do NOT touch` entries and fails on
`scope: excluded <path>`; st-u3's gate refuses an excluded path first. The classes row above
("Standing exceptions to `## Affected files`") is superseded by this paragraph. rp-u1 must land before st-u1.

## Amendment 2026-10-21 (antislop-review-patches Step 9, st-u1 review)
st-u1 passed with three NOTE[spec] findings, fixed before st-u2 by rp-u8 (reviewer-tier.sh prints `opus`,
exit 0, when a library is missing or defines nothing) and rp-u9 (`us_exclusions`: a `## Do NOT touch`
bullet excludes only its whole subject, the `partial:` marker never excludes; globs stay in one segment;
empty, newline, `.` and `..` paths are `out`). st-u2, st-u3 and st-u4 are amended in place to match: each
checks its library functions with `declare -F` and fails closed (precheck exit 2; scope gate blocks the
three writers; lane `full`), st-u2 and st-u3 read exclusions with `us_exclusions`, and range criteria name
the unit's last commit. New dispatch order and versions: rp-u8 0.31.199, rp-u9 0.31.200, st-u2 0.31.201,
st-u3 0.31.202, st-u4 0.31.203 (then rp-u10, rp-u7, rp-u4 to rp-u6, rp-s1; see
`docs/plans/antislop-review-patches/spec.md`, Dispatch section). The Dispatch section versions above are
superseded.

## Amendment 2026-10-21 (antislop-review-patches Step 10, rp-u9 review)
rp-u9 passed with findings F1 to F6, verified against 952a8796 (st-u2 landed, 0.31.201). st-u3 is amended
in place: its scope gate checks the `.claude/` and `docs/plans/` allowance before `## Do NOT touch` (F1:
aof-u1-fix1's bullet excluded the two `.claude/agents/` copies its own mandated `--update` regenerated; a
deliberate exclusion of a `.claude/` copy is reviewer-enforced prose, "only through `--update`", and
st-u2's precheck already leaves both trees out), normalises Write/Edit paths lexically before judging them
(F2), and blocks a C-quoted committed name; cases (o), (p), (q). st-u4 is amended in place: an entry
`us_safe_path` rejects is `full` (`./hooks/x.sh` and `/hooks/x.sh` printed `small`). The library side of F2
and F3 to F5 is a new unit, rp-u11, dispatched before st-u3. New order and versions: st-u2 0.31.201 (landed,
in review), rp-u11 0.31.202, st-u3 0.31.203, st-u4 0.31.204 (then rp-u10, rp-u12, rp-u7, rp-u4 to rp-u6,
rp-s1; see `docs/plans/antislop-review-patches/spec.md`, Dispatch section). The 2026-10-21 Step 9 versions
above are superseded.

## Amendment 2026-10-21/22 (antislop-review-patches Step 11: st-u3 spec gap and operator step O1)
st-u3 amended twice in place. (1) 2026-10-21, `amended-3`: the gate sources `lib/state-access.sh` and uses its
unit-id helpers, because tests/state-access-constraints.test.sh M5 forbids a second spelling of the unit-id
class under `hooks/scripts/`. (2) 2026-10-22, operator ruling: the `hooks/hooks.json` registration is no
agent's edit (harness-integrity-gate.sh, Set B) and becomes operator step O1, applied by hand after the
lead's st-u3 commit with the snippet and commit command in st-u3's `operator-step-O1:` line (no version bump,
no CHANGELOG line, no `--update`). The lead's commit is green without O1 (validate.sh exit 0 on a clone);
until O1 the gate is installed but inert, and the reviewer does not FAIL st-u3 for it. Open item: O1, then
the `O1-check:` (`stop-gate.sh,writer-scope-gate.sh`). Order and versions: st-u3 0.31.204, st-u4 0.31.205
(see `docs/plans/antislop-review-patches/spec.md`, Dispatch section, Step 11).

## Amendment 2026-10-22 (antislop-review-patches Step 12: O1 held for rp-u15)
st-u3 landed at abc6d195 (0.31.204, PASS) and st-u4 at 7231a42e (0.31.205). The st-u3 review listed fail-open
and false-block cases in the gate; operator step O1 is held until rp-u15
(`docs/plans/antislop-review-patches/contracts/rp-u15.md`, expected 0.31.206) reaches PASS, then applied as
written in st-u3's `operator-step-O1:` line. rp-u15 leaves the registration (`hooks/hooks.json`) to O1.
