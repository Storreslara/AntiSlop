#!/usr/bin/env bash
# Non-vacuity proof for the holdout checks (spec C2.1, C2.2).
# Usage: verify-checks.sh --all | EVAL_ID
# For each fixture: two builds agree on the baseline sha; on the baseline at
# least one required check fails; after applying reference.patch every
# required check passes; no check.sh names a fixture or run path. The patch is
# applied with --recount because a contract payload turns a context line that
# holds one space into an empty line.
# Env: ABT_FIXTURES_DIR, ABT_CHECKS_ROOT override the default directories.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="$(cd "$HERE/../.." && pwd)"
FIX="${ABT_FIXTURES_DIR:-$HERE/fixtures}"
CHK="${ABT_CHECKS_ROOT:-$HERE/checks}"
FIX="$(cd "$FIX" 2>/dev/null && pwd || echo "$FIX")"
CHK="$(cd "$CHK" 2>/dev/null && pwd || echo "$CHK")"
export ABT_CHECKS_LIB="$HERE/checks/lib.sh"
arg="${1:?usage: verify-checks.sh --all | EVAL_ID}"
if [ "$arg" = "--all" ]; then
  ids=()
  for d in "$FIX"/*/; do ids+=("$(basename "$d")"); done
else
  ids=("$arg")
fi
[ "${#ids[@]}" -gt 0 ] || { echo "verify-checks: no fixtures found" >&2; exit 2; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
bad=0

# rows CHECKS_JSON: print "<required failed> <required total>".
rows() {
  python3 -I -c 'import json,sys;c=[x for x in json.loads(sys.argv[1]) if x["required"]];print(sum(1 for x in c if not x["pass"]),len(c))' "$1"
}

for id in "${ids[@]}"; do
  fx="$FIX/$id"
  ck="$CHK/$id"
  if [ ! -f "$fx/build.sh" ] || [ ! -f "$ck/check.sh" ] || [ ! -f "$fx/reference.patch" ] || [ ! -f "$fx/allowed-paths.txt" ]; then
    echo "verify: $id missing build.sh, check.sh, reference.patch or allowed-paths.txt"; bad=1; continue
  fi
  if grep -qE 'fixtures/|\.runs/' "$ck/check.sh"; then
    echo "verify: $id check.sh names a fixture or run path"; bad=1; continue
  fi
  a="$(bash "$fx/build.sh" "$T/$id-a" | tail -n1)"
  b="$(bash "$fx/build.sh" "$T/$id-b" | tail -n1)"
  if [ -z "$a" ] || [ "$a" != "$b" ]; then
    echo "verify: $id nondeterministic build ($a vs $b)"; bad=1; continue
  fi
  base_json="$(bash "$ck/check.sh" "$T/$id-a" "$a" "$a" "$fx/allowed-paths.txt")"
  read -r base_fail base_total < <(rows "$base_json")
  git -C "$T/$id-b" apply --recount "$fx/reference.patch" && git -C "$T/$id-b" add -A \
    && git -C "$T/$id-b" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m reference
  ref_json="$(bash "$ck/check.sh" "$T/$id-b" "$a" "$a" "$fx/allowed-paths.txt")"
  read -r ref_fail ref_total < <(rows "$ref_json")
  echo "verify: $id baseline-required-failures=$base_fail/$base_total reference-required-failures=$ref_fail/$ref_total"
  [[ "$base_fail" =~ ^[0-9]+$ && "$base_total" =~ ^[0-9]+$ && "$ref_fail" =~ ^[0-9]+$ && "$ref_total" =~ ^[0-9]+$ ]] || { echo "verify: $id check.sh printed no valid JSON checks"; bad=1; continue; }
  if [ "$base_total" -eq 0 ] || [ "$base_fail" -lt 1 ] || [ "$ref_fail" -ne 0 ]; then
    bad=1
  fi
done

if [ "$bad" -eq 0 ]; then echo "verify-checks: ok"; else echo "verify-checks: FAILED"; fi
exit "$bad"
