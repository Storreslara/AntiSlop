---
name: ptr-u4b index-size gaps
description: ptr-u4b PASS (2026-10-15, 81a019e): two CONTEXT.md entries minted (agent-memory index, index-size cap); three non-blocking gaps in the index-size warning for follow-up
metadata:
  type: project
---

ptr-u4b (issue #545) PASS on 2026-10-15 at 81a019e; issue closed by scribe; glossary commit b9187b7. Added **agent-memory index** and **index-size cap** to CONTEXT.md (domain route; no prior synonym existed; the write path is the harness-glossary term **agent-memory write**).

**Why:** the reviewer found both terms undefined; the cap is advisory (warn-only, exit 0), so it sits in the domain glossary, not the harness one.

**How to apply:** when the follow-up unit touches the index-size check, these are the open gaps (none block; none belong to this dispatch):
- (a) The over-lines test fixture (41 lines, 4182 B) also trips the byte cap, so the line cap is not tested in isolation. A 41-line fixture under 4096 B would isolate it.
- (b) The contract's AC7 mutation note (stray `)` after `exit 0`) cannot turn criterion 7 red: the `bash -n` loops in `tests/validate.sh` cover only hooks/ and adapters/, not bin/.
- (c) Non-numeric `--index-cap-*` values are unguarded (same pattern as `--threshold-kb`), and a MEMORY.md without a final newline is undercounted by one line (`wc -l`).

No wiki page describes the size check, so no wiki edit was made.
