#!/usr/bin/env bash
# E2 holdout checks. Usage: check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check no-mutation-and-checkout-match defect true 'cp "$ABT_CHECKS_DIR/preview.holdout.test.js" test/ && node --test test/preview.holdout.test.js'
abt_check rounding-sensitive-cart defect true 'cp "$ABT_CHECKS_DIR/rounding.holdout.test.js" test/ && node --test test/rounding.holdout.test.js'
abt_check original-tests-still-pass defect true 'node --test test/pricing.test.js' test/pricing.test.js
abt_check_scope scope-outside-allowed true
abt_emit
