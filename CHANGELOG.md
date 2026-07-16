# Changelog

All notable changes to the antislop plugin (formerly seb-personas) are
recorded here. Dates are ISO (YYYY-MM-DD).

## [0.13.0] - 2026-07-16

### Added
- **Signal-gated sonnet on the reviewer's authoritative PASS/FAIL gate (amends
  ADR-0004).** The gate defaults to opus and may run on sonnet for
  demonstrably-mechanical units, never on fable. See ADR-0006
  (docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md) for the full
  decision, conjunctive conditions (haiku-tagged lead-programmer AND not
  heavy-unit-trigger AND no prior `.fail`), escalation protocol, and impact on
  the core Writer/Reviewer safety property.

## [0.12.1] - 2026-07-16

### Fixed
- **`.claude-plugin/plugin.json`'s marketplace/install description still
  named the old `hivemind` persona.** `hivemind` was split into
  `spec-master` + `task-master` back in v0.10.0 (see
  `docs/adr/0003-hivemind-split-spec-master-task-master.md`), but the
  plugin manifest's `description` field — shown in the Claude Code plugin
  marketplace/install UI — was never updated to match. The optional-personas
  list now reads `spec-master/task-master/scribe/reviewer/researcher/
  milestone-auditor`.

## [0.12.0] - 2026-07-15

### Added
- **12 `mattpocock/skills` vendored first-party** into `skills/` (verbatim,
  with provenance headers and a pinned upstream SHA): `grill-me`, `grilling`,
  `handoff`, `to-spec`, `to-tickets`, `tdd`, `diagnosing-bugs`,
  `improve-codebase-architecture`, `codebase-design`, `domain-modeling`,
  `implement`, `code-review` — see `skills/THIRD-PARTY-NOTICES.md` for the
  full MIT notice and per-skill upstream paths. `to-spec`/`to-tickets`/
  `code-review` are documented repoints (their `/setup-matt-pocock-skills`
  reference replaced with antislop's native `install-antislop` setup;
  otherwise byte-verbatim).
- `docs/maintenance/resync-vendored-skills.md` + `scripts/resync-vendored-
  skills.sh --check`, an actionable periodic re-sync runbook/drift-check
  against the pinned upstream SHA.

### Removed
- **The `<MATTPOCOCK:slot>` substitution machinery** in `bin/cli.js`
  (`MATTPOCOCK_RE`, `applyMattpocockSubs`, `deriveMattpocockSubsForFile`,
  `hasMattpocockResidue`, the `substitutions.mattpocockSkills` backfill/map,
  the `--with-mattpocock`/`--only-mattpocock` install path) and the matching
  `bin/install-deps.sh` branch. Every persona reference that used to resolve
  through a slot (`spec-master`, `milestone-auditor`, `task-master`, `scribe`,
  `lead-programmer`) now points directly at the vendored `antislop:<name>`
  skill. `skills/install-antislop`'s mattpocock-selection step and
  `update-fallback.md`'s unresolved-slot recovery path are dropped
  accordingly; the issue-tracker capture the wizard used to seed is now a
  native `install-antislop` step (`issueTracker` in `persona-config.json`).
- **Capability loss (intentional, recorded per Constitution P4/OQ1):**
  removing the machinery removes the extension point for wiring an
  arbitrary *unported* mattpocock skill via a `<MATTPOCOCK:slot>` +
  `persona-config.json` map entry — that indirection no longer exists. A
  consumer who wants a new mattpocock (or any third-party) skill now adds it
  as a first-party `skills/<name>/` entry instead, the same pattern already
  used for `pathfinder`/`fail-triage`/the 12 skills above. See
  `docs/adr/0005-vendor-mattpocock-skills.md`.

## [0.11.0] - 2026-07-15

### Added
- **`handoff` skill** wired as the 7th `<MATTPOCOCK:slot>` passthrough
  substitution, preloaded into `lead-programmer` only and available
  project-wide as the `/handoff` slash command. Compacts a cut-off unit's
  conversation into a resumption doc (OS temp dir) for a fresh session to
  pick up. Complements, never replaces, the WIP sentinel — a resumption aid,
  not a turn-end permission signal; changes no gate.
- **`fail-triage` skill** (first-party, `skills/fail-triage`), a tailored
  derivative of `mattpocock/skills`' `triage` scoped only to the post-FAIL
  path (2-FAIL-cap / debug-spec escalation, not every FAIL). Wired into
  `spec-master`'s existing debug-spec step to sharpen its root-cause
  diagnosis with an explicit verify/reproduce + categorize front-half, before
  the existing revised-step format. Drops `triage`'s issue/PR state machine,
  label roles, external-PR request surface, `/grilling` +
  `/domain-modeling` deps, and `AGENT-BRIEF.md`/`OUT-OF-SCOPE.md` companion
  docs — same relocation pattern `pathfinder` used for `wayfinder`. The
  reviewer PASS gate and normal first-FAIL→`lead-programmer` route are
  unchanged; `orchestrator.md`/`persona-protocol.md` are not touched.

## [0.10.0] - 2026-07-15

### Changed
- **`repo-historian` renamed to `scribe`** throughout the plugin source,
  adapted copies, adapters (cursor/codex), install-antislop, and living docs
  (Track 1). `agents/repo-historian.md` → `agents/scribe.md`; frontmatter
  `name: repo-historian` → `name: scribe`; "Historian updates"/"Historian
  update hint" → "Scribe updates"/"Scribe update hint" in prose.
- **`hivemind` split into `spec-master` + `task-master`** (Track 3).
  `spec-master` keeps the 9-category ambiguity taxonomy, grill-me
  interrogation, Clarifications log, Constitution check, and Goal/Context/
  Steps spec authoring (now published via `to-spec`, see below), plus the
  debug-spec artifact for the 2-FAIL-cap escalation. `task-master` owns
  ticket-slicing (`to-issues`/`to-tickets`), per-unit `Suggested model`
  tagging (including advisory `Roast pass: fable` markers on heavy units),
  retrieval-contract statements, and per-unit dispatch prompts for
  `lead-programmer`/`scribe`. Neither persona re-plans on its own: a
  mid-flight spec gap discovered by `task-master` routes back up to
  `spec-master`, mirroring `lead-programmer`'s existing "report up" rule.
  `hivemind.md` is retired (both plugin-source and adapted copies).

### Added
- **`to-spec` wired into `spec-master`** via the existing
  `<MATTPOCOCK:slot>` substitution mechanism (Track 2) — the published
  `mattpocock/skills` skill that synthesizes the current conversation into a
  spec and publishes it to the project issue tracker. Its own PRD template
  (Problem Statement / Solution / User Stories / Implementation Decisions /
  Testing Decisions / Out of Scope) is layered on top of the existing
  spec-kit format rather than replacing it; `spec-master` still saves the
  full spec to `docs/plans/` in addition to `to-spec`'s tracker publish.
- **`pathfinder` skill** (first-party, `skills/pathfinder`), wired into
  `task-master` for slicing a finalized spec into dispatch-ready units —
  sizing, naming, and ordering guardrails adapted from
  `mattpocock/skills`' `wayfinder` for reliable, unambiguous
  lead-programmer/scribe dispatch.
- **`roast-work` skill** (first-party, `skills/roast-work`), wired into
  `reviewer` as a supplementary, advisory critique pass — never a PASS/FAIL
  gate. Surfaces contradictions, missing parts, logic gaps, and security
  vulnerabilities beyond the reviewer's existing materiality filter, and
  routes heavy review units to a `fable`-tier model for the extra pass.
- **`LEGACY_PERSONA_MAP` migration entries** in `bin/cli.js` for both
  renames above: `planner` → `hivemind` → `spec-master` + `task-master`
  (a two-hop chain — `resolveLegacyToken` now recurses through intermediate
  legacy tokens) and `repo-historian` → `scribe`. A project adapted at an
  older plugin version that still selects a legacy token gets migrated
  automatically on `--update`, with a logged note explaining the rename.

