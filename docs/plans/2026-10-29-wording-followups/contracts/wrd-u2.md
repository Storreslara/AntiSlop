Unit: wrd-u2

## Objective
Make two `eval/refutation-replay/` comments say what the code does, and cap one copied message, as reported in the cos-u4 PASS notes: (a) `label.py`'s comment in `read_min_real` says a `score.py` that calls `sys.exit()` at import makes label.py exit and "prints nothing"; that is false for `sys.exit('<text>')`, which prints the text to stderr and exits 1 (measured); (b) the refusal copies the first line of the exception message with no length cap; cut it at 160 characters followed by `...`, with a test; (c) `score.py`'s `score()` docstring says "score() is not callable on raw report rows"; raw rows score fine when `num_turns` and `cost_usd` are already numbers (measured), so say that.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-29-wording-followups.md` (Step 2). This file is the contract of record. Dispatch after wrd-u1 has PASSed (one unit under review at a time); it touches no `.claude/` file and runs no `--update`. Implementer tier: sonnet or above.

## Affected files
- `eval/refutation-replay/label.py` (anchor: line matching `        # SystemExit and KeyboardInterrupt are not Exception: a score.py that calls sys.exit() at import ends`; mode stays 755)
- `eval/refutation-replay/score.py` (anchor: line matching `    score() is not callable on raw report rows.`; mode stays 755)
- `tests/refutation-label-server.py` (anchors: line matching `                       ('MIN_REAL = 0', 'MIN_REAL = 0\n'), ('MIN_REAL = -5', 'MIN_REAL = -5\n')):`; line matching `            check('RuntimeError: boom' in out, 'score.py with an import-time error: no message: %r' % out[:160])`; mode stays 644)

These are the only paths in scope.

## Ordered edits
Edits 1 to 4 use the Edit tool, never a Bash heredoc. spec-master applied these edits to a scratch clone of f566aeef and ran every criterion and mutation below there.

1. file: `eval/refutation-replay/label.py`
   anchor: line matching `        # SystemExit and KeyboardInterrupt are not Exception: a score.py that calls sys.exit() at import ends`
   indent: 8
   before:
~~~
        # SystemExit and KeyboardInterrupt are not Exception: a score.py that calls sys.exit() at import ends
        # label.py with that exit code and prints nothing.
        first = (str(e).strip().splitlines() or [''])[0]
~~~
   after:
~~~
        # SystemExit and KeyboardInterrupt are not Exception, so they are not caught here: a score.py that calls
        # sys.exit() at import ends label.py. sys.exit() and sys.exit(<int>) print nothing; sys.exit('<text>')
        # prints the text to stderr and exits 1.
        first = (str(e).strip().splitlines() or [''])[0]
        if len(first) > 160: first = first[:160] + '...'  # the refusal stays one short line (wrd-u2)
~~~

2. file: `eval/refutation-replay/score.py`
   anchor: line matching `    score() is not callable on raw report rows.`
   indent: 4
   before:
~~~
    rows must come from load(), which converts num_turns and cost_usd of every labelled row in place:
    score() is not callable on raw report rows.
~~~
   after:
~~~
    score() needs num_turns and cost_usd as numbers on the labelled rows. load() converts both in place on
    every labelled row, so pass rows from load(), or rows that already hold both as numbers.
~~~

3. file: `tests/refutation-label-server.py`
   anchor: line matching `                       ('MIN_REAL = 0', 'MIN_REAL = 0\n'), ('MIN_REAL = -5', 'MIN_REAL = -5\n')):`
   indent: 23
   before:
~~~
                       ('MIN_REAL = 0', 'MIN_REAL = 0\n'), ('MIN_REAL = -5', 'MIN_REAL = -5\n')):
~~~
   after:
~~~
                       ('MIN_REAL = 0', 'MIN_REAL = 0\n'), ('MIN_REAL = -5', 'MIN_REAL = -5\n'),
                       ('a long import-time message', "MIN_REAL = 30\nraise RuntimeError('x' * 500)\n")):
~~~
   The `\n` are the two characters backslash and `n` inside Python string literals, as in the lines around it.

