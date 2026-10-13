#!/usr/bin/env bash
# p3.sh <unit-id>: the mirror and version-stamp idiom for a stamped unit.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
unit=$1
need_unit "$unit"
node bin/cli.js --update --dry-run >/dev/null || { echo "update --dry-run rc!=0 (stale mirror)"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "dirty tree"; git status --porcelain | head -5; exit 1; }
for c in $(ucommits "$unit"); do
  bash hooks/scripts/version-stamp-check.sh "$c~1..$c" | grep -q '^version-stamp-check: ok' \
    || { echo "version-stamp-check not ok at $c"; exit 1; }
done
grep -q "($unit, " CHANGELOG.md || { echo "no CHANGELOG entry for $unit"; exit 1; }
node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;process.exit(a===b?0:1)" \
  || { echo "package.json and plugin.json versions differ"; exit 1; }
