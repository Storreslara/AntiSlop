---
id: explorer-routing
title: Structural questions go to the explorer
applies_to: [lead-programmer, planner, reviewer, repo-historian, orchestrator]
---
Any question about where something is defined, what calls it, blast radius of
a change, inheritance chains, or test coverage: spawn `explorer`, don't invoke
the code-review-graph skill directly. Note this is instruction-enforced for
most personas, not mechanically blocked: `Skill` is in their `tools:` list so
a teammate copy can reach its OWN preloaded skills (which don't apply to
teammates otherwise) — that same tool would technically let them invoke
code-review-graph too. Only the orchestrator has no `Skill` tool at all,
making its isolation mechanical; everyone else's is this rule. If the
explorer reports the graph index is missing or stale, treat its answer as
grep-derived, not authoritative.
