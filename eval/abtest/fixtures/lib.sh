#!/usr/bin/env bash
# Sourced by eval/abtest/fixtures/<eval-id>/build.sh. Makes a fixture build
# deterministic: fixed identity and dates, so two builds of one fixture
# commit the same baseline sha.

abt_fixture_env() {
  export GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@example.invalid
  export GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid
  export GIT_AUTHOR_DATE=2026-01-01T00:00:00Z GIT_COMMITTER_DATE=2026-01-01T00:00:00Z
}

# The words a git history must not carry, matched case-insensitively as whole words (plurals included).
# evaluate, copilot, personality and the like are fine.
ABT_LEAK_GIT_WORDS='\b(anti[- ]?slop|abtest|evals?|pilots?|personas?|claude|holdouts?|fixtures?|traps?|plants?)\b|hidden checks?'

# _abt_leak_hit REGEX TEXT: print the first match and return 0; return 1 for no match, 2 when grep itself failed.
_abt_leak_hit() {
  local out rc
  out="$(grep -oiE "$1" <<< "$2")"; rc=$?
  if [ "$rc" -eq 0 ]; then printf '%s\n' "${out%%$'\n'*}"; return 0; fi
  [ "$rc" -eq 1 ] && return 1
  return 2
}

# _abt_leak_hist DEST: scan the git history of DEST (commit authors, committers and messages on every branch,
# ref names, tag messages and taggers) for ABT_LEAK_GIT_WORDS. Prints the word on stderr and returns 1; a
# failing git or grep also returns 1.
_abt_leak_hist() {
  local dest="$1" meta hit rc
  meta="$(git -C "$dest" log --all --format='%an%n%ae%n%cn%n%ce%n%B')" \
    || { echo "build: git log failed in $dest; the leak guard cannot scan it" >&2; return 1; }
  meta="$meta"$'\n'"$(git -C "$dest" for-each-ref --format='%(refname)%0a%(taggername)%0a%(contents)')" \
    || { echo "build: git for-each-ref failed in $dest; the leak guard cannot scan it" >&2; return 1; }
  hit="$(_abt_leak_hit "$ABT_LEAK_GIT_WORDS" "$meta")"; rc=$?
  case "$rc" in
    0) echo "build: the git history of $dest names the eval or the tool ('$hit')" >&2; return 1 ;;
    1) return 0 ;;
    *) echo "build: grep failed on the git history of $dest" >&2; return 1 ;;
  esac
}

# The words that must not reach a candidate in the files it reads first: matched case-insensitively as whole
# words, plurals included. evaluate, copilot, personality and the like are fine.
ABT_LEAK_WORDS='\b(anti[- ]?slop|abtest|evals?|pilots?|personas?|claude|holdouts?)\b|hidden checks?'

# _abt_leak_scan DEST LISTFILE: list every file and symlink under DEST except .git, then scan package.json,
# everything under docs/ (any case), every path with a dot-directory or dot-file component, and any file named
# README, CONTEXT, CLAUDE or AGENTS (any case, at any depth, with or without an extension md, markdown, mdx,
# txt or rst). Source and test files are not scanned. A symlink in scope is refused (links are never followed).
# Every failing find, sed or grep fails the scan.
_abt_leak_scan() {
  local dest="$1" list="$2" f rel low content hit rc
  find "$dest" -path "$dest/.git" -prune -o \( -type f -o -type l \) -print0 > "$list" \
    || { echo "build: find failed under $dest; the leak guard cannot scan it" >&2; return 1; }
  while IFS= read -r -d '' f; do
    rel="${f#"$dest"/}"; low="${rel,,}"
    case "/$low" in
      /package.json | /docs | /docs/* | */.*) ;;
      *) [[ "${low##*/}" =~ ^(readme|context|claude|agents)(\.(md|markdown|mdx|txt|rst))?$ ]] || continue ;;
    esac
    if [ -L "$f" ]; then
      echo "build: $f is a symbolic link; the leak guard does not follow links" >&2
      return 1
    fi
    content="$(sed 's/CLAUDE\.md//g' "$f")" || { echo "build: cannot read $f for the leak guard" >&2; return 1; }
    hit="$(_abt_leak_hit "$ABT_LEAK_WORDS" "$content")"; rc=$?
    case "$rc" in
      0) echo "build: $f names the eval or the tool ('$hit')" >&2; return 1 ;;
      1) ;;
      *) echo "build: grep failed on $f; the leak guard cannot scan it" >&2; return 1 ;;
    esac
  done < "$list"
  return 0
}

# abt_leak_guard DEST: fail closed when the built baseline names the eval or the tool where a candidate agent
# would read it: the files _abt_leak_scan scans and, when DEST holds a git repository, its history
# (_abt_leak_hist). Prints the file and the word on stderr and returns 1.
abt_leak_guard() {
  local dest="${1%/}" list rc
  [ -d "$dest" ] || { echo "build: $dest is not a directory; the leak guard cannot scan it" >&2; return 1; }
  list="$(mktemp)" || { echo "build: cannot create a temp file for the leak guard" >&2; return 1; }
  _abt_leak_scan "$dest" "$list"; rc=$?
  rm -f "$list"
  [ "$rc" -eq 0 ] || return "$rc"
  if [ -e "$dest/.git" ]; then _abt_leak_hist "$dest" || return 1; fi
  return 0
}

# abt_fixture_baseline DEST: turn DEST into a git repo with one neutral commit ("initial import" by dev) and
# print the commit sha (the last stdout line of build.sh). The guard runs before the commit and again on the
# finished repository; a leaking history is removed, so no refused build leaves a repository behind.
abt_fixture_baseline() {
  abt_leak_guard "$1" || return 1
  abt_fixture_env
  ( cd "$1" && git init -q -b main && git add -A && git commit -q -m "initial import" ) || return 1
  abt_leak_guard "$1" || { rm -rf "${1%/}/.git"; return 1; }
  git -C "$1" rev-parse HEAD
}
