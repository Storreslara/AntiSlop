Unit: rfp-u4

## Objective
Teach the two downstream readers of the refutation pass what rfp-u3 made the reviewer write (plan Step 4,
D1, D5 layer 2, and the Cost model's kill criterion).
- `agents/task-master.md` gains a fix-contract bullet, right after "Fix contract.":
  - the FAIL block's last line, `refutation: …`, is telemetry and gets no criterion and no edit;
  - a defect prefixed `[unconfirmed]` gets a reproduce-first `command:` edit, an `## Escalation` line that
    skips it and reports `not-reproduced: <the defect line, without the prefix>` when it does not
    reproduce, and a criterion that holds whether it was fixed or never reproduced.
- `agents/milestone-auditor.md` gains the bullet "Refutation sample", before "No PASS/FAIL verdict":
  - list the `NOTE[code]: refuted:` notes of the `.pass` markers with one grep, keep this milestone's,
    and re-verify the first 3 (all, if fewer) against the code at the marker's `commit:`;
  - a refutation that does not hold is a finding (at least moderate), an undecidable one informational;
  - count prevented FAILs `p` and FAIL blocks that survived a pass `f` with two greps, and end the
    findings list with `refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>`;
  - at 20 or more eligible runs with `p` under a tenth, an informational finding recommends retiring or
    re-scoping the pass.
- New `tests/refutation-sample.test.sh` runs those three grep commands on a fixture with decoys and checks
  that the persona source and its mirror ship them verbatim.

The lead-programmer side of D1 (reproduce an `[unconfirmed]` defect before fixing it) already ships in the
protocol's FAIL-record section through rfp-u3; this unit does not touch `agents/lead-programmer.md`.

**Precondition: rfp-u3 has PASS.** Ordered edit 0 checks that its protocol text is on this branch.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Units and order",
"Step 4", "Safety" layer 2, "Cost model" kill criterion, "FAIL-record readers"). This file is the contract of
record. Dispatch only after rfp-u3 has a PASS marker; rfp-u5 waits for this unit's PASS.

