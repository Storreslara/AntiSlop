#!/usr/bin/env bash
# vtargeted.sh '<header substring>'...: run each named validate.sh section group.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
export CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel)" REVIEWED_DIR_LEAK_GUARD_NESTED=1
for k in "$@"; do
  vrun "$k" >/dev/null 2>&1 || { echo "section group failed: $k"; exit 1; }
done
