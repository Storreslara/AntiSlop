#!/usr/bin/env bash
# epf-2 AC2.5: the card and view.sh blocks are byte-untouched.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
node tests/adapter-protocol-parity.test.js >/dev/null || { echo "parity (card byte-identity) failed"; exit 1; }
bash tests/packet-view-script.test.sh >/dev/null 2>&1 || { echo "packet-view-script T1 failed"; exit 1; }