## Affected files
- `agents/task-master.md` (anchor: line matching `  tier tag; the ratchet stays.`)
- `agents/milestone-auditor.md` (anchor: line matching `- **No PASS/FAIL verdict — that vocabulary belongs to the reviewer.** Return`)
- `tests/refutation-sample.test.sh` (anchor: new file, mode 755)
- `tests/persona-prose-pins.test.sh` (anchor: line matching `if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi`)
- `tests/validate.sh` (anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md` (the task-master and milestone-auditor bodies, every mirror's stamp line), `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

No hand-synced port carries either persona: `adapters/codex/` and `adapters/cursor/` ship only explorer,
lead-programmer, orchestrator and reviewer, and the fix-contract bullet's text exists only in
`agents/task-master.md` and its generated mirror (spec-master grepped the tree at 3bd60f56, worktrees
excluded).

## Ordered edits
0. command: `grep -cF 'refutation: skipped=<mechanical|over-cap|resume|no-subagent>' templates/persona-protocol.md`
   expect: 0, stdout `1` (rfp-u3's edit 9 is on this branch). Stdout `0`: stop, rfp-u3 has not landed.
1. file: `tests/refutation-sample.test.sh` (new, mode 755), content:
~~~
#!/usr/bin/env bash
# rfp-u4: the milestone-auditor's refutation-sample commands count what the plan's Cost model defines
# (prevented FAILs: .pass markers carrying a `NOTE[code]: refuted:` note; FAILs that survived a pass:
# FAIL-block lines starting `refutation: confirmed=`), on a fixture with decoys, and
# agents/milestone-auditor.md and its mirror ship exactly these commands. Fixtures live under mktemp -d only.
set -uo pipefail
cd "$(dirname "$0")/.."
root="$(pwd)"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

LIST="grep -rnF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | sort"
PREVENTED="grep -rlF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | wc -l"
SURVIVED="grep -rh '^refutation: confirmed=' --include='*.fail' .claude/reviewed | wc -l"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
proj="$tmp/proj"
d="$proj/.claude/reviewed"
mkdir -p "$d"
cat > "$d/m1.pass" <<'EOF'
PASS m1 2026-11-01T00:00:00Z commit: none criteria: x
NOTE[code]: refuted: D1 src/a.sh:2 b is unquoted — src/a.sh:1 quotes it — the quote is on this path
NOTE[code]: refuted: D2 src/a.sh:5 no empty check — src/a.sh:4 returns early — it runs first
EOF
cat > "$d/m2.pass" <<'EOF'
PASS m2 2026-11-01T00:00:00Z commit: none criteria: x
NOTE[code]: unconfirmed: D1 src/b.sh:3 maybe racy
NOTE[code]: the wrap width is ragged
EOF
cat > "$d/m3.pass" <<'EOF'
PASS m3 2026-11-01T00:00:00Z commit: none criteria: x
NOTE[code]: refuted: D1 src/c.sh:7 off by one — tests/c.test.sh:12 covers the bound — it fails on the claimed input
EOF
cat > "$d/m4.fail" <<'EOF'
FAIL m4 2026-11-01T00:00:00Z
tier: haiku
- src/d.sh:2 a defect whose prose quotes refutation: confirmed=9 mid-line
refutation: confirmed=1 refuted=0 uncertain=0

FAIL m4 2026-11-02T00:00:00Z
tier: haiku
- review-precheck printed a criterion failure line
refutation: skipped=mechanical

EOF
cat > "$d/m5.fail" <<'EOF'
FAIL m5 2026-11-01T00:00:00Z
tier: sonnet
- src/e.sh:4 first
- [unconfirmed] src/e.sh:9 second
refutation: confirmed=1 refuted=1 uncertain=1

NOTE[code]: refuted: D9 a decoy outside any .pass marker
EOF
cat > "$d/m6.blocked" <<'EOF'
NOTE[code]: refuted: D1 a decoy in a .blocked marker
EOF

run() { (cd "$proj" && bash -c "$1"); }

# (a) the list holds the three refuted notes of the .pass markers, sorted, and no decoy
list="$(run "$LIST")"
want='.claude/reviewed/m1.pass:2:NOTE[code]: refuted: D1 src/a.sh:2 b is unquoted — src/a.sh:1 quotes it — the quote is on this path
.claude/reviewed/m1.pass:3:NOTE[code]: refuted: D2 src/a.sh:5 no empty check — src/a.sh:4 returns early — it runs first
.claude/reviewed/m3.pass:2:NOTE[code]: refuted: D1 src/c.sh:7 off by one — tests/c.test.sh:12 covers the bound — it fails on the claimed input'
[ "$list" = "$want" ] && ok "(a) sample list" || bad "(a) sample list: [$list]"

# (b) prevented FAILs: two .pass markers carry a refuted note (m1 counts once)
p="$(run "$PREVENTED" | tr -d ' ')"
[ "$p" = 2 ] && ok "(b) prevented=2" || bad "(b) prevented=[$p]"

# (c) FAILs that survived a pass: m4's first block and m5; the skipped block and the mid-line quote do not count
f="$(run "$SURVIVED" | tr -d ' ')"
[ "$f" = 2 ] && ok "(c) survived=2" || bad "(c) survived=[$f]"

# (d) the persona source and its mirror ship exactly these three commands and the summary line
for file in agents/milestone-auditor.md .claude/agents/milestone-auditor.md; do
  flat="$(tr -s ' \n' ' ' < "$root/$file")"
  miss=""
  for c in "$LIST" "$PREVENTED" "$SURVIVED" 'refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>'; do
    printf '%s' "$flat" | grep -qF -- "$c" || miss="$miss [$c]"
  done
  [ -z "$miss" ] && ok "(d) $file ships the commands" || bad "(d) $file lacks:$miss"
done

if [ "$fail" -eq 0 ]; then echo "All refutation-sample checks passed."; else echo "refutation-sample: FAILED"; fi
exit "$fail"
~~~
   Write it with the `Write` tool: its text names the reviewed-markers directory, so a Bash heredoc is
   refused by `reviewed-path-gate.sh` (see Escalation). Run it: cases (a) to (c) pass and both case (d)
   lines fail until edits 3 and 7. This is the red step.
2. file: `agents/task-master.md`
   anchor: line matching `  tier tag; the ratchet stays.`
   indent: 0
   insert-after:
~~~
- **Refutation telemetry and `[unconfirmed]` defects in a fix contract.**
  The latest FAIL block's last line, `refutation: …`, is telemetry: it gets
  no criterion and no edit. A defect prefixed `[unconfirmed]` is one the
  reviewer's refutation pass could neither prove nor disprove. Its first
  ordered edit is a `command:` that reproduces it, with the failing output
  as its `expect:`, and the contract's `## Escalation` says: if that command
  does not show the failure, make no edit for this defect and report
  `not-reproduced: <the defect line, without the prefix>`. Its criterion is
  the same command with the failure gone, so it holds whether the defect
  was fixed or never reproduced.
~~~
3. file: `agents/milestone-auditor.md`
   anchor: line matching `- **No PASS/FAIL verdict — that vocabulary belongs to the reviewer.** Return`
   indent: 0
   insert-before:
~~~
- **Refutation sample.** The reviewer's refutation pass turns a FAIL into a
  PASS when it refutes every defect, and no later gate re-checks such a
  refutation, so sample them here. List them with
  `grep -rnF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | sort`
  and keep the lines whose marker (`<unit-id>.pass`) is a unit of this
  milestone. Re-verify the first 3 of them (all, if fewer) against the code
  at the marker's `commit:` (HEAD when it reads `none`): read the defect's
  cited lines and the note's artifact yourself, and decide whether the
  artifact defeats the claim on the defect's own path. This judges the
  reviewer's reasoning; it does not re-run the reviewer's checks. A
  refutation that does not hold is a finding of at least moderate severity,
  quoting the note and your evidence; one you cannot decide is an
  informational finding. Then count, over the whole project, the prevented
  FAILs `p` with
  `grep -rlF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | wc -l`
  and the FAIL blocks that survived a pass `f` with
  `grep -rh '^refutation: confirmed=' --include='*.fail' .claude/reviewed | wc -l`,
  and end your findings list with one line:
  `refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>`.
  When `eligible` is 20 or more and `p` is under a tenth of it, add an
  informational finding recommending a follow-up to retire or re-scope the
  pass. With no `refuted:` note in this milestone, the line reads
  `sampled=0 held=0` and needs no finding.
~~~
   Do not reflow edits 2 and 3. Each command must stay on one physical line: case (d) of edit 1 matches
   them after `tr -s ' \n' ' '`, so a wrap inside a command is tolerated, but a changed character is not.
4. file: `tests/persona-prose-pins.test.sh`
   anchor: line matching `if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi`
   indent: 0
   insert-before:
~~~
for f in agents/task-master.md .claude/agents/task-master.md; do
  has "$f" 'it gets no criterion and no edit'
  has "$f" 'with the failing output as its `expect:`'
  has "$f" '`not-reproduced: <the defect line, without the prefix>`'
done
for f in agents/milestone-auditor.md .claude/agents/milestone-auditor.md; do
  has "$f" 'Re-verify the first 3 of them (all, if fewer)'
  has "$f" 'decide whether the artifact defeats the claim on the defect'
  has "$f" 'When `eligible` is 20 or more and `p` is under a tenth of it'
done
~~~
   These pins prove the text shipped to both copies, not that it is followed. The behaviour-bearing check
   is edit 1's fixture test (the commands count the right things, and the shipped commands are those).
5. file: `tests/validate.sh`
   anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`
   indent: 0
   insert-before:
~~~
echo "== refutation-sample: the milestone auditor's refutation-sample commands on a fixture (Bash, rfp-u4) =="
if bash tests/refutation-sample.test.sh > /dev/null; then
  echo "OK   tests/refutation-sample.test.sh"
else
  echo "FAIL tests/refutation-sample.test.sh"
  fail=1
fi

echo
~~~
6. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0 (+1 on whatever is current at dispatch; it was 0.31.219 at 3bd60f56, before rfp-u1 to rfp-u3)
7. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Fix contracts and the milestone auditor read the refutation pass (rfp-u4, VERSION).** `agents/task-master.md` gains a fix-contract bullet: the FAIL block's `refutation:` line is telemetry and gets no criterion; a defect prefixed `[unconfirmed]` gets a reproduce-first `command:` edit, an Escalation line that skips it and reports `not-reproduced: <the defect line, without the prefix>` when it does not reproduce, and a criterion that holds either way. `agents/milestone-auditor.md` gains "Refutation sample": at each milestone it re-verifies up to 3 of the milestone's `NOTE[code]: refuted:` notes, ends its findings with `refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>` from two grep counts, and recommends retiring or re-scoping the pass when 20 or more eligible runs show fewer than a tenth prevented. New `tests/refutation-sample.test.sh` runs the shipped commands on a fixture with decoys. Spec: `docs/plans/2026-10-27-refutation-pass.md`.
~~~
   Replace `VERSION` with the version edit 6 wrote.
8. command: `node bin/cli.js --update`
   expect: 0
9. command: `bash -c 'for t in persona-prose-pins refutation-sample prompt-diet-pins; do bash tests/$t.test.sh >/dev/null || echo "red $t"; done; for t in protocol-cross-references rubric-doc-parity contract-examples; do node tests/$t.test.js >/dev/null || echo "red $t"; done; echo done'`
   expect: 0, stdout `done` only
10. command: `git add agents/task-master.md agents/milestone-auditor.md tests/refutation-sample.test.sh tests/persona-prose-pins.test.sh tests/validate.sh .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude ':(exclude).claude/agent-memory' && git commit -m "feat(rfp-u4): fix contracts reproduce [unconfirmed] defects first; the milestone auditor samples refuted notes"`
    expect: 0
    Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it.
    Every later commit of this unit (a fix round) that touches `agents/` repeats edits 6 to 8 in that same
    commit, adds its own CHANGELOG line naming its own version, and keeps `(rfp-u4): ` in its subject.
    Constitution P3 is checked per commit, over every `(rfp-u4)` commit (criterion 5).

## Do NOT touch
- `agents/reviewer.md`, `templates/persona-protocol.md`, `adapters/` (rfp-u3's; criterion 4)
- `agents/lead-programmer.md`, `agents/orchestrator.md` (D1's lead-programmer half ships in the protocol; criterion 4)
- `hooks/`, `bin/`, `scripts/` (no reader changes; criterion 4)
- `eval/` (rfp-u2's and Gate G's; criterion 4)
- `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/` (rfp-u5's; criterion 4)
- `.claude/` mirrors by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'out=$(bash tests/persona-prose-pins.test.sh); rc=$?; printf "%s\n" "$out" | grep -c "^FAIL"; echo "rc=$rc"'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: skip edit 8 (`--update`); the three `.claude/agents/task-master.md` and three `.claude/agents/milestone-auditor.md` pins fail, so stdout is `6` then `rc=1` (spec-master ran it on a scratch copy).
2. run: `bash -c 'bash tests/refutation-sample.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: drop the `^` from the `refutation: confirmed=` command in both the test and `agents/milestone-auditor.md`; the fixture's mid-line decoy counts, case (c) prints `survived=[3]` and stdout is `1`. Dropping `--include='*.pass'` from the `-rlF` command (both places) counts the two decoys, case (b) prints `prevented=[4]` (spec-master ran both).
3. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u4): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for f in agents/task-master.md:12 agents/milestone-auditor.md:25; do p=${f%:*}; m=${f#*:}; a=0; r=0; for c in $cs; do set -- $(git show --numstat --format= "$c" -- "$p"); a=$((a+${1:-0})); r=$((r+${2:-0})); done; if [ "$a" -ge 1 ] && [ "$a" -le "$m" ] && [ "$r" = 0 ]; then echo "ok $p"; else echo "off $p +$a -$r"; fi; done'`
   exit: 0
   stdout: `ok agents/task-master.md` then `ok agents/milestone-auditor.md`
   mutation: paste edit 3's bullet twice; the second line reads `off agents/milestone-auditor.md +46 -0`. With no `(rfp-u4): ` commit, stdout is `no-commits`, exit 1. spec-master's scratch commit measured +10/-0 and +23/-0.
4. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u4): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -v "^\.claude/" | grep -vxE "agents/(task-master|milestone-auditor)\.md|tests/(persona-prose-pins|refutation-sample)\.test\.sh|tests/validate\.sh|\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md|docs/plans/.+" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: commit a new file such as `src_extra.txt` under a `(rfp-u4): ` subject; stdout is `1` (spec-master ran it). An `agents/reviewer.md` edit counts the same way. It reads only this unit's commits, so other units' commits interleaved on the branch do not count.
5. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u4): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; bad=0; t=no; for c in $cs; do o=$(bash hooks/scripts/version-stamp-check.sh "$c^..$c"); case "$o" in "version-stamp-check: ok touched: yes"*) t=yes ;; "version-stamp-check: ok "*) ;; *) bad=$((bad+1)) ;; esac; done; echo "bad=$bad touched=$t"'`
   exit: 0
   stdout: `bad=0 touched=yes`
   mutation: add a fix-round commit `fix(rfp-u4): …` that edits `agents/milestone-auditor.md` without edit 6; stdout is `bad=1 touched=yes` (spec-master ran it).
