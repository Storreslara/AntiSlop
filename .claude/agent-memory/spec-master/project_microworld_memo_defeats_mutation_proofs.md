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
1. **Before commit 194add2** (memo-key-1 fix — 2026-08-26): Never read `result=fail` in
   `.claude/microworld-audit.log` as evidence a unit regressed without first re-running
   the bundle standalone. For a mutation-proof bundle the queue's verdict was
   unconditionally wrong.
   
   **After commit 194add2**: The memo key now includes argv+environment digest and per-shell
   guards, so mutation-proof bundles can legitimately pass under the queue. See
   **[[suite-level memoization]]** for the corrected behavior. Verify real regressions by
   re-running standalone as always, but a queue PASS on a mutation-proof bundle is now valid.
   
2. **Never "fix" a mutation-proof bundle to make the queue green.** The memo
   defeats the repo's primary anti-vacuity mechanism (see
   [[mutate-to-prove-the-criterion]], [[verify-own-criteria-nonvacuous]]);
   relaxing the bundle to match would delete real coverage and leave the
   vacuity undetectable. Fix belongs in `_memo_setup`, not the bundles.
3. When specing anything that touches the microworld queue, require the memo
   key to distinguish invocations that can legitimately differ. **Correction
   (measured 2026-08-26, while specing the fix): a content hash of "the files
   the suite exercises" — this memory's original suggestion — does NOT fix
   either affected bundle.** Neither mutates the working tree. Both copy
   `hooks/scripts/lib` to a `mktemp -d`, build the mutant there, and re-invoke
   the suite with an env prefix (`GATE_UNDER_TEST=…`): `rpg-canon-2/run.sh:29`,
   `hdg-anchor-1/run.sh:31`. The tree is byte-identical across baseline and
   mutant; **the environment is the only difference**, so a tree hash computes
   the same key for both. What was measured to work: argv+`env` digest in the
   key, AND/OR a "one cache hit per shell per key" guard (`<key>.$$.seen`);
   both preserve AC-A4 dedup at 1 execution. The naive owner-PID-in-the-`.rc`
   variant was measured BROKEN — a bundle that takes a cross-owner hit never
   becomes the owner, so all its later calls hit too. A criterion of the shape
   "bundle X exits 0 under the queue" is not machine-checkable for this class
   until the fix lands. Full spec: `docs/plans/2026-08-26-microworld-memo-mutation-proof.md`.
4. Not a timeout: `rpg-canon-2`'s manifest allows 180 s and it runs in 69 s.
   That was the obvious first hypothesis and it is wrong.

Introduced by spec2-unitA's queue work; surfaced (correctly, and exactly once
— the watermark at `stop-gate-core.sh:83` advances unconditionally before the
block fires) by Unit A's own deferred-surfacing block. Reported to the
coordinator 2026-08-26, not fixed here: another unit's file, and spec-master
never writes production code.
