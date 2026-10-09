# Backlog follow-ups after blc-1..8 (2026-10-09)

Status: FINAL (spec-master, 2026-10-09, tip ad79b4c). Unit prefix `blf`. Standard path
(8 units): `task-master` slices this plan into dispatch contracts. Hook scripts
(`hooks/scripts/*`) are out of scope; they are the human-only items blc-h1..h4.

## Goal

Close the non-hook reviewer notes left by `docs/plans/2026-10-09-backlog-cleanup.md`
(blc-1..8, all PASS):

- G1 (item 1). `bin/contract-guard.js` exits 2 with empty stdout on a repeated `--unit=` or
  `--shape=` flag and on any unknown flag, including a lone one with no positional
  argument; `tests/contract-score.test.js` proves both cases with tests that fail on the
  current code.
- G2 (item 2). `agents/task-master.md` **Range criteria** lists a unit's commits by subject
  only (no body-line match), states how a unit id is escaped in the pattern, and makes
  criteria over a unit's commits iterate that list instead of a `<first>~1..<last>` span.
- G3 (item 3). The CHANGELOG 0.31.148 entry reads as the blc-5 contract's edit-9 payload.
- G4 (item 4). The ladder-exhaustion sentence in `templates/persona-protocol.md` is wrapped
  as the blc-6 edit-7 contract wrapped it, and it and the digest say "FAIL-block count".
- G5 (item 5). `CONTEXT.md` defines fix round, trailer sweep, untagged-tail criterion,
  FAIL-block count and guard demotion; rubric v2, contract score and Rulings ledger
  point at each other.
- G6 (item 6). A test fails when a doc's rubric row range disagrees with
  `bin/contract-score.js`.
- G7 (item 7). Every FAIL block carries a `tier:` line naming the tier the failed attempt
  ran on (feasible without hook changes; see F7).

## Context

### Sources

- Reviewer notes: `.claude/reviewed/blc-5.pass` (CHANGELOG paraphrase; body-line match of
  the anchored pattern; "untagged-tail" vs "untagged"; "fix rounds"), `blc-6.pass` (edit 7
  on one 212-char line; FAIL count vs FAIL-block count), `blc-7.pass` (rubric rows not
  cross-checked), `blc-8.pass` (guard repeated/unknown flags).
- `bash bin/marker-audit.sh . --notes --surface=<path>` was not re-run per path: the four
  blc PASS markers above were read whole, which is a superset for these surfaces. The
  sweep is best-effort; `.claude/reviewed/` is gitignored per-clone state.
- Prior FAILs on surfaces this plan touches: blc-2, blc-3, blc-4, blc-6, blc-8 each FAILed
  once before PASS (see Risks R1). No blf unit is a re-scope of a failed unit.

### Measured facts (2026-10-09, HEAD ad79b4c, version 0.31.149)

- F1. `bin/contract-guard.js:66-77` takes the first `--unit=`/`--shape=` match and treats
  every other argument as positional. `--unit=demo-2 --unit=demo-2` exits 0 today. With
  `--unit=x --bogus` and no positional, `--bogus` is opened as a file: a file of that name
  in the CWD is scored. The existing test `guard-usage-extra-args` already covers
  `['-', '--unit=demo-2', '--bogus']` (two positionals); it stays green.
- F2. The anchored `git log -E --grep` pattern is in `agents/task-master.md:202` and
  nowhere else outside `docs/plans/` and CHANGELOG. `agents/lead-programmer.md:48`,
  `agents/scribe.md:107-108` and both lead-programmer ports only say each commit's subject
  carries `(<task-id>)` as its scope; they hold no regex. **Premise correction**: item 2's
  "unescaped pattern in lead-programmer.md, scribe.md and the ports" applies to
  task-master.md only; the other four files need no edit.
- F3. The unit-id grammar (`agents/orchestrator.md:113-115`, `contract-guard.js:23`) is
  `[A-Za-z0-9][A-Za-z0-9._#-]{0,63}`. Of those characters only `.` is an ERE
  metacharacter. `git log --grep` with `^` anchors at any message line, so a body line
  `fix(u1): x` in a later commit matches (blc-5 note, reproduced by its reviewer).
  `git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(blc-5\): ' | cut -c1-7` prints
  `6dc68fa`, the same as the current pattern.
- F4. Every blc range criterion uses `B=<first>~1` .. `U=<last>`: a span that includes any
  other unit's commit landed between them. That is the reason item 2 asks for the unit's
  own commits to be listed.
- F5. `CHANGELOG.md` sits under `## [Unreleased]`; line 7 is the 0.31.148 entry. Its
  sentence "`agents/lead-programmer.md` **Fix turns** and both ports, `agents/scribe.md`:
  without a contract, every commit carries the unit id as scope" is false for
  lead-programmer (shipped text: "with or without a contract"). The contract payload is
  `docs/plans/2026-10-09-backlog-cleanup.md:1551`. `CHANGELOG.md` is not a
  version-stamped path: `hooks/scripts/version-stamp-check.sh:61,92` matches only
  `agents/*.md|templates/*`.
- F6. `templates/persona-protocol.md:708` is 212 characters; the blc-6 edit-7 payload
  (`docs/plans/2026-10-09-backlog-cleanup.md:1816-1818`) has three lines.
  `templates/protocol-digest.md:15` says "FAIL count"; `agents/orchestrator.md:362` and
  `CONTEXT.md:373` say "FAIL-block count". No test pins either phrase. No adapter port
  carries the sentence.
