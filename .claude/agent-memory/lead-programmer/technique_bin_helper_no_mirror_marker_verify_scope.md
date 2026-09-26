---
name: bin-helper-no-mirror-marker-verify-scope
description: bin/ scripts aren't mirrored across adapters/.claude like hooks/scripts/lib are; marker-verify.sh is scoped to .pass only
metadata:
  type: technique
---

`bin/*.sh` helpers (e.g. `bin/marker-audit.sh`, `bin/fail-count.sh`) have
exactly one copy in the repo — `tests/validate.sh` never asserts mirror
parity for them, unlike `hooks/scripts/lib/*.sh` and gate scripts, which are
mirrored into `.claude/` and both `adapters/*/hooks/scripts/`. Before adding
a mirror-parity step for a new `bin/` script, check whether one is actually
asserted (grep `tests/validate.sh` for the script's path) rather than
assuming R3-style blast radius applies uniformly.

Separately: `hooks/scripts/marker-verify.sh` is scoped to `.pass` markers
only (`state_unit_marker_exists "$task_id" pass` gates entry) and has
line-2 note-parsing logic (`run_notes_mode`) that a persona-audit finding
already flagged as fragile. When a new marker-reading feature is scoped to
`.fail` (e.g. counting FAIL blocks, item12-2), prefer a standalone `bin/`
helper over extending `marker-verify.sh` — it sidesteps that fragile parsing
entirely rather than risking it, and needs no mirror-parity step per the
paragraph above.

**Why:** discovered while implementing item12-2's FAIL-block count command;
the spec offered both a `marker-verify.sh` mode and a `bin/` helper as valid
homes, and picking the `bin/` helper avoided both the note-parsing risk and
an unnecessary mirror-parity obligation.

**How to apply:** any future unit touching `.fail`/`.pass` marker reading
(item12-3, item9's grace period, item15's seal sidecars) should re-check
this scope split rather than assuming `marker-verify.sh` is the generic
marker-reading entry point.
