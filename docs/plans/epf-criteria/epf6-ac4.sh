#!/usr/bin/env bash
# epf-6 AC6.4: seven erratum sub-bullets, the Errata section, and scope.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
P=docs/plans/2026-10-12-escalation-packet-aesthetics.md
[ "$(grep -c '^  - erratum (2026-10-13, epf-6)' "$P")" -ge 7 ] || { echo "fewer than 7 erratum sub-bullets"; exit 1; }
grep -q '^## Errata (2026-10-13, epf-6)' "$P" || { echo "no Errata section"; exit 1; }
exec bash "$D/scope.sh" epf-6 'docs/plans/2026-10-12-escalation-packet-aesthetics\.md|docs/plans/2026-10-01-in-session-escalation-decision\.md'
