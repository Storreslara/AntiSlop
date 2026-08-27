---
name: gh413_m3_state_consolidation
description: Unit gh413 M3 — consolidate 13 state artifacts into 5 key domains via new state-access.sh lib
metadata:
  type: project
---

## gh413 Scope

Consolidate 13 live state-artifact species into 5 key domains via a new `hooks/scripts/lib/state-access.sh` library with read/write/sweep entry points. Every hook that touches state must source this lib. Every ordering/atomicity constraint and distinction must survive.

## Five Domains (consolidating 13 species)

| Domain | Key | Absorbs | Must Keep |
|--------|-----|---------|-----------|
| **Unit** | unit id | `.review-join.<unit>`, five marker verbs (`.pass/.fail/.blocked/.escalated/.directed`), `human-review/<id>/` packet + `DECISION` | per-unit file granularity (ADR-0016); DECISION zero-identity write ban; DECISION↔`.escalated` timestamp binding |
| **Agent** | agent id | `.pending-review.<agent>`, `wip-handoff.<agent>` | opposite polarities (pending-review persists, handoff consumed-on-read); existence vs. content independent signals |
| **Session** | session id | `.session-baseline.<session>` | create-only-if-absent; content is git ref |
| **One-shot** | global | `.dispatch-override`, `.dispatch-override.consumed` + tmp | `.consumed`-before-`rm` ordering; content-embedded epoch (not mtime); dispatch-identity hash |
| **Log** | append-only | four audit logs | append-only semantics; `review-audit.log`'s tail as control input |

## 15 Distinctions That Must Survive (A18 test id count)

1. `.pending-review.<agent>` — existence blocks dispatch, content-blind; created only-if-absent
2. `.review-join.<unit>` — staleness anchor via `prior_mtime`
3. `.session-baseline.<session>` — git object reference answer
4. `wip-handoff.<agent>` — suppresses test/lint check; empty ≠ absent
5. `.dispatch-override` — global one-shot waiver token
6. `.dispatch-override.consumed` — 10-second replay window
7. `.pass` — commit attestation marker
8. `.fail` — 2-FAIL-cap slot consumer
9. `.blocked` — read by existence glob only
10. `.escalated` — first-line timestamp is staleness key
11. `.directed` — absent from stop-gate's globs (deadlock prevention)
12. `human-review/<id>/` packet
13. `DECISION` — only artifact no agent may write
14. The four logs (append-only)
15. `.codex/.stop-loop-guard.<session>` — consecutive-block counter

## Ten Ordering/Atomicity Constraints (A19)

Explicit (5):
1. `.consumed`-before-`rm`
2. `.blocked`/`.escalated` glob → review-join eval → `rm -f .pending-review.*`
3. create-only-if-absent on `.pending-review`
4. create-only-if-absent on `.session-baseline`
5. `.directed`'s exclusion from stop-gate's globs

Six more (from Testing decisions, need to identify):
- Likely from: DECISION zero-identity write ban, DECISION↔`.escalated` timestamp binding, opposite polarities, existence vs. content signals, per-unit keying, append-only log semantics

## TDD Red Phase Requirements

- Write failing tests BEFORE touching any artifact
- Tests must be red now (asserting current behavior)
- When consolidation reorders, tests must turn red for right reason
- Each constraint mutation-proved: revert fix, re-run, must fail
- Tests are external-behaviour (exit codes, audit records), not function internals

## Acceptance Criteria Summary

- A17: species enumeration test (exact filename patterns)
- A18: distinctions manifest (15 test ids minimum)
- A19: all ten constraints mutation-proved
- A20: concurrency test (two units concurrent, no deadlock)
- A21: validate.sh + cli.js --update --check in clean worktree
- A22: capability-regression fixture (humanReviewMode: "all")
- A30: no persona-config.json changes except fileHashes/pluginVersion

## Next Steps

1. Wait for explorer results on affected hook scripts
2. Design state-access.sh seams (read/write/sweep per domain)
3. Write TDD red-phase tests (15 + 10 + species enumeration + concurrency + capability)
4. Implement state-access.sh
5. Migrate hooks one at a time with test re-runs
6. Verify all acceptance criteria
