---
name: fail-triage
description: >
  Apply during spec-master's debug spec on 2-FAIL-cap escalation, to add a
  verify-then-categorize front-half before diagnosing the plan. Scoped to
  this one post-FAIL path only — not a general issue/PR triage workflow.
---
Derived from mattpocock/skills `triage`, scoped to this project's post-FAIL
path: `triage` moves issues and PRs through a maintainer-facing role
workflow; `fail-triage` narrows that idea to the one moment it actually
applies here — the front-half of spec-master's debug spec, immediately
after the 2-FAIL cap escalates a unit.

Three steps, run in order:

1. VERIFY — re-run the failing unit's acceptance-criteria command fresh;
   don't just read the `.fail` record's text. Debug spec already reads that
   record (the single latest one at `.claude/reviewed/<task-id>.fail` — a
   second FAIL overwrites the first, there is no append/rotation
   mechanism) together with `git log`/`git diff` over the unit's fix-attempt
   commits. This step adds a live reproduction on top of that: report
   confirmed (with the failing command and its output) or could-not-
   reproduce.
2. CATEGORIZE the root cause into this project's two actual routes — no
   others exist:
   - **code defect** — the acceptance criterion is right, the code is
     wrong. This is the normal FAIL route: back to `lead-programmer`,
     unchanged by this skill.
   - **spec/criterion defect** — the acceptance criterion is ambiguous,
     unverifiable, wrong, or reveals a plan gap. This is spec-master's
     debug-spec revised-criteria path.
3. BRIEF — feed the verification result and category into spec-master's
   EXISTING debug-spec output (root-cause/diagnosis plus revised spec
   step(s), reasoned through the taxonomy/constitution/self-check machinery
   already defined for debug specs). Do not invent a second brief format.

`fail-triage` never re-grills the user — spec-master already grilled during
original authoring — and never edits code. It carries none of the upstream
skill's maintainer-facing issue/PR workflow, its label roles, its
external-PR request surface, its pair of chained upstream skills for
sharpening a raw request into a spec, or its companion reference documents
for durable briefs and rejected-request tracking.
