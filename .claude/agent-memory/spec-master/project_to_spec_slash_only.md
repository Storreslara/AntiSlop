---
name: to-spec-slash-only
description: The to-spec skill is disable-model-invocation, so a spec-master subagent cannot fire it via the Skill tool — apply its template/process manually.
metadata:
  type: project
---

`to-spec`'s SKILL.md has `disable-model-invocation: true`. Calling it via the
`Skill` tool fails with "cannot be used with Skill tool due to
disable-model-invocation" — it is a slash-command-only skill.

**Why:** It is meant to be user-triggered (`/to-spec`); a dispatched subagent
has no slash-command channel.

**How to apply:** When spec-master runs as a subagent and the task says
"publish via to-spec," read the skill's SKILL.md for its PRD template + process
and apply them manually — map the finalized plan onto Problem Statement /
Solution / User Stories / Implementation Decisions / Testing Decisions / Out of
Scope / Further Notes, then publish to the tracker yourself. Same applies to
`grill-me` if it is also disable-model-invocation. Issue tracker for this repo:
GitHub issues, repo Storreslara/AntiSlop, `ready-for-agent` label exists. When
the spec targets an existing source issue, posting the PRD as a comment on that
issue + adding the label avoids duplicating it as a near-identical new issue.
