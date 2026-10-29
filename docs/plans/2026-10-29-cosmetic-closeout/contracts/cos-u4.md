Unit: cos-u4

## Objective
Make the `eval/refutation-replay/` docstrings and comments say what the code does, and close one input gap, as reported in the rfp-u6b, rfp-u7c, rfp-u7d and rfp-u7e PASS notes: (a) `score.py`'s module docstring: "Without --gate it exits 0 unless the input is bad" and "an error after that (a code bug, a closed stdout) ends in a traceback" are both imprecise or false (measured: an unwritable stdout exits 120 with Python's "Exception ignored on flushing sys.stdout", no traceback); (b) `score()` gets a docstring saying it needs rows from `load()`; (c) `guard.py`'s docstring states the deliberate over-refusal of a value ending in `:..` and that `leaves()` also checks the Glob and Grep glob values, and tests pin both; (d) `label.py`'s comment says `SystemExit`/`KeyboardInterrupt` at import are not caught, the load-failure refusal adds the first line of the exception message to its type, and a `MIN_REAL` below 1 is refused like a non-int one.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-29-cosmetic-closeout.md` (Step 4, Context rows 3a-3d, Open Question 2). This file is the contract of record. Dispatch after cos-u3 has PASSed (serial order; this unit touches no mirror and no version-stamped path).

## Affected files
- `eval/refutation-replay/score.py` (anchors: line matching `files maps an error to bad input; an error after that (a code bug, a closed stdout) ends in a traceback.`; line matching `def score(gate, labels, rows):`; mode stays 755)
- `eval/refutation-replay/guard.py` (anchor: line matching `Anything else exits 2 with the reason on stderr, which blocks the call. \`git -c\` and git aliases cannot`; mode stays 755)
- `eval/refutation-replay/label.py` (anchor: line matching `    except Exception as e:  # a broken score.py is a refusal to start, never a traceback`; mode stays 755)
- `tests/refutation-label-server.py` (anchors: line matching `                       ('an import-time error', 'MIN_REAL = 30\nraise RuntimeError(\'boom\')\n')):`; line matching `        check(not os.path.exists(fx.log), 'score.py with %s: log created' % name)`; mode stays 644)
- `tests/refutation-replay-isolation.test.sh` (anchor: line matching `gb 0 'git show HEAD:src/a.sh'`; mode stays 755)

These are the only paths in scope.

## Ordered edits
Edits 1 to 7 use the Edit tool, never a Bash heredoc. spec-master applied an equivalent of every edit to a scratch clone of ab174935 and ran every criterion and mutation below there. Run every Python command with `PYTHONDONTWRITEBYTECODE=1` (an untracked `eval/refutation-replay/__pycache__/` is not gitignored).

1. file: `eval/refutation-replay/score.py`
   before:
~~~
on stdout and one line on stderr: `score.py: bad input: <reason>`. Only reading the arguments and the two
files maps an error to bad input; an error after that (a code bug, a closed stdout) ends in a traceback.
~~~
   after:
~~~
on stdout and one line on stderr: `score.py: bad input: <reason>`. Only reading the arguments and the two
files maps an error to bad input. After that, a code bug ends in a traceback with exit 1, and a stdout that
cannot be written (a closed pipe, a full disk) exits 120, Python's own exit code for a failed final flush.
~~~

2. file: `eval/refutation-replay/score.py`
   before:
~~~
max-turns <= MAX_TURNS, dup-conflict = 0 and capped = 0. Anything else is fail. Without --gate it exits 0 unless the input is bad.
~~~
   after:
~~~
max-turns <= MAX_TURNS, dup-conflict = 0 and capped = 0. Anything else is fail. Without --gate every verdict exits 0.
~~~

3. file: `eval/refutation-replay/score.py`
   anchor: line matching `def score(gate, labels, rows):`
   insert-after:
~~~
    """Print the replay-gate line; return its --gate exit code, or 0 without --gate.

    rows must come from load(), which converts num_turns and cost_usd of every labelled row in place:
    score() is not callable on raw report rows.
    """
