#!/usr/bin/env python3
"""Deterministic GNU/WSL -> macOS (bash 3.2 / BSD userland) conversion for the repo's shell scripts.

  python3 -I scripts/portable-convert.py              # dry run: unified diff of every pending fix + manual findings
  python3 -I scripts/portable-convert.py --check      # exit 1 if any fix is pending (CI / pre-push)
  python3 -I scripts/portable-convert.py --write      # apply the fixes in place
  python3 -I scripts/portable-convert.py --root DIR   # operate on another tree (git-tracked *.sh, else a walk)
  python3 -I scripts/portable-convert.py PATH...      # restrict to files / directories

Properties
  * Deterministic: stdlib only, sorted file order, no clock/network/locale input, same bytes in -> same bytes out.
  * Idempotent: every rewrite produces text its own pattern no longer matches; a second --write changes nothing.
  * Conservative: rewrites are exact-shape regexes. A line is skipped when it is a comment, carries
    `# portable-ok`, or the match sits inside single quotes (pinned strings, sed scripts, heredoc stubs
    that are written as quoted text). Anything that needs judgement is only REPORTED (`manual:`), never edited.
  * Default scope: git-tracked *.sh outside docs/, eval/ and the generated copies (.claude/hooks/,
    adapters/*/hooks/); regenerate those with `node bin/cli.js --update --force-render` after --write.

Automatic rewrites (rule ids)
  quote-in-pattern  ${v//$'\\047'/x}   -> ${v//$sq/x} with `sq=$'\\047'` declared in scope (bash 3.2 mis-parses ' and ")
  empty-array-loop  for x in "${a[@]}" -> for x in ${a[@]+"${a[@]}"}   (empty array is "unbound" under set -u on 3.2)
  array-copy        b=( "${a[@]}" )    -> b=( ${a[@]+"${a[@]}"} )      (same reason, one-line array literals)
  case-fold         ${v,,} / ${v^^}    -> $(printf '%s' "$v" | tr ...)  (bash 4+ only)
  mapfile           mapfile -t a < ... -> a=(); while IFS= read -r ...; done < ...
  stat-c            stat -c %Y F || ..  -> adds `stat -f %m F` fallback (GNU first: GNU `stat -f` is filesystem-status)
  stat-format       stat --format=%Y F  -> stat -c %Y F 2>/dev/null || stat -f %m F
  date-d            date -u -d @N +FMT  -> adds `date -u -r N +FMT` fallback
  head-neg          head -n -1 FILE >   -> sed '$d' FILE >
  paste-stdin       paste -sd'x' <<<    -> paste -sd'x' - <<<   (BSD paste needs the `-`)
  sed-brace         sed '/x/{s/a/b/p}'  -> sed '/x/{s/a/b/p;}'   (BSD sed needs `;` before `}`)
"""
import argparse
import difflib
import os
import re
import subprocess
import sys

GENERATED = (".claude/hooks/", "adapters/")
SKIP_DIRS = ("docs/", "eval/", "tmp/")
OK_MARK = "# portable-ok"


# ---------------------------------------------------------------- quoting ---
def quote_state(line, upto):
    """(in_single, in_double) at index `upto` of a shell line; $'..' counts as single-quoted."""
    sq = dq = False
    i = 0
    while i < upto and i < len(line):
        c = line[i]
        if c == "\\" and not sq:
            i += 2
            continue
        if c == '"' and not sq:
            dq = not dq
        elif c == "'" and not dq:
            sq = not sq
        i += 1
    return sq, dq


def sub_outside_single(line, pattern, repl):
    """re.sub that ignores matches starting inside single quotes."""
    out, last = [], 0
    for m in pattern.finditer(line):
        if quote_state(line, m.start())[0]:
            continue
        out.append(line[last:m.start()])
        out.append(repl(m))
        last = m.end()
    out.append(line[last:])
    return "".join(out)


def is_comment(line):
    return line.lstrip().startswith("#")


