---
name: drift-check-idiom-broken
description: The `--update --check | grep -qE ': (updated|created|pending)$'` drift-check idiom is measured-broken; never reuse it in a new acceptance criterion.
metadata:
  type: project
---

The acceptance-criterion form

    ! node bin/cli.js --update --check 2>&1 | grep -qE ': (updated|created|pending)$'

**cannot detect what it claims to.** It appears in several `docs/plans/` files
and reads like an established idiom. It is not one.

**Why:** finding F2 in `docs/plans/2026-08-09-agent-auditor-persona.md:1454-1493`
(measured on a throwaway clone, 2026-08-09) established that (a) anchored at
`$`, the regex matches exactly one of the six per-file summary shapes
`bin/cli.js` emits — `: updated (no local edits detected)` can never match
because of the parenthetical, and no `: pending$` line is ever emitted; (b) the
pipe discards the exit code, which is the only signal carrying the verdict; and
(c) F2 then corrected its own proposed remedy — a *bare exit-code check* fails
too, because `--check` is not a dry run and silently self-heals the
"source edited, mirror stale" shape before exiting 0. Only exit code **and** a
post-run working-tree assertion discriminates all three drift shapes.

**How to apply:** never copy this form into a new criterion. Until a genuine
`--dry-run` lands (specced in [[cli-update-flag-surface-spec]], issue #335,
whose exit-code contract collapses the two-signal check back to one), any
"no residual drift" criterion needs both an exit-code assertion and a
`git status --porcelain` assertion after the run. Related:
[[verify-own-criteria-nonvacuous]].
