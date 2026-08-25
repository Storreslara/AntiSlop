---
name: branch-agreement-criterion
description: When a textual guard and a structural guard protect the same thing, assert the two AGREE rather than enumerating characters — the antidote to specs that keep missing one more dimension.
metadata:
  type: feedback
---

When one component guards a resource along two paths — a **textual** path (scan
the command string) and a **structural** path (resolve the actual target) —
write the acceptance criterion as **"the two paths return the same verdict for
the same input"**, not as an enumeration of inputs the textual path must catch.

**Why:** `human-decision-gate.sh`'s Bash path FAILed twice on the same function
(`hdg-prose-2`, 2-FAIL cap) and shipped a third fail-open after that. Each time
the spec defined the deny condition by naming a character dimension — first
"non-quote", then "non-whitespace", then "path-safe punctuation" — and each time
an unmodelled value of that dimension walked straight through. The gate's own
Write/Edit branch (`case "$subject" in .claude/human-review/*/DECISION`, applied
to a `normalize_path()`-resolved path) was an authoritative definition of the
protected set sitting in the same file the whole time, and nobody used it as the
oracle. Measured 2026-08-24: 630 disagreements over a 670-path corpus at HEAD,
0 under the fix. A criterion that names no characters cannot be defeated by a
character nobody thought of.

**How to apply:** look for a second enforcement path over the same resource —
a glob-matched normalized path, a parser, a DB constraint, a type-checked
schema. Make the suite assert *equality* of the two verdicts over a
cross-product corpus, and keep the enumerated cases as a floor, not the ceiling.
If the enumeration and the agreement criterion ever disagree, the enumeration is
wrong. Corollary: this also tells you when an "uncovered" shape is **correct** —
21 shapes like `.claude/human-review:/u 1/DECISION` looked like a gap until the
structural branch showed it allows them too, because that is a different
directory. A candidate fix that denied them was over-blocking, not stronger.

Related: [[verify-own-criteria-nonvacuous]], [[gate-early-exit-residuals-spec]].
