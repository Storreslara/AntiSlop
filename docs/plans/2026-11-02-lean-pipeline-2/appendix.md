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
- 2026-11-01 Functional scope & success criteria: Q Does "item 8" mean the H4 warning or the harness fixes? → A: both, units 7 and 8 (user, Open Question 1)
- 2026-11-01 Edge cases / failure handling: Q Commit or ignore the untracked `eval/reports/`? → A: committed in 90a3a5b2 (user, Open Question 2); its Risks and recommendation text removed
- 2026-11-01 Edge cases / failure handling: Q Stop-gate hardening (a)-(d) now or later? → A: (a)-(c) now as opus full-lane units after l2-ports; (d) accepted as the known residual (user, Open Question 3)
- 2026-11-01 Functional scope & success criteria: Q Were the four rules the lp-orch cut deleted intended? → A: yes (user); dropped from the plan
- 2026-11-01 Technical constraints & tradeoffs: Q One hardening unit or two? → A (self-resolved): two; (a) and (c) are both in `stop-gate-core.sh` rule 5-6 (l2-sg1), (b) is in `dispatch-hygiene.sh` (l2-sg2), so (a) and (b) do not share code
- 2026-11-01 Terminology consistency: Q Is "small repo" a new term next to "unit lane"? → A (self-resolved): yes, a harness term for `docs/harness-glossary.md` (unit 15), distinct from the small lane
- 2026-11-01 Edge cases / failure handling: Q What does the reviewer do when its precheck packet reads `br blast-radius: unavailable`? → A (self-resolved): the script counts as missing, so the existing explorer trigger applies (one added sentence in contract l2-revprose)

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
- CHK4: Is item 8's meaning unambiguous? — FAIL (ambiguous) — converted to Open Question 1 (answered 2026-11-01: both)
- CHK5: Do any two units edit the same file without an order? — PASS (reviewer.md 1→2→5; unit-bookkeeping.sh 3→11; review-precheck.test.sh 4→12; CHANGELOG serial)
- CHK6: Is the orchestrator byte budget defined for unit 6? — PASS (adds about 110, cuts about 162; criterion at or below 16,384)
- CHK7: Will small-lane units in this clone pass `check`? — FAIL (missing) — converted to Open Question 2 (answered 2026-11-01: committed)
- CHK8: Is each excluded follow-up named with where it went? — PASS (Risks, Open Question 3)
- CHK10: Does each hardening change fail closed when its own write or check fails? — PASS (10a: replace, then create, then block; 10b: no touch on exit 2 or a crash)
- CHK11: Do 10b and unit 8 edit `dispatch-hygiene.sh` in a defined order? — PASS (8 before 10b)
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
`bash bin/marker-audit.sh . --notes --surface=<path>` (best-effort; about 2 minutes per surface) returned
these `NOTE[spec]`/`untagged` line counts: `agents/reviewer.md` 93, `agents/orchestrator.md` 211,
`bin/cli.js` 208, `bin/unit-bookkeeping.sh` 6, `bin/review-precheck.sh` 5, `templates/persona-protocol.md`
84, `hooks/scripts/lib/stop-gate-core.sh` 10, `hooks/scripts/lib/reviewer-route-gate-core.sh` 3,
`hooks/scripts/lib/unit-scope.sh` 1, `hooks/scripts/dispatch-hygiene.sh` 16,
`hooks/scripts/reviewed-path-gate.sh` 13, `adapters` 112, `eval/abtest` 17, `CONTEXT.md` 528.
Disposition: the recent rv- and lp- PASS notes come from the session's follow-up harvest (`followups.txt`)
and each is placed in D7, Risks or this appendix. The older notes predate 0.32.0's retirements and were
not re-read one by one. Contract spawns for units 3, 4, 9, 11 and 12 re-read their surface's lines (all
under 11). An empty or partial sweep proves nothing.

## Tracker
Not published: this repo's plans are dispatched from contract files (publication is optional); each
contract's Retrieval line points at the plan path.

## Contract criteria verification (l2-prebr, l2-revprose, l2-orch; 2026-11-01)
Each criterion ran through `bin/review-precheck.sh <unit> HEAD --contract <file> --criterion <n>` in a throwaway clone of 50483180 with the three contracts committed; every criterion parsed. The `validate.sh` criteria (deferred long) were not run.
- At HEAD (before the work): l2-prebr 1, 2, 4 fail; 3 and 5 pass (3 is a guard: today the flag is itself a usage error). l2-revprose 1, 2, 4 fail; 3 and 5 pass (3 keeps the existing `(j)` pins). l2-orch 1, 2 (`0 4` then `0 4`), 3, 5 fail; 4 (source 16,384, deployed 40,032) and 6 pass.
- With the work simulated in the clone: l2-orch's quoted edits plus an N21 section → 2, 3, 4 pass (source 16,340, deployed 39,988), `tests/unit-size.test.sh` exits 0. l2-revprose's edits rendered, with the Pending-review section removed from the deployed reviewer to stand in for l2-slim → 2, 3 pass, `tests/blast-radius.test.sh` has no FAIL. A minimal `--blast-radius` in `review-precheck.sh` → l2-prebr 2, 3 pass.
- Byte sizes: l2-prebr 2,958; l2-revprose 3,067; l2-orch 2,852.

