#!/usr/bin/env bash
# Payload-shape parity guard for the three stop-gate ports (issue #202,
# retargeted for gh411's core extraction: decision logic now lives in ONE
# shared file, hooks/scripts/lib/stop-gate-core.sh, copied byte-for-byte into
# each adapter - A10 proves the copies identical, so re-running every
# decision branch per port would only re-prove that byte-identity). (a)-(d)
# and (f) exercise PAYLOAD-SHAPE wiring (does each port's thin entry thread
# project_dir/dot/hook_event/agent_type into the core?) on all three ports;
# (e)/(g)/(h) mutate CODEX's core copy to prove that wiring is load-bearing;
# (i) covers marker-commit-check wiring on codex alone, since it is pure core
# logic once (e)/(g)/(h) prove a core mutation binds through codex's entry.
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
# make_project <port> <case> -> a fresh project dir with that port's config
make_project() {
  local dot dir
  dot="$(dotdir_for "$1")"
  dir="$tmproot/$1-$2"
  mkdir -p "$dir/$dot/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
    > "$dir/$dot/persona-config.json"
  echo "$dir"
}
# make_mutant_copy <port> <name> -> a throwaway copy of that port's entry
# script + lib/ dir; mutating the copy's lib/stop-gate-core.sh (not the thin
# entry) is what a mutation must target since gh411.
make_mutant_copy() {
  local port="$1" name="$2" dst script
  script="$(script_for "$port")"
  dst="$tmproot/$name"
  mkdir -p "$dst"
  cp "$script" "$dst/stop-gate.sh"
  cp -R "$(dirname "$script")/lib" "$dst/lib"
  echo "$dst"
}
# run_stop/run_gated_stop/run_reviewer_stop <port> <dir> [script] [agent] -
# each port names the project dir and events differently (env var vs .cwd vs
# .workspace_roots[0]; PascalCase vs lower/mixed-case event names).
run_stop() {
  local port="$1" dir="$2" script rc=0
  script="${3:-$(script_for "$port")}"
  case "$port" in
    claude) printf '%s' '{"hook_event_name":"Stop","session_id":"main"}' \
      | CLAUDE_PROJECT_DIR="$dir" bash "$script" || rc=$? ;;
    codex)  printf '{"hook_event_name":"Stop","session_id":"main","cwd":"%s"}' "$dir" \
      | bash "$script" || rc=$? ;;
    cursor) printf '{"hook_event_name":"stop","conversation_id":"main","workspace_roots":["%s"]}' "$dir" \
      | bash "$script" || rc=$? ;;
  esac
  return "$rc"
}
run_gated_stop() {
  local port="$1" dir="$2" script agent rc=0
  script="${3:-$(script_for "$port")}"
  agent="${4:-lead-programmer}"
  case "$port" in
    claude) printf '%s' "{\"hook_event_name\":\"SubagentStop\",\"agent_type\":\"$agent\",\"session_id\":\"main\"}" \
      | CLAUDE_PROJECT_DIR="$dir" bash "$script" || rc=$? ;;
    codex)  printf '{\"hook_event_name\":\"SubagentStop\",\"agent_type\":\"%s\",\"agent_id\":\"agent-1\",\"session_id\":\"main\",\"cwd\":\"%s\"}' "$agent" "$dir" \
      | bash "$script" || rc=$? ;;
    cursor) printf '{\"hook_event_name\":\"subagentStop\",\"subagent_type\":\"%s\",\"conversation_id\":\"main\",\"workspace_roots\":[\"%s\"]}' "$agent" "$dir" \
      | bash "$script" || rc=$? ;;
  esac
  return "$rc"
}
# run_reviewer_stop <port> <dir> [script] - a reviewer SubagentStop is just
# run_gated_stop with agent="reviewer" (same payload shape on all 3 ports).
run_reviewer_stop() { run_gated_stop "$1" "$2" "${3-}" reviewer; }
# records <dir> <port> <pattern> - occurrences of pattern in that port's
# review-audit.log. A missing log file means zero.
records() {
  local n
  n="$(grep -c "$3" "$1/$(dotdir_for "$2")/review-audit.log" 2>/dev/null || true)"
  echo "${n:-0}"
}
# check <label> <true|false> <state-detail> - OK/FAIL line; FAIL sets $fail
check() {
  if [ "$2" = true ]; then echo "OK   $1"; else echo "FAIL $1: $3"; fail=1; fi
}
# (a) one single-line defer: write permits three Stops and logs exactly one record
for port in $PORTS; do
  dir="$(make_project "$port" single)"
  printf 'defer: reviewer already dispatched\n' > "$dir/$(dotdir_for "$port")/.pending-review.lp-1"
  ok=true
  for _ in 1 2 3; do run_stop "$port" "$dir" || ok=false; done
  n="$(records "$dir" "$port" 'defer: ')"
  check "(a) $port: three Stops with an unchanged defer: log exactly one record" \
    "$([ "$ok" = true ] && [ "$n" = 1 ] && echo true || echo false)" "ok=$ok records=$n"