## [0.9.0] - 2026-07-14

### Added
- **Four spec-kit-inspired additions** to the plan/review/audit loop, per
  `docs/specs/2026-07-14-speckit-ports.md`:
  - An opt-in, per-project `.claude/constitution.md` (versioned
    project-specific principles), offered by a new `install-antislop`
    section 6.5 and consulted by `hivemind` (Constitution check), `reviewer`
    (MUST-violation FAIL reason), and `milestone-auditor` (premise grilling)
    when present.
  - A 9-category ambiguity taxonomy scorecard in `hivemind`, run before
    `grill-me`, plus a dated `## Clarifications` log capped at 5 questions
    per plan.
  - A pre-handoff requirements self-check in `hivemind` — "unit tests for
    the spec" — that revises the plan once before converting unresolved
    failures to Open Questions.
  - A named `unconverged-requirement` finding category in
    `milestone-auditor`'s existing audit pass, with append-only follow-up
    steps routed back to `hivemind` (never actioned by the auditor itself).

### Verification methodology
- Grep-checked against the spec's own acceptance criteria (all pass), but
  static text checks only confirm the prose is *present*, not that a real
  dispatch *follows* it — so this round also ran three live-dispatch
  simulations, each via a Fable-model "overseer" agent that built a fresh
  dummy project and used the `Agent` tool to actually invoke the real,
  freshly-edited `hivemind`/`reviewer`/`milestone-auditor` personas against
  it (not a hypothetical read-through):
  - **Round 1** (small dummy CLI project): found all four features
    textually correct but behaviorally degraded under real dispatch — the
    Clarifications scorecard and Self-check list collapsed into free prose,
    and `reviewer`'s constitution citation dropped its version number.
  - **Round 2** (harder multi-module dummy REST API, `fable`-tier dispatch):
    confirmed the gap sharply — all four literal formats failed outright
    under `fable`, and even `opus` reached only partial compliance on the
    two hardest ones (Clarifications' two-part shape, Self-check's itemized
    list). Isolated the cause: the prose described the required *shape* but
    never *showed* it.
  - **Round 3** (third dummy project, `fable`-only, no opus escalation):
    after adding a concrete fenced-code worked example for each literal
    format directly into `agents/hivemind.md`, `agents/reviewer.md`, and
    `agents/milestone-auditor.md`, all four features reliably produced
    their exact required shape under `fable` — closing the gap rounds 1-2
    identified. Two remaining cosmetic blemishes (a dropped `Q ... →` clause
    on one self-resolved line; a `P<n>` numeral folded into a principle-name
    citation) were fixed with one wording tweak each and re-verified clean.
  - Net effect: every literal-format requirement added this release ships
    with a worked example, not just a structural instruction — empirically
    necessary for reliable compliance at the `fable` tier, not a style
    preference.

## [0.8.0] - 2026-07-14

### Added
- **Codex port (MVP): the always-on subagent-orchestrator loop now ships for
  Codex CLI** alongside the existing Claude Code and Cursor plugins, under a
  new self-contained `adapters/codex/` tree. Implements
  `docs/specs/codex-plugin.md` in full (a design pass that itself supersedes
  the Codex column of `docs/specs/codex-cursor-plugin.md`, re-verifying its
  research live against `learn.chatgpt.com/docs/*`). Delivered:
  - **Four persona definitions** in Codex's native TOML format
    (`adapters/codex/agents/{orchestrator,explorer,lead-programmer,reviewer}.toml`)
    — persona *body* prose ported verbatim into `developer_instructions` as a
    literal (non-escape-processing) multi-line string, since the bodies'
    shell/printf examples contain literal backslash sequences a TOML *basic*
    multi-line string would have silently reinterpreted. `explorer.toml`
    keeps **per-agent MCP scoping** for the Code Review Graph — the one
    primitive Codex preserves that the Cursor port had to give up (Cursor's
    subagents inherit all parent MCP tools; Codex's do not).
  - **Enforcement hooks** as `adapters/codex/hooks/hooks.json` (confirmed
    live to use the SAME nested `{matcher?, hooks:[{type,command}]}` shape as
    Claude's, not Cursor's flatter list) plus five scripts: protected-paths,
    graph-update, lint-on-edit, stop-gate, and reviewer-route-gate. Each
    keeps the Claude/Cursor version's decision logic and swaps in a Codex
    payload-extraction preamble (`.cwd` for the project dir, `.agent_id`/
    `.agent_type` for identity, `.session_id` for the baseline). Protected-
    paths/graph-update/lint-on-edit additionally parse OpenAI's documented
    `apply_patch` patch-header format (`*** Add/Update/Delete File: <path>`)
    as a fallback when no single-file `tool_input` key is present, since
    Codex's canonical edit tool can touch multiple files in one call, unlike
    Claude/Cursor's one-file-per-invocation tools. `stop-gate.sh` also
    implements a self-tracked loop guard (no Codex-native
    `stop_hook_active`/`loop_count` equivalent was found) and keys the
    pending-review flag off `agent_id`, which — if that field is genuinely a
    stable per-spawn-instance id — fixes the Cursor port's known
    concurrent-same-type-subagent limitation outright.
  - **The shared persona-protocol** inlined directly into the project's
    `AGENTS.md` (`adapters/codex/agents-md-fragment.md`, upserted between
    version-agnostic marker comments) since Codex's AGENTS.md has no
    `@import`/include mechanism (confirmed) — unlike Cursor's separate
    always-apply rule file. Also inlined as a backstop digest into every
    persona's `developer_instructions`, since whether AGENTS.md content
    empirically reaches spawned subagents is doc-stated but not yet
    confirmed against a live build.
  - **Plugin packaging** (`adapters/codex/.codex-plugin/{plugin.json,
    marketplace.json}`) — deliberately does NOT bundle agent definitions via
    the plugin manifest, since Codex's documented plugin components are
    skills/mcpServers/apps/hooks only with no confirmed `agents` pointer;
    the four persona TOMLs are instead delivered by the scaffolder copying
    them straight into the project, same as the Claude/Cursor paths already
    do.
  - **Scaffolder support**: `bin/cli.js --target=codex` scaffolds all of the
    above into a project's `.codex/`, plus a new `upsertMarkedBlock` helper
    for the AGENTS.md inlining and a new `applyMcpTomlPlaceholder`/
    `renderMcpTomlBlock` pair (used by `--wire-graph-mcp --target=codex`) for
    rescoping the Code Review Graph into `explorer.toml`.
  - **`docs/codex-port-notes.md`** documenting what ported cleanly, which
    `docs/specs/codex-plugin.md` §12 open questions resolved vs. remain
    unverified (no `codex` CLI was available to probe live against), what
    was dropped, and two TOML-substitution bugs this port's own end-to-end
    scaffold test caught and fixed before they shipped.
- `tests/validate.sh` gained a Codex-artifacts section (bash syntax on hook
  scripts, JSON parse on hooks/plugin/marketplace manifests, TOML parse +
  required-field check on the four agent TOMLs, and a check that the
  AGENTS.md fragment source never bakes in the scaffold-time-only markers).

### Degraded / dropped on Codex (loud, not silent — see docs/codex-port-notes.md)
- **AGENTS.md-reaches-subagents is doc-stated but empirically unverified** —
  every persona TOML also inlines the load-bearing protocol digest as a
  backstop, same mitigation the Cursor port used for its own (weaker) version
  of this same open question.
- **reviewer-route-gate's "lead-programmer must not spawn the reviewer
  directly" half is instruction-only** — no confirmed field exposes the
  *calling* agent's identity on `SubagentStart`, only the spawned agent's own
  `agent_id`/`agent_type`. The pending-review dispatch-block half is
  mechanical regardless.
- Per-agent **tool allowlist** (beyond `sandbox_mode`), **`maxTurns` caps**,
  and **`memory: project`** all degrade to instruction-only/file-convention,
  matching the Cursor port's equivalents. Agent-teams mode, the
  `TaskCompleted`/task-gate (Codex has no such event), and structured
  user-question prompts are dropped, same as Cursor.
- **No `--update` support for the Codex target** — matches the Cursor port's
  own scope; only fresh-scaffold and `--overwrite` are implemented.
- The reviewer ships `sandbox_mode = "workspace-write"`, not `read-only` —
  a deliberate deviation from this port's own spec, decided rather than left
  open: Codex's sandbox is a real OS-level filesystem restriction (unlike
  Cursor's IDE-level tool gate), so `read-only` would almost certainly block
  the reviewer's Bash-invoked PASS/FAIL marker write.

## [0.7.2] - 2026-07-14

### Changed
- **Renamed the `setup-personas` skill to `install-antislop`** (directory
  `skills/setup-personas/` -> `skills/install-antislop/`, frontmatter
  `name:` field, and every source/doc/hook reference to it, including the
  `<REAL_LAUNCH_COMMAND_FROM_SETUP_PERSONAS_STEP_*>` placeholder tokens,
  which are now `..._INSTALL_ANTISLOP_...`). The command moves from
  `/antislop:setup-personas` (bare `/setup-personas` on the no-plugin CLI
  route) to `/antislop:install-antislop` (bare `/install-antislop`).
  Pre-v0.7.2 CHANGELOG entries below still say `setup-personas` — that was
  the name at the time and is left as-is rather than rewritten.

### Fixed
- **`stop-gate.sh`'s pending-review flag no longer clobbers a `defer:`/`skip:`
  reason on a repeat `SubagentStop`.** A gated agent resumed multiple times
  for check-ins on one long-running unit (not just its final, genuinely
  finished stop) re-triggers `SubagentStop` each time, and the flag write at
  step 2.5 was an unconditional overwrite — so a `defer: <reason>` the main
  session had written into the flag (the documented escape hatch at step
  0.75) got wiped back to a bare `agent=...` timestamp on the very next
  check-in, forcing the same block/defer cycle to repeat on every resume of
  that unit. The flag write is now idempotent: it only creates the flag if
  one doesn't already exist, so a defer/skip reason survives later
  `SubagentStop`s from the same `agent_id`, while a genuinely new unit (new
  `agent_id`) still gets a fresh flag. Applied to both the Claude Code hook
  (`hooks/scripts/stop-gate.sh`) and the Cursor port
  (`adapters/cursor/hooks/scripts/stop-gate.sh`).

## [0.7.1] - 2026-07-13

### Fixed
- **The v0.6.4 "`--update` is a deterministic script" fix didn't actually
  reach every project.** Any project adapted before v0.6.4 (missing
  `persona-config.json`'s `substitutions`/`fileHashes`) still hard-failed
  `bin/cli.js --update` straight into the old LLM-driven full re-derivation —
  the exact 100K-token, ~15-minute flow the script was supposed to replace,
  and a broad condition (every pre-v0.6.4 project), not a rare edge case.
  `bin/cli.js --update` now auto-backfills both fields deterministically from
  whatever's already on disk (zero LLM cost): `substitutions.mattpocockSkills`
  is reverse-derived by diffing the plugin's own source persona files against
  the project's already-substituted copies (a generic per-line diff —
  handles both the `skills:` frontmatter cases and `lead-programmer.md`'s
  body-prose placeholders with one algorithm); `substitutions.graphMcpLaunch`/
  `arxivMcpLaunch` are reverse-parsed from the already-rendered `mcpServers:`
  block in `explorer.md`/`researcher.md`; `fileHashes` adopts current on-disk
  content as the trusted baseline (logged loudly, since this is a one-time
  transitional gap for anyone with genuine pre-existing hand-edits). A single
  file/slot that still can't be determined (e.g. prose reworded across
  several plugin versions) no longer aborts the whole run — it's now
  collected and reported per-file, non-fatally, with a specific remediation,
  while every other file still updates normally in the same run. New test
  coverage: `tests/cli-backfill.test.js`, wired into `tests/validate.sh`,
  round-trips the new derivation logic against the real shipped `agents/*.md`
  content.