## Contract criteria verification (l2-abfix, l2-h4, l2-gatemsg; 2026-11-01)
Each criterion ran through `bin/review-precheck.sh <unit> HEAD --contract <file> --criterion <n>` in a throwaway clone of fdfb2981 with the three contracts committed; every criterion parsed. The `validate.sh` criteria (deferred long) were not run.
- At HEAD (before the work): l2-abfix 1-5 fail. l2-h4 1-4 fail (2 prints `5`; 3 prints the `WARNING: H4:` line), 5 passes (guard). l2-gatemsg 1, 2, 4 fail (2 prints today's text twice), 3 passes (guard: the six core copies are identical today).
- With the work simulated in the clone: every criterion passes. l2-h4's criterion 5 passes only after the re-render's `.claude/persona-config.json` hash update is committed with the rest. `tests/abtest-fixtures.test.sh` (7 passed) and `tests/abtest-checks.test.sh` (332 passed) still pass with `CONTEXT.md` added to both allowed-paths files. The proposed `(l2-g3)`/`(l2-g4)` tests pass against today's join, so they pin behaviour and need no code change.
- Mutations confirmed: l2-abfix 1 (drop the `escalated_markers` test → exit 1), 2 (skip the checks test → `false complete 1`); l2-h4 1 and 3 (restore the warning → exit 1 / `WARNING:` line); l2-gatemsg 1 (drop `chmod 644` → exit 1), 2 (keep today's text → line 2 unchanged), 3 (one core not re-rendered → `3`).
- `tests/abtest-arms.test.sh` pins none of l2-abfix's files (grep for `make-row`, `README`, `allowed`, `stalled`, `run_pass`: no hit), so it is not edited.
- Byte sizes: l2-abfix 3,064; l2-h4 3,037; l2-gatemsg 3,069.

## Contract criteria verification (l2-ports, l2-sg1, l2-sg2; 2026-11-01)
Each criterion ran through `bin/review-precheck.sh <unit> HEAD --contract <file> --criterion <n>` in throwaway clones of 03cc0f13 with the three contracts committed; every criterion parsed. The `validate.sh` criteria (deferred long) were not run.
- At HEAD (before the work): l2-ports 1-3 fail (2 prints `0` then `0`: an exported `writer_lane=small` suppresses the flag on both ports today), 4 passes (guard). l2-sg1 1, 2, 4 fail (2 prints `rc=0 0 0 0`: the sentinel is honoured over a forged `.pass`), 3 passes (guard: copies identical today). l2-sg2 1 and 3 fail, 2 prints `hyg=2 stamp=1 stop=0` (a blocked dispatch re-touches the stamp, so the forged marker stops tripping), 4 passes (guard).
- Found while probing: today a flag path that is a directory makes the writer's stop exit 1 (a non-blocking hook error) and the main Stop skips it, and a symlinked flag path to an existing file is kept as is. Hence `(l2-s7)`, `(l2-s8)` and the "unless the path is a dir" rule in l2-sg1 (`mv -f` onto a symlink to a directory would move the file into that directory).
- With the work simulated in the clone (both ports' `writer_lane=""` and dead-line deletion; a `state_replace_pending_review` per the contract; the D6 check moved above the WIP rule; an `EXIT`-trap stamp; minimal `(l2-p1)`, `(l2-s1)`-`(l2-s8)`, `(l2-c1)`, `(l2-c2)`, `(l2-d1)`-`(l2-d5)` tests; re-render; CHANGELOG bullets): every criterion passes, and the existing stop-gate, state-access, parity and dispatch-hygiene cases stay green.
- Mutations confirmed: l2-ports 1 (no cursor line → exit 1), 2 (no codex line → `0` then `1`); l2-sg1 1 (rule 6 on `state_write_pending_review` → s3, s4, s8 FAIL; s7 still passes because the `|| block` catches the failed write); l2-sg2 1 (touch at the match → d1, d4 FAIL), 2 (→ `hyg=2 stamp=1 stop=0`).
- Writer note: `tests/stop-gate.test.sh` already uses project names `s1`-`s5`; new cases need distinct names (a collision makes `ln -s` fail under `set -e`).
- Byte sizes: l2-ports 2,985; l2-sg1 3,072; l2-sg2 2,949.
