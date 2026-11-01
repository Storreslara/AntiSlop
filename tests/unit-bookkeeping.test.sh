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

# rv-tools: check (rules C1-C8) with the precheck stubbed through UB_PRECHECK, and flag.
cat > "$T/stub/pre" << 'STUB'
#!/usr/bin/env bash
S="$(dirname "$0")"
while [ "$#" -gt 0 ]; do [ "$1" = --criterion ] && { cat "$S/crit.$2"; exit 0; }; shift; done
cat "$S/packet"; exit "$(cat "$S/rc" 2>/dev/null || echo 0)"
STUB
PASSP='precheck: result=pass unit=uc range=a..b fails=0 deferred=0 judge=0'
mkdir -p "$HDR" "$T/repo/.claude/reviewed"
printf '.claude/*\n!.claude/agent-memory/\nc.md\nignored.txt\n' > .gitignore && git add .gitignore && g commit -q -m 'chore: ignore'
SZ='size: files=1 lines=1 binary=0'
setup() { # <lane> <first packet line> [more packet lines]; $SZ is the size line, c.md declares the packet's criteria
  printf 'lane: %s files=1 reason=paths\n' "$1" > "$HDR/uc.lane"
  { printf '%s\n' "$2"; [ -z "$SZ" ] || printf '%s\n' "$SZ"; shift 2; [ "$#" -eq 0 ] || printf '%s\n' "$@"; } > "$T/stub/packet"; echo 0 > "$T/stub/rc"
  { printf '## Affected files\n- `a.txt`\n\n## Acceptance criteria\n'; sed -n 's/^criterion \([0-9]*\):.*/\1. run: `true`/p' "$T/stub/packet"; } > c.md
  rm -f "$T/repo/.claude/reviewed/uc.fail" "$T/repo/.claude/persona-config.json"
}
ck() { UB_PRECHECK="$T/stub/pre" bash "$UB" check uc "$BASE" "$@" | head -n1; }
is_ck() { # <label> <want-first-line> [check args]
  local label="$1" want="$2" got; shift 2; got="$(ck "$@")"
  [ "$got" = "$want" ] && ok "$label $want" || bad "$label: want '$want', got '$got'"
}
setup medium "$PASSP"; is_ck "(rv-c1)" 'check: escalate unit=uc reason=not-small'
setup small "$PASSP"; echo "FAIL uc" > "$T/repo/.claude/reviewed/uc.fail"; is_ck "(rv-c2)" 'check: escalate unit=uc reason=fail-record'
setup small "$PASSP"; echo 1 > "$T/stub/rc"; is_ck "(rv-c3)" 'check: escalate unit=uc reason=precheck-error'
setup small 'garbage'; is_ck "(rv-c3) bad first line" 'check: escalate unit=uc reason=precheck-error'
setup small 'precheck: result=fail unit=uc range=a..b fails=1 deferred=0 judge=0' 'scope: fail x'
is_ck "(rv-c4)" 'check: fail unit=uc reason=precheck' --contract c.md
UB_PRECHECK="$T/stub/pre" bash "$UB" check uc "$BASE" --contract c.md | grep -qx 'scope: fail x' && ok "(rv-c4) packet printed" || bad "(rv-c4) packet missing"
setup small 'precheck: result=pass unit=uc range=a..b fails=0 deferred=0 judge=2' 'criterion 1: pass exit=0'; is_ck "(rv-c5)" 'check: escalate unit=uc reason=judge' --contract c.md
setup small 'precheck: result=pass unit=uc range=a..b fails=0 deferred=1 judge=0' 'criterion 3: deferred long'
echo 'criterion 3: fail exit=124 timeout' > "$T/stub/crit.3"; is_ck "(rv-c6)" 'check: escalate unit=uc reason=timeout' --contract c.md
echo 'criterion 3: fail exit=1 want=0' > "$T/stub/crit.3"; is_ck "(rv-c6) other failure" 'check: fail unit=uc reason=criterion-3' --contract c.md
echo 'criterion 3: pass exit=0' > "$T/stub/crit.3"; is_ck "(rv-c6) deferred pass" 'check: pass unit=uc reason=precheck' --contract c.md
setup small "$PASSP"; is_ck "(rv-c7) no command" 'check: escalate unit=uc reason=no-criteria'
echo '{"testAndLintCommand":"exit 3"}' > "$T/repo/.claude/persona-config.json"; is_ck "(rv-c7) failing command" 'check: fail unit=uc reason=test-command'
echo '{"testAndLintCommand":"exit 124"}' > "$T/repo/.claude/persona-config.json"; is_ck "(rv-c7) timeout" 'check: escalate unit=uc reason=timeout'
setup small "$PASSP" 'criterion 1: pass exit=0'
echo '{"testAndLintCommand":"exit 3"}' > "$T/repo/.claude/persona-config.json"; is_ck "(rv-c7) contract skips the command" 'check: pass unit=uc reason=precheck' --contract c.md
echo '{"testAndLintCommand":"true"}' > "$T/repo/.claude/persona-config.json"; is_ck "(rv-c8)" 'check: pass unit=uc reason=precheck'
tail -n1 "$LOG" | grep -qE "^RULING $TS unit=uc decision=small-lane check: pass precheck\$" && ok "(rv-c8) ruling appended" || bad "(rv-c8) ruling: $(tail -n1 "$LOG")"
bash "$UB" check uc 'not-a-ref' >/dev/null 2>&1; [ "$?" = 2 ] && ok "(rv-c8) bad baseline exits 2" || bad "(rv-c8) bad baseline"