~~~

4. file: `eval/refutation-replay/guard.py`
   anchor: line matching `Anything else exits 2 with the reason on stderr, which blocks the call. \`git -c\` and git aliases cannot`
   insert-before (as new docstring lines, indent 0):
~~~
A `..` after a `:` is refused wherever it ends the token or comes before a `/`, so a value-only argument such as
`git log --grep=a:..` or `--format=%h:..` is refused too: an over-refusal kept on purpose, never a leak.
The same leaves() check runs on the Glob `pattern` and `glob` values and the Grep `glob` value, so a glob that
starts with `/` or `~`, or holds a `..` segment (at the start, or after a `/` or a `:`), is refused as well.
~~~

5. file: `eval/refutation-replay/label.py`
   before:
~~~
    except Exception as e:  # a broken score.py is a refusal to start, never a traceback
        raise LabelError('score.py could not be loaded (%s): the Gate G targets cannot be read' % type(e).__name__)
    v = getattr(mod, 'MIN_REAL', None)
    if type(v) is not int: raise LabelError('score.py MIN_REAL is not an integer')  # bool is an int subclass, so not isinstance
    return v
~~~
   after:
~~~
    except Exception as e:  # a broken score.py is a refusal to start, never a traceback
        # SystemExit and KeyboardInterrupt are not Exception: a score.py that calls sys.exit() at import ends
        # label.py with that exit code and prints nothing.
        first = (str(e).strip().splitlines() or [''])[0]
        raise LabelError('score.py could not be loaded (%s%s): the Gate G targets cannot be read'
                         % (type(e).__name__, ': ' + first if first else ''))
    v = getattr(mod, 'MIN_REAL', None)
    if type(v) is not int: raise LabelError('score.py MIN_REAL is not an integer')  # bool is an int subclass, so not isinstance
    if v < 1: raise LabelError('score.py MIN_REAL is %d, not a positive integer' % v)
    return v
~~~

6. file: `tests/refutation-label-server.py`
   before:
~~~
                       ('an import-time error', 'MIN_REAL = 30\nraise RuntimeError(\'boom\')\n')):
~~~
   after:
~~~
                       ('an import-time error', 'MIN_REAL = 30\nraise RuntimeError(\'boom\')\n'),
                       ('MIN_REAL = 0', 'MIN_REAL = 0\n'), ('MIN_REAL = -5', 'MIN_REAL = -5\n')):
~~~

7. file: `tests/refutation-label-server.py`
   anchor: line matching `        check(not os.path.exists(fx.log), 'score.py with %s: log created' % name)` (the one inside this loop, right after `unchanged(fx, before, 'score.py with ' + name)`)
   insert-after:
~~~
        if name == 'a syntax error':
            check('line 1' in out, 'score.py with a syntax error: the refusal does not name the line: %r' % out[:160])
        if name == 'an import-time error':
            check('RuntimeError: boom' in out, 'score.py with an import-time error: no message: %r' % out[:160])
~~~

8. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `gb 0 'git show HEAD:src/a.sh'`
   insert-after:
~~~
# cos-u4: documented over-refusal: a value ending in :.. is refused, and leaves() checks Glob and Grep globs too
gb 2 'git log --grep=a:..'
gr 2 'Glob pattern holding :../' '{"tool_name": "Glob", "tool_input": {"pattern": "src/a:../*"}}'
gr 2 'Grep glob ending in :..' '{"tool_name": "Grep", "tool_input": {"glob": "a:.."}}'
gr 0 'Glob pattern holding a colon' '{"tool_name": "Glob", "tool_input": {"pattern": "src/a:b/*"}}'
~~~

9. command: `git add eval/refutation-replay/score.py eval/refutation-replay/guard.py eval/refutation-replay/label.py tests/refutation-label-server.py tests/refutation-replay-isolation.test.sh && git commit -m "fix(cos-u4): refutation-replay docstrings match behaviour; label.py refuses MIN_REAL below 1"`
   expect: 0
   Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it; if `eval/refutation-replay/__pycache__/` exists, report it (do not delete it).

