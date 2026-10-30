#!/usr/bin/env bash
# writer-scope-gate.sh (st-u3, hardened by rp-u15): SubagentStop gate for the three writing
# personas (lead-programmer, scribe, spec-master). It attributes changed paths from the
# subagent's OWN transcript (Write/Edit file paths, plus the files of every commit
# whose `[<branch> <sha>]` line appears in a Bash result), keeps the ones whose net
# content still differs from where the subagent started (its dispatch baseline: the HEAD
# dispatch-hygiene.sh recorded for its dispatch, sgb-u2), and blocks the stop
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
if ! declare -F identity_persona_name _portable_sha256 us_section us_entries us_exclusions us_excluded us_listed us_named_in us_classify unit_id_valid unit_id_sanitize >/dev/null; then
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
# The baseline is the dispatch baseline (sgb-u2): the HEAD that dispatch-hygiene.sh recorded when this
# writer was dispatched, read from the first line of .claude/reviewed/dispatch-baseline.log whose
# tool_use_id is the transcript's own (toolUseId in its .meta.json) and whose prompt hash is that of the
# transcript's dispatch message. The writer controls its timestamps, its commit lines and its commit
# dates, so none of them moves the baseline, and replace objects and grafts are off for every git call
# below. A commit line still adds its commit's files to the candidates. head=none (no commit at dispatch)
# is the empty tree. No usable record, or a recorded commit that is not an ancestor of HEAD: allowed when
# there is no candidate, else blocked (logged), never a fallback the writer could steer.
export GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE="$W/no-grafts"
while IFS= read -r s; do
  git cat-file -e "$s^{commit}" 2>/dev/null || continue
  git show --no-renames --name-only -z --format= "$s" >> "$W/cand"
done < "$W/shas"
tu="$(jq -r '.toolUseId // empty' "${tr_path%.jsonl}.meta.json" 2>/dev/null)"
ph="$(printf '%s' "$(cat "$W/prompt")" | _portable_sha256 - | cut -d' ' -f1)"
start=""; why="no record"
if [[ $tu =~ ^[A-Za-z0-9_]{1,128}$ ]]; then
  rec="$(awk -v t="tool_use_id=$tu" '$2 == t { print; exit }' "$dot/reviewed/dispatch-baseline.log" 2>/dev/null)"
  if [ -n "$rec" ]; then
    read -r _ _ rh rp _ <<< "$rec"
    if [ "$rp" != "prompt=$ph" ]; then why="record for another dispatch message"
    elif [ "$rh" = head=none ]; then start="$(git hash-object -t tree /dev/null)"
    elif [[ $rh =~ ^head=[0-9a-f]{40}$ ]] && git cat-file -e "${rh#head=}^{commit}" 2>/dev/null; then
      start="${rh#head=}"
      git merge-base --is-ancestor "$start" HEAD 2>/dev/null || { why="baseline ${start:0:10} is not an ancestor of HEAD"; start=""; }
    else why="record malformed or its commit is missing"
    fi
  fi
fi
if [ -z "$start" ]; then
  if [ ! -s "$W/cand" ]; then log "baseline: none ($why), nothing to judge"; allow; fi
  log "blocked: no dispatch baseline ($why)"
  echo "BLOCKED (writer-scope-gate): no dispatch baseline for this writer ($why), so your changes cannot be checked against your unit scope. Report this block to your dispatcher and wait; do not edit .claude/reviewed/." >&2
  exit 2
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
unit="$(sed -n 's/^Unit: //p' "$W/prompt" | head -n1)"; unit_id_valid "$unit" || unit=""
us_entries "$W/prompt" > "$W/listed"
# A bullet of the dispatch message's own list may name its path bare (tg-u2): the bullet's first word counts
# when, without backticks and a trailing `,:;`, it holds a `/` or a `.` and only path characters. A path later
# in the bullet's prose is never listed. Contract files keep the backtick rule (review-precheck reads them).
awk '/^[-*][[:space:]]/ { t = $0; sub(/^[-*][[:space:]]+/, "", t); split(t, w, /[[:space:]]+/); p = w[1]; gsub(/`/, "", p); sub(/[,:;]+$/, "", p)
       if (p ~ /[\/.]/ && p ~ /^[A-Za-z0-9._\/*?-]+$/) print p }' "$W/sec" >> "$W/listed"
us_exclusions "$W/prompt" > "$W/excl"
# The unit's own contract file, when the message cites it, always adds its list and its exclusions (tg-u2): a
# backticked token in a prose section (`.claude/`) no longer hides it. A contract is read as the baseline commit
# holds it, never from the working tree: this gate exempts `docs/plans/`, so a contract the writer edits or
# creates itself must not widen its own scope (a contract is committed before its dispatch). A cited path counts
# only as a clean `docs/plans/<slug>/contracts/<id>.md`, with no `.`, `..` or empty segment. Another unit's cited
# contract is read only when nothing is listed, as before, so a contract cited for context never widens the scope.
cs="$(grep -oE "docs/plans/[A-Za-z0-9._/-]*contracts/[${UNIT_ID_CHARCLASS}]+\.md" "$W/prompt")"
cfile() { # <cited path> <out file>: the contract at the baseline; false for an unclean path or one the baseline lacks
  case "/$1" in */../*|*/./*|*//*) return 1 ;; esac
  case "$1" in docs/plans/*/contracts/*.md) ;; *) return 1 ;; esac
  git show "$start:$1" > "$2" 2>/dev/null
}
own=0
if [ -n "$unit" ]; then
  while IFS= read -r c; do
    cfile "$c" "$W/own" || continue
    us_entries "$W/own" >> "$W/listed"; us_exclusions "$W/own" >> "$W/excl"; own=1; break
  done < <(printf '%s\n' "$cs" | awk -F/ -v u="$unit.md" '$NF == u')
fi
if [ "$own" = 0 ] && [ ! -s "$W/listed" ]; then
  while IFS= read -r c; do
    cfile "$c" "$W/own" || continue
    us_entries "$W/own" > "$W/listed"; us_exclusions "$W/own" > "$W/excl"; break
  done < <(printf '%s\n' "$cs")
fi
grep -oE 'file: `[^` ]+`' "$W/prompt" | sed 's/^file: `//; s/`$//' >> "$W/listed" || true
us_section "$W/prompt" "Acceptance criteria" | grep -E '^[0-9]+\. run: ' > "$W/crit" || true
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
