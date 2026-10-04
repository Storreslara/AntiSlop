#!/usr/bin/env bash
# PreToolUse (Bash, Write|Edit). Blocks EVERY agent identity - reviewer
# included, empty/main-session agent_type included - from writing
# .claude/human-review/<task-id>/DECISION, the human's own resolution of a
# pending ESCALATE-TO-HUMAN packet. No grant branch and no fallback: unlike
# reviewed-path-gate.sh, no identity may ever write this file on its own
# authority. The one exception is not a grant: for the main-session prompt
# route, is_prompt_eligible_decision_write() below turns this gate's deny into
# a permission "ask", so the file exists only if the human approves its exact
# bytes at Claude Code's permission prompt. The gate never allows it. Reads are
# allowed, a backslash inside a single-quoted span included. The shared lexer
# once failed closed on EVERY backslash, inert or not, and this header used to
# record that as a deliberately-open false positive; hdg-lexer-1 closed it
# (docs/plans/2026-08-24-human-decision-gate-prose-false-positive.md Step 1).
# What still fails closed is a backslash that changes bash's OWN lexing - a
# `$'...'` or `$"..."` span, an escaped quote inside double quotes, a line
# continuation, an escaped separator - because each of those moves where a write
# really lands (pinned in the suite as the P13 cases that name a backslash
# construct; P13-k, which sits inside that range, is the own-line-comment R-11
# residual instead and is not one of them).
#
# One write shape IS allowed, via is_sanctioned_marker_write() below: the
# sanctioned marker-write template, which exists because the protocol requires
# a `human:` attestation to quote the DECISION path verbatim inside a
# .claude/reviewed/<task-id>.pass marker. Blocking that is what caused the
# 2026-08-12 incident.
# The marker filename (id) charclass accepts the dispatch grammar: alphanumeric/
# underscore start, then alphanumeric/underscore/hash/dot/dash. This prevents
# leading-dot ids (.task) and rejects / (no directory escape), but allows
# dots/hashes within the id (e.g., gh345.1, gh#348). Traversal is prevented by
# the charclass rejecting both / and leading dots simultaneously.
#
# No adapter port exists for this gate, following the same precedent already
# set by reviewed-path-gate.sh, which likewise has none under
# adapters/*/hooks/scripts/.
#
# The sanctioned way to discard a resolved escalation packet is
# `rm -rf .claude/human-review/<task-id>` (the whole directory) - its command
# text never spells DECISION, so it passes the substring early-exit below and
# is never routed through command_is_provably_benign() at all. A per-file
# `rm .../DECISION` is blocked for every identity, reviewer included; that is
# intended, not a defect.
#
# STILL OPEN (disclosure, moved out of runtime denial stderr, gh419/RD4): the
# deny() message used to name the technique "[s]plitting the path across shell
# variables, or otherwise rephrasing so the command text never spells it" as a
# self-authorized bypass, cross-reference reviewed-path-gate.sh (which grants
# the reviewer an identity that this gate grants nobody), and attach the
# rationale clause "its command text never spells DECISION" to the `rm -rf`
# discard route. All of that stays true and lives here now, for a human
# reading this file at leisure; the runtime denial states only the blocked
# action, the sanctioned route, and one flat, technique-free prohibition on
# everything else.
#
# The gate's only config read is reviewGating.mode: under exactly "off" there
# is no escalation, hence no DECISION to protect, so the gate exits 0 - read
# only once a Write/Edit path or the Bash text has already hit a DECISION.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/benign-command.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"

input="$(cat)"
config="${CLAUDE_PROJECT_DIR:-.}/.claude/persona-config.json"
gating_off() { [ "$(jq -r '.reviewGating.mode // "enforce"' "$config" 2>/dev/null || echo enforce)" = "off" ]; }
project_dir="${CLAUDE_PROJECT_DIR:-.}"
audit="${project_dir}/.claude/review-audit.log"

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"
agent_id="$(echo "$input" | jq -r '.agent_id // empty' 2>/dev/null || true)"
permission_mode="$(echo "$input" | jq -r '.permission_mode // empty' 2>/dev/null || true)"

