# ADR 0011: Idempotency window for dispatch-override escape hatch

Date: 2026-08-02
Status: Accepted

## Context

Issue #166 describes a failure in the `.claude/.dispatch-override` escape hatch
mechanism in `hooks/scripts/dispatch-hygiene.sh`. The hatch is designed to be
single-use — one operator action to bypass a dispatch block — but fails when the
hook fires twice for the same tool call (double registration or race condition):

- **Sequential double-fire**: the hook reads the sentinel, deletes it *before*
  deciding, then the second invocation finds nothing. Measured 100% failure rate.
- **Parallel double-fire**: 15% failure rate (3/20 trials). One invocation may
  succeed while the other blocks.

The mechanism's failure is worse than having no escape hatch, because the
operator *believes* they have one.

## Decision: Adopted Direction

**Replace the read-then-delete with an idempotency window, bound to payload
identity.**

When `dispatch-hygiene.sh` receives a valid `override: <reason>` directive:
1. Read the first line of `.claude/.dispatch-override`
2. Honour the override (log under `override=`, delete the sentinel)
3. Write a consumption stamp `.claude/.dispatch-override.consumed` containing
   `<epoch-seconds> <key> <reason>`

When the sentinel is absent but replay conditions are met (the consumption
stamp exists, its epoch is within a 10-second window, and its `key` equals
this dispatch's `key`), honour a *replay* (log under `override-replay=`,
do not delete the stamp).

**Payload identity key:** `cksum` of the prompt plus the prompt's byte length.
POSIX, no fallback chain. Deterministic and collision-resistant for practical
purposes, but treated as an identity hint rather than a security boundary in
code comments — an attacker with sufficient capability to craft a colliding
prompt inside a 10-second window could equally just write a second override
file. See `hooks/scripts/dispatch-hygiene.sh` comments for the full rationale.

**Window duration:** 10 seconds. The two sequential fires of one tool call are
microseconds apart; 10s is generous slack under load and far below any
plausible interval between two distinct operator dispatches. The key binding
ensures a truly distinct dispatch is still blocked.

**Fail-open floor:** if the stamp cannot be written, the first invocation still
honours and the sibling still blocks — exactly today's behaviour, never worse.

## Decision: Rejected Direction

**"Extend `mergeNestedHooksJson` to the Claude standalone path"** — structurally
cannot fix the named state.

The double registration that #166 describes occurs when both of these are true:
- A `.claude/settings.json` carries hook registrations from prior runs or the
  plugin's standalone path
- The plugin's `${CLAUDE_PLUGIN_ROOT}/hooks.json` carries the same hook (e.g.,
  one persisted install, one plugin-shipped default)

These are *two different files*, one of which the CLI never writes. A
matcher-keyed merge *within* `settings.json` cannot dedupe across the
boundary between those two files. Such a merge would make the problem
*appear* fixed for one specific cause (repeated standalone runs) while
leaving the cross-file collision untouched, worsening the failure mode
from "sometimes fails" to "fails silently sometimes."

**Note on a separate finding:** while evaluating this direction, a distinct
latent bug was discovered in `deepMerge` at `bin/cli.js:162-182`: it dedupes
array items by reference equality, not structural equality, so repeated
standalone scaffolds append duplicate matcher-groups to `.claude/settings.json`
despite present-time deduplication. This is real and out of scope for #166
itself. See issue #228.

## Open Question 1 Disposition: Detection Only

Issue #153's retroactive half asked whether to backfill PASS markers for
units #141, #142, #143 that were reviewed but lack markers on record.

**Ruling: detection only. Do not fabricate markers.**

The code of those three units was independently mutation-verified by the plan
that created issue #153 itself (plan
`docs/plans/2026-07-31-reviewed-path-gate-write-intent.md`, Steps 1–6, all
closed). Nothing is unsafe; only the record is thin. However, a PASS marker
asserts "a reviewer ran these criteria at this time." Nobody can now attest
that for those three units. Writing a marker anyway would put a fabricated
verdict into the very audit trail this plan exists to make trustworthy — the
worst possible outcome for a change whose entire point is record integrity.

Step 2 of plan `docs/plans/2026-08-02-hook-layer-audit-and-escape-hatch.md`
adds detection (the clear-watermark coupling to `stop-gate.sh`) for future
units; no step fabricates a marker for the three historical gaps.

## Consequences

- **Escape hatch now survives double fire.** A doubly-registered hook honours
  the override exactly once per authorized dispatch, however many times it
  fires in sequence or parallel.

- **Audit trail stays readable.** `override=` and `override-replay=` log keys
  distinguish the first honoring from replays, so double-fire recovery is
  visible in `.claude/dispatch-audit.log` rather than hidden.

- **Trade accepted.** Honouring a consumed override for N seconds means two
  *identical* dispatches inside the window both pass. This is a deliberate,
  small widening in exchange for an escape hatch that actually works. Bounded
  by payload binding: two *different* dispatches never both pass.

- **Historical record of #141/#142/#143 preserved.** Their code remains safe
  (it was verified). The absence of a marker is now formally recorded as a
  disposition, not left as ambiguity that might invite later re-litigation.

## Related

- **Issue #166** — the double-fire defect this ADR resolves.
- **Issue #153** — the marker-presence detection that Step 2 implements,
  enabled by this ADR's adoption and disposition.
- **Issue #228** — the separate `deepMerge` array-deduplication bug discovered
  while evaluating the rejected direction.
- **Plan:** `docs/plans/2026-08-02-hook-layer-audit-and-escape-hatch.md`
  (Steps 1–6, including this ADR as Step 6).
- **ADR-0002** — reviewed-dir ownership and the Writer/Reviewer split this ADR
  serves.
