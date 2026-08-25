---
name: technique-mask-comments-via-skeleton
description: How to mask only `#` comment bodies (leaving quoted spans intact) by reading command_skeleton()'s output instead of re-implementing bash comment semantics — plus the quote-split residual reviewed-path-gate.sh still carries
metadata:
  type: project
---

To mask ONLY comment bodies in a bash command while leaving quoted spans
intact, do NOT write a second comment scanner. Scan `command_skeleton()`'s
output for the two-character sequence `#X` and mask the maximal `X` run after
it, consuming the skeleton and the real command from the front in lockstep.

**Why it is sound:** in a skeleton, `X` appears only where a quoted body or a
comment body was masked, and a quoted body is *always* preceded by its own
quote character. So an `X` immediately after a literal `#` can only be a
comment body. The one other way `#X` occurs is a non-comment `#` followed by a
literal `X` in the command, where copying `X` over `X` is the identity. Any
protected token that contains no `X` therefore cannot be partially erased.

Two traps that bite:
- `masked="$(mask …)"` strips TRAILING newlines, so the skeleton can be
  SHORTER than the command. Lockstep front-consumption plus appending the
  command's remainder raw keeps the offsets aligned; index arithmetic against
  `${#skel}` does not.
- The maximal-`X`-run trim (`run="${run%%[!X]*}"`) is what makes the comment
  end at its newline. Deleting that one line is a real fail-open (a mask
  running to end-of-string hides a second line's write entirely).

**How to apply:** any gate that wants "a mention bash discards is not my
business". Prove zero marginal capability the same way — if every occurrence
is inside a comment body, the comment-stripped command behaves identically and
no longer spells the path, so the gate's own substring early-exit already
allowed it.

**CLOSED 2026-08-24 by rpg-canon-2** (was: the gate failed open on the
quote-split spelling). `mentions_marker_dir()` now unions raw / quote-joined /
per-word-normalized text at BOTH copies of the literal. What still fails open
there, measured with real writes: backslash escapes inside the path, `$'...'`
quoting, glob metacharacters, shell-variable splitting and a `cd`-relative
write — all pinned as case 38 residuals now, so they are ratified rather than
silent.

See [[feedback_bash_word_assembly_in_gates]] for the joining rule this residual
is the other half of, and [[feedback_mutation_proof_needs_sole_denier]] for
picking cases where the new guard is the ONLY denier.
