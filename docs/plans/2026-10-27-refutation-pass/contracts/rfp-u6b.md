Unit: rfp-u6b

## Objective
Clear the replay-tooling advisory notes from the rfp-u2b, rfp-u2c, rfp-u2d and rfp-u2f reviews (plan Step 6,
items 3 to 6). Every change is under `eval/refutation-replay/` or its suites; nothing reads the real
`labels.tsv`, `corpus.jsonl` or `report.jsonl`.
1. **The label page's pointer rule counts from the click** (`label_page.html`). Today `lw` is created with
   `moved: false` when the POST resolves, so a pointer move made while the write is in flight is not counted:
   a deliberate click on card B, pointer moved to B during the POST and then held still, is dropped silently
   until the pointer moves again. The rule as the rfp-u2c fix contract states it ("the pointer has not left
   the click point of that write") is kept, and the code now follows it: `clickPt` carries its own `moved`
   flag from the click on, `pointerActed` updates both `lw` and `clickPt`, and the new `lw` copies
   `clickPt.moved`. No other rule changes: a stationary re-click is still dropped.
2. **Browser coverage** (`tests/refutation-label-browser.js`, `tests/refutation-label.test.sh`). B12 repeats
   its stationary re-click after the second and the third write. New B14: a vertical-only move during an
   in-flight write (POST delayed 400 ms with `page.route`) re-arms labelling, and after a write a wheel turn
   alone, with no mousemove off the click point, re-arms it. The suite's case count goes from 13 to 14.
3. **`score.py` bad input** exits 2 with one stderr line `score.py: bad input: <reason>` and no stdout, with
   or without `--gate`, for an unreadable report or labels file (a directory), a line that is not a JSON
   object, a non-numeric `num_turns` or `cost_usd`, and `--labels` with no file. Today each exits 1 with a
   traceback. New case (o). New case (p): a capped row whose id is foreign does not count (`capped` is over
   the scored ids, `score.py:64`, not over all rows).
4. **`guard.py`**: `-SObject`, `-G[O]` and `-L1,2:src/IO.c` are refused today because `BAD_OPT` treats any
   capital O in a short-option bundle as `-O`. `-S`, `-G` and `-L` take the rest of the token as their value,
   so the bundle scan stops at them: `-[^-SGL]*O`. `-RO<file>`, `-pO<file>` and `-pRO<file> -SObject` stay
   refused. New cases include `git log --grep=FOO` (allowed), which turns red under the widening mutant that
   lets a bundle span a dash. The module docstring states the bundle rule and the fail-closed wrapper.
5. **`build-corpus.py --refresh-claims`**, multi-match: new case (n), a row whose claim prefix matches two
   defects of its block exits 1 and writes nothing (`build-corpus.py:211`). No change to `build-corpus.py`.

No stamped path is touched (`eval/` and `tests/` only), so there is no version bump and no CHANGELOG entry
(constitution P3; as for rfp-u2b to rfp-u2f).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Units and order", "Step 6").
This file is the contract of record. rfp-u6a, rfp-u6b and rfp-u6c share no file and may go in any order; one
unit is mid-review at a time.

## Affected files
- `eval/refutation-replay/score.py` (anchor: line matching `MIN_REAL, MAX_MISSES, MAX_TURNS, MAX_UNANSWERED = 30, 1, 10, 0.20`, which stays byte-identical; mode stays 755)
- `eval/refutation-replay/guard.py` (anchor: line matching `BAD_OPT = re.compile(r'^(--ou|--no-ind|--ext|--textc|-[^-]*O)')`; mode stays 755)
- `eval/refutation-replay/label_page.html` (anchor: line matching `function pointerActed(e) {`)
- `tests/refutation-replay.test.sh` (anchor: line matching `# scorer fixtures: N real rows, M of them REFUTED with an artifact`; mode stays 755)
- `tests/refutation-replay-isolation.test.sh` (anchor: line matching `gb 0 'git diff -R -a src/a.sh'`; mode stays 755)
- `tests/refutation-label-browser.js` (anchor: line matching `// B13: focus. The page disables every label button while a POST is in flight, which drops focus in Chromium by itself,`)
- `tests/refutation-label.test.sh` (anchor: line matching `[ "$n" -eq 13 ] || { bad "B00 probe reported $n of 13 cases"; head -3 "$T/br.err"; }`)

## Ordered edits
Edits 1 to 19 were generated from spec-master's tested scratch payload (a clone at 57ec2d70). Applied in
order, they reproduce it byte for byte. Use the Write/Edit tools for every file edit.

1. file: `eval/refutation-replay/score.py`
   anchor: line matching `insufficient = fewer than MIN_REAL distinct real ids, or missing > 0.`
   before:
~~~
With --gate: exit 0 on pass, 1 on fail, 2 on insufficient.
insufficient = fewer than MIN_REAL distinct real ids, or missing > 0.
~~~
   after:
~~~
With --gate: exit 0 on pass, 1 on fail, 2 on insufficient.
A report or labels file that cannot be read or parsed (a directory, a line that is not a JSON object, a
non-numeric num_turns or cost_usd, --labels with no file) exits 2, with or without --gate, printing nothing
on stdout and one line on stderr: `score.py: bad input: <reason>`.
insufficient = fewer than MIN_REAL distinct real ids, or missing > 0.
~~~

2. file: `eval/refutation-replay/score.py`
   anchor: line matching `gate = '--gate' in argv`
   before:
~~~
def main(argv):
    gate = '--gate' in argv
~~~
   after:
~~~
def main(argv):
    try:
        return score(argv)
    except (OSError, ValueError, TypeError) as e:
        print('score.py: bad input: %s' % (' '.join(str(e).split()) or type(e).__name__), file=sys.stderr)
        return 2


def read_rows(report):
    rows = []
    if not os.path.exists(report):
        return rows
    with open(report, encoding='utf-8') as f:
        for n, l in enumerate(f, 1):
            if not l.strip():
                continue
            try:
                r = json.loads(l)
            except ValueError as e:
                raise ValueError('%s line %d: %s' % (report, n, e))
            if not isinstance(r, dict):
                raise ValueError('%s line %d: not a JSON object' % (report, n))
            rows.append(r)
    return rows


def score(argv):
    gate = '--gate' in argv
~~~

3. file: `eval/refutation-replay/score.py`
   anchor: line matching `i = args.index('--labels')`
   before:
~~~
        i = args.index('--labels')
        labels_file = args[i + 1]
~~~
   after:
~~~
        i = args.index('--labels')
        if i + 1 >= len(args):
            raise ValueError('--labels needs a file')
        labels_file = args[i + 1]
~~~

4. file: `eval/refutation-replay/score.py`
   anchor: line matching `for l in open(labels_file):`
   before:
~~~
        for l in open(labels_file):
~~~
   after:
~~~
        for l in open(labels_file, encoding='utf-8'):
~~~

5. file: `eval/refutation-replay/score.py`
   anchor: line matching `rows = [json.loads(l) for l in open(report) if l.strip()] if os.path.exists(report) else []`
   before:
~~~
    rows = [json.loads(l) for l in open(report) if l.strip()] if os.path.exists(report) else []
~~~
   after:
~~~
    rows = read_rows(report)
~~~

6. file: `eval/refutation-replay/guard.py`
   anchor: line matching `other files (`--output`, `-O`, `--no-index`, `--ext-diff`, `--textconv`, abbreviations included).`
   before:
~~~
  other files (`--output`, `-O`, `--no-index`, `--ext-diff`, `--textconv`, abbreviations included).
~~~
   after:
~~~
  other files (`--output`, `--no-index`, `--ext-diff`, `--textconv`, abbreviations included, and `-O`,
  also inside a bundle of short options such as `-RO<file>`). In a bundle, the value-taking `-S`, `-G`
  and `-L` take the rest of the token as their value, so a capital O after them (`-SObject`) is allowed.
~~~

7. file: `eval/refutation-replay/guard.py`
   anchor: line matching `Every call appends one line to <log-file>, so run.sh can tell that the hook is wired.`
   before:
~~~
Every call appends one line to <log-file>, so run.sh can tell that the hook is wired.
~~~
   after:
~~~
Every call appends one line to <log-file>, so run.sh can tell that the hook is wired. Any unexpected
exception also exits 2 (fail closed): exit 1 is a non-blocking hook error that would let the call go ahead.
~~~

8. file: `eval/refutation-replay/guard.py`
   anchor: line matching `BAD_OPT = re.compile(r'^(--ou|--no-ind|--ext|--textc|-[^-]*O)')`
   before:
~~~
BAD_OPT = re.compile(r'^(--ou|--no-ind|--ext|--textc|-[^-]*O)')
~~~
   after:
~~~
BAD_OPT = re.compile(r'^(--ou|--no-ind|--ext|--textc|-[^-SGL]*O)')
~~~

9. file: `eval/refutation-replay/label_page.html`
   anchor: line matching `var lw = null, clickPt = null; // lw: the last written card and the pointer point of that click; moved turns true once the pointer or wheel has acted since`
   before:
~~~
var lw = null, clickPt = null; // lw: the last written card and the pointer point of that click; moved turns true once the pointer or wheel has acted since
~~~
   after:
~~~
var lw = null, clickPt = null; // clickPt: the point of the label click in flight; lw: the last written card and that click's point; moved turns true once the pointer leaves the point or the wheel turns, counted from the click, so a move made while the write is in flight counts
~~~

10. file: `eval/refutation-replay/label_page.html`
   anchor: line matching `lw = clickPt === null ? null : { id: id, x: clickPt.x, y: clickPt.y, moved: false };`
   before:
~~~
        lw = clickPt === null ? null : { id: id, x: clickPt.x, y: clickPt.y, moved: false };
~~~
   after:
~~~
        lw = clickPt === null ? null : { id: id, x: clickPt.x, y: clickPt.y, moved: clickPt.moved }; // mut:inflight
~~~

11. file: `eval/refutation-replay/label_page.html`
   anchor: line matching `clickPt = { x: e.clientX, y: e.clientY };`
   before:
~~~
      clickPt = { x: e.clientX, y: e.clientY };
~~~
   after:
~~~
      clickPt = { x: e.clientX, y: e.clientY, moved: false };
~~~

12. file: `eval/refutation-replay/label_page.html`
   anchor: line matching `if (lw !== null && (e.type === 'wheel' || e.clientX !== lw.x || e.clientY !== lw.y)) lw.moved = true;`
   before:
~~~
  if (lw !== null && (e.type === 'wheel' || e.clientX !== lw.x || e.clientY !== lw.y)) lw.moved = true;
~~~
   after:
~~~
  [lw, clickPt].forEach(function (p) {
    if (p !== null && (e.type === 'wheel' || e.clientX !== p.x || e.clientY !== p.y)) p.moved = true;
  });
~~~

13. file: `tests/refutation-replay.test.sh`
   anchor: line matching `# scorer fixtures: N real rows, M of them REFUTED with an artifact`
   before:
~~~

# scorer fixtures: N real rows, M of them REFUTED with an artifact
~~~
   after:
~~~

# (n) rfp-u6b: a row whose claim matches two defects of its block fails closed too: exit 1, nothing written
mk3="$tmp/markers3"; mkdir -p "$mk3"; cp "$mk/u9.pass" "$mk3/"
printf 'FAIL u9 2026-01-03T00:00:00Z\ntier: haiku\n- src/a.sh:2 x is unquoted, so a space splits it\n- src/a.sh:1 no guard on empty input\n- src/a.sh:1 no guard on empty input, and none on a blank one\n\n' > "$mk3/u9.fail"
cp "$c" "$r3/two.jsonl"; h5="$(md5sum < "$r3/two.jsonl")"
o6="$(python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk3" --out "$r3/two.jsonl" --refresh-claims)"; rc6=$?
if [ "$rc6" = 1 ] && printf '%s' "$o6" | grep -q '^corpus: refreshed rows=2 longer=0 errors=1$' \
   && printf '%s' "$o6" | grep -q ': 2 matching defects in its FAIL block$' && [ "$(md5sum < "$r3/two.jsonl")" = "$h5" ]; then
  ok "(n) --refresh-claims refuses a row that matches two defects and writes nothing"
