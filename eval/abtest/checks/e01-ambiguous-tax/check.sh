#!/usr/bin/env bash
# E1 holdout checks. Usage: check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check tax-after-discount defect true 'cp "$ABT_CHECKS_DIR/tax.holdout.test.js" test/ && node --test test/tax.holdout.test.js'
abt_check existing-behaviour defect true 'cp "$ABT_CHECKS_DIR/characterisation.holdout.test.js" test/ && node --test test/characterisation.holdout.test.js'
abt_check assumptions-file-present process false 'f=ASSUMPTIONS.md; p="$ABT_CHECKS_DIR/../../tasks/e01-ambiguous-tax.prompt.md"; git cat-file -e "$ABT_BASE:CONTEXT.md" && git cat-file -e "$ABT_BASE:README.md" && [ -f "$f" ] && [ -s "$p" ] && [ "$(grep -c "[^[:space:]]" "$f")" -ge 2 ] && [ "$(tr -d "[:space:]" < "$f" | wc -c)" -ge 40 ] && ! cmp -s "$f" <(git show "$ABT_BASE:CONTEXT.md") && ! cmp -s "$f" <(git show "$ABT_BASE:README.md") && ! cmp -s "$f" "$p"'
abt_check_scope scope-outside-allowed true
abt_emit
