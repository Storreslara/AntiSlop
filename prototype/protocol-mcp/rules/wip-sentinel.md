---
id: wip-sentinel
title: WIP sentinel (mid-task handoff, not a bypass)
applies_to: [lead-programmer, reviewer, planner]
---
To end your turn with work genuinely in progress or a red suite you haven't
finished fixing (TDD red phase, a blocked report, a "the plan is wrong"
escalation): write your reason INTO the sentinel file — e.g.
`echo "TDD red phase, 3 tests intentionally failing" > .claude/wip-handoff.<your-agent-id>`
— and state it in your report too. A bare `touch` no longer works: the
stop-gate hook now requires non-empty content, logs it (with a timestamp) to
`.claude/wip-audit.log`, deletes your sentinel, and allows that one turn to
end. An empty sentinel is deleted but NOT honored — the normal check runs
anyway. This is for legitimate pauses only — never write a reason just to
dodge a red suite you could otherwise fix; the audit log exists precisely so
that use is reviewable after the fact. (Claude Code force-ends a turn after 8
consecutive Stop-hook blocks regardless; the sentinel is the designed exit,
not a workaround for that cap.)
