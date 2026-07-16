# R&D Spec: RL fine-tuning of a 7B coder via GRPO + QLoRA with a hybrid programmatic/LLM-judge reward

Status: Finalized draft (defaults baked in, flagged as assumptions). Open
Questions at the end mark the genuine human-preference forks — answering them
may adjust the baked defaults but does not block starting the environment and
reward-unit work.

Author: spec-master · Date: 2026-07-15 · Location: `RnD/`
Hardware target: RTX 5070 Ti (16 GB VRAM, Blackwell / sm_120) + 128 GB DDR4.

---

## Problem Statement

I want to improve the *behavior/style policy* of a small (7B) coder model —
push it toward code that compiles, is short, is documented, and reads
cleanly — without pretraining or full fine-tuning, on a single 16 GB consumer
GPU. The reward signal should be mostly cheap/deterministic, with an LLM
judge grading only the fuzzy parts (simplicity, readability). I also want a
closing-the-loop step where a judge periodically analyzes failure clusters
and steers future tasks / rubric weights. My draft mixes a training stack
(QLoRA + GRPO) with Ollama, and it is unclear where Ollama actually fits,
whether the VRAM budget is real, and what "done" means.

## Solution

A single-GPU RL fine-tuning pipeline with a clearly separated set of model
roles and a hybrid reward. The core insight from the draft holds: RL on a 7B
reshapes the policy over behaviors the model already has, so a group-relative
policy method (GRPO, no critic) over QLoRA adapters is a good fit for
verifiable, rubric-style rewards. The corrections this spec makes:

- **Ollama does not train.** Ollama (llama.cpp / GGUF) is inference-only. It
  cannot run a GRPO loop, cannot backprop through LoRA adapters, and cannot
  serve the intermediate policy inside the training step. The policy model is
  trained in a PyTorch/HF QLoRA stack (default: **Unsloth**, which wraps TRL's
  `GRPOTrainer` with memory-optimized, optionally vLLM-backed generation).
  Ollama is reserved for one confirmed role: **serving the final merged
  model** after training, where CPU+GPU layer offload over the 128 GB RAM is
  exactly what Ollama is good at. (If the task pool is later augmented with
  synthetic tasks, a local generator model could also run on Ollama, but that
  is optional and not part of v1.)
- **The 128 GB RAM helps around the loop, not inside it.** It holds the task
  pool, the judge cache, the dataset, logs, and (if needed) 8-bit optimizer
  state / CPU-offloaded optimizer — none of which is Ollama's job. Training
  activations for the policy must live in VRAM; they cannot be spilled to
  Ollama.
- **The VRAM budget is made concrete** (see Implementation Decisions) with a
  named config that fits 16 GB and explicit OOM fallbacks.
- **"Claude Code as judge" is the literal Claude Code CLI** (user's explicit
  choice), invoked programmatically per grading behind a stable
  `score(instruction, completion) -> 1..10` contract. Because the CLI is an
  agentic, per-call-slow tool rather than a batched reward API,
  batching/caching/async/subsampling mitigations are **mandatory** (see Judge
  design) and its latency/cost tradeoff is flagged explicitly, not silently.
- **Success/stopping criteria are defined** as machine-checkable metrics on a
  held-out eval set.
- **Reward-config drift from the auto-research loop is bounded** by guardrails
  (capped weight deltas, held-out non-regression gate, versioned reward
  config, human approval above a threshold).

## Model roles (the disambiguation the draft was missing)

| Role | What it is | Where it runs | Notes |
|---|---|---|---|
| **Policy** | the 7B being trained | Unsloth/TRL QLoRA in VRAM | 4-bit frozen base + trainable bf16 LoRA adapters. **Never Ollama.** |
| **Reference** | frozen baseline for KL penalty | same process, **adapters disabled** | No separate served model needed; GRPOTrainer toggles adapters to get reference logprobs. |
| **Task source** | supplies real coding instructions (+ optional code context) | offline pool **extracted from this repo's historical `lead-programmer` work** | See "Task pool" below. Frontier synthesis only as optional augmentation. |
| **Judge** | grades fuzzy rubric (simplicity/readability) | **programmatic invocation of the Claude Code CLI**, batched + cached + async | Higher latency/cost per call than an API — mitigations mandatory (see Judge design). |
| **Serving** | final merged model for use/eval | **Ollama** (GGUF + CPU/GPU offload) | This is Ollama's correct and only in-scope home. |

