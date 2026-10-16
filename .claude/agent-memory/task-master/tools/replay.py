#!/usr/bin/env python3
"""Replay a task-master contract in scratch git worktrees.

  replay.py CONTRACT REPO BASE_SHA [--keep]

For a fresh detached worktree of REPO at BASE_SHA: (1) run every criterion
before any edit (report which already pass), (2) apply all Ordered edits and
run every criterion (all must pass), (3) for every criterion whose
`mutation:` reads `skip edit N`, rebuild with edit N skipped and require that
criterion to fail. Edits: new file / insert-after / before+after / delete
(anchors counted 1) and command items (exit code compared).
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

FENCE = re.compile(r'^\s*(`{3,}|~{3,})')


def fence_flags(lines):
    flags, open_ = [], None
    for l in lines:
        m = FENCE.match(l)
        if open_ is None:
            if m:
                open_ = m.group(1)
                flags.append('open')
            else:
                flags.append(None)
        elif l.strip() == open_:
            open_ = None
            flags.append('close')
        else:
            flags.append('in')
    return flags


def section(lines, name):
    flags = fence_flags(lines)
    start = next((i for i, l in enumerate(lines) if flags[i] is None and re.match(rf'^## {re.escape(name)}\b', l)), None)
    if start is None:
        return []
    end = next((i for i in range(start + 1, len(lines)) if flags[i] is None and lines[i].startswith('## ')), len(lines))
    return lines[start + 1:end]


def items(sec):
    flags = fence_flags(sec)
    out, cur, pending = [], None, None
    for i, raw in enumerate(sec):
        if flags[i] is not None:
            if pending is not None and flags[i] == 'in':
                pending['body'].append(raw)
            if flags[i] == 'close':
                pending = None
            continue
        if re.match(r'^\d+\. ', raw):
            cur = {}
            out.append(cur)
        if cur is None:
            continue
        m = re.match(r'^(?:\d+\. )?\s*([a-z-]+):\s*(.*)$', raw)
        if not m or m.group(1) in cur:
            continue
        key, val = m.group(1), m.group(2).strip()
        fenced = val == '' and i + 1 < len(sec) and bool(FENCE.match(sec[i + 1]))
        cur[key] = {'value': val, 'fenced': fenced, 'body': []}
        if fenced:
            pending = cur[key]
    return out


def inline(v):
    m = re.match(r'^`(.*)`', v)
    return m.group(1) if m else v


def body_text(field, indent):
    if field['fenced']:
        ls = field['body']
        return '\n'.join(l[indent:] if l.strip() else '' for l in ls)
    return inline(field['value'])


def apply_edit(it, cwd, log):
    if 'command' in it:
        cmd = inline(it['command']['value'])
        want = int(it['expect']['value'].split()[0])
        r = subprocess.run(['bash', '-c', cmd], cwd=cwd, capture_output=True, text=True)
        if r.returncode != want:
            log.append(f'  command exit {r.returncode} != {want}: {cmd[:90]}\n{r.stdout[-300:]}{r.stderr[-300:]}')
            return False
        return True
    path = inline(it['file']['value'])
    full = os.path.join(cwd, path)
    anchor = it['anchor']['value']
    indent = int(it['indent']['value']) if 'indent' in it else 0
    exists = os.path.exists(full)
    text = open(full).read() if exists else ''
    lines = text.split('\n') if text else []
    if 'insert-after' in it:
        payload = body_text(it['insert-after'], indent).split('\n')
        if anchor.startswith('new file'):
            if exists:
                log.append(f'  new file already exists: {path}')
                return False
            os.makedirs(os.path.dirname(full) or '.', exist_ok=True)
            open(full, 'w').write('\n'.join(payload) + '\n')
            return True
        lit = inline(anchor.split('line matching', 1)[1].strip())
        hits = [i for i, l in enumerate(lines) if lit in l]
        if len(hits) != 1:
            log.append(f'  anchor count {len(hits)} for {lit!r} in {path}')
            return False
        lines[hits[0] + 1:hits[0] + 1] = payload
        open(full, 'w').write('\n'.join(lines).rstrip('\n') + '\n')
        return True
    if 'before' in it:
        b, a = body_text(it['before'], indent), body_text(it['after'], indent)
        if text.count(b) != 1:
            log.append(f'  before text count {text.count(b)} in {path}: {b[:60]!r}')
            return False
        open(full, 'w').write(text.replace(b, a))
        return True
    if 'delete' in it:
        d = body_text(it['delete'], indent)
        if text.count(d) != 1:
            log.append(f'  delete text count {text.count(d)} in {path}')
            return False
        open(full, 'w').write(text.replace(d, ''))
        return True
    log.append('  unknown edit shape')
    return False


def run_crit(c, cwd):
    run = inline(c['run']['value'])
    want = int(c['exit']['value'].split()[0])
    frag = c['stdout']['value']
    r = subprocess.run(['bash', '-c', run], cwd=cwd, capture_output=True, text=True)
    out = r.stdout.strip()
    if frag.strip() == 'empty':
        okout = out == ''
    else:
        okout = inline(frag) in out
    return r.returncode == want and okout, r.returncode, out[-200:]


def fresh(repo, base):
    d = tempfile.mkdtemp(prefix='replay-')
    shutil.rmtree(d)
    subprocess.run(['git', '-C', repo, 'worktree', 'add', '--detach', '-q', d, base], check=True)
    subprocess.run(['git', '-C', d, 'config', 'user.email', 't@t.invalid'], check=True)
    subprocess.run(['git', '-C', d, 'config', 'user.name', 't'], check=True)
    for pair in filter(None, os.environ.get('REPLAY_SEED', '').split(',')):
        src, dst = pair.split(':')
        os.makedirs(os.path.dirname(os.path.join(d, dst)) or d, exist_ok=True)
        shutil.copy(src, os.path.join(d, dst))
    for pre in filter(None, os.environ.get('REPLAY_PRE', '').split(',')):
        plines = open(pre).read().split('\n')
        for it in items(section(plines, 'Ordered edits')):
            if not apply_edit(it, d, []):
                print('  (pre-contract edit failed: ' + pre + ')')
    return d


def drop(repo, d):
    subprocess.run(['git', '-C', repo, 'worktree', 'remove', '--force', d], capture_output=True)


def main():
    contract, repo, base = sys.argv[1:4]
    lines = open(contract).read().split('\n')
    edits = items(section(lines, 'Ordered edits'))
    crits = items(section(lines, 'Acceptance criteria'))
    problems = 0

    d = fresh(repo, base)
    print(f'-- pre-edit state ({len(crits)} criteria)')
    for k, c in enumerate(crits, 1):
        ok, rc, out = run_crit(c, d)
        print(f'  criterion {k}: {"ALREADY PASSES" if ok else "red"} (exit {rc})')
    drop(repo, d)

    def build(skip=None):
        d = fresh(repo, base)
        log = []
        for n, it in enumerate(edits, 1):
            if n == skip:
                continue
            if not apply_edit(it, d, log):
                if skip is None or 'command' not in it:
                    print(f'  edit {n} FAILED'); print('\n'.join(log))
                    return d, False
                print(f'  (skip-edit {skip} build: command edit {n} failed, continuing)')
                log.clear()
        return d, True

    d, ok = build()
    print('-- full change')
    if not ok:
        return 1
    for k, c in enumerate(crits, 1):
        good, rc, out = run_crit(c, d)
        print(f'  criterion {k}: {"green" if good else "NOT GREEN"} (exit {rc}) {"" if good else out}')
        problems += 0 if good else 1
    drop(repo, d)

    for k, c in enumerate(crits, 1):
        m = re.search(r'skip edit (\d+)', c['mutation']['value'])
        if not m:
            print(f'  criterion {k}: mutation is a proof: line, not replayed ({c["mutation"]["value"][:50]})')
            continue
        d, ok = build(skip=int(m.group(1)))
        if not ok:
            problems += 1
            continue
        good, rc, out = run_crit(c, d)
        print(f'  criterion {k} mutated (skip edit {m.group(1)}): {"still green -- VACUOUS" if good else "red as expected"} (exit {rc}) {out[-60:]}')
        problems += 1 if good else 0
        drop(repo, d)
    print('PROBLEMS:', problems)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
