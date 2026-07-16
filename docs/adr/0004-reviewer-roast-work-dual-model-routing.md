# ADR 0004: Reviewer advisory critique (`roast-work` skill) and opus-default / fable-heavy-lifting routing

Date: 2026-07-15
Status: Accepted (completed plan 2026-07-14-threefold-update Track 4)

## Context
The review step has two potentially competing demands:
1. **Detailed prose critique:** beyond just checking acceptance criteria (contradictions, missing parts, logic gaps, security vulnerabilities, actionable feedback) — the detail level that can only be applied reliably on a large surface because smaller surfaces don't generate enough context.
2. **Core safety property (machine-checkable PASS/FAIL gate):** PASS only when every acceptance-criteria command passes AND the materiality filter (correctness / security / unmet-acceptance-criteria) is satisfied. This gate must be authoritative and never weakened.

A third tension: **model choice for reviewer.**
- The existing fable-eligibility principle (Constitution principle area) reserves fable for LIGHT, well-scoped, mechanical, low-judgment work.
- But reviewer's PASS/FAIL gate is judgment-heavy, so it should run on opus (the default for heavy work).
- Yet reviewer.md's roast-work skill (producing detailed critique) is a BULK-CONTEXT task — large surface coverage is exactly where fable's bulk-context strength comes into play.

How to reconcile without weakening the gate?

## Decision
**Tension 1 (prose critique vs gate safety):** resolved as advisory-only.
- `roast-work` is a supplementary prose-critique section appended AFTER the verdict line, clearly demarcated and labeled advisory.
- **Core safety property untouched:** PASS/FAIL is determined exactly as today — the machine-checkable acceptance-criteria command plus the existing materiality filter (correctness / security / unmet-acceptance-criteria). roast-work's critique NEVER flips a verdict, never substitutes for running the command; the v2 PASS marker still records `criteria: <command(s) run>`.
- **No new blocking category:** roast-work does not expand what FAIL means. A security or correctness defect still FAILs via the EXISTING materiality filter, independently of roast-work; roast-work merely narrates/surfaces detail advisorily.
- **Verdict format discipline preserved:** reviewer.md's "verdict-first, only the verdict" bullet is updated to permit exactly ONE clearly-demarcated advisory section (roast-work) appended after the verdict line and nothing else. The discipline that the verdict line comes first and is never obscured is preserved.

**Tension 2 (model routing):** resolved as opus default + fable for heavy lifting.
- `reviewer.md` frontmatter stays `model: opus` (the authoritative PASS/FAIL gate always runs on opus; never fable).
- **For heavy units only**, the orchestrator **additionally dispatches** a separate, non-authoritative **fable roast-work advisory pass** in parallel.
- **Heavy unit trigger** (concrete, runnable): a unit meets ANY of:
  1. Large surface: ≥~8 impacted files OR ≥~400 changed lines
  2. Structural / cross-cutting change (e.g. persona split, orchestrator routing rewrite, `bin/cli.js` migration)
  3. Security-sensitive surface (auth, input parsing/validation, secret handling, migrations)
- **For routine/small units:** the single opus reviewer runs roast-work inline (it is a preloaded skill regardless of model), no separate fable pass.
- **Task-master tags heavy units** with an advisory `Roast pass: fable` marker (mirroring the `Suggested model` per-unit tag pattern), and the orchestrator honors it at dispatch.

**Why separate advisory dispatch instead of "whole heavy review on fable":**
- The model is fixed per dispatch invocation; there is no way to run the authoritative gate on opus while running the bulk critique on fable within a single dispatch.
- A distinct fable advisory pass costs an extra fable invocation (cheap relative to opus) on heavy units only.
- It keeps the two concerns separated: the judgment-critical gate is always opus; only the non-gating bulk-context critique uses fable's strength.
- The gate never runs on fable, preserving the core safety property and the existing fable=light-work principle.

## Consequences
- **Safety property enhanced, not weakened:** PASS/FAIL gate integrity is preserved and even sharpened (roast-work being explicitly advisory confirms the gate is independent). The v2 PASS marker protocol is unchanged.
- **Bulk-context critique available:** detailed prose critique is available on the units where context is abundant (large surface, structural changes), using the model strength that excels at that.
- **Controlled cost:** only heavy units get the additional fable pass; routine small changes incur no extra cost.
- **Clarity on advisory vs authoritative:** the demarcation (separate advisory section, separate fable dispatch) makes it crystal clear that roast-work never gates.
- **Reconciled principles:** the existing fable=light-work principle is preserved (fable still does NOT do judgment-critical gates); the roast-work heavy-lifting use is reconcilable because it serves a different purpose (non-gating bulk critique on a large surface, not judgment-critical gating).
- **Inversion flagged:** this approach inverts the existing pattern (fable for light, opus for heavy) but only for a non-gating use, and the inversion is documented and reconciled rather than silently normalized.

## Related
- **Amended by ADR-0006:** Signal-gated sonnet on the reviewer's authoritative PASS/FAIL gate — amends the "gate is always opus" statement to permit sonnet for demonstrably-mechanical units per a conjunctive condition.
- **Roast-work skill:** a new first-party skill (not derived from any single packaged skill) that provides a detail-driven critique rubric: contradictions, missing parts, logic gaps, security vulnerabilities, actionable feedback. Written to the mattpocock/skills quality bar. Ships via the plugin-source `skills/roast-work/SKILL.md` path.
- **Core safety property (The Writer/Reviewer split):** unchanged. Reviewer is independent (did not write the code); only reviewer can mark a unit done (`.claude/reviewed/*.pass`). This remains the system's load-bearing safety property, now explicitly reinforced by roast-work being advisory-only and never gating.
