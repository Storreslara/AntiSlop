# Wording follow-ups from the cosmetic close-out

## Goal
Close the small wording and test findings left in the PASS notes of plan `docs/plans/2026-10-29-cosmetic-closeout.md` (cos-u2, cos-u3, cos-u4, cos-u5), without touching `hooks/` (a separate hardening plan owns `hooks/scripts/writer-scope-gate.sh`):
- G1. `bin/review-precheck.sh` fails a multi-part stdout spec whose last part is empty, and a test pins it; its `.` capture comment stops calling the trick a "sentinel". (Step 1)
- G2. `eval/refutation-replay/label.py` and `score.py` comments say what the code does; label.py caps the copied score.py message at 160 characters, with a test. (Step 2)
- G3. The glossary `dispatch message` entry says "a double quote" and drops the false "can be added" clause; the `multi-part stdout spec` entry states G1's rule; the cos-u3 contract says 644 for its two test files; a new `amended line` entry names the `amended <date> (<unit>):` convention. (Step 3)

## Context
Each item of the request was checked against the files at f566aeef (2026-10-29). None was already fixed or wrong; one premise was adjusted:
- Item 1 (glossary `dispatch message`, `docs/harness-glossary.md:3564`). Confirmed. The gate's case at `hooks/scripts/writer-scope-gate.sh:238` is `*'"'*|*'\'*|*[[:cntrl:]]*`: a double quote, a backslash or a control character, no apostrophe. `:175` appends the unit's own cited contract's entries and exclusions (`>>`); the fallback at `:181` (a message that lists nothing) overwrites both lists with another cited contract's (`>`), so the message's own exclusions are dropped there. Decision: drop the parenthesis "(their entries and exclusions can be added)" and leave the rule to the gate rather than add a clause for `:181`. Reasons: the entry already says "The full scope rules are in the gate"; this entry FAILed review three times on false clauses (`.claude/reviewed/cos-u5.fail`, three blocks); and the parallel hardening plan may change `:175-181`.
- Item 2 (`bin/review-precheck.sh`). Confirmed by reading `run_one` and running it in a scratch clone: the spec `` `0` then `` `` (empty last part) builds the expected text `0\n`, and output `0\n\n` less one trailing newline equals it, so it passes. No contract under `docs/plans/` uses such a spec (the only match, in cos-u2.md, is a test's expected message). "sentinel" occurs once, in the comment at `:98`; no variable is named for it. A replacement noun was rejected too: "marker" is the harness's word for review markers, so the comment uses no noun at all ("Printing '.' after the output keeps ...").
- Item 3 (cos-u3 contract). Confirmed: `tests/unit-scope-prose.test.sh` and `tests/persona-prose-pins.test.sh` are 100644 at 1a987d32 (cos-u3's baseline), at ecc8104e (cos-u3's commit) and now. The contract says 755 in three places: lines 13 and 14 (`## Affected files`) and line 166 (`## Escalation`).
- Item 4 (`eval/refutation-replay/`). Confirmed by measurement: `sys.exit()` exits 0 and prints nothing, `sys.exit(3)` exits 3 and prints nothing, and `sys.exit("boom")` prints `boom` to stderr and exits 1. `score()` on a raw row with numeric `num_turns`/`cost_usd` returns 0; with string values it raises TypeError, with no values KeyError. One adjustment: `score()` reads `num_turns` from every labelled row but `cost_usd` only from the first row of each id, so the docstring says "on the labelled rows", not "on every labelled row" (load() does convert both on every labelled row).
- Item 5 (`amended` convention). Used on 4 lines in 2 contracts (tg-u2.md, plus its copies in cos-u1.md, all written by cos-u1). Step 3 adds 3 more. `crit_items` ignores such a line, and `bin/review-precheck.sh` fails `contract: changed-since-baseline` when a contract differs between baseline and HEAD (both measured in a scratch repository). Decision: load-bearing enough for one entry in `docs/harness-glossary.md` (harness mechanics, so not `CONTEXT.md`). A contract reader has to know that an indented free-text line under a criterion is not part of its stdout. Placement claim measured: all four criterion-level amended lines follow a `stdout:` line.
- Prior FAIL history: `.claude/reviewed/cos-u5.fail` has three blocks (sonnet, sonnet, opus), all false clauses in the `dispatch message` entry. So Step 3 pins every new claim with a criterion tied to its source line or behaviour, and its contract asks for opus. tg-u1 FAILed once on sonnet on `bin/review-precheck.sh` (recorded in cos-u2.md), so Step 1 asks for sonnet or above. A survey of all `.fail` records found no other record for these files' units: cos-u1 to cos-u4 have only `.pass` files.
- Notes sweep (`bash bin/marker-audit.sh . --notes --surface=<path>`, best-effort). On `bin/review-precheck.sh` it returned four `NOTE[spec]` lines. rfp-u2 and rfp-u3 report false fails of multi-part specs; tg-u1 and cos-u2 fixed these, so they are already done. The tg-u2 note (a fix contract's stale `ac=6`) was fixed by cos-u1's amended lines, so it is already done too. The st-u2 note (a relative `--contract` resolves against the repo top) is out of scope for this plan and left as is. On `tests/review-precheck.test.sh` the sweep returned nothing. On `label.py` and `score.py` it returned only `NOTE[code]` lines (the cos-u4 notes this plan addresses). The sweep of the remaining paths did not finish within the tool timeout; the cos-u3 and cos-u5 `.pass` notes on those paths were read directly instead. An empty or partial sweep proves nothing.
- Measured: all three units' edits applied to a scratch clone of f566aeef and committed. Every criterion of the three contracts was run through `bin/review-precheck.sh --criterion` (all pass), and each stated mutation was run (each fails as stated). The full validate run (`ANTISLOP_VALIDATE_LANES=4`) exited 0 with OK=3442 FAIL=0 WARN=2 in 476 s.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-29 Edge cases / failure handling: Q Should a multi-part stdout spec whose last part is empty pass on output ending in a blank line, or fail? → A (self-resolved; the user delegated the choice, asking for the safer one with a reason): fail, whatever the output, with `criterion <n>: fail stdout spec ends in an empty part`. The pass reading depends on the one-trailing-newline rule, which a contract reader cannot see, so the script and a by-hand reading can disagree. Failing closed costs one rewrite of a spec no contract uses. A judge line was rejected because it hands the same ambiguity to the reviewer. An empty part before the last one stays a blank line.
- 2026-10-29 Technical constraints & tradeoffs: Q How are the five items grouped and sequenced so mirror/config files are never touched by two units at once, and how does the plan coexist with the parallel gate-hardening plan? → A (self-resolved): three units by file family. wrd-u1 (bin + test + mirror/config via `--update`) is the only unit that touches `.claude/`. wrd-u2 (eval) and wrd-u3 (docs) touch none, and run in order u1, u2, u3. wrd-u3 drops the fallback clause rather than describing gate code the hardening plan may change. Its criterion 1 pins the gate's case line and stops the unit if that line has changed.
- 2026-10-29 Terminology consistency: Q What should the `.` capture trick be called, given that "sentinel" collides with "WIP sentinel" and "marker" with the review markers? → A (self-resolved): no noun; the comment describes the action ("Printing '.' after the output ..."). Q Where does the `amended <date> (<unit>):` term go? → A (self-resolved): a new `amended line` entry in `docs/harness-glossary.md` (harness mechanics), linking `[[contract file]]`.

Ubiquitous-language check (prose mode, request and draft): lens 1 (a term used with a different meaning) found "sentinel" for the `.` capture next to the harness term "WIP sentinel"; Step 1 resolves it. Lens 2 (new synonym) found nothing; "dispatch prompt" is the existing synonym of the `dispatch message` entry. Lens 3 (new term) found "amended line"; Step 3 adds it to `docs/harness-glossary.md`, not `CONTEXT.md`, because it is harness mechanics.

## Risks / dependencies
- R1. The parallel hardening plan owns `hooks/scripts/writer-scope-gate.sh`. If it lands first and changes the case at `:238`, wrd-u3 criterion 1 prints `gate=0` and the contract says stop and report, so the wording gets a new decision instead of going stale. If it changes `:175-181`, nothing here goes stale, because the clause is dropped.
- R2. Only wrd-u1 runs `node bin/cli.js --update` and stages `.claude/` (by `git add -u -- .claude ':(exclude).claude/agent-memory'`, never naming the persona-selection config in Bash). No other unit of this plan touches `.claude/`, and no unit of this plan may run in parallel with another plan's `--update` unit.
- R3. Version stamps: no unit touches `agents/*.md` or `templates/*` (checked against `hooks/scripts/version-stamp-check.sh:87`), so no plugin bump or CHANGELOG entry is needed.
- R4. `python3 -I` ignores `PYTHONDONTWRITEBYTECODE`; a run without `-B` leaves `eval/refutation-replay/__pycache__/` behind (spec-master hit it once while measuring and removed its own file). Every Python command in wrd-u2 and wrd-u3 uses `-B`, and wrd-u2 criterion 6 fails on a stray untracked file under `eval/`.
- R5. Lane C4.1a of `tests/validate.sh` is known to flake (it passes alone and on re-run); each validate criterion says to re-run once and report both runs if it is the only failure.
- R7. The hardening plan (`docs/plans/2026-10-29-scope-gate-baseline-hardening.md`, uncommitted when this plan was written) also appends a `docs/harness-glossary.md` entry (`dispatch baseline`). wrd-u3 edit 4 appends after whatever the last entry is, and none of wrd-u3's criteria depend on the position. But wrd-u3 must never run at the same time as that plan's glossary unit: both write the same file.
- R6. wrd-u3 criterion 3 runs wrd-u1's test, so wrd-u3 is dispatched only after wrd-u1 has PASSed.
- No criterion uses `rm`, `rmdir`, `find -delete` or a deleting trap; scratch repositories are unique `mktemp -d` directories left in place.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every claim, criterion and mutation was run in a scratch clone (see Context, last bullet).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The mirror and `fileHashes` change only through `node bin/cli.js --update` (wrd-u1 edit 5).
- P3 "Version-stamp discipline": satisfied. No version-stamped path is touched (R3).
- P5 "`tests/validate.sh` is the merge gate": satisfied. Each unit's last criterion is the full validate after its commit.

## Step 1 — wrd-u1: review-precheck empty last part, comment wording
Affected files: `bin/review-precheck.sh`, `tests/review-precheck.test.sh`, `.claude/bin/review-precheck.sh` (generated), the persona-selection config's `fileHashes` (generated).
Acceptance criteria: `tests/review-precheck.test.sh` prints `fails=0 m=14 rc=0` (two new (m) cases: empty last part fails, empty middle part passes); `sentinel=0 printing=1 msg=1` in the script; mirror `cmp` equal; `tests/cli-backfill.test.js` exit 0; modes 100755; commit scope `out=0 dot-claude=2`; full validate exit 0. Mutation: the script as at f566aeef prints `fails=1 m=13 rc=1`.
Contract: [`contracts/wrd-u1.md`](2026-10-29-wording-followups/contracts/wrd-u1.md)

## Step 2 — wrd-u2: label.py and score.py wording, message cap
Affected files: `eval/refutation-replay/label.py`, `eval/refutation-replay/score.py`, `tests/refutation-label-server.py`.
Acceptance criteria: the server suite prints `ok=16 fail=0 rc=0` (a new S13 case: a 500-character message is cut to 160 plus `...`); the old phrases are gone and the new ones are present (`old=0 new=1 cap=1 raw=0 num=1`); the behaviour the comments state, measured (`rc=0 out=` then `rc=3 out=` then `rc=1 out=boom`; `rc=0 TypeError KeyError`); modes; commit scope and no stray files (`out=0 dirty=0`); full validate exit 0. Mutation: label.py as at f566aeef prints `ok=15 fail=1 rc=1`.
Contract: [`contracts/wrd-u2.md`](2026-10-29-wording-followups/contracts/wrd-u2.md)

## Step 3 — wrd-u3: glossary wording, amended line entry, cos-u3 modes
Affected files: `docs/harness-glossary.md`, `docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u3.md`.
Acceptance criteria: the gate's case line is unchanged and the entry says "double quote" without "can be added" (`gate=1 dq=1 added=0 cites=1`); the multi-part entry quotes the message the script prints (`gloss=1 script=1 last=1 mid=1`), and wrd-u1's two test cases pass (`1 1`); the `amended line` entry is present and its links resolve; a scratch repository shows an amended line changes no check and a changed contract fails `changed-since-baseline`; placement `amended=7 after-stdout=4`; cos-u3 says 644 with 3 amended lines and the modes are 100644 at 1a987d32, ecc8104e and HEAD; commit scope `out=0`; full validate exit 0.
Contract: [`contracts/wrd-u3.md`](2026-10-29-wording-followups/contracts/wrd-u3.md)

## Dispatch
Fast path (3 units, no tracker issue). The order is wrd-u1, then wrd-u2, then wrd-u3, one at a time; dispatch each from its contract file:
- [wrd-u1](2026-10-29-wording-followups/contracts/wrd-u1.md): sonnet or above
- [wrd-u2](2026-10-29-wording-followups/contracts/wrd-u2.md): sonnet or above
- [wrd-u3](2026-10-29-wording-followups/contracts/wrd-u3.md): opus (cos-u5 history)

## Open Questions
None. The one genuine design choice (item 2) was delegated by the user, and its answer and reason are recorded in Clarifications.

## Self-check
- CHK1: Is the outcome defined for an empty part that is not the last one? — PASS (wrd-u1 edit 2 comment and test case 14; wrd-u3 edit 3 sentence)
- CHK2: Do wrd-u1 and wrd-u3 agree on the exact failure message? — PASS (`fail stdout spec ends in an empty part`, pinned in both by wrd-u3 criterion 2 `script=1`)
- CHK3: Does every new glossary claim have a criterion tied to its source? — PASS (double quote: criterion 1 against gate `:238`; empty last part: criteria 2 and 3; amended line: criteria 4 to 6)
- CHK4: Do the cos-u3 count criteria count their own amended lines by mistake? — FAIL (conflicting): the first draft of wrd-u3 criterion 7 counted "mode stays 755" inside the amended lines and printed `s755=2`. Revised in place: the counts now leave out `  amended ` lines, and the re-run passes.
- CHK5: Is there a sequencing rule that keeps mirror/config writes out of two units at once? — PASS (R2; only wrd-u1 touches `.claude/`)
- CHK6: Does any criterion delete files or use a shared temp path? — PASS (last bullet of Risks; every scratch path is `mktemp -d`)
- CHK7: Is every Goal clause mapped to a step criterion? — PASS (G1: Step 1 criteria 1 and 2; G2: Step 2 criteria 1 to 4; G3: Step 3 criteria 1, 2, 4 and 7)
- CHK8: Does the wrd-u2 score() docstring overstate cost_usd coverage? — FAIL (ambiguous): the first draft said "on every labelled row" for what score() needs. Revised in place to "on the labelled rows", with load()'s every-row conversion stated separately (wrd-u2 edit 2).
- CHK9: Does wrd-u3 criterion AC4 still fail under its own `mutation:` line, given item03-2-link-integrity-guard's recorded class vacuous? — FAIL (missing): the first draft's mutation line said "the second line is missing", but the command exits 1 instead. Revised in place: the mutation line now says `criterion 4: fail exit=1 want=0`, measured. (Replay of `docs/audits/unit-outcomes/2026-10-06.jsonl`: this was the only `vacuous`/`host` unit whose files intersect a `run:` of this plan, here `tests/context-glossary-links.test.js`.)

## Scribe update hint
- `docs/harness-glossary.md` gets one new entry, `amended line`, in wrd-u3, and two edited entries, `dispatch message` and `multi-part stdout spec`. Nothing for `CONTEXT.md`.
- Knowledge proposal, not applied: cos-u3's PASS note suggests a `verdict block` entry; it is out of this plan's scope.
