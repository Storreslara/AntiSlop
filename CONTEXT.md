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
- **Adapter behavioural parity** (issue #202, 2026-08-01 efficiency pass 2,
  Step 4) — a merge-gate check that the adapter ports' *scripts* produce the
  same observable behaviour as the main Claude Code hook, not merely that
  the same *text* is present. `tests/adapter-stop-gate-parity.test.sh`
  drives `hooks/scripts/stop-gate.sh` and both adapter ports
  (`adapters/{codex,cursor}/hooks/scripts/stop-gate.sh`) through the same
  `defer:`-dedupe scenarios *and* the empty-after-colon `defer:`/`skip:`
  rejection scenario, asserting the same audit-log record count and exit
  code from each, scoped to those two scenarios — not a general
  behavioural-parity guarantee for every hook. Do not conflate with the
  other two parity mechanisms in this repo: **byte-parity**
  (`tests/validate.sh`'s check that the three copies of
  `hooks/scripts/lib/agent-identity.sh` are byte-identical, since that file
  derives its behaviour from its own on-disk location rather than any
  per-platform input) and **document/section-presence parity**
  (`tests/adapter-protocol-parity.test.js`, which checks that canonical
  protocol *sections* are accounted for in the Codex/Cursor doc ports —
  presence, not runtime behaviour). See
  [modules/adapters.md](.claude/wiki/modules/adapters.md) and
  [modules/hooks.md](.claude/wiki/modules/hooks.md).
- **clear-watermark** — `.claude/.last-review-clear`, a zero-byte file whose
  mtime records when the reviewer's flag-clear path (via `stop-gate.sh`'s
  SubagentStop grant branch) last succeeded, as the reference point for
  detecting whether a marker has been written since the previous review.
  Used in issue #153's implementation (Step 2) to couple the reviewer's
  flag-clear to a marker-write requirement: `marker_since_last_clear` returns
  2 when the watermark is absent (fail-open bootstrap), 0 when a PASS or FAIL
  marker is newer than the watermark, and 1 otherwise (triggering a block on
  the reviewer's stop with an exit-2 flag-clear refusal). Defer-immune by
  design (immune to the dispatch-time `defer:` convention that defeats a
  naive mtime-of-flag approach); see issue #153 Probe case 6.
- **Protocol excerpt** — the subset of `templates/persona-protocol.md`'s 16
  `## `-delimited canonical sections that a given full-tier persona's
  `.claude/agents/*.md` mirror actually inlines, per `bin/cli.js`'s
  `PROTOCOL_SECTIONS_BY_PERSONA` matrix (issue #190, 2026-08-01 efficiency
  pass, finding F1). Distinct from the full/slim **tier** (which file a
  persona gets): the excerpt is which sections *within* the full tier. Three
  fail-closed rules govern it: an unknown persona name gets every section;
  a matrix row naming a non-existent heading throws at load; any persona in
  `gatedAgents` force-includes "WIP sentinel" and "Pending-review flag"
  regardless of its row. Claude-Code-only by construction — the Cursor and
  Codex adapter ports have no per-persona seam and keep carrying the union.
  `.claude/persona-protocol.md` exists on disk as the full, untrimmed
  reference copy a trimmed persona can read on demand (reversing the
  earlier `OQ11=DROP` decision, whose premise stopped holding once excerpts
  were trimmed). See [protocol-delivery-tiers.md](.claude/wiki/protocol-delivery-tiers.md).
- **Measured reviewer tier** — the reviewer's `sonnet`/`opus` model is
  decided at reviewer-*dispatch* time (not pre-implementation) by
  `hooks/scripts/reviewer-tier.sh <task-id> <git-range>`, a deterministic,
  fail-closed script (not a registered hook — deliberately absent from
  `hooks/hooks.json`; it's an orchestrator-invoked helper). It prints
  `sonnet` only when the diff is ≤40 changed lines AND ≤3 changed files AND
  touches no sensitive path class; otherwise `opus`. Replaces the earlier
  ADR-0006 scheme where `task-master` guessed reviewer tier from its own
  pre-implementation `Suggested model: haiku` tag — a prediction that was
  reachable roughly 0% of the time in practice. This was ADR-0009's historical
  rationale, measured at issue #190 (finding F2): no unit in this repo was
  tagged `haiku`. The orchestrator's judgment
  may **downgrade** `sonnet` → `opus` but may **never upgrade** `opus` →
  `sonnet`; `fable` stays permanently excluded from the gate (ADR-0004) and
  a prior `.fail` record still forces `opus`. Measured on 2026-08-03 at 8/60
  commits (13.3%), inside the predicted band. See
  [ADR 0009](docs/adr/0009-reviewer-tier-measured-eligibility.md), which
  amends [ADR 0006](docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md).
- **The graph** — Code Review Graph, a third-party MCP server providing
  structural code queries (callers/callees, blast radius, architecture
  overview). Scoped to `explorer` alone, never project-wide — see
  [ADR 0001](docs/adr/0001-mcp-scoped-to-single-persona.md).
- **Skills-library remediation completed** (2026-08-07, spec #245 / unit #255) —
  all persona-declared skills are now reachable in every mode. The `disable-model-invocation`
  flag was stripped from `to-spec`, `to-tickets`, `handoff`, and
  `improve-codebase-architecture`; `grill-me` repointed to `grilling`; `implement`
  deleted; `domain-modeling` wired into `scribe`. Plugin cache refreshed to
  v0.25.0 and reachability verified live post-restart. **All reachability claims
  (Steps 4/5) are now verified live, not just by file-content grep.** The `fm-noflag`
  declared-deviation class (stripping the model-invocation flag from `handoff` and
  `improve-codebase-architecture`) is now formally documented in [ADR 0012](docs/adr/0012-vendored-skill-declared-deviations.md);
  [ADR 0005](docs/adr/0005-vendor-mattpocock-skills.md) amended to reference it.
  See `docs/plans/2026-08-04-skills-library-remediation.md` Revision 5.
- **Upstream MCP tool naming gap** (recorded 2026-08-06) — code-review-graph
  installer templates contain five MCP tool names lacking the `_tool` suffix
  that the live MCP server actually exposes: `get_flow`, `list_graph_stats`,
  `get_community`, `list_flows`, `find_large_functions`. Seven occurrences in
  shipped SKILL.md files (`debug-issue`, `explore-codebase`, `refactor-safely`).
  Root cause is upstream installer content bug, not antislop defect. Now that
  these SKILL.md files are tracked/shipped, the gap is more visible and should
  be fixed in the installer itself.
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
  after the verdict line. Runs inline, as part of the single reviewer
  dispatch, only — there is no separate fable advisory pass.
- **`disable-model-invocation` flag** — a hard, mode-independent skill
  configuration flag that removes a skill from context in every mode
  (direct invocation, teams mode, subagent context). A skill carrying
  `disable-model-invocation: true` in its frontmatter is entirely
  unreachable — not just in teams mode, but in all modes. This is distinct
  from skill *licensing*, which gates based on permission levels or
  operational mode; this flag is a blanket removal. See unit #254 (2026-08-07)
  for the correction to this repo's prior documentation, which had stated
  the weaker (false) version: "not in teams mode only."
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
