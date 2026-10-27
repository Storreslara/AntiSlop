#!/usr/bin/env bash
# Tests the secrets lock of eval/abtest (OD-21) with a fake claude: no network, no real claude.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="$REPO_ROOT/eval/abtest/run-matrix.sh"
FX="$REPO_ROOT/tests/fixtures/abtest"
T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }
T="$(cd "$T" && pwd -P)"
MAN="$T/work/.secrets-lock.manifest"
trap '[ -e "$MAN" ] && ( . "$REPO_ROOT/eval/abtest/arms/common.sh"; abtest_unlock_secrets "$MAN" ); chmod -R u+rwx "$T/sec" 2> /dev/null; rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing '$3')" ;; esac; }

export HOME="$T/home"
mkdir -p "$HOME/.claude"
printf '{}\n' > "$HOME/.claude/.credentials.json"
export ABTEST_CLAUDE="$FX/fake-claude.sh" FAKE_CLAUDE_LOG="$T/flog"
export ABT_RESULTS="$T/results.jsonl" ABT_RUNS="$T/runs" ABT_WORK="$T/work"
E=e01-ambiguous-tax
SEC="$T/sec"
mkdir -p "$SEC/sub" "$SEC/exe"
printf 'SECRET-TOKEN\n' > "$SEC/sub/a.txt"
printf '#!/bin/sh\n' > "$SEC/exe/run.sh"
chmod 640 "$SEC/sub/a.txt"
chmod 755 "$SEC/exe/run.sh"
chmod 750 "$SEC/sub"
ln -s "$SEC" "$T/alias"
export ABT_LOCK_PATHS="$SEC"
modes() { find "$SEC" -printf '%m %p\n' | sort; }
BEFORE="$(modes)"
msum() { md5sum | cut -d' ' -f1; }
BS="$(printf '%s\n' "$BEFORE" | msum)"
fresh() { rm -rf "$ABT_RESULTS" "$ABT_RUNS" "$ABT_WORK" "$T/flog"; }
. "$REPO_ROOT/eval/abtest/arms/common.sh"

# --- the lock functions ---
check "the default lock covers the checks and fixtures directories of this checkout" "$( unset ABT_FIXTURES_DIR ABT_LOCK_PATHS; abtest_secret_paths | paste -sd' ' - )" "$REPO_ROOT/eval/abtest/checks $REPO_ROOT/eval/abtest/fixtures"
check "ABT_LOCK_PATHS replaces the default" "$(ABT_LOCK_PATHS="$SEC:$T/x" abtest_secret_paths | paste -sd' ' -)" "$SEC $T/x"
abtest_lock_secrets "$MAN"; rc=$?
check "the lock applies" "$rc|$(stat -c %a "$SEC")|$(test -s "$MAN" && echo manifest)" "0|0|manifest"
check "a read of a locked file is permission denied" "$(cat "$SEC/sub/a.txt" 2>&1 | grep -c 'Permission denied')" "1"
check "a listing of a locked directory fails" "$(ls "$SEC" > /dev/null 2>&1; echo $?)" "2"
check "a read through a symlink alias is permission denied" "$(cat "$T/alias/sub/a.txt" 2>&1 | grep -c 'Permission denied')" "1"
check "a read through find and xargs is permission denied" "$(printf '%s\0' "$T/alias/sub/a.txt" | xargs -0 grep -H SECRET 2>&1 | grep -c 'Permission denied')" "1"
W="/mnt/wslg/distro$SEC"
if [ -d "$W" ]; then
  check "the /mnt/wslg alias of a locked directory is permission denied" "$(cat "$W/sub/a.txt" 2>&1 | grep -c 'Permission denied')" "1"
else
  ok "no /mnt/wslg alias on this host; the symlink alias above stands in for it"
