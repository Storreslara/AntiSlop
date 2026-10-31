Unit: lp-tidy2

## Objective
Second half of the lean-pipeline tidy-up (lp-tidy is the persona-prose half): two test fixes and stale comments and docs that describe removed gates as live. Hook edits are comment lines only, no behaviour change, no version bump.
1. `tests/plan-size-cap.test.sh`: count lines with `awk 'END{print NR}'` in place of `wc -l` (a last line with no newline was not counted, so a 401-line plan passed), and in the contracts loop replace the `case "$d" in [0-9]*)` check with `[[ $d =~ ^[0-9]{8}$ ]] || continue` (a slug such as `2026-1x-01-y` printed `integer expression expected`).
2. `tests/marker-write.test.sh`: above `for id in reviewer antislop:reviewer; do`, add a comment saying that since lean-pipeline D5 both path gates allow every Bash command, so this loop, the design-constraint proof and the human-decision-gate loop below can no longer fail and are kept as smoke checks. The comment contains the words `can no longer fail`. Do not change the checks.
3. `README.md`: the `humanReviewMode` row's third cell becomes `Retired (0.32.0): nothing escalates; only session-start's microworld warning reads it.`. Replace the two sentences from `An escalated unit lands` to `(ADR-0004, ADR-0013, ADR-0039).` with: a unit that needs you reaches you as a `needs-human:` note, which the orchestrator relays with `AskUserQuestion`.
4. `docs/trust-model.md`: row 9 says `five-field contract` and that H4 checks the `Unit:` line and the four `## ` headings are present, each with a non-empty body. Row 18 keeps its number and its `self-reported` checked-by cell; its last cell starts `Retired (0.32.0): heavy-trigger.sh was deleted (lp-escbin); nothing measures a surface now.` Do not touch row 25 (lp-scribe edits it).
5. Comments only:
   - `hooks/scripts/dispatch-hygiene.sh`: line 5 `nine-element` becomes `five-field`. Replace the `H3 does not parse a Mode: advisory` sentences (about lines 74-80) with: H3 does not parse a `Mode: advisory` line, and no hook or script reads that convention since lp-joinstamp removed the route gate's parsing, so an advisory reviewer dispatch onto a PASSed unit trips H3 like any re-dispatch. In the H4 comment, `eight ## headings` becomes the five fields.
   - `hooks/scripts/harness-integrity-gate.sh`: delete `Precedent: human-decision-gate.sh:2-5.` (that gate is a stub now).
   - `hooks/scripts/reviewed-path-gate.sh`: the comment above `escalated_markers=` says `.escalated` is retired (0.32.0) and nothing writes it, so the branch catches only a marker left from an older version. The `echo "BLOCKED: ..."` string stays as it is.
6. `CHANGELOG.md`, one bullet under `## [Unreleased]` titled `**Stale tests, comments and docs are tidied (lp-tidy2).**`, listing edits 1-5.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, section "Dispatch" (lp-tidy2 line). This file is the contract of record. Dispatch after lp-tidy has PASSed and before lp-scribe. Implementer tier: sonnet.

## Affected files
- `tests/plan-size-cap.test.sh`
- `tests/marker-write.test.sh`
- `README.md`
- `docs/trust-model.md`
- `hooks/scripts/dispatch-hygiene.sh`
- `hooks/scripts/harness-integrity-gate.sh`
- `hooks/scripts/reviewed-path-gate.sh`
- `CHANGELOG.md`
- `.claude/hooks/scripts/` mirrors, only via `node bin/cli.js --update --force-render`

## Do NOT touch
- `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/`, `.claude/wiki/` (lp-scribe)
- Trust-model rows other than 9 and 18; any code line in `hooks/scripts/` (criterion 6); `hooks/hooks.json`; `eval/`
- `hooks/scripts/stop-gate.sh`, `hooks/scripts/lib/stop-gate-core.sh`, `bin/review-precheck.sh` (stop-gate hardening and the precheck parser bug are separate work)
- `agents/`, `templates/`, `adapters/` (lp-tidy)