- **Every product-facing nudge pointed at the expensive path anyway.**
  `hooks/scripts/session-start.sh`'s version-drift warning and
  `hooks/scripts/task-gate.sh`'s two legacy-marker messages all told users to
  run `/antislop:setup-personas --update` (the 568-line LLM skill,
  invoked directly, bypassing the script entirely) instead of
  `/antislop:update-antislop` (the cheap command). Repointed all three.
- `skills/setup-personas/SKILL.md`'s own `--update` handling (section 11) was
  descriptive ("you only land here when the script says to") rather than
  imperative, so a direct `/antislop:setup-personas --update` invocation had
  nothing actually forcing it to run the script first. Section 11 now runs
  `bin/cli.js --update` as its explicit first action and only proceeds
  further based on the specific exit condition.
- Split `SKILL.md`'s two largest, least-often-needed sections out of the
  always-loaded file: the section 10 sandboxed hook-verification probe
  script moved to `skills/setup-personas/hook-verification.md` (read only by
  the delegated subagent that actually runs it); the old section 11 manual
  re-derivation flow was replaced with a much shorter
  `skills/setup-personas/update-fallback.md` scoped to resolving the one
  specific gap `bin/cli.js --update` names, not a full re-adapt. `SKILL.md`
  itself shrank from 568 to 491 lines.
- Updated `commands/update-antislop.md` and `README.md`'s update section to
  describe the narrower fallback surface, and fixed two stale in-code error
  messages (`applyMattpocockSubs`/`applyMcpPlaceholder` in `bin/cli.js`) that
  told users to re-run the very flow that had just failed to derive their
  value, instead of pointing at manual resolution or `--wire-graph-mcp`/
  `--wire-arxiv-mcp`.

## [0.7.0] - 2026-07-13

### Added
- **Cursor port (MVP): the always-on subagent-orchestrator loop now ships for
  Cursor** alongside the existing Claude Code plugin, under a new self-contained
  `adapters/cursor/` tree (kept separate so none of the Claude-only artifacts
  change). Implements the spec's §5 MVP milestone from
  `docs/specs/codex-cursor-plugin.md` — the Codex half is deliberately NOT
  built here. Delivered:
  - **Four persona definitions** in Cursor's native format
    (`adapters/cursor/agents/{orchestrator,explorer,lead-programmer,reviewer}.md`)
    — markdown + `name`/`description`/`model`/`readonly` frontmatter. The
    persona *body* prose is ported faithfully from `agents/*.md`; only the
    frontmatter and platform-specific mechanics changed.
  - **Enforcement hooks** as `adapters/cursor/hooks/hooks.json` (`version: 1`,
    camelCase events `preToolUse`/`afterFileEdit`/`subagentStart`/`stop`/
    `subagentStop`) plus five scripts: protected-paths, graph-update,
    lint-on-edit, stop-gate, and reviewer-route-gate. Each script keeps the
    Claude version's decision logic and swaps in a thin Cursor payload-
    extraction preamble (project dir from `.workspace_roots[0]`,
    `subagent_type` for caller identity, `.loop_count` for the loop guard,
    `.conversation_id` for the baseline).
  - **The shared persona-protocol** as an `alwaysApply: true` Cursor rule
    (`adapters/cursor/rules/persona-protocol.mdc`).
  - **Plugin packaging** (`adapters/cursor/.cursor-plugin/{plugin.json,
    marketplace.json}`).
  - **Scaffolder support**: `bin/cli.js --target=cursor` scaffolds all of the
    above into a project's `.cursor/`, reusing the existing "merge, never
    clobber" discipline (hooks.json is deep-merged; `--overwrite` preserves the
    judgment-driven persona-config fields).
  - **`docs/cursor-port-notes.md`** documenting what ported cleanly, what
    degraded (per spec §2A/§2D), which §6 open questions were resolved vs. left
    as loud unverified assumptions, and what was explicitly dropped.
