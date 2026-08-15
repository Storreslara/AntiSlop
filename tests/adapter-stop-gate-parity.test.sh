#!/usr/bin/env bash
# Behavioural parity guard for the three stop-gate ports (issue #202). Each
# port's header claims its ordered decision logic is identical to the main
# hook, differing only in payload field extraction, loop guard and dot-dir -
# nothing checked that claim, so the defer: dedupe drifted. This drives all
# three scripts through the same defer: scenarios via each port's own payload
# shape and asserts the same observable outcome (audit records + exit code).
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

PORTS="claude codex cursor"

script_for() {
  case "$1" in
    claude) echo hooks/scripts/stop-gate.sh ;;
    codex)  echo adapters/codex/hooks/scripts/stop-gate.sh ;;
    cursor) echo adapters/cursor/hooks/scripts/stop-gate.sh ;;
  esac
}

dotdir_for() {
  case "$1" in
    claude) echo .claude ;;
    codex)  echo .codex ;;
    cursor) echo .cursor ;;
  esac
}

make_project() {
  # $1 = port, $2 = case name -> echoes a fresh project dir with that port's config
  local dot dir
  dot="$(dotdir_for "$1")"
  dir="$tmproot/$1-$2"
  mkdir -p "$dir/$dot/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
    > "$dir/$dot/persona-config.json"
  echo "$dir"
}

run_stop() {
  # $1 = port, $2 = project dir, $3 = script (default: that port's real script).
  # The three ports name the project dir differently - env var, .cwd,
  # .workspace_roots[0] - and cursor downcases the event name.
  local port="$1" dir="$2" script rc=0
  script="${3:-$(script_for "$port")}"
  case "$port" in
    claude)
      printf '%s' '{"hook_event_name":"Stop","session_id":"main"}' \
        | CLAUDE_PROJECT_DIR="$dir" bash "$script" || rc=$?
      ;;
    codex)
      printf '{"hook_event_name":"Stop","session_id":"main","cwd":"%s"}' "$dir" \
        | bash "$script" || rc=$?
      ;;
    cursor)
      printf '{"hook_event_name":"stop","conversation_id":"main","workspace_roots":["%s"]}' "$dir" \
        | bash "$script" || rc=$?
      ;;
  esac
  return "$rc"
}

run_gated_stop() {
  # $1 = port, $2 = project dir, $3 = script (default: that port's real script), $4 = agent (default: lead-programmer).
  # Runs a gated SubagentStop event to create a pending-review flag.
  local port="$1" dir="$2" script agent rc=0
  script="${3:-$(script_for "$port")}"
  agent="${4:-lead-programmer}"
  case "$port" in
    claude)
      printf '%s' "{\"hook_event_name\":\"SubagentStop\",\"agent_type\":\"$agent\",\"session_id\":\"main\"}" \
        | CLAUDE_PROJECT_DIR="$dir" bash "$script" || rc=$?
      ;;
    codex)
      printf '{\"hook_event_name\":\"SubagentStop\",\"agent_type\":\"%s\",\"agent_id\":\"agent-1\",\"session_id\":\"main\",\"cwd\":\"%s\"}' "$agent" "$dir" \
        | bash "$script" || rc=$?
      ;;
    cursor)
      printf '{\"hook_event_name\":\"subagentStop\",\"subagent_type\":\"%s\",\"conversation_id\":\"main\",\"workspace_roots\":[\"%s\"]}' "$agent" "$dir" \
        | bash "$script" || rc=$?
      ;;
  esac
  return "$rc"
}

run_reviewer_stop() {
  # $1 = port, $2 = project dir, $3 = script (default: that port's real script).
  # Runs a reviewer SubagentStop event to test the marker-coupling check.
  local port="$1" dir="$2" script rc=0
  script="${3:-$(script_for "$port")}"
  case "$port" in
    claude)
      printf '%s' '{"hook_event_name":"SubagentStop","agent_type":"reviewer","session_id":"main"}' \
        | CLAUDE_PROJECT_DIR="$dir" bash "$script" || rc=$?
      ;;
    codex)
      printf '{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"reviewer-1","session_id":"main","cwd":"%s"}' "$dir" \
        | bash "$script" || rc=$?
      ;;
    cursor)
      printf '{"hook_event_name":"subagentStop","subagent_type":"reviewer","conversation_id":"main","workspace_roots":["%s"]}' "$dir" \
        | bash "$script" || rc=$?
      ;;
  esac
  return "$rc"
}

