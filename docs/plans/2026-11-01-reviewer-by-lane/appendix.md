# Appendix: 2026-11-01-reviewer-by-lane

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-11-01 Functional scope & success criteria: Q Which lanes keep the reviewer? → A: small skips it, medium and full keep it (dispatch default, accepted as D1)
- 2026-11-01 Domain entities / data model: Q Where does the gate read a writer's lane from, given that a writer can edit `.claude/bookkeeping/`? → A (self-resolved): a dispatch-time snapshot in `.claude/reviewed/dispatch-lane.log`, joined by toolUseId and prompt hash (D3)
- 2026-11-01 Non-functional attributes (perf, security, scale): Q Does the exemption weaken medium or full units, or let a writer move itself to the small lane? → A (self-resolved): no; a miss fails toward the flag, the first record wins, and medium and full are unchanged (D3, Risks "Trust")
- 2026-11-01 Edge cases / failure handling: Q What happens after a small unit's check fails or cannot decide? → A (self-resolved, Open Question 1): the unit moves to medium (D2)
- 2026-11-01 Edge cases / failure handling: Q What about agent-teams mode, where `task-gate.sh` requires a `.pass`? → A (self-resolved, Open Question 2): the exemption is off there (D7)
- 2026-11-01 Technical constraints & tradeoffs: Q Do both the lane exemption and recommendation 3 fit in one plan? → A (self-resolved): yes, as separate later units (rv-mainstop, rv-routemark, rv-flagprose) after the lane units
- 2026-11-01 Terminology consistency: Q Does "only the reviewer can mark a unit done" (CONTEXT.md, "The Writer/Reviewer split") still hold? → A (self-resolved): no, a small-lane unit is done on `check: pass`; rv-scribe amends the entry and adds "unit lane" and "small-lane check"
- 2026-11-01 Edge cases / failure handling: Q After a small unit's check fails, does the unit stay small or move to medium? → A: moves to medium, so the fix gets the reviewer (user, Open Question 1; matches D2)
- 2026-11-01 Edge cases / failure handling: Q Do small units skip the reviewer in agent-teams mode too? → A: no; agent-teams mode keeps the reviewer and `task-gate.sh` is unchanged (user, Open Question 2; matches D7)
- 2026-11-01 Functional scope & success criteria: Q Does the scribe close a small unit's tracker issue? → A: no; it stays on the `open:` line and `agents/scribe.md` is unchanged (user, Open Question 3; matches D8)
- 2026-11-01 Edge cases / failure handling: Q The rv-tools PASS marker carries nine notes (zero criteria, `sensitive:` lines, uncommitted state, `--at-least` after `--contract`, flag TOCTOU and symlinks, C7 cwd, C6 stdin, non-numeric judge, rv-prose command form). Fix them before the lane goes live, or carry them? → A: "Harden first" (user); new unit rv-harden (1b), before rv-stopgate
- 2026-11-01 Edge cases / failure handling: Q Does an empty range (baseline == HEAD) give fail or escalate? → A (self-resolved): escalate `empty-range`; a clean empty range is a wrong baseline or a "no change warranted" outcome, not a defect the writer can fix
- 2026-11-01 Technical constraints & tradeoffs: Q Reject arguments after `--contract <path>`, or parse `--at-least` anywhere? → A (self-resolved): reject (exit 2), the smaller edit

## Constitution check (.claude/constitution.md v1.2.0)
- P1 "Verify, don't assume": satisfied. Every unit has runnable criteria, and the direct criteria 1 and 2 of rv-tools were run against HEAD and fail there.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The replacement for the reviewer is a script (`unit-bookkeeping.sh check`), and the mirrors change only through `node bin/cli.js --update --force-render`.
- P3 "Version-stamp discipline": satisfied. Content units add `[Unreleased]` bullets only, and a single release unit, rv-release, ships 0.33.0.
- P5 "`tests/validate.sh` is the merge gate": satisfied. It is the last criterion of every unit.
- (P4 is a SHOULD: the new orchestrator line keeps "(if present)".)