# rv-harden: C2a, C2b, C4a, C5 non-numeric, C6 stdin, C7 cwd and no-criteria, flag symlink and TOCTOU.
setup small "$PASSP" 'criterion 1: pass exit=0'; is_ck "(rv-h1) with a criterion line" 'check: pass unit=uc reason=precheck' --contract c.md
setup small "$PASSP"; is_ck "(rv-h1)" 'check: escalate unit=uc reason=no-criteria' --contract c.md
setup small "$PASSP" 'sensitive: hooks/x.sh'; is_ck "(rv-h2)" 'check: escalate unit=uc reason=sensitive' --contract c.md
setup small "$PASSP" 'criterion 1: pass exit=0'; echo y >> a.txt; is_ck "(rv-h3)" 'check: fail unit=uc reason=uncommitted' --contract c.md
git checkout -q -- a.txt
setup small "$PASSP" 'criterion 1: pass exit=0'
[ "$(UB_PRECHECK="$T/stub/pre" bash "$UB" check uc HEAD --contract c.md | head -n1)" = 'check: escalate unit=uc reason=empty-range' ] && ok "(rv-h4) baseline HEAD" || bad "(rv-h4)"
setup small 'precheck: result=pass unit=uc range=a..b fails=0 deferred=0 judge=x' 'criterion 1: pass exit=0'; is_ck "(rv-h5)" 'check: escalate unit=uc reason=precheck-error' --contract c.md
cat > "$T/stub/pre2" << 'STUB'
#!/usr/bin/env bash
S="$(dirname "$0")"
while [ "$#" -gt 0 ]; do
  if [ "$1" = --criterion ]; then cat > /dev/null; cat "$S/crit.$2"; exit 0; fi; shift
done
cat "$S/packet"
STUB
setup small "${PASSP/deferred=0/deferred=2}" 'criterion 1: deferred long' 'criterion 2: deferred long'
echo 'criterion 1: pass exit=0' > "$T/stub/crit.1"; echo 'criterion 2: fail exit=1 want=0' > "$T/stub/crit.2"
[ "$(UB_PRECHECK="$T/stub/pre2" bash "$UB" check uc "$BASE" --contract c.md < /dev/zero 2>&1 | head -n1)" = 'check: fail unit=uc reason=criterion-2' ] && ok "(rv-h6) precheck stdin is /dev/null" || bad "(rv-h6)"
mkdir -p sub; setup small "$PASSP"; echo '{"testAndLintCommand":"test -f a.txt"}' > "$T/repo/.claude/persona-config.json"
[ "$(cd sub && UB_PRECHECK="$T/stub/pre" bash "$UB" check uc "$BASE" | head -n1)" = 'check: pass unit=uc reason=precheck' ] && ok "(rv-h7) command runs from the repo top" || bad "(rv-h7)"
rm -rf sub "$T/repo/.claude/persona-config.json"

