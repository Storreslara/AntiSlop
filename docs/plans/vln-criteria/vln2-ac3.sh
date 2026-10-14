#!/usr/bin/env bash
# vln2-ac3.sh: tests/validate-lanes.test.sh stops with exit 99 and a setup
# message, before any case runs, when a throwaway tree's git setup fails.
# The host failure is real, not mocked: commit signing is switched on through
# the environment with a signing program that always fails (git's own
# GIT_CONFIG_COUNT mechanism, git >= 2.31). The test runs with a private
# TMPDIR, which must be empty afterwards (its EXIT trap still cleans up).
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
tmp="$VLN_ROOT/tmp"; mkdir -p "$tmp"
out=$(env -u CLAUDE_PROJECT_DIR TMPDIR="$tmp" GIT_CONFIG_COUNT=2 \
  GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=true \
  GIT_CONFIG_KEY_1=gpg.program GIT_CONFIG_VALUE_1=false \
  bash tests/validate-lanes.test.sh 2>&1); rc=$?
[ "$rc" = 99 ] || { echo "signing: test exit $rc, want 99"; printf '%s\n' "$out"; exit 1; }
printf '%s\n' "$out" | grep -q '^tree: git setup failed in ' || { echo "signing: no setup message"; printf '%s\n' "$out"; exit 1; }
printf '%s\n' "$out" | grep -qE '^(ok  |FAIL) \(L' && { echo "signing: a case ran against a broken tree"; printf '%s\n' "$out"; exit 1; }
[ -z "$(find "$tmp" -mindepth 1 -print -quit)" ] || { echo "signing: the test left files in TMPDIR"; exit 1; }
exit 0
