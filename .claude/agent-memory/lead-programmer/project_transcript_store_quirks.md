---
name: transcript-store-quirks
description: Real quirks in Claude Code's own ~/.claude/projects/<slug>/ transcript store found by prototyping scripts/agent-audit.sh against the live 642-dispatch corpus - thin sessions, orphaned meta.json, and a SendMessage auto-grant the agent-auditor spec didn't document.
metadata:
  type: project
---

Found while implementing `scripts/agent-audit.sh` (issue #281,
docs/plans/2026-08-09-agent-auditor-persona.md Step 1) by running the
detector against the FULL live corpus rather than trusting the spec's
frozen 2026-08-09 measurements. Relevant to anyone extending that script
(Steps 2-7 of the same plan) or writing fixtures for it.

- **"Thin" session files exist.** Some top-level `<session-id>.jsonl`
  files contain only administrative bookkeeping records (`type:
  "last-prompt"`, `"mode"`, `"agent-setting"`, `"permission-mode"`) with
  `timestamp: null` and NO real user/assistant turn - e.g. a session that
  was opened but never used. A format probe or any consumer that reads
  `.[0]` of the first session file found by glob order can unluckily land
  on one of these and wrongly conclude the format changed. Search across
  multiple sessions/records for genuine content instead of trusting any
  single file to be representative.
- **A `agent-<id>.meta.json` can exist with no paired `.jsonl`.** An
  orphaned dispatch record (subagent created, never produced transcript
  output) is normal, not corruption - always guard with `[ -f "$jsonl" ]`
  before reading it, and don't treat the first meta.json found as
  necessarily complete.
- **Agent-teams teammates can call `SendMessage` regardless of their
  persona's declared `tools:` list.** This is a THIRD auto-grant beyond
  the two the agent-auditor spec's R3 documented (the `memory:` field
  auto-granting Read/Write/Edit, and user-scope auto-memory writes) -
  identifiable via `taskKind == "in_process_teammate"` in the dispatch's
  meta.json. Without modeling this, 6 milestone-auditor teammate
  dispatches false-positived as "undeclared tool use" in the live corpus.
  Confirms the shared persona protocol's own "Agent-teams mode" section
  (SendMessage is how a teammate reports back) rather than being a bug.
- **Agent-teams meta.json carries a `customAgentType` field the spec's
  Context table didn't list** (`{agentType, description, toolUseId,
  spawnDepth, model}` only). For a teammate with a custom name (e.g.
  `agentType: "reviewer-2"`), `customAgentType` holds the REAL underlying
  persona (`"reviewer"`) - always prefer `customAgentType // agentType`
  when resolving which persona a dispatch actually is, or every
  custom-named teammate false-positives as unregistered/undeclared.
- **One genuine anomaly surfaced by this calibration**: a `reviewer`
  dispatch wrote its own `.fail` marker via the `Write` tool instead of
  the documented `Bash` + `printf` convention (persona-protocol.md's
  marker-writing convention). `reviewer`'s frontmatter has no `Write` in
  `tools:` - this is a real, if minor, deviation worth knowing about
  independent of the agent-auditor work itself.

See also [[bash-jq-tsv-pitfalls]] for the parsing bugs hit while building
the detector, and [[reviewed-path-gate-false-positive-report-and-wait]] for the
unrelated gate issue hit while WRITING the script file itself (needing to
reference the marker directory in source code, not read it).