## User Stories

1. As the researcher, I want the policy model trained in a QLoRA + GRPO stack
   on my 16 GB GPU, so that I can do RL without renting cloud GPUs.
2. As the researcher, I want each programmatic reward component (compile,
   line-count, docstring brevity, test-pass) to be an independently
   unit-testable pure function, so that I can trust the reward before
   spending training time.
3. As the researcher, I want a hard compile gate that zeroes total reward on
   non-compiling output, so that the model is never rewarded for
   syntactically broken code.
4. As the researcher, I want the LLM judge behind a stable, batched, cached
   contract, so that judge latency and cost don't dominate step time.
5. As the researcher, I want a KL penalty against the reference model, so that
   the policy doesn't reward-hack into trivially short/degenerate code.
6. As the researcher, I want a concrete VRAM budget and named config that fits
   16 GB, plus documented OOM fallbacks, so that a training run starts instead
   of crashing.
7. As the researcher, I want a smoke-test task pool and a short run that
   proves the GRPO update increases mean group reward, so that I know the loop
   actually optimizes before committing to a long run.
8. As the researcher, I want defined success and stopping criteria on a
   held-out eval set, so that I know when the run is "working" or "done."
9. As the researcher, I want the auto-research failure-cluster step to emit a
   structured, bounded, versioned proposal, so that the judge cannot silently
   drift my reward function.
10. As the researcher, I want the final trained adapters merged and exported to
    GGUF and served via Ollama, so that I can actually run the improved model
    with CPU+GPU offload.
11. As the researcher, I want the environment validated for Blackwell/sm_120
    (recent CUDA, PyTorch, bitsandbytes), so that 4-bit kernels don't silently
    fail on a brand-new GPU.
12. As the researcher, I want any execution of model-generated code sandboxed,
    so that a test-pass reward can't run untrusted code against my machine.

## Implementation Decisions

### Stack
- **Training framework (default):** Unsloth on top of TRL `GRPOTrainer`
  (memory-optimized QLoRA, fast/vLLM-backed generation, current Blackwell
  support). Alternative: raw **TRL + PEFT + bitsandbytes**. **Out of scope:**
  hand-rolled GRPO and axolotl.
- **Base model (default):** `Qwen2.5-Coder-7B-Instruct` (strong current 7B
  coder, GQA — helps KV-cache memory). Swappable; unconfirmed by user —
  remaining Open Question 1.
- **PEFT config:** LoRA on `q_proj, k_proj, v_proj, o_proj, gate_proj,
  up_proj, down_proj`; rank **r=16** to start (alpha=32), escalate to r=32
  only if capacity-limited. Base in 4-bit NF4, adapters bf16.
- **RL algorithm:** GRPO. k=**8** completions per prompt to start (fallback 6),
  group-normalized reward as advantage, no value/critic model, KL penalty vs
  reference (adapters-off).

### VRAM budget (the concrete estimate the draft owed)
Approximate steady-state for Qwen2.5-Coder-7B, r=16, k=8, max prompt ~1024 /
max completion ~512 tokens, gradient checkpointing ON, AdamW **8-bit**
(bitsandbytes), per-step prompt batch = 1:

| Component | Est. VRAM |
|---|---|
| 4-bit NF4 base weights (+ absmax overhead) | ~5.0 GB |
| LoRA adapters + grads + AdamW8bit states (r=16) | ~0.6 GB |
| Generation KV cache (k=8, ~1.5k tok, GQA) | ~0.7 GB |
| Training activations w/ gradient checkpointing (8 seqs) | ~4–6 GB |
| Stored old/ref/policy logprobs for k completions | <0.5 GB |
| CUDA context + framework + fragmentation | ~1.5–2 GB |
| **Total** | **~12–15 GB** |

Verdict: **fits 16 GB, tight, no large headroom.** Required settings:
gradient checkpointing ON, 8-bit optimizer, seq caps as above, prompt batch
1. **OOM fallbacks, in order:** k 8→6, completion 512→384, r 32→16, disable
   vLLM fast-gen if it duplicates weights, enable optimizer/gradient CPU
   offload to the 128 GB RAM. These are documented, not discovered at crash
   time.

