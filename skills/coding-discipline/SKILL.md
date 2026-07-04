---
name: coding-discipline
description: >
  Apply when writing or editing code. Behavioural guardrails that reduce common
  LLM coding mistakes: silent assumptions, over-engineering, sprawling diffs,
  and "make it work" goals with no verification. Bias toward caution over speed;
  use judgment on trivial tasks.
---
Adapted from Andrej Karpathy's observations on LLM coding pitfalls
(multica-ai/andrej-karpathy-skills). Four principles:

1. THINK BEFORE CODING — state assumptions explicitly; if uncertain, ask. If
   multiple interpretations exist, name them, don't silently pick. If a simpler
   approach exists, say so. If something's unclear, stop and name it.
2. SIMPLICITY FIRST — minimum code that solves the problem; no features beyond
   what was asked, no single-use abstractions, no unrequested configurability,
   no error handling for impossible cases. If 200 lines could be 50, rewrite.
   Check: would a senior engineer call this overcomplicated?
3. SURGICAL CHANGES — touch only what you must; don't improve/refactor/reformat
   adjacent code; match existing style; mention unrelated dead code, don't
   delete it; do remove orphans your own change created. Every changed line
   traces to the request.
4. GOAL-DRIVEN EXECUTION — turn tasks into verifiable criteria ("add validation"
   → write tests for invalid inputs, then pass them; "fix bug" → write a
   reproducing test, then pass it). State a brief plan with a per-step
   verification check. Pairs with the `tdd` skill.

Working if: fewer unrelated changes in diffs, fewer rewrites from
over-engineering, and clarifying questions arrive before implementation.
