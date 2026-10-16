import sys
sys.path.insert(0, '.')
from cg import *
W = '../wt/'
U, I = 'abt-u01', 569
rd = lambda p: open(W + p).read()
e = Edits()
e.command('test ! -e eval/abtest && test ! -e tests/abtest-arms.test.sh && test ! -e tests/fixtures/abtest && test -z "$(git status --porcelain --untracked-files=no -- . \':!.claude/agent-memory\')"', 0)
n_common = e.new_file('eval/abtest/arms/common.sh', rd('eval/abtest/arms/common.sh'))
n_a = e.new_file('eval/abtest/arms/arm-a.sh', rd('eval/abtest/arms/arm-a.sh'))
n_b = e.new_file('eval/abtest/arms/arm-b.sh', rd('eval/abtest/arms/arm-b.sh'))
n_fake = e.new_file('tests/fixtures/abtest/fake-claude.sh', rd('tests/fixtures/abtest/fake-claude.sh'))
n_test = e.new_file('tests/abtest-arms.test.sh', rd('tests/abtest-arms.test.sh'))
n_gi = e.insert_after('.gitignore', 'eval/results.jsonl', 'eval/abtest/.runs/\neval/abtest/results.jsonl')
n_chmod = e.command('chmod +x eval/abtest/arms/common.sh eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh tests/fixtures/abtest/fake-claude.sh tests/abtest-arms.test.sh', 0)
files = ['.gitignore', 'eval/abtest/arms/common.sh', 'eval/abtest/arms/arm-a.sh', 'eval/abtest/arms/arm-b.sh', 'tests/fixtures/abtest/fake-claude.sh', 'tests/abtest-arms.test.sh']
subj = 'feat(abt-u01): arm scripts with equal flags and a fake-claude test (#569)'
n_commit = e.command(commit_cmd(files, subj), 0)

crit = ''
crit += criterion(1, 'bash tests/abtest-arms.test.sh', 0, 'All abtest-arms checks passed.',
                  f'skip edit {n_a} (arm-a.sh); the arm A rows FAIL, the script exits non-zero and the fragment is absent.')
crit += criterion(2, 'bash -n eval/abtest/arms/common.sh && bash -n eval/abtest/arms/arm-a.sh && bash -n eval/abtest/arms/arm-b.sh && echo syntax-ok', 0, 'syntax-ok',
                  f'skip edit {n_a}; bash -n of the missing arm-a.sh exits 127 and nothing prints.')
crit += criterion(3, "grep -c -e 'eval/abtest/.runs/' -e 'eval/abtest/results.jsonl' .gitignore", 0, '2',
                  f'skip edit {n_gi}; stdout 0 and the exit is 1.')
crit += criterion(4, "grep -cE -e '--max-turns|--max-budget-usd' eval/abtest/arms/common.sh", 0, '1',
                  f'skip edit {n_common}; the file is missing, grep exits 2 and prints nothing.')
crit += criterion(5, 'test -x eval/abtest/arms/arm-a.sh && test -x eval/abtest/arms/arm-b.sh && test -x tests/fixtures/abtest/fake-claude.sh && echo exec-ok', 0, 'exec-ok',
                  f'skip edit {n_chmod}; the files are not executable and nothing prints.')
sc, nxt = std_criteria(U, 6, files, files, n_commit, ['eval/abtest', 'tests/abtest-arms.test.sh', 'tests/fixtures/abtest', '.gitignore'])
crit += sc
affected = '\n'.join([
 '- `eval/abtest/arms/common.sh` (anchor: new file)',
 '- `eval/abtest/arms/arm-a.sh` (anchor: new file)',
 '- `eval/abtest/arms/arm-b.sh` (anchor: new file)',
 '- `tests/fixtures/abtest/fake-claude.sh` (anchor: new file)',
 '- `tests/abtest-arms.test.sh` (anchor: new file)',
 '- `.gitignore` (anchor: line matching `eval/results.jsonl`)'])
dont = '\n'.join([
 '- `eval/harness/` (the one-arm pilot harness stays untouched; this unit adds files beside it)',
 '- `tests/validate.sh` (merge-gate registration of the new tests is unit abt-u17)',
 '- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)',
 '- `docs/plans/` (never edit a plan or contract by hand)'])
ctx = context('yes tests/abtest-arms.test.sh (criterion 1 is the red-then-green check; the arm scripts do not exist at HEAD)',
              'none', [subj], 9 + 0 + 0 + 0, U, I,
              extra=[GATE, INDENT, 'already-green: criterion 9 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.',
                     'no-real-claude: no command in this contract runs the real claude CLI; tests/abtest-arms.test.sh runs a fake claude and a fake HOME. Never run a headless claude in this unit.',
                     'persona-files: arm-b.sh and the test build the persona-config path from two parts on purpose, so no Bash text names the gated file; keep it that way and apply every edit with the Write or Edit tool.'])
# fix packet criterion count
ncrit = crit.count('\n   mutation:')
ctx = context('yes tests/abtest-arms.test.sh (criterion 1 is the red-then-green check; the arm scripts do not exist at HEAD)',
              'none', [subj], ncrit, U, I,
              extra=[GATE, INDENT, 'already-green: criterion 9 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.',
                     'no-real-claude: no command in this contract runs the real claude CLI; tests/abtest-arms.test.sh runs a fake claude and a fake HOME. Never run a headless claude in this unit.',
                     'persona-files: arm-b.sh and the test build the persona-config path from two parts on purpose, so no Bash text names the gated file; keep it that way and apply every edit with the Write or Edit tool.'])
obj = ('eval/abtest/arms/{common,arm-a,arm-b}.sh exist and build identical claude -p commands for the two arms (Arm B adds only --plugin-dir and --agent orchestrator); '
       'caps are --max-turns and a wall-clock timeout, never a dollar budget; tests/abtest-arms.test.sh passes against a fake claude; .gitignore ignores eval/abtest/.runs/ and eval/abtest/results.jsonl. One commit.')
md = assemble(U, I, obj, affected, e.render(), dont, crit, ctx)
open(f'../out/{U}.md', 'w').write(md)
print(len(md), 'bytes', ncrit, 'criteria')
