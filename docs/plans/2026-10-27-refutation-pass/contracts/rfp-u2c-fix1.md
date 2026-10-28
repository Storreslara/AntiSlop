Unit: rfp-u2c

## Objective
Close the one defect that failed review 1 of rfp-u2c: a human double-click, or a quick second click, on a label button
must never write a label onto a card the human did not aim at. Also close the test-strength gaps the reviewer
measured (`move()`'s on-screen clause, the mousedown `preventDefault` and `blur()`), correct two gaps in the original
contract (criterion 3 could not run, and a `score.py` fallback could hide a missing `score.py`), and take the cheap
non-blocking notes (clean port refusal, truncated Origin in the log, README wording for linked worktrees).
This is a fix contract for the same `Unit: rfp-u2c`; everything else in the original contract stays in force.

## Retrieval
Fast path, no tracker issue. Original contract: `docs/plans/2026-10-27-refutation-pass/contracts/rfp-u2c.md`.
Plan: `docs/plans/2026-10-27-refutation-pass.md` ("Step 2c"). Reviewed range of the first attempt: `219fc24f..c0010804`
(commits `f10c894f`, `c0010804`). The defect text is quoted in this contract; the lead-programmer opens nothing under
the reviewed-markers directory. The implementer reads this file; where it and the original contract differ, this file wins.

## Affected files
All are in the original contract's list; nothing new is added.
- `eval/refutation-replay/label_page.html` (anchor: line matching `if (e.detail === 0) return; // mut:detail`; the label-button click handler, the pointer-rule state and the two `min_real === null` branches)
- `eval/refutation-replay/label.py` (anchor: line matching `def read_min_real():`; also `class Handler(http.server.BaseHTTPRequestHandler):` and `def parser():`)
- `eval/refutation-replay/README.md` (anchor: line matching `- A local write log at `.git/refutation-label-writes.log` records every POST. It is never committed.`)
- `tests/refutation-label-browser.js` (anchor: line matching `async function b10() {`)
- `tests/refutation-label-server.py` (anchor: line matching `def s12():`)
- `tests/refutation-label.test.sh` (anchor: line matching `[ "$n" -eq 11 ] || { bad "B00 probe reported $n of 11 cases"; head -3 "$T/br.err"; }`)
- `tests/validate.sh` (anchor: line matching `echo "== refutation-label: the Gate G1 labeling server, its write checks and a real-browser probe (Bash, rfp-u2c) =="`): expected unchanged; touch it only if the wrapper's output contract changes, and then say so in the report.

No version-stamped path is touched (`eval/` is `export-ignore`): no version bump and no CHANGELOG entry.

## Ordered edits
Decisions this contract takes, so the lead does not have to:
- **The pointer rule (what "aimed" means).** A label click is dropped when `e.detail > 1`. A label click on card B is also
  dropped when the previous successful write was on a different card A, the pointer has not left the click point of
  that write, and the wheel has not turned since. A pointer that moves to a different point, or a wheel turn,
  re-arms labelling. A click on the same card as the last write is never dropped by this rule. This closes the reviewer's
  three reproductions (clickCount 2 after 300 ms; two plain clicks 120 ms apart; clickCount 2 after 250 ms), because under
  filter `unknown` the next card slides under a stationary pointer. A deliberate click on the next card needs a pointer
  movement, which every real click has.
- **score.py is required, the fallback is dropped.** `label.py serve` exits 2 with a one-line reason when `score.py` is
  not beside it or `MIN_REAL` is not an integer. Reason: a fallback that serves a page with `null` targets lets a
  missing `score.py` pass B01 (its target check was skipped on `null`) and S15 was the only guard. With the fallback gone,
  a missing `score.py` in the real tree fails every server and browser case at startup, S13 pins the refusal, and S15
  and B01 assert integer thresholds with no `else`. The criterion-3 and criterion-4 scratch copies therefore now copy
  `score.py` (read only, never edited).
- **Declined notes, with reasons.** Cleaning stale `.labels.*.tmp` files at startup contradicts the original contract's rule
  that startup writes nothing (S01), and non-daemon request threads can hang shutdown; the SIGTERM-during-`atomic_write`
  window stays as a reported, untested, narrow risk. A size cap on the write log is not added: it needs a size rule the
  plan does not make, and the log lives outside the tree; truncating each logged header value to 200 characters is added instead.
- The mutation anchors `mousedown`, `blur`, `multiclick`, `pointer`, `port`, `logtrunc` and `scorecheck` below belong to
  criterion 4. Its `onscreen` mutation edits the existing line
  `if (target === null || !passes(target) || !onScreen(target)) {` in `move()`, which keeps its text and stays one line.
- Create and edit all test content with the Write and Edit tools. A Bash heredoc is refused by the hooks.

| anchor comment | file | the line that carries it | mutation (criterion 4) | must turn red |
|---|---|---|---|---|
| none (existing line) | `label_page.html` | `if (target === null \|\| !passes(target) \|\| !onScreen(target)) {` in `move()` | remove ` \|\| !onScreen(target)` | B07 |
| `// mut:mousedown` | `label_page.html` | the label button's `mousedown` listener line | delete it | B13 |
| `// mut:blur` | `label_page.html` | `e.currentTarget.blur(); // mut:blur` | delete it | B13 |
| `// mut:multiclick` | `label_page.html` | `if (e.detail > 1) return; // mut:multiclick` | delete it | B12 |
| `// mut:pointer` | `label_page.html` | `if (lw !== null && lw.id !== r.id && !lw.moved) return; // mut:pointer` | delete it | B12 |
| `# mut:port` | `label.py` | the `--port` `add_argument` line | `type=port_arg` becomes `type=int` | S13 |
| `# mut:logtrunc` | `label.py` | `def trunc(v): return None if v is None else v[:200]  # mut:logtrunc` | `v[:200]` becomes `v` | S12 |
| `# mut:scorecheck` | `label.py` | the `raise LabelError('score.py not found ...')  # mut:scorecheck` line in `read_min_real` | replace the `raise` with `return None` | S13 |

The test-file edits come first and are the red step; the page, `label.py` and README edits are the green step. B12 and
B13 are printed before B11 so that B11 still sees every page error. The wrapper now expects 13 probe lines.

1. file: `tests/refutation-label-browser.js`
   anchor: line matching `window.__p = { card, hb, onScreen, shown, btn, validButtons, hitLbl, bring, state };`
   indent: 2
before:
~~~
  window.__p = { card, hb, onScreen, shown, btn, validButtons, hitLbl, bring, state };
~~~
after:
~~~
  const ev = [];
  const rec = (e) => { ev.push([e.type, e.clientX, e.clientY]); };
  document.addEventListener('mousemove', rec, true);
  document.addEventListener('mousedown', rec, true);
  document.addEventListener('wheel', rec, { capture: true, passive: true });
  window.__p = { card, hb, onScreen, shown, btn, validButtons, hitLbl, bring, state, ev };
~~~
2. file: `tests/refutation-label-browser.js`
   anchor: line matching `async function newPage(u, viewport) {`
   indent: 0
before:
~~~
async function newPage(u, viewport) {
  const page = await ctx.newPage();
  page.setDefaultTimeout(8000);
  const st = { page, posts: 0, inflight: 0, model: null, step: 'init' };
~~~
after:
~~~
async function newPage(u, viewport, extraInit) {
  const page = await ctx.newPage();
  page.setDefaultTimeout(8000);
  const st = { page, posts: 0, inflight: 0, model: null, step: 'init', lw: null };
~~~
3. file: `tests/refutation-label-browser.js`
   anchor: line matching `  await page.addInitScript(PAGE_HELPERS);`
   indent: 2
before:
~~~
  await page.addInitScript(PAGE_HELPERS);
~~~
after:
~~~
  await page.addInitScript(PAGE_HELPERS);
  for (const f of extraInit || []) await page.addInitScript(f);
~~~
4. file: `tests/refutation-label-browser.js`
   anchor: line matching `  if (!b || !b.valid) throw new Error('could not place a click on ' + id + ' ' + value);`
   indent: 2
before:
~~~
  if (!b || !b.valid) throw new Error('could not place a click on ' + id + ' ' + value);
  await st.page.mouse.click(b.x, b.y);
  st.model.set(id, value);
~~~
after:
~~~
  if (!b || !b.valid) throw new Error('could not place a click on ' + id + ' ' + value);
  await st.page.mouse.move(2, 2); // a deliberate click starts from a pointer that has moved
  await st.page.mouse.click(b.x, b.y);
  st.model.set(id, value);
  await noteWrite(st, id, b.x, b.y);
~~~
5. file: `tests/refutation-label-browser.js`
   anchor: line matching `async function clickLabel(st, id, value) {`
   indent: 0
before: `async function clickLabel(st, id, value) {`
after:
~~~
// The probe's own oracle for the pointer rule: after a write to card A, a label click on another card B is refused
// unless the pointer went to another point or the wheel turned since that write. The probe derives "moved" from the
// pointer events it observed itself (window.__p.ev), never from the page's state.
async function noteWrite(st, id, x, y) {
  st.lw = { id, x, y, n: await st.page.evaluate(() => window.__p.ev.length) };
}

async function accepted(st, id, x, y) {
  if (!st.lw || st.lw.id === id) return true;
  if (x !== st.lw.x || y !== st.lw.y) return true;
  const ev = await st.page.evaluate((n) => window.__p.ev.slice(n), st.lw.n);
  return ev.some((e) => e[0] === 'wheel' || e[1] !== st.lw.x || e[2] !== st.lw.y);
}

async function clickLabel(st, id, value) {
~~~
6. file: `tests/refutation-label-browser.js`
   anchor: line matching `  if (r.min !== null && (!r.rules.includes('at least ' + r.min + ' real') || !r.rules.includes('at most ' + r.max + ' bogus'))) throw new Error('targets missing');`
   indent: 2
before:
~~~
  if (r.min !== null && (!r.rules.includes('at least ' + r.min + ' real') || !r.rules.includes('at most ' + r.max + ' bogus'))) throw new Error('targets missing');
~~~
after:
~~~
  if (!Number.isInteger(r.min) || !Number.isInteger(r.max) || !r.rules.includes('at least ' + r.min + ' real') || !r.rules.includes('at most ' + r.max + ' bogus')) throw new Error('targets missing or not integers: ' + r.min + ' ' + r.max);
~~~
7. file: `tests/refutation-label-browser.js`
   anchor: line matching `    st.step = key;`
   (B07: with an off-screen target the key picks the first on-screen card and moves nothing; with an on-screen target it moves one card and leaves it on screen)
   indent: 4
before:
~~~
    st.step = key;
    await step(st, 'key ' + key, () => st.page.keyboard.press(key));
    const t1 = (await stateOf(st)).target;
    if (!t1 || !(await onScreen(st, t1))) throw new Error(key + ' selected ' + t1 + ', which is not on screen');
~~~
after:
~~~
    st.step = key;
    let first = null;
    for (const i of await shown(st)) if (await onScreen(st, i)) { first = i; break; }
    const y0 = await st.page.evaluate(() => window.scrollY);
    await step(st, 'key ' + key, () => st.page.keyboard.press(key));
    const t1 = (await stateOf(st)).target;
    if (!t1 || !(await onScreen(st, t1))) throw new Error(key + ' selected ' + t1 + ', which is not on screen');
    if (t1 !== first) throw new Error(key + ' with an off-screen target chose ' + t1 + ', not the first on-screen card ' + first);
    if (Math.abs((await st.page.evaluate(() => window.scrollY)) - y0) > 1) throw new Error(key + ' with an off-screen target scrolled the page');
    const vis = await shown(st);
    const want2 = vis[Math.max(0, Math.min(vis.length - 1, vis.indexOf(t1) + (key === 'j' ? 1 : -1)))];
    await step(st, 'second key ' + key, () => st.page.keyboard.press(key));
    const t2 = (await stateOf(st)).target;
    if (t2 !== want2 || !(await onScreen(st, t2))) throw new Error('second ' + key + ' chose ' + t2 + ', expected on-screen ' + want2);
~~~
8. file: `tests/refutation-label-browser.js`
   anchor: line matching `      await st.page.mouse.click(b.x, b.y);`
   (B09 click-label action; the anchor carries its 6 leading spaces, so it does not match clickLabel's 2-space line)
   indent: 6
before:
~~~
      const b = pick(v);
      await st.page.mouse.click(b.x, b.y);
      st.model.set(b.id, b.value);
~~~
after:
~~~
      const b = pick(v);
      const ok = await accepted(st, b.id, b.x, b.y);
      await st.page.mouse.click(b.x, b.y);
      if (ok) { st.model.set(b.id, b.value); await noteWrite(st, b.id, b.x, b.y); }
~~~
9. file: `tests/refutation-label-browser.js`
   anchor: line matching `      await st.page.mouse.click(x, y);`
   indent: 6
before:
~~~
      await st.page.mouse.click(x, y);
      if (hit) st.model.set(hit.id, hit.value);
~~~
after:
~~~
      const ok = hit ? await accepted(st, hit.id, x, y) : false;
      await st.page.mouse.click(x, y);
      if (hit && ok) { st.model.set(hit.id, hit.value); await noteWrite(st, hit.id, x, y); }
~~~
10. file: `tests/refutation-label-browser.js`
   anchor: line matching `    ['key', 3, async () => { await st.page.keyboard.press(pick(NAV_KEYS.concat(['r', 'b', 'u']))); }],`
   indent: 4
insert-after:
~~~
    ['click-same-point', 2, async () => {
      if (!st.lw) return;
      const { x, y } = st.lw;
      const hit = await st.page.evaluate(([a, b]) => window.__p.hitLbl(a, b), [x, y]);
      const ok = hit ? await accepted(st, hit.id, x, y) : false;
      await st.page.mouse.click(x, y);
      if (hit && ok) { st.model.set(hit.id, hit.value); await noteWrite(st, hit.id, x, y); }
    }],
    ['double-click', 2, async () => {
      // Playwright sends click 1 (detail 1) and then click 2 (detail 2): only the first can write
      const v = await st.page.evaluate(() => window.__p.validButtons());
      if (!v.length) return;
      const b = pick(v);
      const ok = await accepted(st, b.id, b.x, b.y);
      await st.page.mouse.click(b.x, b.y, { clickCount: 2 });
      if (ok) { st.model.set(b.id, b.value); await noteWrite(st, b.id, b.x, b.y); }
    }],
    ['lone-detail-2', 2, async () => {
      const v = await st.page.evaluate(() => window.__p.validButtons());
      if (!v.length) return;
      const b = pick(v);
      await st.page.mouse.move(b.x, b.y);
      await st.page.mouse.down({ clickCount: 2 });
      await st.page.mouse.up({ clickCount: 2 });
    }],
~~~
11. file: `tests/refutation-label-browser.js`
   anchor: line matching `async function b10() {`
   indent: 0
before: `async function b10() {`
after:
~~~
const NO_DISABLE = () => {
  Object.defineProperty(HTMLButtonElement.prototype, 'disabled', { configurable: true, get() { return false; }, set() {} });
};
const NO_MOUSEDOWN_PREVENT = () => {
  const p = Event.prototype.preventDefault;
  Event.prototype.preventDefault = function () { if (this.type === 'mousedown') return undefined; return p.call(this); };
};

// B12: the double-click defect. Filter unknown hides each labelled card and the next one slides under the pointer.
async function b12() {
  extWrite(new Map(Array.from(readLabels().keys(), (i) => [i, 'unknown'])));
  const st = await newPage(url, { width: 1280, height: 800 });
  await st.page.locator('.flt[data-f="unknown"]').click();
  await settle(st);
  const ids = await shown(st);
  await st.page.evaluate((i) => window.__p.bring(i, 0.5), ids[0]);
  await settle(st);
  const p = await st.page.evaluate((i) => window.__p.btn(i, 'real'), ids[0]);
  if (!p || !p.valid) throw new Error('no click point on ' + ids[0]);
  const under = async (want) => {
    const h = await st.page.evaluate(([a, b]) => window.__p.hitLbl(a, b), [p.x, p.y]);
    if (!h || h.id !== want) throw new Error('fixture: ' + want + ' is not under the pointer, ' + JSON.stringify(h));
  };
  const unknownNow = (id, what) => { if (readLabels().get(id) !== 'unknown') throw new Error(what + ' wrote ' + id); };
  await st.page.mouse.move(2, 2);
  await step(st, 'first click of a double-click', async () => {
    await st.page.mouse.click(p.x, p.y);
    st.model.set(ids[0], 'real');
    await noteWrite(st, ids[0], p.x, p.y);
  });
  await under(ids[1]);
  await st.page.waitForTimeout(300);
  await step(st, 'second click, detail 2, 300 ms later, on the card that slid under the pointer', async () => {
    await st.page.mouse.down({ clickCount: 2 });
    await st.page.mouse.up({ clickCount: 2 });
  });
  unknownNow(ids[1], 'a detail-2 click at the same point');
  await step(st, 'plain second click, detail 1, same point, 300 ms later', async () => { await st.page.mouse.click(p.x, p.y); });
  unknownNow(ids[1], 'a plain click at the same point with no pointer movement');
  await step(st, 'deliberate click after the pointer moved', async () => {
    await st.page.mouse.move(2, 2);
    await st.page.mouse.click(p.x, p.y);
    st.model.set(ids[1], 'real');
    await noteWrite(st, ids[1], p.x, p.y);
  });
  await under(ids[2]);
  await step(st, 'detail-2 click after the pointer moved', async () => {
    await st.page.mouse.move(2, 2);
    await st.page.mouse.move(p.x, p.y);
    await st.page.mouse.down({ clickCount: 2 });
    await st.page.mouse.up({ clickCount: 2 });
  });
  unknownNow(ids[2], 'a detail-2 click after the pointer moved');
  await step(st, 'plain click after the pointer moved is accepted', async () => {
    await st.page.mouse.move(2, 2);
    await st.page.mouse.click(p.x, p.y);
    st.model.set(ids[2], 'real');
    await noteWrite(st, ids[2], p.x, p.y);
  });
  await st.page.close();
}

// B13: focus. The page disables every label button while a POST is in flight, which drops focus in Chromium by itself,
// so each variant switches that off, and the second one also neutralises the mousedown preventDefault.
async function b13() {
  const variants = [['mousedown default prevented, buttons never disabled', [NO_DISABLE], 'down'],
    ['mousedown default not prevented, buttons never disabled', [NO_DISABLE, NO_MOUSEDOWN_PREVENT], 'up']];
  for (const [name, scripts, when] of variants) {
    const st = await newPage(url, { width: 1280, height: 800 }, scripts);
    const id = (await shown(st))[3];
    await st.page.evaluate((i) => window.__p.bring(i, 0.6), id);
    await settle(st);
    const b = await st.page.evaluate((i) => window.__p.btn(i, 'real'), id);
    if (!b || !b.valid) throw new Error(name + ': no click point on ' + id);
    const held = () => st.page.evaluate(() => /\blbl\b/.test(document.activeElement ? document.activeElement.className : ''));
    await st.page.mouse.move(b.x, b.y);
    await st.page.mouse.down();
    if (when === 'down' && (await held())) throw new Error(name + ': the label button took focus on mousedown');
    if (when === 'up' && !(await held())) throw new Error(name + ': the variant is vacuous, mousedown did not focus the button');
    await st.page.mouse.up();
    st.model.set(id, 'real');
    await settle(st);
    verify(st, name);
    if (await held()) throw new Error(name + ': the label button kept focus after the click');
    const before = st.posts;
    for (const k of ['Enter', 'Space']) await step(st, name + ' ' + k, () => st.page.keyboard.press(k));
    if (st.posts !== before) throw new Error(name + ': a key on the clicked button sent a POST');
    await st.page.close();
  }
}

async function b10() {
~~~
12. file: `tests/refutation-label-browser.js`
   anchor: line matching `  ['B09 seeded random input seed ' + SEED + ' steps ' + STEPS, b09], ['B10 empty corpus page is safe', b10],`
   indent: 2
before:
~~~
  ['B09 seeded random input seed ' + SEED + ' steps ' + STEPS, b09], ['B10 empty corpus page is safe', b10],
  ['B11 no page or console errors', b11]];
~~~
after:
~~~
  ['B09 seeded random input seed ' + SEED + ' steps ' + STEPS, b09], ['B10 empty corpus page is safe', b10],
  ['B12 a double-click or a re-click under a stationary pointer writes only the aimed card', b12],
  ['B13 a label button never holds focus, with or without the page disabling it', b13],
  ['B11 no page or console errors', b11]];
~~~
13. file: `tests/refutation-label.test.sh`
   anchor: line matching `[ "$n" -eq 11 ] || { bad "B00 probe reported $n of 11 cases"; head -3 "$T/br.err"; }`
   indent: 2
before:
~~~
  [ "$n" -eq 11 ] || { bad "B00 probe reported $n of 11 cases"; head -3 "$T/br.err"; }
~~~
after:
~~~
  [ "$n" -eq 13 ] || { bad "B00 probe reported $n of 13 cases"; head -3 "$T/br.err"; }
~~~
14. file: `tests/refutation-label-server.py`
   anchor: line matching `check(fx.token not in text, 'token in the log')`
   indent: 8
insert-after:
~~~
        fx.post(fx.valid(), Origin='http://evil.example/' + 'a' * 5000)
        with open(fx.log) as f:
            last = json.loads(f.read().splitlines()[-1])
        check(last['status'] == 403 and isinstance(last['origin'], str), 'long Origin line %r' % (last,))
        check(0 < len(last['origin']) <= 200 and last['origin'].startswith('http://evil.example/'), 'logged origin is %d chars' % len(last['origin']))
~~~
15. file: `tests/refutation-label-server.py`
   anchor: line matching `        unchanged(fx, before, 'a bound port')`
   (S13 gains the out-of-range ports and the missing score.py refusal; the anchor is the last assertion of the bound-port case)
   indent: 4
before:
~~~
        unchanged(fx, before, 'a bound port')
    finally:
        s.close()
~~~
after:
~~~
        unchanged(fx, before, 'a bound port')
    finally:
        s.close()
    for bad in ('70000', '-1'):
        fx = Fx()
        before = fx.snap()
        p = cli(fx, '--port', bad)
        out = p.stdout + p.stderr
        check(p.returncode == 2 and 'Traceback' not in out, 'port %s: exit %d, %r' % (bad, p.returncode, out[:120]))
        unchanged(fx, before, 'port ' + bad)
    fx = Fx()
    d = mktmp()
    shutil.copy(LABEL_PY, d)
    shutil.copy(os.path.join(RR, 'label_page.html'), d)
    before = fx.snap()
    cmd = [sys.executable, os.path.join(d, 'label.py'), 'serve', '--no-open', '--port', '0', '--corpus', fx.corpus,
           '--labels', fx.labels, '--repo', fx.repo, '--log', fx.log]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    except subprocess.TimeoutExpired:
        raise AssertionError('with no score.py beside it the server started instead of refusing')
    out = (p.stdout + p.stderr).strip()
    check(p.returncode == 2 and len(out.splitlines()) == 1 and 'score.py' in out, 'no score.py: exit %d, %r' % (p.returncode, out[:160]))
    unchanged(fx, before, 'a missing score.py')
    check(not os.path.exists(fx.log), 'no score.py: log created')
~~~
16. file: `tests/refutation-label-server.py`
   anchor: line matching `        if os.path.exists(os.path.join(RR, 'score.py')):  # a stripped copy has no score.py: the targets are then null`
   indent: 8
before:
~~~
        if os.path.exists(os.path.join(RR, 'score.py')):  # a stripped copy has no score.py: the targets are then null
            score = importlib.util.spec_from_file_location('score_ref', os.path.join(RR, 'score.py'))
            sm = importlib.util.module_from_spec(score)
            score.loader.exec_module(sm)
            check(d['min_real'] == sm.MIN_REAL and d['max_bogus'] == len(fx.rows) - sm.MIN_REAL, 'thresholds %r %r' % (d['min_real'], d['max_bogus']))
        else:
            check(d['min_real'] is None and d['max_bogus'] is None, 'targets without score.py: %r' % ((d['min_real'], d['max_bogus']),))
~~~
after:
~~~
        score = importlib.util.spec_from_file_location('score_ref', os.path.join(RR, 'score.py'))
        sm = importlib.util.module_from_spec(score)
        score.loader.exec_module(sm)
        check(isinstance(d['min_real'], int) and d['min_real'] == sm.MIN_REAL and d['max_bogus'] == len(fx.rows) - sm.MIN_REAL, 'thresholds %r %r' % (d['min_real'], d['max_bogus']))
~~~
17. command: `bash -c 'LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh >/dev/null 2>&1'`
   expect: 1
   The red step: S12, S13, B09 and B12 fail against the unfixed page and label.py (the lead measured exactly these four). B07 and B13 are strengthened checks that stay green on correct code and turn red only under the mutations of criterion 4. A run takes about 30 s.
18. command: `git add tests/refutation-label-browser.js tests/refutation-label-server.py tests/refutation-label.test.sh && git commit -m "fix(rfp-u2c): cases for double-click, focus, on-screen navigation, score.py and port refusals"`
   expect: 0
19. file: `eval/refutation-replay/label_page.html`
   anchor: line matching `var target = null, filter = 'all', query = '', collapsed = {};`
   indent: 0
before: `var target = null, filter = 'all', query = '', collapsed = {};`
after:
~~~
var target = null, filter = 'all', query = '', collapsed = {};
var lw = null, clickPt = null; // lw: the last written card and the pointer point of that click; moved turns true once the pointer or wheel has acted since
~~~
20. file: `eval/refutation-replay/label_page.html`
   anchor: line matching `    b.addEventListener('mousedown', function (e) { e.preventDefault(); });`
   (the six new or changed lines carry the anchor comments exactly as written, each on its own line)
   indent: 4
before:
~~~
    b.addEventListener('mousedown', function (e) { e.preventDefault(); });
    b.addEventListener('click', function (e) {
      if (!e.isTrusted) return;
      if (e.detail === 0) return; // mut:detail
      if (!passes(r.id) || document.body.dataset.pending === '1') return;
      e.currentTarget.blur();
      setTarget(r.id);
      postLabel(r.id, v);
    });
~~~
after:
~~~
    b.addEventListener('mousedown', function (e) { e.preventDefault(); }); // mut:mousedown
    b.addEventListener('click', function (e) {
      if (!e.isTrusted) return;
      if (e.detail === 0) return; // mut:detail
      if (e.detail > 1) return; // mut:multiclick
      if (!passes(r.id) || document.body.dataset.pending === '1') return;
      if (lw !== null && lw.id !== r.id && !lw.moved) return; // mut:pointer
      e.currentTarget.blur(); // mut:blur
      clickPt = { x: e.clientX, y: e.clientY };
      setTarget(r.id);
      postLabel(r.id, v);
    });
~~~
21. file: `eval/refutation-replay/label_page.html`
   anchor: line matching `        labels[id] = value;`
   indent: 8
before:
~~~
        labels[id] = value;
~~~
after:
~~~
        labels[id] = value;
        lw = clickPt === null ? null : { id: id, x: clickPt.x, y: clickPt.y, moved: false };
~~~
22. file: `eval/refutation-replay/label_page.html`
   anchor: line matching `document.addEventListener('keydown', function (e) {`
   indent: 0
before: `document.addEventListener('keydown', function (e) {`
after:
~~~
function pointerActed(e) {
  if (lw !== null && (e.type === 'wheel' || e.clientX !== lw.x || e.clientY !== lw.y)) lw.moved = true;
}
document.addEventListener('mousemove', pointerActed, true);
document.addEventListener('wheel', pointerActed, { capture: true, passive: true });

document.addEventListener('keydown', function (e) {
~~~
23. file: `eval/refutation-replay/label_page.html`
   anchor: line matching `  var known = D.min_real !== null;`
   indent: 2
before:
~~~
  var known = D.min_real !== null;
  $('#n-real').classList.toggle('met', known && n.real >= D.min_real);
  var good = known && n.real >= D.min_real && n.bogus <= D.max_bogus;
~~~
after:
~~~
  $('#n-real').classList.toggle('met', n.real >= D.min_real);
  var good = n.real >= D.min_real && n.bogus <= D.max_bogus;
~~~
24. file: `eval/refutation-replay/label_page.html`
   anchor: line matching `  $('#rules').textContent = (D.min_real === null ? 'Gate G targets unavailable: score.py not found' :`
   indent: 2
before:
~~~
  $('#rules').textContent = (D.min_real === null ? 'Gate G targets unavailable: score.py not found' :
    'Gate G targets: at least ' + D.min_real + ' real, at most ' + D.max_bogus + ' bogus, out of ' + rows.length) + '. A card is labelled only by a mouse click on its button.';
~~~
after:
~~~
  $('#rules').textContent = 'Gate G targets: at least ' + D.min_real + ' real, at most ' + D.max_bogus + ' bogus, out of ' + rows.length + '. A card is labelled only by a mouse click on its button.';
~~~
25. file: `eval/refutation-replay/label.py`
   anchor: line matching `def read_min_real():`
   indent: 0
before:
~~~
def read_min_real():
    # None when score.py is not beside this file (a stripped copy): the page then shows no targets
    if not os.path.exists(os.path.join(HERE, 'score.py')):
        return None
    spec = importlib.util.spec_from_file_location('score_consts', os.path.join(HERE, 'score.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.MIN_REAL
~~~
after:
~~~
def read_min_real():
    # score.py is the one source of the Gate G threshold; with no threshold there are no targets to show, so refuse to start
    if not os.path.exists(os.path.join(HERE, 'score.py')): raise LabelError('score.py not found beside label.py: the Gate G targets cannot be read')  # mut:scorecheck
    spec = importlib.util.spec_from_file_location('score_consts', os.path.join(HERE, 'score.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    if not isinstance(mod.MIN_REAL, int): raise LabelError('score.py MIN_REAL is not an integer')
    return mod.MIN_REAL
~~~
26. file: `eval/refutation-replay/label.py`
   anchor: line matching `    with open(os.path.join(HERE, 'label_page.html'), encoding='utf-8') as f:`
   indent: 4
before:
~~~
    with open(os.path.join(HERE, 'label_page.html'), encoding='utf-8') as f:
~~~
after:
~~~
    min_real = read_min_real()  # before any socket is bound, so a refusal leaves nothing listening
    with open(os.path.join(HERE, 'label_page.html'), encoding='utf-8') as f:
~~~
27. file: `eval/refutation-replay/label.py`
   anchor: line matching `    srv.labels, srv.log, srv.min_real = os.path.abspath(labels), log, read_min_real()`
   indent: 4
before:
~~~
    srv.labels, srv.log, srv.min_real = os.path.abspath(labels), log, read_min_real()
~~~
after:
~~~
    srv.labels, srv.log, srv.min_real = os.path.abspath(labels), log, min_real
~~~
28. file: `eval/refutation-replay/label.py`
   anchor: line matching `                'min_real': S.min_real, 'max_bogus': None if S.min_real is None else len(S.rows) - S.min_real}`
   indent: 16
before:
~~~
                'min_real': S.min_real, 'max_bogus': None if S.min_real is None else len(S.rows) - S.min_real}
~~~
after:
~~~
                'min_real': S.min_real, 'max_bogus': len(S.rows) - S.min_real}
~~~
29. file: `eval/refutation-replay/label.py`
   anchor: line matching `class Handler(http.server.BaseHTTPRequestHandler):`
   indent: 0
before: `class Handler(http.server.BaseHTTPRequestHandler):`
after:
~~~
def trunc(v): return None if v is None else v[:200]  # mut:logtrunc


class Handler(http.server.BaseHTTPRequestHandler):
~~~
30. file: `eval/refutation-replay/label.py`
   anchor: line matching `                   remote=self.client_address[0], origin=self.headers.get('Origin'),`
   indent: 19
before:
~~~
                   remote=self.client_address[0], origin=self.headers.get('Origin'),
                   user_agent=(self.headers.get('User-Agent') or '')[:200])
~~~
after:
~~~
                   remote=self.client_address[0], origin=trunc(self.headers.get('Origin')),
                   user_agent=trunc(self.headers.get('User-Agent') or ''))
~~~
31. file: `eval/refutation-replay/label.py`
   anchor: line matching `def parser():`
   indent: 0
before: `def parser():`
after:
~~~
def port_arg(v):
    n = int(v)
    if not 0 <= n <= 65535: raise argparse.ArgumentTypeError('%s is not a port in 0..65535' % v)
    return n


def parser():
~~~
32. file: `eval/refutation-replay/label.py`
   anchor: line matching `    s.add_argument('--port', type=int, default=0, help='0 picks a free port')`
   indent: 4
before:
~~~
    s.add_argument('--port', type=int, default=0, help='0 picks a free port')
~~~
after:
~~~
    s.add_argument('--port', type=port_arg, default=0, help='0 picks a free port')  # mut:port
~~~
33. file: `eval/refutation-replay/README.md`
   anchor: line matching `- A local write log at `.git/refutation-label-writes.log` records every POST. It is never committed.`
   indent: 0
before:
~~~
- A local write log at `.git/refutation-label-writes.log` records every POST. It is never committed.
~~~
after:
~~~
- A local write log, `<git dir>/refutation-label-writes.log`, records every POST (`.git/` in a normal checkout, `.git/worktrees/<name>/` in a linked worktree). It is never committed.
~~~
34. command: `bash -c 'LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh >/dev/null 2>&1'`
   expect: 0
   The green step.
35. command: `git status --short`
   expect: 0
   Run it before the commit. A tracked file outside "Affected files" in the list means STOP and report it.
36. command: `git add eval/refutation-replay/label.py eval/refutation-replay/label_page.html eval/refutation-replay/README.md && git commit -m "fix(rfp-u2c): a double-click or a re-click under a stationary pointer writes only the aimed card; score.py is required; clean port and log handling"`
   expect: 0

## Do NOT touch
- `eval/refutation-replay/labels.tsv` and `eval/refutation-replay/corpus.jsonl`: never start `label.py serve` on them except as criterion 5 does (on copies), and never POST to a server that points at them. The labels are the human's.
- `eval/refutation-replay/score.py`, including `MIN_REAL`, `MAX_MISSES`, `MAX_TURNS` and `MAX_UNANSWERED`: read it, copy it into scratch directories, never edit it.
- `eval/refutation-replay/guard.py`, `eval/refutation-replay/run.sh` and `eval/refutation-replay/build-corpus.py`; `eval/refutation-replay/report.jsonl` must not exist.
- `tests/refutation-replay.test.sh`, `tests/refutation-replay-isolation.test.sh` and `bin/refutation-brief.sh`.
- `agents/`, `templates/`, `hooks/`, `adapters/`, `bin/`, `.claude/` and the persona config. Never read or write anything under the reviewed-markers directory.
- `docs/plans/2026-10-27-refutation-pass/contracts/rfp-u2c.md` and `docs/plans/2026-10-27-refutation-pass.md`.

## Acceptance criteria
Every expected stdout is one line. Original criteria 4, 5, 6, 8, 9 and 10 stay in force unchanged (the reviewer re-runs
them); this file replaces original criteria 1, 2, 3, 7, 11 and 12 with the ones below. Criteria 1 to 4 need the real browser.
Criteria 3 and 4 restate original criterion 3 (split in two so each half stays under the 600 s Bash ceiling) without `rm`:
each makes one fresh `mktemp -d` per mutation and deletes nothing, so the command-safety check no longer refuses it.
Each half leaves its scratch directories in the system temp area, outside the repository.
1. run: `bash -c 'LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: any mutation in criterion 3 or 4 (stdout `1`). Today it also prints `0`, because the old suite still passes; the new cases are what the red step adds.
2. run: `bash -c 'o=$(LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh 2>/dev/null); echo "$(printf "%s\n" "$o" | sed -n "s/^ok - \([SBD][0-9][0-9]\) .*/\1/p" | sort -u | paste -sd, -) fail=$(printf "%s\n" "$o" | grep -c "^FAIL") skip=$(printf "%s\n" "$o" | grep -c "^SKIP")"'`
   exit: 0
   stdout: `B01,B02,B03,B04,B05,B06,B07,B08,B09,B10,B11,B12,B13,D01,S01,S02,S03,S04,S05,S06,S07,S08,S09,S10,S11,S12,S13,S14,S15,S16 fail=0 skip=0`
   mutation: drop B12 or B13 from the probe's case list (that ID leaves the list), or run with no browser (`skip=1`). Today B12 and B13 are missing from the list.
3. run: `bash -c 'L=eval/refutation-replay; mk() { w=$(mktemp -d); mkdir -p "$w/$L" "$w/tests"; cp "$L/label.py" "$L/label_page.html" "$L/README.md" "$L/score.py" "$w/$L/" && cp tests/refutation-label.test.sh tests/refutation-label-server.py tests/refutation-label-browser.js "$w/tests/"; }; st() { LABEL_UI_REQUIRE_BROWSER=1 bash "$w/tests/refutation-label.test.sh" > "$w/o" 2>/dev/null; }; del() { sed -i "/$1/d" "$f"; }; mut() { mk; f="$w/$L/$2"; cp "$f" "$w/orig"; "m_$1"; if cmp -s "$f" "$w/orig"; then r=noanchor; elif st; then r=green; elif grep -q "^FAIL - $3 " "$w/o"; then r=red; else r=other; fi; printf " %s=%s" "$1" "$r"; }; m_host() { del "# mut:host"; }; m_origin() { del "# mut:origin"; }; m_token() { del "# mut:token"; }; m_version() { del "# mut:version"; }; m_atomic() { sed -i "s/os\.replace(tmp, path)  # mut:atomic/open(path, \"w\").write(open(tmp).read()); os.unlink(tmp)/" "$f"; }; m_detail() { del "\/\/ mut:detail"; }; m_keys() { sed -i "/\/\/ mut:keys/a if (e.key === \"r\" \&\& target) postLabel(target, \"real\");" "$f"; }; m_order() { awk "/\/\/ mut:refresh-first/{h=\$0; next} {print} /\/\/ mut:scroll/{print h}" "$f" > "$w/x" && cat "$w/x" > "$f"; }; mk; if st && ! grep -qE "^(FAIL|SKIP)" "$w/o"; then printf base=pass; else printf base=fail; fi; mut host label.py S04; mut origin label.py S05; mut token label.py S03; mut version label.py S08; mut atomic label.py S09; mut detail label_page.html B04; mut keys label_page.html B05; mut order label_page.html B06; echo'`
   exit: 0
   stdout: `base=pass host=red origin=red token=red version=red atomic=red detail=red keys=red order=red`
   mutation: this criterion is the original eight-mutation run. A missing anchor prints `noanchor`, an uncaught check `green`, an unrelated failure `other`. It passes today with `score.py` in the copy list (the lead ran it).
4. run: `bash -c 'L=eval/refutation-replay; mk() { w=$(mktemp -d); mkdir -p "$w/$L" "$w/tests"; cp "$L/label.py" "$L/label_page.html" "$L/README.md" "$L/score.py" "$w/$L/" && cp tests/refutation-label.test.sh tests/refutation-label-server.py tests/refutation-label-browser.js "$w/tests/"; }; st() { LABEL_UI_REQUIRE_BROWSER=1 bash "$w/tests/refutation-label.test.sh" > "$w/o" 2>/dev/null; }; del() { sed -i "/$1/d" "$f"; }; mut() { mk; f="$w/$L/$2"; cp "$f" "$w/orig"; "m_$1"; if cmp -s "$f" "$w/orig"; then r=noanchor; elif st; then r=green; elif grep -q "^FAIL - $3 " "$w/o"; then r=red; else r=other; fi; printf " %s=%s" "$1" "$r"; }; m_onscreen() { sed -i "s/ || !onScreen(target)) {\$/) {/" "$f"; }; m_mousedown() { del "mut:mousedown"; }; m_blur() { del "mut:blur"; }; m_multiclick() { del "mut:multiclick"; }; m_pointer() { del "mut:pointer"; }; m_port() { sed -i "s/type=port_arg/type=int/" "$f"; }; m_logtrunc() { sed -i "s/v\[:200\]/v/" "$f"; }; m_scorecheck() { sed -i "s/raise LabelError.*# mut:scorecheck/return None  # mut:scorecheck/" "$f"; }; mk; if st && ! grep -qE "^(FAIL|SKIP)" "$w/o"; then printf base=pass; else printf base=fail; fi; mut onscreen label_page.html B07; mut mousedown label_page.html B13; mut blur label_page.html B13; mut multiclick label_page.html B12; mut pointer label_page.html B12; mut port label.py S13; mut logtrunc label.py S12; mut scorecheck label.py S13; echo'`
   exit: 0
   stdout: `base=pass onscreen=red mousedown=red blur=red multiclick=red pointer=red port=red logtrunc=red scorecheck=red`
   mutation: this criterion is the mutation run for the new checks. Today it prints `base=pass onscreen=green` and `noanchor` for the other seven.
5. run: `bash -c 'L=eval/refutation-replay; w=$(mktemp -d); cp $L/label.py $L/label_page.html $L/corpus.jsonl $L/labels.tsv $w/; timeout 20 python3 $w/label.py serve --no-open --port 0 --repo . --corpus $w/corpus.jsonl --labels $w/labels.tsv --log $w/w.log > $w/out 2>&1; echo "rc=$? lines=$(wc -l < $w/out) traceback=$(grep -c Traceback $w/out) files=$(ls $w | paste -sd, -)"'`
   exit: 0
   stdout: `rc=2 lines=1 traceback=0 files=corpus.jsonl,label.py,label_page.html,labels.tsv,out`
   mutation: restore the `return None` fallback (`rc=124`: the server serves until the 20 s timeout kills it), or let the refusal raise an uncaught exception (`traceback=1`). Today it prints `rc=124 lines=2 traceback=0 ...`.
6. run: `bash -c 'R=eval/refutation-replay/README.md; echo "new=$(grep -cF "in a linked worktree" $R) old=$(grep -c "at .\.git/refutation-label-writes" $R)"'`
   exit: 0
   stdout: `new=1 old=0`
   mutation: put the original wording back in the README (`new=0 old=1`). Today it prints `new=0 old=1`.
7. run: `bash -c 'n=0; k=0; for c in $(git log --format="%H %s" c0010804..HEAD | grep -E "^[0-9a-f]+ [a-z]+\(rfp-u2c\): " | cut -d" " -f1); do n=$((n+1)); k=$((k+$(git show --name-only --format= "$c" | grep -vxE "eval/refutation-replay/(label\.py|label_page\.html|README\.md)|tests/(refutation-label\.test\.sh|refutation-label-server\.py|refutation-label-browser\.js|validate\.sh)" | wc -l))); done; echo "commits=$([ $n -ge 1 ] && echo some || echo none) outside=$k"'`
   exit: 0
   stdout: `commits=some outside=0`
   mutation: touch `labels.tsv` or `score.py` in a `fix(rfp-u2c):` commit (`outside=1`), or make no such commit (`commits=none`). Only commits after `c0010804` whose subject scope is `rfp-u2c` are read. Today it prints `commits=none outside=0`.
8. run: `bash -c 'e=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(rfp-u2c\): " | cut -d" " -f1 | head -1); git log --format=%s $e..HEAD -- eval/refutation-replay/label.py eval/refutation-replay/label_page.html eval/refutation-replay/README.md tests/refutation-label.test.sh tests/refutation-label-server.py tests/refutation-label-browser.js | grep -vcE "^[a-z]+\(rfp-u2c\): "'`
   exit: 1
   stdout: `0`
   mutation: land a commit over the content files whose subject lacks the `(rfp-u2c)` scope after the unit's last scoped commit (stdout `1`, exit 0). It prints `0` today because the range is empty.
9. run: `bash -c 'git status --porcelain --untracked-files=all -- eval tests | wc -l'`
   exit: 0
   stdout: `0`
   mutation: leave a scratch file or an uncommitted edit under `eval/` or `tests/` (stdout `1` or more).
10. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/refutation-label.test.sh` (stdout `1`).

## Pre-resolved context
tdd: yes tests/refutation-label-browser.js (edits to the three test files go first and the red command must exit 1 before the page and label.py edits)
blast-radius: eval/refutation-replay/label_page.html:206 (the click handler), eval/refutation-replay/label_page.html:262 (`move()`), eval/refutation-replay/label.py:80 (`read_min_real`), eval/refutation-replay/label.py:333 (the only caller), tests/refutation-label-browser.js:134 (`step`), tests/refutation-label-server.py:419 (`s12`)
commit-message: fix(rfp-u2c): cases for double-click, focus, on-screen navigation, score.py and port refusals
commit-message: fix(rfp-u2c): a double-click or a re-click under a stationary pointer writes only the aimed card; score.py is required; clean port and log handling
diagnosis: none
review-packet:
~~~
unit: rfp-u2c (fix round 1, no tracker issue)
changed files: <FILL: changed files>
commits: <FILL: commit SHAs>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
~~~
- fix-of: 2026-10-28T17:13:15Z (the latest FAIL block of rfp-u2c, tier sonnet). The tier tag is unchanged: expected implementer tier opus, the ratchet stays.
- The defect (the record is authoritative): a human double-click on one label button writes a second label onto a different card. The handler drops only untrusted clicks, `e.detail === 0` and clicks while a POST is in flight; it accepts `e.detail === 2`. Under filter `unknown` (or any filter or search that hides the labelled card) the next card slides up under the stationary pointer and the second click, arriving after the POST finished (about 150 to 300 ms), writes it with the same value. B09 missed it because its model counts every trusted click and `page.mouse.click` always sends detail 1.
- Measured test-strength gaps: removing `!onScreen(target)` from `move()` stayed green because B07 checked only the end state and `scrollToTarget` hides the difference; removing the mousedown `preventDefault` and `blur()` stayed green because `setPending` disabling the buttons drops focus in Chromium. B07 now asserts the chosen card and an unmoved scroll position; B13 runs two variants with the disabling switched off.
- Gate: if `writer-scope-gate.sh` blocks the stop with a "changes outside your dispatch's unit scope" message naming a file listed in "Affected files", it is a false positive. Report the block verbatim and wait; do not run the `git checkout` it suggests and do not edit the gate.
- Run `validate.sh` with `ANTISLOP_VALIDATE_LANES=4` (criterion 10); the default lane count flakes at this baseline.
- Criterion 4's `onscreen` mutation edits a line this contract does not change. Confirm with `/usr/bin/grep -cF 'if (target === null || !passes(target) || !onScreen(target)) {' eval/refutation-replay/label_page.html` printing `1` before and after.

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If a trusted-input
scenario of B12 or B13 cannot be made deterministic in headless Chromium, report the scenario and what was measured;
do not drop the case. If no playwright driver or Chromium launches, stop and report it; do not install anything. If any
gate blocks a command, report it and wait. Anything outside "Affected files" goes in the report as a proposal, not an edit.