else
  bad "(n) rc6=$rc6 $o6"
fi

# scorer fixtures: N real rows, M of them REFUTED with an artifact
~~~

14. file: `tests/refutation-replay.test.sh`
   anchor: line matching `# (j) run.sh --dry-run: one line per group, sonnet, 10 turns, read-only tools, no claude run`
   before:
~~~

# (j) run.sh --dry-run: one line per group, sonnet, 10 turns, read-only tools, no claude run
~~~
   after:
~~~

# (o) rfp-u6b: a report or labels file that cannot be read or parsed exits 2 with one stderr line and no stdout,
# with or without --gate, never a traceback
bi="$tmp/bi"; mkdir -p "$bi/dir"; printf '# id\tlabel\nr1\treal\n' > "$bi/labels.tsv"
printf '{"id": "r1", "answer": "CONFIRMED"\n' > "$bi/trunc.jsonl"
printf '[1, 2]\n' > "$bi/list.jsonl"
printf '{"id": "r1", "answer": "CONFIRMED", "num_turns": "abc"}\n' > "$bi/turns.jsonl"
printf '{"id": "r1", "answer": "CONFIRMED", "num_turns": 5}\n' > "$bi/ok.jsonl"
printf '{"id": "r1", "answer": "CONFIRMED", "num_turns": [5]}\n' > "$bi/tlist.jsonl"
obad=""
sb() { # <label> <score.py args>...
  local lab="$1" out err rc; shift
  out="$(python3 "$d/score.py" "$@" 2>"$bi/err")"; rc=$?; err="$(cat "$bi/err")"
  if [ "$rc" != 2 ] || [ -n "$out" ] || [ "$(printf '%s\n' "$err" | grep -c .)" != 1 ] \
     || ! printf '%s' "$err" | grep -q '^score.py: bad input: '; then obad="$obad [$lab rc=$rc out=${out:0:60} err=${err:0:80}]"; fi
}
sb dir "$bi/dir"
sb dir-gate "$bi/dir" --gate
sb truncated "$bi/trunc.jsonl" --gate
sb not-object "$bi/list.jsonl"
sb turns "$bi/turns.jsonl" --gate
sb turns-list "$bi/tlist.jsonl"
sb labels-dir "$bi/ok.jsonl" --labels "$bi/dir" --gate
sb labels-no-file "$bi/ok.jsonl" --gate --labels
[ -z "$obad" ] && ok "(o) unreadable or malformed input exits 2 with one stderr line" || bad "(o)$obad"
# (p) rfp-u6b: capped counts the scored ids, not every row: a foreign capped row neither counts nor fails the gate
mkrep "$tmp/s7" 30 0 9 0
printf '{"id": "x1", "answer": "NONE", "artifact": "", "num_turns": 9, "cost_usd": 0.1, "subtype": "error_max_turns", "is_error": true}\n' >> "$tmp/s7/report.jsonl"
o="$(sc "$tmp/s7")"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$o" | grep -q '^replay-gate: pass real=30 .* foreign=1 capped=0$' \
  && ok "(p) a capped row with an unlabelled id is foreign, not capped" || bad "(p) rc=$rc $o"

