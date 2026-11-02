#!/usr/bin/env bash
# review-precheck.sh (st-u2): the reviewer's mechanical pre-review of <baseline>..HEAD.
# The reviewer runs it itself; its failure lines are FAIL grounds on their own.
# Writes only .claude/bookkeeping/<unit>.precheck (a copy of stdout).
# --contract is read ONLY from the baseline commit, never from the working tree: criteria run here through
# `bash -c`, so no PreToolUse hook sees them, and a copy a writer can edit must not be able to run commands.
# A contract that is not at the baseline is a failure line (`contract: not-at-baseline`), not a fallback.
# --fix-contract is the exception: it is written after the baseline, so it is read from the working tree.
set -uo pipefail
usage() { echo "usage: review-precheck.sh <unit> <baseline> [--contract <path>] [--fix-contract <path>] [--affected <path>]... [--criterion <n>] [--blast-radius]" >&2; exit 2; }
[ "$#" -ge 2 ] || usage
unit="$1"; base="$2"; shift 2
[[ "$unit" =~ ^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$ ]] || { echo "review-precheck: bad unit id: $unit" >&2; exit 2; }
contract=""; fixc=""; only=""; br=0; affected=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --contract) [ "$#" -ge 2 ] || usage; contract="$2"; shift 2 ;;
    --fix-contract) [ "$#" -ge 2 ] || usage; fixc="$2"; shift 2 ;;
    --affected) [ "$#" -ge 2 ] || usage; affected+=("$2"); shift 2 ;;
    --criterion) [ "$#" -ge 2 ] || usage; only="$2"; shift 2 ;;
    --blast-radius) br=1; shift ;;
    *) usage ;;
  esac
done
[ -z "$only" ] || [[ "$only" =~ ^[0-9]+$ ]] || usage
[ -z "$only" ] || [ -n "$contract" ] || usage
[ "$br" = 0 ] || [ -z "$only" ] || usage
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

