#!/usr/bin/env bash
# PreToolUse (Agent). Token-hygiene gate on dispatch prompts: refuses a spawn
# whose prompt inlines an artifact that already exists on disk, or that
# re-dispatches a unit the reviewer has already PASSed. Config lives in
# persona-config.json's `dispatchHygiene` (mode block|warn|off, maxPromptBytes,
# maxInlineBlockLines); every key is optional and defaults to block/30000/80.
#
# Payload fields used: `.tool_name`, `.tool_input.subagent_type` (spawn target
# identity), `.tool_input.prompt`. The caller's own `.agent_type` is
# deliberately NOT consulted - no check here depends on who is dispatching,
# only on what is being dispatched, so reading it would be dead weight.
# `subagent_type` carries an AGENT IDENTITY - a possibly-namespaced wire value
# like `antislop:lead-programmer` - so it is compared via lib/agent-identity.sh,
# never as a bare string. This is a GATE site, where a missed match must fail
# OPEN, hence the liberal matcher (same rationale as
# reviewer-route-gate.sh:40-41).
#
# Logic, in order:
#  0) fail-open preconditions -> exit 0 silently: jq parse failure, tool_name
#     other than Agent, absent/empty prompt, unadapted project (no
#     persona-config.json), mode "off".
#  1) .claude/.dispatch-override sentinel -> honored only when its content
#     starts with "override: " (logged, deleted, exit 0). An empty or
#     reason-less sentinel is deleted but NOT honored, falling through to the
#     checks - same shape as the WIP sentinel at stop-gate.sh:186-189.
#  2) H1 oversize prompt, 3) H2 inlined fenced block, 4) H3 re-dispatch of a
#     unit holding a .claude/reviewed/<id>.pass marker. H3 reads the prompt's
#     FIRST NON-BLANK LINE ONLY, so a quoted `Unit:` example in the body cannot
#     false-positive (the #155 defect shape).
#  5) every check that fired is reported; mode "block" logs blocked= and exits
#     2, mode "warn" logs warned= and exits 0.
#
# H3 is reduced protection by construction: it is correct only when the
# reviewer wrote its marker under the same id the dispatch's `Unit:` line
# names, and a missing or differently-named marker makes it fail open.
#
# Honest limit (same framing as stop-gate.sh:85-88): this cannot force a
# well-formed dispatch - an agent can split one oversize prompt into two
# under-threshold ones, or drop the `Unit:` line. `.claude/dispatch-audit.log`
# is the deterrent, not a guarantee.
set -euo pipefail
# Byte semantics: the thresholds are calibrated in bytes, and ${#prompt} counts
# characters in the ambient locale, so pin the locale rather than the units.
LC_ALL=C

. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
audit="${project_dir}/.claude/dispatch-audit.log"
override="${project_dir}/.claude/.dispatch-override"
# Spelled from the environment directly rather than via $project_dir: this is
# the one path with wire data interpolated into it (R5), so its root stays
# visible at the point the id is appended.
reviewed_dir="${CLAUDE_PROJECT_DIR:-.}/.claude/reviewed"

# A write failure here (unwritable path, full disk) must degrade to "it wasn't
# logged", never abort the gate under set -e.
log_line() {
  { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$audit"; } 2>/dev/null || true
}

# Malformed JSON leaves every field empty, so the tool_name test below is also
# the parse-failure exit.
tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
[ "$tool_name" = "Agent" ] || exit 0

prompt="$(echo "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)"
[ -n "$prompt" ] || exit 0

[ -f "$config" ] || exit 0
mode="$(jq -r '.dispatchHygiene.mode // "block"' "$config" 2>/dev/null || echo block)"
max_bytes="$(jq -r '.dispatchHygiene.maxPromptBytes // 30000' "$config" 2>/dev/null || echo 30000)"
max_lines="$(jq -r '.dispatchHygiene.maxInlineBlockLines // 80' "$config" 2>/dev/null || echo 80)"
# A hand-edited non-numeric threshold would make the arithmetic tests below
# abort under set -e, i.e. exit non-zero and block every dispatch in the
# project. Fall back to the default instead - a config typo must fail OPEN (R1).
case "$max_bytes" in ''|*[!0-9]*) max_bytes=30000 ;; esac
case "$max_lines" in ''|*[!0-9]*) max_lines=80 ;; esac
[ "$mode" = "off" ] && exit 0

