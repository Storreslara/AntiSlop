#!/usr/bin/env bash
# PreToolUse (Bash). Attributes the caller from the top-level `agent_type`
# field and blocks Bash commands whose text touches `.claude/reviewed` (the
# PASS-marker directory) unless the caller is the reviewer, or the main
# session/team lead in the documented no-reviewer fallback (personaSelection
# does NOT contain "reviewer" - start-feature-team.md:49-53, orchestrator.md's
# "if no reviewer persona exists"). Any other caller (lead-programmer above
# all) is blocked. Guards on persona-config.json existing, same as every other
# gate.
#
# `agent_type` carries an AGENT IDENTITY - the possibly-namespaced wire value
# "[<namespace>:]<persona-name>" - not a bare persona name. Probe A
# (docs/experiments/2026-07-probe-hook-payloads.md) established that the field
# is PRESENT on a subagent-issued Bash PreToolUse payload; it did not establish
# its value space, and the field is in fact observed arriving namespaced
# (`antislop:reviewer`). Both sides are therefore normalized through
# lib/agent-identity.sh, with the two matchers failing in opposite directions
# by design: the reviewer-may-write decision is a privilege GRANT and uses the
# conservative matcher (a foreign namespace must never inherit authority over
# the PASS markers), while the personaSelection test is a GATE and uses the
# liberal one, since a miss there only makes the main session's write allowed.
#
# Write-intent allowlist (docs/plans/2026-07-31-reviewed-path-gate-write-intent.md):
# past the substring early-exit, a Bash command mentioning ".claude/reviewed"
# is allowed if command_is_provably_benign() below finds it read-only or
# text-only (ls, cat, grep, gh ...) and blocked otherwise, so read-only
# inspection and prose mentions of the path are no longer collateral.
# This is advisory, not airtight - a determined agent can still obfuscate the
# path past both the substring early-exit and the allowlist (e.g. splitting it
# across a shell variable); see README.md's "Known limitations", same framing
# as the existing `sed -i` bypass caveat on protected-paths.sh.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"

# $1 the whole segment, $2 its first word, $3 its second word (subcommand).
# Allowlist-shaped on purpose: anything unrecognized is NOT allowed, so the
# gate keeps failing closed for command forms nobody enumerated.
#
# `git` and `rg` were on this list until issue #186 and their absence is
# DELIBERATE - do not re-add either one, and in particular do not re-add
# `git log`/`git diff` as a read-only convenience. Both programs consult
# OUT-OF-BAND CONFIGURATION: configuration read at run time from disk or from
# the process environment, which appears nowhere in the command line this gate
# inspects, and which can name a program of the caller's choosing. The flag scan
# they used to carry was deleted with them (recover it from git history or from
# docs/plans/2026-07-31-program-allowed-flag-boundary.md) because it could not
# help: the decisive input was never in the command's text, and the earlier
# command that arms it need never mention the marker directory, so the
# substring early-exit below returns before any of this runs. Validating ambient
# state would mean enumerating a third-party program's entire configuration
# surface - a denylist, which fails open on every key the enumeration missed -
# so the surface was removed instead of inspected. `git commit` is unsound here
# on a second, independent ground: a repository's own `.git/hooks/pre-commit`
# executes by design, with no configuration involved at all.
#
# Documented workarounds for what this costs: `git commit -F <file>` for a
# commit message that discusses the marker directory (the command text then
# never spells the path, so the early-exit fires first), and `grep -r`, which
# stays allowlisted, for searching it.
program_allowed() {
  case "$2" in
    ls|cat|head|tail|wc|stat|file|test|'['|grep|diff|cmp) return 0 ;;
    sha256sum|md5sum|basename|dirname|readlink|realpath) return 0 ;;
    echo|printf) return 0 ;;
    # `gh` needs a subcommand allowlist of its own: `run`/`release download`
    # write into a directory of their choosing, with no redirection involved.
    gh) case "$3" in issue|pr|api|search) return 0 ;; esac ;;
  esac
  return 1
}