- F7. FAIL record writers and readers: the reviewer writes it by heredoc
  (`agents/reviewer.md:211-219`, `adapters/codex/agents/reviewer.toml:84`,
  `adapters/cursor/agents/reviewer.md:81`; protocol text `templates/persona-protocol.md:349`
  and :700-701, `adapters/cursor/rules/persona-protocol.mdc:130`,
  `adapters/codex/agents-md-fragment.md:123`). The only parser of block content is
  `bin/fail-count.sh` (counts `^FAIL <id> ` lines). Hooks read only existence and mtime
  (`hooks/scripts/lib/reviewer-route-gate-core.sh:139-142`). A second line inside a block
  changes no count and no hook. The reviewer cannot see the implementer's tier on its own;
  the orchestrator knows it (the `model` it passed). Commit trailers also name a tier, but
  blc-7 and blc-8 show trailers rewritten by orchestrator re-commits, so they are not
  ground truth. A second FAIL write path exists: `hooks/scripts/marker-write.sh FAIL`
  (not a registered hook) writes the header, then its `<detail>` argument verbatim, and
  `tests/fail-marker-format-parity.test.sh` pins both paths to one block shape; a `tier:`
  line passed as the first line of `<detail>` needs no script change.
  `agents/orchestrator.md:476-477` says "which tier wrote a block is never
  needed" (wrapped across two lines); that stays true for the ladder.
- F8. Rubric rows in `bin/contract-score.js:380-386`: v2 lead R1-R7, v2 scribe S1-S7, v1
  lead R1-R7, v1 scribe S1-S5. Docs that state ranges: `CONTEXT.md` **rubric v2**
  (R1-R7, S1-S7), `docs/harness-glossary.md` **contract score** (R1-R7, S1-S5 v1, S1-S7
  v2), `agents/task-master.md:140` (R1-R7). All agree today, so the new test passes at
  HEAD and is proven by mutation.
- F9. `CONTEXT.md` has no heading for fix round, trailer sweep, untagged-tail criterion,
  FAIL-block count or guard demotion. "guard demotion" appears inside the
  **Contract-score guard** entry (CONTEXT.md:411) and `agents/orchestrator.md:499`.
  **Rulings ledger** is a `docs/harness-glossary.md:1464` heading; CONTEXT.md links it
  cross-file, which `tests/context-glossary-links.test.js` accepts.
- F10. "trailer sweep" (blc-4): the plan-record edit that replaced a model-name
  placeholder in landed contracts' trailer lines with the trailer each unit's first commit
  carries (`docs/plans/2026-10-09-backlog-cleanup.md:1329`).

### Decisions

- D1 (item 1). Argument rule: exactly `-` is positional; `--unit=` and `--shape=` are
  flags, each allowed once; any other argument starting with `-` (including `--`) is an
  unknown flag. Repeated flag: `usage('repeated --<name>')`; unknown flag:
  `usage('unknown flag: <arg>')`. Both exit 2 with empty stdout. A file whose name starts
  with `-` is passed as `./-name`. The header comment (lines 10-11) states the new rule.
- D2 (item 2). Escaping, not a charset restriction: the grammar already allows `.`, so a
  "safe charset" note would be false. The pattern escapes `.` as `\.`; the text says no
  other grammar character is special. Subject-only listing replaces `git log --grep`.
  Criteria over a unit's commits iterate the list per commit.
- D3 (item 3). Replace CHANGELOG line 7 with the edit-9 payload verbatim (the contract of
  record) in blf-3's commit. P3 does not apply to CHANGELOG.md itself (F5), but blf-3
  touches `templates/*`, so it bumps to 0.31.151 and its new entry names the correction.
  No separate version for the correction.
- D4 (item 4). Rewrap line 708 into the three contract lines, with "FAIL count" changed
  to "FAIL-block count" there and in the digest (G5's canonical term). Mirrors refresh via
  `node bin/cli.js --update`.
- D5 (item 5). Canonical terms: **fix round** (synonym heading **fix turn**, matching
  lead-programmer's **Fix turns** section); **FAIL-block count** (the record's count;
  "FAIL count" kept only for the in-session advisory count under review gating off);
  **guard demotion** covers every non-haiku guard outcome, and "fails safe to sonnet" is
  its error subset. No agent prose is renamed in this plan.
- D6 (item 6). A new test file `tests/rubric-doc-parity.test.js`, registered in
  `tests/validate.sh`. It reads row keys from the scorer's own JSON output (black box, no
  export added). It is a new file, so it does not collide with blf-1's test edits.
- D7 (item 7). Included, not deferred: no hook or human-only surface is touched. The FAIL
  block's line 2 is `tier: <haiku|sonnet|opus|unknown>`. The value comes from an
  `Implementer tier: <t>` line the orchestrator puts second in every reviewer dispatch;
  it is `unknown` when that line is missing (agent-teams, manual dispatch, ports). The
  ladder never reads it. Split across blf-6 (Claude surfaces), blf-7 (ports) and blf-8
  (orchestrator) to keep each unit inside the haiku size limit.
