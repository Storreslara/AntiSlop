#!/usr/bin/env bash
# Arm A: bare Fable. claude -p in the fixture worktree with no plugin, no
# personas and no hooks. The worktree must hold no .claude directory.
# Usage: arm-a.sh WORKTREE PROMPT_FILE STREAM_FILE STDERR_FILE (absolute paths)
# Env:   ABTEST_CONFIG_DIR (required; a clean dir from abtest_make_config_dir)
# Prints one line, "scaffold-sha: <sha>", the commit the agent starts from.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$HERE/common.sh"

wt="${1:?usage: arm-a.sh WORKTREE PROMPT_FILE STREAM_FILE STDERR_FILE}"
pf="${2:?missing PROMPT_FILE}"
out="${3:?missing STREAM_FILE}"
err="${4:?missing STDERR_FILE}"
: "${ABTEST_CONFIG_DIR:?ABTEST_CONFIG_DIR must name a clean config dir}"

abtest_arm_setup "$wt" || exit 2
if [ "${ABTEST_HOME_OWNED:-0}" = 1 ]; then trap 'rm -rf "${ABTEST_HOME:?}"' EXIT; fi
if [ -e "$wt/.claude" ]; then
  echo "arm-a.sh: $wt has a .claude directory; Arm A must run without one" >&2
  exit 3
fi

abtest_trust_path "$ABTEST_CONFIG_DIR" "$wt"
export CLAUDE_CONFIG_DIR="$ABTEST_CONFIG_DIR"
unset CLAUDE_CODE_SUBAGENT_MODEL
printf 'scaffold-sha: %s\n' "$(git -C "$wt" rev-parse HEAD)"
abtest_run_claude "$wt" "$pf" "$out" "$err"
