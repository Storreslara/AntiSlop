# Contract hardening: a stage after Stages 0-3 of the rubric-gated haiku programme (2026-10-06)

Status: FINAL (standard path, 12 units incl. follow-ups H1b and H11, so task-master slices them). Parent:
`docs/plans/2026-10-06-rubric-gated-haiku-programme.md` (cited by path and not
restated). Stages 0-3 of the parent are reviewer-PASSed at HEAD 325f51d, version
0.31.129. **Stages 4-5 and gates G3/G4 of the parent are untouched** by this plan.

## Goal

task-master does all the thinking. lead-programmer and scribe (target tier:
haiku) follow orders and never need to reason. This stage closes the gaps where
Stage 3's shipped text still leaves a decision to the implementer or scribe.
Units are ordered by importance for that goal.

| Goal clause | Unit | Criterion |
|---|---|---|
| The scorer measures exactly what the persona text demands (A6, A2 scorer half) | H1 | AC-H1.* |
| Every contract element is fully literal: review-packet template, version derivation, mutation proofs, indentation, anchors, split rule (A2, A3 content, A4, A6 wording) | H2 | AC-H2.* |
| A FAIL re-dispatch carries a contract; sibling and held units serialize and resume deterministically (A1 author side, A5) | H3 | AC-H3.* |
| The orchestrator routes FAILs through a fix contract, passes the scribe contract, and fills the PASS-line placeholder (A1, A3, C) | H4 | AC-H4.* |
| lead-programmer follows fix contracts and the packet template with no judgment left (A1, A2, C) | H5 | AC-H5.* |
| scribe decides nothing beyond its hard close rules (A3) | H6 | AC-H6.* |
| The exporter's CLI and parsing are strict (A6 exporter half), and `rubric_version` is recorded | H7 | AC-H7.* |
| Tier and turn-cap invariants are pinned and robust to line wrapping (C) | H8 | AC-H8.* |
| spec-master's Replay source / Incumbent baseline rules are well-defined (C) | H9 | AC-H9.* |
| Glossary and outcome README text matches what shipped (C) | H10 | AC-H10.* |

## Context

### Verified evidence (HEAD 325f51d)

- **A1.** On FAIL, the orchestrator "route[s] the defect list back to the
  lead-programmer" (agents/orchestrator.md:185-186; ladder at :434-437). The cap
  options at :337-352 re-dispatch with a debug spec or a human directive.
  lead-programmer's precedence applies only "When your dispatch is a dispatch
  contract" (agents/lead-programmer.md:30-36). So a fix turn runs with full
  judgment.
- **A2.** agents/lead-programmer.md:35 "Fill the ready-for-review packet template
  the contract supplies". No element supplies one (agents/task-master.md:112-145).
  The canonical term is **advisory review packet** (agents/lead-programmer.md:68).
- **A3.** agents/scribe.md:91-94 ("your own judgment applies only where the
  contract is silent"). scribe still owns wiki, changelog and stale
  module/api/conventions updates (:34-37) and the prune duty (:49-56).
  agents/task-master.md:224-226: `## ADR` is a number and title only, and
  `## Close conditions` holds "the quoted marker first line", while the example
  quotes only a prefix. Under review gating off, the PASS verdict line cannot be
  known when the contract is written (agents/scribe.md:96-101).
- **A4.**
  - agents/task-master.md:126-130 gives no version derivation.
  - The example's AC2 (:205-208) names the mutation "skip edit 3" (package.json),
    which `hooks/scripts/version-stamp-check.sh` cannot detect: it reads only
    `.claude-plugin/plugin.json` (:43). The version-sync block in
    `tests/validate.sh:92` catches it.
  - :72-74 hard-codes "all 14 `.claude/` paths", which is repo-specific in a
    shipped persona.
  - :193 uses `git add -A agents`.
  - :147-152: the self-check never proves its mutations, "Confirm every `anchor:`
    exists with `grep -n`" has no pattern, and "split or reported" is a choice.
- **A5.** agents/task-master.md:59-62: "Two units touching the same file" makes
  every persona unit collide on the bump files. There is no intersection table,
  held banner or resume rule. Its "re-resolved by the orchestrator" step has no
  counterpart in agents/orchestrator.md.
- **A6.** In bin/contract-score.js:
  - the POINTER regex holds 6 phrases (:6), while the persona names 2 (:124-125);
  - only backtick fences are recognised (:26, :34, :89, :150);
  - the tool probe is `command -v|which ` (:94);
  - context keys must start at column 0 (:98);
  - R6 counts any indented `-`/`*` line as a bullet and any backticked token as
    a path (:111-112);
  - `split('\n')` with no CR normalisation (:12, :69, :88, :149);
  - the scribe rows s1-s5 (:118-140) do not check `Unit:`, `## Objective`,
    `## Retrieval`, `## Escalation` or element order.

  scripts/unit-outcomes.js:21-30 `parseArgs` silently accepts unknown flags.
- **C (selected).**
  - agents/lead-programmer.md:33 "no explorer spawn" conflicts with :55-56
    "verify the specific claim you doubt".
  - :25-27 is the per-step commit cadence.
  - tests/writer-tier-consistency.test.js:67 does not strip whitespace (AC-D9 at
    :95-105 does).
  - docs/harness-glossary.md:3172 "halts" and :3185 "retained for re-work".
  - docs/persona-design-notes.md:34,63 already read `maxTurns: 120`, so no unit
    is needed there.
  - The parent plan's line 55 said task-master `maxTurns: 40`. It is corrected in
    this commit, because the plan doc is spec-master's own file.
- In the Bash tool `grep` is a shell function (ugrep) that does not reach
  sub-shells. Criteria use `/usr/bin/grep`.

### Measurement note (G3 confound)

The parent's G3 window opened at U3-4's PASS. H2 changes what contracts look
like inside that window. Default (Open Question 4): **pool** both as rubric
era, because hardened contracts are what haiku would receive. H7 adds a
`rubric_version` field (`v1` when `contract_ts` is at or before H2's PASS
`pass_ts`, `v2` after) so Stage 4 can stratify. The scorer keeps `--rubric=v1`
as its default, so G3 scores do not shift retroactively. task-master self-checks
with `--rubric=v2`.

### Contract-quality rules for every H contract (lesson B)

1. Every criterion's `mutation:` must demonstrably flip its check.
   - For phrase checks, this plan recorded each phrase's HEAD count (all 0 for
     added phrases; 1 for removed phrases such as `all 14`, `git add -A`,
     `defect block`), so "skip edit N" is demonstrated.
   - For anything else, task-master runs the mutation in a scratch copy and
     records a `proof:` line.
2. Never name `version-stamp-check.sh` as the detector of a skipped package.json
   bump. Use the **version-sync check** below. Its mutation was run 2026-10-06:
   bumping only plugin.json prints `version-sync: mismatch` and exits 1.
   ```
   node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;console.log(a===b?'version-sync: ok':'version-sync: mismatch');process.exit(a===b?0:1)"
   ```
3. Line counts and indentation numbers are computed with a command quoted in the
   contract (`wc -l`, `awk '{print match($0,/[^ ]/)-1}'`), never written from
   memory.
4. No `run:`/`command:` names the reviewed-marker directory or the persona config
   file (both gates refuse it). Stage the `--update` output with
   `git add -u -- .claude`.
5. Every commit subject ends with `(#<issue>)` so scribe can close the issue.
   Contracts carry this in `commit-message:`, and a criterion checks it:
   `git log --format=%s <B>..HEAD | /usr/bin/grep -vc '(#<issue>)$'` prints `0`.
6. **validate.sh runtime (10-12 min, above the 600000 ms foreground ceiling).**
   - Unit criteria use a **targeted check set**: the named `node tests/*.test.js`
     files, `bash -n` on changed shell, the version-sync check, AC-SCOPE-1/2/3,
     and `version-stamp-check.sh`.
   - The full `bash tests/validate.sh` runs once at gate **HG**, by the main
     session (which, unlike a subagent, is re-woken when a background job ends).
     It writes output to a scratch file and reads the real exit code from that
     file's last line, via `bash tests/validate.sh > $F 2>&1; echo "exit=$?" >> $F`.
   - A non-zero result at HG becomes a FAIL routed to the latest unit touching
     the failing check.
