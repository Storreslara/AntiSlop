#!/usr/bin/env bash
# Is this project's harness armed? Sourced, never executed. Port-invariant -
# hand-edit only here; adapters/*/hooks/scripts/lib/harness-arm.sh are
# generated copies (SHARED_HOOK_LIB_FILES in bin/cli.js), so the dot-dir is a
# parameter rather than a literal.
#
# harness_armed <project_dir> [dot_label] -> 0 armed, 1 unadapted, 2 tampered.
# "Tampered" has two independently sufficient routes: two adaptation
# witnesses - agents/*.md, plus hooks/scripts/ or reviewed/ - with the config
# absent, empty or unparseable (spec 2026-08-25-harness-trust-gaps Step 1,
# R2); OR, on its own with no directory witness left at all, the git-index
# witness below, i.e. a config absent from the working tree but still tracked
# (spec 2026-09-09-fable-gate-audit-remediation Step 2, C2).
# The witness
# test never reads persona-config.json (D1): the file that may have been
# deleted cannot also be the evidence that it should exist. Requiring
# agents/*.md is R2's false-positive mitigation - a project mid-adapt can
# have the directories before any agent file is written.
#
# The refusal names restoring the file from version control, not the
# literal `git restore`, and no self-service rebuild command, and it
# lives HERE ONLY, not copied into the six adopters (RD2a, C1.7). Every
# rebuild route was measured and rejected: one cannot reconstruct a deleted
# config at all, and the other writes protectedPaths empty, which would make
# this gate a documented tamper completion rather than a detector. Do not add
# one back.
set -euo pipefail

_harness_arm_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
# harness_arm_or_deny() calls audit_append - source it here so every caller
# gets it transitively (same rationale as lib/agent-identity.sh).
. "${_harness_arm_lib_dir}/audit-log.sh"

# Set by harness_armed() on a verdict of 2, consumed by the message below.
HARNESS_ARM_WITNESSES=""
HARNESS_ARM_STATE=""

# A tracked-but-missing persona-config.json means .claude/ was deleted or
# moved wholesale (rm -rf, mv .claude .claude.bak, git clean -fdx), taking
# both witnesses above with it. D1 still holds: this reads the git index,
# never the config's content.
_harness_arm_git_witness() {
  local project_dir="$1" dot_label="$2" config="$3"
  [ -e "$config" ] && return 1
  command -v git >/dev/null 2>&1 || return 1
  git -C "$project_dir" ls-files --error-unmatch \
    "${dot_label}/persona-config.json" >/dev/null 2>&1 || return 1
  HARNESS_ARM_WITNESSES="a git index entry for ${dot_label}/persona-config.json"
  HARNESS_ARM_STATE="absent"
  return 0
}

harness_armed() {
  local project_dir="$1" dot_label="${2:-.claude}" dot config agents second f
  dot="${project_dir}/${dot_label}"
  config="${dot}/persona-config.json"
  HARNESS_ARM_WITNESSES=""
  HARNESS_ARM_STATE=""

  if [ -s "$config" ] && jq -e . "$config" >/dev/null 2>&1; then
    return 0
  fi

  agents=""
  for f in "${dot}"/agents/*.md; do
    if [ -e "$f" ]; then agents="${dot_label}/agents/*.md"; break; fi
  done
  if [ -z "$agents" ]; then
    _harness_arm_git_witness "$project_dir" "$dot_label" "$config" && return 2
    return 1
  fi

  second=""
  if [ -d "${dot}/hooks/scripts" ]; then
    second="${dot_label}/hooks/scripts/"
  elif [ -d "${dot}/reviewed" ]; then
    second="${dot_label}/reviewed/"
  fi
  if [ -z "$second" ]; then
    _harness_arm_git_witness "$project_dir" "$dot_label" "$config" && return 2
    return 1
  fi

  HARNESS_ARM_WITNESSES="${agents} and ${second}"
  if [ ! -e "$config" ]; then
    HARNESS_ARM_STATE="absent"
  elif [ ! -s "$config" ]; then
    HARNESS_ARM_STATE="empty"
  else
    HARNESS_ARM_STATE="unparseable"
  fi
  return 2
}

_harness_arm_message() {
  cat >&2 <<EOF
antislop: harness disarmed — refusing to proceed.

This project is adapted (${HARNESS_ARM_WITNESSES} present) but ${1}/persona-config.json
is ${HARNESS_ARM_STATE}. The trust gates cannot verify their own configuration, so this
action is denied rather than silently allowed.

This file is judgment-bearing and cannot be regenerated from what is on disk:
protectedPaths, testAndLintCommand, issueTracker, gatedAgents and
humanReviewMode have no other on-disk witness. Restoring it is an operator
action, not an in-session one.

Operator: restore the file from version control — it is a tracked file — then
start a new session. If it was never committed, run /antislop:install-antislop,
whose repo scan refills those fields with you in the loop. Re-running the
plain CLI scaffold is NOT equivalent: it writes protectedPaths empty and would
leave this project's harness weaker than it was before the file went missing.
EOF
}

# harness_arm_or_deny <project_dir> [dot_label] [audit_log] - returns 0 when
# the project is armed OR unadapted (the caller then proceeds exactly as it
# did before this gate existed), and EXITS 2 when it is tampered. <audit_log>
# defaults to the review-audit.log every adopter but dispatch-hygiene.sh
# already writes its own denials to.
harness_arm_or_deny() {
  local project_dir="$1" dot_label="${2:-.claude}" audit="${3:-}" verdict=0
  harness_armed "$project_dir" "$dot_label" || verdict=$?
  [ "$verdict" = 2 ] || return 0
  _harness_arm_message "$dot_label"
  [ -n "$audit" ] || audit="${project_dir}/${dot_label}/review-audit.log"
  audit_append "$audit" "$(printf '%s harness-disarmed hook=%s state=%s' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$0" .sh)" "$HARNESS_ARM_STATE")"
  exit 2
}