## Do NOT touch
- `eval/refutation-replay/labels.tsv`, `corpus.jsonl`, `report.jsonl`, `label_page.html`, `build-corpus.py`, `run.sh`, `README.md`. Never run `run.sh` without `--dry-run`; never start `label.py serve` against the real corpus or labels (the server test uses its own fixtures in `mktemp` dirs); never set a label.
- the `UP`, `META` and `BAD_OPT` patterns and the code of `guard.py` (Open Question 2: the over-refusal stays)
- the code of `score.py` (only its docstrings change) and every `label.py` line outside edit 5
- `hooks/`, `bin/`, `.claude/`, `agents/`, `adapters/`, `templates/`, `CONTEXT.md`, `docs/`, `tests/validate.sh`

## Acceptance criteria
1. run: `bash -c 'out=$(PYTHONDONTWRITEBYTECODE=1 python3 tests/refutation-label-server.py 2>&1); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") s13=$(printf "%s\n" "$out" | grep -c "^ok - S13 ") rc=$rc"'`
   exit: 0
   stdout: `fails=0 s13=1 rc=0`
   mutation: with the `label.py` of ab174935 and the new test, S13 fails on "the refusal does not name the line": `fails=1 s13=0 rc=1`. Replacing `if v < 1` with `if v < -100` fails S13 on "MIN_REAL = 0: the server started instead of refusing" (spec-master ran both).
2. run: `bash -c 'out=$(PYTHONDONTWRITEBYTECODE=1 bash tests/refutation-replay-isolation.test.sh 2>&1); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") g2=$(printf "%s\n" "$out" | grep -c "^OK   (g2) ") rc=$rc"'`
   exit: 0
   stdout: `fails=0 g2=1 rc=0`
   mutation: in a scratch clone, changing `UP`'s `(/|$)` to `(/)` lets a trailing `:..` through; the two new trailing-`:..` cases print `guard: ... rc=0 want=2` and the line is `FAIL (g2) guard`, so stdout is `fails=1 g2=0 rc=1`. Dropping the `:` from `UP`'s `[/:]` fails the three rfp-u7e cases and the three new refusal cases.
3. run: `bash -c 'T=$(mktemp -d); : > $T/r.jsonl; f=eval/refutation-replay/score.py; python3 -I $f $T/r.jsonl >/dev/null; a=$?; python3 -I $f $T/r.jsonl --gate >/dev/null; b=$?; python3 -I $f $T 2>/dev/null; c=$?; python3 -I $f $T/r.jsonl >/dev/full 2>/dev/null; d=$?; echo "$a $b $c $d"'`
   exit: 0
   stdout: `0 2 2 120`
   mutation: this checks the docstring's claims against the code (an empty report with no labels file is `insufficient`: exit 0 without --gate, 2 with it; a directory is bad input, 2; a full stdout, 120). A change to score.py that maps the flush error to bad input prints `0 2 2 2`. The temp dir has no labels.tsv, so the real one is never read. Linux only (`/dev/full`).
4. run: `bash -c 'f=eval/refutation-replay; s=$(tr -s " \n" " " < $f/score.py); g=$(tr -s " \n" " " < $f/guard.py); l=$(tr -s " \n" " " < $f/label.py); n=0; for p in "Without --gate every verdict exits 0." "exits 120, Python" "rows must come from load()," "score() is not callable on raw report rows."; do printf "%s" "$s" | grep -qF -- "$p" || n=$((n+1)); done; for p in "unless the input is bad" "a closed stdout) ends in a traceback"; do printf "%s" "$s" | grep -qF -- "$p" && n=$((n+1)); done; for p in "is refused too: an over-refusal kept on purpose, never a leak." "The same leaves() check runs on the Glob"; do printf "%s" "$g" | grep -qF -- "$p" || n=$((n+1)); done; for p in "SystemExit and KeyboardInterrupt are not Exception" "not a positive integer"; do printf "%s" "$l" | grep -qF -- "$p" || n=$((n+1)); done; echo "missing=$n"'`
   exit: 0
   stdout: `missing=0`
   mutation: at ab174935 it prints `missing=10` (8 sentences absent, 2 old sentences present). Skipping edit 3 prints `missing=2`.
