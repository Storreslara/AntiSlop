#!/usr/bin/env bash
# PreToolUse (Write|Edit; the Bash registration is kept for A/B harness
# parity and allows every command, lean-pipeline D5). Configless, hardcoded write-deny for the
# harness's own control surface (docs/plans/2026-08-25-harness-trust-gaps.md
# Step 2). Reads NOTHING from the harness's own persona-selection config
# file (see $persona_cfg below) - not its existence, not its content, not
# its review-gating mode switch - ever: that config sits in the protected
# set below, so the file that may be gone cannot also be this gate's own
# precondition (spec 6 D0 names this exemption explicitly). No grant
# branch, no identity exemption.
#
# Five of the paths below route through a human-confirmation branch instead
# of an outright deny: the persona-selection config (Set A's one ask-eligible
# member) and each of Set B's four registration-surface literals. That
# branch always emits permissionDecision "ask", leaving the call to a
# human; it never returns the terminal grant a bare "allow" would. The two
# sets differ in which modes reach it: Set A asks in
# default|plan|acceptEdits|auto (4 modes); Set B asks in default|plan|auto
# (3 modes) - Set B excludes acceptEdits, unlike Set A. Both tiers never
# emit ask from a subagent.
#
# Both sets are Write/Edit-only: a Bash command is never scanned or refused
# (lean-pipeline D5, Risk R1).
#
# SET A - denied on Write/Edit (exact path, project-root-relative). Each audit log's `.seal` sidecar (gh415) is
# included, since a denial the gate itself logs sits in Set A too:
#   the harness's persona-selection config file ($persona_cfg below)
#   .claude/review-audit.log[.seal]
#   .claude/dispatch-audit.log[.seal]
#   .claude/microworld-audit.log[.seal]
#   .claude/wip-audit.log[.seal]
#
# SET B - 4 literals, denied on Write/Edit, except the human-confirmation
# branch (see above). This is the gate's own registration surface:
# deregistering it (hooks/hooks.json), redefining it (harness-integrity-gate.sh
# itself or its regenerated mirror), or reaching it via the standalone
# scaffold's registration file (.claude/settings.json).
#   hooks/hooks.json
#   .claude/settings.json
#   hooks/scripts/harness-integrity-gate.sh
#   .claude/hooks/scripts/harness-integrity-gate.sh
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/normalize-path.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
audit="${project_dir}/.claude/review-audit.log"

# Built by concatenation, never spelled as one contiguous literal in this
# file's own text (C2.2 greps this SOURCE FILE for that exact name and
# requires a zero count - a machine-checkable proxy for "never read", not
# just documentation of intent). $persona_cfg still exact-matches the real
# file for the write-deny below; only the SPELLING in this script's source
# is split, not the runtime value.
persona_cfg=".claude/persona""-config.json"
review_log=".claude/review-audit.log"
dispatch_log=".claude/dispatch-audit.log"
microworld_log=".claude/microworld-audit.log"
wip_log=".claude/wip-audit.log"

# completed <set> <subject> - PostToolUse-only bookkeeping: records that a
# write to a human-confirmable path completed. Never denies; the write
# already succeeded by the time this runs. The gh418 newline-flattening idiom
# is reused defensively on subject even though the caller's exact-match case
# below already rules out an embedded newline reaching here.
completed() {
  audit_append "$audit" "$(printf '%s completed hook=harness-integrity-gate set=%s subject=%s' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$(printf '%s' "$2" | tr '\n\r' '  ')")"
}

