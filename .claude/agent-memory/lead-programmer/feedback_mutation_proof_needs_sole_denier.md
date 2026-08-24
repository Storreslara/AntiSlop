---
name: mutation-proof-needs-sole-denier
description: A guard's mutation-proof case must be one the guard ALONE denies; a case also caught by an allowlist or an earlier scan lets the mutant survive
metadata:
  type: feedback
---

When proving a new fail-closed branch is load-bearing (delete it, the case must
flip to allowed), pick a case where **that branch is the only thing denying it**.
A case that is also denied by a program allowlist, an earlier substring scan, or
an unbalanced-quote fallback will stay denied with the branch gone, and the
mutant survives — which looks like the proof failing when it is the *case* that
is wrong.

**Why:** on hdg-lexer-1 the spec's own binding cases for the `$'…'` guard were
`sh -c $'printf x > <path>'` — but `sh` is not in `program_allowed()`, so
deleting the guard changed nothing. The real binder had to start with an
allowlisted program: `printf $'a\'' ; printf x > <path>\'` (two quote chars,
one escaped, so bash and a naive lexer both balance but pair one position
apart). Same trap for the double-quote branch: a single `\"` leaves an odd
quote count, so the naive path fails closed on *unbalanced quotes* rather than
on the guard — it takes **two** escaped quotes to re-balance the count and
expose the masked `>`.

**How to apply:** before writing the mutant, ask "what else in this pipeline
would reject this input?" Then confirm with a differential: run the same text
through real bash in a throwaway sandbox and show it actually performs the
write. ALLOW + a real side effect is the kill; anything less is an argument.
Related: [[review_technique_mutate_to_prove_criterion]] (the reviewer-side
version of the same move).

**A NEW condition can silently un-bind an OLD one's proof.** On
hdg-prose-2-fix2 the added companion scan did its own quote-joining, so it
denied every case that used to bind the run scan's fragment joining: reverting
that older condition went from flipping 14 suite cases to flipping ZERO. The
older guard was still load-bearing (a case with a non-path-safe interstitial
still needs it) but nothing in the suite proved it any more. So after adding a
condition, re-run EVERY existing mutant, not just your own, and add a binder
back if one went vacuous — a mutation proof rots silently, with a green suite
the whole time.

**Measurement hygiene: never baseline a sweep on `HEAD`.** A differential
script doing `git show HEAD:<file>` re-baselines itself the moment you commit,
and then cheerfully reports a tiny diff because it is comparing your work
against itself. Pin the explicit pre-unit sha. Also widen the corpus along
combined dimensions: a sweep over "whitespace ids" and "punctuation ids"
separately misses ids holding BOTH, which was exactly the hole the spec's own
420-command sweep failed to surface.
