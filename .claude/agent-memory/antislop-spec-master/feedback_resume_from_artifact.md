---
name: resume-from-artifact
description: When continuing a prior spec-master session that ended holding Open Questions, read the plan doc and proceed — do not re-grill or re-run the taxonomy
metadata:
  type: feedback
---

When re-delegated to finalize a plan a *previous* spec-master session
authored, treat the saved `docs/plans/YYYY-MM-DD-<slug>.md` as the sole
source of truth and continue from it. Do **not** re-run the 9-category
ambiguity taxonomy, do not re-invoke `grill-me`, and do not re-derive the
Context section's findings.

**Why:** prior sessions are not resumable (no live transcript), and this repo
follows a "cite the artifact, not the interrogation trail" convention — the
plan doc is written to be picked up cold. Re-interrogating burns tokens
re-deriving conclusions already recorded and measured, and risks contradicting
baselines the earlier session verified against a specific commit.

**How to apply:** on a continuation pass the work is mechanical and narrow —
(1) append one dated line per answered category to **Clarifications** (record
the answer, never merely consume it), (2) fill any placeholder literals into
the acceptance criteria and **re-measure their baselines live**, since the tree
moves between sessions, (3) mark each Open Question RESOLVED with an explicit
"Effect on the spec" line, (4) run a fresh Self-check pass over the *new* text
only and number it continuing from the existing items, (5) publish and hand
off. Keep the original taxonomy scorecard verbatim — it scores the incoming
request, not the post-resolution state.

Re-measuring in step 2 is not optional: on the ceremony-reduction pass a
baseline carried over by inspection was wrong (`≥3 units` in `agents/` was
stated as 1, measured as 4), and a criterion pinned to ADR number `0024` had
already been overtaken by `0023` landing. See [[criterion-authoring-nonvacuity]].
