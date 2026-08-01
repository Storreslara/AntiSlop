# adapters/

Self-contained ports of the same three-layer shape (personas / hooks /
ADAPT) to other coding agents. Each mirrors the Claude Code layout in its
own idiom rather than sharing files.

## adapters/cursor/
Cursor port: `.cursor-plugin/` (plugin manifest), `agents/*.md`,
`hooks/{hooks.json,scripts}`, `rules/persona-protocol.mdc` (a
project-wide, always-apply rule carrying the **full, untrimmed** protocol).
Claude Code does not deliver its protocol via an `@include` either —
`bin/cli.js` physically inlines a per-persona trimmed excerpt into each
`.claude/agents/*.md` mirror (see
[protocol-delivery-tiers.md](../protocol-delivery-tiers.md)). Cursor's
`.mdc` has no per-persona seam, so it is a hand-adapted condensed rewrite
that must keep carrying the union for every persona — this is what bounds
the Claude-Code-only trimming mechanism's blast radius. `bin/cli.js
--target=cursor` scaffolds this into a project's `.cursor/`, merging
rather than clobbering an existing `.cursor/hooks.json`.

## adapters/codex/
Codex port: `.codex-plugin/`, `agents/*.toml` (TOML, not markdown — Codex's
native agent format), `hooks/{hooks.json,scripts}`,
`agents-md-fragment.md` (inlined into the project's `AGENTS.md` as a single
shared document, rather than kept as a separate protocol file — Codex has
no per-persona seam either, so like Cursor's rule file it carries the full
union, never a trimmed excerpt). Not every persona is ported — see
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
