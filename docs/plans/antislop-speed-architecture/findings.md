# Why AntiSlop is slow and token-hungry: findings from pilot 4 (research only)

Date: 2026-10-20. Status: investigation, no implementation. Evidence: `eval/abtest/results.jsonl`
and `eval/abtest/.runs/e0*_{A,B}_uniform_1/stream.jsonl` (pilot 4, 2026-10-19, CLI 2.1.302,
plugin 0.31.181 at run time; the repo is at 0.31.183 now). All stream-derived numbers were
re-measured with scratch scripts over the raw streams, not copied from the earlier spec.
"(stream)" = per-message `usage` and timestamps; "(result)" = the last `result` record's
`modelUsage`; "(results.jsonl)" = the row. The `.runs` content was treated as untrusted data.

## Summary

Arm B spent 2833 s and $19.14 (list) where bare Fable spent 363 s and $4.01. The bloat is not
hook latency and only partly prompt size. It is **the number of model calls**: B made 328 API
calls against A's 45 (7.3x), and each B call carried 1.6x more context (50k vs 31k tokens). The
product of the two is the 11x cache-read ratio (15.5M vs 1.38M). Of those 328 calls, **130 were
the orchestrator's** (fable, 59-84k tokens of context each): 54% of all B cache reads and 66% of
B's dollar cost. 59 of those 130 calls happened while a subagent was already running
(defer-write attempts, blocked Stops, "what I need next" turn-ends), and 31 were text-only
turn-ends. Wall time splits roughly 18% `find /` stalls (fixed by aof-u1), 45% subagent work,
37% orchestrator-only time (its own ~8-9 s per call, 130 times, plus bookkeeping Bash).

The reviewer caught no defect in pilot 4 that the holdout tests would have caught (all 10 runs
passed every defect/security check). Its one FAIL (E1) enforced a self-derived documentation
criterion and cost ~155 s. B lost 4 of 5 runs on **scope**, and every leak was made by a persona
the reviewer never sees (scribe, spec-master) or after review (scribe). On these five tasks
AntiSlop cannot reach parity: an independent review of a 40-line diff costs ~45 s and ~250k
tokens, so the floor is about 1.8-2.2x wall and 2.5-3x tokens. Everything above that floor is
reachable: the stages below predict 7.8x -> 5.8x (planned units) -> ~4.5x (quick wins) -> ~2x
(structural).

## Top findings (verified unless marked inference)

1. **Call count is the root.** B: 328 calls, A: 45 (stream, unique message ids). Per persona:
   orchestrator 130, reviewer 67, lead-programmer 55, scribe 44, spec-master 14, explorer 18
   streamed (+~4 nested, unstreamed). Average context per call: A 31k, B 50k (orchestrator
   59-84k, reviewer 43-48k, lead-programmer 34-39k, scribe 31-36k, explorer 21k).
2. **The orchestrator is the single largest cost centre.** 8.42M of 15.5M cache-read tokens
   (54%), $12.63 of $19.14 (66%, result `costUSD` on `claude-fable-5-1`). It alone costs three
   times all of Arm A. Median gap before an orchestrator call: 5-10 s; mean 8-17 s (stream,
   previous event to its next message).
3. **Orchestrator churn while waiting.** 59 of 130 orchestrator calls (4.34M context tokens, 28%
   of all B cache reads) ran while a subagent was in flight. Seen in every run: 10 denied
   `defer:` writes ("sensitive file"), 6 `Stop` exit-2 blocks, 31 text-only turn-ends
   (E1 8/27, E2 5/19, E3 5/15, E4 4/16, E5 9/53). Each turn-end starts a new main-session
   segment (3-8 `result` records per B stream) and re-reads 50-84k tokens on wake-up.
4. **Stalls: 506 s = 18% of B wall.** `find /` hit the 120 s Bash timeout in E1 (orchestrator,
   t+31..152; reviewer, t+466..603, `find / -name heavy-trigger.sh`), E2 and E5 (orchestrator).
   Fixed by aof-u1 (commits 68235153, 895f5427).
