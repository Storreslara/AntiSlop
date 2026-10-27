#!/usr/bin/env bash
# Portable tools for macOS/BSD and Linux/GNU compatibility. Sourced, never executed.
# Port-invariant - hand-edit only here; adapters/*/hooks/scripts/lib/portable-tools.sh
# are generated copies (node bin/cli.js --update --force-render).
#
# These helpers abstract over common differences between GNU coreutils (Linux/WSL)
# and BSD userland (macOS), ensuring scripts work on both platforms without
# branching on OS detection.
set -euo pipefail

# _portable_stat_mtime <file> - Get file modification time in seconds since epoch.
# GNU stat uses: stat -c '%Y' <file>
# BSD stat uses: stat -f '%m' <file>  (tried second; see below)
# Returns 0 on error (file not found, unreadable, etc.)
_portable_stat_mtime() {
  local f="$1"
  # GNU first: on GNU `stat -f` is filesystem-status and may succeed with junk output.
  # BSD stat rejects -c, so it falls through to -f '%m'.
  stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f" 2>/dev/null || echo 0
}

# _portable_sha256 <file> - Output "HASH  FILENAME" format (two spaces between hash and name).
# Portable across sha256sum (Linux) and shasum -a 256 (macOS).
# If reading from stdin, <file> should be "-" and output is "HASH  -" to match expected format.
_portable_sha256() {
  local f="$1"
  sha256sum "$f" 2>/dev/null || shasum -a 256 "$f" 2>/dev/null || {
    echo "portable-tools.sh: neither sha256sum nor shasum -a 256 found" >&2
    return 1
  }
}

# _portable_timeout <seconds> <command> [args...] - Run a command with a timeout.
# GNU timeout exits with 124 on timeout. macOS does not ship timeout by default
# (Homebrew coreutils installs as gtimeout unless aliased). When neither exists
# a pure-bash watchdog takes over: the command runs in the background, a
# sleeper sends it SIGTERM after <seconds>, and the result is 124 only when
# that SIGTERM actually landed on a still-running command. Without this
# fallback every microworld bundle on a stock macOS came back 125 and was
# logged result=fail regardless of what run.sh did.
# Returns the command's exit code, or 124 if timed out.
_portable_timeout() {
  local secs="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
    return $?
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
    return $?
  fi

  local cmd_pid watchdog_pid rc=0
  "$@" <&0 &
  cmd_pid=$!
  # The watchdog's exit status is kill's: 0 only if the command was still
  # alive when the timer fired, which is the one case that is a timeout. Its
  # TERM trap reaps the sleeper so a finished command leaves no stray sleep.
  ( trap 'kill "$sleep_pid" 2>/dev/null; exit 143' TERM
    sleep "$secs" & sleep_pid=$!
    wait "$sleep_pid" && kill -TERM "$cmd_pid" 2>/dev/null ) &
  watchdog_pid=$!
  wait "$cmd_pid" 2>/dev/null || rc=$?
  kill "$watchdog_pid" 2>/dev/null || true
  if wait "$watchdog_pid" 2>/dev/null; then
    rc=124
  fi
  return "$rc"
}

# _mapfile_compat [-t] <arrayname> <<< "input"
# Bash 3.2-compatible replacement for mapfile -t (read lines from input into array).
# Usage: _mapfile_compat -t lines <<< "$input"
#        _mapfile_compat -t lines < "$file"
# The -t flag strips trailing newlines from each line (same as mapfile -t).
# Without -t, each line keeps its newline.
# Note: This function is a bash function meant to be called like mapfile, but
# we implement it using a while read loop which is fully portable.
_mapfile_compat() {
  local strip_trailing=0
  local array_name

  if [ "$1" = "-t" ]; then
    strip_trailing=1
    array_name="$2"
  else
    array_name="$1"
  fi

  # Clear the array
  eval "$array_name=()"

  # Read lines into array
  while IFS= read -r line; do
    if [ "$strip_trailing" = 1 ]; then
      eval "$array_name+=(\"\$line\")"
    else
      # Preserve newlines by appending manually (not typically used)
      eval "$array_name+=(\"\$line\")"
    fi
  done
}
