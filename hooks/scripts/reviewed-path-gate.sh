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
# Collateral, accepted per the plan: any Bash command whose text merely
# CONTAINS the substring ".claude/reviewed" is blocked, including read-only
# ones (e.g. `cat .claude/reviewed/foo.pass`) - personas have the Read tool
# for that, and the block message says so. This is advisory, not airtight -
# a determined agent could obfuscate the path past the substring match; see
# README.md's "Known limitations", same framing as the existing `sed -i`
# bypass caveat on protected-paths.sh.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"

# $1 first word of a segment, $2 its second word (only consulted for `git`).
# Allowlist-shaped on purpose: anything unrecognized is NOT allowed, so the
# gate keeps failing closed for command forms nobody enumerated.
program_allowed() {
  case "$1" in
    ls|cat|head|tail|wc|stat|file|test|'['|grep|rg|diff|cmp) return 0 ;;
    sha256sum|md5sum|basename|dirname|readlink|realpath) return 0 ;;
    echo|printf|gh) return 0 ;;
    git) case "$2" in commit|log|show|diff|status|tag|blame) return 0 ;; esac ;;
  esac
  return 1
}

# A command is provably benign only if it can neither redirect nor run text as
# code, AND every segment of it invokes an allowlisted program.
command_is_provably_benign() {
  local cmd="$1" normalized seg first sub
  case "$cmd" in
    *'>'*|*'`'*|*'$('*) return 1 ;;
  esac
  if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])(eval|exec|source)([^[:alnum:]_]|$)'; then
    return 1
  fi
  normalized="${cmd//&&/;}"
  normalized="${normalized//|/;}"
  while IFS= read -r seg; do
    read -r first sub _ <<< "$seg"
    [ -n "$first" ] || continue
    program_allowed "$first" "$sub" || return 1
  done < <(printf '%s\n' "$normalized" | tr ';' '\n')
  return 0
}

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
[ -f "$config" ] || exit 0

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
case "$command" in
  *".claude/reviewed"*) ;;
  *) exit 0 ;;
esac

agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

# Only past the substring early-exit above: this hook fires on EVERY Bash call
# in the session, and the hot path must pay nothing for the audit log.
review_audit="${project_dir}/.claude/review-audit.log"
identity_drift_log "$agent_type" reviewed-path-gate "$review_audit"

if persona_matches_grant "$agent_type" reviewer; then
  exit 0
fi

if command_is_provably_benign "$command"; then
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
    exit 0
  fi
  echo "BLOCKED: this project has a reviewer persona selected, so the main session/team lead may not write to .claude/reviewed/ itself - route the unit to the reviewer instead, per persona-protocol.md's Review Ownership section." >&2
  exit 2
fi

echo "BLOCKED: '${agent_type}' may not write to .claude/reviewed/ via Bash - only the reviewer writes the PASS marker there (or the main session/team lead, ONLY in the documented no-reviewer fallback where no reviewer persona is selected). Per persona-protocol.md's Review Ownership section. Read-only inspection (ls, cat, grep, test ...) and text-only mentions of the path (gh, git commit -m) ARE allowed; this command was recognized as neither, because it redirects, substitutes, or runs a program that could write." >&2
exit 2
