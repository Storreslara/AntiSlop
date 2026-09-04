---
name: gh295_2_note_classification_feature
description: gh295-2 landed non-blocking note classification and sweep duty; five technical gaps flagged for future maintenance
metadata:
  type: project
---

## What gh295-2 shipped

Unit gh295-2 (commit `82139aa`) formalized the reviewer's duty to classify non-blocking notes written on PASS markers with `NOTE[spec]:` or `NOTE[code]:` tags (bare, unemphasized, at column 0), and widened spec-master's fail-record-screening duty to sweep these tagged notes via `bin/marker-audit.sh . --notes --surface=<path>` before writing follow-up specs.

**Classification rule (in reviewer.md:139-145):**
- `NOTE[spec]`: divergence between shipped code and plan/spec/doc, undocumented load-bearing input, or warning for undispatcher steps
- `NOTE[code]`: everything else (robustness, style, edge case handling)
- **Format:** tag at column 0, no emphasis; indented lines are continuations, not new notes

**Worked example added (reviewer.md:152-158):**
```
NOTE[spec]: the plan doc doesn't document the new --tag flag's default value
NOTE[code]: consider extracting the repeated sed pattern into a helper
  this also affects the loose-anchor fallback path
```

**spec-master duty (spec-master.md:103-111):** Run `marker-audit.sh . --notes --surface=<path>` per touched file/dir before follow-up specs; sweep is best-effort (gitignored state, no recovery source).

**Test coverage:** AC2.1 (branch-agreement: three literals occur in both marker-verify.sh and reviewer.md) and AC2.7 (worked example extraction and parsing) added to tests/marker-verify.test.sh.

## Five non-blocking gaps flagged by reviewer

**Gap 1 (blocker for escalated markers):** `bin/marker-audit.sh` only globs `*.pass` (:79) — notes appended to `.escalated` marker bodies (which reviewer.md's ESCALATE route explicitly asks for) never reach spec-master's sweep. Consistent with R7's stated boundary but asymmetric in practice.

**Gap 2 (ordering ambiguity):** No specified ordering between `human: approved by ...` attestation line and `Non-blocking notes:` anchor in reviewer.md. If attestation comes first, it's classified as untagged note by the parser, inflating the `untagged` count spec-master is told to treat as required input. Pre-existing interaction, out of this unit's scope (R7), but needs documenting in Step 3.

**Gap 3 (prose/parser divergence):** reviewer.md:147-150 says "indented = continuation", but shipped parser (marker-verify.sh:106-115) starts a NEW note when indented line carries a NOTE tag. Unreachable for conforming reviewer (clause forbids indented tags), and prose is Addendum A.4.1 verbatim (the plan's own text). Flagged for Step 3 glossary entry to state the parser's actual rule.

**Gap 4 (AC2.7 fragility):** tests/marker-verify.test.sh AC2.7's awk extractor keys on first line matching `^[[:space:]]*Worked example:[[:space:]]*$`. Today exactly one exists in reviewer.md (:152), unambiguous. Future edit adding earlier "Worked example:" would silently extract wrong block. Needs NR guard or enclosing-bullet anchor.

**Gap 5 (AC2.1 asymmetry):** check_literal_pair's ERE tolerates optional backslash before brackets in BOTH files, so escaped form on reviewer.md side still passes. Tolerance genuinely needed in script (case patterns), but one-sided in intent — tighter to assert bare form on persona file, escaped form on script.

## Deliberate scope decisions (not gaps)

- **Adapter parity NOT required:** Cursor and Codex adapter ports do not carry the note-writing duty. This was already deliberate (no parity probe matches it), not oversight; no action needed unless plan is later revised.

## Glossary entries — routed to gh295-3

CONTEXT.md has no entries for "non-blocking note", "NOTE[spec]", "NOTE[code]", "emphasis wrapper", or the note sweep. Already flagged for Step 3's glossary deliverable (per Addendum A.4's "Step 3 pickup" paragraph); this is confirmation via ubiquitous-language Lens check.

## Related

- gh295 plan: `docs/plans/2026-09-01-advisory-note-channel-gh295.md`
- PASS marker: `.claude/reviewed/gh295-2.pass`
- gh295-1 memory: [[gh295_state_access_sh_trap]], [[gh295_surface_term_ambiguity_for_step3]]
- Upcoming: gh295-3 (glossary + omnibus minor fixes)
