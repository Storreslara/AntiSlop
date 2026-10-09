<!-- antislop v0.31.152 | source: templates/protocol-digest.md | ADAPT-substituted -->
<!-- Copied into the project as .claude/protocol-digest.md by install-antislop,
     version-stamped like persona-protocol.md. Re-injected verbatim by
     session-start.sh's SessionStart hook, ONLY on `source: resume`/`compact`
     - never `startup`/`clear`. Keep the body to at most 15 non-empty lines (tested) - if it grows,
     mechanize the rule (a hook) instead of making the digest longer. -->

# Protocol digest (post-compaction/resume reminder)

- Structural questions (definitions, callers, blast radius, coverage): spawn
  `explorer`; never invoke the code-review-graph skill directly.
- Only the orchestrator/team lead routes between lead-programmer and reviewer.
  "Done" = reviewer PASS (a critical unit may first route through
  ESCALATE-TO-HUMAN).
- 2 FAILs per implementer tier move the unit up the Escalation ladder; only
  ladder exhaustion (FAIL-block count reaching or exceeding the ladder's length)
  stops re-delegation and surfaces the full defect history to the user.
- WIP sentinel `.claude/wip-handoff.<agent-id>`: genuine mid-task pause only,
  with a stated reason (empty is ignored); never to dodge a fixable red suite.
- `.claude/.pending-review.<id>` blocks turn-end and the next implementation
  dispatch until the reviewer runs or it holds `defer: <reason>`/`skip: <reason>`.
- `memory:` auto-grants Read/Write/Edit; that is not license to edit outside
  your role's stated scope.