done
# (b) a MULTI-LINE reason is flattened to one logical line, so it still dedupes
for port in $PORTS; do
  dir="$(make_project "$port" multiline)"
  printf 'defer: reviewer dispatched\nsee issue 202 for the reason\n' \
    > "$dir/$(dotdir_for "$port")/.pending-review.lp-1"
  ok=true
  for _ in 1 2 3; do run_stop "$port" "$dir" || ok=false; done
  n="$(records "$dir" "$port" 'defer: ')"
  lines="$(wc -l < "$dir/$(dotdir_for "$port")/review-audit.log" 2>/dev/null || echo 0)"
  check "(b) $port: three Stops with an unchanged multi-line defer: log one one-line record" \
    "$([ "$ok" = true ] && [ "$n" = 1 ] && [ "$lines" = 1 ] && echo true || echo false)" \
    "ok=$ok records=$n log-lines=$lines"
done
# (c) a CHANGED reason is recorded again: defer: A -> Stop -> defer: B -> Stop
for port in $PORTS; do
  dir="$(make_project "$port" changed)"
  flag="$dir/$(dotdir_for "$port")/.pending-review.lp-1"
  ok=true
  printf 'defer: reason A\n' > "$flag"; run_stop "$port" "$dir" || ok=false
  printf 'defer: reason B\n' > "$flag"; run_stop "$port" "$dir" || ok=false
  got="$(cut -d' ' -f2- < "$dir/$(dotdir_for "$port")/review-audit.log" 2>/dev/null | tr '\n' '|' || true)"
  check "(c) $port: defer: A -> Stop -> defer: B -> Stop logs both reasons, in order" \
    "$([ "$ok" = true ] && [ "$got" = 'defer: reason A|defer: reason B|' ] && echo true || echo false)" \
    "ok=$ok got=[$got]"
done
# (d) a reason empty after the colon is NOT an escape hatch - blocks, logs nothing
for port in $PORTS; do
  for kind in defer skip; do
    dir="$(make_project "$port" "empty-$kind")"
    flag="$dir/$(dotdir_for "$port")/.pending-review.lp-1"
    printf '%s: \n' "$kind" > "$flag"
    rc=0
    run_stop "$port" "$dir" 2>/dev/null || rc=$?
    n="$(records "$dir" "$port" "$kind: ")"
    check "(d) $port: an empty-after-colon '$kind: ' reason blocks, logs nothing, keeps the flag" \
      "$([ "$rc" = 2 ] && [ "$n" = 0 ] && [ -f "$flag" ] && echo true || echo false)" \
      "rc=$rc records=$n flag-exists=$([ -f "$flag" ] && echo yes || echo no)"
  done
