# Changelog

All notable changes to the seb-personas plugin are recorded here. Dates are
ISO (YYYY-MM-DD).

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
