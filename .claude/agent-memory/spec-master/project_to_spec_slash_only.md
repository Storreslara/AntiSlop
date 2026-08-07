---
name: to-spec-slash-only
description: to-spec WAS slash-only but unit #252 un-flagged it (2026-08-06); verify against your live skills list before assuming either state.
metadata:
  type: project
---

**CORRECTED 2026-08-06 — this memory was written before unit #252 landed.**
`to-spec` and `to-tickets` were un-flagged by commit `1eb4627` ("fix: un-flag
to-spec and to-tickets, remove /implement reference (unit #252)"), and
`antislop:to-spec` now appears in a dispatched spec-master's available-skills
list. Treat the "slash-only" claim below as **historical**.

**Check before relying on either state:** look for `antislop:to-spec` in your
own available-skills listing. Per the skills-library spec's R7, skills resolve
from the versioned *plugin cache*, not the working tree — so a repo-side
un-flagging does not take effect until the cache is refreshed and the session
restarts. The two can legitimately disagree.

Historical detail, still accurate about what the flag does: a skill carrying
`disable-model-invocation: true` is not merely blocked from the `Skill` tool —
it is removed from the agent entirely (absent from the skills list, body not
preloaded), in every mode, not just agent-teams.

**How to apply:** When spec-master runs as a subagent and the task says
"publish via to-spec," read the skill's SKILL.md for its PRD template + process
and apply them manually — map the finalized plan onto Problem Statement /
Solution / User Stories / Implementation Decisions / Testing Decisions / Out of
Scope / Further Notes, then publish to the tracker yourself. Same applies to
`grill-me` if it is also disable-model-invocation. Issue tracker for this repo:
GitHub issues, repo Storreslara/AntiSlop, `ready-for-agent` label exists. When
the spec targets an existing source issue, posting the PRD as a comment on that
issue + adding the label avoids duplicating it as a near-identical new issue.
