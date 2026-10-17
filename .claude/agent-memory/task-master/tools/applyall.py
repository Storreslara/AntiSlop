"""applyall.py CONTRACT REPO BASE [skip,...] -> prints a worktree dir with all (non-skipped) edits applied (including commands)."""
import sys
sys.path.insert(0, '/home/sebas/AntiSlop/.claude/agent-memory/task-master/tools')
import replay as R
contract, repo, base = sys.argv[1:4]
skip = set(int(x) for x in sys.argv[4].split(',')) if len(sys.argv) > 4 and sys.argv[4] else set()
lines = open(contract).read().split('\n')
edits = R.items(R.section(lines, 'Ordered edits'))
d = R.fresh(repo, base)
for n, it in enumerate(edits, 1):
    if n in skip: continue
    log = []
    if not R.apply_edit(it, d, log):
        print('edit', n, 'failed', log, file=sys.stderr)
print(d)