# The one command shape allowed past command_is_provably_benign(): a marker
# write whose heredoc body may quote the DECISION path as inert data. Safety
# rests on four properties, together proven against the attack suite in
# tests/human-decision-gate.test.sh (named rather than counted, because the
# count in this comment had already drifted twice):
# only the first physical line is code and it must match end-to-end, so nothing
# rides along; the delimiter is single-quoted, which is bash's own guarantee the
# body is wholly inert; the target is a bare literal under .claude/reviewed/
# whose id charclass excludes `/` and rejects leading dots, preventing
# any traversal; and the first line equal to the delimiter must be the LAST line,
# without which a body could close the heredoc early and run whatever follows.
is_sanctioned_marker_write() {
  local cmd="$1" first delim rest line
  # Under a UTF-8 locale [[:space:]] also matches Unicode spaces (U+3000 etc.).
  local LC_ALL=C
  local re='^cat[[:space:]]+>>?[[:space:]]*[.]claude/reviewed/[A-Za-z0-9_]['"${UNIT_ID_CHARCLASS}"']*[.](pass|fail|directed|blocked|escalated|countersign)[[:space:]]+<<'\''([A-Za-z0-9_]+)'\''$'

  while [ "${cmd: -1}" = $'\n' ]; do cmd="${cmd%$'\n'}"; done
  first="${cmd%%$'\n'*}"
  # [[:space:]] below also matches \v, \f and \r, which bash does not split on.
  [[ $first == *[$'\v\f\r']* ]] && return 1  # MARKER-WS
  [ "$first" != "$cmd" ] || return 1
  [[ $first =~ $re ]] || return 1
  delim="${BASH_REMATCH[2]}"

  rest="${cmd#*$'\n'}"
  while :; do
    line="${rest%%$'\n'*}"
    if [ "$line" = "$rest" ]; then
      [ "$line" = "$delim" ] && return 0
      return 1
    fi
    [ "$line" = "$delim" ] && return 1
    rest="${rest#*$'\n'}"
  done
}

# The one shape this gate ASKS on - it never allows (esc-chat-2,
# docs/plans/2026-10-01-in-session-escalation-decision.md): the main session
# recording the human's in-chat answer as the composer's exact heredoc
# (decision-block.js composeHeredocCommand + composeEscalationDecisionBody,
# via: 'prompt'). Claude Code renders the prompt from the tool call itself, so
# the bytes the human approves are the file. Same parse discipline as
# is_sanctioned_marker_write(): the first line is the only code and matches
# end-to-end, only `>` (never `>>`), the delimiter is exactly 'EOF', and the
# first line equal to it is the last line. Sets pg_id, pg_route and
# pg_escalation for the two helpers below and for ask_decision().
#
# The mode allowlist is FROZEN, never a denylist: default, acceptEdits and auto
# only (Amendment A1). plan is excluded because it is read-only, so there is
# no write approval for a human to make there. bypassPermissions and dontAsk
# are excluded because a silent auto-approve there would be an undetectable
# fabricated approval. An empty, absent or unknown mode denies too.
#
# esc-chat-2b, two deliberate tightenings of the plan's first-line regex:
# - Separators are [ \t], not the plan's [[:space:]]. [[:space:]] also matches
#   \v, \f and \r, which bash does NOT split words on: `cat\v> <path>` (a
#   vertical tab) reached ask, and once approved bash created an empty target
#   and then failed rc 127.
# - The target is absolute and its prefix must equal $project_dir exactly. A
#   relative target resolves against the Bash tool's cwd, which this gate cannot
#   see, while every eligibility check below runs under $project_dir; with the
#   absolute form the approved bytes alone fix where the file lands. The prefix
#   class matches decision-block.js PROJECT_DIR_RE, and that composer emits it.
is_prompt_eligible_decision_write() {
  local cmd="$1" first n i ws=$' \t'
  local re='^cat['"$ws"']+>['"$ws"']*((/[A-Za-z0-9_.-]+)+)/[.]claude/human-review/([A-Za-z0-9_]['"${UNIT_ID_CHARCLASS}"']*)/DECISION['"$ws"']+<<'\''EOF'\''$'
  local -a lines
  [ -z "$agent_id" ] || return 1
  case "$permission_mode" in
    default|acceptEdits|auto) ;;
    *) return 1 ;;
  esac
  while [ "${cmd: -1}" = $'\n' ]; do cmd="${cmd%$'\n'}"; done
  first="${cmd%%$'\n'*}"
  [ "$first" != "$cmd" ] || return 1
  [[ $first =~ $re ]] || return 1
  [ "${BASH_REMATCH[1]}" = "$project_dir" ] || return 1
  pg_id="${BASH_REMATCH[3]}"
  mapfile -t lines <<< "${cmd#*$'\n'}"
  n=${#lines[@]}
  [ "${lines[n-1]}" = EOF ] || return 1
  for ((i = 0; i < n - 1; i++)); do
    [ "${lines[i]}" != EOF ] || return 1
  done
  decision_body_ok "${lines[@]:0:n-1}" || return 1
  decision_target_eligible
}

