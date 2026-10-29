# Cosmetic close-out of the refutation-pass and tg-u1/tg-u2 review notes

Date: 2026-10-29. Author: spec-master (unit cos-spec). Fast path: 5 units, contracts under
`docs/plans/2026-10-29-cosmetic-closeout/contracts/`.

## Goal
Close the non-blocking review notes left by the refutation-pass units (rfp-u2b to rfp-u7e) and by tg-u1/tg-u2,
grouped by file family, without changing any gate's behaviour except the three precheck fixes the user authorised:

- G1. The glossaries define "verdict block", "dispatch message", "multi-part stdout spec" and `judge`, say what both
  senses of "FAIL block" are, and the FAIL ground entry names every source of a FAIL ground (cos-u5).
- G2. `agents/reviewer.md` and its codex and cursor ports say "FAIL ground", not "FAIL reason"; the reviewer's Verdict
  bullet no longer opens with a bare "ONLY the verdict"; the On INSUFFICIENT-CONTEXT bullet says the `.blocked`
  marker carries no REFUTED defect (wording only) (cos-u3).
- G3. The `eval/refutation-replay/` docstrings and comments match what the code does, and `label.py` refuses a
  `MIN_REAL` below 1 (cos-u4).
- G4. `bin/review-precheck.sh`: a multi-part stdout spec fails on extra trailing blank lines, accepts any run of
  spaces around `then`, and prints an unambiguous mismatch message when an output line holds a backslash, backtick,
  CR or tab; "`A` then `B` (two lines)" stays judge (cos-u2).
- G5. `contracts/tg-u2.md` no longer holds stale criteria: run with `--fix-contract tg-u2-fix1.md`, the precheck reads
  `result=pass` (cos-u1).

Goal-to-criterion map (every clause above has a criterion): G1 -> cos-u5 criteria 1-6; G2 -> cos-u3 criteria 1-3;
G3 -> cos-u4 criteria 1-4; G4 -> cos-u2 criterion 1 (cases 8-12 and case 5); G5 -> cos-u1 criterion 1.

## Context
Every item in the dispatch was checked against the tree at ab174935 (2026-10-29). What was found:

