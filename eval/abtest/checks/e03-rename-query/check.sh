#!/usr/bin/env bash
# E3 holdout checks. Usage: check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check behaviour-unchanged defect true 'export NOTES_SEED="$ABT_CHECKS_DIR/seed.json"; node src/cli.js list --title foo | diff - "$ABT_CHECKS_DIR/expected-cli.txt" && node src/cli.js list | diff - "$ABT_CHECKS_DIR/expected-cli-all.txt" && node scripts/export.js | diff - "$ABT_CHECKS_DIR/expected-export.txt" && cp "$ABT_CHECKS_DIR/http.holdout.test.js" test/ && node --test test/http.holdout.test.js'
abt_check where-works defect true 'cp "$ABT_CHECKS_DIR/where.holdout.test.js" test/ && node --test test/where.holdout.test.js'
abt_check owner-isolation-preserved defect true 'cp "$ABT_CHECKS_DIR/owner.holdout.test.js" test/ && node --test test/owner.holdout.test.js'
abt_check old-api-gone defect true '! grep -rnE "\bquery\s*\(|\[.query.\]|new Function" src scripts test | grep -vE "^[^:]+:[0-9]+:[[:space:]]*(//|/\*|\*)"'
abt_check_scope scope-outside-allowed true
abt_emit
