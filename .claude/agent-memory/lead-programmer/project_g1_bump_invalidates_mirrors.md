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
  that file. Measured on gh345-2 (2026-08-12): a hand-restored
  `protectedPaths` entry and a hand-bumped `pluginVersion` both survive the
  run untouched; `--update` only rewrites `fileHashes`. Still worth a `jq`
  check after, since it is the file the run owns.
- **Since 0.31.28 `--update` also manages `.claude/hooks/scripts/**`** (raw,
  unstamped, content-hash-tracked). Two consequences: (a) any unit that makes
  `--update` treat a new file class as managed CANNOT be green while this
  repo's copy of that class is stale, because `cli-backfill.test.js`'s two F2
  cases copy the whole working tree into a fixture and assert the post-run
  tree is clean — so regeneration is forced into the same unit, no matter what
  a plan's unit split says; (b) `buildFileSpecs()` is NOT the place to add a
  new class — four existing tests treat every spec it returns as a stamped
  ADAPT mirror (`buildBaselineProject` stamps them all). Add a sibling builder
  and concat it in `runUpdate`, and teach `buildBaselineProject` to write the
  new class too, or its fixtures look like a project with that directory
  deleted.
- The code-review-graph's post-commit "Untested: <fn>" line is a **false
  negative** for bash hooks: it cannot see coverage that runs the script as a
  subprocess from a `.test.sh`. Do not treat it as a real test gap.
