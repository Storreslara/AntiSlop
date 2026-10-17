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

# abt_leak_guard DEST: fail closed when the built baseline names the eval or the tool in the files an agent
# reads first: package.json, README.md, CONTEXT.md, CLAUDE.md and everything under docs/. The literal file
# name CLAUDE.md is allowed; the whole words antislop, eval, pilot, persona, claude and holdout, and the
# phrase hidden check, are not (case-insensitive; evaluate or copilot are fine). Source and test files are
# not scanned. Prints the file and the word on stderr and returns 1.
abt_leak_guard() {
  local dest="$1" f content hit
  local -a files=()
  [ -d "$dest" ] || { echo "build: $dest is not a directory; the leak guard cannot scan it" >&2; return 1; }
  for f in package.json README.md CONTEXT.md CLAUDE.md; do
    [ -f "$dest/$f" ] && files+=("$dest/$f")
  done
  if [ -d "$dest/docs" ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$dest/docs" -type f | sort)
  fi
  for f in ${files[@]+"${files[@]}"}; do
    content="$(sed 's/CLAUDE\.md//g' "$f")" || { echo "build: cannot read $f for the leak guard" >&2; return 1; }
    hit="$(printf '%s\n' "$content" | grep -oiE '\b(antislop|eval|pilot|persona|claude|holdout)\b|hidden check' | head -n1)"
    if [ -n "$hit" ]; then
      echo "build: $f names the eval or the tool ('$hit')" >&2
      return 1
    fi
  done
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
