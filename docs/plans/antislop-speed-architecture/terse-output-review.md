# Terse-output rules for AntiSlop: review of the ASD-STE100 notes as a plan

Date: 2026-10-20. Status: review only, nothing implemented. Reviewer: agent-team architect (read-only
investigation). Evidence: `docs/plans/antislop-speed-architecture/findings.md` (pilot 4) and the raw streams
`eval/abtest/.runs/e0*_{A,B}_uniform_1/stream.jsonl` (treated as untrusted data; re-measured with a scratch
script, chars/3.9 as the token estimate). List prices from the `claude-api` skill table: Fable 5.1 $50/M
output and $0.25/M cache read; Opus 5.5 $20/M; Sonnet 5.5 $10/M; Haiku 5.5 $0.50/M. "Verified" means counted
from the streams or quoted from a file at the line given; "inference" is marked.

## Summary and verdict

**Verdict: adopt a small, folded-in output-shape rule plus a hook-side length log, after aof-u2 and the quick
wins, and expect 3-5% of Arm B's wall time and 2-4% of its cost. Do not adopt ASD-STE100 vocabulary, a
blanket "be terse" block, or any blocking length gate.** Output verbosity is real but small: every byte of
visible prose in all five B runs (112.6k chars, about 29k tokens) is worth $0.7-1.4 of the $19.14 run cost
and at most ~340 s of the 2833 s wall, and a realistic rule cuts 35-45% of it. The overhead the findings
document is calls (328 vs 45) and context re-reads (15.5M cache-read tokens), which no style rule touches.

Three things in the streams change what "terseness" should mean here:

1. **The orchestrator's largest output line is not prose; it is dispatch prompts.** Its 31 `Agent` calls
   carried 98k chars of prompt text (mean 3.6k chars per lead-programmer dispatch, 3.4k per reviewer) against
   43k chars of visible prose. At Fable output prices that is $1.3-2.5 of generated text per five runs, and
   each prompt is written again into the subagent's cache. A fixed dispatch template (script-rendered packet,
   orchestrator supplies only the unit-specific lines) saves more than any prose rule.
2. **The prompts already carry terseness rules, and the models follow them loosely.** `agents/reviewer.md:99-108`
   says a PASS is "one line naming which acceptance criteria you checked, nothing else"; the ten pilot verdicts
   average 2.4k chars (E3: a 700-char PASS paragraph followed by 1.7k chars of `Roast:` and `Ubiquitous
   language:` advisory sections, which the same file requires). `agents/orchestrator.md:9` says "synthesize
   results briefly"; the five final relays average 2.5k chars. This is the notes' "models overrate their
   compliance" point, measured in this repo. Another prompt sentence will move the number a little; only a
   mechanical measure moves it reliably.
3. **Inter-tool narration is already negligible on every model.** Across B, 69 of 328 messages carried text
   before a tool call, 2.8k tokens in total (1% of output). "Skip narration between tool calls" saves nothing
   measurable; on Fable (A: 18 of 45 messages, 23 tokens each) the notes' claim that it narrates little holds.

## Where Arm B's money goes (verified from result `modelUsage`, five runs)

| Line | Tokens | $ (list) | Share of $19.14 | Does terseness touch it? |
|---|---|---|---|---|
| Cache reads | 15.5M | ~$3.1 | 16% | Only via smaller hand-backs re-read later: 1-3% of this line |
| Cache writes + uncached input | 1.42M + ~1k | ~$8.9 | 46% | No (first-call persona prompt per dispatch, orchestrator transcript growth) |
| Output, thinking | 68.8k | $1.71 | 9% | No (effort setting, not style) |
| Output, non-thinking | 207k | $5.45 | 28% | Partly: tool inputs (code, Bash, dispatch prompts) ~72%, visible prose ~28% of streamed chars |
| of which visible prose | 29k content-tokens (58k if scaled to billed) | $0.69-1.4 | 3.6-7.2% | **Yes. This is the whole target.** |

Output tokens are 37% of B's dollars (Fable's $50/M makes the orchestrator's 107k output tokens worth $5.34
alone), so "output is a small share" is wrong in dollars but right for prose: thinking and tool input are the
bulk. Calibration caveat (verified): streamed content explains only ~50% of billed non-thinking output on every
model (Fable 1.8x, Opus 2.1x, Sonnet 2.1x, Haiku 2.4x); the remainder is unstreamed nested explorer calls,
tokenizer density on code, or thinking not reported under `thinkingTokens`. Low estimates below use streamed
chars/3.9; high estimates scale by 2.

