#!/usr/bin/env bash
# Scaffolds a fresh, disposable copy of eval/fixtures/toy-lib-template into
# DEST, installs the antislop persona system into it non-interactively
# via bin/cli.js, then fills in the repo-specific config that /install-antislop
# would normally do interactively (this fixture's commands are already known,
# so that interactive step is safely skippable here) and wires in the same
# OTel telemetry env block ~/claude_trace uses, with a fresh project.name so
# every pilot run lands in the shared ~/otel/otel_data.duckdb queryable the
# same way telemetry-reviewer queries claude_trace's own data.
#
# Usage: scaffold.sh DEST [--force]
#   DEST    path to create the scratch fixture at (must not exist unless
#           --force is passed, in which case it is removed first)
#
# Prints the resolved project.name to stdout as the last line on success —
# callers should capture it for later DuckDB queries.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/eval/fixtures/toy-lib-template"

DEST="${1:?usage: scaffold.sh DEST [--force]}"
FORCE="${2:-}"

if [ -e "$DEST" ]; then
  if [ "$FORCE" = "--force" ]; then
    rm -rf "$DEST"
  else
    echo "scaffold.sh: $DEST already exists — pass --force to remove it first, or pick a fresh path." >&2
    exit 1
  fi
fi

mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
cp -r "$TEMPLATE_DIR/." "$DEST/"

# Each scratch fixture is a workspace path Claude Code has never seen, so a
# headless `claude -p` run there silently ignores settings.json's
# permissions.allow ("this workspace has not been trusted") — there's no TTY
# to accept the trust dialog. Pre-trust it the same way the error message's
# own suggested fix does. Scoped to this one path; eval/harness/cleanup.sh
# removes the entry again when a scratch dir is torn down for good.
python3 - "$DEST" <<'PYEOF'
import json, os, sys

dest = sys.argv[1]
config_path = os.path.expanduser("~/.claude.json")
with open(config_path) as f:
    config = json.load(f)

projects = config.setdefault("projects", {})
projects.setdefault(dest, {})["hasTrustDialogAccepted"] = True

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PYEOF

PROJECT_NAME="antislop-pilot-$(date +%s%N | sha256sum | head -c8)"

# Non-interactive scaffold: --personas= alone puts cli.js in scriptedMode,
# so it never touches stdin (bin/cli.js:132-133,150-208,308).
( cd "$DEST" && node "$REPO_ROOT/bin/cli.js" --personas=spec-master,task-master,reviewer )

# The rest is the judgment-driven half normally done by /install-antislop
# interactively — safe to do mechanically here since this fixture's real
# commands are already known by construction.
cat > "$DEST/.claude/persona-config.json" <<EOF
{
  "testAndLintCommand": "npm test",
  "lintCommand": "true",
  "graphUpdateCommand": "",
  "sourceGlobs": [],
  "protectedPaths": [],
  "gatedAgents": ["lead-programmer"],
  "pluginVersion": "$(node -e "console.log(require('$REPO_ROOT/.claude-plugin/plugin.json').version)")",
  "personaSelection": ["spec-master", "task-master", "reviewer"],
  "issueTracker": "None - single-task eval fixture, no tracker needed."
}
EOF

python3 - "$DEST/.claude/settings.json" "$PROJECT_NAME" <<'PYEOF'
import json, sys

settings_path, project_name = sys.argv[1], sys.argv[2]
with open(settings_path) as f:
    settings = json.load(f)

# Resolve the two placeholder permission strings settings-fragment.json ships
# (templates/settings-fragment.json:8-10) into this fixture's real commands.
allow = settings.setdefault("permissions", {}).setdefault("allow", [])
replacements = {
    "__REPLACE_WITH_REAL_TEST_BUILD_LINT_GIT_COMMANDS__": ["Bash(npm test)", "Bash(npm run *)", "Bash(git *)"],
    "__REPLACE_WITH_GRAPH_INCREMENTAL_UPDATE_COMMAND__": [],  # no code-review-graph in this fixture
}
new_allow = []
for entry in allow:
    new_allow.extend(replacements.get(entry, [entry]))
for extra in ["Bash(npm test)", "Bash(npm run *)", "Bash(git *)"]:
    if extra not in new_allow:
        new_allow.append(extra)
settings["permissions"]["allow"] = new_allow

# Same OTel telemetry env block ~/claude_trace/.claude/settings.json uses,
# with this run's own unique project.name.
env = settings.setdefault("env", {})
env.update({
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4318",
    "OTEL_METRIC_EXPORT_INTERVAL": "60000",
    "OTEL_METRICS_INCLUDE_SESSION_ID": "true",
    "OTEL_RESOURCE_ATTRIBUTES": f"project.name={project_name}",
})

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF

( cd "$DEST" && git init -q && git add -A && git commit -q -m "eval fixture baseline" )

echo "$PROJECT_NAME"
