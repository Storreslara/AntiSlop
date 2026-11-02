# Appendix: residuals (2026-11-03)

Plan: `docs/plans/2026-11-03-residuals.md`. Baseline `b93658d3`.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-11-02 Functional scope & success criteria: Q Which of the ten listed items are still open at the
  baseline? → A (self-resolved): item 8 (all eight sub-items), item 10 "moves to medium" and item 6 lines
  15-16 were already fixed (plan D1, with line cites); the rest are open and each maps to a unit.
- 2026-11-02 Functional scope & success criteria: Q Item 10 asks to "decide" the `Mode: advisory`
  convention: document as prose-only or enforce? → A (self-resolved, the user delegated the choice):
  prose-only, honoured by the reviewer's gating bullet; glossary corrected (plan D6). Alternative named in
  the plan's Open Questions note.
- 2026-11-02 Non-functional attributes (perf, security, scale): Q Item 8's remaining sub-item, `check`'s total
  run time over the 600 s Bash ceiling: fix or accept? → A (self-resolved): accept; the cancelled call prints
  no `check:` line, which the protocol routes to `medium` (fails closed; plan D2c).
- 2026-11-02 Edge cases / failure handling: Q Item 2: escalate on any submodule, or scan inside each? → A
  (self-resolved): escalate `submodule` (plan D4); fail closed and needs no recursion.
- 2026-11-02 Edge cases / failure handling: Q Item 3: how does the reviewer stop a false `off` header from
  withholding markers? → A (self-resolved, from the l2-revprose PASS note): it runs the one `jq` command
  when the header says `off`, as when it is absent (plan D5).
- 2026-11-02 Technical constraints & tradeoffs: Q Item 5's no-script fallback: what replaces "write
  'defer: <reason>' ... into a flag"? → A (self-resolved): route to the user (plan D7).
- 2026-11-02 Technical constraints & tradeoffs: Q Does any unit need orchestrator prose? → A
  (self-resolved): no; D6 keeps the orchestrator's pinned `Mode: advisory` sentence as is (plan D8).

Terminology check (prose mode, `CONTEXT.md` and `docs/harness-glossary.md` indexes): lens 1 none (plan uses
"small-lane check" only as `unit-bookkeeping.sh check`, never bare "the check" for it); lens 2 none; lens 3
none new ("writer-dispatch stamp", "marker check", "advisory dispatch" are harness-glossary entries).

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume": satisfied. Each D1 closure and each D3 reproduction cites lines or a measured
  run at the baseline; every criterion was run at the baseline (expected mutation values recorded).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Item 2 and item 1 are script fixes;
  item 3 adds one deterministic `jq` call to the reviewer.
- P3 "Version-stamp discipline": satisfied. rs-release bumps to 0.35.0 with its CHANGELOG entry in the same
  commit (criterion 4); content units add `[Unreleased]` bullets only.
- P5 "`tests/validate.sh` is the merge gate": satisfied. It is every unit's last criterion.
- (P4 is a SHOULD: no optional-persona reference is added.)

## Self-check
- CHK1: Does every numbered item map to a unit or a D1/D2 record? — PASS (1 rs-stamp; 2 rs-check; 3
  rs-prose; 4 rs-tokens; 5 rs-corelib; 6 rs-release + D1; 7 rs-docs + rs-corelib(c); 8 D1 + D2c; 9
  rs-corelib(d) + D2e; 10 D6 rs-prose/rs-docs, D1, rs-prose spec-master, D2d)
- CHK2: Do rs-corelib and rs-docs agree on the umask wording? — PASS (both "uses the umask")
- CHK3: Is the reviewer.md byte budget defined? — PASS (D8, rs-prose criterion 3, at most 24,630)
- CHK4: Do any two units edit the same file without an order? — PASS (CHANGELOG serial per D10;
  harness-glossary and CONTEXT only rs-docs; reviewer.md only rs-prose)
- CHK5: Does rs-docs's citation fix depend on files another unit edits? — PASS (`review-precheck.sh`,
  `unit-scope.sh`, `reviewed-path-gate.sh` are in no unit's files)
- CHK6: Does rs-stamp criterion 2 fail at the baseline? — PASS (measured `TERM 1 INT 1 HUP 1`; `0 0 0`
  with the traps in a scratch copy)
- CHK7: Is every user-accepted residual recorded? — PASS (D2a, D2b; rs-docs criterion 3 counts 4)
- CHK8: Is the orchestrator byte cap protected? — PASS (D8; every unit lists `agents/orchestrator.md` or
  `agents/` under Do NOT touch, or does not touch persona sources)
- CHK9 (replay, gh413 `vacuous`, files `dispatch-hygiene.sh`, `stop-gate-core.sh`): Do rs-stamp criteria 1-2
  and rs-corelib criteria 1-3 still fail under their own `mutation:` lines? — PASS (each names a FAIL output)
- CHK10 (replay, mw-step3, spec2-unitA, spec2-unitB `vacuous`/`host`, `stop-gate-core.sh`): same question for
  rs-corelib criterion 1? — PASS (stale copy → second line `0 1 0`)
- CHK11 (replay, 18 units incl. gh288-1, gh307, gh317, gh413 on `agents/reviewer.md`/`spec-master.md`): Do
  rs-prose criteria 1, 2 and 4 fail under their mutations? — PASS (baseline measured `0 0 0 1 1 0 0 0 1 1`)
- CHK12 (replay, 22 units on `CHANGELOG.md`/`plugin.json`, incl. gh313, gh320, gh409 `version`/`vacuous`):
  Do rs-release criteria 1-7 fail under their mutations? — PASS (criterion 7 baseline `1 0 0`)

## Marker sweep
One run, all plan surfaces as repeated `--surface` (dispatch-hygiene.sh, stop-gate-core.sh, state-access.sh,
reviewer-route-gate, unit-bookkeeping.sh, token-usage, agents/reviewer.md, spec-master.md, adr/0045,
adr/0046, CHANGELOG.md, harness-glossary.md, wiki/, `Mode:`): 750 note lines over 782 markers (spec 231,
code 188, untagged 331). Disposition: the l2-, rv- and lp- notes were read; those named in the request are
in units; two co-located ones are added (D9 l2-abfix bullet; D5 "or wrong", l2-revprose). Not taken (outside
the request): l2-gatemsg flag spelling (`defer|skip` vs `<defer|skip>`, cosmetic), l2-ckhard grep exit sense
at `unit-bookkeeping.sh:122` (fails closed overall), l2-ports reviewer-route-gate.sh port header comment,
l2-revprose "missing or failed" `br` wording, the lean-pipeline-2 appendix omission of
`spec-master.md:123/:154` (closed plan), and the lp-orch NEEDS-HUMAN on four deleted orchestrator rules
(still in `followups.txt`; relay to the user). Older notes predate 0.32.0 and were not re-read. An empty
or partial sweep proves nothing.

## Tracker
Not published: contracts are dispatched from files; each contract's Retrieval line points at the plan path.
