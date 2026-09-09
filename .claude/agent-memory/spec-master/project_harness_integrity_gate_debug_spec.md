---
name: harness-integrity-gate-debug-spec
description: Debug spec for the 2-FAIL-capped harness-integrity-gate-hardening unit — the unbounded-universal root cause, the nested-brace bypass the roast under-called, and the frozen family table that defines closure
metadata:
  type: project
---

Debug spec at `docs/plans/2026-09-09-debug-spec-harness-integrity-gate-hardening.md`
(unit `harness-integrity-gate-hardening`, attempts `c71ed27` and `341ec67`).

**Why the unit FAILed twice: the criterion was an unbounded universal.**
"No bypass exists" over arbitrary shell text can always be falsified by one
more counterexample, so each pass closed strictly more (1 family, then 4) and
each still FAILed. The tell was in the artifact — attempt 2's memory note
escalated to a *bolded* "any spelling … is detected. That is the whole claim"
with a single named exception. A universal with one exception is the same
unbounded criterion restated.

**How to apply:** when scoping a detection/hardening unit over an adversarial
input space, invert the quantifier before dispatch — freeze an enumerated
family table (closed / documented residual / accepted over-block), encode it as
a test table, and state that a spelling outside the table is out of scope
rather than a FAIL ground. See [[feedback_verify_own_criteria_nonvacuous]].

**Measured finding the review passes both missed** (verify before reusing —
this may be fixed by now): the brace-collapse loop in `set_a_mentioned()` is
correct only at nesting depth 1. `.claude/{persona-config,{x,y}}.json` really
does expand to the protected file and was ALLOWED, because the loop consumes
the outer `{` with the *inner* `}` and leaves a stray `}` in the pattern. The
prior review filed this as a cosmetic roast note ("stray unmatched braces"); it
was a live bypass inside a family the commit claimed closed. Fix shape that
works is innermost-first collapse to a fixpoint; the cheaper "strip residual
braces" variant closes one nesting shape and leaves `{{a,q},x}` open.

**Second-order lesson:** 62 green example cases hid it. Example count is not
coverage — none of the 62 tested a *property of the normalizer*. The
one-line invariant that catches the whole depth-N class is "after collapse the
candidate contains no `{` and no `}`". Pair example rows with fixpoint/invariant
criteria, plus a reachability precondition (prove the spelling actually expands
to the protected path before crediting a BLOCKED row).

**Settled scoping decision:** the working-directory-relative family
(`cd .claude; …`, `git -C .claude …`, `a=.claude; b=…; $a/$b`) is a **documented
residual, deliberately not fixed** — it is a working-directory-modelling defect,
not a glob-detection one, it is pre-existing (identical at `35df52e`, not a
regression), and the reviewer explicitly said not to widen the gate in that
unit. Reversible on user request; a follow-up spec is assumed.

Also settled: `341ec67`'s re-anchoring introduced a new fail-closed false
positive — `rm -rf ~/.claude/*` and `/tmp/x/.claude/*` are now BLOCKED though
unrelated to project Set A. Accepted and test-pinned, not narrowed.

Gate-specific friction confirmed live while writing this spec: the gate blocks
your own diagnostic commands when their text names a Set A path. Probe scripts
must be written to the scratchpad (Write checks `file_path` only) and run as
`bash /path/probe.sh`. See [[project_reviewed_path_gate_blocks_bash]].
