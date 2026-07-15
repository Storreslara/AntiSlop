# Changelog (lead-programmer digest log)

Dated log of persona-driven work in this repo. Distinct from the project's
own `CHANGELOG.md` (which tracks plugin version releases for consumers).

## 2026-07-14
- Ran `install-antislop` (fresh ADAPT) on this repo — previously had a
  broken partial/manual setup (no `persona-config.json`; `explorer.md`'s
  frontmatter contained an unresolved placeholder in an invalid YAML
  position, silently breaking its agent registration entirely). Full
  persona selection: all optional personas included (spec-master,
  task-master, scribe, researcher, milestone-auditor, reviewer — explicit
  confirmation given for reviewer, the system's core safety property).
- Wired Code Review Graph MCP to `explorer` only and arXiv MCP
  (`arxiv-mcp-server` via `uvx`) to `researcher` only — both verified live
  in-session (self-reported `PROVENANCE: graph-derived` /
  `PROVENANCE: mcp-derived`, not a grep/WebFetch fallback).
- Set `.claude/settings.json`'s `"agent": "orchestrator"` — this repo's
  main session was running as plain default Claude Code before this,
  despite the plugin being enabled; personas were invocable as subagents
  but nothing routed the main session through the orchestrator.
- Ratified `.claude/constitution.md` v1.0.0 (5 principles, seeded from
  `CONTRIBUTING.md`/`README.md`/`install-antislop`'s own "verify, don't
  assume" theme).
- Seeded this wiki, `CONTEXT.md`, and `docs/adr/0001-mcp-scoped-to-single-persona.md`.