### Task pool (extracted from historical `lead-programmer` work)
The task pool is built **offline from this repo's real persona-system
history**, not from live frontier synthesis. I checked what is actually
durable before designing this (findings drive every choice below):

- **Durable, usable sources (verified present):**
  - `docs/plans/YYYY-MM-DD-*.md` — numbered plan steps, each with a goal,
    affected files, and acceptance criteria. This is the durable stand-in for
    the "dispatch prompt given to lead-programmer" (raw dispatch prompts are
    *not* persisted durably; plan steps are the closest durable equivalent and
    are in fact richer).
  - **Git commits** — the real code `lead-programmer` produced, linked to a
    step by commit-message convention (`Step X.Y:` / `Track N Step N.N:`
    prefixes, `Plan: docs/plans/...` and `Issue #NN` trailers).
  - `.claude/reviewed/<task-id>.pass` — first line carries the actual
    `criteria: <command(s)>` that were run — real historical acceptance
    checks, attachable best-effort.
- **Confirmed NON-durable (do not rely on):** raw subagent JSONL transcripts.
  None persist in the repo (only unrelated `eval/results.jsonl`); the
  originals live under `/tmp` and do not survive reboots. The pipeline reads
  only git + `docs/plans/` + `.claude/reviewed/`.

**One RL "task" =**
- **instruction** (the only *required* field, and the only one the reward
  needs): the plan step's text — goal + affected files + acceptance-criteria
  block — normalized into a coding instruction.
- **code context before (optional):** the pre-change state of the affected
  files (`git show <parent>:<file>`), giving the policy the same starting
  context the original `lead-programmer` had.
- **reference diff (optional, NOT ground truth):** the commit diff
  `lead-programmer` actually produced, joined via the commit-message linkage.
  It is prior *real* code, not a gold solution — see assumption below.
- **historical criteria (optional bonus):** the `criteria:` command from the
  matching `.pass` marker.

**Extraction pipeline (offline, one-time, emits a static JSON pool):**
1. Parse `docs/plans/*.md` → `(plan, step#, goal, affected_files, criteria)`
   records.
2. Walk `git log`, parse commit messages for the `Step`/`Track`/`Plan:`/`Issue`
   linkage → map each step to commit SHA(s) and diff.
3. Best-effort join `.claude/reviewed/*.pass` by task-id to attach historical
   criteria (partial join is fine; the field is optional).
4. Emit `{id, instruction, context_before?, reference_diff?, criteria?,
   provenance}` records.

**Assumptions (flagged, not silently baked):**
- **Reference diffs are prior real code, not gold solutions.** This does not
  matter for v1: the reward is compile-gate + static checks + judge, with **no
  diff-match / test-pass component** (deferred to v2), so no ground-truth
  solution is required. Reference diffs serve only as optional realism context
  or for eval-time comparison — never as a reward input.
- **No test cases are derivable** from this source (consistent with test-pass
  deferred to v2). The pool supplies realistic *instructions* (+ optional code
  context); that is sufficient for v1.
- **Scale limitation (important):** this repo currently holds ~3 plan files
  with a few dozen steps total, so the real-history pool is a **small,
  high-realism seed**, not enough alone for a full RL run. v1 trains/smoke-tests
  on this seed; to reach training scale, augment with (a) more plans as the
  repo accrues them, and/or (b) targeted synthetic tasks from the
  auto-research `request_tasks` path (optional, and where a local Ollama
  generator could re-enter). Augmentation is additive; the historical seed
  remains the anchor, tagged by provenance.
- **Linkage is convention-based.** A step with no matching commit still yields
  a valid instruction-only task; the diff/criteria fields are simply absent.

### Reward function
- Total reward = weighted sum of components, with a **hard compile gate**:
  if the completion does not parse/compile, total reward = 0 regardless of
  other components.
- Components (v1): (a) compile/parse check [gate], (b) line-count gate
  (`len(code_lines) <= 70`), (c) docstring-brevity score, (d) judge rubric
  score (simplicity/readability, 1–10 normalized to 0–1). Each is a pure
  function `f(instruction, completion) -> float` with unit tests.
- **Test-pass reward (running model-generated code)** is **deferred to v2**
  (user-confirmed): it requires a hardened sandbox. v1 rewards
  compile/parse + static gates + judge only. If enabled, execution runs in an
  isolated sandbox (container/nsjail/subprocess with no network, CPU/mem/time
  limits, ephemeral FS).
