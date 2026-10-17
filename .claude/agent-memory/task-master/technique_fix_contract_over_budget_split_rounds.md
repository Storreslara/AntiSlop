---
name: fix-contract-over-budget-split-rounds
description: A fix whose diff exceeds the 30000-byte contract budget is cut by feature into sequential fix1..fixN contract files under one Unit id; tools/dedit.py turns a file diff into edits.
metadata:
  type: reference
---

When a FAIL plus folded-in items needs ~45 KB of edits (abt-u14, 2026-10-16), write contracts/<unit>-fix1.md, -fix2.md, -fix3.md, all `Unit: <id>`, one commit each, each leaving the suite green, edit 1 of round N checking that round N-1 landed. Build each round's file states by hand (stage files), then `tools/dedit.py` `diff_edits(e, path, old, new, log)` emits the insert-after / before+after edits (anchors unique, backtick-free, split at 76 lines). Replay round N against a scratch clone with rounds 1..N-1 committed.

**Why:** the dispatch contract budget is hard; one oversized contract scores sizeOver.

**How to apply:** pick commit-selecting criteria by a round-specific subject word (`fix\(unit\): <word>`), because the original unit commit would keep a "newest unit commit" criterion green when the round commit is skipped. A criterion that guards already-correct code (kills a mutant) cannot use "skip edit N" when the test edit is a non-last chunk of a chunked insert (skipping breaks the next chunk's anchor): use a mutation + `proof:` naming the scratch mutant, and verify the row really FAILs under it.
