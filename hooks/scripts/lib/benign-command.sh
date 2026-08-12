#!/usr/bin/env bash
# Shared benign-command lexer, extracted from reviewed-path-gate.sh so
# human-decision-gate.sh can reuse the same implementation. Sourced, never
# executed. See reviewed-path-gate.sh's header comment for the design
# rationale behind these functions (git/rg exclusion, quote-aware
# skeletonization, the two exempt redirection forms, path normalization).

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
# stays allowlisted, for searching it. Both are scoped to reviewed-path-gate.sh,
# which grants the reviewer an identity, and never for human-decision-gate.sh,
# which grants nobody: rephrasing a command so its text stops spelling that
# gate's file is a self-authorized bypass, not a workaround.
program_allowed() {
  case "$2" in
    ls|cat|head|tail|wc|stat|file|test|'['|grep|diff|cmp) return 0 ;;
    sha256sum|md5sum|basename|dirname|readlink|realpath) return 0 ;;
    echo|printf) return 0 ;;
    # `gh` needs a subcommand allowlist of its own: `run`/`release download`
    # write into a directory of their choosing, with no redirection involved.
    # `api` is excluded on the same denylist-fails-open ground as `git`/`rg`
    # above: it is a general-purpose authenticated HTTP client whose method is
    # IMPLICIT (POST as soon as any -f/-F/--field/--raw-field is present, no -X
    # required) and which also reaches GraphQL mutations naming no REST route
    # at all - no scan of the command's text can bound what it writes, so the
    # surface is removed rather than inspected, same as `git`/`rg`.
    gh) case "$3" in issue|pr|search) return 0 ;; esac ;;
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
