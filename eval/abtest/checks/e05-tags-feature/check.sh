#!/usr/bin/env bash
# E5 holdout checks. Usage: check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
T='cp "$ABT_CHECKS_DIR"/lib.holdout.js test/ && cp "$ABT_CHECKS_DIR/%s" test/ && node --test test/%s'
abt_check tags-validation defect true "$(printf "$T" validation.holdout.test.js validation.holdout.test.js)"
abt_check tag-filter-http-and-cli defect true "$(printf "$T" filter.holdout.test.js filter.holdout.test.js)"
abt_check tags-counts defect true "$(printf "$T" counts.holdout.test.js counts.holdout.test.js)"
abt_check migration defect true "$(printf "$T" migration.holdout.test.js migration.holdout.test.js)"
abt_check readme-tags-route defect true 'grep -q "/tags" README.md'
abt_check readme-data-format-v2 docs false 'grep -qi "version.*2" README.md'
abt_check original-tests-still-pass defect true 'node --test test/store.test.js test/server.test.js test/cli.test.js' test/store.test.js test/server.test.js test/cli.test.js
abt_check commits-at-least-four process true 'n=$(git rev-list --count "$ABT_START..HEAD"); [ $((n - ${ABT_SNAPSHOT:-0})) -ge 4 ]'
abt_check_scope scope-outside-allowed true
abt_emit