# rv-harden2: C2a-C2c, C3-C5 shape, C6 count and exit=, C7 declared numbers.
is_ckb() { # <label> <want> <baseline> [check args]
  local label="$1" want="$2" b="$3" got; shift 3
  got="$(UB_PRECHECK="$T/stub/pre" bash "$UB" check uc "$b" "$@" | head -n1)"
  [ "$got" = "$want" ] && ok "$label $want" || bad "$label: want '$want', got '$got'"
}
OKP='criterion 1: pass exit=0'
setup small "$PASSP" "$OKP"; echo z > untracked.txt; is_ck "(rv-k1)" 'check: fail unit=uc reason=uncommitted' --contract c.md; rm untracked.txt
setup small "$PASSP" "$OKP"; echo z > ignored.txt; mkdir -p .claude/agent-memory; echo n > .claude/agent-memory/n.md
is_ck "(rv-k2)" 'check: pass unit=uc reason=precheck' --contract c.md; rm -rf ignored.txt .claude/agent-memory
H0="$(git rev-parse HEAD)"; g commit -q --allow-empty -m later; D1="$(git rev-parse HEAD)"; git checkout -q "$H0"
setup small "$PASSP" "$OKP"; is_ckb "(rv-k3)" 'check: escalate unit=uc reason=bad-baseline' "$D1" --contract c.md
git checkout -q -
B1="$(git rev-parse HEAD)"; echo q > q.txt; git add q.txt; g commit -q -m q; g revert --no-edit HEAD >/dev/null
setup small "$PASSP" "$OKP"; is_ckb "(rv-k4) commit and revert" 'check: escalate unit=uc reason=empty-range' "$B1" --contract c.md
SZ='size: files=0 lines=0 binary=0'; setup small "$PASSP" "$OKP"; is_ck "(rv-k4) size files=0" 'check: escalate unit=uc reason=empty-range' --contract c.md
SZ=''; setup small "$PASSP" "$OKP"; is_ck "(rv-k5) no size line" 'check: escalate unit=uc reason=precheck-error' --contract c.md
SZ='size: files=1 lines=1 binary=0'
setup small "$PASSP judge=5" "$OKP"; is_ck "(rv-k5) judge twice" 'check: escalate unit=uc reason=precheck-error' --contract c.md
setup small "${PASSP/fails=0/fails=3}" "$OKP"; is_ck "(rv-k5) pass with fails=3" 'check: escalate unit=uc reason=precheck-error' --contract c.md
setup small "${PASSP/unit=uc/unit=other}" "$OKP"; is_ck "(rv-k5) other unit" 'check: escalate unit=uc reason=precheck-error' --contract c.md
setup small "${PASSP/judge=0/judge=99999999999999999999}" "$OKP"; is_ck "(rv-k6)" 'check: escalate unit=uc reason=judge' --contract c.md
setup small "$PASSP" "$OKP"; printf '## Acceptance criteria\n1. run: `true`\n2. run: `true`\n' > c.md
is_ck "(rv-k7) declared 1,2 packet 1" 'check: escalate unit=uc reason=criteria-mismatch' --contract c.md
setup small "$PASSP" "$OKP" 'criterion 3: pass exit=0'; printf '## Acceptance criteria\n1. run: `true`\n2. run: `true`\n' > c.md
is_ck "(rv-k7) declared 1,2 packet 1,3" 'check: escalate unit=uc reason=criteria-mismatch' --contract c.md
setup small "$PASSP" 'criterion 1: fail exit=1 want=0'; is_ck "(rv-k8) fail line under fails=0" 'check: escalate unit=uc reason=precheck-error' --contract c.md
setup small "${PASSP/deferred=0/deferred=2}" 'criterion 3: deferred long'; is_ck "(rv-k8) deferred count" 'check: escalate unit=uc reason=precheck-error' --contract c.md
setup small "${PASSP/deferred=0/deferred=1}" 'criterion 3: deferred long'; echo 'criterion 3: pass' > "$T/stub/crit.3"
is_ck "(rv-k9)" 'check: fail unit=uc reason=criterion-3' --contract c.md

P1="$T/repo/.claude/.pending-review.a1"; P2="$T/repo/.claude/.pending-review.a2"
printf 'pending a1\n' > "$P1"; printf 'pending a2\n' > "$P2"
o="$(bash "$UB" flag defer 'waiting on reviewer')"; rc=$?
[ "$rc" = 0 ] && [ "$o" = 'flag: defer flags=2' ] && [ "$(sed -n 1p "$P1")" = 'defer: waiting on reviewer' ] && [ "$(sed -n 2p "$P1")" = 'pending a1' ] && [ "$(sed -n 1p "$P2")" = 'defer: waiting on reviewer' ] && ok "(rv-f1) defer rewrites the first line and keeps the content" || bad "(rv-f1) rc=$rc out=$o p1=$(cat "$P1")"
bash "$UB" flag skip '   ' >/dev/null 2>&1; r1=$?
bash "$UB" flag bogus x >/dev/null 2>&1; r2=$?
rm -f "$P1" "$P2"
bash "$UB" flag skip 'gone' >/dev/null 2>&1; r3=$?
[ "$r1" = 2 ] && [ "$r2" = 2 ] && [ "$r3" = 1 ] && ! ls "$T/repo/.claude"/.pending-review.* >/dev/null 2>&1 && ok "(rv-f2) blank reason exits 2, missing flag exits 1 and none is created" || bad "(rv-f2) r1=$r1 r2=$r2 r3=$r3"

