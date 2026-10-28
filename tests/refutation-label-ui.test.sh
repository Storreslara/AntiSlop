#!/usr/bin/env bash
# Tests eval/refutation-replay/label-ui.py: page data, escaping, export format, no repo writes.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$ROOT/eval/refutation-replay/label-ui.py"
RR="$ROOT/eval/refutation-replay"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0
ok() { echo "ok - $1"; }
bad() { echo "FAIL - $1"; fails=$((fails+1)); }
chk() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

before="$(git -C "$ROOT" status --porcelain)"

# real corpus, labels as committed
python3 "$GEN" --out "$T/real.html" >"$T/real.out" 2>&1; rc=$?
chk "real corpus: generator exits 0" "[ $rc -eq 0 ]"
chk "real corpus: prints output path and file:// URL" "grep -q 'file://' '$T/real.out' && grep -q '$T/real.html' '$T/real.out'"

# fixture: one tricky claim, mixed labels, a fix commit that exists
fix="$(python3 -c "import json;print(json.loads(open('$RR/corpus.jsonl').readline())['fix_commit'])")"
python3 - "$T" "$fix" <<'PY'
import json, sys
t, fix = sys.argv[1:3]
base = {"baseline": fix, "reviewed": fix, "fix_commit": fix, "fail_ts": "2026-01-01T00:00:00Z"}
rows = [
    dict(base, id="u1@t#D1", unit="u1", group="u1@t", dline='D1: README.md:3 quote " back \\ </script><b>x</b> tail'),
    dict(base, id="u1@t#D2", unit="u1", group="u1@t", dline="D2: no/such/file.txt:9 second claim"),
    dict(base, id="u2@t#D1", unit="u2", group="u2@t", dline="D1: README.md:1 third claim"),
]
open(t + "/corpus.jsonl", "w").write("".join(json.dumps(r) + "\n" for r in rows))
open(t + "/labels.tsv", "w").write("# id<TAB>real|bogus|unknown (fixture header)\nu1@t#D1\treal\nu1@t#D2\tunknown\nu2@t#D1\tbogus\n")
PY
cp "$T/labels.tsv" "$T/labels.orig"
python3 "$GEN" --corpus "$T/corpus.jsonl" --labels "$T/labels.tsv" --out "$T/fx.html" >"$T/fx.out" 2>&1; rc=$?
chk "fixture: generator exits 0" "[ $rc -eq 0 ]"

# blank fixture: nothing labeled, a default first header followed by a later # line
printf '# id<TAB>real|bogus|unknown (Gate G1: a human sets each label)\n# later comment\n' > "$T/blank.tsv"
python3 "$GEN" --corpus "$T/corpus.jsonl" --labels "$T/blank.tsv" --out "$T/blank.html" >"$T/blank.out" 2>&1; rc=$?
chk "blank fixture: generator exits 0" "[ $rc -eq 0 ]"

# multi fixture: 7 unlabeled rows in 3 groups; group ga@t is split (rows 0, 1 and 4), so card order != row order
python3 - "$T" "$fix" <<'PY'
import json, sys
t, fix = sys.argv[1:3]
base = {"baseline": fix, "reviewed": fix, "fix_commit": fix, "fail_ts": "2026-01-01T00:00:00Z"}
spec = [("ga", 1, "README.md:1 alpha one"), ("ga", 2, "no/such:2 alpha two"), ("gb", 1, "README.md:3 beta one"),
        ("gb", 2, "no/such:4 beta two"), ("ga", 3, "README.md:5 alpha three"), ("gc", 1, "no/such:6 gamma one"),
        ("gc", 2, "README.md:7 gamma two")]
