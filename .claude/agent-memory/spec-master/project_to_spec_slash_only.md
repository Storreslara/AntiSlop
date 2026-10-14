---
name: to-spec-slash-only
description: to-spec and grill-me no longer exist as skills (retired 2026-10-14, skr-2/skr-3); the PRD template lives in spec-master's own appendix. Historical note on the disable-model-invocation flag kept.
metadata:
  type: project
---

**SUPERSEDED 2026-10-14 (skills audit, ADR-0041).** `to-spec` was merged into
`agents/spec-master.md` (skr-3) and `grill-me` was retired (skr-2); neither is a
skill any more, so never look for `antislop:to-spec` or `antislop:grill-me`.
Originals: `docs/archive/skills/to-spec/`, `docs/archive/skills/grill-me/`.

**How to apply:** to publish, map the finished plan onto your own
`## Appendix: PRD template` (Problem Statement / Solution / User Stories /
Implementation Decisions / Testing Decisions / Out of Scope / Further Notes)
and publish to the tracker named by `issueTracker` (read the persona config
with the Read tool, never Bash). Grill with `antislop:grilling` plus
`antislop:domain-modeling`. Tracker here: GitHub issues, repo
Storreslara/AntiSlop, `ready-for-agent` label exists; when the spec targets an
existing source issue, posting the PRD as a comment on it plus the label avoids
a near-duplicate issue.

Still-true history about the flag: a skill carrying
`disable-model-invocation: true` is removed from the agent entirely (absent
from the skills list, body not preloaded) in every mode, and skills resolve
from the versioned plugin cache, so a repo-side change reaches a session only
after a plugin update and restart.
