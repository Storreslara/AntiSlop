Unit: rfp-u7d

## Objective
Close Open Question 8 of the plan (the rfp-u2c PASS note about `label.py` on a broken `score.py`; plan Step 7,
item 8). `read_min_real` in `eval/refutation-replay/label.py` reads the Gate G threshold by executing
`score.py`. Today:
- a `score.py` with a syntax error, a missing `MIN_REAL`, or an exception at import time makes
  `label.py serve` exit 1 with a traceback, because `main()` catches only `LabelError`, `OSError`, `ValueError`
  and `KeyError`;
- `MIN_REAL = True` is accepted, because `bool` is a subclass of `int`, and the page then reads "at least true
  real".

Nothing is written and no socket is bound on that path today (`read_min_real` runs before the server is
built), so this is an exit-shape fix. After it, loading `score.py` is wrapped and any exception becomes a
`LabelError` (one stderr line `label: score.py could not be loaded (<ExceptionType>): …`, exit 2). `MIN_REAL` is
read with `getattr` and must be exactly an `int` (`type(v) is int`), so a missing value, a `bool` or a string
is the existing `label: score.py MIN_REAL is not an integer` refusal. Server case S13 gains five broken
`score.py` variants, each run from a copy of `label.py` in a temporary directory. The suite keeps its 16 cases,
so `tests/refutation-label.test.sh` needs no change.

No stamped path is touched (`eval/` and `tests/` only), so there is no version bump and no CHANGELOG entry
(constitution P3).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Units and order", "Step 7").
This file is the contract of record. rfp-u7d shares no file with rfp-u7b, rfp-u7c or rfp-u7e, so the four may be
built at the same time. One unit is mid-review at a time.

## Affected files
- `eval/refutation-replay/label.py` (anchor: line matching `def read_min_real():`; mode stays 755)
- `tests/refutation-label-server.py` (anchor: line matching `check(not os.path.exists(fx.log), 'no score.py: log created')`)

## Ordered edits
Edits 1 and 2 were generated from spec-master's tested scratch payload (a clone at b9bcdf92). Applied in order,
they reproduce it byte for byte. Use the Write/Edit tools for every file edit.

1. file: `eval/refutation-replay/label.py`
   anchor: line matching `spec.loader.exec_module(mod)`
   before:
~~~
    spec.loader.exec_module(mod)
    if not isinstance(mod.MIN_REAL, int): raise LabelError('score.py MIN_REAL is not an integer')
    return mod.MIN_REAL
~~~
   after:
~~~
    try:
        spec.loader.exec_module(mod)
    except Exception as e:  # a broken score.py is a refusal to start, never a traceback
        raise LabelError('score.py could not be loaded (%s): the Gate G targets cannot be read' % type(e).__name__)
    v = getattr(mod, 'MIN_REAL', None)
    if type(v) is not int: raise LabelError('score.py MIN_REAL is not an integer')  # bool is an int subclass, so not isinstance
    return v
~~~

2. file: `tests/refutation-label-server.py`
   anchor: line matching `check(not os.path.exists(fx.log), 'no score.py: log created')`
   before:
~~~
    check(not os.path.exists(fx.log), 'no score.py: log created')
~~~
   after:
~~~
    check(not os.path.exists(fx.log), 'no score.py: log created')
    # rfp-u7d: a score.py that cannot be loaded, or whose MIN_REAL is not a plain int (a bool is an int subclass),
    # is the same one-line refusal, never a traceback
    for name, text in (('a syntax error', 'MIN_REAL = (\n'), ('no MIN_REAL', 'MAX_MISSES = 1\n'),
                       ('MIN_REAL = True', 'MIN_REAL = True\n'), ("MIN_REAL = '30'", "MIN_REAL = '30'\n"),
                       ('an import-time error', 'MIN_REAL = 30\nraise RuntimeError(\'boom\')\n')):
        fx = Fx()
        d = mktmp()
        shutil.copy(LABEL_PY, d)
        shutil.copy(os.path.join(RR, 'label_page.html'), d)
        write(os.path.join(d, 'score.py'), text)
        before = fx.snap()
        cmd = [sys.executable, os.path.join(d, 'label.py'), 'serve', '--no-open', '--port', '0', '--corpus', fx.corpus,
               '--labels', fx.labels, '--repo', fx.repo, '--log', fx.log]
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        except subprocess.TimeoutExpired:
            raise AssertionError('score.py with %s: the server started instead of refusing' % name)
        out = (p.stdout + p.stderr).strip()
        check(p.returncode == 2 and len(out.splitlines()) == 1 and out.startswith('label: score.py ') and 'Traceback' not in out,
              'score.py with %s: exit %d, %r' % (name, p.returncode, out[:160]))
        unchanged(fx, before, 'score.py with ' + name)
        check(not os.path.exists(fx.log), 'score.py with %s: log created' % name)
~~~

3. command: `bash -c 'out=$(LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh 2>&1); echo "rc=$?"'` (Bash tool timeout 600000 ms)
   expect: 0, stdout `rc=0`

