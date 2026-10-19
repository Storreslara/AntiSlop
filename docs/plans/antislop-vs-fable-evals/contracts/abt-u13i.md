Unit: abt-u13i

## Objective
`run-matrix.sh` sets every file and directory under `eval/abtest/checks` and the fixtures directory to mode 000 just before each arm process starts and restores the recorded modes after the arm exits and before anything is scored, on every exit path (normal, timeout, failure, exit 75 and 76, SIGINT, SIGTERM, SIGHUP; a SIGKILLed runner is repaired at the next start), failing closed with exit 1 and a message naming the path. Both arms get 35 best-effort deny rules for chmod, chattr, setfacl, install, mv, cp and ln on the secret names, the canary probe prints `probe: canary-lock covered=yes restored=yes`, and the new `tests/abtest-lock.test.sh` (32 rows, registered in `tests/validate.sh`) pins all of it. No doc changes (abt-u13j writes OD-21 and the amendments).

## Retrieval
GitHub issues: `gh issue view 626 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/arms/common.sh` (anchor: line matching `# abtest_make_home DIR: a per-run HOME outside the harness with a neutral git identity and nothing else.`)
- `eval/abtest/run-matrix.sh` (anchor: line matching `MAX_LIMIT_HITS="${ABT_MAX_LIMIT_HITS:-3}"`)
- `tests/abtest-arms.test.sh` (anchor: line matching `check "the deny rules are the four rules for the harness root and nothing else"`)
- `tests/abtest-probe.test.sh` (anchor: line matching `case "\${CANARY_DENY:-none}" in *\$arm*) deny=1 ;; *) deny=0 ;; esac`)
- `tests/abtest-lock.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "== tests/abtest-score.test.sh: scorer and verdict rules (Bash, abt-u14) =="`)

## Ordered edits
1. command: `test -f eval/abtest/arms/common.sh && ! /usr/bin/grep -qF -e 'abtest_lock_secrets' eval/abtest/arms/common.sh && ! test -e tests/abtest-lock.test.sh && ! /usr/bin/grep -qF -e 'OD-21' docs/plans/antislop-vs-fable-evals/operator-decisions.md && test "$(id -u)" != 0`
   expect: 0

2. file: `eval/abtest/arms/common.sh`
   anchor: line matching `# abtest_make_home DIR: a per-run HOME outside the harness with a neutral git identity and nothing else.`
   indent: 0
   before:
~~~~
# abtest_make_home DIR: a per-run HOME outside the harness with a neutral git identity and nothing else.
~~~~
   after:
~~~~
# abtest_secret_paths: OD-21. The paths the lock covers, one per line: ABT_LOCK_PATHS (colon-separated) or else the
# checks directory and the fixtures directory (ABT_FIXTURES_DIR when set) of this checkout.
abtest_secret_paths() {
  local base q
  base="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
  if [ -n "${ABT_LOCK_PATHS:-}" ]; then
    local IFS=:
    for q in $ABT_LOCK_PATHS; do [ -z "$q" ] || realpath -m -- "$q"; done
  else
    printf '%s\n' "$base/checks" "$(realpath -m -- "${ABT_FIXTURES_DIR:-$base/fixtures}")"
  fi
}

# abtest_lock_secrets STATE: OD-21. Record every mode under the secret paths in the manifest STATE (path, tab, mode,
# NUL), then set each to 000, children first. The lock is on the inode, so an alias path is denied too. Fails closed and
# names the path (root, a stale manifest, a missing directory, a failed chmod, a root still listable); the caller then
# runs abtest_unlock_secrets.
abtest_lock_secrets() {
  local state="$1" root p m
  local -a roots
  if [ "$(id -u)" = 0 ]; then echo "abtest: the secrets lock does not hold for root; run as a normal user" >&2; return 1; fi
  if [ -e "$state" ]; then echo "abtest: $state holds an unrestored lock; restore it first" >&2; return 1; fi
  mapfile -t roots < <(abtest_secret_paths)
  for root in "${roots[@]}"; do
    [ -d "$root" ] || { echo "abtest: cannot lock $root: it is not a directory" >&2; return 1; }
  done
  mkdir -p -- "$(dirname -- "$state")" || return 1
  for root in "${roots[@]}"; do
    find "$root" -not -type l -printf '%p\t%m\0' >> "$state" || { echo "abtest: cannot list $root" >&2; return 1; }
  done
  while IFS=$'\t' read -r -d '' p m; do
    chmod 000 -- "$p" || { echo "abtest: cannot lock $p" >&2; return 1; }
  done < <(LC_ALL=C sort -z -r "$state")
  for root in "${roots[@]}"; do
    if ls -- "$root" > /dev/null 2>&1; then echo "abtest: $root is still listable after the lock" >&2; return 1; fi
  done
}