7. Any scribe contract editing `docs/harness-glossary.md` or `CONTEXT.md` runs
   `node tests/context-glossary-links.test.js` and
   `node tests/ubiquitous-language.test.js` (exit 0) before committing.
   Lesson: a9ecb19 broke the link test.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-06 Functional scope & success criteria: Q who writes a FAIL re-dispatch contract? → A (default, Open Question 1): task-master writes a **fix contract** from the latest FAIL block. The orchestrator dispatches task-master between the FAIL verdict and the fix dispatch. The 2-FAIL cap, the implementer-tier ratchet and reviewer routing are unchanged. Without task-master, today's defect-list re-dispatch stands
- 2026-10-06 Functional scope & success criteria: Q do scribe's wiki/changelog/prune duties move into the contract? → A (default, Open Question 2): per-unit doc edits move into a `## Doc edits` element (items, or the literal `none — make no other doc changes`). The prune duty is release-only and stays out of per-unit contracts, as `prune: none`
- 2026-10-06 Non-functional attributes: Q how is validate.sh run given its 10-12 min runtime? → A (self-resolved): a targeted check set per unit plus one full run at gate HG by the main session (rule B6)
- 2026-10-06 Edge cases / failure handling: Q what if a fix needs diagnosis? → A (self-resolved): the fix contract carries `diagnosis: required`, the one declared case in which lead-programmer's judgment duties apply. The tier ratchet already sends that attempt to opus
- 2026-10-06 Technical constraints & tradeoffs: Q add a 10th contract element for the packet template? → A (self-resolved): no. The nine-element shape is pinned by H4's dispatch-hygiene check (hooks/scripts/dispatch-hygiene.sh:366) and its tests, so the template goes inside `## Pre-resolved context` as a `review-packet:` fenced block
- 2026-10-06 Technical constraints & tradeoffs: Q harden version-stamp-check.sh to read package.json? → A (default, Open Question 3): no unit. The version-sync check covers it in contracts, and the hook is guarded (`hooks/`, SENSITIVE_PATHS, mirrored with `fileHashes`)
- 2026-10-06 Terminology consistency: Q "ready-for-review packet template", "defect block", "Pre-dispatch self-check", "executor"? → A (self-resolved): **advisory review packet** (template), **FAIL block** (CONTEXT.md:771), **contract self-check** (already in the harness glossary), **implementer**
- 2026-10-06 Completion / acceptance signals: Q how is the G3 confound handled? → A (default, Open Question 4): pool both eras, record `rubric_version`, and keep scorer default v1

## Risks / dependencies

- HR1 H2 is the largest unit. Its contract must stay under 30000 bytes. If it
  cannot, task-master splits it by the plan's sub-bullets (a)-(d), each a separate
  version bump.
- HR2 H1 before H2 (the examples must score under v2). H2 before H3 (H3 cites the
  v2 elements). H3 before H4 and H5 (they reference the fix contract).
- HR3 Prior FAIL history: the Stage 0-3 persona units carried false mutation
  claims (lesson B). These are new units, but task-master tags none of them below
  the default tier.
- HR4 H4 edits the orchestrator, which carries the guarded 2-FAIL-cap section and
  the AC-D7/D9/D9b pins. AC-H4.4 proves them unchanged.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every pinned phrase's HEAD count and the version-sync mutation were run before publishing.
- P2 "Prefer deterministic scripts": satisfied. Mirrors and `fileHashes` change only via `node bin/cli.js --update`, staged with `git add -u -- .claude`.
- P3 "Version-stamp discipline": satisfied. H2, H3, H4, H5, H6 and H9 bump plugin.json and package.json and add a CHANGELOG entry in the same commit; checked by `version-stamp-check.sh` = `ok` plus the version-sync check.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. The fix-contract routing and scribe-contract passing are phrased "if task-master is present" / "if scribe is present" (AC-H4.3, AC-H5.3).
- P5 "tests/validate.sh is the merge gate": satisfied via gate HG (rule B6); new tests are registered in validate.sh.

## Units (dispatch order)

Persona-file units follow the parent's **Persona-unit scope rule**
(AC-SCOPE-1/2/3; parent plan section of that name) with the OWN/extra files
named per unit. Version chain, serial, assuming no interleaved bump (otherwise
HEAD + 1):

| Unit | Sets version |
|---|---|
| H2 | 0.31.130 |
| H3 | 0.31.131 |
| H4 | 0.31.132 |
| H5 | 0.31.133 |
| H6 | 0.31.134 |
| H9 | 0.31.135 |

H1, H7, H8 and H10 set no version and may interleave (H1 must precede H2).
"Flattened grep" means `tr '\n' ' ' < F | tr -s ' ' | /usr/bin/grep -cF 'P'`.
"Persona baseline" means: version-sync check prints `version-sync: ok`;
`bash hooks/scripts/version-stamp-check.sh <B>..HEAD` starts
`version-stamp-check: ok`; `node tests/writer-tier-consistency.test.js` exit 0;
AC-SCOPE-1/2/3; commit-subject check (B5).

### H1: scorer v2 (`bin/contract-score.js`, non-persona)
Affected: `bin/contract-score.js`, `tests/contract-score.test.js`,
`tests/fixtures/contract-score/v2-*.md`. Behaviour: `--rubric=v1` (default,
current behaviour byte-for-byte) and `--rubric=v2`. v2 changes:
- fences are ``` or `~~~`, of any length ≥3, closed by the same char and length;
- CRLF is normalised to LF;
- context keys may be indented, provided they sit under `## Pre-resolved context`;
- R5 additionally requires a `review-packet:` key followed by a fenced block
  containing ≥1 `<FILL:` blank and no other placeholder;
- R6 counts only lines whose marker `-`, `*` or `+` sits at column 0 or 1, and
  the backticked token must contain `/` or `.`;
- R1 fenced payloads require an `indent: N` line, and every payload line must
  start with ≥N spaces;
- the scribe shape becomes 7 rows:
  - S1 Glossary edits;
  - S2 ADR (`none`, or `NNNN <title>` plus a `body:` fenced payload);
  - S3 Close conditions (`#N`, task-id, and the prefix `"PASS <task-id> "` or the literal `<PASS-VERDICT-LINE>`);
  - S4 Do NOT touch;
  - S5 criteria;
  - S6 `## Doc edits` (file/heading/text items, or the literal `none — make no other doc changes`);
  - S7 skeleton (`Unit:` first line, and all required headings present in order).

The JSON output gains `"rubric":"v1"|"v2"`.
- AC-H1.1 `node tests/contract-score.test.js` exit 0. The suite covers:
  - v1 regression: all existing fixtures give the same output;
  - a v2 all-pass fixture (score 7);
  - one `v2-minus-<row>.md` per changed rule (R1-indent, R5-packet, R6-col, R6-path, S3, S6, S7), each differing from all-pass by one edit and flipping only that row;
  - `~~~~~` and CRLF fixtures that score 7 under v2 and lower under v1.
- AC-H1.2 Mutation proof inside the suite: reverting any v2 rule to v1 behaviour fails ≥1 named assertion (the suite prints the assertion name).
- AC-H1.3 `node bin/contract-score.js --rubric=v3 x` exits 2.

