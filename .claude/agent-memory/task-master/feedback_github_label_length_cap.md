---
name: feedback-github-label-length-cap
description: GitHub labels are capped at 50 characters — this repo's `plan/<YYYY-MM-DD>-<slug>` per-plan label convention can exceed that with a long doc slug; truncate the slug, don't drop the convention.
metadata:
  type: feedback
---

This repo's slicing convention (seen across `plan/2026-07-15-handoff-triage-
skills`, `plan/2026-07-16-reviewer-gate-model-selection`,
`plan/2026-07-17-marketplace-precedence`, etc.) is a per-plan GitHub label
named `plan/<YYYY-MM-DD>-<slug>`, matching the `docs/plans/` filename slug.

GitHub rejects label names over 50 characters (`HTTP 422: name is too long
(maximum is 50 characters)` from `gh label create`). Observed 2026-07-17:
the full doc slug `suggested-model-tier-routing-consistency` made
`plan/2026-07-17-suggested-model-tier-routing-consistency` too long; had to
shorten to `plan/2026-07-17-model-tier-routing` (issue #86/#87 slicing).

**Why:** the doc-filename slug is chosen for readability in `docs/plans/`,
not for label-length budget — nothing enforces the two staying in sync.

**How to apply:** before running `gh label create` for a new per-plan label,
count the full `plan/<date>-<slug>` string; if it's at or near 50 chars,
shorten the slug portion (drop less-essential words) rather than abandoning
the `plan/` prefix or the date, since both carry information other memories
([[cross_plan_version_coordination]]) rely on when cross-referencing plans.
Keep the shortened label's meaning recoverable from the issue body (which
still names the canonical doc in full) even if the label itself is
abbreviated.
