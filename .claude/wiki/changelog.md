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

## 2026-07-15
- **Completed Track 1 — Persona rename:** `repo-historian` → `scribe` across all references (plugin source + adapted copies, templates, adapters, shared prose, tests, CLI). Added `'repo-historian': 'scribe'` to `bin/cli.js` `LEGACY_PERSONA_MAP` so existing adapted projects migrate on `--update`.
- **Completed Track 2 — Skills for planning personas:** wired `to-spec` (existing published mattpocock skill) into `spec-master` via `<MATTPOCOCK:to-spec>` slot (complements `grill-me` — sequential not overlapping); authored new first-party `pathfinder` skill (tailored derivative of mattpocock's `wayfinder`, not a passthrough) for `task-master` to build reliable dispatch instructions; resolved OQ6 (to-spec template LAYERS on top of v0.9.0 spec-kit, not replace).
- **Completed Track 3 — Persona split:** `hivemind` → `spec-master` (spec authoring, grilling, .fail check, debug spec on 2-FAIL-cap) + `task-master` (dispatch-instruction authoring, `to-issues` slicing outright, per-unit model routing, upstream signal on spec gaps); added `'hivemind': ['spec-master', 'task-master']` one-to-two mapping to `LEGACY_PERSONA_MAP`; updated orchestrator routing (two-stage pipeline, FAIL → lead-programmer, 2-FAIL-cap → spec-master debug spec → task-master re-derive).
- **Completed Track 4 — Reviewer critique skill:** authored new first-party `roast-work` skill for `reviewer` (detail-driven critique: contradictions, missing parts, logic gaps, security vulnerabilities, actionable feedback); Tension 1 resolved advisory-only (never gates, appends after verdict); Tension 2 resolved opus default + fable for heavy lifting (≥8 files, ≥400-line diff, structural, or security-sensitive) via non-authoritative advisory dispatch.
- **Final consolidation:** version bumped to 0.10.0 across plugin and package manifests; all version-stamped files re-stamped; CHANGELOG.md updated with full release notes; fileHashes regenerated via deterministic `node bin/cli.js --update`.
