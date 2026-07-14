# Hook verification probe script

This is the sandboxed probe list referenced by `SKILL.md` section 10. It is a
separate file so the orchestrating model never has to load it — only the
delegated subagent doing the actual probing reads this, on a throwaway
branch, scoped to whichever sub-bullets section 10's conditional logic said
apply.

On a throwaway branch:
- Make a trivial edit; confirm `graph-update.sh` and `lint-on-edit.sh` fired
  (check the graph index timestamp / lint output).
- Confirm the stop-gate does **NOT** block a trivial explorer or
  repo-historian turn even with a dirty tree — proof that `gatedAgents`
  scoping (read from `persona-config.json`, not hardcoded in `hooks.json`) is
  working and won't strangle the cheap, high-frequency personas.
  Additionally confirm the stop-gate does NOT block a trivial main-session
  (orchestrator) Stop even with a dirty tree from an in-flight subagent —
  this is the regression test for the main-session allowlist; pipe a
  synthetic `{"hook_event_name":"Stop","session_id":"test"}` into the hook
  with a dirty tree and a default config and confirm exit 0.
- Introduce a failing check, end a lead-programmer-style turn, confirm
  BLOCK; `touch .claude/wip-handoff.<agent-id>` (empty, no reason), confirm
  it is REJECTED (deleted, but the BLOCK still fires) — this proves the
  empty-sentinel bypass is actually closed, not just documented as closed.
  Then `echo "test reason" > .claude/wip-handoff.<agent-id>`, confirm ALLOW,
  the sentinel is deleted, and the reason appears as a new line in
  `.claude/wip-audit.log`.
- Pipe a synthetic `{"session_id":"test","source":"resume"}` into
  `session-start.sh` directly (real compaction/resume isn't reliably
  triggerable inside a sandboxed verification run) and confirm the output
  JSON's `additionalContext` contains `.claude/protocol-digest.md`'s content.
  Repeat with `"source":"startup"` and confirm additionalContext is empty
  (no version drift, no digest) — the digest must NOT appear on a fresh
  start, only resume/compact.
- Test the protected-paths hook with a dry write against one of the
  configured `protectedPaths` patterns; confirm BLOCK with the human-approval
  message (this specifically re-verifies the path-anchoring fix — a pattern
  like `supabase/migrations/*` must now actually match the tool's absolute
  file path).
- If `reviewer` was selected: run one task named `impl:*` through to a
  reviewer PASS in agent-teams mode and confirm the completion marker write
  succeeds (no "No such file or directory" error) thanks to step 9's `mkdir`.
- Pipe a synthetic `{"agent_type":"lead-programmer","tool_input":{"subagent_type":"reviewer"}}`
  into `reviewer-route-gate.sh` directly and confirm BLOCK; repeat with
  `subagent_type":"explorer"` and with `"agent_type":"orchestrator"` (target
  `reviewer`) and confirm both ALLOW — proves the gate only fires for the
  specific lead-programmer→reviewer pair, not every Agent-tool call.
- **PASS marker v2 (`task-gate.sh`)**: `touch .claude/reviewed/test.pass`
  (bare, empty) then pipe `{"task":{"subject":"impl:test","id":"test"}}` into
  `task-gate.sh` and confirm BLOCK (exit 2) naming the required `printf`
  format and the `--update` remedy; then write a valid first line —
  `printf 'PASS test %s criteria: <cmd>\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > .claude/reviewed/test.pass`
  — and confirm ALLOW plus a new `marker-accepted` line in
  `.claude/review-audit.log` — proves the existence-only check is gone.
- **Pending-review flag (`stop-gate.sh`)**: pipe a synthetic
  `{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","agent_id":"test"}`
  and confirm `.claude/.pending-review.test` is created; then pipe
  `{"hook_event_name":"Stop","session_id":"test"}` and confirm BLOCK
  ("awaiting review"); then pipe a reviewer `SubagentStop`
  (`"agent_type":"reviewer"`) and confirm the flag is gone and
  `cleared-by=reviewer` appears in `.claude/review-audit.log`. Also confirm
  the `defer: <reason>`/`skip: <reason>` escape hatch: overwriting the flag
  with `defer: ...` allows that one Stop and keeps the flag; `skip: ...`
  allows it and deletes the flag; both log to `.claude/review-audit.log`.
- **Pending-review dispatch block (`reviewer-route-gate.sh`)**: with a
  `.claude/.pending-review.*` flag present, pipe
  `{"agent_type":"","tool_input":{"subagent_type":"lead-programmer"}}` and
  confirm BLOCK; repeat with `"subagent_type":"reviewer"` and confirm
  ALLOW — proves the next gated-agent dispatch is blocked while a unit
  awaits review, without blocking the reviewer dispatch itself.
- Revert the branch completely. Your final turn must end with the repo clean
  and all sentinels/markers removed.