# ------------------------------------------------------------ line rules ----
STAT_C = re.compile(r"""(?<![/\w.-])stat(?P<L> -L)? -c '?%Y'? (?P<A>"[^"]+"|\$\{?\w+\}?)(?: 2>/dev/null)? \|\| (?!stat )""")
STAT_FMT = re.compile(r"""(?<![/\w.-])stat(?P<L> -L)? --format=%Y (?P<A>"[^"]+")(?P<R> 2>/dev/null)?""")
DATE_D = re.compile(r"""(?<![/\w.-])date -u -d (?:"@(?P<A>\$\{?\w+\}?)"|@"(?P<B>\$\{?\w+\}?)") (?P<F>\+\S+)(?: 2>/dev/null)?""")
FOR_LOOP = re.compile(r"""(\bfor \w+ in )"\$\{(\w+)\[@\]\}"(?=;\s*do\b|\s*$)""")
ARRAY_COPY = re.compile(r"""^(?P<I>\s*(?:local |declare )?\w+)=\((?P<B>.*)\)(?P<T>\s*(?:#.*)?)$""")
ARRAY_ELEM = re.compile(r"""\"\$\{(\w+)\[@\]\}\"""")
CASE_FOLD = re.compile(r"""\$\{(?P<V>[A-Za-z_]\w*|[0-9])(?P<O>,,|\^\^)\}""")
HEAD_NEG = re.compile(r"""(?<![/\w.-])head -n -1 (?P<F>\S+) >""")
PASTE = re.compile(r"""(?<![/\w.-])paste (?P<O>-sd ?|-s -d ?)(?P<D>'[^']*'|"[^"]*")(?=\s*(?:<<<|\)|\||;|$|\|\|))""")
MAPFILE = re.compile(r"""^(?P<I>\s*)(?:mapfile|readarray) -t (?P<N>\w+) (?P<R><.*)$""")
SED_QUOTED = re.compile(r"""(?<![/\w.-])(?P<H>sed\b[^'\n]*?')(?P<S>[^'\n]*)'""")
SED_BRACE = re.compile(r"""(?P<O>(?:^|[\s;/$0-9,])\{)(?P<B>[^{}]*?[/{;\s]?[pdqPDNnGghHxl=])\}""")


def r_stat_c(line):
    return sub_outside_single(
        line, STAT_C,
        lambda m: m.group(0) + "stat%s -f %%m %s 2>/dev/null || " % (m.group("L") or "", m.group("A")))


def r_stat_format(line):
    def f(m):
        L, A = m.group("L") or "", m.group("A")
        return "stat%s -c %%Y %s 2>/dev/null || stat%s -f %%m %s%s" % (L, A, L, A, m.group("R") or "")
    return sub_outside_single(line, STAT_FMT, f)


def r_date_d(line):
    if "date -u -r" in line or line.rstrip().endswith("\\"):
        return line  # fallback already present, or on the continuation line (rules are per-line)

    def f(m):
        var = m.group("A") or m.group("B")
        return m.group(0) + ' || date -u -r "%s" %s 2>/dev/null' % (var, m.group("F"))
    return sub_outside_single(line, DATE_D, f)


def r_for_loop(line):
    return sub_outside_single(line, FOR_LOOP, lambda m: '%s${%s[@]+"${%s[@]}"}' % (m.group(1), m.group(2), m.group(2)))


def r_array_copy(line):
    """name=( "${a[@]}" ... ) on one line: guard each expansion against the empty-array 'unbound' on bash 3.2."""
    body = line.rstrip("\n")
    nl = "\n" if line.endswith("\n") else ""
    m = ARRAY_COPY.match(body)
    if not m or "[@]+" in body:
        return line
    inner = sub_outside_single(m.group("B"), ARRAY_ELEM, lambda e: '${%s[@]+"${%s[@]}"}' % (e.group(1), e.group(1)))
    if inner == m.group("B"):
        return line
    return "%s=(%s)%s%s" % (m.group("I"), inner, m.group("T"), nl)


def r_case_fold(line):
    def f(m):
        a, b = ("[:upper:]", "[:lower:]") if m.group("O") == ",," else ("[:lower:]", "[:upper:]")
        return "$(printf '%%s' \"$%s\" | tr '%s' '%s')" % (m.group("V"), a, b)
    return sub_outside_single(line, CASE_FOLD, f)


def r_head_neg(line):
    return sub_outside_single(line, HEAD_NEG, lambda m: "sed '$d' %s >" % m.group("F"))


def r_paste(line):
    return sub_outside_single(line, PASTE, lambda m: m.group(0) + " -")


def r_mapfile(line):
    m = MAPFILE.match(line.rstrip("\n"))
    if not m:
        return line
    nl = "\n" if line.endswith("\n") else ""
    n = m.group("N")
    return ('%s%s=(); while IFS= read -r _mf_line || [ -n "$_mf_line" ]; do %s+=("$_mf_line"); done %s%s'
            % (m.group("I"), n, n, m.group("R"), nl))


def r_sed_brace(line):
    if "sed" not in line:
        return line

    def fix_script(s):
        return SED_BRACE.sub(lambda m: m.group("O") + m.group("B") + ";}", s)

    def f(m):
        if quote_state(line, m.start())[0]:
            return m.group(0)
        return m.group("H") + fix_script(m.group("S")) + "'"
    return SED_QUOTED.sub(f, line)


