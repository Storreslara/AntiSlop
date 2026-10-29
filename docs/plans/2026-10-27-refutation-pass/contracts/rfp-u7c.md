Unit: rfp-u7c

## Objective
Clear the two `score.py` advisory notes from the rfp-u6b review (plan Step 7, item 7). Every change is in
`eval/refutation-replay/score.py` and its suite; nothing writes the real `labels.tsv`, `corpus.jsonl` or
`report.jsonl`.
1. **The docstring contradicts itself.** It says bad input exits 2 "with or without --gate", then ends "Without
   --gate it always exits 0". The last sentence becomes "Without --gate it exits 0 unless the input is bad", and
   the bad-input paragraph says that only reading the arguments and the two files maps an error to bad input.
2. **The bad-input `try` is too wide.** `main()` wraps the whole of `score()`, so a `ValueError` or `TypeError`
   from a later code bug, or an `OSError` such as a broken pipe on the final `print`, is also reported as
   `score.py: bad input: …` with exit 2. The parsing steps move into a new `load(argv)` (the arguments, the labels
   file, `read_rows`, and the `int(num_turns)` and `float(cost_usd)` conversions of each labelled row). Only
   `load()` sits inside the `try`; `score(gate, labels, rows)` runs after it, so an error there ends in a
   traceback. The output line and the exit codes on good input do not change.
3. **Tests** (`tests/refutation-replay.test.sh`): case (o) gains a non-numeric `cost_usd`, which pins the
   conversion inside `load()`. New case (o2) replaces `score.score` with a function that raises `ValueError` and
   checks that `main()` lets it propagate. New case (o3) runs `score.py` with unbuffered stdout on `/dev/full`
   and checks for a traceback with exit 1 and no `bad input` line. It reports itself skipped where there is no
   `/dev/full`.

No stamped path is touched (`eval/` and `tests/` only), so there is no version bump and no CHANGELOG entry
(constitution P3, as for rfp-u6b).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Units and order", "Step 7").
This file is the contract of record. rfp-u7c shares no file with rfp-u7b, rfp-u7d or rfp-u7e, so the four may be
built at the same time. One unit is mid-review at a time.

## Affected files
- `eval/refutation-replay/score.py` (anchor: line matching `MIN_REAL, MAX_MISSES, MAX_TURNS, MAX_UNANSWERED = 30, 1, 10, 0.20`, which stays byte-identical; mode stays 755)
- `tests/refutation-replay.test.sh` (anchor: line matching `# (p) rfp-u6b: capped counts the scored ids, not every row: a foreign capped row neither counts nor fails the gate`; mode stays 755)

## Ordered edits
Edits 1 to 11 were generated from spec-master's tested scratch payload (a clone at b9bcdf92). Applied in order,
they reproduce it byte for byte. Use the Write/Edit tools for every file edit.

1. file: `eval/refutation-replay/score.py`
   anchor: line matching `` on stdout and one line on stderr: `score.py: bad input: <reason>`. ``
   before:
~~~
on stdout and one line on stderr: `score.py: bad input: <reason>`.
~~~
   after:
~~~
on stdout and one line on stderr: `score.py: bad input: <reason>`. Only reading the arguments and the two
files maps an error to bad input; an error after that (a code bug, a closed stdout) ends in a traceback.
~~~

2. file: `eval/refutation-replay/score.py`
   anchor: line matching `max-turns <= MAX_TURNS, dup-conflict = 0 and capped = 0. Anything else is fail. Without --gate it always exits 0.`
   before:
~~~
max-turns <= MAX_TURNS, dup-conflict = 0 and capped = 0. Anything else is fail. Without --gate it always exits 0.
~~~
   after:
~~~
max-turns <= MAX_TURNS, dup-conflict = 0 and capped = 0. Anything else is fail. Without --gate it exits 0 unless the input is bad.
~~~