- Reward config (component weights) lives in a **versioned** file; every
  change is recorded with a version id.

### Judge contract and CLI-cost mitigations
- Interface: `score(instruction, completion) -> int in [1,10]` (normalized to
  [0,1] for aggregation). **Backend: the Claude Code CLI, invoked
  programmatically per grading** (user's explicit choice, not the Anthropic
  API). Malformed CLI output (non-JSON / missing scores) is retried once then
  clamped to a neutral score, and the event is logged.
- **Flagged risk/tradeoff (explicit, not silent):** the Claude Code CLI is an
  interactive *agentic* CLI, not a batched reward-model API. Each invocation
  pays process-spawn + agent-loop + tool-init overhead, so per-call latency
  and cost are **materially higher** than a single batched API call, and it is
  not designed for tight per-completion loops. Naive use — one CLI spawn per
  completion per step (k=8 × steps × prompts) — will dominate step time and can
  make training impractically slow. The following mitigations are therefore
  **mandatory**, not optional:
  1. **Batch many completions per invocation.** Send all k completions for a
     prompt (or a subsample) in a *single* CLI call whose prompt requests a
     JSON array of scores, one per completion — amortizing spawn/agent-loop
     overhead across many grades. Target: 1 spawn per graded prompt, not k.
  2. **Aggressive content-addressed cache** keyed by
     `hash(instruction, completion, rubric_version)` — an identical
     (instruction, completion) never re-spawns the CLI.
  3. **Async / parallel judge workers.** A small pool of CLI worker processes
     grades batches off the GRPO critical path; the step consumes scores when
     ready or from cache, so judge latency overlaps compute.
  4. **Cap grading frequency / subsample.** Run the judge only every Nth GRPO
     step and/or grade only a random/uncertainty-selected j of the k
     completions. The programmatic components (compile/line/docstring) still
     score every completion every step, so the *dense* signal stays dense —
     only the expensive fuzzy judge is subsampled.
- Observability: per-step CLI spawn count, cache-hit rate, and grading
  wall-clock are logged (feeds AC-JUDGE-PERF).

### Auto-research / closing the loop (concretization of draft step 5)
- **Trigger:** every P training steps (default P = every checkpoint / every
  N=100 steps), run on a frozen batch of the lowest-reward completions since
  the last run.
- **Output:** a structured JSON report — a list of clusters, each
  `{label, exemplar, frequency, hypothesis, proposed_action}` where
  `proposed_action ∈ {adjust_weight(component, delta),
  request_tasks(topic, n)}`.
- **Guardrails (against judge-driven reward drift):**
  1. `adjust_weight` deltas are clamped to a max magnitude per run.
  2. Any weight change is applied only if it does **not regress** mean reward
     on a **frozen held-out eval set** (auto-rollback otherwise).
  3. Changes above a threshold require **human approval**.
  4. Every applied change bumps the reward-config version and is logged.
- `request_tasks` drives the **optional augmentation generator** (synthetic
  tasks, since the historical seed pool is fixed-size) to produce targeted
  tasks hitting the identified weakness; generated tasks enter the pool tagged
  with `synthetic` provenance, distinct from the `lead-programmer-history`
  anchor tasks.

### Success / stopping criteria (was undefined)
- **Primary metric:** mean rubric reward on a held-out eval task set,
  evaluated every N steps.
- **Stop when any of:** (a) held-out reward plateaus (improvement < ε over Q
  consecutive evals), (b) KL-to-reference exceeds its budget ceiling, or
  (c) max steps reached.
- **"Working" (smoke-level):** over a short run the mean *group* reward has a
  positive linear-fit slope and KL stays bounded.
- **"Improved" (run-level):** on the held-out eval, the merged model beats the
  base model on the programmatic components (compile rate, mean line-count
  within budget, docstring score) without KL divergence.

### Serving / export
- After training: merge adapters into the base, export to GGUF, load in
  Ollama, serve a completion. This is the sole Ollama-in-loop touchpoint and
  is where CPU/GPU offload over 128 GB RAM applies.

## Testing Decisions (machine-checkable acceptance criteria)

A good test here exercises externally-observable behavior of a component
(reward value, judge contract, memory ceiling, learning signal) — not
internal wiring. Each criterion below is runnable and pass/fail.

