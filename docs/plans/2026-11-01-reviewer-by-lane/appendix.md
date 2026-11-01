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
- CHK8: Does criterion rv-lanerec 1 still fail under its own `mutation:` line, given gh413's recorded classes host and vacuous? — PASS (the mutation removes the `.fail` override, and `(rv-l2)` asserts it)
- CHK9: Does criterion rv-stopgate 2 still fail under its own `mutation:` line, given the recorded class vacuous for gh413 and mw-step3? — FAIL (ambiguous) — revised in place (the mutation was "hand-edit the codex copy", which a behaviour-neutral edit survives; it now removes rule 6's flag write, which the parity test's `has_flag` cases detect)
- CHK10: Do the C-mirror criteria (which run `bin/cli.js`) still fail under their `mutation:` lines, given the recorded classes host and vacuous for gh348-4, gh360, gh409, item04-2-apply-drops and mw-step3? — PASS (reverting a generated copy makes `git diff --quiet` exit 1)
- CHK11: Do the `tests/validate.sh` criteria (recorded class vacuous for gh317, gh320, gh346-2, gh409, gh413, human-review-cleanup-1, mw-step1-3, rollout-map-1, spec2-unitA, spec2-unitB) fail under a `mutation:` line? — FAIL (missing) — revised in place (the plan now states that it is a gate over the whole suite with no mutation and never the only detector of a behaviour)

Prose-mode terminology pass (advisory): lens 1, "Writer/Reviewer split" ("only the reviewer can mark a unit done") now has a small-lane exception, so rv-scribe amends it. Lens 2: no new synonym found; "precheck PASS" is the user's own report string. Lens 3: "unit lane", "small-lane check", "dispatch-lane record" and "review-dispatched flag" are new, and the Scribe update hint carries them.

## PRD mapping (not published)
The tracker is not used for this plan; publishing is optional, and `docs/plans/` is the canonical artifact. Mapping: Goal → Problem Statement; D1-D10 → Solution; units 1-9 → User Stories; the constitution check → Implementation Decisions; the criteria in each contract → Testing Decisions; Open Questions 1-3 → Out of Scope; this appendix → Further Notes.

## Marker sweep (`bin/marker-audit.sh . --notes --surface=<path>`)
- `bin/unit-size.sh`: spec=0 code=0 untagged=0.
- `bin/unit-bookkeeping.sh`: spec=0 code=7 untagged=0. No `NOTE[spec]` line, so there is nothing to dispose of.
- Other surfaces (`hooks/scripts/dispatch-hygiene.sh`, `hooks/scripts/stop-gate.sh`, `hooks/scripts/lib/stop-gate-core.sh`, `hooks/scripts/lib/reviewer-route-gate-core.sh`, `agents/orchestrator.md`, `templates/persona-protocol.md`): the sweep runs about 1-2 minutes per surface and had not finished at checkpoint 1. The next spawn records them here. An empty sweep proves nothing, because `.claude/reviewed/` is per-clone state.
- Prior FAIL screen: there is no `.claude/reviewed/rv-*.fail`. The related `lp-escbin.fail` (contract paths listed bare or with `:line` suffixes failed `review-precheck.sh`) is why every Affected-files entry here is a full repo-relative path.
