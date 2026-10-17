"""chain.py REPO BASE CONTRACT... -> worktree with each contract's edits applied in order (failures to stderr)."""
import sys
sys.path.insert(0, '/home/sebas/AntiSlop/.claude/agent-memory/task-master/tools')
import replay as R
repo, base = sys.argv[1:3]
d = R.fresh(repo, base)
for c in sys.argv[3:]:
    lines = open(c).read().split('\n')
    for n, it in enumerate(R.items(R.section(lines, 'Ordered edits')), 1):
        log = []
        if not R.apply_edit(it, d, log):
            print(c.split('/')[-1], 'edit', n, 'failed:', ' '.join(log)[:160], file=sys.stderr)
print(d)