3. file: `eval/refutation-replay/score.py`
   anchor: line matching `return score(argv)`
   before:
~~~
        return score(argv)
~~~
   after:
~~~
        gate, labels, rows = load(argv)
~~~

4. file: `eval/refutation-replay/score.py`
   anchor: line matching `return 2` (the only one; it closes `main()`'s `except` block)
   before:
~~~
        return 2
~~~
   after:
~~~
        return 2
    return score(gate, labels, rows)
~~~

5. file: `eval/refutation-replay/score.py`
   anchor: line matching `def score(argv):`
   before:
~~~
def score(argv):
~~~
   after:
~~~
def load(argv):
    # every parsing step: the arguments, both files, and the numeric fields of each labelled row
~~~

6. file: `eval/refutation-replay/score.py`
   anchor: line matching `rows = read_rows(report)`
   before:
~~~
    rows = read_rows(report)
~~~
   after:
~~~
    rows = read_rows(report)
    for r in rows:
        if str(r.get('id')) in labels:
            r['num_turns'] = int(r.get('num_turns') or 0)
            r['cost_usd'] = float(r.get('cost_usd') or 0)
    return gate, labels, rows


def score(gate, labels, rows):
~~~

7. file: `eval/refutation-replay/score.py`
   anchor: line matching `turns.append(int(r.get('num_turns') or 0))`
   before:
~~~
        turns.append(int(r.get('num_turns') or 0))
~~~
   after:
~~~
        turns.append(r['num_turns'])
~~~

8. file: `eval/refutation-replay/score.py`
   anchor: line matching `costs = [float(r.get('cost_usd') or 0) for r in scored]`
   before:
~~~
    costs = [float(r.get('cost_usd') or 0) for r in scored]
~~~
   after:
~~~
    costs = [r['cost_usd'] for r in scored]
~~~

9. file: `tests/refutation-replay.test.sh`
   anchor: line matching `printf '{"id": "r1", "answer": "CONFIRMED", "num_turns": [5]}\n' > "$bi/tlist.jsonl"`
   before:
~~~
printf '{"id": "r1", "answer": "CONFIRMED", "num_turns": [5]}\n' > "$bi/tlist.jsonl"
~~~
   after:
~~~
printf '{"id": "r1", "answer": "CONFIRMED", "num_turns": [5]}\n' > "$bi/tlist.jsonl"
printf '{"id": "r1", "answer": "CONFIRMED", "num_turns": 5, "cost_usd": "abc"}\n' > "$bi/cost.jsonl"
~~~

10. file: `tests/refutation-replay.test.sh`
   anchor: line matching `sb turns-list "$bi/tlist.jsonl"`
   before:
~~~
sb turns-list "$bi/tlist.jsonl"
~~~
   after:
~~~
sb turns-list "$bi/tlist.jsonl"
sb cost "$bi/cost.jsonl" --gate
~~~

11. file: `tests/refutation-replay.test.sh`
   anchor: line matching `&& ok "(p) a capped row with an unlabelled id is foreign, not capped" || bad "(p) rc=$rc $o"`
   before:
~~~
  && ok "(p) a capped row with an unlabelled id is foreign, not capped" || bad "(p) rc=$rc $o"
~~~
   after:
~~~
  && ok "(p) a capped row with an unlabelled id is foreign, not capped" || bad "(p) rc=$rc $o"
# (o2) rfp-u7c: only reading and parsing map to bad input. A ValueError raised after them, here by the scoring
# step, propagates instead of exiting 2
o2="$(python3 -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import score
def boom(*a): raise ValueError("a code bug")
score.score = boom
try:
    print("swallowed rc=%s" % score.main([sys.argv[2]]))
except ValueError:
    print("propagates")' "$d" "$tmp/s1/report.jsonl" 2>&1)"
[ "$o2" = propagates ] && ok "(o2) an error after parsing is not bad input" || bad "(o2) $o2"
# (o3) rfp-u7c: a failed write to stdout is not bad input either: unbuffered stdout on /dev/full ends in a
# traceback, exit 1
if [ -w /dev/full ]; then
  python3 -B -u "$d/score.py" "$tmp/s1/report.jsonl" > /dev/full 2>"$tmp/full.err"; rc=$?
  if [ "$rc" = 1 ] && grep -q '^Traceback' "$tmp/full.err" && ! grep -q 'bad input' "$tmp/full.err"; then
    ok "(o3) a stdout write error ends in a traceback"
  else bad "(o3) rc=$rc $(tail -1 "$tmp/full.err")"; fi
else
  ok "(o3) skipped: no /dev/full"
fi
~~~

12. command: `bash -c 'bash tests/refutation-replay.test.sh >/dev/null; a=$?; bash tests/refutation-replay-isolation.test.sh >/dev/null; echo "replay=$a isolation=$?"'`
    expect: 0, stdout `replay=0 isolation=0`

13. command: `git add eval/refutation-replay/score.py tests/refutation-replay.test.sh && git commit -m "fix(rfp-u7c): score.py maps only parsing errors to bad input"`
    expect: 0
    Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it,
    unless it is one of rfp-u7b's, rfp-u7d's or rfp-u7e's files (those units may be in progress in the same
    tree): leave those unstaged. A fix round is a new commit whose subject keeps `(rfp-u7c): `.

