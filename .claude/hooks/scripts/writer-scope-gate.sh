#!/usr/bin/env bash
# writer-scope-gate.sh (st-u3): SubagentStop gate for the three writing personas
# (lead-programmer, scribe, spec-master). It attributes changed paths from the
# subagent's OWN transcript (Write/Edit file paths, plus the files of every commit
# whose `[<branch> <sha>]` line appears in a Bash result), keeps the ones whose net
# content still differs from where the subagent started, and blocks the stop
# (exit 2, reason on stderr) when one of them is outside the dispatch's unit scope.
# Claude-only: it needs agent_transcript_path. Reads only; its one write is a log
# line in .claude/bookkeeping/scope-gate.log (gitignored since qw-u1).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
# agent-identity.sh sources audit-log.sh, which turns on `set -e`; this gate decides by
# explicit checks, so errexit is switched back off, before the two libraries below are
# sourced (a missing one must reach the `declare -F` check, not exit 1 under errexit).
set +e
# state-access.sh owns the unit-id grammar (UNIT_ID_CHARCLASS, unit_id_valid, unit_id_sanitize;
# tests/state-access-constraints.test.sh M5 allows no second spelling under hooks/scripts/).
{ . "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh" && . "$(dirname "${BASH_SOURCE[0]}")/lib/unit-scope.sh"; } >/dev/null 2>&1 || true
# state-access.sh turns errexit on again when sourced (hence `|| true` above: a missing
# unit-scope.sh must not end the gate with exit 1, which Claude Code reads as allow).
set +e

allow() { exit 0; }
input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)}"
[ -n "$project_dir" ] || project_dir="$PWD"
dot="${project_dir}/.claude"
config="${dot}/persona-config.json"
[ -f "$config" ] || allow
[ "$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)" = SubagentStop ] || allow
persona="$(identity_persona_name "$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)")"
case "$persona" in lead-programmer|scribe|spec-master) ;; *) allow ;; esac
agent_id="$(unit_id_sanitize "$(printf '%s' "$input" | jq -r '.agent_id // "unknown"' 2>/dev/null)" 2>/dev/null)"
tr_path="$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty' 2>/dev/null)"
cd "$project_dir" 2>/dev/null || allow
git rev-parse --verify -q HEAD >/dev/null || allow
log() { mkdir -p "$dot/bookkeeping" && printf '%s agent=%s persona=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$persona" "$1" >> "$dot/bookkeeping/scope-gate.log"; }
# A missing, empty or cut-short library would make every path look in scope (an undefined function
# only reads as "false"), so the writer's stop fails closed until the library is restored.
if ! declare -F us_section us_entries us_exclusions us_excluded us_listed us_named_in us_classify unit_id_valid unit_id_sanitize >/dev/null; then
  log "blocked: unit-scope library unavailable"
  echo "BLOCKED (writer-scope-gate): hooks/scripts/lib/unit-scope.sh is missing or incomplete (or state-access.sh is), so your changes cannot be checked against your unit scope. Report this block to your dispatcher and wait; do not edit the library." >&2
  exit 2
fi
if [ -z "$tr_path" ] || [ ! -r "$tr_path" ]; then log "unattributable: no transcript"; allow; fi

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
jq -rs 'map(select(.type == "user"))[0].message.content
        | if type == "string" then . else (map(select(.type? == "text") | .text) | join("\n")) end' \
  "$tr_path" > "$W/prompt" 2>/dev/null || : > "$W/prompt"
jq -r 'select(.type == "assistant") | .message.content[]?
       | select(type == "object" and .type == "tool_use" and (.name == "Write" or .name == "Edit" or .name == "NotebookEdit"))
       | .input.file_path // .input.notebook_path // empty' "$tr_path" 2>/dev/null > "$W/abs" || : > "$W/abs"
jq -r 'select(.type == "user") | .message.content[]?
       | select(type == "object" and .type == "tool_result") | .content
       | if type == "string" then . else (map(select(.type? == "text") | .text) | join("\n")) end' "$tr_path" 2>/dev/null \
  | grep -oE '^\[[^]]* [0-9a-f]{7,40}\]' | grep -oE '[0-9a-f]{7,40}\]$' | tr -d ']' > "$W/shas" || true

