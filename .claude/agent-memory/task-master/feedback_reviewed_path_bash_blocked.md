---
name: feedback-reviewed-path-bash-blocked
description: task-master's Bash tool is hook-blocked from touching .claude/reviewed/ (even read-only ls/cat) — same reviewed-path-gate that applies to spec-master. Rely on the finalized spec's own statement about prior .fail records instead of trying to self-check.
metadata:
  type: feedback
---

Observed 2026-07-22 (issue #108 slicing, fable-roast-cli-guard-followups
batch): running `ls .claude/reviewed/` via Bash to check for prior `.fail`
records before tagging units A/B (which touch the same `bin/cli.js` guard
surface as the already-PASSed #102) was rejected outright by
`reviewed-path-gate.sh`:

> BLOCKED: 'task-master' may not write or otherwise touch .claude/reviewed/
> via Bash - only the reviewer writes the PASS marker there... (Read-only
> commands are blocked too - use the Read tool for that.)

The error text says "use the Read tool for that," but per-file `Read` still
requires knowing the exact `<task-id>.fail` filename in advance — there is
no enumeration path at all for task-master, mirroring the constraint
`docs/plans/2026-07-22-fable-roast-cli-guard-followups.md`'s own Context
section notes applies to spec-master ("Bash cannot enumerate
`.claude/reviewed/` under the reviewed-path-gate for spec-master").

**Why:** the reviewed-path-gate's write/enumerate restriction is scoped to
more personas than just spec-master's Bash tool — task-master hits the same
wall. This isn't a bug to route around; it's the same ownership boundary
described in persona-protocol.md's Review Ownership section (only the
reviewer writes there).

**How to apply:** don't spend a turn trying `ls`/`find`/`cat` against
`.claude/reviewed/` from task-master — it will be blocked. Instead: (1) trust
the finalized spec's own Context/Risks section if it already states whether
a `.fail` record applies to the units being sliced (spec-master has Bash
access during its own drafting phase and states this explicitly when
relevant — e.g. "No `.claude/reviewed/*.fail` record applies" in #108's
spec); (2) if the spec is silent on this and a unit is a re-scope of
previously-FAILed work, ask spec-master (or the orchestrator, which does
have unrestricted Bash) rather than trying to verify it yourself; (3) if you
already know the specific `<task-id>.fail` filename from context (e.g. a
FAIL verdict relayed to you directly), the single-file `Read` tool does work
against that exact path — the gate only blocks Bash-based touch/enumerate,
not a direct `Read` of a known filename.
