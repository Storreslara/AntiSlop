#!/usr/bin/env python3
# Writes one self-contained HTML page for the human Gate G labeling of the refutation replay corpus.
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(tempfile.gettempdir(), 'gateg-label-ui.html')
DEFAULT_HEADER = '# id<TAB>real|bogus|unknown (Gate G1: a human sets each label)'
DIFF_CAP = 200


def git(repo, *args):
    p = subprocess.run(['git', '-C', repo] + list(args), capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else None


def read_labels(path):
    header, labels, seen = DEFAULT_HEADER, {}, False
    for l in open(path):
        if l.startswith('#'):
            header, seen = (header if seen else l.rstrip('\n')), True
        elif l.strip():
            k, _, v = l.rstrip('\n').partition('\t')
            labels[k] = v
    return header, labels


def cited(dline):
    m = re.match(r'^D\d: ([^\s:]+):(\d+)', dline)
    return (m.group(1), int(m.group(2))) if m else (None, None)


def evidence(repo, row):
    fix = row['fix_commit']
    subject = (git(repo, 'show', '-s', '--format=%h %s', fix) or '').strip()
    out = {'fix_sha': fix[:8], 'fix_subject': subject.partition(' ')[2] or '(fix commit unreachable)',
           'files': [], 'diff': '', 'diff_truncated': False}
    numstat = git(repo, 'show', '--numstat', '--format=', fix)
    path, line = cited(row['dline'])
    out['cited_path'], out['cited_line'] = path, line
    if numstat is None:
        out['hint'] = 'unknown'
        return out
    for l in numstat.splitlines():
        a, d, p = (l.split('\t') + ['', '', ''])[:3]
        out['files'].append({'path': p, 'add': a, 'del': d})
    touched = any(f['path'] == path for f in out['files'])
    out['hint'] = 'touches' if touched else 'untouched'
    if touched:
        lines = (git(repo, 'show', '--format=', fix, '--', path) or '').splitlines()
        out['diff'] = '\n'.join(lines[:DIFF_CAP])
        out['diff_truncated'] = len(lines) > DIFF_CAP
    return out


def build_data(repo, corpus, labels_path):
    rows = [json.loads(l) for l in open(corpus) if l.strip()]
    header, labels = read_labels(labels_path)
    out_rows = []
    for r in rows:
        e = evidence(repo, r)
        out_rows.append(dict({k: r[k] for k in ('id', 'unit', 'group', 'fail_ts', 'dline')}, **e))
    fp = hashlib.sha256(json.dumps([[r['id'], r['dline']] for r in rows]).encode()).hexdigest()[:16]
    ids = [r['id'] for r in rows]
    return {'header': header, 'rows': out_rows, 'fingerprint': fp,
            'labels': {i: labels.get(i) if labels.get(i) in ('real', 'bogus', 'unknown') else 'unknown' for i in ids}}


def embed(data):
    s = json.dumps(data, ensure_ascii=True)
    return s.replace('<', '\\u003c').replace('>', '\\u003e').replace('&', '\\u0026')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', default=DEFAULT_OUT)
    p.add_argument('--corpus', default=os.path.join(HERE, 'corpus.jsonl'))
    p.add_argument('--labels', default=None)
    p.add_argument('--repo', default=os.path.join(HERE, '..', '..'))
    a = p.parse_args()
    labels_path = a.labels or os.path.join(os.path.dirname(os.path.abspath(a.corpus)), 'labels.tsv')
    data = build_data(a.repo, a.corpus, labels_path)
    html = TEMPLATE.replace('__DATA__', embed(data))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, 'w') as f:
        f.write(html)
    print('wrote %s (%d rows)' % (a.out, len(data['rows'])))
    print('file://' + os.path.abspath(a.out))
    return 0