5. run: `bash -c 'a=$(git ls-files -s eval/refutation-replay/score.py eval/refutation-replay/guard.py eval/refutation-replay/label.py tests/refutation-replay-isolation.test.sh | cut -c1-6 | sort -u | paste -sd " " -); b=$(git ls-files -s tests/refutation-label-server.py | cut -c1-6); echo "$a $b"'`
   exit: 0
   stdout: `100755 100644`
   mutation: committing `label.py` at mode 644 prints `100644 100755 100644`.
6. run: `bash -c 'cs=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(cos-u4\): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "eval/refutation-replay/(score|guard|label)\.py|tests/refutation-label-server\.py|tests/refutation-replay-isolation\.test\.sh" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: committing an `eval/refutation-replay/labels.tsv` edit under a `(cos-u4): ` subject prints `1`.
7. run: `bash -c 'git status --porcelain -- eval/refutation-replay tests/refutation-label-server.py tests/refutation-replay-isolation.test.sh | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: an untracked `eval/refutation-replay/__pycache__/` (a Python run without `PYTHONDONTWRITEBYTECODE=1`) prints `1`; so does any uncommitted edit. Untracked files count here on purpose.
8. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms; about 280 s)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/refutation-replay-isolation.test.sh`; validate.sh reports `FAIL tests/refutation-replay-isolation.test.sh` (`tests/validate.sh:841-846`) and stdout is `1`. Run this after the commit, with no other unit's edits uncommitted in the tree.

## Pre-resolved context
- tdd: yes. Edits 6 to 8 first: criterion 1 goes red (S13); the new guard cases already pass (they pin current behaviour, proven by the `UP` mutation of criterion 2). Edits 1 to 5 turn criterion 1 and criterion 4 green.
- blast-radius: `score.py` is run by `run.sh` and `tests/refutation-replay.test.sh`, and read for `MIN_REAL` by `label.py` (`read_min_real`); `guard.py` is the hook command `run.sh` writes, tested by `tests/refutation-replay-isolation.test.sh` (g)/(g2); `label.py` is tested by `tests/refutation-label-server.py` S13/S15 through `tests/refutation-label.test.sh` (`tests/validate.sh:851-855`). No test pins any docstring sentence that changes here (checked with `git grep`).
- commit-message: fix(cos-u4): refutation-replay docstrings match behaviour; label.py refuses MIN_REAL below 1
- Measured at ab174935: `printf ... | python3 -I guard.py` exits 2 for `git log --grep=a:..`, `git log --format=%h:..`, Glob pattern `src/a:../*` and Grep glob `a:..`, and 0 for Glob pattern `src/a:b/*`. `score.py r.jsonl >&-` exits 0 (Python drops prints to a closed stdout); `| true` and `>/dev/full` exit 120 with "Exception ignored on flushing sys.stdout".
- The real `score.py` has `MIN_REAL = 30`, so the new `v < 1` check never fires on the real file; S15's threshold check (`d['min_real'] == sm.MIN_REAL`) is unaffected.
- The over-refusal is kept on purpose (plan Open Question 2): loosening a fail-closed guard needs its own reviewed unit.

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If a `before` block or anchor is not found exactly once, stop and report the current text. If the Edit tool is unavailable (`exists but is not enabled in this context`), use a `python3` heredoc that asserts the old text occurs exactly once before replacing it, and restore each file's mode afterwards (`chmod --reference` an untouched sibling). Never start `label.py serve` on the real files, never run `run.sh` without `--dry-run`, and never edit `labels.tsv`, `corpus.jsonl` or `report.jsonl`.
