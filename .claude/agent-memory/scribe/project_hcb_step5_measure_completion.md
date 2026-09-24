---
name: project_hcb_step5_measure_completion
description: Unit hcb-step5-measure (issue #467) PASS completion; three glossary entries added to CONTEXT.md
metadata:
  type: project
---

## Unit hcb-step5-measure (issue #467) - PASS 2026-09-24

**Status:** Institutional knowledge updated per scribe duties. Three glossary entries added to CONTEXT.md as flagged by reviewer in PASS marker.

**Glossary entries added to CONTEXT.md:**

1. **characterization record** (new, line ~27): artifact class for dated, self-reported probe records like `docs/experiments/2026-09-23-probe-permission-mode-ask.md`. Distinct from Microworld bundles by being one-time measurements, not mechanically re-derivable.

2. **self-reported** (new, line ~40): formal evidence label marking an artifact as self-attested by human operator, not mechanically re-derived by test suite. Complementary to "mechanical"/"mechanically checked". Documented in `docs/trust-model.md`'s trust matrix.

3. **permission-mode allowlist** (new, line ~54): gate-internal filter on `permission_mode` values (`default|plan|acceptEdits|auto`, excluding `dontAsk`/`bypassPermissions`) that `harness-integrity-gate.sh`'s `ask_allowed()` checks before emitting `ask`. Distinct from [[Set A / Set B]] (file-path protection) and `permissions.allow` (individual grant override).

**Key findings recorded in unit:**
- All 6 permission_mode values render prompt when hook returns `ask` — including `bypassPermissions` (counterintuitive, noteworthy)
- Headless run (`-p`): `denied` (fail-closed, confirms R4)
- **U1 verdict:** `ask-still-prompts` — `permissions.allow` does NOT silently override hook's `ask` decision
- Set B's Step 1 (`docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md`) cleared to proceed as designed

**Note on inference:** `acceptEdits set=B` row is INFERENCE from single `set=A` probe run (hook is unconditional; rendering varies by mode, not production gate's case logic). Reviewer flagged this distinction as a review-technique lesson worth recording.

**Files touched:** `.claude/settings.local.json` (gitignored, one `permissions.allow` entry removed). New record: `docs/experiments/2026-09-23-probe-permission-mode-ask.md`.

**Do NOT touch:** `docs/trust-model.md`, source code, plan doc per unit instructions. Issue #467 not closed per normal duties (not in scribe's mandate).

---

**Why:** These three terms are load-bearing for understanding hcb-step5-measure's findings and the permission-mode ask behavior characterization. All three were missing from CONTEXT.md despite being central to the unit's evidence.

**How to apply:** Future units touching characterization records, self-reported evidence, or permission-mode gate logic should reference these entries. The trio of terms disambiguates: characterization records are self-reported artifacts, made checkable by marking them as not mechanically derived; permission-mode allowlist clarifies a gate-internal filter distinct from file-path protection or grant-level overrides.
