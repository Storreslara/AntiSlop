# Project constitution
Version: 1.0.0 | Ratified: 2026-07-14 | Last amended: 2026-07-14

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
does.

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