- D8. Version numbers in order: blf-2 0.31.150, blf-3 0.31.151, blf-6 0.31.152, blf-8
  0.31.153. A unit that finds HEAD at any other version stops and reports a spec gap.
  Units that touch no `agents/*.md` or `templates/*` file (blf-1, blf-4, blf-5, blf-7)
  bump nothing and add no CHANGELOG entry, which is what keeps them file-disjoint.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-09 Functional scope & success criteria: Q Item 2 names lead-programmer.md,
  scribe.md and the ports as carrying the unescaped pattern; must they change? → A
  (self-resolved): no; only task-master.md holds a pattern (F2).
- 2026-10-09 Functional scope & success criteria: Q Item 7: deferred as human-only, or in
  scope? → A (self-resolved): in scope; no hook reads block content (F7, D7). Source of
  the tier value is Open Question 1.
- 2026-10-09 Domain entities / data model: Q Where in a FAIL block does the tier go, and
  does it break the FAIL-block count? → A (self-resolved): line 2 as `tier: <t>`;
  `bin/fail-count.sh` counts header lines only (F7).
- 2026-10-09 Edge cases / failure handling: Q Is `-` (stdin) or `--` an unknown flag to
  the guard? → A (self-resolved): `-` is positional; `--` is unknown (D1).
- 2026-10-09 Technical constraints & tradeoffs: Q Does correcting a shipped CHANGELOG
  entry need its own version bump under P3? → A (self-resolved): no, CHANGELOG.md is not
  stamped (F5); the correction rides in blf-3, which bumps for its template edit (D3).
- 2026-10-09 Technical constraints & tradeoffs: Q Which units can run in parallel? → A
  (self-resolved): see the unit table; every version-bumping unit is serial (D8).
- 2026-10-09 Terminology consistency: Q "fix round" vs "fix turn", and "FAIL count" vs
  "FAIL-block count": which is canonical? → A (self-resolved): D5.

## Risks / dependencies

- R1. Prior FAILs on these surfaces (blc-2/3/4/6/8) were contract defects (wrapping,
  version-stamp, criterion cut ranges), not hard code. The ratchet is unaffected: no blf
  unit re-scopes a failed unit. task-master must still run every criterion at HEAD and
  check each mutation before dispatch.
- R2. Serial chain blf-2 → blf-3 → blf-6 → blf-8 shares `.claude-plugin/plugin.json`,
  `package.json`, `CHANGELOG.md` and the `.claude/` mirrors. Never run two of them at once
  or in separate worktrees.
- R3. blf-6 changes the reviewer's FAIL write while a unit could be under review. Dispatch
  blf-6 only when no other unit is mid-review (the one-unit-at-a-time invariant already
  ensures this).
- R4. Until blf-8 lands, reviewers write `tier: unknown`. This is expected, not a defect.
- R5. The concurrent agent-memory dirt issue (blc-7, blc-8 notes): clean-tree criteria
  exclude `.claude/agent-memory`.
- R6. `tests/validate.sh` (constitution P5) is not run by the reviewer; the orchestrator
  runs it once after each unit merges.
- Deferred / out of scope: hook scripts (blc-h1..h4); renaming "Fix turns" or "fix
  rounds" in agent prose; the `CONTEXT.md` **FAIL record** entry's mention of the new
  `tier:` line (scribe hint); the agent-teams team-lead reviewer dispatch
  (`commands/start-feature-team.md`) sending `Implementer tier:` (the `unknown` fallback
  covers it).

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied — every claim above was measured at ad79b4c, and
  every criterion below has a mutation line.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — mirrors are
  refreshed only by `node bin/cli.js --update`; no `.claude/` file is hand-edited.
- P3 "Version-stamp discipline": satisfied — each stamped unit bumps in the same commit
  (D8); shared criterion SC3 checks every commit of the unit.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — the `tier:` line falls
  back to `unknown` when there is no orchestrator.
- P5 "`tests/validate.sh` is the merge gate": satisfied — blf-5 registers its test there,
  and R6 assigns the run.

## Steps

### Unit table

| Unit | Item | Persona | Files (content) | Version | Depends on | Parallel group |
|---|---|---|---|---|---|---|
| blf-1 | 1 | lead | `bin/contract-guard.js`, `tests/contract-score.test.js` | none | — | P |
| blf-2 | 2 | lead | `agents/task-master.md` | 0.31.150 | — | S (1st) |
| blf-3 | 3, 4 | lead | `CHANGELOG.md` line 7, `templates/persona-protocol.md`, `templates/protocol-digest.md` | 0.31.151 | blf-2 | S (2nd) |
| blf-4 | 5 | scribe | `CONTEXT.md`, `docs/harness-glossary.md` | none | — | P |
| blf-5 | 6 | lead | `tests/rubric-doc-parity.test.js` (new), `tests/validate.sh` | none | — | P |
| blf-6 | 7 | lead | `agents/reviewer.md`, `templates/persona-protocol.md` | 0.31.152 | blf-3 | S (3rd) |
| blf-7 | 7 | lead | `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md`, `adapters/cursor/rules/persona-protocol.mdc`, `adapters/codex/agents-md-fragment.md` | none | blf-6 (wording only) | P after blf-6 |
| blf-8 | 7 | lead | `agents/orchestrator.md` | 0.31.153 | blf-6 | S (4th) |

