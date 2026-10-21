#!/usr/bin/env bash
# review-precheck.sh (st-u2): the reviewer's mechanical pre-review of <baseline>..HEAD.
# The reviewer runs it itself; its failure lines are FAIL grounds on their own.
# Writes only .claude/bookkeeping/<unit>.precheck (a copy of stdout).
set -uo pipefail
usage() { echo "usage: review-precheck.sh <unit> <baseline> [--contract <path>] [--fix-contract <path>] [--affected <path>]... [--criterion <n>]" >&2; exit 2; }
[ "$#" -ge 2 ] || usage
unit="$1"; base="$2"; shift 2
[[ "$unit" =~ ^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$ ]] || { echo "review-precheck: bad unit id: $unit" >&2; exit 2; }
contract=""; fixc=""; only=""; affected=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --contract) [ "$#" -ge 2 ] || usage; contract="$2"; shift 2 ;;
    --fix-contract) [ "$#" -ge 2 ] || usage; fixc="$2"; shift 2 ;;
    --affected) [ "$#" -ge 2 ] || usage; affected+=("$2"); shift 2 ;;
    --criterion) [ "$#" -ge 2 ] || usage; only="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -z "$only" ] || [[ "$only" =~ ^[0-9]+$ ]] || usage
[ -z "$only" ] || [ -n "$contract" ] || usage
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib="$dir/../hooks/scripts/lib"
. "$lib/sensitive-paths.sh" 2>/dev/null || exit 2
. "$lib/unit-scope.sh" 2>/dev/null || exit 2
# An empty or cut-short library defines nothing, and an undefined function only reads as "false":
# never run on a partial class (rp-u8's fail-closed rule).
declare -F touches_sensitive_path us_section us_entries us_exclusions us_classify >/dev/null \
  || { echo "review-precheck: scope libraries incomplete under $lib" >&2; exit 2; }
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "review-precheck: not a git repository" >&2; exit 2; }
cd "$top" || exit 2
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "review-precheck: baseline does not resolve: $base" >&2; exit 2; }
head="$(git rev-parse HEAD)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
out="$W/out"; : > "$out"; fails=0; deferred=0; judge=0
say() { printf '%s\n' "$*" >> "$out"; }
failon() { say "$*"; fails=$((fails + 1)); }

# The contract is read as it was at the baseline, so the unit cannot rewrite its own criteria.
cfile=""
if [ -n "$contract" ]; then
  if git cat-file -e "$base:$contract" 2>/dev/null; then
    git show "$base:$contract" > "$W/contract"; cfile="$W/contract"
    if [ -e "$contract" ] && ! cmp -s "$W/contract" "$contract"; then failon "contract: changed-since-baseline $contract"; fi
  elif [ -f "$contract" ]; then
    cp "$contract" "$W/contract"; cfile="$W/contract"; say "contract: not-at-baseline $contract"
  else
    echo "review-precheck: contract not found: $contract" >&2; exit 2
  fi
fi

