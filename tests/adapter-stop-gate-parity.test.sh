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

# (e) MUTATION CONTROL for the step (issue #202 criterion 4): revert the dedupe
#     in a throwaway copy of ONE adapter script - CODEX - and confirm case (a)
#     fails there. A parity test that still passes against an unported script
#     would be worthless.
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

exit "$fail"
