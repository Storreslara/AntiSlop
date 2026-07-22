# Persona design notes

Maintainer rationale relocated out of each persona body's multi-line HTML
comment block, per Step 4 of
`docs/plans/2026-07-22-persona-system-audit-patch.md`. Preserved verbatim
(reflowed from the source's hand-wrapped comment lines into plain
paragraphs; no wording changed). The version-stamp line (`--update` keys
off it) and load-bearing inline warnings that must sit next to the
frontmatter they protect — e.g. explorer's `mcpServers` shape warning —
remain in the persona body itself, not here.

## orchestrator

Deliberately no `skills:` field — persona skills never load into the
orchestrator. Deliberately no `memory:` field — a router that accumulates
state contradicts "you keep only routing rules." Bash is for the
graph-freshness check only, by instruction (not tool-enforced).
TaskStop/TaskOutput: a dispatched lead-programmer can run for a long time on
a real multi-step task, and `tools:` is an allowlist that REPLACES the
inherited set — without these two explicitly listed here, the orchestrator
has no way to poll a background dispatch's liveness (TaskOutput with
block=false) or cancel one that's genuinely stuck (TaskStop), and is left
guessing from file mtimes instead.

## spec-master

`memory: project` auto-grants Read/Write/Edit for memory-file management
(see shared protocol) — this does NOT relax "never write production code"
below; that remains instruction-enforced. `skills:` placeholders are
namespaced names from the mattpocock/skills plugin, resolved and
substituted by ADAPT (which copies a corrected copy of this file into the
project's .claude/agents/, since project agents override plugin agents).
`Skill` is in tools so a teammate copy can invoke grill-me/to-spec
explicitly, since preloading doesn't apply to teammates. `maxTurns: 30` —
starting bound, adjust after real usage. `model: opus` is the default;
orchestrator may override per-dispatch (orchestrator.md). Never change the
tier here.

Pointer only (orchestrator.md's "Opus|Fable routing for spec-master and
milestone-auditor" section is authoritative): fable is eligible only when
ALL hold: scope already enumerated, rides existing seams, no interrogation
needed; any relevant `.claude/reviewed/*.fail` record forces `opus`
regardless.

spec-master owns the spec through Open Questions relay and publishing via
`to-spec`; ticket-slicing (`to-issues`), per-unit model tagging, the
retrieval-contract line, and per-unit dispatch-prompt authoring for
lead-programmer/scribe belong to `task-master`, a separate persona split
out of what used to be a single planning persona (see
agents/task-master.md).

## task-master

`memory: project` auto-grants Read/Write/Edit for memory-file management
(see shared protocol) — this does NOT grant Write/Edit for source docs;
task-master's dispatch prompts and sliced-issue bodies are its TEXT OUTPUT
(relayed via SendMessage/report, or filed directly as tracker issues
through `gh` via Bash) — the same "produce the text, the
tracker/orchestrator persists it" shape `spec-master` uses for the plan doc
itself. `Skill` is in tools so a teammate copy can invoke `to-issues`
explicitly, since preloading doesn't apply to teammates. `maxTurns: 30` —
starting bound, matching `spec-master`'s, adjust after real usage. `model:
sonnet` is the default; opus-eligible per-dispatch at the orchestrator's
discretion (orchestrator.md) — fable is EXCLUDED for this persona, the
judgment needed to write accurate dispatch boundaries doesn't fit fable's
light/mechanical profile. Never change the tier here.

task-master owns `to-issues`/`to-tickets` slicing outright, per-unit model
tagging, the retrieval-contract line, and per-unit dispatch-prompt
authoring for lead-programmer/scribe — split, alongside `spec-master`, out
of what used to be a single planning persona (see agents/spec-master.md),
which owns everything upstream of a finalized spec (taxonomy scorecard,
interrogation, Open Questions, Self-check, publishing via `to-spec`).

## lead-programmer

No maintainer-rationale HTML comment block is currently present in this
persona body — nothing to relocate.

## reviewer

Deliberately no Write/Edit — it can never fix what it's grading; the Agent
tool is for spawning the explorer, not for delegating fixes. Deliberately
no `memory:` field — fresh eyes every review is the point of the
Writer/Reviewer split; accumulated impressions of past code erode it. Bash
is permitted for running checks AND for the one bookkeeping exception below
(the PASS marker) — that marker is not code under review, so writing it
doesn't violate "never edits." `Skill` is in tools so a teammate copy can
invoke coding-discipline and roast-work explicitly, since preloading
doesn't apply to teammates. `maxTurns: 30` bounds this Opus-tier persona the
same way explorer's maxTurns: 10 bounds it.

The `model: opus` frontmatter is the DEFAULT for this persona. The
orchestrator may override it to `sonnet` on the PASS/FAIL gate for
demonstrably-mechanical units (per its "Reviewer gate model selection"
section), but the gate NEVER runs on fable, for any unit, regardless of
complexity. Regardless of which model runs the dispatch, the materiality
filter, machine-checkable criteria, and PASS/FAIL marker format remain
unchanged.

## milestone-auditor

Deliberately no Write/Edit, same reasoning as reviewer.md — it can't fix
what it's auditing, and fixing isn't its job anyway (this doesn't grade
implementation, so there'd be nothing well-formed to fix). Deliberately no
`memory:` field — same rationale as reviewer: fresh eyes per audit, no
accumulated impressions to erode the adversarial stance. `Agent` is for
spawning the explorer for structural facts, not for delegating fixes.
`Bash` is for independently inspecting real state (data, config, deployed
artifacts) — the whole point is checking premises against something
outside the plan's own reasoning, not re-reading the plan more carefully.
`Skill` carries `grill-me` so this persona can interrogate the PLAN's own
stated assumptions adversarially, the same tool spec-master uses on the
original request — but aimed the other direction, after the fact rather
than before. `maxTurns: 20` — starting bound, adjust after real usage.
`model: opus` is the default; orchestrator may override per-dispatch
(orchestrator.md). Never change the tier here.

## explorer

No `memory:` — stateless by design. `Skill` stays in `tools` for teammate
copies. `maxTurns: 10` bounds the highest-frequency persona.

## scribe

`Skill` is in tools so a teammate copy can invoke
improve-codebase-architecture explicitly, since preloading doesn't apply to
teammates.
