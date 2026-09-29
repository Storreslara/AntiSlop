---
name: coding-discipline
description: >
  Apply when writing or editing code. Behavioural guardrails that reduce common
  LLM coding mistakes: silent assumptions, over-engineering, sprawling diffs,
  and "make it work" goals with no verification. Bias toward caution over speed;
  use judgment on trivial tasks.
---
Seven principles:

1. THINK BEFORE CODING — state assumptions explicitly; if uncertain, ask. If
   multiple interpretations exist, name them, don't silently pick. If a simpler
   approach exists, say so. If something's unclear, stop and name it.
2. SIMPLICITY FIRST — minimum code that solves the problem; no features beyond
   what was asked, no single-use abstractions, no unrequested configurability,
   no error handling for impossible cases. If 200 lines could be 50, rewrite.
   Optimize for the human reviewer, not for cleverness: check would a senior
   engineer reviewing this call it overcomplicated, or be able to approve it
   in one pass?
3. SURGICAL CHANGES — touch only what you must; don't improve/refactor/reformat
   adjacent code; match existing style; mention unrelated dead code, don't
   delete it; do remove orphans your own change created. Every changed line
   traces to the request.
4. GOAL-DRIVEN EXECUTION — turn tasks into verifiable criteria ("add validation"
   → write tests for invalid inputs, then pass them; "fix bug" → write a
   reproducing test, then pass it). State a brief plan with a per-step
   verification check. Pairs with the `tdd` skill.
5. FUNCTION SIZE & NO HEADER BLOAT — keep functions at or under 60 lines,
   comments and docstrings excluded (NASA/JPL cap); if a function grows past
   it, split it rather than argue the exception. No verbose file/script
   headers or docstrings — skip banners, license blocks, restated changelogs,
   and param-by-param docstrings; be blunt and straightforward, a single
   one-line purpose comment at most, only if the filename doesn't already
   say it.
6. NO REACHING THROUGH — use only what you were handed, built, or own: one
   hop into your own input is fine (`jq '.agent_type'` on hook stdin);
   chaining into another unit's internals is not (`a().b.c`, jq-ing a
   sibling script's private output, grepping a persona's prose). Read shared
   formats via their owner: source `hooks/scripts/lib/state-access.sh`, don't
   re-derive a marker path or unit-id regex inline.
7. EXTEND, DON'T SPECIAL-CASE — if working code has an extension point (a
   `case` table, config list, lib function), add a new entry beside it, not
   an `if <special case>` inside working logic. Never build a seam
   speculatively: inline the first case, extract on the second real caller
   (principle 2 wins until then); any edit it still forces stays surgical
   (principle 3).
