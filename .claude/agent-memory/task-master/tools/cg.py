"""Contract-writing helpers for task-master (generator side).

Usage from a unit script:
    import sys; sys.path.insert(0, '<dir of cg.py>')
    from cg import *
    e = Edits()
    e.new_file('eval/x.sh', open(SCRATCH + '/eval/x.sh').read())
    e.insert_after('.gitignore', 'eval/results.jsonl', 'eval/abtest/.runs/\\neval/abtest/results.jsonl')
    e.command('chmod +x eval/x.sh', 0)
    md = e.render()
`new_file` splits a long file into consecutive insert-after edits of at most
MAXN lines, each split at a line that is unique in the whole file and has no
backtick, so the next edit's anchor `line matching` that line counts 1.
"""
import re

MAXN = 78


def _fence_for(lines):
    f = '~~~~'
    while any(l.strip().startswith(f) for l in lines):
        f += '~'
    return f


def _unique(lit, all_lines):
    return sum(1 for l in all_lines if lit in l) == 1


class Edits:
    def __init__(self, start=1):
        self.n = start
        self.out = []

    def _payload(self, key, lines):
        fence = _fence_for(lines)
        self.out.append(f'   {key}:')
        self.out.append(fence)
        self.out.extend(lines)
        self.out.append(fence)

    def new_file(self, path, text, maxn=MAXN):
        lines = text.rstrip('\n').split('\n')
        i = 0
        anchor = None
        first = True
        while i < len(lines):
            remaining = len(lines) - i
            if remaining <= maxn:
                j = len(lines)
            else:
                j = i + maxn
                while j > i + 10:
                    cand = lines[j - 1]
                    if cand.strip() and '`' not in cand and len(cand.strip()) >= 8 and _unique(cand, lines):
                        break
                    j -= 1
                else:
                    raise SystemExit(f'no unique split line near {path}:{i + maxn}')
            chunk = lines[i:j]
            self.out.append(f'{self.n}. file: `{path}`')
            if first:
                self.out.append('   anchor: new file')
            else:
                self.out.append(f'   anchor: line matching `{anchor}`')
            self.out.append('   indent: 0')
            self._payload('insert-after', chunk)
            self.n += 1
            anchor = chunk[-1]
            first = False
            i = j
        return self.n - 1

    def insert_after(self, path, anchor, text):
        assert '`' not in anchor
        lines = text.rstrip('\n').split('\n')
        self.out.append(f'{self.n}. file: `{path}`')
        self.out.append(f'   anchor: line matching `{anchor}`')
        self.out.append('   indent: 0')
        self._payload('insert-after', lines)
        self.n += 1
        return self.n - 1

    def insert_chunked(self, path, anchor, text, existing, maxn=MAXN):
        lines = text.rstrip('\n').split('\n')
        everything = existing.split('\n') + lines
        i = 0
        while i < len(lines):
            if len(lines) - i <= maxn:
                j = len(lines)
            else:
                j = i + maxn
                while j > i + 10:
                    cand = lines[j - 1]
                    if cand.strip() and '`' not in cand and len(cand.strip()) >= 8 and _unique(cand, everything):
                        break
                    j -= 1
                else:
                    raise SystemExit('no unique split line')
            chunk = lines[i:j]
            self.out.append(f'{self.n}. file: `{path}`')
            self.out.append(f'   anchor: line matching `{anchor}`')
            self.out.append('   indent: 0')
            self._payload('insert-after', chunk)
            self.n += 1
            anchor = chunk[-1]
            i = j
        return self.n - 1

    def replace(self, path, anchor, before, after):
        assert '`' not in anchor
        self.out.append(f'{self.n}. file: `{path}`')
        self.out.append(f'   anchor: line matching `{anchor}`')
        if '\n' in before or '\n' in after or '`' in before or '`' in after:
            self.out.append('   indent: 0')
            self._payload('before', before.split('\n'))
            self._payload('after', after.split('\n'))
        else:
            self.out.append(f'   before: `{before}`')
            self.out.append(f'   after: `{after}`')
        self.n += 1
        return self.n - 1

    def command(self, cmd, expect=0):
        assert '`' not in cmd, 'backtick in command'
        self.out.append(f'{self.n}. command: `{cmd}`')
        self.out.append(f'   expect: {expect}')
        self.n += 1
        return self.n - 1

    def render(self):
        return '\n'.join(self.out) + '\n'


