#!/usr/bin/env bash
# Reads Claude Code's existing per-session/per-subagent transcript store
# (~/.claude/projects/<slug>/) and reports five anomaly checks (A1-A4, A6) plus
# two informational inventories (I1-I2). Read-only: no new instrumentation,
# no hook, no gitignore entry - the data already exists on disk.
#
# Privacy (R5): this script emits metadata, paths, names and counts only.
# It must NEVER print a prompt body or a tool-input body (e.g. Bash command
# text, file contents, assistant prose). Every jq/text extraction below is
# scoped to identifiers (persona names, tool names, session/agent ids,
# models, skill names, spawnDepth, task ids) for exactly this reason.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/agent-identity.sh
source "$PROJECT_DIR/hooks/scripts/lib/agent-identity.sh"

SESSIONS_N=1
ALL=0
JSON=0
FORMAT_PROBE=0

for arg in "$@"; do
  case "$arg" in
    --all) ALL=1 ;;
    --json) JSON=1 ;;
    --format-probe) FORMAT_PROBE=1 ;;
    --sessions=*) SESSIONS_N="${arg#--sessions=}" ;;
    *)
      echo "agent-audit.sh: unrecognized argument: $arg" >&2
      exit 1
      ;;
  esac
done

# --- root resolution -------------------------------------------------------

slugify() {
  local p="$1" out="" c i
  for (( i = 0; i < ${#p}; i++ )); do
    c="${p:i:1}"
    case "$c" in
      [A-Za-z0-9]) out+="$c" ;;
      *) out+="-" ;;
    esac
  done
  printf '%s' "$out"
}

# AGENT_AUDIT_ROOT, when set, stands in for the whole data root a fixture
# needs: transcript sessions directly under it, and PASS/FAIL markers under
# its "reviewed/" sibling - see the A6 section below for why the marker
# directory needs its own override rather than reusing the live one.
if [ -n "${AGENT_AUDIT_ROOT:-}" ]; then
  ROOT="$AGENT_AUDIT_ROOT"
  MARKER_DIR="$AGENT_AUDIT_ROOT/reviewed"
else
  ROOT="$HOME/.claude/projects/$(slugify "$PROJECT_DIR")"
  MARKER_DIR="$PROJECT_DIR/.claude/reviewed"
fi

# --- frontmatter helpers -----------------------------------------------

# Registration surface (docs/plans/2026-08-09-agent-auditor-persona.md,
# "Registration surface for a new persona"): source of truth is agents/*.md,
# with two documented exceptions - a scaffolded mirror under .claude/agents/
# and researcher's template under templates/*.md.tmpl.
persona_source_file() {
  local id="$1"
  if [ -f "$PROJECT_DIR/agents/$id.md" ]; then
    printf '%s' "$PROJECT_DIR/agents/$id.md"
    return 0
  fi
  if [ -f "$PROJECT_DIR/.claude/agents/$id.md" ]; then
    printf '%s' "$PROJECT_DIR/.claude/agents/$id.md"
    return 0
  fi
  if [ -f "$PROJECT_DIR/templates/$id.md.tmpl" ]; then
    printf '%s' "$PROJECT_DIR/templates/$id.md.tmpl"
    return 0
  fi
  return 1
}

frontmatter_field() {
  local f="$1" key="$2" infm=0 line
  while IFS= read -r line; do
    if [ "$infm" = 0 ]; then
      [ "$line" = "---" ] && infm=1
      continue
    fi
    [ "$line" = "---" ] && break
    case "$line" in
      "$key":*) printf '%s\n' "${line#"$key":}"; return 0 ;;
    esac
  done < "$f"
  return 1
}

frontmatter_has_key() {
  local f="$1" key="$2" infm=0 line
  while IFS= read -r line; do
    if [ "$infm" = 0 ]; then
      [ "$line" = "---" ] && infm=1
      continue
    fi
    [ "$line" = "---" ] && break
    case "$line" in "$key":*) return 0 ;; esac
  done < "$f"
  return 1
}

