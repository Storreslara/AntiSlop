Unit: rfp-u2b

## Objective
Harden the Gate G replay tooling that rfp-u2 shipped (commit 6c8b4b1a, reviewer PASS) before the paid replay
(Gate G2). The reviewer's advisory findings show that the gate measurement could be weak or gamed:
1. `score.py` counts rows, not distinct ids: one real id repeated 30 times passes `--gate`.
2. The replay runs in a worktree that shares refs with the main repository, so `git log --all` shows the
   later fix commit. Read and grep reach the main checkout's FAIL records and `labels.tsv` by absolute path.
3. `run.sh` allows `Bash(git *)` and `Bash(grep *)`, while the README says read-only.
4. `run.sh` drops a whole group when its worktree or brief fails, so those rows count as neither unanswered
   nor missed.
5. The builder docstring promises a diffstat it does not print, and the 300-character claim cut is not
   documented.

The fix:
- `score.py` scores distinct ids. Ids not in `labels.tsv` are `foreign` and ignored. Repeated rows for one
  id count once, and a conflict fails the gate. Every id labelled real or bogus must have a row (otherwise
  `insufficient`), and `real >= 30` counts distinct ids.
- `run.sh` replays each group in a fresh repository fetched up to the reviewed commit only. It emits `NONE`
  rows for a group it cannot set up.
- The `claude -p` call loads no user, project or plugin settings, gets four tools, and pre-approves only
  `git show`, `git diff` and `git log`.
- A new PreToolUse hook, `guard.py`, refuses every read outside the clone and every other Bash command.
- `run.sh` stops with exit 3 if a run used tools but the hook logged no call.
- The docs say exactly this.

This unit runs **no** model: `claude` is a fake on `PATH` in every test. The Gate G thresholds (`MIN_REAL`
30, `MAX_MISSES` 1, `MAX_UNANSWERED` 0.20, `MAX_TURNS` 10) and the 41 `unknown` labels do not change. The
corpus is not regenerated, because no builder logic changes.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Units and order", "Step 2b",
"Gate G"). This file is the contract of record. Dispatch after rfp-u2 has a PASS (it has one); Gate G runs
only after this unit's PASS.

