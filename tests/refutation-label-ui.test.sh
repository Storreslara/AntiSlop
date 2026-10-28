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
// usage: node dom-probe.js <jsdom dir> <fixture page> <blank page>; prints "name=PASS" or "name=FAIL detail"
const fs = require('fs');
const { JSDOM } = require(process.argv[2]);
const [fx, blank] = [process.argv[3], process.argv[4]];
const D1 = 'u1@t#D1', D2 = 'u1@t#D2', U2 = 'u2@t#D1';
function page(f) {
  return new JSDOM(fs.readFileSync(f, 'utf8'), { runScripts: 'dangerously', url: 'http://localhost/',
    beforeParse(w) { w.Element.prototype.scrollIntoView = function () {}; } }).window;
}
function key(w, k, target) { (target || w.document.body).dispatchEvent(new w.KeyboardEvent('keydown', { key: k, bubbles: true })); }
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

  w = page(blank); search(w, 'third'); key(w, 'r');
  const cur = w.document.querySelector('.card.cur');
  res('search-hidden-card-unlabeled', unchanged(w, [D1, D2], 'unknown'), J(state(w)) + J(stored(w)));
  res('search-cur-is-visible', !!cur && !cur.classList.contains('hide') && cur.dataset.id === U2, cur && cur.dataset.id);

  w = page(blank); card(w, D1).querySelector('.s-real').click();
  w.document.querySelector('button[data-f="real"]').click(); key(w, 'u'); key(w, 'b');
  res('filter-u-b-hidden-card-unlabeled', state(w)[D1] === 'unknown' && !Object.values(stored(w)).includes('bogus') && !Object.values(state(w)).includes('bogus'), J(state(w)) + J(stored(w)));

  w = page(blank); w.document.querySelector('details[data-g="u1@t"]').open = false; key(w, 'r'); key(w, 'b');
  res('collapsed-group-unlabeled', unchanged(w, [D1, D2], 'unknown'), J(state(w)) + J(stored(w)));

  w = page(blank); search(w, '#d1'); key(w, 'r');
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
})();
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

# real page handlers under jsdom (found locally; nothing is installed)
JSDOM=""
for c in "${JSDOM_PATH:-}" "$ROOT/node_modules/jsdom" "$HOME"/*/node_modules/jsdom "$HOME"/*/frontend/node_modules/jsdom; do
  [ -n "$c" ] && [ -f "$c/package.json" ] && { JSDOM="$c"; break; }
done
if command -v node >/dev/null 2>&1 && [ -n "$JSDOM" ]; then
  node "$T/dom-probe.js" "$JSDOM" "$T/fx.html" "$T/blank.html" > "$T/dom.out" 2>"$T/dom.err"
  chk "dom probe: ran and reported 10 scenarios" "[ \"\$(grep -c '=' '$T/dom.out')\" -eq 10 ] || { cat '$T/dom.err' | head -5; false; }"
  while IFS= read -r line; do
    case "$line" in
      *=PASS) ok "dom: ${line%=PASS}" ;;
      *) bad "dom: $line" ;;
    esac
  done < "$T/dom.out"
else
  echo "SKIP - node plus jsdom not found (set JSDOM_PATH): keyboard/handler checks skipped"
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
