---
name: project-gh424-spec1-completion
description: gh424 closed spec 1 (harness-trust-gaps) with 5 glossary terms; all five matched ticket's described shape exactly, no spec-gap escalation needed
metadata:
  type: project
---

Unit gh424 (2026-08-27) added five CONTEXT.md glossary entries — **disarm
surface**, **audit seal**, **sanctioned rotation**, **countersign**,
**authority** — closing the final (10th) unit of
`docs/plans/2026-08-25-harness-trust-gaps.md` ("spec 1"). Committed at
`1156085`.

**Why:** the ticket instructed reading the actually-landed diffs (gh415
`7dbbfdf`+, gh417 `f25b74e`/`54d7ebc`, gh422 `065ff12`, gh423 `30e4c96`)
rather than trusting the plan's pre-implementation description, and to STOP
and report a spec gap if the shipped shape diverged materially.

**How to apply:** verified all five terms against the real code
(`bin/harness-integrity.sh`'s `normalize_disarm_surface()`,
`hooks/scripts/lib/audit-log.sh`, `hooks/scripts/lib/microworld-queue.sh`'s
`_bundle_authority()`, `bin/human-review-cleanup.sh`'s `rotate_log()`) —
every term matched the ticket's description exactly, including gh423's
9-field disarm-surface list named verbatim in the dispatch. No divergence,
so no escalation was filed. One nuance worth knowing if this area is
touched again: **sanctioned rotation** has two call sites with genuinely
different archival shapes — `audit_rotate()` in `audit-log.sh` (fresh log +
header line, used by `bin/harness-integrity.sh --rotate`) and
`human-review-cleanup.sh`'s own pre-existing `rotate_log()` (preserves the
log's last line for defer-dedup, calls `_audit_reseal` directly rather than
switching to `audit_rotate`'s format). Both are legitimate; a bare `mv`/`: >`
elsewhere would not be. `docs/trust-model.md` and `README.md`'s "Known
limitations" gap were both correctly left untouched per the ticket's Do NOT
touch list (the README gap is entangled with sibling spec 6's coordination).

No reviewer PASS marker existed for gh424 at completion time (checked
`.claude/reviewed/`) — issue not closed by scribe; awaits reviewer PASS per
the standard gate before any close.
