---
name: haiku-default-tier-spec
description: 2026-10-08 haiku-default spec — config precedence makes a frontmatter tier flip inert here; settled ladder/fail-closed/migration decisions.
metadata:
  type: project
---

Plan: `docs/plans/2026-10-08-haiku-default-tier.md` (7 units, standard path; supersedes Stage 5 of the 2026-10-06 rubric programme, parks Stage 4).

Durable finding: **a tier change via `agents/lead-programmer.md` frontmatter alone is inert in this repo.** `.claude/persona-config.json` holds `defaultImplementerModel: "sonnet"` (the item18-2 backfill), the config outranks the frontmatter, and `--update` only backfills an ABSENT key. Any future tier flip needs a config path: here, a one-time migration keyed on the old `pluginVersion` < `IMPLEMENTER_HAIKU_DEFAULT_SINCE`, set in the same commit as the flip.

**Why:** the 2026-10-06 plan's Draft ADR listed "defaultImplementerModel unchanged" without noticing the value was `sonnet`, so a flip there would have done nothing.

**How to apply:** before speccing any default-tier change, read the config with the Read tool (Bash naming it is refused) and check the precedence chain end to end.

Settled decisions (user rulings 2026-10-08 plus self-resolved): a flat haiku default; ladder = the tiers from the default tier upward, two attempts each; the tier is a pure function of the FAIL-block count, so no tier record is needed across sessions; an unreadable count goes to opus; pre-cutover blocks start the ladder at sonnet; after exhaustion, re-dispatch goes to opus. Open: does opus get 1 or 2 attempts (default 2). The `gh issue create` umbrella publish was denied by the auto-mode classifier — don't assume to-spec publishing is permitted. See [[cli-update-never-reaches-settings-fragment]].