## Do NOT touch
- `eval/refutation-replay/labels.tsv`, `corpus.jsonl` (ground truth) and `report.jsonl` (Gate G run 2 evidence):
  never edit, move or regenerate them (criterion 6)
- `eval/refutation-replay/run.sh`, `label.py`, `guard.py`, `build-corpus.py`, `label_page.html`, `README.md`
  (criteria 5 and 6; `label.py` is rfp-u7d's, `guard.py` rfp-u7e's)
- `tests/refutation-replay-isolation.test.sh` (rfp-u7e's), `tests/refutation-label-server.py` (rfp-u7d's)
- `hooks/`, `bin/`, `.claude/`, every gate script, `agents/`, `templates/`, `CONTEXT.md`, `docs/` (criterion 5)
- Never run `eval/refutation-replay/run.sh` without `--dry-run`, and never run `label.py serve` against the
  real `labels.tsv` or `corpus.jsonl`. Mutations go in a scratch clone, never in this working tree.

## Acceptance criteria
1. run: `bash -c 'out=$(bash tests/refutation-replay.test.sh 2>&1); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") o2=$(printf "%s\n" "$out" | grep -c "^OK   (o2) ") o3=$(printf "%s\n" "$out" | grep -c "^OK   (o3) a stdout") rc=$rc"'`
   exit: 0
   stdout: `fails=0 o2=1 o3=1 rc=0`
   mutation: in a scratch clone, each alone (spec-master ran all four): `score.py` at b9bcdf92 prints `fails=2 o2=0 o3=0 rc=1` (`(o2) score.py: bad input: a code bug`, `(o3) rc=2 … No space left on device`); moving `return score(gate, labels, rows)` inside the `try` prints the same; moving the `cost_usd` conversion back into `score()` makes case (o) red (`cost rc=1 … Traceback`); dropping `TypeError` from the except tuple makes case (o) red (`turns-list rc=1`). `o3=1` requires `/dev/full`, which this machine has; where it is missing, case (o3) prints `skipped` and this criterion's `o3` reads `0`.
2. run: `bash -c 'f=eval/refutation-replay/score.py; echo "always=$(grep -c "Without --gate it always exits 0" $f) unless=$(grep -c "Without --gate it exits 0 unless the input is bad" $f)"'`
   exit: 0
   stdout: `always=0 unless=1`
   mutation: `score.py` at b9bcdf92 prints `always=1 unless=0` (spec-master ran it).
