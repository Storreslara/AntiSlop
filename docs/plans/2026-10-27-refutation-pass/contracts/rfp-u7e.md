Unit: rfp-u7e

## Objective
Fix the rfp-u6b PASS note about a `..` right after a `:` (plan Step 7, item 9b). The replay guard
`eval/refutation-replay/guard.py` refuses an argument with a `..` path segment, but its `UP` pattern
`(^|/)\.\.(/|$)` only sees a `..` at the start of the argument or after a `/`. So `git log -L1,2:../x` and
`git show HEAD:../x` pass the guard. It is not an exploitable leak: git itself refuses them ("'../x' is outside
repository"), and META keeps the cwd at the clone root. But the docstring promises to refuse any argument with
a `..` path segment, so code and doc disagree. After the fix, `UP` is `(^|[/:])\.\.(/|$)`, and the docstring
says that a `..` right after a `:` counts. Still allowed: `-L1,2:src/IO.c`, `-SObject`, `-G[O]`, `--grep=FOO`,
`HEAD~1..HEAD`, `..HEAD`, `HEAD:src/a.sh`. The isolation suite's (g2) case gains seven lines.

No stamped path is touched (`eval/` and `tests/` only), so there is no version bump and no CHANGELOG entry
(constitution P3).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Step 7"). This file is the
contract of record. rfp-u7e shares no file with rfp-u7b, rfp-u7c or rfp-u7d, so the four may be built at the
same time. One unit is mid-review at a time.

## Affected files
- `eval/refutation-replay/guard.py` (anchor: line matching `UP = re.compile(`; mode stays 755)
- `tests/refutation-replay-isolation.test.sh` (anchor: line matching `gb 2 'git log -pRO/abs/x -SObject'`; mode stays 755)

## Ordered edits
Edits 1 to 3 were generated from spec-master's tested scratch payload (a clone at cb1f9373, whose `eval/` and
`tests/` match b9bcdf92). Applied in order, they reproduce it byte for byte. Use the Write/Edit tools for every
file edit.

1. file: `eval/refutation-replay/guard.py`
   anchor: line matching `has a \`..\` path segment, and none of the options that read or write`
   before:
~~~
  that starts with `/` or `~` or has a `..` path segment, and none of the options that read or write
~~~
   after:
~~~
  that starts with `/` or `~` or has a `..` path segment (a `..` right after a `:` counts, as in
  `-L1,2:../x` or `HEAD:../x`), and none of the options that read or write
~~~

2. file: `eval/refutation-replay/guard.py`
   anchor: line matching `UP = re.compile(`
   before:
~~~
UP = re.compile(r'(^|/)\.\.(/|$)')
~~~
   after:
~~~
UP = re.compile(r'(^|[/:])\.\.(/|$)')
~~~

3. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `gb 2 'git log -pRO/abs/x -SObject'`
   before:
~~~
gb 2 'git log -pRO/abs/x -SObject'
~~~
   after:
~~~
gb 2 'git log -pRO/abs/x -SObject'
# rfp-u7e: a .. path segment right after a colon leaves the clone too; a range's .. and a colon value stay allowed
gb 2 'git log -L1,2:../x'
gb 2 'git log -L:main:../x'
gb 2 'git show HEAD:../x'
gb 0 'git diff HEAD~1..HEAD'
gb 0 'git log ..HEAD'
gb 0 'git log -L:main:src/a.sh'
gb 0 'git show HEAD:src/a.sh'
~~~

4. command: `bash -c 'out=$(bash tests/refutation-replay-isolation.test.sh 2>&1); echo "rc=$?"'` (Bash tool timeout 600000 ms)
   expect: 0, stdout `rc=0`

5. command: `git add eval/refutation-replay/guard.py tests/refutation-replay-isolation.test.sh && git commit -m "fix(rfp-u7e): guard.py refuses a .. path segment after a colon"`
   expect: 0
   Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it,
   unless it is one of rfp-u7b's, rfp-u7c's or rfp-u7d's files (those units may be in progress in the same
   tree): leave those unstaged. A fix round is a new commit whose subject keeps `(rfp-u7e): `.

## Do NOT touch
- `eval/refutation-replay/labels.tsv`, `corpus.jsonl` (ground truth) and `report.jsonl` (Gate G run 2 evidence):
  never edit, move or regenerate them (criterion 4)
- `eval/refutation-replay/score.py` (rfp-u7c's), `label.py` (rfp-u7d's), `run.sh`, `build-corpus.py`,
  `label_page.html`, `README.md` (criteria 3 and 4)
