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

---

# Dispatch contracts (standard path; the plan file is the retrieval contract)

Written by task-master on 2026-10-09 at HEAD 625ab2b, version 0.31.149, after the spec above was FINAL. Nothing above this rule is changed by the contracts. Open Question 1 is applied at its recommended default (the orchestrator's `Implementer tier:` dispatch line, `unknown` as the fallback), so blf-6, blf-7 and blf-8 are sliced as the spec writes them.

## Retrieval contract

No per-unit issues exist (none was filed). The retrieval contract for every unit is this file, `docs/plans/2026-10-09-backlog-followups.md`, under `## Unit blf-<n>`: read the unit's `~~~~~~~markdown` block (its first line is `Unit: blf-<n>`), and the orchestrator's guard reads it with `node bin/contract-guard.js docs/plans/2026-10-09-backlog-followups.md --unit=blf-<n>` (add `--shape=scribe` for blf-4). The contract block outranks the plan prose above; a conflict is a spec gap: STOP. Every commit subject ends `(#529)`, the umbrella issue of the preceding backlog stages (it is CLOSED; reused as blc did, so one `sed` replaces it if a new umbrella is wanted); scribe closes nothing and never closes #529.

## Dispatch table

Every unit is tagged `Suggested model: haiku`: no `blf-*.fail` record exists (read for blf-1 to blf-8), and the tag is reactive. The reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over the unit's actual diff. `tests/validate.sh` (about 11 minutes) is not a unit criterion: the orchestrator runs it once after each unit merges (spec R6).

| unit | persona | Suggested model | Depends on | contract shape |
|---|---|---|---|---|
| blf-1 | lead-programmer | haiku | none | lead |
| blf-2 | lead-programmer | haiku | none (first of the stamped chain) | lead, stamped 0.31.150 |
| blf-3 | lead-programmer | haiku | blf-2 (PASS) | lead, stamped 0.31.151 |
| blf-4 | scribe | haiku | none | scribe |
| blf-5 | lead-programmer | haiku | none | lead |
| blf-6 | lead-programmer | haiku | blf-3 (PASS) | lead, stamped 0.31.152 |
| blf-7 | lead-programmer | haiku | blf-6 (PASS; wording only) | lead |
| blf-8 | lead-programmer | haiku | blf-6 (PASS) | lead, stamped 0.31.153 |

Intersection table (shared files are content files that two units edit; the bump files and the paths `node bin/cli.js --update` changes are excluded by definition, and stamped units serialize on those):

| unit | shared files | depends on |
|---|---|---|
| blf-1 | none | none |
| blf-2 | none | none (first stamped unit; each stamped unit sets HEAD + 1) |
| blf-3 | `templates/persona-protocol.md` | blf-2 (serial stamped edit) |
| blf-4 | none | none |
| blf-5 | none | none |
| blf-6 | `templates/persona-protocol.md` | blf-3 (serial stamped edit; shares the template with blf-3) |
| blf-7 | none | blf-6 (wording only; no shared file) |
| blf-8 | none | blf-6 (serial stamped edit, so it runs after blf-6) |

The parallel/serial map is the spec's. **Dispatchable now: blf-1, blf-2, blf-4 and blf-5** (blf-1, blf-4 and blf-5 are file-disjoint from each other and from the stamped chain, and none of them runs `node bin/cli.js --update`; they may run in separate worktrees). The stamped chain blf-2, then blf-3, then blf-6, then blf-8 runs in order on one branch and alone (spec R2). blf-7 waits for blf-6 PASS and may then run in parallel with blf-8. blf-6 is dispatched only when no other unit is mid-review (spec R3).

## Slice state

| unit | state | reason |
|---|---|---|
| blf-1, blf-4, blf-5 | dispatchable | none |
| blf-2 | dispatchable | none (first of the stamped chain) |
| blf-3 | waiting | dispatch after blf-2 PASS (serial stamped edit) |
| blf-6 | waiting | dispatch after blf-3 PASS (serial stamped edit; shares `templates/persona-protocol.md`) |
| blf-7 | waiting | dispatch after blf-6 PASS (reuses its wording) |
| blf-8 | waiting | dispatch after blf-6 PASS (serial stamped edit) |

No unit is held and no spec gap was found. The contracts below score 7/7 under `node bin/contract-guard.js` (rubric v2) and were replayed, unit by unit and in dispatch order, in a scratch worktree of 625ab2b: every edit applies, every criterion passes afterward, and for each file edit of each unit, a replay with only that edit skipped made the criteria that name it fail as claimed (and the `node bin/cli.js --update` item for the stamped units). Slicing notes for spec-master (the spec text above is untouched):

1. **Shared criteria SC1 to SC5.** SC1 and SC2 carry a "stdout at least 1" and a loop over the unit's commits; each contract writes them per commit with a leading guard that prints `no-unit-commit` and exits 3 when the unit has no commit yet (an empty loop would otherwise print `0` and pass before the unit). SC3 (stamped units only) additionally requires `touched: yes` on every unit commit. SC4 was measured with one deliberately stale scratch run (one line appended to `templates/protocol-digest.md` in a worktree of 625ab2b): the non-current entries print `would be rewritten.` (for `.claude/persona-config.json`) and `would be updated (no local edits detected)` (for `.claude/protocol-digest.md`), two lines, so `grep -vc ': already current$'` prints `2` there and `0` on a current tree. SC5 excludes `.claude/agent-memory` as the spec says.
2. **No `<first>~1..<last>` span.** Every criterion over a unit's commits iterates the unit's own commit list (`git log --format='%H %s'` filtered by the anchored subject pattern). Each contract also carries the untagged-tail criterion that agents/task-master.md **Range criteria** requires, over the unit's content files only (the version files are excluded). The tail criteria of blf-3 and blf-6 are run at review time, before the next unit that edits `templates/persona-protocol.md` lands.
3. **blf-7 criterion 3** (the spec's `git diff --name-only <first>~1 HEAD` span) is replaced by a per-commit loop, as the spec itself allowed.
4. **blf-3 edit a** is anchored by the entry's text, not by `CHANGELOG.md:7`: the line number moves down by two once blf-2 prepends its entry.
5. **Backticks in `run:` lines.** An inline-code `run:` cannot hold a backtick, so the spec's phrase counts that quote backticked text (blf-2, blf-6, blf-7, blf-8) use `grep -E` with `.` standing for a backtick; each was re-run and counts `0` at HEAD and `1` after the edit.
6. **blf-5 mutation criteria** run in a `git worktree add --detach` scratch copy of HEAD instead of editing `CONTEXT.md` and `agents/task-master.md` in place and restoring them with `git checkout`, so the working tree stays clean; they count the test's own `FAIL <doc>` line, which a missing test file cannot print, so they are red at HEAD.
7. **blf-4 hunk count.** The spec's two entries after **ladder exhaustion** and three after **rubric v2** land as two insertion hunks plus the **rubric v2** pointer hunk: `CONTEXT.md` has 3 hunks under `-U0`, `docs/harness-glossary.md` 2 (criterion 7). The **fix round** entry keeps the spec's bold on **Fix turns** mid-line, which `tests/context-glossary-links.test.js` reads only at the start of a line.
8. **Version-bump count of `.claude` paths.** `node bin/cli.js --update` rewrites 14 `.claude` paths in each stamped unit (10 agent mirrors, `.claude/persona-config.json` and three protocol files), measured in the replay; each stamped contract states it as the expected `stdout` of its status command.
9. **Resume.** No tracker issue exists, so the Slice state table above is the slice-state record: a later pass that finds a gap ruled (a line starting `- <ruling-id>:` under `## Rulings`) flips the affected rows; no unit is re-filed.

## Rulings

(spec-master adds one line per resolved gap, starting `- <ruling-id>:`.)

## Unit blf-1

~~~~~~~markdown
Unit: blf-1

## Objective
`bin/contract-guard.js` exits 2 with empty stdout on a repeated `--unit=` or `--shape=` flag and on any unknown flag (any other argument that starts with `-` and is not exactly `-`), including a lone one with no positional argument; its header comment states the rule; `tests/contract-score.test.js` proves both cases with two new checks that fail on the current code.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-followups.md`, `## Unit blf-1`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `tests/contract-score.test.js` (anchors: line matching `const path = require('path');` and line matching `console.log(failures === 0 ?`)
- `bin/contract-guard.js` (anchors: line matching `// Any argument other than one <path|-> and the --unit=<id> / --shape=<lead|scribe> flags is a usage` and line matching `  const opt = (k) => {`)

## Ordered edits
1. file: `tests/contract-score.test.js`
   anchor: line matching `const path = require('path');`
   indent: 0
   insert-after:
```
const os = require('os');
```
2. file: `tests/contract-score.test.js`
   anchor: line matching `console.log(failures === 0 ?`
   indent: 0
   before:
```
console.log(failures === 0 ? '\nAll contract-score checks passed.' : `\n${failures} check(s) failed.`);
```
   after:
```
check('guard-usage-repeated-flag', () => {
  for (const args of [['-', '--unit=demo-2', '--unit=demo-2'], ['-', '--unit=demo-2', '--shape=lead', '--shape=lead']]) {
    const r = guard(args, G_LEAD);
    assert.strictEqual(r.status, 2, `${args.join(' ')}: exit ${r.status}`);
    assert.strictEqual(r.stdout, '', `${args.join(' ')}: stdout ${r.stdout}`);
  }
});

check('guard-usage-lone-unknown-flag', () => {
  // A file named `--bogus` exists in the CWD: an unknown flag must be refused, never opened as the input.
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'guard-flag-'));
  try {
    fs.writeFileSync(path.join(dir, '--bogus'), G_LEAD);
    const r = spawnSync('node', [path.join(REPO_ROOT, 'bin', 'contract-guard.js'), '--unit=demo-2', '--bogus'], { cwd: dir, encoding: 'utf8' });
    assert.strictEqual(r.status, 2, `exit ${r.status}`);
    assert.strictEqual(r.stdout, '', `stdout ${r.stdout}`);
    assert.ok(r.stderr.includes('unknown flag: --bogus'), `stderr ${r.stderr}`);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

console.log(failures === 0 ? '\nAll contract-score checks passed.' : `\n${failures} check(s) failed.`);
```
3. command: `node tests/contract-score.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=1`
4. file: `bin/contract-guard.js`
   anchor: line matching `// Any argument other than one <path|-> and the --unit=<id> / --shape=<lead|scribe> flags is a usage`
   indent: 0
   before:
```
// Any argument other than one <path|-> and the --unit=<id> / --shape=<lead|scribe> flags is a usage
// error (exit 2, empty stdout), for example `--shape scribe` written with a space.
```
   after:
```
// Arguments: exactly `-`, or one other word that does not start with `-`, is the <path|->;
// `--unit=<id>` and `--shape=<lead|scribe>` are flags, each allowed once (a repeat is a usage
// error); any other argument that starts with `-`, including `--`, is an unknown flag. Every such
// case exits 2 with empty stdout, for example `--shape scribe` written with a space. A file whose
// name starts with `-` is passed as `./-name`.
```
5. file: `bin/contract-guard.js`
   anchor: line matching `  const opt = (k) => {`
   indent: 2
   before:
```
  const opt = (k) => {
    const a = args.find((x) => x.startsWith(`--${k}=`));
    return a ? a.slice(k.length + 3) : null;
  };
  const id = opt('unit');
  const shape = opt('shape') || 'lead';
  const rest = args.filter((a) => !/^--(unit|shape)=/.test(a));
  if (rest.length > 1) usage(`unexpected argument(s): ${rest.slice(1).join(' ')}`);
```
   after:
```
  const flags = {};
  const rest = [];
  for (const a of args) {
    const m = /^--(unit|shape)=(.*)$/.exec(a);
    if (m) {
      if (Object.hasOwn(flags, m[1])) usage(`repeated --${m[1]}`);
      flags[m[1]] = m[2];
    } else if (a !== '-' && a.startsWith('-')) {
      usage(`unknown flag: ${a}`);
    } else {
      rest.push(a);
    }
  }
  const id = flags.unit || null;
  const shape = flags.shape || 'lead';
  if (rest.length > 1) usage(`unexpected argument(s): ${rest.slice(1).join(' ')}`);
```
6. command: `node tests/contract-score.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
7. command: `git add bin/contract-guard.js tests/contract-score.test.js && git commit -m "fix(blf-1): contract guard rejects repeated and unknown flags (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `bin/contract-score.js` (the scorer is unchanged)
- `agents/orchestrator.md` (its guard call lines already pass only valid arguments)
- `.claude/` (bin/ and tests/ have no mirror; no `--update` and no version bump apply)
- `tests/validate.sh` (the test file already exists and is already registered)

## Acceptance criteria
1. run: `node tests/contract-score.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 5; the two new checks fail and it prints `exit=1`. It prints `exit=0` at HEAD (no new checks yet), so criterion 2 is the red-at-HEAD proof.
2. run: `node tests/contract-score.test.js | /usr/bin/grep -cE '^OK +guard-usage-(repeated-flag|lone-unknown-flag)$'`
   exit: 0
   stdout: `2`
   mutation: skip edit 2; it prints `0` and exits 1. It prints `0` at HEAD.
3. run: `node bin/contract-guard.js - --unit=demo-2 --unit=demo-2 < tests/fixtures/contract-score/v2-all-pass.md 2>/dev/null; echo "exit=$?"`
   exit: 0
   stdout: `exit=2`
   mutation: skip edit 5; it prints the `contract-guard: haiku` line and then `exit=0`.
4. run: `R=$(pwd); D=$(mktemp -d); cp tests/fixtures/contract-score/v2-all-pass.md "$D/--bogus"; (cd "$D" && node "$R/bin/contract-guard.js" --unit=demo-2 --bogus 2>/dev/null); E=$?; rm -rf "$D"; echo "exit=$E"`
   exit: 0
   stdout: `exit=2`
   mutation: skip edit 5; the file named `--bogus` is scored, the haiku line prints and then `exit=0`.
5. run: `node bin/contract-guard.js - --unit=demo-2 --shape=lead --shape=lead < tests/fixtures/contract-score/v2-all-pass.md 2>/dev/null; echo "exit=$?"`
   exit: 0
   stdout: `exit=2`
   mutation: skip edit 5; it prints the haiku line and then `exit=0`.
6. run: `node bin/contract-guard.js tests/fixtures/contract-score/guard-plan-hdc.md --unit=hdc-1 | head -1`
   exit: 0
   stdout: `contract-guard: haiku unit=hdc-1 shape=lead score=7/7`
   mutation: in edit 5 write `flags[m[1]] = m[2]` as `flags[m[1]] = ''`; the unit id is lost and the guard exits 2 with no stdout, so nothing prints. It already passes at HEAD and must stay green.
7. run: `/usr/bin/grep -cE 'passed as .[.]/-name' bin/contract-guard.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; it prints `0` and exits 1.
8. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(blf-1\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
9. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
10. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- bin/contract-guard.js tests/contract-score.test.js | /usr/bin/grep -vcE '^[a-z]+\(blf-1\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
11. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `bin/contract-guard.js tests/contract-score.test.js`
   mutation: touch one extra file in the unit's commit; the list gains that path.
12. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-1\): ' | wc -l` prints `0`, and `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: yes tests/contract-score.test.js (edit 2 adds the two checks, edit 3 shows them red against the current guard, edit 6 shows them green after edits 4 and 5)
blast-radius: bin/contract-guard.js:66, bin/contract-guard.js:10, tests/contract-score.test.js:297, tests/contract-score.test.js:318
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 1 inserts one line after the `path` require; edit 2's `before:` is the last code line of the test file and `after:` is the two new checks, one empty line, then that same line.
note: the existing check `guard-usage-extra-args` (two positionals) stays green; `-` stays a positional; `--` is an unknown flag; `--unit=` and `--shape=` with an empty value behave as before (`bad or missing --unit`; shape falls back to `lead`).
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blf-1)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 625ab2b; grep-derived, not graph-derived).
commit-message: fix(blf-1): contract guard rejects repeated and unknown flags (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blf-1 (#529)
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
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit blf-2

~~~~~~~markdown
Unit: blf-2

## Objective
`agents/task-master.md` **Range criteria** lists a unit's commits by subject only (never `git log --grep`, whose `^` also matches a body line), states that each `.` of the unit id is written `\.` in the pattern, and makes criteria over a unit's commits iterate that list instead of a `<first>~1..<last>` span. Version 0.31.150; mirrors refreshed.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-followups.md`, `## Unit blf-2`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `agents/task-master.md` (anchor: line matching `  **Range criteria.** A criterion over a commit range binds its start and`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.149",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `agents/task-master.md`
   anchor: line matching `  **Range criteria.** A criterion over a commit range binds its start and`
   indent: 2
   before:
```
  **Range criteria.** A criterion over a commit range binds its start and
  end to the unit's own first and last commits, found with `git log
  --format=%H -E --grep='^[a-z]+\(<unit-id>\): '` (`tail -1`, `head -1`), never
  `HEAD`; the anchored pattern matches only a subject whose scope is the unit,
  never a later commit that merely mentions it. That end holds only if every
  commit of the unit, fix rounds included, carries `(<unit-id>)` as its subject
  scope, so every `commit-message:` line of a contract or fix contract does,
  and every range contract adds one untagged-tail criterion, run at review
  time over the unit's content files (never the version files or `.claude/`):
  `git log --format=%s <end>..HEAD -- <content files> | grep -vcE
  '^[a-z]+\(<unit-id>\): '`, `exit: 1`, `stdout: 0`. A red-set criterion over
```
   after:
```
  **Range criteria.** A unit's own commits are listed by subject only: `git log
  --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(<unit-id>\): ' | cut -d' ' -f1`,
  newest first (`tail -1` is the unit's first commit, `head -1` its last), never
  `HEAD` and never `git log --grep`, whose `^` also matches a body line of a
  later commit. In `<unit-id>` write each `.` as `\.`; no other character of the
  unit-id grammar is special in the pattern. A criterion over a unit's commits
  iterates that list (`for c in <list>; do … "$c~1..$c"; done`), never a
  `<first>~1..<last>` span, which also takes in any other unit's commit landed
  between them. That list is complete only if every commit of the unit, fix
  rounds included, carries `(<unit-id>)` as its subject scope, so every
  `commit-message:` line of a contract or fix contract does, and every range
  contract adds one untagged-tail criterion, run at review time over the unit's
  content files (never the version files or `.claude/`): `git log --format=%s
  <end>..HEAD -- <content files> | grep -vcE '^[a-z]+\(<unit-id>\): '`,
  `exit: 1`, `stdout: 0`. A red-set criterion over
```
2. file: `.claude-plugin/plugin.json` (version 0.31.150)
   anchor: line matching `"version": "0.31.149",`
   before: `  "version": "0.31.149",`
   after: `  "version": "0.31.150",`
3. file: `package.json` (version 0.31.150)
   anchor: line matching `"version": "0.31.149",`
   before: `  "version": "0.31.149",`
   after: `  "version": "0.31.150",`
4. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Range criteria list a unit's commits by subject (blf-2, 0.31.150).** `agents/task-master.md` **Range criteria**: a unit's own commits are listed with `git log --format='%H %s'` filtered by the anchored subject pattern, never `git log --grep` (whose `^` also matches a body line of a later commit); each `.` of the unit id is written `\.` in the pattern; a criterion over a unit's commits iterates that list instead of spanning `<first>~1..<last>`, which also takes in any other unit's commit landed between them. Mirrors refreshed by `node bin/cli.js --update`.
```
5. command: `node bin/cli.js --update`
   expect: 0
6. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
7. command: `git add agents/task-master.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "docs(blf-2): range criteria list a unit's commits by subject (0.31.150) (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0
8. command: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/lead-programmer.md`, `agents/scribe.md`, `adapters/cursor/agents/lead-programmer.md`, `adapters/codex/agents/lead-programmer.toml` (they hold no pattern; the spec's premise correction F2)
- `agents/orchestrator.md`, `agents/reviewer.md` (units blf-6 and blf-8)
- `templates/` (unit blf-3)
- `.claude/` (mirrors are regenerated only by `node bin/cli.js --update`)

## Acceptance criteria
1. run: `tr '\n' ' ' < agents/task-master.md | tr -s ' ' | /usr/bin/grep -cE 'never .git log --grep., whose .\^. also matches a body line'`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; it prints `0`, exit 1.
2. run: `tr '\n' ' ' < agents/task-master.md | tr -s ' ' | /usr/bin/grep -cE 'write each .[.]. as .\\[.].'`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; it prints `0`, exit 1.
3. run: `tr '\n' ' ' < agents/task-master.md | tr -s ' ' | /usr/bin/grep -cE 'never a .<first>~1[.][.]<last>. span'`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; it prints `0`, exit 1.
4. run: `/usr/bin/grep -cF -- "--format=%H -E --grep=" agents/task-master.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 1; it prints `1`, exit 0.
5. run: `git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blc-5\): ' | cut -d' ' -f1 | cut -c1-7`
   exit: 0
   stdout: `6dc68fa`
   mutation: a claim check that the documented pipeline runs; it does not depend on the edit. Replace `blc-5` with `blc-9`; it prints nothing. It already passes at HEAD and must stay green.
6. run: `cmp <(sed -n '/Range criteria/,/stdout: 0/p' agents/task-master.md) <(sed -n '/Range criteria/,/stdout: 0/p' .claude/agents/task-master.md) && echo same`
   exit: 0
   stdout: `same`
   mutation: skip edit 5 (`node bin/cli.js --update`); the mirror keeps the old paragraph and cmp reports a difference, exit 1. Both files hold the old paragraph at HEAD, so it passes there and must stay green.
7. run: `cat .claude-plugin/plugin.json package.json | /usr/bin/grep -c '"version": "0.31.150"'`
   exit: 0
   stdout: `2`
   mutation: skip edit 2 or 3; it prints `1`.
8. run: `/usr/bin/grep -cF '(blf-2, 0.31.150)' CHANGELOG.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; it prints `0`, exit 1.
9. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do bash hooks/scripts/version-stamp-check.sh "$c~1..$c"; done | /usr/bin/grep -vc '^version-stamp-check: ok touched: yes '`
   exit: 1
   stdout: `0`
   mutation: skip edit 2; the line reads `violation` and it prints `1`, exit 0 (the script exits 0 on a violation, so this gates on stdout).
10. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.150';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 3; it prints `version-sync: mismatch`, exit 1.
11. run: `node bin/cli.js --update --dry-run 2>&1 | /usr/bin/grep -E '^  ' | /usr/bin/grep -vc ': already current$'`
   exit: 1
   stdout: `0`
   mutation: skip edit 5; the mirror and the config line are non-current and it prints `14`, exit 0. It prints `0` at HEAD (a current tree) and must stay `0`. Measured with a stale scratch copy (one template line appended): the non-current lines read `would be rewritten.` and `would be updated (no local edits detected)`, so the filter catches both.
12. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(blf-2\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
13. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
14. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- agents/task-master.md | /usr/bin/grep -vcE '^[a-z]+\(blf-2\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches the content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
15. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | /usr/bin/grep -v '^\.claude/' | LC_ALL=C sort -u | tr '\n' ' '`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md agents/task-master.md package.json`
   mutation: touch one extra file in the unit's commit; the list gains that path.
16. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.149`. Anything else: STOP; the orchestrator re-derives every version literal as HEAD version + 1 and rewrites this contract's version lines before dispatch (spec D8: a unit that finds HEAD at another version reports a spec gap).
precondition: `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-2\): ' | wc -l` prints `0`, the tree is clean (`git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l` prints `0`), and no other unit that runs `node bin/cli.js --update` is in flight (blf-2, blf-3, blf-6 and blf-8 run one at a time on one branch). Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edit of an agent file (criteria 1-4 count phrases that are absent at HEAD)
blast-radius: agents/task-master.md:200, .claude/agents/task-master.md:201, bin/cli.js:1
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 1's `after:` ends with the words `A red-set criterion over`, which continue on the next line of the file exactly as before; the paragraph from `A red-set criterion over` on is unchanged. Edit 4's payload begins with one empty line, which is part of the text, and its entry is ONE line.
note: the new paragraph contains the unicode ellipsis `…` exactly as the spec writes it; keep it.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blf-2)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 625ab2b; grep-derived, not graph-derived).
commit-message: docs(blf-2): range criteria list a unit's commits by subject (0.31.150) (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blf-2 (#529)
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
criterion 16: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit blf-3

~~~~~~~markdown
Unit: blf-3

## Objective
The CHANGELOG 0.31.148 entry reads as the blc-5 contract's edit-9 payload; the ladder-exhaustion sentence in `templates/persona-protocol.md` is wrapped on three lines and, like `templates/protocol-digest.md`, says "FAIL-block count". Version 0.31.151; mirrors refreshed.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-followups.md`, `## Unit blf-3`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `CHANGELOG.md` (anchors: line matching `**Unit commits carry their scope; anchored range pattern (blc-5, 0.31.148).**` and line matching `## [Unreleased]`)
- `templates/persona-protocol.md` (anchor: line matching `human stop happens there. Only ladder exhaustion (the unit's FAIL count`)
- `templates/protocol-digest.md` (anchor: line matching `  ladder exhaustion (FAIL count reaching or exceeding the ladder's length)`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.150",`)
- the `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `CHANGELOG.md`
   anchor: line matching `**Unit commits carry their scope; anchored range pattern (blc-5, 0.31.148).**`
   indent: 0
   before:
```
**Unit commits carry their scope; anchored range pattern (blc-5, 0.31.148).** `agents/task-master.md` **Range criteria** now binds range start and end to a unit's first and last commits using the anchored pattern `git log --format=%H -E --grep='^[a-z]+\(<unit-id>\): '`, which matches only unit-scoped subjects, never later mentions. Every commit of a unit, fix rounds included, carries the unit id as its scope; fix contracts apply this rule. Every range contract adds an untagged-tail criterion run at review time. `agents/lead-programmer.md` **Fix turns** and both ports, `agents/scribe.md`: without a contract, every commit carries the unit id as scope. The ports' AC-A1 parity test confirms the lead-programmer sentence reads identically in both.
```
   after:
```
**Unit commits carry their scope (blc-5, 0.31.148).** `agents/task-master.md`: a unit's range criteria find its first and last commits with the anchored `git log --format=%H -E --grep='^[a-z]+\(<unit-id>\): '`, which no later commit that merely mentions the unit id can match, and every range contract adds an untagged-tail criterion (`exit: 1`, `stdout: 0`) so a fix-round commit outside the unit's scope is caught at review time; a fix contract's `commit-message:` carries the unit scope. `agents/lead-programmer.md` and its Cursor and Codex ports: every fix commit's subject carries `(<task-id>)`, with or without a contract. `agents/scribe.md`: without a contract, every commit of a unit, fix rounds included, carries `(<task-id>)`. No hook is added. Mirrors refreshed by `node bin/cli.js --update`.
```
2. file: `templates/persona-protocol.md`
   anchor: line matching `human stop happens there. Only ladder exhaustion (the unit's FAIL count`
   indent: 0
   before:
```
human stop happens there. Only ladder exhaustion (the unit's FAIL count reaching or exceeding the ladder's length: normally the second FAIL on its top tier) stops re-dispatch: the orchestrator (or team lead) then
```
   after:
```
human stop happens there. Only ladder exhaustion (the unit's FAIL-block count
reaching or exceeding the ladder's length: normally the second FAIL on its top
tier) stops re-dispatch: the orchestrator (or team lead) then
```
3. file: `templates/protocol-digest.md`
   anchor: line matching `  ladder exhaustion (FAIL count reaching or exceeding the ladder's length)`
   indent: 2
   before: `  ladder exhaustion (FAIL count reaching or exceeding the ladder's length)`
   after: `  ladder exhaustion (FAIL-block count reaching or exceeding the ladder's length)`
4. file: `.claude-plugin/plugin.json` (version 0.31.151)
   anchor: line matching `"version": "0.31.150",`
   before: `  "version": "0.31.150",`
   after: `  "version": "0.31.151",`
5. file: `package.json` (version 0.31.151)
   anchor: line matching `"version": "0.31.150",`
   before: `  "version": "0.31.150",`
   after: `  "version": "0.31.151",`
6. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Ladder-exhaustion wording; 0.31.148 entry corrected (blf-3, 0.31.151).** `templates/persona-protocol.md` wraps the ladder-exhaustion sentence on three lines, and it and `templates/protocol-digest.md` say "FAIL-block count" (the count of `FAIL <task-id> ` header lines in the FAIL record) instead of "FAIL count". The 0.31.148 entry is corrected to match the blc-5 contract: `agents/lead-programmer.md` and its Cursor and Codex ports commit every fix with the unit scope, with or without a contract. Mirrors refreshed by `node bin/cli.js --update`.
```
7. command: `node tests/protocol-doc-drift.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
8. command: `node bin/cli.js --update`
   expect: 0
9. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
10. command: `git add CHANGELOG.md templates/persona-protocol.md templates/protocol-digest.md .claude-plugin/plugin.json package.json && git add -u -- .claude && git commit -m "docs(blf-3): ladder-exhaustion wording, FAIL-block count, 0.31.148 entry corrected (0.31.151) (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0
11. command: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/` (no agent file changes in this unit)
- `templates/persona-protocol.md` lines other than the ladder-exhaustion sentence (the line `so the FAIL count is readable across sessions` keeps its wording; unit blf-6 edits the FAIL record section)
- `CONTEXT.md`, `docs/harness-glossary.md` (unit blf-4; scribe owns them)
- `.claude/` (mirrors are regenerated only by `node bin/cli.js --update`)

## Acceptance criteria
1. run: `W=$(mktemp); sed -n 1551p docs/plans/2026-10-09-backlog-cleanup.md > "$W"; /usr/bin/grep -cxFf "$W" CHANGELOG.md; rm -f "$W"`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; it prints `0`.
2. run: `/usr/bin/grep -cF 'anchored range pattern (blc-5, 0.31.148)' CHANGELOG.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 1; it prints `1`, exit 0.
3. run: `awk 'length>80' templates/persona-protocol.md | /usr/bin/grep -cF 'Only ladder exhaustion'`
   exit: 1
   stdout: `0`
   mutation: skip edit 2; it prints `1`, exit 0.
4. run: `/usr/bin/grep -cxF "tier) stops re-dispatch: the orchestrator (or team lead) then" templates/persona-protocol.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; it prints `0`, exit 1.
5. run: `cat templates/persona-protocol.md templates/protocol-digest.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -oF 'FAIL-block count reaching or exceeding' | wc -l`
   exit: 0
   stdout: `2`
   mutation: skip edit 3; it prints `1`.
6. run: `node tests/protocol-doc-drift.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: add a 16th non-empty body line to `templates/protocol-digest.md`; the budget check fails and it prints `exit=1`. It already passes at HEAD and must stay green.
7. run: `cat .claude-plugin/plugin.json package.json | /usr/bin/grep -c '"version": "0.31.151"'`
   exit: 0
   stdout: `2`
   mutation: skip edit 4 or 5; it prints `1`.
8. run: `/usr/bin/grep -cF '(blf-3, 0.31.151)' CHANGELOG.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; it prints `0`, exit 1.
9. run: `tr '\n' ' ' < .claude/persona-protocol.md | tr -s ' ' | /usr/bin/grep -oF 'FAIL-block count reaching or exceeding' | wc -l`
   exit: 0
   stdout: `1`
   mutation: skip edit 8 (`node bin/cli.js --update`); the mirror keeps the old words and it prints `0`.
10. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-3\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do bash hooks/scripts/version-stamp-check.sh "$c~1..$c"; done | /usr/bin/grep -vc '^version-stamp-check: ok touched: yes '`
   exit: 1
   stdout: `0`
   mutation: skip edit 4; the line reads `violation` and it prints `1`, exit 0 (the script exits 0 on a violation, so this gates on stdout).
11. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.151';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 5; it prints `version-sync: mismatch`, exit 1.
12. run: `node bin/cli.js --update --dry-run 2>&1 | /usr/bin/grep -E '^  ' | /usr/bin/grep -vc ': already current$'`
   exit: 1
   stdout: `0`
   mutation: skip edit 8; the mirrors are non-current and it prints a count above `0`, exit 0 (a stale scratch copy prints the lines `would be rewritten.` and `would be updated (no local edits detected)`). It prints `0` at HEAD and must stay `0`.
13. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-3\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(blf-3\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
14. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-3\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
15. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-3\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- templates/persona-protocol.md templates/protocol-digest.md | /usr/bin/grep -vcE '^[a-z]+\(blf-3\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time, before blf-6 lands: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
16. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-3\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | /usr/bin/grep -v '^\.claude/' | LC_ALL=C sort -u | tr '\n' ' '`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md package.json templates/persona-protocol.md templates/protocol-digest.md`
   mutation: touch one extra file in the unit's commit; the list gains that path.
17. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.150` (unit blf-2 has landed). Anything else: STOP; the orchestrator re-derives every version literal as HEAD version + 1 and rewrites this contract's version lines before dispatch (spec D8).
precondition: `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-3\): ' | wc -l` prints `0`, `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-2\): ' | wc -l` is at least `1` (the orchestrator confirms the blf-2 PASS marker before dispatch), the tree is clean, and no other unit that runs `node bin/cli.js --update` is in flight. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text. Edit 1's `before:` is the whole 0.31.148 entry line (its number moves down when blf-2 lands, so it is anchored by text) and its `after:` is line 1551 of `docs/plans/2026-10-09-backlog-cleanup.md`, byte for byte (the contract of record for that entry).
tdd: no prose and changelog edit (criteria 1-5 and 8 count text that is absent at HEAD; criterion 6 runs the existing drift test)
blast-radius: templates/persona-protocol.md:708, templates/protocol-digest.md:15, CHANGELOG.md:7, tests/protocol-doc-drift.test.js:1, .claude/persona-protocol.md:1
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 6's payload begins with one empty line, which is part of the text, and its entry is ONE line. Edit 2 turns one 212-character line into three lines; the third line ends with the words `or team lead) then`, which the file continues on its next line exactly as before.
note: CHANGELOG.md is not a version-stamped path (`hooks/scripts/version-stamp-check.sh` matches only `agents/*.md` and `templates/*`), so the correction in edit 1 needs no bump of its own; it rides in this unit, which bumps for its template edits (spec D3).
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blf-3)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 625ab2b; grep-derived, not graph-derived).
commit-message: docs(blf-3): ladder-exhaustion wording, FAIL-block count, 0.31.148 entry corrected (0.31.151) (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blf-3 (#529)
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
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit blf-4

~~~~~~~markdown
Unit: blf-4

## Objective
CONTEXT.md defines **FAIL-block count**, **fix round** (synonym **fix turn**), **guard demotion**, **untagged-tail criterion** and **trailer sweep**, and rubric v2, contract score and the Rulings ledger point at each other.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-followups.md`, `## Unit blf-4`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Glossary edits
Items 1, 2 and 3 replace a substring of one line inside the entry named by `heading:`: each `before:` is that substring (no leading or trailing spaces, so the line's own spaces stay), and `text:` replaces exactly that substring. Items 4 to 8 add a new entry: insert one empty line and then the `text:` lines directly after the `_Avoid_:` line of the entry named by `heading:`; the empty line that already follows that entry stays after the new one. Apply the items in order: items 5, 7 and 8 name the entry that the item before them added.
1. file: `CONTEXT.md`
   heading: `**rubric v2**:`
   before:
```
v1 stays for older contracts.
```
   text:
```
v1 stays for older contracts. See [[contract score]] for the v1 table.
```
2. file: `docs/harness-glossary.md`
   heading: `**contract score**:`
   before:
```
See [[unit-outcome export]], [[content-typed contract]].
```
   text:
```
See [[unit-outcome export]], [[content-typed contract]]. See [[rubric v2]].
```
3. file: `docs/harness-glossary.md`
   heading: `**Rulings ledger**:`
   before:
```
see [[ruling / rulings disambiguation]]).
```
   text:
```
see [[ruling / rulings disambiguation]]). Each [[guard demotion]] is recorded here.
```
4. file: `CONTEXT.md`
   heading: `**ladder exhaustion**:`
   text:
```
**FAIL-block count**:
(unit blf-4, 2026-10-09) — the number of `FAIL <task-id> ` header lines in a
  unit's [[FAIL record]], one per FAIL verdict, as `bin/fail-count.sh` prints it;
  the count the [[Escalation ladder]] and [[ladder exhaustion]] read. Under
  review gating off no FAIL record is written and the orchestrator counts
  advisory FAILs in the session: that is a FAIL count, never a FAIL-block count.
_Avoid_: FAIL count (when the record is meant)
```
5. file: `CONTEXT.md`
   heading: `**FAIL-block count**:`
   text:
```
**fix round** (synonym: **fix turn**):
(unit blf-4, 2026-10-09) — one re-dispatch of a unit to the implementer after a
  FAIL verdict, with a fix contract or with the bare defect list, and the commits
  it lands. Each of its commits carries the unit's scope, and its trailer names
  the model of its own tier. lead-programmer's **Fix turns** section is the
  implementer's side of the same round.
_Avoid_: fix attempt
```
6. file: `CONTEXT.md`
   heading: `**rubric v2**:`
   text:
```
**guard demotion**:
(unit blf-4, 2026-10-09) — the [[Contract-score guard]] moving a unit to the
  ladder that starts at `sonnet`: every outcome other than an exit-0
  `contract-guard: haiku ` line, whether a row failed, the contract is oversize,
  no contract block was found, or the script or scorer errored. "Fails safe to
  sonnet" names the error cases only; all of them are guard demotions and each
  gets a line in the [[Rulings ledger]].
_Avoid_: escalation (that is FAIL-driven), downgrade
```
7. file: `CONTEXT.md`
   heading: `**guard demotion**:`
   text:
```
**untagged-tail criterion**:
(unit blc-5, 2026-10-09) — the criterion every range contract adds, run at review
  time: no commit after the unit's last commit touches the unit's content files
  without the unit's scope in its subject. Unrelated to the `untagged` lines of
  the reviewer note channel (a note line with no NOTE tag).
_Avoid_: untagged (alone)
```
8. file: `CONTEXT.md`
   heading: `**untagged-tail criterion**:`
   text:
```
**trailer sweep**:
(unit blc-4, 2026-10-09) — a one-off edit of landed plan contracts that replaced
  a model-name placeholder in each contract's trailer line with the trailer the
  unit's first commit carries, measured with `git log`. It changes plan records
  only and never rewrites a commit.
_Avoid_: trailer fix
```

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #529 is the umbrella [spec] issue and no per-unit issue exists: close nothing, and never close #529
- task-id: blf-4
- marker first line: "PASS blf-4 "
- commit: one commit of `CONTEXT.md` and `docs/harness-glossary.md` (plus one per fix round after a FAIL), made with `git add CONTEXT.md docs/harness-glossary.md && git commit -m "docs(blf-4): glossary FAIL-block count, fix round, guard demotion, untagged-tail criterion, trailer sweep (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"` (a fix round on another tier names that tier's model). Every commit of this unit carries `(blf-4)` as its subject scope.
- precondition: `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-4\): ' | wc -l` prints `0`; the tree is clean; each `before:` substring appears in its file exactly once (`/usr/bin/grep -cF -- '<before text>' <file>` prints `1`); the headings `**ladder exhaustion**:` and `**rubric v2**:` each appear exactly once at the start of a line of `CONTEXT.md`, and `**contract score**:` and `**Rulings ledger**:` once in `docs/harness-glossary.md`. Anything else: STOP.
- if a glossary test rejects the new text, STOP and report the failing check verbatim; do not reshape the entries. If a message scan blocks `-m`, commit with `git commit -F <file>`; never rephrase to dodge a gate.
- the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.

## Do NOT touch
- every other entry of `CONTEXT.md` (in particular **FAIL record**, **FAIL block**, **ladder exhaustion** apart from the entry inserted after it, **Contract-score guard**, **contract of record**); the scribe hint to amend **FAIL record** with the `tier:` line waits until blf-6 and blf-8 have landed
- `docs/harness-glossary.md` entries other than **contract score** and **Rulings ledger**
- `docs/adr/`, `agents/`, `templates/`, `tests/`, `bin/`, `.claude/`

## Acceptance criteria
1. run: `for t in 'FAIL-block count' 'fix round' 'guard demotion' 'untagged-tail criterion' 'trailer sweep'; do /usr/bin/grep -c "^\*\*$t\*\*" CONTEXT.md; done | /usr/bin/grep -cx 1`
   exit: 0
   stdout: `5`
   mutation: skip one of items 4 to 8; it prints `4`. It prints `0` at HEAD.
2. run: `node tests/context-glossary-links.test.js 2>&1 | tail -n 1`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: misspell `[[guard demotion]]` in item 3 as `[[guard demotions]]`; the link check names it as dangling and the last line changes. It already passes at HEAD and must stay green.
3. run: `node tests/ubiquitous-language.test.js 2>&1 | /usr/bin/grep -c 'passes all 4 structural/distinguishability checks'`
   exit: 0
   stdout: `1`
   mutation: set `UL_TEST_MUTATE=1`; the test exits non-zero and prints `0` (it checks skills/ubiquitous-language/SKILL.md, not the entries).
   proof: `UL_TEST_MUTATE=1 node tests/ubiquitous-language.test.js` exits non-zero. This criterion already passes at HEAD and must stay green.
4. run: `tr '\n' ' ' < docs/harness-glossary.md | tr -s ' ' | /usr/bin/grep -oE 'See \[\[rubric v2\]\]|Each \[\[guard demotion\]\] is recorded here' | wc -l`
   exit: 0
   stdout: `2`
   mutation: skip item 2 or item 3; it prints `1`. It prints `0` at HEAD.
5. run: `awk '/^\*\*rubric v2\*\*/,/^_Avoid_/' CONTEXT.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -cF 'See [[contract score]] for the v1'`
   exit: 0
   stdout: `1`
   mutation: skip item 1; it prints `0`, exit 1.
6. run: `awk '/^\*\*FAIL-block count\*\*/,/^_Avoid_/' CONTEXT.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -oE '\[\[(FAIL record|Escalation ladder|ladder exhaustion)\]\]' | sort | tr '\n' ' '`
   exit: 0
   stdout: `[[Escalation ladder]] [[FAIL record]] [[ladder exhaustion]]`
   mutation: skip item 4; nothing prints. It prints nothing at HEAD.
7. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-4\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show -U0 --format= "$c" -- CONTEXT.md | /usr/bin/grep -c '^@@'; git show -U0 --format= "$c" -- docs/harness-glossary.md | /usr/bin/grep -c '^@@'; done | tr '\n' ' '`
   exit: 0
   stdout: `3 2`
   mutation: also edit another entry; the first count rises above `3`. Skip item 1; it falls to `2`. The three hunks of `CONTEXT.md` are the rubric v2 pointer, the pair of entries after **ladder exhaustion** and the three entries after **rubric v2**; the two of `docs/harness-glossary.md` are items 2 and 3. With one unit commit the output is exactly the two counts.
8. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-4\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(blf-4\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
9. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-4\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
10. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-4\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- CONTEXT.md docs/harness-glossary.md | /usr/bin/grep -vcE '^[a-z]+\(blf-4\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
11. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-4\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | LC_ALL=C sort -u | tr '\n' ' '`
   exit: 0
   stdout: `CONTEXT.md docs/harness-glossary.md`
   mutation: touch one extra file in the unit's commit; the list gains that path.
12. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit blf-5

~~~~~~~markdown
Unit: blf-5

## Objective
A new test `tests/rubric-doc-parity.test.js`, registered in `tests/validate.sh`, fails when a doc's rubric row range (R1-R7, S1-S5, S1-S7) disagrees with the rows `bin/contract-score.js` reports; it reads the row keys from the scorer's JSON output and checks `CONTEXT.md` **rubric v2**, `docs/harness-glossary.md` **contract score** and `agents/task-master.md`.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-followups.md`, `## Unit blf-5`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `tests/rubric-doc-parity.test.js` (anchor: new file; edit 2 anchors on its first payload's last line)
- `tests/validate.sh` (anchor: line matching `echo "== agents/task-master.md worked examples score 7/7 under --rubric=v2 (Node, rgh-h2) =="`)

## Ordered edits
1. file: `tests/rubric-doc-parity.test.js`
   anchor: new file (create it with exactly this content; its last line begins `if (lead.v1 !== lead.v2) fail(`, and edit 2 appends the rest)
   indent: 0
   insert-after:
```
#!/usr/bin/env node
'use strict';

// Rubric row-range parity (blf-5): a doc that states a rubric row range (R1-R7, S1-S5, S1-S7) must
// agree with the rows bin/contract-score.js reports. The row keys come from the scorer's own JSON
// output (black box: the scorer exports nothing).

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const FIX = 'tests/fixtures/contract-score';

let failures = 0;
function fail(msg) {
  console.log(`FAIL ${msg}`);
  failures++;
}
function ok(msg) {
  console.log(`OK   ${msg}`);
}

// The contiguous range of row keys the scorer reports for one fixture, shape and rubric.
function scorerRange(fixture, shape, rubric) {
  const r = spawnSync('node', ['bin/contract-score.js', `${FIX}/${fixture}`, `--shape=${shape}`, `--rubric=${rubric}`], { cwd: REPO_ROOT, encoding: 'utf8' });
  let keys = [];
  try {
    keys = Object.keys(JSON.parse(r.stdout).rows);
  } catch (e) {
    fail(`scorer ${shape} ${rubric}: no JSON rows (exit ${r.status})`);
    return null;
  }
  const letter = keys[0][0];
  if (!keys.every((k, i) => k === `${letter}${i + 1}`)) {
    fail(`scorer ${shape} ${rubric}: rows are not contiguous: ${keys.join(',')}`);
    return null;
  }
  return `${letter}1-${letter}${keys.length}`;
}

const lead = { v1: scorerRange('v2-all-pass.md', 'lead', 'v1'), v2: scorerRange('v2-all-pass.md', 'lead', 'v2') };
const scribe = { v1: scorerRange('v2-scribe-all-pass.md', 'scribe', 'v1'), v2: scorerRange('v2-scribe-all-pass.md', 'scribe', 'v2') };
if (lead.v1 !== lead.v2) fail('lead rows differ between rubrics: v1 ' + lead.v1 + ', v2 ' + lead.v2);
```
2. file: `tests/rubric-doc-parity.test.js`
   anchor: line matching `if (lead.v1 !== lead.v2) fail('lead rows differ between rubrics: v1 '`
   indent: 0
   insert-after:
```

const flat = (text) => text.replace(/\s+/g, ' ');
const read = (rel) => fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');

// A glossary entry: its heading line down to the next blank line, whitespace flattened.
function entry(rel, heading) {
  const lines = read(rel).split('\n');
  const start = lines.findIndex((l) => l.startsWith(heading));
  if (start < 0) {
    fail(`${rel}: no entry ${heading}`);
    return '';
  }
  let end = start;
  while (end < lines.length && lines[end].trim() !== '') end++;
  return flat(lines.slice(start, end).join(' '));
}

const rangesIn = (text) => [...text.matchAll(/\b([RS])\d+-\1\d+\b/g)].map((m) => m[0]);

// sMode 'each': every S-range equals the v2 scribe range; 'set': the S-ranges are exactly {v1, v2}; null: S-ranges are not checked.
const docs = [
  { name: 'CONTEXT.md rubric v2 entry', text: entry('CONTEXT.md', '**rubric v2**:'), sMode: 'each' },
  { name: 'docs/harness-glossary.md contract score entry', text: entry('docs/harness-glossary.md', '**contract score**:'), sMode: 'set' },
  { name: 'agents/task-master.md', text: flat(read('agents/task-master.md')), sMode: null },
];

for (const doc of docs) {
  const found = rangesIn(doc.text);
  if (found.length === 0) {
    fail(`${doc.name}: states no row range`);
    continue;
  }
  const bad = [];
  for (const r of found.filter((x) => x[0] === 'R')) {
    if (r !== lead.v2) bad.push(`${r} (the scorer's lead rows are ${lead.v2})`);
  }
  const s = found.filter((x) => x[0] === 'S');
  if (doc.sMode === 'each') {
    for (const r of s) if (r !== scribe.v2) bad.push(`${r} (the scorer's v2 scribe rows are ${scribe.v2})`);
  } else if (doc.sMode === 'set') {
    const got = [...new Set(s)].sort().join(' ');
    const want = [...new Set([scribe.v1, scribe.v2])].sort().join(' ');
    if (got !== want) bad.push(`S-ranges {${got}} differ from the scorer's {${want}}`);
  }
  if (bad.length) fail(`${doc.name}: ${bad.join('; ')}`);
  else ok(`${doc.name}: ${[...new Set(found)].join(', ')}`);
}

if (failures) {
  console.log(`\n${failures} rubric-doc-parity check(s) FAILED.`);
  process.exit(1);
}
console.log('\nAll rubric-doc-parity checks passed.');
```
3. file: `tests/validate.sh`
   anchor: line matching `echo "== agents/task-master.md worked examples score 7/7 under --rubric=v2 (Node, rgh-h2) =="`
   indent: 0
   before:
```
echo "== agents/task-master.md worked examples score 7/7 under --rubric=v2 (Node, rgh-h2) =="
```
   after:
```
echo "== rubric row ranges in docs match bin/contract-score.js (Node, blf-5) =="
if node tests/rubric-doc-parity.test.js; then
  echo "OK   tests/rubric-doc-parity.test.js"
else
  echo "FAIL tests/rubric-doc-parity.test.js"
  fail=1
fi

echo
echo "== agents/task-master.md worked examples score 7/7 under --rubric=v2 (Node, rgh-h2) =="
```
4. command: `node tests/rubric-doc-parity.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
5. command: `git add tests/rubric-doc-parity.test.js tests/validate.sh && git commit -m "test(blf-5): rubric row ranges in docs match the scorer (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `bin/contract-score.js` (the scorer is unchanged; the test reads its JSON output only)
- `CONTEXT.md`, `docs/harness-glossary.md`, `agents/task-master.md` (the test reads them and writes none; unit blf-4 and unit blf-2 own the edits there)
- `tests/contract-score.test.js` (unit blf-1)
- `.claude/` (tests/ has no mirror; no `--update` and no version bump apply)

## Acceptance criteria
1. run: `node tests/rubric-doc-parity.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 1; the file is missing and it prints `exit=1`.
2. run: `node tests/rubric-doc-parity.test.js | /usr/bin/grep -c '^OK '`
   exit: 0
   stdout: `3`
   mutation: skip edit 2; the script ends after the scorer ranges and prints no `OK` line, so it prints `0`, exit 1.
3. run: `D=$(mktemp -d); git worktree add --detach -q "$D" HEAD; sed -i 's/on rows S1-S7/on rows S1-S6/' "$D/CONTEXT.md"; node "$D/tests/rubric-doc-parity.test.js" 2>&1 | /usr/bin/grep -c '^FAIL CONTEXT.md rubric v2 entry'; git worktree remove --force "$D"`
   exit: 0
   stdout: `1`
   mutation: skip edit 1 or 2; the test is missing or never reaches the doc check and it prints `0`. The scratch copy is the only file changed; the checked-out tree stays clean.
4. run: `D=$(mktemp -d); git worktree add --detach -q "$D" HEAD; sed -i 's/rows R1-R7:/rows R1-R6:/' "$D/agents/task-master.md"; node "$D/tests/rubric-doc-parity.test.js" 2>&1 | /usr/bin/grep -c '^FAIL agents/task-master.md'; git worktree remove --force "$D"`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; it prints `0`. This proves `agents/task-master.md` is read.
5. run: `D=$(mktemp -d); git worktree add --detach -q "$D" HEAD; sed -i 's/(R1-R7 lead, S1-S5 scribe)/(R1-R7 lead, S1-S4 scribe)/' "$D/docs/harness-glossary.md"; node "$D/tests/rubric-doc-parity.test.js" 2>&1 | /usr/bin/grep -c '^FAIL docs/harness-glossary.md contract score entry'; git worktree remove --force "$D"`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; it prints `0`. This proves the S-range set check on the contract score entry.
6. run: `/usr/bin/grep -c 'node tests/rubric-doc-parity.test.js' tests/validate.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; it prints `0`, exit 1.
7. run: `bash -n tests/validate.sh && echo syntax-ok`
   exit: 0
   stdout: `syntax-ok`
   mutation: delete the `fi` line of the new block; bash reports a syntax error and prints nothing, exit 2. It already passes at HEAD and must stay green.
8. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-5\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(blf-5\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
9. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-5\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
10. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-5\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- tests/rubric-doc-parity.test.js tests/validate.sh | /usr/bin/grep -vcE '^[a-z]+\(blf-5\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
11. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-5\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | LC_ALL=C sort -u | tr '\n' ' '`
   exit: 0
   stdout: `tests/rubric-doc-parity.test.js tests/validate.sh`
   mutation: touch one extra file in the unit's commit; the list gains that path.
12. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-5\): ' | wc -l` prints `0`, and `test -e tests/rubric-doc-parity.test.js && echo exists` prints nothing. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:` other than `new file`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: yes tests/rubric-doc-parity.test.js (the new test is the deliverable; criteria 3 to 5 are its mutation proofs, each red when a doc range is changed in a scratch copy)
blast-radius: bin/contract-score.js:380, CONTEXT.md:426, docs/harness-glossary.md:665, agents/task-master.md:140, tests/validate.sh:1225
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 2's payload begins with one empty line, which is part of the text. Edit 1 creates the file and ends with the `if (lead.v1 !== lead.v2)` line; edit 2 inserts its payload directly after that line.
note: the test passes at HEAD: all three docs agree with the scorer today (spec F8), so it is proven by mutation (criteria 3 to 5), not by a red run.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blf-5)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 625ab2b; grep-derived, not graph-derived).
commit-message: test(blf-5): rubric row ranges in docs match the scorer (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blf-5 (#529)
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
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit blf-6

~~~~~~~markdown
Unit: blf-6

## Objective
`agents/reviewer.md` and `templates/persona-protocol.md` (FAIL record; Continuing after a FAIL) say a FAIL block's second line is `tier: <haiku|sonnet|opus|unknown>`, the tier the failed attempt ran on, copied from the reviewer dispatch's `Implementer tier:` line (`unknown` when there is none) and never read by the Escalation ladder. Version 0.31.152; mirrors refreshed.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-followups.md`, `## Unit blf-6`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `agents/reviewer.md` (anchor: line matching `followed by the same defect list`)
- `templates/persona-protocol.md` (anchors: line matching `followed by the defect list from the verdict, verbatim. The record` and line matching `then the defect list verbatim) is what`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.151",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `agents/reviewer.md`
   anchor: line matching `followed by the same defect list`
   indent: 2
   before:
```
  `FAIL <task-id> <UTC ISO-8601 timestamp>`, followed by the same defect list
```
   after:
```
  `FAIL <task-id> <UTC ISO-8601 timestamp>`, its second line exactly `tier: <t>`,
  where `<t>` is the dispatch's `Implementer tier:` value (`haiku`, `sonnet` or
  `opus`), or `unknown` when the dispatch has no such line, followed by the
  same defect list
```
2. file: `templates/persona-protocol.md`
   anchor: line matching `followed by the defect list from the verdict, verbatim. The record`
   indent: 0
   before:
```
(both orchestration modes) — first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`,
followed by the defect list from the verdict, verbatim. The record
```
   after:
```
(both orchestration modes) — first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`,
second line `tier: <haiku|sonnet|opus|unknown>`, the tier the failed attempt ran on,
copied from the reviewer dispatch's `Implementer tier:` line (the Escalation
ladder never reads it), followed by the defect list from the verdict, verbatim. The record
```
3. file: `templates/persona-protocol.md`
   anchor: line matching `then the defect list verbatim) is what`
   indent: 0
   before:
```
<task-id> <UTC ISO-8601 timestamp>`, then the defect list verbatim) is what
```
   after:
```
<task-id> <UTC ISO-8601 timestamp>`, then its `tier:` line and the defect list verbatim) is what
```
4. file: `.claude-plugin/plugin.json` (version 0.31.152)
   anchor: line matching `"version": "0.31.151",`
   before: `  "version": "0.31.151",`
   after: `  "version": "0.31.152",`
5. file: `package.json` (version 0.31.152)
   anchor: line matching `"version": "0.31.151",`
   before: `  "version": "0.31.151",`
   after: `  "version": "0.31.152",`
6. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**FAIL blocks name the failed attempt's tier (blf-6, 0.31.152).** `agents/reviewer.md` and `templates/persona-protocol.md` (FAIL record; Continuing after a FAIL): a FAIL block's second line is `tier: <haiku|sonnet|opus|unknown>`, the tier the failed attempt ran on, copied from the reviewer dispatch's `Implementer tier:` line (`unknown` when the dispatch has none, until `agents/orchestrator.md` sends it in blf-8). `bin/fail-count.sh` counts header lines only and no hook reads block content, so the Escalation ladder never reads it. Mirrors refreshed by `node bin/cli.js --update`.
```
7. command: `bash tests/fail-marker-format-parity.test.sh > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
8. command: `node bin/cli.js --update`
   expect: 0
9. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
10. command: `git add agents/reviewer.md templates/persona-protocol.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(blf-6): FAIL blocks name the failed attempt's tier (0.31.152) (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0
11. command: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `hooks/scripts/marker-write.sh` and every other file under `hooks/` (the `tier:` line passed as the first line of the `<detail>` argument needs no script change; hooks are the human-only items blc-h1..h4)
- `bin/fail-count.sh` (it counts `^FAIL <id> ` header lines only and stays unchanged)
- `agents/orchestrator.md` (unit blf-8) and the four adapter ports (unit blf-7)
- `templates/persona-protocol.md` lines other than the FAIL record sentence and the Continuing after a FAIL sentence (unit blf-3 already edited the ladder-exhaustion sentence)
- `.claude/` (mirrors are regenerated only by `node bin/cli.js --update`)

## Acceptance criteria
1. run: `tr '\n' ' ' < agents/reviewer.md | tr -s ' ' | /usr/bin/grep -cE 'its second line exactly .tier: <t>.'`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; it prints `0`, exit 1.
2. run: `tr '\n' ' ' < templates/persona-protocol.md | tr -s ' ' | /usr/bin/grep -cE 'second line .tier: <haiku[|]sonnet[|]opus[|]unknown>.'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; it prints `0`, exit 1.
3. run: `tr '\n' ' ' < templates/persona-protocol.md | tr -s ' ' | /usr/bin/grep -cE 'then its .tier:. line and the defect list verbatim'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; it prints `0`, exit 1.
4. run: `bash tests/fail-marker-format-parity.test.sh > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: a claim check; the second FAIL write path (`hooks/scripts/marker-write.sh FAIL <id> - <detail> <path>`) writes `<detail>` verbatim after the header, so a reviewer using it puts the `tier:` line first in `<detail>` and no hook changes. It already passes at HEAD and must stay green; to prove it is not vacuous, delete a `FAIL ` header line from the heredoc literal in a scratch copy of the test and it exits 1.
5. run: `tr '\n' ' ' < .claude/agents/reviewer.md | tr -s ' ' | /usr/bin/grep -cE 'its second line exactly .tier: <t>.'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8 (`node bin/cli.js --update`); the mirror keeps the old words and it prints `0`, exit 1.
6. run: `cat .claude-plugin/plugin.json package.json | /usr/bin/grep -c '"version": "0.31.152"'`
   exit: 0
   stdout: `2`
   mutation: skip edit 4 or 5; it prints `1`.
7. run: `/usr/bin/grep -cF '(blf-6, 0.31.152)' CHANGELOG.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; it prints `0`, exit 1.
8. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-6\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do bash hooks/scripts/version-stamp-check.sh "$c~1..$c"; done | /usr/bin/grep -vc '^version-stamp-check: ok touched: yes '`
   exit: 1
   stdout: `0`
   mutation: skip edit 4; the line reads `violation` and it prints `1`, exit 0 (the script exits 0 on a violation, so this gates on stdout).
9. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.152';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 5; it prints `version-sync: mismatch`, exit 1.
10. run: `node bin/cli.js --update --dry-run 2>&1 | /usr/bin/grep -E '^  ' | /usr/bin/grep -vc ': already current$'`
   exit: 1
   stdout: `0`
   mutation: skip edit 8; the mirrors are non-current and it prints a count above `0`, exit 0 (a stale scratch copy prints the lines `would be rewritten.` and `would be updated (no local edits detected)`). It prints `0` at HEAD and must stay `0`.
11. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-6\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(blf-6\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
12. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-6\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
13. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-6\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- agents/reviewer.md templates/persona-protocol.md | /usr/bin/grep -vcE '^[a-z]+\(blf-6\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time, before blf-8 lands: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
14. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-6\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | /usr/bin/grep -v '^\.claude/' | LC_ALL=C sort -u | tr '\n' ' '`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md agents/reviewer.md package.json templates/persona-protocol.md`
   mutation: touch one extra file in the unit's commit; the list gains that path.
15. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.151` (unit blf-3 has landed). Anything else: STOP; the orchestrator re-derives every version literal as HEAD version + 1 and rewrites this contract's version lines before dispatch (spec D8).
precondition: `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-6\): ' | wc -l` prints `0`, `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-3\): ' | wc -l` is at least `1` (the orchestrator confirms the blf-3 PASS marker before dispatch), the tree is clean, no other unit that runs `node bin/cli.js --update` is in flight, and no other unit is mid-review (spec R3: this unit changes the reviewer's FAIL write). Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edit of an agent file and a template (criteria 1 to 3 count phrases that are absent at HEAD; criterion 4 runs the existing format-parity test)
blast-radius: agents/reviewer.md:216, templates/persona-protocol.md:349, templates/persona-protocol.md:701, hooks/scripts/marker-write.sh:1, bin/fail-count.sh:1, tests/fail-marker-format-parity.test.sh:1
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 1's `after:` ends with the words `same defect list`, which continue on the next line of the file (`you return in your verdict, verbatim, ...`) exactly as before. Edit 2's `after:` last line ends with `The record`, which continues on the next line (`appends a block per FAIL verdict ...`) exactly as before.
note: a reviewer that writes the FAIL block through `hooks/scripts/marker-write.sh FAIL` puts the `tier:` line first in its `<detail>` argument; no script change is needed (spec F7). Until unit blf-8 lands the orchestrator sends no `Implementer tier:` line, so reviewers write `tier: unknown`; that is expected (spec R4).
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blf-6)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 625ab2b; grep-derived, not graph-derived).
commit-message: feat(blf-6): FAIL blocks name the failed attempt's tier (0.31.152) (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blf-6 (#529)
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

## Unit blf-7

~~~~~~~markdown
Unit: blf-7

## Objective
The four adapter ports of the reviewer's FAIL-record text (`adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md`, `adapters/cursor/rules/persona-protocol.mdc`, `adapters/codex/agents-md-fragment.md`) say a FAIL block's second line is `tier: <haiku|sonnet|opus|unknown>`, with `unknown` when the dispatch names no implementer tier. No version bump (no `agents/*.md` or `templates/*` file changes).

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-followups.md`, `## Unit blf-7`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `adapters/codex/agents/reviewer.toml` (anchor: line matching `  first line exactly `)
- `adapters/cursor/agents/reviewer.md` (anchor: line matching `  first line exactly `)
- `adapters/cursor/rules/persona-protocol.mdc` (anchor: line matching `- first line exactly `)
- `adapters/codex/agents-md-fragment.md` (anchor: line matching `- first line exactly `)

## Ordered edits
1. file: `adapters/codex/agents/reviewer.toml`
   anchor: line matching `  first line exactly `
   indent: 2
   before:
```
  first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`, followed by
```
   after:
```
  first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`, then a second
  line `tier: <haiku|sonnet|opus|unknown>` (`unknown` when the dispatch names no
  implementer tier), followed by
```
2. file: `adapters/cursor/agents/reviewer.md`
   anchor: line matching `  first line exactly `
   indent: 2
   before:
```
  first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`, followed by
```
   after:
```
  first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`, then a second
  line `tier: <haiku|sonnet|opus|unknown>` (`unknown` when the dispatch names no
  implementer tier), followed by
```
3. file: `adapters/cursor/rules/persona-protocol.mdc`
   anchor: line matching `- first line exactly `
   indent: 0
   before:
```
- first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`, followed by the
```
   after:
```
- first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`, then a second
line `tier: <haiku|sonnet|opus|unknown>` (`unknown` when the dispatch names no
implementer tier), followed by the
```
4. file: `adapters/codex/agents-md-fragment.md`
   anchor: line matching `- first line exactly `
   indent: 0
   before:
```
- first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`, followed by the
```
   after:
```
- first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`, then a second
line `tier: <haiku|sonnet|opus|unknown>` (`unknown` when the dispatch names no
implementer tier), followed by the
```
5. command: `node tests/adapter-protocol-parity.test.js > /dev/null 2>&1 && node tests/adapter-skill-parity.test.js > /dev/null 2>&1 && bash tests/fail-marker-format-parity.test.sh > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
6. command: `git add adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md adapters/cursor/rules/persona-protocol.mdc adapters/codex/agents-md-fragment.md && git commit -m "docs(blf-7): adapter ports name the FAIL block tier line (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/` and `templates/` (this unit changes no stamped file: no version bump, no CHANGELOG entry, no `node bin/cli.js --update`; units blf-6 and blf-8 own the Claude surfaces)
- `adapters/cursor/agents/lead-programmer.md` and `adapters/codex/agents/lead-programmer.toml` (unit blc-5, landed)
- `hooks/scripts/marker-write.sh` and every other file under `hooks/` (human-only items blc-h1..h4)
- `.claude/` (no mirror applies to the adapter ports)

## Acceptance criteria
1. run: `for f in adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md adapters/cursor/rules/persona-protocol.mdc adapters/codex/agents-md-fragment.md; do tr '\n' ' ' < $f | tr -s ' ' | /usr/bin/grep -cE 'second line .tier: <haiku[|]sonnet[|]opus[|]unknown>.'; done | /usr/bin/grep -cx 1`
   exit: 0
   stdout: `4`
   mutation: skip one of edits 1 to 4; it prints `3`. It prints `0` at HEAD.
2. run: `node tests/adapter-protocol-parity.test.js > /dev/null 2>&1 && node tests/adapter-skill-parity.test.js > /dev/null 2>&1 && bash tests/fail-marker-format-parity.test.sh > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: a claim check that the wording change leaves the port parity tests green; it already passes at HEAD and must stay green. proof: `node tests/adapter-protocol-parity.test.js` prints `OK   negative case: an absent-phrase present in the port is REJECTED`, so the test can fail.
3. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-7\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show -U0 --format= "$c" | /usr/bin/grep '^+' | /usr/bin/grep -v '^+++' | LC_ALL=C /usr/bin/grep -cP '[^\x00-\x7F]'; done | /usr/bin/grep -cvx 0`
   exit: 1
   stdout: `0`
   mutation: write an em dash in an inserted line of a port; the count of such commits becomes `1` and it exits 0 (the two reviewer ports keep ASCII hyphens in what this unit adds).
4. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-7\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | /usr/bin/grep -cE '^(agents|templates|\.claude-plugin|\.claude)/'`
   exit: 1
   stdout: `0`
   mutation: touch `agents/reviewer.md` in a unit commit; it prints `1` and exits 0. The loop covers each commit of the unit, so another unit's commit landed in between cannot disturb it.
5. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-7\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(blf-7\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
6. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-7\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
7. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-7\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md adapters/cursor/rules/persona-protocol.mdc adapters/codex/agents-md-fragment.md | /usr/bin/grep -vcE '^[a-z]+\(blf-7\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches a content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
8. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-7\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | LC_ALL=C sort -u | tr '\n' ' '`
   exit: 0
   stdout: `adapters/codex/agents-md-fragment.md adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md adapters/cursor/rules/persona-protocol.mdc`
   mutation: touch one extra file in the unit's commit; the list gains that path.
9. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-7\): ' | wc -l` prints `0`, `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-6\): ' | wc -l` is at least `1` (the orchestrator confirms the blf-6 PASS marker before dispatch: this unit reuses blf-6's wording), and the tree is clean. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edit of four adapter ports (criterion 1 counts a phrase that is absent at HEAD; criterion 2 runs the existing parity tests)
blast-radius: adapters/codex/agents/reviewer.toml:84, adapters/cursor/agents/reviewer.md:81, adapters/cursor/rules/persona-protocol.mdc:130, adapters/codex/agents-md-fragment.md:123, tests/adapter-protocol-parity.test.js:1
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Each `after:` ends with the words `followed by` (the two `.mdc` and fragment ones with `followed by the`), which continue on the next line of the file exactly as before.
note: this unit may run in a worktree in parallel with units blf-1, blf-4 and blf-5 (file-disjoint), but only after blf-6 has landed; it bumps nothing. Criterion 4 is written per commit of the unit, so it holds even if another unit's commit lands between this unit's commits.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blf-7)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 625ab2b; grep-derived, not graph-derived).
commit-message: docs(blf-7): adapter ports name the FAIL block tier line (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blf-7 (#529)
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
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~~~

## Unit blf-8

~~~~~~~markdown
Unit: blf-8

## Objective
`agents/orchestrator.md` says a reviewer dispatch's second line is `Implementer tier: <t>` (the `model` the unit's latest implementer dispatch ran on), and that a FAIL block's `tier:` line is for the human reader and never read by the Escalation ladder. Version 0.31.153; mirrors refreshed.

## Retrieval
Plan file: `docs/plans/2026-10-09-backlog-followups.md`, `## Unit blf-8`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `agents/orchestrator.md` (anchors: line matching `   ≤64 chars.` and line matching `wrote a block is never needed. Fail closed: if n cannot be read (the grep`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.152",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `agents/orchestrator.md`
   anchor: line matching `   ≤64 chars.`
   indent: 3
   before:
```
   ≤64 chars.
```
   after:
```
   ≤64 chars. A reviewer dispatch's second line is `Implementer tier: <t>`: the
   `model` the unit's latest implementer dispatch ran on.
```
2. file: `agents/orchestrator.md`
   anchor: line matching `wrote a block is never needed. Fail closed: if n cannot be read (the grep`
   indent: 0
   before:
```
wrote a block is never needed. Fail closed: if n cannot be read (the grep
```
   after:
```
wrote a block is never needed (a block's `tier:` line is for the human reader;
the ladder never reads it). Fail closed: if n cannot be read (the grep
```
3. file: `.claude-plugin/plugin.json` (version 0.31.153)
   anchor: line matching `"version": "0.31.152",`
   before: `  "version": "0.31.152",`
   after: `  "version": "0.31.153",`
4. file: `package.json` (version 0.31.153)
   anchor: line matching `"version": "0.31.152",`
   before: `  "version": "0.31.152",`
   after: `  "version": "0.31.153",`
5. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Reviewer dispatch names the implementer tier (blf-8, 0.31.153).** `agents/orchestrator.md` (Dispatch hygiene rule 3): a reviewer dispatch's second line is `Implementer tier: <t>`, the `model` the unit's latest implementer dispatch ran on; the reviewer copies it into the `tier:` line of a FAIL block (`unknown` when the line is missing: agent-teams, manual dispatch, the ports). The Escalation ladder text now says a block's `tier:` line is for the human reader and the ladder never reads it. Mirrors refreshed by `node bin/cli.js --update`.
```
6. command: `node tests/writer-tier-consistency.test.js > /dev/null 2>&1; echo exit=$?`
   expect: 0
   stdout: `exit=0`
7. command: `node bin/cli.js --update`
   expect: 0
8. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
9. command: `git add agents/orchestrator.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(blf-8): reviewer dispatch names the implementer tier (0.31.153) (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0
10. command: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `hooks/scripts/dispatch-hygiene.sh` and every other file under `hooks/` (it reads only the `Unit:` first line; the second line is ignored by it; hooks are the human-only items blc-h1..h4)
- `commands/start-feature-team.md` (the agent-teams team-lead dispatch stays as is: the `unknown` fallback covers it, spec out of scope)
- `agents/reviewer.md`, `templates/persona-protocol.md` (unit blf-6) and the adapter ports (unit blf-7)
- `.claude/` (mirrors are regenerated only by `node bin/cli.js --update`)

## Acceptance criteria
1. run: `tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -cE "A reviewer dispatch's second line is .Implementer tier: <t>."`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; it prints `0`, exit 1.
2. run: `tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -cF 'the ladder never reads it)'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; it prints `0`, exit 1.
3. run: `node tests/writer-tier-consistency.test.js > /dev/null 2>&1; echo exit=$?`
   exit: 0
   stdout: `exit=0`
   mutation: delete the `**Escalation ladder.**` sentence from `agents/orchestrator.md` in a scratch copy; the AC-D7 check fails and it prints `exit=1`. It already passes at HEAD and must stay green.
4. run: `tr '\n' ' ' < .claude/agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -cE "A reviewer dispatch's second line is .Implementer tier: <t>."`
   exit: 0
   stdout: `1`
   mutation: skip edit 7 (`node bin/cli.js --update`); the mirror keeps the old words and it prints `0`, exit 1.
5. run: `cat .claude-plugin/plugin.json package.json | /usr/bin/grep -c '"version": "0.31.153"'`
   exit: 0
   stdout: `2`
   mutation: skip edit 3 or 4; it prints `1`.
6. run: `/usr/bin/grep -cF '(blf-8, 0.31.153)' CHANGELOG.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; it prints `0`, exit 1.
7. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-8\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do bash hooks/scripts/version-stamp-check.sh "$c~1..$c"; done | /usr/bin/grep -vc '^version-stamp-check: ok touched: yes '`
   exit: 1
   stdout: `0`
   mutation: skip edit 3; the line reads `violation` and it prints `1`, exit 0 (the script exits 0 on a violation, so this gates on stdout).
8. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.153';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 4; it prints `version-sync: mismatch`, exit 1.
9. run: `node bin/cli.js --update --dry-run 2>&1 | /usr/bin/grep -E '^  ' | /usr/bin/grep -vc ': already current$'`
   exit: 1
   stdout: `0`
   mutation: skip edit 7; the mirrors are non-current and it prints a count above `0`, exit 0 (a stale scratch copy prints the lines `would be rewritten.` and `would be updated (no local edits detected)`). It prints `0` at HEAD and must stay `0`.
10. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-8\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%s "$c"; done | /usr/bin/grep -vcE '^[a-z]+\(blf-8\): .+ \(#529\)$'`
   exit: 1
   stdout: `0`
   mutation: a unit commit whose subject lacks ` (#529)` makes it print `1` and exit 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
11. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-8\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | /usr/bin/grep -cx 0`
   exit: 1
   stdout: `0`
   mutation: drop one commit's trailer; it prints `1` and exits 0.
12. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-8\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; U=$(echo "$L" | head -1); git log --format=%s "$U"..HEAD -- agents/orchestrator.md | /usr/bin/grep -vcE '^[a-z]+\(blf-8\): '`
   exit: 1
   stdout: `0`
   mutation: run at review time: a later commit that touches the content file with the subject `fix: x` prints `1` and exits 0; before the unit's first commit it prints `no-unit-commit` and exits 3.
13. run: `L=$(git log --format='%H %s' | /usr/bin/grep -E '^[0-9a-f]+ [a-z]+\(blf-8\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git show --name-only --format= "$c"; done | /usr/bin/grep -v '^\.claude/' | LC_ALL=C sort -u | tr '\n' ' '`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md agents/orchestrator.md package.json`
   mutation: touch one extra file in the unit's commit; the list gains that path.
14. run: `git status --porcelain --untracked-files=no -- . ':(exclude).claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified or unstaged; it prints `1`. It already passes on the clean tree before the unit; it guards the commit.

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.152` (unit blf-6 has landed). Anything else: STOP; the orchestrator re-derives every version literal as HEAD version + 1 and rewrites this contract's version lines before dispatch (spec D8).
precondition: `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-8\): ' | wc -l` prints `0`, `git log --format=%H --extended-regexp --grep='^[a-z]+\(blf-6\): ' | wc -l` is at least `1` (the orchestrator confirms the blf-6 PASS marker before dispatch), the tree is clean, and no other unit that runs `node bin/cli.js --update` is in flight. Anything else: STOP.
precondition: FIRST, for every edit item that has an `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and its `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edit of an agent file (criteria 1 and 2 count phrases that are absent at HEAD; criterion 3 runs the existing writer-tier test)
blast-radius: agents/orchestrator.md:109, agents/orchestrator.md:476, tests/writer-tier-consistency.test.js:73, hooks/scripts/dispatch-hygiene.sh:1
note: payload fences sit at column 0 and hold the file's literal text, leading spaces included; `indent: N` is the smallest leading-space count of the payload's non-empty lines, so nothing is stripped or added. Edit 1's `before:` is the single line `   ≤64 chars.` with its three leading spaces and the unicode `≤`; keep both. Edit 5's payload begins with one empty line, which is part of the text, and its entry is ONE line.
note: the trailer names the implementing model; a fix round dispatched on another tier writes that tier's model name (for example `Claude Sonnet 5.5`).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
note: every commit of this unit, fix rounds included, carries `(blf-8)` as its subject scope.
explorer: not needed (provenance: grep and read by task-master at 625ab2b; grep-derived, not graph-derived).
commit-message: feat(blf-8): reviewer dispatch names the implementer tier (0.31.153) (#529)
trailer: Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
review-packet:
```
unit: blf-8 (#529)
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