4. file: `tests/refutation-label-server.py`
   anchor: line matching `            check('RuntimeError: boom' in out, 'score.py with an import-time error: no message: %r' % out[:160])`
   insert-after:
~~~
        if name == 'a long import-time message':  # wrd-u2: the copied message is cut at 160 characters
            check(('x' * 160 + '...') in out and ('x' * 161) not in out, 'score.py with a long message: not cut at 160: %r' % out[:300])
~~~
   The new case runs inside case S13's loop, so the suite still reports 16 cases; the loop's existing checks (exit 2, one line, no traceback) apply to it too.

5. command: `git add eval/refutation-replay/label.py eval/refutation-replay/score.py tests/refutation-label-server.py && git commit -m "fix(wrd-u2): label.py caps the copied score.py message; label and score comments say what the code does"`
   expect: 0
   Run `git status --short --untracked-files=all` first. If any file outside "Affected files" is modified or untracked (a `__pycache__/` directory under `eval/` included), stop and report it.

## Do NOT touch
- `eval/refutation-replay/labels.tsv`, `eval/refutation-replay/corpus.jsonl`, `eval/refutation-replay/report.jsonl`
- `eval/refutation-replay/run.sh` (never run it without `--dry-run`; this unit needs no run of it at all), `eval/refutation-replay/label_page.html`, every other file under `eval/`
- `hooks/`, `bin/`, `.claude/`, `docs/`, `tests/validate.sh`, `tests/refutation-label.test.sh`
- never start `label.py serve` against the real `eval/refutation-replay/` files; the test suite starts it only against temporary fixtures

## Acceptance criteria
1. run: `bash -c 'out=$(python3 -B tests/refutation-label-server.py 2>&1); rc=$?; echo "ok=$(printf "%s\n" "$out" | grep -c "^ok - S") fail=$(printf "%s\n" "$out" | grep -c "^FAIL - ") rc=$rc"'`
   exit: 0
   stdout: `ok=16 fail=0 rc=0`
   mutation: with `eval/refutation-replay/label.py` as at f566aeef and the new test file, S13 fails with `score.py with a long message: not cut at 160` and the line is `ok=15 fail=1 rc=1` (spec-master ran it).
2. run: `bash -c 'f=eval/refutation-replay/label.py; g=eval/refutation-replay/score.py; echo "old=$(grep -cF "label.py with that exit code and prints nothing" $f) new=$(grep -cF "sys.exit(<int>) print nothing; sys.exit(" $f) cap=$(grep -cF "if len(first) > 160: first = first[:160] + " $f) raw=$(grep -cF "not callable on raw report rows" $g) num=$(grep -cF "or rows that already hold both as numbers" $g)"'`
   exit: 0
   stdout: `old=0 new=1 cap=1 raw=0 num=1`
   mutation: skipping edit 1 prints `old=1 new=0 cap=0`; skipping edit 2 prints `raw=1 num=0`.
3. run: `bash -c 'd=$(mktemp -d); cp eval/refutation-replay/label.py "$d"/; for s in "sys.exit()" "sys.exit(3)" "sys.exit(\"boom\")"; do printf "import sys\n%s\n" "$s" > "$d/score.py"; o=$(python3 -B -I -c "import sys; sys.path.insert(0, sys.argv[1]); import label; label.read_min_real()" "$d" 2>&1); echo "rc=$? out=$o"; done'`
   exit: 0
   stdout: `rc=0 out=` then `rc=3 out=` then `rc=1 out=boom`
   mutation: none for the comment text (this pins the behaviour the edit-1 comment states); a label.py that caught SystemExit and refused with exit 2 would print `rc=2 out=label: ...`-style lines instead of these three. The copy runs in its own `mktemp -d` directory, so no `__pycache__` lands under `eval/`.
