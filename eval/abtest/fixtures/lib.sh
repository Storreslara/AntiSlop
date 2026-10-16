#!/usr/bin/env bash
# Sourced by eval/abtest/fixtures/<eval-id>/build.sh. Makes a fixture build
# deterministic: fixed identity and dates, so two builds of one fixture
# commit the same baseline sha.

abt_fixture_env() {
  export GIT_AUTHOR_NAME=abtest GIT_AUTHOR_EMAIL=abtest@example.invalid
  export GIT_COMMITTER_NAME=abtest GIT_COMMITTER_EMAIL=abtest@example.invalid
  export GIT_AUTHOR_DATE=2026-01-01T00:00:00Z GIT_COMMITTER_DATE=2026-01-01T00:00:00Z
}

# abt_fixture_baseline DEST: turn DEST into a git repo with one commit named
# baseline and print the commit sha (the last stdout line of build.sh).
abt_fixture_baseline() {
  abt_fixture_env
  ( cd "$1" && git init -q -b main && git add -A && git commit -q -m baseline && git rev-parse HEAD )
}
