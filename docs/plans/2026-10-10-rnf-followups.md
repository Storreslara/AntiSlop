# rnf follow-ups: the `Unit:` line, a line-order pin, glossaries, clean port reads (2026-10-10)

Status: FINAL (spec-master, 2026-10-10, tip 1b5b2e3, version 0.31.154). Unit prefix `rnf`,
continuing at `rnf-4` (`git log --oneline | grep -c 'rnf-[4-9]'` prints `0`). Fast path (3
units): the nine-element dispatch contracts are below and the orchestrator dispatches from this
file. Hook scripts (`hooks/scripts/*`, `marker-write.sh`'s tier line, every blc-h* item) are
human-only and out of scope. `docs/adr/0040-implementer-tier-haiku-default.md` is a dated record
and is not edited.

## Goal

Close the non-hook leftovers of `docs/plans/2026-10-09-reviewer-note-cleanups.md` (rnf-1..3, all
PASS, merged at 1b5b2e3):

- G1 (item 1). In `agents/orchestrator.md` **Review routing**, the sentence after the
  `Implementer tier:` rule names the `Unit:` line explicitly in both places ("reads exactly the
  `Unit:` line", "omits the `Unit:` line"). Persona change: version 0.31.155, CHANGELOG entry and
  `node bin/cli.js --update` mirrors in the same commit (P3).
- G2 (item 2). A new test registered in `tests/validate.sh` fails when `agents/orchestrator.md`
  drops any of the three line-order statements: `Unit:` first; `Implementer tier: <t>` second for
  a verdict-owning dispatch; `Mode: advisory` second and the tier line third for an advisory one.
- G3 (item 3). `docs/harness-glossary.md` **advisory dispatch** says the tier line goes third.
  `CONTEXT.md` **Reviewer dispatch opening line** gives the full line order.
  `docs/harness-glossary.md:868` ("fix attempt") stays as it is.
- G4 (item 4). `tests/adapter-fail-tier-pin.test.js` prints a `FAIL <port>: unreadable (<code>)`
  line instead of a stack trace when a port file is missing, and still exits non-zero.

## Context

### Sources and note dispositions

`bash bin/marker-audit.sh . --notes --surface=<path>` was not run: `reviewed-path-gate.sh` blocks
a spec-master Bash command that names the reviewed directory as an argument (measured again this
session). The three `rnf-*.pass` markers were read whole with Read instead. No `rnf-*.fail`
exists. No unit here re-scopes a unit that failed. The sweep is best-effort; the directory is
gitignored per-clone state, so an empty result proves nothing.

| Note | Disposition |
|---|---|
| rnf-1 n1: "that line"/"the line" now reads as the tier line | rnf-4 (G1) |
| rnf-1 n2: **advisory dispatch** already exists in `docs/harness-glossary.md:3100`; amend it, don't add one | rnf-6 item 1 (G3); `CONTEXT.md` links it, adds no entry |
| rnf-1 n3: no test pins the reviewer dispatch line order | rnf-5 (G2) |
| rnf-1 n4 (code): digest "2 FAILs ... climb" makes the FAILs the subject | deferred (not requested; the digest is at its 15-line budget) |
| rnf-2 n3 (code): validate.sh nested leak-guard re-run passes the 600 s ceiling | deferred (not requested); R5 below keeps the validate.sh run with the orchestrator |
| rnf-2 n4 (code): test file mode 100644 | no change; the new test matches it (validate.sh calls it through `node`) |
| request item 4: a missing port gives a stack trace | rnf-5 (G4) |

### Measured facts (2026-10-10, HEAD 1b5b2e3, version 0.31.154)

- F1. `agents/orchestrator.md:146-152` sets the order: `Unit: <task-id>` "literal first non-blank
  line", then "Unless the dispatch is advisory (below), its second non-blank line is
  `Implementer tier: <t>`" and "omit the line when that dispatch passed no `model`". Lines 153 and
  156 follow with "reads exactly that line" and "omits the line". `reviewer-route-gate-core.sh:88-94`
  reads the first non-blank line and matches `^Unit:`, so both phrases mean the `Unit:` line.
  Lines 163-165 put `Mode: advisory` second and move the tier line to third.
- F2. `git grep -n "Implementer tier\|second non-blank\|literal first non-blank" -- tests` is
  empty. `tests/review-join.test.sh:173-197` pin only the `Mode: advisory` position, against the
  hook.
- F3. `docs/harness-glossary.md:3100-3110` **advisory dispatch** says `Mode: advisory` is second
  "immediately after the dispatch's `Unit: <id>` first line" and does not mention the tier line.
  `CONTEXT.md:690-696` **Reviewer dispatch opening line** names only the first line.
  `tests/context-glossary-links.test.js` resolves `[[links]]` across both files, so a
  `[[advisory dispatch]]` link from `CONTEXT.md` resolves (measured).
- F4. `tests/adapter-fail-tier-pin.test.js:24-26` calls `fs.readFileSync` with no try/catch. With
  `adapters/cursor/agents/reviewer.md` deleted it exits 1 and prints 9 `    at ` stack lines
  (measured).
- F5. Replay (scratch worktree of 1b5b2e3, in order rnf-4, rnf-5, rnf-6, each committed with its
  contract's message). `node bin/cli.js --update` changes 14 `.claude` paths; afterwards
  `--update --dry-run` reports 0 non-current entries. Every criterion below gave its stated result
  after the edits and its stated red result at HEAD or under its mutation. These stay green:
  protocol-doc-drift, writer-tier-consistency, protocol-cross-references, adapter-protocol-parity,
  contract-examples, cli-backfill, context-glossary-links, ubiquitous-language, rubric-doc-parity.
  `version-stamp-check.sh` prints `ok touched: yes old: 0.31.154 new: 0.31.155` for rnf-4 and
  `ok touched: no` for rnf-5.
- F6. `.claude/constitution.md` v1.1.0: P3 covers `agents/*.md` and `templates/*` only. `tests/`,
  `CONTEXT.md`, `docs/harness-glossary.md` and `CHANGELOG.md` are unstamped.
- F7. The new test's phrases (F1 lines 146-152 and 163-165) do not overlap rnf-4's edit (lines
  153-156), so rnf-5 passes against both HEAD's and rnf-4's `agents/orchestrator.md` (measured
  on both).

### Decisions

- D1 (item 1). Replace "that line" with "the `Unit:` line" and "the line" with "the `Unit:` line"
  in lines 153 and 156. No rewrap beyond those two lines. "omit the line" at line 151 refers to
  the tier line in its own sentence and stays.
- D2 (items 2 and 4 merged). rnf-5 holds both test changes. Both are lead-programmer, test-only,
  unstamped work; one unit means one review. The new test uses the same try/catch shape, so a
  missing `agents/orchestrator.md` is also a FAIL line. Open Question 1 covers the split.
- D3 (item 2 shape). New file `tests/reviewer-dispatch-line-order.test.js`: flatten whitespace in
  `agents/orchestrator.md`, require three phrases (F1), print `OK`/`FAIL` per phrase. Source file
  only, not the `.claude/` mirror (`--update --dry-run` already guards mirror drift). It is
  registered in `tests/validate.sh` after the rnf-2 block. It does not check paragraph order or
  hook behaviour (Open Question 2).
- D4 (item 3). Two glossary items in one scribe unit, rnf-6. `docs/harness-glossary.md`
  **advisory dispatch** gains one sentence; `CONTEXT.md` **Reviewer dispatch opening line** gains
  the order and links `[[advisory dispatch]]` (no new CONTEXT.md entry: the term is defined once,
  in the harness glossary, and the link test forbids a second definition).
- D5. rnf-5 and rnf-6 bump nothing and never run `--update`. The three units are file-disjoint.
  Commit subjects end `(#529)`, the closed umbrella. scribe closes no issue.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-10 User interaction flow: Q Should the CONTEXT.md entry restate the no-`model` case for
  the tier line? → A (self-resolved): yes, in one clause, matching `agents/orchestrator.md:151`.
- 2026-10-10 Edge cases / failure handling: Q A missing port: one FAIL line per file, or one per
  phrase? → A (self-resolved): one per file (`continue` after the catch), counted once in the
  failure total; exit stays 1.
- 2026-10-10 Edge cases / failure handling: Q Does the new pin test need the same missing-file
  handling? → A (self-resolved): yes (D2), so the two tests behave alike.
- 2026-10-10 Technical constraints & tradeoffs: Q Four units (one per item) or three? → A
  (self-resolved): three; items 2 and 4 share a persona and a test-only surface (D2); recorded as
  Open Question 1.
- 2026-10-10 Technical constraints & tradeoffs: Q Can rnf-5 run in parallel with rnf-4, which edits
  the file rnf-5's test reads? → A (self-resolved): yes, the pinned phrases are outside rnf-4's
  edit (F7).
- 2026-10-10 Terminology consistency: Q Add **advisory dispatch** to CONTEXT.md? → A
  (self-resolved): no; it is already in `docs/harness-glossary.md`, and a double definition fails
  `tests/context-glossary-links.test.js`; CONTEXT.md links it (D4).

## Risks / dependencies

- R1. rnf-4 rewrites `.claude/` through `--update`. Do not run it at the same time as any other
  unit that runs `--update`. rnf-5 and rnf-6 do not run it.
- R2. A later rewrite of the **Review routing** paragraph that keeps the meaning but changes a
  pinned phrase fails rnf-5's test. That is intended; the fix is to update the phrase list.
- R3. Prior FAIL history on these files (replay items below) is `vacuous`/`host` criteria, none
  of it an rnf unit. Every criterion here was run red and green in the replay (F5). The
  Implementer-tier ratchet does not apply.
- R4. Worktree-mutation criteria (rnf-5 c3-c6) create and remove a `mktemp -d` worktree of
  `HEAD`; run them after the unit's commit.
- R5. `tests/validate.sh` (P5) is not a unit criterion (rnf-2 n3: over 600 s). The orchestrator
  runs it once after the units merge.
- R6. Concurrent agent-memory writes: clean-tree criteria exclude `.claude/agent-memory`.
- Deferred / out of scope: hook scripts, `marker-write.sh`, blc-h*, ADR-0040, rnf-1 n4, rnf-2 n3,
  a hook-level test that a tier line in second position is stamped normally.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. F1-F7 measured at 1b5b2e3; all three units replayed with
  every criterion run (F5).
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Mirrors come from
  `node bin/cli.js --update` only.
- P3 "Version-stamp discipline": satisfied. rnf-4 bumps 0.31.154 → 0.31.155 with a CHANGELOG
  entry in the same commit (criterion 7 checks every unit commit). rnf-5 and rnf-6 touch no
  stamped path (rnf-5 c9, rnf-6 c8 file lists).
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. No persona dependency changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied. rnf-5 registers its test; R5 assigns the
  run.

## Steps

### Unit table

| Unit | Items | Persona | Content files | Version | Depends on | Group |
|---|---|---|---|---|---|---|
| rnf-4 | 1 | lead-programmer | `agents/orchestrator.md` (+ `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`, 14 `.claude/` mirrors) | 0.31.155 | none | S (sole stamped unit) |
| rnf-5 | 2, 4 | lead-programmer | `tests/reviewer-dispatch-line-order.test.js` (new), `tests/validate.sh`, `tests/adapter-fail-tier-pin.test.js` | none | none | P |
| rnf-6 | 3 | scribe | `docs/harness-glossary.md`, `CONTEXT.md` | none | none | P |

The file sets are disjoint. rnf-5's test reads `agents/orchestrator.md` but passes against both
versions (F7). All three may be dispatched at once in separate worktrees; rnf-4 must be the only
`--update` in flight (R1). Reviews go one at a time.

### Step 1 (rnf-4): name the `Unit:` line

Edit 1 `agents/orchestrator.md` (D1); edits 2-4 version and CHANGELOG; then `--update`. Criteria:
contract below (15 items).

### Step 2 (rnf-5): line-order pin and clean port reads

New test (D3), validate.sh registration, try/catch in the port pin test (G4). Criteria: contract
below (14 items).

### Step 3 (rnf-6): glossaries

**advisory dispatch** and **Reviewer dispatch opening line** (D4). Criteria: contract below
(12 items).

## Open Questions

1. (From CHK5.) Items 2 and 4 as one unit rnf-5 (default) or two units? Splitting buys a separate
   review per test change and nothing else; the file sets would still be disjoint.
2. (From CHK7.) Should the line-order pin also exercise the hook (a `tests/review-join.test.sh`
   case: `Unit:` then `Implementer tier: haiku` gets a real stamp; `Unit:`, `Mode: advisory`,
   `Implementer tier: haiku` gets none)? Default: no, the request asks for a prose pin, and
   `tests/review-join.test.sh:173-197` already pins the `Mode: advisory` position. Choosing yes
   adds `tests/review-join.test.sh` to rnf-5.

## Self-check

- CHK1: Do G1 and rnf-4 edit 1 agree on which two phrases change and which ("omit the line" at
  151) stays? — PASS (D1; criteria 1-3).
- CHK2: Is the mirror refresh checked, not just run? — PASS (rnf-4 c4, c10).
- CHK3: Do rnf-5's pinned phrases avoid rnf-4's edited lines, so parallel dispatch is safe? —
  FAIL (missing: first draft did not say) — revised in place (F7, measured on both versions).
- CHK4: Is the missing-file behaviour defined as one FAIL line per file, with exit 1 and no stack
  trace? — FAIL (ambiguous) — revised in place (Clarifications; rnf-5 c5 checks
  `exit=1 unreadable=1 stack=0`).
- CHK5: Is the unit grouping a choice the user may want to make? — FAIL (missing) — converted to
  Open Question 1.
- CHK6: Does rnf-6 add a second definition of **advisory dispatch**? — PASS (D4; rnf-6 c4 runs the
  link test that forbids it).
- CHK7: Is a hook-level line-order test in scope? — FAIL (missing) — converted to Open Question 2.
- CHK8: Is `docs/harness-glossary.md:868` "fix attempt" protected? — PASS (rnf-6 c3 counts `1`).
- CHK9 (P3): Does the stamped unit carry a per-commit version-stamp criterion, and do the others
  prove they stay unstamped? — PASS (rnf-4 c7; rnf-5 c9; rnf-6 c8).
- CHK10 (P5): Is the new test registered and a validate.sh run assigned? — PASS (rnf-5 c7-c8; R5).
- CHK11 (replay; gh307, gh310, gh348-14 vacuous, gh429 host; `agents/orchestrator.md`): do rnf-4
  criteria 1-4 still fail under their own `mutation:` lines? — PASS (HEAD values `0`, `0`, `2`,
  `0`, measured).
- CHK12 (replay; gh317, gh320, mw-step1/2/3, rollout-map-1, spec2-unitA/B vacuous, gh346-2,
  gh409, gh413, human-review-cleanup-1 host; `tests/validate.sh`): does rnf-5 criterion 7 still
  fail under its own `mutation:` line? — PASS (`0` at HEAD).
- CHK13 (replay; gh-303, gh354, spec2-unitA/B vacuous, gh339, gh409, gh426, gh429,
  human-review-cleanup-1, ci-fetch-depth-cleanup host; `CONTEXT.md`): do rnf-6 criteria 1-2 still
  fail under their own `mutation:` lines? — PASS (`0`, `0` at HEAD).
- CHK14 (replay; gh288-1, gh313, gh317, gh320, gh348-3, gh360, item17-3, memdirt-1 vacuous,
  gh339, gh348-4 host; `CHANGELOG.md`, version files): do rnf-4 criteria 5-8 still fail under
  their own `mutation:` lines? — PASS (`0`, `0`, `no-unit-commit`, `version-sync: mismatch` at
  HEAD).
- CHK15 (replay, host class): does any `run:` use a host path other than `mktemp` and
  `/usr/bin/grep`? — PASS (no `/tmp/`, `/home/`, `~/` or `$HOME` in any `run:` line).

Ubiquitous-language prose check (advisory, against CONTEXT.md). Lens 1: none; "advisory
dispatch" is used with its harness-glossary meaning. Lens 2: "verdict-owning dispatch" is a plain
description, the opposite of **advisory dispatch**, not a synonym of a defined term. Lens 3: none
new; "line order" is covered by the amended **Reviewer dispatch opening line**.

## Scribe update hint

rnf-6 is the glossary work. Close no issue: there is no per-unit tracker issue, and #529 is the
closed umbrella.

## Handoff

Fast path: 3 units, so the contracts are emitted directly below and `task-master` is not
involved. Retrieval contract: this file. The Open Questions have defaults, and the plan is
dispatchable as written.

---

# Dispatch contracts (fast path; this file is the retrieval contract)

## Retrieval contract

No per-unit issue exists. The retrieval contract for every unit is this file,
`docs/plans/2026-10-10-rnf-followups.md`, under `## Unit rnf-<n>`: read the unit's
`~~~~~~~markdown` block, whose first line is `Unit: rnf-<n>`. The orchestrator's guard reads it
with `node bin/contract-guard.js docs/plans/2026-10-10-rnf-followups.md --unit=rnf-<n>` (add
`--shape=scribe` for rnf-6). The contract outranks the plan prose above. A conflict is a spec
gap: STOP.

## Dispatch table

| unit | persona | shape | content files | version | parallel/serial | guard |
|---|---|---|---|---|---|---|
| rnf-4 | lead-programmer | lead, stamped | `agents/orchestrator.md` + version files, `CHANGELOG.md`, 14 `.claude` mirrors | 0.31.155 | the only stamped unit; the only `--update` in flight | 7/7 |
| rnf-5 | lead-programmer | lead | `tests/reviewer-dispatch-line-order.test.js`, `tests/validate.sh`, `tests/adapter-fail-tier-pin.test.js` | none | parallel (worktree) | 7/7 |
| rnf-6 | scribe | scribe | `docs/harness-glossary.md`, `CONTEXT.md` | none | parallel (worktree) | 7/7 |

**Dispatchable now: all three.** Reviews go one at a time.

## Rulings

(spec-master adds one line per resolved gap, starting `- <ruling-id>:`.)

## Unit rnf-4

~~~~~~~markdown
Unit: rnf-4

## Objective
`agents/orchestrator.md` **Review routing**: the sentence after the `Implementer tier:` rule says `reviewer-route-gate.sh` reads exactly the `Unit:` line, and that a dispatch which omits the `Unit:` line leaves the marker-coupling check inert. Before, "that line" and "the line" could be read as the tier line. Nothing else in the paragraph changes. Version 0.31.155; CHANGELOG entry; mirrors refreshed by `node bin/cli.js --update`.

## Retrieval
Plan file: `docs/plans/2026-10-10-rnf-followups.md`, `## Unit rnf-4`. No per-unit issue exists. Umbrella (closed): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `agents/orchestrator.md` (anchor: line matching `` `reviewer-route-gate.sh` reads exactly that line to write the per-unit ``)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.154",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `agents/orchestrator.md`
   anchor: line matching `` `reviewer-route-gate.sh` reads exactly that line to write the per-unit ``
   indent: 0
   before:
```
`reviewer-route-gate.sh` reads exactly that line to write the per-unit
review-join stamp (`.claude/.review-join.<task-id>`) that `stop-gate.sh`
later consumes as proof a verdict was actually produced, so a dispatch that
omits the line leaves the marker-coupling check inert for that unit — the
```
   after:
```
`reviewer-route-gate.sh` reads exactly the `Unit:` line to write the per-unit
review-join stamp (`.claude/.review-join.<task-id>`) that `stop-gate.sh`
later consumes as proof a verdict was actually produced, so a dispatch that
omits the `Unit:` line leaves the marker-coupling check inert for that unit — the
```
2. file: `.claude-plugin/plugin.json` (version 0.31.155)
   anchor: line matching `"version": "0.31.154",`
   before: `  "version": "0.31.154",`
   after: `  "version": "0.31.155",`
3. file: `package.json` (version 0.31.155)
   anchor: line matching `"version": "0.31.154",`
   before: `  "version": "0.31.154",`
   after: `  "version": "0.31.155",`
4. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Review routing names the `Unit:` line (rnf-4, 0.31.155).** `agents/orchestrator.md` (Review routing): the sentence after the `Implementer tier:` rule says `reviewer-route-gate.sh` reads exactly the `Unit:` line, and that a dispatch omitting the `Unit:` line leaves the marker-coupling check inert; before, "that line" and "the line" could be read as the tier line. Mirrors refreshed by `node bin/cli.js --update`.
```
5. command: `node tests/protocol-doc-drift.test.js > /dev/null 2>&1 && node tests/writer-tier-consistency.test.js > /dev/null 2>&1 && node tests/protocol-cross-references.test.js > /dev/null 2>&1 && node tests/contract-examples.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
6. command: `node bin/cli.js --update`
   expect: 0
7. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
8. command: `git add agents/orchestrator.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "docs(rnf-4): Review routing names the Unit line (0.31.155) (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0
9. command: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `hooks/scripts/lib/reviewer-route-gate-core.sh`, `hooks/scripts/marker-write.sh` and every other file under `hooks/` (human-only; this unit is prose only)
- `agents/orchestrator.md` outside edit 1, in particular line 151 ("omit the line when that dispatch passed no `model`", the tier line) and the three line-order statements unit rnf-5's test pins
- `docs/adr/0040-implementer-tier-haiku-default.md` (a dated record)
- `tests/` (unit rnf-5), `CONTEXT.md` and `docs/harness-glossary.md` (unit rnf-6)
- `.claude/` (mirrors are regenerated only by `node bin/cli.js --update`)

## Acceptance criteria
1. run: `tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -cF 'reads exactly the `Unit:` line to write the per-unit'`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; it prints `0`, exit 1. It prints `0` at HEAD.
2. run: `tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -cF 'omits the `Unit:` line leaves the marker-coupling check inert for that unit'`
   exit: 0
   stdout: `1`
   mutation: change only the first line of edit 1; it prints `0`, exit 1. It prints `0` at HEAD.
3. run: `tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -oE 'reads exactly that line|omits the line leaves' | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip edit 1; it prints `2` (measured at HEAD).
4. run: `tr '\n' ' ' < .claude/agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -cF 'reads exactly the `Unit:` line to write the per-unit'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6 (`node bin/cli.js --update`); the mirror keeps the old words and it prints `0`, exit 1.
5. run: `cat .claude-plugin/plugin.json package.json | /usr/bin/grep -c '"version": "0.31.155"'`
   exit: 0
   stdout: `2`
   mutation: skip edit 2 or 3; it prints `1`. It prints `0` at HEAD.
6. run: `/usr/bin/grep -cF '(rnf-4, 0.31.155)' CHANGELOG.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; it prints `0`, exit 1.
7. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-4\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do bash hooks/scripts/version-stamp-check.sh "$c~1..$c"; done | /usr/bin/grep -vc '^version-stamp-check: ok touched: yes '`
   exit: 1
   stdout: `0`
   mutation: skip edit 2; the line reads `violation` and it prints `1`, exit 0 (the script exits 0 on a violation, so this gates on stdout). Before the unit's first commit it prints `no-unit-commit` and exits 3.
8. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.155';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 3; it prints `version-sync: mismatch`, exit 1.
9. run: `node tests/writer-tier-consistency.test.js > /dev/null 2>&1 && node tests/protocol-cross-references.test.js > /dev/null 2>&1 && node tests/protocol-doc-drift.test.js > /dev/null 2>&1 && node tests/contract-examples.test.js > /dev/null 2>&1 && node tests/cli-backfill.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: a claim check that the prose edit leaves these tests green; it already passes at HEAD and must stay green. proof: `node tests/writer-tier-consistency.test.js` pins orchestrator paragraphs (AC-P4) and fails when a pinned phrase is removed.
10. run: `node bin/cli.js --update --dry-run 2>&1 | /usr/bin/grep -E '^  ' | /usr/bin/grep -vc ': already current$'`
   exit: 1
   stdout: `0`
   mutation: skip edit 6; the mirrors are non-current and it prints a count above `0`, exit 0. It prints `0` at HEAD and must stay `0`.
11. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-4\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(rnf-4\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
12. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-4\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
13. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-4\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- agents/orchestrator.md | /usr/bin/grep -vcE '^[a-z]+\(rnf-4\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches `agents/orchestrator.md` with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
14. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-4\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | /usr/bin/grep -v '^\.claude/' | LC_ALL=C sort -u | paste -sd' ' -`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md agents/orchestrator.md package.json`
   mutation: touch one extra file (for example a hook script) in the unit's commit; the list gains that path.
15. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.154`. Anything else: STOP; the orchestrator re-derives the version as HEAD version + 1 and rewrites this contract's version lines before dispatch.
precondition: `git log --format='%H %s' | /usr/bin/grep -cE '^[0-9a-f]+ [a-z]+\(rnf-4\): '` prints `0`, the tree is clean, and no other unit that runs `node bin/cli.js --update` is in flight. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file (measured at 1b5b2e3: all print `1`). On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edit of an agent file (criteria 1, 2 and 4 count phrases absent at HEAD; criterion 3 counts the old phrases, `2` at HEAD)
blast-radius: agents/orchestrator.md:153, agents/orchestrator.md:156, hooks/scripts/lib/reviewer-route-gate-core.sh:88, tests/writer-tier-consistency.test.js
note: payload fences sit at column 0 and hold the file's literal text; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 1 keeps the unicode em dash and the line breaks exactly as shown (four lines in, four lines out; the fourth line grows to 82 characters, which is intended). Edit 4's payload begins with one empty line, which is part of the text, and its entry is ONE line.
note: the gate's first-line parse is unchanged; this unit is wording only. No hook changes.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(rnf-4)` as its subject scope.
explorer: not needed (provenance: grep and read by spec-master at 1b5b2e3, and a full replay in a scratch worktree; grep-derived, not graph-derived).
commit-message: docs(rnf-4): Review routing names the Unit line (0.31.155) (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: rnf-4 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit rnf-5

~~~~~~~markdown
Unit: rnf-5

## Objective
A new test `tests/reviewer-dispatch-line-order.test.js`, registered in `tests/validate.sh`, fails when `agents/orchestrator.md` drops any of the three reviewer dispatch line-order statements (`Unit:` first; `Implementer tier: <t>` second for a verdict-owning dispatch; `Mode: advisory` second and the tier line third for an advisory one). `tests/adapter-fail-tier-pin.test.js` prints `FAIL <port>: unreadable (<code>)` instead of a stack trace when a port file is missing, and still exits 1; the new test does the same for a missing `agents/orchestrator.md`. No version bump (no `agents/*.md` or `templates/*` file changes).

## Retrieval
Plan file: `docs/plans/2026-10-10-rnf-followups.md`, `## Unit rnf-5`. No per-unit issue exists. Umbrella (closed): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `tests/reviewer-dispatch-line-order.test.js` (anchor: new file)
- `tests/adapter-fail-tier-pin.test.js` (anchor: line matching `  const flat = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').replace(/\s+/g, ' ');`)
- `tests/validate.sh` (anchor: line matching `  echo "FAIL tests/adapter-fail-tier-pin.test.js"`)

## Ordered edits
1. file: `tests/reviewer-dispatch-line-order.test.js`
   anchor: new file (create it with exactly this content)
   indent: 0
   insert-after:
```
#!/usr/bin/env node
'use strict';

// Reviewer dispatch line-order pin (rnf-5): agents/orchestrator.md **Review routing**
// gives a reviewer dispatch's opening lines in order. `Unit: <task-id>` is first. A
// verdict-owning dispatch has `Implementer tier: <t>` second; an advisory one has
// `Mode: advisory` second and the tier line third. Whitespace is flattened first, so
// rewrapping the paragraph does not break the check. A missing file is a FAIL line.

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const REL = 'agents/orchestrator.md';
const PHRASES = [
  'That dispatch opens with `Unit: <task-id>` as its **literal first non-blank line**',
  'Unless the dispatch is advisory (below), its second non-blank line is `Implementer tier: <t>`',
  'add `Mode: advisory` as the **literal second non-blank line**, immediately after `Unit: <id>`, and move the `Implementer tier:` line to third.',
];

let failures = 0;
let flat = null;
try {
  flat = fs.readFileSync(path.join(REPO_ROOT, REL), 'utf8').replace(/\s+/g, ' ');
} catch (e) {
  console.log(`FAIL ${REL}: unreadable (${e.code || e.message})`);
  failures++;
}
if (flat !== null) {
  for (const phrase of PHRASES) {
    if (flat.includes(phrase)) {
      console.log(`OK   ${REL}: ${phrase}`);
    } else {
      console.log(`FAIL ${REL}: missing ${phrase}`);
      failures++;
    }
  }
}

console.log(failures === 0
  ? 'All reviewer-dispatch-line-order checks passed.'
  : `${failures} reviewer-dispatch-line-order check(s) FAILED.`);
process.exit(failures === 0 ? 0 : 1);
```
2. file: `tests/adapter-fail-tier-pin.test.js`
   anchor: line matching `  const flat = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').replace(/\s+/g, ' ');`
   indent: 0
   before:
```
for (const rel of PORTS) {
  const flat = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').replace(/\s+/g, ' ');
  for (const phrase of PHRASES) {
```
   after:
```
for (const rel of PORTS) {
  let flat;
  try {
    flat = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').replace(/\s+/g, ' ');
  } catch (e) {
    console.log(`FAIL ${rel}: unreadable (${e.code || e.message})`);
    failures++;
    continue;
  }
  for (const phrase of PHRASES) {
```
3. file: `tests/validate.sh`
   anchor: line matching `  echo "FAIL tests/adapter-fail-tier-pin.test.js"`
   indent: 0
   before:
```
  echo "FAIL tests/adapter-fail-tier-pin.test.js"
  fail=1
fi
```
   after:
```
  echo "FAIL tests/adapter-fail-tier-pin.test.js"
  fail=1
fi

echo
echo "== agents/orchestrator.md pins the reviewer dispatch line order (Node, rnf-5) =="
if node tests/reviewer-dispatch-line-order.test.js; then
  echo "OK   tests/reviewer-dispatch-line-order.test.js"
else
  echo "FAIL tests/reviewer-dispatch-line-order.test.js"
  fail=1
fi
```
4. command: `node tests/reviewer-dispatch-line-order.test.js > /dev/null 2>&1 && node tests/adapter-fail-tier-pin.test.js > /dev/null 2>&1 && bash -n tests/validate.sh; echo exit=$?`
   expect: 0
   stdout: `exit=0`
5. command: `git add tests/reviewer-dispatch-line-order.test.js tests/adapter-fail-tier-pin.test.js tests/validate.sh && git commit -m "test(rnf-5): pin the reviewer dispatch line order; port reads fail cleanly (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/orchestrator.md` (unit rnf-4 owns it; the test only reads it, and its pinned phrases are outside rnf-4's edit)
- `tests/review-join.test.sh` (the hook-level `Mode: advisory` pin stays as it is)
- `adapters/` (the ports the pin test reads; they already carry the clause)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump, no CHANGELOG entry, no `node bin/cli.js --update`)
- `hooks/scripts/marker-write.sh` and every other file under `hooks/` (human-only)
- `.claude/` (no mirror applies to tests)

## Acceptance criteria
1. run: `node tests/reviewer-dispatch-line-order.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 1; the file is missing and it prints `exit=1` (measured at HEAD).
2. run: `node tests/reviewer-dispatch-line-order.test.js | /usr/bin/grep -c '^OK '`
   exit: 0
   stdout: `3`
   mutation: remove one entry from `PHRASES`; it prints `2`.
3. run: `D=$(mktemp -d); git worktree add --detach -q "$D" HEAD; sed -i 's/^to third\. `reviewer-route-gate.sh` recognizes$/to fourth. `reviewer-route-gate.sh` recognizes/' "$D/agents/orchestrator.md"; node "$D/tests/reviewer-dispatch-line-order.test.js" 2>&1 | /usr/bin/grep -c '^FAIL agents/orchestrator.md: missing add `Mode: advisory`'; git worktree remove --force "$D"`
   exit: 0
   stdout: `1`
   mutation: skip edit 1, or drop the third entry of `PHRASES`; it prints `0`. The scratch copy is the only file changed; the checked-out tree stays clean.
4. run: `D=$(mktemp -d); git worktree add --detach -q "$D" HEAD; sed -i 's/^advisory (below), its second non-blank line is/advisory (below), its third non-blank line is/' "$D/agents/orchestrator.md"; node "$D/tests/reviewer-dispatch-line-order.test.js" 2>&1 | /usr/bin/grep -c '^FAIL agents/orchestrator.md: missing Unless the dispatch is advisory'; git worktree remove --force "$D"`
   exit: 0
   stdout: `1`
   mutation: skip edit 1, or drop the second entry of `PHRASES`; it prints `0`.
5. run: `D=$(mktemp -d); git worktree add --detach -q "$D" HEAD; rm "$D/adapters/cursor/agents/reviewer.md"; node "$D/tests/adapter-fail-tier-pin.test.js" > "$D/out.txt" 2>&1; echo "exit=$? unreadable=$(/usr/bin/grep -c '^FAIL adapters/cursor/agents/reviewer.md: unreadable (ENOENT)$' "$D/out.txt") stack=$(/usr/bin/grep -c '^    at ' "$D/out.txt")"; git worktree remove --force "$D"`
   exit: 0
   stdout: `exit=1 unreadable=1 stack=0`
   mutation: skip edit 2; it prints `exit=1 unreadable=0 stack=9` (measured on 1b5b2e3).
6. run: `D=$(mktemp -d); git worktree add --detach -q "$D" HEAD; rm "$D/agents/orchestrator.md"; node "$D/tests/reviewer-dispatch-line-order.test.js" > "$D/out.txt" 2>&1; echo "exit=$? unreadable=$(/usr/bin/grep -c '^FAIL agents/orchestrator.md: unreadable (ENOENT)$' "$D/out.txt") stack=$(/usr/bin/grep -c '^    at ' "$D/out.txt")"; git worktree remove --force "$D"`
   exit: 0
   stdout: `exit=1 unreadable=1 stack=0`
   mutation: remove the `try`/`catch` around the read in edit 1; it prints `unreadable=0` and a non-zero `stack=` count.
7. run: `/usr/bin/grep -c 'node tests/reviewer-dispatch-line-order.test.js' tests/validate.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; it prints `0`, exit 1.
8. run: `bash -n tests/validate.sh && echo syntax-ok`
   exit: 0
   stdout: `syntax-ok`
   mutation: delete the `fi` line of the new block; bash reports a syntax error and prints nothing, exit 2. It already passes at HEAD and must stay green.
9. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-5\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | LC_ALL=C sort -u | paste -sd' ' -`
   exit: 0
   stdout: `tests/adapter-fail-tier-pin.test.js tests/reviewer-dispatch-line-order.test.js tests/validate.sh`
   mutation: touch one extra file (for example `agents/orchestrator.md`) in the unit's commit; the list gains that path.
10. run: `node tests/adapter-fail-tier-pin.test.js | /usr/bin/grep -c '^OK '`
   exit: 0
   stdout: `8`
   mutation: break the loop in edit 2 (for example `continue` before the phrase loop on every port); it prints `0`. It prints `8` at HEAD and must stay `8`.
11. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-5\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(rnf-5\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
12. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-5\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
13. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-5\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- tests/reviewer-dispatch-line-order.test.js tests/adapter-fail-tier-pin.test.js tests/validate.sh | /usr/bin/grep -vcE '^[a-z]+\(rnf-5\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
14. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `git log --format='%H %s' | /usr/bin/grep -cE '^[0-9a-f]+ [a-z]+\(rnf-5\): '` prints `0`, `test -e tests/reviewer-dispatch-line-order.test.js && echo exists` prints nothing, and the tree is clean. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:` other than `new file`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file (measured at 1b5b2e3: all print `1`). On any mismatch STOP and report; do not adapt the text.
tdd: yes tests/reviewer-dispatch-line-order.test.js (the new test is the deliverable; it passes at HEAD's orchestrator text, so criteria 3, 4 and 6 are its red proofs in a scratch copy; criterion 5 is edit 2's red proof)
blast-radius: agents/orchestrator.md:146, agents/orchestrator.md:149, agents/orchestrator.md:163, tests/adapter-fail-tier-pin.test.js:24, tests/validate.sh:1233
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 3's `before:` lines are the end of the rnf-2 block; the new block follows them after one empty line, and the existing empty line and `echo` that follow stay.
note: a missing port counts as one failure (the `continue` skips its phrases), so the summary line reads `1 adapter-fail-tier-pin check(s) FAILED.` for one missing file.
note: this unit may run in a worktree in parallel with units rnf-4 and rnf-6 (file-disjoint); it bumps nothing. Its pinned phrases are at `agents/orchestrator.md:146-152,163-165`; rnf-4 edits only lines 153-156, so the test passes before and after rnf-4 (measured on both).
note: criteria 3-6 create and remove a `mktemp -d` worktree of `HEAD`; run them after edit 5's commit.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(rnf-5)` as its subject scope.
explorer: not needed (provenance: grep and read by spec-master at 1b5b2e3, and a full replay in a scratch worktree; grep-derived, not graph-derived).
commit-message: test(rnf-5): pin the reviewer dispatch line order; port reads fail cleanly (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: rnf-5 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit rnf-6

~~~~~~~markdown
Unit: rnf-6

## Objective
`docs/harness-glossary.md` **advisory dispatch** says the dispatch's `Implementer tier: <t>` line, when present, goes third (a verdict-owning dispatch has it second). `CONTEXT.md` **Reviewer dispatch opening line** gives the full opening-line order and links `[[advisory dispatch]]`. No other entry changes; `docs/harness-glossary.md:868` ("fix attempt") stays.

## Retrieval
Plan file: `docs/plans/2026-10-10-rnf-followups.md`, `## Unit rnf-6`. No per-unit issue exists. Umbrella (closed): `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Glossary edits
Each item replaces a substring inside the entry named by `heading:`. The `before:` text is that substring, with no leading or trailing spaces, so the line's own leading spaces stay. `text:` replaces exactly that substring. Lines of `text:` after the first carry their own two leading spaces.
1. file: `docs/harness-glossary.md`
   heading: `**advisory dispatch**:`
   before:
```
after the dispatch's `Unit: <id>` first line. On recognizing this token
```
   text:
```
after the dispatch's `Unit: <id>` first line. Its `Implementer tier: <t>`
  line, when present, goes third (a verdict-owning dispatch has it second).
  On recognizing this token
```
2. file: `CONTEXT.md`
   heading: `**Reviewer dispatch opening line**:`
   before:
```
dispatch but router routing breaks). Disciplined by lead-programmer dispatch
```
   text:
```
dispatch but router routing breaks). The opening lines go in order:
  `Unit: <task-id>` first; then `Implementer tier: <t>` for a verdict-owning
  dispatch, or `Mode: advisory` and then the tier line for an
  [[advisory dispatch]]; the tier line is omitted when the implementer
  dispatch passed no `model`. Disciplined by lead-programmer dispatch
```

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #529 is the closed umbrella and no per-unit issue exists: close nothing, and never close #529
- task-id: rnf-6
- marker first line: "PASS rnf-6 "
- commit: one commit of `CONTEXT.md` and `docs/harness-glossary.md` (plus one per fix round after a FAIL), made with `git add CONTEXT.md docs/harness-glossary.md && git commit -m "docs(rnf-6): reviewer dispatch line order in both glossaries (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"` (a fix round on another tier names that tier's model). Every commit of this unit carries `(rnf-6)` as its subject scope.
- precondition: `git log --format='%H %s' | /usr/bin/grep -cE '^[0-9a-f]+ [a-z]+\(rnf-6\): '` prints `0`; the tree is clean; each `before:` substring appears in its file exactly once (`/usr/bin/grep -cF -- '<before text>' <file>` prints `1`); the headings `**advisory dispatch**:` (in `docs/harness-glossary.md`) and `**Reviewer dispatch opening line**:` (in `CONTEXT.md`) each appear exactly once at the start of a line (measured at 1b5b2e3: all `1`). Anything else: STOP.
- if a glossary test rejects the new text, STOP and report the failing check verbatim; do not reshape the entries. If a message scan blocks `-m`, commit with `git commit -F <file>`; never rephrase to dodge a gate.
- this unit may run in a worktree in parallel with rnf-4 and rnf-5 (file-disjoint); it bumps nothing.
- the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.

## Do NOT touch
- every other entry of `CONTEXT.md` and `docs/harness-glossary.md`; do not add an **advisory dispatch** entry to `CONTEXT.md` (the term is defined once, in `docs/harness-glossary.md`, and `tests/context-glossary-links.test.js` rejects a second definition)
- `docs/harness-glossary.md:868` ("fix attempt is unstated.") stays as it is
- `docs/adr/` (ADR-0040 is a dated record), `agents/`, `templates/`, `tests/`, `adapters/`, `hooks/`, `.claude/`

## Acceptance criteria
1. run: `awk '/^\*\*advisory dispatch\*\*:$/,/^$/' docs/harness-glossary.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -cF 'first line. Its `Implementer tier: <t>` line, when present, goes third (a verdict-owning dispatch has it second).'`
   exit: 0
   stdout: `1`
   mutation: skip item 1; it prints `0`, exit 1. It prints `0` at HEAD.
2. run: `awk '/^\*\*Reviewer dispatch opening line\*\*:$/,/^$/' CONTEXT.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -cF 'The opening lines go in order: `Unit: <task-id>` first; then `Implementer tier: <t>` for a verdict-owning dispatch, or `Mode: advisory` and then the tier line for an [[advisory dispatch]]; the tier line is omitted when the implementer dispatch passed no `model`.'`
   exit: 0
   stdout: `1`
   mutation: skip item 2, or drop its link brackets; it prints `0`, exit 1. It prints `0` at HEAD.
3. run: `/usr/bin/grep -c 'fix attempt' docs/harness-glossary.md`
   exit: 0
   stdout: `1`
   mutation: reword line 868; it prints `0`, exit 1. It prints `1` at HEAD and must stay `1`.
4. run: `node tests/context-glossary-links.test.js 2>&1 | tail -n 1`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: misspell `[[advisory dispatch]]` in item 2 as `[[advisory dispatches]]`, or add an **advisory dispatch** entry to `CONTEXT.md`; the link or double-definition check fails and the last line changes. It already passes at HEAD and must stay green.
5. run: `node tests/ubiquitous-language.test.js 2>&1 | /usr/bin/grep -c 'passes all 4 structural/distinguishability checks'`
   exit: 0
   stdout: `1`
   mutation: set `UL_TEST_MUTATE=1`; the test exits non-zero and prints `0`. It already passes at HEAD and must stay green.
6. run: `node tests/rubric-doc-parity.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: a claim check that the harness-glossary edit leaves the **contract score** entry check green; it already passes at HEAD and must stay green.
7. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-6\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show -U0 --format= "$c" -- CONTEXT.md docs/harness-glossary.md | /usr/bin/grep -c '^@@'; done | paste -sd' ' -`
   exit: 0
   stdout: `2`
   mutation: also edit another entry; the count rises above `2`. Skip item 1 or item 2; it falls to `1`. With one unit commit the output is that one count.
8. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-6\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | LC_ALL=C sort -u | paste -sd' ' -`
   exit: 0
   stdout: `CONTEXT.md docs/harness-glossary.md`
   mutation: touch one extra file in the unit's commit; the list gains that path.
9. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-6\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(rnf-6\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
10. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-6\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
11. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(rnf-6\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- CONTEXT.md docs/harness-glossary.md | /usr/bin/grep -vcE '^[a-z]+\(rnf-6\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches either file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
12. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap; do not improvise.
~~~~~~~
