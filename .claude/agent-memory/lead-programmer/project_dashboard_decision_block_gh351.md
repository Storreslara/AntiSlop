---
name: project_dashboard_decision_block_gh351
description: gh351 (decision-block.js composer) shape and design choices, relevant to later steps of the dashboard-decision-approval-surface spec
metadata:
  type: project
---

gh351 (Step 2 of `docs/plans/2026-08-13-dashboard-decision-approval-surface.md`,
tracked as #349) shipped `bin/microworld-dashboard/decision-block.js`:
`composeDecisionBlock(kind, context)` returns
`{ kind: 'command'|'block', text, warnings[] }` for the four kinds
(`escalation-decision`, `pending-review-defer`, `pending-review-skip`,
`milestone-findings-response`). Injected into `index.html` via
`__DECISION_BLOCK_SOURCE__` (mirrors `__FEEDBACK_BLOCK_SOURCE__`), wired in
`server.js`'s `GET /` handler.

**Why:** Step 3 (the client-side Decisions section, `index.html` +
`tests/dashboard-decisions-client.test.js`) consumes this module's output
directly — it will call the page-global `composeDecisionBlock` the same way
the existing client calls `formatFeedbackBlock`.

**How to apply / things that weren't obvious:**
- The acceptance criterion's "first line matches the protocol grammar" means
  the *heredoc body's* first line (`DECISION <id> <ts> route: ... escalation:
  ...`), NOT the shell command's first line (`cat > ... <<'EOF'`). `result.text.split('\n')[1]`,
  not `[0]`.
- Command kinds (`escalation-decision`, `pending-review-defer/skip`) always
  wrap their body in a single-quoted `<<'EOF'` heredoc, even when the body
  happens to be short — simpler than branching on multi-line vs single-line,
  and it's what D-6 rule 2 implies since the DECISION body is always >=2
  lines (`DECISION ...` + `by: ...`).
- `assertNoCommandSubstitution` (no `$(`, backtick, `${`) is applied as a
  defensive throw over the *whole* composed text, including human free-text
  fields (`by`, `reason`) — not just the interpolated ids. This goes beyond
  what the acceptance tests assert (they only positive-check a normal
  compose call) but is a direct, cheap reading of D-6 rule 1 as a stated
  correctness requirement.
- `milestone-findings-response`'s placeholder text must avoid literal `>`
  entirely (even in prose like `<paste here>`) since the acceptance
  criterion string-searches the whole block for `>`. Used
  `[fill in ... and paste this block back]` instead of angle brackets.
- Built a `microworlds/gh351/` bundle with one `functions[]` entry
  (`fn/compose.js`, generic `{kind, context}` passthrough to
  `composeDecisionBlock`) — judged the heavy-unit trigger's criterion 3
  (security-sensitive input validation) to apply here despite the small
  file/line count, per the ticket's own "most security-adjacent unit in this
  spec" framing.
