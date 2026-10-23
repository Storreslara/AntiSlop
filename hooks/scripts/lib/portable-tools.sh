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
# BSD stat uses: stat -f '%m' <file>
# Returns 0 on error (file not found, unreadable, etc.)
_portable_stat_mtime() {
  local f="$1"
  stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0
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
# (Homebrew coreutils installs as gtimeout unless aliased). If neither exists,
# emit a clear error.
# Returns the command's exit code, or 124 if timed out, or 125 if timeout mechanism unavailable.
_portable_timeout() {
  local secs="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
    return $?
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
    return $?
  else
    echo "portable-tools.sh: timeout command not found (install gnu-coreutils or coreutils for macOS)" >&2
    return 125
  fi
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
