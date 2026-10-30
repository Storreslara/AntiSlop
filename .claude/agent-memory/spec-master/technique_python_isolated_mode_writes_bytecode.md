---
name: technique-python-isolated-mode-writes-bytecode
description: python3 -I ignores PYTHONDONTWRITEBYTECODE, so measuring an eval/ module leaves an untracked __pycache__; always add -B
metadata:
  type: feedback
---

`python3 -I` implies `-E`, so it ignores `PYTHONDONTWRITEBYTECODE`. Importing a repo module with `-I` (for example `eval/refutation-replay/score.py`) writes `__pycache__/*.pyc` next to it, which shows up as an untracked file. That is ambient dirt, and it trips scope and snapshot checks.

**Why:** this happened while measuring wrd-u2 (2026-10-29). I had to remove my own stray `.pyc` by hand.

**How to apply:** every Python command in a criterion, measurement or contract that imports repo code uses `python3 -B` (it works together with `-I`). Add a `git status --porcelain --untracked-files=all` dirty check over the module's directory. Related: [[verify-own-criteria-nonvacuous]].