| Item | Source note | State at ab174935 | Disposition |
|---|---|---|---|
| 1a "dispatch message" entry | tg-u2.pass NOTE[spec] | absent from both glossaries | cos-u5, in `docs/harness-glossary.md` (gate mechanics) |
| 1b "verdict block" entry | rfp-u7b.pass NOTE[spec] | absent; used at `agents/reviewer.md:148` | cos-u5, in `CONTEXT.md` next to FAIL block |
| 1c "multi-part stdout spec", `judge` | tg-u1 review | absent | cos-u5, in `docs/harness-glossary.md`, after cos-u2 lands |
| 1d two meanings of "FAIL block" | rfp-u7b.pass NOTE[spec] | `CONTEXT.md:1077` = on-disk block; `agents/reviewer.md:133,253,270` = the FAIL section of the returned message | cos-u5 adds the second sense to the entry; reviewer.md keeps its wording (pinned by `tests/persona-prose-pins.test.sh:84`) |
| 1e `_Avoid_: FAIL reason` clash | rfp-u7a.pass NOTE[spec] | `CONTEXT.md:1101` avoids it; reviewer.md 4 uses (54, 55, 64, 71), codex 3, cursor 3, `tests/unit-scope-prose.test.sh:16-17` pins 2 | cos-u3 renames to "FAIL ground" in the persona, both ports and the pins; the glossary keeps `_Avoid_` |
| 1f "Only ... make one" sentence | rfp-u7a.pass NOTE[spec] | `CONTEXT.md:1097-1098` misses the uncommitted-tree FAIL (On PASS bullet, reviewer.md:196-199) and the constitution MUST ground (reviewer.md:69-71) | cos-u5 |
| 1g FAIL block entry missing the refutation line | rfp-u3.pass NOTE[spec] | already fixed (`CONTEXT.md:1085`) | dropped |
| 2a reviewer.md ~127 "ONLY the verdict" | rfp-u7b.pass NOTE[spec] | still `message is ONLY the verdict.` at line 128 | cos-u3, persona only: the ports have neither advisory sections nor a STATUS line, so "ONLY the verdict" is accurate there |
| 2b `.blocked` carries no REFUTED defect | rfp-u7b.pass NOTE[code] | undocumented | cos-u3, persona only (the ports run no refutation pass) |
| 2c Verdict bullet missing the `refutation:` line; "nothing more" tension | rfp-u3, rfp-u6a | already fixed by rfp-u6a/rfp-u7b (reviewer.md:132, 147-149) | dropped |
| 3a score.py module docstring last line | rfp-u7c, rfp-u6b | still "Without --gate it exits 0 unless the input is bad"; the line before it says a closed stdout "ends in a traceback", which is false (measured: an unwritable stdout exits 120 with "Exception ignored on flushing sys.stdout", no traceback) | cos-u4 fixes both sentences |
| 3b score() docstring | rfp-u7c.pass NOTE[code] | `score()` has no docstring and needs rows from `load()` | cos-u4 adds one |
| 3c guard.py `:..` over-refusal; docstring vs Glob/Grep | rfp-u7e.pass NOTE[code] x2 | `--grep=a:..`, `--format=%h:..`, Glob `src/a:../*`, Grep glob `a:..` all exit 2; docstring describes only Bash | cos-u4: documented and pinned, not narrowed (Open Question 2) |
| 3d label.py comment, message, MIN_REAL | rfp-u7d.pass NOTE[code] x3 | comment silent on SystemExit/KeyboardInterrupt; message is type name only; `MIN_REAL = 0` and `-5` are served | cos-u4 |
| 4a trailing blank lines | tg-u1.pass NOTE[code] | `printf '0\nrc=0\n\n\n'` passes `` `0` then `rc=0` `` | cos-u2 (sentinel capture) |
| 4b double space before "then" | tg-u1.pass NOTE[code] | always a false fail | cos-u2 |
| 4c mismatch message at line 99 | tg-u1.pass NOTE[code] | ambiguous with a backtick or CR | cos-u2 |
| 5 tg-u2.md criteria 1 and 2 | tg-u2.pass NOTE[spec] | criterion 1 stale (`ac=6`, tree prints `ac=11`); criterion 2 still correct (prints `4`); criterion 6 (`<first tg-u2 commit>^..HEAD`) turns stale as soon as cos-u3 touches `agents/` | cos-u1 corrects 1 and 6; 2 is left as it is |

Measured on scratch clones of ab174935 (spec-master, this session), with every contract's edits applied:
`ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh` exits 0 (OK=3442 FAIL=0) with cos-u3 alone committed, and
exits 0 with cos-u2, cos-u3 and cos-u4 committed. Uncommitted, the same tree gives `FAIL tests/abtest-arms.test.sh`
(the pruned-copy scaffold compares tracked files), so every validate criterion runs after the unit's commit.

Notes sweep (`bash bin/marker-audit.sh . --notes --surface=<path>`, run for every touched path): see the
"Sweep dispositions" list under Risks. The sweep is best-effort; `.claude/reviewed/` is untracked per-clone state.

