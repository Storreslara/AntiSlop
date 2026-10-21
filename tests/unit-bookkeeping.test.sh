#!/usr/bin/env bash
# unit-bookkeeping.sh (qw-u1): one call per phase runs the tier helper, appends the mechanical RULING
# lines and writes the reviewer dispatch header. Helpers are stubbed through UB_* and all state goes
# to a temp CLAUDE_PROJECT_DIR, so the real .claude/ is never touched.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UB="$ROOT/bin/unit-bookkeeping.sh"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/stub" "$T/repo"
stub() { printf '#!/usr/bin/env bash\necho "%s"\n' "$2" > "$T/stub/$1"; }
cd "$T/repo" || exit 1
g() { git -c user.email=t@t -c user.name=t "$@"; }
git init -q . && g commit -q --allow-empty -m base
BASE="$(git rev-parse HEAD)"
printf 'x\n' > a.txt && git add a.txt && g commit -q -m 'feat(u1): a'
export CLAUDE_PROJECT_DIR="$T/repo"
LOG="$T/repo/.claude/orchestrator-rulings.log"
HDR="$T/repo/.claude/bookkeeping"
lines() { if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else echo 0; fi; }
TS='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'

stub ladder 'ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=guard-demotion'
stub guard 'contract-guard: sonnet score=5/7'
out="$(UB_LADDER="$T/stub/ladder" UB_GUARD="$T/stub/guard" bash "$UB" dispatch u1 --contract c.md)"
[ "$(printf '%s\n' "$out" | head -n1)" = 'ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=guard-demotion' ] && ok "(a) ladder line first" || bad "(a) ladder line first: $out"
printf '%s\n' "$out" | grep -qx 'model: sonnet' && ok "(a) model line" || bad "(a) model line"
printf '%s\n' "$out" | grep -qx 'guard: contract-guard: sonnet score=5/7' && ok "(a) guard line" || bad "(a) guard line"
grep -qE "^RULING $TS unit=u1 decision=contract-guard sonnet: contract-guard: sonnet score=5/7\$" "$LOG" && ok "(a) ruling" || bad "(a) ruling"
[ "$(cat "$HDR/u1.tier" 2>/dev/null)" = sonnet ] && ok "(a) tier recorded" || bad "(a) tier recorded"

stub ladder 'ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=no-contract'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u2 >/dev/null
tail -n1 "$LOG" | grep -qE "^RULING $TS unit=u2 decision=contract-guard sonnet: no-contract\$" && ok "(b) no-contract ruling" || bad "(b) no-contract ruling"

n="$(lines)"; stub ladder 'ladder-tier: haiku n=0 ladder=haiku,sonnet,opus reason=default'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u3 | grep -qx 'model: haiku' && ok "(c) model haiku" || bad "(c) model haiku"
[ "$(lines)" = "$n" ] && ok "(c) no ruling on reason=default" || bad "(c) ruling written on reason=default"

stub ladder 'nonsense'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u4 | grep -qx 'model: opus' && ok "(d) unparseable -> opus" || bad "(d) unparseable -> opus"

UB_LADDER="$T/stub/absent" bash "$UB" dispatch u5 | grep -qx 'model: opus' && ok "(e) missing -> opus" || bad "(e) missing -> opus"
tail -n1 "$LOG" | grep -qF "unit=u5 decision=helper missing: $T/stub/absent: opus" && ok "(e) helper-missing ruling" || bad "(e) helper-missing ruling"

stub ladder 'ladder-tier: EXHAUSTED n=6 ladder=haiku,sonnet,opus reason=default'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u6 | grep -qx 'model: EXHAUSTED' && ok "(f) exhausted" || bad "(f) exhausted"
[ ! -e "$HDR/u6.tier" ] && ok "(f) no tier recorded" || bad "(f) tier recorded on EXHAUSTED"

stub rtier 'sonnet'
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u1 "$BASE" > "$T/out.txt"
H="$HDR/u1.header"
[ "$(sed -n 1p "$H")" = 'Unit: u1' ] && [ "$(sed -n 2p "$H")" = 'Implementer tier: sonnet' ] && ok "(g) Unit and Implementer tier lines" || bad "(g) first two lines"
grep -qx "Range: $BASE..$(git rev-parse HEAD)" "$H" && ok "(g) range" || bad "(g) range"
grep -qx 'Reviewer model: sonnet' "$H" && ok "(g) reviewer model" || bad "(g) reviewer model"
grep -qx -- '- a.txt' "$H" && ok "(g) changed files" || bad "(g) changed files"
cmp -s "$H" "$T/out.txt" && ok "(g) stdout equals header" || bad "(g) stdout differs from header"

stub rtier 'fable'
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u1 "$BASE" | grep -qx 'Reviewer model: opus' && ok "(h) other word -> opus" || bad "(h) other word -> opus"
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u7 "$BASE" | grep -q '^Implementer tier:' && bad "(h) unknown tier line printed" || ok "(h) no Implementer tier line when unknown"

bash "$UB" dispatch '../x' >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && [ ! -e "$T/repo/.claude/x.tier" ] && ok "(i) bad unit id rejected" || bad "(i) bad unit id: rc=$rc"
bash "$UB" review u1 'not-a-ref' >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "(i) bad baseline rejected" || bad "(i) bad baseline: rc=$rc"

exit "$fail"
