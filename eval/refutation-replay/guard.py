#!/usr/bin/env python3
"""PreToolUse guard for the refutation replay (rfp-u2b, docs/plans/2026-10-27-refutation-pass.md).

Hook command, written by run.sh into each run's --settings file:  guard.py <clone-root> <log-file>
Reads one Claude Code hook payload on stdin and allows only:
- Read, Grep and Glob on paths inside <clone-root>, after resolving symlinks;
- Bash as `git show`, `git diff` or `git log`, with no shell operator, no argument (or `--opt=` value)
  that starts with `/` or `~` or has a `..` path segment, and none of the options that read or write
  other files (`--output`, `--no-index`, `--ext-diff`, `--textconv`, abbreviations included, and `-O`,
  also inside a bundle of short options such as `-RO<file>`). In a bundle, the value-taking `-S`, `-G`
  and `-L` take the rest of the token as their value, so a capital O after them (`-SObject`) is allowed.
Anything else exits 2 with the reason on stderr, which blocks the call. `git -c` and git aliases cannot
pass: the second word must be the subcommand itself, and git never lets an alias shadow a builtin.
Every call appends one line to <log-file>, so run.sh can tell that the hook is wired. Any unexpected
exception also exits 2 (fail closed): exit 1 is a non-blocking hook error that would let the call go ahead.
"""
import json, os, re, shlex, sys

SUBCOMMANDS = ('show', 'diff', 'log')
META = re.compile(r'[;|&$`<>(){}\\\n\r]')
BAD_OPT = re.compile(r'^(--ou|--no-ind|--ext|--textc|-[^-SGL]*O)')
UP = re.compile(r'(^|/)\.\.(/|$)')
HINT = ('Allowed: Read, Grep and Glob inside the replay clone; Bash only as git show, git diff or git log '
        'with repo-relative arguments and no shell operators.')


def inside(root, p):
    if not isinstance(p, str) or not p or p.startswith('~'):
        return False
    real = os.path.realpath(p if os.path.isabs(p) else os.path.join(root, p))
    return real == root or real.startswith(root + os.sep)


def leaves(s):
    return s.startswith(('/', '~')) or bool(UP.search(s))


def reason(root, payload):
    tool = payload.get('tool_name')
    ti = payload.get('tool_input') or {}
    if tool == 'Read':
        return None if inside(root, ti.get('file_path')) else 'Read outside the replay clone'
    if tool in ('Grep', 'Glob'):
        if not inside(root, ti.get('path') or root):
            return '%s path outside the replay clone' % tool
        for k in ('pattern', 'glob') if tool == 'Glob' else ('glob',):
            if isinstance(ti.get(k), str) and leaves(ti[k]):
                return '%s %s leaves the replay clone' % (tool, k)
        return None
    if tool == 'Bash':
        cmd = str(ti.get('command') or '').strip()
        if META.search(cmd):
            return 'shell operators are not allowed'
        try:
            toks = shlex.split(cmd)
        except ValueError:
            return 'unparsable command'
        if len(toks) < 2 or toks[0] != 'git' or toks[1] not in SUBCOMMANDS:
            return 'only git show, git diff and git log are allowed'
        for t in toks[2:]:
            if leaves(t) or ('=' in t and leaves(t.split('=', 1)[1])):
                return 'argument leaves the replay clone: %s' % t
            if BAD_OPT.match(t):
                return 'option not allowed: %s' % t
        return None
    return 'tool not allowed in the replay: %s' % tool


def run(argv):
    if len(argv) != 2:
        print('guard.py: usage: guard.py <clone-root> <log-file>', file=sys.stderr)
        return 2
    root = os.path.realpath(argv[0])
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        payload = {}
    why = reason(root, payload) if isinstance(payload, dict) else 'unreadable payload'
    with open(argv[1], 'a') as f:
        f.write(json.dumps({'tool': payload.get('tool_name') if isinstance(payload, dict) else None,
                            'allowed': why is None}, sort_keys=True) + '\n')
    if why:
        print('replay guard: %s. %s' % (why, HINT), file=sys.stderr)
        return 2
    return 0


def main(argv):
    try:
        return run(argv)
    except Exception as e:  # exit 1 is a non-blocking hook error, so any surprise must exit 2
        print('replay guard: internal error (%s), call blocked. %s' % (type(e).__name__, HINT), file=sys.stderr)
        try:
            with open(argv[1], 'a') as f:
                f.write(json.dumps({'tool': None, 'allowed': False}, sort_keys=True) + '\n')
        except Exception:
            pass
        return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
