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

**Why it keeps recurring — the live tree gives a FALSE PASS.**
`buildF2GitFixture` copies the **real repo root verbatim**, including
*uncommitted* files. So an in-flight (unstaged) regeneration makes
`cli-backfill`/`validate.sh` exit 0 locally while the same commit exits 1 in a
pristine worktree. Measured 2026-08-25 at `76c51a8`: live tree exit **0**,
pristine worktree exit **1**. An implementer who "verified" in place sees
green. Always `git worktree add --detach <tmp> <sha>`.

**The fast-path trap is intermittent, which makes it worse.** Measured
2026-08-25: plain `--update` wrote nothing at `6b6a7a2` (test still exit 1)
but *did* fully render at `76c51a8` — only because an unrelated open unit had
left one hash stale, tripping drift detection into a full render. Repairing
that other unit first would silently re-arm the fast path. Never let a spec,
CHANGELOG, or dispatch say "regenerate via `bin/cli.js --update`" — always
`--force-render`.

**Strongest criterion for this class** (better than enumerating greps): in a
pristine worktree at the fix commit, `node bin/cli.js --update --force-render
&& git status --porcelain` must emit **zero lines** — i.e. the committed tree
is a render fixed point. Un-hand-editable, and it fails loudly pre-fix (4
` M ` lines).

**Scope hazard:** `bin/cli.js` rewrites the *whole* `fileHashes` map and
cannot render a subset, so the fix commit may unavoidably carry hash lines
belonging to other open units. Pre-authorize them in the spec and require the
commit message to name them, or a reviewer will FAIL the unit for
out-of-scope hunks.

Fourth recorded instance of this one failure class: `gh385-2.fail`,
`gh402.pass` note 1, `gh403.fail`, `mw-step3.fail` (2026-08-25 — see
`docs/plans/2026-08-25-debug-mw-step3-mirror-regeneration.md`; the 0.31.63
CHANGELOG entry is the mirror-image, mirrors edited without sources).
**Fifth: `spec2-unitE.fail` (2026-08-26)** — the *baseline-only* sub-shape:
content correct in all four copies, only `fileHashes` stale. See
`docs/plans/2026-08-26-debug-spec2-unite-stale-hash-baselines.md`.

**The four-copy change is really a FIVE-artifact change** — three managed
mirrors *plus* `persona-config.json`'s `fileHashes`. `spec2-unitE`'s commit
`9832876` regenerated all three mirrors and omitted the config, so
`bin/cli.js:1427-1431` self-healed on the next `--update`, dirtying the tree
and turning `cli-backfill` red. Any spec whose cross-cutting constraint says
"four-copy change" understates it; say five.

**`validate.sh` has no direct `fileHashes` check** (as of 2026-08-26).
`validate.sh:302` (`diff -rq hooks/scripts .claude/hooks/scripts`) guards
mirror *content* only, and it was GREEN throughout `spec2-unitE`'s FAIL. The
sole detection is `cli-backfill.test.js`'s F2/C2.12, whose message names a
synthetic drift shape ("shape B must leave the working tree clean post-run"),
not the real cause — three `hash would be healed (content unchanged, hash was
stale)` lines buried in an ~80-line summary. That **misattribution**, not the
absence of detection, is what cost three separate debug detours.

**If you propose a direct hash check, `stripStamp` is mandatory — measured
trap.** The obvious form (`sha256sum <file>` vs the recorded value) fails
**13 of 52 entries at a known-green HEAD**: every `kind !== 'raw'` artifact
(ten `.claude/agents/*.md`, `persona-protocol.md`, `persona-protocol-slim.md`,
`protocol-digest.md`) records the hash of the *stamp-stripped* body per
`bin/cli.js:476`. Route through `bin/cli.js`'s exported `sha256Hex` +
`stripStamp` (both in `module.exports`): measured **52/52 clean, 84 ms**.

**Why the render-fixed-point criterion above did NOT generalize.** It works,
but it *mutates* the tree and presupposes a clean one, so it can only ever be
a per-unit criterion — never a standing `validate.sh` gate. That is why the
mw-step3 remedy failed to prevent `spec2-unitE` 24 hours later. A standing
gate must be read-only. Also rejected, both measured: `--update --dry-run`
(exit 3 after any constitution-§3 version bump until mirrors re-stamp, per
`bin/cli.js:1359`/`1403-1409`/`1508`; and its exit code depends on the
invoking machine's `~/.claude/settings.json` — the hazard
`cli-backfill.test.js:1179-1194`'s `buildF2Home` exists to work around).

Precision on line 17 above: `--dry-run` does not literally imply
`--force-render` — the `pluginVersion` fast path at `:1359` still applies. It
renders in the fixture because `buildF2GitFixture` copies a repo whose state
trips drift detection.