# YAML list of MCP server names nested under the frontmatter's mcpServers:
# key, e.g. explorer's "mcpServers:\n  - code-review-graph:\n      ...".
persona_mcp_servers() {
  local f="$1" infm=0 inmcp=0 line
  while IFS= read -r line; do
    if [ "$infm" = 0 ]; then
      [ "$line" = "---" ] && infm=1
      continue
    fi
    [ "$line" = "---" ] && break
    if [ "$inmcp" = 0 ]; then
      case "$line" in mcpServers:*) inmcp=1 ;; esac
      continue
    fi
    if [[ ! "$line" =~ ^[[:space:]] ]]; then
      inmcp=0
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([A-Za-z0-9_.-]+): ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
    fi
  done < "$f"
}

# --- gated-agents list (A4) -------------------------------------------

GATED_AGENTS=""
if [ -f "$PROJECT_DIR/.claude/persona-config.json" ]; then
  GATED_AGENTS="$(jq -r '.gatedAgents[]? // empty' "$PROJECT_DIR/.claude/persona-config.json" 2>/dev/null || true)"
fi

is_gated_persona() {
  local id="$1" g
  while IFS= read -r g; do
    [ "$g" = "$id" ] && return 0
  done <<< "$GATED_AGENTS"
  return 1
}

# --- format probe (R1) --------------------------------------------------