target_type="$(echo "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)"
# Wire data reaching an append-only log; same scrub as stop-gate.sh:176, so it
# cannot forge a second line into the audit trail.
target="${target_type//[^a-zA-Z0-9:._-]/_}"

if [ -f "$override" ]; then
  override_content="$(head -n 1 "$override" 2>/dev/null || true)"
  rm -f "$override"
  case "$override_content" in
    "override: "*)
      log_line "override=${override_content#override: } target=${target}"
      exit 0
      ;;
    *)
      echo "Dispatch-hygiene override at ${override} carried no reason - a 'override: <reason>' line is required. Ignoring it and running the checks instead." >&2
      ;;
  esac
fi

fired=""
messages=""
fire() {
  fired="${fired}${1} "
  messages="${messages}  ${2}"$'\n'
}

# H1 - oversize prompt.
if [ "${#prompt}" -gt "$max_bytes" ]; then
  fire H1 "H1: prompt is ${#prompt} bytes, over the ${max_bytes}-byte limit. Reference the artifact by path (docs/plans/..., a file path) or by issue id instead of inlining it."
fi

# H2 - inlined artifact. Counts the interior lines of each ``` fenced block.
# Nested or ~~~ fences are deliberately not parsed (R6): the failure direction
# is under-counting, which fails open, and a correct Markdown fence parser in
# bash is its own defect surface.
in_block=0
interior=0
widest=0
while IFS= read -r line; do
  case "$line" in
    '```'*)
      if [ "$in_block" -eq 1 ]; then
        in_block=0
        if [ "$interior" -gt "$widest" ]; then widest="$interior"; fi
      else
        in_block=1
        interior=0
      fi
      ;;
    *)
      if [ "$in_block" -eq 1 ]; then interior=$((interior + 1)); fi
      ;;
  esac
done <<< "$prompt"
if [ "$widest" -ge "$max_lines" ]; then
  fire H2 "H2: prompt inlines a fenced block of ${widest} lines (limit ${max_lines}). Reference the file by path; the recipient has Read."
fi

# H3 - re-dispatch of a unit that already holds a reviewer PASS marker. Only
# gated targets are considered, so explorer/scribe/reviewer spawns are never
# touched.
gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
[ -n "$gated" ] || gated="lead-programmer"
is_gated=false
while IFS= read -r name; do
  [ -n "$name" ] && persona_matches_gate "$name" "$target_type" && is_gated=true
done <<< "$gated"

if [ "$is_gated" = true ]; then
  # FIRST NON-BLANK LINE ONLY - never a whole-body scan. Leading blank lines
  # are tolerated because a concatenated prompt commonly starts with a newline.
  first_line=""
  while IFS= read -r line; do
    if [ -n "${line//[[:space:]]/}" ]; then first_line="$line"; break; fi
  done <<< "$prompt"

  if [[ $first_line =~ ^Unit:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._#-]{0,63})[[:space:]]*$ ]]; then
    unit_id="${BASH_REMATCH[1]}"
    # Unreachable given the ERE above (no `/` in the class, and a leading
    # [A-Za-z0-9] rejects `..`), and kept deliberately: the ERE and the path
    # interpolation below are several lines apart, so a future maintainer
    # widening the character class must trip over this guard rather than
    # silently reopen the traversal (R5).
    case "$unit_id" in
      */*|*..*) ;;
      *)
        if [ -f "${reviewed_dir}/${unit_id}.pass" ]; then
          fire H3 "H3: unit ${unit_id} already passed review (.claude/reviewed/${unit_id}.pass exists) - it is done, do not re-dispatch it."
        fi
        ;;
    esac
  fi
fi

[ -n "$fired" ] || exit 0

if [ "$mode" = "warn" ]; then
  verdict="WARNING"
  key="warned"
else
  verdict="BLOCKED"
  key="blocked"
fi

{
  printf '%s: dispatch hygiene (%s) - target %s\n' "$verdict" "$fired" "${target:-unknown}"
  printf '%s' "$messages"
  printf '  Escape hatch, single use and audited: printf "override: <reason>\\n" > .claude/.dispatch-override\n'
} >&2

for check in $fired; do
  log_line "${key}=${check} target=${target}"
done

[ "$key" = "warned" ] && exit 0
exit 2
