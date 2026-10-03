---
name: technique-locale-fix-keeps-prior-mutant-live
description: When closing a [[:space:]] Unicode hole, `local LC_ALL=C` beats rewriting to [ \t] if a prior unit's guard and mutation criterion must stay load-bearing; also the scratchpad is shared across concurrent agents
metadata:
  type: feedback
---

Closing a `[[:space:]]` Unicode-space hole (esf-hardening-3, is_sanctioned_marker_write): pick `local LC_ALL=C` over rewriting separators to `[ \t]`.

**Why:** `[ \t]` would also refuse `\v\f\r`, turning the earlier `# MARKER-WS` guard into dead code, so esf-gate-bytes' own criterion (MARKER-WS tag present once, its deletion mutant flips PG22) would silently stop holding. The C locale fixes only the Unicode half and leaves the old guard load-bearing; both mutants then flip disjoint case sets (12 PG23 vs 6 PG22).

**How to apply:** before choosing between two equivalent fixes, grep docs/plans for the prior unit's tags/mutants on the same lines and pick the one that keeps them killable. Spell test bytes as `$'\xe3\x80\x80'` (not `\u`, which depends on the test's locale and which Edit/Write rewrite to literal chars), and label cases with `od -An -tx1` hex.

Also: the session scratchpad dir is SHARED with concurrent agents (another unit's worktree sat at `scratchpad/wt`, and a scratch script of mine was touched on disk). Use `mktemp -d -p <scratchpad> <unit>-wt.XXXX` for worktrees and never remove worktrees you did not create. Related: [[technique-bash-glob-bytewise-fallback-locale]], [[technique-edit-tool-unicode-escape-and-placeholder-re]].