4. command: `git add eval/refutation-replay/label.py tests/refutation-label-server.py && git commit -m "fix(rfp-u7d): label.py refuses a broken score.py or a non-int MIN_REAL in one line"`
   expect: 0
   Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it,
   unless it is one of rfp-u7b's, rfp-u7c's or rfp-u7e's files (those units may be in progress in the same
   tree): leave those unstaged. A fix round is a new commit whose subject keeps `(rfp-u7d): `.

## Do NOT touch
- `eval/refutation-replay/labels.tsv`, `corpus.jsonl` (ground truth) and `report.jsonl` (Gate G run 2 evidence):
  never edit, move or regenerate them (criterion 4)
- `eval/refutation-replay/score.py` (rfp-u7c's), `guard.py` (rfp-u7e's), `run.sh`, `build-corpus.py`,
  `label_page.html`, `README.md` (criteria 3 and 4)
- `tests/refutation-label.test.sh`, `tests/refutation-label-browser.js` (the case count stays 16; criterion 3)
- `hooks/`, `bin/`, `.claude/`, every gate script, `agents/`, `templates/`, `CONTEXT.md`, `docs/` (criterion 3)
- Never run `eval/refutation-replay/run.sh` without `--dry-run`, and never run `label.py serve` against the
  real `labels.tsv` or `corpus.jsonl`: the suites build their fixtures under `mktemp -d`. Mutations go in a
  scratch clone, never in this working tree.

## Acceptance criteria
1. run: `bash -c 'out=$(python3 tests/refutation-label-server.py 2>&1); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") s13=$(printf "%s\n" "$out" | grep -c "^ok - S13 ") rc=$rc"'`
   exit: 0
   stdout: `fails=0 s13=1 rc=0`
   mutation: in a scratch clone, each alone makes S13 red, so stdout is `fails=1 s13=0 rc=1` (spec-master ran all four): `label.py` at b9bcdf92 (`score.py with a syntax error: exit 1, 'Traceback …`); `type(v) is not int` back to `not isinstance(v, int)` (`score.py with MIN_REAL = True: the server started instead of refusing`); `except Exception` narrowed to `except (SyntaxError,)` (`score.py with an import-time error: exit 1`); `getattr(mod, 'MIN_REAL', None)` back to `mod.MIN_REAL` (`score.py with no MIN_REAL: exit 1`).
2. run: `bash -c 'out=$(LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh 2>&1); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") rc=$rc"'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `fails=0 rc=0`
   mutation: `label.py` at b9bcdf92 prints `fails=1 rc=1` (the server suite's S13 line; spec-master ran it). `LABEL_UI_REQUIRE_BROWSER=1` makes a run with no Chromium fail instead of skipping; the suite runs in about 35 s here.
3. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u7d): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "eval/refutation-replay/label\.py|tests/refutation-label-server\.py" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: commit an edit to `eval/refutation-replay/score.py` under a `(rfp-u7d): ` subject; stdout is `1`. With no `(rfp-u7d): ` commit, stdout is `no-commits`, exit 1.
4. run: `bash -c 'd=$(git diff --name-only b9bcdf92 -- eval/refutation-replay/labels.tsv eval/refutation-replay/corpus.jsonl eval/refutation-replay/report.jsonl eval/refutation-replay/run.sh | wc -l | tr -d " "); s=$(git status --porcelain -- eval/refutation-replay/label.py tests/refutation-label-server.py eval/refutation-replay/labels.tsv eval/refutation-replay/corpus.jsonl eval/refutation-replay/report.jsonl | wc -l | tr -d " "); echo "truth-diff=$d dirty=$s"'`
   exit: 0
   stdout: `truth-diff=0 dirty=0`
   mutation: append a line to `labels.tsv`; stdout is `truth-diff=1 dirty=1`. b9bcdf92 is the commit this contract was written at. The pathspec is this unit's files and the ground truth, so another Step 7 unit's work in progress does not count.

## Pre-resolved context
- spec-master applied edits 1 and 2 to a clone of b9bcdf92 and committed them under a `(rfp-u7d): ` subject:
  both hunks apply once; edit 3 printed `rc=0` (32 `ok` lines); criteria 1 to 4 and the criterion 1 mutations
  behave as stated. The existing "no score.py" check already expects a one-line refusal containing
  `score.py`; the new variants also require the line to start `label: score.py ` and to contain no traceback.
- `except Exception` does not catch `SystemExit` or `KeyboardInterrupt`; a `score.py` that calls `sys.exit()`
  at import is outside this fix. `score.py`'s own `if __name__ == '__main__':` block does not run, because the
  module is loaded under the name `score_consts`.
- Each variant's `mktmp()` directory is removed by the suite's own cleanup (`TMPS`), so no criterion needs
  `rm -rf`. `label.py` sets `sys.dont_write_bytecode`, so the copies leave no `__pycache__`.
- S15 compares the served `min_real` with the real `score.py`'s `MIN_REAL`; rfp-u7c keeps that line
  byte-identical, so the two units may land in either order.
- `bin/contract-score.js --rubric=v2 --shape=lead` scores this file below 7, so the contract-score guard
  dispatches it on `sonnet`.

## Escalation
If a hunk's `before` text is not found exactly once, stop and report the current text. If Chromium cannot be
launched, criterion 2 cannot pass: report it, do not drop `LABEL_UI_REQUIRE_BROWSER`. If a gate blocks a
command, report it and wait. Anything outside "Affected files" goes in your report as a proposal.