records() {
  # $1 = project dir, $2 = port, $3 = pattern. A missing log file means zero.
  local n
  n="$(grep -c "$3" "$1/$(dotdir_for "$2")/review-audit.log" 2>/dev/null || true)"
  echo "${n:-0}"
}

# (a) one single-line defer: write permits three Stops and logs exactly one record
for port in $PORTS; do
  dir="$(make_project "$port" single)"
  printf 'defer: reviewer already dispatched\n' \
    > "$dir/$(dotdir_for "$port")/.pending-review.lp-1"
  ok=true
  for _ in 1 2 3; do
    run_stop "$port" "$dir" || ok=false
  done
  n="$(records "$dir" "$port" 'defer: ')"
  if [ "$ok" = true ] && [ "$n" = 1 ]; then
    echo "OK   (a) $port: three Stops with an unchanged single-line defer: log exactly one record"
  else
    echo "FAIL (a) $port: expected one defer: record from three exit-0 Stops (ok=$ok records=$n)"
    fail=1
  fi
done

# (b) same for a MULTI-LINE reason: flattened to one logical line, so it still
#     dedupes and the log stays one record on one line
for port in $PORTS; do
  dir="$(make_project "$port" multiline)"
  printf 'defer: reviewer dispatched\nsee issue 202 for the reason\n' \
    > "$dir/$(dotdir_for "$port")/.pending-review.lp-1"
  ok=true
  for _ in 1 2 3; do
    run_stop "$port" "$dir" || ok=false
  done
  n="$(records "$dir" "$port" 'defer: ')"
  lines="$(wc -l < "$dir/$(dotdir_for "$port")/review-audit.log" 2>/dev/null || echo 0)"
  if [ "$ok" = true ] && [ "$n" = 1 ] && [ "$lines" = 1 ]; then
    echo "OK   (b) $port: three Stops with an unchanged multi-line defer: log one one-line record"
  else
    echo "FAIL (b) $port: expected one single-line defer: record (ok=$ok records=$n log-lines=$lines)"
    fail=1
  fi
done

# (c) a CHANGED reason is still recorded: defer: A -> Stop -> defer: B -> Stop
#     yields two records, in order
for port in $PORTS; do
  dir="$(make_project "$port" changed)"
  flag="$dir/$(dotdir_for "$port")/.pending-review.lp-1"
  ok=true
  printf 'defer: reason A\n' > "$flag"; run_stop "$port" "$dir" || ok=false
  printf 'defer: reason B\n' > "$flag"; run_stop "$port" "$dir" || ok=false
  got="$(cut -d' ' -f2- < "$dir/$(dotdir_for "$port")/review-audit.log" 2>/dev/null | tr '\n' '|' || true)"
  if [ "$ok" = true ] && [ "$got" = 'defer: reason A|defer: reason B|' ]; then
    echo "OK   (c) $port: defer: A -> Stop -> defer: B -> Stop logs both reasons, in order"
  else
    echo "FAIL (c) $port: expected 'defer: reason A|defer: reason B|' (ok=$ok got=[$got])"
    fail=1
  fi
done

# (d) the other ported mechanism: a reason that is empty after the colon is not
#     an escape hatch - it blocks (exit 2), logs nothing, and keeps the flag
for port in $PORTS; do
  for kind in defer skip; do
    dir="$(make_project "$port" "empty-$kind")"
    flag="$dir/$(dotdir_for "$port")/.pending-review.lp-1"
    printf '%s: \n' "$kind" > "$flag"
    rc=0
    run_stop "$port" "$dir" 2>/dev/null || rc=$?
    n="$(records "$dir" "$port" "$kind: ")"
    if [ "$rc" = 2 ] && [ "$n" = 0 ] && [ -f "$flag" ]; then
      echo "OK   (d) $port: an empty-after-colon '$kind: ' reason blocks, logs nothing, keeps the flag"
    else
      echo "FAIL (d) $port: expected rc=2, no '$kind: ' record, flag kept (rc=$rc records=$n flag-exists=$([ -f "$flag" ] && echo yes || echo no))"
      fail=1
    fi
  done
