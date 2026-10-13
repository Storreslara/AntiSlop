#!/usr/bin/env bash
# epf-5 AC5.4 (scope): only bin/cli.js and the cross-reference test change.
D=$(cd "$(dirname "$0")" && pwd)
exec bash "$D/scope.sh" epf-5 'bin/cli\.js|tests/protocol-cross-references\.test\.js'
