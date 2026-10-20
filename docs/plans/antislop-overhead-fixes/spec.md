# AntiSlop overhead and scope-leak fixes after A/B pilot 4 (spec)

Date: 2026-10-19. Author: spec-master. Status: **finalized** on 2026-10-19, after the operator ruled on the
three Open Questions. 6 units, aof-u1 to aof-u6, all with contract files.
Plan slug: `antislop-overhead-fixes`. Unit prefix: `aof-`.

## Goal

Make Arm B (AntiSlop as shipped) cheaper and keep it in scope without weakening any gate. The gates that must
keep their guarantee are: a reviewer verdict for every unit, the stop gate, the reviewed-path and
harness-integrity gates, and the protected paths. Also fix the harness's token count for multi-result streams,
as a dated amendment. Then re-run the pilot and judge the fixes by measured criteria.

## Context

### Evidence (pilot 4, 2026-10-19, `eval/abtest/results.jsonl`, `eval/abtest/.runs/*_uniform_1/`; re-measured by spec-master)

| Eval | A wall s | B wall s | B spawns | B scope check | B `find /` | B Stop exit 2 | B `.pending-review` write denied | B result records |
|---|---|---|---|---|---|---|---|---|
| E1 | 47 | 742 | 7 | FAIL (README.md) | 2 (main + reviewer) | 2 | 2 | 6 |
| E2 | 39 | 399 | 4 | FAIL (CONTEXT.md) | 1 | 1 | 1 | 4 |
| E3 | 51 (A FAIL: CONTEXT.md) | 265 | 4 | FAIL (CONTEXT.md, docs/adr/0002) | 0 | 1 | 2 | 4 |
| E4 | 55 | 271 | 4 | pass | 1 | 1 | 1 | 3 |
| E5 | 168 | 1155 | 20 | FAIL (CONTEXT.md) | 1 | 1 | 0 | 8 |

Each problem below was checked against the stream data:

1. **Missing helper scripts.** In E1, E2 and E5 a `find /` (or a plugin-dir glob) hit the 120 s Bash timeout,
   with the output "did not complete within its 120s timeout and was moved to the background". In E1 the
   reviewer did the same thing a second time. The cause is that `bin/cli.js`'s standalone scaffold copies
   `hooks/scripts/` to `.claude/hooks/scripts/` (cli.js:2523) but copies nothing from `bin/`. Both
   `agents/orchestrator.md` and `.claude/agents/orchestrator.md` still say `bash bin/ladder-tier.sh`
   (lines 467, 473, 492) and `bash hooks/scripts/reviewer-tier.sh` (line 532). In an installed project those
   paths are `.claude/hooks/scripts/reviewer-tier.sh` and nothing at all. Every B run then logged a
   `RULING ... no-contract (bin/ladder-tier.sh absent)` and put the implementer on `sonnet`. E4 B found the
   plugin copy's path in a hook error message and ran the script from there.
2. **Stop blocked during an in-flight review.** `agents/orchestrator.md:181-189` tells the orchestrator to
   write `defer: reviewer dispatched ...` into the pending-review flag whenever it dispatches the reviewer as a
   background task. Under `claude -p --permission-mode acceptEdits`, Claude Code refuses that Bash write with
   "Claude requested permissions to edit .../.claude/.pending-review.<id> which is a sensitive file". The
   following Stop is then blocked (exit 2, "Unit awaiting review") even though the reviewer is running, which
   costs 1 to 2 turns per run. The same session's append to `.claude/orchestrator-rulings.log` was not refused,
   so the refusal is specific to that path; it is not a blanket denial of `.claude/` writes. The stop gate does
   honour `reviewGating.mode: off`: stop-gate-core.sh:511 skips the Stop branch and :590 skips flag creation.
   The `permission_denials` field stayed 0 in every summary, so these denials did not turn a row into
   `stalled-human`. They cost turns, not run_pass.
3. **Scope leaks.** The stream attribution shows who made the out-of-scope edits:
   - E1 B: scribe edited `README.md`.
   - E2 B: scribe edited `CONTEXT.md`.
   - E3 B: lead-programmer edited `CONTEXT.md` and scribe wrote `docs/adr/0002-filters-are-predicates.md`.
   - E5 B: spec-master wrote `CONTEXT.md` and an ADR during grilling, and scribe added glossary entries to
     `CONTEXT.md`.
   - E3 A: the main session also edited `CONTEXT.md`, so part of the E3 leak is the task itself, not the
     pipeline.

   No task prompt names an allowed-paths list. The lists are hidden (`fixtures/*/allowed-paths.txt`), and
   `checks/scope.sh` never counts `.claude/` or `docs/plans/`.
4. **Serial per-unit cost.** E5 B shows these per-unit durations: lead-programmer 24 to 47 s, reviewer 53 to 67 s
   on opus versus 33 s on sonnet (47 to 55k tokens either way), a nested explorer under the reviewer 20 to 30 s
   (8 of 13 reviews spawned one), and scribe 20 to 40 s after every unit. The total was 1155 s, of which about
   900 s was subagent time. `reviewer-tier.sh` printed `opus` in E1 to E4 for these reasons:
   - E1: 44 changed lines.
   - E2: 41 changed lines, one over the cap.
   - E3: 7 files.
   - E4: 56 lines, 48 of them tests.

   The limits are MAX_CHANGED_LINES=40 and MAX_CHANGED_FILES=3, and test lines count toward the line limit.
   So the cause of the opus verdicts is the threshold, not a bug. E5 got sonnet on 2 of 5 reviews.
5. **Token-count bug in the harness.** `eval/abtest/lib/stream.py:118-133` keeps only the last `result`
   record. For the B streams (3 to 8 result records), the three ways to count give different totals
   (in + out + cache write):

   | Count | E1 | E2 | E3 | E4 | E5 |
   |---|---|---|---|---|---|
   | last record only, as reported | 4075 | 3606 | 3774 | 4678 | 3205 |
   | sum of every record's `usage` | 71693 | 81994 | 44879 | 39493 | 129663 |
   | last record's cumulative `modelUsage`, summed over models | 285138 | 227318 | 197667 | 154522 | 831801 |

   The summed `usage` exactly equals the `claude-fable-5-1` entry of `modelUsage`. That means `usage` counts
   the main thread only, and **summing the result records would still leave out every subagent**. Only
   `modelUsage` covers the whole run. On every single-result A stream all three counts agree.
   `total_cost_usd` is already cumulative, because it equals the sum of the per-model `costUSD`.
   **The same last-record bug also affects `num_turns`**: per-record values for E1 B are 12, 8, 5, 6, 3, 2,
   so the run had 36 main-session turns but reported 2, and `R_turns` is biased with it. `duration_api_ms`
   does **not** have the bug: it holds the same cumulative value on every record. This was corrected after
   the first draft; see Step 5.
