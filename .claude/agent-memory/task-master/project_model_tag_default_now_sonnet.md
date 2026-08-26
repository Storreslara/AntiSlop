---
name: project-model-tag-default-now-sonnet
description: The reactive-default implementer model tag is currently `sonnet` (ADR-0010 reversed the earlier `haiku` default) — don't pattern-match on older sliced tickets (e.g. spec-3's gh413, tagged `haiku (default writer tier)`) as if that default still holds.
metadata:
  type: project
---

Confirmed 2026-08-26 while slicing `docs/plans/2026-08-25-harness-trust-gaps.md`
("spec 1"): `gh label list` still shows a `plan/2026-08-01-haiku-default`
label, and spec 1's own text (line ~67) states plainly "Spec 2 (performance,
FINAL — **ADR-0010 reversed**, implementer default `sonnet`)". This means
the default implementer tag flipped from `haiku` to `sonnet` at some point
after 2026-08-01, and any sliced-ticket example from before that date (e.g.
spec 3's gh413, which says "Suggested model: `haiku` (default writer
tier)") reflects the *old* default, not the current one.

**How to apply:** always tag new units `sonnet` per this project's current
reactive-only default (task-master's own persona instructions already state
this explicitly — this memory exists only so an old ticket's tag isn't
mistaken for the live default when pattern-matching an existing ticket's
shape). The reactive-escalation rule itself (only a prior `.fail` record or
the orchestrator's first-FAIL escalation moves a unit to `opus`) is
unchanged — only the resting default moved from `haiku` to `sonnet`. If a
future ADR reverses it again, re-check via `gh label list` for a
`plan/<date>-*default*` label or grep recent FINAL specs' own text before
assuming which default currently holds.