# --criterion <n>: run that one criterion only, print its line, write nothing.
crit_items() { # prints "n<TAB>cmd<TAB>exit<TAB>stdout-spec<TAB>long" per criterion
  us_section "$1" "Acceptance criteria" | awk '
    function flush() { if (n != "") printf "%s\t%s\t%s\t%s\t%s\n", n, cmd, ex, so, lg; n=""; cmd=""; ex=""; so=""; lg=0 }
    /^[0-9]+\. run: `/ { flush(); n=$1; sub(/\.$/, "", n); s=$0; sub(/^[0-9]+\. run: `/, "", s)
      lg = (s ~ /\(Bash tool timeout/); i=length(s); while (i > 0 && substr(s, i, 1) != "`") i--; cmd=substr(s, 1, i-1); next }
    /^[[:space:]]+exit: / { ex=$0; sub(/^[[:space:]]+exit: /, "", ex); next }
    /^[[:space:]]+stdout: / { so=$0; sub(/^[[:space:]]+stdout: /, "", so); next }
    END { flush() }'
}
run_one() { # n cmd exit spec -> one criterion line, sets rc 1 on fail, 3 on judge
  local n="$1" cmd="$2" want="$3" spec="$4" got rc
  got="$(cd "$top" && timeout 590 bash -c "$cmd" < /dev/null 2>/dev/null)"; rc=$?
  if [ "$rc" = 124 ]; then echo "criterion $n: fail exit=124 timeout"; return 1; fi
  if ! [[ "$want" =~ ^[0-9]+$ ]] || [ "$rc" != "$want" ]; then echo "criterion $n: fail exit=$rc want=${want:-none}"; return 1; fi
  case "$spec" in
    empty) [ -z "$got" ] && { echo "criterion $n: pass exit=$rc"; return 0; }; echo "criterion $n: fail stdout not empty"; return 1 ;;
    \`*\`) local lit="${spec#\`}"; lit="${lit%\`}"
      [ "$got" = "$lit" ] && { echo "criterion $n: pass exit=$rc"; return 0; }; echo "criterion $n: fail stdout want=$lit got=$(printf '%s' "$got" | head -n1)"; return 1 ;;
    *) echo "criterion $n: judge stdout exit=$rc"; return 3 ;;
  esac
}
if [ -n "$only" ]; then
  [ -n "$cfile" ] || usage
  line="$(crit_items "$cfile" | awk -F'\t' -v n="$only" '$1 == n')"
  [ -n "$line" ] || { echo "review-precheck: no criterion $only" >&2; exit 2; }
  IFS=$'\t' read -r n cmd want spec lg <<< "$line"
  run_one "$n" "$cmd" "$want" "$spec"; exit 0
fi

# Unit scope: the contract's `## Affected files`, plus --affected, else the lane record.
: > "$W/listed"; : > "$W/fix"; : > "$W/crit"; : > "$W/failrec"; : > "$W/excl"
[ -z "$cfile" ] || us_entries "$cfile" >> "$W/listed"
[ -z "$cfile" ] || us_exclusions "$cfile" > "$W/excl"
for a in "${affected[@]+"${affected[@]}"}"; do printf '%s\n' "$a" >> "$W/listed"; done
dot="${CLAUDE_PROJECT_DIR:-$top}/.claude"
if [ ! -s "$W/listed" ] && [ -f "$dot/bookkeeping/$unit.scope" ]; then cp "$dot/bookkeeping/$unit.scope" "$W/listed"; fi
[ -z "$fixc" ] || { [ -f "$fixc" ] && us_entries "$fixc" > "$W/fix"; }
[ -z "$cfile" ] || us_section "$cfile" "Acceptance criteria" | grep -E '^[0-9]+\. run: ' > "$W/crit" || true
[ ! -f "$dot/reviewed/$unit.fail" ] || cp "$dot/reviewed/$unit.fail" "$W/failrec"

G=(git -c core.quotepath=false -c diff.relative=false)
PS=(-- . ':(exclude).claude' ':(exclude)docs/plans')
"${G[@]}" diff --no-renames --name-only "$base..HEAD" "${PS[@]}" > "$W/changed"
[ -s "$W/listed" ] || failon "scope: no-affected-list"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  say "changed: $p"
  case "$p" in '"'*) failon "scope: out $p unquotable"; continue ;; esac
  [ -s "$W/listed" ] || continue
  c="$(us_classify "$p" "$base" "$W/listed" "$W/fix" "$W/crit" "$W/failrec" "$W/excl")"
  case "$c" in
    out) failon "scope: out $p" ;;
    excluded) failon "scope: excluded $p" ;;
    judge) say "scope: judge $p version-stamp-name"; judge=$((judge + 1)) ;;
    *) say "scope: ok $p $c" ;;
  esac
done < "$W/changed"
files=0; lines=0; binary=0
while IFS=$'\t' read -r a d p; do
  [ -n "$p" ] || continue; files=$((files + 1))
  case "$a$d" in *[!0-9]*) binary=$((binary + 1)) ;; *) lines=$((lines + a + d)) ;; esac
done < <("${G[@]}" diff --no-renames --numstat "$base..HEAD" "${PS[@]}")
say "size: files=$files lines=$lines binary=$binary"
while IFS= read -r p; do
  [ -n "$p" ] && touches_sensitive_path "$p" && say "sensitive: $p"
done < <("${G[@]}" diff --no-renames --name-only "$base..HEAD" --)
vs="$dir/../hooks/scripts/version-stamp-check.sh"
if [ -f "$vs" ]; then
  v="$(bash "$vs" "$base..HEAD" 2>/dev/null | head -n1)"
  case "$v" in "version-stamp-check: violation"*) failon "version-stamp: $v" ;; *) say "version-stamp: $v" ;; esac
fi
if [ -n "$cfile" ]; then
  while IFS=$'\t' read -r n cmd want spec lg; do
    [ -n "$n" ] || continue
    if [ "$lg" = 1 ]; then say "criterion $n: deferred long"; deferred=$((deferred + 1)); continue; fi
    l="$(run_one "$n" "$cmd" "$want" "$spec")"; rc=$?
    say "$l"
    [ "$rc" = 1 ] && fails=$((fails + 1))
    [ "$rc" = 3 ] && judge=$((judge + 1))
  done < <(crit_items "$cfile")
else
  say "criteria: none (no contract; run the project's test and lint command yourself)"
fi
result=pass; [ "$fails" -gt 0 ] && result=fail
{ echo "precheck: result=$result unit=$unit range=$base..$head fails=$fails deferred=$deferred judge=$judge"; cat "$out"; } > "$W/packet"
mkdir -p "$dot/bookkeeping" && cp "$W/packet" "$dot/bookkeeping/$unit.precheck"
cat "$W/packet"
exit 0