## Self-check
- CHK1: Is the lane of a writer whose dispatch has no record defined? — PASS (D3: every miss writes the flag)
- CHK2: Do D2 and plan unit 1 agree on what `check` does after `fail` and `escalate`? — PASS
- CHK3: Is the gate's behaviour under `reviewGating.mode: off` and with the D6 marker check stated for small units? — PASS (D4; rv-stopgate cases rv-s2 and rv-s6)
- CHK4: Is the `dispatch-baseline.log` format left unchanged, given the exact-line matches in `tests/writer-scope-gate.test.sh`? — PASS (D4; rv-lanerec criterion 2)
- CHK5: Is each gate that misbehaves for a small unit named? — PASS (Risks: task-gate, H3, marker audits, refused reviewer dispatch)
- CHK6: Does every unit that edits orchestrator prose carry both byte caps? — FAIL (missing) — revised in place (unit 4 states the caps and unit 7 references them; their contracts carry them as criteria)
- CHK7: Do the agent-teams carve-out and the small bullet in the orchestrator agree? — PASS (unit 4 text "in agent-teams mode every unit does")
- CHK12: Do plan unit 1b and the rv-harden contract agree on the rule order (C1, C2, C2a, C2b, C3, C4, C4a, C5, C6, C7, C8) and on each outcome word? — PASS
- CHK13: Does each of the nine rv-tools notes have a criterion that detects its fix? — PASS (notes 3 and 5: rv-harden criterion 2 and `(rv-h1)`, `(rv-h3)`, `(rv-h4)`; note 4: `(rv-h2)`, `(rv-e3)`; note 7: criteria 1 and 3; note 8: `(rv-h8)`, `(rv-h9)`; note 9: `(rv-h7)` plus Risks; note 10: `(rv-h6)`; line 15: `(rv-h5)`; note 6: D2, unit 4 and rv-prose pin `(rv-o4)`)
- CHK14: Do rv-harden criteria 1 and 2 fail at HEAD (cf4435d6)? — PASS (run 2026-11-01: criterion 1 printed `lane: small files=1 reason=contract` then `rc=0 n=2`; criterion 2 printed `check: pass` twice)
- CHK15: Can a stub case's mutation be masked by the new C7 no-criteria branch? — FAIL (ambiguous) — revised in place (plan unit 1b and the contract require `criterion 1: pass exit=0` in every stub case under `--contract` except no-criteria)
- CHK16: Is the outcome of a `check` call cut off at the 600000 ms ceiling defined? — PASS (Risks: no `check:` line is not `pass`, so not done)
- CHK8: Does criterion rv-lanerec 1 still fail under its own `mutation:` line, given gh413's recorded classes host and vacuous? — PASS (the mutation removes the `.fail` override, and `(rv-l2)` asserts it)
- CHK9: Does criterion rv-stopgate 2 still fail under its own `mutation:` line, given the recorded class vacuous for gh413 and mw-step3? — FAIL (ambiguous) — revised in place (the mutation was "hand-edit the codex copy", which a behaviour-neutral edit survives; it now removes rule 6's flag write, which the parity test's `has_flag` cases detect)
- CHK10: Do the C-mirror criteria (which run `bin/cli.js`) still fail under their `mutation:` lines, given the recorded classes host and vacuous for gh348-4, gh360, gh409, item04-2-apply-drops and mw-step3? — PASS (reverting a generated copy makes `git diff --quiet` exit 1)
- CHK11: Do the `tests/validate.sh` criteria (recorded class vacuous for gh317, gh320, gh346-2, gh409, gh413, human-review-cleanup-1, mw-step1-3, rollout-map-1, spec2-unitA, spec2-unitB) fail under a `mutation:` line? — FAIL (missing) — revised in place (the plan now states that it is a gate over the whole suite with no mutation and never the only detector of a behaviour)

Prose-mode terminology pass (advisory): lens 1, "Writer/Reviewer split" ("only the reviewer can mark a unit done") now has a small-lane exception, so rv-scribe amends it. Lens 2: no new synonym found; "precheck PASS" is the user's own report string. Lens 3: "unit lane", "small-lane check", "dispatch-lane record" and "review-dispatched flag" are new, and the Scribe update hint carries them.

## PRD mapping (not published)
The tracker is not used for this plan; publishing is optional, and `docs/plans/` is the canonical artifact. Mapping: Goal → Problem Statement; D1-D10 → Solution; units 1, 1b and 2-9 → User Stories; the constitution check → Implementation Decisions; the criteria in each contract → Testing Decisions; Open Questions 1-3 → Out of Scope; this appendix → Further Notes.

