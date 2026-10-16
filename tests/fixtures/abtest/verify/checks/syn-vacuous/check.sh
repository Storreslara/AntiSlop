#!/usr/bin/env bash
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check always-true defect true 'true'
abt_check_scope scope-outside-allowed true
abt_emit
