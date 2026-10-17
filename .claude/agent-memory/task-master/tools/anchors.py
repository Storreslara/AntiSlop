"""anchors.py CONTRACT REPO BASE: apply edits in order in a fresh worktree; before each file edit, print the literal anchor count (must be 1)."""
import sys, os, re, subprocess
sys.path.insert(0, '/home/sebas/AntiSlop/.claude/agent-memory/task-master/tools')
import replay as R
contract, repo, base = sys.argv[1:4]
lines = open(contract).read().split('\n')
edits = R.items(R.section(lines, 'Ordered edits'))
d = R.fresh(repo, base)
bad = 0
for n, it in enumerate(edits, 1):
    if 'file' in it:
        path = R.inline(it['file']['value'].split(' (')[0]) if False else R.inline(it['file']['value'])
        anchor = it['anchor']['value']
        if not anchor.startswith('new file'):
            lit = R.inline(anchor.split('line matching', 1)[1].strip())
            full = os.path.join(d, path)
            c = open(full).read().split('\n') if os.path.exists(full) else []
            k = sum(1 for l in c if lit in l)
            if k != 1:
                print(f'edit {n}: anchor count {k} for {lit[:60]!r}'); bad += 1
    log = []
    if not R.apply_edit(it, d, log):
        print(f'edit {n} failed', log); bad += 1; break
print('anchors ok' if not bad else f'ANCHOR PROBLEMS {bad}')
R.drop(repo, d)
