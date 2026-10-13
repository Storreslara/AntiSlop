#!/usr/bin/env bash
# scope.sh <unit-id> <allowed-files-ERE> [mirrors]
# Prints nothing and exits 0 when every file the unit's own commits changed is
# in the allowed list (or, with `mirrors`, matches the generated-mirror regex).
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
unit=$1; allow=$2; mode=${3:-}
need_unit "$unit"
files=$(for c in $(ucommits "$unit"); do git diff --name-only "$c~1" "$c"; done | sort -u)
extra=$(printf '%s\n' "$files" | grep -vxE "$allow")
if [ "$mode" = mirrors ]; then extra=$(printf '%s\n' "$extra" | grep -vE "$MIRROR_RE"); fi
extra=$(printf '%s\n' "$extra" | sed '/^$/d')
[ -z "$extra" ] || { echo "out of scope: $extra"; exit 1; }
