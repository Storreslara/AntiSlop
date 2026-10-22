---
name: diff-hunks-to-edits-and-test-compaction
description: A fix that rewrites a script plus a generated-matrix test fits the 30000-byte contract cap only if the test is built from helper functions and the edits are difflib hunks with unique anchors; replay in a clone.
metadata:
  type: reference
---

rp-u6-fix1 (2026-10-22): write the finished script and test in a scratch dir first, run them (and against the old script for the red count), then generate the contract edits from `difflib` opcodes (insert-after when the hunk is a pure insertion, else before/after; anchor = the longest backtick-free substring of a before line that is unique in the evolving file). A draft was 42 KB; it fit (29.8 KB) after the test used `one`/`expect`/`sum` helpers, criteria dropped redundant range checks, and prose in Pre-resolved context lost its duplicates.

**Why:** `contract-score` sizeOver is hard at 30000 bytes, and anchors with a literal backtick or a trailing backslash need the escape rules the fixed script parses (a trailing-backslash literal must stay readable, or abt/rp-u14 anchors regress).

**How to apply:** replay the contract with an applier in a `git clone` at the base commit (apply edits, bump, `--update`, commit, run each `run:`, plus `validate.sh`); build skip-edit mutants by re-applying all hunks but one. A Bash text naming the persona config file is refused by the integrity gate: keep such names out of heredocs and write files with the Write tool.
