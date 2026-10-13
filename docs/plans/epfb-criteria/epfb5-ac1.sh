#!/usr/bin/env bash
# epfb-5 AC5.1 (item h): the viewer test passes when its mktemp paths contain
# "raw", and no unanchored `grep -q 'raw'` remains.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
n=$(grep -cF "grep -q 'raw'" tests/packet-view-script.test.sh)
[ "$n" -eq 0 ] || { echo "$n unanchored raw greps"; exit 1; }
d=$(mktemp -d)/rawdir; mkdir -p "$d"
TMPDIR="$d" bash tests/packet-view-script.test.sh >/dev/null 2>&1 || { echo "fails under a TMPDIR containing raw"; exit 1; }
bash tests/packet-view-script.test.sh >/dev/null 2>&1 || { echo "fails under the default TMPDIR"; exit 1; }
