---
name: reconcile-conflicting-rotation-contracts
description: when two shipped features each own log rotation with incompatible file formats, integrate by calling the OTHER's private reseal/rehash helper after your own transform, don't replace either contract
metadata:
  type: project
---

On gh415, `bin/human-review-cleanup.sh`'s pre-existing `rotate_log()` (tested:
`tests/human-review-cleanup.test.sh` asserts the fresh log's last line equals
the archived log's last line, for `stop-gate.sh`'s defer-dedup) and the new
`hooks/scripts/lib/audit-log.sh`'s `audit_rotate()` (tested:
`tests/audit-seal.test.sh` asserts the fresh log's first line is a
`rotated-from=... sha256=...` summary) have genuinely incompatible contracts
for what the post-rotation log's content should be. Neither test could be
changed without breaking a real, load-bearing consumer (stop-gate's dedup
reads the tail; the seal spec reads a summary line).

**Resolution: don't replace either rotate function — call the seal library's
"private" `_audit_reseal <log>` helper right after `rotate_log()`'s own
archive+tail-preserve logic, instead of swapping in `audit_rotate()`
wholesale.** `_audit_reseal` just rewrites `<log>.seal` to match whatever the
log currently contains; it doesn't care what content shape produced that
log. `rm -f "${log}.seal"` first (the old seal describes the archived
content, not the fresh file), then `_audit_reseal "$log"`. This is
"integrated with," not "replaced," per the spec's own stated latitude, and
it required zero changes to either existing test's assertions.

**Why:** don't assume a leading underscore means "do not call this from
another script" — in bash-sourced libraries here it typically means "not
part of the documented public API surface," which is compatible with
reusing it for exactly its stated purpose (resealing) from a second script
that already sources the library. Reusing it beat duplicating the
sha256sum/line-count math inline, and duplicating it would have violated the
dispatch's "don't re-derive the already-shipped contract" instruction.

**Watch for glob collisions the new sidecar introduces.** After adding a
`.seal` file next to the target, an existing test doing
`find "$dir" -name "target.*"` to detect "the archived copy" will now also
match `target.seal` non-deterministically (whichever `find` returns first).
Fix the glob (`! -name '*.seal'`), don't avoid creating the seal.

**How to apply:** whenever a new subsystem's rotation/backup mechanism must
coexist with an existing, differently-shaped one, look for the new
mechanism's most granular internal step (here: reseal, not rotate) and
splice just that step into the existing mechanism's own control flow, rather
than trying to make one call site serve both contracts.
