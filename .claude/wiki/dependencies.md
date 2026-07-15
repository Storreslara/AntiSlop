# Dependencies

## npm
None. `package.json` has no `dependencies`/`devDependencies` field.
`bin/cli.js` imports only Node core modules (`fs`, `os`, `path`, `crypto`,
`readline`, `child_process`). `engines.node >= 18`.

## Optional external tools (shelled out to, not depended on)
- **Code Review Graph** (`code-review-graph`, pip/pipx-installed) — powers
  `explorer`'s structural-query MCP tools. Installed via
  `bin/install-deps.sh` or manually (`pipx install code-review-graph`);
  `cli.js` degrades gracefully (explorer falls back to grep) if absent.
- **arXiv MCP** (`arxiv-mcp-server`, `uvx`-launched) — powers `researcher`'s
  paper-search MCP tools, only relevant if the `researcher` persona is
  selected. Falls back to WebFetch/WebSearch if no working server is found
  at ADAPT time.
- **mattpocock/skills** (`npx skills@latest add mattpocock/skills`) —
  third-party skills (`grill-me`, `to-tickets`, `tdd`, `diagnosing-bugs`,
  `improve-codebase-architecture`, `setup-matt-pocock-skills`) that
  `spec-master`/`task-master`/`scribe`/`milestone-auditor`/`lead-programmer`
  invoke by name once installed at user or project scope.

## This repo's own ADAPT state
This repo self-hosts the plugin (see `.claude/persona-config.json`'s
`substitutions` field for the exact resolved MCP launch commands and
mattpocock skill name mappings).
