#!/usr/bin/env bash
# Function-level tests for hooks/scripts/lib/agent-identity.sh's
# identity_drift_log: regression coverage from the #140 review plus the #140
# follow-up hardening fixes (an unusable audit log must never abort the calling
# hook, on either the read or the write path; the dedupe key must be injective
# so a crafted identity cannot suppress a genuine one).
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

# --- Fix 1: an unusable audit log must not abort the calling hook ---
# Two distinct failure modes: chmod 444 exercises the WRITE path (open for
# append fails), chmod 000 additionally exercises the READ path (the dedupe
# scan's `done < "$audit"` redirection fails). Both must leave the caller
# running AND emit nothing on stderr - a failed redirection's diagnostic comes
# from the shell itself, so it escapes a bare `2>/dev/null` on the command.
check_unusable_audit() {
  local mode="$1" label="$2" a rc=0 out err
  a="$(mktemp)"
  chmod "$mode" "$a"
  err="$(mktemp)"
  out="$(
    bash -c '
      set -euo pipefail
      source "'"$lib"'"
      identity_drift_log "otherplugin:reviewer" "hook" "'"$a"'"
      echo CONTINUED
    ' 2>"$err"
  )" || rc=$?
  chmod 644 "$a"
  if [ "$rc" = 0 ] && [ "$out" = "CONTINUED" ] && [ ! -s "$err" ]; then
    echo "OK   fix1 ($label): $mode audit log degrades to a silent no-op instead of aborting the caller"
  else
    echo "FAIL fix1 ($label): rc=$rc out='$out' stderr='$(cat "$err")' (expected rc=0, CONTINUED, empty stderr)"
    fail=1
  fi
  rm -f "$a" "$err"
}
check_unusable_audit 444 write-path
check_unusable_audit 000 read-path

# --- Fix 2: the dedupe key must be injective ---
# Every payload below is a DIFFERENT raw identity that the old strip-based
# sanitizer collapsed onto the same displayed value as the genuine
# "otherplugin:evil", in a different drift class. Logging the crafted one first
# must never swallow the genuine entry that follows.
genuine="otherplugin:evil"
for poison in \
  'otherplugin:evil@' \
  'otherplugin!:evil' \
  'otherplugin:evil ' \
  'poison me identity=otherplugin:evil'
do
  audit="$(mktemp)"
  rm -f "$audit"
  (
    source "$lib"
    identity_drift_log "$poison" "hook" "$audit"
    identity_drift_log "$genuine" "hook" "$audit"
  )
  lines="$(wc -l < "$audit")"
  if [ "$lines" = 2 ] \
     && grep -q 'class=unparseable' "$audit" \
     && grep -q "class=unrecognized-namespace.*identity=${genuine}\$" "$audit"; then
    echo "OK   fix2: crafted '$poison' does not swallow the genuine '$genuine' entry"
  else
    echo "FAIL fix2: dedupe collision reproduced for '$poison' (got $lines lines, expected 2 distinct entries)"
    fail=1
  fi
  rm -f "$audit"
done

# --- Fix 2b: the length cap is a second lossy step feeding the same key ---
# Two identities sharing their first 128 bytes but differing past the cap, in
# different classes. The cap makes their displayed values identical, so the key
# must carry the class too or the first logged swallows the second.
long_prefix="other:$(printf 'a%.0s' $(seq 1 122))"
if [ "${#long_prefix}" != 128 ]; then
  echo "FAIL fix2b: test fixture prefix is ${#long_prefix} bytes, expected 128"
  fail=1
fi
audit="$(mktemp)"
rm -f "$audit"
(
  source "$lib"
  identity_drift_log "${long_prefix}@" "hook" "$audit"
  identity_drift_log "${long_prefix}X" "hook" "$audit"
)
lines="$(wc -l < "$audit")"
if [ "$lines" = 2 ] \
   && grep -q 'class=unparseable' "$audit" \
   && grep -q 'class=unrecognized-namespace' "$audit"; then
  echo "OK   fix2b: identities differing only past the 128-byte cap stay distinct across classes"
else
  echo "FAIL fix2b: 128-byte truncation collision reproduced (got $lines lines, expected 2)"
  fail=1
fi
rm -f "$audit"

exit "$fail"
