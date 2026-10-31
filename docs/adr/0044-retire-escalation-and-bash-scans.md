# ADR 0044: Retire the escalation verdict and Bash text scanning

Date: 2026-10-30
Status: Accepted
Related: ADR-0002, ADR-0016, ADR-0034

## Context

Two protections cost more than they caught. The ESCALATE-TO-HUMAN verdict, with its `.escalated` marker, review packet, escalation card and human-decision gate, was issued 0 times in 917 review markers. The Bash command-text scans in `harness-integrity-gate.sh` and `reviewed-path-gate.sh` blocked 583 commands a month, and every sampled block was a read-only command.

## Decision

- The reviewer has three verdicts (PASS, FAIL, INSUFFICIENT-CONTEXT). When a decision belongs to the user, it adds a `needs-human: <one line>` note, and the orchestrator relays it with AskUserQuestion. No marker, packet, card or gate exists for it.
- The Bash branches of both gates allow at once. Their `hooks/hooks.json` registrations stay, because the A/B harness (`tests/abtest-arms.test.sh`) pins them. The Write and Edit denies stay.
- A replacement check landed first: `dispatch-hygiene.sh` stamps each gated writer dispatch, and the stop gate blocks a writer's stop when a `.pass`, `.fail` or `.blocked` marker is newer than that stamp. Pending-review flags clear only on a reviewer stop.
- The stop gate keeps one pending-review flag check, the WIP sentinel, and `skip:`/`defer:`.

## Consequences

- Any agent can write review markers or the harness's own config and audit files through Bash without a pre-block. A marker forged during a writer dispatch is caught at that writer's stop; a forgery at any other time is not. `bin/audit-seal-verify.sh` still detects audit-log tampering on demand.
- The stop gate no longer runs test and lint at Stop (the reviewer's single `validate.sh` run covers it), no longer gates microworld reruns, no longer checks config drift, and no longer scopes review per unit through review-join stamps (the protocol already allows one unit mid-review).
- Removing the two inert hooks.json registrations needs the A/B harness changed first.
