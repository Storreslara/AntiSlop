# Project constitution
Version: 1.1.0 | Ratified: 2026-07-14 | Last amended: 2026-09-26

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
Any change to a version-stamped file (`agents/*.md`, templates) must bump
`.claude-plugin/plugin.json`'s version and add a CHANGELOG entry, since the
`--update` mechanism depends on the version actually changing when content
does. The bump and CHANGELOG entry must land in the **same commit** as the
content change — checked **per commit, not once per unit or once per
spec**: `hooks/scripts/version-stamp-check.sh` verifies every commit that
touches a version-stamped path against its own immediate parent, so a later
commit's bump does not excuse an earlier commit in the same unit that lacks
one. A consumer project's `--update` can run against any commit, not only a
unit's or a spec's final one, so any intermediate commit shipping changed
content under an unchanged version leaves `--update` staleness-blind for
that commit.

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