# rv-harden flag: a symlinked flag is skipped; a flag deleted mid-write is not re-created.
printf 'real\n' > "$T/target"; ln -s "$T/target" "$P1"
o="$(bash "$UB" flag defer 'sym')"; rc=$?
[ "$rc" = 1 ] && [ "$o" = 'flag: defer flags=0' ] && [ "$(cat "$T/target")" = real ] && ok "(rv-h8) symlinked flag untouched and not counted" || bad "(rv-h8) rc=$rc out=$o"
rm -f "$P1"; printf 'pending a1\n' > "$P1"
mkdir -p "$T/shim"; printf '#!/usr/bin/env bash\nrm -f "%s"\nexec /bin/dd "$@"\n' "$P1" > "$T/shim/dd"; chmod +x "$T/shim/dd"
o="$(PATH="$T/shim:$PATH" bash "$UB" flag defer 'race')"; rc=$?
[ "$rc" = 1 ] && [ "$o" = 'flag: defer flags=0' ] && [ ! -e "$P1" ] && ok "(rv-h9) a flag deleted mid-write is not re-created" || bad "(rv-h9) rc=$rc out=$o exists=$(ls "$P1" 2>&1)"

# rv-harden end to end: the real precheck in a scratch repo whose contract is committed at the baseline.
E="$T/e2e"; mkdir -p "$E" && cd "$E" || exit 1
git init -q . && mkdir -p .claude/bookkeeping hooks docs/plans && echo '.claude/' > .gitignore
# env: POST runs after the work commit (untracked files); EMPTY=1 makes the work commit empty; DESC=1 passes a descendant baseline
e_run() { # <criteria block> <listed file>
  printf '## Affected files\n- `%s`\n\n## Acceptance criteria\n%s\n' "$2" "$1" > c.md
  git add -A . && g commit -q -m base && local b w out; b="$(git rev-parse HEAD)"
  if [ -n "${EMPTY:-}" ]; then g commit -q --allow-empty -m work; else echo x > "$2" && git add -A . && g commit -q -m work; fi
  echo 'lane: small files=1 reason=paths' > .claude/bookkeeping/ue.lane
  [ -z "${POST:-}" ] || eval "$POST"
  if [ -n "${DESC:-}" ]; then w="$(git rev-parse HEAD)"; git checkout -q "$b"; b="$w"; fi
  out="$(CLAUDE_PROJECT_DIR="$E" bash "$UB" check ue "$b" --contract c.md | head -n1)"
  [ -z "${DESC:-}" ] || git checkout -q -
  rm -f n.txt; echo "$out"
}
want() { [ "$2" = "$3" ] && ok "$1 $3" || bad "$1: want '$3', got '$2'"; }
want "(rv-e1)" "$(e_run $'1. run: `true`\n   exit: 0\n   stdout: empty' a.txt)" 'check: pass unit=ue reason=precheck'
want "(rv-e2)" "$(e_run 'none' b.txt)" 'check: escalate unit=ue reason=no-criteria'
want "(rv-e3)" "$(e_run $'1. run: `true`\n   exit: 0' hooks/x.sh)" 'check: escalate unit=ue reason=sensitive'
CRIT1=$'1. run: `true`\n   exit: 0\n   stdout: empty'
want "(rv-e4)" "$(POST='echo y > n.txt' e_run $'1. run: `test -f n.txt`\n   exit: 0\n   stdout: empty' d4.txt)" 'check: fail unit=ue reason=uncommitted'
want "(rv-e5)" "$(e_run "$CRIT1"$'\n2. run: false' d5.txt)" 'check: escalate unit=ue reason=criteria-mismatch'
want "(rv-e6)" "$(EMPTY=1 e_run "$CRIT1" d6.txt)" 'check: escalate unit=ue reason=empty-range'
want "(rv-e7)" "$(DESC=1 e_run "$CRIT1" d7.txt)" 'check: escalate unit=ue reason=bad-baseline'
want "(rv-e8)" "$(e_run "$CRIT1" docs/plans/p.md)" 'check: escalate unit=ue reason=empty-range'

exit "$fail"
