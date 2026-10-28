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
