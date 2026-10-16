#!/usr/bin/env bash
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check answer-is-two defect true 'grep -qx 2 answer.txt'
abt_check two-commits process true '[ "$(git rev-list --count "$ABT_START..HEAD")" -ge 2 ]'
abt_check_scope scope-outside-allowed true
abt_emit
