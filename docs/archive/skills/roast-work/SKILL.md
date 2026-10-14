---
name: roast-work
description: >
  Apply during review as a supplementary, advisory critique — never a
  PASS/FAIL gate. A detail-driven rubric for surfacing contradictions,
  missing parts, logic gaps, and security vulnerabilities beyond what the
  reviewer's materiality filter already catches, with feedback specific
  enough to act on.
---
This skill produces ONE advisory section, appended after the reviewer's
verdict line — it never determines PASS/FAIL. The acceptance-criteria
command plus the existing materiality filter (correctness / security /
unmet-acceptance-criteria) remains the only gate; this rubric only adds
detail on top of a verdict already reached.

Four critique lenses — work through all four, not just the first one that
turns something up:

1. CONTRADICTIONS — does any part of the change disagree with another part,
   with the plan/spec it claims to satisfy, or with a comment/docstring left
   in place? Cite both sides (file:line each), not just the symptom.
2. MISSING PARTS — for every case the acceptance criteria implies (error
   paths, empty/null inputs, concurrent callers, the "undo" of a new
   feature), check it was actually built, not just the happy path. A
   plausible-looking diff that only covers the happy path is the single most
   common thing this lens exists to catch.
3. LOGIC GAPS — off-by-one, wrong operator, inverted condition, a loop that
   can't terminate, a state transition with no path back, an assumption
   stated as fact. Trace the actual execution, don't pattern-match the shape
   of correct code.
4. SECURITY VULNERABILITIES — injection, authz/authn bypass, leaked secrets,
   unsafe deserialization/input handling, path traversal, SSRF, timing
   leaks. This can overlap with the reviewer's own FAIL-grounds check —
   overlap is fine, a finding stated twice is not a bug, unstated is.

Actionable feedback discipline: every entry names file:line, states what's
wrong in one sentence, and states what a fix would look like in one more —
no vague "consider improving X." If a lens turns up nothing, say so briefly
rather than omitting it silently, so a reader can tell the lens actually ran.

Output shape: a single, clearly-demarcated section (e.g. a `Roast:` or
`Advisory critique:` heading) appended AFTER the verdict line — never before
it, never interleaved with it. This section is additive detail, not a second
opinion: it must not restate or contradict the verdict, and none of its
entries are blocking defects, no matter how sharply worded.