## Visible prose by persona (verified counts; $ at the pilot model; seconds at measured 200-1000 chars/s)

| Persona (pilot model) | Prose tokens | Composition | $ low-high | Seconds | What a rule could cut (likely) |
|---|---|---|---|---|---|
| orchestrator (fable) | 11.1k | 31 text-only turn-ends 9.2k (5 true finals ~3.2k, ~26 mid-run "waiting" turn-ends ~6k); narration 2.0k (39 msgs) | $0.56-1.1 | ~145 | Finals -30% (1k); narration -1.5k; mid-run turn-ends vanish with aof-u2, not with a style rule |
| lead-programmer (sonnet) | 5.3k | 10 hand-backs, mean 2.0k chars (ready-for-review + advisory packet + "pre-resolved context" notes) | $0.05-0.1 | ~60 | Fixed-field packet, 2.0k -> ~0.9k chars: -2.8k |
| explorer (haiku) | 5.3k streamed (~7.4k incl. unstreamed) | 9 hand-backs, mean 3.2-4k chars; the most verbose per dispatch | ~$0.00 | ~30 | Cap at ~1.5k chars: -3.5k; mostly moot after qw-u5 replaces it with a script |
| scribe (haiku) | 3.8k | 8 hand-backs mean 1.3k; narration 0.6k | ~$0.00 | ~15 | -1.5k; aof-u4 already cuts dispatches 8 -> 5 |
| reviewer (opus) | 3.3k streamed (~6.2k incl. unstreamed) | 10 finals mean 2.4k chars: ~30% verdict + evidence, ~70% Roast + Ubiquitous-language | $0.07-0.12 | ~90 | Cap advisory sections at 3 bullets each: -2.4k; keep the evidence line |
| spec-master (opus) | 0.4k | 2 hand-backs | $0.01 | ~2 | nothing |
| **Total** | **29.2k (~34k)** | | **$0.69-1.4** | **~340 ceiling** | **~12k tokens likely** |

Hand-backs enter the caller's context and are re-read on every later call (`task_notification` payloads:
lead-programmer mean 2.6k chars, reviewer 3.0k, explorer 3.8k, scribe 1.9k). Summed over a run that is ~90k
chars (~23k tokens) re-read ~10-25 times: 0.2-0.5M of the 15.5M cache-read tokens (1-3%), ~$0.05-0.15.

## Question 1: realistic savings per run and the cost of the rule text

| Scenario (five runs) | Prose tokens cut | $ cut | Seconds cut | Share of B wall / B cost |
|---|---|---|---|---|
| Low (rule ignored half the time, mid-run turn-ends already gone via aof-u2) | 6k | $0.15-0.3 | ~40 | 1.4% / 1% |
| Likely (finals, hand-backs, advisory caps as in the table) | 12k | $0.35-0.8 | ~120 | 4% / 2-4% |
| High (all hand-backs at half length, finals at a third) | 18k | $0.9-1.4 | ~200 | 7% / 5-7% |
| Plus dispatch-prompt template (not prose; orchestrator output + subagent cache write) | 8k Fable tokens | $0.4-0.8 | 60-100 | +2-3% / +2-4% |

Arithmetic: $ = tokens x the persona's output price (Fable $50/M dominates: 11.1k orchestrator prose tokens =
$0.56 low, $1.1 high); seconds = chars / measured generation rate (Fable long text blocks 2-3k chars in
6-15 s, i.e. 200-500 chars/s; Opus ~270; Sonnet 250-900; Haiku 600-1000). Under aof-u6 (every persona on
Fable next pilot) every row reprices at $50/M: prose becomes $1.5-2.9, and the likely cut $0.6-1.2, but B's
total rises more, so the share stays 3-7%.

**Cost of the rule text.** The notes' six-line block is ~550 bytes (~140 tokens). Appended to every persona
and read on all 328 B calls: +46k cache-read tokens (+0.3%, ~$0.01) and +6k cache-write tokens on 39
dispatches plus 5 session starts (~$0.08). The notes' "+10% for an isolated query" does not transfer: the
persona prompts are 28-80k bytes, so +550 bytes is +0.7-2%. Net is positive in every scenario (likely +$0.3
to +0.7 per five runs). The real conflict is with qw-u3, which is cutting 1.2k bytes from each of five
full-tier mirrors: appending 550 bytes to nine personas returns ~40% of that. Fold the rule into the existing
"Answer shape" section (`templates/persona-protocol.md:41-46`, `persona-protocol-slim.md:31-36`, ~400 bytes)
instead of appending; net bytes then stay near zero.

