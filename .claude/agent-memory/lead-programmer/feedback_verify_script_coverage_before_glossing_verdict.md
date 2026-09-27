---
name: verify-script-coverage-before-glossing-verdict
description: When writing persona prose that glosses a script's verdict/output, grep the script itself for the sub-behavior you're about to claim it covers — don't infer coverage from the verdict's name or the surrounding glossary term
metadata:
  type: feedback
---

FAILed item17-3-wire-p3-check on first pass: the bullets I added to
`agents/lead-programmer.md`/`agents/scribe.md` said `ok` (from
`version-stamp-check.sh`) "clears **version-stamp discipline**" — but that
glossary term is explicitly defined (`CONTEXT.md:128-133`) as version-bump
**and** CHANGELOG entry, while the script (`grep -c CHANGELOG` on it → 0)
only ever checks the bump. `CONTEXT.md:147-148` already said this plainly
("Mechanization covers the version-bump half... the CHANGELOG-entry half
remains reviewer-inspection-only") — I had read that exact line while
drafting and still wrote the overstated gloss, because I matched the
verdict name to the term's *label* rather than checking the script's actual
logic against the term's *definition*.

**Why:** a script's verdict vocabulary (`ok`/`violation`/`unknown`) is not
self-describing about scope. Naming a glossary term in prose implicitly
claims the full definition of that term, even if the sentence only meant
part of it.

**How to apply:** before writing "this check clears/verifies/enforces
<glossary term>" in any persona instruction, grep the script for the
sub-behaviors the term's own definition lists (here: `grep -c CHANGELOG
<script>`), not just for the term's name. If the script only covers a
subset, say so explicitly in the same sentence — don't let the reader infer
full coverage from a `ok` that name-drops the full term. [[project_g1_bump_invalidates_mirrors]]
is the mechanical sibling of this mistake-class (verifying the *mechanism*
against memory instead of the live file); this one is about verifying a
*prose claim* against the artifact it describes.
