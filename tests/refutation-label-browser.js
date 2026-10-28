// Real-browser probe for the Gate G1 labeling page. usage: node refutation-label-browser.js <playwright dir> <url> <labels file> <log file> <empty-url>
// Prints "B<nn> name=PASS" or "B<nn> name=FAIL detail"; exit 3 when Chromium cannot be launched.
'use strict';
const fs = require('fs');
const [dir, url, labelsFile, logFile, emptyUrl] = process.argv.slice(2, 7);
const SEED = parseInt(process.env.LABEL_PROBE_SEED || '20261028', 10);
const STEPS = parseInt(process.env.LABEL_PROBE_STEPS || '200', 10);
const NAV_KEYS = ['j', 'k', 'Space', 'Enter', 'Tab', 'Shift+Tab', 'ArrowDown', 'PageDown', 'Home', 'End'];
const LABEL_KEYS = ['r', 'b', 'u', 'R', 'B', 'U'];
const VALUES = ['real', 'bogus', 'unknown'];

// "On screen": displayed, top edge at or below the sticky header's bottom edge and above the viewport's bottom edge.
const PAGE_HELPERS = () => {
  const card = (id) => Array.from(document.querySelectorAll('article')).find((a) => a.dataset.id === id) || null;
  const hb = () => document.querySelector('header.top').getBoundingClientRect().bottom;
  const onScreen = (id) => {
    const a = card(id);
    if (!a || a.getClientRects().length === 0) return false;
    const t = a.getBoundingClientRect().top;
    return t >= hb() - 1 && t < innerHeight;
  };
  const shown = () => Array.from(document.querySelectorAll('article')).filter((a) => a.getClientRects().length > 0).map((a) => a.dataset.id);
  const place = (b) => {
    const r = b.getBoundingClientRect();
    const x = r.left + r.width / 2, y = r.top + r.height / 2;
    const el = r.width > 0 ? document.elementFromPoint(x, y) : null;
    return { x, y, valid: !!el && b.contains(el) && x >= 0 && x < innerWidth && y > hb() && y < innerHeight };
  };
  const btn = (id, value) => {
    const a = card(id);
    const b = a && a.querySelector('.lbl[data-value="' + value + '"]');
    return b ? place(b) : null;
  };
  const validButtons = () => {
    const out = [];
    document.querySelectorAll('article .lbl').forEach((b) => {
      const p = place(b);
      if (p.valid) out.push({ id: b.closest('article').dataset.id, value: b.dataset.value, x: p.x, y: p.y });
    });
    return out;
  };
  const hitLbl = (x, y) => {
    const el = document.elementFromPoint(x, y);
    const b = el && el.closest('.lbl');
    return b ? { id: b.closest('article').dataset.id, value: b.dataset.value } : null;
  };
  const bring = (id, frac) => {
    const a = card(id);
    const b = a && a.querySelector('.lbl');
    if (!b) return false;
    const r = b.getBoundingClientRect();
    window.scrollBy(0, r.top + r.height / 2 - innerHeight * frac);
    return true;
  };
  const state = () => ({ target: typeof target === 'undefined' ? undefined : target, pending: document.body.dataset.pending,
    active: document.activeElement ? document.activeElement.className + '|' + document.activeElement.tagName : '' });
  window.__p = { card, hb, onScreen, shown, btn, validButtons, hitLbl, bring, state };
};

function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function readLabels() {
  const lines = fs.readFileSync(labelsFile, 'utf8').split('\n');
  if (!lines[0].startsWith('#') || lines[lines.length - 1] !== '') throw new Error('labels file is not header plus lines: ' + JSON.stringify(lines.slice(0, 2)));
  const m = new Map();
  for (const l of lines.slice(1, -1)) {
    const [id, v] = l.split('\t');
    if (!VALUES.includes(v)) throw new Error('bad label line ' + JSON.stringify(l));
    m.set(id, v);
  }
  return m;
}

function extWrite(m) {
  const head = fs.readFileSync(labelsFile, 'utf8').split('\n')[0];
  const tmp = labelsFile + '.probe';
  fs.writeFileSync(tmp, head + '\n' + Array.from(m, ([i, v]) => i + '\t' + v + '\n').join(''));
  fs.renameSync(tmp, labelsFile);
}

const errs = [];
let allow409 = false;
let browser, ctx;

