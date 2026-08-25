---
name: escalation-vs-protectedpaths
description: This repo runs humanReviewMode "off", so ESCALATE-TO-HUMAN does NOT fire; protectedPaths is a separate Write/Edit-only block. Never infer one from the other.
metadata:
  type: project
---

Two unrelated mechanisms that are easy to conflate — I stated the wrong one in
a spec and had to correct it:

- **ESCALATE-TO-HUMAN / the DECISION channel** keys on `humanReviewMode` in
  `.claude/persona-config.json` (`agents/reviewer.md:167`,
  `templates/persona-protocol.md:329`). This repo sets it to **`"off"`**
  (ADR-0024 solo-operator posture; ADR-0018 records the return to `off` after
  the bootstrap window). So escalation does **not** fire here, whatever the
  unit touches. Fresh installs get `critical`; gh345-1 escalated only because
  the key was then ABSENT and defaulted to `critical`.
- **`protectedPaths`** drives `protected-paths.sh`, which hard-blocks
  Write/Edit on its patterns with "Requires explicit human approval". Current
  list: `.github/workflows/*`, `.claude/constitution.md`,
  `hooks/scripts/human-decision-gate.sh`, `hooks/scripts/reviewed-path-gate.sh`.

**Why:** being in `protectedPaths` says nothing about escalation, and
`humanReviewMode: off` says nothing about whether a file is editable.

**How to apply:** re-read the config before claiming a unit will escalate —
this value has changed at least three times. When a unit edits a protected
path, warn in the dispatch that the lead-programmer WILL be blocked and must
ask the operator. Note `protected-paths.sh` matches `Write|Edit` ONLY, so a
Bash heredoc slips past it — that route is a self-authorized bypass, not the
sanctioned Write/Edit fallback in [[teammate-write-edit-unavailable]], which
covers the tool being unavailable, never a gate refusing.
