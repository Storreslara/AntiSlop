---
name: technique-pin-search-window-and-clone-dry-runs
description: A fixed-width sliding-window search for test pins misses literals shorter than the window; dry-run contracts on a git clone in scratch, bumping the version first or --update does nothing
metadata:
  type: feedback
---

A 45-character sliding-window search over `tests/` for pins on moved text cannot see a pin shorter than 45
characters. In the quick-wins spec it missed `tests/packet-view-script.test.sh` T10 (a 44-character literal,
counted twice), and the spec had already claimed "the only pin". Back it up with a second pass: grep tests for
the moved file's path, then read each hit's assertion.

**Why:** a missed pin turns a pure text move into a red validate.sh and a FAIL (aof-u1 FAILed the same way).

**How to apply:** for every move unit, (1) window search, (2) `grep -ln <moved-file> tests/*` and read the
assertions, (3) dry-run the edits on `git clone -q <repo> <scratch>/wtN` and run the suites. In that clone,
bump the version before `node bin/cli.js --update`, or it prints "already current" and regenerates nothing;
commit in the clone before eval tests that copy HEAD (abtest-arms compares against HEAD). Use a fresh clone
directory name instead of `rm -rf $VAR` (a safety check blocks that). Doc text that names a gated path
(DECISION file plus packet dir, or the persona-config path) must be written with Write/Edit, not a Bash
heredoc or a `python3 -` heredoc. See [[technique-generated-contracts-exact-payloads]].
