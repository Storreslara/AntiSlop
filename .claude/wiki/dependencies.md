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
- **mattpocock/skills (HISTORICAL, no longer a live dependency)** — As of
  2026-07-15, all 12 mattpocock-derived skills used by antislop have been
  vendored one-time into `skills/` (pinned at upstream commit
  e9fcdf95b402d360f90f1db8d776d5dd450f9234). The 12 vendored skills are:
  `grill-me`, `grilling`, `handoff`, `to-spec`, `to-tickets`, `tdd`,
  `diagnosing-bugs`, `improve-codebase-architecture`, `codebase-design`,
  `domain-modeling`, `implement`, `code-review` (see
  `skills/THIRD-PARTY-NOTICES.md`). The `<MATTPOCOCK:slot>` substitution
  machinery that resolved these to externally-installed names is deleted
  (Tracks B–C of plan 2026-07-15-vendor-mattpocock-skills completed). The
  external `npx skills@latest add mattpocock/skills` install step is gone.
  These skills are now shipped first-party as `antislop:<name>` references in
  every persona, with content versioned in this repo. A periodic re-sync
  process (`bash scripts/resync-vendored-skills.sh`) manages drift against
  upstream `main` — see `docs/maintenance/resync-vendored-skills.md`.

## This repo's own ADAPT state
This repo self-hosts the plugin (see `.claude/persona-config.json`'s
`substitutions` field for the exact resolved MCP launch commands and
mattpocock skill name mappings).
