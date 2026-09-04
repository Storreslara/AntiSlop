---
name: feedback_multifile_sweep_criterion_defect
description: Multi-file grep path-sweep criteria must handle filename-prefix colons, not just line-number suffixes
metadata:
  type: feedback
---

**Pattern:** Multi-file `grep -o` emits matches prefixed with `<filename>:`. Any cleanup sed that only strips trailing `:<digits>` or `:<start>-<end>` will fail when the evaluated files themselves are named in the paths being swept.

**Why:** This burned gh332's criterion 5, which tried to verify backticked paths resolve. When the ADR file itself (`docs/adr/0029-...md:`) appeared in a backtick, the match `docs/adr/0029-microworld-silo-namespaced-directories.md:` passed the extractor but failed the sed cleanup (only the filename-prefix colon remains, not a line number), so `[ -e docs/adr/0029-microworld-silo-namespaced-directories.md: ]` fails. Proven by mutation: fixing all three stale items still leaves exit=1 with only this artifact.

**How to apply:** When writing multi-file resolution-sweep criteria, choose one of:
1. Run the sweep per-file (no filename prefix)
2. Add `-h` to grep (suppress filename in output)
3. Extend the sed to strip bare trailing colons: `'s/:([0-9]+(-[0-9]+)?)?$//'` (handles both `:<digits>` and bare `:`)

This is a **task-master** note for future spec authoring in this area, not a code fix needed for gh332.
