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

# One flag or value per line, so a test can compare the two arms.
abtest_common_flags() {
  printf '%s\n' \
    --output-format stream-json --verbose --include-hook-events \
    --permission-mode acceptEdits \
    --allowedTools 'Bash(npm test)' 'Bash(npm run *)' 'Bash(git *)' \
    --max-turns "$MAX_TURNS" --model "$ABTEST_MODEL" \
    --no-session-persistence
}

# abtest_make_config_dir DIR: a clean CLAUDE_CONFIG_DIR holding the
# operator's credentials and nothing else (no plugins, no user CLAUDE.md).
abtest_make_config_dir() {
  local dir="$1"
  rm -rf "$dir"
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
  local -a flags
  mapfile -t flags < <(abtest_common_flags)
  local rc=0
  ( cd "$wt" && timeout "${TIMEOUT_MIN}m" "$ABTEST_CLAUDE" -p "$(cat "$pf")" "${flags[@]}" "$@" ) > "$out" 2> "$err" || rc=$?
  return "$rc"
}
