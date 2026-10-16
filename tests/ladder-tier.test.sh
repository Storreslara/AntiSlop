#!/usr/bin/env bash
# Suite for bin/ladder-tier.sh and bin/escalation-card.sh (ptr-u9a). The branch table is
# frozen (every expected line is literal); fixture projects are built in a temp dir.
set -uo pipefail
cd "$(dirname "$0")/.."
repo="$(pwd)"
tier="$repo/bin/ladder-tier.sh"
card="$repo/bin/escalation-card.sh"
fail=0

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

PASSC="$repo/tests/fixtures/contract-score/v2-all-pass.md"   # Unit: demo-2, scores haiku 7/7
FAILC="$repo/tests/fixtures/contract-score/minus-R3.md"      # Unit: demo-1, scores below 7/7
PRE=2026-10-01T00:00:00Z    # before the Haiku-default cutover 2026-10-08T17:28:48Z
POST=2026-10-20T00:00:00Z   # after it
LADDER_H=haiku,haiku,sonnet,sonnet,opus,opus
LADDER_S=sonnet,sonnet,opus,opus
LADDER_O=opus,opus

# mkproj <default tier | ABSENT | NOKEY | BADJSON> -> prints a fresh project dir
mkproj() {
  local p
  p="$(mktemp -d -p "$tmproot")"
  mkdir -p "$p/.claude/reviewed"
  case "$1" in
    ABSENT) ;;
    NOKEY) printf '{"reviewGating":{"mode":"enforce"}}\n' > "$p/.claude/persona-config.json" ;;
    BADJSON) printf '{ not json\n' > "$p/.claude/persona-config.json" ;;
    EMPTYSTR) printf '{"defaultImplementerModel":""}\n' > "$p/.claude/persona-config.json" ;;
    NULLVAL) printf '{"defaultImplementerModel":null}\n' > "$p/.claude/persona-config.json" ;;
    FALSEVAL) printf '{"defaultImplementerModel":false}\n' > "$p/.claude/persona-config.json" ;;
    *) printf '{"defaultImplementerModel":"%s"}\n' "$1" > "$p/.claude/persona-config.json" ;;
  esac
  echo "$p"
}
# addfail <proj> <unit> <count> <timestamp>
addfail() {
  local i
  for ((i = 0; i < $3; i++)); do
    printf 'FAIL %s %s\ntier: haiku\n- defect %s\n\n' "$2" "$4" "$i" >> "$1/.claude/reviewed/$2.fail"
  done
}
# check <label> <expected line> <proj> <unit> [extra args]
check() {
  local label="$1" want="$2" p="$3" u="$4" got
  shift 4
  got="$(bash "$tier" "$u" --project "$p" "$@")"
  if [ "$got" = "$want" ]; then pass "$label"; else bad "$label: expected [$want], got [$got]"; fi
}

echo "-- default tier x n (guard pass for haiku) -----------------------------------"
p="$(mkproj haiku)"
check "haiku n=0 guard pass" "ladder-tier: haiku n=0 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
p="$(mkproj haiku)"; addfail "$p" demo-2 1 "$POST"
check "haiku n=1 guard pass" "ladder-tier: haiku n=1 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
p="$(mkproj haiku)"; addfail "$p" demo-2 2 "$POST"
check "haiku n=2 guard pass" "ladder-tier: sonnet n=2 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
p="$(mkproj haiku)"; addfail "$p" demo-2 4 "$POST"
check "haiku n=4 guard pass" "ladder-tier: opus n=4 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
p="$(mkproj haiku)"; addfail "$p" demo-2 6 "$POST"
check "haiku n=6 guard pass is exhausted" "ladder-tier: EXHAUSTED n=6 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
p="$(mkproj sonnet)"
check "sonnet n=0" "ladder-tier: sonnet n=0 ladder=$LADDER_S reason=default" "$p" u1
p="$(mkproj sonnet)"; addfail "$p" u1 2 "$POST"
check "sonnet n=2" "ladder-tier: opus n=2 ladder=$LADDER_S reason=default" "$p" u1
p="$(mkproj sonnet)"; addfail "$p" u1 4 "$POST"
check "sonnet n=4 is exhausted" "ladder-tier: EXHAUSTED n=4 ladder=$LADDER_S reason=default" "$p" u1
p="$(mkproj opus)"
check "opus n=0" "ladder-tier: opus n=0 ladder=$LADDER_O reason=default" "$p" u1
p="$(mkproj opus)"; addfail "$p" u1 1 "$POST"
check "opus n=1" "ladder-tier: opus n=1 ladder=$LADDER_O reason=default" "$p" u1
p="$(mkproj opus)"; addfail "$p" u1 2 "$POST"
check "opus n=2 is exhausted" "ladder-tier: EXHAUSTED n=2 ladder=$LADDER_O reason=default" "$p" u1
p="$(mkproj bogus)"
check "bogus default n=0 resolves to opus" "ladder-tier: opus n=0 ladder=$LADDER_O reason=default" "$p" u1
p="$(mkproj bogus)"; addfail "$p" u1 2 "$POST"
check "bogus default n=2 is exhausted" "ladder-tier: EXHAUSTED n=2 ladder=$LADDER_O reason=default" "$p" u1
p="$(mkproj EMPTYSTR)"
check "empty-string default n=0 resolves to opus" "ladder-tier: opus n=0 ladder=$LADDER_O reason=default" "$p" u1
p="$(mkproj NULLVAL)"
check "null default n=0 resolves to opus" "ladder-tier: opus n=0 ladder=$LADDER_O reason=default" "$p" u1
p="$(mkproj FALSEVAL)"
check "false default n=0 resolves to opus" "ladder-tier: opus n=0 ladder=$LADDER_O reason=default" "$p" u1

