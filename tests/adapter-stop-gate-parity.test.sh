#!/usr/bin/env bash
# Payload-shape parity guard for the three stop-gate ports (issue #202,
# retargeted for gh411's core extraction: decision logic now lives in ONE
# shared file, hooks/scripts/lib/stop-gate-core.sh, copied byte-for-byte into
# each adapter - A10 proves the copies identical, so re-running every
# decision branch per port would only re-prove that byte-identity). (a)-(d)
# and (f) exercise PAYLOAD-SHAPE wiring (does each port's thin entry thread
# project_dir/dot/hook_event/agent_type into the core?) on all three ports;
# (e)/(g) mutate CODEX's core copy to prove that wiring is load-bearing.
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
# (b) a MULTI-LINE reason logs only its first line, so it still dedupes
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
# (f) flag lifecycle and the writer-dispatch marker check, on all three ports:
#     the copies are byte-identical, so these prove each entry threads its own
#     payload shape (dot-dir, event casing, identity field) into the core.
#     f0: a writer stop writes a flag, a reviewer stop clears it.
#     f1: a reviewer stop clears the flag even when a .blocked marker stands.
#     f2: a marker newer than the stamp blocks the writer stop, names it, no flag.
#     f3: a marker older than the stamp does not block; the flag is written.
#     f4: a foreign-namespace reviewer does not clear the flag.
has_flag() { ls "$1/$(dotdir_for "$2")"/.pending-review.* >/dev/null 2>&1 && echo true || echo false; }
seed_marker() {
  # seed_marker <dir> <port> <stamp time> <marker time>
  local rv="$1/$(dotdir_for "$2")/reviewed"
  touch -d "$3" "$rv/.writer-dispatch-stamp"
  printf 'PASS unit-x 2026-01-01T00:00:00Z\n' > "$rv/unit-x.pass"
  touch -d "$4" "$rv/unit-x.pass"
}
for port in $PORTS; do
  dir="$(make_project "$port" f0)"
  rc=0; run_gated_stop "$port" "$dir" 2>/dev/null || rc=$?
  f0_written="$(has_flag "$dir" "$port")"
  rc2=0; run_reviewer_stop "$port" "$dir" 2>/dev/null || rc2=$?
  check "(f0) $port: a writer stop writes the flag, a reviewer stop clears it" \
    "$([ "$rc" = 0 ] && [ "$f0_written" = true ] && [ "$rc2" = 0 ] && [ "$(has_flag "$dir" "$port")" = false ] \
       && [ "$(records "$dir" "$port" 'cleared-by=reviewer')" = 1 ] && echo true || echo false)" \
    "rc=$rc written=$f0_written rc2=$rc2"
  dir="$(make_project "$port" f1)"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  printf 'BLOCKED unit-f1 2026-01-01T00:00:00Z\n' > "$dir/$(dotdir_for "$port")/reviewed/unit-f1.blocked"
  rc=0; run_reviewer_stop "$port" "$dir" 2>/dev/null || rc=$?
  check "(f1) $port: a reviewer stop clears the flag despite a .blocked marker" \
    "$([ "$rc" = 0 ] && [ "$(has_flag "$dir" "$port")" = false ] && echo true || echo false)" "rc=$rc"
  dir="$(make_project "$port" f2)"
  seed_marker "$dir" "$port" '2026-01-01 00:00:00' '2026-01-02 00:00:00'
  rc=0; err="$(run_gated_stop "$port" "$dir" 2>&1 >/dev/null)" || rc=$?
  check "(f2) $port: a marker newer than the stamp blocks the writer stop and names it" \
    "$([ "$rc" = 2 ] && grep -qF 'unit-x.pass' <<< "$err" && [ "$(has_flag "$dir" "$port")" = false ] && echo true || echo false)" \
    "rc=$rc err=$err"
  dir="$(make_project "$port" f3)"
  seed_marker "$dir" "$port" '2026-01-02 00:00:00' '2026-01-01 00:00:00'
  rc=0; run_gated_stop "$port" "$dir" 2>/dev/null || rc=$?
  check "(f3) $port: a marker older than the stamp does not block; the flag is written" \
    "$([ "$rc" = 0 ] && [ "$(has_flag "$dir" "$port")" = true ] && echo true || echo false)" "rc=$rc"
  dir="$(make_project "$port" f4)"
  run_gated_stop "$port" "$dir" 2>/dev/null || true
  rc=0; run_gated_stop "$port" "$dir" "" other-plugin:reviewer 2>/dev/null || rc=$?
  check "(f4) $port: a foreign-namespace reviewer does not clear the flag" \
    "$([ "$rc" = 0 ] && [ "$(has_flag "$dir" "$port")" = true ] && echo true || echo false)" "rc=$rc"
done
# (e) MUTATION CONTROL (issue #202 crit. 4): revert the dedupe guard in a
#     throwaway copy of CODEX's core (not the thin entry - the logic lives
#     only there since gh411) and confirm case (a) fails against it.
mutant="$(make_mutant_copy codex mutant-codex)"
core="$mutant/lib/stop-gate-core.sh"
guard='[ "$last_logged" = "$first" ] ||'
before_n="$(grep -cF "$guard" "$core" || true)"
sed -i "s/$(printf '%s' "$guard" | sed 's/[][\\.*^$\/]/\\&/g')/false ||/" "$core"
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
# (g) MUTATION CONTROL for the marker check: neutralize its block call in a
#     throwaway copy of CODEX's core, then (f2)'s setup must stop blocking there.
g_mutant="$(make_mutant_copy codex mutant-codex-marker)"
core="$g_mutant/lib/stop-gate-core.sh"
g_before_n="$(grep -c 'block "A verdict marker appeared' "$core" || true)"
sed -i 's/^\( *\)block "A verdict marker appeared/\1: "A verdict marker appeared/' "$core"
g_after_n="$(grep -c 'block "A verdict marker appeared' "$core" || true)"
g_parses=yes; bash -n "$core" 2>/dev/null || g_parses=no
dir="$(make_project codex g-mutant)"
seed_marker "$dir" codex '2026-01-01 00:00:00' '2026-01-02 00:00:00'
rc=0; run_gated_stop codex "$dir" "$g_mutant/stop-gate.sh" 2>/dev/null || rc=$?
check "(g) mutation control: the marker block neutralized in codex's core copy, so (f2) is binding" \
  "$([ "${g_before_n:-0}" = 1 ] && [ "${g_after_n:-0}" = 0 ] && [ "$g_parses" = yes ] && [ "$rc" = 0 ] && echo true || echo false)" \
  "block before=$g_before_n after=$g_after_n parses=$g_parses rc=$rc"
exit "$fail"