Prior FAIL history on these surfaces (`.claude/reviewed/*.fail`, all records read): tg-u1 FAILed once on sonnet
(9306b7d9 broke `tests/validate.sh` via `tests/cli-backfill.test.js`: the mirror and config were not regenerated;
and an orchestrator docs commit to its contract after the baseline produced `contract: changed-since-baseline`).
tg-u2 FAILed once on sonnet (a working-tree contract read in `writer-scope-gate.sh`). rfp-u2c and label-ui FAILed
on `label_page.html` / `label-ui.py` click handling, files this plan does not touch. Consequences: cos-u2 (same
file as tg-u1) must not be dispatched below sonnet, and regenerates the mirror and config in the same commit; no
contract of this plan is edited after it is committed (a re-scope is a fix contract).

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-29 Functional scope & success criteria: Q Which of the listed items are still open at ab174935? → A (self-resolved): all but 1g and 2c (already fixed) and tg-u2.md criterion 2 (still correct); see the Context table.
- 2026-10-29 Domain entities / data model: Q Is "FAIL block" reconciled by renaming the reviewer.md uses or by widening the glossary entry? → A (self-resolved): widen the glossary entry; the reviewer.md phrase "nothing more in the FAIL block" is pinned by tests/persona-prose-pins.test.sh:84 and means the same content the on-disk block copies.
- 2026-10-29 External dependencies & integrations: Q How are the `.claude/` mirrors and the config `fileHashes` regenerated without naming the config in a Bash command? → A (self-resolved): `node bin/cli.js --update`, staged with `git add -u -- .claude ':(exclude).claude/agent-memory'`, as tg-u1-fix1 and rfp-u7b did; measured in scratch: cos-u2 changes 2 `.claude/` paths, cos-u3 changes 14.
- 2026-10-29 Edge cases / failure handling: Q Can the multi-part spec accept tabs around `then`? → A (self-resolved): no; `crit_items` hands the spec over as a tab-separated field, so a tab splits it (measured: a tab case came out `judge`). The fix accepts any run of spaces; the glossary entry says spaces.
- 2026-10-29 Edge cases / failure handling: Q Does the single-literal stdout path also keep trailing blank lines? → A (self-resolved): no, unchanged; the note was about multi-part specs, and changing the literal path would re-grade every existing contract whose command prints without a final newline.
- 2026-10-29 Technical constraints & tradeoffs: Q Fix guard.py's `:..` over-refusal or document it? → A (self-resolved, Open Question 2 records the alternative): document and pin it; loosening a fail-closed guard is not a cosmetic change.
- 2026-10-29 Technical constraints & tradeoffs: Q Can tg-u2.md be corrected so that the precheck passes over tg-u2's own review range (baseline 0e0a2141)? → A (self-resolved, Open Question 1 records it): no. The precheck reads `--contract` from the baseline commit by design (`bin/review-precheck.sh:5-7`), so the baseline copy keeps `ac=6`, and any later edit adds `contract: changed-since-baseline` (it already prints that line today, from the 1c827e9b amendment). cos-u1 makes the check pass with the baseline at its own commit.
- 2026-10-29 Terminology consistency: Q Rename "FAIL reason" in the personas, or drop it from `_Avoid_`? → A (self-resolved, Open Question 3 records the alternative): rename; "FAIL ground" is the canonical term rfp-u7a recorded, and cos-u3 already pays the version bump.
- 2026-10-29 Terminology consistency: Q Which glossary holds each new term? → A (self-resolved): "verdict block" in CONTEXT.md (a reviewer concept a plugin user meets, next to FAIL block); "dispatch message", "multi-part stdout spec" and `judge` in docs/harness-glossary.md (gate and precheck internals). "dispatch message" is recorded as a synonym of the personas' "dispatch prompt", not a new concept.
- 2026-10-29 Completion / acceptance signals: Q What does "the precheck with --contract tg-u2.md --fix-contract tg-u2-fix1.md passes" mean, given the answer above? → A (self-resolved): its first line reads `precheck: result=pass` when run with the baseline at HEAD after cos-u1's commit, and keeps doing so after cos-u2 to cos-u5 land (criterion 6 no longer spans later commits).

## Risks / dependencies
- Order is serial: cos-u1, cos-u2, cos-u3, cos-u4, cos-u5. cos-u2 and cos-u3 both run `--update` and both change the
  persona-selection config, so they never run in parallel. cos-u5 cites cos-u2's precheck behaviour and cos-u3's
  "FAIL ground" wording, so it goes last. cos-u4 touches no mirror.