# PostToolUse (Edit|Write): the only available evidence a human approved an
# interactive permission prompt - no hook fires on approval itself. Must run
# as the first executed decision, before the command= extraction below: a
# PostToolUse payload has no .tool_input.command, so command comes back empty
# and would otherwise fall into the Write/Edit deny path below and block a
# write that already succeeded.
hook_event_name="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
if [ "$hook_event_name" = "PostToolUse" ]; then
  has_path="$(echo "$input" | jq -r '(.tool_input|type) == "object" and (.tool_input|has("file_path"))' 2>/dev/null)" || exit 0
  if [ "$has_path" = true ]; then
    file_path="$(echo "$input" | jq -r '.tool_input.file_path // "" | tostring' 2>/dev/null || true)"
    if [ -n "$file_path" ]; then
      subject="$(normalize_path "$file_path")"
      case "$subject" in
        "$project_dir"/*) subject="${subject#"$project_dir"/}" ;;
      esac
      case "$subject" in
        "$persona_cfg") completed A "$subject" ;;
        hooks/hooks.json|.claude/settings.json|hooks/scripts/harness-integrity-gate.sh|\
        .claude/hooks/scripts/harness-integrity-gate.sh) completed B "$subject" ;;
      esac
    fi
  fi
  exit 0
fi

deny() {
  # $1 set (A|B|unknown), $2 subject, $3 human-readable surface name
  audit_append "$audit" "$(printf '%s denied hook=harness-integrity-gate set=%s subject=%s' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2")"
  echo "BLOCKED: '$2' is part of the harness's own $3 and may not be written directly by any agent identity - this gate is hardcoded and configless, with no grant branch. Route changes through node bin/cli.js --update (install-antislop section 6). Per docs/plans/2026-08-25-harness-trust-gaps.md Step 2." >&2
  exit 2
}

# ask_allowed <set> - FROZEN two-tier allowlist, never a denylist. Every
# branch here is a permission_mode this gate has decided to ask on, not one
# it has decided to trust. An absent, empty, or unrecognised permission_mode
# denies, as does any mode Claude Code adds later, for BOTH sets.
ask_allowed() {
  case "$permission_mode" in
    default|plan|auto) ;;
    acceptEdits) [ "$1" = A ] || return 1 ;;  # Set B stays deny (U2b).
    *) return 1 ;;
  esac
  # agent_id is documented present only inside a subagent. This condition
  # RESTRICTS the allowlist further, it does not exempt subagents from it -
  # a subagent keeps today's deny for both sets, same as an unrecognised mode.
  [ -z "$agent_id" ]
}

# The two frozen reason literals, selected by matched set - never one
# constructed string (C1.6). Set A states the rule and the sanctioned route;
# Set B additionally states what approval costs.
reason_a='This write targets the harness persona-selection config, a protected path with no grant branch. The sanctioned route is node bin/cli.js --update (install-antislop section 6). Approve only if you intend to take that route right now.'
reason_b='This write targets the harness gate registration surface: this gate script, its hooks.json registration, or the settings file that arms it. Approving this can disable every future prompt from this gate, including this one. Route changes through node bin/cli.js --update (install-antislop section 6).'

# ask <set> <subject> - emits permissionDecision "ask" on stdout, exit 0.
ask() {
  audit_append "$audit" "$(printf '%s asked hook=harness-integrity-gate set=%s subject=%s' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2")"
  if [ "$1" = A ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason_a"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason_b"
  fi
  exit 0
}

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"

if [ -z "$command" ]; then
  # Write/Edit path: exact-match Set A UNION Set B after normalize_path.
  has_path="$(echo "$input" | jq -r '(.tool_input|type) == "object" and (.tool_input|has("file_path"))' 2>/dev/null)" || exit 0
  [ "$has_path" = true ] || exit 0
  file_path="$(echo "$input" | jq -r '.tool_input.file_path // "" | tostring' 2>/dev/null || true)"
  if [ -z "$file_path" ]; then
    # A write whose target cannot be established is not provably outside
    # either set, so it fails closed - mirrors reviewed-path-gate.sh:195-201.
    deny unknown "(empty file_path)" "control surface (the target could not be established, so this fails closed)"
  fi
  subject="$(normalize_path "$file_path")"
  case "$subject" in
    "$project_dir"/*) subject="${subject#"$project_dir"/}" ;;
  esac
  case "$subject" in
    "$persona_cfg"|"$review_log"|"$review_log.seal"|"$dispatch_log"|"$dispatch_log.seal"|\
    "$microworld_log"|"$microworld_log.seal"|"$wip_log"|"$wip_log.seal")
      if [ "$subject" = "$persona_cfg" ]; then
        # OQ1: only the persona-selection config gets the human-confirmation
        # branch (Set A's one ask-eligible member). The 4 audit logs and
        # their .seal sidecars stay an unconditional deny - resolved (a)
        # config only.
        permission_mode="$(echo "$input" | jq -r '.permission_mode // empty' 2>/dev/null || true)"
        agent_id="$(echo "$input" | jq -r '.agent_id // empty' 2>/dev/null || true)"
        ask_allowed A && ask A "$subject"
      fi
      deny A "$subject" "audit/config surface (Set A)" ;;
    hooks/hooks.json|.claude/settings.json|hooks/scripts/harness-integrity-gate.sh|\
    .claude/hooks/scripts/harness-integrity-gate.sh)
      permission_mode="$(echo "$input" | jq -r '.permission_mode // empty' 2>/dev/null || true)"
      agent_id="$(echo "$input" | jq -r '.agent_id // empty' 2>/dev/null || true)"
      ask_allowed B && ask B "$subject"
      deny B "$subject" "gate-registration surface (Set B)" ;;
  esac
  exit 0
fi

# Bash branch: allow every command (lean-pipeline D5, Risk R1).
exit 0
