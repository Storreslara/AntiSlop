---
name: reviewer-behavior-regression-eval-spec
description: Settled decisions + 4 premise corrections for the 2026-09-11 reviewer verdict-quality eval spec (openai/evals-style registry inside eval/harness/); OQ1 (ESCALATE scope) and OQ2 (CI spend) were open at handoff.
metadata:
  type: project
---

Spec: `docs/plans/2026-09-11-reviewer-behavior-regression-eval.md` (7 units,
standard path). OQ1–OQ3 answered 2026-09-11 on the recommended defaults;
published the same day as umbrella issue #458 (`ready-for-agent`);
task-master slicing dispatched by the orchestrator, not by me. Authored on
fable at the operator's explicit override of the opus pin.

**Settled decisions (defaults the plan is drafted against):**
- Verdict-quality only: gold is PASS/FAIL; the runner sets the fixture's
  `humanReviewMode: off` so config never converts a would-be PASS into
  ESCALATE. ESCALATE/INSUFFICIENT observed = recorded mismatch. (OQ1 asks
  the human to confirm; the researcher's brief had included ESCALATE.)
- Two-layer scoring: deterministic verdict-token match first (primary
  metric), then a `--json-schema`'d LLM grader for per-defect
  identification, gated by a `reviewer-verdict.grader.v1` calibration split
  that must score 100% on every invocation or the model-graded fields null
  out and the run exits 2.
- "Variant" (persona overlay, the thing under test) is kept distinct from
  "case" (the input); a run is variant × tier × case × rep. REPS=3 with a
  majority rule.
- Raw rows stay in gitignored `eval/results.jsonl` (same file, new
  `task: reviewer-verdict`); the durable artifact is a tracked JSON under
  `eval/reports/`. Thresholds live in the registry, start `null`
  (report-only), opus floor set from the first baseline as
  floor((matched−1)/N×100)/100; sonnet never gated (it is the thing measured).
- Deterministic parts (case validator, verdict parser, summary aggregator)
  enter `tests/validate.sh`; the LLM driver and the workflow never do, and
  `hooks/hooks.json` is pinned at 12 distinct scripts.
- CI: `workflow_dispatch` + monthly schedule gated on repo var
  `BEHAVIOR_REGRESSION_ENABLED`, needs `ANTHROPIC_API_KEY`; caps $60/matrix,
  $1.50/invocation (OQ2 asks to confirm).

**Premise corrections (verified 2026-09-11 at 0a5115b):**
1. `eval/variants/` does NOT exist — the hardening spec's `inject-*`
   variants were never built. "Reuse the variant structure" = reuse
   `apply-variant.sh`'s contract, not an artifact.
2. `eval/results.jsonl` is gitignored (`.gitignore:6`); rows alone cannot
   be "data that informs thresholds".
3. `eval/` has zero merge-gate coverage (validate.sh:89 excludes it from
   npm-pack; nothing registered) — marker note unit 149.
4. `claude -p` facts measured live (haiku probe, $0.019): `--agent`,
   `--append-system-prompt-file`, `--json-schema` exist; the JSON result
   carries `modelUsage` keyed by concrete model id and `permission_denials`.
   `agents/reviewer.md` pins `model: opus` in frontmatter, so a sonnet-tier
   run must be PROVEN via `modelUsage`, never assumed from `--model`.

**Why:** the brief bundled five recommendations whose premises were partly
stale; each correction changed a step's shape (Step 2's tier-attribution
criterion, Step 5's tracked report, Step 1's validator entering the gate).

**How to apply:** if re-delegated with OQ answers, record them as dated
Clarifications lines, then publish via `to-spec` (umbrella `[spec]` issue
naming the plan doc canonical) and hand to `task-master`. If OQ1 resolves to
"include ESCALATE", add an `escalation` split under `critical` mode as a new
step rather than mixing it into `gold.v1`. See [[feedback-verify-own-criteria-nonvacuous]]
(running the criteria caught 3 defects this session: a miscounted YAML-key
pin, a mislabelled guard, a zero-case vacuity) and [[baselines-expire]].
