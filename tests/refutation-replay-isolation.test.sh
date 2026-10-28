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
