# Appendix: 2026-11-02-lean-pipeline-2

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-11-01 Functional scope & success criteria: Q The Q4 table's row 8 is the H4 size warning, but the dispatch describes row 9 (fixture and scoring fixes) as "item 8". Which is meant? → A (self-resolved, pending Open Question 1): plan both, l2-h4 conditional
- 2026-11-01 Functional scope & success criteria: Q Which follow-ups in followups.txt are in scope beyond the dispatch's list? → A (self-resolved): those verified open at 127e22b1 that need no new gate semantics (D7); stop-gate hardening (a)-(d) goes to Open Question 3
- 2026-11-01 Non-functional attributes (perf, security, scale): Q Does a 5m TTL hit the same prefix the reviewer's 1h TTL hits? → A (self-resolved, measured): in-run repeats yes (LP 19 of 19 at 190-363 s); 14 cross-run reviewer hits at gaps over 300 s would be lost; net saving about $6.0, not $10.1 (D1)
- 2026-11-01 Non-functional attributes (perf, security, scale): Q Can a false `Review gating:` header weaken review? → A (self-resolved): no; a false `off` only withholds markers, and the gates then block (D5)
- 2026-11-01 External dependencies & integrations: Q Which file decides `run_pass`? → A (self-resolved): `eval/abtest/lib/make-row.py:74`, so the fix goes there, not in `stream.py` or `score.py` (D6)
- 2026-11-01 Edge cases / failure handling: Q What happens to the existing results rows? → A (self-resolved): nothing; `harness_commit` changes with every commit, so the runner supersedes them on the next run
- 2026-11-01 Edge cases / failure handling: Q How does `us_entries` treat a nested or malformed brace form? → A (self-resolved): literal, so `scope: out` (fail closed)
- 2026-11-01 Technical constraints & tradeoffs: Q Slim tier or trimmed full tier for reviewer and lead-programmer? → A (self-resolved): trimmed full tier; the slim body lacks the marker, FAIL record and contract sections both need (D2)
- 2026-11-01 Technical constraints & tradeoffs: Q Which preloaded skill can go? → A (self-resolved): the reviewer's ubiquitous-language (advisory output only); the lead-programmer keeps both (D2)
- 2026-11-01 Technical constraints & tradeoffs: Q Where do the orchestrator's bytes for item 5 come from? → A (self-resolved): two unpinned cuts, net about -50 bytes (unit 6)
- 2026-11-01 Terminology consistency: Q Is "small repo" a new term next to "unit lane"? → A (self-resolved): yes, a harness term for `docs/harness-glossary.md` (unit 15), distinct from the small lane

## Constitution check (.claude/constitution.md v1.2.0)
- P1 "Verify, don't assume": satisfied. Item 2's premise was measured, not assumed; every unit has runnable criteria with mutation lines in its contract.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Item 5's test is a script (`unit-bookkeeping.sh repo`); item 6 moves facts into the script-built header.
- P3 "Version-stamp discipline": satisfied. Content units add `[Unreleased]` bullets only; l2-release ships 0.34.0. Unit 14's edit of a released 0.32.0 bullet is wording, no version change.
- P5 "`tests/validate.sh` is the merge gate": satisfied. It is every unit's last criterion.
- (P4 is a SHOULD: the new orchestrator sentence names a script that ships with the plugin.)

## Self-check
- CHK1: Does every Goal clause map to a unit? — PASS (G1:1, G2:2, G3:3+6, G4:3+4+5, G5:7+8, G6:9-15, release 16)
- CHK2: Do D5 and unit 5 agree that the reviewer still runs the precheck and every deferred criterion itself? — PASS
- CHK3: Is the item-4 claim "no behavioural rule lost" backed by per-section evidence? — PASS (D3 table, cited lines)
- CHK4: Is item 8's meaning unambiguous? — FAIL (ambiguous) — converted to Open Question 1
- CHK5: Do any two units edit the same file without an order? — PASS (reviewer.md 1→2→5; unit-bookkeeping.sh 3→11; review-precheck.test.sh 4→12; CHANGELOG serial)
- CHK6: Is the orchestrator byte budget defined for unit 6? — PASS (adds about 110, cuts about 162; criterion at or below 16,384)
- CHK7: Will small-lane units in this clone pass `check`? — FAIL (missing) — converted to Open Question 2
- CHK8: Is each excluded follow-up named with where it went? — PASS (Risks, Open Question 3)
- CHK9: Do the units avoid `:NN` and brace forms in Affected files before unit 12? — PASS (D9)

## Follow-ups already fixed (verified at 127e22b1)
Stale "gate is live" comments (harness-integrity-gate.sh, reviewed-path-gate.sh); `tests/plan-size-cap.test.sh`
awk NR and date anchor; milestone-auditor reads Clarifications from the appendix; reviewer "both keys";
lead-programmer `.directed` paragraph; "at escalation time" in protocol and ports; trust-model row 18;
ADR-0045 records the forged `review-dispatched:` flag and the parallel-denial residual; the protocol's
small-lane list already names `fail`, `escalate` and no `check:` line (only the flag case and "its fix"
remain, unit 5); the marker-write reviewer loop is already labelled a smoke check (only the stale comment
and the local `marker_valid` copy remain, unit 14).

## Marker sweep
`bash bin/marker-audit.sh . --notes --surface=<path>` is best-effort and slow here: `agents/reviewer.md`
returned 93 lines and `agents/orchestrator.md` 211; the other surfaces did not finish within the tool
timeout. Disposition: the recent rv- and lp- PASS notes were taken from the session's follow-up harvest
(`followups.txt`) and each is placed in D7, Risks or this appendix. The older notes predate 0.32.0's
retirements and were not re-read one by one; an empty or partial sweep proves nothing.

## Tracker
Not published: this repo's plans are dispatched from contract files (publication is optional); each
contract's Retrieval line points at the plan path.
