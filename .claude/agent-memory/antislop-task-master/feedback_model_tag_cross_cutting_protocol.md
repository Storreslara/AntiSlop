---
name: model-tag-cross-cutting-protocol-units
description: In this repo, units that touch templates/persona-protocol.md + both adapter ports + regenerated .claude/agents copies get opus; isolated single-surface doc units get sonnet
metadata:
  type: feedback
---

When tagging a sliced unit's `Suggested model:` (implementer tag, per
`agents/task-master.md`'s reactive-tagging rule — haiku is default unless a
prior `.claude/reviewed/<id>.fail` exists), this repo's established pattern
for judgment calls between `sonnet` and `opus` (once a blanket
not-haiku-eligible ruling like R7 already applies) is:

- **opus** — the unit extends or adds a section in
  `templates/persona-protocol.md`, requiring hand-ports into both
  `adapters/cursor/rules/persona-protocol.mdc` and
  `adapters/codex/agents-md-fragment.md`, and propagates through
  `bin/cli.js --update` to the six full-protocol `.claude/agents/*.md`
  copies. Confirmed on `docs/plans/2026-07-28-…microworlds…` Steps 2–7
  (#130, #131, #132, #133, #134, #135, #136) and reused for that same plan's
  Convergence follow-ups Steps 9–11 (#298, #299, #300) — all of which extend
  existing protocol sections rather than adding new ones, but still carry the
  same cross-persona blast radius plus fixed prose shapes gated by multiple
  exact-string/heading greps.
- **sonnet** — the unit is scoped to one surface type: a single advisory
  skill (#129, Step 1), a single product doc (#137, README-only, Step 8a),
  or a single scribe-owned artifact set (#138, `CONTEXT.md` + ADRs, Step 8b).

**Why:** the user has not overridden this pattern; it's inferred by matching
each new unit's affected-files shape against the base plan's own tagging,
which is the only evidence available before implementation exists (task-master
tags before any diff or `.fail` record can exist).

**How to apply:** when slicing a new unit, compare its `Affected files` list
against this split — six regenerated persona copies + both adapter ports
present → `opus`; single surface, no adapter/persona propagation → `sonnet`.
This is silent unless a `.fail` record later forces `sonnet`/`opus` upward
per the reactive-tagging rule — this pattern is a tie-breaker for the initial
guess, not a substitute for that rule.
