# bin/cli.js

Single file, ~1530 lines, no submodules. Self-described as "the mechanical
half of the antislop ADAPT flow" — deliberately deterministic file
scaffolding only; judgment calls live in `skills/install-antislop/SKILL.md`
instead. Structured top-to-bottom: small pure(ish) helpers, then larger
orchestrating `async function`s, then `main()`, then a `module.exports` of
the pure helpers (imported directly by `tests/cli-backfill.test.js`).

## Modes (dispatched via `process.argv` in `main()`)

- **Fresh scaffold** (default) — copies agents/hooks/skills/templates into
  `.claude/`, prompts (or `--yes`/`--personas=`) for optional persona
  selection, writes `.claude/persona-config.json`, offers to run
  `install-deps.sh`. Refuses to run over an existing install unless
  `--overwrite` is passed (this repo hit that guard mid-ADAPT since
  `persona-config.json` already existed by the time it was tried).
- **`--update`** (`runUpdate`, ~line 480) — deterministic, zero-LLM resync
  against a newer plugin version: diffs stamped files, backfills
  substitutions/hashes from disk for legacy projects, prints unified
  diffs, migrates legacy persona tokens (e.g. `planner` → `spec-master`+`task-master`).
- **`--wire-graph-mcp` / `--wire-arxiv-mcp[=<server-key>]`**
  (`runWireMcp`, ~line 642) — rescopes an MCP server registration from a
  project-wide `.mcp.json` entry into a single persona's frontmatter
  (`explorer.md` or `researcher.md`), removing the project-wide entry.
  Supports `--target=claude|codex`.
- **`--target=cursor`** (`scaffoldCursor`, ~line 770) — scaffolds the
  Cursor adapter into `.cursor/`, merging rather than clobbering an
  existing `.cursor/hooks.json`.
- **`--target=codex`** (`scaffoldCodex`, ~line 1050) — scaffolds the Codex
  adapter into `.codex/`, including TOML-specific MCP-placeholder handling
  (`applyMcpTomlPlaceholder`, `renderMcpTomlBlock`).

## Key helpers

- `versionStamp` / `insertStampAfterFrontmatter` / `copyStamped` (+
  `copyStampedBody` at ~line 407, a second call site) — the version-stamp
  mechanism. Stamp goes right after the closing `---` of YAML frontmatter
  (a leading comment before it silently breaks Claude Code's agent
  discovery — confirmed the hard way on this repo's own `explorer.md`
  during this ADAPT run); falls back to prepending at the top for files
  with no frontmatter (`persona-protocol.md`, `protocol-digest.md`).
- `sha256Hex` — content-hash stamping (stamp line stripped first) so
  `--update` can tell "unmodified copy" from "user-edited" without an LLM.
- `deriveMattpocockSubsForFile` / `deriveMcpLaunchFromDisk` — infer
  substitution values from what's already on disk, backfilling projects
  ADAPTed before the `substitutions`/`fileHashes` scheme existed.
- `deepMerge` — used for merging `settings-fragment.json` /
  `hooks.json` fragments into existing project config without clobbering.