async function newPage(u, viewport) {
  const page = await ctx.newPage();
  page.setDefaultTimeout(8000);
  const st = { page, posts: 0, inflight: 0, model: null, step: 'init' };
  page.on('request', (r) => { st.inflight++; if (r.method() === 'POST') st.posts++; });
  page.on('requestfinished', () => { st.inflight--; });
  page.on('requestfailed', () => { st.inflight--; });
  page.on('pageerror', (e) => errs.push('pageerror: ' + e.message));
  page.on('console', (m) => {
    if (m.type() !== 'error') return;
    if (allow409 && /status of 409/.test(m.text())) return;
    errs.push('console: ' + m.text());
  });
  await page.addInitScript(PAGE_HELPERS);
  if (viewport) await page.setViewportSize(viewport);
  await page.goto(u);
  await settle(st);
  st.model = readLabels();
  return st;
}

async function settle(st) {
  await st.page.waitForFunction(() => document.body.dataset.pending === '0');
  for (let i = 0; i < 300 && st.inflight > 0; i++) await st.page.waitForTimeout(10);
  await st.page.evaluate(() => new Promise((res) => {
    let last = -1, n = 0;
    const f = () => { if (window.scrollY === last) { if (++n >= 4) return res(); } else { n = 0; last = window.scrollY; } requestAnimationFrame(f); };
    f();
  }));
}

function verify(st, action) {
  const got = readLabels();
  const want = st.model;
  for (const [id, v] of want) {
    if (got.get(id) !== v) throw new Error('step ' + st.step + ' action ' + action + ' seed ' + SEED + ': ' + id + ' expected ' + v + ' got ' + got.get(id));
  }
  if (got.size !== want.size) throw new Error('step ' + st.step + ' action ' + action + ' seed ' + SEED + ': row count changed');
}

async function step(st, action, fn) {
  await fn();
  await settle(st);
  verify(st, action);
}

async function clickLabel(st, id, value) {
  const ev = () => st.page.evaluate(([i, v]) => window.__p.btn(i, v), [id, value]);
  let b = await ev();
  if (!b || !b.valid) {
    await st.page.evaluate((i) => window.__p.bring(i, 0.6), id);
    await settle(st);
    b = await ev();
  }
  if (!b || !b.valid) throw new Error('could not place a click on ' + id + ' ' + value);
  await st.page.mouse.click(b.x, b.y);
  st.model.set(id, value);
}

async function clickCardBody(st, id) {
  const pt = await st.page.evaluate((i) => {
    const m = window.__p.card(i).querySelector('.meta');
    const r = m.getBoundingClientRect();
    return { x: r.left + 4, y: r.top + r.height / 2 };
  }, id);
  await st.page.mouse.click(pt.x, pt.y);
  await settle(st);
  const t = (await st.page.evaluate(() => window.__p.state())).target;
  if (t !== id) throw new Error('card click set target ' + t + ' not ' + id);
}

const onScreen = (st, id) => st.page.evaluate((i) => window.__p.onScreen(i), id);
const shown = (st) => st.page.evaluate(() => window.__p.shown());
const stateOf = (st) => st.page.evaluate(() => window.__p.state());

async function firstOnScreen(st) {
  for (const id of await shown(st)) if (await onScreen(st, id)) return id;
  throw new Error('no card on screen');
}

async function noWrites(st, label, keys) {
  for (const k of keys) {
    const before = st.posts;
    st.step = k;
    await step(st, label + ' ' + k, () => st.page.keyboard.press(k));
    if (st.posts !== before) throw new Error(label + ' ' + k + ' sent a POST');
  }
}

