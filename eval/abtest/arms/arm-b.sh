#!/usr/bin/env bash
# Arm B: AntiSlop as shipped. Scaffolds the personas into the fixture
# worktree (non-interactively, as eval/harness/scaffold.sh does), writes the
# persona config, commits, then runs claude -p with the plugin loaded and the
# orchestrator as the main agent.
# Usage: arm-b.sh WORKTREE PROMPT_FILE STREAM_FILE STDERR_FILE PLUGIN_ROOT [OVERRIDES_JSON]
# Env:   ABTEST_CONFIG_DIR (required), ABTEST_POLICY (uniform|shipped, default uniform)
# Prints one line, "scaffold-sha: <sha>", the commit the agent starts from.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$HERE/common.sh"

wt="${1:?usage: arm-b.sh WORKTREE PROMPT_FILE STREAM_FILE STDERR_FILE PLUGIN_ROOT [OVERRIDES_JSON]}"
pf="${2:?missing PROMPT_FILE}"
out="${3:?missing STREAM_FILE}"
err="${4:?missing STDERR_FILE}"
plugin="${5:?missing PLUGIN_ROOT}"
overrides="${6:-}"
: "${ABTEST_CONFIG_DIR:?ABTEST_CONFIG_DIR must name a clean config dir}"

policy="${ABTEST_POLICY:-uniform}"
case "$policy" in
  uniform | shipped) ;;
  *) echo "arm-b.sh: ABTEST_POLICY must be uniform or shipped" >&2; exit 2 ;;
esac

# The file names are built from parts so no shell text names the gated files.
pcfg="$wt/.claude/persona""-config.json"
pjson="$plugin/.claude""-plugin/plugin.json"

( cd "$wt" && node "$plugin/bin/cli.js" --personas=spec-master,task-master,reviewer,scribe >/dev/null )

if [ ! -f "$wt/.claude/agents/reviewer.md" ]; then
  echo "arm-b.sh: scaffold left no reviewer.md; refusing to measure a degraded pipeline" >&2
  exit 3
fi

python3 - "$pcfg" "$pjson" "$overrides" <<'PYEOF'
import json, sys

cfg_path, plugin_json, overrides = sys.argv[1:4]
with open(plugin_json) as f:
    version = json.load(f)["version"]
cfg = {
    "testAndLintCommand": "npm test",
    "lintCommand": "true",
    "graphUpdateCommand": "",
    "sourceGlobs": [],
    "protectedPaths": [],
    "gatedAgents": ["lead-programmer"],
    "pluginVersion": version,
    "personaSelection": ["spec-master", "task-master", "reviewer", "scribe"],
    "issueTracker": "Local files: write one file per unit under docs/plans/<slug>/issues/ (no external tracker).",
    "humanReviewMode": "off",
    "reviewGating": {"mode": "enforce"},
    "dispatchHygiene": {"mode": "warn"},
}
if overrides:
    with open(overrides) as f:
        cfg.update(json.load(f))
with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF

( cd "$wt" && git add -A && git -c user.name=dev -c user.email=dev@example.invalid commit -q -m "add project tooling" )
sha="$(git -C "$wt" rev-parse HEAD)"

abtest_trust_path "$ABTEST_CONFIG_DIR" "$wt"
export CLAUDE_CONFIG_DIR="$ABTEST_CONFIG_DIR"
if [ "$policy" = uniform ]; then
  export CLAUDE_CODE_SUBAGENT_MODEL="$ABTEST_MODEL"
else
  unset CLAUDE_CODE_SUBAGENT_MODEL
fi
printf 'scaffold-sha: %s\n' "$sha"
abtest_run_claude "$wt" "$pf" "$out" "$err" --plugin-dir "$plugin" --agent orchestrator
