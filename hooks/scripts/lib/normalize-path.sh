#!/usr/bin/env bash
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