# (j) run.sh --dry-run: one line per group, sonnet, 10 turns, read-only tools, no claude run
~~~

15. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `gr 2 'tool_input string' '{"tool_name": "Read", "tool_input": "x"}'`
   before:
~~~
gb 0 'git diff -R -a src/a.sh'
gr 2 'tool_input string' '{"tool_name": "Read", "tool_input": "x"}'
~~~
   after:
~~~
gb 0 'git diff -R -a src/a.sh'
# rfp-u6b: the value of a bundled -S, -G or -L may hold a capital O; a long option never counts as a bundle
gb 0 'git log -SObject'
gb 0 'git log -pSObject'
gb 0 'git log -G[O]'
gb 0 'git log -L1,2:src/IO.c'
gb 0 'git log --grep=FOO'
gb 2 'git log -pRO/abs/x -SObject'
gr 2 'tool_input string' '{"tool_name": "Read", "tool_input": "x"}'
~~~

16. file: `tests/refutation-label-browser.js`
   anchor: line matching `await step(st, 'detail-2 click after the pointer moved', async () => {`
   before:
~~~
  await under(ids[2]);
  await step(st, 'detail-2 click after the pointer moved', async () => {
~~~
   after:
~~~
  await under(ids[2]);
  await step(st, 'plain click, same point, after the second write', async () => { await st.page.mouse.click(p.x, p.y); });
  unknownNow(ids[2], 'a stationary re-click after the second write');
  await step(st, 'detail-2 click after the pointer moved', async () => {
~~~

17. file: `tests/refutation-label-browser.js`
   anchor: line matching `await noteWrite(st, ids[2], p.x, p.y);`
   before:
~~~
    await noteWrite(st, ids[2], p.x, p.y);
  });
~~~
   after:
~~~
    await noteWrite(st, ids[2], p.x, p.y);
  });
  await under(ids[3]);
  await step(st, 'plain click, same point, after the third write', async () => { await st.page.mouse.click(p.x, p.y); });
  unknownNow(ids[3], 'a stationary re-click after the third write');
  await st.page.close();
}