# norm_abs <absolute path>: `//`, `.` and `..` segments resolved lexically and no trailing `/`, so a
# tool-call path such as `src//a.js` or `.claude/../CONTEXT.md` is judged as the file it names (rp-u11).
norm_abs() {
  local rest="$1/" seg out=""
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"; rest="${rest#*/}"
    case "$seg" in ''|.) ;; ..) out="${out%/*}" ;; *) out="$out/$seg" ;; esac
  done
  printf '%s\n' "${out:-/}"
}
top="$(pwd -P)"
pd="$(norm_abs "$project_dir")"
: > "$W/cand"
while IFS= read -r a; do
  [ -n "$a" ] || continue
  a="$(norm_abs "$a")"
  case "$a" in "$top"/*) printf '%s\n' "${a#"$top"/}" >> "$W/cand" ;; "$pd"/*) printf '%s\n' "${a#"$pd"/}" >> "$W/cand" ;; esac
done < "$W/abs"
start=""
while IFS= read -r s; do
  git cat-file -e "$s^{commit}" 2>/dev/null || continue
  [ -n "$start" ] || start="$(git rev-parse -q --verify "$s^" 2>/dev/null || git hash-object -t tree /dev/null)"
  git -c core.quotepath=false show --no-renames --name-only --format= "$s" >> "$W/cand"
done < "$W/shas"
[ -n "$start" ] || start="HEAD"

us_section "$W/prompt" "Affected files" > "$W/sec"
us_entries "$W/prompt" > "$W/listed"
us_exclusions "$W/prompt" > "$W/excl"
if [ ! -s "$W/listed" ]; then
  c="$(grep -oE "docs/plans/[A-Za-z0-9._/-]*contracts/[${UNIT_ID_CHARCLASS}]+\.md" "$W/prompt" | head -n1)"
  [ -n "$c" ] && [ -f "$c" ] && us_entries "$c" > "$W/listed"
  [ -n "$c" ] && [ -f "$c" ] && us_exclusions "$c" > "$W/excl"
fi
grep -oE 'file: `[^` ]+`' "$W/prompt" | sed 's/^file: `//; s/`$//' >> "$W/listed" || true
us_section "$W/prompt" "Acceptance criteria" | grep -E '^[0-9]+\. run: ' > "$W/crit" || true
unit="$(sed -n 's/^Unit: //p' "$W/prompt" | head -n1)"; unit_id_valid "$unit" || unit=""
: > "$W/failrec"; [ -z "$unit" ] || [ ! -f "$dot/reviewed/$unit.fail" ] || cp "$dot/reviewed/$unit.fail" "$W/failrec"
kw="$(jq -r '.knowledgeWrites // "scoped"' "$config" 2>/dev/null)"; [ "$kw" = apply ] || kw=scoped

knowledge() { case "$1" in CONTEXT.md|README.md|docs/harness-glossary.md|docs/adr/*) return 0 ;; esac; return 1; }
in_scope() { # <path> -> exit 0 when this persona may leave it changed
  local p="$1"
  # This standing exception comes before `## Do NOT touch`: a `.claude/` copy changes only through
  # `--update` and `docs/plans/` is the plan itself, so a bullet naming such a path says how it may
  # change (the reviewer's mirror checks enforce that), never whether; this gate cannot tell a hand edit
  # from a regeneration. review-precheck leaves both trees out of its scope lines the same way.
  case "$p" in .claude/*|docs/plans/*) return 0 ;; esac
  us_excluded "$p" "$W/excl" && return 1
  us_listed "$p" "$W/listed" && return 0
  us_named_in "$p" "$W/prompt" && [ "$persona" != lead-programmer ] && return 0
  case "$persona" in
    lead-programmer)
      case "$(us_classify "$p" "$start" "$W/listed" /dev/null "$W/crit" "$W/failrec")" in out) return 1 ;; *) return 0 ;; esac ;;
    spec-master)
      knowledge "$p" && [ "$kw" = apply ] && return 0; return 1 ;;
    scribe)
      if knowledge "$p"; then [ "$kw" = apply ] && return 0; return 1; fi
      case "$p" in docs/*) return 0 ;; esac; return 1 ;;
  esac
  return 1
}
viol=()
while IFS= read -r p; do
  [ -n "$p" ] || continue
  # git C-quotes a committed name holding a quote, a backslash or a control character; such a path
  # cannot be judged (review-precheck fails it as `unquotable`), so it is out of scope.
  case "$p" in '"'*) viol+=("$p"); continue ;; esac
  if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1 || git cat-file -e "$start:$p" 2>/dev/null; then
    git diff --quiet "$start" -- "$p" 2>/dev/null && continue
  else
    [ -e "$p" ] || continue
  fi
  in_scope "$p" || viol+=("$p")
done < <(sort -u "$W/cand")
[ "${#viol[@]}" -eq 0 ] && allow
log "blocked: ${viol[*]}"
{
  echo "BLOCKED (writer-scope-gate): you left changes outside your dispatch's unit scope: ${viol[*]}."
  echo "Restore each one (git checkout $start -- <path>, or git rm a file you added) and commit, then report the change under \`Proposed out-of-scope changes:\` (or \`Knowledge proposals:\`) instead of applying it. In scope: the dispatch's \`## Affected files\` and your persona's standing exceptions; knowledge files (CONTEXT.md, README.md, docs/harness-glossary.md, docs/adr/) need knowledgeWrites \"apply\" or a dispatch that lists or names them."
} >&2
exit 2
