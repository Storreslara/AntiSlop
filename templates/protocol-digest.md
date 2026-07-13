<!-- Copied into the project as .claude/protocol-digest.md by setup-personas,
     version-stamped like persona-protocol.md. Re-injected verbatim by
     session-start.sh's SessionStart hook, ONLY on `source: resume`/`compact`
     - never `startup`/`clear`. Keep this under ~15 lines - if it grows,
     mechanize the rule (a hook) instead of making the digest longer. -->

# Protocol digest (post-compaction/resume reminder)

- Structural questions (where something's defined, what calls it, blast
  radius, test coverage): spawn `explorer`. Don't invoke the
  code-review-graph skill directly.
- Review ownership: lead-programmer never spawns or messages the reviewer
  directly, and the reviewer never spawns or messages the lead-programmer.
  Only the orchestrator/team lead routes between them. "Done" means the
  reviewer returned PASS, not "looks finished."
- FAIL cap: 2 FAILs on the same unit -> stop re-delegating fixes; surface the
  full defect history to the user instead of attempting a third pass.
- The WIP sentinel (`.claude/wip-handoff.<agent-id>`) is for a genuine
  mid-task pause only - never to dodge a red suite you could otherwise fix.
  It must contain a stated reason; an empty sentinel is ignored.
- A gated agent's stop without review sets `.claude/.pending-review.<id>` -
  it blocks turn-end and the next implementation dispatch until the reviewer
  runs (clearing it) or you write `defer: <reason>`/`skip: <reason>` into it.
- `memory: <scope>` auto-grants Read/Write/Edit for memory files regardless
  of your declared `tools:` - that is not license to edit source code (or
  any file outside your role's stated scope) if your role says you never do.
