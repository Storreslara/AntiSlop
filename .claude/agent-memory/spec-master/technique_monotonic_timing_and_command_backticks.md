---
name: technique-monotonic-timing-and-command-backticks
description: Timing criteria must use /proc/uptime (WSL's date +%s jumped back 2 s in a 12 s run); and never put backticks in a contract `command:` line's trailing parenthetical.
metadata:
  type: feedback
---

Two traps found while writing the vlg plan (2026-10-14).

1. **Wall clock is not monotonic here.** A criterion asserting "--lanes 1 takes >= 12 s" for six
   `sleep 2` sections failed reproducibly with 10-11 s by `date +%s`, while `/proc/uptime` showed
   12.1 s. Any elapsed-time criterion (parallelism proofs, timeouts) must measure with
   `cut -d' ' -f1 /proc/uptime`, and keep a 1 s margin.
2. **Backticks in a `command:` parenthetical.** `command: \`git commit ...\` (... if \`index.lock\`
   exists ...)` - a greedy `` `(.*)` `` extractor (mine, and plausibly an implementer reading by eye)
   swallowed the parenthetical into the command, so every commit message ended `...>index.lock`
   and the trailer criterion printed `0 `. Keep the parenthetical backtick-free.

**Why:** both were silent until the plan's edits were applied by script and every criterion run in a
fresh copy; a hand-read plan looked correct.

**How to apply:** for any timing criterion use the monotonic clock; after drafting contracts, extract
`command:` lines with `` `([^`]*)` `` and run them in a scratch copy. Related:
[[technique-parallel-contracts-and-escape-drift]], [[verify-own-criteria-nonvacuous]].
