#!/usr/bin/env bash
# Overlays a named variant's changed persona/hook files onto an already
# -scaffolded fixture (see scaffold.sh). Variant dirs mirror .claude/'s own
# structure, e.g. eval/variants/terse-reviewer/agents/reviewer.md lands at
# DEST/.claude/agents/reviewer.md.
#
# Usage: apply-variant.sh DEST VARIANT_SLUG
#   VARIANT_SLUG "baseline" (or omitted) is a no-op — the scaffolded repo's
#   unmodified persona files are the control condition.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DEST="${1:?usage: apply-variant.sh DEST VARIANT_SLUG}"
VARIANT="${2:-baseline}"

if [ ! -d "$DEST/.claude" ]; then
  echo "apply-variant.sh: $DEST/.claude not found — run scaffold.sh first." >&2
  exit 1
fi

if [ "$VARIANT" = "baseline" ]; then
  echo "apply-variant.sh: baseline condition, no files overlaid."
  exit 0
fi

VARIANT_DIR="$REPO_ROOT/eval/variants/$VARIANT"
if [ ! -d "$VARIANT_DIR" ]; then
  echo "apply-variant.sh: no such variant dir: $VARIANT_DIR" >&2
  exit 1
fi

cp -r "$VARIANT_DIR/." "$DEST/.claude/"
( cd "$DEST" && git add -A && git commit -q -m "apply variant: $VARIANT" )
echo "apply-variant.sh: applied $VARIANT to $DEST"