- `META`, `BAD_OPT` and every other line of `guard.py` outside edits 1 and 2: `--orderfile` (item 9a) is
  dropped, because git 2.43 has no such option (criterion 3)
- `hooks/`, `bin/`, `.claude/`, every gate script, `agents/`, `templates/`, `CONTEXT.md`, `docs/` (criterion 3)
- Never run `eval/refutation-replay/run.sh` without `--dry-run`: the isolation suite builds its fixtures under
  `mktemp -d`. Mutations go in a scratch clone, never in this working tree.

## Acceptance criteria
1. run: `bash -c 'out=$(bash tests/refutation-replay-isolation.test.sh 2>&1); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") g2=$(printf "%s\n" "$out" | grep -c "^OK   (g2) ") rc=$rc"'`
   exit: 0
   stdout: `fails=0 g2=1 rc=0`
   mutation: in a scratch clone, each alone makes the suite red (spec-master ran all three): the old `UP` makes (g2) red on the three new `gb 2` lines (`fails=1 g2=0 rc=1`); `UP = re.compile(r'\.\.')` makes (g) and (g2) red (`HEAD~1..HEAD` refused); `(^|[/:])\.\.` without the trailing group makes (g2) red (`git log ..HEAD rc=2`, `fails=1 g2=0 rc=1`).
2. run: `bash -c 'r=; for c in "git log -L1,2:../x" "git show HEAD:../x" "git log -L1,2:src/IO.c" "git log -SObject" "git log -G[O]" "git log --grep=FOO" "git diff HEAD~1..HEAD"; do python3 -c "import json,sys;print(json.dumps({\"tool_name\":\"Bash\",\"tool_input\":{\"command\":sys.argv[1]}}))" "$c" | python3 -B eval/refutation-replay/guard.py . /dev/null 2>/dev/null; r="$r$?"; done; echo "guard=$r"'`
   exit: 0
   stdout: `guard=2200000`
   mutation: `guard.py` at b9bcdf92 prints `guard=0000000` (spec-master ran it).
3. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u7e): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "eval/refutation-replay/guard\.py|tests/refutation-replay-isolation\.test\.sh" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: commit an edit to `eval/refutation-replay/score.py` under a `(rfp-u7e): ` subject; stdout is `1`. With no `(rfp-u7e): ` commit, stdout is `no-commits`, exit 1.
4. run: `bash -c 'd=$(git diff --name-only b9bcdf92 -- eval/refutation-replay/labels.tsv eval/refutation-replay/corpus.jsonl eval/refutation-replay/report.jsonl eval/refutation-replay/run.sh | wc -l | tr -d " "); s=$(git status --porcelain -- eval/refutation-replay/guard.py tests/refutation-replay-isolation.test.sh eval/refutation-replay/labels.tsv eval/refutation-replay/corpus.jsonl eval/refutation-replay/report.jsonl | wc -l | tr -d " "); echo "truth-diff=$d dirty=$s"'`
   exit: 0
   stdout: `truth-diff=0 dirty=0`
   mutation: append a line to `labels.tsv`; stdout is `truth-diff=1 dirty=1`. b9bcdf92 is the commit Step 7 was written at. The pathspec is this unit's files and the ground truth, so another Step 7 unit's work in progress does not count.
5. run: `bash -c 'grep -cF -- "-L1,2:../x" eval/refutation-replay/guard.py'`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; stdout is `0`, exit 1 (`guard.py` at b9bcdf92 prints `0`).

## Pre-resolved context
- spec-master applied edits 1 to 3 to a scratch clone and committed them under a `(rfp-u7e): ` subject: each
  hunk applies once; the isolation suite runs in about 4 s; criteria 1 to 5 and the criterion 1 and 2
  mutations behave as stated.
- git refuses a `..` after `:` on its own ("'../x' is outside repository"), so this is a doc-and-code
  agreement fix, not a leak fix. The trailing `(/|$)` group is what keeps `HEAD~1..HEAD` and `..HEAD` allowed:
  a range's `..` is followed by a revision name, not by `/` or the end of the argument.
- `--orderfile` (item 9a) is dropped: git 2.43 exits 129 or 128 on it in `diff`, `log` and `show`; only
  `-O<file>` exists, and `BAD_OPT` already refuses it, in a bundle too.
- `bin/contract-score.js --rubric=v2 --shape=lead` scores this file below 7, so the contract-score guard
  dispatches it on `sonnet`.

## Escalation
If a hunk's `before` text is not found exactly once, stop and report the current text. If a gate blocks a
command, report it and wait. Anything outside "Affected files" goes in your report as a proposal.