rows = [dict(base, id="%s@t#D%d" % (g, n), unit=g, group=g + "@t", dline="D%d: %s" % (n, s)) for g, n, s in spec]
open(t + "/multi.jsonl", "w").write("".join(json.dumps(r) + "\n" for r in rows))
open(t + "/empty.jsonl", "w").write("")
PY
printf '# id<TAB>real|bogus|unknown (fixture header)\n' > "$T/hdr.tsv"
python3 "$GEN" --corpus "$T/multi.jsonl" --labels "$T/hdr.tsv" --out "$T/multi.html" >"$T/multi.out" 2>&1; rc=$?
chk "multi fixture: generator exits 0" "[ $rc -eq 0 ]"
python3 "$GEN" --corpus "$T/empty.jsonl" --labels "$T/hdr.tsv" --out "$T/empty.html" >"$T/empty.out" 2>&1; rc=$?
chk "empty corpus: generator exits 0" "[ $rc -eq 0 ]"

# default output path is neutral, under the temp dir, never a session directory
mkdir -p "$T/tmpd"
TMPDIR="$T/tmpd" python3 "$GEN" --corpus "$T/corpus.jsonl" --labels "$T/blank.tsv" >"$T/def.out" 2>&1; rc=$?
chk "default --out: lands in the temp dir as gateg-label-ui.html" "[ $rc -eq 0 ] && [ -s '$T/tmpd/gateg-label-ui.html' ] && grep -q 'file://' '$T/def.out'"
chk "default --out: no hardcoded session path in the generator" "! grep -q 'claude-1000' '$GEN'"

