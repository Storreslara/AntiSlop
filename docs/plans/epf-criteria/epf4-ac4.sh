#!/usr/bin/env bash
# epf-4 AC4.4: CSS tokens and scope.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
H=bin/microworld-dashboard/index.html
grep -qE '^ *\.doc-pane table *\{' "$H" && grep -qE '^ *\.doc-pane th, *\.doc-pane td *\{' "$H" || { echo "table CSS missing"; exit 1; }
! grep -E '^ *\.doc-pane (table|th)' "$H" | grep -qE '#[0-9a-fA-F]{3,8}\b|rgb\(' || { echo "raw colour"; exit 1; }
exec bash "$D/scope.sh" epf-4 'bin/microworld-dashboard/markdown-lite\.js|bin/microworld-dashboard/index\.html|tests/microworld/dashboard-markdown-lite\.test\.js'
