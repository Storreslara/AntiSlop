---
name: feedback-persona-paragraph-edit-needs-port-parity
description: An edit to a pinned paragraph of agents/lead-programmer.md (Contract precedence / Fix turns) must be mirrored in the Cursor and Codex lead-programmer ports; a spec that lists only agents/*.md makes its own writer-tier-consistency criterion unsatisfiable.
metadata:
  type: feedback
---

Observed 2026-10-09 (backlog-cleanup plan, unit blc-5). Step 5 added a sentence to
the **Fix turns** text inside `agents/lead-programmer.md`'s Contract precedence
bullet, and its AC5.5 required `node tests/writer-tier-consistency.test.js` to
exit 0. AC-A1 of that test compares the whole paragraph (whitespace stripped)
across `agents/lead-programmer.md`, `adapters/cursor/agents/lead-programmer.md`,
`adapters/codex/agents/lead-programmer.toml` and the `.claude/` mirror, so it
failed until both ports got the same sentence.

**Why:** the spec's file list came from reading the plan, not from running the
suite; only replaying the unit in a scratch worktree showed the failure.

**How to apply:** before filing a unit that edits a persona paragraph, replay it
in a scratch `git worktree` (my `apply` + `--update` loop) and run
`tests/writer-tier-consistency.test.js` and `tests/adapter-protocol-parity.test.js`.
A missing port file is a spec gap: write the contract with the port edits as the
scratch fix, file the unit HELD with the ruling needed, and do not call it settled.
Related: [[feedback-flip-default-run-suites-first]].
