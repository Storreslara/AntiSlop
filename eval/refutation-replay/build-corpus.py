#!/usr/bin/env python3
"""Replay corpus for the reviewer's refutation pass (rfp-u2, docs/plans/2026-10-27-refutation-pass.md).

Build (default): read every FAIL block under the markers dir, keep judgment-shaped defect lines (no
mechanical keyword on the line) that cite a <path>:<line> present at the reviewed commit, and label a defect proxy-real when a `(<unit>)` commit after
the FAIL touched the cited path and the unit holds a PASS marker. Group them per FAIL block (at most 3,
the pass's cap), sample groups with a fixed seed until --size rows, and write corpus.jsonl plus labels.tsv
(every label `unknown`; a human sets real|bogus, Gate G1). A claim is the whole defect item (rfp-u2f): the
bullet line plus every indented line after it, across blank lines, up to the next bullet or unindented line,
whitespace-collapsed and cut at 8000 characters; its cited <path>:<line> is kept whole. No committed claim
reaches that cut, which keeps a 3-defect brief far below Linux's 128 KiB limit on one argv string. Which
defects are kept still depends on the bullet line alone.
--check: validate the committed corpus and labels against git; print one summary line; exit 1 if invalid.
--labels: print the human labelling checklist (the claim, then the fix commit's short hash and subject).
--refresh-claims: rewrite the `dline` of each row of --out with its whole claim from the FAIL block it came
from, keeping every other field, the row order and labels.tsv; a row whose defect is not found exactly once
is an error, and then nothing is written (exit 1).
Reads markers and git only; writes only --out and its labels.tsv sibling. Deterministic for a given tree.
"""
import argparse, json, os, random, re, subprocess, sys

MECH = re.compile(
    r'(scope: (out|excluded|no-affected-list)|criterion \d+: fail|version-stamp|contract: (changed|not-at)'
    r'|not committed|uncommitted|out of scope|outside .{0,40}affected files|do not touch'
    r'|plugin\.json|CHANGELOG|validate\.sh (exits|fails|reports|prints)'
    r'|exit(s|ed)? (code )?[1-9]|stdout (is|was|prints|reads)'
    r'|criterion \d+ (fails|failed|is red|prints|exits|returns)|mutation)', re.I)
CITE = re.compile(r'([A-Za-z0-9_][A-Za-z0-9_./-]*\.[A-Za-z0-9]{1,6}):(\d+(?:-\d+)?)')
BULLET = re.compile(r'^(?:[-*] |\d+[.)] )')
HERE = os.path.dirname(os.path.abspath(__file__))


def items(lines):
    """Yield (bullet line, whole item text) for each column-0 bullet: the bullet line plus every indented
    line after it, across blank lines, up to the next bullet or unindented line."""
    i = 0
    while i < len(lines):
        if not BULLET.match(lines[i]):
            i += 1
            continue
        parts, j = [lines[i]], i + 1
        while j < len(lines) and not BULLET.match(lines[j]):
            k = j
            while k < len(lines) and not lines[k].strip():
                k += 1
            if k == len(lines) or not lines[k][:1].isspace():
                break
            parts.extend(lines[j:k + 1])
            j = k + 1
        yield lines[i], ' '.join(parts)
        i = j


def claim_text(item, cite):
    claim = re.sub(r'\s+', ' ', BULLET.sub('', item)).strip()
    if claim.startswith(cite):
        claim = claim[len(cite):].lstrip(' :')
    return claim[:8000] or '(no claim text)'


