#!/usr/bin/env bash
# E1 premise matcher. Usage: assumptions.sh ASSUMPTIONS_FILE
# Exit 0 only when the file records both resolved facts: the rate is a
# percentage, and tax is applied after the discount. Echoes of the signature
# (cartTotalWithTax, taxRate, discountPct) and the pre-discount wording are
# dropped first, so restating the prompt scores nothing. Every other outcome
# (missing, empty, unreadable, a crashed tool) exits non-zero.
set -uo pipefail
f="${1:-}"
[ -n "$f" ] && [ -f "$f" ] && [ -s "$f" ] || exit 1
t="$(tr '[:upper:]' '[:lower:]' < "$f" | tr '\n' ' ')" || exit 1
t="$(printf '%s' "$t" | sed -E 's/carttotalwithtax *\([^)]*\)//g; s/carttotalwithtax|taxrate|discountpct//g; s/\b(pre|non|un)-? ?discount(ed)?//g; s/before (the |any )?discount//g')" || exit 1
[ -n "${t//[[:space:]]/}" ] || exit 1
printf '%s' "$t" | LC_ALL=C grep -qE '(^|[^a-z])(percent(age)?s?|per cent)([^a-z]|$)|%' || exit 1
printf '%s' "$t" | LC_ALL=C grep -qE 'post[- ]?discount|\bdiscounted\b|after (applying |taking |subtracting )?(the |any |a )?discount|net of (the |any )?discount|reduced (price|total|subtotal|amount)|discount[a-z ,;]{0,30} (first|then (the |a )?tax|before (the )?tax)' || exit 1
exit 0
