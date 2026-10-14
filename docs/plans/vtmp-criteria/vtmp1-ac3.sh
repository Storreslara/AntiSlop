#!/usr/bin/env bash
# vtmp1-ac3.sh: vtmp-1 changed tests/validate.sh by the mktemp substitution only.
# Drops the five inserted `<name>=$(mktemp)` lines from the unit's last version,
# turns each "$<name>" back into /tmp/<name>, and compares the result with the
# file before the unit's first commit, byte for byte. Prints nothing on success.
D=$(cd "$(dirname "$0")/../epf-criteria" && pwd); . "$D/lib.sh"
need_unit vtmp-1
N='npm_pack_err|marketplace_err|claude_plugin_tag_out|frontmatter_yaml_err|codex_toml_err'
base=$(git show "$F~1:tests/validate.sh") || exit 1
rev=$(git show "$L:tests/validate.sh" | grep -vxE " *($N)=\\\$\\(mktemp\\)" |
  sed -E "s#\"\\\$($N)\"#/tmp/\\1#g") || exit 1
[ "$rev" = "$base" ] || {
  echo "validate.sh differs beyond the mktemp substitution:"
  diff <(printf '%s\n' "$base") <(printf '%s\n' "$rev") | head -6; exit 1; }