4. run: `bash -c 'a=(); for r in "{\"id\": \"a\", \"num_turns\": 3, \"cost_usd\": 0.5}" "{\"id\": \"a\", \"num_turns\": \"3\", \"cost_usd\": \"0.5\"}" "{\"id\": \"a\"}"; do a+=("$(python3 -B -I -c "import json, sys; sys.path.insert(0, \"eval/refutation-replay\"); import score as s; print(\"rc=%s\" % s.score(None, {\"a\": \"real\"}, [json.loads(sys.argv[1])]), file=sys.stderr)" "$r" 2>&1 >/dev/null | tail -n1 | cut -d: -f1)"); done; echo "${a[*]}"'`
   exit: 0
   stdout: `rc=0 TypeError KeyError`
   mutation: none for the docstring text (this pins the behaviour the edit-2 docstring states: a raw row with numeric values scores, string values raise TypeError, missing values raise KeyError). score()'s own gate line goes to stdout, which the command discards; the last stderr line is either `rc=<code>` or the exception's `<Name>: ...` line.
5. run: `bash -c 'git ls-files -s eval/refutation-replay/label.py eval/refutation-replay/score.py tests/refutation-label-server.py | cut -c1-6 | tr "\n" " "'`
   exit: 0
   stdout: `100755 100755 100644 `
   mutation: committing label.py at mode 644 prints `100644 100755 100644 `.
6. run: `bash -c 'cs=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(wrd-u2\): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; o=$(for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "eval/refutation-replay/label\.py|eval/refutation-replay/score\.py|tests/refutation-label-server\.py" | wc -l | tr -d " "); u=$(git status --porcelain --untracked-files=all -- eval tests/refutation-label-server.py | wc -l | tr -d " "); echo "out=$o dirty=$u"'`
   exit: 0
   stdout: `out=0 dirty=0`
   mutation: committing an edit to `eval/refutation-replay/labels.tsv` under a `(wrd-u2): ` subject prints `out=1`; a stray `eval/refutation-replay/__pycache__/` prints `dirty=1`.
7. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms; about 480 s)
   exit: 0
   stdout: `0`
   mutation: reverting edit 1 alone makes `tests/refutation-label.test.sh` fail inside validate.sh (its server suite runs the new case) and stdout is `1`. Run this after the commit, with no other unit's edits uncommitted in the tree. Lane C4.1a is known to flake: if it is the only failure, re-run validate once and report both runs.

## Pre-resolved context
- tdd: yes. After edits 3 and 4 alone, criterion 1 prints `ok=15 fail=1 rc=1` (red); edit 1 turns it green.
- blast-radius: `read_min_real` is called once, from `serve` (before any socket is bound). Its refusal reaches the user through `main`'s `print('label: ' + ...)` of the first line of the error. `score()` is called from `score.py`'s own main and imported by `tests/refutation-label-server.py` only for `MIN_REAL`. The server suite runs inside `tests/refutation-label.test.sh`, which `tests/validate.sh` runs at the `== refutation-label:` lane (it also takes a before/after snapshot of `eval/refutation-replay/`).
- Measured on f566aeef: `sys.exit()` exits 0 and prints nothing, `sys.exit(3)` exits 3 and prints nothing, `sys.exit("boom")` prints `boom` to stderr and exits 1; `score()` on a raw row with numeric `num_turns` and `cost_usd` returns 0, with string values raises TypeError, with neither raises KeyError.
- `python3 -I` ignores `PYTHONDONTWRITEBYTECODE`; every Python command in this unit uses `-B`, or a `__pycache__/` appears under `eval/refutation-replay/` (spec-master hit this once while measuring and removed its own file).
- commit-message: fix(wrd-u2): label.py caps the copied score.py message; label and score comments say what the code does
- Measured in a scratch clone of f566aeef with wrd-u1, wrd-u2 and wrd-u3 applied, committed: criteria 1 to 6 as stated; `bash tests/refutation-label.test.sh` exit 0 in 37 s; full validate exit 0, OK=3442 FAIL=0 WARN=2.
- Gate: if `writer-scope-gate.sh` blocks the stop naming a path listed above, it is a false positive. Report the block verbatim and wait; do not run the `git checkout` it suggests.

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If a `before` block or an anchor is not found exactly once, stop and report the current text. If the Edit tool is unavailable (`exists but is not enabled in this context`), use a `python3 -B` heredoc that asserts the old text occurs exactly once before replacing it, and restore the modes afterwards (`chmod 755` on label.py and score.py, `chmod 644` on the test). Never touch `labels.tsv`, `corpus.jsonl` or `report.jsonl`, and never edit `tests/validate.sh` or `tests/refutation-label.test.sh` to make a criterion pass.
