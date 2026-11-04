#!/usr/bin/env bash
# gate-default-off criterion 5: counts the seven doc claims that name the
# fresh-install default. Prints the count; run from the repo root.
n=0
sed -n '/^## Amendment (2026-11-04)/,$p' docs/adr/0038-review-gating-runtime-switch.md | grep -q 'bin/cli.js' && n=$((n+1))
sed -n '/^\*\*review gating off\*\*/,/^\*\*advisory verdict\*\*/p' CONTEXT.md | grep -q 'fresh install' && n=$((n+1))
grep -E '^\| `reviewGating.mode` \|' README.md | grep -q 'fresh install' && n=$((n+1))
jq -r .properties.reviewGating.properties.mode.description templates/persona-config.schema.json | grep -q 'fresh install' && n=$((n+1))
grep -E '^\| 13 \|' docs/trust-model.md | grep -q 'bin/harness-integrity.sh' && n=$((n+1))
grep -qF 'Always write the key: "off" or "enforce".' skills/install-antislop/SKILL.md && n=$((n+1))
sed -n '/^## \[Unreleased\]/,/^## \[0\.35\.0\]/p' CHANGELOG.md | grep -q 'gate-default-off' && n=$((n+1))
echo "$n"
