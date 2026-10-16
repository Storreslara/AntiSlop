---
name: ptr-u7a-completion
description: ptr-u7a PASS b21b3ee closed #561; gate denials now 3 lines; five OPEN follow-ups
metadata:
  type: project
---

ptr-u7a: PASS b21b3ee (marker 2026-10-16T07:12:35Z), closed #561. Reviewed-path and human-decision gate denials are 3 lines (BLOCKED, Remedy, More: glossary term). Glossary entries `reviewed-path denial` and `decision-gate denial` landed in ec351c5.

**OPEN follow-ups (not fixed):**
- templates/persona-protocol.md ~82-86 (copied into every persona) still says the gates "print their complete remediation"; they now only name the template and point to the glossary. Needs a unit with version bump + CHANGELOG rewording to "read the refusal text and the glossary entry its More: line names". Spec-master asked to fold into wave-7 cleanup U13c.
- Human-decision Remedy line dropped the main-session permission-prompt route; it lives only in the glossary (fine for agents).
- Criterion 8 md5 check strips BLOCKED/Remedy/More echo lines, so it is blind to edits on the untouched BLOCKED echoes (reviewed-path-gate.sh ~214, 280, 285); reviewer covered with a plain diff.
- New N22 pin also matches the old message; the denial_shape token loop is what proves the new text.
- Implementer skipped most skip-edit mutation proofs; reviewer ran them.

**Why:** carry-forward gaps a later unit must close. **How to apply:** check U13c scope before assuming the persona-protocol wording is fixed.