# The DECISION body grammar, one argument per body line (R4: no reserved key
# may be forged inside a reason). Reason and continuation lines ban [[:cntrl:]]
# as by: does, since an ESC/CR sequence repaints the prompt into a line the file
# does not hold. The reserved-key screen is ASCII case-insensitive and tolerates
# leading and pre-colon spaces; the explicit [Vv] pairs keep it locale-free and
# equal to decision-block.js RESERVED_KEY_RE. forbidden_bytes() screens all
# three line kinds bytewise, so the verdict does not depend on the locale.
decision_body_ok() {
  local iso='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]{1,3})?Z'
  local head_re="^DECISION [^ ]+ ${iso} route: (approve|reject|direct) escalation: ${iso}\$"
  local by_re='^by: [^[:cntrl:]]+$' reason_re='^reason: [^[:cntrl:]]+$' bid line
  local reserved_re='^ *([Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn] |([Bb][Yy]|[Vv][Ii][Aa]|[Ee][Xx][Aa][Mm][Pp][Ll][Ee][Ss]|[Rr][Ee][Aa][Ss][Oo][Nn]) *:)'
  local examples="$project_dir/.claude/human-review/$pg_id/EXAMPLES.md"
  [ "$#" -ge 3 ] || return 1
  [[ $1 =~ $head_re ]] || return 1
  read -r _ bid _ _ pg_route _ pg_escalation <<< "$1"
  [ "$bid" = "$pg_id" ] || return 1
  [[ $2 =~ $by_re ]] && ! forbidden_bytes "$2" || return 1
  [ "$3" = 'via: prompt' ] || return 1
  shift 3
  if [ "$pg_route" = approve ]; then
    [ "$#" -le 1 ] || return 1
    case "${1-}" in
      '') [ "$#" -eq 0 ] ;;
      'examples: reviewed'|'examples: skipped') [ -e "$examples" ] ;;
      'examples: none-offered') [ ! -e "$examples" ] ;;
      *) return 1 ;;
    esac
    return
  fi
  [ "$#" -ge 1 ] && [[ $1 =~ $reason_re ]] && ! forbidden_bytes "$1" || return 1
  shift
  for line in "$@"; do
    [[ $line != *[[:cntrl:]]* ]] && [[ ! $line =~ $reserved_re ]] && ! forbidden_bytes "$line" || return 1
  done
}

# True when a body line holds a byte sequence the prompt route refuses
# (esf-gate-bytes): C0 and DEL, C1 (U+009B CSI included), U+2028/9, and the
# zero-width and bidi characters that let the approved prompt render text the
# file does not hold. Matched BYTEWISE whatever locale the gate inherits - under
# LC_ALL=C the reviewer measured 7 composer-refused bodies reaching ask. The
# LEAD-NONASCII screen refuses a non-ASCII byte before the line's first ASCII
# letter or digit (NBSP, U+3000 and other lookalike lead-ins); a by: or reason:
# line leads with an ASCII letter, so it only ever bites a continuation line.
# decision-block.js CONTROL_RE and LEAD_NONASCII_RE refuse exactly this set.
forbidden_bytes() {
  local LC_ALL=C
  [[ $1 == *[[:cntrl:]]* ]] && return 0  # BYTE-C0
  [[ $1 == *$'\xc2'[$'\x80'-$'\x9f']* ]] && return 0  # BYTE-C1
  [[ $1 == *$'\xe2\x80'[$'\xa8\xa9']* ]] && return 0  # BYTE-LS
  [[ $1 == *$'\xe2\x80'[$'\x8b'-$'\x8f'$'\xaa'-$'\xae']* ]] && return 0  # BYTE-BIDI
  [[ $1 == *$'\xe2\x81'[$'\xa0'$'\xa6'-$'\xa9']* ]] && return 0  # BYTE-BIDI
  [[ $1 == *$'\xef\xbb\xbf'* ]] && return 0  # BYTE-BIDI
  [[ $1 == *$'\xd8\x9c'* ]] && return 0  # BYTE-BIDI
  [[ ${1%%[A-Za-z0-9]*} == *[![:ascii:]]* ]] && return 0  # LEAD-NONASCII
  return 1
}

# Filesystem eligibility: the packet exists, holds no DECISION yet, and the
# standing .escalated marker's first line names this id and the timestamp the
# body cites. Neither the packet nor human-review may be a symlink, which would
# land the write outside the directory the checks above describe.
decision_target_eligible() {
  local packet="$project_dir/.claude/human-review/$pg_id" marker_first marker_id marker_ts
  [ -d "$packet" ] && [ ! -L "$packet" ] && [ ! -L "${packet%/*}" ] || return 1
  [ ! -e "$packet/DECISION" ] && [ ! -L "$packet/DECISION" ] || return 1
  marker_first="$(state_read_unit_marker "$pg_id" escalated 2>/dev/null | sed -n 1p)" || return 1
  read -r _ marker_id marker_ts _ <<< "$marker_first"
  [ "$marker_id" = "$pg_id" ] && [ -n "$marker_ts" ] && [ "$marker_ts" = "$pg_escalation" ]
}