## Question 2: which techniques apply to an agent team

| Technique (notes) | Applies? | Evidence / reason |
|---|---|---|
| Fixed output shape for hand-backs, with field names | **Yes, the best fit.** | Hand-backs are 500-1000 tokens of free prose around 5-8 facts (commit, range, test result, files, proposals). `lead-programmer.md:91-100` already names the fields but not the shape. A `key: value` block is parseable by hooks and readable by the orchestrator and a human. |
| Length caps stated as numbers | Yes, for advisory sections and explorer answers | "Terse" in `reviewer.md:99` produced 2.4k-char verdicts. "Roast: at most 3 bullets, 1 line each" is checkable. |
| "Report results only, skip narration" | Measurably useless here | 2.8k tokens across all of B (1%). |
| "No preamble, no recap, no closing offer" | Yes for orchestrator finals; cheap | Finals restate what shipped (E5: 2.8k chars incl. a process paragraph). The "two defaults you may want reversed" part is value, keep it. |
| Structured (JSON) output for machine-consumed hand-backs | No | Hand-backs are consumed by the orchestrator (an LLM) and by one regex (`STATUS:`); JSON would hurt the audit trail humans read in the streams and the relays. Fixed-field text gives the same 2-3x compression. |
| `.claude/output-styles/` | Doubtful for the main session; no for subagents | Absent in the repo and in `~/.claude`. The main session runs as `"agent": "orchestrator"` (`.claude/settings.json:2`), whose body "replaces the default Claude Code system prompt entirely" (`agents/orchestrator.md` header); whether an output style still layers onto a custom main agent is unverified. Editing `orchestrator.md` is the equivalent and is already qw-u2's job. Subagents never see output styles. |
| `--append-system-prompt` | **Yes, as the A/B knob.** | `eval/abtest/arms/common.sh:292` passes extra flags through `"$@"` after the shared set (`:18-26`). A style block can be tested on Arm B without touching a persona file or the four-copy hand-sync. |
| Effort settings | Partly done; gated by policy | `effort:` frontmatter: reviewer `high`, explorer `low`, task-master `medium`; scribe, lead-programmer, spec-master undeclared. The cost-governance plan (2026-09-23) rules judgment may raise, never lower, and excludes the reviewer. Haiku thinking was 24k tokens ($0.01); on Fable next pilot that is $1.2, so `effort: low` on scribe is worth its own ruling (inference). |
| `max_tokens` caps | Not available | No per-agent output cap exists in agent frontmatter; `maxTurns` and `bashOutputMaxChars` (input side, `templates/settings-fragment.json:4`) are the only caps. |
| Model-specific verbosity | Low relevance | Pilot reviewer and spec-master ran Opus 5.5; the reviewer's length is structural (two mandated advisory skills, `reviewer.md:10,112-127`), not a model default. Orchestrator was Fable (narration small, as the notes say) and qw-u6 moves it to Sonnet; lead-programmer frontmatter says `haiku` (`agents/lead-programmer.md`) but the pilot ran Sonnet under the tier scripts. |
| ASD-STE100 vocabulary, 20-word sentences | No | The product's prose surfaces are contracts, CHANGES.md, ADRs and glossary entries; a 900-word dictionary cannot name `reviewed-path denial` or `review-join stamp`, and "one word per meaning" is already the glossary rule (`CONTEXT.md:660-673`, `ubiquitous-language` skill) with its own vocabulary. |
| Diagrams, HTML, video rungs | No | Nothing in the pipeline reads a picture; they add tokens and cannot be grepped by hooks or pins. |

## Question 3: risks and guardrails

