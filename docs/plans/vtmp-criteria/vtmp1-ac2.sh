#!/usr/bin/env bash
# vtmp1-ac2.sh: validate.sh sections 5-7, 10 and 67 pass when /tmp is read-only,
# and they leave no mktemp file (tmp.*) in TMPDIR. Runs in a private user+mount namespace: a private
# tmpfs on /var/tmp holds TMPDIR (t/) and a bind of this checkout (r/), then a
# read-only tmpfs hides /tmp. The real /tmp is never touched. Prints nothing
# and exits 0 on success; exit 2 means the namespace is unavailable.
D=$(cd "$(dirname "$0")/../epf-criteria" && pwd); . "$D/lib.sh"
unshare -rm true 2>/dev/null || { echo "unshare -rm unavailable"; exit 2; }
unshare -rm bash -c '
  mount -t tmpfs none /var/tmp && mkdir /var/tmp/t /var/tmp/r &&
    mount --bind "$1" /var/tmp/r && mount -t tmpfs -o ro none /tmp ||
    { echo "namespace mount setup failed"; exit 2; }
  export TMPDIR=/var/tmp/t REVIEWED_DIR_LEAK_GUARD_NESTED=1
  cd /var/tmp/r && . docs/plans/epf-criteria/lib.sh
  for r in "5 7" "10 10" "67 67"; do
    vsec $r >/dev/null 2>&1 || { echo "sections $r failed with /tmp read-only"; exit 1; }
  done
  left=$(ls -A /var/tmp/t | grep "^tmp\.")
  [ -z "$left" ] || { echo "TMPDIR not cleaned: $left"; exit 1; }
' _ "$PWD"