Every version-bumping unit also touches `.claude-plugin/plugin.json`, `package.json`, the
top of `CHANGELOG.md` and the `.claude/` mirrors. Group P units (blf-1, blf-4, blf-5,
blf-7) are file-disjoint from each other and from the S chain, so they may run in
separate worktrees at the same time as the S chain. blf-5 reads `CONTEXT.md` and
`agents/task-master.md` but writes neither, and blf-4 and blf-2 do not change any rubric
range. The S chain runs in order on one branch.

### Shared criteria (every unit; `<id>` is the unit id)

- SC1. run: `git log --format='%H %s' | grep -cE '^[0-9a-f]+ [a-z]+\(<id>\): '`; exit 0;
  stdout ≥ `1`. mutation: commit without the scope; prints `0`, exit 1.
- SC2. run: `for c in $(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(<id>\): ' | cut -d' ' -f1); do git log -1 --format=%B "$c" | grep -c '^Co-Authored-By: Claude '; done | grep -cx 0`;
  exit 1; stdout `0`. mutation: drop a trailer; prints `1`, exit 0.
- SC3 (stamped units only). run: `for c in $(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(<id>\): ' | cut -d' ' -f1); do bash hooks/scripts/version-stamp-check.sh "$c~1..$c"; done | grep -vc '^version-stamp-check: ok '`;
  exit 1; stdout `0`. mutation: commit the content edit without the bump; prints `1`.
- SC4 (stamped units only). run: `node bin/cli.js --update --dry-run 2>&1 | grep -E '^  ' | grep -vc ': already current$'`;
  exit 1; stdout `0`. mutation: skip the `--update` run; prints ≥ `1`. Measured at HEAD:
  66 entry lines, all `already current`. Task-master confirms the non-current status word
  with one mutated scratch run before dispatch (an older `--check | grep` idiom detected
  nothing).