run_format_probe() {
  local found_session=0 found_subagent=0 f sj m d mj tj tok
  local session_files_exist=0 dispatch_files_exist=0

  if [ ! -d "$ROOT" ]; then
    echo "FORMAT-NO-STORE"
    return 0
  fi

  # Some session files are "thin" - settings/bookmark records only (type
  # "last-prompt", "mode", ...) with a null timestamp, no real conversation
  # turn. Search across sessions for at least one with a genuine
  # (type, timestamp) record rather than trusting glob order to hand back a
  # representative file.
  for f in "$ROOT"/*.jsonl; do
    [ -e "$f" ] || continue
    session_files_exist=1
    sj="$(head -n 20 "$f" 2>/dev/null | jq -rs 'if length==0 then empty else (if any(.[]; ((.type // "")|length)>0 and ((.timestamp // "")|length)>0) then "ok" else empty end) end' 2>/dev/null || true)"
    if [ "$sj" = "ok" ]; then
      found_session=1
      break
    fi
  done

  # A meta.json without a paired .jsonl is a normal, orphaned dispatch
  # record (e.g. a subagent that was created but never produced any
  # transcript output) - the main enumeration below skips these too, so the
  # probe searches across candidates rather than failing on the first one.
  for d in "$ROOT"/*/subagents; do
    [ -d "$d" ] || continue
    for m in "$d"/*.meta.json; do
      [ -e "$m" ] || continue
      dispatch_files_exist=1
      mj="$(jq -r '(.agentType // empty)' "$m" 2>/dev/null || true)"
      [ -n "$mj" ] || continue
      tj="${m%.meta.json}.jsonl"
      [ -f "$tj" ] || continue
      tok="$(head -n 5 "$tj" 2>/dev/null | jq -rs 'if length==0 then empty else (if any(.[]; (.type // "" | length)>0) then "ok" else empty end) end' 2>/dev/null || true)"
      if [ "$tok" = "ok" ]; then
        found_subagent=1
        break 2
      fi
    done
  done

  # Root exists but holds zero candidate files of either kind - the normal
  # not-yet-any-activity case, not a format problem.
  if [ "$session_files_exist" = 0 ] && [ "$dispatch_files_exist" = 0 ]; then
    echo "FORMAT-EMPTY"
    return 0
  fi

  # The discriminator throughout is candidate-file-existence versus
  # parse-success, checked independently per kind: a kind with zero
  # candidates stays silent (normal - e.g. no dispatches yet), but a kind
  # with candidates that all failed to parse makes the whole report
  # untrustworthy.
  if { [ "$session_files_exist" = 1 ] && [ "$found_session" = 0 ]; } || \
     { [ "$dispatch_files_exist" = 1 ] && [ "$found_subagent" = 0 ]; }; then
    echo "FORMAT-UNRECOGNIZED"
    return 0
  fi

  if [ "$dispatch_files_exist" = 0 ]; then
    echo "FORMAT-OK-NO-DISPATCHES"
    return 0
  fi

  echo "FORMAT-OK"
}

if [ "$FORMAT_PROBE" = 1 ]; then
  run_format_probe
  exit 0
fi

# R1: the probe always runs before any report is assembled, so a malformed
# store never renders indistinguishably from "no anomalies" - see
# agents/agent-auditor.md. The banner is plain-text only (never mixed into
# --json, which must stay valid JSON); the persona itself always runs
# --format-probe first regardless of mode, per the same doc.
PROBE_STATE="$(run_format_probe)"
if [ "$JSON" != 1 ] && [ "$PROBE_STATE" = "FORMAT-UNRECOGNIZED" ]; then
  echo "FORMAT-UNRECOGNIZED: transcript store has candidate files that did not parse - this report is untrustworthy and must not be read as \"no anomalies\""
fi

# --- session selection ---------------------------------------------------

session_ids=()
if [ -d "$ROOT" ]; then
  tmp_list="$(mktemp)"
  for f in "$ROOT"/*.jsonl; do
    [ -e "$f" ] || continue
    mt="$(stat -c '%Y' "$f" 2>/dev/null || echo 0)"
    printf '%s\t%s\n' "$mt" "$(basename "$f" .jsonl)" >> "$tmp_list"
  done
  if [ -s "$tmp_list" ]; then
    while IFS=$'\t' read -r _ sid; do
      session_ids+=("$sid")
    done < <(sort -rn "$tmp_list")
  fi
  rm -f "$tmp_list"
fi

if [ "${#session_ids[@]}" -gt 0 ] && [ "$ALL" != 1 ]; then
  if ! [[ "$SESSIONS_N" =~ ^[0-9]+$ ]] || [ "$SESSIONS_N" -lt 1 ]; then
    echo "agent-audit.sh: --sessions=N requires a positive integer" >&2
    exit 1
  fi
  session_ids=("${session_ids[@]:0:$SESSIONS_N}")
fi

if [ "${#session_ids[@]}" -eq 0 ]; then
  echo "no data for window"
  exit 0
fi

# --- dispatch enumeration -------------------------------------------------
# One line per dispatch: session, agent_id, canonical persona, raw agent
# type, spawnDepth, dispatched model (or "-"), is-teammate flag, description
# (used only internally for A6 task-id matching - never printed), jsonl path.

DISPATCHES="$(mktemp)"
WORK_FILES=()
trap 'rm -f "$DISPATCHES" "${WORK_FILES[@]:-}"' EXIT

for sid in "${session_ids[@]}"; do
  subdir="$ROOT/$sid/subagents"
  [ -d "$subdir" ] || continue
  for m in "$subdir"/*.meta.json; do
    [ -e "$m" ] || continue
    aid="$(basename "$m" .meta.json)"
    aid="${aid#agent-}"
    jf="${m%.meta.json}.jsonl"
    [ -f "$jf" ] || continue
    raw_at="$(jq -r '(.customAgentType // .agentType // empty)' "$m" 2>/dev/null || true)"
    [ -n "$raw_at" ] || continue
    persona="$(identity_persona_name "$raw_at")"
    depth="$(jq -r '(.spawnDepth // 0)' "$m" 2>/dev/null || echo 0)"
    model="$(jq -r '(.model // "-")' "$m" 2>/dev/null || echo -)"
    teammate="$(jq -r 'if (.taskKind // "") == "in_process_teammate" then "1" else "0" end' "$m" 2>/dev/null || echo 0)"
    [ -n "$teammate" ] || teammate=0
    desc="$(jq -r '(.description // "")' "$m" 2>/dev/null || true)"
    [ -n "$desc" ] || desc="-"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$sid" "$aid" "$persona" "$raw_at" "$depth" "$model" "$teammate" "$desc" "$jf" >> "$DISPATCHES"
  done
done

if [ ! -s "$DISPATCHES" ]; then
  echo "no data for window"
  exit 0
fi

FINDINGS="$(mktemp)"; WORK_FILES+=("$FINDINGS")
DISTRIBUTION="$(mktemp)"; WORK_FILES+=("$DISTRIBUTION")
SKILLS="$(mktemp)"; WORK_FILES+=("$SKILLS")

emit_finding() {
  # $1 id, $2 session, $3 agent, $4 persona, $5 tool/extra, $6 label, $7 status (optional)
  local status="${7:-}"
  jq -nc --arg id "$1" --arg session "$2" --arg agent "$3" --arg persona "$4" --arg tool "$5" --arg label "$6" --arg status "$status" \
    '{id:$id, session:$session, agent:$agent, persona:$persona} + (if $tool=="" then {} else {tool:$tool} end) + (if $label=="" then {} else {label:$label} end) + (if $status=="" then {} else {status:$status} end)' \
    >> "$FINDINGS"
}

# --- A1: undeclared tool use ------------------------------------------
# effective_tools = declared UNION (memory? {Read,Write,Edit}) UNION
# (in_process_teammate? {SendMessage}), mcp__* matched against declared
# mcpServers rather than tools:, and any Write/Edit whose file_path
# resolves under a memory directory excluded entirely. A dispatch whose
# persona has no resolvable source file (general-purpose, claude-code-guide,
# Explore, ...) has no declaration to diff against and is skipped here -
# it is covered separately by A2.
#
# The SendMessage/teammate term was found by prototyping the formula
# against the live corpus (not in the spec's Pre-resolved context): an
# agent-teams teammate can call SendMessage regardless of its persona's
# declared tools: list (shared protocol, "Agent-teams mode" section), which
# without this term produced 6 false positives for milestone-auditor
# teammates alone.
while IFS=$'\t' read -r sid aid persona raw_at depth model teammate desc jf; do
  pf="$(persona_source_file "$persona" 2>/dev/null || true)"
  [ -n "$pf" ] || continue

  tools_line="$(frontmatter_field "$pf" tools 2>/dev/null || true)"
  declared=",$(printf '%s' "$tools_line" | tr -d ' '),"
  if frontmatter_has_key "$pf" memory; then
    declared="${declared}Read,Write,Edit,"
  fi
  if [ "$teammate" = 1 ]; then
    declared="${declared}SendMessage,"
  fi
  mapfile -t servers < <(persona_mcp_servers "$pf")

  # id -> is_error, built from this dispatch's own tool_result records
  # (joined by tool_use.id == tool_result.tool_use_id, per the Step 12
  # spec - never by array position, since a tool_result for an unrelated
  # id can otherwise sit at the same position).
  declare -A A1_ERR_MAP=()
  while IFS=$'\t' read -r rid is_err; do
    [ -n "$rid" ] || continue
    if [ "$is_err" = "true" ]; then
      A1_ERR_MAP["$rid"]="true"
    elif [ -z "${A1_ERR_MAP[$rid]:-}" ]; then
      A1_ERR_MAP["$rid"]="false"
    fi
  done < <(jq -r '.message.content[]? | select(.type=="tool_result") | [(.tool_use_id // ""), (.is_error // false)] | @tsv' "$jf" 2>/dev/null)

  while IFS=$'\t' read -r tid tname fpath; do
    [ -n "$tname" ] || continue
    status="executed"
    if [ "${A1_ERR_MAP[$tid]:-false}" = "true" ]; then
      status="refused"
    fi
    case "$tname" in
      mcp__*)
        srv="${tname#mcp__}"; srv="${srv%%__*}"
        found=0
        for s in "${servers[@]:-}"; do
          [ "$s" = "$srv" ] && { found=1; break; }
        done
        [ "$found" = 1 ] || emit_finding A1 "$sid" "$aid" "$persona" "$tname" "" "$status"
        ;;
      Write|Edit)
        case "$fpath" in
          */.claude/projects/*/memory/*) continue ;;
          */.claude/agent-memory/*) continue ;;
        esac
        case "$declared" in
          *",$tname,"*) : ;;
          *) emit_finding A1 "$sid" "$aid" "$persona" "$tname" "" "$status" ;;
        esac
        ;;
      *)
        case "$declared" in
          *",$tname,"*) : ;;
          *) emit_finding A1 "$sid" "$aid" "$persona" "$tname" "" "$status" ;;
        esac
        ;;
    esac
  done < <(jq -r '.message.content[]? | select(.type=="tool_use") | [(.id // ""), .name, (.input.file_path // "")] | @tsv' "$jf" 2>/dev/null)
done < "$DISPATCHES"

# --- A2: unregistered agent type ---------------------------------------
# Canonicalizes via identity_persona_name (matching
# hooks/scripts/lib/agent-identity.sh), then checks the same three
# candidate source locations A1 uses.
while IFS=$'\t' read -r sid aid persona raw_at depth model teammate desc jf; do
  if ! persona_source_file "$persona" >/dev/null 2>&1; then
    emit_finding A2 "$sid" "$aid" "$persona" "" ""
  fi
done < "$DISPATCHES"

# --- A3: nested spawn ----------------------------------------------------
while IFS=$'\t' read -r sid aid persona raw_at depth model teammate desc jf; do
  if [[ "$depth" =~ ^[0-9]+$ ]] && [ "$depth" -ge 2 ]; then
    emit_finding A3 "$sid" "$aid" "$persona" "" "spawnDepth=$depth"
  fi
done < "$DISPATCHES"

# --- A4: gated dispatch without review -----------------------------------
# Per session: a gatedAgents persona dispatched with no reviewer dispatch
# starting later in the same session. Start time approximated by the first
# record's timestamp in the dispatch's own transcript (ISO-8601 strings
# compare lexically in chronological order).
first_ts() {
  jq -rs 'if length==0 then empty else (.[0].timestamp // empty) end' "$1" 2>/dev/null || true
}

for sid in "${session_ids[@]}"; do
  reviewer_ts_file="$(mktemp)"; WORK_FILES+=("$reviewer_ts_file")
  while IFS=$'\t' read -r rsid raid rpersona rraw rdepth rmodel rteam rdesc rjf; do
    [ "$rsid" = "$sid" ] || continue
    [ "$rpersona" = "reviewer" ] || continue
    ts="$(first_ts "$rjf")"
    [ -n "$ts" ] && printf '%s\n' "$ts" >> "$reviewer_ts_file"
  done < "$DISPATCHES"

  while IFS=$'\t' read -r gsid gaid gpersona graw gdepth gmodel gteam gdesc gjf; do
    [ "$gsid" = "$sid" ] || continue
    is_gated_persona "$gpersona" || continue
    gts="$(first_ts "$gjf")"
    later=0
    if [ -s "$reviewer_ts_file" ] && [ -n "$gts" ]; then
      while IFS= read -r rts; do
        [ "$rts" \> "$gts" ] && { later=1; break; }
      done < "$reviewer_ts_file"
    fi
    [ "$later" = 1 ] || emit_finding A4 "$gsid" "$gaid" "$gpersona" "" ""
  done < "$DISPATCHES"
done

# --- A6: orphan PASS marker -----------------------------------------------
# A .pass marker whose task-id has no reviewer dispatch in the window. Task
# id is the marker's filename stem; matched against reviewer dispatch
# descriptions by substring (descriptions are read only for this in-process
# comparison and are never printed). Reading the marker directory here is
# legitimate per R8: this command's own invocation text is
# "bash scripts/agent-audit.sh ...", which never spells the marker
# directory's literal path.
if [ -d "$MARKER_DIR" ]; then
  for marker in "$MARKER_DIR"/*.pass; do
    [ -e "$marker" ] || continue
    task_id="$(basename "$marker" .pass)"
    matched=0
    while IFS=$'\t' read -r sid aid persona raw_at depth model teammate desc jf; do
      [ "$persona" = "reviewer" ] || continue
      case "$desc" in
        *"$task_id"*) matched=1; break ;;
      esac
    done < "$DISPATCHES"
    if [ "$matched" = 0 ]; then
      jq -nc --arg id "A6" --arg task "$task_id" '{id:$id, task:$task}' >> "$FINDINGS"
    fi
  done
fi

# --- A7: hook block events (informational) --------------------------------
# Per dispatch, parse is_error: true tool_result entries whose text matches
# the pattern PreToolUse:<Tool> hook error: [<path>/<hook>.sh]: BLOCKED:.
# Emit one row per (dispatch, hook, tool) with a count. Informational only.
# tool_result nests under a user-role line's message.content[] (the A1/A8
# precedent at :349/:481) - there is no top-level tool_result entry and no
# .name field on one; the payload is .content, not .text.
while IFS=$'\t' read -r sid aid persona raw_at depth model teammate desc jf; do
  jq -r '.message.content[]? | select(.type=="tool_result" and .is_error==true and ((.content // "") | test("PreToolUse:.*hook error:.*BLOCKED:"))) | .content' "$jf" 2>/dev/null |
  while IFS= read -r error_text; do
    [ -n "$error_text" ] || continue

    # Parse tool name from error_text (PreToolUse:Tool format)
    if [[ $error_text =~ PreToolUse:([A-Za-z]+) ]]; then
      tool="${BASH_REMATCH[1]}"
    else
      continue
    fi

    # Parse hook name from error_text (hook error: [path/hookname.sh])
    if [[ $error_text =~ hook\ error:\ \[.*\/([^/]+)\.sh\] ]]; then
      hook="${BASH_REMATCH[1]}"
    else
      continue
    fi

    jq -nc --arg id "A7" --arg session "$sid" --arg agent "$aid" --arg persona "$persona" --arg tool "$tool" --arg hook "$hook" \
      '{id:$id, session:$session, agent:$agent, persona:$persona, tool:$tool, hook:$hook}' >> "$FINDINGS"
  done
done < "$DISPATCHES"

# --- A8: agent-memory writes (informational) ----------------------------
# Per dispatch, count Write/Edit tool_use entries whose file_path resolves
# under .claude/agent-memory/ or .claude/projects/*/memory/. Emit one row
# per dispatch with the count and file basenames. Informational only.
while IFS=$'\t' read -r sid aid persona raw_at depth model teammate desc jf; do
  # Extract Write/Edit tool_use entries under memory directories
  memory_writes=()
  while IFS= read -r fpath; do
    [ -n "$fpath" ] || continue
    case "$fpath" in
      .claude/agent-memory/*|*/.claude/agent-memory/*|.claude/projects/*/memory/*|*/.claude/projects/*/memory/*)
        # Extract basename only, not directory components
        bn="$(basename "$fpath")"
        memory_writes+=("$bn")
        ;;
    esac
  done < <(jq -r '.message.content[]? | select(.type=="tool_use" and (.name=="Write" or .name=="Edit")) | .input.file_path // empty' "$jf" 2>/dev/null)

  if [ "${#memory_writes[@]}" -gt 0 ]; then
    # Emit one row per dispatch with count and basenames joined with commas
    basenames="$(printf '%s,' "${memory_writes[@]}" | sed 's/,$//')"
    jq -nc --arg id "A8" --arg session "$sid" --arg agent "$aid" --arg persona "$persona" --argjson count "${#memory_writes[@]}" --arg basenames "$basenames" \
      '{id:$id, session:$session, agent:$agent, persona:$persona, count:$count, basenames:$basenames}' >> "$FINDINGS"
  fi
done < "$DISPATCHES"

# --- I1: model distribution (informational, never a flag) ---------------
while IFS=$'\t' read -r sid aid persona raw_at depth model teammate desc jf; do
  [ "$model" != "-" ] || continue
  pf="$(persona_source_file "$persona" 2>/dev/null || true)"
  [ -n "$pf" ] || continue
  declared_model="$(frontmatter_field "$pf" model 2>/dev/null || true)"
  [ -n "$declared_model" ] || declared_model="-"
  printf '%s\t%s\t%s\n' "$persona" "$model" "$declared_model" >> "$DISTRIBUTION"
done < "$DISPATCHES"

if [ -s "$DISTRIBUTION" ]; then
  sort "$DISTRIBUTION" | uniq -c | while read -r cnt persona dispatched declared; do
    jq -nc --arg persona "$persona" --arg dispatched "$dispatched" --arg declared "$declared" --argjson count "$cnt" \
      '{persona:$persona, dispatched:$dispatched, declared:$declared, count:$count}'
  done > "${DISTRIBUTION}.grouped"
  mv "${DISTRIBUTION}.grouped" "$DISTRIBUTION"
fi

# --- I2: skill inventory (informational) ---------------------------------
while IFS=$'\t' read -r sid aid persona raw_at depth model teammate desc jf; do
  jq -r '.message.content[]? | select(.type=="tool_use" and .name=="Skill") | (.input.skill // empty)' "$jf" 2>/dev/null |
    while IFS= read -r skill; do
      [ -n "$skill" ] && printf '%s\t%s\n' "$persona" "$skill" >> "$SKILLS"
    done
done < "$DISPATCHES"

if [ -s "$SKILLS" ]; then
  sort "$SKILLS" | uniq -c | while read -r cnt persona skill; do
    jq -nc --arg persona "$persona" --arg skill "$skill" --argjson count "$cnt" \
      '{persona:$persona, skill:$skill, count:$count}'
  done > "${SKILLS}.grouped"
  mv "${SKILLS}.grouped" "$SKILLS"
fi

# --- render ----------------------------------------------------------------

section_count() {
  jq -s --arg id "$1" '[.[] | select(.id==$id)] | length' "$FINDINGS" 2>/dev/null
}

if [ "$JSON" = 1 ]; then
  jq -n \
    --slurpfile findings <(cat "$FINDINGS") \
    --slurpfile distribution <(if [ -s "$DISTRIBUTION" ]; then cat "$DISTRIBUTION"; fi) \
    --slurpfile skills <(if [ -s "$SKILLS" ]; then cat "$SKILLS"; fi) \
    '{findings: $findings, distribution: $distribution, skills: $skills}'
  exit 0
fi

print_section() {
  local id="$1" label="$2" n
  n="$(section_count "$id")"
  echo "$id $label (n=$n)"
  jq -r --arg id "$id" 'select(.id==$id) | "  session=\(.session) agent=\(.agent) persona=\(.persona)" + (if .tool then " tool=\(.tool)" else "" end) + (if .label then " \(.label)" else "" end)' "$FINDINGS" 2>/dev/null
}

n1="$(section_count A1)"
n1_executed="$(jq -s '[.[] | select(.id=="A1" and .status=="executed")] | length' "$FINDINGS" 2>/dev/null)"
n1_refused="$(jq -s '[.[] | select(.id=="A1" and .status=="refused")] | length' "$FINDINGS" 2>/dev/null)"
echo "A1 Undeclared tool use (n=$n1, executed=$n1_executed, refused=$n1_refused)"
jq -r 'select(.id=="A1") | "  session=\(.session) agent=\(.agent) persona=\(.persona)" + (if .tool then " tool=\(.tool)" else "" end) + (if .status then " status=\(.status)" else "" end) + (if .label then " \(.label)" else "" end)' "$FINDINGS" 2>/dev/null
print_section A2 "Unregistered agent type"
print_section A3 "Nested spawn"
print_section A4 "Gated dispatch without review"
n6="$(jq -s '[.[] | select(.id=="A6")] | length' "$FINDINGS" 2>/dev/null)"
echo "A6 Orphan PASS marker (n=$n6)"
jq -r 'select(.id=="A6") | "  task=\(.task)"' "$FINDINGS" 2>/dev/null

n7="$(jq -s '[.[] | select(.id=="A7")] | length' "$FINDINGS" 2>/dev/null)"
echo "A7 Hook block events (informational - never a finding; n=$n7)"
jq -r 'select(.id=="A7") | "  session=\(.session) agent=\(.agent) persona=\(.persona) hook=\(.hook) tool=\(.tool)"' "$FINDINGS" 2>/dev/null

n8="$(jq -s '[.[] | select(.id=="A8")] | length' "$FINDINGS" 2>/dev/null)"
echo "A8 Agent-memory writes (informational - never a finding; n=$n8)"
jq -r 'select(.id=="A8") | "  session=\(.session) agent=\(.agent) persona=\(.persona) count=\(.count) basenames=\(.basenames)"' "$FINDINGS" 2>/dev/null

echo "I1 Model distribution (informational - dispatched vs declared)"
if [ -s "$DISTRIBUTION" ]; then
  jq -r '"  persona=\(.persona) dispatched=\(.dispatched) declared=\(.declared) count=\(.count)"' "$DISTRIBUTION"
fi

echo "I2 Skill inventory (informational)"
if [ -s "$SKILLS" ]; then
  jq -r '"  persona=\(.persona) skill=\(.skill) count=\(.count)"' "$SKILLS"
fi
