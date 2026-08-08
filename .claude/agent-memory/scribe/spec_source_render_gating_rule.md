---
name: spec-source-render-gating-rule
description: Source-artifact + render steps can never be independently gated; always merge or pin failure
metadata:
  type: project
---

When a spec plan involves editing a source artifact (e.g., `templates/persona-protocol.md`) in one step and regenerating/porting its shipped copies (e.g., `.claude/agents/*.md` mirrors) in a separate step, **these two steps can never be independently gated** under this repo's `tests/validate.sh`.

**Why:** The mirror assertion suite enforces bijection across declared sections. An edit-only commit (source changed, mirrors stale) fails the suite at the mirror assertion. A render-only commit (mirrors regenerated with old source) fails differently. The gates cannot tolerate an intermediate state where only one half has been updated, so the steps must either be merged into one unit or the intermediate failure set must be pinned and explicitly audited.

**How to apply:** When authoring a spec that touches a source+render pair:

1. **Merge them into one unit up-front** (preferred for small pairs), OR
2. **Divide them but pin the intermediate failure set** in the spec's written text (cite which lines of `tests/validate.sh` will red, which assertions will fail, how many lines), then audit in the spec's self-checks that **every** source+render pair in the plan is accounted for — not just the first one an implementer hits.

Example: `docs/plans/2026-08-07-per-unit-review-join.md` split a source edit (Step 4: `templates/persona-protocol.md`) and its render (Step 6: `.claude/agents/*.md` mirrors) because Step 5 was a prerequisite fix. The plan declared the deviation (lines 442-469) and added check CHK18 (line 1249) to generalize the rule for future plans.

**Scope:** Repo-wide structural rule. Applies to all future specs, not specific to the review-join feature.

References: issues #265, #266, #267 (merged unit, second occurrence of this pattern in the same spec); commit 4fcc0d5.
