#!/usr/bin/env bash
# Removes a scratch fixture dir AND the ~/.claude.json trust entry
# scaffold.sh added for it — the two are created together, so they should be
# torn down together rather than leaving stale trust entries for deleted
# paths accumulating in the user's global config.
#
# Usage: cleanup.sh DEST
#   DEST    a dir previously created by scaffold.sh
set -euo pipefail

DEST="${1:?usage: cleanup.sh DEST}"

if [ -d "$DEST" ]; then
  DEST="$(cd "$DEST" && pwd)"
  rm -rf "$DEST"
fi

python3 - "$DEST" <<'PYEOF'
import json, os, sys

dest = sys.argv[1]
config_path = os.path.expanduser("~/.claude.json")
with open(config_path) as f:
    config = json.load(f)

if config.get("projects", {}).pop(dest, None) is not None:
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")
PYEOF

echo "cleanup.sh: removed $DEST and its trust entry"
