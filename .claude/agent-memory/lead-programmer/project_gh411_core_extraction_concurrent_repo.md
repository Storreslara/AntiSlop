---
name: gh411-core-extraction-concurrent-repo
description: gh411 (reviewer-route-gate/stop-gate core extraction) gotchas - concurrent --force-render races corrupting persona-config.json hashes, block()/allow() function-injection for a genuinely divergent loop-guard mechanism, two spec numeric criteria proven unreachable
metadata:
  type: project
---

Unit gh411 (extract reviewer-route-gate.sh/stop-gate.sh into
hooks/scripts/lib/*-core.sh, retarget tests/adapter-stop-gate-parity.test.sh)
landed at commits 9b1e768 (main work) + cbd53d5 (hash fix). Reusable lessons:

**Concurrent `--force-render` runs corrupt `.claude/persona-config.json`.**
This repo runs multiple agents/worktrees simultaneously (`git worktree list`
showed 2 others mid-session). Running `node bin/cli.js --update
--force-render` while another unit has an uncommitted OR already-committed-
but-not-yet-mirror-regenerated source template change sweeps their content
into YOUR regenerated `.claude/agents/*.md` mirrors and persona-config.json
hashes. Reverting the mirror `.md` files via `git checkout HEAD -- <path>`
without ALSO re-syncing persona-config.json's hash entries for those same
paths leaves the two inconsistent - caught late, by
`tests/cli-backfill.test.js`'s "diverged from a fresh copy" check. Fix:
after any `git checkout HEAD` on a stamped mirror file you didn't mean to
touch, immediately recompute and hand-patch its persona-config.json hash
entry to match (`cli.sha256Hex(cli.stripStamp(fs.readFileSync(path)))`) in
the SAME step, not as an afterthought.

**Before assuming a red test is yours, prove it predates you.** When
`tests/cli-backfill.test.js` still failed after my hash fix (different
failure this time: "shape B... got: M .claude/agents/lead-programmer.md"),
I used `git worktree add --detach /tmp/x <parent-commit>` to run the same
test at the commit BEFORE my own work started. Identical failure, byte-for-
byte. That worktree check is cheap (no working-tree disruption) and is the
right way to distinguish "my diff broke this" from "this was already broken
and I'm just now the one who ran the suite." See
[[feedback_never_unconditional_stash_pop]] for the sibling lesson about not
touching shared state destructively in this repo - worktrees are the safe
alternative for read-only historical checks.

**A genuinely divergent per-port MECHANISM (not just a field name) needs a
function-injection extension to the entry-sources-core contract.**
stop-gate.sh's loop guard differs in KIND across ports: Claude's
`stop_hook_active` and Cursor's `.loop_count` are proactive (checked once
before the core is even sourced); Codex has no such field and self-tracks
consecutive blocks reactively inside its own exit points. A single shared
core can't express this with a variable - I had each entry define `block()`
and `allow()` shell functions BEFORE sourcing the core (trivial `exit
2`/`exit 0` wrappers for Claude/Cursor, the counter-file logic for Codex),
and the core calls `block "<msg>"`/`allow` instead of bare `exit`. This
extends gh410's "set vars then source" pattern to "set vars AND functions
then source" - reasonable per the unit's own escalation clause, but flag
this class of extension explicitly if it recurs, since gh410's cores never
needed it.

**Two acceptance-criteria numbers in gh411 were unreachable and I reported
rather than forced them:** (1) the adapter-tree line-count target (`<=1097`,
baseline 1995) assumes a reduction gh410's actual mechanism doesn't
provide - each core is copied byte-for-byte into BOTH adapter trees (a hard
requirement of the A10 md5sum check), so adapter volume can only grow as
shared logic grows; measured 2447. Pre-gh411 (post-gh410) was already 2252,
UP from the 1995 pre-gh410 baseline - gh410 itself never reduced this
metric either. (2) "7 top-level scripts per adapter" - only 6 of 14
`hooks/scripts/*.sh` have any adapter port at all, per the unit's own Do NOT
touch list; correct count is 6. Don't invent a 7th script to satisfy a
miscounted criterion.

**Retargeting a parity test's mutation controls after a core extraction:**
`sed`/`grep` mutation-control blocks that reference the entry script's own
text must retarget to `$mutant/lib/<name>-core.sh` (the extraction moves the
asserted text there) - grep the SAME string against the wrong file silently
returns 0 matches, and `before_n=0`/`after_n=0` still looks superficially
"consistent" in a naive check, so always assert `before_n=1` explicitly, not
just `before_n == after_n`. I found 3 MORE test files with this same
pattern (`tests/stop-gate-blocked.test.sh`, `tests/stop-gate-escalated.test.sh`)
that weren't named in gh411's own Affected files list - `grep -rl
"hooks/scripts/stop-gate.sh\|hooks/scripts/reviewer-route-gate.sh" tests/`
after any core extraction to find every test asserting exact text spans
against the now-thin entry script, not just the one the dispatch names.