6. run: `bash -c 'git status --porcelain --untracked-files=no -- . ":!.claude/agent-memory" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: leave `.claude/agents/task-master.md` unstaged after edit 8; stdout is `1`.
7. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/refutation-sample.test.sh`; validate.sh reports it (edit 5) and stdout is `1`.

## Pre-resolved context
- spec-master applied edits 1 to 4 and 6 to a scratch copy of 3bd60f56 (`git archive`), ran
  `node bin/cli.js --update`, and committed under a `(rfp-u4): ` subject:
  - both anchors occur exactly once; the diffs measured +10/-0 (task-master) and +23/-0 (milestone-auditor);
  - `--update` changed exactly the paths listed under Affected files (every mirror's stamp line, the
    config, the two protocol copies and the digest);
  - every pin of edit 4 matches once in both copies and never at 3bd60f56;
  - `persona-prose-pins`, `prompt-diet-pins`, `refutation-sample`, `protocol-cross-references`,
    `rubric-doc-parity`, `contract-examples`, `effort-tier-consistency` and `writer-tier-consistency` pass;
  - criteria 2 to 5 and their mutations behave as stated. `tests/validate.sh` was not run there.
- Gate interaction, measured as the spec-master identity at 3bd60f56: the three grep commands of edit 3,
  run in this repo, pass `reviewed-path-gate.sh` (read-only `grep -r`, piped to `sort` or `wc -l`), and both
  counts print `0` today. A form with `$(…)` substitution around them is refused, which is why the auditor
  gets two plain counts and adds them itself. Criterion 4 matches `^\.claude/` instead of naming the
  config file, because `harness-integrity-gate.sh` refuses any Bash text that names it.
