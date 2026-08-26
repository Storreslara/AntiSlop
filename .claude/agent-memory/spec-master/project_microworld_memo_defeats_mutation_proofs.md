---
name: microworld-memo-defeats-mutation-proofs
description: microworld-queue.sh's _memo_setup memoizes `bash tests/*.test.sh` on the test PATH alone, so every mutation-proof bundle reports a false FAIL under the queue while passing standalone
metadata:
  type: project
---

`hooks/scripts/lib/microworld-queue.sh`'s `_memo_setup` (~:58-80) exports a
`bash` shell function that memoizes any `bash tests/*.test.sh` call, keyed on
**the test path alone** — `key="$(printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_')"`
— with no input from the state of the code under test.

A **mutation proof** does exactly the thing that breaks: mutate a source file,
re-invoke *the same* suite, expect a *different* exit code. The memo returns
the cached rc from the unmutated run, so every mutant appears to kill nothing
and the bundle reports FAIL.

**Why:** measured 2026-08-26, reproduced both directions on `rpg-canon-2` at a
clean HEAD.
- Standalone (`bash ./microworlds/rpg-canon-2/run.sh <path>`): **exit 0** —
  "OK 14 kills", "OK 11 kills".
- With `_memo_setup`'s function replicated verbatim: **exit 1** — "FAIL site1
  did not reopen case 38.1 (or the mutant crashed)", same for site2.
Same commit, same tree; the memo is the only difference.

The affected set is predictable and was predicted before measuring: only
bundles whose `run.sh` re-invokes a suite after mutating source. In this repo
that is exactly `rpg-canon-2` and `hdg-anchor-1` — and those are precisely the
two that failed on all four deferred drains (14:50, 15:03, 15:05, 15:15Z)
while `rpg-comment-3`, `hdg-lexer-1`, `hdg-prose-2`, `hdg-prose-2-fix2` passed
every time. A *stable* fail/pass split across drains is the signature; genuine
tree-state breakage would vary.

**How to apply:**
1. **Never read `result=fail` in `.claude/microworld-audit.log` as evidence a
   unit regressed** without first re-running the bundle standalone. For a
   mutation-proof bundle the queue's verdict is unconditionally wrong.
2. **Never "fix" a mutation-proof bundle to make the queue green.** The memo
   defeats the repo's primary anti-vacuity mechanism (see
   [[mutate-to-prove-the-criterion]], [[verify-own-criteria-nonvacuous]]);
   relaxing the bundle to match would delete real coverage and leave the
   vacuity undetectable. Fix belongs in `_memo_setup`, not the bundles.
3. When specing anything that touches the microworld queue, require the memo
   key to include the content hash of the files the suite exercises, or an
   opt-out a mutation-proof `run.sh` can set. A criterion of the shape "bundle
   X exits 0 under the queue" is not machine-checkable today for this class.
4. Not a timeout: `rpg-canon-2`'s manifest allows 180 s and it runs in 69 s.
   That was the obvious first hypothesis and it is wrong.

Introduced by spec2-unitA's queue work; surfaced (correctly, and exactly once
— the watermark at `stop-gate-core.sh:83` advances unconditionally before the
block fires) by Unit A's own deferred-surfacing block. Reported to the
coordinator 2026-08-26, not fixed here: another unit's file, and spec-master
never writes production code.
