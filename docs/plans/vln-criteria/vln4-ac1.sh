#!/usr/bin/env bash
# vln4-ac1.sh: the vlg plan's vlg-3 "measured:" line carries the re-measured
# timings (test about 0.35 s, criteria 1-3 about 3 s; monotonic, at 5178319)
# instead of the first estimate (about 5 s and 40 s), exactly once, and the
# vlg-3 dispatch contract still scores 7/7 under contract-guard.
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
p=docs/plans/2026-10-14-validate-lanes-and-guard-followups.md
old='the test takes about 5 s; criteria 1-3 about 40 s together;'
new='the test takes about 0.35 s; criteria 1-3 about 3 s together (re-measured with /proc/uptime at 5178319 on 2026-10-14; the first estimate, 5 s and 40 s, was stale);'
[ "$(grep -cF -- "$old" "$p")" = 0 ] || { echo "the stale timing text is still present"; exit 1; }
[ "$(grep -cF -- "$new" "$p")" = 1 ] || { echo "the re-measured timing text is not present exactly once"; exit 1; }
[ "$(grep -c '^measured: at e13447a each anchor occurs once and validate.sh has 115 sections' "$p")" = 1 ] \
  || { echo "the vlg-3 measured: line lost its start"; exit 1; }
g=$(node bin/contract-guard.js "$p" --unit=vlg-3 2>&1)
[ "$g" = 'contract-guard: haiku unit=vlg-3 shape=lead score=7/7' ] || { echo "contract-guard: $g"; exit 1; }
exit 0