6. **Model mix.** `arm-b.sh` exports `CLAUDE_CODE_SUBAGENT_MODEL=fable` under `uniform`. Even so, every B
   `modelUsage` contains haiku, sonnet and opus. Explicit dispatch `model:` parameters (sonnet for
   lead-programmer, opus for reviewer and spec-master) and frontmatter defaults (`model: haiku` for the
   explorer) took precedence. This contradicts `agents/orchestrator.md:474` ("A set
   `CLAUDE_CODE_SUBAGENT_MODEL` silently wins over this routing") and the pre-registration's "every persona on
   Fable". The operator ruled option (b): see Step 6 (aof-u6, OD-23).

### Additional finding (out of scope, recorded for the operator)

`hooks/scripts/session-start.sh:149` resolves `bin/harness-integrity.sh` as `<script dir>/../../bin`. In an
installed project that path is `.claude/bin/harness-integrity.sh`, which does not exist, so the config-drift
check silently does nothing there (explorer `overhead-fixes-explorer`; inferred from code, not executed).
aof-u1 creates `.claude/bin/` but must **not** copy `harness-integrity.sh` into it, because that would switch
on a gate in every installed project as a side effect. Re-arming it needs its own operator decision.

### Prior defect history (FAIL-record screen)

`docs/audits/unit-outcomes/2026-10-06.jsonl` lists earlier units with `vacuous` or `host` FAIL classes on the
same files this spec touches:
- `hooks/scripts/lib/stop-gate-core.sh`: gh413, mw-step3, spec2-unitA, spec2-unitB.
- `bin/cli.js`: gh348-4, gh360, gh409, item04-2-apply-drops.
- `agents/orchestrator.md`: gh307, gh310, gh348-14.
- `tests/validate.sh` registration: mw-step1, mw-step2, gh317, gh320, human-review-cleanup-1.

Every criterion below therefore names a `mutation:` that must make it fail. A test registered in validate.sh
must be wired so its failure fails validate.sh, and must not be appended after a gate that cannot fail. The per-surface sweep `bash bin/marker-audit.sh . --notes --surface=<path>` (676 markers) produced these
items and dispositions:
- `NOTE[spec]` gate-audit-step3: CONTEXT.md:1220 cites a stale `stop-gate.sh:188-198` line. **Not taken
  up.** CONTEXT.md is outside every unit's scope, and the item goes to the Scribe update hint.
- Untagged 265, 266 and 267: `bin/cli.js` PLACEHOLDER_RE raises a false "unresolved placeholder" warning on
  `<HEAD>` in the orchestrator's reviewer-tier example. **Taken up in aof-u1**, which rewrites that line: it
  must keep `HEAD` without angle brackets, and AC1.5 checks that the warning is absent.
- Untagged mw-step2 M2: a hand-edited `.claude/` mirror left a stale `fileHashes` entry. **Taken up in every
  unit**: mirrors are regenerated only by `node bin/cli.js --update`, never edited by hand.
- Untagged 199 (reviewer-tier "run from the repo root") and gh411, gh415 and gh424 (stop-gate wording):
  **not taken up**. No step changes those lines' meaning.

Per protocol, the sweep is best effort, not proof that nothing else exists.

### Alternatives per problem

Each cell gives the expected saving per B run on this pilot's shape, the risk to the Writer/Reviewer safety
property, the blast radius, how it can be tested, and the effort (S, M or L).

#### P1: helper scripts unreachable

| Alt | Patch | Saving | Safety risk | Blast radius | Testability | Effort |
|---|---|---|---|---|---|---|
| 1A **(chosen)** | Scaffold shim: `cli.js` copies the 5 ladder helpers (`ladder-tier.sh`, `contract-guard.js`, `contract-score.js`, `fail-count.sh`, `escalation-card.sh`) to `.claude/bin/` as hash-tracked `raw` specs on both the scaffold and `--update` paths. Orchestrator and task-master prose point to `.claude/bin/...` and `.claude/hooks/scripts/reviewer-tier.sh`, and forbid filesystem searches. | about 120 s in 3 of 5 runs (360 s in total), plus 1 to 2 orchestrator turns per unit | none, and the ladder becomes real again: the haiku guard runs instead of a blanket `sonnet` RULING | cli.js (new spec builder plus one copy line), orchestrator.md, task-master.md, agent-auditor.md prose, their `.claude/` mirrors, plugin.json, CHANGELOG, one new test | high: scaffold into a temporary repo and run the shim | M |
| 1B | SessionStart hook adds `${CLAUDE_PLUGIN_ROOT}/bin` to `additionalContext` | same as 1A when the plugin is loaded | none | session-start.sh, orchestrator.md | medium: the output depends on `CLAUDE_PLUGIN_ROOT`, which is empty on the standalone settings-registered copy (explorer 1c) | S |
| 1C | Put the ladder arithmetic in the orchestrator prompt and drop the script | same | **raises risk**: the contract-guard score (JS) cannot be inlined, and LLM arithmetic replaces a pure function (constitution P2) | orchestrator.md | low | S |
| 1D | PreToolUse hook on `Agent` computes the tier and rewrites `tool_input.model` | removes the tier step entirely | neutral, but tool-input mutation is invisible to the orchestrator | new hook in hooks.json, adapter parity, settings | medium | L |
| 1E | Rule only: "never `find /`" | removes the stall | the tier stays an unverified `sonnet` RULING on every unit | orchestrator.md | grep-level | S |

1A wins because the installed layout already mirrors the plugin's. In `.claude/bin/ladder-tier.sh`,
`repo_root` resolves to `.claude`, and the script's dependencies `agents/orchestrator.md` (cutover line),
`agents/lead-programmer.md` (`model:`), `hooks/scripts/lib/state-access.sh` and `bin/contract-guard.js` all
exist under `.claude/`. contract-guard finds `contract-score.js` through `__dirname`. So the shim needs no
script edits, and it works for plugin installs, standalone installs and the eval alike. 1B fails on standalone
installs. 1C breaks P2 and the guard. 1D is the largest change for a cost 1A already removes. 1E's rule is
kept as part of 1A, but on its own it fixes only the symptom.

#### P2: Stop blocked during an in-flight review

| Alt | Patch | Saving | Safety risk | Blast radius | Testability | Effort |
|---|---|---|---|---|---|---|
| 2A **(chosen)** | Read-only review-in-flight check in stop-gate-core.sh's Stop branch. Allow Stop when the number of fresh `.review-join.<unit>` stamps that have no verdict yet and are not `.advisory` is at least the number of undeferred pending-review flags. Fresh means at most 1800 s since the stamp's own timestamp. Log `stop-allowed=review-in-flight units=<ids>` to review-audit.log. Delete the orchestrator's "write `defer:` on a background reviewer dispatch" instruction. | 1 to 2 main turns per run, about 20 to 60 s, and no sensitive-file denials | **stricter than today**: today's sticky `defer:` lasts forever, while a stamp expires after 30 minutes and Stop blocks again if the reviewer died. The reviewer's own SubagentStop join, the route gate's next-dispatch block and the PASS-marker rules do not change. | stop-gate-core.sh plus 3 mirrored copies (regenerated by `--update`), orchestrator.md (one paragraph), one new test | high: the hook is fed JSON fixtures | M |
| 2B | reviewer-route-gate.sh writes `defer:` into the flag itself when it stamps a reviewer dispatch | same | equal to today's documented semantics, so a sticky defer survives a dead reviewer | reviewer-route-gate-core.sh plus copies | high | M |
| 2C | A new escape file outside `.claude/` that Claude Code does not treat as sensitive | same | adds a second, less-audited escape surface | stop-gate, docs, glossary | medium | M |
| 2D | Detect headless mode and relax the gate | same | **weakens**: the gate behaves differently by mode | stop-gate | low (env-dependent) | S |
| 2E | Do nothing | 0 | none | none | n/a | 0 |

2A wins because it adds no write, no escape surface and no mode dependence, and because its expiry makes it
stricter than the sticky `defer:` it replaces. 2B keeps today's weakness, where a dead reviewer leaves Stop
open. 2C and 2D weaken. 2E leaves the cost. The check must not reuse `review_join_state()` as it is, because
that function deletes malformed and advisory stamps (stop-gate-core.sh:266-281). It needs a read-only sibling.

#### P3: scope leaks

| Alt | Patch | Saving | Safety risk | Blast radius | Testability | Effort |
|---|---|---|---|---|---|---|
| 3A **(chosen, part 1: aof-u3)** | **Unit scope** becomes a first-class dispatch field. Every lead-programmer dispatch carries `## Affected files`, including the orchestrator's direct single-unit dispatch, which has no contract. The orchestrator derives the list from the paths the user named, their test directories and the explorer's blast radius. lead-programmer edits nothing outside it and reports anything else as a proposal. The reviewer runs `git diff --name-only <baseline>..HEAD` against it as a FAIL ground; `.claude/` and `docs/plans/` are exempt. | removes the lead-programmer leaks (E3) | **strengthens** the reviewer's check | orchestrator.md, lead-programmer.md, reviewer.md, their `.claude/` mirrors, plugin.json, CHANGELOG, validate guard | prose-level guard (grep) plus re-pilot S3 | M |
| 3B **(chosen, part 2: aof-u4)** | **Knowledge proposals.** scribe and spec-master write `CONTEXT.md`, `README.md` or `docs/adr/*` only when the path is in unit scope or the project sets `knowledgeWrites: "apply"`. Otherwise they put the change in their report as a proposal, which the orchestrator relays in its final summary, and, when a plan document exists, also under its "Scribe update hint". | removes the scribe and spec-master leaks (E1, E2, E3, E5) | none: knowledge files are not gate surfaces | scribe.md, spec-master.md, orchestrator.md, templates/persona-config.schema.json, cli.js default, this repo's own config | grep guard plus schema test plus re-pilot | M |
| 3C | PreToolUse path gate on Write/Edit against a per-unit scope file | mechanical | adds a gate, and Bash writes bypass it (the same asymmetry as reviewed-path-gate) | new hook, hooks.json, adapters, state file, glossary | high | L |
| 3D | Reviewer-only diff check | partial: scribe and spec-master are not reviewed | none | reviewer.md | prose | S |

How the list reaches a persona when the prompt names none: a contract unit already has `## Affected files`
from spec-master or task-master. For a direct dispatch, the orchestrator writes it, using the derivation
above. An interactive user widens the scope by naming a file in the request ("also update the README"), or
project-wide by setting `knowledgeWrites: "apply"`. Interactive behaviour stays visible: the proposals appear
in the session's final message, so nothing is lost silently.

3A plus 3B is chosen over 3C because the leakers are knowledge personas acting on instructions they were
given. Fixing the instruction removes the cause. A new Write/Edit gate would add a bypassable gate surface
and adapter-parity work, and would not catch Bash writes. 3D alone misses three of the four leak sources.
3A and 3B together change nothing in `scope.sh`, the allowed paths or the prompts. They rely only on the
pipeline's own `docs/plans/` and on chat output; the report carries the proposals.

#### P4: serial per-unit chain

| Alt | Patch | Saving (E5 shape) | Safety risk | Blast radius | Testability | Effort |
|---|---|---|---|---|---|---|
| 4A | `reviewer-tier.sh` stops counting test-file lines toward the 40-line cap | about 20 to 30 s per review that flips to sonnet (E1, E2 and E4 would flip) | **relaxes a measured threshold**. E4 is the security eval, and its unit would go to sonnet. Consumer `src/` paths are never in the sensitive list. | reviewer-tier.sh, its test, glossary | high | S |
| 4B **(chosen, folded into aof-u4)** | Scribe runs **once per plan**, after the last unit's PASS, with every unit's digest and every verbatim PASS line. On the fast path with no tracker issue and no in-scope knowledge change, it is not dispatched at all. | (units - 1) x 20 to 40 s, so about 120 s on E5 and about 30 s on each of E1 to E3 | none: scribe is not a gate, and issue closing still quotes each PASS line | orchestrator.md (Scribe dispatch convention), scribe.md | prose guard plus re-pilot spawn counts | S |
| 4C | Reviewer skips the nested explorer on small diffs | 20 to 30 s per review | **weakens** reviewer independence. The protocol says the reviewer always re-derives blast radius, and "no export change" needs a language-specific predicate. | reviewer.md, protocol | low | S |
| 4D | Move the rulings-ledger append into `ladder-tier.sh` | a few seconds per unit | breaks the script's "never writes" purity contract (ladder-tier.sh:6) | ladder-tier.sh, test | high | S |

4B is chosen: it is the largest saving that touches no gate. 4A is held back: the threshold is the only thing
keeping a security-relevant consumer diff on opus. It stays available as a future operator ruling with its own
evidence; it is not part of this plan. 4C conflicts with the protocol's "the reviewer always re-derives" rule.
4D buys almost nothing once aof-u1 removes the 120 s stall, which is where most of the orchestrator's
bookkeeping time went. The downgrade-only rule and the sensitive-path rule are untouched by every alternative
chosen here.

#### P5: harness token count (amendment)

| Alt | Patch | Correct? | Notes |
|---|---|---|---|
| 5A | Sum `usage` over every result record | **no** | equals the main-thread `modelUsage` entry, so subagents are still missing (table above) |
| 5B **(chosen)** | Take tokens from the last result's cumulative `modelUsage`, summed over models. Fall back to the sum of `usage` over all result records only when `modelUsage` is absent or empty. | yes | matches the total cost, and the A rows do not change |
| 5C | Recompute from per-assistant-message usage in the stream | maybe | double-counting risk, and subagent messages may not carry usage |

Model-mix labelling had three alternatives: (a) relabel the rows `shipped` and disclose it; (b) enforce uniform
in the eval copy; (c) both. The operator ruled (b), which is aof-u6.

### Draft ADR (for scribe to number and land; it meets all three domain-modeling tests)

**Knowledge files change only inside unit scope.** Context: in pilot 4, knowledge personas (scribe,
spec-master) edited `CONTEXT.md`, `README.md` and `docs/adr/` that no task named, in 4 of 5 Arm B runs.
Decision: knowledge writes outside a unit's scope become proposals, unless the project opts in with
`knowledgeWrites: "apply"`. Alternatives rejected: a Write/Edit path gate, which can be bypassed through Bash
and adds a gate surface, and a reviewer-only check, which misses unreviewed personas. Consequence: the glossary
grows more slowly in projects that do not opt in. This repo opts in. The ADR is hard to reverse, because
projects come to rely on the default.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-19 Functional scope & success criteria: Q Does "fix the token-sum bug" include `num_turns` and `duration_api_ms`, which have the same last-record defect and feed `R_turns`? → A: (a) per the operator, 2026-10-19. `num_turns` is summed. `duration_api_ms` was re-measured as already cumulative, so it is kept rather than summed; see the correction note in Step 5.
- 2026-10-19 User interaction flow: Q In an interactive project with no stated allowed list, how does a persona learn its scope and how does the user widen it? → A (self-resolved): through the contract's `## Affected files`, or for a direct dispatch through the orchestrator-derived list (named paths, their test directories, explorer blast radius). The user widens it by naming a file or by setting `knowledgeWrites: "apply"`. Proposals are relayed in the final message.
- 2026-10-19 Non-functional attributes (perf, security, scale): Q May the reviewer-tier line threshold be relaxed to save opus time? → A (self-resolved): no, not in this plan (4A rejected; E4's security unit would go to sonnet). Downgrade-only and sensitive-path rules unchanged.
- 2026-10-19 External dependencies & integrations: Q Can a Claude Code permission setting be relied on to allow the `defer:` write headlessly? → A (self-resolved): no. The refusal comes from Claude Code's sensitive-file check under `acceptEdits`, which the plugin does not control, so the fix moves the decision into the hook (2A).
- 2026-10-19 Edge cases / failure handling: Q What happens if a reviewer dispatched in the background dies and never stops? → A (self-resolved): its review-join stamp expires 1800 s after its timestamp, and Stop blocks again as it does today. The orphaned stamp is never deleted by the Stop path.
- 2026-10-19 Terminology consistency: Q Rows labelled `model_policy: uniform` do not meet the glossary's **model policy** definition ("every persona on the same model") → A: (b) per the operator, 2026-10-19. Uniform is enforced in the eval copy (aof-u6, OD-23).
- 2026-10-19 Completion / acceptance signals: Q Which re-pilot numbers decide that the fixes worked? → A (self-resolved): S1 to S8 under "Re-pilot plan" below
- 2026-10-19 Functional scope & success criteria: Q What should `knowledgeWrites` default to when the key is absent? → A: (a) per the operator, 2026-10-19. Absent means `scoped`, and this repo opts into `apply` through `--update`.

## Risks / dependencies

- R1 (aof-u1): `.claude/bin/` is new executable state that the orchestrator trusts. It is hash-tracked by
  `--update` drift detection in the same way as `.claude/hooks/scripts/`. It is not added to the
  harness-integrity Set A, which keeps parity with every other scaffolded script except the gate itself. A
  tampered `ladder-tier.sh` could only change the implementer tier, and the reviewer gate is unaffected.
- R2 (aof-u1): `harness-integrity.sh` is deliberately not shimmed (see the additional finding above).
- R3 (aof-u2): mirrored copies of `stop-gate-core.sh` under `adapters/codex`, `adapters/cursor` and
  `.claude/hooks/scripts/lib` must be regenerated in the same commit with `node bin/cli.js --update`.
  `tests/adapter-stop-gate-parity.test.sh` catches drift.
- R4 (aof-u2): the 1800 s expiry is a constant. A review longer than 30 minutes falls back to today's
  behaviour, which blocks Stop and accepts a `defer:`. It never fails open.
- R5 (all agent and template units): constitution P3 requires a version bump in `.claude-plugin/plugin.json`
  and a CHANGELOG entry **in each commit** that touches `agents/*.md` or `templates/*`. Units aof-u1 to aof-u4
  all touch `agents/orchestrator.md`, so they must run serially in the order u1, u2, u3, u4. aof-u5 and aof-u6
  touch no stamped file. They run serially with each other (u5, then u6), because both append to the same two
  amendment documents.
- R6 (re-pilot): every product unit moves `plugin_commit`, and aof-u5 and aof-u6 move `harness_commit`. Under
  OD-14 the runner supersedes all 10 pilot-4 rows and repeats them. That is expected.
- R7 (aof-u4): this repo's own `.claude/persona-config.json` is Set A. Its `knowledgeWrites: "apply"` is set
  only through the new `node bin/cli.js --update --knowledge-writes=apply` option, never by a direct write.
- R9 (aof-u6): the copy-only hook relies on Claude Code honouring `hookSpecificOutput.updatedInput` for
  PreToolUse on `Agent`. The unit tests can prove the hook's output but not the CLI's reaction, so re-pilot
  S8 is the live proof. If S8 fails, the rows are mixed again and must not be scored as uniform; stop and
  return to the operator.
- R10 (aof-u6): under `uniform` the reviewer runs on the run's model (Fable). The product rule "Fable is never
  valid on the gate" is overridden in the eval copy only, and OD-23(c) discloses it.
- R8: E3's `CONTEXT.md` leak also occurred in Arm A (the glossary names the renamed function). Under 3A/3B the
  B pipeline turns that edit into a proposal, so B can now score better than A on E3 scope. That is a
  legitimate product effect, not a change to scoring.
- Dependency: aof-u4 depends on aof-u3 (unit scope), and aof-u6 depends on aof-u5 (OD numbering).

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every claim in Context was re-measured from the streams, and each step's criteria are commands.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. 1A keeps the ladder in scripts (1C was rejected for violating this), and 2A puts the in-flight decision in the hook, not in an orchestrator write.
- P3 "Version-stamp discipline": satisfied. Steps 1 to 4 each require a bump and a CHANGELOG entry in the same commit (R5).
- P5 "`tests/validate.sh` is the merge gate": satisfied. Each step ends with `bash tests/validate.sh` exit 0, and every new test is registered there.

## Steps

### Step 1 (aof-u1): helper scripts reachable in installed projects (P1, alt 1A)
Affected files: `bin/cli.js`, `agents/orchestrator.md`, `agents/task-master.md`, `agents/agent-auditor.md`,
and their `.claude/agents/*.md` mirrors (regenerated by `node bin/cli.js --update`); `.claude/bin/*` (5 new
generated files, plus `fileHashes` written by `--update`); `.claude-plugin/plugin.json`; `CHANGELOG.md`;
`tests/bin-helpers-scaffold.test.sh` (new); `tests/validate.sh`.
Acceptance criteria:
- AC1.1 run: `bash tests/bin-helpers-scaffold.test.sh` exits 0. It scaffolds a fresh temporary git repo with
  `node bin/cli.js --personas=spec-master,task-master,reviewer,scribe` and asserts:
  - the 5 helpers exist under `.claude/bin/`;
  - `.claude/bin/harness-integrity.sh` does **not** exist;
  - `bash .claude/bin/ladder-tier.sh u1` (run from the temp root) prints a line matching
    `^ladder-tier: (haiku|sonnet) n=0 ladder=[a-z,]+ reason=no-contract$`;
  - `node .claude/bin/contract-guard.js <a fixture contract> --unit=u1` prints a first line starting
    `contract-guard: `;
  - after `rm -rf .claude/bin`, a `node <plugin>/bin/cli.js --update` brings all 5 back.

  mutation: removing the new copy call from the scaffold path makes the existence assertion fail; removing
  the spec builder from `runUpdate` makes the `--update` assertion fail.
- AC1.2 run: `test "$(grep -cE 'bash bin/(ladder-tier|escalation-card)\.sh|node bin/contract-guard\.js|bash hooks/scripts/reviewer-tier\.sh' agents/orchestrator.md agents/task-master.md | awk -F: '{s+=$2} END{print s}')" = 0`.
  mutation: restoring any old path makes the count non-zero.
- AC1.3 run: `grep -qF 'Never search the filesystem for a harness script' agents/orchestrator.md && ! grep -qF 'silently wins over this routing' agents/orchestrator.md`.
  This includes correcting the `CLAUDE_CODE_SUBAGENT_MODEL` sentence at line 474, as recommended under Open
  Question 2. mutation: reverting either edit fails the check.
- AC1.6 run: plugin.json and CHANGELOG.md are both in `git show --name-only HEAD` (P3, same commit).
- AC1.4 run: `bash tests/validate.sh` exits 0, with the new test registered so that its failure fails
  validate.sh. mutation: `exit 1` at the top of the new test must make validate.sh exit non-zero.
- AC1.5 run: `! node bin/cli.js --update --dry-run 2>&1 | grep -q 'unresolved placeholder.*orchestrator.md'`.
  Use `--dry-run`: `--check` is a deprecated alias that writes files (cli.js:1169-1171).
  mutation: writing `<HEAD>` in the reviewer-tier example makes the warning appear and the check fail.

### Step 2 (aof-u2): Stop allowed while a dispatched review is in flight (P2, alt 2A)
Affected files: `hooks/scripts/lib/stop-gate-core.sh`; its mirrored copies (`.claude/hooks/scripts/lib/`,
`adapters/codex/hooks/scripts/lib/`, `adapters/cursor/hooks/scripts/lib/`, regenerated by `--update`);
`agents/orchestrator.md` (lines 181-189 paragraph) and its `.claude/` mirror; `.claude-plugin/plugin.json`;
`CHANGELOG.md`; `tests/stop-gate-review-inflight.test.sh` (new); `tests/validate.sh`.
Acceptance criteria:
- AC2.1 run: `bash tests/stop-gate-review-inflight.test.sh` exits 0, covering these cases. Each one feeds a
  main-session Stop payload with one undeferred `.pending-review.x` flag unless stated otherwise.
  - (a) fresh stamp `.review-join.u1`, no marker: exit 0, and review-audit.log gains a line containing
    `stop-allowed=review-in-flight units=u1`.
  - (b) no stamp: exit 2.
  - (c) stamp timestamp 1801 s old: exit 2.
  - (d) stamp plus a format-valid `PASS u1 ` marker newer than the stamp: exit 2. The verdict has returned, so
    the reviewer stop has to clear the flag; Stop does not.
  - (e) only `.review-join.u1.advisory`: exit 2.
  - (f) two undeferred flags and one fresh stamp: exit 2.
  - (g) the sha256 of every `.review-join.*` file is unchanged after cases (a) to (f), so the check is
    read-only.
  - (h) `reviewGating.mode: off`: exit 0 and no new audit line.
  - (i) a malformed stamp (no `unit=`): exit 2, and the stamp is not deleted.

  mutation: removing the in-flight branch fails (a); removing the age comparison fails (c); calling the
  existing `review_join_state` instead of a read-only reader fails (g) and (i).
- AC2.2 run: `bash -c 'for m in adapters/codex adapters/cursor .claude; do cmp -s hooks/scripts/lib/stop-gate-core.sh "$m/hooks/scripts/lib/stop-gate-core.sh" || { echo "differs: $m"; exit 1; }; done'`
  exits 0 with no stdout. mutation: an un-regenerated or appended mirror prints `differs: <mirror>` and
  exits 1. (Amended 2026-10-20: `tests/adapter-stop-gate-parity.test.sh` tests behaviour only and passes
  with a reverted or appended mirror.)
- AC2.3 run: `bash -c "! tr -s ' \n' ' ' < agents/orchestrator.md | grep -qF 'write \`defer: reviewer dispatched' && grep -qF 'stop-allowed=review-in-flight' agents/orchestrator.md"`.
  mutation: restoring the old paragraph fails it. (Amended 2026-10-20: the earlier needle
  `background task, write` matched the new paragraph too.)
- AC2.5 run: the existing `tests/stop-gate-blocked.test.sh`, `stop-gate-escalated.test.sh` and
  `stop-gate-config-drift.test.sh` still exit 0. A case with an empty-reason `defer: ` flag plus a fresh stamp
  still exits 2.
- AC2.4 run: `bash tests/validate.sh` exits 0, with the new test registered so that it can fail validate.sh.
  The mutation is the same as AC1.4.

### Step 3 (aof-u3): unit scope carried in every implementer dispatch (P3, alt 3A)
Affected files: `agents/orchestrator.md`, `agents/lead-programmer.md`, `agents/reviewer.md` and their
`.claude/` mirrors; the hand-synced adapter ports `adapters/codex/agents/{lead-programmer,reviewer}.toml` and
`adapters/cursor/agents/{lead-programmer,reviewer}.md`. The adapter orchestrator ports carry no direct-dispatch
packet text, so they are not touched. Also `.claude-plugin/plugin.json`; `CHANGELOG.md`;
`tests/unit-scope-prose.test.sh` (new); `tests/validate.sh`.
Rules the prose must state:
1. The orchestrator's direct (contract-less) lead-programmer dispatch includes an `## Affected files` section.
   It is derived from the paths the request names, those paths' test directories and the explorer's blast
   radius, and never left empty.
2. lead-programmer edits only files in `## Affected files`, plus `docs/plans/` and `.claude/` bookkeeping. Any
   other change it believes is needed goes into its report under `Proposed out-of-scope changes:` and is not
   applied.
3. The reviewer computes `git diff --name-only <baseline>..HEAD`, minus `.claude/` and `docs/plans/`, minus
   `## Affected files`. A non-empty remainder is a FAIL ground unless an acceptance criterion of the unit
   requires that file.

Acceptance criteria:
- AC3.1 run: `bash tests/unit-scope-prose.test.sh` exits 0. It greps for one anchored sentence per rule (the
  exact sentences are fixed in the aof-u3 contract) in `agents/orchestrator.md`, `agents/lead-programmer.md`,
  `agents/reviewer.md`, their `.claude/agents/` mirrors and the four adapter ports. mutation:
  deleting any one sentence fails it.
- AC3.2 run: `bash tests/validate.sh` exits 0, with the new test registered so that it can fail validate.sh.

### Step 4 (aof-u4): knowledge proposals, plus scribe once per plan (P3 alt 3B, P4 alt 4B)
Affected files: `agents/scribe.md`, `agents/spec-master.md`, `agents/orchestrator.md` (Scribe dispatch
convention, lines 41-60) and their `.claude/` mirrors; `templates/persona-config.schema.json`; `bin/cli.js`
(a new `--knowledge-writes=<scoped|apply>` option for `--update`); this repo's `.claude/persona-config.json`
through that option only (R7); `.claude-plugin/plugin.json`; `CHANGELOG.md`; `tests/knowledge-writes.test.sh`
(new); `tests/validate.sh`.
Rules:
1. When `knowledgeWrites` is absent or `scoped` (OQ1 = a: **absent means `scoped`**), scribe and spec-master
   write `CONTEXT.md`, `docs/harness-glossary.md`, `README.md` and `docs/adr/*` only when that path is in
   unit scope. Any other knowledge change goes into a `Knowledge proposals:` report section, and into the
   plan's "Scribe update hint" when a plan exists. The orchestrator relays the proposals in its final message.
   `.claude/wiki/` stays scribe's to write freely.
2. The orchestrator dispatches scribe once, after the last unit of a plan (or of a single-unit request)
   reaches PASS. That dispatch carries every unit's digest, task-id, issue number (if any), verbatim PASS
   verdict line and scribe dispatch contract (if any). scribe still closes each issue only on its own quoted
   PASS line.
3. Scribe is not dispatched when no unit has a tracker issue and no proposal falls in scope.
4. The schema has `knowledgeWrites` as an enum (`scoped`, `apply`). `--update` never backfills the key, so an
   absent key keeps meaning `scoped`, and Arm B, whose config `arm-b.sh` writes without the key, measures
   the shipped default.
5. This repo opts in by running `node bin/cli.js --update --knowledge-writes=apply`, committed in the same
   unit.

Acceptance criteria:
- AC4.1 run: `bash tests/knowledge-writes.test.sh` exits 0. It covers:
  - the schema enum (a valid and an invalid value);
  - a fresh scaffold whose config has no `knowledgeWrites` key;
  - `--update --knowledge-writes=apply` setting the key;
  - `--knowledge-writes=bogus` exiting non-zero with the config unchanged;
  - one anchored sentence per rule in each persona;
  - mirror sync.

  mutation: deleting the enum, the option or any sentence fails it.
- AC4.2 run: `jq -r .knowledgeWrites .claude/persona-config.json` prints `apply` (this repo opted in).
- AC4.3 run: `bash tests/validate.sh` exits 0, with the new test registered.

### Step 5 (aof-u5): whole-run token and turn count, plus amendment OD-22 (P5, alt 5B; harness, not product)
Affected files: `eval/abtest/lib/stream.py`; `tests/abtest-stream.test.sh`;
`tests/fixtures/abtest/streams/` (2 new fixtures); `docs/plans/antislop-vs-fable-evals/operator-decisions.md`
(OD-22 appended); `docs/experiments/abtest-2026-10.md` (amendment paragraph after the OD-21 one, which ends at
line 66).
Acceptance criteria:
- AC5.1 run: `bash tests/abtest-stream.test.sh` exits 0, with these new checks:
  - (a) fixture `multi-result.jsonl`: 3 result records, the last one carrying
    `modelUsage: {m1:{inputTokens:10,outputTokens:20,cacheCreationInputTokens:30,cacheReadInputTokens:400}, m2:{inputTokens:1,outputTokens:2,cacheCreationInputTokens:3,cacheReadInputTokens:40}}`.
    Each record carries `usage` with in+out+cw = 6, `num_turns` 1 to 3 (1, 2, 3), and the same
    `duration_api_ms` of 500. Expected: `tokens_total` 66, `tokens_cache_read` 440, `tokens_in` 11,
    `tokens_out` 22, `tokens_cache_write` 33, `num_turns` 6, `duration_api_ms` 500.
  - (b) fixture `multi-result-no-mu.jsonl`: 2 result records without `modelUsage`, with usage (1,2,3,0) and
    (4,5,6,0). Expected: `tokens_total` 21.
  - (c) the existing check "tokens_total is input plus output plus cache write" (value 60) and "turns read
    from the result" (value 7) still pass.

  mutation: reverting stream.py to last-record usage makes (a) report 6 and (b) report 15; reverting
  `num_turns` makes (a) report 3; summing `duration_api_ms` makes (a) report 1500.
- AC5.2 run: `bash tests/abtest-score.test.sh && bash tests/abtest-row.test.sh` exit 0. The
  `tokens_total = in + out + cw` invariant (score.py:88-90) holds because all four fields come from the same
  source.
- AC5.3 run: `grep -q '^- OD-22 (2026-10-19' docs/plans/antislop-vs-fable-evals/operator-decisions.md && grep -q '^Amendment 2026-10-19 (OD-22' docs/experiments/abtest-2026-10.md`.
  mutation: a missing entry fails it.
- AC5.4 run: on the real pilot-4 E5 B stream, `summarize()` returns `tokens_total` 831801 and `num_turns` 53.
- AC5.5 run: `bash tests/validate.sh` exits 0.

**Correction to the premise of Open Question 3 (recorded 2026-10-19 after the ruling).** Re-measurement
shows that `duration_api_ms` is **already cumulative**: every result record in a stream carries the same
value (E1 B: 519300 on all 6; E5 B: 1253697 on all 8). Summing it, as the ruling literally says, would
multiply it by the record count. Per-segment wall time is in `duration_ms`, which no row reads. aof-u5
therefore carries out the ruling's intent, a correct whole-run value:
- `num_turns` is summed over all result records (E1 B: 36, E5 B: 53);
- `duration_api_ms` keeps the last record's value, which is the whole-run value;
- a test guards both.

This is a deviation from the literal answer, made because the premise I gave was wrong. The coordinator
should relay it to the operator. If the operator still wants a different field summed, that is a new ruling.

OD-22 text (verbatim draft for aof-u5; it appends after OD-21):

> - OD-22 (2026-10-19, whole-run token and turn count; binding operator decision from pilot 4, 2026-10-19)
>   Evidence (eval/abtest/.runs/*_B_uniform_1/stream.jsonl, pilot 4): an Arm B stream holds 3 to 8 `result`
>   records, one per main-session segment, and lib/stream.py read the last one only. Each record's `usage`
>   counts the main thread of its own segment only (their sum equals the main model's `modelUsage` entry), so
>   B's `tokens_total` was 3205 to 4678, while the last record's `modelUsage` is cumulative over the whole run
>   and every model, subagents included (B: 285138, 227318, 197667, 154522 and 831801 for E1 to E5; its
>   `costUSD` sum equals `total_cost_usd`). Each record's `num_turns` is per segment too (E1 B: 12, 8, 5, 6, 3
>   and 2, so 36 main-session turns were reported as 2). `duration_api_ms` is the same on every record of a
>   stream, so it is already a whole-run value. Every Arm A stream holds one record, where all readings agree.
>   (a) The rule. `tokens_in`, `tokens_out`, `tokens_cache_write` and `tokens_cache_read` are the sums over all
>   models of the last result record's `modelUsage` (`inputTokens`, `outputTokens`,
>   `cacheCreationInputTokens`, `cacheReadInputTokens`); when `modelUsage` is absent or empty, they are the sums
>   of `usage` over every result record. `tokens_total` stays input + output + cache write (OD-5). `num_turns`
>   is the sum over every result record, which is the main-session turn count of OD-2 and OD-9.
>   `duration_api_ms`, `total_cost_usd` and `model_usage` stay read from the last record, which is already
>   cumulative.
>   (b) Unchanged. The definitions of `tokens_total` (OD-5) and of the turn count (OD-2, OD-9), the R_tokens,
>   R_wall and R_turns thresholds, the checks, the allowed paths, the prompts and every verdict rule. Arm A
>   values are unchanged (one record).
>   (c) Not covered. The model policy of Arm B rows is OD-23.
>   (d) Fingerprint. This change moves `harness_commit`, so under OD-14 every pilot-4 row is superseded and
>   repeated.

Experiment-doc amendment (verbatim draft, appended after line 66 of `docs/experiments/abtest-2026-10.md`):

> Amendment 2026-10-19 (OD-22, before the first full run): `tokens_total` and `num_turns` now count the whole
> run. Arm B streams hold one `result` record per main-session segment (3 to 8 in pilot 4), and the harness had
> read the last one only, which counted the final segment's main thread (3205 to 4678 tokens for B against
> 154522 to 831801 for the whole run, and 2 turns against 36 in E1). The harness now sums the last record's
> cumulative per-model usage, which covers every segment and every subagent, and sums `num_turns` over every
> record; `duration_api_ms` was already cumulative and is unchanged. The definitions (OD-2, OD-5, OD-9) and
> every threshold are unchanged, and Arm A rows (one record) are unaffected. The change moves
> `harness_commit`, so the pilot-4 rows are superseded (OD-14) and repeated.

### Step 6 (aof-u6): uniform model policy enforced in Arm B's plugin copy, plus amendment OD-23 (OQ2 = b; harness, not product)
Affected files: `eval/abtest/arms/common.sh` (a new `abtest_uniform_models DEST MODEL`); `eval/abtest/arms/arm-b.sh`
(it calls that function under `uniform` only); `tests/abtest-arms.test.sh`;
`docs/plans/antislop-vs-fable-evals/operator-decisions.md` (OD-23); `docs/experiments/abtest-2026-10.md`
(amendment after OD-22's).
Rules: under `ABTEST_POLICY=uniform` only, and in the plugin copy only:
- `abtest_uniform_models` removes the `model:` line from the YAML frontmatter of every `agents/*.md`;
- it writes a copy-only hook `hooks/scripts/abtest-uniform-model.sh`, with the model name baked in at copy
  time. For a PreToolUse `Agent` or `Task` call, the hook returns `hookSpecificOutput.updatedInput`: the
  original `tool_input` with `model` set to the model;
- it registers that hook in the copy's `hooks/hooks.json` under PreToolUse with matcher `Agent|Task`;
- it fails unless at least one `model:` line was removed and none remain, and unless exactly one registration
  was added.

The product tree, Arm A and the `shipped` policy are untouched.
Acceptance criteria:
- AC6.1 run: `bash tests/abtest-arms.test.sh` exits 0, with new checks:
  - (a) after `abtest_uniform_models <copy> fable`, no `agents/*.md` frontmatter in the copy has `model:`;
  - (b) the hook fed `{"hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"subagent_type":"reviewer","model":"opus","prompt":"p"}}`
    prints JSON whose `.hookSpecificOutput.updatedInput` equals the input with `model` = `fable`, keeping
    `subagent_type` and `prompt`;
  - (c) fed a `Bash` tool call, the hook exits 0 with no output;
  - (d) the copy's hooks.json has exactly one entry naming `abtest-uniform-model.sh`;
  - (e) a second `abtest_uniform_models` on the same copy fails;
  - (f) `arm-b.sh` calls `abtest_uniform_models` inside the `uniform` branch only (grep);
  - (g) the product `agents/*.md` still carry their `model:` lines.

  mutation: dropping the frontmatter strip fails (a); dropping the `model` assignment fails (b); calling the
  function unconditionally fails (f).
- AC6.2 run: `grep -q '^- OD-23 (2026-10-19' docs/plans/antislop-vs-fable-evals/operator-decisions.md && grep -q '^Amendment 2026-10-19 (OD-23' docs/experiments/abtest-2026-10.md`.
- AC6.3 run: `bash tests/validate.sh` exits 0.
- Live check (re-pilot S8, not a unit criterion): every B row under `uniform` has `model_usage` keys equal to
  the one model that the A rows use.

OD-23 text (verbatim draft for aof-u6; it appends after OD-22):

> - OD-23 (2026-10-19, uniform model policy enforced in Arm B; binding operator decision, option (b), from pilot 4)
>   Evidence (eval/abtest/results.jsonl and .runs/*_B_uniform_1/summary.json, pilot 4): every Arm B row labelled
>   `model_policy: uniform` has `model_usage` entries for haiku, sonnet and opus besides Fable. arm-b.sh exports
>   `CLAUDE_CODE_SUBAGENT_MODEL` under `uniform`, but on CLI 2.1.302 an explicit `model` on a dispatch (the
>   orchestrator's per-unit routing: sonnet for lead-programmer, opus for reviewer and spec-master) and a
>   persona's frontmatter `model:` (haiku for the explorer) both take precedence over it. The rows therefore did
>   not meet the pre-registration's "every persona on Fable".
>   (a) The rule. Under `ABTEST_POLICY=uniform`, the plugin copy that arm-b.sh loads (and scaffolds from) has
>   the `model:` line removed from every persona's frontmatter, and registers one extra PreToolUse hook for
>   `Agent` and `Task` that only exists in the copy. It sets the dispatch's `model` to `ABTEST_MODEL` and changes
>   nothing else. The copy fails to build unless the strip and the registration both happen exactly as stated.
>   (b) Unchanged. The product tree, hooks/scripts, every gate, the `shipped` policy (no strip, no hook), Arm A,
>   lib/stream.py, the scorer, the checks, the allowed paths and the prompts.
>   (c) Cost. Under `uniform`, Arm B runs AntiSlop with its model routing switched off: the per-unit ladder, the
>   measured reviewer tier and the product rule that Fable is never valid on the review gate do not apply, and
>   every persona runs on `ABTEST_MODEL`. This is the process-effect comparison the pre-registration names; the
>   product cost question stays with the deferred `shipped` replicates (OD-7). The report must say that Arm B's
>   uniform rows ran with routing overridden (pre-registration amendment 2026-10-19).
>   (d) Pilot-4 rows. The 5 B rows of pilot 4 are mixed-tier, not uniform. They are superseded (OD-14, OD-22)
>   and none of them counts.
>   (e) Fingerprint. This change moves `harness_commit`; under OD-14 the rows made before it are superseded and
>   repeated.

Experiment-doc amendment (verbatim draft, appended after the OD-22 paragraph):

> Amendment 2026-10-19 (OD-23, before the first full run): the uniform policy is now enforced in Arm B. Pilot 4
> showed that `CLAUDE_CODE_SUBAGENT_MODEL` does not win over an explicit dispatch model or a persona's
> frontmatter model, so the B rows labelled `uniform` ran subagents on haiku, sonnet and opus. Under `uniform`,
> the plugin copy Arm B loads now drops every persona's frontmatter `model:` and carries one copy-only hook
> that sets every subagent dispatch's model to the run's model; Arm B therefore runs with AntiSlop's model
> routing switched off, as "every persona on Fable" requires. The product tree, the gates, Arm A, the `shipped`
> policy, the checks and the scoring are unchanged. The change moves `harness_commit`, so the earlier rows are
> superseded (OD-14) and repeated.

## Re-pilot plan

Run this after all six units, aof-u1 to aof-u6, have reached PASS and are committed. Arm B's plugin copy is
built by `git archive HEAD` (common.sh:141), so uncommitted work is not measured.

Commands, in order, from the repo root (per OD-20(e) and OD-21(f)):
1. `bash tests/validate.sh`
2. `eval/abtest/run-matrix.sh --probe-isolation`
3. `eval/abtest/run-matrix.sh --probe-canary`. A `FOUND` blocks everything.
4. `eval/abtest/run-matrix.sh --pilot`, which produces 10 rows (E1 to E5 by A and B, rep 1). The runner moves
   the stale pilot-4 rows to `results.superseded.jsonl` (OD-14).

Expected cost on the Max plan: pilot 4 was about $4.0 list-equivalent for A and $19.1 for B (`total_cost_usd`
is list price, not a bill), with about 6 min of A wall time and 47 min of B wall time. Under OD-23 every B
subagent runs on the run's model instead of haiku and sonnet, so B's token cost per subagent may rise even as
the overhead fixes remove turns. Plan for about 45 to 55 min of sequential wall time and at most about 1.5
times pilot-4 usage. If a `usage-limit` row occurs, it is repeated, not scored (OD-4).

Success criteria. Each one is measured by a command over `eval/abtest/results.jsonl` and
`eval/abtest/.runs/*_B_uniform_1/stream.jsonl`, and the script for it is in the aof-u5 contract's Pre-resolved
context:
- S1, no stall: zero B tool_use Bash commands contain `find /`, and zero tool results contain "did not
  complete within its 120s timeout".
- S2, no Stop churn: zero B results contain "which is a sensitive file", and the total number of Stop
  exit 2 records across the 5 B streams is at most 1.
- S3, scope: `scope-outside-allowed` passes in at least 4 of 5 B rows, and for every eval B's
  `out_of_scope_files` is at most A's.
- S4, wall time: the sum of B `wall_clock_ms` is at most 0.8 x 2832 s (2266 s), and no single B eval is more
  than 10 % slower than pilot 4. Because OD-23 changes B's models, a miss on S4 alone is reported with that
  caveat, not treated as a failed fix.
- S5, safety kept: the `reviewer` spawn count in every B stream is at least `process.units`, and every unit
  has a `.pass` marker in the run's snapshot or a FAIL and re-review. No B eval whose defect checks passed in
  pilot 4 fails one now.
- S6, ladder live: at least one B stream shows a `ladder-tier:` line produced by `.claude/bin/ladder-tier.sh`.
- S7, counts sane: for every row, `tokens_total` equals the sum over `model_usage` of
  inputTokens + outputTokens + cacheCreationInputTokens, and each B row's `num_turns` is greater than 2.
- S8, uniform real: every B row's `model_usage` has exactly the one key that the A rows have.

S5 must hold. Failing it means a gate regressed, so stop and diagnose. S1, S2, S6, S7 and S8 test the
mechanical fixes and must all hold. S3 and S4 are the product targets: if either misses, re-plan that problem
only.

## Resolved questions (operator ruling relayed by the coordinator, 2026-10-19)

1. `knowledgeWrites` default: **(a)**. An absent key means `scoped`, this repo opts into `apply` through
   `--update`, and Arm B measures the shipped default. Implemented in Step 4.
2. Arm B model mix: **(b)**. Uniform is enforced in the eval only, as aof-u6, with amendment OD-23
   (Step 6). The `CLAUDE_CODE_SUBAGENT_MODEL` sentence at orchestrator.md:474 is corrected in aof-u1.
3. OD-22 scope: **(a)** for `num_turns`. For `duration_api_ms` the premise was wrong: the value is already
   cumulative, so it is kept, not summed (see "Correction to the premise of Open Question 3" in Step 5). The
   coordinator relays this.

## Open Questions

None.

## Self-check
- CHK1: Does the plan define every measurement field that the stream.py last-record bug affects? — FAIL (missing) — converted to Open Question 3; resolved: `num_turns` summed, `duration_api_ms` verified cumulative and kept (Step 5)
- CHK2: Do Step 2 and Clarifications (Edge cases) agree on what happens when a background reviewer dies? — PASS
- CHK3: Is the review-in-flight check required to be read-only, given that review_join_state() deletes stamps? — PASS (AC2.1 g and i)
- CHK4: Do Steps 1 to 4 agree with R5 on serial order and on a per-commit version bump? — PASS
- CHK5: Is the allowed-list derivation defined for a direct dispatch that has no contract? — PASS (Step 3 rule 1)
- CHK6: Is the default `knowledgeWrites` value defined? — FAIL (missing) — converted to Open Question 1; resolved (a) (Step 4 rule 1)
- CHK7: Is the label that Arm B rows will carry defined? — FAIL (ambiguous) — converted to Open Question 2; resolved (b) (Step 6, OD-23)
- CHK8: Does each chosen alternative leave downgrade-only, the sensitive-path list, the reviewer per unit and the protected paths untouched in the product? — PASS (4A and 4C rejected; OD-23 overrides routing in the eval copy only)
- CHK9: Does any step change scope.sh, allowed-paths, prompts or verdict rules? — PASS (none do; OD-22 and OD-23 are operator-approved amendments)
- CHK10: Does criterion AC2.1 still fail under its own `mutation:` line, given spec2-unitB's recorded class vacuous (stop-gate-core.sh, validate.sh)? — PASS (three named mutations, each tied to a case)
- CHK11: Does criterion AC1.1 still fail under its own `mutation:` line, given gh409's recorded class vacuous/host (bin/cli.js, validate.sh)? — PASS
- CHK12: Does criterion AC1.2 still fail under its own `mutation:` line, given gh348-14's recorded class vacuous (agents/orchestrator.md)? — PASS
- CHK13: Do AC1.4, AC2.5, AC3.2 and AC4.3 still fail under their own `mutation:` lines, given mw-step1's recorded class vacuous (tests/validate.sh registration)? — PASS (each names the exit-1 mutation)
- CHK14: Does the plan state which re-pilot measurement decides success, with a command? — PASS (S1 to S8)
- CHK15 (ubiquitous-language, advisory): the plan uses "unit scope", "knowledge proposal" and "review in flight" as new terms, and uses `uniform` against the glossary's **model policy** definition. Resolved by OD-23, which makes the label true; the new terms go to the Scribe update hint.
- CHK16: Do Step 5 and Step 6 agree on the OD numbering and the order in which they append to the same two documents? — PASS (OD-22 in u5 first, then OD-23 in u6; Dispatch makes u6 depend on u5)
- CHK17: Does the OQ3 ruling as implemented match the measured data? — PASS after revision: the literal "sum `duration_api_ms`" would be wrong, so it was revised in place with an explicit correction note

## Dispatch

The finalized spec resolves to **6 units**. All six contract files are written, and each is the contract of
record:
- [aof-u1](contracts/aof-u1.md)
- [aof-u2](contracts/aof-u2.md)
- [aof-u3](contracts/aof-u3.md)
- [aof-u4](contracts/aof-u4.md)
- [aof-u5](contracts/aof-u5.md)
- [aof-u6](contracts/aof-u6.md)

Order and dependencies:
- **Product chain, strictly serial:** aof-u1, then aof-u2, then aof-u3, then aof-u4. Each touches
  `agents/orchestrator.md` and bumps the version in its own commit (R5). Each depends on the previous unit's
  PASS. aof-u4 also depends on aof-u3, because the scribe rule refers to the unit scope that aof-u3 defines.
- **Eval chain, strictly serial:** aof-u5, then aof-u6. Both append to `operator-decisions.md` and
  `docs/experiments/abtest-2026-10.md`, and OD-23 must follow OD-22. They share no code file
  (`lib/stream.py` against `arms/`), so the only reason for the order is the documents.
- **The two chains are independent.** Under the one-unit-at-a-time review invariant they still interleave one
  unit at a time. Suggested overall order: u5, u6, u1, u2, u3, u4, so the harness fixes land first.
- **Re-pilot** after all six reach PASS and are committed.

task-master: the protocol sends a plan of 6 or more units to task-master for slicing. Here the slicing and all
six nine-element contracts are already done, so re-slicing would only re-derive them. What task-master would
add is a `Suggested model` tag per unit, and the orchestrator's ladder (`.claude/bin/ladder-tier.sh` after
aof-u1) computes that tier at dispatch time anyway. Recommendation: dispatch directly from the contract files.
If the coordinator wants the protocol followed to the letter, task-master can adopt these files unchanged as
the contracts of record.

## Scribe update hint
- New glossary terms to consider for `CONTEXT.md`: **unit scope** (a unit's `## Affected files` plus the
  `.claude/` and `docs/plans/` bookkeeping), **knowledge proposal**, **review in flight** (a fresh review-join
  stamp with no verdict yet).
- Amend **model policy**: under `uniform`, Arm B's model routing is overridden in the plugin copy (OD-23).
- The draft ADR above ("Knowledge files change only inside unit scope") is for scribe to number once aof-u4 lands.
- Stale citation (marker note gate-audit-step3): CONTEXT.md:1220 `stop-gate.sh:188-198`.
- Operator-decision note, not a unit: in installed projects `session-start.sh:149` looks for
  `.claude/bin/harness-integrity.sh`, which does not exist, so the config-drift check never runs there.
  aof-u1 deliberately does not install it. Re-arming the check is a separate operator decision.