- **AC-ENV** — `python -c "import torch;assert torch.cuda.is_available();print(torch.cuda.get_device_name(0))"`
  prints the RTX 5070 Ti; a tiny NF4 `bitsandbytes` linear forward runs
  without a kernel/sm_120 error. Pass = both exit 0.
- **AC-REWARD-UNIT** — `pytest tests/test_rewards.py`: each component is pure
  and deterministic (same input → identical score); compile-check returns
  fail on a syntax error and pass on valid code; line-count and docstring
  gates return expected values on fixtures.
- **AC-REWARD-GATE** — unit test: when compile fails, total reward == 0
  regardless of other component values.
- **AC-JUDGE-CONTRACT** — `pytest tests/test_judge.py`: `score()` invokes the
  Claude Code CLI and returns an int in [1,10]; a batched call over k
  completions returns exactly k scores from a **single** CLI invocation
  (assert subprocess-spawn count == 1, not k); malformed CLI output is
  retried-then-clamped (no exception escapes); a second identical query is
  served from cache with **zero** CLI spawns (assert spawn count == 0). The
  CLI is stubbed with a recorded fixture so the test is hermetic and offline.
- **AC-JUDGE-PERF** — with the real CLI path, a fixed benchmark grading a
  50-completion fixture via the batched+cached wrapper (a) completes within a
  configured wall-clock budget of X seconds, (b) issues ≤ ceiling CLI spawns
  (asserted: 1 per graded prompt when grading is enabled that step, 0 when
  subsampled out or fully cached), and (c) logs per-step spawn count and
  cache-hit rate. Runnable pass/fail, not "judge is fast enough."
- **AC-SMOKE-NO-OOM** — training script runs **N=20** GRPO steps on a 10-task
  smoke pool without OOM; logged `torch.cuda.max_memory_allocated()` asserted
  < 16 GB.
- **AC-LEARNING-SIGNAL** — over **M=100** steps on the smoke pool, linear-fit
  slope of mean group reward > 0 (or final-window mean − initial-window mean >
  threshold); KL-to-reference stays below its ceiling the whole run.
- **AC-KL-GUARD** — with KL enabled, mean completion length does not collapse
  below a floor over the smoke run (reward-hacking guard). A KL-disabled
  control run demonstrating the pathology is optional/documented.
- **AC-TASKPOOL-EXTRACT** — `pytest tests/test_taskpool.py`: the extractor
  reads `docs/plans/*.md` + `git log` + `.claude/reviewed/*.pass` and emits
  ≥1 task record with a non-empty `instruction`; every record validates
  against the schema; steps with a linked commit carry a `reference_diff` and
  steps without one still emit a valid instruction-only record; each record
  carries `provenance == "lead-programmer-history"`. Runs offline against the
  real repo fixtures.
- **AC-AUTORESEARCH-GUARDRAIL** — unit test: a proposed `adjust_weight` delta
  exceeding the cap is rejected; a weight change that regresses held-out
  reward is auto-rolled-back; every applied change bumps the reward-config
  version.
- **AC-EXPORT-SERVE** — after a smoke run, adapters merge, export to GGUF,
  `ollama run <model> "<prompt>"` returns a non-empty completion.

Prior art: reward components mirror standard pytest pure-function unit tests;
the smoke-run assertions follow the common "N steps, assert peak memory + loss
trend" pattern used in single-GPU fine-tuning harnesses.

## Out of Scope

- Ollama serving the *policy* during training, or Ollama as any training-loop
  component (technically impossible).
- Running untrusted model-generated code for a test-pass reward in v1
  (deferred to v2 behind a hardened sandbox — user-confirmed).
- Multi-GPU / distributed training; cloud training.
- Full fine-tuning or pretraining; teaching new knowledge (this is policy
  reshaping only).
- Hand-rolled GRPO and axolotl-based pipelines.
- A production judge service; the judge is a local batched+cached wrapper.

## Further Notes

### Spec provenance — ambiguity taxonomy scorecard (vs. original draft)
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Missing
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Missing

### Clarifications (dated; self-resolved unless marked otherwise)
- 2026-07-15 External dependencies & integrations: Q Where does Ollama fit,
  given it can't train? → A (user-confirmed): serving-only — Ollama serves the
  final merged GGUF with CPU/GPU offload; not in the training loop. Policy
  trains in Unsloth/TRL QLoRA.