done

# (f) review-join marker-coupling check: drives all three ports through
#     bootstrap, missing-marker block, satisfied clear, re-review-stale block,
#     and .blocked precedence. Each port uses its own dot-dir and payload shape.
#     First a gated agent SubagentStop creates the pending-review flag; then a
#     reviewer SubagentStop tests the check against various stamp/marker states.
#     The stamp is what reviewer-route-gate.sh writes at dispatch time; its
#     single line is
#       <UTC ISO-8601> unit=<unit-id> prior=<none|fail|blocked> prior_mtime=<epoch|->
seed_join_stamp() {
  # $1 = project dir, $2 = port, $3 = unit id, $4 = prior, $5 = prior_mtime
  printf '2026-08-07T12:00:00Z unit=%s prior=%s prior_mtime=%s\n' "$3" "$4" "$5" \
    > "$1/$(dotdir_for "$2")/.review-join.$3"
}

for port in $PORTS; do
  dot="$(dotdir_for "$port")"

  # Case f0: bootstrap (no review-join stamp at all -> fail OPEN, one marker-check=bootstrap record)
  dir="$(make_project "$port" "f0-bootstrap")"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  rc=0
  run_reviewer_stop "$port" "$dir" 2>/dev/null || rc=$?
  has_bootstrap="$(records "$dir" "$port" 'marker-check=bootstrap')"
  flag_exists=false
  ls "$dir/$dot"/.pending-review.* >/dev/null 2>&1 && flag_exists=true
  if [ "$rc" = 0 ] && [ "$has_bootstrap" = 1 ] && [ "$flag_exists" = false ]; then
    echo "OK   (f0) $port: no review-join stamp fails open with marker-check=bootstrap, clears flag"
  else
    echo "FAIL (f0) $port: expected rc=0, marker-check=bootstrap record, flag cleared (rc=$rc has_bootstrap=$has_bootstrap flag_exists=$flag_exists)"
    fail=1
  fi

  # Case f1: missing-marker block (a stamp stands, its unit holds no marker ->
  #          blocks with marker=MISSING naming that unit; stamp is NOT deleted)
  dir="$(make_project "$port" "f1-missing")"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  seed_join_stamp "$dir" "$port" unit-f1 none -
  rc=0
  run_reviewer_stop "$port" "$dir" 2>/dev/null || rc=$?
  has_missing="$(records "$dir" "$port" 'marker=MISSING unit=unit-f1')"
  stamp_kept=false
  [ -f "$dir/$dot/.review-join.unit-f1" ] && stamp_kept=true
  flag_exists=false
  ls "$dir/$dot"/.pending-review.* >/dev/null 2>&1 && flag_exists=true
  if [ "$rc" = 2 ] && [ "$has_missing" = 1 ] && [ "$flag_exists" = true ] && [ "$stamp_kept" = true ]; then
    echo "OK   (f1) $port: an unsatisfied stamp blocks with marker=MISSING unit=, keeps the flag and the stamp"
  else
    echo "FAIL (f1) $port: expected rc=2, marker=MISSING unit=unit-f1 record, flag kept, stamp kept (rc=$rc has_missing=$has_missing flag_exists=$flag_exists stamp_kept=$stamp_kept)"
    fail=1
  fi

  # Case f2: satisfied clear (a format-valid v3 marker for the stamped unit ->
  #          consumes that stamp and proceeds). A zero-byte `touch`ed marker
  #          used to serve here; under the format check that is now case f2b.
  dir="$(make_project "$port" "f2-present")"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  seed_join_stamp "$dir" "$port" unit-f2 none -
  printf 'PASS unit-f2 2026-08-07T12:00:00Z commit: abc123 criteria: bash tests/validate.sh\n' \
    > "$dir/$dot/reviewed/unit-f2.pass"
  rc=0
  run_reviewer_stop "$port" "$dir" 2>/dev/null || rc=$?
  has_cleared="$(records "$dir" "$port" 'cleared-by=reviewer')"
  has_consumed="$(records "$dir" "$port" 'join-consumed=unit-f2')"
  stamp_gone=false
  [ -e "$dir/$dot/.review-join.unit-f2" ] || stamp_gone=true
  flag_exists=false
  ls "$dir/$dot"/.pending-review.* >/dev/null 2>&1 && flag_exists=true
  if [ "$rc" = 0 ] && [ "$has_cleared" = 1 ] && [ "$has_consumed" = 1 ] \
     && [ "$stamp_gone" = true ] && [ "$flag_exists" = false ]; then
    echo "OK   (f2) $port: a format-valid marker satisfies the stamp, consumes it, clears the flag"
  else
    echo "FAIL (f2) $port: expected rc=0, cleared-by=reviewer, join-consumed=unit-f2, stamp consumed, flag deleted (rc=$rc has_cleared=$has_cleared has_consumed=$has_consumed stamp_gone=$stamp_gone flag_exists=$flag_exists)"
    fail=1
  fi

  # Case f2b: a zero-byte `touch`ed marker is NOT a verdict - the format check
  #           mirrors task-gate.sh's marker_valid(), so this must block.
  dir="$(make_project "$port" "f2b-zero-byte")"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  seed_join_stamp "$dir" "$port" unit-f2b none -
  : > "$dir/$dot/reviewed/unit-f2b.pass"
  rc=0
  run_reviewer_stop "$port" "$dir" 2>/dev/null || rc=$?
  has_missing="$(records "$dir" "$port" 'marker=MISSING unit=unit-f2b')"
  flag_exists=false
  ls "$dir/$dot"/.pending-review.* >/dev/null 2>&1 && flag_exists=true
  if [ "$rc" = 2 ] && [ "$has_missing" = 1 ] && [ "$flag_exists" = true ]; then
    echo "OK   (f2b) $port: a zero-byte marker fails the format check and still blocks"
  else
    echo "FAIL (f2b) $port: expected rc=2, marker=MISSING unit=unit-f2b record, flag kept (rc=$rc has_missing=$has_missing flag_exists=$flag_exists)"
    fail=1
  fi

  # Case f3: re-review-stale block (the stamp recorded the mtime of the .fail
  #          this re-review is meant to supersede; that same marker must not
  #          satisfy it, or a re-review after FAIL would need no new verdict)
  dir="$(make_project "$port" "f3-stale")"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  printf 'FAIL unit-f3 2026-08-07T12:00:00Z defects: 1) criterion 3 not met\n' \
    > "$dir/$dot/reviewed/unit-f3.fail"
  f3_mtime="$(stat -L --format=%Y "$dir/$dot/reviewed/unit-f3.fail")"
  seed_join_stamp "$dir" "$port" unit-f3 fail "$f3_mtime"
  rc=0
  run_reviewer_stop "$port" "$dir" 2>/dev/null || rc=$?
  has_missing="$(records "$dir" "$port" 'marker=MISSING unit=unit-f3')"
  flag_exists=false
  ls "$dir/$dot"/.pending-review.* >/dev/null 2>&1 && flag_exists=true
  if [ "$rc" = 2 ] && [ "$has_missing" = 1 ] && [ "$flag_exists" = true ]; then
    echo "OK   (f3) $port: a marker no newer than the recorded prior_mtime blocks, keeps flag"
  else
    echo "FAIL (f3) $port: expected rc=2, marker=MISSING unit=unit-f3 record, flag kept (rc=$rc has_missing=$has_missing flag_exists=$flag_exists prior_mtime=$f3_mtime)"
    fail=1
  fi

  # Case f4: .blocked marker precedence (a .blocked marker must short-circuit to
  #     allow even when a stamp stands unsatisfied - guards the same
  #     insertion-point failure mode issue #221's own criterion 9 exists for)
  dir="$(make_project "$port" "f4-blocked-precedence")"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  seed_join_stamp "$dir" "$port" unit-f4 none -
  printf 'BLOCKED unit-f4 2026-08-07T12:00:00Z missing: constraint Z\n' \
    > "$dir/$dot/reviewed/unit-f4.blocked"
  rc=0
  run_reviewer_stop "$port" "$dir" 2>/dev/null || rc=$?
  has_blocked="$(records "$dir" "$port" 'verdict=blocked flags-kept')"
  stamp_kept=false
  [ -f "$dir/$dot/.review-join.unit-f4" ] && stamp_kept=true
  flag_exists=false
  ls "$dir/$dot"/.pending-review.* >/dev/null 2>&1 && flag_exists=true
  if [ "$rc" = 0 ] && [ "$has_blocked" = 1 ] && [ "$flag_exists" = true ] && [ "$stamp_kept" = true ]; then
    echo "OK   (f4) $port: a .blocked marker short-circuits to allow ahead of the review-join check, keeps flag and stamp"
  else
    echo "FAIL (f4) $port: expected rc=0, verdict=blocked flags-kept record, flag kept, stamp kept (rc=$rc has_blocked=$has_blocked flag_exists=$flag_exists stamp_kept=$stamp_kept)"
    fail=1
  fi