def criterion(n, run, exit_, stdout, mutation, precondition=None, proof=None):
    assert '`' not in run, 'backtick in run'
    s = f'{n}. run: `{run}`\n   exit: {exit_}\n'
    s += f'   stdout: {stdout if stdout == "empty" else "`" + stdout + "`"}\n'
    if precondition:
        s += f'   precondition: {precondition}\n'
    s += f'   mutation: {mutation}\n'
    if proof:
        s += f'   proof: {proof}\n'
    return s


def packet(unit, issue, files_hint, ncrit):
    lines = ['review-packet:', '~~~', f'unit: {unit} (#{issue})',
             'changed files: <FILL: changed files>', 'commit: <FILL: commit SHA>']
    for k in range(1, ncrit + 1):
        lines.append(f'criterion {k}: <FILL: exit and stdout>')
    lines.append('~~~')
    return '\n'.join(lines)


TRAILER = 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'
REPO = 'Storreslara/AntiSlop'
SLUG = 'antislop-vs-fable-evals'
PLAN = 'docs/plans/antislop-vs-fable-evals.md'
DECISIONS = 'docs/plans/antislop-vs-fable-evals/operator-decisions.md'


def commit_cmd(files, subject):
    assert '`' not in subject
    return f'git add {" ".join(files)} && git commit -m "{subject}" -m "{TRAILER}"'


def unit_list(unit):
    uid = unit.replace('.', '\\.')
    return ("L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\\(" + uid +
            "\\): ' | cut -d' ' -f1); test -n \"$L\" || { echo no-unit-commit; exit 3; }; ")


def std_criteria(unit, start, files, content_files, commit_edit, status_paths):
    """Four standard criteria for a one-commit unit. Returns (markdown, next_n)."""
    uid = unit.replace('.', '\\.')
    out = ''
    n = start
    out += criterion(n, unit_list(unit) + 'c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "',
                     0, ' '.join(sorted(files)),
                     f'skip edit {commit_edit} (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.')
    n += 1
    out += criterion(n, unit_list(unit) + 'git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"',
                     0, '1', f'skip edit {commit_edit}; no unit commit exists and the exit is 3.')
    n += 1
    out += criterion(n, unit_list(unit) + 'E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- ' + ' '.join(content_files) +
                     ' | grep -vcE "^[a-z]+\\(' + uid + '\\): "',
                     1, '0',
                     'add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.',
                     proof='scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.')
    n += 1
    out += criterion(n, 'git status --porcelain -- ' + ' '.join(status_paths), 0, 'empty',
                     f'skip edit {commit_edit}; the new files stay untracked and are listed.')
    n += 1
    return out, n


def context(tdd, blast, subjects, ncrit, unit, issue, extra=()):
    lines = [f'tdd: {tdd}', f'blast-radius: {blast}']
    lines += list(extra)
    for s in subjects:
        lines += [f'commit-message: {s}', TRAILER]
    lines += ['diagnosis: none', packet(unit, issue, '', ncrit)]
    return '\n'.join(lines) + '\n'


GATE = ('gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it '
        '(no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.')
INDENT = ('payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; '
          'empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.')
ESC = 'If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.'


def assemble(unit, issue, objective, affected, edits, dont, crit, ctx, extra_retrieval=''):
    retr = (f'GitHub issues: `gh issue view {issue} --repo {REPO}`. Siblings: `gh issue list --repo {REPO} --label plan/{SLUG}`. '
            f'Spec: `{PLAN}`; operator overrides (win on conflict): `{DECISIONS}`.' + extra_retrieval)
    return (f'Unit: {unit}\n\n## Objective\n{objective}\n\n## Retrieval\n{retr}\n\n## Affected files\n{affected}\n\n'
            f'## Ordered edits\n{edits}\n## Do NOT touch\n{dont}\n\n## Acceptance criteria\n{crit}\n## Pre-resolved context\n{ctx}\n## Escalation\n{ESC}\n')
