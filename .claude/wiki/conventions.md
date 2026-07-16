# Conventions

- **`bash tests/validate.sh` before committing** — bash syntax, JSON
  validity, agent/skill frontmatter shape, optional-persona conditional
  phrasing, plus the Node backfill unit tests (it shells out to
  `node tests/cli-backfill.test.js` internally, no separate invocation
  needed). This is `testAndLintCommand` in `.claude/persona-config.json`.
- **Version-stamp discipline**: any change to a version-stamped file
  (`agents/*.md`, `templates/*`) needs a `.claude-plugin/plugin.json`
  version bump + a `CHANGELOG.md` entry — the `--update` mechanism only
  regenerates a file when the stamped version actually differs.
- **Never hand-edit MCP wiring or fileHashes** — use
  `bin/cli.js --wire-graph-mcp` / `--wire-arxiv-mcp`; hand-editing risks a
  flattened `mcpServers` map, which connects to nothing with no error.
- **Optional-persona references stay conditionally phrased** ("if present,
  otherwise...") in shared prose (`orchestrator.md`, `lead-programmer.md`,
  `commands/start-feature-team.md`) so a project that skips a persona still
  gets a plain copy that degrades gracefully.
- **No npm dependencies** — `bin/cli.js` uses only Node core modules.
  Optional external tooling (Code Review Graph, mattpocock skills) is
  shelled out to via `install-deps.sh`, never depended on directly.
- **Judgment vs. mechanism split**: `bin/cli.js` does deterministic file
  scaffolding only; anything requiring judgment (persona selection wording,
  substitution discovery, hook-verification interpretation) lives in
  `skills/install-antislop/SKILL.md` instead. Don't blur this line by
  adding judgment calls into `cli.js`.
- See also the [project constitution](../constitution.md) for the
  human-ratified version of several of these rules, with rationale.
