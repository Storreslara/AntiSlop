# ADR 0014: Dispatch hygiene ships as a hook, not persona-protocol prose

Date: 2026-08-07 (recorded retroactively, unit #165)
Status: Accepted

## Context

`hooks/scripts/dispatch-hygiene.sh` mechanically enforces four checks on a
dispatch prompt before a spawn (H1 oversize prompt, H2 an inlined artifact as
a large fenced block, H3 re-dispatch of an already-PASSed unit, H4 missing
dispatch-contract headings — see **Dispatch hygiene** in `CONTEXT.md`). The
alternative considered (and rejected) was adding a rule to
`templates/persona-protocol.md` instructing personas to keep dispatch
prompts short, reference artifacts by path, and not re-dispatch a passed
unit.

The full-tier protocol is inlined verbatim into six persona bodies
(`orchestrator`, `lead-programmer`, `spec-master`, `task-master`,
`reviewer`, `milestone-auditor` — see
[protocol-delivery-tiers.md](../../.claude/wiki/protocol-delivery-tiers.md)),
and `tests/adapter-protocol-parity.test.js` fails closed on any new canonical
section, requiring it to be ported to both adapter docs. Growing that
always-inlined file has a real, measurable cost: six copies of prose that
every persona reads on every dispatch, whether or not the rule is relevant
to that turn.

## Decision

**Narrowed thesis: do not grow the always-inlined protocol for a rule that
can be mechanized as a hook instead.** This is deliberately narrower than
"hooks over protocol prose in general" — two sibling plans
(`2026-07-28-maxturns-cutoff-handoff`,
`2026-07-28-microworlds-ubiquitous-language-human-review`) legitimately
added protocol sections in the same window, because *those* rules govern
judgment a hook cannot check (e.g. how to interpret a truncated turn). The
distinguishing test is not "is this a rule for personas" but "can this
specific rule be checked mechanically against the dispatch payload alone,
with no judgment call":

- H1/H2/H3/H4 are all answerable from the `PreToolUse`/`Agent` payload
  (`tool_input.prompt`, `tool_input.subagent_type`) plus files already on
  disk (`.claude/reviewed/*.pass`, `persona-config.json`). No persona
  judgment is required to evaluate any of them — a byte count, a fenced-block
  line count, a file-existence check, and a heading-presence check are all
  deterministic.
- A hook enforces the rule on **every** dispatch, including ones written by
  a persona that never read (or has forgotten) the relevant protocol
  section, or by a differently-configured adapter port. Protocol prose only
  binds a persona that inlines it and follows it; a hook binds the seam
  itself.
- The cost of a hook is paid once (the script), not six times (once per
  full-tier persona body) plus twice more (both adapter doc ports).

## Consequences

- `dispatch-hygiene.sh` carries the enforcement; `persona-protocol.md`
  carries none of it. A persona never needs to be told "keep dispatch
  prompts short" because an oversize prompt cannot be dispatched to a gated
  target in `block` mode regardless of what the persona intended.
- New dispatch-shape rules that are payload-checkable belong in this hook
  (or a sibling hook), not as a new protocol section — apply the same test
  above before proposing one.
- New dispatch-shape rules that require judgment (e.g. "is this prompt
  actually clear," "did the persona pick the right target") still belong in
  protocol prose, since no hook can evaluate them from the payload alone.
- Escape hatch: `.claude/.dispatch-override` exists precisely because a hook,
  unlike a persona, cannot be reasoned with mid-dispatch — an operator who
  judges a block wrong needs a way to say so explicitly, once, audited (see
  [ADR 0011](0011-dispatch-override-idempotency-window.md)).

## Related

- **CONTEXT.md** — **Dispatch hygiene** entry (this ADR's companion,
  added same unit).
- **ADR 0011** — the escape-hatch idempotency window for this same hook.
- [protocol-delivery-tiers.md](../../.claude/wiki/protocol-delivery-tiers.md)
  — why the full/slim tier split exists and what it costs to grow either.
- Issue #165 (unit dispatch) and its parent spec #156, whose "Scribe update
  hint" raised this ADR as an optional follow-up.
