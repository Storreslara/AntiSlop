#!/usr/bin/env bash
# vtmp1-ac1.sh: tests/validate.sh and tests/lib/*.sh name no fixed /tmp path, and
# each of the five scratch files is made by one mktemp line and removed by one
# rm -f line. Prints nothing and exits 0 on success.
D=$(cd "$(dirname "$0")/../epf-criteria" && pwd); . "$D/lib.sh"
bad=$(grep -nE '/tmp' tests/validate.sh tests/lib/*.sh)
[ -z "$bad" ] || { echo "fixed /tmp path remains:"; printf '%s\n' "$bad"; exit 1; }
for n in npm_pack_err marketplace_err claude_plugin_tag_out frontmatter_yaml_err codex_toml_err; do
  a=$(grep -cxE " *$n=\\\$\\(mktemp\\)" tests/validate.sh)
  b=$(grep -cxE " *rm -f \"\\\$$n\"" tests/validate.sh)
  [ "$a $b" = "1 1" ] || { echo "$n: mktemp lines=$a rm lines=$b (want 1 1)"; exit 1; }
done