## Affected files
- `tests/refutation-replay-isolation.test.sh` (anchor: new file, mode 755)
- `eval/refutation-replay/guard.py` (anchor: new file, mode 755)
- `eval/refutation-replay/score.py` (anchor: whole file, replaced; mode stays 755)
- `eval/refutation-replay/run.sh` (anchor: whole file, replaced; mode stays 755)
- `eval/refutation-replay/build-corpus.py` (anchor: the module docstring, two edits)
- `eval/refutation-replay/README.md` (anchor: three `before:` blocks in edit 6)
- `tests/validate.sh` (anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`)

## Ordered edits
1. file: `tests/refutation-replay-isolation.test.sh` (new, mode 755). Create it with the **Write** tool (a
   heredoc is refused by the hooks), then `chmod 755`. Content:
~~~
#!/usr/bin/env bash
# Fixture suite for the Gate G hardening of eval/refutation-replay/ (rfp-u2b): per-id scoring, the
# history-limited replay clone, the guard hook, NONE rows for groups that cannot run, and the docs.
# Every fixture lives under mktemp -d. `claude` is a fake on PATH: no model runs, nothing is spent.
set -uo pipefail
cd "$(dirname "$0")/.."
root="$(pwd)"
d="$root/eval/refutation-replay"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ---- per-id scoring (finding 1) ----
labels() { # <dir> <n-real>: labels.tsv with r1..rn real
  local i; mkdir -p "$1"; printf '# id\tlabel\n' > "$1/labels.tsv"
  for i in $(seq 1 "$2"); do printf 'r%d\treal\n' "$i" >> "$1/labels.tsv"; done; : > "$1/report.jsonl"
}
row() { # <dir> <id> <answer> [artifact]
  printf '{"id": "%s", "answer": "%s", "artifact": "%s", "num_turns": 5, "cost_usd": 0.1}\n' "$2" "$3" "${4:-x.sh:1 guard}" >> "$1/report.jsonl"
}
sc() { python3 "$d/score.py" "$1/report.jsonl" --gate; }
labels "$tmp/a" 30; for i in $(seq 1 30); do row "$tmp/a" r1 CONFIRMED; done
o="$(sc "$tmp/a")"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$o" | grep -q '^replay-gate: insufficient real=1 .* missing=29 ' \
  && ok "(a) one real id repeated 30 times is insufficient" || bad "(a) rc=$rc $o"
labels "$tmp/b" 30; for i in $(seq 1 30); do row "$tmp/b" "r$i" CONFIRMED; done; row "$tmp/b" r1 REFUTED
o="$(sc "$tmp/b")"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$o" | grep -q '^replay-gate: fail real=30 .* dup-conflict=1 ' \
  && ok "(b) conflicting rows for one id fail the gate" || bad "(b) rc=$rc $o"
labels "$tmp/c" 30; for i in $(seq 1 30); do row "$tmp/c" "r$i" CONFIRMED; done; row "$tmp/c" r2 CONFIRMED
o="$(sc "$tmp/c")"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$o" | grep -q '^replay-gate: pass real=30 .* dup-conflict=0 ' \
  && ok "(c) an identical repeated row counts once" || bad "(c) rc=$rc $o"
labels "$tmp/e" 30; for i in $(seq 1 30); do a=CONFIRMED; [ "$i" -gt 23 ] && a=NONE; row "$tmp/e" "r$i" "$a"; done
for i in $(seq 1 100); do row "$tmp/e" "x$i" CONFIRMED; done
o="$(sc "$tmp/e")"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'unanswered=7 .* foreign=100$' \
  && ok "(e) rows with unlabelled ids cannot dilute the unanswered share" || bad "(e) rc=$rc $o"
labels "$tmp/f" 31; for i in $(seq 1 30); do row "$tmp/f" "r$i" CONFIRMED; done
o="$(sc "$tmp/f")"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$o" | grep -q '^replay-gate: insufficient real=30 .* missing=1 ' \
  && ok "(f) a labelled id with no report row is insufficient" || bad "(f) rc=$rc $o"

# ---- the guard hook (findings 2 and 3) ----
croot="$tmp/croot"; sec="$tmp/secret"; glog="$tmp/guard.log"
mkdir -p "$croot/src" "$sec"; printf 'a\n' > "$croot/src/a.sh"; printf 'r1\treal\n' > "$sec/labels.tsv"
ln -s "$sec" "$croot/src/out"
gbad=0; calls=0
gp() { # <want-rc> <tool> <key> <value>
  python3 -c 'import json, sys; print(json.dumps({"tool_name": sys.argv[1], "tool_input": {sys.argv[2]: sys.argv[3]}}))' "$2" "$3" "$4" \
    | python3 "$d/guard.py" "$croot" "$glog" 2>/dev/null; local r=$?
  calls=$((calls + 1))
  [ "$r" = "$1" ] || { echo "  guard: $2 $3=$4 rc=$r want=$1"; gbad=1; }
}
gp 0 Read file_path "$croot/src/a.sh"
gp 0 Read file_path src/a.sh
gp 0 Grep path "$croot"
gp 0 Glob pattern '**/*.sh'
gp 0 Bash command 'git show HEAD:src/a.sh'
gp 0 Bash command 'git log --oneline -- src/a.sh'
gp 0 Bash command 'git diff HEAD~1..HEAD -- src/a.sh'
gp 0 Bash command 'git log --format="%h %s" -3'
gp 2 Read file_path "$sec/labels.tsv"
gp 2 Read file_path "$croot/src/out/labels.tsv"
gp 2 Read file_path "$croot/../secret/labels.tsv"
gp 2 Grep path "$sec"
gp 2 Glob pattern "$sec/*"
gp 2 Glob pattern '../**'
gp 2 Bash command 'git -c alias.show=!sh show'
gp 2 Bash command 'git update-ref refs/heads/x HEAD'
gp 2 Bash command "git diff /dev/null $sec/labels.tsv"
gp 2 Bash command 'git diff ../secret/labels.tsv src/a.sh'
gp 2 Bash command 'git diff ~/labels.tsv src/a.sh'
gp 2 Bash command 'git diff --no-index src/a.sh src/b.sh'
gp 2 Bash command 'git log --output=x'
gp 2 Bash command 'git log --outp=x'
gp 2 Bash command 'git diff -Oorder src/a.sh'
gp 2 Bash command "git log --pathspec-from-file=$sec/labels.tsv"
gp 2 Bash command 'git show HEAD; cat src/a.sh'
gp 2 Bash command 'git show $(cat src/a.sh)'
gp 2 Bash command 'git log --all | head'
gp 2 Bash command 'grep -r x .'
gp 2 Bash command 'GIT_DIR=x git log'
gp 2 Write file_path "$croot/src/a.sh"
gp 2 WebFetch url 'https://example.com'
[ "$gbad" = 0 ] && [ "$(grep -c . "$glog" 2>/dev/null)" = "$calls" ] \
  && ok "(g) guard allows clone-local reads and git show|diff|log only, and logs every call" || bad "(g) guard"

# ---- run.sh against a fixture repository, with a fake claude (findings 2, 3 and 4) ----
repo="$tmp/repo"; mkdir -p "$repo/src"
gc() { ( cd "$repo" && git -c user.email=t@t -c user.name=t "$@" ); }
( cd "$repo" && git init -q . )
printf 'a\n' > "$repo/src/a.sh"; gc add -A; gc commit -q -m base
printf 'a\nx\n' > "$repo/src/a.sh"; gc commit -q -am "feat(u9): first"
printf 'a\ny\n' > "$repo/src/a.sh"; gc commit -q -am "fix(u9): second"
printf 'r\n' > "$repo/src/b.sh"; gc add -A; gc commit -q -m "feat(u8): later"
B="$(gc rev-parse HEAD~3)"; R="$(gc rev-parse HEAD~2)"; L1="$(gc rev-parse HEAD~1)"; L2="$(gc rev-parse HEAD)"
refs0="$(gc for-each-ref | md5sum)"
corp="$tmp/corpus.jsonl"
python3 - "$corp" "$R" "$B" <<'PY'
import json, sys
out, R, B = sys.argv[1:4]
rows = [('g1', R, B, 'D1: src/a.sh:2 x is unquoted'), ('g1', R, B, 'D2: src/a.sh:1 no guard on empty input'),
        ('g2', '0' * 40, B, 'D1: src/a.sh:2 unreachable reviewed commit'),
        ('g3', R, B, 'D1: no citation on this line')]
with open(out, 'w') as f:
    for n, (g, rv, bl, dl) in enumerate(rows):
        f.write(json.dumps({'id': '%s#%d' % (g, n), 'group': g, 'reviewed': rv, 'baseline': bl, 'dline': dl}) + '\n')
PY
fb="$tmp/fakebin"; mkdir -p "$fb"
cat > "$fb/claude" <<'EOF'
#!/usr/bin/env bash
# Fake claude: records what the replay environment can reach, calls the guard hook named in --settings
# like Claude Code would (unless FAKE_MODE=noguard), and prints a print-mode JSON result.
settings=""; prev=""
for a in "$@"; do [ "$prev" = --settings ] && settings="$a"; prev="$a"; done
p="$PROBE/$(ls "$PROBE" | wc -l)"; mkdir -p "$p"
printf '%s\n' "$@" > "$p/argv"; pwd -P > "$p/cwd"
git rev-list --all > "$p/revs" 2>/dev/null; git remote > "$p/remotes"
{ [ -e .git/objects/info/alternates ] && echo alternates; [ -e .git/FETCH_HEAD ] && echo fetch-head
  git for-each-ref --format='%(refname)'; find . -name labels.tsv -o -name corpus.jsonl; } > "$p/leaks"
if [ "${FAKE_MODE:-guard}" = guard ]; then
  cmd="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["hooks"]["PreToolUse"][0]["hooks"][0]["command"])' "$settings")"
  printf '{"tool_name": "Read", "tool_input": {"file_path": "%s/src/a.sh"}}' "$PWD" | sh -c "$cmd"; echo $? > "$p/guard-in"
  printf '{"tool_name": "Read", "tool_input": {"file_path": "%s"}}' "$LABELS" | sh -c "$cmd" 2>/dev/null; echo $? > "$p/guard-out"
fi
printf '{"result": "D1: CONFIRMED — q1=a — artifact: src/a.sh:2\\nD2: UNCERTAIN — q1=b — artifact: none", "num_turns": 3, "total_cost_usd": 0.01}\n'
EOF
chmod +x "$fb/claude"
pr="$tmp/probe"; mkdir -p "$pr"
rep="$tmp/report.jsonl"
PATH="$fb:$PATH" PROBE="$pr" LABELS="$d/labels.tsv" bash "$d/run.sh" --corpus "$corp" --repo "$repo" --out "$rep" >/dev/null 2>"$tmp/run.err"; rc=$?
p="$pr/0"
cwd="$(cat "$p/cwd" 2>/dev/null)"
if [ "$rc" = 0 ] && [ "$(ls "$pr" | wc -l)" = 1 ] && [ -n "$cwd" ] && [ "${cwd#"$repo"}" = "$cwd" ] && [ "${cwd#"$root"}" = "$cwd" ] \
   && grep -qx "$R" "$p/revs" && grep -qx "$B" "$p/revs" && ! grep -qx "$L1" "$p/revs" && ! grep -qx "$L2" "$p/revs" \
   && [ ! -s "$p/remotes" ] && [ ! -s "$p/leaks" ]; then
  ok "(h) the replay runs in a clone holding history up to the reviewed commit only, outside both checkouts"
else
  bad "(h) rc=$rc cwd=$cwd leaks=$(tr '\n' ' ' < "$p/leaks" 2>/dev/null) err=$(head -c 300 "$tmp/run.err")"
fi
[ "$(cat "$p/guard-in" 2>/dev/null)" = 0 ] && [ "$(cat "$p/guard-out" 2>/dev/null)" = 2 ] \
  && ok "(i) the --settings hook is guard.py on the clone: in-clone read allowed, the labels file refused" \
  || bad "(i) guard-in=$(cat "$p/guard-in" 2>/dev/null) guard-out=$(cat "$p/guard-out" 2>/dev/null)"
want='--setting-sources local --strict-mcp-config --permission-mode dontAsk --tools Read,Grep,Glob,Bash --allowedTools Read Grep Glob Bash(git show *) Bash(git diff *) Bash(git log *) --settings'
got="$(sed -n '/^--setting-sources$/,/^--settings$/p' "$p/argv" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
[ "$got" = "$want" ] && ! grep -qxE 'Bash\(git \*\)|Bash\(grep \*\)' "$p/argv" \
  && ok "(j) claude gets no user or project settings, four tools and git show|diff|log only" || bad "(j) argv: $got"
ans="$(python3 -c 'import json, sys
for l in open(sys.argv[1]):
    r = json.loads(l); print(r["id"], r["answer"], r.get("setup", "-"))' "$rep" 2>/dev/null | tr '\n' ',')"
[ "$ans" = "g1#0 CONFIRMED -,g1#1 UNCERTAIN -,g2#2 NONE clone,g3#3 NONE brief," ] \
  && ok "(k) a group whose clone or brief fails gets one NONE row per defect" || bad "(k) rows: $ans"
[ "$(gc for-each-ref | md5sum)" = "$refs0" ] && [ "$(gc worktree list | grep -c .)" = 1 ] \
  && ok "(l) the source repository's refs and worktrees are untouched" || bad "(l) source repository changed"
pr2="$tmp/probe2"; mkdir -p "$pr2"
PATH="$fb:$PATH" PROBE="$pr2" LABELS="$d/labels.tsv" FAKE_MODE=noguard bash "$d/run.sh" --corpus "$corp" --repo "$repo" --out "$tmp/r2.jsonl" >/dev/null 2>"$tmp/r2.err"; rc=$?
[ "$rc" = 3 ] && grep -q 'guard not invoked for g1' "$tmp/r2.err" \
  && ok "(m) a run that used tools without a guard call stops the replay (exit 3)" || bad "(m) rc=$rc $(head -c 200 "$tmp/r2.err")"
pr3="$tmp/probe3"; mkdir -p "$pr3"
dr="$(PATH="$fb:$PATH" PROBE="$pr3" bash "$d/run.sh" --dry-run --corpus "$corp" --repo "$repo")"; rc=$?
[ "$rc" = 0 ] && [ "$(ls "$pr3" | wc -l)" = 0 ] && [ "$(printf '%s\n' "$dr" | grep -cF -- "$want")" = 3 ] \
  && ok "(n) --dry-run prints the guarded flags for each group and runs nothing" || bad "(n) rc=$rc"

# ---- docs match the code (findings 3 and 5) ----
rules="$(grep -oE '"Bash\(git [a-z]+ \*\)"' "$d/run.sh" | sed -E 's/"Bash\(git ([a-z]+) \*\)"/`git \1`/' | paste -sd, - | sed 's/,\([^,]*\)$/ and \1/; s/,/, /g')"
[ -n "$rules" ] && grep -qF "Bash only as $rules" "$d/README.md" && ! grep -qF '`git`, `grep`' "$d/README.md" \
  && ok "(o) README names exactly run.sh's Bash rules ($rules)" || bad "(o) README does not say: Bash only as $rules"
cut="$(grep -oE "claim\[:[0-9]+\]" "$d/build-corpus.py" | grep -oE '[0-9]+')"
doc="$(python3 -c 'import ast, sys; print(" ".join(ast.get_docstring(ast.parse(open(sys.argv[1]).read())).split()))' "$d/build-corpus.py")"
[ -n "$cut" ] && printf '%s' "$doc" | grep -q "cut at $cut characters" && grep -q "cut at $cut characters" "$d/README.md" \
  && ! printf '%s' "$doc" | grep -qi diffstat \
  && ok "(p) the builder docstring and README state the $cut-character claim cut, and no diffstat" || bad "(p) cut=$cut"

if [ "$fail" -eq 0 ]; then echo "All refutation-replay-isolation checks passed."; else echo "refutation-replay-isolation: FAILED"; fi
exit "$fail"
~~~
   Run it: it must exit 1, because `guard.py` does not exist yet. This is the red step. Criterion 3 checks
   later which cases are red against rfp-u2's files.
2. file: `eval/refutation-replay/guard.py` (new, mode 755; Write tool, then `chmod 755`). Content:
~~~
#!/usr/bin/env python3
"""PreToolUse guard for the refutation replay (rfp-u2b, docs/plans/2026-10-27-refutation-pass.md).

Hook command, written by run.sh into each run's --settings file:  guard.py <clone-root> <log-file>
Reads one Claude Code hook payload on stdin and allows only:
- Read, Grep and Glob on paths inside <clone-root>, after resolving symlinks;
- Bash as `git show`, `git diff` or `git log`, with no shell operator, no argument (or `--opt=` value)
  that starts with `/` or `~` or has a `..` path segment, and none of the options that read or write
  other files (`--output`, `-O`, `--no-index`, `--ext-diff`, `--textconv`, abbreviations included).
Anything else exits 2 with the reason on stderr, which blocks the call. `git -c` and git aliases cannot
pass: the second word must be the subcommand itself, and git never lets an alias shadow a builtin.
Every call appends one line to <log-file>, so run.sh can tell that the hook is wired.
"""
import json, os, re, shlex, sys

SUBCOMMANDS = ('show', 'diff', 'log')
META = re.compile(r'[;|&$`<>(){}\\\n\r]')
BAD_OPT = re.compile(r'^(--ou|--no-ind|--ext|--textc|-O)')
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