// B14 (rfp-u6b): the pointer rule counts from the click. A vertical-only move made while the write is in flight
// re-arms labelling (B sits above A, so a change in A's card cannot shift B), and after a write a wheel turn
// alone, with no mousemove off the click point, re-arms it. Each click here is a bare down and up: mouse.click()
// would first send a mousemove, which re-arms labelling by itself.
async function b14() {
  extWrite(new Map(Array.from(readLabels().keys(), (i) => [i, 'unknown'])));
  const st = await newPage(url, { width: 1280, height: 800 });
  await st.page.route('**/label', async (route) => { await new Promise((res) => setTimeout(res, 400)); await route.continue(); });
  const ids = await shown(st);
  const A = ids[1], B = ids[0];
  await st.page.evaluate((i) => window.__p.bring(i, 0.7), A);
  await settle(st);
  const a = await st.page.evaluate((i) => window.__p.btn(i, 'real'), A);
  const b = await st.page.evaluate((i) => window.__p.btn(i, 'real'), B);
  if (!a || !a.valid || !b || !b.valid || a.x !== b.x || !(b.y < a.y)) throw new Error('fixture: no vertical pair ' + JSON.stringify([a, b]));
  await st.page.mouse.move(2, 2);
  await step(st, 'write A, then move straight up to B while the write is in flight', async () => {
    await st.page.mouse.click(a.x, a.y);
    st.model.set(A, 'real');
    await noteWrite(st, A, a.x, a.y);
    if ((await stateOf(st)).pending !== '1') throw new Error('fixture: the write was not in flight during the move');
    await st.page.mouse.move(b.x, b.y);
  });
  const hb = await st.page.evaluate(([x, y]) => window.__p.hitLbl(x, y), [b.x, b.y]);
  if (!hb || hb.id !== B) throw new Error('fixture: B is not under the pointer after the write, ' + JSON.stringify(hb));
  await step(st, 'click B without moving again', async () => {
    await st.page.mouse.down();
    await st.page.mouse.up();
    st.model.set(B, 'real');
  });
  const pt = await st.page.evaluate(() => {
    const d = window.__p.ev.filter((e) => e[0] === 'mousedown').pop();
    return { x: d[1], y: d[2], n: window.__p.ev.length };
  });
  let h = null;
  for (let i = 0; i < 80 && (!h || h.id === A || h.id === B); i++) {
    await st.page.mouse.wheel(0, 40);
    await settle(st);
    h = await st.page.evaluate(([x, y]) => window.__p.hitLbl(x, y), [b.x, b.y]);
  }
  if (!h || h.id === A || h.id === B) throw new Error('fixture: the wheel brought no unlabelled card under the pointer');
  const off = await st.page.evaluate(([n, x, y]) => window.__p.ev.slice(n).filter((e) => e[0] === 'mousemove' && (e[1] !== x || e[2] !== y)).length, [pt.n, pt.x, pt.y]);
  if (off !== 0) throw new Error('fixture: the pointer moved off the click point, so the wheel is not what re-armed labelling');
  await step(st, 'click the card the wheel brought under the still pointer', async () => {
    await st.page.mouse.down();
    await st.page.mouse.up();
    st.model.set(h.id, h.value);
  });
~~~

18. file: `tests/refutation-label-browser.js`
   anchor: line matching `['B13 a label button never holds focus, with or without the page disabling it', b13],`
   before:
~~~
  ['B13 a label button never holds focus, with or without the page disabling it', b13],
  ['B11 no page or console errors', b11]];
