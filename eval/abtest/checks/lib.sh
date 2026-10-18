#!/usr/bin/env bash
# Sourced by eval/abtest/checks/<eval-id>/check.sh. Conventions:
#   check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE
#   . "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
#   abt_init "$1" "$2" "$3" "$4"
#   abt_check ID KIND REQUIRED 'COMMAND' [PATH_TO_RESTORE_FROM_BASE ...]
#   abt_check_scope ID REQUIRED
#   abt_emit            # prints the checks array as one JSON line
# KIND is defect|scope|security|docs|process|premise; REQUIRED is true|false.
# Every COMMAND runs in a throwaway copy of the final tree, with package.json
# (and any listed path) restored from BASE_SHA, so a check cannot change the
# agent's tree and an agent cannot pass by editing the test runner. The
# command sees ABT_WT (the copy), ABT_BASE, ABT_START and ABT_CHECKS_DIR (the
# directory holding the holdout files). Exit 0 means the check passed.
# The runner also exports ABT_SNAPSHOT, the number of commits its dirty-tree snapshot added ahead of
# the arm's own work (0 when unset); the E5 commit-count check subtracts it from its commit count.

# Fail closed (abt-u05h): a worktree that is empty, missing, not a directory, not the root of its own git repository,
# a filesystem root, a home directory or a parent of one is refused with exit 3 before anything is copied or written
# (an empty ABT_WT once made "$ABT_WT/." read /. and copied a whole disk). The copy target is a fresh mktemp directory.
_abt_refuse() { echo "abt-checks: refusing to run: $1" >&2; exit 3; }

# _abt_guard_wt CANDIDATE: on success ABT_WT holds CANDIDATE's physical absolute path; otherwise exit 3.
_abt_guard_wt() {
  local w="${1-}" r p rp top
  [ -n "$w" ] || _abt_refuse "the worktree argument is empty or unset"
  case "$w" in *$'\n'*) _abt_refuse "the worktree path contains a newline" ;; esac
  [ -d "$w" ] || _abt_refuse "the worktree is not an existing directory"
  r="$(cd -P -- "$w" 2> /dev/null && pwd -P)" || _abt_refuse "the worktree path cannot be resolved"
  case "$r" in /?*) ;; *) _abt_refuse "the worktree is the filesystem root" ;; esac
  case "$r" in *$'\n'*) _abt_refuse "the resolved worktree path contains a newline" ;; esac
  [ -d "$r" ] || _abt_refuse "the resolved worktree path is not a directory"
  for p in "${HOME-}" "${TMPDIR:-/tmp}"; do
    [ -n "$p" ] || continue
    rp="$(cd -P -- "$p" 2> /dev/null && pwd -P)" || continue
    case "$rp/" in "$r"/*) _abt_refuse "the worktree is, or contains, $p" ;; esac
  done
  [ -e "$r/.git" ] || _abt_refuse "the worktree has no .git"
  top="$(git -C "$r" rev-parse --show-toplevel 2> /dev/null)" || _abt_refuse "the worktree is not a git worktree"
  [ "$top" = "$r" ] || _abt_refuse "the worktree is not the root of its git repository"
  ABT_WT="$r"
}

# _abt_drop_refuse DIR MESSAGE: remove the (empty) directory this run just made, then refuse.
_abt_drop_refuse() { rmdir -- "${1-}" 2> /dev/null; _abt_refuse "$2"; }

# _abt_guard_copy DIR: DIR must be a fresh, empty, absolute directory that is neither inside the worktree nor above it.
_abt_guard_copy() {
  local c="${1-}" rc
  case "$c" in /?*) ;; *) _abt_drop_refuse "$c" "the copy directory is not an absolute path below /" ;; esac
  case "$c" in *$'\n'*) _abt_drop_refuse "$c" "the copy directory path contains a newline" ;; esac
  [ -d "$c" ] || _abt_refuse "the copy directory was not created"
  rc="$(cd -P -- "$c" 2> /dev/null && pwd -P)" || _abt_refuse "the copy directory cannot be resolved"
  case "$rc/" in "$ABT_WT"/*) _abt_drop_refuse "$c" "the copy directory is inside the worktree" ;; esac
  case "$ABT_WT/" in "$rc"/*) _abt_drop_refuse "$c" "the copy directory is above the worktree" ;; esac
  [ -z "$(ls -A -- "$rc")" ] || _abt_refuse "the copy directory is not empty"
}

abt_init() {
  _abt_guard_wt "${1-}"
  ABT_BASE="$2"
  ABT_START="$3"
  ABT_ALLOWED="${4:-}"
  ABT_CHECKS_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  ABT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ABT_OUT="$(mktemp)"
  export ABT_WT ABT_BASE ABT_START ABT_CHECKS_DIR
}

abt_record() {
  python3 -I - "$ABT_OUT" "$1" "$2" "$3" "$4" "$5" "${6:-}" <<'PYEOF'
import json, sys

out, cid, kind, req, cmd, rc, value = sys.argv[1:8]
rec = {"id": cid, "kind": kind, "required": req == "true", "cmd": cmd,
       "exit": int(rc), "pass": int(rc) == 0}
if value != "":
    rec["value"] = int(value)
with open(out, "a") as f:
    f.write(json.dumps(rec) + "\n")
PYEOF
}

abt_validate() {
  case "$1" in
    defect | scope | security | docs | process | premise) ;;
    *) echo "abt_check: bad kind $1" >&2; exit 2 ;;
  esac
  case "$2" in
    true | false) ;;
    *) echo "abt_check: required must be true or false" >&2; exit 2 ;;
  esac
}

abt_check() {
  local id="$1" kind="$2" req="$3" cmd="$4"
  shift 4
  abt_validate "$kind" "$req"
  local copy rc=0 p
  _abt_guard_wt "${ABT_WT-}"
  copy="$(mktemp -d "${TMPDIR:-/tmp}/abt-check.XXXXXX")" || _abt_refuse "cannot create the copy directory"
  _abt_guard_copy "$copy"
  cp -a -- "${ABT_WT:?}/." "${copy:?}/" || { rm -rf -- "${copy:?}"; _abt_refuse "copying the worktree failed"; }
  for p in package.json "$@"; do
    git -C "$copy" checkout -q "$ABT_BASE" -- "$p" 2>/dev/null || true
  done
  ( cd "$copy" && ABT_WT="$copy" timeout -k 5s "${ABT_CHECK_TIMEOUT_S:-120}s" bash -c "$cmd" ) > /dev/null 2>&1 || rc=$?
  rm -rf -- "${copy:?}"
  abt_record "$id" "$kind" "$req" "$cmd" "$rc"
}

abt_check_scope() {
  local id="$1" req="$2" v rc=0
  abt_validate scope "$req"
  _abt_guard_wt "${ABT_WT-}"
  v="$(bash "$ABT_LIB_DIR/scope.sh" "$ABT_WT" "$ABT_START" "$ABT_ALLOWED" lines)"
  [ "$v" = 0 ] || rc=1
  abt_record "$id" scope "$req" "scope.sh lines outside the allowed paths" "$rc" "$v"
}

abt_emit() {
  python3 -I - "$ABT_OUT" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    recs = [json.loads(l) for l in f if l.strip()]
print(json.dumps(recs))
PYEOF
  rm -f "$ABT_OUT"
}
