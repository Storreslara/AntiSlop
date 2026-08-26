#!/usr/bin/env bash
# Sidecar-sealed audit log writes. Sourced, never executed. Port-invariant -
# hand-edit only here; adapters/*/hooks/scripts/lib/audit-log.sh are generated
# copies (node bin/cli.js --update --force-render).
#
# What the seal does and does not prove.
# It detects: accidental truncation, a crashed or partial write, a `git
# clean` that removed the log, an out-of-band edit by a tool that does not
# know about the seal, and an adversary who truncates the log and does not
# reseal.
# It does NOT detect: an adversary who truncates the log AND reseals -
# resealing is one sha256sum plus a two-line rewrite, and nothing in this
# file stops a determined agent from doing both. The seal prices the attack
# (a one-call truncation becomes a two-step operation that must also model
# the seal format) and catches accidents reliably; it is evidence against
# carelessness, not a defense against intent, and does nothing against a
# resealer.
set -euo pipefail

# _audit_reseal <log> - rewrites <log>.seal to `lines=<N> sha256=<hash of the
# whole file>`. N is the file's line count at reseal time, so "first N lines"
# at verify time means "everything sealed so far".
_audit_reseal() {
  local log="$1" n hash
  # Each redirection is wrapped in its own brace group so a failed open (an
  # unreadable/unwritable path) is suppressed by the trailing 2>/dev/null - a
  # bare `cmd < file 2>/dev/null` does NOT suppress a failed `<` open, because
  # bash reports that error before the later 2>/dev/null redirection applies.
  n="$({ wc -l < "$log"; } 2>/dev/null)" || n=0
  hash="$(sha256sum "$log" 2>/dev/null | cut -d' ' -f1)"
  { printf 'lines=%s sha256=%s\n' "$n" "$hash" > "${log}.seal"; } 2>/dev/null || true
}

# audit_append <log> <line> - appends <line> to <log>, then reseals. A write
# failure (unwritable path, full disk) degrades to "it wasn't logged", never
# aborts the caller under set -e.
audit_append() {
  local log="$1" line="$2"
  { printf '%s\n' "$line" >> "$log"; } 2>/dev/null || return 0
  _audit_reseal "$log"
}

# audit_seal_verify <log> - ok|truncated|missing-seal|absent|unverifiable.
# ok: the file has >= N lines AND the sha256 of its first N lines equals the
# sealed hash (N, hash from <log>.seal at last reseal). Appends by a writer
# that did not reseal are therefore fine; truncation, deletion and mid-file
# rewriting are not.
audit_seal_verify() {
  local log="$1" seal="${1}.seal" sealed_line sealed_n sealed_hash actual_n actual_hash
  [ -f "$log" ] || { echo absent; return 0; }
  [ -f "$seal" ] || { echo missing-seal; return 0; }
  sealed_line="$(head -n 1 "$seal" 2>/dev/null || true)"
  if [[ "$sealed_line" =~ ^lines=([0-9]+)\ sha256=([0-9a-f]{64})$ ]]; then
    sealed_n="${BASH_REMATCH[1]}"
    sealed_hash="${BASH_REMATCH[2]}"
  else
    echo unverifiable
    return 0
  fi
  actual_n="$(wc -l < "$log" 2>/dev/null || echo 0)"
  if [ "$actual_n" -lt "$sealed_n" ]; then
    echo truncated
    return 0
  fi
  actual_hash="$(head -n "$sealed_n" "$log" | sha256sum | cut -d' ' -f1)"
  if [ "$actual_hash" = "$sealed_hash" ]; then
    echo ok
  else
    echo truncated
  fi
}

# audit_rotate <log> - moves <log> to <dot-dir>/audit-archive/<utc>-<name>.log
# (dot-dir derived from <log>'s own path, never hardcoded to one port: .claude/,
# .cursor/, or .codex/), starts a fresh <log> whose first line
# records the archived file's name, line count and sha256, and seals it.
# Collision-safe within the same second (a counter suffix, same idiom as
# bin/human-review-cleanup.sh's pre-existing rotate_log()).
audit_rotate() {
  local log="$1" dot archive_dir name utc archived n hash counter
  dot="$(dirname "$log")"
  name="$(basename "$log")"
  archive_dir="${dot}/audit-archive"
  mkdir -p "$archive_dir" 2>/dev/null || return 1
  utc="$(date -u +%Y%m%dT%H%M%SZ)"
  archived="${archive_dir}/${utc}-${name}"
  if [ -e "$archived" ]; then
    counter=1
    while [ -e "${archive_dir}/${utc}-${counter}-${name}" ]; do
      counter=$((counter + 1))
    done
    archived="${archive_dir}/${utc}-${counter}-${name}"
  fi
  n=0
  hash=""
  if [ -f "$log" ]; then
    n="$(wc -l < "$log" 2>/dev/null || echo 0)"
    hash="$(sha256sum "$log" 2>/dev/null | cut -d' ' -f1)"
    mv "$log" "$archived" 2>/dev/null || return 1
  fi
  rm -f "${log}.seal" 2>/dev/null || true
  printf 'rotated-from=%s lines=%s sha256=%s\n' "$(basename "$archived")" "$n" "$hash" > "$log"
  _audit_reseal "$log"
}
