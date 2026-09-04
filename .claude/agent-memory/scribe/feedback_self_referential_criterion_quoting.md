---
name: feedback-self-referential-criterion-quoting
description: Quoting a "must not contain X" grep pattern verbatim inside the artifact it checks reintroduces X and self-poisons the check — happened editing tracker issue #354's CRIT-5F table
metadata:
  type: feedback
---

When a dispatch says to copy acceptance-criteria tables "verbatim" into an
artifact, and one of those criteria checks that same artifact for the
**absence** of a literal phrase, copying the criterion's own grep pattern into
the artifact reintroduces the forbidden phrase and makes the criterion fail
against itself. Not hypothetical: dispatched to bring GitHub issue #354's
title/body in line with `docs/plans/2026-08-13-dashboard-decision-approval-surface.md`
Addendum A.6, I was told to append CRIT-5F verbatim into the issue body.
CRIT-5F's own rows check `B | grep -c 'vacuous as shipped'` == 0 (and two
similar rows) where `B` is the issue body — copying that row's pattern into
`B` made `B` contain "vacuous as shipped", so the row it defines failed
against the very body carrying it. CRIT-5C had the same trap in one row
(quoting a "must be 0 in the plan file" pattern that also happens to be one of
CRIT-5F's banned body phrases).

**Why:** the plan's own `nb()` normalizer strips blockquote lines specifically
so a *plan document* can quote retracted wording without tripping its own
negative check (this repo's dated-correction convention). A raw
`gh issue view --json body` has no such blockquote-stripping — there is no
sanctioned way to quote the literal banned phrase inside the issue body and
still pass. "Verbatim" in a dispatch instruction is a good-faith default, not
an absolute when it collides with the literal correctness check the same
dispatch requires.

**How to apply:** before pasting any acceptance-criteria table into the exact
artifact that table inspects, check whether any row's search pattern is also
one of that artifact's own forbidden substrings. If so, break the contiguous
match with an inserted marker (e.g. `'vacuous […] as shipped'`) and add one
line explaining why the pattern is broken and where the literal pattern
actually lives (e.g. "see Addendum A.6") — preserves the row's meaning for a
human reader without reintroducing the poison string. Re-run every negative
check against the final artifact state before reporting done; don't trust
that "I copied it verbatim" implies "the checks pass" — verify after, not
just during composition. Related: [[project_gh354_dispatchA_completion]],
[[gh354_fail_fix_completion]].