done
# (f) review-join marker-coupling: bootstrap, missing-marker block, satisfied
#     clear, re-review-stale block, .blocked precedence. Full depth (f0-f4)
#     runs once, on claude; codex/cursor get a two-case wiring smoke test
#     (f0 + f2) proving their own gated/reviewer SubagentStop payload shape
#     still reaches the shared core. Stamp format (reviewer-route-gate.sh):
#     <UTC ISO-8601> unit=<unit-id> prior=<none|fail|blocked> prior_mtime=<epoch|->
seed_join_stamp() {
  printf '2026-08-07T12:00:00Z unit=%s prior=%s prior_mtime=%s\n' "$3" "$4" "$5" \
    > "$1/$(dotdir_for "$2")/.review-join.$3"
}
f0_case() {
  local port="$1" dot dir rc=0 has flagx
  dot="$(dotdir_for "$port")"
  dir="$(make_project "$port" f0-bootstrap)"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  run_reviewer_stop "$port" "$dir" 2>/dev/null || rc=$?
  has="$(records "$dir" "$port" 'marker-check=bootstrap')"
  flagx=false; ls "$dir/$dot"/.pending-review.* >/dev/null 2>&1 && flagx=true
  check "(f0) $port: no review-join stamp fails open with marker-check=bootstrap, clears flag" \
    "$([ "$rc" = 0 ] && [ "$has" = 1 ] && [ "$flagx" = false ] && echo true || echo false)" \
    "rc=$rc bootstrap=$has flag=$flagx"
}
f2_case() {
  local port="$1" dot dir rc=0 cleared consumed gone flagx
  dot="$(dotdir_for "$port")"
  dir="$(make_project "$port" f2-present)"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  seed_join_stamp "$dir" "$port" unit-f2 none -
  printf 'PASS unit-f2 2026-08-07T12:00:00Z commit: abc123 criteria: bash tests/validate.sh\n' \
    > "$dir/$dot/reviewed/unit-f2.pass"
  run_reviewer_stop "$port" "$dir" 2>/dev/null || rc=$?
  cleared="$(records "$dir" "$port" 'cleared-by=reviewer')"
  consumed="$(records "$dir" "$port" 'join-consumed=unit-f2')"
  gone=false; [ -e "$dir/$dot/.review-join.unit-f2" ] || gone=true
  flagx=false; ls "$dir/$dot"/.pending-review.* >/dev/null 2>&1 && flagx=true
  check "(f2) $port: a format-valid marker satisfies the stamp, consumes it, clears the flag" \
    "$([ "$rc" = 0 ] && [ "$cleared" = 1 ] && [ "$consumed" = 1 ] && [ "$gone" = true ] && [ "$flagx" = false ] && echo true || echo false)" \
    "rc=$rc cleared=$cleared consumed=$consumed stamp-gone=$gone flag=$flagx"
}
f0_case claude
f2_case claude
# f1: an unsatisfied stamp blocks with marker=MISSING, keeps flag and stamp
dir="$(make_project claude f1-missing)"
run_gated_stop claude "$dir" 2>/dev/null || true
seed_join_stamp "$dir" claude unit-f1 none -
rc=0; run_reviewer_stop claude "$dir" 2>/dev/null || rc=$?
has="$(records "$dir" claude 'marker=MISSING unit=unit-f1')"
stamp=false; [ -f "$dir/.claude/.review-join.unit-f1" ] && stamp=true
flagx=false; ls "$dir/.claude"/.pending-review.* >/dev/null 2>&1 && flagx=true
check "(f1) claude: an unsatisfied stamp blocks with marker=MISSING unit=, keeps the flag and the stamp" \
  "$([ "$rc" = 2 ] && [ "$has" = 1 ] && [ "$flagx" = true ] && [ "$stamp" = true ] && echo true || echo false)" \
  "rc=$rc missing=$has flag=$flagx stamp=$stamp"
# f2b: a zero-byte `touch`ed marker is NOT a verdict (mirrors task-gate.sh)
dir="$(make_project claude f2b-zero-byte)"
run_gated_stop claude "$dir" 2>/dev/null || true
seed_join_stamp "$dir" claude unit-f2b none -
: > "$dir/.claude/reviewed/unit-f2b.pass"
rc=0; run_reviewer_stop claude "$dir" 2>/dev/null || rc=$?
has="$(records "$dir" claude 'marker=MISSING unit=unit-f2b')"
flagx=false; ls "$dir/.claude"/.pending-review.* >/dev/null 2>&1 && flagx=true
check "(f2b) claude: a zero-byte marker fails the format check and still blocks" \
  "$([ "$rc" = 2 ] && [ "$has" = 1 ] && [ "$flagx" = true ] && echo true || echo false)" \
  "rc=$rc missing=$has flag=$flagx"
# f3: a marker no newer than the stamp's recorded prior_mtime still blocks
dir="$(make_project claude f3-stale)"
run_gated_stop claude "$dir" 2>/dev/null || true
printf 'FAIL unit-f3 2026-08-07T12:00:00Z defects: 1) criterion 3 not met\n' \
  > "$dir/.claude/reviewed/unit-f3.fail"
f3_mtime="$(stat -L --format=%Y "$dir/.claude/reviewed/unit-f3.fail")"
seed_join_stamp "$dir" claude unit-f3 fail "$f3_mtime"
rc=0; run_reviewer_stop claude "$dir" 2>/dev/null || rc=$?
has="$(records "$dir" claude 'marker=MISSING unit=unit-f3')"
flagx=false; ls "$dir/.claude"/.pending-review.* >/dev/null 2>&1 && flagx=true
check "(f3) claude: a marker no newer than the recorded prior_mtime blocks, keeps flag" \
  "$([ "$rc" = 2 ] && [ "$has" = 1 ] && [ "$flagx" = true ] && echo true || echo false)" \
  "rc=$rc missing=$has flag=$flagx prior_mtime=$f3_mtime"