# True when some run of the text spells BOTH trigger tokens with no whitespace
# between them - i.e. the text names the file as a path, in any quoting,
# dot-segments, `..` traversal and repeated slashes included. Unconditional: a
# spelled path is denied wherever it sits, a commit message and a comment
# included, because this gate cannot resolve a target and must not try.
#
# A quote character does NOT end a run; it is deleted and the fragments on
# either side JOIN. Bash concatenates adjacent quoted and unquoted fragments
# into one word, so `'<dir>/'"DECISION"` names the file exactly as the bare
# spelling does - treating the quote as a terminator saw two harmless halves and
# let an allowlisted program write the real file (measured fail-open, pinned as
# Q1-Q16 in the suite). Whitespace still ends a run even INSIDE quotes, which is
# what keeps a prose sentence naming both tokens from reading as a path - but
# that is a property of THIS scan, not of the protected set. A bash word may
# contain a space and so may this gate's file: nothing constrains the packet
# directory's name at creation time (the reviewer derives it from the free-form
# `Unit: <id>` dispatch line, dispatchHygiene.mode is "warn" rather than "block",
# and reviewer spawns are not gated by that grammar at all), and the Write/Edit
# branch below already denies such a path through a `*` glob.
# has_whitespace_id_packet_path() is what makes the two branches agree about the
# identical path string; without it they disagreed, and the Bash branch was the
# looser of the two (measured fail-open, pinned as W1-W16 and U1-U126). That
# agreement is now unqualified rather than holding only for path-safe ids: the
# branch it agrees with is the `.claude/human-review/*/DECISION` case below, and
# the suite asserts the two verdicts EQUAL over a punctuation x id-shape x
# prefix-spelling corpus.
#
# Deliberately a pure-bash scan - tokenizing via $(printf ... | tr ...) would
# word-split AND glob, and a bare `*` in a commit message then expands to every
# filename in the repository (measured: 22 of them).
has_path_shaped_occurrence() {
  # \047 and \042 are ' and ". Spelled as escapes so a literal quote inside the
  # pattern cannot unbalance this file's own quoting.
  local rest="$1" run="" chunk sep ws=$' \t\n' seps=$' \t\n\047\042'
  while :; do
    chunk="${rest%%[$seps]*}"
    run="$run$chunk"
    case "$run" in
      *human-review*) case "$run" in *DECISION*) return 0 ;; esac ;;
    esac
    [ "$chunk" != "$rest" ] || return 1
    sep="${rest:${#chunk}:1}"
    rest="${rest:${#chunk}+1}"
    case "$sep" in [$ws]) run="" ;; esac
  done
}