TEMPLATE = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Gate G labeling</title>
<style>
:root{--bg:#f6f7f9;--card:#fff;--ink:#1b1f24;--mute:#59636e;--line:#d0d7de;--real:#1a7f37;--realbg:#dafbe1;--bogus:#cf222e;--bogusbg:#ffebe9;--unk:#6e7781;--unkbg:#eaeef2;--amber:#9a6700;--amberbg:#fff8c5;--blue:#0969da}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,-apple-system,Segoe UI,sans-serif}
header.top{position:sticky;top:0;z-index:5;background:#fff;border-bottom:2px solid var(--line);padding:10px 16px}
.row{display:flex;flex-wrap:wrap;gap:12px;align-items:center}
.count{font-weight:700;font-size:18px;padding:2px 10px;border-radius:6px}
.c-real{background:var(--realbg);color:var(--real)}.c-bogus{background:var(--bogusbg);color:var(--bogus)}.c-unknown{background:var(--unkbg);color:var(--unk)}
.status{font-weight:700;padding:3px 10px;border-radius:6px;color:#fff}.ok{background:var(--real)}.no{background:var(--bogus)}
.rules{color:var(--mute);font-size:13px;margin-top:4px}
.bar{display:flex;height:8px;border-radius:4px;overflow:hidden;background:var(--unkbg);margin-top:6px}
.bar i{display:block;height:100%}
main{max-width:980px;margin:0 auto;padding:12px 16px 80px}
.tools{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:8px 0}
button,.btn{font:inherit;border:1px solid var(--line);background:#fff;border-radius:6px;padding:6px 12px;cursor:pointer}
button.on{background:var(--blue);color:#fff;border-color:var(--blue)}
input[type=search]{font:inherit;padding:6px 10px;border:1px solid var(--line);border-radius:6px;min-width:200px;flex:1}
.note{background:var(--amberbg);border:1px solid #d4a72c;border-radius:6px;padding:8px 12px;font-size:13px;margin:8px 0}
.next{background:#ddf4ff;border:1px solid #54aeff;border-radius:6px;padding:8px 12px;font-size:13px;margin:8px 0}
code,pre{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12.5px}
details.grp{margin:14px 0}
details.grp>summary{cursor:pointer;font-weight:700;padding:8px 12px;background:#fff;border:1px solid var(--line);border-radius:6px;list-style:none}
.card{background:var(--card);border:1px solid var(--line);border-left:6px solid var(--unk);border-radius:8px;padding:12px 14px;margin:10px 0}
.card.real{border-left-color:var(--real);background:#f6fff8}.card.bogus{border-left-color:var(--bogus);background:#fff8f7}
.card.cur{outline:3px solid var(--blue)}
.claim{white-space:pre-wrap;overflow-wrap:anywhere;font-size:15px;margin:6px 0}
.cut{color:var(--mute);font-size:12px}
.meta{color:var(--mute);font-size:12.5px}
.badge{display:inline-block;font-size:12px;font-weight:700;padding:1px 8px;border-radius:10px;border:1px solid}
.b-touch{color:var(--blue);border-color:var(--blue);background:#ddf4ff}.b-amber{color:var(--amber);border-color:#d4a72c;background:var(--amberbg)}
.files{margin:6px 0 0;padding:0;list-style:none;font-size:12.5px}
.files li{font-family:ui-monospace,Menlo,monospace;overflow-wrap:anywhere}.files li.cite{background:var(--amberbg)}
.add{color:var(--real)}.del{color:var(--bogus)}
.lab{display:flex;gap:8px;margin-top:10px}
.lab button{flex:1;font-size:17px;font-weight:700;padding:10px}
.lab button.s-real.on{background:var(--real);border-color:var(--real)}.lab button.s-bogus.on{background:var(--bogus);border-color:var(--bogus)}.lab button.s-unknown.on{background:var(--unk);border-color:var(--unk)}
pre.diff{max-height:320px;overflow:auto;background:#f6f8fa;border:1px solid var(--line);padding:8px;white-space:pre;margin:6px 0}
.hide{display:none}
@media(max-width:600px){.lab button{font-size:15px;padding:8px 4px}}
</style></head><body>
<header class="top">
 <div class="row">
  <span class="count c-real" id="n-real"></span><span class="count c-bogus" id="n-bogus"></span><span class="count c-unknown" id="n-unknown"></span>
  <span class="status" id="status"></span>
 </div>
 <div class="rules">Gate G: need at least <b>30 real</b> of <span id="total"></span>; at most <b>11 bogus</b> can be tolerated. Keys: j/k move, r real, b bogus, u unknown; keys act only on the outlined card (after a filter, search or collapse, press j/k or click a card first).</div>
 <div class="bar" id="bar"></div>
</header>
<main>
 <div class="note"><b>Hints are not labels.</b> The HINT badge only says whether the fix commit's diff touches the file the claim cites. You decide each label. Nothing is pre-selected: starting state is the committed labels.tsv plus this browser's saved work.</div>
 <div class="tools">
  <span id="filters"></span>
  <input type="search" id="q" placeholder="Search id, claim, fix subject">
 </div>
 <div class="tools">
  <button id="dl">Download labels.tsv</button><button id="cp">Copy labels.tsv</button>
  <label class="btn">Import labels.tsv<input type="file" id="imp" accept=".tsv,.txt,text/plain" hidden></label>
  <span class="meta" id="msg"></span>
 </div>
 <div class="next"><b>After export:</b> 1) save the file over <code>eval/refutation-replay/labels.tsv</code>; 2) run <code>python3 eval/refutation-replay/build-corpus.py --check</code> (must print <code>unlabeled=0</code>); 3) commit. This page cannot write into the repo.</div>
 <div id="groups"></div>
</main>
<script id="data" type="application/json">__DATA__</script>
<script>
/*EXPORT-BEGIN*/
function buildTsv(header, ids, labels) {
  return header + '\n' + ids.map(function (i) { return i + '\t' + (labels[i] || 'unknown') + '\n'; }).join('');
}
/*EXPORT-END*/
(function () {
  var D = JSON.parse(document.getElementById('data').textContent);
  var KEY = 'gateg-labels:' + D.fingerprint;
  var VALID = ['real', 'bogus', 'unknown'];
  var ids = D.rows.map(function (r) { return r.id; });
  // Invariant: r/b/u write only onto rows[cur], the card outlined as .cur, and only while it is visible (filter,
  // search, group open) and deliberately targeted since the visible set last changed: by a click on that card,
  // by j/k, or by the scrolled-into-view auto-advance after the human's own r/b. Anything else that changes the
  // visible set (filter, search, group toggle) or hides the targeted card sets cur = -1: nothing is targeted and
  // r/b/u do nothing until a click or j/k. cards[i] and rows[i] are always the same row (cards are in group order).
  var labels = {}, filter = 'all', cur = -1, cards = [], rows = [];
  ids.forEach(function (i) { labels[i] = D.labels[i]; });
  try {
    var saved = JSON.parse(localStorage.getItem(KEY) || '{}');
    ids.forEach(function (i) { if (VALID.indexOf(saved[i]) >= 0) labels[i] = saved[i]; });
  } catch (e) {}
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function save() { try { localStorage.setItem(KEY, JSON.stringify(labels)); } catch (e) {} }
  function count(v) { return ids.filter(function (i) { return labels[i] === v; }).length; }

  function hintBadge(r) {
    if (r.hint === 'touches') return el('span', 'badge b-touch', 'HINT: fix touches cited file');
    if (r.hint === 'untouched') return el('span', 'badge b-amber', 'HINT: fix does not touch cited file');
    return el('span', 'badge b-amber', 'HINT: fix commit unreachable');
  }
  function evidenceNode(r) {
    var box = el('div');
    var ul = el('ul', 'files');
    r.files.forEach(function (f) {
      var li = el('li', f.path === r.cited_path ? 'cite' : '');
      li.appendChild(el('span', 'add', '+' + f.add + ' '));
      li.appendChild(el('span', 'del', '-' + f.del + ' '));
      li.appendChild(document.createTextNode(f.path));
      ul.appendChild(li);
    });
    box.appendChild(ul);
    if (r.diff) {
      var d = el('details'); d.appendChild(el('summary', 'meta', 'Fix diff for ' + r.cited_path + (r.diff_truncated ? ' (first 200 lines)' : '')));
      d.appendChild(el('pre', 'diff', r.diff)); box.appendChild(d);
    }
    return box;
  }
  function card(r, idx) {
    var c = el('div', 'card'); c.dataset.id = r.id;
    var head = el('div', 'row');
    head.appendChild(el('b', '', r.id)); head.appendChild(hintBadge(r));
    c.appendChild(head);
    c.appendChild(el('div', 'claim', r.dline));
    if (r.dline.length >= 300) c.appendChild(el('div', 'cut', 'claim text is cut at about 300 characters by the corpus builder'));
    c.appendChild(el('div', 'meta', 'fix ' + r.fix_sha + ' ' + r.fix_subject));
    c.appendChild(evidenceNode(r));
    var lab = el('div', 'lab');
    VALID.forEach(function (v) {
      var b = el('button', 's-' + v, v); b.dataset.v = v;
      b.onclick = function () { set(r.id, v, false); setCur(idx); };
      lab.appendChild(b);
    });
    c.appendChild(lab);
    return c;
  }
  function render() {
    var root = document.getElementById('groups'); root.textContent = ''; cards = []; rows = [];
    var order = [], by = {};
    D.rows.forEach(function (r) { if (!by[r.group]) { by[r.group] = []; order.push(r.group); } by[r.group].push(r); });
    order.forEach(function (g) {
      var d = el('details', 'grp'), was = true; d.open = true; d.dataset.g = g;
      d.ontoggle = function () { if (d.open !== was) { was = d.open; untarget(); } };
      var s = el('summary'); s.appendChild(el('span', '', by[g][0].unit + '  '));
      s.appendChild(el('span', 'meta', by[g][0].fail_ts + '  '));
      s.appendChild(el('span', 'meta gp', '')); d.appendChild(s);
      by[g].forEach(function (r) { var c = card(r, cards.length); cards.push(c); rows.push(r); d.appendChild(c); });
      root.appendChild(d);
    });
    refresh();
  }
  function vis(i) { return matches(rows[i]) && cards[i].parentNode.open; }
  function step(from, dir) {
    for (var i = from + dir; i >= 0 && i < cards.length; i += dir) if (vis(i)) return i;
    return -1;
  }
  function matches(r) {
    var l = labels[r.id], q = document.getElementById('q').value.toLowerCase();
    if (filter === 'amber' ? r.hint === 'touches' : (filter !== 'all' && l !== filter)) return false;
    return !q || (r.id + ' ' + r.dline + ' ' + r.fix_subject).toLowerCase().indexOf(q) >= 0;
  }
  function refresh() {
    if (cur >= 0 && !vis(cur)) cur = -1;
    rows.forEach(function (r, i) {
      var c = cards[i], l = labels[r.id];
      c.className = 'card ' + (l === 'unknown' ? '' : l) + (i === cur ? ' cur' : '') + (matches(r) ? '' : ' hide');
      Array.prototype.forEach.call(c.querySelectorAll('.lab button'), function (b) { b.classList.toggle('on', b.dataset.v === l); });
    });
    Array.prototype.forEach.call(document.querySelectorAll('details.grp'), function (g) {
      var rs = D.rows.filter(function (r) { return r.group === g.dataset.g; });
      var done = rs.filter(function (r) { return labels[r.id] !== 'unknown'; }).length;
      g.querySelector('.gp').textContent = done + '/' + rs.length + ' labeled';
      g.classList.toggle('hide', !rs.some(matches));
    });
    var n = ids.length, re = count('real'), bo = count('bogus'), un = count('unknown');
    document.getElementById('total').textContent = n;
    document.getElementById('n-real').textContent = 'real ' + re + '/' + n;
    document.getElementById('n-bogus').textContent = 'bogus ' + bo;
    document.getElementById('n-unknown').textContent = 'unknown ' + un;
    var can = re + un >= 30 && bo <= 11, st = document.getElementById('status');
    st.className = 'status ' + (can ? 'ok' : 'no');
    st.textContent = can ? 'Gate G still reachable (' + re + ' real + ' + un + ' unknown >= 30)' : 'Gate G NOT reachable (need 30 real, bogus max 11)';
    var bar = document.getElementById('bar'); bar.textContent = '';
    [['real', re, '#1a7f37'], ['bogus', bo, '#cf222e']].forEach(function (x) { var i = el('i'); i.style.width = (100 * x[1] / n) + '%'; i.style.background = x[2]; bar.appendChild(i); });
  }
  function set(id, v, advance) {
    var nx = advance ? step(cur, 1) : -1;
    labels[id] = v; save();
    if (nx >= 0) { cur = nx; cards[nx].scrollIntoView({block: 'center'}); }
    refresh();
  }
  function setCur(i) { cur = i; refresh(); }
  function untarget() { cur = -1; refresh(); }
  function move(dir) {
    var i = cur < 0 ? step(dir > 0 ? -1 : cards.length, dir) : step(cur, dir);
    if (i >= 0) { cur = i; refresh(); cards[i].scrollIntoView({block: 'center'}); }
  }
  document.addEventListener('keydown', function (e) {
    if (e.target.tagName === 'INPUT' || e.ctrlKey || e.metaKey || e.altKey) return;
    var k = e.key.toLowerCase(), v = {r: 'real', b: 'bogus', u: 'unknown'}[k];
    if (k === 'j' || k === 'k') return move(k === 'j' ? 1 : -1);
    if (!v || e.repeat) return;
    refresh(); // a collapse whose toggle event is still queued may have hidden the target
    if (cur >= 0) set(rows[cur].id, v, k !== 'u');
  });
  var fb = document.getElementById('filters');
  [['all', 'all'], ['unknown', 'unknown'], ['real', 'real'], ['bogus', 'bogus'], ['amber', 'hinted-amber: fix does not touch cited file']].forEach(function (f) {
    var b = el('button', f[0] === 'all' ? 'on' : '', f[1]); b.dataset.f = f[0];
    b.onclick = function () {
      filter = f[0] === 'amber' ? 'amber' : f[0];
      Array.prototype.forEach.call(fb.children, function (x) { x.classList.toggle('on', x === b); });
      untarget();
    };
    fb.appendChild(b);
  });
  document.getElementById('q').oninput = untarget;
  function tsv() { return buildTsv(D.header, ids, labels); }
  function say(t) { document.getElementById('msg').textContent = t; }
  document.getElementById('dl').onclick = function () {
    var a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([tsv()], {type: 'text/tab-separated-values'}));
    a.download = 'labels.tsv'; a.click(); say('downloaded labels.tsv');
  };
  document.getElementById('cp').onclick = function () {
    if (navigator.clipboard) navigator.clipboard.writeText(tsv()).then(function () { say('copied'); }, function () { say('copy blocked: use Download'); });
    else say('copy unavailable: use Download');
  };
  document.getElementById('imp').onchange = function (e) {
    var f = e.target.files[0]; if (!f) return;
    var rd = new FileReader();
    rd.onload = function () {
      var n = 0, skipped = 0;
      String(rd.result).split(/\r?\n/).forEach(function (l) {
        if (!l.trim() || l.charAt(0) === '#') return;
        var p = l.split('\t');
        if (labels.hasOwnProperty(p[0]) && VALID.indexOf(p[1]) >= 0) { labels[p[0]] = p[1]; n++; } else skipped++;
      });
      save(); refresh(); say('imported ' + n + ' labels, skipped ' + skipped + ' lines');
    };
    rd.readAsText(f);
  };
  render();
})();
</script></body></html>
'''

if __name__ == '__main__':
    sys.exit(main())