5. **Hook latency is negligible; hook semantics are not.** Tool-call round-trip medians
   (stream, tool_use to tool_result): Edit 0.08 s in both arms (B runs 4 pre + 4 post scripts),
   Write 0.07 s B vs 0.15 s A, Bash 0.28 s B. Hook scripts cost well under 1% of wall. But the
   stop-gate's "block Stop while a flag stands" plus the headless refusal of the `defer:`
   write produced the churn in finding 3 (aof-u2 addresses it; not yet implemented).
6. **Prompt size is a 1.6x multiplier, not the root.** Installed prompts (fixture copy, bytes):
   orchestrator 79.5k, task-master 47.4k, spec-master 46.3k, reviewer 44.4k, lead-programmer
   28.2k, scribe 14.7k, explorer 8.0k. The inlined protocol block is 20.2-24.2k bytes in each
   full-tier persona (5.8k slim); repo sources are `agents/*.md` 158k total and
   `templates/persona-protocol.md` 60k. First-call cache creation (stream): orchestrator 40.0k
   tokens (A's main session: 22.2k), spec-master 40.6k, reviewer 34.3k, lead-programmer 31.7k,
   scribe 27.6k, explorer 16.6k. So a persona adds 5-18k tokens over the ~23k Claude Code
   baseline, re-read on every call. Nobody read `.claude/persona-protocol.md` at runtime (0 Read
   hits across B streams); inlining works as designed.
7. **Mandatory per-unit ceremony.** E5 per-unit cadence (lead-programmer dispatch to the next):
   155, 143, 97, 141 s; A finished the whole 5-unit feature in 165 s. Per unit the orchestrator
   makes 2 Bash bookkeeping calls (tier script, rulings ledger, marker/flag verification), 3
   dispatches and 2-4 text turns (~10 calls, ~0.8M context tokens per unit). The reviewer
   spawned a nested explorer in 8 of 10 reviews (10-25 s each, on the critical path), per
   `agents/reviewer.md:18-22,83`.
8. **Model tiering helped cost, hurt labels.** Rows labelled `uniform` ran sonnet (lead-
   programmer, 2 reviews), opus (reviewer, spec-master), haiku (scribe, explorer). Opus total
   $4.75 (25%), sonnet $1.67, haiku $0.09. Sonnet reviews took 21-34 s vs 45-81 s on opus for
   the same ~45k tokens (E5). The scribe is 11% of E5 cache reads (0.96M) and ~22% of the
   in+out+cache-write metric, but $0.06 of $8.31 because it ran on haiku. aof-u6 (landed) puts
   every persona on Fable next pilot, which will raise B's per-subagent cost.
9. **Where value was absent.** Defect/security checks: 10/10 runs pass. Scope check: B failed
   E1 (2 lines, scribe README), E2 (17, scribe CONTEXT.md), E3 (9, lead-programmer CONTEXT.md +
   scribe ADR), E5 (5, spec-master + scribe CONTEXT.md); A failed E3 only. The reviewer PASSed
   E3 with the CONTEXT.md edit in the diff and never sees scribe or spec-master writes.

## Numbers

### Table 1: per eval (results.jsonl; tokens from the result `modelUsage`)

| Eval | A wall s | B wall s | ratio | A calls | B calls | B dispatches | A cache-read | B cache-read | A $ | B $ | B outcome |
|---|---|---|---|---|---|---|---|---|---|---|---|
| E1 | 47 | 742 | 15.8 | 5 | 52 | 7 (LP 2, rev 2, expl 2, scribe 1) | 115k | 2.40M | 0.61 | 3.69 | scope FAIL; 1 review FAIL |
| E2 | 40 | 399 | 10.0 | 5 | 33 | 4 | 114k | 1.35M | 0.51 | 3.09 | scope FAIL |
| E3 | 52 | 265 | 5.1 | 6 | 39 | 4 | 166k | 1.59M | 0.78 | 2.14 | scope FAIL (A too) |
| E4 | 56 | 271 | 4.8 | 6 | 36 | 4 | 157k | 1.58M | 0.67 | 1.91 | pass |
| E5 | 169 | 1156 | 6.8 | 23 | 168 | 20 (spec 2, LP 5, rev 5, expl 3, scribe 5) | 828k | 8.58M | 1.44 | 8.31 | scope FAIL |
| Sum | 363 | 2833 | 7.8 | 45 | 328 | 39 | 1.38M | 15.5M | 4.01 | 19.14 | |

B billed metric (in+out+cache-write): 1.70M vs A 146k (11.6x). B cache-write 1.42M vs 120k;
output 276k vs 25k. Diff size B/A (lines added, non-doc): 37/53, 46/78, 15/12, 52/54, 246/215.
Per line of code on E5: B $0.034 and 4.7 s, A $0.007 and 0.8 s. Lead-programmer time barely
tracked size (26-43 s per E5 unit of 30-60 lines): the cost is per hop, not per line.

### Table 2: wall-time phases, Arm B (stream spans, seconds)

| Eval | span | orientation before 1st dispatch (excl. stall) | `find /` stalls | subagent busy (union, excl. stall) | orchestrator-only, non-stall | tail after last subagent |
|---|---|---|---|---|---|---|
| E1 | 718 | 63 | 261 (124 orch + 137 reviewer) | 213 | 243 | 20 |
| E2 | 386 | ~75 | ~120 | 102 | ~165 | 22 |
| E3 | 260 | 65 | 0 | 124 | 136 | 21 |
| E4 | 262 | 16 | 0 | 150 | 113 | 24 |
| E5 | 1150 | ~70 | ~125 | 651 | ~375 | 19 |
| Sum | 2776 | ~290 | ~506 (18%) | ~1240 (45%) | ~1030 (37%) | 106 |

"Orchestrator-only" is wall time with no subagent in flight; minus Bash execution time it is
model latency: (367-139)/27 = 8.4 s per call in E1; 8.4 E2; 8.5 E3; 6.9 E4; 6.9 E5.

Per-dispatch spans (dispatch to the subagent's last message): lead-programmer 23-65 s;
reviewer 45-81 s on opus, 21-34 s on sonnet (E1 re-review 183 s incl. the 137 s stall);
scribe 14-60 s; spec-master 172 + 52 s (checkpoint re-dispatch); explorer 22 s top-level,
10-25 s nested.

Fixed per run (B, stalls removed): ~60 s orientation + ~20 s tail + first-call cache writes
(orchestrator 40k, each persona 28-41k tokens). Per unit: lead-programmer 25-65 s, orchestrator
verify/tier/ledger/dispatch 20-40 s (2-4 calls), reviewer 45-80 s (opus, with nested explorer),
orchestrator post-review 15-30 s, scribe 15-40 s (overlapped with the next unit in E5):
135-250 s per unit; the measured E5 cadence is 97-155 s because scribe overlapped.

### Table 3: tokens and cost by persona, all five B runs (stream attribution; cost by model)

| Persona | calls | cache-read | share | cache-write | ctx/call | model(s) | cost (by model) |
|---|---|---|---|---|---|---|---|
| orchestrator (main) | 130 | 8.42M | 54% | 257k | 59-84k | fable | $12.63 (66%) |
| reviewer | 67 | 2.67M | 17% | 338k | 43-48k | opus (8 reviews), sonnet (2) | opus total $4.75, incl. spec-master |
| lead-programmer | 55 | 1.72M | 11% | 284k | 34-39k | sonnet | sonnet total $1.67, incl. E2 scribe and 2 reviews |
| scribe | 44 | 1.28M | 8% | 259k | 31-36k | haiku (4 runs), sonnet (E2) | haiku total $0.09, incl. explorer |
| spec-master | 14 | 0.66M | 4% | 105k | 47-55k | opus | (in opus) |
| explorer | 18+ | ~0.34M+ | 2%+ | ~153k | 21k | haiku | (in haiku) |

Orchestrator calls split: 71 with nothing running (4.3M ctx), 59 while a subagent ran (4.34M
ctx). E1 alone: 11 churn calls between dispatching the reviewer and receiving its verdict.

### Table 4: hook invocations per tool call (`hooks/hooks.json`) and measured latency

| Event | scripts | pilot count (E5) | measured round-trip |
|---|---|---|---|
| PreToolUse Bash | reviewed-path-gate, human-decision-gate, harness-integrity-gate | 115 records / 115 calls | Bash median 0.28 s incl. the command |
| PreToolUse Write/Edit | protected-paths, reviewed-path-gate, human-decision-gate, harness-integrity-gate | 56 / 14 calls | Edit median 0.08 s (A: 0.08) |
| PostToolUse Write/Edit | graph-update, lint-on-edit, microworld-rerun, harness-integrity-gate | 56 / 14 | (included above) |
| PreToolUse Agent | reviewer-route-gate, dispatch-hygiene | 40 / 20 | Agent median 0.3 s |
| Stop / SubagentStop | stop-gate | 9 + 21 | 6 exit-2 across the 5 runs |

## Root-cause ranking (share of B overhead above A; confidence)

1. **Hop and turn multiplication (orchestrator as a reasoning layer, background dispatch plus
   wake-up, stop-gate churn): ~55% of tokens, ~35% of wall.** High confidence: directly counted
   (130 orchestrator calls, 59 while waiting, 31 text-only turns, 6 exit-2, 10 denials).
2. **Mandatory per-unit ceremony regardless of size (spec-master on a 5-unit feature, nested
   explorer in 8/10 reviews, scribe per unit, tier script + ledger + verification per unit):
   ~20% of tokens, ~25% of wall.** High confidence on the counts; medium on the share, because
   ceremony and hops overlap.
3. **`find /` stalls: 18% of wall, ~3% of tokens.** High confidence; already fixed (aof-u1).
4. **Context size per call (persona + protocol block, growing orchestrator transcript): a 1.6x
   multiplier on everything above, ~15-20% of tokens in isolation.** High confidence on sizes;
   the orchestrator's growth (35k -> 84k per call in E5) is transcript, not prompt.
5. **Model tiering: the opus reviewer is 25% of cost but ~10% of wall; the haiku scribe is
   nearly free.** Tiering as shipped reduced cost; the fable orchestrator is the expensive
   choice. Medium confidence (list prices, mixed tiers).
6. **Serial-only dispatch: <10% of wall on this pilot** (only E5 has several units, and they
   shared `src/server.js` and `src/store.js`). Medium confidence.
7. **Hook execution latency: <1%.** High confidence.

## Where the overhead buys value, and where it is ceremony

- Independent review: zero defect catches in pilot 4 (10/10 defect checks pass in both arms).
  The E1 FAIL enforced "each ASSUMPTIONS.md bullet cites README/CONTEXT or is flagged as a
  judgment call", a criterion the orchestrator derived; the eval's own `assumptions-file-present`
  check passed before the fix. The re-review cost 2 dispatches, ~155 s (plus a 137 s stall) and
  ~$1. Verdict: the Writer/Reviewer split showed its mechanism works (FAIL -> fix -> PASS, markers,
  join stamps) but changed no outcome. Inference: on tasks where bare Fable is already at 100%
  on holdouts, a reviewer can only add cost; the value question needs riskier tasks (below).
- Scope control: this is the one property B lost on, and the reviewer is structurally unable
  to protect it: scribe runs after PASS, spec-master before any unit, and neither is reviewed.
  The holdout `scope.sh` check is mechanical and caught all four leaks; the opus reviewer saw
  one (E3) and passed it. aof-u3/u4 fix this by prose; variation (f) fixes it by script.
- Spec-master on E5: 224 s and 0.77M tokens produced five contracts for a feature A built in
  165 s with 215 lines. The contracts kept lead-programmer prompts short (2.0-2.9k chars) and
  gave the reviewer criteria: real value on larger work, pure overhead here.
- Rulings ledger, tier script, marker verification: 2 Bash calls per unit, each a full
  orchestrator call (~60-80k tokens, ~8 s). The information is mechanical; the LLM is the
  wrong executor.
- Scribe: README/CONTEXT/ADR edits nobody asked for, in 4 of 5 runs. Ceremony here; value only
  where a plan or tracker issue needs closing.

## Solution variations (structurally different; savings estimated against pilot-4 totals)

Baseline for the arithmetic: B 2833 s, 15.5M cache-read (cr), $19.14; A 363 s, 1.38M, $4.01.
"Orch call" = ~8 s and ~65k cr tokens.

| # | Variation | Mechanism | Est. saving (wall / cr tokens / $) | Guarantee kept or weakened | Effort | Risk | Measure with the A/B harness | Depends on |
|---|---|---|---|---|---|---|---|---|
| P0 | Planned units aof-u2, u3, u4 | Stop allowed during review (no `defer:` write); unit scope in every dispatch; knowledge proposals; scribe once per plan | u2: -16 orch calls (10 denials + 6 exit-2) = -130 s, -1.0M; u4: scribe 8 -> 5 dispatches = -100 s, -0.7M; u3: 0 time, removes 3 scope leaks | Stricter stop gate (stamp expiry); reviewer gains a scope FAIL ground | M (contracted) | low | S1-S8 in the spec | u1 landed |
| a | Size/risk-routed fast path | A script (`unit-size.sh`: files, lines, sensitive paths, reusing reviewer-tier.sh's rules) picks a lane at dispatch: small+safe = no spec-master, no pre-explorer, lead-programmer then one reviewer fed the mechanical packet (f); medium = today's chain; large or sensitive = full pipeline | E5 skips spec-master: -300 s (224 + orch handling), -0.77M, -$0.8; E1-E4 orientation collapsed to one call: -40 s each; total ~-460 s, -1.2M | Keeps an independent review for every unit; weakens only planning depth on small units; the lane choice must be downgrade-only (same rule as reviewer-tier.sh) | M | medium: a misclassified unit skips a spec it needed | spawn counts per eval; wall; defect checks unchanged | u1 (helpers in `.claude/bin`), u3 (`## Affected files` as the size input) |
| b | Prompt diet | orchestrator 79.5k -> ~25k bytes (routing table, pipeline, gate rules; incident narratives such as `agents/orchestrator.md:191-195` move to docs); protocol block 20-24k -> ~6k with per-section lazy `Read` on demand; reviewer 44k -> ~20k; rules that are mechanical (unit-id grammar, marker format, tier arithmetic) live in hooks only | ~-14k ctx per orch call x 130 and ~-5k x 198 subagent calls = -2.8M cr (-18%); cache-write -6k x 39 dispatches = -230k; wall -3-5% (TTFT) | None if deletions are duplicates or dead text (gh348 discipline); the risk is dropping a live rule | M-L (four-copy hand sync, adapters) | medium | ctx/call per persona from streams; first-call cache creation | none; cannot fix the call count alone |
| c1 | Reviewer absorbs explorer | The reviewer gets `git diff --name-only` plus a `callers.sh` (grep or graph) result in its packet; it spawns explorer only when the packet is empty | 8-11 nested dispatches x 10-25 s = -200 s; -0.5M | Independence unchanged (script output is evidence; the reviewer still re-derives) | S | low | nested spawn count; reviewer span | conflicts with the protocol's "always re-derive via explorer" (4C in the spec); needs an operator ruling |
| c2 | Bookkeeping hook | lead-programmer's SubagentStop runs reviewer-tier.sh and ladder-tier.sh, writes the ledger line and a `review-packet.<unit>` file; the orchestrator reads one file and dispatches | -2 orch calls per unit x 10 = -20 calls = -170 s, -1.3M, -$1.5 | Gate unchanged; the ledger becomes machine-written (purer) | M | low | orch calls per unit | u1 |
| c3 | Unit runner | One dispatch per unit runs lead-programmer then reviewer in sequence inside a thin runner agent (foreground, nested) and returns the verdict; orchestrator calls per unit ~10 -> ~3 | -50 idle-path orch calls = -400 s, -4-6M cr, -$6 | Writer/Reviewer split kept (separate agents, separate contexts); the orchestrator stops being "single owner" of review routing; route gate and join stamps must key on the runner's dispatch | L | medium-high: nested-depth streaming and limits; marker privileges granted by agent identity | result-record count, orch calls, wall | replaces part of u2's semantics |
| d | Parallel units / overlapping review | Dispatch independent units concurrently (per-unit join stamps already support concurrent reviewers); start the next unit's lead-programmer while the previous review runs | E5 only: ~-250 s if units 3-5 were independent (they shared files, so more like -100 s); E1-E4: 0 | Weakens the "one unit, one review" ordering; merge-conflict risk; reviewer-route-gate blocks it by design today | M | medium | E5 wall; conflicts | u3 (scope lists decide independence) |
| e1 | Sonnet reviewer for small, non-sensitive diffs | Stop counting test lines in reviewer-tier.sh (spec alt 4A); keep the sensitive-path and downgrade-only rules | E1, E2 flip: -2 x 30 s, -$1.0; E4 stays opus (security) | A measured threshold is relaxed; the spec rejected it pending evidence | S | low-medium | tier printed vs defects escaped | none |
| e2 | Cheaper orchestrator | Run the main session on sonnet (the router relays and bookkeeps; the gate is the reviewer) | fable share $12.63 -> ~$3-4 (-45% of B cost); ~-3 s per call x 130 = -400 s (inferred from sonnet vs opus review latency) | No gate sits on the orchestrator; the risk is routing quality | S | medium | cost, wall, routing errors | aof-u6 must allow a per-persona exception under `uniform` |
| e3 | Cache friendliness | Stable prefix order (persona body before volatile dispatch text), 1h TTL on every persona (the reviewer has it), avoid per-segment cache re-creation | cache-write 1.42M -> ~0.9M; small wall gain | none | S | low | cache-write per run | none |
| f | Mechanised pre-review | `review-precheck.sh` at lead-programmer SubagentStop: test and lint exit codes, `git diff --name-only` vs `## Affected files`, diff size, sensitive paths, the criteria commands; writes a signed packet; the reviewer FAILs on packet failures without reading, and reads code only for judgment | reviewer tool calls 8-13 -> 4-6: -25 s x 10 = -250 s, -0.8M; catches all 4 pilot scope leaks mechanically (if scribe and spec-master writes are inside the checked range) | Strengthens: deterministic checks cannot be rubber-stamped; the reviewer stays independent | M | low | scope-check pass rate; reviewer span | u3 (scope list); supersedes u3's prose rule |
| g1 | Review as a post-hoc batch audit | lead-programmer runs all units of a plan; one reviewer audit over the whole range; FAIL -> targeted fix contracts | E5: 5 reviews -> 1: -4 x (55 + 30) = -340 s, -1.5M; E1-E4: 0 | Weakens the per-unit gate (late defects cost more); keeps independence | M | medium | review count; defects escaped | conflicts with reviewer-route-gate's one-unit invariant |
| g2 | Writer self-verification + cheap verifier | lead-programmer emits a verification packet (f); a haiku or sonnet verifier checks the packet against the evidence; opus reviewer only on verifier doubt or sensitive paths | reviewer cost -60% ($4.75 -> ~$2), -30 s per unit; tokens -1.5M | Weakens: the verifier is not adversarial; keep opus for sensitive paths | M | medium-high | defects escaped on riskier evals | f |
| g3 | Writer-as-main, review forced by the gate | Drop the orchestrator hop: the main session is the lead-programmer (as in Arm A) with `coding-discipline`; the Stop hook blocks until a PASS marker exists; the reviewer dispatch prompt is generated by a script from the unit id and range, and `reviewer-route-gate.sh` verifies the prompt equals the template | B -> ~A + reviews: 363 + 10 x ~50 s + ~100 s = ~1000 s (2.8x); cr ~1.4M + 10 x 0.3M = ~4.4M (3.2x); cost ~$9 | Keeps separate contexts and the marker gate; weakens "the writer never spawns the reviewer" (mitigated by the templated, gate-verified dispatch); loses spec-master and task-master unless invoked on demand | L | high: the biggest change to the protocol and to every gate's identity assumptions | a direct A/B: B' vs A | replaces u2; keeps u3/u4 |

Compatibility: b, c1, c2, e1, e2, e3, f and P0 are mutually compatible and compose with a. c3,
g1 and g3 are alternative architectures (pick one); a composes with c3 or g3 as the routing
layer. d conflicts with the one-unit-one-review invariant and with g1. g2 is f plus a cheaper
reviewer tier and can be one lane inside a.

## Recommendation

1. **Now (contracted): aof-u2, u3, u4.** Predicted B/A after this stage: wall ~2100 s (5.8x),
   cr ~13.8M (10x), cost ~$17 (4.2x). The -506 s of stalls are already landed.
2. **Quick wins (S/M, no gate change): c2 bookkeeping hook, c1 reviewer packet with scripted
   callers, e3 cache hygiene, b prompt diet.** Predicted: wall ~1650 s (4.5x), cr ~9.5M (7x),
   cost ~$13 (3.3x). e1 (sonnet on small diffs) and e2 (sonnet orchestrator) are the cheapest
   dollar wins (-$1 and -$8) but each needs an operator ruling on the tier rules.
3. **Structural: a (fast path) + f (mechanised pre-review) + one of c3/g3.** Predicted:
   wall ~600-800 s (1.7-2.2x), cr ~2.5-3.5M (2-2.5x), cost ~$6-8 (1.5-2x). This is the floor.
4. **Not worth doing for small tasks: d (parallelism), g1 (batch audit).** They pay only on
   multi-unit plans, and g1 trades the per-unit gate for speed.

**Floor and break-even.** On a 40-line task bare Fable needs 5-6 calls and 115-166k cr. One
independent review needs 4-8 calls at 35-45k each (~250k) plus ~45 s. So B stays at or above
~2x wall and ~2.5-3x tokens on tiny tasks unless review is skipped, which removes the product's
only hard guarantee. Break-even is where bare Fable's defect rate times the cost of an escaped
defect exceeds ~$2-4 and 1-2 minutes per unit. Pilot 4 cannot show that: A scored 100% on every
defect and security check, and B's one FAIL was documentation. To test it, measure (without
designing the full eval here): tasks of 3-8 files and 200-600 changed lines with at least one
hidden cross-module invariant and one security-sensitive path; A's defect rate per eval at
N >= 3 reps; `review_fail_cycles` with the defect class each FAIL cited; and defects escaped per
arm. If A's defect rate on such tasks stays near zero, the product's value case is scope and
audit trail, not correctness, and f (mechanical) delivers both at ~1.3x.

## Caveats and unverified items

- N=1 per eval; E1's 15.8x includes two stalls; medians would be fairer than sums.
- Arm B `uniform` rows were mixed-tier (haiku/sonnet/opus/fable); aof-u6 changes this for the
  next pilot, and the cost shares in Table 3 will move (scribe and explorer get much dearer).
- Costs are list prices (`costBasis: list`), not the Max-plan bill.
- Nested explorer calls under the reviewer are not streamed in E1/E2 (visible only in haiku
  totals); subagent spans end at the subagent's last streamed message, so orchestrator wake-up
  latency (~5-25 s per dispatch) is counted as orchestrator-only time.
- Hook latency is inferred from tool round-trips, not from timing the scripts in isolation;
  the `hook_started` record count for Bash (1 per call, not 3) is unexplained.
- Savings for c3 and g3 are extrapolations from call counts, not measurements; both would
  change gate identity assumptions (`persona_matches_grant`, review-join stamps) that were not
  traced.
- `tests/validate.sh` speed (the validate-speed plan) is internal-only and in no eval run.