## Marker sweep (`bin/marker-audit.sh . --notes --surface=<path>`)
- `bin/unit-size.sh`: spec=0 code=0 untagged=0.
- `bin/unit-bookkeeping.sh`: spec=0 code=7 untagged=0. No `NOTE[spec]` line, so there is nothing to dispose of.
- `hooks/scripts/lib/reviewer-route-gate-core.sh`: spec=1 code=1 untagged=0. The NOTE[spec] (blf-8) is about the position of the advisory `Mode:` line and about review-join stamps. Disposition: obsolete. lp-joinstamp removed the core's stamp parsing, and the current `agents/orchestrator.md` already puts `Mode: advisory` second and `Implementer tier:` third. rv-routemark needs nothing for it.
- `hooks/scripts/dispatch-hygiene.sh`: spec=1 code=6 untagged=14. NOTE[spec] fc-2 (orchestrator prose under-describes H1/H2): not about the lane record; not adopted.
- `hooks/scripts/stop-gate.sh`: spec=1 code=0 untagged=48. NOTE[spec] rp-u2 ("a loop-guarded stop never blocks" comment): rv-stopgate does not touch the loop guard; not adopted.
- `hooks/scripts/lib/stop-gate-core.sh`: spec=4 code=1 untagged=5. gate-audit-step3 (stale `stop-gate.sh:188-198` / `$verdict_gate_mode` citation, now in `docs/harness-glossary.md:1847`, entry "Review-join stamp condition"): outside this plan; deferred, not folded into rv-scribe. item19-1 and lo2-4: unrelated to rules 3 and 6; not adopted. lp-scribe (ADR-0044 says flags clear only on a reviewer stop, but `skip:` deletes at main Stop): adopted as a caution for rv-scribe, whose ADR-0045 must not repeat that sentence; the rv-scribe criteria do not test it.
- `agents/orchestrator.md`: spec=77 code=44 untagged=129, nearly all from closed plans. None names the "Lane routing" section, the small bullet or the `defer:` sentence that rv-prose and rv-flagprose replace. rgo-4 (the scribe closes only on a quoted PASS line) agrees with D8. Not adopted.
- `templates/persona-protocol.md`: spec=30 code=21 untagged=51. ptr-u12 (orchestrator points to "Review ownership" for the inert/armed hook list) and esf-flag-prose (no test anchors the flag timing prose) touch the sections rv-prose and rv-flagprose edit; neither changes those units' text. Their criterion 4 was checked: renaming either heading makes it exit 1. Not adopted.
- `templates/protocol-digest.md`: spec=2 code=2 untagged=1. hdc-2 (the digest is over its own "under ~15 lines" budget): rv-flagprose rewrites the flag line in place. htd-5 (the "2 FAILs" line): already fixed at HEAD. Not adopted.
- rv-harden (2026-11-01, after rv-tools): `bin/unit-size.sh` spec=0 code=1; `bin/unit-bookkeeping.sh` spec=0 code=8; no `NOTE[spec]` line on either, so nothing to dispose of. The rv-tools PASS notes (in `.claude/reviewed/rv-tools.pass`) are the unit's input, all adopted (CHK13).
- No untagged line names an rv- unit, so no undispatched step is affected. An empty sweep proves nothing, because `.claude/reviewed/` is per-clone state.
- Criteria check (2026-11-01, contracts at 76e8c374): every non-long criterion of the six later contracts was run through `review-precheck.sh --criterion <n>`. Each printed a `pass` or `fail` line, none printed `judge` or `no criterion`. The targeted criteria fail at HEAD. The guards (stop-gate parity, review-gating-off, protocol parity, cli mirror) pass. Mutations checked by hand: deleting the codex core `defer:` case makes the parity test exit 1. Dropping the route core's mode-off test makes `review-gating-off.test.sh` exit 1.
- Prior FAIL screen: there is no `.claude/reviewed/rv-*.fail`. The related `lp-escbin.fail` (contract paths listed bare or with `:line` suffixes failed `review-precheck.sh`) is why every Affected-files entry here is a full repo-relative path.
