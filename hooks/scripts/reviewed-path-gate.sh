#!/usr/bin/env bash
# PreToolUse (Write|Edit; the Bash registration is kept for A/B harness parity
# and allows every command, lean-pipeline D5). Attributes the caller from the
# top-level `agent_type` field and blocks a Write/Edit into `.claude/reviewed`
# (the PASS-marker directory) unless the caller is the reviewer, or the main
# session/team lead in the documented no-reviewer fallback (personaSelection
# does NOT contain "reviewer" - start-feature-team.md:49-53, orchestrator.md's
# "if no reviewer persona exists"). Any other caller (lead-programmer above
# all) is blocked. Guards on persona-config.json existing, same as every other
# gate.
#
# `agent_type` carries an AGENT IDENTITY - the possibly-namespaced wire value
# "[<namespace>:]<persona-name>" - not a bare persona name. Probe A
# (docs/experiments/2026-07-probe-hook-payloads.md) established that the field
# is PRESENT on a subagent-issued Bash PreToolUse payload; it did not establish
# its value space, and the field is in fact observed arriving namespaced
# (`antislop:reviewer`). Both sides are therefore normalized through
# lib/agent-identity.sh, with the two matchers failing in opposite directions
# by design: the reviewer-may-write decision is a privilege GRANT and uses the
# conservative matcher (a foreign namespace must never inherit authority over
# the PASS markers), while the personaSelection test is a GATE and uses the
# liberal one, since a miss there only makes the main session's write allowed.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/normalize-path.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/harness-arm.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
harness_arm_or_deny "$project_dir" ".claude"
[ -f "$config" ] || exit 0

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$command" ] || exit 0

# Write/Edit carries `.tool_input.file_path`. Keyed on has(), not on
# emptiness: a payload with no file_path key at all (NotebookEdit's
# `notebook_path`, say) targets no file this gate owns, while a PRESENT but
# unusable one is a write whose target cannot be read and fails closed below.
# A payload jq cannot read at all exits 0 - the same precondition every other
# hook here takes.
has_path="$(echo "$input" | jq -r '(.tool_input|type) == "object" and (.tool_input|has("file_path"))' 2>/dev/null)" || exit 0
[ "$has_path" = true ] || exit 0
file_path="$(echo "$input" | jq -r '.tool_input.file_path // "" | tostring' 2>/dev/null || true)"
if [ -z "$file_path" ]; then
  # A write whose target cannot be read is not provably outside the marker
  # directory, so it is blocked rather than guessed at - including for the
  # reviewer, whose GRANT has no path to apply to here.
  echo "BLOCKED: this Write/Edit carries an empty file_path, so reviewed-path-gate.sh cannot establish where it writes. Blocked by design (this gate fails closed) - reissue the call with an explicit path." >&2
  exit 2
fi
# Project-root-relative, the same normalization protected-paths.sh:22-25
# does. The match below is a substring test and holds for either form; the
# strip keeps the block message readable.
subject="$(normalize_path "$file_path")"
case "$subject" in
  "$project_dir"/*) subject="${subject#"$project_dir"/}" ;;
esac

case "$subject" in
  *".claude/reviewed"*) ;;
  *) exit 0 ;;
esac

agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

# Only past the early-exit above: this hook fires on every Write/Edit in the
# session, and the hot path must pay nothing for the audit log.
review_audit="${project_dir}/.claude/review-audit.log"
identity_drift_log "$agent_type" reviewed-path-gate "$review_audit"

if persona_matches_grant "$agent_type" reviewer; then
  exit 0
fi

if [ -z "$agent_type" ] || persona_matches_gate "$agent_type" orchestrator; then
  has_reviewer=""
  personas="$(jq -r '.personaSelection[]? // empty' "$config" 2>/dev/null || true)"
  while IFS= read -r persona; do
    if persona_matches_gate "$persona" reviewer; then
      has_reviewer=1
      break
    fi
  done <<< "$personas"
  if [ -z "$has_reviewer" ]; then
    # .escalated is retired (0.32.0) and nothing writes it, so this branch
    # catches only a marker left from an older version.
    shopt -s nullglob
    escalated_markers=( "${project_dir}"/.claude/reviewed/*.escalated )
    shopt -u nullglob
    if [ "${#escalated_markers[@]}" -gt 0 ]; then
      echo "BLOCKED: this project has a standing .escalated marker and no reviewer persona selected. The marker is left from a version before 0.32.0, which retired escalation (ADR-0044); nothing resolves it any more, so a human deletes it at their own terminal." >&2
      exit 2
    fi
    exit 0
  fi
  echo "BLOCKED: this project has a reviewer persona selected, so the main session/team lead may not write to .claude/reviewed/ itself - route the unit to the reviewer instead, per persona-protocol.md's Review Ownership section." >&2
  exit 2
fi

audit_append "$review_audit" "$(printf '%s grant-denied hook=reviewed-path-gate identity=%s' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")")"
echo "BLOCKED: '${agent_type}' may not write '${subject}'; only the reviewer creates records in .claude/reviewed/ (the no-reviewer fallback excepted)." >&2
echo "Remedy: route the unit to the reviewer; Bash can search with 'grep -r' and commit with 'git commit -F <file>'. Any other route is a self-authorized bypass whether or not this gate blocks it; report and wait." >&2
echo "More: docs/harness-glossary.md — \"reviewed-path denial\"" >&2
exit 2
