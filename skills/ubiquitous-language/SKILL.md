---
name: ubiquitous-language
description: >
  Detect terminology drift against a canonical glossary — three lenses, two
  input modes. Flagging (a) a glossary term used with a different meaning,
  (b) a new synonym for an already-defined term, (c) a load-bearing new
  domain term with no glossary entry. Advisory only; never gates.
---

## Shared drift core

This skill examines terminology against the canonical glossary at
`CONTEXT.md` using three lenses, applied identically in both modes below.
Read the glossary once per session and reuse it across both check points.

**Degradation (no glossary):** if no `CONTEXT.md` exists, emit a single line
saying the glossary is absent and that `scribe` (if present) can seed one —
then stop. Not a finding, not an error.

The three lenses:

1. **A glossary term used with a different meaning.** A word the glossary
   defines is used in the input with a different meaning. Name both the term
   and the canonical definition, then state the divergent meaning you found.

2. **A new synonym for an already-defined term.** The input introduces a new
   way to say something already defined in the glossary. Name the canonical
   term, state the new synonym, and note that both refer to the same thing.

3. **A load-bearing new domain term with no glossary entry.** The input
   introduces a new concept the glossary does not define. Report it as a
   suggestion for `scribe` (if present) to consider adding to `CONTEXT.md`.

If a lens turns up nothing, say so briefly rather than omitting it, so a
reader can tell it ran.

## Diff mode

**Input:** a diff (file changes).

**Consumer:** `reviewer`.

**Output:** ONE clearly-demarcated advisory section, appended AFTER the
verdict line. Never flips PASS/FAIL, never adds a FAIL ground, never
substitutes for running the acceptance-criteria command. Findings append to
the `.pass` marker with the reviewer's other non-blocking notes.

**Anchor:** findings name `file:line`.

Work through all three lenses systematically, checking identifiers, type/module
names, comments, and docs introduced or renamed by the diff against the
glossary. Every finding names `file:line`, states the drift in one sentence,
and states the canonical term in one more.

## Prose mode

**Input:** a natural-language request or a draft spec.

**Consumer:** `spec-master`.

**Output:** advisory only. Findings inform the category-8 score but never
block progression to `grill-me`, `to-spec`, or `task-master` handoff. No new
gate, no new hook.

**Anchor:** findings anchor on a quoted span from the input or the plan's own
step/heading number (e.g., "Step 3" or "## Context").

Apply the same three lenses to the prose, looking for terminology that
diverges from the glossary, overlaps with defined terms, or introduces new
domain concepts worth recording. State the drift, name the canonical term
(or suggest one for `scribe` if the term is new), and cite the anchor (span
or step number).
