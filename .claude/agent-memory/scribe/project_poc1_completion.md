---
name: poc-1 completion
description: PASS 2026-10-05; transcript_holds_prompt verifies teammate identity; three known limits (truncated lead, tmux placeholder, first-candidate shadowing)
metadata:
  type: project
---

poc-1 (commit 3ddfa45, 2026-10-05) ships `scripts/probe-hook-identity.sh` with a new optional 5th arg (candidate's transcript) and transcript verification logic to eliminate Outcome C false positives when the lead runs the teammate marker itself.

**Key change:** `transcript_holds_prompt()` reads the candidate's own transcript to check for the run-2 operator prompt string. A transcript bearing that prompt belongs to a lead session. When a candidate's transcript holds the prompt AND the teammate marker, the candidate is the lead itself calling the marker — the row is withheld, eliminating the false Outcome C (outcome=C signals a genuine teammate, which is wrong when it's the lead's own call).

**Known limits (non-blocking, per reviewer):**
- **L1 (truncated lead):** `transcript_holds_prompt()` uses `jq -e` which exits 2 on unparsable lines (e.g., truncated trailing line). A prompt-bearing lead transcript with a truncated trailing line adds nothing and the false C survives. Workaround exists (line-tolerant jq read) but is out of scope.
- **L2 (tmux placeholder):** if tmux stores the pasted prompt as a placeholder string `"[Pasted text #N]"` rather than the full text, the proof is inert until the tmux case is measured (operator step O2).
- **L3 (first-candidate shadowing):** `teammate_choose()` stops at the first genuine candidate. If a lead's own marker line appears as a genuine candidate before a later real teammate, the lead is withheld but the teammate is still missed (false Outcome D).

**Test additions:** rows I44–I49 added to `tests/probe-hook-identity.test.sh`, with fixture T9 and mutation controls.

**Regression check:** esf-eid-probe-fix FAIL cases (i) and (ii) re-run on this commit: both return `OUTC=D` (no false C/A).

**Plan:** docs/plans/2026-10-04-probe-outcome-c.md. No glossary entries needed (probe internals, implementation detail).
