# Project constitution
Version: 1.2.0 | Ratified: 2026-07-14 | Last amended: 2026-10-30

## Principles
### 1. Verify, don't assume (MUST)
A plausible-looking result is not proof. Before reporting something as
working (an MCP connection, a test command, a substitution), actually run
it and check the output. This repo has repeated documented incidents of
silent failures — flattened `mcpServers` YAML, unresolved placeholders in
invalid YAML positions — that "looked fine" until checked directly.

### 2. Prefer deterministic scripts over LLM re-derivation (MUST)
`bin/cli.js`'s backfill/update logic exists specifically to make `--update`
a zero-token, mechanical operation. Never hand-edit a file that has a
script-driven path (`--wire-graph-mcp`, `--wire-arxiv-mcp`, `fileHashes`) —
hand-editing risks the exact traps those scripts exist to avoid.

### 3. Version-stamp discipline (MUST)
Version stamping is **per release**, not per commit. A release is one
commit that bumps `.claude-plugin/plugin.json`'s version and adds the
CHANGELOG entry naming that version in the same commit. Content commits
(including changes to `agents/*.md` and templates) need no bump of their own,
and the version never decreases. A consumer project's `--update` sees the
content at releases, so the version must change at each release.
`hooks/scripts/version-stamp-check.sh` checks every release commit in a range
for its same-commit CHANGELOG line and for a non-decreasing version.

### 4. Optional personas degrade gracefully (SHOULD)
References to `spec-master`/`task-master`/`scribe`/`reviewer`/`researcher`/
`milestone-auditor` in shared prose must stay conditionally phrased ("if
present, otherwise...") so a project that skips one doesn't ship broken
prose.

### 5. `tests/validate.sh` is the merge gate (MUST)
Bash syntax, JSON validity, and frontmatter shape checks must pass before
committing; it's cheap and catches the plugin's own historically-worst bug
class — malformed frontmatter silently breaking agent discovery, which this
very ADAPT run hit firsthand on `explorer.md`.

## Amendment log
- 1.0.0 (2026-07-14): ratified.
- 1.1.0 (2026-09-26): P3 clarified to require the version bump and
  CHANGELOG entry in the same commit as the content change (per-commit
  semantics, matching `hooks/scripts/version-stamp-check.sh`), not batched
  once per unit or once per spec (item17-1).
- 1.2.0 (2026-10-30): P3 changed to per-release semantics (lp-vsr).
