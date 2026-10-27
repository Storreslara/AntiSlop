#!/usr/bin/env bash
# writer-scope-gate.sh (st-u3, hardened by rp-u15): SubagentStop gate for the three writing
# personas (lead-programmer, scribe, spec-master). It attributes changed paths from the
# subagent's OWN transcript (Write/Edit file paths, plus the files of every commit
# whose `[<branch> <sha>]` line appears in a Bash result), keeps the ones whose net
# content still differs from where the subagent started (the last commit before its
# transcript's first timestamp), and blocks the stop
# (exit 2, reason on stderr) when one of them is outside the dispatch's unit scope.
# Claude-only: it needs agent_transcript_path. Reads only; its one write is a log
# line in .claude/bookkeeping/scope-gate.log (gitignored since qw-u1).
set -uo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
allow() { exit 0; }
input="$(cat)"
# jq is a hard dependency of every hook (README). Without it the gate cannot tell which persona
# stopped, so a block would stop every subagent: it allows, logs and says so (rp-u15).
if ! command -v jq >/dev/null 2>&1; then
  d="${CLAUDE_PROJECT_DIR:-$PWD}/.claude"
  [ -d "$d" ] && { mkdir -p "$d/bookkeeping" && printf '%s agent=unknown persona=unknown unattributable: jq missing\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$d/bookkeeping/scope-gate.log"; } 2>/dev/null
  echo "writer-scope-gate: jq is not installed, so no writer's unit scope is checked; install it (README: every hook needs jq)." >&2
  allow
fi
at="$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)"
tr_path="$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty' 2>/dev/null)"
# A named dispatch reports its dispatch name as agent_type; the transcript's sibling .meta.json
# records the persona it runs as agentType, so either one naming a writer gates the stop.
mt=""; [ -z "$tr_path" ] || mt="$(jq -r '.agentType // empty' "${tr_path%.jsonl}.meta.json" 2>/dev/null)"
# writer_of <persona name>: the writer it names, also with the harness's `-<n>` collision suffix.
writer_of() { [[ ${1-} =~ ^(lead-programmer|scribe|spec-master)(-[0-9]+)?$ ]] && printf '%s' "${BASH_REMATCH[1]}"; }
guess="$(writer_of "${at##*:}")$(writer_of "${mt##*:}")"
# A library that runs `exit` while it is sourced would end the gate with its status (0 is an
# allow), so an EXIT trap turns that into a block for a writer until sourcing is done.
# fd 3 keeps stderr: the trap runs inside the group's `>/dev/null 2>&1`.
sourced=0; exec 3>&2
trap '[ "$sourced" = 1 ] || [ -z "$guess" ] || { echo "BLOCKED (writer-scope-gate): a library under hooks/scripts/lib/ ended the gate while it was being sourced, so your changes cannot be checked against your unit scope. Report this block to your dispatcher and wait; do not edit the library." >&3; exit 2; }' EXIT
# agent-identity.sh (through audit-log.sh) and state-access.sh turn on `set -e` when sourced; this
# gate decides by explicit checks, so errexit is switched off after the group. `|| true`: a missing
# library must reach the `declare -F` check below, not exit 1, which Claude Code reads as allow.
# state-access.sh owns the unit-id grammar (UNIT_ID_CHARCLASS, unit_id_valid, unit_id_sanitize;
# tests/state-access-constraints.test.sh M5 allows no second spelling under hooks/scripts/).
{ . "$here/lib/agent-identity.sh" && . "$here/lib/state-access.sh" && . "$here/lib/unit-scope.sh"; } >/dev/null 2>&1 || true
set +e
sourced=1; trap - EXIT; exec 3>&-

project_dir="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)}"
[ -n "$project_dir" ] || project_dir="$PWD"
dot="${project_dir}/.claude"
config="${dot}/persona-config.json"
[ -f "$config" ] || allow
[ "$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)" = SubagentStop ] || allow
# Policy: the exact persona name, its namespaced form (identity_persona_name) and the `-<n>` suffix are
# gated; `Lead-Programmer` or a trailing space are not values the harness emits.
pn() { if declare -F identity_persona_name >/dev/null; then identity_persona_name "$1"; else printf '%s' "${1##*:}"; fi; }
persona="$(writer_of "$(pn "$at")")"; [ -n "$persona" ] || persona="$(writer_of "$(pn "$mt")")"
[ -n "$persona" ] || allow
agent_id="$(unit_id_sanitize "$(printf '%s' "$input" | jq -r '.agent_id // "unknown"' 2>/dev/null)" 2>/dev/null)"
cd "$project_dir" 2>/dev/null || allow
git rev-parse --verify -q HEAD >/dev/null || allow
log() { mkdir -p "$dot/bookkeeping" && printf '%s agent=%s persona=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$persona" "$1" >> "$dot/bookkeeping/scope-gate.log"; }
# A missing, empty or cut-short library would make every path look in scope (an undefined function
# only reads as "false"), so the writer's stop fails closed until the library is restored.
if ! declare -F identity_persona_name us_section us_entries us_exclusions us_excluded us_listed us_named_in us_classify unit_id_valid unit_id_sanitize >/dev/null; then
  log "blocked: unit-scope library unavailable"
  echo "BLOCKED (writer-scope-gate): hooks/scripts/lib/unit-scope.sh is missing or incomplete (or state-access.sh or agent-identity.sh is), so your changes cannot be checked against your unit scope. Report this block to your dispatcher and wait; do not edit the library." >&2
  exit 2
fi
if [ -z "$tr_path" ] || [ ! -e "$tr_path" ]; then log "unattributable: no transcript"; allow; fi

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# Each line is parsed on its own: a malformed or cut-off line is skipped, never the whole file. A
# transcript with no readable record (a directory, a foreign format) blocks the writer's stop.
jq -cR 'fromjson? | select(type == "object")' "$tr_path" > "$W/tr" 2>/dev/null
if [ ! -s "$W/tr" ]; then
  log "blocked: transcript unreadable"
  echo "BLOCKED (writer-scope-gate): your transcript ($tr_path) has no record this gate can read, so your changes cannot be checked against your unit scope. Report this block to your dispatcher and wait." >&2
  exit 2
fi
bad=$(( $(grep -c . "$tr_path" 2>/dev/null) - $(wc -l < "$W/tr") ))
[ "$bad" -le 0 ] || log "skipped: $bad malformed transcript line(s)"
jq -rs 'try (map(select(.type == "user"))[0].message.content
        | if type == "string" then . else (map(select(.type? == "text") | .text) | join("\n")) end) catch ""' \
  "$W/tr" > "$W/prompt" 2>/dev/null
jq -j 'try (select(.type == "assistant") | .message.content[]?
       | select(type == "object" and .type == "tool_use" and (.name == "Write" or .name == "Edit" or .name == "NotebookEdit"))
       | (.input.file_path // .input.notebook_path // empty) | strings | . + "\u0000") catch empty' "$W/tr" > "$W/abs" 2>/dev/null
jq -r 'try (select(.type == "user") | .message.content[]?
       | select(type == "object" and .type == "tool_result") | .content
       | if type == "string" then . else (map(select(.type? == "text") | .text) | join("\n")) end) catch empty' "$W/tr" 2>/dev/null \
  | grep -oE '^\[[^]]* [0-9a-f]{7,40}\]' | grep -oE '[0-9a-f]{7,40}\]$' | tr -d ']' > "$W/shas" || true
