Unit: rfp-u7b

## Objective
Clear the reviewer-text advisory notes left by the rfp-u6a and rfp-u6c reviews (plan Step 7, items 4 to 6). It is
the only Step 7 unit that touches a version-stamped path, so it alone bumps the version, adds a CHANGELOG entry
and runs `node bin/cli.js --update`.
- **Item 4** (rfp-u6c PASS note): the Refutation pass bullet of `agents/reviewer.md` does not say where REFUTED
  defects go when none stands, one or more is UNCERTAIN, and the verdict is INSUFFICIENT-CONTEXT. The bullet
  now says they go, with their reasons, in the `refutation` advisory section, as in a FAIL. That is the rule the
  bullet already gives for a mixed FAIL, and the Verdict bullet already lets advisory sections follow any
  verdict line. No `templates/` file and no port carries the Refutation pass bullet.
- **Item 5** (rfp-u6a PASS note; also unit 124's untagged note "final message is ONLY the verdict vs the
  required trailing STATUS line"): the Verdict bullet ends a FAIL with "and nothing more", yet advisory sections
  and the protocol's STATUS line follow it. The FAIL now ends "and nothing more in the FAIL block", and one
  sentence after the advisory-section order says that each "nothing else" or "nothing more" bounds the verdict
  block itself, so those sections and the STATUS line still follow it.
- **Item 6** (rfp-u6a PASS note): `tests/refutation-sample.test.sh` case (d) flattens the file before `grep -F`,
  so it passes when a doc splits a command across two lines. It now greps the file itself, so each command must
  sit whole on one line.
- `tests/persona-prose-pins.test.sh` pins the three new reviewer sentences in the source and its mirror.

Not in this unit: the codex and cursor ports' Verdict bullets (Open Question 10; they run no refutation pass).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Units and order", "Step 7").
This file is the contract of record. rfp-u7b shares no file with rfp-u7c, rfp-u7d or rfp-u7e, so the four may be
built at the same time. It is the only Step 7 unit that bumps the version, edits `CHANGELOG.md` or runs
`--update`. rfp-u7a is dispatched after this unit's PASS. One unit is mid-review at a time.

## Affected files
- `agents/reviewer.md` (anchor: line matching `settle each; on the resume, without a second pass, FAIL a defect you now`)
- `tests/refutation-sample.test.sh` (anchor: line matching `# (d) the persona source and its mirror ship exactly these three commands and the summary line`; mode stays 755)
- `tests/persona-prose-pins.test.sh` (anchor: line matching `hasnot "$f" '(file:line + how to trigger) and nothing more'`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md` (the reviewer body and every mirror's stamp line), `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
Edits 2 to 11 were generated from spec-master's tested scratch payload (a clone at b9bcdf92). Applied in order,
they reproduce it byte for byte. Use the Write/Edit tools for every file edit: the text of
`tests/refutation-sample.test.sh` names the reviewed-markers directory, so a Bash heredoc or `python3 -c` edit
of it is refused by `reviewed-path-gate.sh` (see Escalation).

1. command: `bash -c 'tr -s " \n" " " < agents/reviewer.md | grep -c "and nothing more — the orchestrator/team-lead routes them back to the lead-programmer"'`
   expect: 0, stdout `1` (rfp-u6a's Verdict text is on this branch). Stdout `0`: stop and report.

2. file: `agents/reviewer.md`
   anchor: line matching `more — the orchestrator/team-lead routes them back to the lead-programmer;`
   before:
~~~
  more — the orchestrator/team-lead routes them back to the lead-programmer;
~~~
   after:
~~~
  more in the FAIL block — the orchestrator/team-lead routes them back
  to the lead-programmer;
~~~

3. file: `agents/reviewer.md`
   anchor: line matching `and is never obscured.`
   before:
~~~
  and is never obscured.
~~~
   after:
~~~
  and is never obscured. Each "nothing else" or "nothing more" above bounds
  the verdict block itself: these advisory sections and the protocol's
  terminal STATUS line still follow it.
~~~

4. file: `agents/reviewer.md`
   anchor: line matching `settle each; on the resume, without a second pass, FAIL a defect you now`
   before:
~~~
  settle each; on the resume, without a second pass, FAIL a defect you now
~~~
   after:
~~~
  settle each, and the REFUTED ones and your reasons go in the
  `refutation` advisory section, as in a FAIL; on the resume, without a
  second pass, FAIL a defect you now
~~~

5. file: `tests/refutation-sample.test.sh`
   anchor: line matching `# (d) the persona source and its mirror ship exactly these three commands and the summary line`
   before:
~~~
# (d) the persona source and its mirror ship exactly these three commands and the summary line
for file in agents/milestone-auditor.md .claude/agents/milestone-auditor.md; do
  flat="$(tr -s ' \n' ' ' < "$root/$file")"
  miss=""
  for c in "$LIST" "$PREVENTED" "$SURVIVED" 'refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>'; do
    printf '%s' "$flat" | grep -qF -- "$c" || miss="$miss [$c]"
~~~
   after:
~~~
# (d) the persona source and its mirror ship exactly these three commands and the summary line, each whole on
# one line (rfp-u7b: the file is not flattened, so a command split across two lines is missing)
for file in agents/milestone-auditor.md .claude/agents/milestone-auditor.md; do
  miss=""
  for c in "$LIST" "$PREVENTED" "$SURVIVED" 'refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>'; do
    grep -qF -- "$c" "$root/$file" || miss="$miss [$c]"
~~~

6. file: `tests/persona-prose-pins.test.sh`
   anchor: line matching `` has "$f" '(file:line + how to trigger), then the `refutation:` line the Refutation pass below defines, and nothing more' ``
   before:
~~~
  has "$f" '(file:line + how to trigger), then the `refutation:` line the Refutation pass below defines, and nothing more'
~~~
   after:
~~~
  has "$f" '(file:line + how to trigger), then the `refutation:` line the Refutation pass below defines, and nothing more in the FAIL block'
~~~

7. file: `tests/persona-prose-pins.test.sh`
   anchor: line matching `hasnot "$f" '(file:line + how to trigger) and nothing more'`
   before:
~~~
  hasnot "$f" '(file:line + how to trigger) and nothing more'
~~~
   after:
~~~
  hasnot "$f" '(file:line + how to trigger) and nothing more'
  has "$f" 'Each "nothing else" or "nothing more" above bounds the verdict block itself: these advisory sections and the'
  has "$f" 'If none stands and one or more is UNCERTAIN, return INSUFFICIENT-CONTEXT, its `missing:` naming the evidence that would settle each, and the REFUTED ones and your reasons go in the `refutation` advisory section, as in a FAIL;'
~~~

8. command: `bash -c 'bash tests/persona-prose-pins.test.sh | grep -c "^FAIL"'`
   expect: stdout `3`. Before edit 11 the reviewer mirror still has the old text, so its three changed pins
   fail and the source's pass. This is the red step.

9. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0 (+1 on whatever is current at dispatch; it is 0.31.224 at b9bcdf92, so 0.31.225)

10. file: `CHANGELOG.md`
    anchor: line matching `## [Unreleased]`
    indent: 0
    insert-after:
~~~

**The reviewer's verdict bullets say where the advisory sections go and where an INSUFFICIENT-CONTEXT's refuted defects go (rfp-u7b, VERSION).** `agents/reviewer.md`'s Verdict bullet now ends a FAIL with "nothing more in the FAIL block" and says that each "nothing else" or "nothing more" bounds the verdict block itself, so the advisory sections and the terminal STATUS line still follow it. The Refutation pass bullet now says that when none stands and one or more is UNCERTAIN, the INSUFFICIENT-CONTEXT verdict puts the REFUTED defects and their reasons in the `refutation` advisory section, as a FAIL does. `tests/refutation-sample.test.sh` case (d) checks each command on one unflattened line, so a command split across two lines no longer passes. Spec: `docs/plans/2026-10-27-refutation-pass.md` (Step 7).
~~~
    Replace `VERSION` with the version edit 9 wrote.

11. command: `node bin/cli.js --update`
    expect: 0

12. command: `bash -c 'for t in persona-prose-pins refutation-sample prompt-diet-pins fail-record-refutation; do bash tests/$t.test.sh >/dev/null || echo "red $t"; done; for t in protocol-cross-references rubric-doc-parity contract-examples effort-tier-consistency writer-tier-consistency context-glossary-links; do node tests/$t.test.js >/dev/null || echo "red $t"; done; echo done'`
    expect: 0, stdout `done` only

13. command: `git add agents/reviewer.md tests/refutation-sample.test.sh tests/persona-prose-pins.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude ':(exclude).claude/agent-memory' && git commit -m "fix(rfp-u7b): verdict bullets bound the verdict block; INSUFFICIENT-CONTEXT keeps refuted defects in the advisory section; refutation-sample checks whole lines"`
    expect: 0
    Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it,
    unless it is one of rfp-u7c's, rfp-u7d's or rfp-u7e's files (those units may be in progress in the same
    tree): leave those unstaged. Every later commit of this unit (a fix round) that touches `agents/` repeats
    edits 9 to 11 in that same commit, adds its own CHANGELOG line naming its own version, and keeps
    `(rfp-u7b): ` in its subject.

## Do NOT touch
- `adapters/` (Open Question 10; criterion 4)
- `templates/`, and `agents/` other than `agents/reviewer.md` (criterion 4)
- `hooks/`, `bin/`, `scripts/`, `eval/`, and every gate script (rfp-u7c, rfp-u7d and rfp-u7e own the eval fixes; criterion 4)
- `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/` (rfp-u7a owns the glossary; criterion 4)
- `.claude/` mirrors by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'out=$(bash tests/persona-prose-pins.test.sh); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") rc=$rc"'`
   exit: 0
   stdout: `fails=0 rc=0`
   mutation: skip edit 11 (`--update`); the reviewer mirror's three changed pins fail, so stdout is `fails=3 rc=1` (spec-master ran it on the scratch clone). Revert edit 4 in the source alone after the commit; its INSUFFICIENT-CONTEXT pin fails: `fails=1 rc=1` (spec-master ran it; `--update` then keeps the mirror, because it skips when the version already matches).
2. run: `bash -c 'bash tests/refutation-sample.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: in a scratch clone, break the `grep -rl '^NOTE\[code]: refuted: '` command of `agents/milestone-auditor.md` onto two lines before its `--include`; case (d) fails for the source, so stdout is `1`. With the case (d) of b9bcdf92 the same mutant prints `0`, which is the vacuity edit 5 removes (spec-master ran both).
3. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u7b): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for f in agents/reviewer.md:8:3 tests/refutation-sample.test.sh:3:3; do p=${f%%:*}; r=${f#*:}; ma=${r%%:*}; mr=${r#*:}; a=0; d=0; for c in $cs; do set -- $(git show --numstat --format= "$c" -- "$p"); a=$((a+${1:-0})); d=$((d+${2:-0})); done; if [ "$a" = "$ma" ] && [ "$d" = "$mr" ]; then echo "ok $p"; else echo "off $p +$a -$d"; fi; done | paste -sd " " -'`
   exit: 0
   stdout: `ok agents/reviewer.md ok tests/refutation-sample.test.sh`
   mutation: also reword another bullet of `agents/reviewer.md`; stdout starts `off agents/reviewer.md`. spec-master's scratch commit measured +8/-3 and +3/-3. With no `(rfp-u7b): ` commit, stdout is `no-commits`, exit 1.
4. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u7b): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -v "^\.claude/" | grep -vxE "agents/reviewer\.md|tests/(persona-prose-pins|refutation-sample)\.test\.sh|\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: commit an `adapters/codex/agents/reviewer.toml` edit under a `(rfp-u7b): ` subject; stdout is `1`.
5. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u7b): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; bad=0; t=no; for c in $cs; do o=$(bash hooks/scripts/version-stamp-check.sh "$c^..$c"); case "$o" in "version-stamp-check: ok touched: yes"*) t=yes ;; "version-stamp-check: ok "*) ;; *) bad=$((bad+1)) ;; esac; done; echo "bad=$bad touched=$t"'`
   exit: 0
   stdout: `bad=0 touched=yes`
   mutation: a fix-round commit `fix(rfp-u7b): …` that edits `agents/reviewer.md` without edit 9; stdout is `bad=1 touched=yes`. spec-master's scratch commit printed `version-stamp-check: ok touched: yes old: 0.31.224 new: 0.31.225 offenders: -`.
