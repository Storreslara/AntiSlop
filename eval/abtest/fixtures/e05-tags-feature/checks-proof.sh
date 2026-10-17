#!/usr/bin/env bash
# Shows three properties of the E5 hidden checks on the reference solution, one line per case
# ("<case>: <check> pass|fail"): the migration check does not read a dump the arm changed;
# readme-tags-route needs the route, not the name of a test file; and
# readme-data-format-v2 needs a version 2 note, not the words "Node version 20".
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
G=(git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid)
base="$(bash "$HERE/build.sh" "$T/w" | tail -n1)"
for p in "$HERE"/reference.d/*.patch; do
  "${G[@]}" apply --recount "$p"
  "${G[@]}" add -A
  "${G[@]}" commit -q -m reference
done
"${G[@]}" tag reference
show() {
  local label="$1" json
  shift
  json="$(bash "$ABT_REPO_ROOT/eval/abtest/checks/e05-tags-feature/check.sh" "$T/w" "$base" "$base" "$HERE/allowed-paths.txt")"
  python3 -I -c 'import json,sys;c={x["id"]:x["pass"] for x in json.loads(sys.argv[1])};[print(sys.argv[2] + ":", k, "pass" if c[k] else "fail") for k in sys.argv[3:]]' "$json" "$label" "$@"
}
variant() {
  "${G[@]}" reset -q --hard reference
  "$@"
  "${G[@]}" add -A
  "${G[@]}" commit -q --allow-empty -m variant
}
noop_migrate() { printf '%s\n' "require('node:fs').copyFileSync(process.argv[2], process.argv[3]);" > "$T/w/scripts/migrate-v1.js"; }
tamper() { noop_migrate; empty_dump; }
empty_dump() { printf '%s\n' '{"version": 2, "notes": []}' > "$T/w/data/dump-v1.json"; }
readme_edit() { python3 -I -c 'import sys;p=sys.argv[1];s=open(p).read();exec(sys.argv[2]);open(p,"w").write(s)' "$T/w/README.md" "$1"; }
variant true
show "the reference" migration readme-tags-route readme-data-format-v2
variant tamper
show "a no-op migrate script and an emptied v2 dump" migration
variant noop_migrate
show "a no-op migrate script and the original dump" migration
variant readme_edit 's="\n".join(l for l in s.split("\n") if "/tags" not in l)+"\n| test | test/tags.test.js |\nTests: test/tags-counts.test.js\n"'
show "a README that names the route only through a test file" readme-tags-route
variant readme_edit 's="\n".join(l for l in s.split("\n") if "/tags" not in l)+"\nTry: curl localhost:3000/tags\n"'
show "a README that shows the route in a curl example" readme-tags-route
variant readme_edit 's=s[:s.index("## Data format v2")]+"Runs on Node version 20.\n"'
show "a README that says Node version 20" readme-data-format-v2
