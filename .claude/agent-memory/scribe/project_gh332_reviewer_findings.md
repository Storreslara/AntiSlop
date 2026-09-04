---
name: gh332_reviewer_findings
description: gh332 unit non-blocking advisory notes — stale citations, criterion defect pattern, ubiquitous-language gaps
metadata:
  type: project
---

## PASS marker non-blocking notes from gh332 reviewer

**Three pre-existing stale CONTEXT.md path citations (separate from tracked #426/#427)**

The new ADR-0029 asserts "only living reference docs describe the current tree," but CONTEXT.md itself carries three untouched PRE-EXISTING stale path citations unrelated to this plan, confirmed at BASE commit d1f2399:
- `bin/human-review-cleanup.sh:187-196,209-212` (CONTEXT.md:1325 — comma-form line range defeats the `sed` cleanup)
- `docs/adr/0024` (CONTEXT.md:868 — bare ADR shorthand, not a full path)
- `docs/plans/2026-07-28-agent-identity-namespace-gate-fix.md` (CONTEXT.md:1000)

These are not the same as the already-tracked #426 (README.md:177 line-drift) or #427 (four stale tests/dashboard-* comments in bin/). Use judgment: if these three are genuinely new/uncaptured drift, consider filing one follow-up for them in the same pattern. If out of scope, log and defer. **Status:** flagged for potential future cleanup, not blocking.

---

## Spec-level criterion defect for task-master guidance

**Issue #332 criterion 5 is structurally unsatisfiable for ANY correct implementation**

The backtick-path resolution sweep in Step 6 criterion 5 combines:
1. Multi-file `grep -o` (which prefixes matches with `<filename>:`)
2. A sed that only strips trailing `:<digits>`, never a bare filename-prefix colon

This makes the criterion exit 1 whenever the reviewed files themselves appear in backticks (e.g., the ADR's own filename `docs/adr/0029-...:` matches the extractor but doesn't get stripped). **This is a defect in the issue's acceptance-criteria command, not the implementation.** Proven by mutation: repairing all three stale items still leaves exit=1 with only the artifact.

**Guidance for future multi-file resolution-sweep criteria:**
- Run the sweep per-file, OR
- Add `-h` to the first grep (suppress filename in output), OR
- Extend the sed to strip a bare trailing colon: `'s/:([0-9]+(-[0-9]+)?)?$//'` instead of `'s/:[0-9]+(-[0-9]+)?$//'`

---

## Ubiquitous-language suggestions (non-blocking)

Four new terms introduced in ADR-0029 lack CONTEXT.md headwords (not defects, just gaps):
- **canonical index** (5 uses in ADR, including Decision section)
- **tracked mirror** (2 uses)
- **adapter mirror** (2 uses)

The new **Microworld silo** entry is well-structured with appropriate cross-links and an `_Avoid_:` clause to retire "the dashboard directory."

---

## Scope deviations recorded by reviewer

1. **Dispatch A scope: two changelog entries instead of one.** Step 6 spec said "one new entry"; Dispatch A appended the gh332 entry plus a retroactive gh331/Step 4 entry that had been missing. The gh331 entry's claims match its `.pass` marker exactly, deletions remain 0, no criterion violated. **Recorded as minor scope deviation only.**

2. **ADR-0029 historical-path convention not stated.** Lines 10, 13, 47, 51, 58 write the retired path `bin/dashboard/` in italic rather than backticked (which keeps it out of the resolution sweep). Semantically defensible — it marks historical paths that must not resolve — but the ADR never documents the italic-means-historical convention, so a later editor might "fix" it to backticks and trip the criterion. **Recommendation:** add one sentence to the ADR's conventions section if this pattern is intended to recur.

---

## Heavy-surface override note

The hook-run (hooks/scripts/heavy-trigger.sh) reported `surface: heavy files: 20 lines: 184` over the unit commits, but 14 of those 20 files are one-line mechanical version stamps (no executable surface). The project's humanReviewMode is "off", so escalation is inert regardless. **Recorded for audit trail only.**