# Companion to the run scan, covering the one word shape it structurally cannot
# see: a packet directory whose NAME holds whitespace. Two arms, either of which
# denies, applied to the head between a `human-review` and the first `/DECISION`
# after it in the quote-joined text.
#
# Arm 1 - path-safe characters only: the marker id charclass plus `/`, space and
# tab. Newline is deliberately NOT path-safe, which is what keeps a multi-line
# commit message naming the two tokens on different lines allowed.
#
# Arm 2 - the head BEGINS with `/` and holds no newline. This one is anchored to
# the protected path's own STRUCTURE rather than to the id's characters: the path
# is .claude/human-review/<task-id>/DECISION, so the character straight after
# `human-review` is always `/`. Prose naming the two tokens interposes something
# else first (`, `, ` packet -> `, `: `), which is what keeps the commit-message
# allowance standing. Arm 2 exists because arm 1 alone made the verdict depend on
# WHICH characters an id spelled: an id holding both whitespace and one character
# outside the charclass (`my unit!`, `u: 1`) escaped arm 1 on the punctuation and
# the run scan on the whitespace, and really wrote the file. That was the third
# character dimension to cost this function a fail-open, after quote boundaries
# and quoted whitespace, so arm 2 deliberately names no characters at all.
#
# The binding property is BRANCH AGREEMENT with the Write/Edit branch below,
# which is this gate's own definition of the protected set: for any path, the
# verdict on `printf x > '<path>'` equals the verdict on a Write to `<path>`.
# The suite asserts that equality rather than a fixed verdict, so it cannot rot
# when the protected set next changes.
#
# STILL OPEN, and the one path where the two branches disagree: an id holding a
# NEWLINE. Arm 1 misses it because newline is not path-safe, arm 2 because it
# excludes newline, the run scan because newline is whitespace and ends a run.
# It is not closable behind arm 2's newline exclusion, which is the only thing
# keeping a multi-line commit message that names the two tokens on separate
# lines allowed - the exact false positive the parent units exist to remove.
# Tracked open, pinned as NL1 in the suite, NOT accepted.
#
# It sits BESIDE has_path_shaped_occurrence(), never in place of it, and is
# never consulted to permit anything - so it can only ever add denials.
has_whitespace_id_packet_path() {
  # \047 and \042 are ' and ", spelled as escapes for the same reason as above.
  local rest="$1" head
  rest="${rest//$'\047'/}"
  rest="${rest//$'\042'/}"
  while :; do
    case "$rest" in
      *human-review*) rest="${rest#*human-review}" ;;
      *) return 1 ;;
    esac
    case "$rest" in
      */DECISION*)
        head="${rest%%/DECISION*}"
        # Only the FIRST /DECISION is worth testing: every later one has a head
        # that CONTAINS this one, so a head that failed both arms can never
        # become safe by growing. Arm 1 is monotone because an unsafe character
        # stays present; arm 2 for the same reason in both halves - "begins with
        # `/`" is fixed by the head's first character, which a longer head keeps,
        # and "holds no newline" only ever degrades as the head grows. A failed
        # head therefore means this `human-review` is spent - go on to the next
        # one rather than to the next `/DECISION`.
        case "$head" in
          *[!A-Za-z0-9_$' \t'/.#-]*) ;;
          *) return 0 ;;
        esac
        case "$head" in
          /*) case "$head" in *$'\n'*) ;; *) return 0 ;; esac ;;
        esac
        ;;
    esac
  done
}

# Shared precondition for both allowances below: bash cannot act on any mention.
# No substitution - read from the RAW text, since double quotes do not inhibit
# `$(` or backticks; neither path condition above may hold; the command must
# lex; and no trigger may survive into the skeleton's CODE text.
# command_skeleton() masks quoted spans and comment bodies to X, so a trigger
# still visible in the skeleton sat where bash would execute it or use it as a
# redirection target - `printf x > DECISION` with a `# human-review` comment is
# denied here, and would otherwise write the real file whenever the cwd is the
# packet directory.
triggers_are_inert() {
  local cmd="$1" skel
  case "$cmd" in *'`'*|*'$('*|*'<('*) return 1 ;; esac
  has_path_shaped_occurrence "$cmd" && return 1
  has_whitespace_id_packet_path "$cmd" && return 1
  skel="$(command_skeleton "$cmd")" || return 1
  case "$skel" in *human-review*|*DECISION*) return 1 ;; esac
  return 0
}

# command_is_provably_benign() with its write test replaced by the condition
# above: this gate guards ONE file, so a write that provably cannot name it is
# not its business. The program allowlist still applies, which is what keeps
# `sh -c 'cd .claude/human-review/u1 && printf x > DECISION'` denied.
write_with_inert_triggers() {
  local cmd="$1" skel rest head start=0 seps=$';&|\n'
  triggers_are_inert "$cmd" || return 1
  skel="$(command_skeleton "$cmd")" || return 1
  skel="$(mask_inert_redirections "$skel")"
  if printf '%s' "$skel" | grep -Eq '(^|[^[:alnum:]_])(eval|exec|source)([^[:alnum:]_]|$)'; then
    return 1
  fi
  rest="$skel"
  while :; do
    head="${rest%%[$seps]*}"
    segment_allowed "${cmd:start:${#head}}" || return 1
    [ "$head" != "$rest" ] || return 0
    start=$((start + ${#head} + 1))
    rest="${rest:${#head}+1}"
  done
}

# A single `git commit` whose only mention is prose in its message. `git` is
# absent from the SHARED program_allowed() (benign-command.sh:12-14, "do not
# re-add either one") and STAYS absent - this judgment is local to this file,
# exactly as is_sanctioned_marker_write() is. It is sound because the capability
# is message-independent: the identical commit carrying different prose is
# already allowed, and a repository pre-commit hook runs either way, so refusing
# on prose alone was removing no capability at all. What keeps the attacks denied
# is the rest: no redirection, exactly one segment, and both words fixed - which
# is what rejects `git -c core.hooksPath=... commit` and every chained write.
is_prose_only_commit() {
  local cmd="$1" skel first sub ops=$'>;&|\n<'
  triggers_are_inert "$cmd" || return 1
  skel="$(command_skeleton "$cmd")" || return 1
  case "$skel" in *[$ops]*) return 1 ;; esac
  # `first`/`sub` are read from the RAW cmd, not the skeleton, and that is safe
  # only because of the guard immediately above: `ops` holds every separator, so
  # by here the command is provably ONE segment, and command_skeleton() is
  # length-preserving, so the two texts agree on where words begin. Widening
  # `ops` is fine; NARROWING it - dropping a separator - would let `read` reach
  # across one and report a first word that is not the segment's.
  read -r first sub _ <<< "$cmd"
  [ "$first" = git ] && [ "$sub" = commit ]
}

# F-1 (esc-left-3, docs/plans/2026-10-04-escalation-leftovers.md): sets glob_h /
# glob_d when an unquoted glob, extglob or brace word could expand to the
# human-review directory / the DECISION file, though the text never spells it.
# Quotedness comes from command_skeleton(): a masked character is literal, a
# kept quote character only joins fragments, and a quoted `/` still separates
# components. When the skeleton cannot lex, the raw text is scanned with every
# metacharacter live (fail closed), minus only the bodies of heredocs whose
# delimiter is quoted, which bash never expands. Matching assumes the worst
# shell options (A2): nocasematch and extglob are switched on here and restored
# before returning. Locale: LC_ALL=C - both tokens are ASCII, and C keeps the
# byte-oriented pattern operations below locale-independent.
glob_names_tokens() {
  local cmd="$1" skel had_ext=0 had_nc=0
  glob_h=0 glob_d=0
  case "$cmd" in *[\*\?\[\{]*|*[@+!]\(*) ;; *) return 0 ;; esac
  local LC_ALL=C
  shopt -q extglob && had_ext=1
  shopt -q nocasematch && had_nc=1
  shopt -s extglob nocasematch
  if skel="$(command_skeleton "$cmd")"; then
    glob_scan_words "$cmd" "$skel"
  else
    glob_strip_quoted_heredoc_bodies "$cmd"
    glob_text="${glob_text//[\'\"]/}"
    glob_scan_words "$glob_text" "$glob_text"
  fi
  [ "$had_ext" = 1 ] || shopt -u extglob
  [ "$had_nc" = 1 ] || shopt -u nocasematch
  return 0
}

# Splits $1 into words at unquoted metacharacters, read off the aligned skeleton
# $2, and hands every word holding an unquoted glob to glob_word(). An extglob
# group - `(` straight after an unquoted ?*+@! - stays inside its word.
glob_scan_words() {
  local text="$1" skel="$2" rest chunk sep start=0 off=0 depth r c
  local metas=$' \t\n;&|<>()'
  rest="$skel"
  while :; do
    chunk="${rest%%[$metas]*}"
    off=$((off + ${#chunk}))
    if [ "$chunk" = "$rest" ]; then
      glob_maybe_word "${text:start:off-start}" "${skel:start:off-start}"
      return 0
    fi
    sep="${rest:${#chunk}:1}"
    if [ "$sep" = '(' ] && [ "$off" -gt "$start" ] && [[ ${skel:off-1:1} == [\?\*+@!] ]]; then
      depth=1 r="${rest:${#chunk}+1}"
      off=$((off + 1))
      while [ "$depth" -gt 0 ]; do
        c="${r%%[()]*}"
        if [ "$c" = "$r" ]; then off=$((off + ${#r})); r=""; break; fi
        [ "${r:${#c}:1}" = '(' ] && depth=$((depth + 1)) || depth=$((depth - 1))
        off=$((off + ${#c} + 1))
        r="${r:${#c}+1}"
      done
      rest="$r"
      continue
    fi
    glob_maybe_word "${text:start:off-start}" "${skel:start:off-start}"
    off=$((off + 1))
    start=$off
    rest="${rest:${#chunk}+1}"
  done
}

# $1 one word's text, $2 its skeleton. Builds the pattern word - unquoted
# characters live, masked ones escaped, quote characters dropped - with quoted
# `{` `}` `,` held as \001 \002 \003 so brace parsing sees only unquoted ones.
glob_maybe_word() {
  local t="$1" s="$2" out="" run seg c
  case "$s" in *[\*\?\[\{]*|*[@+!]\(*) ;; *) return 0 ;; esac
  while [ -n "$s" ]; do
    run="${s%%[X\'\"]*}"
    out="$out$run"
    s="${s:${#run}}" t="${t:${#run}}"
    [ -n "$s" ] || break
    if [ "${s:0:1}" = X ]; then
      run="${s%%[!X]*}"
      seg="${t:0:${#run}}"
      seg="${seg//\\/\\\\}"
      for c in '*' '?' '[' ']' '(' ')' '|' '@' '!' '+'; do seg="${seg//"$c"/\\$c}"; done
      seg="${seg//\{/$'\001'}" seg="${seg//\}/$'\002'}" seg="${seg//,/$'\003'}"
      out="$out$seg"
      s="${s:${#run}}" t="${t:${#run}}"
    else
      s="${s:1}" t="${t:1}"
    fi
  done
  glob_word "$out"
}

# Brace groups, innermost first, until none is left: a group with a top-level
# comma expands to its alternatives (no eval), `${...}` and every other group
# collapse to `*`, except a comma-free group holding `/`, which names both
# tokens. More than 256 expansions names both too.
glob_word() {
  local -a queue=("$1")
  local w pre left inner alt n=1
  while [ "${#queue[@]}" -gt 0 ]; do
    w="${queue[0]}"
    queue=("${queue[@]:1}")
    pre="${w%%\}*}"
    if [ "$pre" = "$w" ]; then glob_match_path "$w"; continue; fi
    left="${pre%\{*}"
    if [ "$left" = "$pre" ]; then queue+=("$pre"$'\002'"${w:${#pre}+1}"); continue; fi
    inner="${pre:${#left}+1}"
    w="${w:${#pre}+1}"
    if [ "${left: -1}" = '$' ]; then
      queue+=("${left%\$}*$w")
    elif [[ $inner == *,* ]]; then
      while :; do
        alt="${inner%%,*}"
        queue+=("$left$alt$w")
        n=$((n + 1))
        [ "$alt" != "$inner" ] || break
        inner="${inner#*,}"
      done
    elif [[ $inner == */* && $inner != *..* ]]; then
      glob_h=1 glob_d=1
      return 0
    else
      queue+=("$left*$w")
    fi
    if [ "$n" -gt 256 ]; then glob_h=1 glob_d=1; return 0; fi
  done
}