6. run: `bash -c 'git status --porcelain --untracked-files=no -- agents/reviewer.md tests/persona-prose-pins.test.sh tests/refutation-sample.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md .claude ":!.claude/agent-memory" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: leave `.claude/agents/reviewer.md` unstaged after edit 11; stdout is `1`. The pathspec is this unit's own files, so another Step 7 unit's work in progress in the same tree does not count.
7. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/refutation-sample.test.sh`; validate.sh reports `FAIL tests/refutation-sample.test.sh` (`tests/validate.sh:869-874`) and stdout is `1`. Run this criterion when no other Step 7 unit has uncommitted edits in the same tree, or in this unit's own worktree: validate.sh runs every suite.

## Pre-resolved context
- spec-master applied edits 2 to 11 to a clone of b9bcdf92 and committed them under a `(rfp-u7b): ` subject:
  every anchor occurs once; `--update` changed exactly the generated paths above; edit 12 printed `done`;
  criteria 1 to 6 and their mutations behave as stated; with rfp-u7c, rfp-u7d, rfp-u7e and rfp-u7a also
  committed on that clone, `ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh` exited 0 (OK=3442 FAIL=0 WARN=2,
  about 6 minutes).
- The validate wrapper needs no edit: it already runs both suites (`tests/validate.sh:869-874` and `:1625-1630`).
- The rfp-u6c criterion 3 source phrase "the REFUTED ones and your reasons go in the refutation advisory
  section" now occurs twice in `agents/reviewer.md` (the mixed FAIL and the new INSUFFICIENT-CONTEXT clause);
  its `grep -qF` still matches. rfp-u6a's prose pin is replaced by edit 6's longer phrase, which contains it.
- The milestone-auditor mirror changes only on its stamp line under `--update`, so case (d) reads the same
  command lines in the source and the mirror.
- Item 4's rule, chosen as the least change: the Verdict bullet already lets advisory sections follow any
  verdict line, and the Refutation pass bullet already sends REFUTED defects to the `refutation` section in a
  mixed FAIL. What happens to those REFUTED defects on the resume is Open Question 9, and this unit leaves the
  resume text as it is.
- `bin/contract-score.js --rubric=v2 --shape=lead` scores this file below 7, like rfp-u6a, so the
  contract-score guard dispatches it on `sonnet`.

## Escalation
If edit 1 prints `0`, do not start. If an anchor is not found exactly once, stop and report the current text.
If the `Write` or `Edit` tool is refused for `tests/refutation-sample.test.sh`, do not fall back to a Bash
heredoc: report it and wait. If `node bin/cli.js --update` refuses, quote its message and stop. If a gate
blocks a command, report it and wait. Anything outside "Affected files" goes in your report as a proposal.