# --contract as a repository-relative path with "." and ".." folded; an absolute path under the top is
# stripped to it. Prints nothing and returns 1 for a path outside the repository.
top_rel() {
  local p="$1" seg out=() n IFS=/
  case "$p" in "$top"/*) p="${p#"$top"/}" ;; /*) return 1 ;; esac
  read -ra segs <<< "$p"
  for seg in ${segs[@]+"${segs[@]}"}; do
    case "$seg" in
      ''|.) ;;
      ..) n=${#out[@]}; [ "$n" -gt 0 ] || return 1; out=("${out[@]:0:n-1}") ;;
      *) out+=("$seg") ;;
    esac
  done
  [ "${#out[@]}" -gt 0 ] || return 1
  printf '%s' "${out[*]}"
}
if [ -n "$contract" ]; then
  c0="$contract"; contract="$(top_rel "$c0")" || { echo "review-precheck: contract is not a path inside the repository: $c0" >&2; exit 2; }
fi

# The contract is read as it was at the baseline, so the unit cannot rewrite its own criteria. It is
# compared with HEAD, not the working tree, so an uncommitted doc edit is not the unit's change.
cfile=""
if [ -n "$contract" ]; then
  if git cat-file -e "$base:$contract" 2>/dev/null; then
    git show "$base:$contract" > "$W/contract"; cfile="$W/contract"
    if ! git show "$head:$contract" 2>/dev/null | cmp -s "$W/contract" -; then failon "contract: changed-since-baseline $contract"; fi
  elif [ -e "$contract" ] || git cat-file -e "$head:$contract" 2>/dev/null; then
    failon "contract: not-at-baseline $contract"
  else
    echo "review-precheck: contract not found: $contract" >&2; exit 2
  fi
fi

# --criterion <n>: run that one criterion only, print its line, write nothing.
crit_items() { # prints one tab-separated line per criterion: n, cmd, exit, stdout-spec, long
  us_section "$1" "Acceptance criteria" | awk '
    function flush() { if (n != "") printf "%s\t%s\t%s\t%s\t%s\n", n, cmd, ex, so, lg; n=""; cmd=""; ex=""; so=""; lg=0 }
    /^[0-9]+\. run: `/ { flush(); n=$1; sub(/\.$/, "", n); s=$0; sub(/^[0-9]+\. run: `/, "", s)
      lg = (s ~ /\(Bash tool timeout/); i=length(s); while (i > 0 && substr(s, i, 1) != "`") i--; cmd=substr(s, 1, i-1); next }
    /^[[:space:]]+exit: / { ex=$0; sub(/^[[:space:]]+exit: /, "", ex); next }
    /^[[:space:]]+stdout: / { so=$0; sub(/^[[:space:]]+stdout: /, "", so); next }
    END { flush() }'
}
# One line per output line, each in backticks, joined by " then ". A backslash, backtick, CR or tab inside a
# line is shown as \\, \`, \r or \t, so the message reads one way whatever the output holds (cos-u2).
show_lines() {
  local l first=1
  while IFS= read -r l; do
    l="${l//\\/\\\\}"; l="${l//\`/\\\`}"; l="${l//$'\r'/\\r}"; l="${l//$'\t'/\\t}"
    [ "$first" = 1 ] || printf ' then '; first=0; printf '`%s`' "$l"
  done <<< "$1"
}
run_one() { # n cmd exit spec -> one criterion line, sets rc 1 on fail, 3 on judge
  local n="$1" cmd="$2" want="$3" spec="$4" raw got rc
  # The '.' sentinel keeps every trailing newline of the output in $raw (cos-u2); $got is the old reading,
  # with all of them stripped, as $(...) alone strips them.
  raw="$(cd "$top" && timeout 590 bash -c "$cmd" < /dev/null 2>/dev/null; r=$?; printf .; exit "$r")"; rc=$?
  raw="${raw%.}"; got="$raw"; while [ "${got%$'\n'}" != "$got" ]; do got="${got%$'\n'}"; done
  if [ "$rc" = 124 ]; then echo "criterion $n: fail exit=124 timeout"; return 1; fi
  if ! [[ "$want" =~ ^[0-9]+$ ]] || [ "$rc" != "$want" ]; then echo "criterion $n: fail exit=$rc want=${want:-none}"; return 1; fi
  # "`A` then `B`" (tg-u1): two or more backticked parts are one expected stdout of several lines. The parts
  # lose their backticks, are joined by newlines and compared exactly with the output less ONE trailing
  # newline, so an extra blank line fails (cos-u2). Any run of spaces may surround then; a tab cannot reach
  # here, because crit_items hands the spec over as a tab-separated field. A part holds no backtick, so a
  # literal that only contains the word then, or text after the last part, keeps its old reading.
  local multi='^`[^`]*`( +then +`[^`]*`)+$' part='^ *(then +)?`([^`]*)`(.*)$'
  if [[ "$spec" =~ $multi ]]; then
    local rest="$spec" parts="" sep="" one="${raw%$'\n'}"
    while [[ "$rest" =~ $part ]]; do
      parts+="$sep${BASH_REMATCH[2]}"; sep=$'\n'; rest="${BASH_REMATCH[3]}"
    done
    [ "$one" = "$parts" ] && { echo "criterion $n: pass exit=$rc"; return 0; }
    echo "criterion $n: fail stdout want=$(show_lines "$parts") got=$(show_lines "$one")"; return 1
  fi
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
elif [ -n "$contract" ]; then
  say "criteria: none (the contract is not at the baseline; no criteria are read from anywhere else)"
else
  say "criteria: none (no contract; run the project's test and lint command yourself)"
fi
result=pass; [ "$fails" -gt 0 ] && result=fail
{ echo "precheck: result=$result unit=$unit range=$base..$head fails=$fails deferred=$deferred judge=$judge"; cat "$out"; } > "$W/packet"
if [ "$br" = 1 ]; then
  if brout="$(bash "$dir/blast-radius.sh" "$base" 2>/dev/null)" && [ -n "$brout" ]; then
    while IFS= read -r l || [ -n "$l" ]; do printf 'br %s\n' "$l"; done <<< "$brout" >> "$W/packet"
  else
    echo "br blast-radius: unavailable" >> "$W/packet"
  fi
fi
mkdir -p "$dot/bookkeeping" && cp "$W/packet" "$dot/bookkeeping/$unit.precheck"
cat "$W/packet"
exit 0