fi
abtest_lock_secrets "$MAN" 2> "$T/again.err"; rc=$?
check "a second lock while a manifest stands is refused" "$rc|$(grep -c 'unrestored lock' "$T/again.err")" "1|1"
abtest_unlock_secrets "$MAN"; rc=$?
check "the restore succeeds and removes the manifest" "$rc|$(test -e "$MAN" && echo left || echo gone)" "0|gone"
check "every mode is back" "$(modes | msum)" "$BS"
check "a locked file is readable again" "$(cat "$SEC/sub/a.txt")" "SECRET-TOKEN"
mkdir -p "$T/work"
out="$(ABT_LOCK_PATHS="$SEC:$T/missing" abtest_lock_secrets "$MAN" 2>&1)"; rc=$?
check "a lock over a missing path fails and names it" "$rc|$(printf '%s' "$out" | grep -cF "$T/missing")|$(test -e "$MAN" && echo left || echo gone)" "1|1|gone"
mkdir -p "$T/shim"
printf '#!/bin/sh\ncase "$*" in *"/sub") exit 1 ;; esac\nexec /bin/chmod "$@"\n' > "$T/shim/chmod"
chmod 755 "$T/shim/chmod"
out="$(PATH="$T/shim:$PATH" abtest_lock_secrets "$MAN" 2>&1)"; rc=$?
check "a chmod that fails stops the lock and names the path" "$rc|$(printf '%s' "$out" | grep -cF "cannot lock $SEC/sub")" "1|1"
abtest_unlock_secrets "$MAN"
check "the restore after a half-applied lock brings every mode back" "$(modes | msum)" "$BS"
abtest_lock_secrets "$MAN"
printf '%s\t%s\0' "$T/gone" 755 >> "$MAN"
out="$(abtest_unlock_secrets "$MAN" 2>&1)"; rc=$?
check "a restore that fails names the path, returns 1 and keeps the manifest" "$rc|$(printf '%s' "$out" | grep -cF "$T/gone")|$(test -e "$MAN" && echo kept || echo gone)" "1|1|kept"
check "the other modes were still restored" "$(modes | msum)" "$BS"
rm -f "$MAN"
check "the deny rules refuse chmod, chattr, setfacl, install, mv, cp and ln on the secret names (35 rules)" "$(abtest_deny_flags | grep -cE '^Bash\((chmod|chattr|setfacl|install|mv|cp|ln) \*(abtest/checks|abtest/fixtures|holdout|reference\.patch|canary-)\*\)$')" "35"