# $1 one expanded pattern word: the last component that can match DECISION
# names the file, any earlier one that can match human-review the directory.
glob_match_path() {
  local rest="$1" comp
  rest="${rest//$'\001'/\{}" rest="${rest//$'\002'/\}}" rest="${rest//$'\003'/,}"
  while :; do
    comp="${rest%%/*}"
    if [ "$comp" = "$rest" ]; then
      [[ DECISION == $comp ]] && glob_d=1
      return 0
    fi
    [[ human-review == $comp ]] && glob_h=1
    rest="${rest#*/}"
  done
}

# Sets glob_text to $1 without the body lines of every heredoc whose delimiter
# is quoted (from the operator line up to the first line equal to the
# delimiter). If any code line does not lex, or a terminator is never found,
# glob_text is $1 unchanged: nothing is narrowed unless it is fully modelled.
glob_strip_quoted_heredoc_bodies() {
  local cmd="$1" line cmp out=""
  local -a lines
  glob_hd=()
  glob_text="$cmd"
  case "$cmd" in *'<<'*) ;; *) return 0 ;; esac
  mapfile -t lines <<< "$cmd"
  for line in "${lines[@]}"; do
    if [ "${#glob_hd[@]}" -gt 0 ]; then
      cmp="$line"
      if [ "${glob_hd[0]:0:1}" = - ]; then
        while [ "${cmp:0:1}" = $'\t' ]; do cmp="${cmp:1}"; done
      fi
      if [ "$cmp" = "${glob_hd[0]:2}" ]; then
        glob_hd=("${glob_hd[@]:1}")
      elif [ "${glob_hd[0]:1:1}" = u ]; then
        out="$out$line"$'\n'
      fi
      continue
    fi
    out="$out$line"$'\n'
    glob_heredoc_ops "$line" || return 0
  done
  [ "${#glob_hd[@]}" -eq 0 ] || return 0
  glob_text="$out"
}