- `wc -l` pads its number with spaces on BSD; the test strips them with `tr -d ' '`.
- Why `not-reproduced: <the defect line, without the prefix>` and not `D<n>`: D-numbers exist only in the
  brief the reviewer pipes to `refutation-brief.sh`; the FAIL block's defect list carries no D-number. The
  plan's Step 4 is updated to match.
- `agents/milestone-auditor.md` says "Never re-run the reviewer's checks (tests, lint, build)". The sample
  judges a refutation's reasoning, and the bullet says so.
- Under `reviewGating.mode: off` no marker or FAIL record exists, so the sample prints `sampled=0` and both
  counts are `0`. That is correct: nothing was recorded.
- `bin/contract-score.js --rubric=v2 --shape=lead` scores this file below 7, like rfp-u1 to rfp-u3, so the
  contract-score guard dispatches it on `sonnet`.

## Escalation
If edit 0 prints `0`, do not start: rfp-u3 has not landed. If an anchor is not found exactly once, stop and
report the current text. If the `Write` tool is refused for edit 1, do not fall back to a Bash heredoc
(`reviewed-path-gate.sh` refuses heredoc text naming the reviewed-markers directory): report it and wait. If
`node bin/cli.js --update` refuses, quote its message and stop. If a gate blocks a command, report it and
wait. Anything outside "Affected files" goes in your report as a proposal.
