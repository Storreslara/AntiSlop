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
- **Microworld bundle layout**: each bundle lives at `microworlds/<unit-slug>/`
  and is **gitignored working-tree scratch**, never committed. Contents:
  `manifest.json` (unit slug, watch globs, function entries, timeout);
  `run.sh` (executable, relocatable — resolves its own internal paths relative
  to `$(dirname $0)`, not hard-coded `microworlds/<unit>/`);
  `inputs/` and `expected/` (test fixtures); `README.md` (human-facing
  description for review). `lead-programmer` executes `run.sh` during
  implementation, producing the bundle; `reviewer` verifies bundle presence
  by filesystem check (not a diff check) and never executes a bundle's
  entries; the `PostToolUse` hook re-runs on every edit. Bundles are
  expected to be absent in CI and fresh clones (normal state). On escalation,
  the reviewer snapshots the bundle to `.claude/human-review/<task-id>/`
  (escalation packet, untracked but persistent until resolution).
- **Microworld bundle format v2 — `functions[]` and the entry contract:**
  `manifest.json` gains an optional `functions[]` array (alongside `timeoutSeconds`,
  the check timeout), allowing the dashboard to enumerate and invoke individual
  function entries separately from the bundle's `run.sh` check. Each entry is a dict
  with: `id` (stable, unique-within-the-bundle slug), `group` (grouping label),
  `label` (human-readable UI tab name), `entry` (bundle-relative path to an
  executable), `description`, optional `location` (author-declared pointer to where
  the code lives in the repo), and `inputs` (optional array of named input parameters
  — `name`, `type`, optional `default`, `description` — that defines the JSON object
  passed on stdin). **Entry execution contract:** a function entry is an executable
  that takes one JSON object on stdin and writes output to stdout; invoked in a child
  process with `cwd` set to the project root and `MICROWORLD_BUNDLE_DIR` set to the
  bundle's directory path (so relative paths in the entry's inputs can be resolved).
  An empty argv array, no shell (`shell: false`) — entries are direct child processes
  passed a JSON payload, allowing language-agnostic, deterministic invocation by the
  dashboard's Node consumer. The `location` field is optional, author-declared at
  authoring time, and carries a staleness risk (it goes stale when code moves, with
  no auto-revalidation); see **Function location** in CONTEXT.md. **Authoring
  policy:** `functions[]` is optional in general — a bundle without it is fully valid
  and appears in the dashboard with only its check status and nothing to invoke.
  `lead-programmer` SHOULD author `functions[]` (with `location` on each entry) for
  units meeting the heavy-unit trigger (see
  [ADR 0004](../../docs/adr/0004-reviewer-roast-work-dual-model-routing.md), as
  amended by
  [ADR 0013](../../docs/adr/0013-fable-removed-from-roast-work-advisory-pass.md)),
  and MAY skip `functions[]` and `location` otherwise. Every microworld bundle still
  gets `run.sh` (the check) regardless of trigger status; only `functions[]`
  (human-explorable entries) is conditional on the heavy-unit trigger.
- See also the [project constitution](../constitution.md) for the
  human-ratified version of several of these rules, with rationale.