done

# (e) MUTATION CONTROL for the step (issue #202 criterion 4): revert the dedupe
#     in a throwaway copy of ONE adapter script - CODEX - and confirm case (a)
#     fails there. A parity test that still passes against an unported script
#     would be worthless. (See case (g) below for the analogous mutation
#     control on the clear-watermark check added by issue #222.)
mutant="$tmproot/mutant-codex"
mkdir -p "$mutant"
cp adapters/codex/hooks/scripts/stop-gate.sh "$mutant/stop-gate.sh"
cp -R adapters/codex/hooks/scripts/lib "$mutant/lib"
guard='if [ "$last_logged" != "$flag_content" ]; then'
before_n="$(grep -cF "$guard" "$mutant/stop-gate.sh" || true)"
sed -i "s/$(printf '%s' "$guard" | sed 's/[][\\.*^$\/]/\\&/g')/if true; then/" "$mutant/stop-gate.sh"
after_n="$(grep -cF "$guard" "$mutant/stop-gate.sh" || true)"
parses=yes
bash -n "$mutant/stop-gate.sh" 2>/dev/null || parses=no

dir="$(make_project codex mutation)"
printf 'defer: reviewer already dispatched\n' > "$dir/.codex/.pending-review.lp-1"
ok=true
for _ in 1 2 3; do
  run_stop codex "$dir" "$mutant/stop-gate.sh" || ok=false