~~~
   after:
~~~
  ['B13 a label button never holds focus, with or without the page disabling it', b13],
  ['B14 a move during an in-flight write, or a wheel turn alone, re-arms labelling', b14],
  ['B11 no page or console errors', b11]];
~~~

19. file: `tests/refutation-label.test.sh`
   anchor: line matching `[ "$n" -eq 13 ] || { bad "B00 probe reported $n of 13 cases"; head -3 "$T/br.err"; }`
   before:
~~~
  [ "$n" -eq 13 ] || { bad "B00 probe reported $n of 13 cases"; head -3 "$T/br.err"; }
~~~
   after:
~~~
  [ "$n" -eq 14 ] || { bad "B00 probe reported $n of 14 cases"; head -3 "$T/br.err"; }
~~~
20. command: `bash -c 'bash tests/refutation-replay.test.sh >/dev/null; a=$?; bash tests/refutation-replay-isolation.test.sh >/dev/null; b=$?; LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh >/dev/null 2>&1; echo "replay=$a isolation=$b label=$?"'` (Bash tool timeout 600000 ms)
    expect: 0, stdout `replay=0 isolation=0 label=0`
21. command: `git add eval/refutation-replay/score.py eval/refutation-replay/guard.py eval/refutation-replay/label_page.html tests/refutation-replay.test.sh tests/refutation-replay-isolation.test.sh tests/refutation-label-browser.js tests/refutation-label.test.sh && git commit -m "fix(rfp-u6b): the label page counts a move made during a write; score.py fails cleanly on bad input; guard.py allows -S/-G/-L values with a capital O"`
    expect: 0
    Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it.
    A fix round is a new commit whose subject keeps `(rfp-u6b): `.

