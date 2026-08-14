---
name: sed-mutant-hash-comment-in-jq
description: A mutation-proof sed that appends `# MUTATED-<id>` can silently break a single-line jq program or a case-pattern line — pick the injection site by syntax context, not just by content match
metadata:
  type: feedback
---

When writing a mutation-proof `sed -i 's/PATTERN/false # MUTATED-X/'` against a
scratch copy of a script (the established pattern in
`tests/agent-auditor.test.sh`'s `mutation_proof()` helper), the trailing `#
MUTATED-X` comment is only safe on a **bare bash statement line**. Two ways it
breaks silently instead of loudly:

1. If `PATTERN` lives inside a single-line `jq '...'` program string, `#`
   starts a *jq* comment and swallows the rest of that jq pipeline (closing
   parens, the final `| @tsv`/output stage). jq then fails to parse, and under
   `set -euo pipefail` in the test script this aborts the **whole test suite**
   with a bare `exit 3` and no readable diagnostic — it looks like an
   unrelated hard crash, not a broken mutant.
2. If a broad regex range (e.g. `/--- A8 ---/,/print_section/{ ... }`) matches
   a *comment* line that happens to mention the same substring as the real
   code, and the substitution is `s/.*/false # ...../` (whole-line
   replacement), it turns a `#`-prefixed comment into an executed `false`
   statement — an unconditional failure under `set -e`, again unrelated to the
   detection logic you meant to neutralize. Same broad match can also hit a
   `case` pattern label line and replace the whole `pattern)` with a bare
   statement, breaking `case` syntax outright.

**How to apply:** before adding a mutation-proof sed, check what syntactic
context the matched line sits in (jq single-line program string vs. bash
statement vs. `case` label vs. comment). For a jq program, mutate the
predicate itself (e.g. `test(...)` → `false`) with **no trailing comment**.
For a `case` label, replace only the exact label text with a
never-matching-but-still-valid label (e.g. `NEVER-MATCHES-X-MUTANT)`),
never `s/.*/.../ ` across a whole line range. Always dry-run the mutant
(`bash -n` the mutated copy, or run it once by hand) before trusting the
suite's own PASS. Hit on gh288-1 (2026-08-14): both bugs were present
simultaneously in the A7 and A8 mutation-proof blocks the prior dispatch
left uncommitted, and both manifested identically as "the whole suite exits
3" rather than a normal FAIL line.
