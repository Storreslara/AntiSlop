---
name: g1-bump-invalidates-mirrors
description: A G1 version bump alone turns tests/validate.sh RED via cli-backfill.test.js — the .claude/ mirrors bake in the version stamp and must be regenerated in the SAME unit; also, `--update --check` writes despite the name
metadata:
  type: project
---

Bumping the G1 version triple **by itself** makes `bash tests/validate.sh`
fail, even with no other change. Regenerate the mirrors in the **same unit**
as the bump.

**Why:** every `.claude/agents/*.md`, `.claude/persona-protocol{,-slim}.md`
and `.claude/protocol-digest.md` carries a
`<!-- antislop v<VERSION> | source: ... -->` stamp line. Bumping
`package.json` / `.claude-plugin/plugin.json` / `pluginVersion` leaves all 13
stamped at the old version. `tests/cli-backfill.test.js`'s F2 regression
copies the whole working tree into a fixture, so the stale stamps flip its
shape-B assertion and `validate.sh` goes RED with a failure that names
`.claude/agents/agent-auditor.md` and looks completely unrelated to your
change. Hit on gh345-1 (2026-08-12); the 0.31.25 CHANGELOG entry describes
the same mechanism from the other direction.

**How to apply:**
- After the G1 bump, run `node bin/cli.js --update` and commit the 13
  regenerated files with the rest of the unit. The diff is one comment line
  each, `content unchanged` — mechanical, not a content edit, so it does not
  conflict with a "do not touch `.claude/agents/*.md`" scope line that is
  about prose. Say so explicitly in the review packet, since it looks like
  scope creep at a glance.
- **`node bin/cli.js --update --check` WRITES.** Despite the flag it reports
  "update complete" and refreshes the stamps on disk. Do not reach for it as
  a read-only probe — check `git status` after, and see
  [[cli-update-flag-surface]] territory.
- Verify `.claude/persona-config.json` survives the run intact if you edited
  it by hand first (e.g. a `protectedPaths` change) — `--update` rewrites
  that file.
- The code-review-graph's post-commit "Untested: <fn>" line is a **false
  negative** for bash hooks: it cannot see coverage that runs the script as a
  subprocess from a `.test.sh`. Do not treat it as a real test gap.
