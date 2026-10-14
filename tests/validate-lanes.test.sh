#!/usr/bin/env bash
# Regression tests for tests/validate-lanes.sh (vlg-3), the opt-in parallel
# runner for tests/validate.sh. Every case builds a throwaway git tree under
# a private mktemp root, with a copy of the runner and a stub validate.sh,
# so nothing here reads or writes this checkout's own .claude/ state.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
runner="$(pwd)/tests/validate-lanes.sh"
root="$(mktemp -d)" || exit 1
trap 'rm -rf "$root"' EXIT
failures=0

# tree <name> <sections>: a git tree holding the runner and a stub suite made
# of validate.sh's preamble, <sections> and its closing summary. Prints it.
tree() {
  local t="$root/$1"
  mkdir -p "$t/tests" "$t/.claude/reviewed" "$t/tmp"
  cp "$runner" "$t/tests/validate-lanes.sh"
  { printf '#!/usr/bin/env bash\nset -uo pipefail\ncd "$(dirname "$0")/.."\nfail=0\n'
    printf '%s\n' "$2"
    printf 'echo\nif [ "$fail" -eq 0 ]; then\n  echo "All checks passed."\nelse\n  echo "One or more checks FAILED."\nfi\nexit "$fail"\n'
  } > "$t/tests/validate.sh"
  printf 'PASS old x\n' > "$t/.claude/reviewed/old.pass"
  (cd "$t" && git init -q && git add tests \
    && git -c user.name=t -c user.email=t@t commit -qm init) >/dev/null 2>&1
  printf '%s\n' "$t"
}
sec() { printf 'echo\necho "== s%s =="\n%s\n' "$1" "${2:-echo \"OK   s$1\"}"; }

# run <tree> [args]: run the tree's runner as the harness would. Sets RC, OUT.
run() {
  local t="$1"; shift
  OUT="$(cd "$t" && env -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_INNER \
    TMPDIR="$t/tmp" CLAUDE_PROJECT_DIR="$t" bash tests/validate-lanes.sh "$@" 2>&1)"
  RC=$?
}

# check <id> <description> <want-rc> <substring>...: '!' prefix = must be absent.
check() {
  local id="$1" desc="$2" want="$3" s bad=""; shift 3
  [ "$RC" = "$want" ] || bad="exit $RC, want $want"
  for s in "$@"; do
    case "$s" in
      '!'*) case "$OUT" in *"${s#!}"*) bad="${bad:+$bad; }unexpected: ${s#!}" ;; esac ;;
      *) case "$OUT" in *"$s"*) ;; *) bad="${bad:+$bad; }missing: $s" ;; esac ;;
    esac
  done
  if [ -z "$bad" ]; then
    echo "ok   ($id) $desc"
  else
    echo "FAIL ($id) $desc: $bad"
    printf '%s\n' "$OUT" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
}

t=$(tree green "$(sec 1; sec 2; sec 3)"); run "$t"
order=$(printf '%s\n' "$OUT" | grep -E '^== s[0-9] ==$' | tr -d '=s ' | tr -d '\n')
last=$(printf '%s\n' "$OUT" | grep -v '^[[:space:]]*$' | tail -n 1)
[ "$order" = 123 ] && [ "$last" = 'All checks passed.' ] || OUT="order=$order last=$last
$OUT"
check L1 'all sections pass: exit 0, header order kept, summary is the last line' 0 \
  '== lanes: 3, sections: 3,' "!order=" '!FAIL'

t=$(tree red "$(sec 1 'echo "FAIL s1"; fail=1'; sec 2)"); run "$t"
check L2 'a failing check: exit 1, later sections still run' 1 'FAIL s1' 'OK   s2' 'One or more checks FAILED.' '!All checks passed.'

t=$(tree abort "$(sec 1 'echo "half"; exit 1; echo "OK   tail"'; sec 2)"); run "$t" --lanes 2
check L3 'a section that exits early is reported as aborted, even with exit 1' 1 \
  'FAIL section 1 aborted (exit 1)' '!OK   tail' 'OK   s2'

t=$(tree rel "$(sec 1 'printf x > .claude/reviewed/relA.pass'; sec 2)"); run "$t"
check L4 'a repo-root-relative marker write is a FAIL naming the section' 1 \
  'FAIL section 1 changed' 'relA.pass' '!FAIL section 2 changed'
[ "$(ls -A "$t/.claude/reviewed")" = old.pass ] || { echo "FAIL (L4b) the source tree's marker directory changed"; failures=$((failures + 1)); }

t=$(tree env "$(sec 1 'printf x > "$CLAUDE_PROJECT_DIR/.claude/reviewed/envB.fail"'; sec 2 'echo "CPD=$CLAUDE_PROJECT_DIR"')"); run "$t"
check L5 'a CLAUDE_PROJECT_DIR marker write is a FAIL; the variable never names the source tree' 1 \
  'FAIL section 1 changed' 'envB.fail' "!CPD=$t
"
[ "$(ls -A "$t/.claude/reviewed")" = old.pass ] || { echo "FAIL (L5b) the source tree's marker directory changed"; failures=$((failures + 1)); }

g='git -c user.name=t -c user.email=t@t commit -qm lane --allow-empty || fail=1'
t=$(tree git "$(sec 1 "$g"; sec 2 "$g"; sec 3 "$g")"); head0=$(git -C "$t" rev-parse HEAD); run "$t"
[ "$(git -C "$t" rev-parse HEAD)" = "$head0" ] || OUT="source HEAD moved
$OUT"
check L6 'git commits in sections stay in the lane copies' 0 '!source HEAD moved' 'All checks passed.'

for bad in 0 9 x; do
  t=$(tree "bad$bad" "$(sec 1)"); run "$t" --lanes "$bad"
  check "L7-$bad" "--lanes $bad is refused" 2 '!All checks passed.'
done

t=$(tree linked "$(sec 1)"); rm -rf "$t/.git"; printf 'gitdir: /nonexistent\n' > "$t/.git"; run "$t"
check L8 'a linked worktree (.git is a file) is refused' 2 'is not a directory'

[ -z "$(find "$root"/*/tmp -mindepth 1 -print -quit)" ] \
  || { echo "FAIL (L9) the runner left files in TMPDIR"; failures=$((failures + 1)); }

echo
if [ "$failures" -eq 0 ]; then
  echo "All validate-lanes cases passed."
  exit 0
fi
echo "$failures validate-lanes case(s) FAILED."
exit 1
