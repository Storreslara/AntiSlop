---
name: ocigf-2-completion
description: PASS 2026-10-05; orchestrator/reviewer "may" wording phrasing closed; version 0.31.122 stamped-file regeneration; three non-blocking gaps noted
metadata:
  type: project
---

**Verdict**: PASS ocigf-2 (reviewer, 2026-10-05)

**Commit range**: ce73a28..712b23b (1 commit, scribe stamped-persona update)

**Summary**: Unit ocigf-2 closed an open-inconsistency from ocig-3 regarding the orchestrator and reviewer persona phrasing around journal re-reading. The orchestrator.md:177 previously said "checks against the journal file itself" (obligation), while reviewer.md:89-90 said "may re-read" (permission). Updated orchestrator.md to align with reviewer.md: both now say "may check against the journal file and its stated sha256" (optional evidence-only re-read), matching the design intent that journal re-read is optional verification, not required. Version bumped to 0.31.122 in both agents/orchestrator.md and agents/reviewer.md frontmatter. Regenerated all stamped-file copies via `node bin/cli.js --update` (one-line version stamps + config hashes matching prior release footprint d5b7510/efeaed7).

**Glossary updates made**:
- None (no new terminology introduced)

**Non-blocking gaps recorded**:

1. **No validate.sh suite pins orchestrator/reviewer journal "may" wording**: The spec's Step 2 CHANGELOG wording and AC-2.6 phrase count currently rely on manual review of prose. A flattened-grep parity check near tests/validate.sh ~L1147 would mechanize the "may" keyword presence in both persona files and close this gap for future releases.

2. **Spec's Step 2 CHANGELOG wording contradicts AC-2.6 phrase count**: The CHANGELOG entry uses a paraphrased summary ("re-read is optional; correct 0.31.121 overclaim") but AC-2.6 requires preservation of evidence as-stated. The paraphrase is accepted by reviewer (AC-2.6 allows brief distillation), but future steps should clarify whether CHANGELOG distillation is in scope for AC-2.6 parity checks.

3. **Heavy-surface reading from mechanical --update regeneration**: The `node bin/cli.js --update` step regenerates all stamped-file copies (one-line stamps, config hashes) which produces shallow per-file diffs (line 1 of each agent file changed). This makes manual review of the stamped changes laborious; no content substantive changes, but footprint verification requires checking the hashes match prior release. Noted for future stamped-file tooling enhancements.

**Advisory notes**:
- Version bump and CHANGELOG entry recorded as complete (revision 0.31.122, agents/orchestrator.md + agents/reviewer.md frontmatter, regenerated stamped-file copies via `node bin/cli.js --update`)
- Reviewer confirmed footprint of regenerated stamped files matches prior release d5b7510/efeaed7 (one-line version stamp on every stamped file + config hash updates)
- This unit resolves the ocig-3 gap #3: [[project_ocig3_completion#gap3]]