LINE_RULES = (
    ("mapfile", r_mapfile),
    ("empty-array-loop", r_for_loop),
    ("array-copy", r_array_copy),
    ("case-fold", r_case_fold),
    ("stat-format", r_stat_format),
    ("stat-c", r_stat_c),
    ("date-d", r_date_d),
    ("head-neg", r_head_neg),
    ("paste-stdin", r_paste),
    ("sed-brace", r_sed_brace),
)


# ----------------------------------------------------- scope-aware rule -----
FUNC_START = re.compile(r"""^(?P<I>\s*)(?:function\s+)?[A-Za-z_][\w:.-]*\s*\(\)\s*\{""")
QUOTE_PAT = re.compile(r"""\$\{[^}\n]*?\$'\\0(?P<C>47|42)'[^}\n]*\}""")
SQ_DECL = "sq=$'\\047'"
DQ_DECL = "dq=$'\\042'"


def fix_quote_in_pattern(lines):
    """Replace $'\\047' / $'\\042' inside ${...} with $sq / $dq and declare them once per scope."""
    out, changes = [], []
    scope_start = 0          # index in `out` where the current function (or file) begins
    func_indent = None
    declared = False
    for idx, line in enumerate(lines):
        stripped = line.rstrip("\n")
        if func_indent is None:
            m = FUNC_START.match(stripped)
            if m and not is_comment(stripped):
                func_indent, scope_start, declared = m.group("I"), len(out), False
        elif stripped == func_indent + "}":
            out.append(line)
            func_indent, scope_start, declared = None, 0, False
            continue
        if is_comment(stripped) or OK_MARK in stripped or "$'\\0" not in stripped:
            out.append(line)
            continue

        def repl(m):
            if quote_state(stripped, m.start())[0]:
                return m.group(0)
            return m.group(0).replace("$'\\047'", "$sq").replace("$'\\042'", "$dq")
        new = QUOTE_PAT.sub(repl, stripped)
        if new == stripped:
            out.append(line)
            continue
        need = [d for d, tok in ((SQ_DECL, "$sq"), (DQ_DECL, "$dq")) if tok in new]
        scope_text = "".join(out[scope_start:])
        missing = [d for d in need if d not in scope_text]
        if missing:
            indent = re.match(r"\s*", new).group(0)
            kw = "local " if func_indent is not None else ""
            out.append("%s%s%s  # bash 3.2 mis-parses ' and \" inside ${v//pat/}: hold them in variables\n"
                       % (indent, kw, " ".join(missing)))
        out.append(new + ("\n" if line.endswith("\n") else ""))
        changes.append(("quote-in-pattern", idx + 1))
    return out, changes


# --------------------------------------------------------- manual findings --
MANUAL = (
    (re.compile(r"\b(?:declare|local|typeset) -A\b"), "associative array (bash 4+): use a case lookup or per-key files"),
    (re.compile(r"\bgrep\b[^|;]*\s-[a-zA-Z]*P"), "grep -P (PCRE) is not in BSD grep: use sed -E / perl"),
    (re.compile(r"(?<![/\w-])sed -i(?!\s*'')(?!\.)"), "sed -i without a backup suffix: BSD needs `-i ''` (tests use tests/lib/bsd-shims)"),
    (re.compile(r"(?<![\w/_-])timeout (?=[\d\"$])"), "timeout is not on macOS: use _portable_timeout (hooks/scripts/lib/portable-tools.sh)"),
    (re.compile(r"\breadlink -f\b"), "readlink -f is GNU-only: use cd/pwd -P"),
    (re.compile(r"\bfind\b[^|;]*-printf\b"), "find -printf is GNU-only"),
    (re.compile(r"/proc/"), "/proc is Linux-only"),
    (re.compile(r"\bxargs -r\b"), "xargs -r is GNU-only"),
    (re.compile(r"(?<![/\w-])date -d\b"), "date -d (unhandled shape): add a `date -r` fallback by hand"),
    (re.compile(r"(?<![/\w-])touch -d\b"), "touch -d is GNU-only (BSD: touch -t); tests get a shim"),
    (re.compile(r"(?<![/\w_-])(?:sha256sum|sha1sum|md5sum)\b(?!\|)"), "use _portable_sha256 (shasum -a 256 on macOS)"),
    (re.compile(r"(?<![/\w.-])stat -[cL ]*c\b(?![^\n]*stat [^\n]*-f)"), "stat -c without a BSD `stat -f` fallback on the same line"),
    (re.compile(r"\$\{[A-Za-z_]\w*@[QEPAa]\}"), "${v@Q}-style transforms are bash 4.4+"),
    (re.compile(r"\$\(\s*case\b|<\([^)]*\bcase\b"), "case inside $( ) / <( ): bash 3.2 mis-parses it, move it into a function"),
    (re.compile(r"\$\{[^}]*/#?[^}]*\\~[^}]*\}"), "\\~ in a ${v/pat/\\~} replacement keeps the backslash on bash 3.2: use a variable"),
    (re.compile(r"\[\[[^\]]*\[\[:(?:upper|lower)"), "POSIX classes in [[ == ]] misbehave under nocasematch on bash 3.2"),
    (re.compile(r"(?:\bflock\b|\bsetsid\b|\btac\b|\bnumfmt\b)"), "GNU/Linux-only utility"),
    (re.compile(r"\bhead -n? ?-\d"), "negative head count is GNU-only"),
)


