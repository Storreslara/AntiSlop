#!/usr/bin/env bash
# PreToolUse (Bash). Attributes the caller from the top-level `agent_type`
# field and blocks Bash commands whose text touches `.claude/reviewed` (the
# PASS-marker directory) unless the caller is the reviewer, or the main
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
#
# Write-intent allowlist (docs/plans/2026-07-31-reviewed-path-gate-write-intent.md):
# past the substring early-exit, a Bash command mentioning ".claude/reviewed"
# is allowed if command_is_provably_benign() below finds it read-only or
# text-only (ls, cat, grep, gh ...) and blocked otherwise, so read-only
# inspection and prose mentions of the path are no longer collateral.
# This is advisory, not airtight - a determined agent can still obfuscate the
# path past both the substring early-exit and the allowlist (e.g. splitting it
# across a shell variable); see README.md's "Known limitations", same framing
# as the existing `sed -i` bypass caveat on protected-paths.sh.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/benign-command.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
[ -f "$config" ] || exit 0

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
subject="$command"
write_tool=""

if [ -z "$command" ]; then
  # Second input shape: Write/Edit carries `.tool_input.file_path` where Bash
  # carries `.tool_input.command`. Keyed on has(), not on emptiness: a payload
  # with no file_path key at all (NotebookEdit's `notebook_path`, say) targets
  # no file this gate owns, while a PRESENT but unusable one is a write whose
  # target cannot be read and fails closed below. A payload jq cannot read at
  # all exits 0 - the same precondition every other hook here takes.
  has_path="$(echo "$input" | jq -r '(.tool_input|type) == "object" and (.tool_input|has("file_path"))' 2>/dev/null)" || exit 0
  [ "$has_path" = true ] || exit 0
  write_tool=1
  file_path="$(echo "$input" | jq -r '.tool_input.file_path // "" | tostring' 2>/dev/null || true)"
  if [ -z "$file_path" ]; then
    # A write whose target cannot be read is not provably outside the marker
    # directory, so it is blocked rather than guessed at - including for the
    # reviewer, whose GRANT has no path to apply to here.
    echo "BLOCKED: this Write/Edit carries an empty file_path, so the marker-directory gate cannot establish where it writes. Blocked by design (this gate fails closed) - reissue the call with an explicit path." >&2
    exit 2
  fi
  # Project-root-relative, the same normalization protected-paths.sh:22-25
  # does. The match below is a substring test and holds for either form; the
  # strip keeps the block message readable.
  subject="$(normalize_path "$file_path")"
  case "$subject" in
    "$project_dir"/*) subject="${subject#"$project_dir"/}" ;;
  esac
fi

case "$subject" in
  *".claude/reviewed"*) ;;
  *) exit 0 ;;
esac

agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

# Only past the substring early-exit above: this hook fires on EVERY Bash call
# and every Write/Edit in the session, and the hot path must pay nothing for
# the audit log.
review_audit="${project_dir}/.claude/review-audit.log"
identity_drift_log "$agent_type" reviewed-path-gate "$review_audit"

if persona_matches_grant "$agent_type" reviewer; then
  exit 0
fi

# Bash-command path only: a Write or Edit into the marker directory is a write
# by definition, so there is no benign carve-out on that shape.
if [ -z "$write_tool" ] && command_is_provably_benign "$command"; then
  exit 0
fi

if [ -z "$agent_type" ]; then
  has_reviewer=""
  personas="$(jq -r '.personaSelection[]? // empty' "$config" 2>/dev/null || true)"
  while IFS= read -r persona; do
    if persona_matches_gate "$persona" reviewer; then
      has_reviewer=1
      break
    fi
  done <<< "$personas"
  if [ -z "$has_reviewer" ]; then
    # Only the reviewer writes .escalated, so a standing one under a
    # reviewer-less config proves the reviewer was deselected AFTER the
    # escalation was raised - exactly the laundering transition this closes.
    shopt -s nullglob
    escalated_markers=( "${project_dir}"/.claude/reviewed/*.escalated )
    shopt -u nullglob
    if [ "${#escalated_markers[@]}" -gt 0 ]; then
      echo "BLOCKED: this project has a standing .escalated marker with no reviewer persona selected to resolve it. The only route that resolves an escalation is the DECISION channel (per Step 1/#325's gate); if this project has permanently deselected its reviewer with a stale escalation on file, that decision belongs to a human at their own terminal, not to this fallback." >&2
      exit 2
    fi
    exit 0
  fi
  echo "BLOCKED: this project has a reviewer persona selected, so the main session/team lead may not write to .claude/reviewed/ itself - route the unit to the reviewer instead, per persona-protocol.md's Review Ownership section." >&2
  exit 2
fi

if [ -n "$write_tool" ]; then
  { printf '%s grant-denied hook=reviewed-path-gate identity=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
      >> "$review_audit"; } 2>/dev/null || true
  echo "BLOCKED: '${agent_type}' may not write '${subject}' - only the reviewer creates .pass/.fail/.blocked records in .claude/reviewed/ (or the main session/team lead, ONLY in the documented no-reviewer fallback where no reviewer persona is selected). Per persona-protocol.md's Review Ownership section. Every Write/Edit into that directory is a write by definition, so the read-only exemption that applies to Bash commands does not apply here." >&2
  exit 2
fi
{ printf '%s grant-denied hook=reviewed-path-gate identity=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
    >> "$review_audit"; } 2>/dev/null || true

echo "BLOCKED: '${agent_type}' may not write to .claude/reviewed/ via Bash - only the reviewer writes the PASS marker there (or the main session/team lead, ONLY in the documented no-reviewer fallback where no reviewer persona is selected). Per persona-protocol.md's Review Ownership section. Read-only inspection (ls, cat, grep, test ...) and text-only mentions of the path in a gh issue/pr comment ARE allowed; this command was recognized as neither, because it redirects, substitutes, runs a program that could write, or could not be lexed at all (an unbalanced quote, a backslash escape and a heredoc are never assumed benign). Note that 'git' and 'rg' are NOT allowlisted at all, whatever the subcommand - see program_allowed() for why. To land a commit whose MESSAGE discusses this path, put the message in a file and use 'git commit -F <file>', whose command text then never spells the path; to search the directory, use 'grep -r'." >&2
exit 2
