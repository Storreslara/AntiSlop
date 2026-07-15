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

## 2026-07-15 (continued)
- **Completed Track A (Step A.3) — Vendor the 3 repointed mattpocock skills:** vendored `to-spec`, `to-tickets`, and `code-review` from mattpocock/skills @ SHA e9fcdf95b402d360f90f1db8d776d5dd450f9234 as first-party `skills/` entries (provenance headers added). Each references `/setup-matt-pocock-skills` in upstream body — repointed to antislop's native mechanism (`install-antislop` + `.claude/persona-config.json` `issueTracker` field + retrieval contract) per plan design. No breaking changes to body prose besides the repoints. All 12 mattpocock-dependency skills now on disk (Track A complete): 9 byte-verbatim + 3 repointed. Acceptance: `grep -rniI 'setup-matt-pocock-skills' skills/to-spec skills/to-tickets skills/code-review` returns 0 matches; repoint recorded in each skill's provenance header; `bash tests/validate.sh` passes; `bash scripts/resync-vendored-skills.sh --check` exit 0 (0 drift on the pinned SHA).
- **Completed plan 2026-07-15-vendor-mattpocock-skills (all tracks A–F):** vendored the full 12-skill mattpocock dependency closure (grill-me, grilling, handoff, to-spec, to-tickets, tdd, diagnosing-bugs, improve-codebase-architecture, codebase-design, domain-modeling, implement, code-review) first-party into `skills/` under MIT license (© Matt Pocock), pinned at SHA e9fcdf95b402d360f90f1db8d776d5dd450f9234 (Track A complete: 9 byte-verbatim + 3 with documented repoints of /setup-matt-pocock-skills refs). Deleted the `<MATTPOCOCK:slot>` substitution machinery entirely (MATTPOCOCK_RE, applyMattpocockSubs, deriveMattpocockSubsForFile, hasMattpocockResidue, the substitutions map, --with-mattpocock/--only-mattpocock install paths, TDD-first test rewrite: Tracks B–C complete). Simplified install/adapt flow (mattpocock-selection step removed; issue-tracker capture moved to install-antislop native step: Track D complete). Documented periodic re-sync process (docs/maintenance/resync-vendored-skills.md + scripts/resync-vendored-skills.sh --check: Track E complete). Bumped version to 0.12.0, re-stamped all affected agent files, recorded capability loss (no more <MATTPOCOCK:slot> extension point; add new skills as first-party skills/<name>/ instead) in CHANGELOG.md [0.12.0] and new ADR-0005 (Track F complete). Acceptance: all Tracks landed reviewer-PASSed; plugin.json/package.json version equal at 0.12.0; all 12 skills `[OK]` under resync check; `bash tests/validate.sh` exit 0. ADR-0005 supersedes ADR-0003's slot-wiring language; deps.md and architecture.md updated to reflect final state (mattpocock/skills is one-time pinned source, not runtime dependency). Full plan: docs/plans/2026-07-15-vendor-mattpocock-skills.md. Re-sync runbook: docs/maintenance/resync-vendored-skills.md. Licenses: skills/THIRD-PARTY-NOTICES.md.