# f4: a .blocked marker short-circuits to allow ahead of the review-join check
dir="$(make_project claude f4-blocked-precedence)"
run_gated_stop claude "$dir" 2>/dev/null || true
seed_join_stamp "$dir" claude unit-f4 none -
printf 'BLOCKED unit-f4 2026-08-07T12:00:00Z missing: constraint Z\n' \
  > "$dir/.claude/reviewed/unit-f4.blocked"
rc=0; run_reviewer_stop claude "$dir" 2>/dev/null || rc=$?
has="$(records "$dir" claude 'verdict=blocked flags-kept')"
stamp=false; [ -f "$dir/.claude/.review-join.unit-f4" ] && stamp=true
flagx=false; ls "$dir/.claude"/.pending-review.* >/dev/null 2>&1 && flagx=true
check "(f4) claude: a .blocked marker short-circuits to allow, keeps flag and stamp" \
  "$([ "$rc" = 0 ] && [ "$has" = 1 ] && [ "$flagx" = true ] && [ "$stamp" = true ] && echo true || echo false)" \
  "rc=$rc blocked=$has flag=$flagx stamp=$stamp"
for port in codex cursor; do f0_case "$port"; f2_case "$port"; done
# (e) MUTATION CONTROL (issue #202 crit. 4): revert the dedupe guard in a
#     throwaway copy of CODEX's core (not the thin entry - the logic lives
#     only there since gh411) and confirm case (a) fails against it.
mutant="$(make_mutant_copy codex mutant-codex)"
core="$mutant/lib/stop-gate-core.sh"
guard='if [ "$last_logged" != "$flag_content" ]; then'
before_n="$(grep -cF "$guard" "$core" || true)"
sed -i "s/$(printf '%s' "$guard" | sed 's/[][\\.*^$\/]/\\&/g')/if true; then/" "$core"
after_n="$(grep -cF "$guard" "$core" || true)"
parses=yes; bash -n "$core" 2>/dev/null || parses=no
dir="$(make_project codex mutation)"
printf 'defer: reviewer already dispatched\n' > "$dir/.codex/.pending-review.lp-1"
ok=true
for _ in 1 2 3; do run_stop codex "$dir" "$mutant/stop-gate.sh" || ok=false; done
n="$(records "$dir" codex 'defer: ')"
check "(e) mutation control: dedupe reverted in codex's core copy logs 3 records, so (a) is binding" \
  "$([ "${before_n:-0}" = 1 ] && [ "${after_n:-0}" = 0 ] && [ "$parses" = yes ] && [ "$ok" = true ] && [ "$n" = 3 ] && echo true || echo false)" \
  "guard before=$before_n after=$after_n parses=$parses ok=$ok records=$n"
# (g) MUTATION CONTROL for the review-join check (issue #222 crit. 4): stub
#     review_join_state's result in CODEX's core copy so it always sees zero
#     stamps (bootstrap fail-open), then re-run blocking cases f1/f2b/f3
#     against it - all must FAIL to block, or scenario (f) is worthless there.
watermark_mutant="$(make_mutant_copy codex mutant-codex-review-join)"
core="$watermark_mutant/lib/stop-gate-core.sh"
wm_before_n="$(grep -cxF '    review_join_state "$dot"' "$core" || true)"
sed -i 's/^    review_join_state "\$dot"$/    review_join_state "$dot"; JOIN_STAMP_COUNT=0/' "$core"
wm_after_n="$(grep -cF 'JOIN_STAMP_COUNT=0' "$core" || true)"
wm_parses=yes; bash -n "$core" 2>/dev/null || wm_parses=no
mutant_binding=true
dir="$(make_project codex mutant-f1-missing)"
run_gated_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || true
seed_join_stamp "$dir" codex unit-f1 none -
rc=0; run_reviewer_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || rc=$?
has="$(records "$dir" codex 'marker=MISSING')"
{ [ "$rc" = 2 ] || [ "$has" != 0 ]; } && mutant_binding=false
dir="$(make_project codex mutant-f2b-zero-byte)"
run_gated_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || true
seed_join_stamp "$dir" codex unit-f2b none -
: > "$dir/.codex/reviewed/unit-f2b.pass"
rc=0; run_reviewer_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || rc=$?
has="$(records "$dir" codex 'marker=MISSING')"
{ [ "$rc" = 2 ] || [ "$has" != 0 ]; } && mutant_binding=false
dir="$(make_project codex mutant-f3-stale)"
run_gated_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || true
printf 'FAIL unit-f3 2026-08-07T12:00:00Z defects: 1) criterion 3 not met\n' \
  > "$dir/.codex/reviewed/unit-f3.fail"