def main(argv):
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


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
~~~
3. file: `eval/refutation-replay/score.py`: replace the whole file with the following. Keep mode 755.
~~~
#!/usr/bin/env python3
"""Score a refutation replay (rfp-u2; per-id scoring rfp-u2b). Usage: score.py <report.jsonl> [--gate] [--labels <labels.tsv>]

A report row is {"id", "answer": REFUTED|CONFIRMED|UNCERTAIN|NONE, "artifact", "num_turns", "cost_usd"}.
Scoring is per distinct id, never per row:
- a row whose id is not in labels.tsv is `foreign` and ignored;
- repeated rows for one id count once; if they differ in answer or artifact, the id is a `dup-conflict`;
- every id labelled real or bogus must have a row, or it is `missing`.
A real defect answered REFUTED with a non-empty artifact is a miss: the pass would have dropped a real
defect. Prints one line:
  replay-gate: <pass|fail|insufficient> real=<n> refuted-real=<m> confirmed-real=<c> uncertain-real=<u>
  unanswered=<x> bogus=<b> refuted-bogus=<rb> max-turns=<t> mean-cost-usd=<c> missing=<k>
  dup-conflict=<d> foreign=<f>
With --gate: exit 0 on pass, 1 on fail, 2 on insufficient.
insufficient = fewer than MIN_REAL distinct real ids, or missing > 0.
pass = not insufficient, refuted-real <= MAX_MISSES, unanswered <= 20% of the scored ids,
max-turns <= MAX_TURNS and dup-conflict = 0. Anything else is fail. Without --gate it always exits 0.
"""
import json, os, sys

