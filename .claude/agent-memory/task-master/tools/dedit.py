"""Turn a diff between two file versions into contract edits (insert-after / before+after), applied sequentially."""
import difflib
import sys

sys.path.insert(0, '/home/sebas/AntiSlop/.claude/agent-memory/task-master/tools')
from cg import Edits, _fence_for  # noqa: E402

MAXN = 76


def uniq(lines, k):
    s = lines[k].strip()
    return bool(s) and '`' not in s and len(s) >= 8 and sum(1 for l in lines if s in l) == 1


def payload(e, key, lines):
    e._payload(key, lines)


def emit_insert(e, path, anchor, new, cur_after):
    """insert-after, chunked at MAXN lines with unique split lines (checked against the text after the insert)."""
    i = 0
    first = True
    while i < len(new):
        if len(new) - i <= MAXN:
            j = len(new)
        else:
            j = i + MAXN
            while j > i + 10:
                cand = new[j - 1]
                if cand.strip() and '`' not in cand and len(cand.strip()) >= 8 and sum(1 for l in cur_after if cand.strip() in l) == 1:
                    break
                j -= 1
            else:
                raise SystemExit('no unique split line')
        chunk = new[i:j]
        e.out.append(f'{e.n}. file: `{path}`')
        e.out.append(f'   anchor: line matching `{anchor}`')
        e.out.append('   indent: 0')
        e._payload('insert-after', chunk)
        e.n += 1
        anchor = chunk[-1].strip()
        i = j
    return e.n - 1


def emit_replace(e, path, anchor, before, after):
    assert len(before) <= MAXN and len(after) <= MAXN, (len(before), len(after), anchor)
    assert '`' not in anchor
    e.out.append(f'{e.n}. file: `{path}`')
    e.out.append(f'   anchor: line matching `{anchor}`')
    e.out.append('   indent: 0')
    e._payload('before', before)
    e._payload('after', after)
    e.n += 1
    return e.n - 1


def diff_edits(e, path, old_text, new_text, log):
    """Append edits turning old_text into new_text. log gets (edit number, kind, new lines)."""
    old = old_text.split('\n')
    new = new_text.split('\n')
    cur = list(old)
    off = 0
    sm = difflib.SequenceMatcher(None, old, new, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == 'equal':
            continue
        add = new[j1:j2]
        p1, p2 = i1 + off, i2 + off
        if tag == 'insert':
            k = p1 - 1
            while k >= 0 and not uniq(cur, k):
                k -= 1
            assert k >= 0, 'no anchor'
            if k == p1 - 1:
                after_cur = cur[:p1] + add + cur[p1:]
                n = emit_insert(e, path, cur[k].strip(), add, after_cur)
                log.append((n, 'insert', add))
            else:
                before = cur[k:p1]
                after = before + add
                assert '\n'.join(cur).count('\n'.join(before)) == 1
                n = _replace_or_split(e, path, cur, k, before, after, log, 'insert')
        else:
            lo, hi = p1, p2
            flip = 0
            while not any(uniq(cur, k) for k in range(lo, hi)):
                if flip % 2 == 0 and lo > 0:
                    lo -= 1
                elif hi < len(cur):
                    hi += 1
                flip += 1
                assert flip < 60, 'cannot anchor'
            before = cur[lo:hi]
            after = cur[lo:p1] + add + cur[p2:hi]
            assert '\n'.join(cur).count('\n'.join(before)) == 1, 'before block not unique'
            _replace_or_split(e, path, cur, lo, before, after, log, tag)
        cur[p1:p2] = add
        off += len(add) - (i2 - i1)
    assert '\n'.join(cur) == new_text, 'diff replay mismatch'
    return new_text


def _replace_or_split(e, path, cur, lo, before, after, log, kind):
    anchor = next(l.strip() for l in before if uniq_in(cur, l))
    if len(after) <= MAXN:
        n = emit_replace(e, path, anchor, before, after)
        log.append((n, kind, after))
        return n
    # long after: replace with the first part, then insert the rest after its last unique line
    raise SystemExit('replace with a long after payload: split the piece by hand')


def uniq_in(lines, l):
    s = l.strip()
    return bool(s) and '`' not in s and len(s) >= 8 and sum(1 for x in lines if s in x) == 1