done
n="$(records "$dir" codex 'defer: ')"
if [ "${before_n:-0}" = 1 ] && [ "${after_n:-0}" = 0 ] && [ "$parses" = yes ] \
   && [ "$ok" = true ] && [ "$n" = 3 ]; then
  echo "OK   (e) mutation control: with the dedupe reverted in the CODEX port the same run logs 3 records, so (a) is binding"
else
  echo "FAIL (e) mutation not applied or did not change behavior in the CODEX port (guard before=$before_n after=$after_n parses=$parses ok=$ok records=$n)"
  fail=1
fi

# (g) MUTATION CONTROL for the review-join check (issue #222 criterion 4,
#     carried forward to the per-unit mechanism): stub review_join_state's
#     result in a throwaway copy of the CODEX port so the check always sees
#     zero stamps (i.e. "no check", the bootstrap fail-open path), then re-run
#     scenario (f)'s blocking codex cases f1, f2b and f3 against that mutant via
#     the $3 script override. All must FAIL to block (rc=0, no marker=MISSING
#     record) - if any still correctly blocks, the mutation did not take and
#     scenario (f) would be worthless for the codex port.
watermark_mutant="$tmproot/mutant-codex-review-join"
mkdir -p "$watermark_mutant"
cp adapters/codex/hooks/scripts/stop-gate.sh "$watermark_mutant/stop-gate.sh"
cp -R adapters/codex/hooks/scripts/lib "$watermark_mutant/lib"
wm_before_n="$(grep -cxF '    review_join_state "$dot"' "$watermark_mutant/stop-gate.sh" || true)"
sed -i 's/^    review_join_state "\$dot"$/    review_join_state "$dot"; JOIN_STAMP_COUNT=0/' \
  "$watermark_mutant/stop-gate.sh"
wm_after_n="$(grep -cF 'JOIN_STAMP_COUNT=0' "$watermark_mutant/stop-gate.sh" || true)"
wm_parses=yes
bash -n "$watermark_mutant/stop-gate.sh" 2>/dev/null || wm_parses=no

