#!/usr/bin/env bash
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check answer-is-three defect true 'grep -qx 3 answer.txt'
abt_check_scope scope-outside-allowed true
abt_emit
