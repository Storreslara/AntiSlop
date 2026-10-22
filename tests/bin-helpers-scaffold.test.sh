#!/usr/bin/env bash
# Scaffold and --update install the ladder helpers to .claude/bin/ (aof-u1).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1
git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
node "$ROOT/bin/cli.js" --personas=spec-master,task-master,reviewer,scribe >/dev/null 2>&1

FILES="ladder-tier.sh contract-guard.js contract-score.js fail-count.sh escalation-card.sh unit-bookkeeping.sh blast-radius.sh review-precheck.sh unit-size.sh"
check_files() {
  local f miss=0
  for f in $FILES; do [ -f ".claude/bin/$f" ] || miss=1; done
  [ "$miss" = 0 ]
}

if check_files; then ok "(a) nine helpers present"; else bad "(a) nine helpers present"; fi
if [ ! -e .claude/bin/harness-integrity.sh ]; then ok "(b) harness-integrity.sh absent"; else bad "(b) harness-integrity.sh absent"; fi
# rp-u7: every helper is executable in a fresh scaffold, after --update restores it, and in this repo's own index.
check_exec() {
  local f miss=0
  for f in $FILES; do [ -x ".claude/bin/$f" ] || miss=1; done
  [ "$miss" = 0 ]
}
if check_exec; then ok "(f) scaffolded helpers executable"; else bad "(f) scaffolded helpers executable"; fi
idx="$(git -C "$ROOT" ls-files -s -- .claude/bin 2>/dev/null)"
nonexec="$(printf '%s\n' "$idx" | awk 'NF && $1 != "100755" {print $4}')"
if [ -n "$idx" ] && [ -z "$nonexec" ]; then ok "(g) this repo's .claude/bin helpers are committed executable"; else bad "(g) committed without +x: ${nonexec:-no index entries}"; fi

out="$(bash .claude/bin/ladder-tier.sh u1 2>&1)"
if printf '%s\n' "$out" | grep -qE '^ladder-tier: (haiku|sonnet) n=0 ladder=[a-z,]+ reason=no-contract$'; then
  ok "(c) ladder-tier runs from .claude/bin"
else bad "(c) ladder-tier output: $out"; fi

cp "$ROOT/tests/fixtures/contract-score/v2-all-pass.md" "$TMP/c.md"
first="$(node .claude/bin/contract-guard.js "$TMP/c.md" --unit=u1 2>&1 | head -1)"
case "$first" in
  "contract-guard: "*) ok "(d) contract-guard runs from .claude/bin" ;;
  *) bad "(d) contract-guard first line: $first" ;;
esac

rm -rf .claude/bin
node "$ROOT/bin/cli.js" --update >/dev/null 2>&1
if check_files; then ok "(e) --update restores helpers"; else bad "(e) --update restores helpers"; fi
if check_exec; then ok "(h) restored helpers executable"; else bad "(h) restored helpers executable"; fi

exit "$fail"
