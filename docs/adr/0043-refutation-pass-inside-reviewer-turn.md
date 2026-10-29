# ADR 0043: The refutation pass runs inside the reviewer's turn, behind a replay gate

Date: 2026-10-27
Status: Accepted
Related: ADR-0002, ADR-0016

## Context

A FAIL verdict whose defect is hallucinated, or already mitigated by code the reviewer did not read, still uses up an Escalation-ladder attempt, because the ladder's `n` is the FAIL-block count. A wrong refutation is the costly direction: the reviewer's PASS is the terminal gate, so a real defect refuted away ships.

## Decision

Before returning FAIL, the reviewer pipes at most 3 judgment defects into `bin/refutation-brief.sh` (installed as `.claude/bin/refutation-brief.sh`) and spawns one foreground, unnamed `explorer` on `sonnet` with its output as the prompt, to disprove each defect against the whole file, its callers and the baseline. The reviewer re-checks each artifact itself, states its own reason, and may keep a defect standing. Only defects that survive reach the FAIL record, whose every block now ends with a `refutation:` telemetry line. The reviewer instructions shipped only after an offline replay of past real defects passed its gate (`eval/refutation-replay/score.py --gate`), and the milestone auditor samples up to 3 live `refuted:` notes per milestone.

## Consequences

- No hook, marker, ladder or orchestrator change. A PASS reached through a refutation writes the same marker, stamp and flag state as any other PASS, and a prevented FAIL writes no FAIL block.
- The FAIL-record format gains a last line, and a defect the pass could not settle carries the `[unconfirmed]` prefix.
- The pass's answer is evidence; the verdict stays the reviewer's.
- The codex and cursor ports run no pass and write `refutation: skipped=no-subagent`.

## Alternatives rejected

- An orchestrator-dispatched refutation after the FAIL: `n` has already gone up, so undoing it needs a new marker or a `ladder-tier.sh` change, plus fix-contract filtering and a second route-gate shape.
- A nested `Mode: advisory` reviewer: the reviewer-dispatch caller allowlist refuses it.
- A new `refuter` persona: it costs a persona file, ports, personaSelection and cli.js lists, and buys nothing over `explorer`.

## Why the three ADR tests hold

- Hard to reverse: moving the pass to the orchestrator needs state machinery, and the telemetry format would already be in consumer records.
- Surprising without context: a second check before FAIL reads like a second dispatch, and it is not one.
- A real trade-off: the alternatives above were weighed against one subagent round-trip on the FAIL path.
