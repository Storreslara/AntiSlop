---
name: technique-sed-range-one-line-overrun
description: sed -n '/start/,/end/p' never tests the end regex on the start line, so a one-line match (e.g. a one-line JS array) runs to the NEXT end match; use awk with an exit
metadata:
  type: reference
---

`sed -n '/^const X/,/];/p'` checks address 2 only from the line AFTER the start line. When the start line
also holds the end (`const X = ['a'];`), the range runs on to the next `];` in the file and pulls in
unrelated content, so a "does the array hold Y" grep gets false hits.

Use `awk '/^const X/{f=1} f{print} f&&/\];/{exit}'` instead. Found writing l2-tests (2026-11-01): the
plan's suggested `const` line to `];` extraction was the overrunning sed form; a fixture with a one-line
array followed by another array naming the target proves the difference (`1 1 1` vs `1 0 1`).

Related: [[technique-update-index-one-flag-per-call]].
