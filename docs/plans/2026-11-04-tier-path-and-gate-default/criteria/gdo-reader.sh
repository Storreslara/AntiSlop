#!/usr/bin/env bash
# gate-default-off criterion 4: the reviewGating reader rule is unchanged.
# Exit 1 if any reader surface changed since 57267561 (tier-path-rule's two
# files excepted); otherwise prints the schema default, whether the schema
# keeps its resolution sentence, and the CONTEXT.md absent-rule line count.
set -euo pipefail
git diff --quiet 57267561 -- hooks adapters commands eval bin/harness-integrity.sh \
  ':!hooks/scripts/reviewer-tier.sh' ':!hooks/scripts/lib/sensitive-paths.sh'
jq -r '.properties.reviewGating.properties.mode | .default, (.description | test("absent, unreadable or any other value resolves to enforce"))' \
  templates/persona-config.schema.json
grep -c 'Absent or junk values mean `enforce`' CONTEXT.md
