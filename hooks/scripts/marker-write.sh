#!/usr/bin/env bash
# Single-call marker-write helper: collapses the reviewer's documented
# "mkdir -p .claude/reviewed" + printf two-step (agents/reviewer.md) into one
# invocation that writes a format-valid PASS/FAIL/BLOCKED marker.
#
# NOT A HOOK. Deliberately unregistered in hooks/hooks.json, same as
# reviewer-tier.sh (see that file's header for the precedent). Lives under
# hooks/scripts/ only so tests/validate.sh's bash-syntax/executable-bit
# sweeps cover it and `node bin/cli.js --update` mirrors it to
# .claude/hooks/scripts/.
#
# The marker PATH is a required CLI argument, not derived internally: the
# invoking Bash command's own text must therefore spell .claude/reviewed/...,
# so reviewed-path-gate.sh's identity check (reviewer-only grant) still fires
# on this invocation exactly as it does on the two-call form today. See
# docs/plans/2026-08-25-agent-throughput-performance-dampeners.md, Unit C.
#
# Usage: marker-write.sh <PASS|FAIL|BLOCKED> <unit-id> <commit> <detail> <marker-path>
#   PASS:    "PASS <unit-id> <ts> commit: <commit> criteria: <detail>".
#            commit is required (a sha, or "none" for a non-git project).
#   FAIL:    "FAIL <unit-id> <ts>", then <detail> verbatim on the lines that
#            follow (the defect list). commit is unused - pass "-".
#   BLOCKED: "BLOCKED <unit-id> <ts> missing: <detail>". commit is unused -
#            pass "-".
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"
dot="${CLAUDE_PROJECT_DIR:-.}/.claude"

# Same unit-id grammar dispatch-hygiene.sh already enforces elsewhere in this
# repo: alphanumeric first character, then alphanumeric/`._#-`, <=64 chars.
UNIT_ID_RE='^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$'

usage_die() {
  echo "marker-write.sh: $1" >&2
  echo "Usage: marker-write.sh <PASS|FAIL|BLOCKED> <unit-id> <commit> <detail> <marker-path>" >&2
  exit 1
}

verdict="${1:-}"
unit_id="${2:-}"
commit="${3:-}"
detail="${4:-}"
marker_path="${5:-}"

case "$verdict" in
  PASS|FAIL|BLOCKED) ;;
  *) usage_die "verdict must be PASS, FAIL or BLOCKED, got '${verdict}'" ;;
esac

[[ "$unit_id" =~ $UNIT_ID_RE ]] || usage_die "malformed unit id '${unit_id}' (must match ${UNIT_ID_RE})"

if [ "$verdict" = PASS ] && [ -z "$commit" ]; then
  usage_die "PASS requires a commit argument (a sha, or 'none' for a non-git project)"
fi

[ -n "$marker_path" ] || usage_die "marker-path argument is required"

ext=pass
[ "$verdict" = FAIL ] && ext=fail
[ "$verdict" = BLOCKED ] && ext=blocked
expected_path=".claude/reviewed/${unit_id}.${ext}"
[ "$marker_path" = "$expected_path" ] || \
  usage_die "marker-path '${marker_path}' does not match the expected '${expected_path}' for verdict ${verdict}/unit ${unit_id}"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$(dirname "$marker_path")"

case "$verdict" in
  PASS)
    printf 'PASS %s %s commit: %s criteria: %s\n' "$unit_id" "$ts" "$commit" "$detail" > "$marker_path"
    ;;
  FAIL)
    {
      printf 'FAIL %s %s\n' "$unit_id" "$ts"
      [ -z "$detail" ] || printf '%s\n' "$detail"
    } > "$marker_path"
    ;;
  BLOCKED)
    printf 'BLOCKED %s %s missing: %s\n' "$unit_id" "$ts" "$detail" > "$marker_path"
    ;;
esac
