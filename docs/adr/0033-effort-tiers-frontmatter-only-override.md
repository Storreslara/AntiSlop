# ADR 0033: Effort is a frontmatter-only override, not a per-dispatch parameter

Date: 2026-09-24
Status: Accepted

## Context
The cost-governance brief left open whether reasoning effort could be
controlled per subagent dispatch (an orchestrator-set runtime parameter) or
only at the level of a persona's own definition file. This was resolved
empirically against the installed Claude Code (2.1.281): `effort` is a
documented `agents/*.md` frontmatter key, sibling to `model`/`tools`/`memory`
in the same schema object, validated against
`["low","medium","high","xhigh","max"]` or an integer at load time (an
invalid value is loud — *"has invalid effort '\<v\>'. Valid options: …"* — not
silent). The `Agent` tool's own schema, by contrast, exposes only
`description`, `prompt`, `subagent_type`, `model`, and `isolation` — **there
is no per-dispatch effort parameter.** The harness's own tool description
confirms this directly: each agent's model, reasoning effort, and tools come
from its definition file, not from the call site.

The brief's originating phrasing described the desired invariant as a
"floor" — effort could be raised per dispatch but never lowered past a
measured or default minimum. That framing does not fit what was found. A
floor is a one-sided constraint (blocks going under, permits going over);
what `effort:` frontmatter actually does is **pin** a persona's effort to a
declared value, overriding ambient session effort in *both* directions —
this also blocks a persona from getting *more* effort than declared when the
ambient session runs hot (e.g. `explorer`'s `effort: low` is not inflated by
a `high`-effort main session). "Floor" describes only the `reviewer`
half-case (declared `high`, must never silently drop) and mischaracterizes
the `explorer` half-case (declared `low`, must never silently rise). A
just-landed sibling scribe unit (CONTEXT.md's **effort override / effort
tier** entry, commit 6b76a6b) already corrected this in the glossary; this
ADR's title and text use the same corrected term rather than
reintroducing "floor."

## Decision
Effort is frontmatter-only. There is no dispatch-time effort knob for the
orchestrator, or anything else, to set, weaken, or strengthen. Consequently,
the only way to change a persona's declared effort is to edit its
`agents/<persona>.md` definition — a harness-control-surface edit this
project already treats as a guarded class of change (the same class that
governs `agents/reviewer.md`'s other gate-relevant fields). This makes the
asymmetry *structural* rather than prose-enforced: unlike the `model`-tier
precedent, where a real per-dispatch `model` parameter exists and the
downgrade-only/never-upgrade rule must be maintained by instruction, there is
no dispatch-time surface here to police at all.

Where a one-way rule is stated for how a *persona definition* should be
edited over time (e.g. `reviewer`'s `effort: high`), this repo's direction
applies, not the brief's inverted one: judgment may move a persona's
declared effort toward **more** capability; it may never quietly move it
toward less. This mirrors the existing `sonnet`→`opus` downgrade-only
reviewer-tier rule, where "downgrade" already means "toward more capable" in
this repo's vocabulary — not the brief's assumption that "raise" always means
"more" and "lower" always means "less risk to guard against."

## Consequences
- No dispatch-time effort knob exists for the orchestrator to guard against
  misuse — there is nothing to police at the call site, only the guarded
  frontmatter files themselves.
- `explorer` (`low`), `task-master` (`medium`), and `reviewer` (`high`) each
  declare a pinned value; `milestone-auditor` deliberately declares none,
  per the user's settled 2026-09-23 decision, since its adversarial judgment
  is per-persona rather than per-phase and cannot be priced separately.
- **Empirical pin (R7), stated exactly as Step 4's own unit report recorded
  it, not strengthened here:** live-dispatching `explorer` under its new
  `effort: low` frontmatter completed a trivial subagent turn with no
  dispatch failure or "has invalid effort" warning, confirming the key is
  *declared* and *loads* correctly. This does **not** confirm end-to-end
  silent inheritance for personas that omit the key altogether — R7's
  stronger claim remains unproven, and this ADR does not assert it.
- Any future proposal to make effort a per-dispatch parameter would require
  a new Claude Code capability that does not exist as of 2.1.281; until then,
  "raise effort for this one dispatch" is not an available action anywhere
  in this system, by construction rather than by policy.

## Related
- `CONTEXT.md`'s **effort override / effort tier** glossary entry (unit
  #480, commit 6b76a6b) — the corrected "override, not floor" terminology
  this ADR's title follows.
- `tests/effort-tier-consistency.test.js` (Step 4, commit 9109f35) — the
  mutation-proof pin on `reviewer`'s `high` and the positive absence
  assertion for `milestone-auditor`.
- ADR 0032 (this same Step 6) — the sibling decision rejecting command
  rewriting as a cost-control mechanism, for the same spec's other half.