# Appends one entry per real heredoc operator on code line $1 to glob_hd:
# <dash|.><q|u><delimiter>. Fails when the line does not lex. Each `<<` is
# re-spelled `<;` (same length, same word-start behaviour) so the skeleton
# shows which ones sit outside quotes and comments.
glob_heredoc_ops() {
  local line="$1" sk pre real a s dash word ws q
  local metas=$' \t\n;&|<>()'
  case "$line" in *'<<'*) ;; *) return 0 ;; esac
  sk="$(command_skeleton "${line//<</<;}")" || return 1
  while :; do
    pre="${line%%<<*}"
    [ "$pre" != "$line" ] || return 0
    real=0
    [ "${sk:${#pre}:2}" != '<;' ] || real=1
    line="${line:${#pre}+2}" sk="${sk:${#pre}+2}"
    # `<<<` is a here-string, not a heredoc
    if [ "${line:0:1}" = '<' ]; then line="${line:1}" sk="${sk:1}"; continue; fi
    [ "$real" = 1 ] || continue
    a="$line" s="$sk"
    dash=.
    if [ "${a:0:1}" = - ]; then dash=- a="${a:1}" s="${s:1}"; fi
    while [[ ${a:0:1} == [$' \t'] ]]; do a="${a:1}" s="${s:1}"; done
    ws="${s%%[$metas]*}"
    word="${a:0:${#ws}}"
    [ -n "$word" ] || return 1
    case "$word" in *[\'\"]*) q=q ;; *) q=u ;; esac
    glob_hd+=("$dash$q${word//[\'\"]/}")
  done
}

deny() {
  audit_append "$audit" "$(printf '%s decision-gate-denied identity=%s' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")")"
  printf "BLOCKED: '%s' may not write .claude/human-review/<task-id>/DECISION - that file records the human's own resolution of a pending escalation and no agent identity may create or modify it, reviewer included.\n" "$agent_type" >&2
  cat >&2 <<'MSG'

If you are writing a review marker whose body must quote that path verbatim,
use the sanctioned marker-write template - this gate allows it:

cat > .claude/reviewed/<task-id>.pass <<'EOF'
<marker body; the delimiter is single-quoted, so nothing here expands>
EOF

Rules: the delimiter must be single-quoted, the target a bare literal
.claude/reviewed/<id>.{pass,fail,directed,blocked,escalated}, and the
terminator the last line of the command. >> works in place of >.

The human records a decision in the terminal or the dashboard, or - from the
main session only - by approving the exact decision heredoc at Claude Code's
permission prompt, which this gate asks for and never grants by itself. Any
other route to it is a
self-authorized bypass whether or not this gate blocks it; if no sanctioned
route fits, report and wait.

That rule governs commands TARGETING this file. A mention that only narrates it
is allowed outright and needs no workaround: prose inside a single 'git commit'
message, a single-quoted read pattern, and a trailing '#' comment all pass. What
you hit is narrower - this command's text spells the path itself, or a mention
sits where bash would execute it.

To discard a resolved packet, delete the whole directory with
'rm -rf .claude/human-review/<task-id>'.
MSG
  exit 2
}