t0="$(jq -r 'try (.timestamp | strings) catch empty' "$W/tr" 2>/dev/null | head -n1)"

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
# canon <absolute path>: norm_abs, then the directory's symlinks resolved (pwd -P), so an edit made
# through a symlinked project path is judged as the file it names (rp-u15). The file name itself is
# kept: an edit through a symlinked file changes the link's target, not the link.
canon() {
  local a d; a="$(norm_abs "$1")"; d="${a%/*}"; [ -n "$d" ] || d=/
  [ -d "$d" ] && d="$(cd "$d" 2>/dev/null && pwd -P)" && a="${d%/}/${a##*/}"
  printf '%s' "$a"
}
top="$(pwd -P)"
pd="$(norm_abs "$project_dir")"
: > "$W/cand"
while IFS= read -r -d '' a; do
  [ -n "$a" ] || continue
  a="$(canon "$a")"
  case "$a" in "$top"/*) printf '%s\0' "${a#"$top"/}" >> "$W/cand" ;; "$pd"/*) printf '%s\0' "${a#"$pd"/}" >> "$W/cand" ;; esac
done < "$W/abs"
# The baseline is the last commit on HEAD's first-parent line before the transcript's first
# timestamp, so a Write/Edit path the writer committed is judged even when no commit line shows
# (rp-u15). A commit line still proves the commit is the writer's: the baseline is then also no
# later than that commit's parent. No timestamp and no commit line: HEAD (logged).
first=""
while IFS= read -r s; do
  git cat-file -e "$s^{commit}" 2>/dev/null || continue
  [ -n "$first" ] || first="$(git rev-parse -q --verify "$s^" 2>/dev/null || git hash-object -t tree /dev/null)"
  git show --no-renames --name-only -z --format= "$s" >> "$W/cand"
done < "$W/shas"
start=""
if [ -n "$t0" ]; then
  start="$(git rev-list -1 --first-parent --before="$t0" HEAD 2>/dev/null)"
  [ -n "$start" ] || start="$(git hash-object -t tree /dev/null)"
fi
if [ -n "$first" ] && [ -n "$start" ]; then
  start="$(git merge-base "$start" "$first" 2>/dev/null || printf '%s' "$first")"
elif [ -n "$first" ]; then
  start="$first"
elif [ -z "$start" ]; then
  start="HEAD"; log "baseline: HEAD (no timestamp and no commit line)"
fi

# ptok: the prompt as one token per line, so us_named_in reads a path the way a person does. Split at
# whitespace and at quotes, backticks, brackets, braces, angle brackets, `|`, `,`, `;` and `=`; then cut
# trailing sentence punctuation (`.,;:!?`) from each token, repeating until nothing more comes off, and
# a leading `./`. A `:12` or `#L12` line suffix needs no cutting: `:` and `#` already end a path token.
# Inner dots stay, so `xREADME.md`, `other/README.md` and `README.md.bak` are still different tokens.
# us_named_in alone counts a sentence-final `.` as part of the path, so a path that ends a sentence
# was never named (rp-u15 fix 1).
tr '[:space:]`()[]{}<>|,;=\047\042' '\n' < "$W/prompt" \
  | sed -E ':a; s/[.,;:!?]+$//; ta; s#^(\./)+##' > "$W/ptok"
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
  us_named_in "$p" "$W/ptok" && [ "$persona" != lead-programmer ] && return 0
  case "$persona" in
    lead-programmer)
      # Only the classes us_classify names as in scope count; `out`, `excluded`, empty or any other
      # output is out (rp-u15).
      case "$(us_classify "$p" "$start" "$W/listed" /dev/null "$W/crit" "$W/failrec")" in
        listed|criteria|fail-record|fix-contract|plugin-version|judge) return 0 ;; *) return 1 ;;
      esac ;;
    spec-master)
      knowledge "$p" && [ "$kw" = apply ] && return 0; return 1 ;;
    scribe)
      if knowledge "$p"; then [ "$kw" = apply ] && return 0; return 1; fi
      case "$p" in docs/*) return 0 ;; esac; return 1 ;;
  esac
  return 1
}
# foreign <path>: the short shas of the commits after the baseline that changed the path and that no
# commit line of the transcript shows. The restore command would revert them too (rp-u15 fix 1).
foreign() {
  local c s seen out=""
  while IFS= read -r c; do
    seen=0
    while IFS= read -r s; do [ -n "$s" ] || continue; case "$c" in "$s"*) seen=1; break ;; esac; done < "$W/shas"
    [ "$seen" = 1 ] || out="$out ${c:0:10}"
  done < <(git rev-list "$start..HEAD" -- "$1" 2>/dev/null)
  printf '%s' "${out# }"
}
viol=()
while IFS= read -r -d '' p; do
  [ -n "$p" ] || continue
  if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1 || git cat-file -e "$start:$p" 2>/dev/null; then
    git diff --quiet "$start" -- "$p" 2>/dev/null && continue
  else
    [ -e "$p" ] || continue
    # An untracked file git ignores (a microworlds/<slug>/ bundle, scratch) never ships (rp-u15).
    git check-ignore -q -- "$p" 2>/dev/null && continue
  fi
  # A name holding a quote, a backslash or a control character cannot be judged (review-precheck
  # fails it as `unquotable`): while it still differs it is out of scope for every persona.
  case "$p" in *'"'*|*'\'*|*[[:cntrl:]]*) viol+=("$p"); continue ;; esac
  in_scope "$p" || viol+=("$p")
done < <(sort -zu "$W/cand")
[ "${#viol[@]}" -eq 0 ] && allow
shown=(); for p in ${viol[@]+"${viol[@]}"}; do shown+=("$(printf '%q' "$p")"); done
log "blocked: ${shown[*]}"
{
  echo "BLOCKED (writer-scope-gate): you left changes outside your dispatch's unit scope: ${shown[*]}."
  echo "Restore each one, and commit if you had committed it:"
  for p in ${viol[@]+"${viol[@]}"}; do
    q="$(printf '%q' "$p")"
    if git cat-file -e "$start:$p" 2>/dev/null; then echo "  git checkout $start -- $q"
    elif git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then echo "  git rm -qf -- $q   (a file you added)"
    else echo "  rm -- $q   (a new file you never added)"
    fi
    f="$(foreign "$p")"
    [ -z "$f" ] || echo "    note: commit(s) $f changed it after the baseline and are not in your transcript (another session's, or a commit made before you started and re-dated); restore only your own change, not theirs."
  done
  echo "Then report the change under \`Proposed out-of-scope changes:\` (or \`Knowledge proposals:\`) instead of applying it. In scope: the dispatch's \`## Affected files\` and your persona's standing exceptions; knowledge files (CONTEXT.md, README.md, docs/harness-glossary.md, docs/adr/) need knowledgeWrites \"apply\" or a dispatch that lists or names them."
} >&2
exit 2