cat > "$T/probe.js" <<'JS'
const fs = require('fs');
function load(f) {
  const h = fs.readFileSync(f, 'utf8');
  const m = h.match(/<script id="data" type="application\/json">([\s\S]*?)<\/script>/);
  if (!m) throw new Error('no data script in ' + f);
  return { html: h, data: JSON.parse(m[1]) };
}
const [mode, f, extra] = process.argv.slice(2);
const { html, data } = load(f);
if (mode === 'ids') {
  const missing = data.rows.filter(r => !html.includes(r.id) && !JSON.stringify(data).includes(JSON.stringify(r.id).slice(1, -1)));
  console.log(data.rows.length + ' ' + missing.length);
} else if (mode === 'labels') {
  const c = {}; Object.values(data.labels).forEach(v => c[v] = (c[v] || 0) + 1);
  console.log(JSON.stringify(c));
} else if (mode === 'claim') {
  console.log(data.rows[0].dline);
} else if (mode === 'export') {
  const s = html.match(/\/\*EXPORT-BEGIN\*\/([\s\S]*?)\/\*EXPORT-END\*\//);
  if (!s) throw new Error('no export block');
  const buildTsv = new Function(s[1] + '; return buildTsv;')();
  process.stdout.write(buildTsv(data.header, data.rows.map(r => r.id), data.labels));
} else if (mode === 'header') {
  console.log(data.header);
}
JS

cat > "$T/dom-probe.js" <<'JS'
// usage: node dom-probe.js <jsdom dir> <fixture> <blank> <multi> <empty>; prints "name=PASS" or "name=FAIL detail"
const fs = require('fs');
const { JSDOM, VirtualConsole } = require(process.argv[2]);
const [fx, blank, multi, empty] = process.argv.slice(3, 7);
const D1 = 'u1@t#D1', D2 = 'u1@t#D2', U2 = 'u2@t#D1';
function page(f) {
  const errs = [], vc = new VirtualConsole();
  vc.on('jsdomError', e => errs.push(String(e && e.message || e)));
  const w = new JSDOM(fs.readFileSync(f, 'utf8'), { runScripts: 'dangerously', url: 'http://localhost/', virtualConsole: vc,
    beforeParse(w) { w.__scrolled = null; w.Element.prototype.scrollIntoView = function () { w.__scrolled = this; }; } }).window;
  w.__errs = errs;
  return w;
}
function key(w, k, target, repeat) { (target || w.document.body).dispatchEvent(new w.KeyboardEvent('keydown', { key: k, bubbles: true, repeat: !!repeat })); }
function curId(w) { const c = w.document.querySelectorAll('.card.cur'); return c.length === 1 ? c[0].dataset.id : c.length ? 'MANY' : null; }
function tick() { return new Promise(r => setTimeout(r, 0)); }
function stored(w) {
  const k = Object.keys(w.localStorage).find(x => x.indexOf('gateg-labels:') === 0);
  return k ? JSON.parse(w.localStorage.getItem(k)) : {};
}
function state(w) {
  const s = {};
  w.document.querySelectorAll('.card').forEach(c => { s[c.dataset.id] = (c.querySelector('.lab button.on') || { dataset: {} }).dataset.v; });
  return s;
}
function card(w, id) { return w.document.querySelector('.card[data-id="' + id + '"]'); }
function search(w, v) { const q = w.document.getElementById('q'); q.value = v; q.dispatchEvent(new w.Event('input')); }
function res(name, ok, det) { console.log(name + (ok ? '=PASS' : '=FAIL ' + det)); }
function unchanged(w, ids, want) { return ids.every(i => state(w)[i] === want && [undefined, want].includes(stored(w)[i])); }
const J = o => JSON.stringify(o);

(async () => {
  let w = page(blank);
  res('prelabel', Object.values(state(w)).every(v => v === 'unknown') && !w.document.querySelector('.card.real, .card.bogus') && J(stored(w)) === '{}', J(state(w)));
  const data = JSON.parse(w.document.getElementById('data').textContent);
  const c0 = card(w, D1).querySelector('.claim');
  res('claim-text', c0.querySelectorAll('*').length === 0 && c0.textContent === data.rows[0].dline, c0.innerHTML);

  w = page(blank); key(w, 'r', w.document.getElementById('q'));
  res('input-guard', unchanged(w, [D1, D2, U2], 'unknown'), J(state(w)));

  w = page(blank); key(w, 'j'); search(w, 'third'); key(w, 'r');
  res('search-hidden-card-unlabeled', unchanged(w, [D1, D2, U2], 'unknown') && curId(w) === null, J(state(w)) + J(stored(w)) + curId(w));
  key(w, 'j');
  const cur = w.document.querySelector('.card.cur');
  res('search-cur-is-visible', !!cur && !cur.classList.contains('hide') && cur.dataset.id === U2, cur && cur.dataset.id);

  w = page(blank); card(w, D1).querySelector('.s-real').click();
  w.document.querySelector('button[data-f="real"]').click(); key(w, 'u'); key(w, 'b');
  res('filter-u-b-hidden-card-unlabeled', state(w)[D1] === 'real' && !Object.values(stored(w)).includes('bogus') && !Object.values(state(w)).includes('bogus'), J(state(w)) + J(stored(w)));

  w = page(blank); key(w, 'j'); w.document.querySelector('details[data-g="u1@t"]').open = false; key(w, 'r'); key(w, 'b');
  res('collapsed-group-unlabeled', unchanged(w, [D1, D2, U2], 'unknown'), J(state(w)) + J(stored(w)));

  w = page(blank); search(w, '#d1'); key(w, 'j'); key(w, 'r');
  const c2 = w.document.querySelector('.card.cur');
  res('advance-skips-hidden', state(w)[D1] === 'real' && state(w)[D2] === 'unknown' && !!c2 && c2.dataset.id === U2, J(state(w)) + (c2 && c2.dataset.id));

  w = page(blank); search(w, 'third'); key(w, 'k'); key(w, 'j');
  const c3 = w.document.querySelector('.card.cur');
  res('jk-visible-only', !!c3 && c3.dataset.id === U2, c3 && c3.dataset.id);

  w = page(blank);
  const imp = w.document.getElementById('imp');
  Object.defineProperty(imp, 'files', { value: [new w.File(['# h\r\n' + D1 + '\treal\r\n' + D2 + '\tbogus\r\nnope#D9\treal\r\n'], 'l.tsv')] });
  imp.dispatchEvent(new w.Event('change'));
  await new Promise(r => setTimeout(r, 150));
  const msg = w.document.getElementById('msg').textContent;
  res('import-crlf-and-skips', state(w)[D1] === 'real' && state(w)[D2] === 'bogus' && /imported 2 labels, skipped 1/.test(msg), msg + J(state(w)));

  const A1 = 'ga@t#D1', A2 = 'ga@t#D2', A3 = 'ga@t#D3', B1 = 'gb@t#D1', B2 = 'gb@t#D2', C1 = 'gc@t#D1', C2 = 'gc@t#D2';
  const ALL = [A1, A2, A3, B1, B2, C1, C2];
  const only = (w, want) => ALL.every(i => state(w)[i] === (want[i] || 'unknown') && [undefined, want[i] || 'unknown'].includes(stored(w)[i]));
  w = page(multi); [A1, B1, C1].forEach(i => card(w, i).querySelector('.s-real').click());
  w.document.querySelector('button[data-f="real"]').click(); card(w, B1).querySelector('.s-real').click();
  w.__scrolled = null; key(w, 'u'); key(w, 'b');
  res('reviewer-a-filter-real-u-then-b', only(w, { [A1]: 'real', [C1]: 'real' }) && curId(w) === null && w.__scrolled === null, J(state(w)) + curId(w));

  w = page(multi); w.document.querySelector('button[data-f="unknown"]').click();
  card(w, B2).querySelector('.s-real').click(); key(w, 'r');
  res('reviewer-b-filter-unknown-click-then-r', only(w, { [B2]: 'real' }) && curId(w) === null, J(state(w)) + curId(w));

  w = page(multi); w.document.querySelector('button[data-f="unknown"]').click();
  card(w, B2).querySelector('.s-bogus').click(); w.__scrolled = null; key(w, 'r'); key(w, 'b');
  res('click-hides-card-under-unknown-then-r-labels-nothing', only(w, { [B2]: 'bogus' }) && curId(w) === null && w.__scrolled === null, J(state(w)) + curId(w));

  w = page(multi); key(w, 'j'); const jFirst = curId(w) === A1 && w.__scrolled === card(w, A1);
  w = page(multi); key(w, 'k'); const kLast = curId(w) === C2 && w.__scrolled === card(w, C2);
  w = page(multi); key(w, 'r');
  res('jk-from-no-target-start-at-ends', jFirst && kLast && only(w, {}) && curId(w) === null, J([jFirst, kLast, state(w)]));

  w = page(multi); key(w, 'j'); key(w, 'j'); key(w, 'j'); const outlined = curId(w); key(w, 'b');
  res('split-group-keyboard-labels-outlined-row', outlined === A3 && only(w, { [A3]: 'bogus' }), outlined + J(state(w)));

  w = page(multi); key(w, 'j'); key(w, 'r', null, true); key(w, 'b', null, true); key(w, 'u', null, true);
  const noRep = only(w, {}) && curId(w) === A1;
  key(w, 'r'); key(w, 'r', null, true); key(w, 'r', null, true);
  res('held-key-repeat-ignored', noRep && only(w, { [A1]: 'real' }) && curId(w) === A2, J(state(w)) + curId(w));

  w = page(empty); ['j', 'k', 'r', 'b', 'u'].forEach(k => key(w, k)); w.document.querySelector('button[data-f="unknown"]').click(); search(w, 'x');
  await tick();
  res('empty-corpus-no-error', w.__errs.length === 0 && w.document.querySelectorAll('.card').length === 0, J(w.__errs));

  let total = 0, err = '';
  for (const seed of [1, 7, 42, 1234]) {
    try { total += await prop(multi, seed, 400); } catch (e) { err = err || e.message; }
  }
  res('property-keyboard-writes-only-targeted-visible-card', !err && total >= 40, err || ('only ' + total + ' keyboard writes'));
})();

function rng(s) {
  return function () { s = s + 0x6D2B79F5 | 0; let t = Math.imul(s ^ s >>> 15, 1 | s); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
}
// Model of the targeting spec, independent of the page code: the human targets a card by clicking it (if it stays
// visible), by j/k, or by the scrolled-in auto-advance after their own r/b; any filter, search or collapse drops it.
async function prop(f, seed, steps) {
  const w = page(f), doc = w.document, R = rng(seed), pick = a => a[Math.floor(R() * a.length)];
  const data = JSON.parse(doc.getElementById('data').textContent), rows = {};
  data.rows.forEach(r => { rows[r.id] = r; });
  const order = Array.from(doc.querySelectorAll('.card')).map(c => c.dataset.id);
  const M = { labels: Object.assign({}, data.labels), filter: 'all', q: '', open: {}, target: null };
  data.rows.forEach(r => { M.open[r.group] = true; });
  const matches = id => {
    const r = rows[id];
    if (M.filter === 'amber' && r.hint === 'touches') return false;
    if (['real', 'bogus', 'unknown'].includes(M.filter) && M.labels[id] !== M.filter) return false;
    return !M.q || (r.id + ' ' + r.dline + ' ' + r.fix_subject).toLowerCase().includes(M.q);
  };
  const vis = id => matches(id) && M.open[rows[id].group];
  let writes = 0;
  for (let i = 0; i < steps; i++) {
    const x = R(), was = M.target;
    let act = '', moved = null;
    w.__scrolled = null;
    if (x < 0.5) {
      const k = pick(['j', 'j', 'k', 'r', 'r', 'b', 'b', 'u']), rep = R() < 0.15;
      act = 'key ' + k + (rep ? ' (repeat)' : '');
      const p = order.indexOf(M.target), after = order.filter((id, j) => vis(id) && j > p), before = order.filter((id, j) => vis(id) && j < p && p >= 0);
      if (k === 'j' || k === 'k') {
        const vo = order.filter(vis);
        moved = M.target === null ? (k === 'j' ? vo[0] : vo[vo.length - 1]) : (k === 'j' ? after[0] : before[before.length - 1]);
        key(w, k, null, rep);
        if (moved) M.target = moved;
      } else if (!rep && M.target !== null) {
        writes++;
        M.labels[M.target] = { r: 'real', b: 'bogus', u: 'unknown' }[k];
        key(w, k, null, rep);
        if (k !== 'u' && after.length) M.target = moved = after[0];
        else if (!vis(M.target)) M.target = null;
      } else key(w, k, null, rep);
    } else if (x < 0.7) {
      const vo = order.filter(vis);
      if (!vo.length) continue;
      const id = pick(vo), v = pick(['real', 'bogus', 'unknown']);
      act = 'click ' + v + ' on ' + id;
      card(w, id).querySelector('.s-' + v).click();
      M.labels[id] = v; M.target = vis(id) ? id : null;
    } else if (x < 0.8) {
      const fl = pick(['all', 'unknown', 'real', 'bogus', 'amber']);
      act = 'filter ' + fl; doc.querySelector('button[data-f="' + fl + '"]').click(); M.filter = fl; M.target = null;
    } else if (x < 0.9) {
      const q = pick(['', '', 'alpha', 'beta', 'gamma', '#d1', 'two', 'zzz']);
      act = 'search ' + q; search(w, q); M.q = q; M.target = null;
    } else {
      const gs = Object.keys(M.open).filter(g => order.some(id => rows[id].group === g && matches(id)));
      if (!gs.length) continue;
      const g = pick(gs);
      act = 'toggle ' + g; doc.querySelector('details.grp[data-g="' + g + '"] > summary').click(); M.open[g] = !M.open[g];
      await tick(); M.target = null;
    }
    const at = 'seed ' + seed + ' step ' + i + ' ' + act + ' (target ' + was + '): ';
    const st = state(w), sv = stored(w);
    const off = order.filter(id => st[id] !== M.labels[id] || (id in sv && sv[id] !== M.labels[id]));
    if (off.length) throw new Error(at + 'label landed off target on ' + J(off) + ' ' + J(st));
    const hid = order.filter(id => { const c = card(w, id), g = c.parentNode; return vis(id) === (c.classList.contains('hide') || !g.open || g.classList.contains('hide')); });
    if (hid.length) throw new Error(at + 'visibility disagrees on ' + J(hid));
    if (curId(w) !== M.target) throw new Error(at + 'outlined ' + curId(w) + ' but targeted ' + M.target);
    if (moved && w.__scrolled !== card(w, moved)) throw new Error(at + 'moved to ' + moved + ' without scrolling it into view');
  }
  return writes;
}
JS

if command -v node >/dev/null 2>&1; then
  chk "real corpus: 41 rows, all ids present" "[ \"\$(node '$T/probe.js' ids '$T/real.html')\" = '41 0' ]"
  chk "real corpus: embedded data parses, nothing pre-labelled real/bogus" "[ \"\$(node '$T/probe.js' labels '$T/real.html')\" = '{\"unknown\":41}' ]"
  chk "fixture: mixed labels reflected" "[ \"\$(node '$T/probe.js' labels '$T/fx.html')\" = '{\"real\":1,\"unknown\":1,\"bogus\":1}' ]"
  chk "fixture: claim round-trips through JSON intact" "[ \"\$(node '$T/probe.js' claim '$T/fx.html')\" = \"\$(python3 -c \"import json;print(json.loads(open('$T/corpus.jsonl').readline())['dline'])\")\" ]"
  node "$T/probe.js" export "$T/fx.html" > "$T/exported.tsv" 2>"$T/exp.err"
  chk "export: fixture labels reproduce labels.tsv byte-identical" "cmp -s '$T/exported.tsv' '$T/labels.orig'"
  node "$T/probe.js" export "$T/real.html" > "$T/exported-real.tsv" 2>>"$T/exp.err"
  chk "export: real labels reproduce committed labels.tsv byte-identical" "cmp -s '$T/exported-real.tsv' '$RR/labels.tsv'"
else
  echo "SKIP - node not found: JSON/export checks skipped"
fi

if command -v node >/dev/null 2>&1; then
  chk "header: first header line kept when a later # line follows" "[ \"\$(node '$T/probe.js' header '$T/blank.html')\" = '# id<TAB>real|bogus|unknown (Gate G1: a human sets each label)' ]"
fi

# real page handlers under jsdom (JSDOM_PATH or $ROOT/node_modules; nothing is installed)
JSDOM=""
for c in "${JSDOM_PATH:-}" "$ROOT/node_modules/jsdom"; do
  [ -n "$c" ] && [ -f "$c/package.json" ] && { JSDOM="$c"; break; }
done
if command -v node >/dev/null 2>&1 && [ -n "$JSDOM" ]; then
  node "$T/dom-probe.js" "$JSDOM" "$T/fx.html" "$T/blank.html" "$T/multi.html" "$T/empty.html" > "$T/dom.out" 2>"$T/dom.err"
  chk "dom probe: ran and reported 18 scenarios" "[ \"\$(grep -c '=' '$T/dom.out')\" -eq 18 ] || { cat '$T/dom.err' | head -5; false; }"
  while IFS= read -r line; do
    case "$line" in
      *=PASS) ok "dom: ${line%=PASS}" ;;
      *) bad "dom: $line" ;;
    esac
  done < "$T/dom.out"
