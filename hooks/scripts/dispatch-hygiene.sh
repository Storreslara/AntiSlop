#!/usr/bin/env bash
# PreToolUse (Agent). Token-hygiene gate on dispatch prompts: refuses a spawn
# whose prompt inlines an artifact that already exists on disk, that
# re-dispatches a unit the reviewer has already PASSed, or that sends a gated
# target something other than the nine-element dispatch contract. Config lives
# in persona-config.json's `dispatchHygiene` (mode block|warn|off,
# maxPromptBytes, maxInlineBlockLines, requireContract); every key is optional
# and defaults to block/30000/80/true.
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
#     checks - same shape as the WIP sentinel at stop-gate.sh:186-189. When a
#     valid override is honored, a stamp is written to .claude/.dispatch-override.consumed
#     containing epoch-seconds, a dispatch-identity key (cksum-based, not
#     cryptographic, and bound to subagent_type as well as the prompt so the
#     same prompt to a different target is never treated as a replay of it),
#     and the reason. A sibling dispatch within the window with the same key
#     honours the stamp (exit 0, logged as override-replay= for audit
#     distinction) without re-consuming the sentinel. The window is a
#     10-second forward bound plus 2 seconds of backward slack for clock/
#     scheduler skew between parallel dispatches (effective span [-2, +10]).
#     A stamp is deleted only once it is genuinely PAST that window; an
#     unparseable or key-mismatched-but-fresh stamp is left alone and simply
#     not honoured, so an unrelated in-window dispatch can never destroy a
#     live sibling's stamp.
#  2) H1 oversize prompt, 3) H2 inlined fenced block, 4) H3 re-dispatch of a
#     unit holding a .claude/reviewed/<id>.pass marker. H3 reads the prompt's
#     FIRST NON-BLANK LINE ONLY, so a quoted `Unit:` example in the body cannot
#     false-positive (the #155 defect shape). H3 also reads the MARKER's first
#     line for a `commit: <sha>` field: only a marker whose SHA git can
#     positively prove is unreachable from HEAD declines to fire; every other
#     case - no field, `commit: none`, a malformed token, no git repo, or a
#     reachable SHA - still fires.
#  5) H4 a gated dispatch missing any of the nine dispatch-contract markers
#     agents/task-master.md defines. Gated targets only, and disarmed by
#     `requireContract: false`.
#  6) every check that fired is reported; mode "block" logs blocked= and exits
#     2, mode "warn" logs warned= and exits 0.
#
# H3 is reduced protection by construction: it is correct only when the
# reviewer wrote its marker under the same id the dispatch's `Unit:` line
# names, and a missing or differently-named marker makes it fail open. The
# commit-anchored check narrows this only in the provably-safe direction: it
# can decline to fire when a marker's `commit:` SHA is positively proven
# unreachable from HEAD, never the reverse - anything it cannot verify (no
# field, a malformed token, no git repo) still fires.
#
# H4 checks LABELS, NOT SUBSTANCE. It can force a well-LABELLED dispatch, never
# a well-FORMED one: an agent can emit all nine headings and fill them with
# nothing, and H4 will pass it. Presence is matched as a plain substring
# anywhere in the prompt, so the failure direction is under-firing, i.e. open.
#
# Escape-hatch fail-open floor: if .dispatch-override.consumed cannot be
# written (disk full, unwritable path), the first invocation still honours and
# the sibling still blocks - i.e. no worse than today's single-use-only
# behaviour. Write failures are silent and never abort the hook under
# set -euo pipefail.
#
# Honest limit (same framing as stop-gate.sh:85-88): this cannot force a
# well-formed dispatch - an agent can split one oversize prompt into two
# under-threshold ones, drop the `Unit:` line, or emit empty contract headings.
# `.claude/dispatch-audit.log` is the deterrent, not a guarantee.
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
# NOT `// true`: jq's alternative operator treats a literal `false` the same as
# absent, so `.requireContract // true` would silently ignore the opt-out. Read
# the raw value and let the case below supply the default - which also gives a
# hand-edited non-boolean the same fail-to-the-default treatment as above.
require_contract="$(jq -r '.dispatchHygiene.requireContract' "$config" 2>/dev/null || echo true)"
case "$require_contract" in false) ;; *) require_contract=true ;; esac
[ "$mode" = "off" ] && exit 0