# --- the runner ---
fresh
FAKE_CLAUDE_READ="$T/alias/sub/a.txt" bash "$RUN" --pilot --evals $E > "$T/o1.txt" 2> "$T/e1.txt"; rc=$?
S1="$ABT_RUNS/${E}_A_uniform_1/stream.jsonl"
S2="$ABT_RUNS/${E}_B_uniform_1/stream.jsonl"
check "a pilot with a lock exits 0" "$rc" "0"
check "a simulated arm that reads the secret through the alias gets unreadable, in both arms" "$(grep -c unreadable "$S1")|$(grep -c unreadable "$S2")|$(cat "$S1" "$S2" | grep -c SECRET-TOKEN)" "1|1|0"
check "the modes are restored after a normal exit" "$(modes | msum)|$(test -e "$MAN" && echo left || echo gone)" "$BS|gone"
fresh
export ABT_LOCK_PATHS="$SEC:$REPO_ROOT/eval/abtest/checks"
bash "$RUN" --pilot --evals $E > /dev/null 2>&1; rc=$?
check "with the real checks directory locked, the run still scores after the restore" "$rc|$(python3 -I "$REPO_ROOT/eval/abtest/score.py" "$ABT_RESULTS" --validate-rows | tail -n 1)|$(find "$REPO_ROOT/eval/abtest/checks" -perm 000 | wc -l | tr -d ' ')" "0|rows ok: 2|0"
export ABT_LOCK_PATHS="$SEC"
fresh
TIMEOUT_MIN=0.02 FAKE_CLAUDE_SLEEP=5 bash "$RUN" --pilot --evals $E > /dev/null 2>&1
check "the modes are restored after a timeout" "$(modes | msum)|$(test -e "$MAN" && echo left || echo gone)|$(python3 -I -c 'import json,sys;print(json.loads(open(sys.argv[1]).readline())["completion_status"])' "$ABT_RESULTS")" "$BS|gone|timeout"
fresh
FAKE_CLAUDE_EXIT=3 bash "$RUN" --pilot --evals $E > /dev/null 2>&1
check "the modes are restored after an arm that fails" "$(modes | msum)|$(test -e "$MAN" && echo left || echo gone)" "$BS|gone"
fresh
FAKE_CLAUDE_STREAM="$FX/streams/limit-text.jsonl" FAKE_CLAUDE_EXIT=1 bash "$RUN" --pilot --evals $E > /dev/null 2>&1; rc=$?
check "the modes are restored after a usage-limit exit 75" "$rc|$(modes | msum)|$(test -e "$MAN" && echo left || echo gone)" "75|$BS|gone"
fresh
FAKE_CLAUDE_SLEEP=20 bash "$RUN" --pilot --evals $E > /dev/null 2>&1 &
RP=$!
for _ in $(seq 1 100); do [ -e "$T/flog/argv.1" ] && break; sleep 0.1; done
check "the lock stands while the arm runs" "$(stat -c %a "$SEC")" "0"
kill -TERM "$RP"
wait "$RP"; rc=$?
check "the modes are restored after a SIGTERM and the runner exits 143" "$rc|$(modes | msum)|$(test -e "$MAN" && echo left || echo gone)" "143|$BS|gone"
fresh
mkdir -p "$T/work"
abtest_lock_secrets "$MAN"
bash "$RUN" --pilot --evals $E > /dev/null 2> "$T/e2.txt"; rc=$?
check "a stale manifest from a killed runner is restored before the next run" "$rc|$(grep -c 'stale' "$T/e2.txt")|$(modes | msum)|$(test -e "$MAN" && echo left || echo gone)" "0|1|$BS|gone"
fresh
ABT_LOCK_PATHS="$SEC:$T/missing" bash "$RUN" --pilot --evals $E > /dev/null 2> "$T/e3.txt"; rc=$?
check "a lock that cannot be taken aborts the run, names the path and starts no arm" "$rc|$(grep -cF "$T/missing" "$T/e3.txt")|$(test -e "$T/flog" && echo started || echo none)" "1|1|none"

# --- the canary probe ---
unset ABT_LOCK_PATHS
fresh
CKD="$REPO_ROOT/eval/abtest/checks"
FXD="$REPO_ROOT/eval/abtest/fixtures"
RB="$(find "$CKD" "$FXD" -printf '%m %p\n' | sort | msum)"
FAKE_CLAUDE_READ="$CKD/e01-ambiguous-tax/canary-holdout.txt" bash "$RUN" --probe-canary > "$T/o4.txt" 2> /dev/null
SA="$ABT_RUNS/probe-canary/A/stream.jsonl"
has "the probe reports the canary files covered by the lock and restored" "$(cat "$T/o4.txt")" "probe: canary-lock covered=yes restored=yes"
check "the canary file is unreadable to both probe arms and the token is in neither stream" "$(grep -c unreadable "$SA")|$(grep -c unreadable "$ABT_RUNS/probe-canary/B/stream.jsonl")|$(cat "$SA" "$ABT_RUNS/probe-canary/B/stream.jsonl" | grep -c 'ABT-CANARY-')" "1|1|0"
check "the checks and fixtures modes are unchanged after the probe and the canary files are gone" "$(find "$CKD" "$FXD" -printf '%m %p\n' | sort | msum)|$(test -e "$CKD/e01-ambiguous-tax/canary-holdout.txt" && echo left || echo gone)" "$RB|gone"

echo "abtest-lock: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-lock checks passed."
exit "$fail"