mutant_binding=true

# f1 against the mutant: an unsatisfied stamp must no longer block
dir="$(make_project codex mutant-f1-missing)"
run_gated_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || true
seed_join_stamp "$dir" codex unit-f1 none -
rc=0
run_reviewer_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || rc=$?
has_missing="$(records "$dir" codex 'marker=MISSING')"
if [ "$rc" = 2 ] || [ "$has_missing" != 0 ]; then
  echo "FAIL (g) codex f1 still blocks against the mutant - mutation not binding"
  mutant_binding=false
fi

# f2b against the mutant: a zero-byte marker must no longer block
dir="$(make_project codex mutant-f2b-zero-byte)"
run_gated_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || true
seed_join_stamp "$dir" codex unit-f2b none -
: > "$dir/.codex/reviewed/unit-f2b.pass"
rc=0
run_reviewer_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || rc=$?
has_missing="$(records "$dir" codex 'marker=MISSING')"
if [ "$rc" = 2 ] || [ "$has_missing" != 0 ]; then
  echo "FAIL (g) codex f2b still blocks against the mutant - mutation not binding"
  mutant_binding=false
fi

# f3 against the mutant: a re-review-stale marker must no longer block
dir="$(make_project codex mutant-f3-stale)"
run_gated_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || true
printf 'FAIL unit-f3 2026-08-07T12:00:00Z defects: 1) criterion 3 not met\n' \
  > "$dir/.codex/reviewed/unit-f3.fail"
seed_join_stamp "$dir" codex unit-f3 fail "$(stat -L --format=%Y "$dir/.codex/reviewed/unit-f3.fail")"
rc=0
run_reviewer_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || rc=$?
has_missing="$(records "$dir" codex 'marker=MISSING')"
if [ "$rc" = 2 ] || [ "$has_missing" != 0 ]; then
  echo "FAIL (g) codex f3 still blocks against the mutant - mutation not binding"
  mutant_binding=false
fi

if [ "${wm_before_n:-0}" = 1 ] && [ "${wm_after_n:-0}" = 1 ] && [ "$wm_parses" = yes ] \
   && [ "$mutant_binding" = true ]; then
  echo "OK   (g) mutation control: with the review-join check stubbed in the CODEX port, f1, f2b and f3 no longer block, so scenario (f) is binding on codex"
else
  echo "FAIL (g) review-join mutation not applied or did not change behavior in the CODEX port (call before=$wm_before_n stub after=$wm_after_n parses=$wm_parses binding=$mutant_binding)"
  fail=1
fi


# (h) GNU/BSD stat portability regression (issue #274): the review-join
#     stamp's marker-coupling check reads a marker's mtime via GNU-only
#     `stat --format=%Y`, which fails silently on BSD/macOS stat (the
#     trailing `|| true` swallows the error), leaving a genuinely NEW verdict
#     marker undetected and blocking with marker=MISSING on exactly the
#     platform the fix targets. Stub a BSD-only `stat` first on PATH (accepts
#     `-f %m`, rejects GNU's `-c`/`--format`) and drive the same repro shape
#     as case (f3) through it, using the (e)/(g) mutation-control pattern: a
#     throwaway copy with the OLD GNU-only call restored must still block
#     under the BSD stub (proving the test is non-vacuous), while the real,
#     fixed script must succeed.
bsd_stat_bin="$tmproot/bsd-stat-bin"
mkdir -p "$bsd_stat_bin"
cat > "$bsd_stat_bin/stat" <<'STATEOF'
#!/usr/bin/env bash
# Minimal BSD-stat stand-in: supports -L/-f %m (mtime), rejects GNU's -c/--format.
fmt=""
file=""
skip=false
for a in "$@"; do
  if $skip; then fmt="$a"; skip=false; continue; fi
  case "$a" in
    -c|--format=*|--format) echo "stat: illegal option" >&2; exit 1 ;;
    -f) skip=true ;;
    -L) ;;
    -*) ;;
    *) file="$a" ;;
  esac
