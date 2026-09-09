#!/usr/bin/env bash
# PreToolUse (Write|Edit, Bash). Configless, hardcoded write-deny for the
# harness's own control surface (docs/plans/2026-08-25-harness-trust-gaps.md
# Step 2). Reads NOTHING from the harness's own persona-selection config
# file (see $persona_cfg below) - not its existence, not its content, not
# its review-gating mode switch - ever: that config sits in the protected
# set below, so the file that may be gone cannot also be this gate's own
# precondition (spec 6 D0 names this exemption explicitly). No grant
# branch, no identity exemption. Precedent: human-decision-gate.sh:2-5.
#
# SET A - denied on BOTH the Write/Edit and the Bash branch (exact path,
# project-root-relative). Each audit log's `.seal` sidecar (gh415) is
# included, since a denial the gate itself logs sits in Set A too:
#   the harness's persona-selection config file ($persona_cfg below)
#   .claude/review-audit.log[.seal]
#   .claude/dispatch-audit.log[.seal]
#   .claude/microworld-audit.log[.seal]
#   .claude/wip-audit.log[.seal]
#
# SET B - denied on Write/Edit ONLY. This is the gate's own registration
# surface: deregistering it (hooks/hooks.json), redefining it
# (harness-integrity-gate.sh itself), or reaching it via the standalone
# scaffold's registration file (.claude/settings.json).
#   hooks/hooks.json
#   .claude/settings.json
#   hooks/scripts/harness-integrity-gate.sh
#
# Set B is DELIBERATELY absent from the Bash branch - a ratified ADR-0025
# decision, not an oversight. The Bash branch is a text scan, and ADR-0025's
# standing ruling is that a gate triggered by mere word-presence in text
# necessarily fires on prose, not just write attempts: 144 tracked files
# mention `hooks/`, 1,183 occurrences, 186 of them in tests/ alone (measured
# 09cc304). Nearly every command this repo's own suites run would carry the
# token. Do NOT "fix" this by adding Set B to the Bash branch - the asymmetry
# mutation control in tests/harness-integrity-gate.test.sh exists specifically
# to catch that regression.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/benign-command.sh"

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

deny() {
  # $1 set (A|B|unknown), $2 subject, $3 human-readable surface name
  audit_append "$audit" "$(printf '%s denied hook=harness-integrity-gate set=%s subject=%s' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2")"
  echo "BLOCKED: '$2' is part of the harness's own $3 and may not be written directly by any agent identity, ever - this gate is hardcoded and configless, with no grant branch and no exemption. Per docs/plans/2026-08-25-harness-trust-gaps.md Step 2." >&2
  exit 2
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
      deny A "$subject" "audit/config surface (Set A)" ;;
    hooks/hooks.json|.claude/settings.json|hooks/scripts/harness-integrity-gate.sh)
      deny B "$subject" "gate-registration surface (Set B)" ;;
  esac
  exit 0
fi