async function b01() {
  const st = await newPage(url, { width: 1280, height: 800 });
  const r = await st.page.evaluate(() => {
    const cards = Array.from(document.querySelectorAll('article'));
    const txt = (s) => document.querySelector(s) ? document.querySelector(s).textContent : '';
    return {
      n: cards.length, rows: document.querySelector('main').dataset.rows, ids: cards.map((a) => a.dataset.id),
      counts: [txt('#n-real'), txt('#n-bogus'), txt('#n-unknown')], rules: document.body.innerText, min: D.min_real, max: D.max_bogus,
      cards: cards.map((a) => ({ claim: a.querySelector('.claim').textContent, fix: a.querySelector('.fix').textContent,
        cite: a.querySelectorAll('.files li.cite').length, files: a.querySelectorAll('.files li').length,
        hint: a.querySelector('.hint').textContent, xd: !!a.querySelector('button.xd'), diffHidden: a.querySelector('pre.diff').getClientRects().length === 0 })),
      rowsData: D.rows.map((x) => ({ id: x.id, dline: x.dline, sha: x.fix_sha, subject: x.fix_subject })),
    };
  });
  const model = st.model;
  if (r.n !== model.size || String(r.n) !== r.rows) throw new Error('cards ' + r.n + ', data-rows ' + r.rows + ', file ' + model.size);
  if (JSON.stringify(r.ids) !== JSON.stringify(Array.from(model.keys()))) throw new Error('card ids differ from the file');
  const c = (v) => Array.from(model.values()).filter((x) => x === v).length;
  const want = VALUES.map(c);
  const got = r.counts.map((s) => parseInt(s.replace(/\D/g, ''), 10));
  if (JSON.stringify(want) !== JSON.stringify(got)) throw new Error('counts ' + JSON.stringify(got) + ' vs file ' + JSON.stringify(want));
  if (r.min !== null && (!r.rules.includes('at least ' + r.min + ' real') || !r.rules.includes('at most ' + r.max + ' bogus'))) throw new Error('targets missing');
  r.cards.forEach((k, i) => {
    const d = r.rowsData[i];
    if (!k.claim.includes(d.dline)) throw new Error('claim missing on ' + d.id);
    if (!k.fix.includes(d.sha) || !k.fix.includes(d.subject)) throw new Error('fix commit missing on ' + d.id);
    if (k.files < 1 || k.cite < 1) throw new Error('numstat or cited mark missing on ' + d.id);
    if (!/not a label/.test(k.hint)) throw new Error('hint wording missing on ' + d.id);
    if (!k.xd || !k.diffHidden) throw new Error('diff not collapsed with an expand control on ' + d.id);
  });
  await st.page.close();
}

async function b02() {
  const st = await newPage(url, { width: 1280, height: 800 });
  const id = (await shown(st))[1];
  for (const v of ['real', 'bogus', 'unknown']) {
    st.step = v;
    await step(st, 'click ' + v, () => clickLabel(st, id, v));
    const s = await stateOf(st);
    if (/\blbl\b/.test(s.active)) throw new Error('a label button kept focus after ' + v + ': ' + s.active);
    if (s.target !== id) throw new Error('target after ' + v + ' is ' + s.target + ', not the clicked card');
    if (readLabels().get(id) !== v) throw new Error('card line is not ' + v);
  }
  await st.page.close();
}

async function b03() {
  const st = await newPage(url, { width: 1280, height: 800 });
  await clickCardBody(st, await firstOnScreen(st));
  await noWrites(st, 'navigation key', NAV_KEYS);
  await st.page.close();
}