- cos-u3 is the only unit that touches a version-stamped path; it alone bumps the version and adds a CHANGELOG line
  (P3), in the same commit. A fix-round commit that touches `agents/` repeats the bump.
- Adding (m) cases 8-12 makes the frozen contracts tg-u1.md / tg-u1-fix1.md print `m=12` where they say `m=7`. Those
  are records of a PASSed unit; only tg-u2.md is corrected because the user asked for it.
- Out of scope, user's decision: hardening `hooks/scripts/writer-scope-gate.sh` so `$start` comes from something
  the writer cannot forge (tg-u2.pass NOTE[code] refuted D1). No unit edits that file or any other hook or gate.
- Not in scope: `eval/refutation-replay/labels.tsv`, `corpus.jsonl`, `report.jsonl`; `run.sh` is never run without
  `--dry-run` and `label.py serve` is never started against the real files. Every criterion uses a fresh
  `mktemp -d` and deletes nothing.
- Sweep dispositions (marker-audit `--notes` NOTE[spec] lines on the touched surfaces): the NOTE[spec] lines this
  plan closes are listed in the Context table; the rest are recorded in "Sweep dispositions" at the end of this file.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied — every criterion and mutation below was run by spec-master on a scratch clone; each contract's Pre-resolved context gives the measured output.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — mirrors and `fileHashes` only through `node bin/cli.js --update`; nothing under `.claude/` is hand-edited.
- P3 "Version-stamp discipline": satisfied — cos-u3 (the only unit touching `agents/*.md`; no unit touches `templates/`) bumps `.claude-plugin/plugin.json` and `package.json` and adds a CHANGELOG line in the same commit; its criterion 5 checks every `(cos-u3): ` commit against its own parent.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every unit except cos-u1 (a `docs/plans/` edit only) has a full `ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh` criterion, run after the commit.

## Steps

### Step 1 — cos-u1: tg-u2.md criteria match the tree
Contract: [cos-u1](2026-10-29-cosmetic-closeout/contracts/cos-u1.md).
Affected files: `docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2.md`.
Acceptance: the precheck run with `--contract tg-u2.md --fix-contract tg-u2-fix1.md` and the baseline at HEAD prints
`result=pass`; criterion 2 of tg-u2.md is byte-unchanged; only that file changes.

### Step 2 — cos-u2: review-precheck multi-part stdout fixes
Contract: [cos-u2](2026-10-29-cosmetic-closeout/contracts/cos-u2.md).
Affected files: `bin/review-precheck.sh`, `tests/review-precheck.test.sh`, `.claude/bin/review-precheck.sh`
(generated), the persona-selection config's `fileHashes` (generated).
Acceptance: `tests/review-precheck.test.sh` prints `fails=0 m=12 rc=0` (with the precheck of ab174935 it prints
`fails=4 m=8 rc=1`); mirror byte-equal; cli-backfill and validate green.

### Step 3 — cos-u3: reviewer wording, ports, pins, version bump
Contract: [cos-u3](2026-10-29-cosmetic-closeout/contracts/cos-u3.md).
Affected files: `agents/reviewer.md`, `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md`,
`tests/unit-scope-prose.test.sh`, `tests/persona-prose-pins.test.sh`, `.claude-plugin/plugin.json`, `package.json`,
`CHANGELOG.md`, and the 14 `.claude/` paths `--update` generates.
Acceptance: both pin suites `fails=0 rc=0` (skipping `--update` gives `fails=3 rc=1` in each); no "FAIL reason" left in
`agents/`, `adapters/`, `.claude/agents/`; per-commit version-stamp `bad=0 touched=yes`; validate green.