- 2026-07-15 External dependencies & integrations: Q Is "Claude Code" the
  interactive CLI or a Claude API model? → A (user-chose, reversing my
  default): the **literal Claude Code CLI**, invoked programmatically per
  grade. Judge design + AC-JUDGE-CONTRACT/PERF updated; CLI latency/cost
  flagged with mandatory batching/caching/async/subsampling mitigations.
- 2026-07-15 Domain entities / data model: Q What is the task-pool source? → A
  (user-chose, replacing my synthetic-pool default): built from **real
  historical `lead-programmer` work in this repo**. Concretized into an offline
  extractor over `docs/plans/*.md` + git commits + `.claude/reviewed/*.pass`
  (raw subagent transcripts confirmed non-durable, excluded). See "Task pool".
- 2026-07-15 Domain entities / data model: Q Which base 7B? → A (self-resolved
  default, still unconfirmed by user): Qwen2.5-Coder-7B-Instruct. Remaining
  Open Question 1.
- 2026-07-15 Technical constraints & tradeoffs: Q Does the config actually fit
  16 GB? → A (self-resolved): yes at ~12–15 GB with the named config; OOM
  fallbacks documented.
- 2026-07-15 Non-functional attributes: Q Is executing model-generated code
  (test-pass reward) safe/in-scope for v1? → A (user-confirmed): deferred to
  v2; v1 uses compile/static/judge rewards only. Sandbox required if enabled.
- 2026-07-15 Completion / acceptance signals: Q What is "done/working"? → A
  (self-resolved): held-out reward plateau / KL budget / max steps; smoke-level
  = positive group-reward slope with bounded KL.
- 2026-07-15 Non-functional attributes: Q Blackwell/sm_120 support? → A
  (self-resolved): add AC-ENV to validate CUDA/torch/bitsandbytes on the new
  GPU before training.

### Constitution check (.claude/constitution.md v1.0.0)
The five principles govern the plugin codebase (bin/cli.js, version-stamped
`agents/*`/templates, mcpServers wiring, `tests/validate.sh`). This is an
R&D write-up under `RnD/` and touches none of those artifacts, so P2–P5 are
**not applicable**. P1 "Verify, don't assume" is a general discipline and
**applies to this authoring**: satisfied — the VRAM claim is a concrete
budget, and every acceptance criterion is a runnable pass/fail check rather
than a prose assertion.

### Self-check
- CHK1: Is Ollama's exact role stated and reconciled with training reality? —
  PASS
- CHK2: Is there a concrete VRAM number and an OOM fallback path? — PASS
- CHK3: Is every reward component defined as independently unit-testable? —
  PASS
- CHK4: Is the judge identity (CLI vs API) resolved with a stable contract? —
  PASS (user-chose the Claude Code CLI; contract + CLI-cost mitigations + ACs
  updated accordingly)
- CHK10: Is the task-pool source concrete and buildable from durable records? —
  PASS (offline extractor over plans + git + `.claude/reviewed/`; non-durable
  transcripts explicitly excluded; scale limitation + augmentation flagged)
- CHK5: Are success and stopping criteria machine-checkable? — PASS
- CHK6: Is the auto-research loop's drift risk bounded by named guardrails? —
  PASS
- CHK7: Is the safety of executing model-generated code addressed? — PASS
  (user-confirmed deferred to v2 with sandbox requirement)
- CHK8: Do the model-roles table and the Solution/Stack agree on what is and
  isn't Ollama? — PASS (no conflict)
- CHK9: Is the brand-new-GPU (sm_120) environment risk covered by a check? —
  PASS (AC-ENV)

### Remaining Open Questions
All four forks the user was asked (Ollama scope, judge identity, task-pool
source, test-pass deferral) are now resolved and folded into the spec above.
One minor item was never put to the user and stays as a flagged default:
1. **Base model** — default `Qwen2.5-Coder-7B-Instruct`. Confirm, or prefer
   another 7B coder (e.g. DeepSeek-Coder-7B, CodeLlama-7B)? Not a blocker; the
   pipeline is model-agnostic and this can be set at run time.

### Scribe update hint
`RnD/` is a new artifact class (research/experimentation write-ups). No
module-wiki change is needed for this document. If RnD write-ups recur,
consider a short wiki note on their naming/structure convention
(date-prefixed slug, mirroring `docs/plans/`).
