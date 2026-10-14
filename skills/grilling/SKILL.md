---
name: grilling
description: >
  Grill a plan, decision or idea until its branches are resolved. Use when asked to grill,
  stress-test or interrogate a plan, whether a live user is present, only a dispatcher is,
  or no one is (self-grill).
---
<!-- Derived from mattpocock/skills skills/productivity/grilling/SKILL.md @ e9fcdf9 (MIT, see skills/THIRD-PARTY-NOTICES.md); vendored original archived at docs/archive/skills/grilling/ -->

Grill the plan, decision or idea until every branch of its decision tree is resolved and the dependencies between decisions are settled one by one. For each question, give your recommended answer.

## Pick the context first

1. **Live user in the main session.** Ask one at a time, each with your recommended answer, and wait for the answer before the next. Asking several at once is bewildering.
2. **Dispatched subagent with no live user.** You cannot wait for answers. Batch up to 4 questions per round, ordered by impact x uncertainty (the answer that changes the most and that you know least about comes first). Give each question a recommended default, and list options where the answer space is discrete. Return them as Open Questions and stop; you resume when re-dispatched with the answers.
3. **Self-grill (no user, for example auditing a plan's premises).** Answer each question yourself from evidence in the repo (files, tests, history, tools). A question the evidence cannot answer becomes a finding, never a guess.

## In every context

- If a *fact* can be found by exploring the environment (filesystem, tools, etc.), look it up instead of asking.
- The *decisions* belong to the user: put each one to the user (or return it as an Open Question) and do not decide it yourself.
- Take no action on the plan until the questions converge on a shared understanding.
