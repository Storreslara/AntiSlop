---
name: feedback_grep_acceptance_line_wrap
description: Multi-word grep -q acceptance anchors in hand-wrapped persona .md prose must not span a line wrap, and must match literally (hyphen vs space)
metadata:
  type: feedback
---

When an acceptance criterion is `grep -q "some multi-word phrase"` against a
hand-wrapped markdown file (persona files like `agents/orchestrator.md` wrap
prose at ~78 cols), `grep -q` only matches within a single line — a phrase
split across a line-wrap boundary silently fails with no error, it just
doesn't print.

**Why:** Self-caught while implementing issue #95 (Step 6 of
[[project_threefold_update]]'s sibling plan,
`docs/plans/2026-07-21-subagent-background-self-wake-protocol.md`): wrote
"still genuinely\nrunning" split across two wrapped lines, and separately
wrote `WIP-sentinel` (hyphenated) when the acceptance grep required `WIP
sentinel` (space) — both compiled/read fine as prose but failed their
literal-string check silently until I ran the exact acceptance command
myself instead of eyeballing the diff.

**How to apply:** After any prose edit whose acceptance criteria are
literal-string greps, always run the exact grep commands from the
plan/issue verbatim (not a paraphrase) before reporting ready-for-review,
and re-check every multi-word anchor phrase stays on one line post-edit —
don't trust that "the words are all in there somewhere" is equivalent to
"the exact substring matches."
