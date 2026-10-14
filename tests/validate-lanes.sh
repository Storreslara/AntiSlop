#!/usr/bin/env bash
# Opt-in parallel runner for tests/validate.sh (vlg-2). The default merge gate
# is still `bash tests/validate.sh`, run serially; this file never changes it.
#
# Usage: bash tests/validate-lanes.sh [--lanes N]     (N: 1-8, default 3)
#
# Each lane gets its own full copy of this checkout (working tree and .git,
# minus .claude/worktrees), so every lane has a private .claude/ state tree
# and a private git index. CLAUDE_PROJECT_DIR is pointed at the lane copy,
# never at this checkout. Sections are cut out of tests/validate.sh at its
# `echo "== ` headers and claimed by whichever lane is free (heaviest first).
# Each section's output is printed in header order once every lane is done.
#
# Leak check: before and after every section, the lane copy's
# .claude/reviewed/ is fingerprinted (name, type, size and mtime of every
# entry). Any change is a FAIL naming the section. Because the copy is private to the lane, this
# sees leaks through CLAUDE_PROJECT_DIR AND writes relative to the repository
# root, with no race against a live reviewer. Section 101's nested leak guard
# is skipped here (REVIEWED_DIR_LEAK_GUARD_NESTED=1); it would re-run the
# whole suite serially inside one lane.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"

lanes=3
while [ $# -gt 0 ]; do
  case "$1" in
    --lanes) lanes="${2:-}"; shift 2 || { echo "usage: bash tests/validate-lanes.sh [--lanes N]"; exit 2; } ;;
    --lanes=*) lanes="${1#--lanes=}"; shift ;;
    *) echo "usage: bash tests/validate-lanes.sh [--lanes N]"; exit 2 ;;
  esac
done
case "$lanes" in
  [1-8]) ;;
  *) echo "FAIL --lanes must be an integer from 1 to 8 (got: $lanes)"; exit 2 ;;
esac

if [ ! -d "$root/.git" ]; then
  echo "FAIL $root/.git is not a directory (a linked worktree or no repository);"
  echo "     a lane copy would share its git index. Run from a main checkout."
  exit 2
fi

suite="$root/tests/validate.sh"
count="$(grep -c '^echo "== ' "$suite")"
end_line="$(grep -n '^if \[ "\$fail" -eq 0 \]; then$' "$suite" | tail -n 1 | cut -d: -f1)"
if [ "$count" -lt 1 ] || [ -z "$end_line" ]; then
  echo "FAIL could not find the section headers or the closing summary block in tests/validate.sh"
  exit 2
fi

work="$(mktemp -d)" || exit 2
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
# When TMPDIR lies inside the checkout, keep the work dir out of the copies.
case "$work" in "$root"/*) work_rel="${work#"$root"/}" ;; *) work_rel= ;; esac
mkdir -p "$work/sec" "$work/out" "$work/rc" "$work/leak" "$work/claim"

# Cut section i (1-based header order) into $work/sec/i.body.
awk -v dir="$work/sec" -v endl="$end_line" '
  /^echo "== / { n++ }
  n > 0 && FNR < endl { print > (dir "/" n ".body") }
' "$suite"

# Claim order: known-heavy sections first (matched on header text, so a
# renumbering only costs balance, never correctness), then the rest in order.
heavy='probe-hook-identity|unit-outcomes|human-decision gate|configless write-deny|reviewed-path gate'
order="$(awk -v re="$heavy" '/^echo "== /{n++; if ($0 ~ re) print n}' "$suite")
$(seq 1 "$count")"

fingerprint() { # <lane-root>: name, type, size and mtime of every entry
  local d="$1/.claude/reviewed"
  if [ -d "$d" ]; then
    find "$d" -mindepth 1 -printf '%P %y %s %T@\n' | sort
  else
    echo "(the .claude/reviewed/ directory itself is missing)"
  fi
}

lane() { # <k>
  local k="$1" l="$work/lane$1" i before after rc
  mkdir -p "$l"
  tar -C "$root" --exclude=./.claude/worktrees ${work_rel:+"--exclude=./$work_rel"} -cf - . \
    | tar -C "$l" -xf - || { echo 2 > "$work/lane$k.copyfail"; return; }
  rm -f "$l/.git/index.lock"
  for i in $order; do
    mkdir "$work/claim/$i" 2>/dev/null || continue
    before="$(fingerprint "$l")"
    # The section records its own $fail only if it reaches its end; a section
    # that exits early (any exit code, 1 included) leaves no rc file.
    { printf 'set -uo pipefail\ncd %q || exit 2\nfail=0\n' "$l"
      cat "$work/sec/$i.body"
      printf '\necho "$fail" > %q\nexit "$fail"\n' "$work/rc/$i"; } > "$work/sec/$i.sh"
    (cd "$l" && CLAUDE_PROJECT_DIR="$l" REVIEWED_DIR_LEAK_GUARD_NESTED=1 ANTISLOP_VALIDATE_INNER=1 \
      bash "$work/sec/$i.sh") > "$work/out/$i" 2>&1
    rc=$?
    [ -f "$work/rc/$i" ] || echo "FAIL section $i aborted (exit $rc)" >> "$work/out/$i"
    after="$(fingerprint "$l")"
    if [ "$before" != "$after" ]; then
      { echo "FAIL section $i changed the lane copy's .claude/reviewed/ (a leak via CLAUDE_PROJECT_DIR or a repo-root-relative path):"
        diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed 's/^/     /'; } >> "$work/out/$i"
      echo 1 > "$work/leak/$i"
    fi
  done
}

start=$(date +%s)
for k in $(seq 1 "$lanes"); do lane "$k" & done
wait

fail=0
for k in $(seq 1 "$lanes"); do
  [ -e "$work/lane$k.copyfail" ] && { echo "FAIL lane $k: could not copy the checkout"; fail=1; }
done
for i in $(seq 1 "$count"); do
  if [ ! -f "$work/out/$i" ]; then echo "FAIL section $i never ran"; fail=1; continue; fi
  cat "$work/out/$i"
  [ "$(cat "$work/rc/$i" 2>/dev/null)" = 0 ] || fail=1
  [ -f "$work/leak/$i" ] && fail=1
done

echo
echo "== lanes: $lanes, sections: $count, wall: $(( $(date +%s) - start ))s =="
echo "Skipped checks: $(cat "$work"/out/* 2>/dev/null | grep -c '^SKIP')"
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks FAILED."
fi
exit "$fail"