def manual_findings(path, lines):
    found = []
    for i, line in enumerate(lines, 1):
        if is_comment(line) or OK_MARK in line:
            continue
        for pat, msg in MANUAL:
            m = pat.search(line)
            if m and not quote_state(line, m.start())[0]:
                found.append("manual: %s:%d: %s\n        %s" % (path, i, msg, line.strip()[:140]))
    return found


# ------------------------------------------------------------------ driver --
def convert(text):
    """Return (new_text, [(rule, lineno)]). Pure function of `text`."""
    lines = text.splitlines(keepends=True)
    changes = []
    new = []
    for i, line in enumerate(lines, 1):
        cur = line
        if not is_comment(cur) and OK_MARK not in cur:
            for name, rule in LINE_RULES:
                nxt = rule(cur)
                if nxt != cur:
                    changes.append((name, i))
                    cur = nxt
        new.append(cur)
    new, qchanges = fix_quote_in_pattern(new)
    changes.extend(qchanges)
    return "".join(new), sorted(changes, key=lambda c: (c[1], c[0]))


def discover(root, paths):
    files = []
    if paths:
        for p in paths:
            ap = os.path.join(root, p) if not os.path.isabs(p) else p
            if os.path.isdir(ap):
                for d, _, fs in os.walk(ap):
                    files += [os.path.relpath(os.path.join(d, f), root) for f in fs if f.endswith(".sh")]
            else:
                files.append(os.path.relpath(ap, root))
    else:
        try:
            r = subprocess.run(["git", "-C", root, "ls-files", "*.sh"], capture_output=True, text=True, check=True)
            files = [f for f in r.stdout.split("\n") if f]
        except (subprocess.CalledProcessError, FileNotFoundError):
            for d, _, fs in os.walk(root):
                files += [os.path.relpath(os.path.join(d, f), root) for f in fs if f.endswith(".sh")]
        files = [f for f in files if not f.startswith(GENERATED + SKIP_DIRS)]
        files = [f for f in files if not (f.startswith("adapters/") and "/hooks/" in f)]
    return sorted(set(files))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--write", action="store_true", help="apply the fixes in place")
    ap.add_argument("--check", action="store_true", help="exit 1 when any fix is pending (no output of diffs)")
    ap.add_argument("--strict", action="store_true", help="with --check, manual findings also fail")
    ap.add_argument("--no-syntax", action="store_true", help="skip the /bin/bash -n syntax pass")
    ap.add_argument("--quiet-manual", action="store_true", help="do not print manual findings")
    args = ap.parse_args(argv)

    pending = manual = bad_syntax = 0
    bash = "/bin/bash" if os.path.exists("/bin/bash") else None
    for rel in discover(args.root, args.paths):
        path = os.path.join(args.root, rel)
        try:
            with open(path, newline="", encoding="utf-8") as fh:
                old = fh.read()
        except (OSError, UnicodeDecodeError) as e:
            print("skip: %s: %s" % (rel, e), file=sys.stderr)
            continue
        new, changes = convert(old)
        if changes:
            pending += len(changes)
            if args.write:
                with open(path, "w", newline="", encoding="utf-8") as fh:
                    fh.write(new)
                print("fixed: %s (%s)" % (rel, ", ".join(sorted({c[0] for c in changes}))))
            elif not args.check:
                sys.stdout.writelines(difflib.unified_diff(
                    old.splitlines(keepends=True), new.splitlines(keepends=True), "a/" + rel, "b/" + rel))
            else:
                for rule, ln in changes:
                    print("pending: %s:%d: %s" % (rel, ln, rule))
        if not args.quiet_manual:
            for f in manual_findings(rel, new.splitlines()):
                manual += 1
                print(f)
        if bash and not args.no_syntax:
            r = subprocess.run([bash, "-n", path], capture_output=True, text=True)
            if r.returncode:
                bad_syntax += 1
                print("syntax: %s: %s" % (rel, r.stderr.strip().splitlines()[0] if r.stderr.strip() else "error"))
    verb = "applied" if args.write else "pending"
    print("\nportable-convert: %d fix(es) %s, %d manual finding(s), %d syntax error(s)" % (pending, verb, manual, bad_syntax))
    if bad_syntax:
        return 1
    if args.check and (pending or (args.strict and manual)):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
