Unit: rfp-u6a

## Objective
Clear two persona-text advisory notes from the refutation-pass reviews (plan Step 6, items 1 and 2).
- `agents/reviewer.md`, Verdict bullet: a FAIL is "the PASS/FAIL line, then a bare list of specific
  reproducible defects (file:line + how to trigger) and nothing more", which contradicts the Refutation pass
  bullet of the same file (it ends the FAIL with a `refutation:` line, and the plan's Safety section puts that
  line in the verdict text under review gating off). The bullet gains "then the `refutation:` line the
  Refutation pass below defines" before "and nothing more" (rfp-u3 PASS note).
- `agents/milestone-auditor.md`, Refutation sample bullet: the list and prevented-count greps use `-F` with no
  line-start anchor, so a `.pass` note that quotes `NOTE[code]: refuted: ` mid-line is sampled and counted as a
  prevented FAIL. Both are anchored at line start (`grep -rn '^NOTE\[code]: refuted: '` and
  `grep -rl '^NOTE\[code]: refuted: '`), as the survived-count grep already is. The bullet also says, in one
  sentence, that an undecidable refutation counts toward `sampled`, never toward `held` (rfp-u4 PASS notes).
- `tests/refutation-sample.test.sh` ships the anchored commands and gains a mid-line decoy in `m2.pass`;
  `tests/persona-prose-pins.test.sh` pins both new sentences in the sources and their mirrors.

Not in this unit: the codex and cursor ports' Verdict bullets carry the same "bare list ... and nothing more"
sentence, but they run no refutation pass and put `refutation: skipped=no-subagent` only in the FAIL record,
after "the same defect list you return in your verdict", so their two bullets do not contradict each other.
They stay unchanged (plan Step 6, dropped items). No `templates/` file carries the sentence.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Units and order", "Step 6").
This file is the contract of record. rfp-u6a, rfp-u6b and rfp-u6c share no file and may go in any order; one
unit is mid-review at a time.

