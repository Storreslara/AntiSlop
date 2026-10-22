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
[ -z "$(ls "$HDR" 2>/dev/null | grep '\.tier$')" ] && ok "(a) no tier file written" || bad "(a) tier file written"

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
[ -z "$(ls "$HDR" 2>/dev/null | grep '\.tier$')" ] && ok "(f) no tier file after EXHAUSTED or helper-missing" || bad "(f) tier file written"

stub rtier 'sonnet'
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u1 "$BASE" --implementer-tier sonnet > "$T/out.txt"
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

printf '#!/usr/bin/env bash\necho sonnet\nexit 1\n' > "$T/stub/rtierbad"
UB_REVIEWER_TIER="$T/stub/rtierbad" bash "$UB" review u1 "$BASE" | grep -qx 'Reviewer model: opus' && ok "(j) helper prints sonnet then exits 1 -> opus" || bad "(j) helper prints sonnet then exits 1 -> opus"
UB_REVIEWER_TIER="$T/stub/absent" bash "$UB" review u1 "$BASE" | grep -qx 'Reviewer model: opus' && ok "(j) missing helper -> opus" || bad "(j) missing helper -> opus"

stub ladder 'ladder-tier: haiku n=0 ladder=haiku,sonnet,opus reason=default'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u8 >/dev/null
o="$(UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u8 "$BASE" --implementer-tier sonnet)"
[ "$(printf '%s\n' "$o" | sed -n 2p)" = 'Implementer tier: sonnet' ] && ok "(k) ladder haiku raised to sonnet: header says sonnet" || bad "(k) raised tier: $o"

UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u9 >/dev/null
UB_LADDER="$T/stub/absent" bash "$UB" dispatch u9 >/dev/null
o="$(UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u9 "$BASE")"
printf '%s\n' "$o" | grep -qx 'Unit: u9' && ! printf '%s\n' "$o" | grep -q '^Implementer tier:' && ok "(l) no stale tier after ladder then helper-missing" || bad "(l) stale tier: $o"
o="$(UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u9 "$BASE" --implementer-tier fable)"
printf '%s\n' "$o" | grep -qx 'Unit: u9' && ! printf '%s\n' "$o" | grep -q '^Implementer tier:' && ok "(l) invalid tier omitted" || bad "(l) invalid tier: $o"
bash "$UB" review u9 "$BASE" --implementer-tier >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "(l) flag without value rejected" || bad "(l) flag without value: rc=$rc"
bash "$UB" review u9 "$BASE" --bogus x >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "(l) unknown flag rejected" || bad "(l) unknown flag: rc=$rc"

printf '#!/usr/bin/env bash\nexit 1\n' > "$T/stub/guardbad"
stub ladder 'ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=guard-demotion'
out="$(UB_LADDER="$T/stub/ladder" UB_GUARD="$T/stub/guardbad" bash "$UB" dispatch u10 --contract c.md)"
printf '%s\n' "$out" | grep -qx 'guard: guard unavailable' && ok "(m) failed guard prints a placeholder" || bad "(m) failed guard: $out"
tail -n1 "$LOG" | grep -qF 'unit=u10 decision=contract-guard sonnet: guard unavailable' && ok "(m) failed guard ruling has a placeholder" || bad "(m) failed guard ruling"

stub ladder 'other-tag: haiku n=0 ladder=haiku,sonnet,opus reason=default'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u11 | grep -qx 'model: opus' && ok "(n) wrong first field -> opus" || bad "(n) wrong first field -> opus"

# rp-u3: a ladder that prints a tier and exits non-zero yields opus, EXHAUSTED stays EXHAUSTED, the usage
# names --implementer-tier, and Range: is two full SHAs for a symbolic baseline.
printf '#!/usr/bin/env bash\necho "ladder-tier: haiku n=0 ladder=haiku,sonnet,opus reason=default"\nexit 3\n' > "$T/stub/ladderbad"
UB_LADDER="$T/stub/ladderbad" bash "$UB" dispatch u12 | grep -qx 'model: opus' && ok "(o) non-zero ladder exit -> opus" || bad "(o) non-zero ladder exit -> opus"
printf '#!/usr/bin/env bash\necho "ladder-tier: EXHAUSTED n=6 ladder=haiku,sonnet,opus reason=default"\nexit 3\n' > "$T/stub/ladderex"
UB_LADDER="$T/stub/ladderex" bash "$UB" dispatch u13 | grep -qx 'model: EXHAUSTED' && ok "(o) non-zero exit keeps EXHAUSTED" || bad "(o) non-zero exit keeps EXHAUSTED"
u="$(bash "$UB" 2>&1)"; printf '%s\n' "$u" | grep -qF 'review <unit> <baseline> [--implementer-tier <t>]' && ok "(p) usage names --implementer-tier" || bad "(p) usage omits --implementer-tier"
stub rtier 'sonnet'
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u14 HEAD~1 >/dev/null
grep -qx "Range: $BASE..$(git rev-parse HEAD)" "$HDR/u14.header" && ok "(q) symbolic baseline resolved to a full SHA" || bad "(q) $(grep '^Range:' "$HDR/u14.header")"

# rp-u10: a non-zero ladder exit records `helper failed rc=<n>: <tier>` and runs neither the guard
# demotion nor the no-contract ruling.
printf '#!/usr/bin/env bash\necho "ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=guard-demotion"\nexit 4\n' > "$T/stub/ladderdem"
stub guard 'contract-guard: sonnet score=5/7'
out="$(UB_LADDER="$T/stub/ladderdem" UB_GUARD="$T/stub/guard" bash "$UB" dispatch u15 --contract c.md)"
printf '%s\n' "$out" | grep -qx 'model: opus' && ok "(r) failed helper -> opus" || bad "(r) failed helper -> opus: $out"
printf '%s\n' "$out" | grep -q '^guard:' && bad "(r) guard ran for a failed helper" || ok "(r) no guard line"
grep -qF 'unit=u15 decision=contract-guard' "$LOG" && bad "(r) demotion ruling for a failed helper" || ok "(r) no demotion ruling"
tail -n1 "$LOG" | grep -qE "^RULING $TS unit=u15 decision=helper failed rc=4: opus\$" && ok "(r) helper-failed ruling" || bad "(r) helper-failed ruling: $(tail -n1 "$LOG")"
printf '#!/usr/bin/env bash\necho "ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=no-contract"\nexit 5\n' > "$T/stub/laddernc"
UB_LADDER="$T/stub/laddernc" bash "$UB" dispatch u16 >/dev/null
tail -n1 "$LOG" | grep -qE "^RULING $TS unit=u16 decision=helper failed rc=5: opus\$" && ok "(r) no-contract ruling skipped for a failed helper" || bad "(r) no-contract: $(tail -n1 "$LOG")"

exit "$fail"
