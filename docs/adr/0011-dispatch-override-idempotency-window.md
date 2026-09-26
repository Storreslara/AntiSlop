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

**Payload identity key:** `cksum` of `subagent_type` plus the prompt (which
also folds in the prompt's byte length via `cksum`'s own output), POSIX, no
fallback chain — `dispatch_key="$(cksum <<< "${target_type} ${prompt}" | tr
-d ' ')"`. `subagent_type` is folded in so the same prompt text sent to a
DIFFERENT target is never honoured as a replay of a different dispatch.
Deterministic and collision-resistant for practical purposes, but treated as
an identity hint rather than a security boundary in code comments — an
attacker with sufficient capability to craft a colliding prompt inside a
10-second window could equally just write a second override file. See
`hooks/scripts/dispatch-hygiene.sh` comments for the full rationale.

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

## Reconsidered 2026-09-26: id-keyed replacement parked

A 2026-09-25 adversarial review proposed replacing this ADR's cksum-keyed,
clock-based replay window with a unit-id-keyed override list, to remove
clock-skew handling from a hook. `docs/plans/2026-09-25-item11-dispatch-override-replay-window.md`
specced that replacement, then measured its own premise before implementing
it. The measurement does not support the change:

1. this repo runs `dispatchHygiene.mode: "warn"` since commit `0f6efa7`
   (2026-08-16), per [ADR-0024](0024-ceremony-reduction-solo-operator.md);
2. `warned=` is emitted only in `warn` mode
   (`hooks/scripts/dispatch-hygiene.sh:390-396`), so an all-`warned=` log
   proves the posture for every recorded event;
3. the recorded `.claude/dispatch-audit.log` history contains zero
   `override=`, zero `override-replay=` and zero `blocked=` entries — i.e.
   **zero blocked dispatches**, so the hatch's trigger condition never
   occurred and the zero is not evidence about the hatch;
4. the record begins 2026-08-16 while the hook landed 2026-07-30
   (`6829050`) and the override 2026-08-02 (`37fec4b`) — a ~2-week
   unrecoverable blind window, no rotation archive;
5. the log's line count is **not** an exposure denominator, because a clean
   dispatch logs nothing (`:388`) and one dispatch can emit two lines;
6. H1/H2 fire on non-gated targets (`:272`, `:299`) that carry no `Unit:`
   line, so an id-keyed override cannot cover them — with the observed
   instance (`2026-09-25T18:07:55Z warned=H1 target=spec-master`) named.

**Decision: option (c) — park the id-keyed rework.** Keep the existing
clock-based, `cksum`-keyed replay window and the escape hatch exactly as they
are (this ADR's `Status:` remains `Accepted`, unchanged). Neither proceeding
with the id-keyed design nor deleting the escape hatch is adopted.

**Re-open triggers** (the park is conditional, not permanent):

1. `dispatchHygiene.mode` in `.claude/persona-config.json` returns to
   `"block"` in this repo, or a downstream install reports a real block.
   That restores the hatch's trigger condition, and the first `override=` or
   `blocked=` line in `.claude/dispatch-audit.log` makes the coverage
   question measurable for the first time. Re-run the coverage measurement
   against the newly recorded window before touching the design.
2. A double-fire recurs (two `override=`/`override-replay=` lines for one
   operator action, or a re-registration of the hook across
   `.claude/settings.json` and the plugin's `hooks.json`). That is the only
   condition under which the window's correctness is load-bearing again, and
   the id-keyed design's idempotency-by-construction becomes worth its cost.

See `docs/plans/2026-09-25-item11-dispatch-override-replay-window.md`,
§ Scope reconsideration (2026-09-26), for the full reasoning.

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
- **ADR-0024** — the solo-operator posture (`dispatchHygiene.mode: "warn"`)
  that makes this ADR's window untriggered in this repo's own history.
- **Plan:** `docs/plans/2026-09-25-item11-dispatch-override-replay-window.md`
  — the id-keyed-replacement review this section responds to.