echo "-- absent default resolves to the lead-programmer frontmatter model --------------"
fm="$(sed -n '1,/^---$/{s/^model: *//p}' "$repo/agents/lead-programmer.md" | head -1)"
if [ "$fm" = "haiku" ]; then pass "lead-programmer frontmatter model is haiku"; else bad "lead-programmer frontmatter model is [$fm], this table assumes haiku"; fi
p="$(mkproj ABSENT)"
check "absent config file, guard pass" "ladder-tier: haiku n=0 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
p="$(mkproj NOKEY)"
check "config without the key, guard pass" "ladder-tier: haiku n=0 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"

echo "-- pre-cutover block, expiry, guard demotion, no contract, unreadable --------------"
p="$(mkproj haiku)"; addfail "$p" demo-2 1 "$PRE"
check "pre-cutover block, haiku default" "ladder-tier: sonnet n=1 ladder=$LADDER_S reason=pre-cutover" "$p" demo-2 --contract "$PASSC"
p="$(mkproj sonnet)"; addfail "$p" u1 2 "$PRE"
check "pre-cutover block, sonnet default" "ladder-tier: opus n=2 ladder=$LADDER_S reason=pre-cutover" "$p" u1
p="$(mkproj opus)"; addfail "$p" u1 1 "$PRE"
check "pre-cutover block, opus default keeps the opus ladder" "ladder-tier: opus n=1 ladder=$LADDER_O reason=pre-cutover" "$p" u1
p="$(mkproj haiku)"; addfail "$p" demo-2 2 "$POST"
touch -t 202601010000 "$p/.claude/reviewed/demo-2.fail"
printf 'PASS demo-2 2026-01-02T00:00:00Z commit: none criteria: x\n' > "$p/.claude/reviewed/demo-2.pass"
touch -t 202601020000 "$p/.claude/reviewed/demo-2.pass"
check "expired record (newer PASS marker) counts as n=0" "ladder-tier: haiku n=0 ladder=$LADDER_H reason=expired" "$p" demo-2 --contract "$PASSC"
p="$(mkproj haiku)"
check "guard demotion" "ladder-tier: sonnet n=0 ladder=$LADDER_S reason=guard-demotion" "$p" demo-1 --contract "$FAILC"
p="$(mkproj haiku)"
check "no contract fails toward the sonnet ladder" "ladder-tier: sonnet n=0 ladder=$LADDER_S reason=no-contract" "$p" demo-2
p="$(mkproj haiku)"; printf 'not a fail header\n' > "$p/.claude/reviewed/demo-2.fail"
check "unreadable count (record with no FAIL header) is fail-closed" "ladder-tier: opus n=unknown ladder=opus reason=fail-closed" "$p" demo-2 --contract "$PASSC"
p="$(mkproj BADJSON)"
check "unreadable config is fail-closed" "ladder-tier: opus n=unknown ladder=opus reason=fail-closed" "$p" demo-2 --contract "$PASSC"