MIN_REAL, MAX_MISSES, MAX_TURNS, MAX_UNANSWERED = 30, 1, 10, 0.20


def main(argv):
    gate = '--gate' in argv
    args = [x for x in argv if x != '--gate']
    labels_file = None
    if '--labels' in args:
        i = args.index('--labels')
        labels_file = args[i + 1]
        del args[i:i + 2]
    report = args[0] if args else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'report.jsonl')
    labels_file = labels_file or os.path.join(os.path.dirname(os.path.abspath(report)), 'labels.tsv')
    labels = {}
    if os.path.exists(labels_file):
        for l in open(labels_file):
            if l.strip() and not l.startswith('#'):
                k, _, v = l.rstrip('\n').partition('\t')
                labels[k] = v
    rows = [json.loads(l) for l in open(report) if l.strip()] if os.path.exists(report) else []
    first, conflict, foreign, turns = {}, set(), set(), []
    for r in rows:
        rid = str(r.get('id'))
        if rid not in labels:
            foreign.add(rid)
            continue
        turns.append(int(r.get('num_turns') or 0))
        if rid not in first:
            first[rid] = r
        elif (first[rid].get('answer'), first[rid].get('artifact')) != (r.get('answer'), r.get('artifact')):
            conflict.add(rid)
    scored = list(first.values())
    real = [r for r in scored if labels[str(r.get('id'))] == 'real']
    bogus = [r for r in scored if labels[str(r.get('id'))] == 'bogus']
    missing = sum(1 for k, v in labels.items() if v in ('real', 'bogus') and k not in first)
    refuted = lambda r: r.get('answer') == 'REFUTED' and str(r.get('artifact') or '').strip() != ''
    misses = sum(1 for r in real if refuted(r))
    unanswered = sum(1 for r in scored if r.get('answer') not in ('REFUTED', 'CONFIRMED', 'UNCERTAIN'))
    costs = [float(r.get('cost_usd') or 0) for r in scored]
    max_turns = max(turns) if turns else 0
    if len(real) < MIN_REAL or missing:
        verdict, code = 'insufficient', 2
    elif (misses <= MAX_MISSES and unanswered <= MAX_UNANSWERED * len(scored) and max_turns <= MAX_TURNS
          and not conflict):
        verdict, code = 'pass', 0
    else:
        verdict, code = 'fail', 1
    print('replay-gate: %s real=%d refuted-real=%d confirmed-real=%d uncertain-real=%d unanswered=%d bogus=%d '
          'refuted-bogus=%d max-turns=%d mean-cost-usd=%.3f missing=%d dup-conflict=%d foreign=%d' % (
              verdict, len(real), misses, sum(1 for r in real if r.get('answer') == 'CONFIRMED'),
              sum(1 for r in real if r.get('answer') == 'UNCERTAIN'), unanswered, len(bogus),
              sum(1 for r in bogus if refuted(r)), max_turns, (sum(costs) / len(costs)) if costs else 0.0,
              missing, len(conflict), len(foreign)))
    return code if gate else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
