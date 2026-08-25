---
name: hot-path-predicate-costs-a-fork
description: A per-word `$(helper …)` inside a PreToolUse gate predicate that runs BEFORE the early-exit costs one fork per word on every tool call — prefilter it with a condition you can prove exact, and measure old-vs-new rather than trusting the spec's number
metadata:
  type: feedback
---

Any predicate a gate evaluates **before** its early-exit runs on every single
tool call in the session. If that predicate calls a shell helper per word via
`$(helper "$word")`, each call is a fork (~1.4 ms), so a long command is
seconds, not milliseconds.

**Why:** on rpg-canon-2 the spec had measured "129 ms at 3000 `.claude`-bearing
words" and told me not to re-derive it. Measuring anyway: **3.3 s**, because
the per-word `$(normalize_path …)` forks and the front-consuming word loop
(`rest="${rest:${#chunk}+1}"`) is O(n²) on top. A pre-resolved-context number
is a claim about a prototype, not about the code you actually wrote — the
"don't re-derive" instruction covers *design decisions already settled by
measurement*, not the properties of your own diff.

**How to apply:** prefilter with a condition you can prove is **exact**, i.e.
that skipping can change no verdict, not merely that it "usually" holds. The
exactness argument is what makes it a refinement rather than a semantics
change. Here: a word can only normalize into `A/B` if it already holds both
`A` and `B`, in that order, because `normalize_path()` copies segments verbatim
and only drops `.`/empty ones or pops on `..`, and the `/` between them is a
segment boundary. That took the hot path to 12 ms while the union's verdicts
stayed byte-identical (whole 458-assertion suite, plus an old-vs-new sweep).

**Accept the residual cost rather than capping it.** A crafted command whose
words all hold both tokens non-contiguously still costs 4.6 s. A cap can only
be paid for by failing open (a bypass) or by denying a long read (a false
positive of exactly the kind the gate exists to avoid), and the slow path
buys the attacker nothing — the command is still judged. Document the number
in the function's own header instead.

Related: [[feedback_mutation_proof_needs_sole_denier]] (the other half of
"measure it yourself"), [[technique_mask_comments_via_skeleton]].

**The differential that finds this class of bug: a spelling-consistency
oracle.** Don't diff old-verdict vs new-verdict alone — that only shows what
changed. Compare the NEW gate's verdict on an obfuscated spelling against the
OLD gate's verdict on the PLAIN spelling of the same template. It names no
characters, so an unmodelled spelling cannot make it pass vacuously, and it
catches over-blocks and fail-opens in one sweep (444 pairs, 6 disagreements,
all in the safe direction). Pair it with the usual anti-vacuity counter that
the oracle corpus spans both verdicts.