## Do NOT touch
- `eval/refutation-replay/labels.tsv`, `corpus.jsonl` (ground truth) and `report.jsonl` (Gate G run 2
  evidence, committed at ce8b7511): never edit, move or regenerate them (criteria 5 and 6)
- `eval/refutation-replay/label.py`, `build-corpus.py`, `run.sh`, `README.md` (no change needed; criterion 5)
- `hooks/`, `bin/`, `.claude/bin/`, every gate script (criterion 5)
- `agents/`, `templates/`, `adapters/`, `CONTEXT.md`, `docs/` (rfp-u6a's and rfp-u6c's; criterion 5)
- Never run `eval/refutation-replay/run.sh` without `--dry-run`, and never run `label.py serve` against the
  real `labels.tsv` or `corpus.jsonl`. The suites build their fixtures under `mktemp -d`. Mutations go in a
  scratch clone, never in this working tree.

## Acceptance criteria
1. run: `bash -c 'out=$(LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh 2>&1); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") b14=$(printf "%s\n" "$out" | grep -c "^ok - B14 ") rc=$rc"'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `fails=0 b14=1 rc=0`
   mutation: each of these, applied alone to `label_page.html` in a scratch clone, turns one case red, so stdout is `fails=1 b14=0 rc=1` or `fails=1 b14=1 rc=1` (spec-master ran all six): the page at 57ec2d70 (B14); `moved: clickPt.moved` back to `moved: false` (B14); `lw = …` to `if (lw === null) lw = …` (B12, the stationary re-click after the second write); `moved: clickPt.moved || !!(lw && lw.moved)` (B12); deleting the `wheel` listener (B14, the wheel step); comparing only `clientX` in `pointerActed` (B14, the vertical move). `LABEL_UI_REQUIRE_BROWSER=1` makes a run with no Chromium fail instead of skipping.
2. run: `bash -c 'bash tests/refutation-replay.test.sh >/dev/null; a=$?; bash tests/refutation-replay-isolation.test.sh >/dev/null; echo "replay=$a isolation=$?"'`
   exit: 0
   stdout: `replay=0 isolation=0`
   mutation: in a scratch clone, each alone makes one suite red (spec-master ran all): `score.py` at 57ec2d70 (case (o): `dir rc=1 … Traceback`); `capped = sum(1 for r in rows if …)` (case (p): `foreign=1 capped=1`, rc 1); dropping `TypeError` from `score.py`'s except tuple (case (o): `turns-list rc=1`); `if len(hits) != 1:` to `if len(hits) < 1:` in `build-corpus.py` (case (n): `rc6=0`); `BAD_OPT`'s bundle term as `-[^-]*O` (the old code), `-.*O`, `-[^SGL]*O` (a bundle spans a dash: `git log --grep=FOO rc=2`), `-[^-GL]*O` or `-[^-SG]*O` (case (g2) red each time); `-[^-SGLR]*O` (`git diff -RO/abs/file rc=0`).
3. run: `bash -c 'e=$(python3 eval/refutation-replay/score.py eval/refutation-replay --gate 2>&1 >/dev/null); rc=$?; echo "rc=$rc lines=$(printf "%s\n" "$e" | grep -c .) head=${e%%:*}"'`
   exit: 0
   stdout: `rc=2 lines=1 head=score.py`
   mutation: `score.py` at 57ec2d70 prints `rc=1 lines=8 head=Traceback (most recent call last)` (spec-master ran it). The report path is the directory itself, so the labels file looked up beside it is `eval/labels.tsv`, which does not exist: the command never reads the real `labels.tsv`.
4. run: `bash -c 'r=; for c in "git log -SObject" "git log --grep=FOO" "git diff -RO/x"; do python3 -c "import json,sys;print(json.dumps({\"tool_name\":\"Bash\",\"tool_input\":{\"command\":sys.argv[1]}}))" "$c" | python3 eval/refutation-replay/guard.py . /dev/null 2>/dev/null; r="$r$?"; done; echo "guard=$r"'`
   exit: 0
   stdout: `guard=002`
   mutation: `guard.py` at 57ec2d70 prints `guard=202` (spec-master ran it).
5. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u6b): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "eval/refutation-replay/(score|guard)\.py|eval/refutation-replay/label_page\.html|tests/refutation-replay(-isolation)?\.test\.sh|tests/refutation-label\.test\.sh|tests/refutation-label-browser\.js" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: commit an edit to `eval/refutation-replay/label.py` under a `(rfp-u6b): ` subject; stdout is `1` (spec-master ran it). With no `(rfp-u6b): ` commit, stdout is `no-commits`, exit 1.
6. run: `bash -c 'd=$(git diff --name-only 57ec2d70 -- eval/refutation-replay/labels.tsv eval/refutation-replay/corpus.jsonl eval/refutation-replay/report.jsonl | wc -l | tr -d " "); s=$(git status --porcelain --untracked-files=no -- . ":!.claude/agent-memory" | wc -l | tr -d " "); echo "truth-diff=$d dirty=$s"'`
   exit: 0
   stdout: `truth-diff=0 dirty=0`
   mutation: any edit to `labels.tsv`, `corpus.jsonl` or `report.jsonl`, committed or not, makes `truth-diff` non-zero; an uncommitted edit also makes `dirty` non-zero (spec-master ran it with a line appended to `labels.tsv`: `truth-diff=1 dirty=1`). 57ec2d70 is the commit this contract was written at.

## Pre-resolved context
- The validate wrapper needs no edit: it already runs all three suites (`tests/validate.sh:832-858`).
- spec-master applied edits 1 to 19 to a clone of 57ec2d70 and committed them under a `(rfp-u6b): ` subject:
  every hunk applies once; edit 20 printed `replay=0 isolation=0 label=0`; criteria 1 to 5 and every mutation
  above behave as stated. The new `score.py` prints the same `replay-gate: pass real=41 … capped=0` line, rc 0,
  as the committed one on the real run-2 `report.jsonl` (read-only), so rfp-u3's criterion 8 is unaffected.
- Chromium and playwright are found here at
  `$HOME/miniforge3/envs/claude_voice/lib/python3.11/site-packages/playwright/driver/package`; the label suite
  runs in about 30 s.
- B14's clicks are bare `mouse.down()`/`mouse.up()`: `mouse.click(x, y)` first sends a mousemove, even to the
  pointer's current point, which re-arms labelling by itself and made a first draft of B14 pass on the old
  page. B sits above A because labelling A changes A's card height and shifts every card below it. The wheel
  step scrolls in 40 px turns until an unlabelled card's label button is under the still pointer, and checks
  that no mousemove left the click point, so the wheel is what re-arms.
- `git log -SObject`, `-pSObject` and `-pSfooO<file>` on git 2.43 run a pickaxe search and read no orderfile,
  so allowing them leaks nothing. `-n`, `-U`, `-M`, `-C` and the other short options stay in the scanned set:
  a capital O after them is still refused (an over-block, the safe direction).
- `score.py`'s exit 2 on bad input shares the code `--gate` uses for `insufficient`. Both are "not a pass";
  stdout tells them apart (one `replay-gate:` line versus none). `label.py` imports `score.py` only for
  `MIN_REAL`, which stays byte-identical.
- `bin/contract-score.js --rubric=v2 --shape=lead` scores this file below 7, so the contract-score guard
  dispatches it on `sonnet`.

## Escalation
If a hunk's `before` text is not found exactly once, stop and report the current text. If Chromium cannot be
launched, criterion 1 cannot pass: report it, do not drop `LABEL_UI_REQUIRE_BROWSER`. If the label suite
fails only on B14's `fixture:` lines (the layout differs on this machine), report the line; do not loosen the
fixture checks. If a gate blocks a command, report it and wait. Anything outside "Affected files" goes in your
report as a proposal.