**Correction (2026-10-06, after H1's review).**
- AC-H1.1's list of changed rules ("R1-indent, R5-packet, R6-col, R6-path, S3,
  S6, S7") was incomplete. Ruling H-B also changes S1 (a single `none`) and S2
  (the ADR form). R2, R3, R4, R7, S4 and S5 differ from v1 through v2's fence
  and section handling.
- H1's mutation clause "each other v2 rule reverted to v1 likewise fails its
  named check" was false for eight rows. Measured at 08eb23a: swapping each of
  R2, R3, R4, R7, S1, S2, S4 and S5 in `SHAPES_V2` back to its v1 function
  leaves `node tests/contract-score.test.js` at exit 0, while the R1 and R6
  swaps exit 1.
- H1b closes this.

### H1b: scorer v2 lock-in fixtures and lookup hardening (non-persona)
Scope `rgh-h1b`. Affected: `tests/contract-score.test.js`,
`tests/fixtures/contract-score/`, `bin/contract-score.js`. No version bump.
- Two commits:
  - **red:** fixtures and checks, `test(rgh-h1b): ... (#<issue>)`;
  - **green:** code, `fix(rgh-h1b): ... (#<issue>)`.
- Dispatch after H1. H2 does NOT depend on H1b: the files are disjoint, and H2's
  examples contain no fenced Do-NOT-touch lines.

**Fixtures.** Each is derived by one literal edit from `v2-all-pass.md` (L) or
`v2-scribe-all-pass.md` (Sc). I prototyped each one at 08eb23a; the observed
rows are recorded below.

| Fixture | Derivation | v2 | v1 |
|---|---|---|---|
| `v2-fenced-heading-R2.md` | L: append a `~~~` block holding `## Affected files` and `## End` to the Objective paragraph, and delete acceptance criterion 2 (the `version-stamp-check.sh` item) | R2 false | R2 true |
| `v2-fenced-heading-R3.md` | L: insert a `~~~` block holding `## Note` right after the `## Acceptance criteria` heading | R3 true | R3 false |
| `v2-tilde-run-R4.md` | L: append a `~~~` block holding ``run: `cat /tmp/x` `` to the Objective | R4 true | R4 false |
| `v2-indented-diagnosis.md` | L: `diagnosis: none` becomes `  diagnosis: none` | R7 true | R7 false |
| `v2-S1-none.md` | Sc: the Glossary edits item becomes the single line `none` | S1 true | S1 false |
| `v2-minus-S2-bare-title.md` | Sc: the ADR body becomes `0042 Demo decision` | S2 false | S2 true |
| `v2-minus-S2-backticked-none.md` | Sc: the ADR body becomes `` `none` `` | S2 false | S2 true |
| `v2-fenced-heading-S4.md` | Sc: append a `~~~` block holding `## Do NOT touch` and `## End` to the Objective | S4 true | S4 false |
| `v2-fenced-heading-S5.md` | Sc: insert a `~~~` block holding `## Note` after `## Acceptance criteria` | S5 true | S5 false |
| `v2-r1-pointer-in-anchor.md` | L: edit 1's anchor becomes ``line matching `see the plan old line` `` | R1 true | (n/a) |
| `v2-fence-len.md` | L: edit 1's `after:` fence becomes a 4-tilde `~~~~` fence holding the lines `~~~` and `as needed` (3-space indent) | R1 true | (n/a) |
| `v2-fence-char.md` | L: edit 1's `after:` `~~~` fence holds the lines `` ``` `` and `as needed` (3-space indent) | R1 true | (n/a) |
| `v2-minus-S6-prune-not-last.md` | Sc: the Doc edits lines are swapped (`prune: none` first) | S6 false | (n/a) |
| `v2-r6-nested.md` | L: insert `  - nested prose note` (column 2) after the first Do NOT touch bullet | R6 true | R6 false |
| `v2-r6-fenced.md` | L: append a `~~~` block holding `- x` to Do NOT touch | R6 true (after green; false at 08eb23a) | R6 false |

**Remove** `v2-crlf.md`. It is an LF decoy: `.gitattributes` `eol=lf` strips
its CRs, so its blob holds 0 CR bytes. Its check is rebuilt in the test: read
`v2-all-pass.md`, `.replace(/\n/g, '\r\n')`, assert the input contains `\r`,
and pipe it to `node bin/contract-score.js - --rubric=v2`, which must give
score 7. Under `--rubric=v1` it must score below 7 (measured: 4 and 4). The
check keeps the name `v2-crlf`. `.gitattributes` is not touched.

**Code (green commit).**
- Both table lookups in `main()` use `Object.hasOwn` (`{v1,v2}` and
  `table[shape]`). `--rubric=__proto__` or `--shape=toString` then exits 2 with
  the usage line. At 08eb23a they exit 0 with score 0 (measured).
- `r6v2` drops lines whose `fenceFlags` value is non-null before counting
  bullets, as `r5v2` does. This is defensible hardening, included, and proven
  by `v2-r6-fenced`.

**Named checks.** One per new fixture, named by its file stem, asserting the v2
row above. For the eight rows (R2, R3, R4, R7, S1, S2 ×2, S4, S5) the check also
asserts that the v1 row differs on the same file. Plus `v2-usage-proto-rubric`
and `v2-usage-proto-shape` (exit 2).

**Acceptance criteria.**
- AC-H1b.1 `ls tests/fixtures/contract-score/v2-*.md | wc -l` prints `37` (23 − 1 + 15), and `test -e tests/fixtures/contract-score/v2-crlf.md` exits 1.
- AC-H1b.2 `node tests/contract-score.test.js | /usr/bin/grep -c '^OK   v2'` prints `40` (23 + 15 + 2), and the suite exits 0.
- AC-H1b.3 Red commit: at the red commit, the suite exits 1, and its failing checks are exactly `v2-r6-fenced`, `v2-usage-proto-rubric` and `v2-usage-proto-shape` (every other new check passes, because the behaviour already exists and is being locked in).
- AC-H1b.4 Mutation proofs, all measured by spec-master at 08eb23a in a scratch copy:
  - each of the eight `SHAPES_V2` row swaps (R2→r2, R3→r3, R4→r4, R7→r7, S1→s1, S2→s2, S4→s4, S5→s5) now fails the check of that row's fixture;
  - **M3b** (delete the `anchor: line matching` literal strip at bin/contract-score.js:239) makes R1 false on `v2-r1-pointer-in-anchor`;
  - **FLEN** (close a fence on any same-char run of 3 or more) and **FCHAR** (close on any fence run) make R1 false on `v2-fence-len` and `v2-fence-char`;
  - **PRUNE** (accept `prune: none` anywhere) makes S6 true on `v2-minus-S6-prune-not-last`;
  - **R6N** (count bullets at any indent) makes R6 false on `v2-r6-nested`;
  - removing CRLF normalisation (bin/contract-score.js:400) scores the generated CRLF input 4, failing `v2-crlf`.

  The implementer re-runs each mutation in a scratch copy and lists the failing check name per mutant in the review packet.
- AC-H1b.5 The v1 regression still holds: every pre-H1 fixture's `--rubric=v1` output is unchanged (H1's AC-H1.1 check stays green).
- AC-H1b.6 Commit subjects: `git log --format=%s <B>..HEAD | /usr/bin/grep -vcE '^(test|fix)\(rgh-h1b\): .* \(#[0-9]+\)$'` prints `0`.