# abtest_make_home DIR: a per-run HOME outside the harness with a neutral git identity and nothing else.
~~~~

3. file: `eval/abtest/arms/common.sh`
   anchor: line matching `# abtest_make_home DIR: a per-run HOME outside the harness with a neutral git identity and nothing else.`
   indent: 0
   before:
~~~~
# abtest_make_home DIR: a per-run HOME outside the harness with a neutral git identity and nothing else.
~~~~
   after:
~~~~
# abtest_unlock_secrets STATE: OD-21. Restore every mode the manifest STATE records, parents first, then remove it; a
# no-op without STATE. A mode that cannot be restored is named, the rest are still restored, STATE is kept, return 1.
abtest_unlock_secrets() {
  local state="$1" p m rc=0
  [ -e "$state" ] || return 0
  while IFS=$'\t' read -r -d '' p m; do
    chmod "$m" -- "$p" 2> /dev/null || { echo "abtest: cannot restore mode $m of $p; the manifest $state is kept" >&2; rc=1; }
  done < <(LC_ALL=C sort -z "$state")
  [ "$rc" -eq 0 ] && rm -f -- "$state"
  return "$rc"
}

# abtest_make_home DIR: a per-run HOME outside the harness with a neutral git identity and nothing else.
~~~~

4. file: `eval/abtest/arms/common.sh`
   anchor: line matching `    for q in ${ABTEST_DENY_PATHS:-}; do [ -z "$q" ] || realpath -m -- "$q"; done`
   indent: 0
   before:
~~~~
    for q in ${ABTEST_DENY_PATHS:-}; do [ -z "$q" ] || realpath -m -- "$q"; done
  )
~~~~
   after:
~~~~
    for q in ${ABTEST_DENY_PATHS:-}; do [ -z "$q" ] || realpath -m -- "$q"; done
  )
  # OD-21, best effort: the arm may not undo the lock by name. A path built in a variable still gets through, which is why
  # the canary probe stays the check.
  local m n
  for m in chmod chattr setfacl install mv cp ln; do
    for n in abtest/checks abtest/fixtures holdout reference.patch canary-; do
      printf '%s\n' "Bash($m *$n*)"
    done
  done
~~~~

5. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `MAX_LIMIT_HITS="${ABT_MAX_LIMIT_HITS:-3}"`
   indent: 0
   insert-after:
~~~~
SECRETS_STATE="$WORK/.secrets-lock.manifest"
~~~~

6. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `  setsid -w timeout -k "${ABT_KILL_AFTER_S:-30}s" "${outer}s" "$@" > "$out" 2>> "$err" &`
   indent: 0
   before:
~~~~
  setsid -w timeout -k "${ABT_KILL_AFTER_S:-30}s" "${outer}s" "$@" > "$out" 2>> "$err" &
  ARM_SID=$!
  wait "$ARM_SID" || grc=$?
  reap_arm
  return "$grc"
~~~~
   after:
~~~~
  abtest_lock_secrets "$SECRETS_STATE" || { release_secrets; echo "run-matrix: the secrets lock failed (OD-21); no arm was started" >&2; exit 1; }
  setsid -w timeout -k "${ABT_KILL_AFTER_S:-30}s" "${outer}s" "$@" > "$out" 2>> "$err" &
  ARM_SID=$!
  wait "$ARM_SID" || grc=$?
  reap_arm
  release_secrets || exit 1
  return "$grc"
~~~~

7. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `release_lock() {`
   indent: 0
   before:
~~~~
# release_lock: remove the lock directory this runner took.
release_lock() {
  if [ -n "$LOCK_DIR" ]; then rm -rf "$LOCK_DIR"; fi
  LOCK_DIR=""
  return 0
}
~~~~
   after:
~~~~
# release_secrets: OD-21. Restore the modes the lock recorded; a no-op when no lock stands. Returns 1 on a failed restore.
release_secrets() {
  abtest_unlock_secrets "$SECRETS_STATE" || { echo "run-matrix: the secrets lock was not restored; fix the modes named above, then run again" >&2; return 1; }
}

# release_lock: restore the secrets, then remove the lock directory this runner took.
release_lock() {
  local src=0
  release_secrets || src=1
  if [ -n "$LOCK_DIR" ]; then rm -rf "$LOCK_DIR"; fi
  LOCK_DIR=""
  return "$src"
}
~~~~

8. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `  printf '%s\n' "$$" > "$lock/pid"`
   indent: 0
   insert-after:
~~~~
  if [ -e "$SECRETS_STATE" ]; then
    echo "run-matrix: restoring the modes recorded in the stale $SECRETS_STATE (a runner was killed mid-run)" >&2
    release_secrets || exit 1
  fi
~~~~

9. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `trap release_lock EXIT`
   indent: 0
   before:
~~~~
trap release_lock EXIT
~~~~
   after:
~~~~
trap 'release_lock || exit 1' EXIT
~~~~

10. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `  trap 'rm -f "${CANARY_FILES[@]}"; release_lock' EXIT`
   indent: 0
   before:
~~~~
  trap 'rm -f "${CANARY_FILES[@]}"; release_lock' EXIT
~~~~
   after:
~~~~
  trap 'release_secrets; rm -f "${CANARY_FILES[@]}"; release_lock || exit 1' EXIT
~~~~

11. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `  cctl=""`
   indent: 0
   insert-after:
~~~~
  mapfile -t SECRET_ROOTS < <(abtest_secret_paths)
  clock=""
  for cf in "${CANARY_FILES[@]}"; do
    cov=no
    for sp in "${SECRET_ROOTS[@]}"; do
      case "$(realpath -m -- "$cf")/" in "$sp"/*) cov=yes ;; esac
    done
    [ "$cov" = yes ] || { clock="$clock uncovered:$cf"; crc=1; }
    [ -r "$cf" ] || { clock="$clock unrestored:$cf"; crc=1; }
  done
  echo "probe: canary-lock${clock:- covered=yes restored=yes}"
~~~~

12. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `    [ -f "$fx/arm-b.overrides.json" ] && ov=("$fx/arm-b.overrides.json")`
   indent: 0
   before:
~~~~
    [ -f "$fx/arm-b.overrides.json" ] && ov=("$fx/arm-b.overrides.json")
~~~~
   after:
~~~~
    if [ -f "$fx/arm-b.overrides.json" ]; then
      cp "$fx/arm-b.overrides.json" "$wdir/arm-b.overrides.json" || internal "$run_id" "overrides copy"
      ov=("$wdir/arm-b.overrides.json")
    fi
~~~~

13. file: `tests/abtest-arms.test.sh`
   anchor: line matching `check "the deny rules are the four rules for the harness root and nothing else"`
   indent: 0
   before:
~~~~
check "the deny rules are the four rules for the harness root and nothing else" "$(grep -vxF -e "Read(/$REPO_PHYS)" -e "Read(/$REPO_PHYS/**)" -e "Edit(/$REPO_PHYS/**)" -e "Bash(*$REPO_PHYS*)" "$T/denyA" | wc -l | tr -d ' ')|$(wc -l < "$T/denyA" | tr -d ' ')" "0|4"
~~~~
   after:
~~~~
check "the deny rules are the four rules for the harness root and the 35 lock-guard rules of OD-21, nothing else" "$(grep -vxF -e "Read(/$REPO_PHYS)" -e "Read(/$REPO_PHYS/**)" -e "Edit(/$REPO_PHYS/**)" -e "Bash(*$REPO_PHYS*)" "$T/denyA" | grep -vcE '^Bash\((chmod|chattr|setfacl|install|mv|cp|ln) \*(abtest/checks|abtest/fixtures|holdout|reference\.patch|canary-)\*\)$')|$(wc -l < "$T/denyA" | tr -d ' ')" "0|39"
~~~~

14. file: `tests/abtest-probe.test.sh`
   anchor: line matching `case "\${CANARY_DENY:-none}" in *\$arm*) deny=1 ;; *) deny=0 ;; esac`
   indent: 0
   insert-after:
~~~~
[ -n "\$leak" ] && chmod -R u+rwx "$REPO_ROOT/eval/abtest/checks" "$REPO_ROOT/eval/abtest/fixtures" 2> /dev/null
~~~~

15. file: `tests/abtest-probe.test.sh`
   anchor: line matching `has "no arm found the canary" "$out" "probe: canary A=not-found B=not-found"`
   indent: 0
   insert-after:
~~~~
has "the probe reports the canary files covered by the lock and restored (OD-21)" "$out" "probe: canary-lock covered=yes restored=yes"
~~~~

16. file: `tests/abtest-lock.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
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
check "the default lock covers the checks and fixtures directories of this checkout" "$( unset ABT_FIXTURES_DIR ABT_LOCK_PATHS; abtest_secret_paths | paste -sd' ' )" "$REPO_ROOT/eval/abtest/checks $REPO_ROOT/eval/abtest/fixtures"
check "ABT_LOCK_PATHS replaces the default" "$(ABT_LOCK_PATHS="$SEC:$T/x" abtest_secret_paths | paste -sd' ')" "$SEC $T/x"
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
~~~~

17. file: `tests/abtest-lock.test.sh`
   anchor: line matching `check "the restore after a half-applied lock brings every mode back" "$(modes | msum)" "$BS"`
   indent: 0
   insert-after:
~~~~
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
~~~~

18. file: `tests/validate.sh`
   anchor: line matching `echo "== tests/abtest-score.test.sh: scorer and verdict rules (Bash, abt-u14) =="`
   indent: 0
   before:
~~~~
echo "== tests/abtest-score.test.sh: scorer and verdict rules (Bash, abt-u14) =="
~~~~
   after:
~~~~
echo "== tests/abtest-lock.test.sh: the secrets lock and its restore on every exit path (Bash, abt-u13i) =="
if bash tests/abtest-lock.test.sh > /dev/null; then
  echo "OK   tests/abtest-lock.test.sh"
else
  echo "FAIL tests/abtest-lock.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-score.test.sh: scorer and verdict rules (Bash, abt-u14) =="
~~~~

19. command: `chmod +x tests/abtest-lock.test.sh`
   expect: 0

20. command: `git add tests/abtest-lock.test.sh`
   expect: 0

21. command: `git commit -m "feat(abt-u13i): the answer key is unreadable to the arm while it runs, restored on every exit path (OD-21) (#626)" -- eval/abtest/arms/common.sh eval/abtest/run-matrix.sh tests/abtest-lock.test.sh tests/abtest-arms.test.sh tests/abtest-probe.test.sh tests/validate.sh`
   expect: 0
   trailers: before running it, add one more `-m` argument for the Co-Authored-By trailer and one for the Claude-Session trailer, both taken from the session attribution; the paths after `--` stay explicit, and the only `git add` is the new test file of the previous edit.

## Do NOT touch
- `hooks/`, `eval/abtest/lib/stream.py`, `eval/abtest/score.py`, `eval/abtest/arms/arm-a.sh`, `eval/abtest/arms/arm-b.sh` (unchanged)
- `eval/abtest/checks/`, `eval/abtest/fixtures/` (the answer key: content, names and modes stay as committed)
- `tests/fixtures/abtest/` and every other `tests/abtest-*.test.sh` (unchanged)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md`, `docs/experiments/abtest-2026-10.md`, `eval/abtest/README.md` (abt-u13j writes the prose)
- `eval/abtest/results.jsonl`, `eval/abtest/results.superseded.jsonl`, `eval/abtest/.runs/` (run output)
- `bin/cli.js`, `CHANGELOG.md`, `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no version bump)

## Acceptance criteria
1. run: `set -o pipefail; bash tests/abtest-lock.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-lock checks passed.`
   mutation: skip edit 6; exit 4, stdout `abtest-lock: 28 passed, 4 failed`.

2. run: `bash tests/abtest-lock.test.sh | /usr/bin/grep -c '^ok'`
   exit: 0
   stdout: `32`
   mutation: skip edit 7; exit 0, stdout `20`.

3. run: `set -o pipefail; bash tests/abtest-arms.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-arms checks passed.`
   mutation: skip edit 13; exit 1, stdout `abtest-arms: 98 passed, 1 failed`.

4. run: `set -o pipefail; bash tests/abtest-probe.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-probe checks passed.`
   mutation: skip edit 14; exit 13, stdout `abtest-probe: 105 passed, 13 failed`.

5. run: `bash tests/abtest-probe.test.sh | /usr/bin/grep -c '^ok'`
   exit: 0
   stdout: `118`
   mutation: skip edit 15; exit 0, stdout `117`.

6. run: `for f in tests/abtest-*.test.sh; do bash "$f" > /dev/null 2>&1 || echo "$f"; done | wc -l | tr -d ' '`
   exit: 0
   stdout: `0`
   mutation: skip edit 12; exit 0, stdout `1`.

7. run: `/usr/bin/grep -cF 'abtest_lock_secrets "$SECRETS_STATE"' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; exit 1, stdout `0`.

8. run: `/usr/bin/grep -cF -e "trap 'release_lock || exit 1' EXIT" eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 9; exit 1, stdout `0`.

9. run: `/usr/bin/grep -cF 'probe: canary-lock' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 11; exit 1, stdout `0`.

10. run: `bash -c '. eval/abtest/arms/common.sh; abtest_deny_flags | /usr/bin/grep -cE "^Bash\((chmod|chattr|setfacl|install|mv|cp|ln) "'`
   exit: 0
   stdout: `35`
   mutation: skip edit 4; exit 1, stdout `0`.

11. run: `/usr/bin/grep -cF 'bash tests/abtest-lock.test.sh > /dev/null' tests/validate.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 18; exit 1, stdout `0`.

12. run: `find eval/abtest/checks eval/abtest/fixtures -perm 000 | wc -l | tr -d ' '`
   exit: 0
   stdout: `0`
   mutation: set `eval/abtest/checks/lib.sh` to mode 000; exit 0, stdout `1`.
   proof: scratch worktree with the unit applied, `chmod 000 eval/abtest/checks/lib.sh`, then the run: command there

13. run: `/usr/bin/grep -cE '^[^#"]*(^|[ ;|&(])claude( |$)' tests/abtest-lock.test.sh`
   exit: 1
   stdout: `0`
   mutation: append the line `claude -p hi` to tests/abtest-lock.test.sh; exit 0, stdout `1`.
   proof: scratch worktree with the unit applied, append that line, then the run: command there

14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13i\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/arms/common.sh eval/abtest/run-matrix.sh tests/abtest-arms.test.sh tests/abtest-lock.test.sh tests/abtest-probe.test.sh tests/validate.sh`
   mutation: skip edit 21 (the commit); exit 3, stdout `no-unit-commit`.

15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13i\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 21 (the commit); exit 3, stdout `no-unit-commit`.

16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13i\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/arms/common.sh eval/abtest/run-matrix.sh tests/abtest-lock.test.sh tests/abtest-arms.test.sh tests/abtest-probe.test.sh tests/validate.sh | grep -vcE "^[a-z]+\(abt-u13i\): "`
   exit: 1
   stdout: `0`
   mutation: skip edit 21 (the commit); a later commit `docs: tail` touching eval/abtest/arms/common.sh without the unit scope prints 1; before the commit, exit 3, stdout `no-unit-commit`.

## Pre-resolved context
tdd: yes tests/abtest-lock.test.sh (criteria 1, 2, 5, 7 to 11 and 13 are red at HEAD; see green-at-HEAD)
blast-radius: eval/abtest/run-matrix.sh:235 eval/abtest/run-matrix.sh:246 eval/abtest/run-matrix.sh:255 eval/abtest/run-matrix.sh:284 eval/abtest/run-matrix.sh:308 eval/abtest/run-matrix.sh:312 eval/abtest/run-matrix.sh:399 eval/abtest/run-matrix.sh:427 eval/abtest/run-matrix.sh:457 eval/abtest/arms/common.sh:45 eval/abtest/arms/common.sh:67 eval/abtest/arms/arm-b.sh:87 tests/abtest-arms.test.sh:179 tests/abtest-probe.test.sh:170 tests/validate.sh:1471 (grep-derived; run_guarded is the one place every arm process starts, so one lock there covers a run, the isolation probe and the canary probe; arm-b.sh reads the fixture's arm-b.overrides.json inside the arm, which the lock would deny, so edit 12 copies it into the work directory first)
payload-indent: every fenced payload starts at column 0 of the contract file, keeps its own leading spaces and states indent: 0; empty payload lines stay empty.
test-hazard: the suites lock this checkout's own eval/abtest/checks and fixtures (mode 000) while a fake claude runs. Run them one at a time. If a run is killed and a directory stays locked, STOP and report the path; do not chmod -R.
decision: no SPEC-GAP. Operator decision 2026-10-19, option 1 (OD-21, written by abt-u13j). The lock is taken in run_guarded and restored there and in the EXIT trap (on_signal exits, so signals restore too); SIGKILL cannot be trapped, so acquire_lock restores a leftover manifest first. ABT_LOCK_PATHS lets the suites lock a temp tree. The 35 deny rules (7 commands x 5 names) are best effort. Committing this unit moves harness_commit, so every earlier row is superseded (done_run, OD-14).
green-at-HEAD: criteria 3, 4, 6 and 12 already pass before the edits (3 and 4 are regression guards, 6 is the full sweep and prints 0 at HEAD and after, 12 is a guard); criteria 14 to 16 print no-unit-commit with exit 3 until edit 21 runs. Run criterion 6 alone, in the foreground (about six minutes): a backgrounded shell ignores SIGINT and the SIGINT row of abtest-runner then hangs, at HEAD too.
not-stamped: no agents/*.md or templates/ file is touched; no version bump.
commit-message: feat(abt-u13i): the answer key is unreadable to the arm while it runs, restored on every exit path (OD-21) (#626)
trailers: use the Co-Authored-By and Claude-Session trailers from the session attribution (criterion 15 greps the Co-Authored-By line)
diagnosis: none
review-packet:
~~~
unit: abt-u13i (#626)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
