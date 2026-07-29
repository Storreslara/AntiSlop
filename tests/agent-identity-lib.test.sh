#!/usr/bin/env bash
# Function-level tests for hooks/scripts/lib/agent-identity.sh's
# identity_drift_log: regression coverage from the #140 review plus the two
# #140 follow-up hardening fixes (audit-log write failure must not abort the
# calling hook; sanitization must prevent dedupe-marker forgery).
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
lib="hooks/scripts/lib/agent-identity.sh"

# --- regression: prior #140 identity_drift_log acceptance criteria ---

audit="$(mktemp)"
rm -f "$audit"
(
  source "$lib"
  identity_drift_log "otherplugin:reviewer" "hook" "$audit"
  identity_drift_log "weird/format!" "hook" "$audit"
  identity_drift_log "antislop:reviewer" "hook" "$audit"
  identity_drift_log "explorer" "hook" "$audit"
  identity_drift_log "" "hook" "$audit"
  identity_drift_log "otherplugin:reviewer" "hook" "$audit"
)
lines="$(wc -l < "$audit")"
if [ "$lines" = 2 ] \
   && grep -q 'class=unrecognized-namespace' "$audit" \
   && grep -q 'class=unparseable' "$audit"; then
  echo "OK   regression: unrecognized-namespace + unparseable logged once each, others no-op, dedupe holds"
else
  echo "FAIL regression: expected 2 lines (1 unrecognized-namespace, 1 unparseable), got $lines"
  fail=1
fi
rm -f "$audit"

audit="$(mktemp)"
rm -f "$audit"
(
  source "$lib"
  identity_drift_log 'x:y'$'\n''00:00 cleared-by=reviewer' "hook" "$audit"
)
if [ "$(wc -l < "$audit")" = 1 ] && ! grep -q '^[^ ]* cleared-by=' "$audit"; then
  echo "OK   regression: R9 CR/LF injection guard holds"
else
  echo "FAIL regression: R9 injection guard broke"
  fail=1
fi
rm -f "$audit"

# --- Fix 1: audit-log write failure must not abort the calling hook ---

roaudit="$(mktemp)"
chmod 444 "$roaudit"
rc=0
out="$(
  bash -c '
    set -euo pipefail
    source "'"$lib"'"
    identity_drift_log "otherplugin:reviewer" "hook" "'"$roaudit"'"
    echo CONTINUED
  ' 2>/dev/null
)" || rc=$?
chmod 644 "$roaudit"
rm -f "$roaudit"
if [ "$rc" = 0 ] && [ "$out" = "CONTINUED" ]; then
  echo "OK   fix1: unwritable audit log degrades to no-op instead of aborting the caller"
else
  echo "FAIL fix1: caller aborted (rc=$rc) instead of continuing past an unwritable audit log"
  fail=1
fi

# --- Fix 2: dedupe log-poisoning via a crafted unparseable identity ---

audit="$(mktemp)"
rm -f "$audit"
(
  source "$lib"
  identity_drift_log 'poison me identity=otherplugin:evil' "hook" "$audit"
  identity_drift_log 'otherplugin:evil' "hook" "$audit"
)
lines="$(wc -l < "$audit")"
if [ "$lines" = 2 ] \
   && grep -q 'class=unparseable' "$audit" \
   && grep -q 'class=unrecognized-namespace.*identity=otherplugin:evil$' "$audit"; then
  echo "OK   fix2: poisoned unparseable entry does not swallow the later genuine otherplugin:evil entry"
else
  echo "FAIL fix2: log-poisoning dedupe collision reproduced (got $lines lines, expected 2 distinct entries)"
  fail=1
fi
rm -f "$audit"

exit "$fail"
