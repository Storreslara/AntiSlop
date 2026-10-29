#!/usr/bin/env bash
# Fixture suite for the Gate G hardening of eval/refutation-replay/ (rfp-u2b): per-id scoring, the
# history-limited replay clone, the guard hook, NONE rows for groups that cannot run, and the docs; the CLI
# result's subtype, the capped-run gate field, stdin and fd 3, and the parse-first run.sh body (rfp-u2f).
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
[ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'unanswered=7 .* foreign=100 capped=0$' \
  && ok "(e) rows with unlabelled ids cannot dilute the unanswered share" || bad "(e) rc=$rc $o"
labels "$tmp/f" 31; for i in $(seq 1 30); do row "$tmp/f" "r$i" CONFIRMED; done
o="$(sc "$tmp/f")"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$o" | grep -q '^replay-gate: insufficient real=30 .* missing=1 ' \
  && ok "(f) a labelled id with no report row is insufficient" || bad "(f) rc=$rc $o"
# rfp-u2f: a run cut off at the CLI's turn cap fails the gate on its own, whatever its num_turns says
labels "$tmp/s" 30; for i in $(seq 1 29); do row "$tmp/s" "r$i" CONFIRMED; done; cp -r "$tmp/s" "$tmp/s0"
printf '{"id": "r30", "answer": "NONE", "artifact": "", "num_turns": 5, "cost_usd": 0.1, "subtype": "error_max_turns", "is_error": true}\n' >> "$tmp/s/report.jsonl"
printf '{"id": "r30", "answer": "CONFIRMED", "artifact": "x.sh:1 guard", "num_turns": 5, "cost_usd": 0.1, "subtype": "success", "is_error": false}\n' >> "$tmp/s0/report.jsonl"
o="$(sc "$tmp/s")"; rc=$?; o0="$(sc "$tmp/s0")"; rc0=$?
[ "$rc" = 1 ] && printf '%s' "$o" | grep -q '^replay-gate: fail real=30 .* max-turns=5 .* foreign=0 capped=1$' \
  && [ "$rc0" = 0 ] && printf '%s' "$o0" | grep -q '^replay-gate: pass real=30 .* foreign=0 capped=0$' \
  && ok "(s) an error_max_turns run fails the gate as capped=1, appended after foreign=" || bad "(s) rc=$rc $o / rc0=$rc0 $o0"

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

# rfp-u2d: -O inside a bundle of short options is refused, plain bundles stay allowed, and an unexpected
# exception fails closed (exit 2; exit 1 would let the tool call go ahead).
g2bad=0; g2log="$tmp/guard2.log"
gr() { # <want-rc> <label> <raw-stdin-json> [log-path]
  printf '%s' "$3" | python3 "$d/guard.py" "$croot" "${4:-$g2log}" 2>/dev/null; local r=$?
  [ "$r" = "$1" ] || { echo "  guard: $2 rc=$r want=$1"; g2bad=1; }
}
gb() { gr "$1" "$2" "$(python3 -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))' "$2")"; }
gb 2 'git diff -RO/abs/file'
gb 2 'git diff -aO/abs/file'
gb 2 'git log -pO/abs/x'
gb 2 'git diff -aOorder -R src/a.sh'
gb 2 'git diff -pRO'
gb 0 'git log -p -n 5'
gb 0 'git diff -U3'
gb 0 'git show --stat'
gb 0 'git log -pn5'
gb 0 'git diff -R -a src/a.sh'
# rfp-u6b: the value of a bundled -S, -G or -L may hold a capital O; a long option never counts as a bundle
gb 0 'git log -SObject'
gb 0 'git log -pSObject'
gb 0 'git log -G[O]'
gb 0 'git log -L1,2:src/IO.c'
gb 0 'git log --grep=FOO'
gb 2 'git log -pRO/abs/x -SObject'
# rfp-u7e: a .. path segment right after a colon leaves the clone too; a range's .. and a colon value stay allowed
gb 2 'git log -L1,2:../x'
gb 2 'git log -L:main:../x'
gb 2 'git show HEAD:../x'
gb 0 'git diff HEAD~1..HEAD'
gb 0 'git log ..HEAD'
gb 0 'git log -L:main:src/a.sh'
gb 0 'git show HEAD:src/a.sh'
gr 2 'tool_input string' '{"tool_name": "Read", "tool_input": "x"}'
gr 2 'tool_input list' '{"tool_name": "Bash", "tool_input": ["git", "log"]}'
gr 2 'tool_input null' '{"tool_name": "Read", "tool_input": null}'
gr 2 'NUL in Read path' '{"tool_name": "Read", "tool_input": {"file_path": "src/a\u0000.sh"}}'
gr 2 'unwritable log' '{"tool_name": "Read", "tool_input": {"file_path": "src/a.sh"}}' "$tmp/no-such-dir/g.log"
[ "$g2bad" = 0 ] && ok "(g2) guard refuses -O in option bundles, keeps plain bundles, and fails closed on unexpected errors" || bad "(g2) guard"

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
[ -n "${FAKE_DRAIN:-}" ] && cat > "$p/stdin"
{ : <&3; } 2>/dev/null && echo open > "$p/fd3"
if [ -n "${FAKE_MUTATE:-}" ] && [ ! -e "$FAKE_MUTATE.done" ]; then
  # rewrite the runner in place (same inode), as an editor would while a replay runs
  sz="$(wc -c < "$FAKE_MUTATE")"; yes 'exit 7' | head -c "$((sz + 4096))" > "$FAKE_MUTATE"; : > "$FAKE_MUTATE.done"
fi
printf '%s\n' "$@" > "$p/argv"; pwd -P > "$p/cwd"
git rev-list --all > "$p/revs" 2>/dev/null; git remote > "$p/remotes"
{ [ -e .git/objects/info/alternates ] && echo alternates; [ -e .git/FETCH_HEAD ] && echo fetch-head
  git for-each-ref --format='%(refname)'; find . -name labels.tsv -o -name corpus.jsonl; } > "$p/leaks"
if [ "${FAKE_MODE:-guard}" = guard ]; then
  cmd="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["hooks"]["PreToolUse"][0]["hooks"][0]["command"])' "$settings")"
  printf '{"tool_name": "Read", "tool_input": {"file_path": "%s/src/a.sh"}}' "$PWD" | sh -c "$cmd"; echo $? > "$p/guard-in"
  printf '{"tool_name": "Read", "tool_input": {"file_path": "%s"}}' "$LABELS" | sh -c "$cmd" 2>/dev/null; echo $? > "$p/guard-out"
fi
if [ -n "${FAKE_SUBTYPE:-}" ]; then
  printf '{"type": "result", "subtype": "%s", "is_error": true, "num_turns": 11, "errors": ["Reached maximum number of turns (10)"], "total_cost_usd": 0.02}\n' "$FAKE_SUBTYPE"
  exit 0
fi
printf '{"type": "result", "subtype": "success", "is_error": false, "result": "D1: CONFIRMED — q1=a — artifact: src/a.sh:2\\nD2: UNCERTAIN — q1=b — artifact: none", "num_turns": 3, "total_cost_usd": 0.01}\n'
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

# rfp-u2e: a claude that reads standard input (the real one does) must not eat the remaining groups.
corp3="$tmp/corpus3.jsonl"
python3 - "$corp3" "$R" "$B" <<'PY'
import json, sys
out, R, B = sys.argv[1:4]
with open(out, 'w') as f:
    for n in (1, 2, 3):
        f.write(json.dumps({'id': 'h%d#%d' % (n, n), 'group': 'h%d' % n, 'reviewed': R, 'baseline': B, 'dline': 'D1: src/a.sh:2 x is unquoted'}) + '\n')
PY
pr4="$tmp/probe4"; mkdir -p "$pr4"
# rfp-u2f: run.sh's own stdin is a sentinel file, so a claude that is handed it records the sentinel and
# the case fails at once instead of hanging on an open pipe; timeout bounds it anyway.
printf 'SENTINEL\n' > "$tmp/stdin.sentinel"
PATH="$fb:$PATH" PROBE="$pr4" LABELS="$d/labels.tsv" FAKE_DRAIN=1 timeout 60 bash "$d/run.sh" --corpus "$corp3" --repo "$repo" --out "$tmp/r4.jsonl" <"$tmp/stdin.sentinel" >"$tmp/r4.out" 2>"$tmp/r4.err"; rc=$?
ids4="$(python3 -c 'import json, sys
print(",".join(json.loads(l)["id"] for l in open(sys.argv[1])))' "$tmp/r4.jsonl" 2>/dev/null)"
read4="$(cat "$pr4"/*/stdin 2>/dev/null)"
[ "$rc" = 0 ] && grep -q ' groups=3 ' "$tmp/r4.out" && [ "$ids4" = "h1#1,h2#2,h3#3" ] && [ "$(ls "$pr4" | wc -l)" = 3 ] \
  && [ "$(ls "$pr4"/*/stdin 2>/dev/null | wc -l)" = 3 ] && [ -z "$read4" ] \
  && ok "(q) a claude that drains standard input still sees all three groups and reads nothing" || bad "(q) rc=$rc ids=$ids4 read=$read4 $(tail -1 "$tmp/r4.out")"
[ "$(ls "$pr4"/*/fd3 2>/dev/null | wc -l)" = 0 ] && [ "$(ls "$pr4" | wc -l)" = 3 ] \
  && ok "(u) claude does not inherit run.sh's group stream on fd 3" || bad "(u) fd 3 open in $(ls "$pr4"/*/fd3 2>/dev/null | wc -l) runs"

# rfp-u2f: every row carries the CLI result's subtype and is_error; a run cut off at the turn cap is
# error_max_turns, and a row with no CLI result says none
sub="$(python3 -c 'import json, sys
for l in open(sys.argv[1]):
    r = json.loads(l); print(r["id"], r["answer"], r.get("subtype", "-"), r.get("is_error", "-"), r["num_turns"])' "$rep" 2>/dev/null | tr '\n' ',')"
pr5="$tmp/probe5"; mkdir -p "$pr5"
PATH="$fb:$PATH" PROBE="$pr5" LABELS="$d/labels.tsv" FAKE_SUBTYPE=error_max_turns bash "$d/run.sh" --corpus "$corp" --repo "$repo" --out "$tmp/r5.jsonl" >/dev/null 2>&1 </dev/null; rc=$?
sub5="$(python3 -c 'import json, sys
for l in open(sys.argv[1]):
    r = json.loads(l); print(r["id"], r["answer"], r.get("subtype", "-"), r.get("is_error", "-"), r["num_turns"])' "$tmp/r5.jsonl" 2>/dev/null | tr '\n' ',')"
[ "$sub" = "g1#0 CONFIRMED success False 3,g1#1 UNCERTAIN success False 3,g2#2 NONE none True 0,g3#3 NONE none True 0," ] \
  && [ "$rc" = 0 ] && [ "$sub5" = "g1#0 NONE error_max_turns True 11,g1#1 NONE error_max_turns True 11,g2#2 NONE none True 0,g3#3 NONE none True 0," ] \
  && ok "(r) report rows carry the CLI result's subtype and is_error" || bad "(r) rows: $sub / rc=$rc $sub5"

# rfp-u2f: run.sh is parsed whole before it runs, so rewriting it during a replay changes nothing
rr="$tmp/rr"; mkdir -p "$rr/eval/refutation-replay" "$rr/bin"
cp -p "$d/run.sh" "$d/guard.py" "$rr/eval/refutation-replay/"; cp -p "$root/bin/refutation-brief.sh" "$rr/bin/"
pr6="$tmp/probe6"; mkdir -p "$pr6"
PATH="$fb:$PATH" PROBE="$pr6" LABELS="$d/labels.tsv" FAKE_MUTATE="$rr/eval/refutation-replay/run.sh" timeout 60 bash "$rr/eval/refutation-replay/run.sh" --corpus "$corp3" --repo "$repo" --out "$tmp/r6.jsonl" >"$tmp/r6.out" 2>"$tmp/r6.err" </dev/null; rc=$?
[ "$rc" = 0 ] && [ -e "$rr/eval/refutation-replay/run.sh.done" ] && grep -q ' groups=3 ' "$tmp/r6.out" && [ "$(grep -c . "$tmp/r6.jsonl")" = 3 ] && [ ! -s "$tmp/r6.err" ] \
  && ok "(t) rewriting run.sh during a replay does not change the running replay" || bad "(t) rc=$rc $(tail -1 "$tmp/r6.out") $(head -c 200 "$tmp/r6.err")"

# ---- docs match the code (findings 3 and 5) ----
rules="$(grep -oE '"Bash\(git [a-z]+ \*\)"' "$d/run.sh" | sed -E 's/"Bash\(git ([a-z]+) \*\)"/`git \1`/' | paste -sd, - | sed 's/,\([^,]*\)$/ and \1/; s/,/, /g')"
[ -n "$rules" ] && grep -qF "Bash only as $rules" "$d/README.md" && ! grep -qF '`git`, `grep`' "$d/README.md" \
  && ok "(o) README names exactly run.sh's Bash rules ($rules)" || bad "(o) README does not say: Bash only as $rules"
cut="$(grep -oE "claim\[:[0-9]+\]" "$d/build-corpus.py" | grep -oE '[0-9]+')"
doc="$(python3 -c 'import ast, sys; print(" ".join(ast.get_docstring(ast.parse(open(sys.argv[1]).read())).split()))' "$d/build-corpus.py")"
[ -n "$cut" ] && printf '%s' "$doc" | grep -q "cut at $cut characters" && grep -q "cut at $cut characters" "$d/README.md" \
  && ! printf '%s' "$doc" | grep -qi diffstat \
  && ok "(p) the builder docstring and README state the $cut-character claim cut, and no diffstat" || bad "(p) cut=$cut"

# rfp-u2f: the README states the capped rule with the subtype score.py actually counts
st="$(grep -oE "r\.get\('subtype'\) == '[a-z_]+'" "$d/score.py" | grep -oE "'[a-z_]+'$" | tr -d "'")"
[ -n "$st" ] && grep -qF 'needs all five of the following' "$d/README.md" && grep -qF "(\`capped=0\`: no row's \`subtype\` is \`$st\`)" "$d/README.md" \
  && ok "(v) README states the capped rule with score.py's subtype ($st)" || bad "(v) README does not state capped=0 for subtype '$st'"

if [ "$fail" -eq 0 ]; then echo "All refutation-replay-isolation checks passed."; else echo "refutation-replay-isolation: FAILED"; fi
exit "$fail"