**Protected, machine-parsed surfaces (no style rule may alter these).** `STATUS:` last line, regex
`^STATUS: (complete|incomplete [—-] .+)$` (`persona-protocol.md:148-157`; routed on at
`orchestrator.md:85-93`); `STATUS: incomplete — checkpoint: <path>` (pinned in
`tests/persona-prose-pins.test.sh`); `Unit: <id>` as the first non-blank line of every dispatch prompt and the
non-empty contract headings (`hooks/scripts/dispatch-hygiene.sh:322,371,87`); marker first lines `PASS <unit>
<ts> commit: <sha> criteria: <detail>` and `FAIL <unit> <ts>` plus the defect block (`marker-write.sh:19-24`,
`stop-gate-core.sh:532`); `defer:|skip: <reason>` flag content (`stop-gate-core.sh:632`); the verdict word
PASS / FAIL / INSUFFICIENT-CONTEXT / ESCALATE-TO-HUMAN as the first token of a reviewer final
(`reviewer.md:99-107`); `Knowledge proposals:` and `Proposed out-of-scope changes:` report labels the
orchestrator relays by name (aof-u4; `orchestrator.md:60-61`); the `examples:` line in `.escalated` bodies and
the byte-identical `PACKET.md` (`persona-protocol.md:548-552`); RULING lines (now script-written by qw-u1,
unparsed per the quick-wins spec). Also every pinned phrase: `tests/persona-prose-pins.test.sh`,
`tests/adapter-protocol-parity.test.js`, `tests/packet-view-script.test.sh` T10,
`tests/writer-tier-consistency.test.js`, and qw-u2's planned `tests/prompt-diet-pins.test.sh`; and the
four-copy hand-sync (templates, `agents/*.md`, codex and cursor adapters).

**Free prose a rule may shape:** hand-back bodies, orchestrator relays, explorer answers, the reviewer's
advisory sections, scribe reports, narration.