~~~
4. file: `eval/refutation-replay/run.sh`: replace the whole file with the following. Keep mode 755.
~~~
#!/usr/bin/env bash
# Refutation replay runner (rfp-u2, Gate G2; isolation rfp-u2b). For each corpus group (at most 3 defects
# from one past FAIL block), fetch the reviewed commit into a fresh repository that holds only the history
# up to that commit (no other refs, no remote, no FETCH_HEAD, no alternates), build the brief there with
# this checkout's bin/refutation-brief.sh, and run one headless `claude -p` on sonnet with a 10-turn cap.
# The run loads no user, project or plugin settings (--setting-sources local; the clone has no
# .claude/settings.local.json) and only guard.py as a PreToolUse hook: Read, Grep and Glob inside the
# clone, Bash only as `git show`, `git diff` or `git log`. Each answer line
# `D<n>: VERDICT — ... — artifact: ...` becomes one report row. A group whose clone or brief fails gets
# one NONE row per defect, so the scorer counts it as unanswered.
# Usage: eval/refutation-replay/run.sh [--dry-run] [--corpus <file>] [--out <file>] [--repo <dir>]
# --dry-run prints one `group=<id> cmd: ...` line per group and runs nothing: no claude, no clone.
# Exit 3: a run used tools but the guard logged no call, so the guard is not wired; the replay stops.
# A real run spends API budget (each run capped by --max-budget-usd 1). The human runs it (Gate G2).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
corpus="$here/corpus.jsonl"
out="$here/report.jsonl"
dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1; shift ;;
    --corpus) corpus="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    --repo) repo="$(cd "$2" && pwd)"; shift 2 ;;
    *) echo "run.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -f "$corpus" ] || { echo "run.sh: no corpus at $corpus" >&2; exit 2; }
brief="$here/../../bin/refutation-brief.sh"
[ -f "$brief" ] || { echo "run.sh: missing bin/refutation-brief.sh (rfp-u1)" >&2; exit 2; }
brief="$(cd "$(dirname "$brief")" && pwd)/refutation-brief.sh"

CLAUDE_FLAGS=(--model sonnet --max-turns 10 --output-format json --no-session-persistence
  --max-budget-usd 1 --setting-sources local --strict-mcp-config --permission-mode dontAsk
  --tools Read,Grep,Glob,Bash
  --allowedTools Read Grep Glob "Bash(git show *)" "Bash(git diff *)" "Bash(git log *)")

groups="$(python3 - "$corpus" <<'PY'
import json, sys, collections
g = collections.OrderedDict()
for l in open(sys.argv[1]):
    if l.strip():
        r = json.loads(l)
        g.setdefault(r['group'], []).append(r)
for gid, rows in g.items():
    print('\t'.join([gid, rows[0]['reviewed'], rows[0]['baseline'], json.dumps([r['dline'] for r in rows]), json.dumps([r['id'] for r in rows])]))
PY
)" || { echo "run.sh: unreadable corpus" >&2; exit 2; }