### H2: task-master contract content (`agents/task-master.md`, 0.31.130)
OWN: `agents/task-master.md`. Extra: `tests/contract-examples.test.js` (new),
`tests/validate.sh` (register it). Pinned edits, each a bold-label rule in the
contract section (anchors: the elements list at :112-145, the self-check at
:147-152, the examples at :161-260):
- (a) A2: element 8 gains `review-packet:`, a fenced advisory review packet
  template whose only blanks are `<FILL: ...>` for observed results (changed
  files, commit SHAs, each criterion's actual exit/stdout).
- (b) A4:
  - **Version derivation.** The new version is HEAD's plugin.json version, patch
    +1 per stamped unit in serial order, read with
    `node -p "require('./.claude-plugin/plugin.json').version"`.
  - **Mutation proof.** A `mutation:` is either "skip edit N", proven by running
    the `run:` at the pre-edit HEAD, or carries a `proof:` line naming the scratch
    command run. A package.json bump is checked with the version-sync check, never
    `version-stamp-check.sh`.
  - "all 14 `.claude/` paths" becomes "every path `--update` changes", and the
    commit is followed by `git status --porcelain --untracked-files=no` = empty.
  - **Payload indentation.** Each fenced payload states `indent: N` (computed),
    and N spaces are stripped.
  - **Literal anchors.** `anchor: line matching \`<literal>\``, which the
    self-check confirms with `/usr/bin/grep -cF` = 1. A split payload's second
    anchor is the last line of the first payload.
  - **Split or gap.** R7 or a missing decision is a spec gap; size or R1/R3
    shortfall is a split.
  - The example's `git add -A agents` becomes explicit paths.
- (c) A6 wording: list all six pointer phrases; tool probe = `command -v` or
  `which `; context keys start at column 0 (or as v2 allows); `~~~` fences
  allowed. Rename "Pre-dispatch self-check" to **Contract self-check**, which runs
  `node bin/contract-score.js --rubric=v2`. "executor" becomes "implementer".
- (d) A3 scribe contract:
  - `## Doc edits` (S6);
  - `## ADR` with a `body:` payload;
  - Close conditions quote the prefix `"PASS <task-id> "`, or `<PASS-VERDICT-LINE>` under review gating off (the orchestrator fills it, H4);
  - `prune: none`;
  - any contract editing a glossary carries the two link and terminology tests (B7).

  The scribe example is updated to 7/7.
- AC-H2.1 `node tests/contract-examples.test.js` exit 0. It extracts the whole-line-anchored lead and scribe examples and asserts `"score":7` for each under `--rubric=v2`. Mutation: delete the example's `review-packet:` block; the lead score drops to 6 (proof: the H1 fixture `v2-minus-R5-packet`).
- AC-H2.2 Flattened greps of `agents/task-master.md` = 1 each: `review-packet:`, `Version derivation`, `Mutation proof`, `every path \`--update\` changes`, `Payload indentation`, `Literal anchors`, `Split or gap`, `Contract self-check`, `Doc edits`, `PASS-VERDICT-LINE`, `prune: none`. All are 0 at 325f51d.
- AC-H2.3 Flattened greps = 0: `all 14`, `Pre-dispatch self-check`. Plus `/usr/bin/grep -c 'git add -A' agents/task-master.md` = 0. All are 1 at 325f51d.
- AC-H2.4 The same AC-H2.2 greps against `.claude/agents/task-master.md` = 1 each.
- AC-H2.5 Persona baseline. AC-SCOPE extras: the two test files.

### H3: task-master slicing and fix contracts (`agents/task-master.md`, 0.31.131)
OWN: `agents/task-master.md`. Depends on H2. Pinned rules (anchor: the bullets
at :55-74):
- **Fix contract.** On a FAIL, if task-master is present, it writes a nine-element
  fix contract for the same `Unit:` id from the latest FAIL block. The edits are
  literal. The criteria are the original ones, plus one per defect. It carries
  `fix-of: <FAIL header timestamp>`, or `diagnosis: required` when the cause is
  unknown. It never changes the tier tag; the ratchet stays.
- **Shared file, defined.** "File" excludes the bump files (plugin.json,
  package.json, CHANGELOG.md) and paths generated by `--update`.
- **Stamped-file units serialize.** Units editing version-stamped files always
  get serial `Depends on` edges, because each sets HEAD + 1.
- The slice report includes a unit × shared-file intersection table.
- Held units are filed, and their issue body's first line is `HELD: <reason>`.
  They are never dispatched while that line stands. This replaces "are not
  published" in **Partial slice on a spec gap**, matching current practice; see
  ruling H-E(ii).
- **Resume from slice state.** The Slice state table is posted as a comment on
  the umbrella issue. On re-invocation task-master reads it and, for each held
  unit whose gap is resolved, removes the `HELD:` line by editing the issue. It
  never re-files a unit.
- Remove "re-resolved by the orchestrator" (anchors are literal patterns per H2).
- The fast-path sentence becomes "On the fast path spec-master writes it;
  task-master never runs the fast path".
- Add "the finalized spec stands in for user approval" for to-tickets' approval
  loop.
- AC-H3.1 Flattened greps = 1 each: `Fix contract`, `fix-of:`, `diagnosis: required`, `Shared file, defined`, `Stamped-file units serialize`, `HELD:`, `Resume from slice state`, `never runs the fast path`, `stands in for user approval`. All are 0 at 325f51d (measured).
- AC-H3.2 Flattened grep `re-resolved by the orchestrator` = 0 (1 at 325f51d).
- AC-H3.3 Mirror greps for AC-H3.1 = 1 each.
- AC-H3.4 Persona baseline (AC-D5's literal `` `sonnet` is\n  the default for every unit`` intact).

### H4: orchestrator routing (`agents/orchestrator.md`, 0.31.132)
OWN: `agents/orchestrator.md`. Depends on H3. Pinned:
- **Fix-contract re-dispatch.** After a FAIL verdict, if task-master is present,
  dispatch task-master (default tier; never `fable`) to write the fix contract,
  then dispatch lead-programmer with it on the ratcheted tier. Without
  task-master, the defect-list re-dispatch is unchanged. Inserted after :185-186
  and referenced from :434-437, without editing the "Sonnet units escalate on
  first FAIL" sentence or the "At the 2-FAIL cap" section.
- Scribe convention (:41-50): the orchestrator **passes the scribe dispatch
  contract** (if scribe is present) and, under review gating off, replaces
  `<PASS-VERDICT-LINE>` with the reviewer's verbatim PASS line.
- AC-H4.1 Flattened greps of `agents/orchestrator.md` = 1 each: `Fix-contract re-dispatch`, `passes the scribe dispatch contract`, `<PASS-VERDICT-LINE>`. All are 0 at 325f51d.
- AC-H4.2 Mirror greps = 1 each.
- AC-H4.3 P4: flattened grep `if task-master is present` ≥ 1, and `if scribe is present` ≥ 1, in agents/orchestrator.md.
- AC-H4.4 Guarded text unchanged: `git diff <B>..HEAD -- agents/orchestrator.md | /usr/bin/grep -cE '^-.*(At the 2-FAIL cap|Sonnet units escalate on first FAIL|fable. is excluded)'` = 0, and `node tests/writer-tier-consistency.test.js` exit 0 (AC-D7, D9, D9b).
- AC-H4.5 Persona baseline.

### H5: lead-programmer under contracts (`agents/lead-programmer.md`, 0.31.133)
OWN: `agents/lead-programmer.md`. Extra:
`adapters/cursor/agents/lead-programmer.md`,
`adapters/codex/agents/lead-programmer.toml` (hand-maintained ports; same text,
same commit). Pinned, in the Contract precedence bullet (:30-36):
- **Fix turns.** A fix contract is a dispatch contract and precedence applies.
  Only `diagnosis: required` re-enables judgment duties. A defect-list
  re-dispatch without a contract (task-master absent) leaves them in force.
- Replace "ready-for-review packet template the contract supplies" with "the
  advisory review packet template in `review-packet:`; fill only its `<FILL:`
  blanks".
- "no explorer spawn, not even to verify a doubted claim; report a spec gap
  instead".
- **Commit cadence under a contract**: the `commit-message:` lines fix the count,
  overriding the per-step cadence at :25-27.
- AC-H5.1 Flattened greps = 1 each, in all three files: `Fix turns`, `advisory review packet template`, `not even to verify`, `Commit cadence under a contract`. All are 0 at 325f51d.
- AC-H5.2 Flattened grep `ready-for-review packet template` = 0 in all three files (1 in agents/lead-programmer.md at 325f51d).
- AC-H5.3 P4: `task-master, if present` is still ≥1. `node tests/adapter-protocol-parity.test.js` exit 0.
- AC-H5.4 Persona baseline (`model: sonnet` intact).

### H6: scribe decides nothing (`agents/scribe.md`, 0.31.134)
OWN: `agents/scribe.md`. Pinned, replacing the Contract precedence paragraph
(:91-94):
- "**Contract-only doc edits.** With a scribe dispatch contract (if task-master
  is present), make exactly the contract's Glossary edits, Doc edits and ADR body,
  and no other doc change; skip the prune duty unless the contract says otherwise.
  The four close conditions and every never-close rule still apply on top of the
  contract."
- The judgment duties at :34-37 and :49-56 apply only to dispatches without a
  contract.
- `model: haiku` is kept.
- AC-H6.1 Flattened greps = 1: `Contract-only doc edits`, `every never-close rule still apply`. Both are 0 at 325f51d.
- AC-H6.2 Flattened grep `your own judgment applies only where the contract is silent` = 0 (1 at 325f51d).
- AC-H6.3 Mirror greps = 1. `sed -n '1,12p' agents/scribe.md | /usr/bin/grep -c '^model: haiku$'` = 1.
- AC-H6.4 Persona baseline.

### H7: exporter strictness (`scripts/unit-outcomes.js`, non-persona)
Affected: `scripts/unit-outcomes.js`, `tests/unit-outcomes.test.js`, fixtures.
- `--help` prints usage and exits 0 without exporting.
- An unknown flag prints `unknown flag: <f>` and exits 2.
- The `Unit:` match is anchored to the contract's first line.
- The test's `gh` stub honours `--limit`.
- A new field `rubric_version` (see Measurement note).
- G3 output is otherwise unchanged.
- AC-H7.1 `node tests/unit-outcomes.test.js` exit 0, with assertions for each item. A mutation of each (removing the check) fails a named assertion.
- AC-H7.2 `node scripts/unit-outcomes.js --help` prints `usage:` and exits 0 within 5 s (`timeout 5`). `node scripts/unit-outcomes.js --bogus` exits 2.

### H11: G3 scores each unit under its own rubric_version (non-persona)
Scope `rgh-h11`. Affected: `scripts/unit-outcomes.js`,
`tests/unit-outcomes.test.js`, and fixtures under `tests/fixtures/` used by that
test. No version bump.
- Two commits: `test(rgh-h11): … (#<issue>)` (red), then `feat(rgh-h11): … (#<issue>)` (green).
- Dispatch after H7 (#509, passed at cfe6790). It does NOT depend on H2: the
  fixtures supply their own v2 contracts and their own `rgh-h2` PASS marker.

**Behaviour:**
- `contract_score` keeps its meaning: the v1 score, unchanged, for G3 history
  and snapshot comparability.
- A new field `contract_score_v2` holds the `score` from
  `bin/contract-score.js - --rubric=v2` over the same contract text, or null
  when `contract_score` is null.
- `gateG3` counts a rubric-era unit toward `scored7` iff its per-version score
  is 7. The per-version score is `contract_score` when `rubric_version` is `v1`,
  and `contract_score_v2` when it is `v2`. Units with null `rubric_version` are
  outside the population already.
- The `G3 open`/`G3 closed` line format is unchanged.
- Discriminator (measured 2026-10-06): `tests/fixtures/contract-score/v2-all-pass.md`
  scores 6 under v1 and 7 under v2. `all-pass.md` (v1-format) scores 7 under v1
  and 6 under v2.

**New checks, prefix `g3v2`** (does not collide with `g3` 6, `asof` 3,
`source` 4, `era` 4, `strict` 4, `rubric_version` 4, `until` 3, `issue` 3,
`timestamps` 2, `read-only` 2; 46 `^OK` lines at cfe6790):
- `g3v2 field`: a fixture unit whose issue contract is `v2-all-pass.md` has
  `contract_score` 6 and `contract_score_v2` 7. A no-contract unit has both null.
- `g3v2 v2-counts`: a G3 fixture set has 60 rubric-era units. 10 are v1 with v1
  score 7, 10 are v2 (after the fixture's `rgh-h2` PASS) with v2 score 7 and v1
  score 6, and 40 score below 7 under their own version. It prints `G3 open` and
  `scored7=20`.
- `g3v2 v1-not-v2`: the same set, except the 10 v1 units carry v1-format
  contracts scoring 6 under v1 and 7 under v2. It prints `G3 closed` and
  `scored7=10`.
- `g3v2 v2-not-v1`: the same set as `v2-counts`, but `rgh-h2` has no PASS, so
  all 20 are `v1`. It prints `scored7=10`, because the v2 contracts score 6
  under v1.

**Acceptance criteria:**
- AC-H11.1 `node tests/unit-outcomes.test.js | /usr/bin/grep -c '^OK   g3v2'` prints `4`. The total `^OK` count is 50 (46 + 4). The existing 6 `g3` checks still pass, and the suite exits 0.
- AC-H11.2 Red commit (corrected 2026-10-06, ruling H-G): exactly three checks fail, `g3v2 field`, `g3v2 v2-counts` and `g3v2 v1-not-v2`. Every other check passes, including `g3v2 v2-not-v1`. That check is a regression guard: its expected `scored7=10` is already what the v1-only rule prints, and it stays green across red and green so that the v2 path never counts v2 contracts while `rgh-h2` has no PASS. Measured by task-master on a clone of f1422db.
- AC-H11.2b Helpers: the new checks use their own five-tilde wrapper (`wrap5`, `g3v2Run`), because the existing `g3Set` wraps issue bodies in a three-tilde fence that cuts v2 contracts off at their own `~~~` lines. `g3Set` is not modified: `git diff <B>..HEAD -- tests/unit-outcomes.test.js | /usr/bin/grep -c '^-.*g3Set'` prints `0`.
- AC-H11.3 Mutation proofs (the implementer runs each in a scratch copy and names the failing check):
  - **M-v1only** (`gateG3` counts `contract_score === 7` for every unit, the shipped behaviour) fails `g3v2 v2-counts` (prints `scored7=10`).
  - **M-v2only** (counts `contract_score_v2 === 7` for every unit) fails `g3v2 v1-not-v2` (prints `scored7=20`, `G3 open`).
  - **M-field** (compute `contract_score_v2` with the v1 default) fails `g3v2 field`.

  The premise of all three (the same text scoring 6 and 7 under the two rubrics) was measured by spec-master on the two fixtures named above.
- AC-H11.4 `node scripts/unit-outcomes.js --until=2026-10-06T00:00:00Z | jq -s 'length > 0 and all(has("contract_score_v2"))'` prints `true` (`length > 0` added in ruling H-G, because `all()` is vacuously true on empty input).
- AC-H11.5 Commit subjects: `git log --format=%s <B>..HEAD | /usr/bin/grep -vcE '^(test|feat)\(rgh-h11\): .* \(#[0-9]+\)$'` prints `0`.
- AC-H11.6 `git diff --name-only <B>..HEAD` lists only `scripts/unit-outcomes.js`, `tests/unit-outcomes.test.js` and files under `tests/fixtures/`. The committed snapshot `docs/audits/unit-outcomes/2026-10-06.jsonl` is NOT regenerated: it is the 2026-10-06 historical record, and nothing automated re-runs U0-3's reproduction (no test or script references the snapshot, checked with `git grep -l 2026-10-06.jsonl -- tests bin scripts hooks`). The README's comparison note, extended by H10 (AC-H10.14), excludes the post-snapshot fields `rubric_version` and `contract_score_v2`.

**G3 snapshot refresh:** none needed. The orchestrator evaluates G3 live with
`node scripts/unit-outcomes.js --gate=G3`, which reads markers, issues and
transcripts directly. A refreshed snapshot, if one is ever wanted for Stage 4,
belongs to U4-3.

### H8: invariant tests (non-persona)
Affected: `tests/writer-tier-consistency.test.js`.
- AC-D6 uses `stripWhitespace` (strip-all; the item06-3 NOTE[spec] convention).
- A new AC-T1 asserts `^maxTurns: 120$` in `agents/spec-master.md` and
  `agents/task-master.md`.
- A new AC-A1 asserts that the Contract precedence paragraph's normalised text is
  identical across lead-programmer source and its two ports, after H5.
- AC-H8.1 `node tests/writer-tier-consistency.test.js` exit 0.
- AC-H8.2 Mutation proofs, run by the implementer in a scratch copy and recorded in the packet:
  - inserting `looks\nmechanical` into a copy of task-master.md fails AC-D6;
  - setting `maxTurns: 40` fails AC-T1;
  - altering one port's paragraph fails AC-A1.

### H9: spec-master rule fixes (`agents/spec-master.md`, 0.31.135)
OWN: `agents/spec-master.md`.
- **Replay source** (inserted by U2-1): the lookup uses each recorded unit's
  `final_commit` with `git show --name-only` for files, cites every matching
  criterion, and is "answered by the plan's own `mutation:` line".
- **Incumbent baseline** (U2-2): "one row per defect in each FAIL block".
  "defect block" becomes "FAIL block". Convergence follow-ups use the columns
  finding id, finding, revised criterion, prior criterion ("finding id and prior
  criterion").
- AC-H9.1 Flattened greps = 1: `` plan's own `mutation:` line ``, `one row per defect in each FAIL block`, `finding id and prior criterion`. All are 0 at 325f51d.
- AC-H9.2 Flattened grep `defect block` = 0 (1 at 325f51d).
- AC-H9.3 Mirror greps. Persona baseline (AC-D9 spec-master check intact).

### H10: glossary and README accuracy (scribe contract, non-persona)
Affected: `docs/harness-glossary.md`, and `docs/audits/unit-outcomes/README.md`
(written by the implementer if scribe's custody excludes `docs/audits`; default:
lead-programmer for the README, scribe for the glossary, as two contracts under
one unit id).
- Glossary :3172 "halts" becomes "stops slicing the gap unit".
- Glossary :3185 "retained for re-work…" is cut to the shipped behaviour.
- Glossary link citations use section anchors.
- New entries: **fix contract**, **contract self-check** (update), **review-packet**.
- README: "plan stem"; `task_master_cutoff` is always null until measured;
  `final_commit` is null also for `commit: none`; short SHAs; the replay-pool term.
- AC-H10.1 `node tests/context-glossary-links.test.js` exit 0, and `node tests/ubiquitous-language.test.js` exit 0.
- AC-H10.2 `/usr/bin/grep -c 'halts' docs/harness-glossary.md` is one lower than at `<B>` (computed at slicing time). Flattened grep `**fix contract**` = 1.
- AC-H10.3 `git diff --name-only <B>..HEAD` lists only the two affected files.

### Gate HG (stage end; main session)
Run the full suite per B6: `bash tests/validate.sh > $F 2>&1; echo "exit=$?" >> $F`.
The last line must be `exit=0`. Then mark the stage done.

## Spec-gap rulings (task-master, 2026-10-06)

These rulings supersede any conflicting text above. Each regex was run against
the fixtures named, on 2026-10-06.

**H-A (H1 R5 v2, review-packet placeholders).** Applied only to the fenced block
after `review-packet:`:
- Blank: `/<FILL:[^<>\n]*[^<>\s][^<>\n]*>/g` (`<FILL:` plus ≥1 non-space
  character, no nested `<>`).
- Forbidden other placeholder, tested after removing every blank:
  `/<FILL:\s*>|<(?!FILL:)[A-Za-z][^<>\n]*>|\b(?:TODO|TBD|FIXME|XXX)\b/`.
- Allowed non-blank text: everything else, including `->`, `a < b` and
  `<!-- ... -->`. There is no allowed `<name>` token: task-master writes the
  literal task-id, issue number and file paths, because it knows them.
- R5 v2 holds iff blanks ≥ 1 and the forbidden test is false.
- `<PASS-VERDICT-LINE>` is NOT subject to this rule. It is legal only in the
  scribe shape, only inside `## Close conditions` (S3), and spelled exactly
  `<PASS-VERDICT-LINE>`. The scribe shape has no review-packet.
- Fixtures (in tests/fixtures/contract-score/):

  | Fixture | Content | R5 |
  |---|---|---|
  | `v2-r5-pass.md` | `<FILL: changed files>` | true |
  | `v2-r5-tokens-ok.md` | `<FILL: a>` plus `x -> y, a < b, <!-- c -->` | true |
  | `v2-r5-name-token.md` | `<task-id> <FILL: x>` | false |
  | `v2-r5-todo.md` | `<FILL: a> TBD` | false |
  | `v2-r5-empty-fill.md` | `<FILL: a> <FILL:>` | false |
  | `v2-r5-no-blank.md` | no `<FILL:` | false |

  All six were measured on the final regexes above (node, 2026-10-06). The
  empty-fill row needs the `<FILL:\s*>` arm; without it `<FILL:>` is silently
  ignored.

**H-B (S7 heading order, `prune:`, ADR body).** The v2 scribe contract is, in
this exact order:
- `Unit: <task-id>` as line 1, written as the literal id;
- `## Objective`, `## Retrieval`, `## Glossary edits`, `## Doc edits`, `## ADR`,
  `## Close conditions`, `## Do NOT touch`, `## Acceptance criteria`,
  `## Escalation`.

S7 holds iff line 1 matches `^Unit: \S+$` and the sequence of `^## (.+)$`
headings equals that list exactly: no extras, none missing, same order.
- `## Glossary edits`: items `file:`/`heading:`/`text:`, or the single line
  `none`.
- `## Doc edits`: items `file:`/`heading:`/`text:`, or the line
  `none — make no other doc changes` (regex `^none [—-] make no other doc changes$`).
  Its last line is always `prune: none`, at column 0, spelled exactly so (S6
  requires it). A release-time scribe dispatch would instead carry
  `prune: release <version>`, which is out of scope here.
- `## ADR`: either the single line `none`, or three parts: a line
  `NNNN <title>`, a line `file: docs/adr/NNNN-<slug>.md`, and a line `body:`
  followed by an `indent: N` line and a fenced block holding the full ADR text.

**H-C (R1 v2 indentation).** Lines inside a fenced payload that are empty or
whitespace-only are exempt from the `indent: N` check. They denote an empty line
in the payload: the implementer writes them as empty lines, with no trailing
spaces. All other payload lines must start with ≥N spaces, and exactly N are
stripped.
- Fixtures: `v2-r1-blank-line.md` (payload with an empty line and a
  spaces-only line) gives R1 true. `v2-r1-short-indent.md` (one non-blank line
  with N-1 spaces) gives R1 false.

**H-D (H7 `rubric_version`).**
- The constant is `const RUBRIC_V2_UNIT = 'rgh-h2';`, at the top level of
  `scripts/unit-outcomes.js`, next to the other module constants, and documented
  in the README field dictionary (H10).
- Values:
  - `contract_ts` null gives `rubric_version` null;
  - no PASS for `RUBRIC_V2_UNIT` as of the cutoff gives `v1` for every unit
    with a non-null `contract_ts`;
  - otherwise `v1` when `contract_ts` ≤ that PASS's `pass_ts`, and `v2` after.
- AC-H7.3: fixtures cover all four cases (null contract_ts; no rgh-h2 PASS;
  before; after), each asserted by name.

**H-E (H10 exact text and criteria).**
- (i) Section-anchor citations. A "line-number citation" is a match of
  `/[A-Za-z0-9_\/.-]+\.(md|js|sh|json|toml):[0-9]+/` inside a glossary entry
  whose header line contains `(unit rgh-`. A "section anchor" is a backticked
  path followed by a bold bullet label or a heading name, with no `:<digits>`.
  At ff3651f there is exactly one, at docs/harness-glossary.md:705
  (`agents/task-master.md:110-145`). Its two sentences, from "The text says" to
  "is unstated.", are replaced with:
  "Under a contract, lead-programmer fills only the `<FILL:` blanks of the
  advisory review packet template in `review-packet:` (`agents/task-master.md`
  **Per-unit dispatch prompts**, element 8). A FAIL re-dispatch carries a
  **fix contract**, to which the same precedence applies (`agents/lead-programmer.md`
  **Fix turns**)."
  - AC-H10.4: `awk '/\(unit rgh-/{f=1} /^$/{f=0} f' docs/harness-glossary.md | /usr/bin/grep -cE '[A-Za-z0-9_/.-]+\.(md|js|sh|json|toml):[0-9]+'` prints `0` (it prints `1` at ff3651f, measured).
- (ii) **held unit** entry. The sentence "When a spec gap is encountered,
  task-master publishes all already-sliced units and halts; the gap unit and
  everything transitively depending on it remain unpublished (held) and are
  reported in the **`Slice state:` table** with state "held" and the gap
  reason." becomes:
  "When a spec gap is encountered, task-master files every unit, but the gap
  unit and everything transitively depending on it are filed with a
  `HELD: <reason>` first body line and are not dispatched while it stands; the
  report's **`Slice state:` table** lists them as held, with the gap reason."
  In **Slice state: table**, "units in the "held" state are retained for re-work
  after the spec gap is resolved" becomes:
  "units in the "held" state keep their `HELD:` line until the gap is resolved;
  on re-invocation task-master reads the table from the umbrella-issue comment
  and removes the `HELD:` line from those units only (**Resume from slice state**)."
  - AC-H10.5: `/usr/bin/grep -c 'halts' docs/harness-glossary.md` prints `0` (1 at ff3651f, measured), and a flattened grep of `retained for re-work` prints `0`.
  - AC-H10.6: a flattened grep of `removes the \`HELD:\` line from those units only` prints `1`.
- (iii) README (`docs/audits/unit-outcomes/README.md`), exact line replacements:
  - L3 "…so this file is the replay pool." becomes "…so this file is the durable
    copy of outcome history that later replays read." ("Replay pool" is the
    research note's term and is undefined in this repo.)
    - AC-H10.7: `/usr/bin/grep -c 'replay pool' README` prints `0` (1 at ff3651f).
  - L22 becomes ``- `plan`: the plan stem (the `docs/plans/` file name without directory or `.md`), or null.`` (measured: values read like `2026-10-01-in-session-escalation-decision`).
    - AC-H10.8: `/usr/bin/grep -c 'the plan stem' README` prints `1`.
  - L28 becomes ``- `final_commit`: the PASS marker's `commit:` value as written (48 are short SHAs in this snapshot), or null when the unit has no PASS or its marker reads `commit: none`.``. 48 was measured with `jq -s '[.[]|select(.final_commit!=null and (.final_commit|length)<40)]|length'`.
    - AC-H10.9: `/usr/bin/grep -c 'commit: none' README` prints ≥ 1, and the README's stated number equals that jq output.
  - L35 becomes ``- `task_master_cutoff`: always null in this snapshot; the exporter does not yet measure cutoffs, and G3 prints `task_master_cutoffs=unmeasured`.``. Measured: 0 non-null values.
    - AC-H10.10: `/usr/bin/grep -c 'always null in this snapshot' README` prints `1`.
  - New line after L38: ``- `rubric_version`: `v1`, `v2` or null; see `RUBRIC_V2_UNIT` in `scripts/unit-outcomes.js`.``.
  - New line after that (added with H11): ``- `contract_score_v2`: the `score` under `bin/contract-score.js --rubric=v2`, or null when there is no real contract; G3 uses it for `rubric_version` `v2` units.``. AC-H10.13 (corrected 2026-10-06, ruling H-H): `/usr/bin/grep -cE '^- .contract_score_v2.: ' README` = 1. The bare-name grep prints 2, because the AC-H10.14 note also names the field (measured). This anchored form counts the field-dictionary line only.
  - L8, append (prose only; the machine-read lines stay unchanged): " Fields added after this snapshot (`rubric_version`, `contract_score_v2`) are absent from the committed file and are excluded from the comparison too." AC-H10.14: flattened grep `are excluded from the comparison too` = 1. AC-H10.12 still holds.
    - AC-H10.11: `/usr/bin/grep -c 'RUBRIC_V2_UNIT' README` prints `1`.
  - Machine-read lines unchanged:
    - AC-H10.12: `git diff <B>..HEAD -- docs/audits/unit-outcomes/README.md | /usr/bin/grep -cE '^[-+](cutoff:|reproduce-command:|count:)'` prints `0`. Mutation: editing any `count:` line prints ≥ 2.
  - (In these criteria, README = `docs/audits/unit-outcomes/README.md`.)

**H-F (pointer test versus payloads; option (a)).** The pointer test exists to
catch an *instruction* that points elsewhere instead of carrying content. A
payload that quotes a pointer phrase as data is content, so v2 skips payloads.
v1 is untouched.
- **Rule (H1, v2 R1 only).** The pointer regex (`POINTER`, unchanged) is tested
  against the `## Ordered edits` section with these payload spans removed first:
  1. every line inside a fenced block (``` or `~~~`, per the v2 fence rule),
     fence lines included;
  2. the backticked inline-code span that is the value of `before:`, `after:`,
     `insert-after:` or `delete:`;
  3. the backticked literal of an `anchor: line matching \`...\`` value.

  Everything else is instruction text and is still tested. That includes item
  text, `file:` lines, `command:`/`expect:` lines, and any text after a
  payload's closing backtick on the same line.
- **Fixtures (tests/fixtures/contract-score/):**

  | Fixture | Content | v2 R1 | v1 R1 |
  |---|---|---|---|
  | `v2-r1-pointer-in-payload.md` | "as specified" inside a fenced payload, and "see the plan" inside an `after:` inline-code value | true | false |
  | `v2-r1-pointer-in-instruction.md` | an otherwise-valid edit item whose `file:` line reads `` file: `agents/x.md` as specified in the plan `` (the phrase is instruction text after the path) | false | n/a |

  The instruction fixture must be structurally valid apart from the phrase:
  with the phrase deleted it scores R1 true. The suite asserts this, so mutant
  M2 truly flips it.
  | `v2-r1-pointer-after-payload.md` | `` after: `x` as needed `` | false | n/a |

- **Mutation proofs** (the suite names each assertion):
  - Mutant M1 (apply the test to payloads too, i.e. v1 behaviour) makes the
    payload fixture's v2 R1 false, failing `v2-r1-pointer-in-payload`.
  - Mutant M2 (skip the pointer test entirely) makes both the instruction
    fixture and the after-payload fixture R1 true, failing
    `v2-r1-pointer-in-instruction` and `v2-r1-pointer-after-payload`.
  - Mutant M3 (treat the whole `after:` line as payload) fails
    `v2-r1-pointer-after-payload`.
- **Scribe shape.** No S row runs a pointer test (s1/s6 check only
  `file:`/`heading:`/`text:` presence), so nothing changes. If a later S row adds
  a pointer test, `text:` values count as payload under the same rule.
- **G3 and v1.** v1 output is byte-identical (AC-H1.1's v1 regression). G3 keeps
  scoring with the v1 default, so no historical score changes.
- **Accepted scores.**
  - H2's own contract must score **7/7 under v2**. task-master checks this with
    its scratch copy of H1 v2 until H1 lands; after that the reviewer re-scores
    with the landed `bin/contract-score.js --rubric=v2`.
  - Any contract written before H1's PASS, or scored with v1, that falls short of
    7 under v1 **only** because R1's pointer test matched payload text is accepted
    at 6/7, provided it carries the line
    `score-exception: R1 pointer phrase in payload (H-F); v2 7/7` in its
    `## Pre-resolved context` and scores 7/7 under v2.
  - Any other shortfall is not excepted.
  - **Exact condition (H-F2, 2026-10-06; applies whenever written, before or
    after H1's PASS).** A contract is excepted from the v1 7/7 requirement iff
    all five hold:
    (1) it scores `"score":7` under `--rubric=v2` with the merged scorer;
    (2) under `--rubric=v1` its only false row is R1;
    (3) with every pointer phrase inside payload spans (the H-F rule's three span
        kinds) replaced by `x`, it scores 7 under v1. This proves the shortfall
        is solely payload text;
    (4) its `## Pre-resolved context` carries the line
        `score-exception: R1 pointer phrase in payload (H-F); v2 7/7`;
    (5) its unit is listed in the exception list below.
    The reviewer checks (1), (2) and (4) by running the scorer and grepping, and
    checks (5) against this list.
  - **Exception list (H-F2):**

    | Unit | Why its payload must quote a pointer phrase |
    |---|---|
    | H2 | H2(c) lists all six pointer phrases in task-master.md |
    | H1b | fixtures `v2-r1-pointer-in-anchor.md` ("see the plan") and `v2-fence-len.md` ("as needed") |

    Checked for the other units, against their specified payloads:
    - H3, H4, H5, H6, H7, H9: no pointer phrase.
    - H8: quotes "looks mechanical", which is not a `POINTER` phrase.
    - H10: its **instruction text** glossary entry describes the scope without
      quoting the phrases, and must keep doing so.

    A new entry needs a spec-master ruling.
  - **The v1 7/7 requirement does not lapse** for contracts written after H1's
    PASS. task-master's self-check still requires v1 7/7 (the shipped rule)
    until H2 switches the self-check to v2. After H2's PASS, contracts must score
    7/7 under v2, and v1 is informational.
  - **G3 effect (superseded 2026-10-06 by the user's answer to Open Question 5).**
    G3 now scores each unit under its own `rubric_version` (programme plan,
    Gate G3; implemented by H11). The `score-exception:` line is informational
    for G3, which reads `rubric_version` and the scores, never the line. H2 and
    H1b have `rubric_version` `v1` (written before `rgh-h2`'s PASS), so with a v1
    score of 6 they still do not count toward the 20.
  - **The H-F2 mechanism is still needed** for the per-unit self-check:
    task-master's shipped self-check requires v1 7/7 until H2 switches it to
    `--rubric=v2`. After H2's PASS the exception list stops growing, because v2
    has no payload pointer shortfall.
- **H2(c) wording kept:** "list all six pointer phrases" stands, written
  literally inside the payload. No obfuscation.

Unit gating after these rulings: H1, H2, H3 (with the HELD reconciliation
above), H4, H5, H6, H7, H8, H9 and H10 are un-gated by these specs. H10 depends
on H3 and H5, because its replacement text cites their shipped labels.

## Placement table

| Item | Placed |
|---|---|
| A1 FAIL re-dispatch carries no contract | H3 (author), H4 (routing), H5 (lead-programmer side); OQ1 |
| A2 packet template | H1 (R5 v2), H2(a), H5 wording |
| A3 scribe judgment | H1 (S1-S7), H2(d), H4 (contract passing + placeholder), H6; prune duty parked (release-only) via OQ2 |
| A4 version derivation / mutations / staging / indentation / anchors / split / `git add -A` | H2(b) |
| A5 shared-file rule, table, banner, resume | H3 |
| A6 scorer vs persona | H1 (code), H1b (lock-in fixtures, CRLF in-test, `Object.hasOwn`, fenced R6), H2(c) (wording), H7 (exporter items) |
| OQ5 answered by the user: G3 scores each unit under its own `rubric_version` | H11 (exporter `contract_score_v2` + `gateG3`); programme plan Gate G3 amended in text; README notes in H10 |
| H1 review: 8 rows indistinguishable from v1, survivors M3b/fence/prune/R6-nested, vacuous CRLF fixture, prototype-key lookups, fenced R6 lines | H1b |
| H1 review: glossary "instruction text"; "rubric" sense collision (CONTEXT.md:451 is roast-work's critique rubric) | H10 scribe contract adds a harness-glossary entry **instruction text** (the v2 pointer test's scope: text outside fenced payloads and outside the backticked `before:`/`after:`/`insert-after:`/`delete:`/`anchor: line matching` values). The **rubric v1/v2** entry stays in `docs/harness-glossary.md` and notes it is distinct from CONTEXT.md's roast-work rubric |
| A6 H2 hook counts only backtick fences | parked: hook change (`hooks/`, guarded); scorer `sizeOver` covers it for contracts |
| B false mutations, computed counts, indentation, validate.sh runtime | Contract-quality rules B1-B7, applied to every H contract; B6 and gate HG |
| C explorer conflict, commit cadence | H5 |
| C orchestrator scribe-contract passing | H4 |
| C SHA re-resolve step | H3 (clause removed) |
| C fast-path home, to-tickets approval loop, self-check rename, "executor" | H3, H2(c) |
| C Replay source / Incumbent baseline | H9 |
| C README wording, glossary over-statements, link citations | H10 |
| C AC-D6 strip, maxTurns pin, adapter parity | H8 |
| C version-stamp-check.sh package.json | parked as optional; OQ3 (default: no unit) |
| C persona-design-notes caps 120 | already true (docs/persona-design-notes.md:34,63); no unit |
| C parent plan line 55, #494 body | done in this commit (spec-master's own docs) |
| Process: glossary tests in scribe contracts, `/usr/bin/grep`, gate-refused names | B4, B7, the persona baseline |

## Open Questions

1. Who writes FAIL re-dispatch contracts? Default: **task-master (fix contract), dispatched by the orchestrator between FAIL and re-dispatch; cap/ratchet/routing unchanged**. Alternative: the orchestrator keeps the original contract plus a fixed-shape defect block (no extra dispatch, but the fix edits are not literal). Origin: Clarifications cat. 1, CHK2.
2. Do scribe's doc-update duties move into the contract? Default: **yes for per-unit doc edits (`## Doc edits`); prune duty parked (release-only)**. Origin: Clarifications cat. 1.
3. Include an optional unit hardening `hooks/scripts/version-stamp-check.sh` to read package.json? Default: **no** (the version-sync check in contracts covers it; guarded hook). Origin: Clarifications cat. 7.
4. G3 confound: pool v1 and v2 contracts as rubric era (recorded via `rubric_version`), or pause G3 counting until the hardening stage ends? Default: **pool and record**. Origin: Clarifications cat. 9, CHK5.
5. Should the programme plan's G3 count v2 scores for contracts written after H2's PASS (v1 cannot score the hardened format's payload-quoting contracts at 7)? Default: **yes, score each G3 unit with its own `rubric_version` (v1 for v1-era, v2 for v2-era contracts)**, applied only on the user's approval as an amendment to `docs/plans/2026-10-06-rubric-gated-haiku-programme.md`'s G3. Evidence: v1 is fence-blind to `~~~`. `v2-all-pass.md`, the canonical hardened contract, scores R1 false under v1 (measured 2026-10-06), so after H2 almost no contract can reach v1 7/7, and G3's "≥20 at 7/7" would stall regardless of contract quality. Origin: ruling H-F2. **ANSWERED 2026-10-06 by the user: each unit is scored under its own `rubric_version` (v1 for v1-era, v2 for v2-era); not "keep v1", not "v2 for everything".** Applied to the programme plan's Gate G3, stage table and U0-2b note; implemented by H11.

## Self-check
- CHK1: Does every reviewer item A1-A6, B, C appear in the placement table? — PASS
- CHK2: Is the author of a fix contract defined? — FAIL (missing: needs the user) — converted to Open Question 1
- CHK3: Does any criterion name version-stamp-check.sh as the package.json detector? — PASS (rule B2; version-sync check, mutation run)
- CHK4: Do all pinned-phrase criteria have a recorded HEAD count proving the mutation? — PASS (Context, rule B1)
- CHK5: Is the effect of H1/H2 on the parent's G3 measurement defined? — FAIL (ambiguous) — revised in place (Measurement note) and converted to Open Question 4
- CHK6: Do H4's edits leave the 2-FAIL cap, the ratchet, reviewer routing and the fable exclusion unchanged, checkably? — PASS (AC-H4.4)
- CHK7: Does every persona unit have a distinct version with no collisions? — PASS (version table)
- CHK8: Is the validate.sh runtime problem resolved without backgrounding a subagent's acceptance command? — PASS (B6, gate HG in the main session)
- CHK9: Are Stages 4-5 and G3/G4 untouched? — PASS (no unit edits the parent plan's Stage 4-5 text or gate definitions; H7 only adds a field)

## Out of scope
- The parent's Stage 4-5 units and G3/G4 definitions.
- Hook changes: H2 fence parity, version-stamp-check.sh (OQ3).
- `dispatchHygiene.mode` and `gatedAgents` (parent OQ3).

## Scribe update hint
After H2: **review-packet** and **contract self-check** (renamed). After H3:
**fix contract**, **held unit** / **slice state** (corrected per H10). Avoid
"ready-for-review packet template", "defect block" and "executor".
