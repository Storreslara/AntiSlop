#!/usr/bin/env bash
# epf-1 AC1.5: the durable parity-test pin runs and passes.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
log=$(mktemp)
node tests/adapter-protocol-parity.test.js > "$log" || { tail -5 "$log"; exit 1; }
grep -q '^OK   orchestrator escalation steps handle a marker with no fold line or no decide: line' "$log" || { echo "check not run"; exit 1; }