# A fresh repository holding the reviewed commit's history only, with the baseline in it.
clone() { # <dir> <reviewed> <baseline>
  git init -q "$1" && git -C "$1" fetch -q --no-tags "file://$repo" "$2" \
    && git -C "$1" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD \
    && rm -f "$1/.git/FETCH_HEAD" && git -C "$1" cat-file -e "$3^{commit}"
}
none_rows() { # <ids-json> <setup-step>: one unanswered row per defect of a group that could not run
  python3 -c 'import json, sys
for i in json.loads(sys.argv[1]):
    print(json.dumps({"id": i, "answer": "NONE", "artifact": "", "num_turns": 0, "cost_usd": 0, "setup": sys.argv[2]}, sort_keys=True))' "$1" "$2" >> "$out"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
[ "$dry" = 1 ] || : > "$out"
n=0
while IFS=$'\t' read -r gid reviewed baseline dlines ids; do
  [ -n "$gid" ] || continue
  n=$((n + 1))
  if [ "$dry" = 1 ]; then
    echo "group=$gid cmd: claude -p <brief> ${CLAUDE_FLAGS[*]} --settings <guard.py hook for the group's clone>"
    continue
  fi
  wt="$work/$n"
  clone "$wt" "$reviewed" "$baseline" >/dev/null 2>&1 \
    || { echo "run.sh: clone failed for $gid" >&2; none_rows "$ids" clone; rm -rf "$wt"; continue; }
  prompt="$(cd "$wt" && python3 -c 'import json,sys; print("\n".join(json.loads(sys.argv[1])))' "$dlines" | bash "$brief" "$baseline")" \
    || { echo "run.sh: brief refused for $gid" >&2; none_rows "$ids" brief; rm -rf "$wt"; continue; }
  log="$work/$n.guard.log"; : > "$log"
  python3 -c 'import json, shlex, sys
cmd = " ".join(shlex.quote(x) for x in ["python3"] + sys.argv[1:])
print(json.dumps({"hooks": {"PreToolUse": [{"matcher": "*", "hooks": [{"type": "command", "command": cmd}]}]}}))' \
    "$here/guard.py" "$wt" "$log" > "$work/$n.settings.json"
  ( cd "$wt" && claude -p "$prompt" "${CLAUDE_FLAGS[@]}" --settings "$work/$n.settings.json" ) > "$work/$n.json" 2> "$work/$n.err"
  turns="$(python3 -c 'import json, sys
try:
    print(int(json.load(open(sys.argv[1])).get("num_turns") or 0))
except Exception:
    print(0)' "$work/$n.json")"
  if [ "$turns" -ge 2 ] && [ ! -s "$log" ]; then
    echo "run.sh: guard not invoked for $gid (num_turns=$turns): the guard hook is not wired; stopping" >&2
    exit 3
  fi
  python3 - "$work/$n.json" "$ids" >> "$out" <<'PY'
import json, re, sys
try:
    res = json.load(open(sys.argv[1]))
except Exception:
    res = {}
text = str(res.get('result') or '')
ids = json.loads(sys.argv[2])
ans = {}
for line in text.splitlines():
    m = re.match(r'^\s*D([1-3]):\s*(REFUTED|CONFIRMED|UNCERTAIN)\b(.*)$', line)
    if m and m.group(1) not in ans:
        art = re.search(r'artifact:\s*(.*)$', m.group(3))
        ans[m.group(1)] = (m.group(2), art.group(1).strip() if art else '')
for i, rid in enumerate(ids, 1):
    v, art = ans.get(str(i), ('NONE', ''))
    print(json.dumps({'id': rid, 'answer': v, 'artifact': art, 'num_turns': res.get('num_turns', 0),
                      'cost_usd': res.get('total_cost_usd', 0)}, sort_keys=True))
PY
  rm -rf "$wt"
done <<< "$groups"
echo "run.sh: groups=$n dry-run=$dry out=$( [ "$dry" = 1 ] && echo none || echo "$out")"
~~~
5. file: `eval/refutation-replay/build-corpus.py`, two edits in the module docstring:
   before:
~~~
--labels: print the human labelling checklist (claim, then the fix commit's subject and diffstat).
~~~
   after:
~~~
--labels: print the human labelling checklist (the claim, then the fix commit's short hash and subject).
~~~
   before:
~~~
(every label `unknown`; a human sets real|bogus, Gate G1).
~~~
   after:
~~~
(every label `unknown`; a human sets real|bogus, Gate G1). A claim is whitespace-collapsed and cut at
300 characters; its cited <path>:<line> is kept whole.
~~~
   The docstring side is fixed, not the code: `checklist()` keeps printing the first line of `git show
   --stat` only. This is the cheaper side, and it needs no change to the labelling output.
6. file: `eval/refutation-replay/README.md`, three edits:
   before:
~~~
| `run.sh` | rfp-u2 | one headless `claude -p` per corpus group, at the reviewed commit |
~~~
   after:
~~~
| `run.sh` | rfp-u2, rfp-u2b | one headless `claude -p` per corpus group, in a fresh clone holding the history up to the reviewed commit only |
| `guard.py` | rfp-u2b | the PreToolUse hook of every run: Read, Grep and Glob inside the clone, Bash only as `git show`, `git diff` and `git log` |
~~~
   before:
~~~
   `--max-budget-usd 1` and `--max-turns 10`. Check the plan first with `--dry-run`. Commit
   `report.jsonl`.
~~~
   after:
~~~
   `--max-budget-usd 1` and `--max-turns 10`. Check the plan first with `--dry-run`. A group whose clone
   or brief fails gets one `NONE` row per defect, which counts as unanswered. Exit 3 means a run used
   tools but the guard logged no call: the guard hook is not wired, so fix that and re-run from the
   start. Commit `report.jsonl`.
~~~
   before:
~~~
- The replay is not the `explorer` persona. It sends the same brief, but runs headless with read-only tools
  (`Read`, `Grep`, `Glob`, `git`, `grep`), without the persona body or its graph MCP.
~~~
   after:
~~~
- The replay is not the `explorer` persona. It sends the same brief, but runs headless without the persona
  body or its graph MCP, and loads no user, project or plugin settings (`--setting-sources local`). Its
  tools are Read, Grep and Glob inside the clone and Bash only as `git show`, `git diff` and `git log`.
  `guard.py` refuses everything else, including `git -c`, shell operators and paths outside the clone.
- Each run happens in a fresh repository fetched up to the reviewed commit. The later fix commit, other
  refs, `labels.tsv` and the FAIL records are not in it, and the guard refuses paths outside it.
- A claim is whitespace-collapsed and cut at 300 characters when the corpus is built; its cited
  `<path>:<line>` is kept whole. The live reviewer writes its own defect lines, with no cut.
~~~
   The first `after:` adds a table row, so the Files table gains `guard.py`. Case (o)
   checks that the README sentence names exactly `run.sh`'s Bash rules, and case (p) checks the cut figure
   against the code.
7. file: `tests/validate.sh`
   anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`
   indent: 0
   insert-before:
~~~
echo "== refutation-replay-isolation: per-id gate scoring, history-limited replay clone and guard hook (Bash, rfp-u2b) =="
if bash tests/refutation-replay-isolation.test.sh > /dev/null; then
  echo "OK   tests/refutation-replay-isolation.test.sh"
else
  echo "FAIL tests/refutation-replay-isolation.test.sh"
  fail=1
fi

echo
~~~
   It lands right after rfp-u2's `refutation-replay` block, which ends at the same anchor.
8. command: `git add tests/refutation-replay-isolation.test.sh eval/refutation-replay/guard.py eval/refutation-replay/score.py eval/refutation-replay/run.sh eval/refutation-replay/build-corpus.py eval/refutation-replay/README.md tests/validate.sh && git commit -m "fix(rfp-u2b): per-id replay gate scoring, history-limited replay clone and guard hook"`
   expect: 0
   Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report
   it. No version bump: nothing here is version-stamped (`agents/*.md`, `templates/*`) or shipped to
   consumer projects (`eval/` is `export-ignore`). The same applies to every fix-round commit: subject
   `fix(rfp-u2b): …`, staged by explicit path.

## Do NOT touch
- `eval/refutation-replay/corpus.jsonl` and `eval/refutation-replay/labels.tsv`. The labels stay `unknown`
  (a human sets them in Gate G1), and the corpus is not regenerated (criteria 4 and 7).
- `eval/refutation-replay/report.jsonl`: it must not exist after this unit (criterion 4). Never run
  `run.sh` without `--dry-run` against the real corpus, and never run a real `claude -p`.
- `MIN_REAL`, `MAX_MISSES`, `MAX_TURNS`, `MAX_UNANSWERED` in `score.py` (edit 3 keeps them byte-identical).
- `bin/refutation-brief.sh` (rfp-u1's), `tests/refutation-replay.test.sh` (rfp-u2's suite still passes
  unchanged: criterion 2), and `agents/`, `templates/`, `hooks/`, `adapters/`, `bin/` (criterion 7).
- the reviewed-markers directory under `.claude/`: nothing reads it here. Every fixture lives under
  `mktemp -d`.

## Acceptance criteria
Every expected stdout is a single line. `review-precheck.sh` compares a criterion's whole stdout with one
backtick literal (see "Pre-resolved context").
1. run: `bash -c 'bash tests/refutation-replay-isolation.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: each of these, applied alone, turns the named cases red (stdout `1`), as spec-master ran them on a scratch copy. (i) In `run.sh`, replace the three `"Bash(git … *)"` rules with `"Bash(git *)" "Bash(grep *)"`: cases j, n and o go red. (ii) Delete `none_rows "$ids" clone; `: case k. (iii) Change `if len(real) < MIN_REAL or missing:` to `if len(real) < MIN_REAL:`: case f. (iv) Replace `scored = list(first.values())` with per-row scoring, `scored = [r for r in rows if str(r.get("id")) in labels]`: cases a, b and c. (v) Drop `|-O` from `BAD_OPT`: case g. (vi) Drop ` && rm -f "$1/.git/FETCH_HEAD"`: case h. (vii) Make the guard tripwire `if false; then`: case m.
2. run: `bash -c 'bash tests/refutation-replay.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: reorder the `replay-gate:` fields so that `real=` is no longer second; rfp-u2's case (d) greps `^replay-gate: pass real=30 refuted-real=1 ` and stdout is `1`.
3. run: `bash -c 'b=$(git log --format=%H --fixed-strings --grep="(rfp-u2b)" | tail -1); [ -n "$b" ] || { echo no-commits; exit 1; }; t=$(mktemp -d); mkdir -p "$t/eval/refutation-replay" "$t/bin" "$t/tests"; for f in $(git ls-tree --name-only "$b^" eval/refutation-replay/) bin/refutation-brief.sh; do git show "$b^:$f" > "$t/$f"; done; cp tests/refutation-replay-isolation.test.sh "$t/tests/"; bash "$t/tests/refutation-replay-isolation.test.sh" 2>/dev/null | sed -n "s/^FAIL (\([a-z]\)).*/\1/p" | paste -sd, -; rm -rf "$t"'`
   exit: 0
   stdout: `a,b,c,e,f,g,h,i,j,k,m,n,o,p`
   mutation: weaken a case so that it also passes on rfp-u2's files, e.g. make case (a) accept `rc=0`. Its letter drops out of the list and stdout differs. On a tree with no `(rfp-u2b)` commit, stdout is `no-commits` and the exit is 1. Case (l) is deliberately absent from the list: it guards against a regression (the source repository's refs and worktrees stay untouched), and rfp-u2's worktree code also left them untouched.
4. run: `bash -c 'b=$(git log --format=%H --fixed-strings --grep="(rfp-u2b)" | tail -1); [ -n "$b" ] || { echo no-commits; exit 1; }; n=$(git diff --name-only "$b^" HEAD -- eval/refutation-replay/corpus.jsonl eval/refutation-replay/labels.tsv | wc -l); r=$(test -e eval/refutation-replay/report.jsonl && echo report || echo no-report); echo "changed=$n $r $(python3 eval/refutation-replay/build-corpus.py --check | head -1)"'`
   exit: 0
   stdout: `changed=0 no-report corpus: rows=41 groups=24 units=24 unlabeled=41 real=0 bogus=0 errors=0`
   mutation: set one label in `labels.tsv` to `real`; stdout ends `unlabeled=40 real=1 bogus=0 errors=0`. Committing that change also makes it `changed=1`. On an empty range, stdout is `no-commits` and the exit is 1.
5. run: `bash -c 'o=$(python3 eval/refutation-replay/score.py eval/refutation-replay/report.jsonl --gate); rc=$?; echo "$(printf "%s" "$o" | cut -d" " -f1-3) $(printf "%s" "$o" | grep -o "missing=[0-9]* dup-conflict=[0-9]* foreign=[0-9]*") rc=$rc"'`
   exit: 0
   stdout: `replay-gate: insufficient real=0 missing=0 dup-conflict=0 foreign=0 rc=2`
   mutation: set `MIN_REAL` to 0; stdout is `replay-gate: pass real=0 missing=0 dup-conflict=0 foreign=0 rc=0`. This also shows that the new fields are appended after the old ones, so rfp-u3 criterion 8 (`cut -d" " -f1-2`) still reads `replay-gate: <verdict>`.
6. run: `bash -c 'g=$(python3 eval/refutation-replay/build-corpus.py --check | sed -n "s/.* groups=\([0-9]*\) .*/\1/p"); n=$(bash eval/refutation-replay/run.sh --dry-run | grep -cF -- "--setting-sources local --strict-mcp-config --permission-mode dontAsk --tools Read,Grep,Glob,Bash --allowedTools Read Grep Glob Bash(git show *) Bash(git diff *) Bash(git log *) --settings"); [ -n "$g" ] && [ "$g" -gt 0 ] && [ "$g" = "$n" ] && echo same || echo "differ $g $n"'`
   exit: 0
   stdout: `same`
   mutation: restore `"Bash(git *)" "Bash(grep *)"` in `CLAUDE_FLAGS`; stdout is `differ 24 0`.
7. run: `bash -c 'c=$(git log --format=%H --fixed-strings --grep="(rfp-u2b)"); [ -n "$c" ] || { echo no-commits; exit 1; }; for x in $c; do git show --name-only --format= "$x"; done | sort -u | grep -vxE "eval/refutation-replay/(README\.md|build-corpus\.py|run\.sh|score\.py|guard\.py)|tests/refutation-replay-isolation\.test\.sh|tests/validate\.sh" | wc -l'`
   exit: 0
   stdout: `0`
   mutation: touch `bin/refutation-brief.sh`, or regenerate `corpus.jsonl`, in an `(rfp-u2b)` commit; stdout is `1`. Only this unit's own commits are read (`--fixed-strings` on `(rfp-u2b)`), and on an empty range stdout is `no-commits` with exit 1.
8. run: `bash -c 'git ls-files -s eval/refutation-replay/guard.py eval/refutation-replay/run.sh eval/refutation-replay/score.py tests/refutation-replay-isolation.test.sh | cut -c1-6 | paste -sd, -'`
   exit: 0
   stdout: `100755,100755,100755,100755`
   mutation: commit `guard.py` at mode 644; the first field reads `100644`.
9. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/refutation-replay-isolation.test.sh`; validate.sh reports it (edit 7) and stdout is `1`.

## Pre-resolved context
- **spec-master ran every payload** in a scratch clone at 6c8b4b1a:
  - The new suite passes all 15 cases. Against rfp-u2's files it fails exactly the 14 listed in criterion 3.
  - rfp-u2's suite still passes.
  - Criteria 1 to 8 print their expected lines on a commit subject-tagged `(rfp-u2b)`.
  - Criteria 3, 4 and 7 print `no-commits` and exit 1 on the real tree, which has no such commit.
  - Every `mutation:` line above was run and changes the output as stated.
- **The clone.** `git init` + `git fetch --no-tags file://<repo> <reviewed-sha>` works with git 2.43: a
  local `file://` fetch goes through upload-pack, so objects are copied (no alternates), and a bare commit
  id can be fetched. On this repository it took 0.5 s for the first corpus row. The fix commit was
  unreachable and the baseline reachable. `FETCH_HEAD` names the source path, so `run.sh` deletes it.
- **Settings.**
  - `.claude/settings.json` was tracked here until 3ce5916c (2026-09-23), so a clone at an older reviewed
    commit carries this repository's project hooks.
  - The user's `~/.claude/settings.json` enables the antislop plugin and a Stop hook.
  - `~/.claude/settings.local.json` allows `Bash(python3 -c ' *)`, and allow rules merge across scopes.
  - `--setting-sources local` loads only the clone's `.claude/settings.local.json`, which was never tracked,
    so none of the above loads. Auth is the credentials file, not a setting source.
  - `--strict-mcp-config` ignores the tracked `.mcp.json`.
  - `--permission-mode dontAsk` denies anything not pre-approved without prompting. This CLI (2.1.312) has
    no `default` mode.
- **Why permission rules alone are not enough, and the hook is the enforcement** (Claude Code docs,
  permissions and hooks pages, via `claude-code-guide`):
  - `Bash(git show *)` matches `git show …` and bare `git show`. It does not match `git -c … show`.
  - A compound command needs every part allowed. But read-only commands such as `cat` run without a prompt
    in every mode, so `git show x; cat <labels>` could run.
  - A bare `Read` rule matches absolute paths outside the working directory.
  - A PreToolUse hook that exits 2 blocks the call even when an allow rule matches, and its stderr reaches
    the model. Matcher `"*"` matches every tool.
  - The docs do not state that `--settings` hooks fire in `-p` mode. That is why `run.sh` has the exit-3
    tripwire: a run with `num_turns >= 2` and an empty guard log stops the replay after at most one
    $1-capped run, and the incomplete report scores `insufficient` (missing ids).
- **Git aliases and `-c`.** The guard requires the second word to be `show`, `diff` or `log`. Git never
  lets an alias shadow a builtin, so neither an alias nor `git -c` can reach a subcommand. The guard
  refuses these, abbreviations included:
  - `--output` (writes a file);
  - `-O` (reads an order file);
  - `--no-index`, an absolute path or a `..` segment (`git diff` compares any two files when a path lies
    outside the repository);
  - `--pathspec-from-file=` with an absolute value.
- **The fake `claude`** is the suite's way to test the non-dry path without spending anything. It records
  what the replay environment can reach (cwd, `git rev-list --all`, remotes, refs, `FETCH_HEAD`,
  alternates, stray `labels.tsv`). It calls the hook command named in `--settings` the way Claude Code
  would, and prints a print-mode JSON result.
- **The precheck quirk.** `review-precheck.sh` `run_one` compares a criterion's whole stdout with one
  backtick literal. A two-line expected stdout such as rfp-u2 criterion 3's (`` `…` then `rc=2` ``) can
  never match, so the reviewer had to judge it by hand. Every criterion here has a single-line stdout.
- **The scorer semantics, decided by spec-master** (plan Clarifications):
  - `missing` counts ids labelled real **or** bogus. Dropping bogus `NONE` rows would otherwise shrink the
    unanswered denominator.
  - Identical repeated rows are harmless (a re-appended run). Rows that differ in `answer` or `artifact`
    are a `dup-conflict`, which fails the gate.
  - `max-turns` is read over every labelled row, so a repeated row cannot hide a long run.
- `validate.sh` at default lanes is known to be flaky at the baseline. `ANTISLOP_VALIDATE_LANES=4` is the
  safe setting (criterion 9).

## Escalation
- If a fetch by commit id is refused on the operator's git (an upload-pack `not our ref` error), stop and
  report it. The fallback, a temporary ref in the source repository, changes that repository's refs and is
  a plan decision.
- If a gate blocks a command, report it and wait.
- Anything outside "Affected files" goes in your report as a proposal, not an edit.
