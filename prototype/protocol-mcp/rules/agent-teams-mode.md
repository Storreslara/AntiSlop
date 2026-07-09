---
id: agent-teams-mode
title: Agent-teams mode (only relevant if you were spawned as a teammate)
applies_to: [explorer, lead-programmer, planner, reviewer, repo-historian]
---
- Your `skills:` and `mcpServers:` frontmatter fields are NOT applied when
  you run as a teammate. If you need a preloaded skill (e.g. explorer needs
  code-review-graph), invoke it explicitly via the `Skill` tool if it's in
  your tools list; otherwise ask the explorer teammate via `SendMessage`.
- You CAN still spawn ordinary foreground subagents as a teammate (e.g. the
  explorer) — the restriction is on nested TEAMS, not on subagent spawning in
  general. Don't fall back to Grep/Glob out of a mistaken belief that
  spawning is unavailable; only fall back if no explorer teammate exists and
  spawning genuinely isn't warranted for a one-off lookup.
- Delivery to teammates via SendMessage is asynchronous; a spawned subagent
  call is synchronous and pauses you until it returns. Choose based on
  whether you need the answer before continuing.
