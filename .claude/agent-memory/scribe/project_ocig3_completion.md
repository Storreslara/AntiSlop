---
name: ocig-3-completion
description: PASS 2026-10-05; external run journal glossary alias + external workflow runner term; six non-blocking gaps recorded
metadata:
  type: project
---

**Verdict**: PASS ocig-3 (reviewer, 2026-10-05)

**Commit range**: c7a6388..efeaed7 (9 commits including prototype and versioned release)

**Summary**: Unit ocig-3 completed the external run journal feature trial (OutcomeCI Design A). Commit A introduced a formatter (`journal-evidence.sh`) that presents a workflow runner's per-call record to reviewers as non-authoritative evidence. Commit B integrated it into the persona system (orchestrator.md and reviewer.md) and bumped version 0.31.121. Reviewer verified all criteria AC3.1–AC3.5 and AC3b.1–AC3b.8 and confirmed the stamp footprint matches prior releases (no `--update` drift).

**Glossary updates made**:
- Added "external run journal" as an alias/synonym linking to "broker journal"
- Added "external workflow runner" as a new glossary entry (distinct concept: the actor producing the journal)

**Non-blocking gaps recorded**:

1. **Escaping in crafted fields** (prototype only): The formatter copies `step`, `capability`, `status`, and `decision` verbatim without escaping `|` or newlines. A crafted journal field could add lines to the reviewer dispatch. Prototype-only and operator-written inputs (banner marks the block non-authoritative), but warrants future hardening.

2. **Zero-byte and missing-key error handling**: A 0-byte `journal.json` prints "integer expression expected" error. A journal file with no `.calls` key is reported as "journal absent" — both cases lack explicit user-facing error messages.

3. **Persona phrasing inconsistency** (orchestrator vs. reviewer): `agents/orchestrator.md:177` says the reviewer "checks against the journal file itself", while `agents/reviewer.md:89-90` says "may re-read". Both should say "may" (permission, not obligation). Would require a stamped-persona edit, version bump, and CHANGELOG entry. **CLOSED by ocigf-2**: orchestrator.md now aligns with reviewer.md, both say "may check against the journal file and its stated sha256" (evidence-only optional re-read); version 0.31.122.

4. **AC3.4 scope ambiguity**: The spec wording "this unit's range" should be explicitly scoped to commit A (the prototype formatter), not the full range including Commit B.

5. **Ubiquitous-language reconciliation** (gap closed by glossary updates): Persona text "external run journal" and "external workflow runner's per-call record" are synonyms/aspects of the glossary's "broker journal". Glossary now captures both the concept (broker journal) and the terminology (external run journal as alias, external workflow runner as distinct agent term).

6. **`git add -A` due to integrity gate**: Commit B staged 19 paths with `git add -A` because the gate blocked explicit-path staging of one config file. Reviewed by reviewer as NOTE (not FAIL) — all expected paths staged, no unintended files included.

**Advisory notes**:
- Version bump and CHANGELOG entry recorded as complete (revision 0.31.121, plugin.json, package.json, regenerated stamped-file copies)
- Reviewer confirmed footprint of `node bin/cli.js --update` matches prior release d5b7510 (edited personas only + one-line stamp on every other stamped file + config hashes)
