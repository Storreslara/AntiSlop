---
name: teammate-cannot-spawn-named-agent
description: A teammate dispatch cannot pass Agent's `name:` parameter — the roster is flat; nested dispatches are anonymous synchronous subagents only.
metadata:
  type: project
---

When running as a **teammate** (spawned into the session roster, not as a plain
subagent), the `Agent` tool's `name:` parameter is rejected outright:

> Teammates cannot spawn other teammates — the team roster is flat. To spawn a
> subagent instead, omit the `name` parameter.

**Why:** the roster is flat by construction. A teammate's own nested dispatch is
always an anonymous *synchronous* subagent — it returns its result to you, and it
is not addressable by the team lead or any other roster member.

**How to apply:** if a lead instructs you to "give your nested dispatch an
explicit `name:` so I can address it directly," that instruction cannot be
satisfied — say so plainly rather than retrying, and tell the lead to route
follow-ups through you. Report the returned `agentId` for the record, but do not
imply the lead can message it. Measured 2026-08-15 dispatching `task-master`
from a `spec-master` teammate.

Related: the same teammate context also withholds `Skill` (so `to-spec` /
`grill-me` must be followed by reading their `SKILL.md` directly) and `Write`/
`Edit` (fall back to Bash heredocs) — see [[to-spec-slash-only]] and the shared
protocol's teammate fallback section.