elif [ -n "${LABEL_UI_REQUIRE_DOM:-}" ]; then
  bad "dom probe: LABEL_UI_REQUIRE_DOM is set but node plus jsdom was not found (set JSDOM_PATH)"
else
  echo "SKIP !!! node plus jsdom not found (set JSDOM_PATH): ALL keyboard/handler checks SKIPPED, this run proves nothing about them !!!"
fi

chk "fixture: exactly 2 </script> closers (data + code), none from claim" "[ \"\$(grep -o '</script>' '$T/fx.html' | wc -l)\" -eq 2 ] && ! grep -q '</script><b>' '$T/fx.html'"
chk "fixture: no raw <b>x</b> from claim in output" "! grep -q '<b>x</b>' '$T/fx.html'"
chk "page is self-contained (no http(s) resource refs)" "! grep -Eq '(src|href)=[\"'\\'']https?:' '$T/real.html'"
chk "page declares hint-not-label wording" "grep -q 'not labels' '$T/real.html'"
chk "page shows the next-step command" "grep -q 'build-corpus.py --check' '$T/real.html'"

after="$(git -C "$ROOT" status --porcelain)"
chk "generator modified no tracked file" "[ \"$before\" = \"$after\" ]"
chk "labels.tsv and corpus.jsonl untouched" "git -C '$ROOT' diff --quiet -- eval/refutation-replay/labels.tsv eval/refutation-replay/corpus.jsonl"

[ "$fails" -eq 0 ] && { echo "PASS"; exit 0; }
echo "$fails failure(s)"; exit 1