done
[ "$fmt" = "%m" ] && [ -n "$file" ] || exit 1
/usr/bin/stat -c %Y "$file" 2>/dev/null || exit 1
STATEOF
chmod +x "$bsd_stat_bin/stat"

fixed_call='mtime="$(stat -L -c %Y "$mpath" 2>/dev/null || stat -L -f %m "$mpath" 2>/dev/null || true)"'
old_call='mtime="$(stat -L --format=%Y "$mpath" 2>/dev/null || true)"'

for port in $PORTS; do
  dot="$(dotdir_for "$port")"
  script="$(script_for "$port")"

  # mutant: throwaway copy with the OLD GNU-only stat call restored
  mutant="$tmproot/mutant-h-$port"
  mkdir -p "$mutant"
  cp "$script" "$mutant/stop-gate.sh"
  cp -R "$(dirname "$script")/lib" "$mutant/lib"
  before_n="$(grep -cF "$fixed_call" "$mutant/stop-gate.sh" || true)"
  python3 - "$mutant/stop-gate.sh" "$fixed_call" "$old_call" <<'PYEOF'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
assert text.count(old) == 1, f"expected exactly one occurrence, found {text.count(old)}"
open(path, "w").write(text.replace(old, new))
PYEOF
  after_n="$(grep -cF "$old_call" "$mutant/stop-gate.sh" || true)"
  parses=yes
  bash -n "$mutant/stop-gate.sh" 2>/dev/null || parses=no

  # seed the repro: an OLD .fail marker, a stamp recording its mtime, and a
  # NEWER format-valid .pass marker superseding it
  dir="$(make_project "$port" "h-portability")"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  printf 'FAIL unit-x 2026-08-07T12:00:00Z defects: 1) x\n' > "$dir/$dot/reviewed/unit-x.fail"
  touch -d '2020-01-01T00:00:00' "$dir/$dot/reviewed/unit-x.fail"
  fail_mtime="$(stat -L -c %Y "$dir/$dot/reviewed/unit-x.fail" 2>/dev/null || stat -L -f %m "$dir/$dot/reviewed/unit-x.fail")"
  seed_join_stamp "$dir" "$port" unit-x fail "$fail_mtime"
  printf 'PASS unit-x 2026-08-07T12:00:05Z commit: abc123 criteria: bash tests/validate.sh\n' \
    > "$dir/$dot/reviewed/unit-x.pass"

  # (h-mutant) the OLD code, under the BSD stub, must still block (non-vacuous)
  rc=0
  PATH="$bsd_stat_bin:$PATH" run_reviewer_stop "$port" "$dir" "$mutant/stop-gate.sh" 2>/dev/null || rc=$?
  mutant_missing="$(records "$dir" "$port" 'marker=MISSING unit=unit-x')"
  mutant_stamp_kept=false
  [ -f "$dir/$dot/.review-join.unit-x" ] && mutant_stamp_kept=true

  # (h-fixed) the real, fixed script, under the SAME BSD stub, must succeed
  rc2=0
  PATH="$bsd_stat_bin:$PATH" run_reviewer_stop "$port" "$dir" "$script" 2>/dev/null || rc2=$?
  fixed_consumed="$(records "$dir" "$port" 'join-consumed=unit-x')"
  fixed_stamp_gone=false
  [ -e "$dir/$dot/.review-join.unit-x" ] || fixed_stamp_gone=true

  if [ "${before_n:-0}" = 1 ] && [ "${after_n:-0}" = 1 ] && [ "$parses" = yes ] \
     && [ "$rc" = 2 ] && [ "$mutant_missing" = 1 ] && [ "$mutant_stamp_kept" = true ] \
     && [ "$rc2" = 0 ] && [ "$fixed_consumed" = 1 ] && [ "$fixed_stamp_gone" = true ]; then
    echo "OK   (h) $port: BSD-only stat - OLD code blocks (marker=MISSING), FIXED code consumes the stamp (join-consumed=unit-x)"
  else
    echo "FAIL (h) $port: mutant before=$before_n after=$after_n parses=$parses rc=$rc missing=$mutant_missing stamp_kept=$mutant_stamp_kept | fixed rc2=$rc2 consumed=$fixed_consumed stamp_gone=$fixed_stamp_gone"
    fail=1
  fi
done

exit "$fail"