- SC5. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`;
  exit 0; stdout `0`. mutation: leave an edit unstaged; prints `1`.

### Step 1 (blf-1): guard rejects repeated and unknown flags (item 1)

Affected files: `bin/contract-guard.js` (argument parsing in `main()` lines 65-77, header
comment lines 10-11), `tests/contract-score.test.js` (two new `check(...)` blocks placed
after `guard-usage-extra-args`, before the final `console.log`).
Behaviour: D1. Tests:
- `guard-usage-repeated-flag`: for `['-', '--unit=demo-2', '--unit=demo-2']` and
  `['-', '--unit=demo-2', '--shape=lead', '--shape=lead']`, exit 2 and stdout `''`.
- `guard-usage-lone-unknown-flag`: in a `fs.mkdtempSync(os.tmpdir())` directory, write
  `G_LEAD` to a file named `--bogus`; spawn `node <REPO_ROOT>/bin/contract-guard.js
  --unit=demo-2 --bogus` with that directory as `cwd`; expect exit 2, stdout `''`, stderr
  containing `unknown flag: --bogus`. (Requires `const os = require('os');`.)

Acceptance criteria:
1. run: `node tests/contract-score.test.js`; exit 0. mutation: revert `bin/contract-guard.js`;
   exit 1.
2. run: `node tests/contract-score.test.js | grep -cE '^OK +guard-usage-(repeated-flag|lone-unknown-flag)$'`;
   exit 0; stdout `2`. mutation: omit a test; prints `1`.
3. run: `node bin/contract-guard.js - --unit=demo-2 --unit=demo-2 < tests/fixtures/contract-score/v2-all-pass.md; echo "exit=$?"`;
   stdout `exit=2` (one line). mutation: revert the guard; prints the haiku line, then `exit=0`.
4. run: `R=$(pwd); D=$(mktemp -d); cp tests/fixtures/contract-score/v2-all-pass.md "$D/--bogus"; (cd "$D" && node "$R/bin/contract-guard.js" --unit=demo-2 --bogus); echo "exit=$?"`;
   stdout `exit=2`. mutation: revert the guard; prints the haiku line, then `exit=0`.
5. SC1, SC2, SC5.

### Step 2 (blf-2): range criteria list a unit's commits by subject (item 2)

Affected files: `agents/task-master.md` (the **Range criteria** paragraph, lines 199-212),
`.claude/agents/task-master.md` (via `--update`), `.claude-plugin/plugin.json`,
`package.json`, `CHANGELOG.md` (new top entry), `.claude/persona-config.json` (via
`--update`). Replace the paragraph from `**Range criteria.**` through `` `exit: 1`,
`stdout: 0`. `` with this text (task-master sets the final line breaks; words are fixed):

> **Range criteria.** A unit's own commits are listed by subject only: `git log
> --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(<unit-id>\): ' | cut -d' ' -f1`, newest
> first (`tail -1` is the unit's first commit, `head -1` its last), never `HEAD` and never
> `git log --grep`, whose `^` also matches a body line of a later commit. In `<unit-id>`
> write each `.` as `\.`; no other character of the unit-id grammar is special in the
> pattern. A criterion over a unit's commits iterates that list (`for c in <list>; do …
> "$c~1..$c"; done`), never a `<first>~1..<last>` span, which also takes in any other
> unit's commit landed between them. That list is complete only if every commit of the
> unit, fix rounds included, carries `(<unit-id>)` as its subject scope, so every
> `commit-message:` line of a contract or fix contract does, and every range contract
> adds one untagged-tail criterion, run at review time over the unit's content files
> (never the version files or `.claude/`): `git log --format=%s <end>..HEAD -- <content
> files> | grep -vcE '^[a-z]+\(<unit-id>\): '`, `exit: 1`, `stdout: 0`.

The rest of the paragraph (from "A red-set criterion over a test file" on) is unchanged.
Version 0.31.149 → 0.31.150; CHANGELOG entry titled
`**Range criteria list a unit's commits by subject (blf-2, 0.31.150).**`.

Acceptance criteria (`F` = `tr '\n' ' ' < agents/task-master.md | tr -s ' '`):
1. run: `F | /usr/bin/grep -cF "never \`git log --grep\`, whose \`^\` also matches a body line"` — task-master writes it as a shell-safe single-quoted `grep -cF`; stdout `1`. mutation: skip the edit; `0`.
2. run: flattened `grep -cF 'write each `.` as `\.`'`; stdout `1`. mutation: skip; `0`.
3. run: flattened `grep -cF 'never a `<first>~1..<last>` span'`; stdout `1`. mutation: skip; `0`.
4. run: `/usr/bin/grep -cF -- "--format=%H -E --grep=" agents/task-master.md`; exit 1; stdout `0`. mutation: skip; `1`.
5. run: `git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(blc-5\): ' | cut -d' ' -f1 | cut -c1-7`;
   stdout `6dc68fa`. (Proves the documented pipeline runs; it does not depend on the edit.
   mutation: n/a, a claim check, not an edit check.)
6. run: `cmp <(sed -n '/Range criteria/,/stdout: 0/p' agents/task-master.md) <(sed -n '/Range criteria/,/stdout: 0/p' .claude/agents/task-master.md) && echo same`;
   stdout `same`. mutation: skip `--update`; cmp differs.
7. run: `cat .claude-plugin/plugin.json package.json | grep -c '"version": "0.31.150"'`;
   stdout `2`. mutation: skip one bump; `1`.
8. run: `/usr/bin/grep -cF '(blf-2, 0.31.150)' CHANGELOG.md`; stdout `1`. mutation: skip; `0`.
9. SC1-SC5.

### Step 3 (blf-3): CHANGELOG 0.31.148 correction; edit-7 wrap; FAIL-block count (items 3, 4)

Affected files: `CHANGELOG.md` (line 7 replaced; new top entry), `templates/persona-protocol.md`
line 708, `templates/protocol-digest.md` line 15, version files, `.claude/` mirrors.
Edits:
- a. Replace `CHANGELOG.md` line 7 (starts `**Unit commits carry their scope; anchored range
  pattern (blc-5, 0.31.148).**`) with the single line at
  `docs/plans/2026-10-09-backlog-cleanup.md:1551`, byte for byte.
- b. Replace `templates/persona-protocol.md:708` with three lines:
  `human stop happens there. Only ladder exhaustion (the unit's FAIL-block count` /
  `reaching or exceeding the ladder's length: normally the second FAIL on its top` /
  `tier) stops re-dispatch: the orchestrator (or team lead) then`.
- c. `templates/protocol-digest.md:15`: `FAIL count reaching` → `FAIL-block count reaching`.
- d. Version 0.31.150 → 0.31.151; top CHANGELOG entry
  `**Ladder-exhaustion wording; 0.31.148 entry corrected (blf-3, 0.31.151).**`, saying the
  0.31.148 entry now matches the blc-5 contract (lead-programmer: with or without a
  contract).

Acceptance criteria:
1. run: `W=$(mktemp); sed -n 1551p docs/plans/2026-10-09-backlog-cleanup.md > "$W"; /usr/bin/grep -cxFf "$W" CHANGELOG.md`;
   stdout `1`. mutation: skip edit a; `0`.
2. run: `/usr/bin/grep -cF 'anchored range pattern (blc-5, 0.31.148)' CHANGELOG.md`; exit 1;
   stdout `0`. mutation: skip edit a; `1`.
3. run: `awk 'length>80' templates/persona-protocol.md | /usr/bin/grep -cF 'Only ladder exhaustion'`;
   exit 1; stdout `0`. mutation: skip edit b; `1`.
4. run: `/usr/bin/grep -cxF "tier) stops re-dispatch: the orchestrator (or team lead) then" templates/persona-protocol.md`;
   stdout `1`. mutation: skip edit b; `0`.
5. run: `cat templates/persona-protocol.md templates/protocol-digest.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -oF 'FAIL-block count reaching or exceeding' | wc -l`;
   stdout `2`. mutation: skip edit c; `1`.
6. run: `node tests/protocol-doc-drift.test.js`; exit 0. mutation: add a 16th digest body
   line; exit 1.
7. run: `cat .claude-plugin/plugin.json package.json | grep -c '"version": "0.31.151"'`; stdout `2`.
8. run: `/usr/bin/grep -cF '(blf-3, 0.31.151)' CHANGELOG.md`; stdout `1`.
9. SC1-SC5.

### Step 4 (blf-4, scribe): glossary entries and pointers (item 5)

Affected files: `CONTEXT.md`, `docs/harness-glossary.md`. Glossary edits (scribe contract
`## Glossary edits`; wording fixed, line breaks the scribe's):
- After the `_Avoid_:` line of **ladder exhaustion** in `CONTEXT.md`, insert:
  - `**FAIL-block count**:` (unit blf-4, 2026-10-09) — the number of `FAIL <task-id> `
    header lines in a unit's [[FAIL record]], one per FAIL verdict, as
    `bin/fail-count.sh` prints it; the count the [[Escalation ladder]] and [[ladder
    exhaustion]] read. Under review gating off no FAIL record is written and the
    orchestrator counts advisory FAILs in the session: that is a FAIL count, never a
    FAIL-block count. `_Avoid_: FAIL count (when the record is meant)`
  - `**fix round** (synonym: **fix turn**):` (unit blf-4, 2026-10-09) — one re-dispatch of
    a unit to the implementer after a FAIL verdict, with a fix contract or with the bare
    defect list, and the commits it lands. Each of its commits carries the unit's scope,
    and its trailer names the model of its own tier. lead-programmer's **Fix turns**
    section is the implementer's side of the same round. `_Avoid_: fix attempt`
- After the `_Avoid_:` line of **rubric v2**, insert:
  - `**guard demotion**:` (unit blf-4, 2026-10-09) — the [[Contract-score guard]] moving a
    unit to the ladder that starts at `sonnet`: every outcome other than an exit-0
    `contract-guard: haiku ` line, whether a row failed, the contract is oversize, no
    contract block was found, or the script or scorer errored. "Fails safe to sonnet"
    names the error cases only; all of them are guard demotions and each gets a line in
    the [[Rulings ledger]]. `_Avoid_: escalation (that is FAIL-driven), downgrade`
  - `**untagged-tail criterion**:` (unit blc-5, 2026-10-09) — the criterion every range
    contract adds, run at review time: no commit after the unit's last commit touches the
    unit's content files without the unit's scope in its subject. Unrelated to the
    `untagged` lines of the reviewer note channel (a note line with no NOTE tag).
    `_Avoid_: untagged (alone)`
  - `**trailer sweep**:` (unit blc-4, 2026-10-09) — a one-off edit of landed plan
    contracts that replaced a model-name placeholder in each contract's trailer line with
    the trailer the unit's first commit carries, measured with `git log`. It changes plan
    records only and never rewrites a commit. `_Avoid_: trailer fix`
- `CONTEXT.md` **rubric v2** entry: append the sentence `See [[contract score]] for the v1
  table.` to the body (before `_Avoid_:`).
- `docs/harness-glossary.md` **contract score** entry: append ` See [[rubric v2]].` after
  `See [[unit-outcome export]], [[content-typed contract]].`
- `docs/harness-glossary.md` **Rulings ledger** entry: append the sentence `Each [[guard
  demotion]] is recorded here.` to its body.

Acceptance criteria:
1. run: `for t in 'FAIL-block count' 'fix round' 'guard demotion' 'untagged-tail criterion' 'trailer sweep'; do /usr/bin/grep -c "^\*\*$t\*\*" CONTEXT.md; done | grep -cx 1`;
   stdout `5`. mutation: skip one entry; `4`.
2. run: `node tests/context-glossary-links.test.js`; exit 0. mutation: misspell
   `[[guard demotion]]`; exit 1.
3. run: `node tests/ubiquitous-language.test.js`; exit 0.
4. run: `tr '\n' ' ' < docs/harness-glossary.md | tr -s ' ' | /usr/bin/grep -oE 'See \[\[rubric v2\]\]|Each \[\[guard demotion\]\] is recorded here' | wc -l`;
   stdout `2`. mutation: skip one pointer; `1`.
5. run: `awk '/^\*\*rubric v2\*\*/,/^_Avoid_/' CONTEXT.md | tr '\n' ' ' | /usr/bin/grep -cF 'See [[contract score]] for the v1'`;
   stdout `1`. mutation: skip; `0`.
6. SC1, SC2, SC5.

### Step 5 (blf-5): rubric row ranges in docs match the scorer (item 6)

Affected files: `tests/rubric-doc-parity.test.js` (new), `tests/validate.sh` (one block
after the `tests/contract-score.test.js` block, same shape).
Test behaviour: run `node bin/contract-score.js` on `tests/fixtures/contract-score/v2-all-pass.md`
(`--rubric=v1` and `--rubric=v2`, shape lead) and on `v2-scribe-all-pass.md` (both
rubrics, shape scribe); take `Object.keys(json.rows)`; assert each key list is contiguous
`X1..Xn` and form ranges `R1-R7`, `S1-S5`, `S1-S7`. Then, on whitespace-flattened text,
collect every `\b([RS])\d+-\1\d+\b` match in: the `CONTEXT.md` **rubric v2** entry (from
its heading to the next blank line), the `docs/harness-glossary.md` **contract score**
entry (same), and all of `agents/task-master.md`. Assert: every R-range equals the lead
range (v1 and v2 lead must be equal); in **rubric v2** every S-range equals the v2 scribe
range; in **contract score** the set of S-ranges equals {v1 scribe, v2 scribe}; each doc
yields at least one range. Exit 1 on any failure, printing the doc and the range.

Acceptance criteria:
1. run: `node tests/rubric-doc-parity.test.js`; exit 0. mutation: `sed -i 's/on rows S1-S7/on rows S1-S6/' CONTEXT.md`
   then run; exit 1; then `git checkout CONTEXT.md`.
2. run: same test after `sed -i 's/rows R1-R7:/rows R1-R6:/' agents/task-master.md`; exit 1;
   then `git checkout agents/task-master.md`. (Second mutation: proves task-master.md is read.)
3. run: `/usr/bin/grep -c 'node tests/rubric-doc-parity.test.js' tests/validate.sh`; stdout `1`.
   mutation: skip registration; `0`.
4. run: `bash -n tests/validate.sh`; exit 0.
5. SC1, SC2, SC5.

### Step 6 (blf-6): FAIL block names the failed attempt's tier, Claude surfaces (item 7)

Affected files: `agents/reviewer.md` (lines 216-219), `templates/persona-protocol.md`
(FAIL record section line 349-350; "Continuing after a FAIL" lines 700-701), version
files, `.claude/` mirrors.
Edits (words fixed, line breaks set by task-master):
- a. reviewer.md: after `` `FAIL <task-id> <UTC ISO-8601 timestamp>` `` insert
  `, its second line exactly `tier: <t>`, where `<t>` is the dispatch's `Implementer
  tier:` value (`haiku`, `sonnet` or `opus`), or `unknown` when the dispatch has no such
  line,` before `followed by the same defect list`.
- b. persona-protocol.md FAIL record section: after the first-line sentence insert
  `second line `tier: <haiku|sonnet|opus|unknown>`, the tier the failed attempt ran on,
  copied from the reviewer dispatch's `Implementer tier:` line (the Escalation ladder
  never reads it),` before `followed by the defect list from the verdict, verbatim.`
- c. persona-protocol.md "Continuing after a FAIL": `then the defect list verbatim` →
  `then its `tier:` line and the defect list verbatim`.
- d. Version 0.31.151 → 0.31.152; CHANGELOG entry
  `**FAIL blocks name the failed attempt's tier (blf-6, 0.31.152).**`.

Acceptance criteria (`flat` = `tr '\n' ' ' < FILE | tr -s ' '`):
1. run: flat `agents/reviewer.md` | `/usr/bin/grep -cF 'its second line exactly `tier: <t>`'`; stdout `1`. mutation: skip a; `0`.
2. run: flat `templates/persona-protocol.md` | `/usr/bin/grep -cF 'second line `tier: <haiku|sonnet|opus|unknown>`'`; stdout `1`. mutation: skip b; `0`.
3. run: flat `templates/persona-protocol.md` | `/usr/bin/grep -cF 'then its `tier:` line and the defect list verbatim'`; stdout `1`. mutation: skip c; `0`.
4. run: `bash tests/fail-marker-format-parity.test.sh`; exit 0. (The second FAIL write
   path, `hooks/scripts/marker-write.sh FAIL <id> - <detail> <path>`, writes `<detail>`
   verbatim after the header, so a reviewer using it puts the `tier:` line first in
   `<detail>`; no hook change. Claim check, mutation n/a.)
5. run: `cat .claude-plugin/plugin.json package.json | grep -c '"version": "0.31.152"'`; stdout `2`.
6. run: `/usr/bin/grep -cF '(blf-6, 0.31.152)' CHANGELOG.md`; stdout `1`.
7. SC1-SC5.

### Step 7 (blf-7): FAIL block tier line in the adapter ports (item 7)

Affected files: `adapters/codex/agents/reviewer.toml:84`, `adapters/cursor/agents/reviewer.md:81`,
`adapters/cursor/rules/persona-protocol.mdc:130`, `adapters/codex/agents-md-fragment.md:123`.
Each gets, after its `` `FAIL <task-id> <UTC ISO-8601 timestamp>` `` first-line text, the
inserted clause `then a second line `tier: <haiku|sonnet|opus|unknown>` (`unknown` when
the dispatch names no implementer tier),` (ASCII hyphens only in the two reviewer ports,
matching their style). Not stamped: no version bump, no CHANGELOG entry (D8).

Acceptance criteria:
1. run: `for f in adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md adapters/cursor/rules/persona-protocol.mdc adapters/codex/agents-md-fragment.md; do tr '\n' ' ' < $f | tr -s ' ' | /usr/bin/grep -cF 'second line `tier: <haiku|sonnet|opus|unknown>`'; done | grep -cx 1`;
   stdout `4`. mutation: skip one port; `3`.
2. run: `node tests/adapter-protocol-parity.test.js && node tests/adapter-skill-parity.test.js && bash tests/fail-marker-format-parity.test.sh`; exit 0.
3. run: `git diff --name-only $(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(blf-7\): ' | tail -1 | cut -d' ' -f1)~1 HEAD -- agents templates .claude-plugin | wc -l`;
   stdout `0` when blf-7 is the last unit merged; task-master replaces this with a per-commit
   `git show --name-only` loop if other units interleave. mutation: touch `agents/reviewer.md`; `1`.
4. SC1, SC2, SC5.

### Step 8 (blf-8): orchestrator sends the implementer tier to the reviewer (item 7)

Affected files: `agents/orchestrator.md` (dispatch rule 3, lines 109-115; ladder text
lines 476-477), version files, `.claude/` mirrors.
Edits:
- a. Rule 3: append `A reviewer dispatch's second line is `Implementer tier: <t>`: the
  `model` the unit's latest implementer dispatch ran on.`
- b. `which tier wrote a block is never needed.` → `which tier wrote a block is never
  needed (a block's `tier:` line is for the human reader; the ladder never reads it).`
- c. Version 0.31.152 → 0.31.153; CHANGELOG entry
  `**Reviewer dispatch names the implementer tier (blf-8, 0.31.153).**`.

Acceptance criteria (`flat` as in Step 6, over `agents/orchestrator.md`):
1. run: flat | `/usr/bin/grep -cF "A reviewer dispatch's second line is \`Implementer tier: <t>\`"`; stdout `1`. mutation: skip a; `0`.
2. run: flat | `/usr/bin/grep -cF 'the ladder never reads it)'`; stdout `1`. mutation: skip b; `0`.
3. run: `node tests/writer-tier-consistency.test.js`; exit 0.
4. run: `cat .claude-plugin/plugin.json package.json | grep -c '"version": "0.31.153"'`; stdout `2`.
5. run: `/usr/bin/grep -cF '(blf-8, 0.31.153)' CHANGELOG.md`; stdout `1`.
6. SC1-SC5.

## Open Questions

1. (From CHK9.) Tier source for the FAIL block's `tier:` line. Recommended default (the
   plan is written to it): the orchestrator's `Implementer tier:` dispatch line, with
   `unknown` as the fallback. Alternative: the reviewer reads the Co-Authored-By trailer
   of the reviewed attempt's last commit. That drops blf-8 but relies on a self-reported
   value that orchestrator re-commits have already rewritten (F7). Second alternative:
   defer item 7 entirely, dropping blf-6/7/8.

## Self-check

- CHK1: Does Step 1 define the guard's treatment of `-` and `--`? — PASS (D1).
- CHK2: Does Step 1's criterion 4 fail on today's code? — PASS (F1: the file is scored, haiku line, exit 0).
- CHK3: Do Steps 2-8 and D8 agree on the version sequence? — PASS (150, 151, 152, 153 for blf-2/3/6/8).
- CHK4: Does the unit table's parallel group agree with each step's affected files? — PASS (P units touch no version file, CHANGELOG or shared content file).
- CHK5: Does item 2's scope in the Goal agree with F2? — FAIL (conflicting) — revised in place (G2 names task-master.md only; F2 records the premise correction).
- CHK6: Is the escaping rule stated so a criterion can check it? — PASS (Step 2 criterion 2).
- CHK7: Is the CHANGELOG correction's P3 treatment stated? — PASS (F5, D3).
- CHK8: Do Step 4's new entries and Step 3's wording agree on "FAIL-block count"? — PASS.
- CHK9: Is the source of the `tier:` value settled? — FAIL (missing user decision) — converted to Open Question 1.
- CHK10: Does Step 5's test fail when a doc range changes? — PASS (criteria 1 and 2 are mutations).
- CHK11: Does blf-7 criterion 3 bind to unit commits rather than HEAD alone? — FAIL (ambiguous: the span is valid only if nothing interleaves) — revised in place (task-master replaces it with a per-commit loop if units interleave, per Step 2's own rule).
- CHK12 (P3): Does every stamped unit carry SC3? — PASS (blf-2, 3, 6, 8).
- CHK13 (P5): Is a validate.sh run assigned? — PASS (R6).
- CHK14 (replay, mw-step2 vacuous; files `agents/reviewer.md`, `templates/persona-protocol.md`, the adapter ports): Do blf-6 criteria 1-3 and blf-7 criterion 1 still fail under their own `mutation:` lines? — PASS (each counts a phrase that is absent at HEAD).
- CHK15 (replay, gh-303 / gh339 vacuous; `CHANGELOG.md`, `CONTEXT.md`): Do blf-3 criteria 1-2 and blf-4 criteria 1, 4, 5 still fail under their mutation lines? — PASS (absent at HEAD; blf-3 criterion 2 counts `1` at HEAD).
- CHK16 (replay, gh317 vacuous; `tests/validate.sh`): Does blf-5 criterion 3 still fail under its mutation line? — PASS (`0` at HEAD).
- CHK17 (replay, gh310 / gh348-14 vacuous; `agents/orchestrator.md`): Do blf-8 criteria 1-2 still fail under their mutation lines? — PASS (absent at HEAD).
- CHK18 (replay, gh385-2 host; `agents/reviewer.md`): Does any blf criterion use a host path outside the repo other than `mktemp` and `/usr/bin/grep`? — FAIL (conflicting: blf-3 criterion 1 wrote `/tmp/blf3-want`) — revised in place (now `mktemp`).
- CHK19: Does item 7 need a change to `hooks/scripts/marker-write.sh`, a human-only surface? — PASS (F7: `<detail>` is written verbatim; blf-6 criterion 4 runs the parity test).

Ubiquitous-language prose check (advisory): lens 1, "FAIL count" in G4 is used in the
canonical D5 sense; nothing found. Lens 2, "fix round" vs "fix turn" are folded into one
heading by blf-4. Lens 3, "Implementer tier" (dispatch line) is new; it is a dispatch field
name, not a domain term, and scribe may add it with the FAIL record amendment.

## Scribe update hint

After blf-6 and blf-8: amend `CONTEXT.md` **FAIL record** (line ~837) to say a block's
second line is `tier: <t>`, informational, never read by the ladder. After blf-1: none
(the guard's argument rule is code-level). Close no issue (no tracker issue exists yet;
task-master publishes per-step issues under `plan/2026-10-09-backlog-followups` if it uses
the tracker).

## Handoff

Standard path: 8 units, so task-master slices with `to-tickets` and writes the
nine-element contracts (`Suggested model` tags are task-master's decision). Retrieval
contract: this file. Open Question 1 has a default; the plan is dispatchable as written.
