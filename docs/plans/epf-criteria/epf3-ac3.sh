#!/usr/bin/env bash
# epf-3 AC3.3 (scope): the unit's commits change only the viewer test.
D=$(cd "$(dirname "$0")" && pwd)
exec bash "$D/scope.sh" epf-3 'tests/packet-view-script\.test\.sh'