# Length-preserving skeleton of $1: the CONTENTS of every single- and
# double-quoted span and of every `#` comment become `X`, the quote and `#`
# characters themselves stay. Operator detection runs on this, because a `>` or
# `;` inside a string literal - or inside a comment - is not an operator.
# Length is preserved so that offsets into the skeleton index the real command.
#
# Only constructs modelled here may be skeletonized; every OTHER construct that
# changes bash's own lexing has to fail closed, or its unmodelled text pairs up
# with real quotes and masks the separators between commands (issue #182: both a
# comment's apostrophe and a heredoc body's quote could swallow a newline and
# hide the second line of a two-line command entirely). So this returns non-zero,
# printing nothing, for a heredoc operator, ANY backslash escape (an escaped
# space defeats the word-start test below just as an escaped quote defeats the
# pairing), and an unbalanced quote.
#
# A `#` opens a comment only at the start of a word and only outside quotes,
# which is why the two are resolved in one left-to-right pass rather than in
# separate ones. `a#b`, `FOO=#b` and `"a"#b` are all ordinary words to bash, and
# masking those would hide a real `>` after them. A word starts at the start of
# the command, or after one of bash's METACHARACTERS - space 0x20, tab 0x09,
# newline 0x0A, and `;` `&` `|` `(` `)` `<` `>`. That set is deliberately NOT the
# POSIX space class (C-locale `isspace`), which also adds VT 0x0B, FF 0x0C and
# CR 0x0D - three bytes bash treats as ordinary word characters. Accepting those
# as word starts masked the remainder of the line, the `;` included, so a second
# command hid behind the first (issue #182, attempt 2). The same enumeration
# anchors both redirection exemptions below, for the same reason.
#
# Two over-blocks here are RATIFIED residuals, not oversights (issue #183,
# docs/plans/2026-07-31-debug-182-step6-word-boundary.md, step 6R-4): ANY
# backslash fails closed, so `cat <dir>/a\ b` is blocked - quote the path
# instead; and a trailing segment that is entirely a comment fails closed,
# because the masked `#` is then the word segment_allowed reads - put the comment
# above the command, or omit it.
command_skeleton() {
  local cmd="$1" out="" pre q body pad
  case "$cmd" in *\\*|*'<<'*) return 1 ;; esac
  while :; do
    pre="${cmd%%[\"\'#]*}"
    if [ "$pre" = "$cmd" ]; then
      printf '%s' "$out$cmd"
      return 0
    fi
    q="${cmd:${#pre}:1}"
    cmd="${cmd:${#pre}+1}"
    out="$out$pre"
    if [ "$q" = '#' ]; then
      case "${out: -1}" in
        ''|[$' \t\n']|[\;\&\|\(\)\<\>]) ;;
        *) out="$out#"; continue ;;
      esac
      body="${cmd%%$'\n'*}"          # to end of line; the newline itself stays
      cmd="${cmd:${#body}}"
      printf -v pad '%*s' "${#body}" ''
      out="$out#${pad// /X}"
    else
      body="${cmd%%"$q"*}"
      [ "$body" != "$cmd" ] || return 1
      cmd="${cmd:${#body}+1}"
      printf -v pad '%*s' "${#body}" ''
      out="$out$q${pad// /X}$q"
    fi
  done
}

# Blank out, length-preservingly, every occurrence of the two closed redirection
# forms that carry no write intent: file-descriptor duplication (`N>&M`, `>&N`)
# and a redirection whose target is literally /dev/null - each of which must end
# at a metacharacter (the same enumeration as above, NOT the POSIX space class)
# or at the end of the command. Every other `>` is left in place for the
# caller's write test, so `>>`, `>&file`, `>/dev/null.txt` and the spaced
# `> /dev/null` all still disqualify. Masking rather than merely exempting is
# what also keeps the `&` of `2>&1` from splitting a segment.
mask_inert_redirections() {
  local rest="$1" out="" pre tail pad meta=$' \t\n;&|()<>'
  # Separate statement, not another `local` operand: every operand of a `local`
  # is expanded before the builtin runs, so `$meta` would still be empty there.
  local fd="^(&[0-9]+)([$meta]|$)" devnull="^(/dev/null)([$meta]|$)"
  while :; do
    pre="${rest%%>*}"
    if [ "$pre" = "$rest" ]; then
      printf '%s' "$out$rest"
      return 0
    fi
    tail="${rest:${#pre}+1}"
    if [[ $tail =~ $fd ]] || [[ $tail =~ $devnull ]]; then
      printf -v pad '%*s' "$(( 1 + ${#BASH_REMATCH[1]} ))" ''
      out="$out$pre${pad// /X}"
      rest="${tail:${#BASH_REMATCH[1]}}"
    else
      out="$out$pre>"
      rest="$tail"
    fi
  done
}

# $1 is one REAL (un-skeletonized) segment: the allowlist reads real text, since
# only operator detection is quote-aware.
segment_allowed() {
  local first sub
  read -r first sub _ <<< "$1"
  [ -n "$first" ] || return 0
  program_allowed "$1" "$first" "$sub"
}

# A command is provably benign only if it can neither redirect nor run text as
# code, AND every segment of it invokes an allowlisted program. The `>` scan and
# the segment split read the quote-aware skeleton; the substitution scan does
# NOT, because double quotes do not inhibit `$(` or backticks, so skeletonizing
# there would hide a live substitution.
command_is_provably_benign() {
  local cmd="$1" skel rest head start=0 seps=$';&|\n'
  case "$cmd" in
    *'`'*|*'$('*|*'<('*) return 1 ;;
  esac
  skel="$(command_skeleton "$cmd")" || return 1
  skel="$(mask_inert_redirections "$skel")"
  case "$skel" in *'>'*) return 1 ;; esac
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

