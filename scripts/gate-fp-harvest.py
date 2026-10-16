#!/usr/bin/env python3
"""Count gate blocks in this repository's transcript store (ptr-u7b-2). Counts only:
no mode prints, writes or returns a command; the outputs are a markdown table,
`leaks=<n>` and `filled <path>`.

Usage: python3 -I scripts/gate-fp-harvest.py [--root DIR] --since ISO --until ISO
         --lib PATH --baseline-lib PATH [--check-doc PATH | --fill-doc PATH]

A hit is a Bash tool_use whose paired tool_result has is_error true and text
containing BLOCKED, timestamped in [since, until). A command is flipped when
command_is_provably_benign is false under --baseline-lib and true under --lib.
"""
import argparse
import datetime
import glob
import json
import os
import re
import subprocess
import sys

GATES = ('reviewed-path-gate', 'human-decision-gate', 'harness-integrity-gate')
CAP = 4096
BEGIN = '<!-- harvest:begin -->'
END = '<!-- harvest:end -->'
F1 = re.compile(r'^\s*cd\s+[^\s;&|$`*?\[]+\s*(&&|;)')
F2 = ('2>&1', '2>/dev/null', '>/dev/null')
F3 = ('du', 'sort', 'uniq', 'cut', 'tr', 'nl', 'jq')


def parse_ts(s):
    d = datetime.datetime.fromisoformat(s.replace('Z', '+00:00'))
    return d if d.tzinfo else d.replace(tzinfo=datetime.timezone.utc)


def result_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return '\n'.join(p.get('text', '') for p in content if isinstance(p, dict))
    return ''


def default_root():
    key = os.getcwd().replace('/', '-')
    return os.path.join(os.path.expanduser('~'), '.claude', 'projects', key)


def collect(root, since, until):
    """Return a list of (command, gate) for every hit in the window."""
    pat = [os.path.join(root, '*.jsonl'), os.path.join(root, '*', 'subagents', '*.jsonl')]
    hits = []
    for path in sorted(p for g in pat for p in glob.glob(g)):
        uses, results = {}, {}
        with open(path, encoding='utf-8', errors='replace') as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                    content = rec['message']['content']
                except (ValueError, KeyError, TypeError):
                    continue
                for part in content if isinstance(content, list) else []:
                    if not isinstance(part, dict):
                        continue
                    if part.get('type') == 'tool_use' and part.get('name') == 'Bash':
                        uses[part.get('id')] = ((part.get('input') or {}).get('command'), rec.get('timestamp'))
                    elif part.get('type') == 'tool_result' and part.get('is_error') is True:
                        results[part.get('tool_use_id')] = result_text(part.get('content'))
        for uid, (cmd, ts) in uses.items():
            text = results.get(uid, '')
            try:
                when = parse_ts(ts)
            except (AttributeError, TypeError, ValueError):
                continue
            if isinstance(cmd, str) and 'BLOCKED' in text and since <= when < until:
                hits.append((cmd, next((g for g in GATES if g in text), 'other')))
    return hits


def benign(lib, cmd):
    script = '. "$1" && command_is_provably_benign "$2"'
    try:
        r = subprocess.run(['bash', '-c', script, 'x', lib, cmd], stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
    except (subprocess.TimeoutExpired, ValueError, OSError):
        return False
    return r.returncode == 0


def in_f3(cmd):
    segs = re.split(r'\|\||&&|;|\|', cmd)
    return any(s.split()[:1] and s.split()[0] in F3 for s in segs)


def build_table(hits, lib, base):
    distinct = list(dict.fromkeys(c for c, _ in hits))
    classified = [c for c in distinct if len(c) <= CAP]
    d = len(classified)
    flipped, still = [], 0
    for c in classified:
        if not benign(lib, c):
            still += 1
        elif not benign(base, c):
            flipped.append(c)

    def share(n):
        return '%.3f' % (n / d) if d else '0.000'

    rows = [('hits', len(hits), '-'), ('distinct', len(distinct), '-'),
            ('oversize', len(distinct) - d, '-'), ('classified', d, '-'),
            ('F1', sum(1 for c in flipped if F1.match(c)), None),
            ('F2', sum(1 for c in flipped if any(t in c for t in F2)), None),
            ('F3', sum(1 for c in flipped if in_f3(c)), None),
            ('flipped', len(flipped), None), ('still-blocked', still, None)]
    for g in GATES + ('other',):
        rows.append(('gate:' + g, sum(1 for _, x in hits if x == g), '-'))
    out = ['| row | count | share |', '| --- | --- | --- |']
    for name, n, sh in rows:
        out.append('| %s | %d | %s |' % (name, n, share(n) if sh is None else sh))
    return '\n'.join(out)


def doc_span(path):
    """Return (lines, begin index, end index) of a doc with exactly one marker pair, else None."""
    try:
        with open(path, encoding='utf-8', newline='') as fh:
            lines = fh.read().splitlines(keepends=True)
    except OSError:
        return None
    keys = [l.strip() for l in lines]
    if keys.count(BEGIN) != 1 or keys.count(END) != 1 or keys.index(BEGIN) > keys.index(END):
        return None
    return lines, keys.index(BEGIN), keys.index(END)


def main(argv):
    ap = argparse.ArgumentParser(prog='gate-fp-harvest.py')
    ap.add_argument('--root')
    ap.add_argument('--since', required=True)
    ap.add_argument('--until', required=True)
    ap.add_argument('--lib')
    ap.add_argument('--baseline-lib')
    ap.add_argument('--check-doc')
    ap.add_argument('--fill-doc')
    a = ap.parse_args(argv)
    if a.check_doc and a.fill_doc:
        ap.error('--check-doc and --fill-doc are exclusive')
    if not a.check_doc and not (a.lib and a.baseline_lib):
        ap.error('--lib and --baseline-lib are required')
    try:
        since, until = parse_ts(a.since), parse_ts(a.until)
    except ValueError:
        ap.error('--since and --until must be ISO timestamps')
    span = doc_span(a.fill_doc) if a.fill_doc else None
    if a.fill_doc and span is None:
        print('the doc must hold exactly one begin and one end marker, in that order', file=sys.stderr)
        return 2
    hits = collect(a.root or default_root(), since, until)
    if a.check_doc:
        with open(a.check_doc, encoding='utf-8', errors='replace') as fh:
            text = fh.read()
        print('leaks=%d' % sum(1 for c in set(c for c, _ in hits) if len(c) >= 20 and c in text))
        return 0
    table = build_table(hits, os.path.abspath(a.lib), os.path.abspath(a.baseline_lib))
    if span:
        lines, b, e = span
        with open(a.fill_doc, 'w', encoding='utf-8', newline='') as fh:
            fh.write(''.join(lines[:b + 1] + [table + '\n'] + lines[e:]))
        print('filled %s' % a.fill_doc)
    else:
        print(table)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
