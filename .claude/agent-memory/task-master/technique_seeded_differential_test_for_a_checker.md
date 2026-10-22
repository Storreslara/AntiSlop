---
name: seeded-differential-test-for-a-checker
description: A checker script that two reviews broke by randomised comparison is closed by a fixed-seed awk oracle in its own test (160 cases, ~12 s), a grammar round-trip table, and one canonical path function; plus the contract-size levers that fit it under 30000 bytes (rp-u6 fix2, 2026-10-22).
metadata:
  type: reference
---

For a fix after a reviewer found false-ok classes by random comparison: put the same comparison in the suite. `awk` generates cases from a Park-Miller LCG (`s = (s*16807) % 2147483647`; doubles stay exact), writes `N.md` (contract), `N.txt` (file), `N.exp`, `N.rc`; bash copies `N.txt` into the repo dir and compares the tool's stdout and exit with the oracle. Same awk program emits (literal, rendered phrase) pairs to test a grammar round-trip. gawk and mawk produce identical files.

**Traps:** `-v s=7331` then `s = seed` in BEGIN zeroes the RNG (every case identical, the test passes against the old script, so always run the new test against the OLD script and require red); `for (e = 1; e <= 1 + rnd(3); e++)` redraws the bound every pass; a payload line of three backticks would open a fence in the contract parser, so token lists avoid a lone backtick token. `pkill -f replay.py` inside a Bash call matches the shell's own command line: use `pgrep -f 'replay[.]py'` and kill the pids.

**Size levers (contract 35.4 KB -> 29.8 KB):** `tools/dedit_short.py` (shortest unique 14+ char anchors, `~~~` fences); drop the duplicated header/context prose; one stdin-contract criterion per feature instead of many; mutations as `skip edit N` where replay.py can prove them, `proof:` lines only for text mutants (run them in a scratch copy first: removing a fallback line gave `1 2 96 96`, not the crash I had guessed). A `git commit -a`-style mutation for the clean-tree criterion is "omit `git add -u -- .claude`", not "skip --update" (skipping leaves .claude clean).

**Why:** the next reviewer round should find nothing a suite could have found.
**How to apply:** any checker/parser unit whose two reviews found different classes of the same false-ok.
