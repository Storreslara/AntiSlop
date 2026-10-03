---
name: jq-filter-preserve-absent-keys
description: jq `{a, b}` turns an absent key into null and silently breaks a downstream `has("a")` check; filter with with_entries(select(...)) instead (esc-chat-1-evidence2)
metadata:
  type: feedback
---

When trimming a JSON object to a few keys before a classifier reads it, use
`jq -c 'with_entries(select(.key == "a" or .key == "b"))'`, never `{a, b}`.

**Why:** `{a, b}` emits `"a": null` for an absent key, so a fallback branch
gated on `! has("a")` (probe_headless's regex classifier) stops firing and the
run turns into a miss. Mutant M10 in esc-chat-1-evidence2 proved it.

**How to apply:** any filter-before-save step whose consumer distinguishes
"absent" from "null/empty". Test the absent-key case with an exact expected
saved string, not just the verdict.

Related fixture trap from the same unit: when a gate parses a "leading run"
of length-prefixed blocks and you add a second block kind, fixtures that
append blocks after the new kind become invisible to the OLD gate (it stops at
the unknown header), so a pre-existing RED case can read GREEN against the old
code mid-TDD. That is expected red-phase noise, not a regression; re-check it
against the new gate. See [[length-prefixed-evidence-blocks]].
