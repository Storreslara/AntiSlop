---
name: feedback-split-unit-across-persona-scopes
description: When a spec-master unit's affected files span two personas' write scopes (e.g. scribe-eligible ADR/CONTEXT.md plus non-scribe CHANGELOG.md/plugin.json), split into two dispatch prompts under one shared unit id/review rather than escalating a spec gap.
metadata:
  type: feedback
---

Observed 2026-08-11 (microworld-silo plan slicing, Step 6 -> issue #332). The
plan bundled `docs/adr/`, `CONTEXT.md`, `CHANGELOG.md`, `.claude/wiki/changelog.md`
and `.claude-plugin/plugin.json`/`package.json` into one step framed as "the
`scribe` unit." Checking `agents/scribe.md`'s actual write-scope line confirmed
`CHANGELOG.md` and `plugin.json` are outside it (only `.claude/wiki/`,
`CONTEXT.md`, `docs/adr/`, memory, tracker issue state) — see
[[feedback_scribe_write_scope]].

This is NOT automatically a spec gap requiring escalation back to spec-master.
Precedent already exists in this repo's own git history for exactly this
split: issue gh138's docs commit (`36a1cfb`, scribe content) was followed by a
separate version-bump commit (`81c197d`, "... (institutional knowledge)") —
same unit, two commits, implicitly two write-scope surfaces.

**How to apply:** when a single spec-master-defined step's affected-files list
crosses a persona's declared write-scope boundary, keep it as ONE unit
(matching spec-master's stated unit count) but author TWO dispatch prompts
under the shared `Unit: <task-id>` id — e.g. "Dispatch A — persona: scribe"
and "Dispatch B — persona: lead-programmer" — each with its own Affected
files / Ordered edits / Do-NOT-touch subset, sharing one combined Acceptance
criteria block run after both land. State the routing split and its
justification explicitly in the dispatch (cite the persona file's actual
write-scope line, not just "documentation vs code"). This is exactly what my
own role description anticipates: "for each sliced unit, write a dispatch
prompt for lead-programmer (and scribe, when the unit needs an
institutional-knowledge update)" — the mechanism already exists, just wasn't
obviously named for a two-way split before.

Reserve an actual spec-gap report for cases where the SAME acceptance
criterion cannot be satisfied by either persona alone (not observed here —
each half's criteria cleanly separated by file).