3. run: `bash -c 'python3 -B eval/refutation-replay/score.py eval/refutation-replay/report.jsonl --gate; echo "rc=$?"' | paste -sd " " -`
   exit: 0
   stdout: `replay-gate: pass real=41 refuted-real=1 confirmed-real=25 uncertain-real=15 unanswered=0 bogus=0 refuted-bogus=0 max-turns=10 mean-cost-usd=0.060 missing=0 dup-conflict=0 foreign=0 capped=0 rc=0`
   mutation: none needed: this is the Gate G run 2 line `score.py` printed at b9bcdf92 on the committed report, read only. A change to the output line or to the row conversions changes it. rfp-u3's criterion 8 reads this same line.
4. run: `bash -c 'bash tests/refutation-replay-isolation.test.sh >/dev/null 2>&1; a=$?; python3 tests/refutation-label-server.py >/dev/null 2>&1; echo "isolation=$a label-server=$?"'`
   exit: 0
   stdout: `isolation=0 label-server=0`
   mutation: rename `MIN_REAL` in `score.py`; `label.py` cannot read the threshold, so the label server suite fails (`label-server=1`). Both suites import or run `score.py` (case (s) of the isolation suite, and S15 of the server suite).
5. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u7c): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "eval/refutation-replay/score\.py|tests/refutation-replay\.test\.sh" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: commit an edit to `eval/refutation-replay/label.py` under a `(rfp-u7c): ` subject; stdout is `1`. With no `(rfp-u7c): ` commit, stdout is `no-commits`, exit 1.
6. run: `bash -c 'd=$(git diff --name-only b9bcdf92 -- eval/refutation-replay/labels.tsv eval/refutation-replay/corpus.jsonl eval/refutation-replay/report.jsonl eval/refutation-replay/run.sh | wc -l | tr -d " "); s=$(git status --porcelain -- eval/refutation-replay/score.py tests/refutation-replay.test.sh eval/refutation-replay/labels.tsv eval/refutation-replay/corpus.jsonl eval/refutation-replay/report.jsonl | wc -l | tr -d " "); echo "truth-diff=$d dirty=$s"'`
   exit: 0
   stdout: `truth-diff=0 dirty=0`
   mutation: append a line to `labels.tsv`; stdout is `truth-diff=1 dirty=1`. b9bcdf92 is the commit this contract was written at. The pathspec is this unit's files and the ground truth, so another Step 7 unit's work in progress does not count.

## Pre-resolved context
- spec-master applied edits 1 to 11 to a clone of b9bcdf92 and committed them under a `(rfp-u7c): ` subject:
  every hunk applies once; edit 12 printed `replay=0 isolation=0`; criteria 1 to 6 and every mutation above
  behave as stated. The new `score.py` prints the same `replay-gate:` line, rc 0, as the committed one on the
  real run-2 `report.jsonl` (criterion 3).
- The conversions in `load()` run only for rows whose id is in the labels, as before; a foreign row with a
  non-numeric `num_turns` is still only counted as `foreign`. One behaviour does change: a repeated labelled row
  with a non-numeric `cost_usd` was ignored before (only an id's first row was costed) and is now bad input.
  This is deliberate, since the row is malformed.
- Case (o2) uses `python3 -B`, so importing `score` writes no `__pycache__` beside it.
- `label.py` imports `score.py` only for `MIN_REAL`, which stays byte-identical (rfp-u7d edits `label.py`, not
  this file).
- `bin/contract-score.js --rubric=v2 --shape=lead` scores this file below 7, like rfp-u6b, so the
  contract-score guard dispatches it on `sonnet`.

## Escalation
If a hunk's `before` text is not found exactly once, stop and report the current text. If `/dev/full` is
missing on the machine, report criterion 1's `o3=0` and stop; do not weaken case (o3). If a gate blocks a
command, report it and wait. Anything outside "Affected files" goes in your report as a proposal.
