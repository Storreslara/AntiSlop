---
name: ocigf1-completion
description: ocigf-1 scribe update completion; PASS verdict; glossary and completion record
metadata:
  type: project
---

## PASS ocigf-1 (2026-10-05)

Reviewer verdict (quoted verbatim): "PASS ocigf-1. I ran all 16 acceptance checks (AC-1.1 to AC-1.16) myself at 01a3480 and all passed."

Marker: `.claude/reviewed/ocigf-1.pass`

Commit range: c82a8f1..01a3480

### Scope

Prototype/outcomeci-series-gate/ only. Scribe documentation updates, no code edits.

### Changes Made

**CONTEXT.md updates:**
- Updated "state snapshot" entry (line 1117) to mention symlinks recorded as `link:<sha256 of readlink string>  <relpath>` lines, never followed
- Added glossary entry "prototype suite runner": new `tests/run-all.sh` harness for the OutcomeCI Design A prototype

**Test verification:**
- Ran `node tests/context-glossary-links.test.js` — all 8 checks passed

### Non-Blocking Gaps

**Specification clarity gaps:**
- **AC-1.9 spec regex typo**: Specification line uses `\./?` (should be `(\./)?`); a spec fix is owed. Correct form already in use by S6 tests.
- **AC-1.6 run-id path check**: Ambiguity in scope of run-id path vs. terminal-status check sequence.

**Implementation stderr leaks (low severity):**
- **oci-series-gate.sh:31-33,52 NUL-byte marker refusal**: NUL bytes in marker cause exit 70 `marker-changed` refusal with stderr leak (bytes echo to terminal before rejection).
- **Deleted-marker "No such file" stderr leak**: When marker deleted between runs, "No such file" error leaks to stderr before gate can refuse.
- **journal-evidence.sh:13 Unicode passthrough**: U+0085/U+2028/U+2029 pass through unchanged in journal output without sanitization.
- **journal-evidence.sh:17 `.review` string vulnerability**: String `.review` appearing in a journal call's `string` field makes the entire journal marked as unreadable (false positive).

**Test coverage notes:**
- **Extra test S6d**: Snapshot-changes half of S6 passes on old code (pre-fix state), indicating test scope may exceed its intention.
- **run-all.sh output handling**: Suite runner discards individual suite output (captured in temp files but not surfaced to logs), reducing debuggability for failed runs.

### Related Entries

- [[ocig-1 completion]] (glossary entries for externalization, externalization precondition wrapper, broker journal, policy decision)
- [[ocig-2 completion]] (state-snapshot, terminal-status-set, zero-API workflow entries)
- [[ocig-3 completion]] (external run journal, external workflow runner entries)
