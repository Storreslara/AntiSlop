# adapters/

Self-contained ports of the same three-layer shape (personas / hooks /
ADAPT) to other coding agents. Each mirrors the Claude Code layout in its
own idiom rather than sharing files.

## adapters/cursor/
Cursor port: `.cursor-plugin/` (plugin manifest), `agents/*.md`,
`hooks/{hooks.json,scripts}`, `rules/persona-protocol.mdc` (an
always-apply rule — Cursor's equivalent of the `@.claude/persona-protocol.md`
include line). `bin/cli.js --target=cursor` scaffolds this into a
project's `.cursor/`, merging rather than clobbering an existing
`.cursor/hooks.json`.

## adapters/codex/
Codex port: `.codex-plugin/`, `agents/*.toml` (TOML, not markdown — Codex's
native agent format), `hooks/{hooks.json,scripts}`,
`agents-md-fragment.md` (inlined into the project's `AGENTS.md` rather than
kept as a separate protocol file, since Codex doesn't have Claude Code's
`@include` syntax). Not every persona is ported — see
`docs/codex-port-notes.md` for which ones and why. MCP wiring for Codex
uses TOML-specific placeholder handling (`applyMcpTomlPlaceholder`,
`renderMcpTomlBlock` in `bin/cli.js`) since `.mcp.json`-style JSON doesn't
apply there.

## Porting notes
`docs/cursor-port-notes.md` and `docs/codex-port-notes.md` document the
per-platform gaps and decisions (e.g. which personas didn't port, which
Claude-Code-specific mechanisms have no equivalent). Read those before
assuming an adapter has full parity with the Claude Code plugin — it
doesn't, by design; see each notes file for the specific deltas.