echo "-- the script writes nothing ---------------------------------------------------"
p="$(mkproj haiku)"; addfail "$p" demo-2 1 "$POST"
before="$(find "$p" -type f | sort | xargs md5sum | md5sum)"
bash "$tier" demo-2 --project "$p" --contract "$PASSC" > /dev/null
bash "$tier" --census --project "$p" > /dev/null
after="$(find "$p" -type f | sort | xargs md5sum | md5sum)"
if [ "$before" = "$after" ]; then pass "ladder-tier.sh leaves the project tree unchanged"; else bad "ladder-tier.sh changed the project tree"; fi

echo "-- census over a synthetic record set ------------------------------------------"
p="$(mkproj haiku)"; addfail "$p" ca 1 "$POST"; addfail "$p" cb 2 "$PRE"
got="$(bash "$tier" --census --project "$p")"
want="ca ladder-tier: haiku n=1 ladder=$LADDER_H reason=default
cb ladder-tier: opus n=2 ladder=$LADDER_S reason=pre-cutover"
if [ "$got" = "$want" ]; then pass "census prints one prefixed line per record"; else bad "census: expected [$want], got [$got]"; fi

echo "-- census over the real record set (n equals bin/fail-count.sh) ----------------"
real="$tmproot/census.out"
bash "$tier" --census --project . > "$real"
set -- .claude/reviewed/*.fail
if [ -f "$1" ]; then want_lines=$#; else want_lines=0; fi
got_lines="$(wc -l < "$real" | tr -d ' ')"
if [ "$got_lines" = "$want_lines" ]; then pass "census prints $got_lines lines, one per .fail record"; else bad "census prints $got_lines lines, $want_lines .fail records exist"; fi
mismatch=0
while read -r id _ _ nfield _; do
  want_n="n=$(bash "$repo/bin/fail-count.sh" "$id")"
  [ "$nfield" = "$want_n" ] || { echo "     $id: census $nfield, fail-count $want_n"; mismatch=1; }
done < "$real"
if [ "$mismatch" = 0 ]; then pass "every census n= equals bin/fail-count.sh"; else bad "a census n= differs from bin/fail-count.sh"; fi
if /usr/bin/grep -q 'reason=fail-closed' "$real"; then bad "a census line has reason=fail-closed"; else pass "no census line has reason=fail-closed"; fi

echo "-- escalation-card.sh ----------------------------------------------------------"
p="$(mkproj haiku)"
printf 'FAIL ec1 2026-10-20T00:00:00Z\ntier: haiku\n- first defect one\n- second defect one\n\nFAIL ec1 2026-10-20T01:00:00Z\ntier: sonnet\n- first defect two\n\n' > "$p/.claude/reviewed/ec1.fail"
got="$(bash "$card" ec1 "$p")"
if printf '%s\n' "$got" | /usr/bin/grep -qx 'FAIL ec1 2026-10-20T01:00:00Z' \
   && printf '%s\n' "$got" | /usr/bin/grep -qx 'tier: sonnet' \
   && printf '%s\n' "$got" | /usr/bin/grep -qF -- '- first defect two' \
   && ! printf '%s\n' "$got" | /usr/bin/grep -qF -- 'second defect one'; then
  pass "card prints each block's header, tier line and first defect line only"
else
  bad "card block lines wrong: [$got]"
fi
if printf '%s\n' "$got" | /usr/bin/grep -qiE 'debug spec|park the unit|re-dispatch with'; then bad "card prints the options"; else pass "card never prints the options"; fi
got="$(bash "$card" ptr-u8 "$p")"
if printf '%s\n' "$got" | /usr/bin/grep -qF '(no FAIL record)'; then pass "card reports a unit with no FAIL record"; else bad "card no-record line missing: [$got]"; fi
got="$(bash "$card" ptr-u8 .)"
if printf '%s\n' "$got" | /usr/bin/grep -qE '^[0-9a-f]+ .*\(ptr-u8\)'; then pass "card lists a commit subject carrying (ptr-u8)"; else bad "card lists no (ptr-u8) commit: [$got]"; fi

if [ "$fail" -eq 0 ]; then
  echo
  echo "All ladder-tier checks passed."
fi
exit "$fail"
