#!/usr/bin/env bash
# Shared claude -p flags, caps and capture for both arms. Sourced, never run.
# Equal for both arms by construction: arm-a.sh and arm-b.sh build their
# command from abtest_common_flags and add nothing to it except Arm B's own
# --plugin-dir and --agent. No dollar cap: the operator is on a Max
# subscription, so the caps are a main-session turn cap and a wall-clock cap.
ABTEST_CLAUDE="${ABTEST_CLAUDE:-claude}"
ABTEST_MODEL="${ABTEST_MODEL:-fable}"
MAX_TURNS="${MAX_TURNS:-100}"
TIMEOUT_MIN="${TIMEOUT_MIN:-45}"
# The harness root is this checkout. The hidden checks, the reference solutions, the results and the fixtures live
# in it, so no arm may be able to read it (OD-16). ABTEST_DENY_PATHS adds more paths, colon-separated.
ABTEST_HARNESS_ROOT="${ABTEST_HARNESS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)}"

# One flag or value per line, so a test can compare the two arms.
# OD-19: both arms allow all of Bash (the single value Bash), so a correct run is not scored stalled-human for an
# ordinary dev command. The isolation lives in abtest_deny_flags, the pruned plugin copy, the per-run HOME and a work
# directory outside the checkout, not in this list. A real ask or denial is still stalled-human (lib/stream.py).
abtest_common_flags() {
  printf '%s\n' \
    --output-format stream-json --verbose --include-hook-events \
    --permission-mode acceptEdits \
    --allowedTools Bash \
    --max-turns "$MAX_TURNS" --model "$ABTEST_MODEL" \
    --no-session-persistence
}

# abtest_outside PATH...: fail when a path is, or is inside, the harness root (the path need not exist yet).
abtest_outside() {
  local p real
  for p in "$@"; do
    real="$(realpath -m -- "$p")" || return 1
    case "$real/" in
      "$ABTEST_HARNESS_ROOT"/*)
        echo "abtest: $p is inside the harness root $ABTEST_HARNESS_ROOT; an arm could read the hidden checks from it" >&2
        return 1
        ;;
    esac
  done
}

# abtest_deny_flags: --disallowedTools and one rule per line that keeps Read, Edit and Bash commands that name the
# harness root, or a path of ABTEST_DENY_PATHS, away from the arm. Read rules also govern Glob and Grep. A deny rule
# cannot stop a shell that never names the path, so the arms also run outside the harness (see abtest_outside).
abtest_deny_flags() {
  local p
  printf '%s\n' --disallowedTools
  # OD-19: Bash is allowed whole, so the rules below are the only command-level protection. Deny rules are checked
  # before allow rules whatever the flag order, and abtest_run_claude still puts them first. The find and sort rules of
  # OD-17 are gone: with every command allowed they guard nothing a plain shell lacks, and each is a denial that would
  # stall a correct run.
  while IFS= read -r p; do
    case "$p" in
      *[[:space:],\(\)]*)
        echo "abtest: a denied path may not hold a space, comma or parenthesis: $p" >&2
        return 1
        ;;
    esac
    printf '%s\n' "Read(/$p)" "Read(/$p/**)" "Edit(/$p/**)" "Bash(*$p*)"
  done < <(
    printf '%s\n' "$ABTEST_HARNESS_ROOT"
    local IFS=:
    for q in ${ABTEST_DENY_PATHS:-}; do [ -z "$q" ] || realpath -m -- "$q"; done
  )
}

# abtest_make_home DIR: a per-run HOME outside the harness with a neutral git identity and nothing else.
abtest_make_home() {
  local dir="$1"
  abtest_outside "$dir" || return 1
  rm -rf "${dir:?}"
  mkdir -p "$dir"
  printf '[user]\n\tname = dev\n\temail = dev@example.invalid\n' > "$dir/.gitconfig"
}

# abtest_plugin_copy ROOT DEST: only what the plugin needs, taken from ROOT's HEAD: the manifest, agents, bin,
# commands, hooks, skills and templates. The scaffold script needs no adapters or package.json (checked: the
# scaffold is byte-identical without them). eval/, tests/, docs/, .claude/ and every fixture, check and result stay out.
abtest_plugin_copy() {
  local root="$1" dest="$2"
  rm -rf "${dest:?}"
  mkdir -p "$dest"
  git -C "$root" archive HEAD .claude-plugin agents bin commands hooks skills templates | tar -x -C "$dest" || return 1
  [ -f "$dest/.claude-plugin/plugin.json" ] && [ -f "$dest/hooks/hooks.json" ] && [ -f "$dest/bin/cli.js" ] || return 1
}

# abtest_arm_setup WORKTREE: refuse a worktree or config dir inside the harness and make a per-run HOME.
abtest_arm_setup() {
  abtest_outside "$1" "${ABTEST_CONFIG_DIR:?}" || return 1
  if [ -z "${ABTEST_HOME:-}" ]; then
    ABTEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/abtest-home.XXXXXX")" || return 1
    ABTEST_HOME_OWNED=1
  fi
  abtest_make_home "$ABTEST_HOME" || return 1
  export ABTEST_HOME
}

# abtest_make_config_dir DIR: a clean CLAUDE_CONFIG_DIR holding the
# operator's credentials and nothing else (no plugins, no user CLAUDE.md).
abtest_make_config_dir() {
  local dir="$1"
  rm -rf "${dir:?}"
  mkdir -p "$dir"
  printf '{}\n' > "$dir/settings.json"
  if [ -f "$HOME/.claude/.credentials.json" ]; then
    cp "$HOME/.claude/.credentials.json" "$dir/.credentials.json"
  fi
  python3 - "$dir/.claude.json" "$HOME/.claude.json" <<'PYEOF'
import json, os, sys

dst, src = sys.argv[1], sys.argv[2]
cfg = {"hasCompletedOnboarding": True, "projects": {}}
if os.path.isfile(src):
    with open(src) as f:
        old = json.load(f)
    if "oauthAccount" in old:
        cfg["oauthAccount"] = old["oauthAccount"]
with open(dst, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
}

# abtest_trust_path DIR PATH: pre-trust PATH in DIR's .claude.json (a
# headless run has no TTY to accept the trust dialog).
abtest_trust_path() {
  python3 - "$1/.claude.json" "$2" <<'PYEOF'
import json, sys

cfg_path, target = sys.argv[1], sys.argv[2]
with open(cfg_path) as f:
    cfg = json.load(f)
cfg.setdefault("projects", {}).setdefault(target, {})["hasTrustDialogAccepted"] = True
with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
}

# abtest_run_claude WORKTREE PROMPT_FILE STREAM_FILE STDERR_FILE [extra flags]
# All paths absolute. Returns claude's exit code, or 124 on the wall-clock cap.
abtest_run_claude() {
  local wt="$1" pf="$2" out="$3" err="$4"
  shift 4
  local -a flags deny
  local denyout home="${ABTEST_HOME:?ABTEST_HOME must name the per-run HOME}"
  mapfile -t flags < <(abtest_common_flags)
  denyout="$(abtest_deny_flags)" || return 2
  mapfile -t deny <<< "$denyout"
  local rc=0
  ( cd "$wt" && env HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" timeout "${TIMEOUT_MIN}m" "$ABTEST_CLAUDE" -p "$(cat "$pf")" "${deny[@]}" "${flags[@]}" "$@" ) > "$out" 2> "$err" || rc=$?
  return "$rc"
}
