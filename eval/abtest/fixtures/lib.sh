#!/usr/bin/env bash
# Sourced by eval/abtest/fixtures/<eval-id>/build.sh. Makes a fixture build
# deterministic: fixed identity and dates, so two builds of one fixture
# commit the same baseline sha.

abt_fixture_env() {
  export GIT_AUTHOR_NAME=abtest GIT_AUTHOR_EMAIL=abtest@example.invalid
  export GIT_COMMITTER_NAME=abtest GIT_COMMITTER_EMAIL=abtest@example.invalid
  export GIT_AUTHOR_DATE=2026-01-01T00:00:00Z GIT_COMMITTER_DATE=2026-01-01T00:00:00Z
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
  return 0
}

# abt_fixture_baseline DEST: turn DEST into a git repo with one commit named
# baseline and print the commit sha (the last stdout line of build.sh).
abt_fixture_baseline() {
  abt_leak_guard "$1" || return 1
  abt_fixture_env
  ( cd "$1" && git init -q -b main && git add -A && git commit -q -m baseline && git rev-parse HEAD )
}
