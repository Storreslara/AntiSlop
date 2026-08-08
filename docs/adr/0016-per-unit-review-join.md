# ADR-0016: Per-Unit Review Join Stamp

**Date**: 2026-08-07  
**Status**: Approved  
**Deciders**: lead-programmer, scribe, reviewer (units #262–#264, #265–#267)

## Context

Reviewer verdict coupling (issue #153) guards against a reviewer clearing pending-review flags without writing a marker by checking whether a PASS or FAIL marker exists and is newer than a global clear-watermark (`.claude/.last-review-clear`). This mechanism has a structural concurrency defect and an under-inclusive gap:

- **Liveness defect (issue #226)**: The single global watermark is shared across concurrent reviewers. When reviewer A writes a valid marker and reviewer B clears first (advancing the watermark), A's own subsequent stop is then blocked demanding a marker it already wrote. The same shape structurally traps an advisory second-reviewer dispatch (a Roast pass on an already-verdicted unit), which is forbidden to write a marker and has no legal exit at all.

- **Under-inclusive gap**: Unit A's marker satisfies unit B's check. The `find`-based predicate proves "some marker exists", never "this unit's verdict was recorded". A reviewer blocked by this gate whose verdict it does not own has no sanctioned exit; one instance took a metadata-only workaround (touching a marker's mtime), a second correctly refused and escalated.

- **Existence-only validation**: The check accepts a bare zero-byte `touch`, while `task-gate.sh`'s `marker_valid()` explicitly rejects it. Two mechanisms from the same parent spec use two different definitions of "a marker was written".

Plus a **process gap**: a persona blocked by a control whose verdict it does not own must report-and-wait, never self-authorize a workaround — including metadata-only ones. The code defect created a bind with no sanctioned exit; codifying the rule is part of the fix.

## Problem

### Why the Three Suggested Directions Collapse to One

Issue #226 offered three non-prescriptive fix directions; two of them collapse into one, and the third fixes only one direction:

**Directions A (per-unit watermark) and B (stamp the task-id at dispatch) are the same fix.** A per-unit watermark is unimplementable without B, because stop time carries no unit id — the `SubagentStop` payload carries `agent_type`, `agent_id` and `session_id`, but not unit id or prompt. Any per-unit join must be established at dispatch time, not at stop time.

**Keying per agent_id instead is provably wrong**, so it is recorded here to prevent re-proposal. The check must fire on a reviewer's first stop when no marker was written (that is its entire purpose), but a per-agent watermark has no prior value on a first stop, so every first stop would bootstrap fail-open and the check would never fire for anyone. The global watermark's cross-dispatch persistence is what carries first-stop coverage today. Per-agent keying destroys it.

**Direction C (accept a marker newer than the watermark's predecessor)** fixes only the liveness direction, leaves under-inclusiveness untouched, and degrades with more than two concurrent reviewers. Rejected.

### Honest Scoping

The new design fixes the liveness direction completely and the under-inclusive direction substantially but not absolutely — see "Residual gaps" below. It also narrows the mechanism's coverage: it fires only for reviewer dispatches carrying a `Unit: <id>` first line. Step 5 makes that line mandatory in prose, but the hook itself fails OPEN without it — deliberately, matching today's bootstrap posture.

## Decision

Adopt a per-unit **review-join stamp**, written by `reviewer-route-gate.sh` at reviewer-dispatch time and consumed (deleted) by `stop-gate.sh` when that unit's verdict marker is found.

### Review-Join Stamp Artifact

**Path**: `.claude/.review-join.<unit-id>` (one per unit under review)

**Content**: A single line: `<UTC ISO-8601 timestamp> unit=<unit-id> prior=<none|fail|blocked> prior_mtime=<epoch|->` 

**Lifecycle**:
- Written by `reviewer-route-gate.sh:PreToolUse (Agent)` when a reviewer is dispatched with a valid `Unit:` line and no prior `.pass` marker exists for that unit
- Deleted by `stop-gate.sh:SubagentStop` when a verdict is satisfied (first review with any marker, cases 2; re-review with marker mtime exceeding `prior_mtime`, case 3; or when the stamp itself is malformed, case 7)
- Left untouched on fail-closed blocks (cases 4–6): when a marker exists but fails the format check, when no marker exists, or when the marker is stale

### Governing Rule

A reviewer's `SubagentStop` is allowed **iff no stamps exist, or at least one stamp is satisfied.**

**Seven-Branch State Table for the Reviewer's SubagentStop**

Evaluated after the `.blocked` early-exit and before flag deletion:

| # | Condition | Classification | Exit | Action |
|---|-----------|----------------|------|--------|
| 1 | No stamps exist at all | **allow**, log `marker-check=bootstrap` | 0 | Clear flags |
| 2 | Stamp for U; format-valid `.pass` or `.fail` exists; no `prior_mtime` recorded | Satisfied | 0 | Delete stamp, clear flags |
| 3 | Stamp for U; format-valid marker exists; marker mtime **greater than** recorded `prior_mtime` | Satisfied | 0 | Delete stamp, clear flags |
| 4 | Stamp for U; format-valid marker exists; marker mtime **not greater than** recorded `prior_mtime` | Unsatisfied (re-review produced no new verdict) | 2 | Keep flags, log `join-unsatisfied`, block |
| 5 | Stamp for U; marker exists but fails format check (e.g. zero-byte) | Unsatisfied | 2 | Keep flags, log `join-unsatisfied`, block |
| 6 | Stamp for U; no marker at all | Unsatisfied | 2 | Keep flags, log `marker=MISSING unit=<U>`, block |
| 7 | Stamp file unreadable, or its `unit=` field absent/malformed | **Satisfied**, fail OPEN | 0 | Delete stamp, clear flags |

### Marker Format Validation

A new helper `marker_format_valid <path> <unit-id> <verb>` mirrors `task-gate.sh`'s `marker_valid()`, unifying the two definitions of "a marker was written":
- File must exist, be non-empty, and its first line must begin `<verb> <unit-id> ` (`PASS` for `.pass`, `FAIL` for `.fail`)
- A zero-byte `touch` fails
- Prefix-only check, so every pre-existing marker stays valid

## Deliberate Non-Changes (Out of Scope)

1. **No change to `dispatch-hygiene.sh`.** Its `Unit:` parser is the model for the new one, but its "gated targets only — reviewer spawns are never touched" invariant is load-bearing and stays. The join lives in the reviewer-lifecycle hook instead.

2. **No new hook registration.** Both edited scripts are already registered (`PreToolUse (Agent)` and `Stop`/`SubagentStop`). `hooks/hooks.json` is not touched.

3. **No stale-stamp sweeper and no stamp TTL.** An unconsumed stamp is inert: a stop is allowed whenever any stamp is satisfied, so a leaked stamp can never deadlock a reviewer that did its job. A TTL would reintroduce a clock into a control that is otherwise purely factual. Left as a documented property.

4. **No marker-format change.** Marker format v3 (0.27.0) is untouched. The hook only reads the first line, reusing `task-gate.sh`'s prefix-only definition so all pre-existing markers stay valid.

5. **No enforcement H-check for the `Unit:` line on reviewer dispatches.** Step 5 makes it a documented requirement and the hook fails open without it. A blocking check would make a missing line a hard dispatch failure for a mechanism whose whole point is to fail safe.

6. **No deletion or migration of existing `.claude/.last-review-clear` files.** They become inert once nothing reads them. Deleting operator-visible state inside a hook is out of proportion to the benefit.

## Residual Gaps (Must Be Documented, Not Papered Over)

**Concurrent reviews of two different units remain partially under-inclusive.** If A and B are genuinely in flight at once and B's marker lands first, A's stop is allowed by B's satisfied stamp. This is strictly narrower than today (today any marker anywhere satisfies any reviewer's stop, indefinitely); it is now bounded to units currently in flight, and only until their stamps are consumed. It is also a state the protocol's own one-unit-at-a-time invariant says should not exist.

**Coverage narrows to `Unit:`-prefixed reviewer dispatches.** A reviewer dispatched without that first line, or resumed purely by `SendMessage` in agent-teams mode without a fresh `Agent` spawn, produces no stamp and its stop fails open. Mitigated by Step 5 (the line becomes mandatory prose) and by the fact that a teammate's initial spawn is an `Agent` call and therefore is stamped. Not mitigated for a teammate re-tasked onto a second unit by message alone.

**Nothing here makes the control tamper-proof.** `rm -f` of a stamp via Bash remains possible, exactly as the file's existing "Honest limit" header says of the pending-review flags. The audit log is the deterrent; the protocol section "Blocked by a gate you do not own" is what makes reaching for it a stated violation rather than an ambiguity.

## Adapter Ports and Per-Location Implementation

Both adapters (Codex and Cursor) replicate the old global-watermark design verbatim:
- `adapters/codex/hooks/scripts/stop-gate.sh:64-77` and `:131-158`
- `adapters/cursor/hooks/scripts/stop-gate.sh:47-60` and `:91-117`

The fix lands **per-location, not centralized**, because `bin/cli.js` copies adapter files verbatim rather than generating them (the same reason `tests/adapter-stop-gate-parity.test.sh` exists as a drift test rather than as construction-time injection). The fix touches **six script files** (three `stop-gate.sh` copies + three `reviewer-route-gate.sh` copies), updated in parallel to maintain parity. `tests/adapter-stop-gate-parity.test.sh` is the anti-drift mechanism and is extended, not bypassed.

One prior defect on this surface must stay closed: `222.fail` recorded that the codex port's clear-watermark block used a bare `exit 2`, bypassing codex's `block()` loop-guard helper. The replacement block path must also call `block()` in codex; claude and cursor have no loop guard and keep a bare `exit 2`.

## Related Issues and ADRs

- Issue #153: Marker coupling via clear-watermark (ADR-0011, superseded)
- Issue #226: Per-unit review join (this ADR)
- Issue #262–#264: Review-join implementation (units #262–#264, Steps 1–3)
- Issue #265–#267: Protocol and documentation (units #265–#267, Steps 4–6)
- ADR-0015: Commit-anchored PASS markers (marker format v3, still in force)

## Rationale

**Fail-safe concurrency.** A single shared watermark cannot safely coordinate concurrent reviewers. Per-unit stamps ensure each reviewer's verdict is decoupled from others' timing, and the governing rule (allow iff no stamps or at least one satisfied) lets the advisory second pass, the same-reviewer re-fire, and the concurrent-reviewer case all live while a reviewer that wrote nothing still blocks.

**Unification of definitions.** Splitting "a marker was written" across two checks (`task-gate.sh` prefix-only vs `stop-gate.sh` existence-only) created a bare-touch bypass. Unifying onto the prefix-only check (reusing `marker_valid()`) closes that gap and makes both mechanisms accountable to the same definition.

**Process discipline.** A gate's defect cannot create a bind with no sanctioned exit. A blocked persona must not self-authorize metadata-only workarounds; it must report and wait. The protocol section "Blocked by a gate you do not own" codifies this rule at the moment of blocking, so it is present in the hook message, not only in a document.

**Scope honesty.** Under-inclusive coverage (concurrent units can cross-satisfy) is a known residual and is bounded by the protocol's own one-unit-at-a-time expectation. Documenting residuals rather than claiming closure teaches future maintainers what is and isn't safe.

## Measurement and Validation

The acceptance criteria for units #262–#267 verify:
- Review-join stamp path, content and lifecycle are implemented
- Marker format validation is unified via `marker_format_valid()`
- The seven-branch state table and governing rule are in force in all six script locations
- ADR-0016 documents the mechanism with required content
- CONTEXT.md and wiki entries are updated
- All three Residual gaps are recorded verbatim
- `bash tests/validate.sh` passes (regression suite)
- Issue #226 is closed after Step 8 lands

See the units' acceptance criteria and the spec's Step 7–8 sections for full measurement details.