- `tests/validate.sh` gained a Cursor-artifacts section (JSON parse of the
  hooks/plugin/marketplace manifests, frontmatter check on the Cursor agents,
  bash syntax check on the Cursor hook scripts).

### Degraded / dropped on Cursor (loud, not silent — see cursor-port-notes.md)
- **Rule cascade into subagents is UNVERIFIED** (spec §6 open q #1). Because
  the protocol *is* the safety system, its load-bearing invariants (review
  ownership, structural-questions-to-explorer, FAIL cap, WIP sentinel) are
  inlined into each subagent body as a guaranteed-delivery backstop in addition
  to the alwaysApply rule.
- **reviewer-route-gate's "lead-programmer must not spawn the reviewer" half is
  instruction-only** — Cursor's `subagentStart` payload carries the spawn
  target but not the caller (spec §6 open q #5). The pending-review half (block
  the next gated dispatch while a unit awaits review) is still mechanical.
- Per-agent **tool allowlist** (beyond `readonly: true`), **maxTurns caps**,
  **per-agent MCP scoping** (graph goes project-wide), and **`memory: project`**
  all degrade to instruction-only / file-convention, matching spec §2A–§2E.
  Agent-teams mode, the `TaskCompleted`/task-gate, and structured
  user-question prompts are explicitly dropped (spec Tier 3).
- This Cursor pass intentionally does NOT do the spec §4 shared-body refactor
  (splitting `agents/*.md` into `*.body.md` + per-platform wrappers), so the
  Cursor persona bodies and hook logic are hand-ported copies — a
  duplication-drift risk that §4's architecture would remove once Codex also
  exists.

## [0.6.5] - 2026-07-13

### Changed
- **Trimmed token bloat across every always-loaded prompt file** — the
  persona bodies (`agents/*.md`), `templates/persona-protocol.md` (imported
  into every persona's and the main session's context via CLAUDE.md, every
  turn), `templates/protocol-digest.md` (re-injected on every resume/compact),
  `skills/coding-discipline/SKILL.md` (preloaded on most lead-programmer/
  reviewer turns), `skills/setup-personas/SKILL.md`, and
  `commands/start-feature-team.md`. Found via a dedicated review pass: the
  same rule or rationale was frequently stated 2-4 times (a comment, then
  body prose, then again in `persona-protocol.md` which is already in every
  persona's context) — cut the redundant restatements, kept the single
  clearest instance. Net ~111 lines removed across 10 files. Did not touch
  anything encoding an actual constraint, a non-obvious gotcha, or a
  confirmed-bug fix (frontmatter-first-bytes, `mcpServers` list-vs-map,
  empty-sentinel-bypass, SKILL.md section 10's regression tests, etc.) — those
  earned their length and stay as-is.

## [0.6.4] - 2026-07-13

### Changed
- **`--update` is now a deterministic script, not an LLM skill invocation.**
  `/antislop:update-antislop` and the npx bare route both now shell straight
  out to `bin/cli.js --update`, which regenerates each version-stamped file
  directly from the plugin's own source plus the substitution values
  recorded in `persona-config.json` at ADAPT time, and only touches a file
  once it's byte-identical to the last known-clean baseline. This was
  previously implemented as `skills/setup-personas/SKILL.md` section 11,
  which meant loading the entire ~530-line, multi-thousand-token skill file
  to do work that section 11 itself only needed ~40 lines of — every
  `--update` run paid for reading the whole fresh-install flow (persona
  wizard, third-party installs, MCP wiring, CLAUDE.md pruning, hook
  verification) it never executed. The common case (no local edits) now
  costs no meaningful tokens; a file only escalates to a *human* decision
  (never an LLM one) when it's genuinely diverged from a fresh copy, via new
  `--accept=<paths>`/`--keep=<paths>` flags (`=all` for both). `--keep`
  deliberately does not "rebase" a file's clean-baseline hash to the kept
  content — doing so would let a later version bump that happens to leave
  the upstream file unchanged silently overwrite the very customization
  `--keep` was asked to preserve; instead the file is re-flagged for a
  decision on every future drift, by design.
- `persona-config.schema.json` gained two fields backing the above:
  `substitutions` (the `mattpocockSkills` slot map, `graphMcpLaunch`,
  `arxivMcpLaunch` — the values ADAPT resolved, so a script can re-derive a
  byte-identical file without guessing at them) and `fileHashes` (the
  known-clean baseline per stamped file). `setup-personas` steps 3-6 now
  record both as they resolve each substitution. Projects adapted before
  this field existed fall back once to the old LLM-driven flow (now section
  11's sole remaining job), which backfills both fields so every later
  update runs through the script.
- Added `bin/cli.js --wire-graph-mcp` and `--wire-arxiv-mcp=<server-key>`:
  read a tool-generated project-wide `.mcp.json` entry, inline its launch
  command into `explorer.md`/`researcher.md`'s `mcpServers:` frontmatter,
  remove the project-wide entry, and record it in `persona-config.json`'s
  `substitutions` — mechanizing the copy/rescope half of `setup-personas`
  steps 4-5 (verifying the connection actually works is still a judgment
  call left to the LLM/human).

## [0.6.3] - 2026-07-13

### Added
- **`commands/update-antislop.md`**: dedicated `/antislop:update-antislop`
  command for plugin-installed projects — a named entry point into
  `skills/setup-personas/SKILL.md`'s section 11 (`--update` mode), instead of
  only being reachable via the `--update` flag on `/antislop:setup-personas`.
  `/antislop:setup-personas --update` still works identically; this is an
  additive alias, not a replacement. npx-scaffolded projects (which don't get
  project-local plugin commands) keep using bare `/setup-personas --update`.
  README, CONTRIBUTING.md, docs/design.md, templates/persona-protocol.md, and
  the bug report template now point at `/antislop:update-antislop` as the
  primary plugin-path instruction. Hardened after an Opus critic pass found
  two gaps: it now checks for `.claude/persona-config.json` first and stops
  with a clear "run `/antislop:setup-personas` instead" message on a
  never-adapted project, rather than delegating straight into section 11
  against a missing file; and it invokes the `/antislop:setup-personas` skill
  itself (letting Claude Code resolve the plugin-root path) instead of
  telling the agent to read `skills/setup-personas/SKILL.md` by a
  project-relative path, which doesn't resolve on a plugin install.

## [0.6.2] - 2026-07-13

### Added
- **`bin/install-deps.sh`**: idempotent installer for the two conditional
  third-party dependencies (Code Review Graph, mattpocock/skills). Skips
  whichever is already present (checks `code-review-graph` on `PATH`, and
  `~/.agents/.skill-lock.json` for a `mattpocock/skills` source entry), so
  it's safe to run repeatedly and works from either install path
  (marketplace or npx), not just the npx CLI. Supports `--only-graph` /
  `--only-mattpocock` to run a single step. Referenced from the README
  Requirements section.

### Changed
- `bin/cli.js`'s `--with-mattpocock` and `--with-graph` flags now delegate
  to `install-deps.sh` instead of duplicating the pipx/npx install calls
  inline, so re-running them no longer unconditionally reinstalls/reopens
  the picker when the dependency is already satisfied.

## [0.6.1] - 2026-07-13

### Fixed
- **No persona had `SendMessage` in its `tools:` list** (#9), so in
  agent-teams mode a named teammate's `idle_notification` — a lifecycle
  signal only, never a report payload — was the team lead's only signal that
  a teammate was done, and its only lever to check further was re-invoking
  `Agent` with the teammate's existing name. That doesn't resume the
  teammate; it silently spawns an unrelated `<name>-2` sibling, so the
  original teammate's actual report never reached the lead through any
  channel its tools exposed. Added `SendMessage` to `orchestrator.md`,
  `lead-programmer.md`, `hivemind.md`, `repo-historian.md`, `reviewer.md`,
  `explorer.md`, and `researcher.md.tmpl`'s `tools:` lines, and documented
  both directions of the fix: `orchestrator.md` and
  `commands/start-feature-team.md` now tell the lead to `SendMessage` an
  idle teammate by name to resume/retrieve its report instead of
  re-invoking `Agent`; `lead-programmer.md`'s ready-for-review handoff and
  `templates/persona-protocol.md`'s agent-teams section now tell a teammate
  to push its report to the lead via `SendMessage` on finishing a unit,
  since plain turn-text isn't visible to other agents. Not a duplicate of
  #5 (`TaskStop`/`TaskOutput` for subagent-orchestrator-mode liveness) or #8
  (same "fresh dispatch instead of resume" symptom, but scoped to
  backgrounded-Bash races in subagent-orchestrator mode) — this is the
  agent-teams-mode named-teammate resume path specifically.
- `package.json`'s version had drifted behind `.claude-plugin/plugin.json`
  since the 0.6.0 release (stuck at 0.5.5) — resynced both to 0.6.1.

## [0.6.0] - 2026-07-13

**Upgrade caveat (read first if you have an adapted project):** the PASS
marker format changed (v1 → v2, see below) and `task-gate.sh` now enforces
it. A project whose copied `agents/reviewer.md` predates this version still
writes the old bare `touch` marker. **A two-week grace period softens the
cutover**, through 2026-07-27: until then, a legacy marker gets a loud
warning (logged to `.claude/review-audit.log`) but is still allowed to
complete; on or after 2026-07-27, `task-gate.sh` BLOCKS it unconditionally at
`TaskCompleted`. Run `/antislop:setup-personas --update` before that date to
refresh the copied persona files and avoid the block.

### Added
- **PASS marker format v2** (`hooks/scripts/task-gate.sh`,
  `agents/reviewer.md`, `commands/start-feature-team.md`,
  `templates/persona-protocol.md`): the reviewer (and the no-reviewer
  fallback lead) now write `PASS <task-id> <UTC ISO-8601 timestamp> criteria:
  <acceptance-criteria command(s) run>` as the marker's first line via
  `printf`, instead of a bare `touch`. `task-gate.sh` validates the format
  and content, not just existence, and logs accepted markers to the new
  `.claude/review-audit.log`. A malformed/legacy marker is rejected with an
  instructive block message naming the exact `printf` command and pointing
  at `--update` as the likely remedy — see the upgrade caveat above.
  **Two-week grace period:** before 2026-07-27, a legacy marker is warned
  about (`legacy-marker-grace-period-warning` in `.claude/review-audit.log`)
  but still allowed; on or after that date the rejection above is
  unconditional. One-time softening of this v1→v2 cutover, not a standing
  feature.
- **Pending-review gate** (`hooks/scripts/stop-gate.sh`,
  `hooks/scripts/reviewer-route-gate.sh`): the default (subagent-orchestrator)
  mode gains its first mechanical backstop for "done = reviewer PASS,"
  mirroring what `TaskCompleted` already enforced in agent-teams mode. A
  gated agent's un-reviewed `SubagentStop` (not honoring a WIP sentinel)
  writes `.claude/.pending-review.<agent_id>`; a reviewer's own stop clears
  all such flags and logs to `.claude/review-audit.log`. While a flag stands,
  `stop-gate.sh` blocks main-session turn-end and
  `reviewer-route-gate.sh` blocks dispatching another gated-agent unit,
  with a `defer:`/`skip:` escape hatch mirroring the existing WIP-sentinel
  pattern. Honest limit: this cannot force the orchestrator's next action —
  it blocks turn-end/dispatch and leaves an audit trail, same as the
  sentinel; `rm` via Bash remains possible.
- **`reviewed-path-gate.sh`** (new `PreToolUse`/`Bash` hook): gates Bash
  writes to `.claude/reviewed/` by caller `agent_type` (reviewer allowed;
  lead-programmer and other writer personas blocked; main session allowed
  only under the documented no-reviewer fallback). Built and scoped against
  an empirically-probed payload shape (`docs/experiments/2026-07-probe-hook-payloads.md`)
  — its known attribution limits (a `cat`-of-a-marker is collateral-blocked;
  a sufficiently obfuscated write can dodge the string match, in which case
  `task-gate.sh`'s content validation is the second layer) are recorded in
  README's "Known limitations."
- **`hivemind` and `milestone-auditor` gain orchestrator-decided Opus|Fable
  dispatch routing** (`agents/orchestrator.md`'s "Per-unit model routing"
  section, new `### Opus|Fable routing for hivemind and milestone-auditor`
  subsection): `hivemind` dispatches on `fable` only when scope is already
  enumerated, the change rides existing seams, and no interrogation is
  needed (all three, conjunctively); `milestone-auditor` dispatches on
  `fable` only when the milestone was mechanical end-to-end (every unit
  `haiku`-tagged, no first-pass FAIL, no human challenge at the pre-audit
  checkpoint). Frontmatter `model: opus` stays the default for both —
  fable is per-dispatch only, never the standing tier. **Cost framing,
  honestly:** this is a routing heuristic, not a structural saving — worst
  case is unchanged from today (both personas can still run on Opus every
  time); the common case is cheaper only when the orchestrator's heuristic
  actually routes well-scoped work to Fable. A wrong-cheap dispatch
  escalates to `opus` on retry, mirroring the existing haiku-unit
  escalation rule.
- **Pre-audit human-grilling checkpoint** (`agents/orchestrator.md`'s
  "Milestone audit gate" section): before every `milestone-auditor`
  dispatch, the orchestrator now fetches the plan's Goal/assumptions/Open
  Questions and surfaces them to the human via `AskUserQuestion` as a quick
  confirm/challenge pass. A material human challenge routes back to
  `hivemind` for a re-plan instead of spending an Opus audit run on an
  already-invalidated plan; a clean checkpoint still requires the full
  audit — it is not a substitute for it.
- **Durable FAIL record** (`agents/reviewer.md`, `templates/persona-protocol.md`):
  on a FAIL verdict the reviewer now also writes
  `.claude/reviewed/<task-id>.fail` (defect list + timestamp, both modes) —
  not for any hook gate (none needed changing), but as a standing warning
  for a future `hivemind` or orchestrator spawn with no memory of this
  session. `agents/orchestrator.md`'s per-unit and Opus|Fable routing rules
  both treat an existing `.fail` record as a hard disqualifier for
  haiku/fable dispatch on that unit; `agents/hivemind.md` checks for one
  before retagging or re-scoping.

### Changed
- **`planner` renamed `hivemind` repo-wide** (display name "HiveMind" in
  unbackticked README prose only; the machine-facing slug stays lowercase
  everywhere else): `agents/planner.md` → `agents/hivemind.md`, every
  routing-table/prose/eval-variant reference, `bin/cli.js`'s
  `OPTIONAL_PERSONAS`/wizard labels, `templates/persona-config.schema.json`,
  `templates/persona-protocol.md`, `templates/researcher.md.tmpl`,
  `commands/start-feature-team.md`, `skills/setup-personas/SKILL.md`,
  `tests/validate.sh`, `eval/harness/scaffold.sh`, and
  `.claude-plugin/plugin.json`'s description. `bin/cli.js --personas=` and
  the `--overwrite`-reuse-selection path both accept the legacy `planner`
  token, map it forward to `hivemind`, and print a deprecation note instead
  of silently dropping it (the pre-rename intersection filter would have
  dropped an unrecognized token with no error). `skills/setup-personas/SKILL.md`
  section 11 (`--update` mode) gained an explicit migration rule: a project
  whose recorded `personaSelection` still says `planner` gets its copied
  agent file renamed/re-derived, its `personaSelection` rewritten, and the
  migration reported. `milestone-auditor` was NOT folded into `hivemind` —
  it stays a separate, memory-less persona; its deliberate absence of a
  `memory:` field (fresh-eyes isolation) is unchanged.
- README's "Cost" section reworded for the dual-model routing above,
  honestly: the smaller-standing-roster savings argument belonged to a fold
  that was proposed and explicitly rejected (see Open Questions in the
  source plan) and does not appear here in any form — `hivemind`,
  `reviewer`, and `milestone-auditor` all still DEFAULT to the pricier tier
  and remain the real spend drivers; the cheaper model is an
  orchestrator-routed discount on top, not a lowered baseline.
- README's orchestrator-drift-surface bullet updated: the main session is
  still deliberately uncapped, but the pending-review gate above gives it
  its first mechanical backstop — "biggest open drift surface" becomes
  "partially closed," not fully closed.

### Reviewed, not changed
- lead-programmer's TDD-first mandate was reviewed for a conditional
  (haiku-tagged-step / no-reviewer-project) carve-out and deliberately kept
  **unconditional**, exactly as written before this release
  (`agents/lead-programmer.md` and its eval-variant twin are untouched) —
  recorded here so the question isn't re-litigated from silence.

## [0.5.5] - 2026-07-13

### Added
- `agents/planner.md`: plan steps now carry a `Suggested model:
  haiku|sonnet` tag (mechanical/low-judgment work → haiku, anything needing
  design judgment, cross-file reasoning, or hard-bug diagnosis → sonnet,
  default to sonnet when unsure), carried unchanged through `to-issues` into
  each unit.
- `agents/orchestrator.md`: new "Per-unit model routing" section — reads a
  unit's `Suggested model` tag and passes it as the dispatch's `model`
  parameter when spawning `lead-programmer`, relying on Claude Code's
  documented per-invocation model override (env var > per-call param >
  frontmatter); omitted tags fall back to lead-programmer's own `model:
  sonnet` default. Added an escalation rule: a haiku-run unit that FAILs
  review re-dispatches on sonnet rather than haiku again, still counting
  against the existing 2-FAIL cap.

## [0.5.4] - 2026-07-12

### Fixed
- `skills/setup-personas/SKILL.md` step 3: mattpocock skill substitution no
  longer trusts hardcoded assumed names (`to-issues`, `diagnose`) — it now
  resolves each `<MATTPOCOCK:*>` placeholder from the actually-installed
  skill's discovered `name:` frontmatter (the real names are `to-tickets`
  and `diagnosing-bugs`), with a new step 3b fail-fast check right after
  substitution. (#1)
- `skills/setup-personas/SKILL.md` step 12: added a mandatory placeholder
  sweep (`grep -rEn '<[A-Z0-9_]+(:[a-zA-Z0-9_-]+)?>' ...`) that must return
  zero matches before the skill can report an adapt run done. (#2)
- `skills/setup-personas/SKILL.md` step 6: `testAndLintCommand` is now run
  once against the clean tree before being written into
  `persona-config.json`; a failing command is surfaced to the human as an
  explicit choice instead of silently becoming a permanently-red stop-gate.
  (#3)
- `hooks/scripts/stop-gate.sh`: `gatedAgents` scoping now also applies to
  the main-session `Stop` event (previously only `SubagentStop`), keyed off
  `settings.json`'s configured main agent. Removes redundant WIP-sentinel
  churn on every orchestrator turn-end while a gated subagent is mid-flight.
  (#4)
- `agents/explorer.md`, `templates/researcher.md.tmpl`: fixed `mcpServers`
  frontmatter from an invalid flat map to the correct list-of-single-key-
  dicts-with-`type:` schema — the flat form silently failed to connect,
  falling back to grep/WebSearch with no visible error anywhere.
  `setup-personas` steps 4-5 now require the verification query's answer to
  self-report MCP-derived vs. fallback-derived provenance, since a
  plausible-looking answer isn't proof the connection is live. (#7)
- `agents/orchestrator.md`: granted `TaskStop`/`TaskOutput` (previously
  missing from its `tools:` allowlist, which replaces rather than extends
  the inherited toolset) plus a new "Managing a long-running background
  dispatch" section instructing it to poll via `TaskOutput(block=false)`
  before ever reaching for `TaskStop`. Root-cause investigation found the
  originally-reported harness gap (no cancel/liveness primitive for a
  background Agent task) was already closed upstream as of Claude Code
  2.1.187; the actual cause of the reported session failure was this
  missing tool grant. (#5)

### Added
- `skills/setup-personas/SKILL.md` new section 0.5: when
  `.claude/persona-config.json` already exists and the invocation isn't
  `--update`, the skill now runs an explicit `AskUserQuestion` decision
  tree (resume / patch gaps only / full restart) instead of silently
  falling through to a fresh 12-section run. (#6)
- `templates/researcher.md.tmpl`: added a `Fallback` self-report bullet
  mirroring `explorer.md`'s existing one, so a broken arXiv MCP connection
  has a chance to be reported rather than silently absorbed by
  `WebFetch`/`WebSearch`.

## [0.5.3] - 2026-07-12

### Added
- `bin/cli.js` gained an `--overwrite` flag: re-copies agents/hooks/skills/
  protocol unconditionally even over an existing install, instead of always
  refusing (previously the only path forward was the LLM-driven
  `/setup-personas --update` diff flow). Preserves `persona-config.json`'s
  judgment-driven fields (`testAndLintCommand`, `protectedPaths`, etc.)
  exactly as recorded — only `personaSelection` and `pluginVersion` refresh.
  With no `--personas=`/`--yes` alongside it, reuses the project's
  already-recorded persona selection rather than silently changing which
  personas are installed.

## [0.5.2] - 2026-07-12

### Added
- `templates/persona-protocol.md` gained two cross-cutting rules, both
  proposed by `persona-improver` (`~/claude_trace`) from a real telemetry
  review of production usage, not written on assumption:
  - A name-collision warning: Claude Code's built-in `Explore` subagent can
    silently shadow this project's own `explorer` persona via
    description-based auto-delegation, since the built-in has no Code
    Review Graph MCP access and falls back to weaker grep-derived answers.
    Personas should spawn `explorer` by name, not rely on auto-delegation.
  - A "scope Bash output before it enters context" rule — pipe verbose
    commands through `head`/`tail`/`grep`/quiet flags before the output
    lands in context, rather than after.
  Both findings and patches are recorded in
  `~/claude_trace/.scratch/telemetry-review/telemetry_review_20260712_052612.md`
  and `~/otel/improvements.duckdb`.

## [0.5.1] - 2026-07-11

### Changed
- `lead-programmer` gained `maxTurns: 30` (previously uncapped — the last
  cost-bounding gap noted in 0.2.0's `maxTurns` rollout). `reviewer`'s
  verdict output contract was rewritten to be strictly terse — verdict-only
  final message, no restated context/summary. Both changes were validated
  against a real, controlled pilot (N=5 reps each vs. a matching N=5
  baseline) before shipping, not applied on assumption: maxTurns cap cut
  cost -10.4%/turns -38.1%/wall -15.4%; the terse contract cut cost
  -17.7%/turns -42.9%/wall -20.1%. Neither regressed the pilot's
  independent defect-catch check (18/18 held across the full pilot,
  including both these variants) — see `docs/experiments/pilot-2026-07-11.md`
  for the full experiment log and the `eval/` harness that produced it.

## [0.5.0] - 2026-07-11

### Changed
- Renamed the plugin from `seb-personas` to `antislop` — package name
  (`package.json`), CLI bin name, plugin id (`.claude-plugin/plugin.json`,
  `marketplace.json`), skill-namespace prefix
  (`seb-personas:coding-discipline` → `antislop:coding-discipline`), and all
  prose references across `README.md`, `CONTRIBUTING.md`, the bug report
  template, `setup-personas/SKILL.md`, `session-start.sh`, `validate.sh`,
  and `bin/cli.js`'s runtime strings and version-stamp comment format.
  Directory path (`~/seb_claude_setup`) intentionally left unchanged — this
  is an identity rename, not a relocation, so `~/claude_trace`'s
  `persona-improver.md`/`protected-paths.sh` references to that path still
  resolve.

## [0.4.2] - 2026-07-10

### Fixed
- `bin/cli.js`'s `copyStamped()` and `setup-personas/SKILL.md` step 2 both
  prepended the `<!-- seb-personas vX.Y.Z ... -->` version-stamp comment
  *before* the frontmatter's opening `---`. Confirmed via a live probe
  (`AWS_Learning`) that Claude Code's subagent discovery requires the file
  to start with `---` as its very first bytes — a leading comment silently
  breaks discovery, so every copied persona (`orchestrator`, `planner`,
  etc.) never registered as an invocable agent type, while a comment-free
  probe file worked fine. The stamp now lands immediately after the closing
  `---` in both the CLI and the skill instructions. Projects already
  scaffolded before this fix have the broken layout in their existing
  `.claude/agents/*.md` files and need those files' leading comment moved
  after the frontmatter (or re-run `setup-personas`/the CLI) to pick up the
  fix.

## [0.4.1] - 2026-07-10

Prompted by walking a real project (`AWS_Learning_Sim`) through install and
catching drift between this repo's design assumptions and how its two
third-party dependencies actually behave today.

### Added
- `seb-personas-setup` runnable npm package (`package.json` + `bin/cli.js`,
  `"private": true` — not published to the npm registry, clone + run via
  `npx /path/to/clone`): scaffolds the mechanical half of ADAPT
  (`.claude/agents/`, hooks, settings.json merge, protocol/digest copy,
  CLAUDE.md wiring, `.gitignore`), replacing `/plugin marketplace add` +
  `/plugin install` with one `npx` call for the file-scaffolding part (same
  clone/collaborator/git-auth prerequisites still apply). Deliberately stops
  short of the judgment-driven half (repo-scan for test/lint commands,
  graph/MCP wiring, hook verification) — copies `setup-personas`/
  `coding-discipline` in project-scoped and tells the user to run
  `/setup-personas` next to finish. Refuses to run over an existing
  `persona-config.json` rather than risk clobbering local edits. Also
  optionally launches the `mattpocock/skills` and `code-review-graph`
  installers itself (`--with-mattpocock`/`--with-graph`, inherited stdio so
  their own interactive prompts work normally) — it stops short of the
  `.mcp.json`→`explorer.md` rescoping (see Fixed below), leaving that to
  `/setup-personas` step 4 since it needs to inspect what the installer
  actually wrote, not a guessed schema.

### Fixed
- README's "real install" instructions used a generic `<owner>/<repo>`
  placeholder and a hardcoded local `~/seb_claude_setup` path in the
  `--plugin-dir` example; now names the actual GitHub slug
  (`Storreslara/My_Claude_Stuff`, which does not match the local clone
  directory name) and generalizes the local path.
- `setup-personas/SKILL.md` step 3: `npx skills@latest add mattpocock/skills`
  opens an interactive terminal picker with no documented non-interactive
  mode. The ADAPT skill previously had the agent attempt to drive this
  itself, which can hang or silently take defaults in a non-interactive
  shell and leave stale `<MATTPOCOCK:*>` placeholders with no error
  surfaced. Now the agent tells the human which skills to pick and asks
  them to run it, then verifies the installed skill list itself afterward.
- `explorer.md` and `setup-personas/SKILL.md` step 4 assumed the Code Review
  Graph installs as a bare-named project skill queried conversationally. Its
  real current install (`code-review-graph install --platform claude-code`)
  is an MCP server that registers itself PROJECT-WIDE in `.mcp.json` by
  default (every persona would inherit it — the exact context-bloat problem
  this system was designed to avoid) plus three unrelated build-graph/
  review-delta/review-pr workflow skills. `explorer.md` now carries its own
  scoped `mcpServers:` frontmatter (the same trick `researcher.md` uses for
  its arXiv MCP) and step 4 explicitly re-scopes the connection there
  instead of leaving the tool's project-wide registration in place.

## [0.4.0] - 2026-07-09

### Added
- `milestone-auditor` persona: an adversarial auditor of the *plan*, not the
  code — runs at milestone boundaries once every unit in it has already
  reviewer-PASSed, hunting for premise gaps and goal drift the reviewer
  structurally can't see. No PASS/FAIL, no override authority, no Write/Edit
  — only a findings list relayed to the human. Wired into README, the
  `persona-config` schema, and `setup-personas`'s selection/placeholder-
  substitution/mattpocock-skill steps.
- `orchestrator.md`: a Plan Mode gate. The harness's built-in Plan Mode ships
  its own Explore/Plan workflow that silently overrides the persona routing
  table and bypasses the Writer/Reviewer split for the whole turn; the
  orchestrator now recognizes this, exits Plan Mode, and re-routes through
  the normal pipeline instead.

### Fixed
- `commands/start-feature-team.md`: closed several gaps found in review —
  the `impl:<slug>` task-naming convention the `TaskCompleted` gate depends
  on was never actually instructed; the no-reviewer/crashed-reviewer path
  could deadlock the task list permanently; the reviewer was never told the
  exact task id needed for its PASS marker to match; FAIL routing didn't
  reference the shared protocol's 2-FAIL cap; the explorer-teammate
  framing contradicted the file's own header comment about subagent
  spawning; the native-plan-approval gate was unverifiable and is now
  secondary to the always-available prose rule.

### Changed
- Trimmed redundant/restated prose in `orchestrator.md` and
  `lead-programmer.md` (behavior unchanged, token cost per spawn reduced).

## [0.3.0] - 2026-07-09

Behavioral-drift hardening, prompted by an audit of which shared-protocol
rules were mechanically enforced vs. instruction-only, reviewed and
reprioritized by a second model pass.

### Added
- `templates/protocol-digest.md`: a short (~15-line) reminder of the
  highest-drift-risk rules (explorer routing, review ownership, the 2-FAIL
  cap, WIP sentinel legitimacy, the memory-grant caveat). `setup-personas`
  copies it to `.claude/protocol-digest.md`, version-stamped like
  `persona-protocol.md`, but does NOT import it into CLAUDE.md.
- `session-start.sh` now re-injects that digest via `additionalContext`, but
  only when the hook's `source` field is `resume` or `compact` — never
  `startup`/`clear`, where the full protocol is already freshly in context.
  This targets the exact moments a long-running session (the orchestrator's
  uncapped main session especially) is most likely to have summarized the
  protocol away. Mechanical timing of when the rules reappear, not more
  static prose to hope survives compaction.
- `hooks/scripts/reviewer-route-gate.sh`: a `PreToolUse` hook (matcher
  `Agent`) mechanically blocking lead-programmer from spawning the reviewer
  directly, closing the payload-attribution question this same section
  previously deferred (see below). Confirmed empirically, not assumed: a
  nested `Agent`-tool call's `PreToolUse` payload carries the calling
  subagent's `agent_type`/`agent_id` alongside the call's own
  `tool_input.subagent_type`, the same attribution `stop-gate.sh` already
  relies on for `SubagentStop`. Registered in `hooks.json` alongside
  `protected-paths.sh`. Only covers a direct `Agent`-tool spawn attempt, not
  `SendMessage` to an existing reviewer teammate in agent-teams mode — a
  different tool with a different payload shape, out of scope here.

### Changed
- `lead-programmer.md`: `tdd` and `diagnose` moved out of the `skills:`
  frontmatter (which preloads a skill's full body into every spawn
  regardless of whether the task needs it) and are now invoked on demand via
  the `Skill` tool instead — the body's "TDD-first" bullet is the trigger.
  `coding-discipline` stays preloaded (small, applies to every task). This
  was the largest identified per-spawn token cost on the system's
  highest-frequency persona; a one-line fix doesn't need the full TDD/diagnose
  choreography resident before it's asked for. The review-ownership bullet is
  now one sentence instead of six lines, since `reviewer-route-gate.sh` (see
  Added) backs it mechanically instead of by instruction alone. A
  maintainer-facing comment explaining the old `skills:`/`tools:` rationale
  was cut from the body (see this entry instead) now that the rationale it
  described no longer applies. Added a short "keep memory bounded" bullet
  (index file + topic files + periodic pruning) since `memory: project` notes
  otherwise accumulate with nothing pruning them.
- `setup-personas` step 3's placeholder-substitution instructions updated:
  `lead-programmer.md`'s `<MATTPOCOCK:tdd>`/`<MATTPOCOCK:diagnose>`
  placeholders now live in its body prose instead of its `skills:`
  frontmatter (per the change above); `planner.md`/`repo-historian.md` are
  unaffected. Step 10's hook-verification list gained a
  `reviewer-route-gate.sh` dry-run check matching the pattern used for the
  other hooks.
- The WIP sentinel (`.claude/wip-handoff.<agent-id>`) now requires non-empty
  content. A bare `touch` used to bypass the stop-gate silently and
  invisibly; `stop-gate.sh` now rejects empty sentinels (deletes but doesn't
  honor them, falling through to the normal check) and logs the stated
  reason plus a timestamp to `.claude/wip-audit.log` before honoring a valid
  one. Closes a silent escape hatch from the system's one blocking gate.
  `.claude/wip-audit.log` is gitignored by `setup-personas` like the other
  runtime-only files.

### Confirmed unchanged / deliberately deferred
- The payload-attribution probe from this section's earlier draft is
  resolved (see `reviewer-route-gate.sh` under Added) — `PreToolUse` does
  carry caller `agent_type`. That unblocks a spawn-matrix hook for review
  ownership (shipped) but a per-persona write-path allowlist is a separate,
  larger follow-up not attempted here.
- The 2-FAIL cap stays instruction-only in subagent-orchestrator mode for
  now; the proposed fix (reviewer writes a `.fail` marker mirroring the
  existing PASS-marker pattern) needs a stable per-unit key that
  subagent-orchestrator mode doesn't currently have.
- No `maxTurns` cap was added to `lead-programmer` yet, despite being the
  other uncapped, long-running persona alongside the orchestrator.

## [0.2.1] - 2026-07-04

### Fixed
- The orchestrator relayed the planner's "Open Questions" as plain
  conversational text with no structured mechanism, even though it runs as
  the main session (not a subagent) and can actually use `AskUserQuestion`.
  Confirmed via docs that subagents (including the planner itself) can never
  use `AskUserQuestion` regardless of tools list — this was the correct
  place to wire it in, and wasn't. Added `AskUserQuestion` to
  `orchestrator.md`'s tools and updated its relay instruction to use it for
  questions that reduce to discrete choices.

### Confirmed unchanged (a deliberate choice, not an oversight)
- `planner.md`'s grill-me trigger stays gated on "for any non-trivial task"
  rather than becoming unconditional — the orchestrator's routing table
  already filters out trivial work before it reaches the planner, so the
  gate is mostly redundant in practice but intentionally left as a second
  line of defense.

## [0.2.0] - 2026-07-04

Bug fixes plus a modularity/update-mechanism rebuild, prompted by a
follow-up review that read the shipped files fresh and asked two questions:
how to make the system more modular, and what's still missing.

### Fixed
- `task-gate.sh` never checked for `.claude/persona-config.json` and nothing
  ever created `.claude/reviewed/`, so the reviewer's PASS-marker `touch`
  would fail on the very first agent-teams completion. Now guarded on config
  presence, and `setup-personas` pre-creates the directory.
- `protected-paths.sh` case-matched project-root-relative glob patterns
  against typically-absolute file paths, so directory-anchored patterns
  (e.g. `supabase/migrations/*`) never matched anything. Paths are now
  normalized against `CLAUDE_PROJECT_DIR` before matching.
- `graph-update.sh` and `lint-on-edit.sh` interpolated the (untrusted) edited
  file path into a string passed to `eval`, allowing command injection via a
  crafted filename. Both now pass the file path as a positional parameter to
  `bash -c` instead.
- All five hook scripts assumed the working directory was the project root;
  they now anchor to `${CLAUDE_PROJECT_DIR:-.}` explicitly.
- `agent_id`/`task_id` values from hook JSON payloads are now sanitized
  before being used to build filesystem paths.
- `stop-gate.sh`'s `SubagentStop` scoping moved from a hardcoded
  `lead-programmer` matcher in `hooks.json` to a config-driven `gatedAgents`
  list in `persona-config.json` (confirmed empirically that the
  `SubagentStop` payload carries `agent_type`), so adding a future
  code-writing persona is a config edit, not a plugin file edit.
- `stop-gate.sh` now also checks whether `HEAD` moved since the session's
  baseline commit (recorded by the new `session-start.sh`), closing a gap
  where a lead-programmer that commits per-step (clean tree at handoff) would
  otherwise never actually trigger the check.
- `planner.md`, `lead-programmer.md`, and `reviewer.md` were missing `Skill`
  in their tools list, so they silently lost their preloaded skills
  (grill-me/to-issues, tdd/diagnose/coding-discipline, coding-discipline
  respectively) when run as agent-teams teammates. `repo-historian.md` had
  the same gap and is fixed too.

### Added
- Persona opt-out: `orchestrator`, `explorer`, `lead-programmer` are the
  minimum viable loop; `planner`, `repo-historian`, `reviewer`, `researcher`
  are now selected per-project by `setup-personas`' persona-selection wizard.
  Cross-references to optional personas are phrased conditionally throughout
  so skipping one degrades gracefully instead of hard-erroring. Skipping
  `reviewer` requires an explicit typed confirmation.
- Version-stamp comments on every ADAPT-copied file, plus a `--update` mode
  in `setup-personas` that re-syncs an already-adapted project against a
  newer plugin version — diffing before overwriting, never silently
  clobbering a local edit.
- A `SessionStart` hook (`session-start.sh`) that warns when a project's
  stamped plugin version is behind the installed plugin's current version.
- A 2-FAIL cap on the reviewer FAIL→fix→re-review loop — the orchestrator
  escalates to the user instead of re-delegating a third time.
- `maxTurns: 30` on `planner.md` and `reviewer.md` (the two Opus-tier
  personas), matching the cost-bounding pattern already used by
  `explorer.md`'s `maxTurns: 10`.
- `tests/validate.sh` + a GitHub Actions workflow validating the plugin's own
  files (bash syntax, JSON validity, agent frontmatter, cross-reference
  consistency).
- `CONTRIBUTING.md` and a bug-report issue template.
- README sections: removing/uninstalling, adding your own persona, and a
  cost-guidance paragraph.

## [0.1.0] - 2026-07-03

Initial release. Six-persona system (orchestrator + explorer/planner/
lead-programmer/repo-historian/reviewer as plugin agents, researcher as a
project-scoped template), coding-discipline skill, enforcement hooks, and the
setup-personas ADAPT skill. Built through two adversarial-critique passes and
one empirical smoke test confirming plugin agents are namespaced and the
mandatory agent-copy fix this required.