### Step 4 — cos-u4: refutation-replay docstrings and MIN_REAL
Contract: [cos-u4](2026-10-29-cosmetic-closeout/contracts/cos-u4.md).
Affected files: `eval/refutation-replay/score.py`, `eval/refutation-replay/guard.py`, `eval/refutation-replay/label.py`,
`tests/refutation-label-server.py`, `tests/refutation-replay-isolation.test.sh`.
Acceptance: label-server S13 green with the new cases (red with the label.py of ab174935); isolation (g2) green with
the new guard cases (red with the `:` dropped from `UP`); the docstring claims hold when run (`0 2 2 120`); validate green.

### Step 5 — cos-u5: glossary entries and reconciliations
Contract: [cos-u5](2026-10-29-cosmetic-closeout/contracts/cos-u5.md).
Affected files: `CONTEXT.md`, `docs/harness-glossary.md`.
Acceptance: four new headings exist once each; each entry's claims are checked against the code it describes;
`node tests/context-glossary-links.test.js` exits 0; validate green.

## Open Questions
None blocks dispatch: each has a default already applied in the contracts. Answering differently changes one unit.
1. tg-u2.md over its original range (from Clarifications, CHK7). The precheck can never pass over 0e0a2141..ab174935
   with `--contract tg-u2.md`, because it reads the contract at the baseline. Default (applied): correct the text
   and check with the baseline at cos-u1's commit. Alternative: leave tg-u2.md untouched and record in the plan that
   `tg-u2-fix1.md` is the contract to pass to `--contract` (cos-u1 is then dropped).
2. guard.py `:..` over-refusal (CHK8). Default (applied): document it in the docstring and pin it with tests.
   Alternative: narrow `UP` so a `:..` only counts after a revision or `-L` range (a fail-closed guard gets looser;
   needs its own security-reviewed unit).
3. "FAIL reason" (CHK9). Default (applied): rename to "FAIL ground" in the persona, both ports and the pins.
   Alternative: drop "FAIL reason" from `CONTEXT.md`'s `_Avoid_` line and leave the personas alone (cos-u3 then
   keeps only items 2a and 2b, and its pin changes in `tests/unit-scope-prose.test.sh` go away).

