import sys, subprocess, re
sys.path.insert(0,'.')
import replay as R
contract, repo, base, k, touch = sys.argv[1:6]
lines = open(contract).read().split('\n')
edits = R.items(R.section(lines,'Ordered edits')); crits = R.items(R.section(lines,'Acceptance criteria'))
d = R.fresh(repo, base)
log=[]
for it in edits:
    assert R.apply_edit(it, d, log), log
open(d+'/'+touch,'a').write('\n# x\n')
subprocess.run(['git','-C',d,'commit','-q','-am','fix: x'],check=True)
print(R.run_crit(crits[int(k)-1], d))
R.drop(repo,d)
