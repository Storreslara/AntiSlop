# Changelog

All notable changes to the antislop plugin (formerly seb-personas) are
recorded here. Dates are ISO (YYYY-MM-DD).

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