def git(repo, *args):
    r = subprocess.run(['git', '-C', repo] + list(args), capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def blocks(markers):
    for name in sorted(os.listdir(markers)):
        if not name.endswith('.fail'):
            continue
        unit = name[:-5]
        cur = None
        for line in open(os.path.join(markers, name), errors='replace').read().split('\n'):
            m = re.match(r'^FAIL (\S+) (\S+)', line)
            if m and m.group(1) == unit:
                if cur:
                    yield cur
                cur = {'unit': unit, 'ts': m.group(2), 'lines': []}
            elif cur is not None and not line.startswith('tier: '):
                cur['lines'].append(line)
        if cur:
            yield cur


def has_pass(markers, unit):
    p = os.path.join(markers, unit + '.pass')
    try:
        return open(p, errors='replace').readline().startswith('PASS %s ' % unit)
    except OSError:
        return False


def build(a):
    rows_by_group = []
    for b in blocks(a.markers):
        # Per defect, not per block: the corpus measures how the brief treats a real judgment defect,
        # so a judgment defect from a block that also had a mechanical ground still counts.
        defects = [(l, item) for l, item in items(b['lines']) if not MECH.search(l)]
        if not defects:
            continue
        unit, ts = b['unit'], b['ts']
        if not has_pass(a.markers, unit):
            continue
        reviewed = git(a.repo, 'log', '-1', '--format=%H', '--before=' + ts, '--grep=(%s)' % unit, '--fixed-strings')
        first = git(a.repo, 'log', '--reverse', '--format=%H', '--grep=(%s)' % unit, '--fixed-strings')
        if not reviewed or not first:
            continue
        baseline = git(a.repo, 'rev-parse', first.split('\n')[0] + '^')
        if not baseline:
            continue
        group = []
        for d, item in defects:
            m = CITE.search(d)
            if not m or git(a.repo, 'cat-file', '-e', '%s:%s' % (reviewed, m.group(1))) is None:
                continue
            fix = git(a.repo, 'log', '--format=%H', '--since=' + ts, '--grep=(%s)' % unit, '--fixed-strings', '--', m.group(1))
            if not fix:
                continue
            cite = '%s:%s' % (m.group(1), m.group(2))
            group.append({'cite': cite, 'claim': claim_text(item, cite), 'fix_commit': fix.split('\n')[-1]})
            if len(group) == 3:
                break
        if group:
            gid = '%s@%s' % (unit, ts)
            rows_by_group.append([dict(id='%s#D%d' % (gid, i + 1), group=gid, unit=unit, fail_ts=ts, reviewed=reviewed,
                                       baseline=baseline, dline='D%d: %s %s' % (i + 1, g['cite'], g['claim']),
                                       fix_commit=g['fix_commit']) for i, g in enumerate(group)])
    rows_by_group.sort(key=lambda g: g[0]['group'])
    random.Random(a.seed).shuffle(rows_by_group)
    out = []
    for g in rows_by_group:
        if len(out) >= a.size:
            break
        out.extend(g)
    with open(a.out, 'w') as f:
        for r in out:
            f.write(json.dumps(r, sort_keys=True) + '\n')
    with open(labels_path(a.out), 'w') as f:
        f.write('# id<TAB>real|bogus|unknown (Gate G1: a human sets each label)\n')
        for r in out:
            f.write('%s\tunknown\n' % r['id'])
    print('corpus: built rows=%d groups=%d candidates=%d' % (len(out), len({r['group'] for r in out}), sum(map(len, rows_by_group))))


def labels_path(out):
    return os.path.join(os.path.dirname(os.path.abspath(out)), 'labels.tsv')


def load(a):
    rows = [json.loads(l) for l in open(a.out) if l.strip()]
    labels = {}
    for l in open(labels_path(a.out)):
        if l.startswith('#') or not l.strip():
            continue
        k, _, v = l.rstrip('\n').partition('\t')
        labels[k] = v
    return rows, labels


def check(a):
    rows, labels = load(a)
    errs = []
    ids = [r.get('id') for r in rows]
    if len(set(ids)) != len(ids):
        errs.append('duplicate ids')
    groups = {}
    for r in rows:
        for k in ('id', 'group', 'unit', 'fail_ts', 'reviewed', 'baseline', 'dline', 'fix_commit'):
            if not r.get(k):
                errs.append('%s: missing %s' % (r.get('id'), k))
        if not re.match(r'^D[1-3]: [^\s:]+:\d+(-\d+)? .+$', r.get('dline', '')):
            errs.append('%s: bad dline' % r.get('id'))
        path = r.get('dline', ' ').split(' ')[1].rsplit(':', 1)[0]
        if git(a.repo, 'cat-file', '-e', '%s:%s' % (r.get('reviewed'), path)) is None:
            errs.append('%s: %s absent at reviewed commit' % (r.get('id'), path))
        if git(a.repo, 'cat-file', '-e', '%s^{commit}' % r.get('baseline')) is None:
            errs.append('%s: baseline unreachable' % r.get('id'))
        groups.setdefault(r.get('group'), []).append(r)
        if labels.get(r.get('id')) not in ('real', 'bogus', 'unknown'):
            errs.append('%s: no label' % r.get('id'))
    errs += ['%s: more than 3 defects' % g for g, v in groups.items() if len(v) > 3]
    if set(labels) != set(ids):
        errs.append('labels.tsv ids differ from corpus ids')
    n = lambda v: sum(1 for i in ids if labels.get(i) == v)
    print('corpus: rows=%d groups=%d units=%d unlabeled=%d real=%d bogus=%d errors=%d'
          % (len(rows), len(groups), len({r.get('unit') for r in rows}), n('unknown'), n('real'), n('bogus'), len(errs)))
    for e in errs[:20]:
        print('  error: ' + e)
    return 1 if errs else 0


def refresh(a):
    rows = [json.loads(l) for l in open(a.out) if l.strip()]
    found = {}
    for b in blocks(a.markers):
        found.setdefault((b['unit'], b['ts']), b['lines'])
    errs, longer = [], 0
    for r in rows:
        m = re.match(r'^(D[1-3]): (\S+) (.*)$', r.get('dline', ''))
        if not m:
            errs.append('%s: bad dline' % r.get('id'))
            continue
        cite, old = m.group(2), m.group(3)
        old = '' if old == '(no claim text)' else old
        hits = []
        for line, item in items(found.get((r.get('unit'), r.get('fail_ts')), [])):
            c = CITE.search(line)
            if c and not MECH.search(line) and '%s:%s' % (c.group(1), c.group(2)) == cite:
                whole = claim_text(item, cite)
                if whole.startswith(old):
                    hits.append(whole)
        if len(hits) != 1:
            errs.append('%s: %d matching defects in its FAIL block' % (r.get('id'), len(hits)))
            continue
        dline = '%s: %s %s' % (m.group(1), cite, hits[0])
        longer += dline != r['dline']
        r['dline'] = dline
    print('corpus: refreshed rows=%d longer=%d errors=%d' % (len(rows), 0 if errs else longer, len(errs)))
    for e in errs[:20]:
        print('  error: ' + e)
    if errs:
        return 1
    with open(a.out, 'w') as f:
        for r in rows:
            f.write(json.dumps(r, sort_keys=True) + '\n')
    return 0


def checklist(a):
    rows, labels = load(a)
    for r in rows:
        stat = git(a.repo, 'show', '--stat', '--format=%h %s', r['fix_commit']) or '(fix commit unreachable)'
        print('== %s [%s]\n%s\n-- fix: %s\n' % (r['id'], labels.get(r['id'], '?'), r['dline'], stat.split('\n')[0]))
    return 0


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--repo', default='.')
    p.add_argument('--markers', default=None)
    p.add_argument('--seed', type=int, default=7)
    p.add_argument('--size', type=int, default=40)
    p.add_argument('--out', default=os.path.join(HERE, 'corpus.jsonl'))
    p.add_argument('--check', action='store_true')
    p.add_argument('--labels', action='store_true')
    p.add_argument('--refresh-claims', action='store_true')
    a = p.parse_args()
    a.markers = a.markers or os.path.join(a.repo, '.claude', 'reviewed')
    if a.check:
        sys.exit(check(a))
    if a.labels:
        sys.exit(checklist(a))
    if a.refresh_claims:
        sys.exit(refresh(a))
    build(a)


if __name__ == '__main__':
    main()
