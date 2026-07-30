#!/usr/bin/env bash
# Provisions a disposable fixture that dispatches personas via the
# `antislop:`-prefixed marketplace form (scaffold.sh alone installs bare-name
# project-local copies only), then prints the R8 provenance table. Used by
# Probe C in docs/experiments/2026-07-probe-hook-payloads.md; the fixture is
# throwaway, the probe document is the durable artifact.
#
# Usage: probe-namespaced-dispatch.sh DEST CAPTURE_DIR
# Prerequisite: `claude plugin update antislop@antislop-marketplace` has
# already refreshed the cache to this working tree's version.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${1:?usage: probe-namespaced-dispatch.sh DEST CAPTURE_DIR}"
CAPTURE_DIR="${2:?missing CAPTURE_DIR}"

"$REPO_ROOT/eval/harness/scaffold.sh" "$DEST" --force >/dev/null
DEST="$(cd "$DEST" && pwd)"
mkdir -p "$CAPTURE_DIR"
CAPTURE_DIR="$(cd "$CAPTURE_DIR" && pwd)"

# 1. Enable the marketplace plugin for this fixture — the only thing that
#    makes `antislop:<persona>` a dispatchable identity. Key shape per
#    tests/cli-backfill.test.js:151.
python3 - "$DEST/.claude/settings.json" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)
settings.setdefault("enabledPlugins", {})["antislop@antislop-marketplace"] = True
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF

# 2. Assert there are no standalone hook registrations to collide with the
#    plugin's own (bin/cli.js skips its own hook merge when the plugin is
#    already enabled). Registering the fixed scripts a second time by absolute
#    path would double-fire every hook — the collision --dedupe-hooks exists
#    for — so the probe must run with the plugin's ${CLAUDE_PLUGIN_ROOT}
#    registrations as the ONLY ones present.
if grep -q 'CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/' "$DEST/.claude/settings.json"; then
  echo "probe: standalone hook registrations present — would double-fire; run bin/cli.js --update --dedupe-hooks" >&2
  exit 1
fi

# 3. Temporary logging hooks, in the FIXTURE's settings.json (never this
#    repo's hooks/hooks.json), writing outside the fixture so the probe's own
#    captures do not dirty its git tree.
mkdir -p "$DEST/.probe"
for event in pretooluse-agent subagentstop; do
  cat > "$DEST/.probe/log-$event.sh" <<EOF
#!/usr/bin/env bash
cat >> "$CAPTURE_DIR/probe-$event.jsonl"
printf '\n' >> "$CAPTURE_DIR/probe-$event.jsonl"
env | grep -E '^CLAUDE_' | sort > "$CAPTURE_DIR/hook-env-$event.txt"
exit 0
EOF
  chmod +x "$DEST/.probe/log-$event.sh"
done

python3 - "$DEST/.claude/settings.json" "$DEST" <<'PYEOF'
import json, sys
path, dest = sys.argv[1], sys.argv[2]
with open(path) as f:
    settings = json.load(f)
hooks = settings.setdefault("hooks", {})
hooks.setdefault("PreToolUse", []).append(
    {"matcher": "Agent",
     "hooks": [{"type": "command", "command": f"{dest}/.probe/log-pretooluse-agent.sh"}]})
hooks.setdefault("SubagentStop", []).append(
    {"hooks": [{"type": "command", "command": f"{dest}/.probe/log-subagentstop.sh"}]})
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF

printf '.probe/\n' >> "$DEST/.gitignore"
( cd "$DEST" && git add -A && git commit -q -m "probe fixture: namespaced dispatch enabled" )

# 4. R8 provenance assertion — the executing scripts must be byte-identical to
#    the working tree, or the whole run is void.
PLUGIN_ROOT="$(python3 - <<'PYEOF'
import json, os
p = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
with open(p) as f:
    data = json.load(f)
print(data["plugins"]["antislop@antislop-marketplace"][0]["installPath"])
PYEOF
)"
echo
echo "CLAUDE_PLUGIN_ROOT (resolved install path) = $PLUGIN_ROOT"
echo
printf '%-38s %-64s %-64s %s\n' script "sha256(plugin-root)" "sha256(working-tree)" verdict
rc=0
for f in hooks/scripts/lib/agent-identity.sh hooks/scripts/stop-gate.sh \
         hooks/scripts/reviewer-route-gate.sh hooks/scripts/reviewed-path-gate.sh; do
  a="$(sha256sum "$PLUGIN_ROOT/$f" | cut -d' ' -f1)"
  b="$(sha256sum "$REPO_ROOT/$f" | cut -d' ' -f1)"
  if [ "$a" = "$b" ]; then verdict=EQUAL; else verdict=MISMATCH; rc=1; fi
  printf '%-38s %-64s %-64s %s\n' "${f#hooks/scripts/}" "$a" "$b" "$verdict"
done
echo
[ "$rc" -eq 0 ] || { echo "R8 VOID: plugin-root scripts differ from the working tree." >&2; exit 1; }
echo "R8 OK — fixture ready at $DEST (captures -> $CAPTURE_DIR)"
