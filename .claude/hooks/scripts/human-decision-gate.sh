#!/usr/bin/env bash
# PreToolUse (Bash, Write|Edit). Blocks EVERY agent identity - reviewer
# included, empty/main-session agent_type included - from writing
# .claude/human-review/<task-id>/DECISION, the human's own resolution of a
# pending ESCALATE-TO-HUMAN packet. No grant branch and no fallback: unlike
# reviewed-path-gate.sh, no identity may ever write this file. Reads are
# allowed, EXCEPT that a read whose command text contains any backslash is
# denied - the shared lexer fails closed on every backslash, including one
# inside single quotes where it is inert. That is a known false positive, left
# open deliberately (docs/plans/2026-08-12-human-decision-gate-false-positive.md,
# Open Question 2): closing it means modelling backslash escapes in a lexer
# reviewed-path-gate.sh also depends on.
#
# One write shape IS allowed, via is_sanctioned_marker_write() below: the
# sanctioned marker-write template, which exists because the protocol requires
# a `human:` attestation to quote the DECISION path verbatim inside a
# .claude/reviewed/<task-id>.pass marker. Blocking that is what caused the
# 2026-08-12 incident.
# The marker filename (id) charclass accepts the dispatch grammar: alphanumeric/
# underscore start, then alphanumeric/underscore/hash/dot/dash. This prevents
# leading-dot ids (.task) and rejects / (no directory escape), but allows
# dots/hashes within the id (e.g., gh345.1, gh#348). Traversal is prevented by
# the charclass rejecting both / and leading dots simultaneously.
#
# No adapter port exists for this gate, following the same precedent already
# set by reviewed-path-gate.sh, which likewise has none under
# adapters/*/hooks/scripts/.
#
# The sanctioned way to discard a resolved escalation packet is
# `rm -rf .claude/human-review/<task-id>` (the whole directory) - its command
# text never spells DECISION, so it passes the substring early-exit below and
# is never routed through command_is_provably_benign() at all. A per-file
# `rm .../DECISION` is blocked for every identity, reviewer included; that is
# intended, not a defect.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/benign-command.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
audit="${project_dir}/.claude/review-audit.log"

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

# The one command shape allowed past command_is_provably_benign(): a marker
# write whose heredoc body may quote the DECISION path as inert data. Safety
# rests on four properties, together proven against a 22-case attack suite:
# only the first physical line is code and it must match end-to-end, so nothing
# rides along; the delimiter is single-quoted, which is bash's own guarantee the
# body is wholly inert; the target is a bare literal under .claude/reviewed/
# whose id charclass excludes `/` and rejects leading dots, preventing
# any traversal; and the first line equal to the delimiter must be the LAST line,
# without which a body could close the heredoc early and run whatever follows.
is_sanctioned_marker_write() {
  local cmd="$1" first delim rest line
  local re='^cat[[:space:]]+>>?[[:space:]]*[.]claude/reviewed/[A-Za-z0-9_][A-Za-z0-9_#.-]*[.](pass|fail|directed|blocked|escalated)[[:space:]]+<<'\''([A-Za-z0-9_]+)'\''$'

  while [ "${cmd: -1}" = $'\n' ]; do cmd="${cmd%$'\n'}"; done
  first="${cmd%%$'\n'*}"
  [ "$first" != "$cmd" ] || return 1
  [[ $first =~ $re ]] || return 1
  delim="${BASH_REMATCH[2]}"

  rest="${cmd#*$'\n'}"
  while :; do
    line="${rest%%$'\n'*}"
    if [ "$line" = "$rest" ]; then
      [ "$line" = "$delim" ] && return 0
      return 1
    fi
    [ "$line" = "$delim" ] && return 1
    rest="${rest#*$'\n'}"
  done
}

deny() {
  { printf '%s decision-gate-denied identity=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
      >> "$audit"; } 2>/dev/null || true
  printf "BLOCKED: '%s' may not write .claude/human-review/<task-id>/DECISION - that file records the human's own resolution of a pending escalation and no agent identity may create or modify it, reviewer included.\n" "$agent_type" >&2
  cat >&2 <<'MSG'

If you are writing a review marker whose body must quote that path verbatim,
use the sanctioned marker-write template - this gate allows it:

cat > .claude/reviewed/<task-id>.pass <<'EOF'
<marker body; the delimiter is single-quoted, so nothing here expands>
EOF

Rules: the delimiter must be single-quoted, the target a bare literal
.claude/reviewed/<id>.{pass,fail,directed,blocked,escalated}, and the
terminator the last line of the command. >> works in place of >.

Splitting the path across shell variables, or otherwise rephrasing so the
command text never spells it, is a self-authorized bypass for this gate - not
a sanctioned move. That workaround is scoped to reviewed-path-gate.sh, which
grants the reviewer an identity; this gate grants nobody. If the template does
not fit your write, report and wait instead.

To discard a resolved packet, delete the whole directory with
'rm -rf .claude/human-review/<task-id>' (its command text never spells DECISION).
MSG
  exit 2
}

if [ -z "$command" ]; then
  has_path="$(echo "$input" | jq -r '(.tool_input|type) == "object" and (.tool_input|has("file_path"))' 2>/dev/null)" || exit 0
  [ "$has_path" = true ] || exit 0
  file_path="$(echo "$input" | jq -r '.tool_input.file_path // "" | tostring' 2>/dev/null || true)"
  subject="$(normalize_path "$file_path")"
  case "$subject" in
    "$project_dir"/*) subject="${subject#"$project_dir"/}" ;;
  esac
  case "$subject" in
    .claude/human-review/*/DECISION) deny ;;
    *) exit 0 ;;
  esac
fi

case "$command" in
  *human-review*) ;;
  *) exit 0 ;;
esac
case "$command" in
  *DECISION*) ;;
  *) exit 0 ;;
esac

command_is_provably_benign "$command" && exit 0
is_sanctioned_marker_write "$command" && exit 0
deny