target_type="$(echo "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)"
# Wire data reaching an append-only log; same scrub as stop-gate.sh:176, so it
# cannot forge a second line into the audit trail.
target="${target_type//[^a-zA-Z0-9:._-]/_}"

# Compute dispatch identity key: cksum of subagent_type+prompt (POSIX, no
# fallback chain). R5: this is an identity hint for replay-window
# deduplication, not a security boundary - cksum is sufficient and portable.
# subagent_type is folded in so the same prompt text sent to a DIFFERENT
# target is never honoured as a replay of a different dispatch. cksum
# outputs two words (checksum and byte count); we concatenate them without a
# space to avoid parsing ambiguity in the consumed stamp (reason field may
# contain spaces).
dispatch_key="$(cksum <<< "${target_type} ${prompt}" | tr -d ' ')"

consumed="${project_dir}/.claude/.dispatch-override.consumed"
now="$(date +%s 2>/dev/null || echo 0)"

if [ -f "$override" ]; then
  override_content="$(head -n 1 "$override" 2>/dev/null || true)"
  case "$override_content" in
    "override: "*)
      reason="${override_content#override: }"
      # Write the consumed stamp atomically via temp-file + rename, THEN delete
      # the sentinel. Order matters: if Process B is scheduled between these
      # operations, we want it to find the consumed stamp, not an empty space.
      # Format: <epoch-seconds> <dispatch-key> <reason>.
      consumed_tmp="${consumed}.tmp.$$.$RANDOM"
      if ! { printf '%s %s %s\n' "$now" "$dispatch_key" "$reason" > "$consumed_tmp" && \
             mv -f "$consumed_tmp" "$consumed"; } 2>/dev/null; then
        # printf succeeded but the rename failed (or printf itself failed and
        # left a partial tempfile): never orphan the tempfile in .claude/.
        rm -f "$consumed_tmp" 2>/dev/null || true
      fi
      rm -f "$override"
      log_line "override=${reason} target=${target}"
      exit 0
      ;;
    *)
      echo "Dispatch-hygiene override at ${override} carried no reason - a 'override: <reason>' line is required. Ignoring it and running the checks instead." >&2
      rm -f "$override"
      ;;
  esac
fi

