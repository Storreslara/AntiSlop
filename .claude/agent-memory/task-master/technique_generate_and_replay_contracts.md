---
name: technique-generate-and-replay-contracts
description: Saved scripts under tools/ generate code-heavy contracts from real scratch files and replay them (edits, criteria, skip-edit mutations) in detached worktrees; plus the rubric traps hit while using them (abt slice, 2026-10-16).
metadata:
  type: reference
---

For a contract that creates whole files, write and run the files in a scratch `git worktree add --detach` first, then generate the contract from those files so the payload is the tested text.

- `tools/cg.py`: `Edits().new_file(path, text)` splits at unique, backtick-free lines (<=78 lines per part, anchors chained to the previous part's last line); `insert_after`, `replace`, `command`, `criterion`, `std_criteria` (files-changed list, trailer, untagged tail, scoped clean-tree), `context`, `assemble`. See `tools/example_unit_script.py`.
- `tools/replay.py CONTRACT REPO BASE_SHA`: red-before, green-after, and a rebuild per `skip edit N` mutation. `REPLAY_SEED=src:dst` copies an untracked file into each worktree. `tools/proof_tail.py` runs the untagged-tail proof.

Traps seen: `blast-radius:` must be exactly `none` or contain a `path:line` token (a trailing parenthetical scores R5 false). A skip mutation must target the LAST part of a split file (skipping a middle part breaks the next anchor). A clean-tree criterion with `--untracked-files=no` stays green when the commit step is skipped (new files are untracked): scope `git status --porcelain -- <paths>` instead. A negative guard criterion (`grep -c` on a missing file) is red only by accident; prefer a positive count.