seed_join_stamp "$dir" codex unit-f3 fail "$(stat -L --format=%Y "$dir/.codex/reviewed/unit-f3.fail")"
rc=0; run_reviewer_stop codex "$dir" "$watermark_mutant/stop-gate.sh" 2>/dev/null || rc=$?
has="$(records "$dir" codex 'marker=MISSING')"
{ [ "$rc" = 2 ] || [ "$has" != 0 ]; } && mutant_binding=false
check "(g) mutation control: review-join stubbed in codex's core copy - f1/f2b/f3 no longer block" \
  "$([ "${wm_before_n:-0}" = 1 ] && [ "${wm_after_n:-0}" = 1 ] && [ "$wm_parses" = yes ] && [ "$mutant_binding" = true ] && echo true || echo false)" \
  "call before=$wm_before_n stub after=$wm_after_n parses=$wm_parses binding=$mutant_binding"
# (h) GNU/BSD stat portability regression (issue #274), codex only - the
#     stat call lives in the core, not payload-shape-sensitive. Stub a
#     BSD-only `stat` on PATH (accepts -f %m, rejects GNU -c/--format) and
#     drive f3's repro through it: a throwaway copy with the OLD GNU-only
#     call restored in the core must still block (non-vacuous); the real,
#     fixed script must succeed.
bsd_stat_bin="$tmproot/bsd-stat-bin"
mkdir -p "$bsd_stat_bin"
cat > "$bsd_stat_bin/stat" <<'STATEOF'
#!/usr/bin/env bash
fmt=""; file=""; skip=false
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
h_mutant="$(make_mutant_copy codex mutant-h-codex)"
h_core="$h_mutant/lib/stop-gate-core.sh"
h_before_n="$(grep -cF "$fixed_call" "$h_core" || true)"
python3 - "$h_core" "$fixed_call" "$old_call" <<'PYEOF'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
assert text.count(old) == 1, f"expected exactly one occurrence, found {text.count(old)}"
open(path, "w").write(text.replace(old, new))
PYEOF
h_after_n="$(grep -cF "$old_call" "$h_core" || true)"
h_parses=yes; bash -n "$h_core" 2>/dev/null || h_parses=no
dir="$(make_project codex h-portability)"
run_gated_stop codex "$dir" 2>/dev/null || true
printf 'FAIL unit-x 2026-08-07T12:00:00Z defects: 1) x\n' > "$dir/.codex/reviewed/unit-x.fail"
touch -d '2020-01-01T00:00:00' "$dir/.codex/reviewed/unit-x.fail"
h_fail_mtime="$(stat -L -c %Y "$dir/.codex/reviewed/unit-x.fail" 2>/dev/null || stat -L -f %m "$dir/.codex/reviewed/unit-x.fail")"
seed_join_stamp "$dir" codex unit-x fail "$h_fail_mtime"
printf 'PASS unit-x 2026-08-07T12:00:05Z commit: abc123 criteria: bash tests/validate.sh\n' \
  > "$dir/.codex/reviewed/unit-x.pass"
rc=0
PATH="$bsd_stat_bin:$PATH" run_reviewer_stop codex "$dir" "$h_mutant/stop-gate.sh" 2>/dev/null || rc=$?
h_missing="$(records "$dir" codex 'marker=MISSING unit=unit-x')"
h_stamp=false; [ -f "$dir/.codex/.review-join.unit-x" ] && h_stamp=true
rc2=0
PATH="$bsd_stat_bin:$PATH" run_reviewer_stop codex "$dir" "$(script_for codex)" 2>/dev/null || rc2=$?
h_consumed="$(records "$dir" codex 'join-consumed=unit-x')"
h_gone=false; [ -e "$dir/.codex/.review-join.unit-x" ] || h_gone=true
check "(h) codex: BSD-only stat - OLD core blocks (marker=MISSING), FIXED core consumes the stamp" \
  "$([ "${h_before_n:-0}" = 1 ] && [ "${h_after_n:-0}" = 1 ] && [ "$h_parses" = yes ] && [ "$rc" = 2 ] && [ "$h_missing" = 1 ] && [ "$h_stamp" = true ] && [ "$rc2" = 0 ] && [ "$h_consumed" = 1 ] && [ "$h_gone" = true ] && echo true || echo false)" \
  "mutant before=$h_before_n after=$h_after_n parses=$h_parses rc=$rc missing=$h_missing stamp=$h_stamp | fixed rc2=$rc2 consumed=$h_consumed gone=$h_gone"