# Bash branch: SET A ONLY (see header). Mirrors reviewed-path-gate.sh's
# mentions_marker_dir() structure, generalized to Set A's several literals:
# a raw literal `case` FIRST - the hot-path requirement pinned by line
# number in tests/harness-integrity-gate.test.sh (C2.3), because this fires
# on every Bash call in the session and a careless per-word fork is what
# costs 9ms -> 6.0s on a crafted 3000-word command
# (reviewed-path-gate.sh:63-71) - then a quote- and backslash-stripped
# test, then (only if neither hits) the per-chunk normalize_path fallback
# for obfuscated spellings (doubled slashes, `.`/`..` segments, globs,
# brace groups).
set_a_mentioned() {
  local cmd="$1" rest chunk norm g lit pre post sep=$' \t\n;|&<>()`'
  case "$cmd" in
    *"$persona_cfg"*|*"$review_log"*|*"$dispatch_log"*|*"$microworld_log"*|*"$wip_log"*)
      return 0 ;;
  esac
  rest="${cmd//$'\047'/}"; rest="${rest//$'\042'/}"; rest="${rest//\\/}"
  case "$rest" in
    *"$persona_cfg"*|*"$review_log"*|*"$dispatch_log"*|*"$microworld_log"*|*"$wip_log"*)
      return 0 ;;
    *.claude*) ;;
    *) return 1 ;;
  esac
  while :; do
    chunk="${rest%%[$sep]*}"
    case "$chunk" in
      *.claude*)
        norm="$(normalize_path "$chunk")"
        case "$norm" in
          *"$persona_cfg"*|*"$review_log"*|*"$dispatch_log"*|*"$microworld_log"*|*"$wip_log"*)
            return 0 ;;
        esac
        # A glob-metachar chunk (*, ?, [...]) that CONTAINS no Set A literal
        # as a substring can still MATCH one as a whole path (e.g. a
        # `persona*.json` glob under .claude/ matches the real persona-config
        # file without containing its name as a contiguous substring) -
        # bash's own `[[ lit == pattern ]]` glob match against each literal,
        # no fork/subshell needed. Two normalizations keep this test as
        # permissive-to-detect as the substring cases above, which match a
        # literal ANYWHERE in the chunk while `==` anchors to all of it:
        #   - the chunking above splits on shell metacharacters, not just
        #     whitespace, so a flush `;`/`|`/`>`/`)` cannot ride along on the
        #     right and defeat the match;
        #   - every Set A literal starts with `.claude/`, so re-anchoring the
        #     candidate at its first `.claude` discards left-side junk (an
        #     absolute or `$VAR/`-prefixed path, a `F=` assignment).
        # Brace groups are not glob syntax, so each `{...}` then collapses to
        # `*` - a deliberate over-approximation (every path the expansion
        # could produce is still covered, plus some that it could not),
        # matching this gate's fail-closed stance everywhere else.
        g=".claude${norm#*.claude}"
        while [[ "$g" == *'{'*'}'* ]]; do
          pre="${g%%\{*}"; post="${g#"$pre"\{}"; g="$pre*${post#*\}}"
        done
        for lit in "$persona_cfg" "$review_log" "$review_log.seal" \
                   "$dispatch_log" "$dispatch_log.seal" \
                   "$microworld_log" "$microworld_log.seal" \
                   "$wip_log" "$wip_log.seal"; do
          [[ "$lit" == $g ]] && return 0
        done
        ;;
    esac
    [ "$chunk" != "$rest" ] || return 1
    rest="${rest:${#chunk}+1}"
  done
}

# jq is not in the shared benign-command.sh allowlist (widening it there
# would loosen reviewed-path-gate.sh and human-decision-gate.sh too, out of
# this unit's scope), but a read-only `jq` query is exactly the kind of
# introspection a GUARD must keep working (e.g. `jq -r .gatedAgents` over
# $persona_cfg). Narrow, local carve-out: the WHOLE command must be a
# single `jq` invocation with no redirection, pipe, separator, or
# substitution.
is_benign_jq_read() {
  local cmd="$1" skel first bad=$';&|\n<>'
  case "$cmd" in *'`'*|*'$('*|*'<('*) return 1 ;; esac
  skel="$(command_skeleton "$cmd")" || return 1
  skel="$(mask_inert_redirections "$skel")"
  case "$skel" in *[$bad]*) return 1 ;; esac
  read -r first _ <<< "$cmd"
  [ "$first" = jq ]
}

set_a_mentioned "$command" || exit 0
command_is_provably_benign "$command" && exit 0
is_benign_jq_read "$command" && exit 0
# $command is raw, fully agent-controlled text and deny() logs it verbatim
# via audit_append - an embedded newline would forge a second line into
# .claude/review-audit.log (Set A member #2) otherwise. Flatten first, same
# idiom as stop-gate-core.sh:439-441 ("do not widen the log record to
# multiple lines instead").
deny A "$(printf '%s' "$command" | tr '\n\r' '  ')" "audit/config surface (Set A)"
