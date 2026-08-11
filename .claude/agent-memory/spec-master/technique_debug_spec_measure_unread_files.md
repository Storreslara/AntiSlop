---
name: technique-debug-spec-measure-unread-files
description: In a debug spec, measure from the transcript store whether the authoring round ever opened the file it made claims about — don't infer the root cause
metadata:
  type: feedback
---

When diagnosing a 2-FAIL-cap escalation over a **prose/documentation** unit,
count tool calls naming the file the false claim is *about*, per round, from
the on-disk transcript store — build round, fix round, and each review round
separately. See [[reference_claude_transcript_store]] for the path;
subagent transcripts live under
`~/.claude/projects/<slug>/<session-id>/subagents/*.jsonl`, and each one's
first user message identifies its role.

**Why:** on gh323 this converted a vague "the agent was careless" root cause
into a measurement: the `scribe` build round and the `scribe` fix round each
made **zero** tool calls naming `bin/dashboard/index.html`, while review
round 1 made exactly one, scoped to a different claim — which is why the same
paragraph was wrong twice about the same file. That table is the strongest
evidence in the artifact, and it also produced the specific corrective
instruction ("read this file first-hand before writing the clause") that a
generic diagnosis could never have produced.

**How to apply:** run it whenever the FAIL is a *false claim about component
X* rather than a broken command. If the authoring rounds never opened X, the
root cause is a **retrieval gap**, not a reasoning-capacity gap — which is
also the strongest available argument for a disclosed deviation from
"sonnet FAIL escalates to opus" (see the gh138 and gh323 debug specs, both of
which recommended sonnet on this ground). Watch specifically for
**quantifier-scope errors**: a fix pass that correctly repairs component A's
facts and then extends them into a whole-system negative ("nothing ...
throughout") about component B it never read. Pair the finding with a
criterion that pins a `file:line` anchor from B, so the prose has to cite its
own evidence — see
[[feedback_docs_units_need_claim_anchored_criteria]].
