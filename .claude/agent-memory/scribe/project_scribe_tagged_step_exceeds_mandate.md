---
name: scribe-tagged-step-exceeds-mandate
description: A spec-master step tagged [scribe] can still ask for test/version-bump work outside scribe's write scope — do the doc part, decline and route the rest
metadata:
  type: project
---

gh348-10 (Step 10 of docs/plans/2026-08-13-persona-efficiency-audit-gh348.md,
finding N1) was tagged `[scribe]` in the spec and asked for CONTEXT.md +
wiki fixes (in scope) AND a new mechanical test / `tests/validate.sh`
addition (C10.4) AND a version bump + CHANGELOG.md entry (C10.5) — both
outside scribe's write scope (`.claude/wiki/`, `CONTEXT.md`, `docs/adr/`,
memory, tracker issue state only; never source code, never
package.json/plugin.json/CHANGELOG.md).

**Why:** the `[scribe]` tag on a spec step describes who owns the
*documentation* half of the finding, not necessarily the whole step. A
step that also wants a regression test to prevent the drift from
recurring is legitimate work, just not scribe's to do.

**How to apply:** when a spec step tagged `[scribe]` includes acceptance
criteria that touch test files, `tests/validate.sh`, version-stamped
files, or CHANGELOG.md, complete only the doc-owned criteria, commit that
separately, and report back explicitly listing the remaining criteria as
needing a lead-programmer follow-up unit. Do not attempt the code/test
criteria yourself even if the "default expectation" language in the spec
suggests you should — do not stretch the mandate under label pressure.
Never leave the mismatch silent; name it in the STATUS line and the
handoff message so the issue doesn't sit half-done. Do not close the
tracker issue when leaving criteria undone this way.

See also [[project_persona_prose_edit_traps]] for other gh348-pass
doc-maintenance gotchas.
