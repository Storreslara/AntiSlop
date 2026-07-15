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
- **mattpocock/skills** (`npx skills@latest add mattpocock/skills`) — still
  a live runtime dependency as of 2026-07-15: `agents/*.md` (`lead-
  programmer`, `task-master`, `milestone-auditor`, `scribe`, `spec-master`)
  still carry `<MATTPOCOCK:slot>` placeholders that ADAPT/`--update`
  resolves to this EXTERNALLY-installed package's skill names. Plan
  `docs/plans/2026-07-15-vendor-mattpocock-skills.md` Track A has now
  vendored all 12 of those skills' CONTENT first-party under `skills/`
  (`grill-me`, `to-tickets`, `tdd`, `diagnosing-bugs`, `improve-codebase-
  architecture`, `to-spec`, `code-review`, and 5 more — see
  `skills/THIRD-PARTY-NOTICES.md`), but the personas don't reference that
  vendored content yet — this line stays until Track B repoints every
  `<MATTPOCOCK:slot>` to `antislop:<name>` and Track C deletes the
  substitution machinery, at which point this external dependency drops out.

## This repo's own ADAPT state
This repo self-hosts the plugin (see `.claude/persona-config.json`'s
`substitutions` field for the exact resolved MCP launch commands and
mattpocock skill name mappings).