## Affected files
- `agents/reviewer.md` (anchor: line matching `specific reproducible defects (file:line + how to trigger) and nothing`)
- `agents/milestone-auditor.md` (anchor: line matching `- **Refutation sample.** The reviewer's refutation pass turns a FAIL into a`)
- `tests/refutation-sample.test.sh` (anchor: line matching `NOTE[code]: the wrap width is ragged`; mode stays 755)
- `tests/persona-prose-pins.test.sh` (anchor: line matching `if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md` (the reviewer and milestone-auditor bodies, every mirror's stamp line), `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
Edits 2 to 10 were generated from spec-master's tested scratch payload (a clone at 57ec2d70). Applied in
order, they reproduce it byte for byte. Use the Write/Edit tools for every file edit: the text of
`tests/refutation-sample.test.sh` names the reviewed-markers directory, so a Bash heredoc or `python3 -c`
edit of it is refused by `reviewed-path-gate.sh` (see Escalation).

1. command: `bash -c 'tr -s " \n" " " < agents/reviewer.md | grep -o "ending the FAIL block with .refutation: confirmed=" | wc -l | tr -d " "'`
   expect: 0, stdout `1` (rfp-u3's Refutation pass bullet is on this branch). Stdout `0`: stop and report.

2. file: `agents/reviewer.md`
   anchor: line matching `specific reproducible defects (file:line + how to trigger) and nothing`
   before:
~~~
  specific reproducible defects (file:line + how to trigger) and nothing
~~~
   after:
~~~
  specific reproducible defects (file:line + how to trigger), then the
  `refutation:` line the Refutation pass below defines, and nothing
~~~

3. file: `agents/milestone-auditor.md`
   anchor: line matching ``grep -rnF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | sort``
   before:
~~~
  `grep -rnF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | sort`
~~~
   after:
~~~
  `grep -rn '^NOTE\[code]: refuted: ' --include='*.pass' .claude/reviewed | sort`
~~~

4. file: `agents/milestone-auditor.md`
   anchor: line matching ``grep -rlF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | wc -l``
   before:
~~~
  `grep -rlF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | wc -l`
~~~
   after:
~~~
  `grep -rl '^NOTE\[code]: refuted: ' --include='*.pass' .claude/reviewed | wc -l`
~~~

5. file: `agents/milestone-auditor.md`
   anchor: line matching ``refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>`.`
   before:
~~~
  `refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>`.
  When `eligible` is 20 or more and `p` is under a tenth of it, add an
~~~
   after:
~~~
  `refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>`.
  `held` counts only the refutations you decided hold: one you cannot
  decide counts toward `sampled`, never toward `held`.
  When `eligible` is 20 or more and `p` is under a tenth of it, add an
~~~

6. file: `tests/refutation-sample.test.sh`
   anchor: line matching `# FAIL-block lines starting `refutation: confirmed=`), on a fixture with decoys, and`
   before:
~~~
# FAIL-block lines starting `refutation: confirmed=`), on a fixture with decoys, and
~~~
   after:
~~~
# FAIL-block lines starting `refutation: confirmed=`), on a fixture with decoys (rfp-u6a: a refuted note
# counts only at line start, never quoted mid-line), and
~~~

7. file: `tests/refutation-sample.test.sh`
   anchor: line matching `PREVENTED="grep -rlF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | wc -l"`
   before:
~~~
LIST="grep -rnF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | sort"
PREVENTED="grep -rlF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | wc -l"
~~~
   after:
~~~
LIST="grep -rn '^NOTE\\[code]: refuted: ' --include='*.pass' .claude/reviewed | sort"
PREVENTED="grep -rl '^NOTE\\[code]: refuted: ' --include='*.pass' .claude/reviewed | wc -l"
~~~

8. file: `tests/refutation-sample.test.sh`
   anchor: line matching `NOTE[code]: the wrap width is ragged`
   before:
~~~
NOTE[code]: the wrap width is ragged
EOF
~~~
   after:
~~~
NOTE[code]: the wrap width is ragged
NOTE[spec]: a mid-line decoy quoting the format NOTE[code]: refuted: D<n> <claim>
EOF
~~~

9. file: `tests/refutation-sample.test.sh`
   anchor: line matching `# (b) prevented FAILs: two .pass markers carry a refuted note (m1 counts once)`
   before:
~~~
# (b) prevented FAILs: two .pass markers carry a refuted note (m1 counts once)
~~~
   after:
~~~
# (b) prevented FAILs: two .pass markers carry a refuted note (m1 counts once; m2 only quotes one mid-line)
~~~

10. file: `tests/persona-prose-pins.test.sh`
   anchor: line matching `if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi`
   before:
~~~
done
if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi
~~~
   after:
~~~
done
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  has "$f" '(file:line + how to trigger), then the `refutation:` line the Refutation pass below defines, and nothing more'
  hasnot "$f" '(file:line + how to trigger) and nothing more'
done
for f in agents/milestone-auditor.md .claude/agents/milestone-auditor.md; do
  has "$f" 'one you cannot decide counts toward `sampled`, never toward `held`'
done
if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi
~~~
11. command: `bash -c 'bash tests/refutation-sample.test.sh | grep -c "^FAIL"'`
    expect: stdout `1`. Before edit 14 the mirror still ships the unanchored commands, so only the
    `.claude/agents/milestone-auditor.md` line of case (d) fails; cases (a) to (c) and the source's case (d)
    pass. This is the red step.
12. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
    expect: 0 (+1 on whatever is current at dispatch; it is 0.31.223 at 57ec2d70, so 0.31.224)
13. file: `CHANGELOG.md`
    anchor: line matching `## [Unreleased]`
    indent: 0
    insert-after:
~~~

**The reviewer's FAIL verdict and the milestone auditor's refutation sample agree with the refutation pass (rfp-u6a, VERSION).** `agents/reviewer.md`'s Verdict bullet now says a FAIL is the verdict line, the bare defect list, then the `refutation:` line, and nothing more (it said "and nothing more" right after the list, which contradicted the Refutation pass bullet). `agents/milestone-auditor.md`'s two refuted-note greps are anchored at line start, so a `.pass` note that quotes the `NOTE[code]: refuted:` prefix mid-line is neither sampled nor counted as a prevented FAIL, and the bullet says an undecidable refutation counts toward `sampled`, never toward `held`. `tests/refutation-sample.test.sh` gains a mid-line decoy. Spec: `docs/plans/2026-10-27-refutation-pass.md` (Step 6).
~~~
    Replace `VERSION` with the version edit 12 wrote.
14. command: `node bin/cli.js --update`
    expect: 0
15. command: `bash -c 'for t in persona-prose-pins refutation-sample prompt-diet-pins fail-record-refutation; do bash tests/$t.test.sh >/dev/null || echo "red $t"; done; for t in protocol-cross-references rubric-doc-parity contract-examples effort-tier-consistency writer-tier-consistency; do node tests/$t.test.js >/dev/null || echo "red $t"; done; echo done'`
    expect: 0, stdout `done` only
16. command: `git add agents/reviewer.md agents/milestone-auditor.md tests/refutation-sample.test.sh tests/persona-prose-pins.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude ':(exclude).claude/agent-memory' && git commit -m "fix(rfp-u6a): the reviewer's FAIL verdict names the refutation line; the refutation sample counts line-start notes only"`
    expect: 0
    Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it.
    Every later commit of this unit (a fix round) that touches `agents/` repeats edits 12 to 14 in that same
    commit, adds its own CHANGELOG line naming its own version, and keeps `(rfp-u6a): ` in its subject.

## Do NOT touch
- `adapters/` (the ports' bullets do not contradict each other; criterion 4)
- `templates/`, `agents/` other than the two files above (criterion 4)
- `hooks/`, `bin/`, `scripts/`, `eval/` (rfp-u6b owns the eval fixes; criterion 4)
- `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/` (rfp-u6c owns the glossary; criterion 4)
- `.claude/` mirrors by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'out=$(bash tests/persona-prose-pins.test.sh); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") rc=$rc"'`
   exit: 0
   stdout: `fails=0 rc=0`
   mutation: skip edit 14 (`--update`); the reviewer mirror's `has` and `hasnot` pins and the milestone-auditor mirror's pin fail, so stdout is `fails=3 rc=1` (spec-master ran it on the scratch clone).
2. run: `bash -c 'bash tests/refutation-sample.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: put back `grep -rnF 'NOTE[code]: refuted: '` and `grep -rlF 'NOTE[code]: refuted: '` in both the test and `agents/milestone-auditor.md`; the mid-line decoy is listed and counted, case (a) fails and case (b) prints `prevented=[3]`, so stdout is `1` (spec-master ran it). Without edit 8's decoy, the unanchored commands pass cases (a) and (b): the decoy is what makes the anchor load-bearing.
3. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u6a): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for f in agents/reviewer.md:2:1 agents/milestone-auditor.md:4:2; do p=${f%%:*}; r=${f#*:}; ma=${r%%:*}; mr=${r#*:}; a=0; d=0; for c in $cs; do set -- $(git show --numstat --format= "$c" -- "$p"); a=$((a+${1:-0})); d=$((d+${2:-0})); done; if [ "$a" = "$ma" ] && [ "$d" = "$mr" ]; then echo "ok $p"; else echo "off $p +$a -$d"; fi; done | paste -sd " " -'`
   exit: 0
   stdout: `ok agents/reviewer.md ok agents/milestone-auditor.md`
   mutation: also reword another bullet of `agents/reviewer.md`; stdout starts `off agents/reviewer.md`. spec-master's scratch commit measured +2/-1 and +4/-2. With no `(rfp-u6a): ` commit, stdout is `no-commits`, exit 1.
4. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u6a): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -v "^\.claude/" | grep -vxE "agents/(reviewer|milestone-auditor)\.md|tests/(persona-prose-pins|refutation-sample)\.test\.sh|\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: commit an `adapters/codex/agents/reviewer.toml` edit under a `(rfp-u6a): ` subject; stdout is `1`.
5. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u6a): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; bad=0; t=no; for c in $cs; do o=$(bash hooks/scripts/version-stamp-check.sh "$c^..$c"); case "$o" in "version-stamp-check: ok touched: yes"*) t=yes ;; "version-stamp-check: ok "*) ;; *) bad=$((bad+1)) ;; esac; done; echo "bad=$bad touched=$t"'`
   exit: 0
   stdout: `bad=0 touched=yes`
   mutation: a fix-round commit `fix(rfp-u6a): …` that edits `agents/reviewer.md` without edit 12; stdout is `bad=1 touched=yes`. spec-master's scratch commit printed `version-stamp-check: ok touched: yes old: 0.31.223 new: 0.31.224 offenders: -`.
