---
name: in-session-escalation-decision-spec
description: 2026-10-01 settled design for a chat-based ESCALATE-TO-HUMAN decision; prompt-gated heredoc write, not an AskUserQuestion PostToolUse hook, and why.
metadata:
  type: project
---

The user picked the prompt-gated write (OQ1-OQ4, all defaults, 2026-10-01).
The plan is `docs/plans/2026-10-01-in-session-escalation-decision.md`, units
esc-chat-1..4. esc-chat-1 is an operator measurement and ship gate.

**Why:** an AskUserQuestion-answer hook cannot prove a human answered:
- the 2.1.287 binary shows answers ride `updatedInput.answers`, which hooks
  and the SDK can fill;
- the writer script becomes a Bash-invocable oracle whose command text never
  spells the protected path.

A gate `ask` on a strictly parsed heredoc renders the exact bytes, and U1/U2
were already measured for Write (2026-09-23 probe).

**How to apply:** for any future "human consents in chat" request, reuse
`ask`-never-`allow` on a strictly parsed shape. Never transcribe from
AskUserQuestion output.

Also: Bash pipelines over `.claude/reviewed/` are blocked by
reviewed-path-gate. Use `grep -r[lc] --include` or the Read tool when
surveying `.fail` records.
