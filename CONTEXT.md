# CONTEXT

Shared-language glossary for this repo. Canonical alongside `docs/adr/`;
owned by `scribe` — keep current, don't let the wiki and this
drift apart.

- **ADAPT** — the one-time per-project setup process that turns the
  plugin's generic personas/hooks/templates into a project-specific
  `.claude/` config. Split into a mechanical half (`bin/cli.js`, zero LLM
  cost in the common case) and a judgment half
  (`skills/install-antislop/SKILL.md`).
- **Persona** — a subagent system prompt in `agents/*.md`. "Core" personas
  (orchestrator, explorer, lead-programmer) are always installed; "optional"
  personas (spec-master, task-master, scribe, reviewer, researcher,
  milestone-auditor) are selected per-project during ADAPT. `spec-master`
  turns ambiguous goals into precise specs via grilling and publishes via
  `to-spec`; `task-master` reads finalized specs and writes dispatch
  instructions for `lead-programmer`, owns `to-issues` slicing outright, tags
  per-unit models. `scribe` maintains institutional knowledge (wiki, CONTEXT.md,
  ADRs). `reviewer` is the independent verifier (the Writer/Reviewer split).
  `researcher` bridges academic literature and spec authoring. `milestone-auditor`
  hunts premise gaps at milestone boundaries after all units reach PASS.
- **Version-stamped file** — any ADAPT-copied file carrying a
  `<!-- antislop vX.Y.Z | source: ... | ADAPT-substituted -->` comment,
  which lets `bin/cli.js --update` tell "plugin's current version" from
  "what's on disk" and detect local edits via `fileHashes` without an LLM.
- **`--update` semantics** — `bin/cli.js --update` is the mechanism for
  refreshing ADAPT-stamped files. Crucially, the `--check` flag is a
  force-the-loop control, not a dry-run: `--check` still writes files via
  `copyStampedBody` and still rewrites `persona-config.json`, unlike
  `scripts/resync-vendored-skills.sh --check` which is genuinely read-only.
  Stamps self-heal automatically: `--update` refreshes a mirror's
  `<!-- antislop vX.Y.Z -->` stamp whenever the resolved plugin version
  differs from the stamp on disk, even when the mirror's body content is
  unchanged, retiring the prior hand-patch workaround.
- **Substitution** — a placeholder in a shipped persona file (e.g.
  `<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>`) resolved to a real
  value at ADAPT time and recorded in `.claude/persona-config.json`'s
  `substitutions` field.
- **The Writer/Reviewer split** — the system's core safety property: the
  `lead-programmer` writes code, but only the independent `reviewer`
  (which did not write the code) can mark a unit done (`.claude/reviewed/*.pass`).
  Enforced mechanically by `stop-gate.sh` and `reviewer-route-gate.sh`, not
  just by persona instruction.
- **Gate** — a hook script that mechanically blocks an action rather than
  relying on a persona to comply (e.g. `stop-gate.sh`, `protected-paths.sh`,
  `reviewed-path-gate.sh`). Config-driven via `.claude/persona-config.json`.
- **The graph** — Code Review Graph, a third-party MCP server providing
  structural code queries (callers/callees, blast radius, architecture
  overview). Scoped to `explorer` alone, never project-wide — see
  [ADR 0001](docs/adr/0001-mcp-scoped-to-single-persona.md).
- **This repo's own ADAPT state** — this repo self-hosts the plugin it
  ships (dogfooding). Its `.claude/persona-config.json` documents exactly
  which personas and substitutions this repo itself uses.
- **`to-spec` skill** — vendored first-party skill (originally from Matt
  Pocock's `skills` repo, see `skills/THIRD-PARTY-NOTICES.md`), wired to
  `spec-master` via `antislop:to-spec`. Turns a finalized spec
  conversation into a single published spec (Problem Statement / Solution /
  User Stories / Implementation Decisions / Testing Decisions / Out of Scope)
  on the issue tracker, no further interview. Complements `grill-me`
  sequentially: grill to resolve ambiguity, then to-spec to synthesize and
  publish. The template LAYERS on top of the v0.9.0 spec-kit format (Goal →
  Context → Clarifications → …), not replacing it.
- **`pathfinder` skill** — first-party skill for `task-master`, derived from
  Matt Pocock's `wayfinder` (adapted for dispatch, not a passthrough). Helps
  `task-master` build reliable, detailed, unambiguous dispatch tasks: one
  decision/one unit per ticket, refer-by-name, explicit blocking/ordering
  edges, precise acceptance criteria (enforces the machine-checkable-criteria
  rule). Ships via plugin-source `skills/pathfinder/SKILL.md` path.
- **`roast-work` skill** — first-party skill for `reviewer`, a detail-driven
  critique rubric (contradictions, missing parts, logic gaps, security
  vulnerabilities, actionable feedback) written to Matt Pocock's quality bar.
  Advisory and non-gating only — PASS/FAIL stays determined by the
  acceptance-criteria command + the existing materiality filter; roast-work
  never flips a verdict. Appended as a clearly-demarcated advisory section
  after the verdict line.
- **Agent identity** — the possibly-namespaced wire form of a persona name,
  `[<namespace>:]<persona-name>`, appearing in hook payloads' `agent_type` and
  `subagent_type` fields. The gate hooks normalize identities to handle both
  bare dispatch (project-local copies) and namespaced dispatch (marketplace
  plugin), using asymmetric matching: liberal matching (any namespace) at sites
  where a miss fails open, conservative matching (recognized namespace only) at
  privilege-grant sites. See plan #139 / `docs/plans/2026-07-28-agent-identity-namespace-gate-fix.md`;
  the shared library is `hooks/scripts/lib/agent-identity.sh`, replicated
  identically across all three platform ports. [ADR 0007](docs/adr/0007-agent-identity-audit-logging-hardening.md)
  documents the audit-logging hardening applied post-Step-1.
- **FAIL routing (post-reviewer)** — normal FAIL routes the defect list to
  `lead-programmer` (unchanged). At the 2-FAIL cap, the orchestrator routes to
  `spec-master` to produce a debug spec (diagnosis using the latest `.fail`
  record plus git log/git diff over fix-attempt commits, revised steps) then
  `task-master` re-derives dispatch instructions from the corrected spec.
  `task-master` is never a re-plan owner. Mid-flight "spec gap" signals also
  route back to `spec-master`.
- **Roast-work routing (fable heavy lifting)** — `reviewer` frontmatter defaults
  to `model: opus` (the authoritative PASS/FAIL gate always opus). For heavy
  units — ≥~8 impacted files OR ≥~400-line diff OR structural/cross-cutting
  change OR security-sensitive surface — the orchestrator dispatches an
  additional non-authoritative `roast-work` advisory pass on fable. The
  judgment-critical gate (acceptance-criteria command) stays on opus; only the
  non-gating bulk-context critique uses fable. Tagged `Roast pass: fable` by
  `task-master` like the `Suggested model` per-unit pattern.