# Logged BEFORE the human answers (R7): an asked line with no DECISION file
# afterwards means the human declined. The reason is a frozen literal built
# only from the parsed route enum and the task id.
ask_decision() {
  audit_append "$audit" "$(printf '%s decision-gate-asked identity=%s task=%s route=%s mode=%s' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
      "$pg_id" "$pg_route" "$permission_mode")"
  jq -n --arg r "This records route=$pg_route as YOUR decision on escalation $pg_id, exactly as shown in the command below. Approve only if it matches what you chose; otherwise choose No." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
}

if [ -z "$command" ]; then
  has_path="$(echo "$input" | jq -r '(.tool_input|type) == "object" and (.tool_input|has("file_path"))' 2>/dev/null)" || exit 0
  [ "$has_path" = true ] || exit 0
  file_path="$(echo "$input" | jq -r '.tool_input.file_path // "" | tostring' 2>/dev/null || true)"
  subject="$(normalize_path "$file_path")"
  case "$subject" in
    "$project_dir"/*) subject="${subject#"$project_dir"/}" ;;
  esac
  case "$subject" in
    .claude/human-review/*/DECISION) gating_off && exit 0; deny ;;
    *) exit 0 ;;
  esac
fi

# Both substring tests read the QUOTE-JOINED text, not the raw command: bash
# concatenates adjacent fragments, so `.claude/human-rev'iew'/u1/DECISION` and
# `"DEC"'IS'"ION"` each spell a trigger token the raw text does not, and each
# really writes the file. Deleting the quote characters can only ADD occurrences
# - neither token contains one - so this subsumes the raw test. A token also
# counts as present when glob_names_tokens() finds an unquoted glob, extglob or
# brace word that could expand to it, which closes F-1 for the frozen family
# table of docs/plans/2026-10-04-escalation-leftovers.md (esc-left-3, pinned as
# F1a-F1d and FG-* in the suite); such a command then fails closed - past the
# prompt route and command_is_provably_benign(), only is_sanctioned_marker_write()
# may allow it. Residuals that remain, because the text names neither token even
# as a pattern: a write from a cwd inside the packet directory with
# `human-review` never spelled anywhere (A3), R-4's split variable, R-5's
# `DECISIO\N`, and NL1's newline in the id (A4).
joined="${command//$'\047'/}"
joined="${joined//$'\042'/}"
glob_names_tokens "$command"
case "$joined" in
  *human-review*) ;;
  *) [ "$glob_h" = 1 ] || exit 0 ;;
esac
case "$joined" in
  *DECISION*) ;;
  *) [ "$glob_d" = 1 ] || exit 0 ;;
esac
gating_off && exit 0

is_prompt_eligible_decision_write "$command" && ask_decision
command_is_provably_benign "$command" && exit 0
if [ "$glob_h" = 1 ] || [ "$glob_d" = 1 ]; then
  is_sanctioned_marker_write "$command" && exit 0
  deny
fi
write_with_inert_triggers "$command" && exit 0
is_prose_only_commit "$command" && exit 0
is_sanctioned_marker_write "$command" && exit 0
deny
