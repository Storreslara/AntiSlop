<!-- code-review-graph MCP tools -->
## Code Review Graph

This project has a code-review-graph knowledge graph, but its MCP
connection is scoped to the `explorer` persona only (not available
directly in this session) — dispatch `explorer` for structural questions
(callers/callees, blast radius, architecture overview, test coverage);
it uses the graph internally and self-reports whether an answer was
graph-derived or grep-fallback. The graph auto-updates on file changes via
hooks and a git pre-commit check regardless of which persona is active.
