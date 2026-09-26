---
name: item04-protocol-matrix-trimming
description: item04 protocol-matrix-trimming plan (docs/plans/2026-09-25-item04-protocol-matrix-trimming.md) — all 3 units done; domain-vs-harness glossary placement call for "protocol tier"
metadata:
  type: project
---

All 3 units of `docs/plans/2026-09-25-item04-protocol-matrix-trimming.md`
are done: item04-1 (measure), item04-2 (apply drops to
`PROTOCOL_SECTIONS_BY_PERSONA`), item04-3 (glossary entry, landed
`3f73f8c`, this unit).

**item04-3 placement decision:** the dispatch packet's own pre-resolved
context said "if item 3 has landed, this is harness-glossary content" —
but I placed the new "Protocol tier" entry in `CONTEXT.md` (domain
glossary) instead, for consistency with the existing sibling entry
"Protocol excerpt" (already domain, already implementation-heavy —
`PROTOCOL_SECTIONS_BY_PERSONA`, `bin/cli.js` line refs, `gatedAgents`
force-include). Applying item03's own rule ("domain = a concept a plugin
user would meet; harness = requires knowing this repo's own
implementation") — which personas get how much shared protocol text is
user-meetable (different agent-file sizes), not gate/marker/dispatch
plumbing. Splitting two closely cross-referenced sibling entries across
files would have been the worse outcome. If a future spec revisits this,
don't treat the packet's own guess as binding — it's a default, not a
verified classification; verify against precedent.

**Current tier facts** (measured 2026-09-26, post item04-2): full tier =
`templates/persona-protocol.md` (685 lines, 19 sections) →
`orchestrator`, `lead-programmer`, `reviewer`, `spec-master`,
`task-master`, `milestone-auditor`. Slim tier =
`templates/persona-protocol-slim.md` (90 lines, 7 sections) →
`SLIM_TIER_PERSONAS` in `bin/cli.js` = `explorer`, `researcher`, `scribe`,
`agent-auditor` (the wiki page `.claude/wiki/protocol-delivery-tiers.md`
is stale here — it lists only explorer/researcher/scribe, missing
agent-auditor; out of scope for this unit, not fixed).
