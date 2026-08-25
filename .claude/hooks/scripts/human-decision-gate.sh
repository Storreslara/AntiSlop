#!/usr/bin/env bash
# PreToolUse (Bash, Write|Edit). Blocks EVERY agent identity - reviewer
# included, empty/main-session agent_type included - from writing
# .claude/human-review/<task-id>/DECISION, the human's own resolution of a
# pending ESCALATE-TO-HUMAN packet. No grant branch and no fallback: unlike
# reviewed-path-gate.sh, no identity may ever write this file. Reads are
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
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/benign-command.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
audit="${project_dir}/.claude/review-audit.log"

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

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
  local re='^cat[[:space:]]+>>?[[:space:]]*[.]claude/reviewed/[A-Za-z0-9_][A-Za-z0-9_#.-]*[.](pass|fail|directed|blocked|escalated)[[:space:]]+<<'\''([A-Za-z0-9_]+)'\''$'

  while [ "${cmd: -1}" = $'\n' ]; do cmd="${cmd%$'\n'}"; done
  first="${cmd%%$'\n'*}"
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

deny() {
  { printf '%s decision-gate-denied identity=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
      >> "$audit"; } 2>/dev/null || true
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

Splitting the path across shell variables, or otherwise rephrasing so the
command text never spells it, is a self-authorized bypass for this gate - not
a sanctioned move. That workaround is scoped to reviewed-path-gate.sh, which
grants the reviewer an identity; this gate grants nobody. If the template does
not fit your write, report and wait instead.

That rule governs commands TARGETING this file. A mention that only narrates it
is allowed outright and needs no workaround: prose inside a single 'git commit'
message, a single-quoted read pattern, and a trailing '#' comment all pass. What
you hit is narrower - this command's text spells the path itself, or a mention
sits where bash would execute it.

To discard a resolved packet, delete the whole directory with
'rm -rf .claude/human-review/<task-id>' (its command text never spells DECISION).
MSG
  exit 2
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
    .claude/human-review/*/DECISION) deny ;;
    *) exit 0 ;;
  esac
fi

# Both substring tests read the QUOTE-JOINED text, not the raw command: bash
# concatenates adjacent fragments, so `.claude/human-rev'iew'/u1/DECISION` and
# `"DEC"'IS'"ION"` each spell a trigger token the raw text does not, and each
# really writes the file. Deleting the quote characters can only ADD occurrences
# - neither token contains one - so this subsumes the raw test. It does NOT
# close the residual CLASS of the same family, whose members reach the real file
# because the raw text never spells a trigger token at all. R-4's split variable
# and R-5's `DECISIO\N` are two examples of it, not the whole enumeration: the
# glob-metacharacter sub-class is wider and is tracked separately as F-1
# (docs/plans/2026-08-24-debug-hdg-prose-2-whitespace-id.md Part 4, pinned as
# F1a-F1d in the suite and deferred rather than accepted).
joined="${command//$'\047'/}"
joined="${joined//$'\042'/}"
case "$joined" in
  *human-review*) ;;
  *) exit 0 ;;
esac
case "$joined" in
  *DECISION*) ;;
  *) exit 0 ;;
esac

command_is_provably_benign "$command" && exit 0
write_with_inert_triggers "$command" && exit 0
is_prose_only_commit "$command" && exit 0
is_sanctioned_marker_write "$command" && exit 0
deny