6. run: `bash -c 'git status --porcelain --untracked-files=no -- . ":!.claude/agent-memory" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: leave `.claude/agents/reviewer.md` unstaged after edit 14; stdout is `1`.
7. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/refutation-sample.test.sh`; validate.sh reports `FAIL tests/refutation-sample.test.sh` (`tests/validate.sh:869-874`) and stdout is `1`.

## Pre-resolved context
- The validate wrapper needs no edit: it already runs both suites (`tests/validate.sh:869-874` and `:1625-1630`).
- spec-master applied edits 2 to 14 to a clone of 57ec2d70 and committed them under a `(rfp-u6a): ` subject:
  every anchor occurs once; `--update` changed exactly the generated paths above; edit 15 printed `done`;
  criteria 1 to 5 and their mutations behave as stated. Gate interaction, measured as the spec-master
  identity: both anchored greps of edit 3 and 4, run alone in this repo, pass `reviewed-path-gate.sh` and print
  nothing or `0` today (no `refuted:` note exists yet). A compound command that names the reviewed-markers
  directory next to `sed` or a redirect is refused.
- `'^NOTE\[code]: refuted: '` is a basic regex: `\[` is a literal `[`, and a lone `]` is literal in GNU and
  BSD grep. A `.pass` marker's notes start at column 0 (`NOTE[...]: ...`); continuation lines are indented.
- The Verdict wording follows the Refutation pass bullet ("ending the FAIL block with `refutation: …`") and the
  plan's Safety section ("With no record, the `refutation:` line goes in the verdict text"). The FAIL-record
  bullet still says the record carries "the same defect list you return in your verdict, verbatim, then the
  `refutation:` line", which stays true.
- `held` vs undecidable: the bullet already makes an undecidable refutation an informational finding, and a
  refutation that does not hold a finding of at least moderate severity. The new sentence keeps `held` to the
  refutations the auditor decided hold, so `sampled - held` counts "did not hold" plus "undecidable", and the
  findings list tells them apart.
- `bin/contract-score.js --rubric=v2 --shape=lead` scores this file below 7, like rfp-u3 and rfp-u4, so the
  contract-score guard dispatches it on `sonnet`.

## Escalation
If edit 1 prints `0`, do not start. If an anchor is not found exactly once, stop and report the current text.
If the `Write` or `Edit` tool is refused for `tests/refutation-sample.test.sh`, do not fall back to a Bash
heredoc: report it and wait. If `node bin/cli.js --update` refuses, quote its message and stop. If a gate
blocks a command, report it and wait. Anything outside "Affected files" goes in your report as a proposal.
