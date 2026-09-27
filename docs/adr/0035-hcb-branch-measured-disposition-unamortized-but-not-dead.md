# ADR 0035: The human-confirmation branch's low fire-count is not evidence it should be replaced (amends ADR-0034)

Date: 2026-09-26
Status: Accepted (amends ADR-0034; does not supersede it)

## Context

A Fable adversarial review (2026-09-25) reiterated the two alternatives
ADR-0034 already rejected — `permissions.ask` in `settings.json`, and simply
running `bin/cli.js --update` outside the harness — and added a new
argument: the branch's two mode tiers, asked/completed audit-record pairing,
and registration-presence assertion are a large surface for a branch that,
per the gate's own header, never emits `ask` from a subagent (where most of
this framework's work happens). Item 16's plan
(`docs/plans/2026-09-25-item16-hcb-human-confirmation-branch.md`) required
measuring the fire-count before answering that concern (Step 1) and
recording the disposition here (Step 2), instead of re-arguing the two
alternatives from first principles a second time.

**Why this is a new ADR rather than an edit to ADR-0034.**
`tests/harness-integrity-gate.test.sh`'s C4.1c check pins ADR-0034 byte-for-byte
against commit `07faca7` as a Cat 3 file (a file that already correctly
describes the post-change state and must carry no further amendment note).
Editing ADR-0034 directly would fail that check, and this unit's own
Do-Not-Touch list forbids editing that test to accommodate a documentation
change. ADR-0034's Decision is not being revisited here — this ADR amends it
with new measurement and evaluation, per that ADR's own precedent of citing
amendments in a separate file (e.g. ADR-0009 amends ADR-0006 without
editing it).

**Measurement (item16-1, verified 2026-09-26).** Fire-count: 21 `asked`
audit records, 0 `completed` audit records, across the audit log's entire
~60-day recorded history. All 21 `asked` records are confirmed synthetic —
same-second clustering (up to 12 in one second, impossible for a real human
approval), probe-scaffolding evidence in adjacent log lines, and a
systematic sweep shape matching exactly the 5 [[ask-eligible]] paths ×
permission-mode tiers — i.e. a prior review's own probe scripts exercising
the gate directly, not production usage. Exposure window: the branch itself
has existed for ~2.2 days of that ~60-day history (built
2026-09-24T19:15–20:29Z). Zero organic fires have been observed to date.

## Decision

Amend ADR-0034 (do NOT supersede it). Both alternatives remain rejected, and
the measurement above changes neither rejection:

**`permissions.ask` is still not equivalent.** The fire-count is irrelevant
to this argument because both grounds ADR-0034 gave are structural, not
usage-dependent: `permissions.ask` would be configured in
`.claude/settings.json`, one of the five paths this branch protects (a
control disableable by the edit it guards against), and it carries no
per-mode tiering (Set B's `acceptEdits` exclusion — the anti-capture
property — has no `permissions.ask` equivalent).

**"Run `--update` outside the harness" is still an operator workaround, not
a mechanism.** It requires a human to remember, every time, and fails closed
silently for any autonomous run that reaches a protected write with nobody
watching. A low measured fire-count for the branch it substitutes for is not
evidence this workaround would perform adequately as the *sole* mechanism.

**Critical reframing: the near-zero fire-count is not evidence of
unamortized weight — it may be the branch working as designed.** The
sanctioned `bin/cli.js --update` route writes via a Node filesystem API call
in a child process, which structurally never passes through Claude Code's
`PreToolUse` hook interception — there is no tool call for the hook to see.
So the branch's near-zero organic fire rate is consistent with two very
different explanations that produce an identical measurement: a dead
feature nobody exercises, or a working deterrent that successfully keeps
agents on the sanctioned `--update` route (which never trips the branch at
all). Fire-count alone cannot distinguish these, so it must not be read as
straightforwardly "unamortized, therefore remove or shrink."

**Disposition.** In the narrow sense of "measured `ask`-branch fire rate,"
the branch is unamortized (21/21 `asked` records synthetic, 0 organic, 0
`completed`, ever). Per the reframing above, this narrow reading does
**not** by itself justify consolidation. Taking ADR-0034's plan's Open
Question 1 default at face value anyway, should a consolidation spec later
be authored: the specific candidates are the asked/completed audit-record
pairing and the registration-presence assertion — both accounting
scaffolding around the branch, not its core decision logic. **Set B's
`acceptEdits` exclusion is explicitly NOT a consolidation candidate** — it
is the anti-capture property (ADR-0034's R1), and removing it would let a
silent auto-accept disable the gate itself, exactly what the branch exists
to prevent. A human decision is required before any such consolidation spec
is authored; this ADR records the evaluation, not that decision.

## Consequences

- The two alternatives the review raised are now evaluated with data, not
  just first-principles argument, so they should not be re-raised
  identically at a future audit without addressing this ADR.
- Nothing about the gate, its tests, or Set A/Set B membership changes. This
  is a documentation-only disposition.
- A future consolidation spec (if a human decides to author one) is scoped
  by this ADR to two named candidates, and is explicitly barred from
  touching the `acceptEdits` exclusion.

## Related

- [ADR-0034](0034-human-confirmation-branch-per-call-consent-not-escalation.md) —
  the decision this ADR amends; its Decision, Residuals, and Consequences
  stand unchanged.
- `docs/plans/2026-09-25-item16-hcb-human-confirmation-branch.md` — the
  finalized spec this ADR records the disposition from (Steps 1 and 2).
