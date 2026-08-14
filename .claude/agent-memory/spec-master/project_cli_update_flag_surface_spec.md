---
name: cli-update-flag-surface-spec
description: Spec #335 (issues #289/#291) settled decisions for bin/cli.js's --update flag surface, incl. the one open question gating its second unit.
metadata:
  type: project
---

Finalized 2026-08-11. Plan: `/home/sebas/AntiSlop/docs/plans/2026-08-11-cli-update-flag-surface.md`.
PRD view: GitHub issue #335 (`ready-for-agent`). Three sequential units;
`task-master` slices. **No unit may be tagged `haiku`** — sonnet floor, opus
recommended for unit 2.

Settled decisions worth not re-deriving:

- `--overwrite` and `--update` are **orthogonal**. `main()` returns
  `runUpdate(args)` before any scaffold flag is parsed, so the update path
  never reads `--overwrite`. Issue #289 asked; this is the answer.
- Adding a persona to `personaSelection` needs **no** per-persona work beyond
  creating its `.claude/agents/<name>.md`. Verified against the scaffold path:
  settings.json, hooks, skills and `.gitignore` are all persona-independent.
- The `--update` path has **eleven** write sites, four of them outside the
  render loop (a legacy-file unlink, a CLAUDE.md rewrite, two `.gitignore`
  appends, a settings rewrite under `--dedupe-hooks`). Two of the helpers
  compute their answer as a side effect of writing it, so a bare
  `if (!dryRun)` wrapper drops the report line too.
- `--dry-run` exit codes: 0 nothing would change, 3 something would, 1 cannot
  render. 0/1/2 are all already load-bearing in `runUpdate`.

**Open question gating unit 2** (relayed to the user 2026-08-11): keep
`--check` as a warning-emitting deprecated alias (recommended, non-breaking)
or hard-refuse it? Hard refusal grows the unit's blast radius to two runbook
documents currently on its "do NOT touch" list, so it is not an
implementer-level call.

**Why:** both issues sit in `bin/cli.js`, which carries 21 of the repo's 47
`.fail` records — the issue text itself demanded the not-haiku tag.
**How to apply:** if re-scoping any of these three units, reuse these answers
rather than re-reading 2200 lines of `bin/cli.js`. Related:
[[drift-check-idiom-broken]].
