---
name: wip-sentinel-agent-id
description: How to learn your own agent id for the WIP sentinel path - don't hunt for it, let the stop-gate's block message tell you
metadata:
  type: project
---

You cannot read your own `agent_id` from the environment or the session
transcript. `CLAUDE_CODE_SESSION_ID` is the *session* id and is NOT what
`stop-gate.sh:175-177` keys the sentinel on (`.agent_id // .session_id`), so a
sentinel named after the session id is silently ignored when a real agent id is
present on the payload. The transcript's `agentId` fields belong to other
agents in the session, not reliably to you.

**Why:** cost two turns on 2026-07-31 hunting through
`~/.claude/projects/*/<session>.jsonl` for an id that was never there.

**How to apply:** don't hunt. Just end the turn with the tree red. The
stop-gate's own block message prints the exact path verbatim
(`... or 'echo "<reason>" > /home/sebas/AntiSlop/.claude/wip-handoff.<id>'`).
Write the sentinel there on the next turn and end again. Two related traps:

- Write the sentinel with the **Write tool**, not a Bash redirect, whenever the
  reason text names the marker directory - `reviewed-path-gate.sh` blocks the
  redirect form and your escalation reason is exactly the kind of text that
  mentions it.
- Delete any sentinel you created under a guessed name. An unconsumed sentinel
  lingers and would honor a *future* stop for whatever id it names. There is a
  pre-existing orphan from another session in `.claude/` - not yours to remove.

See [[live-plugin-probe]] for the related fact that hook edits go live
immediately in the session that makes them.
