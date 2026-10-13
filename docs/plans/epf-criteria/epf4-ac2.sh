#!/usr/bin/env bash
# epf-4 AC4.2: escape-first kept: no new escape site, cells go through renderInline only.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
M=bin/microworld-dashboard/markdown-lite.js
[ "$(grep -c 'escapeHtml(' "$M")" -eq 5 ] || { echo "escapeHtml( count changed"; exit 1; }
[ "$(grep -c 'function renderInline' "$M")" -eq 1 ] || { echo "renderInline definition count"; exit 1; }
grep -q "'<th>' + renderInline(" "$M" && grep -q "'<td>' + renderInline(" "$M" || { echo "cells bypass renderInline"; exit 1; }
! grep -qE '<t[hd] |align=|style=' "$M" || { echo "table tags carry attributes"; exit 1; }
