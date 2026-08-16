---
name: validate-sh-is-a-mirror-parity-check
description: tests/validate.sh IS transitively a source-mirror parity check, so any unit editing agents/*.md or templates/*.md must regenerate mirrors in the SAME unit; and plain --update cannot do it
metadata:
  type: project
---

Any spec step that edits `agents/*.md` or `templates/*.md` **must regenerate
its `.claude/` mirrors inside the same unit**. Deferring mirror regeneration
to a later "release hygiene" step makes `bash tests/validate.sh` exit 1 on
that step's own commit, so a `validate.sh exit 0` criterion becomes
**unsatisfiable within the unit's write scope**.

**Why:** `validate.sh:520` runs `tests/cli-backfill.test.js`, whose
`buildF2GitFixture` copies the **real repo root** verbatim into a fixture;
its C2.12 check then asserts `node bin/cli.js --update --dry-run` exits 0 on
that copy. Since `--dry-run` implies `--force-render`, that is transitively a
live-tree parity check. Measured 2026-08-16: exit 0 at `1ec63c7`, exit 1 at
`46b21da` (four sources edited, no mirror). A plan that writes "validate.sh
does not check agents/ ↔ .claude/agents/ content parity" is stating something
false — that exact sentence caused gh403's 2-FAIL escalation.

**The trap that makes the fix non-obvious:** plain `node bin/cli.js --update`
often **cannot repair this**. Its fast path at `bin/cli.js:1269` returns early
when `config.pluginVersion === version` and every mirror's stamp matches, and
the pre-scan at `:1263` compares the **stamp, not the content**. So right
after any version bump + regen commit, `--update` prints "already current.
Nothing to update." and rewrites nothing while `--dry-run` correctly reports
stale mirrors. Use **`node bin/cli.js --update --force-render`** (CONTEXT.md's
documented canonical force-the-loop control, P2-compliant script output), or
bump the version first — a version bump before `--update` restores the full
render.

**How to apply:** when scoping any step touching persona sources or
templates, put `--force-render` regeneration in that step's affected files,
and never write a "Do NOT touch any `.claude/` mirror" line alongside a
`validate.sh exit 0` criterion. The surviving prohibition is narrower: never
*hand-edit* a mirror or `fileHashes`. Verify `validate.sh` in a **clean
detached worktree at the unit's own commit**, never the live tree — see
[[baselines-expire]] and [[verify-own-criteria-nonvacuous]].

Third recorded instance of this one failure class: `gh385-2.fail`,
`gh402.pass` note 1, `gh403.fail`.
