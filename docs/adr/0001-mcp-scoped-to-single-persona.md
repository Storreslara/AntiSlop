# ADR 0001: MCP servers are scoped to a single persona's frontmatter, never project-wide

Date: 2026-07-14
Status: Accepted (already the shipped design; documented here for the
historical record after re-confirming it live during this repo's own ADAPT)

## Context
Third-party MCP integrations (Code Review Graph for `explorer`, arXiv for
`researcher`) install themselves via their own CLIs, which by default
write a project-wide `.mcp.json` entry — every persona and the main
session would inherit that connection.

## Decision
`bin/cli.js --wire-graph-mcp` / `--wire-arxiv-mcp` mechanically move the
launch command from `.mcp.json` into the single relevant persona's
`mcpServers:` frontmatter block, then delete the project-wide `.mcp.json`
entry. `mcpServers` must be a LIST of single-key dicts each with an
explicit `type:` — a flattened bare map keyed by server name is silently
ignored with no error at all, which is why this is scripted rather than
hand-edited.

## Consequences
- Only `explorer` gets graph tools; only `researcher` gets arXiv tools.
  Other personas (and the main session) fall back to grep/WebFetch, which
  is the intended, cheaper default for most work.
- Verification requires spawning the specific persona and checking its
  self-reported provenance (graph-derived vs. grep-derived) — a
  plausible-looking answer is not proof, since grep alone can answer
  simple structural queries even with the MCP fully disconnected.
- Re-confirmed live on this repo (2026-07-14): `explorer` self-reported
  `PROVENANCE: graph-derived` (used `query_graph_tool` +
  `semantic_search_nodes_tool`); `researcher` self-reported
  `PROVENANCE: mcp-derived` (used `search_papers`, found arXiv 2505.12501).