**Fact and hedge loss.** The reviewer's evidence sentence ("I ran `npm test` myself... 19 of 19") is the audit
trail the findings say is the product's real value when defect catches are zero; a cap must apply to the
advisory sections, never to the criteria-evidence line, and the FAIL defect list (file:line + trigger) must
stay uncapped. Keep "unverified", "not run", "if", "unless" verbatim (the lead-programmer's "Version-stamp
check: not run, because..." is exactly the sentence a 47%-fact-loss rewrite drops). Escalation packets,
`CHANGES.md` (four fixed sections, soft cap 120 lines, "terse: short bullets", `persona-protocol.md:510-532`)
and `EXAMPLES.md` (2-4 lines per example, `:533-544`) are human surfaces that already carry their own caps;
leave them alone. ADRs and glossary entries written by the scribe follow the domain-modeling skill and the
one-term rule; a sentence-length rule there conflicts with definitions that need a qualifier clause.

**Compliance.** Prompt-only rules in this repo are followed loosely (evidence above). The notes' Vale
suggestion has no footing: no Vale config exists (`grep -rw vale` finds nothing); what the repo has is
phrase-pin tests (`tests/persona-prose-pins.test.sh`) and `hooks/scripts/lint-on-edit.sh` (file lint on
Write/Edit, not on messages). The enforceable point is the `SubagentStop` hook input, which carries
`last_assistant_message` (quick-wins spec, "Hook facts"). A length counter there must **log, never block**:
every new blocking gate recreates the churn of finding 3 (6 exit-2 Stops, 10 denied writes, 31 text-only
turn-ends), which cost far more than any prose.

## Question 4: variations

| # | Variation | Saving (5 runs) | Risk | Effort | Testable on the harness |
|---|---|---|---|---|---|
| i | Shared "Output shape" rule folded into the protocol's Answer shape section (replace, not append) | 6-12k prose tokens, $0.2-0.8, 40-120 s | low if folded; byte giveback vs qw-u3 if appended; four-copy sync | S (but touches every mirror and adapter) | yes: prose chars per persona from streams |
| ii | Per-persona hand-back templates with named fields and numeric caps; SubagentStop logs length overruns to `.claude/output-length.log` | 8-12k tokens, 60-120 s; plus 1-3% cache reads | fact loss if the cap hits the evidence line; a blocking variant recreates churn | M | yes: hand-back chars per persona, overrun count, `review_fail_cycles` |
| iii | Output-style file or `--append-system-prompt` for the main session only | 2-4k tokens, 20-40 s on finals and narration | output-style may not apply under a custom main agent (unverified); after qw-u6 the orchestrator is Sonnet, cheaper per token | S | yes, as a flag-only arm variant |
| iv | Hook-side compaction: scripts produce the evidence (qw-u1 bookkeeping, qw-u5 blast-radius, variation f pre-check), personas emit short verdicts; dispatch prompts rendered from a template | the dispatch-prompt line (8k Fable tokens, $0.4-0.8, 60-100 s) plus whatever prose shrinks when there is less to narrate | low; the reviewer must still re-derive | M (mostly already planned) | yes: Agent prompt chars, orchestrator output tokens |
| v | `effort: low` on scribe (explorer already has it); nothing on the reviewer | ~0 at Haiku prices; ~$1 per 5 runs once scribe runs on Fable (aof-u6) | lower-quality glossary edits; needs a ruling under the cost-governance never-lower rule | S | yes: thinking tokens per model |
| vi | Do nothing on style | 0 | none | 0 | n/a |

Composition: iv is the backbone and is already in flight (qw-u1 landed; qw-u5 contracted); ii and v compose
with it and with aof-u2/u3/u4; i is a cheaper, weaker ii and conflicts with qw-u2/u3 only on bytes; iii is
the measurement instrument for i and ii, not a shipping path. vi is right for narration and for ASD-STE100.

## Question 5: recommendation, ordering, measurement

1. **Now, nothing in persona files.** Let aof-u2 (removes the mid-run turn-ends that hold ~6k of the
   orchestrator's 11k prose tokens) and the quick wins land first; they move the numbers the rule would be
   measured against. Predicted: the planned stages' ratios are unchanged by this decision.
2. **During the quick wins: measure before writing.** Add one harness-only arm variant that passes
   `--append-system-prompt` with a 6-line shape block (iii) and a stream-side metric for prose chars per
   persona, hand-back chars per dispatch and Agent-prompt chars. Cost: a harness change, no gate, no pins.
   This also proves or refutes the compliance point at N>=3 before any template is written.
3. **After the quick wins, with the structural stage: ii + iv.** Hand-back templates with numeric caps for
   lead-programmer, explorer, scribe and the reviewer's advisory sections (evidence line and FAIL list
   uncapped); a script-rendered dispatch packet so the orchestrator writes only the unit-specific lines; a
   SubagentStop length log. This belongs with the structural stage because variation f (mechanised
   pre-review) and the fast path change what the hand-backs must contain.
4. **Rule a scribe `effort: low` exception now** if aof-u6 ships every persona on Fable; it is the one
   style-adjacent lever whose value jumps with that change.
5. **Skip:** ASD-STE100 vocabulary, Vale, narration rules, JSON hand-backs, any blocking length gate.

**Predicted effect on B/A (inference from the arithmetic above).** On pilot-4 numbers alone: wall 7.8x ->
~7.4x, cost 4.8x -> ~4.6x, cache-read 11x -> ~10.8x. Stacked on the quick-win stage (findings: ~1650 s,
4.5x; ~$13, 3.3x): ~1530-1560 s (4.2-4.3x), ~$12.3 (3.1x). It cannot by itself move any stage's ratio by
more than ~0.3x.

**A/B design.** Same five evals, same harness, same model policy, N>=3 per arm; arms B (current) and B'
(B plus the style block via `--append-system-prompt` in step 2; via the templates in step 3). Primary
metrics, from `results.jsonl` and the streams: visible prose tokens per persona, hand-back chars per
dispatch, orchestrator output tokens, `persona_tokens`, wall per eval. Non-regression gates: every
`kind: defect` and `scope` check unchanged; `review_fail_cycles` unchanged; every reviewer final still starts
with a verdict word and ends with a valid `STATUS:` line (grep over streams); each PASS final still names
every acceptance criterion it checked (count criterion ids against the contract); hedge tokens ("not run",
"unverified", "if", "unless") per hand-back not reduced; the blind E1 judgment grade (`eval/abtest/blind.sh`)
unchanged. Success is a prose cut of 30% or more on hand-backs with zero gate regressions; a cut below 15%
at N=3 means the model ignored the rule and the template-plus-log path (ii) is the only one left.

## Caveats

- N=1 per eval in pilot 4; the per-persona seconds use block timestamps and generation-rate ranges, not
  per-message token counts (the stream carries only `message_start` usage, 7-16 tokens per block).
- The 2x gap between streamed content and billed non-thinking output is unexplained; the low estimates are
  the only ones fully grounded in visible text.
- `docs/plans/antislop-structural/` did not exist at review time; the interaction with variation f and the
  fast path is inferred from the findings' solution table, not from a spec.
- Whether Claude Code output styles apply when `settings.json` names a custom main agent was not verified.
- Costs are list prices; the Max plan bill differs.