# Replay path: if no active sentinel exists but a fresh consumed stamp does,
# honour it (within the 10-second window and matching the dispatch's identity
# key). This allows double-fire scenarios (sequential or parallel) to both
# honour an operator's escape hatch without requiring the operator to write
# the sentinel twice.
if [ -f "$consumed" ]; then
  consumed_line="$(head -n 1 "$consumed" 2>/dev/null || true)"

  # Parse consumed stamp AS A WHOLE: it must structurally match
  # "<digits> <non-space> <rest>" or it is rejected outright - no field is
  # bound on a partial match, so a line with fewer than two whitespace
  # boundaries can never collapse epoch/key/reason onto the same token (the
  # old `${line%% *}`/`${line#* }` parameter-expansion split was a silent
  # no-op on a malformed line). This also guarantees consumed_epoch is
  # purely numeric BEFORE it ever reaches `$(( ))` below: an unset-looking
  # or non-numeric epoch is a hard `set -u` arithmetic-expansion abort that
  # `|| rc=$?` cannot catch, so it must never reach that point unvalidated.
  is_valid=false
  is_stale=false
  if [[ $consumed_line =~ ^([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.*)$ ]]; then
    consumed_epoch="${BASH_REMATCH[1]}"
    consumed_key="${BASH_REMATCH[2]}"
    consumed_reason="${BASH_REMATCH[3]}"
    time_delta=$((now - consumed_epoch))
    # Window: [-2, +10]. The -2 allows for OS scheduler jitter and clock skew
    # between parallel dispatches; a delta outside the window means the
    # stamp is genuinely expired, regardless of key.
    if [ "$time_delta" -gt 10 ] || [ "$time_delta" -lt -2 ]; then
      is_stale=true
    elif [ "$consumed_key" = "$dispatch_key" ]; then
      is_valid=true
    fi
  fi

  if [ "$is_valid" = true ]; then
    # Honour the stamp: this is a double-fire replay within the window.
    log_line "override-replay=${consumed_reason} target=${target}"
    exit 0
  elif [ "$is_stale" = true ]; then
    # Genuinely past the window: safe to delete regardless of key.
    rm -f "$consumed"
  fi
  # Else (unparseable, or key-mismatched but still fresh): leave the stamp
  # alone. It is not honoured for THIS dispatch, but it must survive so an
  # unrelated in-window dispatch can never destroy a live sibling's replay
  # window - deleting here reproduces the exact double-fire bug this file
  # exists to fix, triggered by any unrelated concurrent Agent spawn.
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
        marker="${reviewed_dir}/${unit_id}.pass"
        if [ -f "$marker" ]; then
          # Commit-anchored verdict (marker format v3, six-branch table): a
          # bare marker fires by default; only a positively-proven-unreachable
          # commit (branch 6) suppresses H3. Everything unverifiable - no
          # commit: field, `commit: none`, a malformed token, no git repo -
          # keeps today's behaviour and fires (R4/governing rule).
          h3_fire=true
          sha=""
          marker_first="$(head -n 1 "$marker" 2>/dev/null || true)"
          if [[ $marker_first =~ commit:[[:space:]]+([0-9a-f]{7,40}|none)([[:space:]]|$) ]]; then
            sha="${BASH_REMATCH[1]}"
            if [ "$sha" != none ] \
               && git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
              if git -C "$project_dir" cat-file -e "${sha}^{commit}" 2>/dev/null \
                 && git -C "$project_dir" merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
                h3_fire=true
              else
                h3_fire=false
              fi
            fi
          fi
          if [ "$h3_fire" = true ]; then
            fire H3 "H3: unit ${unit_id} already passed review (.claude/reviewed/${unit_id}.pass exists) - it is done, do not re-dispatch it."
          else
            echo "unit ${unit_id}'s .pass marker names commit ${sha}, which is not reachable from HEAD - the unit is re-dispatchable because its attested commit is gone." >&2
            log_line "h3-stale-marker=${unit_id} commit=${sha} target=${target}"
          fi
        fi
        ;;
    esac
  fi

  # H4 - dispatch contract. The nine markers agents/task-master.md enumerates;
  # the eight heading strings are byte-for-byte copies of that list, because a
  # paraphrase here would enforce something task-master never emits.
  if [ "$require_contract" = true ]; then
    missing=""
    if [[ ! $first_line =~ ^Unit:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._#-]{0,63})[[:space:]]*$ ]]; then
      missing="a 'Unit: <id>' first line"
    fi
    for heading in '## Objective' '## Retrieval' '## Affected files' \
                   '## Ordered edits' '## Do NOT touch' '## Acceptance criteria' \
                   '## Pre-resolved context' '## Escalation'; do
      case "$prompt" in
        *"$heading"*) ;;
        *) missing="${missing}${missing:+, }${heading}" ;;
      esac
    done
    if [ -n "$missing" ]; then
      fire H4 "H4: dispatch to a gated target is missing ${missing}. A gated dispatch must carry all nine contract elements (see agents/task-master.md); set dispatchHygiene.requireContract to false to disarm this check."
    fi
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
  printf '  Escape hatch, audited and bounded replay: printf "override: <reason>\\n" > .claude/.dispatch-override\n'
  printf '  (First use deletes the sentinel; parallel or sequential re-fires within 10 seconds are honoured without re-writing the sentinel.)\n'
} >&2

for check in $fired; do
  log_line "${key}=${check} target=${target}"
done

[ "$key" = "warned" ] && exit 0
exit 2