# Resolve `.`, `..` and repeated slashes lexically, so that `.claude//reviewed`,
# `.claude/./reviewed` and `.claude/agents/../reviewed` cannot spell the marker
# directory past the substring test on the Write/Edit path. Purely textual:
# symlinks are NOT resolved, which stays the same accepted residual as the Bash
# path's obfuscation bypass.
normalize_path() {
  local p="$1" seg root="" up="" out=""
  case "$p" in /*) root="/" ;; esac
  while [ -n "$p" ]; do
    seg="${p%%/*}"
    case "$p" in */*) p="${p#*/}" ;; *) p="" ;; esac
    case "$seg" in
      ''|.) ;;
      ..)
        if [ -n "$out" ]; then
          case "$out" in */*) out="${out%/*}" ;; *) out="" ;; esac
        elif [ -z "$root" ]; then
          # Nothing left to pop and no root to stop at: keep the `..` so a
          # later segment still resolves against the right position.
          up="${up:+$up/}.."
        fi
        ;;
      *) out="${out:+$out/}$seg" ;;
    esac
  done
  [ -z "$up" ] || out="$up${out:+/$out}"
  printf '%s' "$root$out"
}

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
[ -f "$config" ] || exit 0

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
subject="$command"
write_tool=""

if [ -z "$command" ]; then
  # Second input shape: Write/Edit carries `.tool_input.file_path` where Bash
  # carries `.tool_input.command`. Keyed on has(), not on emptiness: a payload
  # with no file_path key at all (NotebookEdit's `notebook_path`, say) targets
  # no file this gate owns, while a PRESENT but unusable one is a write whose
  # target cannot be read and fails closed below. A payload jq cannot read at
  # all exits 0 - the same precondition every other hook here takes.
  has_path="$(echo "$input" | jq -r '(.tool_input|type) == "object" and (.tool_input|has("file_path"))' 2>/dev/null)" || exit 0
  [ "$has_path" = true ] || exit 0
  write_tool=1
  file_path="$(echo "$input" | jq -r '.tool_input.file_path // "" | tostring' 2>/dev/null || true)"
  if [ -z "$file_path" ]; then
    # A write whose target cannot be read is not provably outside the marker
    # directory, so it is blocked rather than guessed at - including for the
    # reviewer, whose GRANT has no path to apply to here.
    echo "BLOCKED: this Write/Edit carries an empty file_path, so the marker-directory gate cannot establish where it writes. Blocked by design (this gate fails closed) - reissue the call with an explicit path." >&2
    exit 2
  fi
  # Project-root-relative, the same normalization protected-paths.sh:22-25
  # does. The match below is a substring test and holds for either form; the
  # strip keeps the block message readable.
  subject="$(normalize_path "$file_path")"
  case "$subject" in
    "$project_dir"/*) subject="${subject#"$project_dir"/}" ;;
  esac
fi

case "$subject" in
  *".claude/reviewed"*) ;;
  *) exit 0 ;;
esac

agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

# Only past the substring early-exit above: this hook fires on EVERY Bash call
# and every Write/Edit in the session, and the hot path must pay nothing for
# the audit log.
review_audit="${project_dir}/.claude/review-audit.log"
identity_drift_log "$agent_type" reviewed-path-gate "$review_audit"

if persona_matches_grant "$agent_type" reviewer; then
  exit 0
fi

# Bash-command path only: a Write or Edit into the marker directory is a write
# by definition, so there is no benign carve-out on that shape.
if [ -z "$write_tool" ] && command_is_provably_benign "$command"; then
  exit 0
fi

if [ -z "$agent_type" ]; then
  has_reviewer=""
  personas="$(jq -r '.personaSelection[]? // empty' "$config" 2>/dev/null || true)"
  while IFS= read -r persona; do
    if persona_matches_gate "$persona" reviewer; then
      has_reviewer=1
      break
    fi
  done <<< "$personas"
  if [ -z "$has_reviewer" ]; then
    exit 0
  fi
  echo "BLOCKED: this project has a reviewer persona selected, so the main session/team lead may not write to .claude/reviewed/ itself - route the unit to the reviewer instead, per persona-protocol.md's Review Ownership section." >&2
  exit 2
fi

if [ -n "$write_tool" ]; then
  echo "BLOCKED: '${agent_type}' may not write '${subject}' - only the reviewer creates .pass/.fail/.blocked records in .claude/reviewed/ (or the main session/team lead, ONLY in the documented no-reviewer fallback where no reviewer persona is selected). Per persona-protocol.md's Review Ownership section. Every Write/Edit into that directory is a write by definition, so the read-only exemption that applies to Bash commands does not apply here." >&2
  exit 2
fi

echo "BLOCKED: '${agent_type}' may not write to .claude/reviewed/ via Bash - only the reviewer writes the PASS marker there (or the main session/team lead, ONLY in the documented no-reviewer fallback where no reviewer persona is selected). Per persona-protocol.md's Review Ownership section. Read-only inspection (ls, cat, grep, test ...) and text-only mentions of the path in a gh issue/pr comment ARE allowed; this command was recognized as neither, because it redirects, substitutes, runs a program that could write, or could not be lexed at all (an unbalanced quote, a backslash escape and a heredoc are never assumed benign). Note that 'git' and 'rg' are NOT allowlisted at all, whatever the subcommand - see program_allowed() for why. To land a commit whose MESSAGE discusses this path, put the message in a file and use 'git commit -F <file>', whose command text then never spells the path; to search the directory, use 'grep -r'." >&2
exit 2
