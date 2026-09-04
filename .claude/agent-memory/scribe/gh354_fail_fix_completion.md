---
name: gh354-fail-fix-completion
description: gh354 FAIL fix — corrected decision surface "never writes" claim, ADR-0030 red regression criterion, plus a third false "gitignored" claim found by self-verification
metadata:
  type: project
---

Unit gh354 FAIL-fix (commit `cf82521`, 2026-09-04) corrected the scribe half of
a FAIL against prior commit `ea021c1`. Two dispatched defects, plus one I found
by verifying rather than trusting the report.

**Why:** the source plan's compose-only premise was stale — see
[[verify-plan-premise-freshness]] for the general lesson.

**How to apply:**

- The Microworld dashboard's DECISION-file trust anchor is the
  **terminal-delivered confirmation code** (`crypto.timingSafeEqual`,
  `server.js:~480-500`, single-use, 120s arm), *not* an absent write path.
  Never restate the dashboard as "never writes". Three touchpoints are
  compose-only; `ESCALATE-TO-HUMAN` resolution is not.
- Two guards, two distinct paths: `human-decision-gate.sh`
  (`hooks/scripts/human-decision-gate.sh`, not `.claude/hooks/`) blocks every
  *agent identity* from writing DECISION via a tool call; the dashboard server
  is neither an agent identity nor a tool call, so the hook does not cover it —
  the confirmation code does. Stating that the hook's inference "rests on" the
  confirmation code would have been a new false claim; I caught and reworded it.
- Third defect, not in the dispatch: both docs claimed the milestone findings
  record "is gitignored". `.claude/milestone-audit/` has **no** `.gitignore`
  entry (`git check-ignore` does not match). Recorded as intended-but-unenforced
  in both files rather than editing `.gitignore` — that file is outside scribe's
  write scope, and lead-programmer was editing README.md in parallel, so
  widening my file set risked a scope violation.
- Open follow-ups left explicit in ADR-0030: add the `.gitignore` line for
  `.claude/milestone-audit/`, and add an enforcement check for the cleanup duty.
  Neither is delivered.
- ADR-0030 keeps its original filename slug but the H1 and a dated "Corrected"
  note now reflect the narrowed claim. The `Write`-less milestone-auditor
  write-duty precedent (citing ADR-0015/0016) was sound and was left intact.
