Unit: lp-slim

## Objective
Slim the writer packet, the reviewer message and the test runs (plan change 5, decisions D8 and D9, step "U10 lp-slim").
- The lead-programmer's ready-for-review packet is exactly five lines.
- The reviewer's PASS message is three lines. A FAIL lists at most 3 defects of at most 3 lines each, then a `more:` line.
- Advisory sections (roast-work, ubiquitous-language, refutation) go only into the marker body (PASS) or the fail record (FAIL), never into the message.
- The reviewer runs the full suite once, after the unit's final commit. Writers run only the unit's own tests.
No version bump.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, step "U10 lp-slim", D8, D9, R5, R6. This file is the contract of record and supersedes the plan's U10 file list and anchors where they differ. Dispatch after lp-bashscan has PASSed. Implementer tier: sonnet.

## Affected files
- `agents/lead-programmer.md` (the "Don't grade your own work" bullet; the `review-packet:` sentence near :37), `agents/reviewer.md` (the "Run the checks yourself" and "Verdict" bullets; the roast-work and ubiquitous-language bullets where they place output), `agents/orchestrator.md` (the scribe-dispatch sentence near :42-45 that reads the "scribe digest")
- `skills/roast-work/SKILL.md:36`, `skills/ubiquitous-language/SKILL.md` (Diff mode output paragraph)
- Hand-synced copies: `adapters/codex/agents/lead-programmer.toml`, `adapters/cursor/agents/lead-programmer.md` (:41 and the "Advisory review packet" bullet), `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md` (the "Verdict" bullet and the `Advisory critique:` placement line)
- Prose pins on removed wording only (R6), plus mirrors and one `[Unreleased]` CHANGELOG bullet

## Ordered edits
1. lead-programmer.md: replace the packet description with this fenced block. Each line starts at column 0, with no indent:
```
READY <unit-id> <base>..<head>
files: <changed paths>
checks: <criteria commands run and their results>
notes: <changed APIs, new conventions, proposals and knowledge items, or none; longer items go in docs/plans/<slug>/notes.md>
STATUS: complete
```
   Keep the sentences saying that the packet is advisory and that an incomplete one is grounds for INSUFFICIENT-CONTEXT. Drop "scribe digest". Add the sentence `Run only the unit's own test files` (the criteria and the tests they name, never the full suite). Replace the `review-packet:` sentence with: the packet is the five lines above, and a `review-packet:` block in a legacy contract is ignored.
2. reviewer.md: in "Run the checks yourself", add `Run the full suite (\`testAndLintCommand\`) once`, after the unit's final commit and never per fix commit. Mention `bash tests/validate.sh` only as this repository's value. In "Verdict", add these fenced blocks at column 0:
```
PASS <unit-id> <sha> checks: <criteria run>
notes: <n> (see marker)
STATUS: complete
```
```
FAIL <unit-id> <sha>
<at most 3 defects, at most 3 lines each: file:line and how to trigger>
more: .claude/reviewed/<unit-id>.fail
STATUS: complete
```
   INSUFFICIENT-CONTEXT stays one verdict line. Advisory sections and the `refutation:` line go into the marker body or the fail record, never into the message (D9). Keep any `needs-human:` line that lp-escprose added.
3. orchestrator.md: the scribe dispatch carries each unit's packet `files:` and `notes:` lines instead of the "scribe digest".
4. Skills and adapters: say that the advisory section is written into the marker body or the fail record. Sync the four adapter persona copies to steps 1-2 in their own style.
5. Run the pin tests in criterion 4. Fix a pin only where it pins wording this unit removed. Run `node bin/cli.js --update --force-render`, then `git add -- .claude adapters`.

## Do NOT touch
- `bin/contract-score.js`, `bin/contract-guard.js`, `bin/review-precheck.sh`, the marker and fail-record first-line formats (`fail-marker-format-parity` pins them)
- `agents/spec-master.md` (lp-speccap already says spec-master runs no `validate.sh`), `templates/persona-protocol.md` (its Answer-shape section does not restate the packet; leave it)
- `hooks/`, `docs/`, `tests/abtest-*`, `eval/`

## Acceptance criteria
1. run: `grep -c '^READY <unit-id> <base>\.\.<head>$' agents/lead-programmer.md; grep -c "Run only the unit's own test files" agents/lead-programmer.md; grep -c 'Run the full suite (`testAndLintCommand`) once' agents/reviewer.md` → `1`, `1`, `1`. mutation: delete the READY line → first count `0`.
2. run: `grep -c '^PASS <unit-id> <sha> checks: ' agents/reviewer.md; grep -c '^notes: <n> (see marker)$' agents/reviewer.md; grep -c '^more: \.claude/reviewed/<unit-id>\.fail$' agents/reviewer.md; grep -ci 'scribe digest' agents/lead-programmer.md; grep -c 'digest (affected files, changed APIs' agents/orchestrator.md` → `1`, `1`, `1`, `0`, `0`. mutation: restore the orchestrator sentence → last count `1`.
3. run: `git grep -n -i 'appended AFTER the verdict line\|may follow the verdict line\|advisory section appended' -- skills agents adapters templates | wc -l` → `0`. mutation: restore `skills/roast-work/SKILL.md` → `1`.
4. run: `bash tests/persona-prose-pins.test.sh && bash tests/prompt-diet-pins.test.sh && bash tests/fail-marker-format-parity.test.sh && node tests/adapter-protocol-parity.test.js && node tests/adapter-skill-parity.test.js && node tests/writer-tier-consistency.test.js` → exit 0.
5. C-mirror: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` → exit 0. C-full: `bash tests/validate.sh` → exit 0, run once by the reviewer after the final commit.

## Pre-resolved context
- Today (2026-10-30, 7717b64a): criterion 1 gives `0`, `0`, `0`; criterion 2 gives `0`, `0`, `0`, `1`, `1`; criterion 3 counts 6; the criterion 4 tests pass.
- Plan gaps resolved here. (a) The plan's anchor `Run \`bash tests/validate.sh\` once` would ship a repo-specific command to consumer projects. Personas are not templated, so the anchor names `testAndLintCommand`. (b) The plan's criterion 2 (`Knowledge proposals:` → 0) is already 0 today, so it is vacuous; it is replaced by the "scribe digest" check, because the orchestrator consumes that digest. (c) The orchestrator, the skills and the adapter copies are added: each states the old placement or the digest.
- D8: `bin/review-precheck.sh` does not run `testAndLintCommand`, so the reviewer's own run is the single run.

## Escalation
If any gate blocks a write, stop and report the path and the refusal text. Never reword, split or route around it. If a pin test fails on wording this unit did not remove, stop and report it.