## Self-check
- CHK1: Is every Goal clause G1-G5 mapped to a step criterion? — PASS (Goal-to-criterion map)
- CHK2: Do steps 2 and 3 agree about who regenerates the persona-selection config and in which order? — PASS (Risks: serial, cos-u2 before cos-u3; each contract stages it only through `git add -u -- .claude`)
- CHK3: Is the version bump assigned to exactly one unit, and does that unit check it per commit? — PASS (cos-u3 criterion 5; no other unit touches `agents/` or `templates/`)
- CHK4: Does any criterion contain `rm`, `rmdir`, `find -delete` or a deleting trap, or name the persona-selection config in a Bash command? — PASS (none; checked by grep over the five contracts, see cos-spec commit)
- CHK5: Do steps 5 and 2 agree on what a multi-part stdout spec accepts (spaces, not tabs; one trailing newline)? — FAIL (conflicting) — revised in place: the first draft of the entry said "spaces or tabs"; the entry and Clarifications now say spaces only
- CHK6: Is the score.py docstring claim about a closed stdout defined by a measurement? — FAIL (missing) — revised in place: the first draft kept "a closed stdout ends in a traceback"; measured exit 120 with no traceback, cos-u4 edit 1 and criterion 3 now state and check it
- CHK7: Is "the precheck passes" for tg-u2.md defined for a specific baseline? — FAIL (ambiguous) — converted to Open Question 1 (default applied: baseline at cos-u1's commit)
- CHK8: Is the guard.py over-refusal disposition (fix vs document) decided? — FAIL (missing) — converted to Open Question 2 (default applied: document and pin)
- CHK9: Is the "FAIL reason" clash resolved on one side only? — FAIL (ambiguous) — converted to Open Question 3 (default applied: rename in the personas)
- CHK10: Does cos-u3 criterion 1 (persona-prose-pins over `.claude/agents/reviewer.md`) still fail under its own `mutation:` line, given reviewer-changes-examples-lean-2's and gh307's recorded class vacuous? — PASS (skipping `--update` measured `fails=3 rc=1`)
- CHK11: Does cos-u3 criterion 2 (unit-scope-prose over the four reviewer copies) still fail under its own `mutation:` line, given mw-step1's recorded class vacuous? — PASS (the cursor port of ab174935 measured `fails=3 rc=1`)
- CHK12: Do the cli-backfill criteria of cos-u2 and cos-u3 still fail under their own `mutation:` lines, given gh-296's and gh409's recorded class vacuous/host? — PASS (skipping `--update` leaves the config `fileHashes` stale; tg-u1's FAIL 1 is the recorded instance)
- CHK13: Do the validate criteria of cos-u2 to cos-u5 still fail under their own `mutation:` lines, given gh413's and human-review-cleanup-1's recorded class vacuous/host? — PASS (each names a suite validate.sh runs and the FAIL line it prints; the uncommitted-tree host effect is avoided by running after the commit)
- CHK14: Does cos-u3 criterion 5 (version-stamp-check per commit) still fail under its own `mutation:` line, given item17-4-name-p3-offenders' and ci-fetch-depth-cleanup's recorded class host? — PASS (a `(cos-u3): ` commit without the bump measured `bad=1`)
- CHK15: Do cos-u5 criteria 1-6 (CONTEXT.md greps) still fail under their own `mutation:` lines, given spec2-unitA's, gh339's and gh-303's recorded class vacuous? — PASS (each greps a claim sentence and the code line that makes it true; dropping either half fails)
- CHK16: Does cos-u5 criterion 7 (context-glossary-links) still fail under its own `mutation:` line, given item03-2-link-integrity-guard's recorded class vacuous? — PASS (a `[[verdict blocks]]` link with no heading fails the test)

Advisory ubiquitous-language check of this plan (prose mode, against CONTEXT.md): lens 1 — "FAIL block" is used in
two senses, the drift this plan resolves (Context 1d); lens 2 — "dispatch message" is a new name for the personas'
"dispatch prompt", recorded as a synonym rather than a new concept; lens 3 — "verdict block", "multi-part stdout
spec" and `judge` are load-bearing terms with no entry, which cos-u5 adds.

## Scribe update hint
cos-u5 writes the glossary entries itself (`knowledgeWrites: apply`). No ADR: none of the decisions is hard to
reverse. After cos-u5, scribe may fold the four new entries into the wiki's reviewer and precheck pages, if present.

## Dispatch
Fast path, no tracker issue. Dispatch serially from the contract files, each committed before its dispatch:
1. [cos-u1](2026-10-29-cosmetic-closeout/contracts/cos-u1.md)
2. [cos-u2](2026-10-29-cosmetic-closeout/contracts/cos-u2.md) (not below sonnet: tg-u1 FAILed once on this file)
3. [cos-u3](2026-10-29-cosmetic-closeout/contracts/cos-u3.md)
4. [cos-u4](2026-10-29-cosmetic-closeout/contracts/cos-u4.md)
5. [cos-u5](2026-10-29-cosmetic-closeout/contracts/cos-u5.md)

## Sweep dispositions
The per-surface `bash bin/marker-audit.sh . --notes --surface=<path>` sweep was started for all 13 touched surfaces
but did not finish within the session (about 75 s per surface). The NOTE lines it had returned, and the direct
harvest of every `rfp-*`, `rp-*` and `tg-*` `.pass` note, are the sources of the Context table; every NOTE[spec]
there has a disposition. Notes on these surfaces not in the table (for example rfp-u2b's guard.py `-O` bundle note,
fixed by rfp-u2d, and rfp-u2f's score.py test-gap notes) are not cosmetic close-out items and are left as they are.
The sweep is best-effort: an absent note is no proof that none exists.
