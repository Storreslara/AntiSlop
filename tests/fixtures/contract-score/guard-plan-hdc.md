## Unit hdc-1

~~~~~markdown
Unit: hdc-1

## Objective
`agents/orchestrator.md` defines ladder exhaustion as n reaching or exceeding the ladder length, starts a pre-cutover unit's ladder at the more capable of `sonnet` and the default tier, says the ladder depends on the cutover too, and says a `Suggested model` tag can only raise the ladder tier. `agents/task-master.md` says `haiku` is the default unless the project's `defaultImplementerModel` names another tier. Version 0.31.145, one commit, mirrors refreshed by `--update`.

## Retrieval
Plan file: `docs/plans/2026-10-08-haiku-default-cleanup.md`, `## Unit hdc-1`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `agents/orchestrator.md` (anchors below)
- `agents/task-master.md` (anchor below)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.144",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the 14 `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `agents/orchestrator.md`
   anchor: line matching `default (CONTEXT.md's **Writer tier** entry). Read the raw value yourself.`
   indent: 0
   before:
```
default (CONTEXT.md's **Writer tier** entry). Read the raw value yourself.
```
   after:
```
default (CONTEXT.md's **Writer tier** entry), except that the tag can only
raise the tier the **Escalation ladder** below gives, never lower it. Read the
raw value yourself.
```
2. file: `agents/orchestrator.md`
   anchor: line matching `attempt n+1 on the ladder's entry n+1. When n equals the ladder's length,`
   indent: 0
   before:
```
attempt n+1 on the ladder's entry n+1. When n equals the ladder's length,
that is **ladder exhaustion**: dispatch nothing and go to **At the 2-FAIL
cap**. The ladder depends only on n and the default tier, so a fresh session
```
   after:
```
attempt n+1 on the ladder's entry n+1. When n reaches or exceeds the ladder's
length, that is **ladder exhaustion**: dispatch nothing and go to **At the 2-FAIL
cap**. The ladder depends only on n, the default tier and whether any block
predates the **Haiku-default cutover** below, so a fresh session
```
3. file: `agents/orchestrator.md`
   anchor: line matching `such block uses the ladder that starts at `
   indent: 0
   before:
```
count alone cannot say which tier wrote them. Fail closed: a unit with any
such block uses the ladder that starts at `sonnet` (`sonnet`, `sonnet`,
`opus`, `opus`), whatever the default tier.
```
   after:
```
count alone cannot say which tier wrote them. Fail closed: a unit with any
such block uses the ladder that starts at the more capable of `sonnet` and the
default tier: `sonnet`, `sonnet`, `opus`, `opus` when the default tier is
`haiku` or `sonnet`, and `opus`, `opus` when it is `opus`.
```
4. file: `agents/task-master.md`
   anchor: line matching `the default for every unit, and a unit you judge security-sensitive,`
   indent: 2
   before:
```
  haiku|sonnet|opus`. Tagging is **reactive**, not predictive: `haiku` is
  the default for every unit, and a unit you judge security-sensitive,
```
   after:
```
  haiku|sonnet|opus`. Tagging is **reactive**, not predictive: `haiku` is
  the default for every unit unless this project's `defaultImplementerModel`
  names another tier (the orchestrator resolves it), and a unit you judge security-sensitive,
```
5. file: `.claude-plugin/plugin.json` (version 0.31.145)
   anchor: line matching `"version": "0.31.144",`
   before: `  "version": "0.31.144",`
   after: `  "version": "0.31.145",`
6. file: `package.json` (version 0.31.145)
   anchor: line matching `"version": "0.31.144",`
   before: `  "version": "0.31.144",`
   after: `  "version": "0.31.145",`
7. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Escalation ladder edge cases (hdc-1, 0.31.145).** `agents/orchestrator.md`: ladder exhaustion is n reaching or exceeding the ladder's length, so a FAIL after a human-directed re-dispatch still stops; a unit with a FAIL block older than the haiku-default cutover starts its ladder at the more capable of `sonnet` and the default tier, so an `opus`-default project keeps its `opus` ladder; the precedence sentence says a `Suggested model` tag can only raise the ladder tier. `agents/task-master.md`: `haiku` is the default unless the project's `defaultImplementerModel` names another tier.
```
8. command: `node bin/cli.js --update`
   expect: 0
9. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
10. command: `git add agents/orchestrator.md agents/task-master.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(hdc-1): escalation ladder edge cases and tag precedence (0.31.145) (#529)" -m "Co-Authored-By: Claude <your model name> <noreply@anthropic.com>"`
   expect: 0
   (write your own model's name in the trailer, e.g. `Claude Haiku 4.5`)
11. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `tests/` (every pinned substring is kept verbatim on purpose)
- `CONTEXT.md` and `docs/harness-glossary.md` (unit hdc-5)
- `docs/adr/0040-implementer-tier-haiku-default.md` (unit hdc-4)
- `templates/protocol-digest.md` (unit hdc-2)
- `adapters/` (the codex and cursor ports keep their per-unit cap)

## Acceptance criteria
1. run: `F=agents/orchestrator.md; for p in 'When n reaches or exceeds the ladder' 'When n equals the ladder' 'whatever the default tier' 'that starts at the more capable of' 'the tag can only raise the tier the **Escalation ladder** below gives, never lower it' 'predates the **Haiku-default cutover** below'; do tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 0 0 1 1 1 `
   mutation: skip edit 2; prints `0 1 0 1 1 0 `.
   proof: edits 1-4 applied in a scratch worktree of 5f91df7 by spec-master; the per-phrase counts were 1, 0, 0, 1, 1, 1. The skip-edit-2 variant was not run by spec-master.
2. run: `tr '\n' ' ' < agents/task-master.md | tr -s ' ' | /usr/bin/grep -oF -- 'names another tier (the orchestrator resolves it)' | wc -l`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; prints `0`.
3. run: `/usr/bin/grep -c 'When n reaches or exceeds the ladder' .claude/agents/orchestrator.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; prints `0`, exit 1.
4. run: `node tests/writer-tier-consistency.test.js > /dev/null && node tests/default-implementer-model.test.js > /dev/null && echo tier-tests-ok`
   exit: 0
   stdout: `tier-tests-ok`
   mutation: in edit 4 write `every unit starts on the default tier` instead of keeping the line pair "`haiku` is" / "the default for every unit"; AC-D5 fails, exit 1.
   proof: spec-master ran that wording in a scratch worktree; `writer-tier-consistency` printed `1 check(s) failed.` (AC-D5). With edit 4 as written both suites printed their all-passed line.
5. run: `bash hooks/scripts/version-stamp-check.sh "$(git log --format=%H -F --grep='(hdc-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-1)' | head -1)" | /usr/bin/grep -c '^version-stamp-check: ok'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; the line no longer reads `ok`, prints `0`, exit 1 (the script itself exits 0 on a violation, so this gates on stdout).
6. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.145';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 6; prints `version-sync: mismatch`, exit 1.
7. run: `diff <(git diff --name-only "$(git log --format=%H -F --grep='(hdc-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-1)' | head -1)" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' .claude-plugin/plugin.json CHANGELOG.md agents/orchestrator.md agents/task-master.md package.json | sort) && echo scope-1-ok`
   exit: 0
   stdout: `scope-1-ok`
   mutation: skip edit 7; exit 1.
8. run: `git diff --name-only "$(git log --format=%H -F --grep='(hdc-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-1)' | head -1)" -- .claude | wc -l`
   exit: 0
   stdout: `14`
   mutation: skip edit 8; prints `0`.
   proof: spec-master ran edits 1-6 and `node bin/cli.js --update` in a scratch worktree; `git status --porcelain -- .claude` listed 14 paths.
9. run: `git log --format=%s "$(git log --format=%H -F --grep='(hdc-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-1)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
10. run: `git log --format=%B "$(git log --format=%H -F --grep='(hdc-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-1)' | head -1)" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'`
   exit: 0
   stdout: `1`
   mutation: drop the trailer; prints `0`, exit 1.
11. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified; prints `1`.
12. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of `.claude/agents/orchestrator.md`; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run (about 11 minutes; run it in the main checkout).

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.144`. Anything else: STOP; the orchestrator re-derives every version literal as HEAD version + 1.
precondition: `git log --format=%H -F --grep='(hdc-1)' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and every `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edit; the checks are greps, two existing test suites that pin the kept substrings, and validate.sh mirror parity
blast-radius: agents/orchestrator.md:447, agents/orchestrator.md:470, agents/orchestrator.md:484, agents/task-master.md:105, tests/default-implementer-model.test.js:112, tests/writer-tier-consistency.test.js:54
note: `tests/default-implementer-model.test.js:112` pins "`Suggested model` tag > `defaultImplementerModel` config field > frontmatter default" and `tests/writer-tier-consistency.test.js:54` pins "`haiku` is\n  the default for every unit"; the after-texts keep both.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
explorer: not needed (provenance: grep and read by spec-master at 5f91df7, plus an explorer blast-radius pass).
commit-message: feat(hdc-1): escalation ladder edge cases and tag precedence (0.31.145) (#529)
review-packet:
```
unit: hdc-1 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criteria 1-12: <FILL: exit and stdout of each>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit hdc-6

~~~~~markdown
Unit: hdc-6

## Objective
Three glossary corrections: CONTEXT.md **default tier** says a `Suggested model` tag's floor is the ladder's entry, not the default tier (N3); CONTEXT.md **Haiku-default cutover** says ADR-0040's forward rule leaves out the `htd-` units (N2); `docs/harness-glossary.md` **terminal event** says the second FAIL is a stop for a one-tier `opus` ladder (N1). One commit, plus one per fix round after a FAIL.

## Retrieval
Plan file: `docs/plans/2026-10-08-haiku-default-cleanup.md`, `## Unit hdc-6`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Glossary edits
Each `before:` is one whole line (two leading spaces); replace that line with the `text:` lines.
1. file: `CONTEXT.md`
   heading: `**default tier**:`
   before:
```
  model` tag can raise a unit above it, never below it.
```
   text:
```
  model` tag can raise a unit's tier above its ladder's entry, never below
  that entry (the default tier, or for a unit with a FAIL block older than
  the [[Haiku-default cutover]], the more capable of `sonnet` and the default
  tier).
```
2. file: `CONTEXT.md`
   heading: `**Haiku-default cutover**:`
   before:
```
  rule counts units whose [[terminal event]] falls at or after it.
```
   text:
```
  rule counts units whose [[terminal event]] falls at or after it, except
  the `htd-` units of the haiku-default programme itself.
```
3. file: `docs/harness-glossary.md`
   heading: `**terminal event**:`
   before:
```
  ladder]] (ADR-0040) it ends the unit's first tier and is not a stop, and
```
   text:
```
  ladder]] (ADR-0040) it ends the unit's first tier and is not a stop unless
  that tier is the ladder's last (an `opus` default tier gives a one-tier
  `opus` ladder, where the second FAIL is ladder exhaustion), and
```

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #529 is the umbrella [spec] issue and no per-unit issue exists: close nothing, and never close #529
- task-id: hdc-6
- marker first line: "PASS hdc-6 "
- commit: one commit of the two files (plus one per fix round after a FAIL), subject `docs(hdc-6): glossary tag floor is the ladder entry, cutover htd exclusion, one-tier opus stop (#529)`, then a second `-m` argument holding exactly the line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; stage with `git add CONTEXT.md docs/harness-glossary.md`
- precondition: hdc-5 has PASSed (the orchestrator confirms the hdc-5 PASS marker before dispatch); `git log --format=%H -F --grep='(hdc-6)' | wc -l` prints `0`; each `before:` line matches exactly once as a whole line (`/usr/bin/grep -cxF -- '<before line>' <file>` prints `1`). Anything else: STOP and report.

## Do NOT touch
- every other entry in both files (in particular **Escalation ladder**, **ladder exhaustion**, **Implementer-tier ratchet**, **defaultImplementerModel**, **Forward-verification rule**, **Spend-neutrality**)
- `docs/adr/`, `agents/`, `tests/`, `scripts/`

## Acceptance criteria
1. run: `C=CONTEXT.md; for p in 'raise a unit above it, never below it' 'never below that entry' 'the more capable of `sonnet` and the default tier).' 'falls at or after it, except the `htd-` units of the haiku-default programme itself.'; do tr '\n' ' ' < $C | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `0 1 1 1 `
   mutation: skip edit 1; prints `1 0 0 1 `. Skip edit 2; prints `0 1 1 0 `.
   proof: spec-master applied the three edits in a scratch clone at 082ec3c: full `0 1 1 1 `, skip-1 `1 0 0 1 `, skip-2 `0 1 1 0 `, before any edit `1 0 0 0 `.
2. run: `H=docs/harness-glossary.md; for p in 'is not a stop, and' "is not a stop unless that tier is the ladder's last" 'first tier and is not a stop' 'where the second FAIL is ladder exhaustion), and'; do tr '\n' ' ' < $H | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `0 1 1 1 `
   mutation: skip edit 3; prints `1 0 1 0 `.
   proof: measured in the same scratch clone (full `0 1 1 1 `, skip-3 `1 0 1 0 `).
3. run: `node tests/context-glossary-links.test.js > /dev/null && node tests/ubiquitous-language.test.js > /dev/null && echo glossary-tests-ok`
   exit: 0
   stdout: `glossary-tests-ok`
   mutation: in edit 1 write `[[Haiku-default cutovers]]`; the dangling-link check fails, prints nothing, exit 1.
   proof: measured in the scratch clone (passes with the edits; the mutation fails the link test).
4. run: `node tests/writer-tier-consistency.test.js > /dev/null && echo wtc-ok`
   exit: 0
   stdout: `wtc-ok`
   mutation: change the Implementer-tier ratchet entry's two-attempts-per-tier phrase; AC-D5 fails, prints nothing, exit 1.
   proof: passes with the edits in the scratch clone; the mutation is as in hdc-5 criterion 4.
5. run: `git diff --name-only "$(git log --format=%H -F --grep='(hdc-6)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-6)' | head -1)" | sort | tr '\n' ' '`
   exit: 0
   stdout: `CONTEXT.md docs/harness-glossary.md `
   mutation: also commit an edit to the ADR; the list gains it.
6. run: `git log --format=%s "$(git log --format=%H -F --grep='(hdc-6)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-6)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
7. run: `R="$(git log --format=%H -F --grep='(hdc-6)' | tail -1)~1..$(git log --format=%H -F --grep='(hdc-6)' | head -1)"; for c in $(git rev-list "$R"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   check: every commit in the range carries exactly one trailer line (see the 2026-10-08 Ruling).
   mutation: drop one commit's trailer; prints `0 ` or `0 1 `.
   proof: shape proven on hdc-4 and hdc-5 (hdc-5 criterion 7).
8. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave CONTEXT.md unstaged at commit time; prints `1`.
9. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: add a `[[deliberately-missing-term]]` link to CONTEXT.md; prints `validate-exit=1`.
   proof: not run (about 11 minutes; run it in the main checkout).

## Pre-resolved context
blast-radius: CONTEXT.md:385, CONTEXT.md:395, docs/harness-glossary.md:3221 (line numbers at 082ec3c; anchor on the `before:` text, not the number)
note: edit 3 keeps the phrase `first tier and is not a stop`, so hdc-5 criterion 2 still prints `0 1 1 ` afterwards.
note: the tag-floor wording mirrors `agents/orchestrator.md` ("never a tier cheaper than the ladder's entry"); do not edit the orchestrator.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap. If the glossary tests reject the new text, STOP and report the failing check verbatim; do not reshape the entries.
~~~~~