# (i) marker-commit-check wiring parity (gh385-7), codex only - pure core
#     decision logic once (e)/(g)/(h) prove a codex core mutation binds. A
#     STUB classifier (always "mismatch") stands in for the real
#     hooks/scripts/marker-commit-check.sh, whose own marker lookup is not
#     adapter-dot-dir-aware (gh385-6's scope, not this unit's) - the stub
#     isolates the WIRING under test from that unrelated limitation.
mcc_stub_script() {
  cat > "$1/marker-commit-check.sh" <<'STUBEOF'
#!/usr/bin/env bash
printf 'marker-commit-check=mismatch unit=%s commit=deadbeef candidates=cafebabe\n' "$1"
exit 0
STUBEOF
  chmod +x "$1/marker-commit-check.sh"
}
mcc_project() {
  local case="$1" mode="$2" dir="$tmproot/codex-mcc-$1"
  mkdir -p "$dir/.codex/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"markerCommitCheck":{"mode":"%s"}}\n' "$mode" \
    > "$dir/.codex/persona-config.json"
  seed_join_stamp "$dir" codex "unit-$case" none -
  printf 'PASS unit-%s 2026-08-15T00:00:00Z commit: abc123 criteria: true\n' "$case" \
    > "$dir/.codex/reviewed/unit-$case.pass"
  echo "$dir"
}
mcc_port_mutant="$(make_mutant_copy codex mcc-codex)"
mcc_stub_script "$mcc_port_mutant"
mcc_port_no_classifier="$(make_mutant_copy codex mcc-noclassifier-codex)"
dir="$(mcc_project warn warn)"
run_gated_stop codex "$dir" "$mcc_port_mutant/stop-gate.sh" 2>/dev/null || true
rc=0; run_reviewer_stop codex "$dir" "$mcc_port_mutant/stop-gate.sh" 2>/dev/null || rc=$?
has="$(records "$dir" codex 'marker-commit-check=mismatch unit=unit-warn')"
flagx=false; ls "$dir/.codex"/.pending-review.* >/dev/null 2>&1 && flagx=true
check "(i-warn) codex: markerCommitCheck warn+mismatch -> exit 0, audit logged, flag cleared" \
  "$([ "$rc" = 0 ] && [ "$has" = 1 ] && [ "$flagx" = false ] && echo true || echo false)" \
  "rc=$rc mismatch=$has flag=$flagx"
dir="$(mcc_project block block)"
run_gated_stop codex "$dir" "$mcc_port_mutant/stop-gate.sh" 2>/dev/null || true
rc=0; run_reviewer_stop codex "$dir" "$mcc_port_mutant/stop-gate.sh" 2>/dev/null || rc=$?
has="$(records "$dir" codex 'marker-commit-check=mismatch unit=unit-block')"
flagx=false; ls "$dir/.codex"/.pending-review.* >/dev/null 2>&1 && flagx=true
check "(i-block) codex: markerCommitCheck block+mismatch -> exit 2, audit logged, flag kept" \
  "$([ "$rc" = 2 ] && [ "$has" = 1 ] && [ "$flagx" = true ] && echo true || echo false)" \
  "rc=$rc mismatch=$has flag=$flagx"
dir="$(mcc_project unavail block)"
run_gated_stop codex "$dir" "$mcc_port_no_classifier/stop-gate.sh" 2>/dev/null || true
rc=0; run_reviewer_stop codex "$dir" "$mcc_port_no_classifier/stop-gate.sh" 2>/dev/null || rc=$?
has="$(records "$dir" codex 'marker-commit-check=unavailable unit=unit-unavail')"
check "(i-unavail) codex: no classifier present -> logs marker-commit-check=unavailable, exit 0" \
  "$([ "$rc" = 0 ] && [ "$has" = 1 ] && echo true || echo false)" "rc=$rc unavail=$has"
exit "$fail"