async function b04() {
  const st = await newPage(url, { width: 1280, height: 800 });
  const id = (await shown(st))[2];
  await st.page.evaluate((i) => window.__p.bring(i, 0.6), id);
  await settle(st);
  const focus = () => st.page.evaluate((i) => { window.__p.card(i).querySelector('.lbl[data-value="real"]').focus(); }, id);
  for (const k of ['Enter', 'Space']) {
    const before = st.posts;
    await step(st, 'focus then ' + k, async () => { await focus(); await st.page.keyboard.press(k); });
    if (st.posts !== before) throw new Error('trusted ' + k + ' on a focused label button sent a POST');
  }
  const scripted = [['script click', (i) => window.__p.card(i).querySelector('.lbl[data-value="real"]').click()],
    ['detail 0 click', (i) => window.__p.card(i).querySelector('.lbl[data-value="real"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 0 }))]];
  for (const [name, fn] of scripted) {
    const before = st.posts;
    await step(st, name, () => st.page.evaluate(fn, id));
    if (st.posts !== before) throw new Error(name + ' sent a POST');
  }
  await st.page.close();
}

async function b05() {
  const st = await newPage(url, { width: 1280, height: 800 });
  await clickCardBody(st, await firstOnScreen(st));
  await noWrites(st, 'label key', LABEL_KEYS);
  await st.page.close();
}

async function b06() {
  extWrite(new Map(Array.from(readLabels().keys(), (i) => [i, 'unknown'])));
  const st = await newPage(url, { width: 1280, height: 800 });
  await st.page.evaluate(() => { document.documentElement.style.overflowAnchor = 'none'; document.body.style.overflowAnchor = 'none'; });
  await st.page.locator('.flt[data-f="unknown"]').click();
  await settle(st);
  for (const id of (await shown(st)).slice(0, 4)) await st.page.locator('article[data-id="' + id + '"] .xd').click();
  await settle(st);
  for (let n = 1; n <= 6; n++) {
    st.step = 'repeat ' + n;
    const ids = await shown(st);
    const [c2, c3] = [ids[1], ids[2]];
    await st.page.evaluate((i) => { window.__p.bring(i, (innerHeight - 30) / innerHeight); }, c2);
    await settle(st);
    await step(st, 'label card 2 real, repeat ' + n, () => clickLabel(st, c2, 'real'));
    const hidden = !(await shown(st)).includes(c2);
    const s = await stateOf(st);
    if (!hidden) throw new Error('repeat ' + n + ': the labelled card was not hidden by the filter');
    if (s.target !== c3) throw new Error('repeat ' + n + ': target is ' + s.target + ', not the next visible card');
    if (!(await onScreen(st, c3))) throw new Error('repeat ' + n + ': the new target is not on screen');
  }
  await st.page.close();
}

async function b07() {
  const st = await newPage(url, { width: 1280, height: 800 });
  await st.page.evaluate(() => window.scrollTo(0, 0));
  await settle(st);
  await clickCardBody(st, await firstOnScreen(st));
  for (const [key, dy] of [['j', 1500], ['k', -1500]]) {
    await st.page.mouse.move(400, 500);
    for (let i = 0; i < 4; i++) {
      const t = (await stateOf(st)).target;
      if (t && !(await onScreen(st, t))) break;
      await st.page.mouse.wheel(0, dy);
      await settle(st);
    }
    const t0 = (await stateOf(st)).target;
    if (t0 && (await onScreen(st, t0))) throw new Error('could not scroll the target off screen for ' + key);
    st.step = key;
    await step(st, 'key ' + key, () => st.page.keyboard.press(key));
    const t1 = (await stateOf(st)).target;
    if (!t1 || !(await onScreen(st, t1))) throw new Error(key + ' selected ' + t1 + ', which is not on screen');
    await st.page.mouse.move(400, 500);
    for (let i = 0; i < 6; i++) { await st.page.mouse.wheel(0, key === 'j' ? 1500 : -1500); await settle(st); }
  }
  await st.page.close();
}

async function b08() {
  allow409 = true;
  try {
    const st = await newPage(url, { width: 1280, height: 800 });
    const ids = await shown(st);
    const x = ids[ids.length - 1];
    const other = st.model.get(x) === 'bogus' ? 'real' : 'bogus';
    st.model.set(x, other);
    extWrite(st.model);
    const resp = st.page.waitForResponse((r) => r.url().endsWith('/label') && r.status() === 409);
    const reloaded = st.page.waitForEvent('load');
    const y = ids[3];
    const oldY = st.model.get(y);
    await clickLabel(st, y, 'real');
    st.model.set(y, oldY);
    const r = await resp;
    if (!r) throw new Error('no 409');
    await st.page.waitForFunction(() => /labels\.tsv changed on disk/.test(document.body.innerText));
    await reloaded;
    await settle(st);
    verify(st, 'after 409');
    const seen = await st.page.evaluate((i) => window.__p.card(i).className, x);
    if (!new RegExp('\\b' + other + '\\b').test(seen)) throw new Error('after the reload the page does not show the outside value ' + other + ': ' + seen);
    st.model = readLabels();
    await step(st, 'click after reload', () => clickLabel(st, y, 'real'));
    if (readLabels().get(y) !== 'real') throw new Error('the next click did not write');
    await st.page.close();
  } finally { allow409 = false; }
}

async function b09() {
  extWrite(new Map(Array.from(readLabels().keys(), (i) => [i, 'unknown'])));
  const st = await newPage(url, { width: 1280, height: 800 });
  const r = rng(SEED);
  const pick = (a) => a[Math.floor(r() * a.length)];
  const sizes = [{ width: 1280, height: 800 }, { width: 800, height: 600 }, { width: 390, height: 844 }];
  const actions = [
    ['click-label', 4, async () => {
      const v = await st.page.evaluate(() => window.__p.validButtons());
      if (!v.length) return;
      const b = pick(v);
      await st.page.mouse.click(b.x, b.y);
      st.model.set(b.id, b.value);
    }],
    ['click-point', 2, async () => {
      const vp = st.page.viewportSize();
      const x = Math.floor(r() * vp.width), y = Math.floor(r() * vp.height);
      const hit = await st.page.evaluate(([a, b]) => window.__p.hitLbl(a, b), [x, y]);
      await st.page.mouse.click(x, y);
      if (hit) st.model.set(hit.id, hit.value);
    }],
    ['key', 3, async () => { await st.page.keyboard.press(pick(NAV_KEYS.concat(['r', 'b', 'u']))); }],
    ['focus-key', 2, async () => {
      const n = await st.page.evaluate(() => document.querySelectorAll('.lbl').length);
      await st.page.evaluate((i) => document.querySelectorAll('.lbl')[i].focus(), Math.floor(r() * n));
      await st.page.keyboard.press(pick(['Enter', 'Space']));
    }],
    ['filter', 1, async () => { await st.page.locator('.flt[data-f="' + pick(['all', 'unknown', 'real', 'bogus']) + '"]').click(); }],
    ['search', 1, async () => { await st.page.fill('#q', pick(['', 'claim', 'tall', 'D1:', 'r', 'b', 'u', 'zzz'])); }],
    ['group', 1, async () => { await st.page.locator('.gt').nth(Math.floor(r() * 3)).click(); }],
    ['diff', 1, async () => {
      const ids = await shown(st);
      if (ids.length) await st.page.locator('article[data-id="' + pick(ids) + '"] .xd').click();
    }],
    ['wheel', 2, async () => {
      await st.page.mouse.move(400, 400);
      await st.page.mouse.wheel(0, (r() < 0.5 ? -1 : 1) * (200 + Math.floor(r() * 1800)));
    }],
    ['resize', 1, async () => { await st.page.setViewportSize(pick(sizes)); }],
  ];
  const bag = actions.flatMap((a) => Array(a[1]).fill(a));
  for (let i = 1; i <= STEPS; i++) {
    const a = pick(bag);
    st.step = i;
    await step(st, a[0], a[2]);
  }
  await st.page.close();
}

async function b10() {
  const st = await newPage(emptyUrl, { width: 1280, height: 800 });
  const before = errs.length;
  const n = await st.page.evaluate(() => [document.querySelectorAll('article').length, document.querySelector('main').dataset.rows]);
  if (n[0] !== 0 || n[1] !== '0') throw new Error('empty page shows ' + n.join('/') + ' cards/rows');
  await st.page.keyboard.press('j');
  await st.page.keyboard.press('k');
  for (const f of ['unknown', 'real', 'bogus', 'all']) await st.page.locator('.flt[data-f="' + f + '"]').click();
  await settle(st);
  if (errs.length !== before) throw new Error('empty page threw: ' + errs.slice(before).join(' | '));
  await st.page.close();
}

async function b11() {
  if (errs.length) throw new Error(errs.slice(0, 3).join(' | '));
}

const CASES = [['B01 cards render with evidence', b01], ['B02 mouse clicks write that card and leave no focus', b02],
  ['B03 navigation keys write nothing', b03], ['B04 keyboard, script and detail-0 clicks write nothing', b04],
  ['B05 r b u keys write nothing', b05], ['B06 filter hides the labelled card, next target stays on screen', b06],
  ['B07 j and k pick an on-screen card', b07], ['B08 a file changed on disk gets 409 and a reload', b08],
  ['B09 seeded random input seed ' + SEED + ' steps ' + STEPS, b09], ['B10 empty corpus page is safe', b10],
  ['B11 no page or console errors', b11]];

(async () => {
  try {
    const pw = require(dir);
    browser = await pw.chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
    ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  } catch (e) {
    console.error('browser unavailable: ' + String((e && e.message) || e).split('\n')[0]);
    process.exit(3);
  }
  for (const [name, fn] of CASES) {
    try { await fn(); console.log(name + '=PASS'); }
    catch (e) { console.log(name + '=FAIL ' + String((e && e.message) || e).split('\n')[0]); }
  }
  await browser.close();
})().catch((e) => { console.log('probe crashed=FAIL ' + String((e && e.message) || e).split('\n')[0]); process.exit(1); });
