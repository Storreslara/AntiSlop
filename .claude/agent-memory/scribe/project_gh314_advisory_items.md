---
name: gh314-advisory-items
description: Reviewer advisory findings from unit #314 (microworld bundles protocol section) - prose cleanup and future design question
metadata:
  type: project
---

**Unit #314 (microworld bundles) — two reviewer advisory items:**

1. **agents/reviewer.md:62 garbled clause** — "never an acceptance criterion and **never an acceptance criterion** for any criterion-bearing statement" contains a duplicated clause. The first occurrence should be deleted. Prose-only finding, not blocking; can be fixed in a future pass.

2. **Protocol section classification for criteria-authoring personas** — The new "Microworld bundles (format and the check contract)" section is currently classified as `drop` for `spec-master`, `task-master`, and `milestone-auditor` in `bin/cli.js`'s `PROTOCOL_SECTIONS_BY_PERSONA` matrix. The reviewer noted this is worth reconsidering in a future unit: since the section contains the "never an acceptance criterion" sentinel (G5), moving `spec-master` and `task-master` to `include` would ensure the sentinel reaches the two personas that actually author acceptance criteria. **Why:** The protocol section is normative guidance for how to construct acceptance criteria when criteria involve microworld bundles; personas that write such criteria should have direct access to this section. **How to apply:** In a future unit touching the protocol section matrix, evaluate whether to move spec-master and task-master from `drop` to `include` (orchestrator stays at `include` per its "carries all sections" architectural invariant; other personas' classifications unaffected).
