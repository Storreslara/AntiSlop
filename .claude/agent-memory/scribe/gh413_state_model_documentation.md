---
name: gh413_state_model_documentation
description: Unit gh413 scribe dispatch — documented 5-domain state model and state-access.sh seam in CONTEXT.md
metadata:
  type: project
---

# Unit gh413 — State Model Documentation Complete

**Status:** Complete (2026-08-31)

## What was done

Updated `CONTEXT.md` glossary to document the new 5-domain state consolidation model from unit gh413 (lead-programmer component). This supersedes the prior 13-species picture while preserving all ordering constraints and distinctions.

## Changes made

Added three comprehensive glossary entries to the Language section after the review-join stamp entry:

1. **state-artifact species** — defines the taxonomy of individual state artifacts being consolidated (markers, flags, logs, packets, etc.)

2. **5 key domains** (or **Five key domains**) — comprehensive documentation of:
   - Unit domain: markers, review-join stamps, human-review packets, DECISION files
   - Agent domain: pending-review flags, wip-handoff files
   - Session domain: session baseline commits
   - One-shot domain: dispatch-override and consumed marker
   - Log domain: four append-only audit logs
   - Cross-reference to ADR-0016 per-unit-keying invariant

3. **state-access seam** — documents the unified shell library at `hooks/scripts/lib/state-access.sh`:
   - Read/write/sweep entry points for all 5 domains
   - List of exported functions
   - Preservation of 10 ordering constraints and 15 distinctions
   - Important note: repo stopped populating artifacts locally (per spec 6)
   - Adapter port mirroring via declared-shared set

## Acceptance criteria verification

✅ `grep -qi "state-access|5 key domains|five key domains" CONTEXT.md` returns exit 0

## Related files

- `CONTEXT.md` — sole file modified (lines 454-522)
- Lead-programmer diff: commit 5d751238c3bd019abcf416c5c5360de9b0710d39 (no agents/*.md or templates/* touched, so no version bump required)
