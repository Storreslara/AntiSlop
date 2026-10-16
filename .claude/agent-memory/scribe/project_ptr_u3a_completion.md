---
name: ptr-u3a-completion
description: ptr-u3a PASS 33d8348 closed #556; four OPEN follow-ups on tests/contract-files.test.sh; glossary term deferred to ptr-u3b close-out
metadata:
  type: project
---

PASS 2026-10-16, commit 33d8348, closed #556. New tests/contract-files.test.sh; convention: a bare contract file whose line 1 is `Unit: <id>` parses like the plan form (ptr-u3b relies on it).

**Deferred:** glossary term "contract file"/"bare file" and the draft ADR land at the ptr-u3b (#557) close-out, per the spec's scribe hint. Do not add earlier.

OPEN follow-ups (recorded, not fixed):
1. CHANGELOG.md:5 says scored "the same as the block read from stdin", but stdin is the extracted file (test line 52); file-vs-plan equivalence is proven only for the guard line.
2. Stray-fence mutation (test lines 58-64) covers only the first lead contract (vln-1), not all nine.
3. Test lines 48-52 discard node stderr and ignore exit codes; an identical error line on stdout for both forms would pass.
4. CHANGELOG "fenced `Unit:` contracts" is borderline against the glossary avoid-list entry "contract (alone)".

**Why:** reviewer notes, non-blocking. **How to apply:** fold into any later touch of the test or CHANGELOG line.
