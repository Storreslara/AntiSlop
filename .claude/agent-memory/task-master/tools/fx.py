"""Shared builder for fixture-unit contracts (abt-u07..u11)."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from cg import *

W = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'wt') + '/'
rd = lambda p: open(W + p).read()


def fixture_unit(unit, issue, eval_id, files, subject, objective, extra_crit, prompt_sha, deps_note, precond='', ref_path=None, dont_extra=(), tdd='no fixture and check files; the verifier is the red-then-green check (every required check set must fail on the baseline and pass on baseline plus reference.patch)', extra_ctx=()):
    """files: list of repo-relative paths in edit order (all new). extra_crit: list of (run, exit, stdout, mutation_template_or_None, key_path) built by caller as callables (n_of) -> markdown."""
    U, I = unit, issue
    e = Edits()
    fx = f'eval/abtest/fixtures/{eval_id}'
    e.command(f'test ! -e {fx} && test ! -e eval/abtest/checks/{eval_id} && test -f eval/abtest/verify-checks.sh && {precond}test -z "$(git status --porcelain --untracked-files=no -- . \':!.claude/agent-memory\')"', 0)
    N = {p: e.new_file(p, rd(p)) for p in files}
    n_commit = e.command(commit_cmd(files, subject), 0)
    crit = ''
    k = 1
    ref = ref_path or f'{fx}/reference.patch'
    crit += criterion(k, f'bash eval/abtest/verify-checks.sh {eval_id}', 0, 'verify-checks: ok',
                      f'skip edit {N[ref]} (reference.patch); verify reports reference failures, prints FAILED and exits 1.'); k += 1
    prompt = f'eval/abtest/tasks/{eval_id}.prompt.md'
    crit += criterion(k, f"grep -ciE 'reviewer|spec-master|persona|holdout|hidden' {prompt}", 1, '0',
                      f'skip edit {N[prompt]} (the prompt); grep exits 2 on the missing file and prints nothing.',
                      proof='scratch run: a prompt containing the word hidden printed 1 with exit 0.'); k += 1
    crit += criterion(k, f'sha256sum {prompt} | cut -c1-16', 0, prompt_sha,
                      f'skip edit {N[prompt]}; sha256sum fails on the missing file and prints nothing.'); k += 1
    chk = sorted(os.path.basename(p) for p in files if p.startswith(f'eval/abtest/checks/{eval_id}/'))
    crit += criterion(k, f'ls eval/abtest/checks/{eval_id} | paste -sd" "', 0, ' '.join(chk),
                      f'skip edit {N[f"eval/abtest/checks/{eval_id}/check.sh"]} (check.sh); the listing lacks check.sh.'); k += 1
    for fn in extra_crit:
        c, k = fn(N, k)
        crit += c
    sc, nxt = std_criteria(U, k, files, files, n_commit, [fx, f'eval/abtest/checks/{eval_id}', prompt])
    crit += sc
    affected = '\n'.join(f'- `{f}` (anchor: new file)' for f in files)
    dont = '\n'.join([
        '- `eval/fixtures/` (templates stay untouched; this unit adds files beside them)',
        '- `eval/abtest/verify-checks.sh`, `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/fixtures/lib.sh` (unit abt-u04 owns them)',
        '- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/templates/` (other units own them)',
        *dont_extra,
        '- `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)',
        '- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)',
        '- `docs/plans/` (never edit a plan or contract by hand)'])
    ncrit = crit.count('\n   mutation:')
    ctx = context('no ' + tdd, 'none', [subject], ncrit, U, I,
                  extra=[GATE, INDENT,
                         f'already-green: criterion {ncrit} (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.',
                         deps_note,
                         'no-real-claude: no command in this contract runs the real claude CLI.',
                         *extra_ctx])
    md = assemble(U, I, objective, affected, e.render(), dont, crit, ctx)
    open(f'../out/{U}.md', 'w').write(md)
    print(len(md), 'bytes', ncrit, 'criteria')
    return N