## Acceptance criteria
1. run: `bash -c 'T=$(mktemp -d); mkdir -p $T/p $T/q/2026-1x-01-y/contracts; seq 401 | head -c -1 > $T/p/2026-11-01-x.md; echo hi > $T/q/2026-1x-01-y/contracts/u.md; PLAN_CAP_SELFTEST=0 PLANS_DIR=$T/p bash tests/plan-size-cap.test.sh >/dev/null 2>&1; echo "nonl=$?"; PLAN_CAP_SELFTEST=0 PLANS_DIR=$T/q bash tests/plan-size-cap.test.sh 2>&1 >/dev/null | wc -l; rm -rf $T; f=tests/plan-size-cap.test.sh; grep -qE "awk.*NR" $f && grep -qF "[0-9]{8}" $f && echo struct-ok'`
   exit: 0
   stdout: `nonl=1` then `0` then `struct-ok`
   mutation: put `lines=$(wc -l < "$f")` back → first line `nonl=0`, no `struct-ok`.
2. run: `bash -c 'grep -cF "can no longer fail" tests/marker-write.test.sh || true'`
   exit: 0
   stdout: `1`
   mutation: delete the comment → `0`.
3. run: `bash -c 'grep -cE "human-review/|heavy units are escalated|DECISION. file" README.md; grep -E "^\| .humanReviewMode. \|" README.md | grep -c "Retired (0.32.0)" || true'`
   exit: 0
   stdout: `0` then `1`
   mutation: restore the `An escalated unit lands` sentence → first line `2`.
4. run: `bash -c 'f=docs/trust-model.md; grep -cE "nine-element|eight .## . headings" $f; grep -E "^\| 18 \|" $f | grep -c "Retired (0.32.0)"; node tests/trust-model-bijection.test.js >/dev/null 2>&1 && echo bij-ok'`
   exit: 0
   stdout: `0` then `1` then `bij-ok`
   mutation: change row 18's checked-by cell away from `self-reported` → no `bij-ok`, exit 1.
5. run: `bash -c 'grep -cE "nine-element|eight .## . headings|stamp suppression" hooks/scripts/dispatch-hygiene.sh; grep -c "Precedent: human-decision-gate" hooks/scripts/harness-integrity-gate.sh; grep -c "Only the reviewer writes .escalated" hooks/scripts/reviewed-path-gate.sh; grep -cF "no hook or script reads" hooks/scripts/dispatch-hygiene.sh || true'`
   exit: 0
   stdout: `0` then `0` then `0` then `1`
   mutation: restore line 5 of dispatch-hygiene.sh → first line `1`.
6. run: `bash -c 'git diff "$(git log --format=%H -1 --grep="(lp-orch)")" HEAD -- hooks/scripts | grep -E "^[+-]" | grep -vE "^(\+\+\+|---)" | grep -vcE "^[+-][[:space:]]*(#|$)" || true'`
   exit: 0
   stdout: `0`
   mutation: change one code line in reviewed-path-gate.sh (for example the `BLOCKED` echo) → `2`.
7. run: `{ bash tests/plan-size-cap.test.sh && bash tests/marker-write.test.sh && node tests/doc-relative-links.test.js && bash tests/dispatch-hygiene.test.sh && bash tests/harness-integrity-gate.test.sh && bash tests/reviewed-path-gate.test.sh; } >/dev/null 2>&1`
   exit: 0
   stdout: empty
   note: a preservation check; it passes today by design.
8. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` (C-mirror)
   exit: 0
   stdout: empty
9. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; C-full, run once by the reviewer after the final commit)
   exit: 0
   stdout: empty

## Pre-resolved context
- Today (1227fa2a): criterion 1 prints `nonl=0`, `1`, no `struct-ok`; 2 gives `0`; 3 gives `3`,`0`; 4 gives `1`,`0`,`bij-ok`; 5 gives `3`,`1`,`1`,`0`; 6 gives `0`; 7 passes.
- `tests/trust-model-bijection.test.js` pins 10 `self-reported` cells and requires every hook-registered gate in the map, so row 18 stays a row.
- No adapter copies of the three gate scripts exist; `.claude/hooks/scripts/` mirrors regenerate.
- Row 20 of `docs/trust-model.md` still describes the human-decision gate as live; it is out of scope here (the bijection test needs the script named).

## Escalation
If criterion 7 fails on a check this unit did not mean to change, stop and report it. If a gate blocks a write, report the path and the refusal text, and never route around it.
